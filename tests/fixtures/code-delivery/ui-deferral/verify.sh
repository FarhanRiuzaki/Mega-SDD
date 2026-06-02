#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for validate-ui-deferral.sh (Iter-79 B1).
#
# Proves the gate catches the sanctioned UI-deferral bypass — a bolt-report that defers a
# unit's `## UI contract` to a future polish unit ("scaffold kept; UI polish deferred").
#   - bad/  : U-001 has a `## UI contract`; its bolt-report defers it on a view → FAIL (1).
#   - good/ : same unit; bolt-report realizes the contract, no deferral → PASS.
#
# Run: bash tests/fixtures/code-delivery/ui-deferral/verify.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-ui-deferral.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }

[ -f "$VALIDATOR" ] || { fail "validate-ui-deferral.sh not found"; exit 1; }

read_state() { python3 -c "
import json,sys
try:
    d=json.load(open('$1'))
    print($2)
except Exception as e:
    print('ERR:'+str(e))
" 2>/dev/null; }

note "=== BAD fixture (expect FAIL: 1 ui_obligation_deferred on U-001) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --quiet
BAD_EXIT=$?
BAD_STATE="$HERE/bad/.mega-sdd/.ui-deferral-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state file not written"
BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_CNT=$(read_state "$BAD_STATE" "d['summary']['deferral_count']")
BAD_UNIT=$(read_state "$BAD_STATE" "(d['deferrals'][0]['unit'] if d['deferrals'] else '-')")
note "bad: status=$BAD_STATUS exit=$BAD_EXIT deferrals=$BAD_CNT unit=$BAD_UNIT"
[ "$BAD_STATUS" = "FAIL" ] || fail "bad: status expected FAIL, got '$BAD_STATUS'"
[ "$BAD_EXIT" = "1" ] || fail "bad: exit expected 1, got '$BAD_EXIT'"
[ "$BAD_CNT" = "1" ] || fail "bad: deferral_count expected 1, got '$BAD_CNT'"
[ "$BAD_UNIT" = "U-001" ] || fail "bad: flagged unit expected U-001, got '$BAD_UNIT'"

note ""
note "=== GOOD fixture (expect PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --quiet
GOOD_EXIT=$?
GOOD_STATE="$HERE/good/.mega-sdd/.ui-deferral-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state file not written"
GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
GOOD_CNT=$(read_state "$GOOD_STATE" "d['summary']['deferral_count']")
note "good: status=$GOOD_STATUS exit=$GOOD_EXIT deferrals=$GOOD_CNT"
[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_EXIT" = "0" ] || fail "good: exit expected 0, got '$GOOD_EXIT'"
[ "$GOOD_CNT" = "0" ] || fail "good: deferral_count expected 0, got '$GOOD_CNT'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — UI-deferral flags bad/, passes good/."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."
  exit 1
fi
