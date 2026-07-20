#!/usr/bin/env bash
# test-dep-authorization.sh — execute-bolts code gate 6 (P9, v5.3.0).
# The anti-over-engineering dep-authorization: a bolt that adds a dependency the
# unit's allowed_new_deps did not sanction is flagged (advisory). Legacy-safe:
# a unit with no allowed_new_deps key is a no-op. Always exit 0 (advisory-first).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."
SC="$ROOT/plugins/mega-sdd/scripts/check-dep-authorization.sh"
LIB="$ROOT/plugins/mega-sdd/scripts/_lib"
rc=0
ok()  { echo "PASS ($1)"; }
bad() { echo "FAIL ($1)"; rc=1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t depauth)"
trap 'rm -rf "$WORK"' EXIT

# ── a repo that ADDS axios + fakepkg9zz (lodash pre-exists) ──────────────────
R="$WORK/repo"; mkdir -p "$R/u"
( cd "$R"; git init -q; git config user.email t@t; git config user.name t
  printf '{"dependencies":{"lodash":"^4"}}\n' > package.json; git add -A; git commit -qm base >/dev/null
  printf '{"dependencies":{"lodash":"^4","axios":"^1","fakepkg9zz":"^1"}}\n' > package.json
  git add -A; git commit -qm add >/dev/null )
jget() { python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$1'))"; }

# ── absent key → enforced:false, no findings (v4/pre-v5 legacy-safe) ─────────
printf -- '---\nid: U-1\n---\n# u\n' > "$R/u/absent.md"
OUT="$(bash "$SC" --unit "$R/u/absent.md" --base HEAD~1 --head HEAD --cwd "$R" 2>&1)"; E=$?
[ "$(echo "$OUT" | jget enforced)" = "False" ] && ok "absent key -> enforced:false" || bad "absent not no-op: $OUT"
[ "$(echo "$OUT" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["unauthorized"]))')" = "0" ] && ok "absent key -> zero findings" || bad "absent produced findings"
[ "$E" -eq 0 ] && ok "absent key -> exit 0" || bad "absent exit $E"

# ── empty [] → nothing sanctioned → both added flagged ──────────────────────
printf -- '---\nid: U-1\nallowed_new_deps: []\n---\n# u\n' > "$R/u/empty.md"
OUT="$(bash "$SC" --unit "$R/u/empty.md" --base HEAD~1 --head HEAD --cwd "$R" 2>&1)"
[ "$(echo "$OUT" | jget finding)" = "dep_unauthorized" ] && ok "empty [] -> dep_unauthorized finding" || bad "empty missed finding: $OUT"
echo "$OUT" | python3 -c 'import json,sys;u=[e["package"] for e in json.load(sys.stdin)["unauthorized"]];sys.exit(0 if sorted(u)==["axios","fakepkg9zz"] else 1)' \
  && ok "empty [] -> both added deps flagged" || bad "empty wrong flags"

# ── inline allowlist [axios] → only fakepkg flagged ─────────────────────────
printf -- '---\nid: U-1\nallowed_new_deps: [axios]\n---\n# u\n' > "$R/u/inline.md"
OUT="$(bash "$SC" --unit "$R/u/inline.md" --base HEAD~1 --head HEAD --cwd "$R" 2>&1)"
echo "$OUT" | python3 -c 'import json,sys;u=[e["package"] for e in json.load(sys.stdin)["unauthorized"]];sys.exit(0 if u==["fakepkg9zz"] else 1)' \
  && ok "inline [axios] -> only unlisted flagged" || bad "inline allowlist wrong: $OUT"

# ── block-list YAML form (multi-line) → both listed → clean ─────────────────
printf -- '---\nid: U-1\nallowed_new_deps:\n  - axios\n  - fakepkg9zz\n---\n# u\n' > "$R/u/block.md"
OUT="$(bash "$SC" --unit "$R/u/block.md" --base HEAD~1 --head HEAD --cwd "$R" 2>&1)"
[ "$(echo "$OUT" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["unauthorized"]))')" = "0" ] \
  && ok "block-list form parsed; all sanctioned -> clean" || bad "block-list parse failed: $OUT"
[ "$(echo "$OUT" | jget enforced)" = "True" ] && ok "block-list -> enforced:true" || bad "block-list not enforced"

# ── advisory-first: unauthorized STILL exits 0 + carries Indonesian keterangan ─
OUT="$(bash "$SC" --unit "$R/u/empty.md" --base HEAD~1 --head HEAD --cwd "$R" 2>&1)"; E=$?
[ "$E" -eq 0 ] && ok "unauthorized finding STILL exits 0 (advisory-first, never blocks)" || bad "advisory exit $E"
echo "$OUT" | grep -qiE "tidak diotorisasi|over-engineering|scope creep" && ok "keterangan present (Indonesian, per interaction contract)" || bad "keterangan missing"

# ── no new deps at all → clean even when enforced ───────────────────────────
( cd "$R"; git commit -q --allow-empty -m noop >/dev/null )
OUT="$(bash "$SC" --unit "$R/u/empty.md" --base HEAD~1 --head HEAD --cwd "$R" 2>&1)"
[ "$(echo "$OUT" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["added_deps"]))')" = "0" ] \
  && ok "no manifest change -> zero added_deps -> clean" || bad "phantom added deps: $OUT"

# ── shared lib is multi-ecosystem (python requirements.txt) ─────────────────
R2="$WORK/py"; mkdir -p "$R2"
( cd "$R2"; git init -q; git config user.email t@t; git config user.name t
  printf 'flask\n' > requirements.txt; git add -A; git commit -qm base >/dev/null
  printf 'flask\nrequests\n' > requirements.txt; git add -A; git commit -qm add >/dev/null )
OUT="$(cd "$R2" && VND_LIB="$LIB" python3 -c 'import os,sys;sys.path.insert(0,os.environ["VND_LIB"]);from dep_manifest import added_deps;import json;print(json.dumps(added_deps("HEAD~1","HEAD")))')"
echo "$OUT" | python3 -c 'import json,sys;a=[e["package"] for e in json.load(sys.stdin)];sys.exit(0 if a==["requests"] else 1)' \
  && ok "shared lib: python requirements.txt diff (added=requests)" || bad "lib multi-ecosystem wrong: $OUT"

# ── usage guard is non-blocking (advisory posture) ──────────────────────────
bash "$SC" >/dev/null 2>&1; [ $? -eq 0 ] && ok "missing args -> advisory usage, exit 0 (never blocks a bolt)" || bad "usage should exit 0"

echo "== test-dep-authorization: $([ $rc -eq 0 ] && echo ALL-PASS || echo HAS-FAIL) =="
exit $rc
