#!/usr/bin/env bash
# test-bolts-phasing-nextaction-shape.sh — pins the execute-bolts §"Hand-off +
# end-of-chain phasing" next_action SHAPE in halts-and-handoff.md.
#
# The §phasing block emits the completed-execute-bolts next_action for the
# phased-KB-rebuild case. Both branches MUST be the canonical execute-bolts hop
# `suggested_skill: mega-sdd:detect-drift` — the DEFAULT-ON auto-gate that runs
# after every execute-bolts batch (orchestrate-flow/references/chain-execution.md
# §Hybrid drift gate phase :190), so execute-bolts is NEVER terminal — matching
# §Handoff emission (--auto) :377-381 and handoff-contract.md §execute-bolts
# (:411-413). Phase advance / all-phases-done is carried as an informational
# next_action.hint (chain-execution.md §Phase context :260 — "This complements the
# execute-bolts handoff next_action.hint"), NEVER as suggested_skill: cross-phase
# advance is a MANUAL user checkpoint (generation-guide.md §To start the next phase
# :197-201; chain-execution.md :256), not an auto-route.
#
# Regression pinned: the block previously emitted
#   (a) suggested_skill: mega-sdd:generate-intent  --phase=<N+1>  (auto cross-phase
#       advance — the orchestrator consumption loop passes suggested_args straight
#       through, bypassing the manual phase checkpoint), and
#   (b) a BARE STRING  next_action: "All phases complete ..."  (off-shape terminal;
#       execute-bolts is never terminal — detect-drift runs next).
# Both contradicted the same file's --auto template + the contract.
#
# Static doc-consistency grep test (NOT a validator invocation — a non-empty bare
# string / a valid generate-intent dict both PASS validate-handoff-yaml.sh; only
# the SHAPE is wrong). CI-safe: bash + awk + grep only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOC="${PLUGIN_ROOT}/skills/execute-bolts/references/halts-and-handoff.md"

[ -f "$DOC" ] || { echo "FAIL: doc not found at $DOC"; exit 1; }

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

# Extract the §"Hand-off + end-of-chain phasing" block (between its header and the
# next "## Handoff emission" header).
BLOCK="$(awk '
  /^## Hand-off \+ end-of-chain phasing/ {inblk=1; next}
  /^## Handoff emission/ {inblk=0}
  inblk {print}
' "$DOC")"

[ -n "$BLOCK" ] || { echo "FAIL: could not extract §phasing block from $DOC"; exit 1; }

# ── Assertion A (FAIL pre-fix): no auto cross-phase advance ────────────────────
if printf '%s\n' "$BLOCK" | grep -q 'suggested_skill: mega-sdd:generate-intent'; then
  fail "A: §phasing still emits 'suggested_skill: mega-sdd:generate-intent' (auto cross-phase advance — must be a hint, not a suggested_skill)"
else
  pass "A: no 'suggested_skill: mega-sdd:generate-intent' (cross-phase advance is not auto-routed)"
fi

# ── Assertion B (FAIL pre-fix): no bare-string terminal next_action ────────────
if printf '%s\n' "$BLOCK" | grep -Eq 'next_action:[[:space:]]*"All phases complete'; then
  fail "B: §phasing still emits a bare-string next_action: \"All phases complete...\" (off-shape; execute-bolts is never terminal)"
else
  pass "B: no bare-string 'All phases complete' terminal next_action"
fi

# ── Assertion C (PASS post-fix): both branches route to detect-drift ───────────
dd_count="$(printf '%s\n' "$BLOCK" | grep -c 'suggested_skill: mega-sdd:detect-drift')"
if [ "$dd_count" -ge 2 ]; then
  pass "C: both §phasing branches route to 'suggested_skill: mega-sdd:detect-drift' (count=$dd_count)"
else
  fail "C: expected >=2 'suggested_skill: mega-sdd:detect-drift' in §phasing, got $dd_count"
fi

# ── Assertion D (PASS post-fix): phase status carried under a hint: key ─────────
if printf '%s\n' "$BLOCK" | grep -Eq 'hint:.*Phase'; then
  pass "D: phase status appears under a 'hint:' key (informational, not a suggested_skill)"
else
  fail "D: no 'hint:.*Phase' — phase status must be an informational next_action.hint"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "test-bolts-phasing-nextaction-shape: ALL PASS"
  exit 0
else
  echo "test-bolts-phasing-nextaction-shape: $fails FAILURE(S)"
  exit 1
fi
