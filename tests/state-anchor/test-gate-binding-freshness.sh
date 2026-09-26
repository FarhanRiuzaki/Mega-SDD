#!/usr/bin/env bash
# State anchor — the BOLTS gate leg `binding-freshness` (spec
# docs/superpowers/specs/2026-09-25-state-anchor-design.md §8, §13). Drives the REAL
# hooks/pre-tool-use with a bolt-implementer Agent dispatch on a lite fixture whose
# binding the REAL writer produced (derive-unit-claims.sh + write-unit-binding.sh):
# every §8 reason denies, fail-closed paths deny, the ALLOW paths stay open, and a
# deny never spends an attempt. The controller's HOLD / quarantine remedies are prose;
# what is pinned here is the deny and its remedy text.
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
  bash "$S/write-unit-binding.sh" --cwd="$F" --vault="$V" --unit=U-001 --claims="$V/bolts/_wave-claims.json" ${2:-} >/dev/null 2>&1
  mkprompt "$F"
}
mkprompt() { # a prompt carrying the binding's sha256 (what build-dispatch-prompt.sh stamps)
  local B="$1/.mega-sdd/vaults/web/bolts/U-001"
  mkdir -p "$B"
  printf 'mega-sdd-trace:execute-bolts:U-001\nProvenance values:\n  unit_id: U-001\n  binding_sha256: %s\n' \
    "$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$B/binding.json")" > "$B/dispatch-prompt.md"
}
dispatch() { # <dir> [prompt text] — hook stdout ("" = ALLOW)
  local F="$1" P="${2:-}"
  [ -n "$P" ] || P="mega-sdd-trace:execute-bolts:U-001\\nUNIT: U-001 \\\"login\\\"\\nREAD FIRST, IN FULL: $F/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md"
  printf '{"session_id":"sess-gate-0001","cwd":"%s","tool_name":"Agent","tool_input":{"subagent_type":"mega-sdd:bolt-implementer","description":"bolt","prompt":"%s"}}' "$F" "$P" \
    | ( cd "$F" && bash "$HOOK" 2>/dev/null )
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

# 1. ALLOW: fresh binding, built prompt, nothing moved
D=$(fresh a); O=$(dispatch "$D"); [ -z "$O" ] && ok "fresh binding at HEAD: ALLOW" || bad "fresh: [$O]"

# 2. ALLOW: a commit outside the unit scope
D=$(fresh b); ( cd "$D" && echo x >> README.md && G commit -qam "docs: readme" )
O=$(dispatch "$D"); [ -z "$O" ] && ok "commit outside scope: ALLOW" || bad "outside: [$O]"

# 3. DENY binding_stale: a teammate commit to the anchored file after the bind
D=$(fresh c); ( cd "$D" && echo 'export const d = 4' >> src/client.ts && G commit -qam "feat(web): client d" )
O=$(dispatch "$D")
deny_of "$O" && has "$O" "binding_stale" && has "$O" "src/client.ts" && has "$O" "rebind-units.sh" && has "$O" "--units=U-001" \
  && ok "teammate commit in scope after 3.9: DENY binding_stale, path + 3.9b remedy named" || bad "stale: [$O]"

# 4. ALLOW: the fix round after the unit's OWN bolt commit (field layout + a sanctioned test file)
D=$(fresh d); mkdir -p "$D/src/__tests__"
( cd "$D" && echo '// impl' >> src/Login.tsx && echo t > src/__tests__/Login.test.tsx && G add -A \
  && G commit -q -F <(FIELD_MSG U-001 "feat(U-001): login") )
O=$(dispatch "$D"); [ -z "$O" ] && ok "fix round after its own bolt commit (field layout): ALLOW, no re-bind" || bad "own bolt: [$O]"

# 5. DENY binding_legacy: a pre-Slice-2 binding
D=$(fresh e); B="$D/.mega-sdd/vaults/web/bolts/U-001/binding.json"
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));d["schema"]="unit-binding/1";json.dump(d,open(sys.argv[1],"w"))' "$B"; mkprompt "$D"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "binding_legacy" && ok "unit-binding/1: DENY binding_legacy (one-time on upgrade)" || bad "legacy: [$O]"

# 6. DENY dispatch_prompt_stale: the binding changed after the prompt was built
D=$(fresh f); printf '  binding_sha256: %064d\n' 0 >> "$D/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md"
sed -i.bak '/binding_sha256: [0-9a-f]\{64\}$/{x;s/.*//;x;}' "$D/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md" 2>/dev/null
printf 'mega-sdd-trace:execute-bolts:U-001\n  binding_sha256: %064d\n' 0 > "$D/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "dispatch_prompt_stale" && has "$O" "build-dispatch-prompt.sh" \
  && ok "prompt built from another binding: DENY dispatch_prompt_stale → rebuild the prompt" || bad "prompt stale: [$O]"

# 7. DENY unit_changed_since_bind
D=$(fresh g); echo "- extra note" >> "$D/.mega-sdd/vaults/web/units/U-001.md"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "unit_changed_since_bind" && ok "unit file edited after bind: DENY unit_changed_since_bind" || bad "unit changed: [$O]"

# 8. DENY uncommitted_in_scope — and the remedy never tells the controller to stash
D=$(fresh h); echo '// wip' >> "$D/src/client.ts"
O=$(dispatch "$D")
deny_of "$O" && has "$O" "uncommitted_in_scope" && has "$O" "NEVER git stash" && has "$O" "HOLD" && has "$O" "--halt=binding_stale" \
  && ok "uncommitted in-scope edit: DENY uncommitted_in_scope; remedy = HOLD / quarantine, never stash" || bad "dirty: [$O]"

# 9. ALLOW: a bind over unchanged dirt (the snapshot equals the tree), incl. an assume-unchanged scope file
D=$(fresh i); echo '// wip' >> "$D/src/client.ts"; ( cd "$D" && git update-index --assume-unchanged src/Login.tsx && echo '// au' >> src/Login.tsx )
bind "$D"; O=$(dispatch "$D"); [ -z "$O" ] && ok "bind over unchanged dirt (incl. assume-unchanged): ALLOW (one dirty_map everywhere)" || bad "same dirt: [$O]"

# 10. DENY stamp_null (a capture that moved) — the null cause is named
D=$(fresh j); B="$D/.mega-sdd/vaults/web/bolts/U-001/binding.json"
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));d["based_on_sha"]=None;d["null_cause"]="writer_capture_moved";json.dump(d,open(sys.argv[1],"w"))' "$B"; mkprompt "$D"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "stamp_null" && has "$O" "writer_capture_moved" && has "$O" "HOLD" \
  && ok "null stamp: DENY stamp_null with its null_cause and the HOLD remedy" || bad "null: [$O]"

# 11. DENY rebind_exhausted: a 3.9b re-bind at this HEAD did not clear it
D=$(fresh k); echo '// wip' >> "$D/src/client.ts"; bind "$D" --rebind; echo '// more' >> "$D/src/client.ts"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "rebind_exhausted" && has "$O" "write-unit-quarantine.sh" && has "$O" "never a second 3.9b" \
  && ok "still failing after a 3.9b at the same HEAD: DENY rebind_exhausted → quarantine (the bound is a mechanism)" || bad "exhausted: [$O]"

# 12. identity: disagreeing markers, a foreign pointer, a hand-typed inline prompt
D=$(fresh l)
O=$(dispatch "$D" "mega-sdd-trace:execute-bolts:U-001\\nUNIT: U-002\\nREAD FIRST, IN FULL: $D/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md")
deny_of "$O" && has "$O" "unit_identity_conflict" && ok "pointer U-001 vs UNIT: U-002: DENY unit_identity_conflict" || bad "conflict: [$O]"
mkdir -p "$WORK/else/bolts/U-001"; cp "$D/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md" "$WORK/else/bolts/U-001/"
O=$(dispatch "$D" "mega-sdd-trace:execute-bolts:U-001\\nREAD FIRST, IN FULL: $WORK/else/bolts/U-001/dispatch-prompt.md")
deny_of "$O" && has "$O" "unit_identity_foreign" && ok "pointer outside the project vaults: DENY unit_identity_foreign" || bad "foreign: [$O]"
O=$(dispatch "$D" "mega-sdd-trace:execute-bolts:U-001\\nUNIT: U-001\\nimplement the login form please")
deny_of "$O" && has "$O" "dispatch_prompt_missing" && ok "hand-typed inline prompt in a lite project: DENY dispatch_prompt_missing (D20a)" || bad "inline: [$O]"

# 13. symlinked project path → the realpath'd pointer still matches → ALLOW
D=$(fresh m); ln -s "$D" "$WORK/link"
O=$(dispatch "$WORK/link" "mega-sdd-trace:execute-bolts:U-001\\nREAD FIRST, IN FULL: $WORK/link/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md")
[ -z "$O" ] && ok "project reached through a symlink: ALLOW" || bad "symlink: [$O]"

# 14. encoding: an emoji subject + a CJK path under a cp1252 console still DENYs (never a crash-ALLOW)
D=$(fresh n); mkdir -p "$D/src"; printf 'x\n' > "$D/src/測試.ts"
sed -i.bak 's#^- `src/client.ts:1-3` — the `api` client#- `src/client.ts:1-3` — the `api` client\n- `src/測試.ts:1` — cjk#' "$D/.mega-sdd/vaults/web/units/U-001.md"; rm -f "$D/.mega-sdd/vaults/web/units/U-001.md.bak"
( cd "$D" && G add -A && G commit -qm unit ) ; bind "$D"
( cd "$D" && echo 'y' >> "src/測試.ts" && G commit -qam "feat: 🚀 ship it" )
O=$(printf '{"session_id":"sess-gate-0001","cwd":"%s","tool_name":"Agent","tool_input":{"subagent_type":"mega-sdd:bolt-implementer","prompt":"mega-sdd-trace:execute-bolts:U-001\\nREAD FIRST, IN FULL: %s/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md"}}' "$D" "$D" | ( cd "$D" && PYTHONIOENCODING=cp1252 bash "$HOOK" 2>/dev/null ))
deny_of "$O" && has "$O" "binding_stale" && ok "emoji subject + CJK path under PYTHONIOENCODING=cp1252: still DENY binding_stale" || bad "cp1252: [$O]"

# 15. fail closed: an exception inside the leg, and an aggregator crash
PL="$WORK/plug"; mkdir -p "$PL"; cp -a "$PLUGIN/." "$PL/"
python3 - "$PL/scripts/_lib/freshness.py" <<'PY'
import sys; p = sys.argv[1]; t = open(p).read()
t = t.replace("def gate_check(root, vault_dir, uid, prompt_path=None):", "def gate_check(root, vault_dir, uid, prompt_path=None):\n    raise ValueError(\"boom\")", 1)
open(p, "w").write(t)
PY
D=$(fresh o)
O=$(printf '{"session_id":"s","cwd":"%s","tool_name":"Agent","tool_input":{"subagent_type":"mega-sdd:bolt-implementer","prompt":"mega-sdd-trace:execute-bolts:U-001\\nREAD FIRST, IN FULL: %s/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md"}}' "$D" "$D" | ( cd "$D" && bash "$PL/hooks/pre-tool-use" 2>/dev/null ))
deny_of "$O" && has "$O" "freshness NOT evaluated (ValueError)" && ok "exception inside the leg: DENY 'freshness NOT evaluated'" || bad "leg exception: [$O]"
SH="$WORK/crash"; mkdir -p "$SH"; RP=$(command -v python3)
printf '#!/bin/bash\ncase "$*" in *binding-freshness*) exit 3 ;; esac\nexec "%s" "$@"\n' "$RP" > "$SH/python3"; chmod +x "$SH/python3"
O=$(printf '{"session_id":"s","cwd":"%s","tool_name":"Agent","tool_input":{"subagent_type":"mega-sdd:bolt-implementer","prompt":"mega-sdd-trace:execute-bolts:U-001\\nREAD FIRST, IN FULL: %s/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md"}}' "$D" "$D" | ( cd "$D" && PATH="$SH:$PATH" bash "$HOOK" 2>/dev/null ))
deny_of "$O" && has "$O" "gate NOT evaluated (aggregator exit 3)" && ok "aggregator interpreter crash on an in-run dispatch: DENY (D24a), not the old silent ALLOW" || bad "crash: [$O]"

# 16. git failure (rc 128 on ancestry) → not_evaluated human halt with the safe.directory keterangan
D=$(fresh p); ( cd "$D" && echo x >> README.md && G commit -qam r )
SH2="$WORK/g128"; mkdir -p "$SH2"; RG=$(command -v git)
printf '#!/bin/bash\ncase "$*" in *merge-base*--is-ancestor*) echo "fatal: detected dubious ownership" >&2; exit 128 ;; esac\nexec "%s" "$@"\n' "$RG" > "$SH2/git"; chmod +x "$SH2/git"
O=$(printf '{"session_id":"s","cwd":"%s","tool_name":"Agent","tool_input":{"subagent_type":"mega-sdd:bolt-implementer","prompt":"mega-sdd-trace:execute-bolts:U-001\\nREAD FIRST, IN FULL: %s/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md"}}' "$D" "$D" | ( cd "$D" && PATH="$SH2:$PATH" bash "$HOOK" 2>/dev/null ))
deny_of "$O" && has "$O" "not_evaluated" && has "$O" "safe.directory" && ok "git rc 128 on ancestry: DENY not_evaluated with the safe.directory remedy" || bad "not_evaluated: [$O]"

# 17. a deny spends no attempt (attempts.json untouched)
D=$(fresh q); B="$D/.mega-sdd/vaults/web/bolts/U-001"
printf '{"retry_budget":2,"retry_budget_source":"test"}\n' > "$B/review-tier.json"
( cd "$D" && echo 'z' >> src/client.ts && G commit -qam "feat(web): z" )
O=$(dispatch "$D"); deny_of "$O" && [ ! -f "$B/attempts.json" ] && ok "a binding-freshness deny spends no attempt" || bad "attempt spent: $(cat "$B/attempts.json" 2>/dev/null)"

# 18. the D27 guard: Write/Edit of the capture or the built prompt is denied
D=$(fresh r)
for f in ".mega-sdd/vaults/web/bolts/_wave-claims.json" ".mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md" ".mega-sdd/vaults/web/bolts/U-001/_claims.json"; do
  O=$(printf '{"session_id":"s","cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s/%s","content":"x"}}' "$D" "$D" "$f" | ( cd "$D" && bash "$HOOK" 2>/dev/null ))
  deny_of "$O" || bad "Write $f was allowed"
done
[ "$fail" -eq 0 ] && ok "Write/Edit of _wave-claims.json / _claims.json / dispatch-prompt.md: denied (script-written, gate-read)"

# 19. classic project (no per-unit binding): an unreachable SHA-shaped vault head denies; a reachable one does not
C="$WORK/classic"; CV="$C/.mega-sdd/vaults/api"; mkdir -p "$C/src" "$CV/units"
printf -- '---\nid: U-010\ntarget_files:\n  - path: src/svc.php\n    operation: modify\nacceptance_test:\n  - type: test\n    command: x\n    expects: "ok"\n---\n' > "$CV/units/U-010.md"
echo x > "$C/src/svc.php"; ( cd "$C" && git init -q -b main . && G add -A && G commit -qm seed )
printf '{"head":"%s","claims":[]}\n' "$(git -C "$C" rev-parse HEAD)" > "$CV/binding.json"; ( cd "$C" && G add -A && G commit -qm bind )
CP="mega-sdd-trace:execute-bolts:U-010\\nUNIT: U-010"
O=$(printf '{"session_id":"s","cwd":"%s","tool_name":"Agent","tool_input":{"subagent_type":"mega-sdd:bolt-implementer","prompt":"%s"}}' "$C" "$CP" | ( cd "$C" && bash "$HOOK" 2>/dev/null ))
has "$O" "binding-freshness" && bad "classic reachable head denied: [$O]" || ok "classic vault, reachable (older) head: the leg stays advisory"
printf '{"head":"0123456789abcdef0123456789abcdef01234567","claims":[]}\n' > "$CV/binding.json"
O=$(printf '{"session_id":"s","cwd":"%s","tool_name":"Agent","tool_input":{"subagent_type":"mega-sdd:bolt-implementer","prompt":"%s"}}' "$C" "$CP" | ( cd "$C" && bash "$HOOK" 2>/dev/null ))
deny_of "$O" && has "$O" "stamp_unreachable" && has "$O" "bind-codebase" && ok "classic vault, unreachable head: DENY stamp_unreachable → bind-codebase" || bad "classic unreachable: [$O]"

# 20. binding_absent / binding_unparseable / diverged / per-unit stamp_unreachable
D=$(fresh s); rm -f "$D/.mega-sdd/vaults/web/bolts/U-001/binding.json"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "binding_absent" && ok "lite unit with its binding deleted: DENY binding_absent" || bad "absent: [$O]"
D=$(fresh t); echo "{not json" > "$D/.mega-sdd/vaults/web/bolts/U-001/binding.json"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "binding_unparseable" && ok "unparseable binding: DENY binding_unparseable" || bad "unparseable: [$O]"
D=$(fresh u); ( cd "$D" && G checkout -q -b side && echo s >> README.md && G commit -qam side && G checkout -q main )
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));d["based_on_sha"]=sys.argv[2];json.dump(d,open(sys.argv[1],"w"))' "$D/.mega-sdd/vaults/web/bolts/U-001/binding.json" "$(git -C "$D" rev-parse side)"; mkprompt "$D"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "diverged" && ok "stamp on a branch HEAD does not descend from: DENY diverged" || bad "diverged: [$O]"
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));d["based_on_sha"]="0123456789abcdef0123456789abcdef01234567";json.dump(d,open(sys.argv[1],"w"))' "$D/.mega-sdd/vaults/web/bolts/U-001/binding.json"; mkprompt "$D"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "stamp_unreachable" && ok "per-unit stamp object gone: DENY stamp_unreachable" || bad "unreachable: [$O]"

# 21. unit id in two vaults, no pointer → unit_ambiguous
D=$(fresh v); mkdir -p "$D/.mega-sdd/vaults/web2/units"; cp "$D/.mega-sdd/vaults/web/units/U-001.md" "$D/.mega-sdd/vaults/web2/units/"
O=$(dispatch "$D" "mega-sdd-trace:execute-bolts:U-001\\nUNIT: U-001"); deny_of "$O" && has "$O" "unit_ambiguous" && ok "U-001 in two vaults with no pointer: DENY unit_ambiguous" || bad "ambiguous: [$O]"

# 22. a project path with a SPACE: the builder's absolute READ FIRST line still resolves → ALLOW
SP="$WORK/My Projects"; mkdir -p "$SP"; cp -a "$BASE" "$SP/app"; mkprompt "$SP/app"
O=$(dispatch "$SP/app" "mega-sdd-trace:execute-bolts:U-001\\nUNIT: U-001 \\\"login\\\"\\nREAD FIRST, IN FULL: $SP/app/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md")
[ -z "$O" ] && ok "project path with a space: the READ FIRST line resolves → ALLOW" || bad "space path: [$O]"
( cd "$SP/app" && echo 'export const q = 9' >> src/client.ts && G commit -qam "feat(web): q" )
O=$(dispatch "$SP/app" "mega-sdd-trace:execute-bolts:U-001\\nREAD FIRST, IN FULL: $SP/app/.mega-sdd/vaults/web/bolts/U-001/dispatch-prompt.md")
deny_of "$O" && has "$O" "binding_stale" && ok "…and a teammate commit there still DENYs binding_stale" || bad "space stale: [$O]"

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
O=$(dispatch "$D"); [ -z "$O" ] && ok "glob create target, fresh bind: ALLOW" || bad "glob fresh: [$O]"
mkdir -p "$D/src/login"; echo x > "$D/src/login/Wip.tsx"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "uncommitted_in_scope" && has "$O" "src/login/Wip.tsx" && ok "uncommitted file under a glob target: DENY uncommitted_in_scope" || bad "glob dirt: [$O]"
( cd "$D" && G add -A && G commit -qm "feat(web): teammate form" )
O=$(dispatch "$D"); deny_of "$O" && has "$O" "binding_stale" && has "$O" "src/login/Wip.tsx" && ok "teammate commit under a glob target: DENY binding_stale" || bad "glob stale: [$O]"

# 24. quoted `lane: "lite"` in config still classifies the unit as per-unit bound
D=$(fresh x); printf 'lane: "lite"\n' > "$D/.mega-sdd/config.yaml"; rm -f "$D/.mega-sdd/vaults/web/bolts/U-001/binding.json"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "binding_absent" && ok "quoted lane: \"lite\": still gated (binding_absent)" || bad "quoted lane: [$O]"

# 25. the E3 --verdicts pass of a 3.9b keeps rebind_head (the bound survives text claims)
D=$(fresh y); V="$D/.mega-sdd/vaults/web"
printf '\n## Claims\n- C-U001-01 "the api client returns one role" — expect: api role claim shape\n' >> "$V/units/U-001.md"
( cd "$D" && G add -A && G commit -qm claims ); bind "$D"
echo '// wip' >> "$D/src/client.ts"
bash "$S/rebind-units.sh" --cwd="$D" --vault="$V" --units=U-001 >/dev/null 2>&1
printf '{"C-U001-01":{"verdict":"CONFIRMED","anchor":"src/client.ts:2","confidence":"high","evidence":"read"}}\n' > "$WORK/v.json"
bash "$S/write-unit-binding.sh" --cwd="$D" --vault="$V" --unit=U-001 --claims="$V/bolts/U-001/_claims.json" --verdicts="$WORK/v.json" >/dev/null 2>&1
mkprompt "$D"; echo '// more' >> "$D/src/client.ts"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "rebind_exhausted" && ok "3.9b + its E3 pass, then new dirt at the same HEAD: DENY rebind_exhausted" || bad "E3 bound: [$O]"

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

# 27. skip-worktree and gitignored exact scope files present at bind → the dispatch after 3.9 ALLOWs;
#     a later change to the ignored one is still dirt (it is watched, not skipped)
D=$(fresh z2); V="$D/.mega-sdd/vaults/web"
python3 - "$V/units/U-001.md" <<'PY'
import sys; p = sys.argv[1]; s = open(p).read()   # an exact scope path: a gitignored modify target
open(p, "w").write(s.replace("    operation: modify\n", "    operation: modify\n  - path: src/local.config.ts\n    operation: modify\n", 1))
PY
printf 'src/local.config.ts\n' > "$D/.gitignore"; ( cd "$D" && G add -A && G commit -qm "units: local config" )
echo 'export const k = 1' > "$D/src/local.config.ts"
( cd "$D" && git update-index --skip-worktree src/Login.tsx && echo '// sw' >> src/Login.tsx )
bind "$D"; O=$(dispatch "$D")
[ -z "$O" ] && ok "skip-worktree + gitignored exact scope files present at bind: the dispatch after 3.9 ALLOWs" || bad "sw/ignored: [$O]"
echo 'export const k = 2' > "$D/src/local.config.ts"
O=$(dispatch "$D"); deny_of "$O" && has "$O" "uncommitted_in_scope" && has "$O" "src/local.config.ts" \
  && ok "…a later change to the gitignored scope file: DENY uncommitted_in_scope" || bad "ignored change: [$O]"

# 28. the Fase-0 C2 edit (+5 lines above the anchor) STAGED after 3.9: ALLOW in 8.7.2, DENY now
D=$(fresh z3); python3 -c 'import sys;p=sys.argv[1];s=open(p).read();open(p,"w").write("// a\n// b\n// c\n// d\n// e\n"+s)' "$D/src/client.ts"
( cd "$D" && G add src/client.ts )
O=$(dispatch "$D"); deny_of "$O" && has "$O" "uncommitted_in_scope" && has "$O" "src/client.ts" \
  && ok "C2 staged after 3.9 (+5 lines above the anchor): DENY uncommitted_in_scope" || bad "C2 staged: [$O]"

# 29. dirt OUTSIDE the unit scope: no deny, and a bind over it keeps an honest (non-null) stamp
D=$(fresh z4); echo '// sibling wip' >> "$D/README.md"
O=$(dispatch "$D"); [ -z "$O" ] && ok "uncommitted edit outside the unit scope: ALLOW" || bad "outside dirt: [$O]"
bind "$D"; O=$(dispatch "$D")
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));assert d["based_on_sha"]==sys.argv[2] and not d.get("null_cause"),d' \
  "$D/.mega-sdd/vaults/web/bolts/U-001/binding.json" "$(git -C "$D" rev-parse HEAD)" 2>/dev/null && [ -z "$O" ] \
  && ok "a sibling's dirt outside this unit's scope does not null the stamp (bind → ALLOW)" || bad "outside dirt bind: [$O]"

# 30. two waves: wave 1's own bolt commit moves a symbol in wave 2's scope after the run's index build.
#     3.9 step 0 (index first, per bind) → the wave-2 dispatch ALLOWs with NO 3.9b. The control arm
#     (no step 0) shows the index really was stale: the honest writer nulls the stamp.
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
bind2() { # wave 2: 3.9 for U-002 (derive + write) and its built prompt
  bash "$S/derive-unit-claims.sh" --cwd="$1" --vault="$1/.mega-sdd/vaults/web" --units=U-002 >/dev/null 2>&1
  bash "$S/write-unit-binding.sh" --cwd="$1" --vault="$1/.mega-sdd/vaults/web" --unit=U-002 --claims="$1/.mega-sdd/vaults/web/bolts/_wave-claims.json" >/dev/null 2>&1
  local B2="$1/.mega-sdd/vaults/web/bolts/U-002"; mkdir -p "$B2"
  printf 'mega-sdd-trace:execute-bolts:U-002\n  binding_sha256: %s\n' \
    "$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$B2/binding.json")" > "$B2/dispatch-prompt.md"
}
P2="mega-sdd-trace:execute-bolts:U-002\\nUNIT: U-002 \\\"profile\\\"\\nREAD FIRST, IN FULL:"
if [ "$AG" -eq 0 ]; then
  rm -rf "$WORK/z5c"; cp -a "$D" "$WORK/z5c"; bind2 "$WORK/z5c"
  O=$(dispatch "$WORK/z5c" "$P2 $WORK/z5c/.mega-sdd/vaults/web/bolts/U-002/dispatch-prompt.md")
  deny_of "$O" && has "$O" "stamp_null" && has "$O" "index_stale" \
    && ok "two waves, control (no step 0): the run's index is stale → DENY stamp_null (index_stale)" || bad "two-wave control: [$O]"
  bash "$S/build-symbol-index.sh" --cwd="$D" >/dev/null 2>&1                 # 3.9 step 0: index first
else
  ok "ast-grep not installed here: the two-wave index_stale control arm is skipped (symbol claims stay OQ)"
fi
bind2 "$D"
O=$(dispatch "$D" "$P2 $D/.mega-sdd/vaults/web/bolts/U-002/dispatch-prompt.md")
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));assert d["based_on_sha"]==sys.argv[2] and not d.get("rebind_head"),d' \
  "$V/bolts/U-002/binding.json" "$(git -C "$D" rev-parse HEAD)" 2>/dev/null && [ -z "$O" ] \
  && ok "two waves: wave 1 commits into wave 2's scope → step 0 + 3.9 → the wave-2 dispatch ALLOWs with no 3.9b" || bad "two-wave: [$O]"

[ "$fail" -eq 0 ] && { echo "PASS state-anchor gate binding-freshness"; exit 0; }
echo "state-anchor gate binding-freshness FAILED"; exit 1
