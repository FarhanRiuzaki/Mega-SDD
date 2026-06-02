#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for validate-conflict-classification.sh (Iter-79 X-1).
#
# X-1 fixed a VACUOUS gate: the prior validator greped only for ```yaml
# binding_conflict:``` blocks the producer never emits, so it SKIPped on every
# real binding (and was wired to no hook). This DoD asserts the validator now
# detects the markdown `### CONFLICT-N` form bind-codebase actually emits:
#   - bad/  : 1 ACTIVE unclassified conflict + 1 RESOLVED (exempt) → WARN, unclassified=1
#   - good/ : same conflict carrying conflict_class+resolution_complexity → PASS
#
# Run: bash tests/fixtures/code-delivery/conflict-classification/verify.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-conflict-classification.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }

if [ ! -f "$VALIDATOR" ]; then
  fail "validate-conflict-classification.sh not found at $VALIDATOR"
  exit 1
fi

read_state() { python3 -c "
import json,sys
try:
    d=json.load(open('$1'))
    print($2)
except Exception as e:
    print('ERR:'+str(e))
" 2>/dev/null; }

# ─── BAD fixture: must WARN, flag 1 active unclassified conflict ─────────────
note "=== BAD fixture (expect WARN: 1 active unclassified, 1 resolved exempt) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --quiet
BAD_STATE="$HERE/bad/.mega-sdd/.conflict-classification-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state file not written at $BAD_STATE"
BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_TOTAL=$(read_state "$BAD_STATE" "d.get('conflicts_total')")
BAD_UNCL=$(read_state "$BAD_STATE" "d.get('conflicts_unclassified')")
BAD_RESV=$(read_state "$BAD_STATE" "d.get('conflicts_resolved')")
note "bad: status=$BAD_STATUS total=$BAD_TOTAL unclassified=$BAD_UNCL resolved=$BAD_RESV"
[ "$BAD_STATUS" = "WARN" ] || fail "bad: status expected WARN (non-vacuous), got '$BAD_STATUS'"
[ "$BAD_TOTAL" = "2" ] || fail "bad: conflicts_total expected 2, got '$BAD_TOTAL'"
[ "$BAD_UNCL" = "1" ] || fail "bad: conflicts_unclassified expected 1, got '$BAD_UNCL'"
[ "$BAD_RESV" = "1" ] || fail "bad: conflicts_resolved expected 1, got '$BAD_RESV'"

# ─── GOOD fixture: must PASS (active conflict classified) ────────────────────
note ""
note "=== GOOD fixture (expect PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --quiet
GOOD_STATE="$HERE/good/.mega-sdd/.conflict-classification-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state file not written at $GOOD_STATE"
GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
GOOD_CLASS=$(read_state "$GOOD_STATE" "d.get('conflicts_classified')")
GOOD_UNCL=$(read_state "$GOOD_STATE" "d.get('conflicts_unclassified')")
note "good: status=$GOOD_STATUS classified=$GOOD_CLASS unclassified=$GOOD_UNCL"
[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_CLASS" = "1" ] || fail "good: conflicts_classified expected 1, got '$GOOD_CLASS'"
[ "$GOOD_UNCL" = "0" ] || fail "good: conflicts_unclassified expected 0, got '$GOOD_UNCL'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — validator is non-vacuous: WARNs bad/, PASSes good/."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."
  exit 1
fi
