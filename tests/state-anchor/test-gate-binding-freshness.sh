#!/usr/bin/env bash
# State anchor — the per-unit freshness check `_lib/freshness.gate_check` (spec
# docs/superpowers/specs/2026-09-25-state-anchor-design.md §8, §13): the function the
# run-start quarantine calls (derive-exec-plan.sh); the in-run hook leg that also called it
# left with the per-dispatch path (P3, spec 2026-09-27 §8.6). Drives gate_check directly on
# a lite fixture whose binding the REAL writer produced (derive-unit-claims.sh +
# write-unit-binding.sh): every §8 reason is returned, a raise quarantines `not_evaluated`,
# the fresh paths stay open, the Write/Bash guards on the capture and the binding deny, and the
# Skill-entry aggregator's utf-8 guard holds under a cp1252 console.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN="$REPO/plugins/mega-sdd"
HOOK="$PLUGIN/hooks/pre-tool-use"
S="$PLUGIN/scripts"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export PYTHONDONTWRITEBYTECODE=1 GIT_CONFIG_NOSYSTEM=1 HOME="$WORK/home"
mkdir -p "$HOME"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
has() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }
G() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
FIELD_MSG() { printf '%s\n\nUnit: %s\nSDD-PROVENANCE: mega-sdd/execute-bolts unit=%s\nSDD-Acceptance: v5\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' "$2" "$1" "$1"; }

mk() { # <dir> — lite vault, U-001 bound by the real writer at HEAD, a built prompt
  local F="$1" V="$1/.mega-sdd/vaults/web"
  mkdir -p "$F/src" "$V/units" "$F/.mega-sdd"
  printf 'lane: lite\n' > "$F/.mega-sdd/config.yaml"
  printf 'export const a = 1\nexport function api() {}\nexport const c = 3\n' > "$F/src/client.ts"
  printf 'export function Login() {}\n' > "$F/src/Login.tsx"
  printf 'readme\n' > "$F/README.md"
  cat > "$V/units/U-001.md" <<'U'
---
id: U-001
title: login
task_type: extend
target_files:
  - path: src/Login.tsx
    operation: modify
acceptance_test:
  - type: test
    command: npm test
    expects: "ok"
---
# U-001

## Anchors
- `src/client.ts:1-3` — the `api` client
U
  ( cd "$F" && git init -q -b main . && G add -A && G commit -qm seed )
  bind "$F"
}
bind() { # <dir> [extra writer flag]
  local F="$1" V="$1/.mega-sdd/vaults/web"
  bash "$S/derive-unit-claims.sh" --cwd="$F" --vault="$V" --units=U-001 >/dev/null 2>&1
  bash "$S/write-unit-binding.sh" --cwd="$F" --vault="$V" --unit=U-001 --claims="$V/bolts/U-001/_claims.json" ${2:-} >/dev/null 2>&1
}
gate() { # <dir> [unit] — gate_check's verdict: "" = fresh, else "<reason> <detail json>" (any raise → not_evaluated)
  python3 - "$PLUGIN/scripts/_lib" "$1" "${2:-U-001}" <<'PY'
import json, os, sys
sys.path.insert(0, sys.argv[1])
import freshness as fr
root = sys.argv[2]
try:
    r, d = fr.gate_check(root, os.path.join(root, ".mega-sdd", "vaults", "web"), sys.argv[3])
except fr.GitError as e:
    r, d = "not_evaluated", {"error": str(e)}
except Exception as e:  # mirrors derive-exec-plan.sh: a crash is not_evaluated, never an empty (fresh) verdict
    r, d = "not_evaluated", {"error": "%s: %s" % (type(e).__name__, e)}
print("%s %s" % (r, json.dumps(d, sort_keys=True)) if r else "")
PY
}
deny_of() { case "$1" in *'"permissionDecision": "deny"'*) return 0 ;; esac; return 1; }
BASE="$WORK/base"; mk "$BASE"
fresh() { rm -rf "$WORK/$1"; cp -a "$BASE" "$WORK/$1"; printf '%s' "$WORK/$1"; }

# 0. the real writer produced an honest v2 binding at HEAD
python3 - "$BASE/.mega-sdd/vaults/web/bolts/U-001/binding.json" "$(git -C "$BASE" rev-parse HEAD)" <<'PY' \
  && ok "writer: unit-binding/2, based_on_sha = HEAD, scope + own_targets + dirty + unit_sha256 recorded" || bad "writer output"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["schema"] == "unit-binding/2" and d["based_on_sha"] == sys.argv[2], d
assert "src/client.ts" in d["scope"] and d["own_targets"] == ["src/Login.tsx"] and d["dirty"] == {} and len(d["unit_sha256"]) == 64, d
PY

# 1. fresh: fresh binding, nothing moved
D=$(fresh a); O=$(gate "$D"); [ -z "$O" ] && ok "fresh binding at HEAD: fresh" || bad "fresh: [$O]"

# 2. fresh: a commit outside the unit scope
D=$(fresh b); ( cd "$D" && echo x >> README.md && G commit -qam "docs: readme" )
O=$(gate "$D"); [ -z "$O" ] && ok "commit outside scope: fresh" || bad "outside: [$O]"

# 3. binding_stale: a teammate commit to the anchored file after the bind
D=$(fresh c); ( cd "$D" && echo 'export const d = 4' >> src/client.ts && G commit -qam "feat(web): client d" )
O=$(gate "$D")
has "$O" "binding_stale" && has "$O" "src/client.ts" && has "$O" "feat(web): client d" \
  && ok "teammate commit in scope after the bind: binding_stale, path + commit named" || bad "stale: [$O]"

# 4. fresh: the fix round after the unit's OWN bolt commit (field layout + a sanctioned test file)
D=$(fresh d); mkdir -p "$D/src/__tests__"
( cd "$D" && echo '// impl' >> src/Login.tsx && echo t > src/__tests__/Login.test.tsx && G add -A \
  && G commit -q -F <(FIELD_MSG U-001 "feat(U-001): login") )
O=$(gate "$D"); [ -z "$O" ] && ok "fix round after its own bolt commit (field layout): fresh, no re-bind" || bad "own bolt: [$O]"

# 5. binding_legacy: a pre-Slice-2 binding
D=$(fresh e); B="$D/.mega-sdd/vaults/web/bolts/U-001/binding.json"
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));d["schema"]="unit-binding/1";json.dump(d,open(sys.argv[1],"w"))' "$B"
O=$(gate "$D"); has "$O" "binding_legacy" && ok "unit-binding/1: binding_legacy (one-time on upgrade)" || bad "legacy: [$O]"

# 7. unit_changed_since_bind
D=$(fresh g); echo "- extra note" >> "$D/.mega-sdd/vaults/web/units/U-001.md"
O=$(gate "$D"); has "$O" "unit_changed_since_bind" && ok "unit file edited after bind: unit_changed_since_bind" || bad "unit changed: [$O]"

# 8. uncommitted_in_scope
D=$(fresh h); echo '// wip' >> "$D/src/client.ts"
O=$(gate "$D"); has "$O" "uncommitted_in_scope" && has "$O" "src/client.ts" \
  && ok "uncommitted in-scope edit: uncommitted_in_scope, path named" || bad "dirty: [$O]"

# 9. fresh: a bind over unchanged dirt (the snapshot equals the tree), incl. an assume-unchanged scope file
D=$(fresh i); echo '// wip' >> "$D/src/client.ts"; ( cd "$D" && git update-index --assume-unchanged src/Login.tsx && echo '// au' >> src/Login.tsx )
bind "$D"; O=$(gate "$D"); [ -z "$O" ] && ok "bind over unchanged dirt (incl. assume-unchanged): fresh (one dirty_map everywhere)" || bad "same dirt: [$O]"

# 10. stamp_null (a capture that moved) — the null cause is named
D=$(fresh j); B="$D/.mega-sdd/vaults/web/bolts/U-001/binding.json"
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));d["based_on_sha"]=None;d["null_cause"]="writer_capture_moved";json.dump(d,open(sys.argv[1],"w"))' "$B"
O=$(gate "$D"); has "$O" "stamp_null" && has "$O" "writer_capture_moved" \
  && ok "null stamp: stamp_null with its null_cause" || bad "null: [$O]"

# 11. rebind_exhausted: a per-unit re-bind at this HEAD did not clear it
D=$(fresh k); echo '// wip' >> "$D/src/client.ts"; bind "$D" --rebind; echo '// more' >> "$D/src/client.ts"
O=$(gate "$D"); has "$O" "rebind_exhausted" && has "$O" '"cause": "uncommitted_in_scope"' \
  && ok "still stale after a re-bind at the same HEAD: rebind_exhausted, cause named (the bound is a mechanism)" || bad "exhausted: [$O]"

# 14. encoding: an emoji subject + a CJK path is still binding_stale (never a crash)
D=$(fresh n); mkdir -p "$D/src"; printf 'x\n' > "$D/src/測試.ts"
sed -i.bak 's#^- `src/client.ts:1-3` — the `api` client#- `src/client.ts:1-3` — the `api` client\n- `src/測試.ts:1` — cjk#' "$D/.mega-sdd/vaults/web/units/U-001.md"; rm -f "$D/.mega-sdd/vaults/web/units/U-001.md.bak"
( cd "$D" && G add -A && G commit -qm unit ) ; bind "$D"
( cd "$D" && echo 'y' >> "src/測試.ts" && G commit -qam "feat: 🚀 ship it" )
O=$(gate "$D")
has "$O" "binding_stale" && ok "emoji subject + CJK path: still binding_stale" || bad "cjk/emoji: [$O]"

# 14b. D24a, the hook's utf-8 guard on the Skill-entry aggregator: a FAIL whose deny text carries a
#      non-cp1252 character, under PYTHONIOENCODING=cp1252, still denies (never crashes into an ALLOW).
#      The state is read-only so the gate-time re-scan cannot rewrite it.
D=$(fresh n2); M="$D/.mega-sdd"
printf '{"status":"FAIL","issues":[{"unit_id":"U-001","reason":"open_conflict 測試"}]}\n' > "$M/.bolt-conflict-bypass-state.json"
chmod 444 "$M/.bolt-conflict-bypass-state.json"; chmod 555 "$M"
O=$(printf '{"session_id":"s","cwd":"%s","tool_name":"Skill","tool_input":{"skill":"mega-sdd:execute-bolts","args":"--all --lite"}}' "$D" \
  | ( cd "$D" && PYTHONIOENCODING=cp1252 bash "$HOOK" 2>/dev/null ))
chmod 755 "$M"; chmod 644 "$M/.bolt-conflict-bypass-state.json"
deny_of "$O" && has "$O" "conflict-bypass" \
  && ok "Skill entry under PYTHONIOENCODING=cp1252, CJK in the deny text: still denied (conflict-bypass named)" || bad "hook cp1252: [${O:0:300}]"

# 15. fail closed: gate_check raises → the run-start quarantine records `freshness: not_evaluated`
PL="$WORK/plug"; mkdir -p "$PL"; cp -a "$PLUGIN/." "$PL/"
python3 - "$PL/scripts/_lib/freshness.py" <<'PY'
import sys; p = sys.argv[1]; t = open(p).read()
t = t.replace("def gate_check(root, vault_dir, uid, prompt_path=None):", "def gate_check(root, vault_dir, uid, prompt_path=None):\n    raise ValueError(\"boom\")", 1)
open(p, "w").write(t)
PY
D=$(fresh o)
O=$(bash "$PL/scripts/derive-exec-plan.sh" --cwd="$D" --vault="$D/.mega-sdd/vaults/web" 2>/dev/null)
python3 -c 'import json,sys;d=json.loads(sys.argv[1]);assert d["in_scope"]==[] and d["quarantined"]==[{"unit":"U-001","reason":"binding_stale","freshness":"not_evaluated"}],d' "$O" 2>/dev/null \
  && ok "gate_check raises: derive-exec-plan quarantines U-001 (binding_stale, freshness: not_evaluated), never a pass" || bad "raise: [$O]"
D=$(fresh o2); O=$(bash "$S/derive-exec-plan.sh" --cwd="$D" --vault="$D/.mega-sdd/vaults/web" 2>/dev/null)
python3 -c 'import json,sys;d=json.loads(sys.argv[1]);assert d["in_scope"]==["U-001"] and d["quarantined"]==[],d' "$O" 2>/dev/null \
  && ok "…control: the real gate_check on the same fixture leaves U-001 in scope" || bad "raise control: [$O]"

# 16. git failure (rc 128 on ancestry) → GitError → not_evaluated
D=$(fresh p); ( cd "$D" && echo x >> README.md && G commit -qam r )
SH2="$WORK/g128"; mkdir -p "$SH2"; RG=$(command -v git)
printf '#!/bin/bash\ncase "$*" in *merge-base*--is-ancestor*) echo "fatal: detected dubious ownership" >&2; exit 128 ;; esac\nexec "%s" "$@"\n' "$RG" > "$SH2/git"; chmod +x "$SH2/git"
O=$(PATH="$SH2:$PATH"; gate "$D"); has "$O" "not_evaluated" && ok "git rc 128 on ancestry: GitError → not_evaluated" || bad "not_evaluated: [$O]"

# 18. the D27 guard: Write/Edit of the capture or the built prompt is denied
D=$(fresh r)
for f in ".mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md" ".mega-sdd/vaults/web/bolts/U-001/_claims.json"; do
  O=$(printf '{"session_id":"s","cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s/%s","content":"x"}}' "$D" "$D" "$f" | ( cd "$D" && bash "$HOOK" 2>/dev/null ))
  deny_of "$O" || bad "Write $f was allowed"
done
[ "$fail" -eq 0 ] && ok "Write/Edit of _claims.json / dispatch-prompt.md: denied (script-written, gate-read)"

# 20. binding_absent / binding_unparseable / diverged / per-unit stamp_unreachable
D=$(fresh s); rm -f "$D/.mega-sdd/vaults/web/bolts/U-001/binding.json"
O=$(gate "$D"); has "$O" "binding_absent" && ok "lite unit with its binding deleted: binding_absent" || bad "absent: [$O]"
D=$(fresh t); echo "{not json" > "$D/.mega-sdd/vaults/web/bolts/U-001/binding.json"
O=$(gate "$D"); has "$O" "binding_unparseable" && ok "unparseable binding: binding_unparseable" || bad "unparseable: [$O]"
D=$(fresh u); ( cd "$D" && G checkout -q -b side && echo s >> README.md && G commit -qam side && G checkout -q main )
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));d["based_on_sha"]=sys.argv[2];json.dump(d,open(sys.argv[1],"w"))' "$D/.mega-sdd/vaults/web/bolts/U-001/binding.json" "$(git -C "$D" rev-parse side)"
O=$(gate "$D"); has "$O" "diverged" && ok "stamp on a branch HEAD does not descend from: diverged" || bad "diverged: [$O]"
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));d["based_on_sha"]="0123456789abcdef0123456789abcdef01234567";json.dump(d,open(sys.argv[1],"w"))' "$D/.mega-sdd/vaults/web/bolts/U-001/binding.json"
O=$(gate "$D"); has "$O" "stamp_unreachable" && ok "per-unit stamp object gone: stamp_unreachable" || bad "unreachable: [$O]"

# 22. a project path with a SPACE: fresh, and a teammate commit there is still binding_stale
SP="$WORK/My Projects"; mkdir -p "$SP"; cp -a "$BASE" "$SP/app"
O=$(gate "$SP/app"); [ -z "$O" ] && ok "project path with a space: fresh" || bad "space path: [$O]"
( cd "$SP/app" && echo 'export const q = 9' >> src/client.ts && G commit -qam "feat(web): q" )
O=$(gate "$SP/app"); has "$O" "binding_stale" && ok "…and a teammate commit there is still binding_stale" || bad "space stale: [$O]"

# 23. glob-declared create target: a teammate file under it is STALE, uncommitted is dirt
D=$(fresh w); V="$D/.mega-sdd/vaults/web"
cat > "$V/units/U-001.md" <<'U'
---
id: U-001
title: login
target_files:
  - path: src/login/*.tsx
    operation: create
acceptance_test:
  - type: test
    command: npm test
    expects: "ok"
---
U
( cd "$D" && G add -A && G commit -qm glob ); bind "$D"
O=$(gate "$D"); [ -z "$O" ] && ok "glob create target, fresh bind: fresh" || bad "glob fresh: [$O]"
mkdir -p "$D/src/login"; echo x > "$D/src/login/Wip.tsx"
O=$(gate "$D"); has "$O" "uncommitted_in_scope" && has "$O" "src/login/Wip.tsx" && ok "uncommitted file under a glob target: uncommitted_in_scope" || bad "glob dirt: [$O]"
( cd "$D" && G add -A && G commit -qm "feat(web): teammate form" )
O=$(gate "$D"); has "$O" "binding_stale" && has "$O" "src/login/Wip.tsx" && ok "teammate commit under a glob target: binding_stale" || bad "glob stale: [$O]"

# 25. the E3 --verdicts pass of a 3.9b keeps rebind_head (the bound survives text claims)
D=$(fresh y); V="$D/.mega-sdd/vaults/web"
printf '\n## Claims\n- C-U001-01 "the api client returns one role" — expect: api role claim shape\n' >> "$V/units/U-001.md"
( cd "$D" && G add -A && G commit -qm claims ); bind "$D"
echo '// wip' >> "$D/src/client.ts"
bash "$S/rebind-units.sh" --cwd="$D" --vault="$V" --units=U-001 >/dev/null 2>&1
printf '{"C-U001-01":{"verdict":"CONFIRMED","anchor":"src/client.ts:2","confidence":"high","evidence":"read"}}\n' > "$WORK/v.json"
bash "$S/write-unit-binding.sh" --cwd="$D" --vault="$V" --unit=U-001 --claims="$V/bolts/U-001/_claims.json" --verdicts="$WORK/v.json" >/dev/null 2>&1
echo '// more' >> "$D/src/client.ts"
O=$(gate "$D"); has "$O" "rebind_exhausted" && ok "3.9b + its E3 pass, then new dirt at the same HEAD: rebind_exhausted" || bad "E3 bound: [$O]"

# 26. §13: common programmatic writes to binding.json are denied by the Bash guard; a read is not
D=$(fresh z1); BJ=".mega-sdd/vaults/web/bolts/U-001/binding.json"
bash_call() { # <dir> <command> — hook stdout for a Bash tool call
  python3 -c 'import json,sys;print(json.dumps({"session_id":"s","cwd":sys.argv[1],"tool_name":"Bash","tool_input":{"command":sys.argv[2]}}))' "$1" "$2" \
    | ( cd "$1" && bash "$HOOK" 2>/dev/null )
}
for c in "python3 -c \"open('$BJ','w').write('{}')\"" "sed -i.bak 's/a/b/' $BJ" "cp /tmp/forged.json $BJ" \
         "mv /tmp/forged.json $BJ" "echo '{}' | tee $BJ" "echo '{}' > $BJ"; do
  deny_of "$(bash_call "$D" "$c")" || bad "Bash write of binding.json allowed: $c"
done
deny_of "$(bash_call "$D" "cat $BJ")" && bad "cat of binding.json denied (a read must stay open)"
[ "$fail" -eq 0 ] && ok "Bash python open-write / sed -i / cp / mv / tee / redirect into binding.json: denied; cat stays open"

# 27. skip-worktree and gitignored exact scope files present at bind → fresh after the bind;
#     a later change to the ignored one is still dirt (it is watched, not skipped)
D=$(fresh z2); V="$D/.mega-sdd/vaults/web"
python3 - "$V/units/U-001.md" <<'PY'
import sys; p = sys.argv[1]; s = open(p).read()   # an exact scope path: a gitignored modify target
open(p, "w").write(s.replace("    operation: modify\n", "    operation: modify\n  - path: src/local.config.ts\n    operation: modify\n", 1))
PY
printf 'src/local.config.ts\n' > "$D/.gitignore"; ( cd "$D" && G add -A && G commit -qm "units: local config" )
echo 'export const k = 1' > "$D/src/local.config.ts"
( cd "$D" && git update-index --skip-worktree src/Login.tsx && echo '// sw' >> src/Login.tsx )
bind "$D"; O=$(gate "$D")
[ -z "$O" ] && ok "skip-worktree + gitignored exact scope files present at bind: fresh after the bind" || bad "sw/ignored: [$O]"
echo 'export const k = 2' > "$D/src/local.config.ts"
O=$(gate "$D"); has "$O" "uncommitted_in_scope" && has "$O" "src/local.config.ts" \
  && ok "…a later change to the gitignored scope file: uncommitted_in_scope" || bad "ignored change: [$O]"

# 28. the Fase-0 C2 edit (+5 lines above the anchor) STAGED after the bind: uncommitted_in_scope
D=$(fresh z3); python3 -c 'import sys;p=sys.argv[1];s=open(p).read();open(p,"w").write("// a\n// b\n// c\n// d\n// e\n"+s)' "$D/src/client.ts"
( cd "$D" && G add src/client.ts )
O=$(gate "$D"); has "$O" "uncommitted_in_scope" && has "$O" "src/client.ts" \
  && ok "C2 staged after the bind (+5 lines above the anchor): uncommitted_in_scope" || bad "C2 staged: [$O]"

# 29. dirt OUTSIDE the unit scope: fresh, and a bind over it keeps an honest (non-null) stamp
D=$(fresh z4); echo '// sibling wip' >> "$D/README.md"
O=$(gate "$D"); [ -z "$O" ] && ok "uncommitted edit outside the unit scope: fresh" || bad "outside dirt: [$O]"
bind "$D"; O=$(gate "$D")
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));assert d["based_on_sha"]==sys.argv[2] and not d.get("null_cause"),d' \
  "$D/.mega-sdd/vaults/web/bolts/U-001/binding.json" "$(git -C "$D" rev-parse HEAD)" 2>/dev/null && [ -z "$O" ] \
  && ok "a sibling's dirt outside this unit's scope does not null the stamp (bind → fresh)" || bad "outside dirt bind: [$O]"

# 30. two waves: wave 1's own bolt commit moves a symbol in wave 2's scope after the run's index build.
#     Index first (per bind) → U-002 is fresh with NO re-bind. The control arm
#     (no index rebuild) shows the index really was stale: the honest writer nulls the stamp.
D=$(fresh z5); V="$D/.mega-sdd/vaults/web"
python3 - "$V/units/U-001.md" <<'PY'
import sys; p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace("    operation: modify\n", "    operation: modify\n  - path: src/client.ts\n    operation: modify\n", 1))
PY
cat > "$V/units/U-002.md" <<'U'
---
id: U-002
title: profile
target_files:
  - path: src/Profile.tsx
    operation: create
existing_interfaces:
  - file: src/client.ts
    symbol: api
acceptance_test:
  - type: test
    command: npm test
    expects: "ok"
---
U
( cd "$D" && G add -A && G commit -qm "units: wave 2" )
bash "$S/build-symbol-index.sh" --cwd="$D" >/dev/null 2>&1; AG=$?          # step 5: once per run
bind "$D"                                                                    # wave 1: U-001
( cd "$D" && python3 -c 'import sys;p=sys.argv[1];s=open(p).read();open(p,"w").write("// v2 header\n"+s)' src/client.ts \
  && G add -A && G commit -q -F <(FIELD_MSG U-001 "feat(U-001): client header") )
bind2() { # wave 2: derive + write for U-002
  bash "$S/derive-unit-claims.sh" --cwd="$1" --vault="$1/.mega-sdd/vaults/web" --units=U-002 >/dev/null 2>&1
  bash "$S/write-unit-binding.sh" --cwd="$1" --vault="$1/.mega-sdd/vaults/web" --unit=U-002 --claims="$1/.mega-sdd/vaults/web/bolts/U-002/_claims.json" >/dev/null 2>&1
}
if [ "$AG" -eq 0 ]; then
  rm -rf "$WORK/z5c"; cp -a "$D" "$WORK/z5c"; bind2 "$WORK/z5c"
  O=$(gate "$WORK/z5c" U-002)
  has "$O" "stamp_null" && has "$O" "index_stale" \
    && ok "two waves, control (no index rebuild): the run's index is stale → stamp_null (index_stale)" || bad "two-wave control: [$O]"
  bash "$S/build-symbol-index.sh" --cwd="$D" >/dev/null 2>&1                 # index first
else
  ok "ast-grep not installed here: the two-wave index_stale control arm is skipped (symbol claims stay OQ)"
fi
bind2 "$D"
O=$(gate "$D" U-002)
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));assert d["based_on_sha"]==sys.argv[2] and not d.get("rebind_head"),d' \
  "$V/bolts/U-002/binding.json" "$(git -C "$D" rev-parse HEAD)" 2>/dev/null && [ -z "$O" ] \
  && ok "two waves: wave 1 commits into wave 2's scope → index first + bind → U-002 fresh with no re-bind" || bad "two-wave: [$O]"

[ "$fail" -eq 0 ] && { echo "PASS state-anchor gate binding-freshness"; exit 0; }
echo "state-anchor gate binding-freshness FAILED"; exit 1
