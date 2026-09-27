#!/usr/bin/env bash
# test-factory-backward-gate.sh — Round-3 audit gap R3-1.
#
# factory-routing.md claimed the anti-spin / phase_stuck halt is "enforced
# deterministically by ... the PreToolUse gate" — but no PreToolUse gate covered the
# BACKWARD re-dispatch of an upstream phase. Only the forward execute-bolts aggregator
# read the factory ledger, so an orchestrator could re-dispatch a stuck phase forever.
#
# This pins the new backward-dispatch gate:
#   1. A phase in cap-breach (phase_stuck) blocks re-dispatch of THAT phase.
#   2. A phase in spin-breach (anti_spin) blocks re-dispatch of THAT phase.
#   3. Per-phase precision: a DIFFERENT (non-stuck) phase is still allowed — e.g. an
#      extract-intelligence re-run while the sibling `plan` phase is stuck.
#   4. A PASS ledger / an absent ledger never blocks.
#   5. RECOVERY (the deadlock guard): after a block, RESETTING the raw ledger must
#      self-clear the gate on the very next dispatch — the gate RECOMPUTES from the raw
#      ledger, it does not trust a possibly-stale derived state file.
#   6. Ordering: the factory halt arm sits BEFORE the predictive-preflight arm, and with
#      a sibling phase (`plan`) ALSO stuck the halt names the dispatched phase itself.
#
# 9.0 P1b: the arm is keyed on mega-sdd:extract-intelligence only (the removed classic
# ids could never reach it). The hook derives the ledger phase as skill.split(':')[-1],
# so the ledger rows below use phase "extract-intelligence"; validate-factory-ledger.sh
# has no closed phase enum, so the sibling phase is the 9.0 canonical `plan`.
#
# CI-safe: bash + python3 only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/pre-tool-use"

[ -f "$HOOK" ] || { echo "FAIL: hook not found at $HOOK"; exit 1; }

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); echo "    $2"; }

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
MD="$ROOT/.mega-sdd"
mkdir -p "$MD"
LEDGER="$MD/factory-ledger.json"

run_skill() {
  printf '{"cwd": "%s", "tool_name": "Skill", "tool_input": {"skill": "%s"}}' "$ROOT" "$1" \
    | bash "$HOOK" 2>/dev/null
}
denied() { printf '%s' "$1" | grep -q '"permissionDecision": "deny"'; }
factory_denied() { denied "$1" && printf '%s' "$1" | grep -q 'Factory Line'; }

write_ledger() { printf '%s' "$1" > "$LEDGER"; }

CAP_STUCK='[
 {"phase":"extract-intelligence","attempt":1,"status":"unresolved","emitted_at":"t1","unresolved":[{"id":"OQ-1"}]},
 {"phase":"extract-intelligence","attempt":2,"status":"unresolved","emitted_at":"t2","unresolved":[{"id":"OQ-1"}]},
 {"phase":"extract-intelligence","attempt":3,"status":"unresolved","emitted_at":"t3","unresolved":[{"id":"OQ-1"}]}
]'
SPIN_STUCK='[
 {"phase":"extract-intelligence","attempt":1,"status":"unresolved","emitted_at":"t1","unresolved":[{"id":"OQ-2"}]},
 {"phase":"extract-intelligence","attempt":2,"status":"unresolved","emitted_at":"t2","unresolved":[{"id":"OQ-2"}]}
]'
PASS_LEDGER='[
 {"phase":"extract-intelligence","attempt":1,"status":"completed","emitted_at":"t1","unresolved":[]}
]'
# The sibling phase `plan` is cap-stuck; extract-intelligence is not in the ledger.
SIBLING_STUCK='[
 {"phase":"plan","attempt":1,"status":"unresolved","emitted_at":"t1","unresolved":[{"id":"OQ-3"}]},
 {"phase":"plan","attempt":2,"status":"unresolved","emitted_at":"t2","unresolved":[{"id":"OQ-3"}]},
 {"phase":"plan","attempt":3,"status":"unresolved","emitted_at":"t3","unresolved":[{"id":"OQ-3"}]}
]'
# BOTH the sibling `plan` phase and extract-intelligence are cap-stuck.
BOTH_STUCK='[
 {"phase":"plan","attempt":1,"status":"unresolved","emitted_at":"t1","unresolved":[{"id":"OQ-3"}]},
 {"phase":"plan","attempt":2,"status":"unresolved","emitted_at":"t2","unresolved":[{"id":"OQ-3"}]},
 {"phase":"plan","attempt":3,"status":"unresolved","emitted_at":"t3","unresolved":[{"id":"OQ-3"}]},
 {"phase":"extract-intelligence","attempt":1,"status":"unresolved","emitted_at":"t1","unresolved":[{"id":"OQ-1"}]},
 {"phase":"extract-intelligence","attempt":2,"status":"unresolved","emitted_at":"t2","unresolved":[{"id":"OQ-1"}]},
 {"phase":"extract-intelligence","attempt":3,"status":"unresolved","emitted_at":"t3","unresolved":[{"id":"OQ-1"}]}
]'
# A capped phase whose LATEST attempt then reached completed — breach cleared.
BREACH_RELEASED='[
 {"phase":"extract-intelligence","attempt":1,"status":"unresolved","emitted_at":"t1","unresolved":[{"id":"OQ-1"}]},
 {"phase":"extract-intelligence","attempt":2,"status":"unresolved","emitted_at":"t2","unresolved":[{"id":"OQ-1"}]},
 {"phase":"extract-intelligence","attempt":3,"status":"unresolved","emitted_at":"t3","unresolved":[{"id":"OQ-1"}]},
 {"phase":"extract-intelligence","attempt":4,"status":"completed","emitted_at":"t4","unresolved":[]}
]'
FL_STATE="$MD/.factory-ledger-state.json"

# 1. phase_stuck blocks re-dispatch of the stuck phase
write_ledger "$CAP_STUCK"
out=$(run_skill mega-sdd:extract-intelligence)
factory_denied "$out" && pass "phase_stuck blocks re-dispatch of extract-intelligence" \
  || fail "phase_stuck did NOT block stuck phase" "out=[$out]"

# 2. anti_spin blocks re-dispatch of the stuck phase
write_ledger "$SPIN_STUCK"
out=$(run_skill mega-sdd:extract-intelligence)
factory_denied "$out" && pass "anti_spin blocks re-dispatch of extract-intelligence" \
  || fail "anti_spin did NOT block stuck phase" "out=[$out]"

# 3. per-phase precision: extract-intelligence is allowed while the sibling plan phase
# is stuck. Non-vacuity: the state file is removed first, so a FAIL state naming `plan`
# afterwards proves the arm ran (recomputed) for THIS dispatch and saw the breach.
write_ledger "$SIBLING_STUCK"
rm -f "$FL_STATE"
out=$(run_skill mega-sdd:extract-intelligence)
if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get("status")=="FAIL" and any(b.get("phase")=="plan" for b in d.get("cap_breaches") or []) else 1)' "$FL_STATE" 2>/dev/null; then
  factory_denied "$out" && fail "per-phase precision broken: extract-intelligence blocked by the plan phase's halt" "out=[$out]" \
    || pass "per-phase precision: non-stuck extract-intelligence is allowed while plan is stuck"
else
  fail "per-phase precision precondition: the arm did not recompute a FAIL state naming plan" "state=[$(cat "$FL_STATE" 2>/dev/null)]"
fi

# 4a. PASS ledger never blocks
write_ledger "$PASS_LEDGER"
out=$(run_skill mega-sdd:extract-intelligence)
factory_denied "$out" && fail "PASS ledger blocked dispatch" "out=[$out]" \
  || pass "PASS ledger does not block"

# 4b. absent ledger never blocks
rm -f "$LEDGER"
out=$(run_skill mega-sdd:extract-intelligence)
factory_denied "$out" && fail "absent ledger blocked dispatch" "out=[$out]" \
  || pass "absent ledger does not block"

# 5. RECOVERY: block, then reset raw ledger -> next dispatch is ALLOWED (no deadlock).
write_ledger "$CAP_STUCK"
out=$(run_skill mega-sdd:extract-intelligence)
factory_denied "$out" || fail "recovery precondition: stuck phase should block first" "out=[$out]"
rm -f "$LEDGER"   # reset the rebuildable raw ledger (the documented recovery)
out=$(run_skill mega-sdd:extract-intelligence)
factory_denied "$out" && fail "DEADLOCK: gate still blocks after ledger reset (trusted stale derived state)" "out=[$out]" \
  || pass "recovery: ledger reset self-clears the gate (recompute, not stale-state)"

# 6. ordering: the Factory arm is evaluated BEFORE the predictive-preflight arm (so a
# stuck preflight-gated phase would report the more specific Factory halt), and with a
# sibling phase (plan) ALSO stuck the halt is attributed to the dispatched phase.
FL_LINE=$(grep -n 'FACTORY_VALIDATOR=' "$HOOK" | head -1 | cut -d: -f1)
PF_LINE=$(grep -n 'PREFLIGHT=.*validate-preflight.sh' "$HOOK" | head -1 | cut -d: -f1)
if [ -n "$FL_LINE" ] && [ -n "$PF_LINE" ] && [ "$FL_LINE" -lt "$PF_LINE" ]; then
  pass "ordering: the Factory arm (L$FL_LINE) precedes the preflight arm (L$PF_LINE)"
else
  fail "ordering: Factory arm not before preflight arm" "factory=[$FL_LINE] preflight=[$PF_LINE]"
fi
write_ledger "$BOTH_STUCK"
out=$(run_skill mega-sdd:extract-intelligence)
if factory_denied "$out" && printf '%s' "$out" | grep -q 'phase extract-intelligence is HALTED'; then
  pass "ordering: stuck extract-intelligence reports its own Factory halt with plan also stuck"
else
  fail "ordering: extract-intelligence did not report its own Factory halt" "out=[$out]"
fi

# 7. breach-scoped (not a permanent ban): once the phase's latest attempt is completed,
# the gate releases — this is the in-band recovery the cap math allows.
write_ledger "$BREACH_RELEASED"
out=$(run_skill mega-sdd:extract-intelligence)
factory_denied "$out" && fail "gate is a permanent ban: blocked a phase whose latest attempt completed" "out=[$out]" \
  || pass "breach-scoped: gate releases once the phase's latest attempt is completed"

echo
if [ "$fails" -eq 0 ]; then
  echo "test-factory-backward-gate: ALL PASS"
  exit 0
else
  echo "test-factory-backward-gate: $fails FAILURE(S)"
  exit 1
fi
