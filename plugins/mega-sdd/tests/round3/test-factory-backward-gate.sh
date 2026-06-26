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
#   3. Per-phase precision: a DIFFERENT (non-stuck) phase is still allowed — e.g. a
#      re-scan to FIX the stuck phase must not be blocked.
#   4. A PASS ledger / an absent ledger never blocks.
#   5. RECOVERY (the deadlock guard): after a block, RESETTING the raw ledger must
#      self-clear the gate on the very next dispatch — the gate RECOMPUTES from the raw
#      ledger, it does not trust a possibly-stale derived state file.
#   6. Ordering: the factory halt fires BEFORE the predictive-preflight check, so a
#      stuck preflight-gated phase reports the (more specific) factory halt.
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
 {"phase":"generate-intent","attempt":1,"status":"unresolved","emitted_at":"t1","unresolved":[{"id":"OQ-1"}]},
 {"phase":"generate-intent","attempt":2,"status":"unresolved","emitted_at":"t2","unresolved":[{"id":"OQ-1"}]},
 {"phase":"generate-intent","attempt":3,"status":"unresolved","emitted_at":"t3","unresolved":[{"id":"OQ-1"}]}
]'
SPIN_STUCK='[
 {"phase":"generate-intent","attempt":1,"status":"unresolved","emitted_at":"t1","unresolved":[{"id":"OQ-2"}]},
 {"phase":"generate-intent","attempt":2,"status":"unresolved","emitted_at":"t2","unresolved":[{"id":"OQ-2"}]}
]'
PASS_LEDGER='[
 {"phase":"generate-intent","attempt":1,"status":"completed","emitted_at":"t1","unresolved":[]}
]'
BIND_STUCK='[
 {"phase":"bind-codebase","attempt":1,"status":"unresolved","emitted_at":"t1","unresolved":[{"id":"CONFLICT-1"}]},
 {"phase":"bind-codebase","attempt":2,"status":"unresolved","emitted_at":"t2","unresolved":[{"id":"CONFLICT-1"}]},
 {"phase":"bind-codebase","attempt":3,"status":"unresolved","emitted_at":"t3","unresolved":[{"id":"CONFLICT-1"}]}
]'
# A capped phase whose LATEST attempt then reached completed — breach cleared.
BREACH_RELEASED='[
 {"phase":"generate-intent","attempt":1,"status":"unresolved","emitted_at":"t1","unresolved":[{"id":"OQ-1"}]},
 {"phase":"generate-intent","attempt":2,"status":"unresolved","emitted_at":"t2","unresolved":[{"id":"OQ-1"}]},
 {"phase":"generate-intent","attempt":3,"status":"unresolved","emitted_at":"t3","unresolved":[{"id":"OQ-1"}]},
 {"phase":"generate-intent","attempt":4,"status":"completed","emitted_at":"t4","unresolved":[]}
]'

# 1. phase_stuck blocks re-dispatch of the stuck phase
write_ledger "$CAP_STUCK"
out=$(run_skill mega-sdd:generate-intent)
factory_denied "$out" && pass "phase_stuck blocks re-dispatch of generate-intent" \
  || fail "phase_stuck did NOT block stuck phase" "out=[$out]"

# 2. anti_spin blocks re-dispatch of the stuck phase
write_ledger "$SPIN_STUCK"
out=$(run_skill mega-sdd:generate-intent)
factory_denied "$out" && pass "anti_spin blocks re-dispatch of generate-intent" \
  || fail "anti_spin did NOT block stuck phase" "out=[$out]"

# 3. per-phase precision: a DIFFERENT phase is allowed while generate-intent is stuck
write_ledger "$CAP_STUCK"
out=$(run_skill mega-sdd:scan-codebase)
factory_denied "$out" && fail "per-phase precision broken: scan-codebase blocked by another phase's halt" "out=[$out]" \
  || pass "per-phase precision: non-stuck scan-codebase is allowed"

# 4a. PASS ledger never blocks
write_ledger "$PASS_LEDGER"
out=$(run_skill mega-sdd:generate-intent)
factory_denied "$out" && fail "PASS ledger blocked dispatch" "out=[$out]" \
  || pass "PASS ledger does not block"

# 4b. absent ledger never blocks
rm -f "$LEDGER"
out=$(run_skill mega-sdd:generate-intent)
factory_denied "$out" && fail "absent ledger blocked dispatch" "out=[$out]" \
  || pass "absent ledger does not block"

# 5. RECOVERY: block, then reset raw ledger -> next dispatch is ALLOWED (no deadlock).
write_ledger "$CAP_STUCK"
out=$(run_skill mega-sdd:generate-intent)
factory_denied "$out" || fail "recovery precondition: stuck phase should block first" "out=[$out]"
rm -f "$LEDGER"   # reset the rebuildable raw ledger (the documented recovery)
out=$(run_skill mega-sdd:generate-intent)
factory_denied "$out" && fail "DEADLOCK: gate still blocks after ledger reset (trusted stale derived state)" "out=[$out]" \
  || pass "recovery: ledger reset self-clears the gate (recompute, not stale-state)"

# 6. ordering: factory halt fires before preflight for a preflight-gated phase.
# bind-codebase has a preflight precondition (needs vault+map); with neither present,
# preflight would FATAL. The factory halt must win (more specific signal).
write_ledger "$BIND_STUCK"
out=$(run_skill mega-sdd:bind-codebase)
if factory_denied "$out"; then
  pass "ordering: stuck bind-codebase reports the Factory halt before preflight"
else
  fail "ordering: bind-codebase did not report Factory halt first" "out=[$out]"
fi

# 7. breach-scoped (not a permanent ban): once the phase's latest attempt is completed,
# the gate releases — this is the in-band recovery the cap math allows.
write_ledger "$BREACH_RELEASED"
out=$(run_skill mega-sdd:generate-intent)
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
