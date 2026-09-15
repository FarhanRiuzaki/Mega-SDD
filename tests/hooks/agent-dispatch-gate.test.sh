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

echo "── G: panel-pending is not evidence-missing (v8 P3, the measured serializer) ──"
# U-002: a REAL dispatch (dispatch-prompt) keyed by review-tier.json, whose detect-after
# already passed (postflight + acceptance PASS, newer than the prompt; L0 record
# script-written) but whose panel ledger has not merged yet. Under the pre-P3 gate
# this unit's panel_evidence_missing denied EVERY next bolt-implementer dispatch —
# research/2026-09-15-v8-p3-report.md §2 (45 % of the clinic bolt-stage idle).
mkdir -p "$V/bolts/U-002" "$V/lens-inputs/U-002"
echo "dispatch" > "$V/bolts/U-002/dispatch-prompt.md"
# risk: critical → tier full (a `minimal` tier owes only the L0 record, never a ledger)
printf -- '---\nunit_id: U-002\ntask_type: create\nrisk: critical\ntarget_files:\n  - path: src/b.js\n    operation: create\n---\n# U-002\n\n## Acceptance\n' > "$V/units/U-002.md"
bash "$PLUGIN/scripts/resolve-review-tier.sh" --unit="$V/units/U-002.md" --write >/dev/null 2>&1 \
  || bad "G0 resolve-review-tier --write failed (fixture precondition)"
grep -q '"tier": *"full"' "$V/bolts/U-002/review-tier.json" 2>/dev/null || bad "G0 review-tier.json not full (fixture precondition): $(cat "$V/bolts/U-002/review-tier.json" 2>/dev/null | head -c 120)"
printf '{"written_by":"run-code-gates.sh","plugin_version":"test","gates":[]}\n' > "$V/lens-inputs/U-002/l0-results.json"
sleep 1
echo '{"status":"pass","rules":[]}' > "$V/bolts/U-002/postflight.json"
echo '{"status":"pass","entries":[]}' > "$V/bolts/U-002/acceptance.json"
OUT_S=$(drive "$(skill_payload)")
printf '%s' "$OUT_S" | grep -q 'panel-evidence' \
  && ok "G1 Skill entry (run mode) still denies: U-002 owes its panel ledger at the run boundary" \
  || bad "G1 run-mode gate lost the panel-evidence issue: $(printf '%s' "$OUT_S" | head -c 200)"
OUT_A=$(drive "$(agent_payload mega-sdd:bolt-implementer)")
if printf '%s' "$OUT_A" | grep -q 'panel-evidence'; then
  bad "G2 in-run Agent dispatch DENIED by a sibling's PENDING panel — the P3 serializer is back: $(printf '%s' "$OUT_A" | head -c 200)"
else
  ok "G2 in-run Agent dispatch is NOT held by U-002's pending panel (panel_pending_units)"
fi
# bound: more panel-pending units than parallel_max → the full F-07 verdict applies again
printf 'parallel_max: 1\n' > "$F/.mega-sdd/config.yaml"
printf -- '---\nunit_id: U-003\ntask_type: create\nrisk: critical\ntarget_files:\n  - path: src/c.js\n    operation: create\n---\n# U-003\n\n## Acceptance\n' > "$V/units/U-003.md"
( cd "$F" && echo "c" > src/c.js && git add src/c.js .mega-sdd \
  && git -c user.email=t@t -c user.name=t commit -q -m "feat(U-003): bolt

Unit: U-003" )
mkdir -p "$V/bolts/U-003" "$V/lens-inputs/U-003"; echo "# report" > "$V/bolts/U-003/bolt-report.md"
echo "dispatch" > "$V/bolts/U-003/dispatch-prompt.md"
bash "$PLUGIN/scripts/resolve-review-tier.sh" --unit="$V/units/U-003.md" --write >/dev/null 2>&1 || bad "G3 precondition: review-tier U-003"
printf '{"written_by":"run-code-gates.sh","plugin_version":"test","gates":[]}\n' > "$V/lens-inputs/U-003/l0-results.json"
sleep 1
echo '{"status":"pass","rules":[]}' > "$V/bolts/U-003/postflight.json"
echo '{"status":"pass","entries":[]}' > "$V/bolts/U-003/acceptance.json"
OUT_A=$(drive "$(agent_payload mega-sdd:bolt-implementer)")
printf '%s' "$OUT_A" | grep -q 'panel-evidence' \
  && ok "G3 two panel-pending units over parallel_max=1 → in-run dispatch denied (pipeline depth ≤ cap)" \
  || bad "G3 over-cap panel-pending set was dropped — the bound is not enforced: $(printf '%s' "$OUT_A" | head -c 200)"
rm -f "$F/.mega-sdd/config.yaml"
# the L0 record is never pending: remove U-002's l0-results → l0_evidence_missing denies in-run too
rm -f "$V/lens-inputs/U-002/l0-results.json"
OUT_A=$(drive "$(agent_payload mega-sdd:bolt-implementer)")
printf '%s' "$OUT_A" | grep -q 'panel-evidence' \
  && ok "G4 a missing L0 record (l0_evidence_missing) still denies the in-run dispatch" \
  || bad "G4 l0_evidence_missing was dropped as panel-pending: $(printf '%s' "$OUT_A" | head -c 200)"
printf '{"written_by":"run-code-gates.sh","plugin_version":"test","gates":[]}\n' > "$V/lens-inputs/U-002/l0-results.json"
# a hand-written ledger is not a merged panel: the unit stays panel-pending only while NO findings.json exists;
# once a (script-merged) ledger lands the obligation is met and nothing is pending
printf '{"schema":1,"written_by":"merge-panel-findings.sh","findings":[]}\n' > "$V/bolts/U-002/findings.json"
printf '{"schema":1,"written_by":"merge-panel-findings.sh","findings":[]}\n' > "$V/bolts/U-003/findings.json"
OUT_A=$(drive "$(agent_payload mega-sdd:bolt-implementer)")
if printf '%s' "$OUT_A" | grep -q 'panel-evidence'; then
  bad "G5 merged ledgers present but the in-run dispatch is still denied by panel-evidence: $(printf '%s' "$OUT_A" | head -c 200)"
else
  ok "G5 merged ledgers close the obligation — in-run dispatch free of panel-evidence"
fi

echo
[ "$fail" -eq 0 ] && { echo "PASS agent-dispatch-gate"; exit 0; } || { echo "agent-dispatch-gate FAILED"; exit 1; }
