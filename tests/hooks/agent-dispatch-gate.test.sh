#!/usr/bin/env bash
# agent-dispatch-gate.test.sh — F-09 (spec 2026-08-30 §1.1).
#
# The field run (HOST-AS400, 36 units / 117 commits) drove every sprint through
# hand dispatch of `bolt-implementer` and the execute-bolts gate aggregator
# evaluated ONCE — the hooks.json matcher excluded `Agent` on the prose
# assumption "gated phases are Skill-dispatched". This pins the mechanism:
#   A  a non-bolt Agent call in an SDD project → no output, ZERO python
#      (fast-path substring exit)
#   B  a bolt-implementer Agent dispatch is DENIED by the same gate that denies
#      the Skill dispatch (orphan bolt: commit with no bolt-report)
#   C  in-run semantics: once the unit is IN FLIGHT (dispatch-prompt.md newer
#      than postflight.json) its own pending evidence does NOT deny the Agent
#      dispatch — while the Skill entry (run mode) still evaluates it in full
#   D  B2 (batch-suite) is a run-boundary gate: it denies the Skill entry and
#      never the in-run Agent dispatch
#   E  the Agent dispatch ARMS the session (chain_engaged) like a Skill dispatch
#   F  hooks.json carries the Agent matcher (the mechanism's front door)
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN="$REPO/plugins/mega-sdd"
HOOK="$PLUGIN/hooks/pre-tool-use"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { echo "  ok: $1"; }
bad() { echo "  FAIL: $1"; fail=1; }
SID="agent-gate-test"

# python spawn counter (PATH shim — the tier-S harness pattern)
SHIM="$WORK/shim"; mkdir -p "$SHIM"; CNT="$WORK/pycount"
real_py=$(command -v python3)
printf '#!/bin/bash\necho 1 >> "%s"\nexec "%s" "$@"\n' "$CNT" "$real_py" > "$SHIM/python3"; chmod +x "$SHIM/python3"
pycount() { if [ -f "$CNT" ]; then wc -l < "$CNT" | tr -d ' '; else echo 0; fi; }

drive() { # $1=payload-json
  printf '%s' "$1" | PATH="$SHIM:$PATH" bash "$HOOK" 2>/dev/null
}
agent_payload() { # $1=subagent_type
  printf '{"session_id":"%s","cwd":"%s","tool_name":"Agent","tool_input":{"subagent_type":"%s","description":"bolt","prompt":"Read <vault>/bolts/U-001/dispatch-prompt.md first. mega-sdd-trace:execute-bolts"}}' "$SID" "$F" "$1"
}
skill_payload() {
  printf '{"session_id":"%s","cwd":"%s","tool_name":"Skill","tool_input":{"skill":"mega-sdd:execute-bolts","args":"--all"}}' "$SID" "$F"
}

# ── fixture: SDD project, one unit, one bolt commit WITHOUT a bolt-report ────
F="$WORK/proj"
V="$F/.mega-sdd/vaults/app"
mkdir -p "$V/units" "$V/bolts" "$F/src"
( cd "$F" && git init -q . && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed )
printf -- '---\nunit_id: U-001\ntask_type: create\ntarget_files:\n  - path: src/a.js\n    operation: create\n---\n# U-001\n\n## Acceptance\n' > "$V/units/U-001.md"
( cd "$F" && echo "a" > src/a.js && git add src/a.js .mega-sdd \
  && git -c user.email=t@t -c user.name=t commit -q -m "feat(U-001): bolt

Unit: U-001" )

echo "── F: hooks.json front door ──"
grep -q '"matcher": "Skill|Bash|Edit|Write|Agent"' "$PLUGIN/hooks/hooks.json" \
  && ok "F1 PreToolUse matcher carries Agent" || bad "F1 PreToolUse matcher does not carry Agent"

echo "── A: a non-bolt Agent call is free ──"
rm -f "$CNT"
OUT=$(drive "$(agent_payload general-purpose)")
[ -z "$OUT" ] && [ "$(pycount)" -eq 0 ] && ok "A1 general-purpose Agent: no output, 0 python" \
  || bad "A1 non-bolt Agent not free (python=$(pycount) out=[$(printf '%s' "$OUT" | head -c 120)])"
OUT=$(drive "$(agent_payload mega-sdd:spec-reviewer)")
[ -z "$OUT" ] && ok "A2 review-lens Agent: no output" || bad "A2 lens Agent produced output: $(printf '%s' "$OUT" | head -c 120)"

echo "── B: bolt-implementer dispatch is gated like the Skill dispatch ──"
OUT_S=$(drive "$(skill_payload)")
printf '%s' "$OUT_S" | grep -q '"deny"' && printf '%s' "$OUT_S" | grep -q 'bolt-orphans' \
  && ok "B1 Skill execute-bolts denied (orphan bolt) — fixture provokes the gate" \
  || bad "B1 fixture does not provoke the gate on the Skill path: $(printf '%s' "$OUT_S" | head -c 200)"
OUT_A=$(drive "$(agent_payload mega-sdd:bolt-implementer)")
printf '%s' "$OUT_A" | grep -q '"deny"' && printf '%s' "$OUT_A" | grep -q 'bolt-orphans' \
  && ok "B2 Agent bolt-implementer denied by the SAME orphan gate" \
  || bad "B2 Agent bolt-implementer NOT denied — the gate is still Skill-only: $(printf '%s' "$OUT_A" | head -c 200)"
printf '%s' "$OUT_A" | grep -q 'bolt-implementer dispatch (gated as mega-sdd:execute-bolts, in-run)' \
  && ok "B3 deny names the subject (in-run)" || bad "B3 deny does not name the in-run subject"
OUT_A2=$(drive "$(agent_payload bolt-implementer)")
printf '%s' "$OUT_A2" | grep -q '"deny"' && ok "B4 unprefixed subagent_type also gated" || bad "B4 unprefixed bolt-implementer not gated"

echo "── E: the Agent dispatch arms the session ──"
grep -q "\"$SID\": true" "$F/.mega-sdd/.gateguard-state.json" 2>/dev/null \
  && ok "E1 chain_engaged written for this session by the Agent dispatch" \
  || bad "E1 Agent dispatch did not arm the session: $(cat "$F/.mega-sdd/.gateguard-state.json" 2>/dev/null | head -c 200)"

echo "── C: in-flight unit — pending evidence is not missing evidence ──"
mkdir -p "$V/bolts/U-001"
echo "dispatch" > "$V/bolts/U-001/dispatch-prompt.md"   # no postflight.json → in flight
OUT_A=$(drive "$(agent_payload mega-sdd:bolt-implementer)")
if printf '%s' "$OUT_A" | grep -q 'bolt-orphans'; then
  bad "C1 in-flight U-001's own pending bolt-report DENIED its re-dispatch (fix round would false-deny)"
else
  ok "C1 in-flight U-001: orphan issue dropped for the Agent dispatch"
fi
OUT_S=$(drive "$(skill_payload)")
printf '%s' "$OUT_S" | grep -q 'bolt-orphans' \
  && ok "C2 Skill entry (run mode) still evaluates the in-flight unit in full" \
  || bad "C2 run-mode gate lost the orphan issue: $(printf '%s' "$OUT_S" | head -c 200)"
# a unit NOT in flight (hand-dispatched: no dispatch-prompt) stays fully gated
printf -- '---\nunit_id: U-002\ntask_type: create\ntarget_files:\n  - path: src/b.js\n    operation: create\n---\n# U-002\n\n## Acceptance\n' > "$V/units/U-002.md"
( cd "$F" && echo "b" > src/b.js && git add src/b.js .mega-sdd \
  && git -c user.email=t@t -c user.name=t commit -q -m "feat(U-002): bolt

Unit: U-002" )
OUT_A=$(drive "$(agent_payload mega-sdd:bolt-implementer)")
printf '%s' "$OUT_A" | grep -q 'bolt-orphans' && printf '%s' "$OUT_A" | grep -q 'U-002' \
  && ok "C3 hand-dispatched U-002 (no dispatch-prompt) still denies the next bolt dispatch" \
  || bad "C3 non-in-flight orphan U-002 not enforced in-run: $(printf '%s' "$OUT_A" | head -c 200)"
# once its evidence lands, the in-flight window closes
echo "# report" > "$V/bolts/U-001/bolt-report.md"
mkdir -p "$V/bolts/U-002"; echo "# report" > "$V/bolts/U-002/bolt-report.md"
sleep 1; echo '{"status":"pass","rules":[]}' > "$V/bolts/U-001/postflight.json"

echo "── D: B2 is a run-boundary gate ──"
# both bolts now carry reports; no green full-suite covers the newest code commit
OUT_S=$(drive "$(skill_payload)")
printf '%s' "$OUT_S" | grep -q 'batch-suite-gate' \
  && ok "D1 Skill entry denied by B2 (no green full-suite covers the newest code commit)" \
  || bad "D1 fixture does not provoke B2 on the Skill path: $(printf '%s' "$OUT_S" | head -c 200)"
OUT_A=$(drive "$(agent_payload mega-sdd:bolt-implementer)")
if printf '%s' "$OUT_A" | grep -q 'batch-suite-gate'; then
  bad "D2 in-run Agent dispatch denied by B2 — every wave after the first would false-deny"
else
  ok "D2 in-run Agent dispatch is NOT held by B2"
fi

echo
[ "$fail" -eq 0 ] && { echo "PASS agent-dispatch-gate"; exit 0; } || { echo "agent-dispatch-gate FAILED"; exit 1; }
