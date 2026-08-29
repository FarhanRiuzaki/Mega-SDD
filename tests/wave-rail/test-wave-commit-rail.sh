#!/usr/bin/env bash
# test-wave-commit-rail.sh — F-16 (spec 2026-08-30 §1.3).
#
# Waves run on ONE working tree (the --all default since 7.7.0). On the field
# run a BLOCKER commit swept 1,031 lines of two siblings' half-written tests and
# `git commit --amend` was used 11× (once sweeping 8 files). No rail existed.
# This pins the mechanism: while ANY unit is in flight (dispatch-prompt.md newer
# than postflight.json), the sweeping git verbs are DENIED; the pathspec form and
# the non-sweeping verbs pass; a quoted commit MESSAGE never trips the rail; the
# rail is off once the in-flight window closes and in plugin-dev mode.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO/plugins/mega-sdd/hooks/pre-tool-use"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { echo "  ok: $1"; }
bad() { echo "  FAIL: $1"; fail=1; }

F="$WORK/proj"; V="$F/.mega-sdd/vaults/app"
mkdir -p "$V/bolts/U-007" "$F/src"
echo "dispatch" > "$V/bolts/U-007/dispatch-prompt.md"     # in flight (no postflight)

# armed = subagent context (the implementer itself) — the sentinel forces the full path
drive_armed() { # $1=command
  printf '{"session_id":"s","agent_id":"a1","cwd":"%s","tool_name":"Bash","tool_input":{"command":%s}}' "$F" "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | bash "$HOOK" 2>/dev/null
}
drive_unarmed() { # $1=command  (no chain marker, no sentinel — tier-S)
  printf '{"session_id":"s-other","cwd":"%s","tool_name":"Bash","tool_input":{"command":%s}}' "$F" "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | bash "$HOOK" 2>/dev/null
}
deny()  { printf '%s' "$1" | grep -q '"deny"'; }
names() { printf '%s' "$1" | grep -q 'U-007'; }

echo "── sweeping verbs DENIED while U-007 is in flight (armed) ──"
for c in "git add -A" "git add --all" "git add ." "git add -p ." "git commit -am 'x'" "git commit -a -m 'x'" \
         "git commit --amend --no-edit" "git stash" "git stash push -m wip" "git reset --hard HEAD~1" \
         "cd $F && git add -A && git commit -m x"; do
  OUT=$(drive_armed "$c")
  deny "$OUT" && names "$OUT" && ok "deny: $c" || bad "ALLOWED (should deny, naming U-007): $c → $(printf '%s' "$OUT" | head -c 120)"
done

echo "── non-sweeping forms PASS ──"
for c in "git add src/a.ts src/b.ts" "git add ./src/a.ts" "git commit -m 'feat(U-007): add . files and -a flag'" \
         "git commit -m \"add -A\"" "git stash pop" "git stash list" "git reset --soft HEAD~1" "git status" \
         "git log --all --oneline" "git diff --stat HEAD~1" "git add src/x.ts && git commit -m 'fix(U-007): x'"; do
  OUT=$(drive_armed "$c")
  if deny "$OUT" && names "$OUT"; then bad "false DENY: $c"; else ok "allow: $c"; fi
done

echo "── un-armed session on the same tree (the second-session field case) ──"
OUT=$(drive_unarmed "git add -A")
deny "$OUT" && names "$OUT" && ok "un-armed git add -A denied (fragment path)" || bad "un-armed git add -A ALLOWED — a second session can sweep a sibling bolt"
OUT=$(drive_unarmed "git commit --amend --no-edit")
deny "$OUT" && ok "un-armed --amend denied" || bad "un-armed --amend ALLOWED"
OUT=$(drive_unarmed "git add src/a.ts")
[ -z "$OUT" ] && ok "un-armed pathspec add: silent (tier-S)" || bad "un-armed pathspec add produced output: $(printf '%s' "$OUT" | head -c 120)"

echo "── in-flight window closes when postflight lands ──"
sleep 1; echo '{"status":"pass"}' > "$V/bolts/U-007/postflight.json"
OUT=$(drive_armed "git add -A")
if deny "$OUT" && names "$OUT"; then bad "rail still on after postflight.json is newer than dispatch-prompt"; else ok "git add -A allowed once no unit is in flight"; fi
# a NEW dispatch (dispatch-prompt rewritten) re-opens the window
sleep 1; echo "dispatch r2" > "$V/bolts/U-007/dispatch-prompt.md"
OUT=$(drive_armed "git commit --amend")
deny "$OUT" && ok "re-dispatch (newer dispatch-prompt) re-opens the rail" || bad "re-dispatch did not re-open the rail"

echo "── plugin-dev mode is exempt ──"
PD="$WORK/plugdev"; mkdir -p "$PD/plugins/mega-sdd/hooks" "$PD/.mega-sdd/vaults/app/bolts/U-001"
echo d > "$PD/.mega-sdd/vaults/app/bolts/U-001/dispatch-prompt.md"
OUT=$(printf '{"session_id":"s","agent_id":"a1","cwd":"%s","tool_name":"Bash","tool_input":{"command":"git add -A"}}' "$PD" | bash "$HOOK" 2>/dev/null)
if deny "$OUT"; then bad "plugin-dev tree denied git add -A"; else ok "plugin-dev tree: rail off"; fi

echo "── single definition: the helper is what both consumers read ──"
python3 - "$REPO/plugins/mega-sdd/scripts/_lib" "$F" <<'EOF' && ok "vault_layouts.inflight_units agrees with the hook (U-007 in flight)" || bad "helper disagrees / missing"
import sys, os
sys.path.insert(0, sys.argv[1]); import vault_layouts
assert vault_layouts.inflight_units(sys.argv[2]) == ["U-007"], vault_layouts.inflight_units(sys.argv[2])
EOF
grep -q 'vault_layouts.inflight_units' "$HOOK" && ok "hook imports the shared helper (no second predicate)" || bad "hook does not use vault_layouts.inflight_units"
grep -q 'inflight_units' "$REPO/plugins/mega-sdd/agents/bolt-implementer.md" "$REPO/plugins/mega-sdd/skills/execute-bolts/references/batch-and-fanout.md" 2>/dev/null \
  || grep -q 'pathspec' "$REPO/plugins/mega-sdd/agents/bolt-implementer.md" && ok "implementer contract carries the pathspec rule" || bad "implementer contract lacks the pathspec rule"

echo
[ "$fail" -eq 0 ] && { echo "wave commit rail: ALL PASS"; exit 0; } || { echo "wave commit rail: FAILED"; exit 1; }
