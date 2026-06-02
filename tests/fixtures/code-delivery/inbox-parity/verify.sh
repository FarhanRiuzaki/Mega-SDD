#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for the inbox-surfacing concern + flow_step:
# applies_when operator (Iter-79 N-1).
#
# Proves the NEW `flow_step:<regex>` operator in validate-sibling-consistency.sh and the
# pack-declared `inbox-surfacing` concern catch a SHARED RUNTIME SIDE-EFFECT parity gap
# (the af49ede defect): two sibling workflow units both cite the "Update
# workflow_assignments" flow step, but only one declares the advanceAssignments mechanism.
#   - bad/  : U-002 omits the mechanism while sibling U-001 declares it → FAIL (1 inconsistent)
#   - good/ : both declare it → PASS
#
# Run: bash tests/fixtures/code-delivery/inbox-parity/verify.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-sibling-consistency.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }

[ -f "$VALIDATOR" ] || { fail "validate-sibling-consistency.sh not found"; exit 1; }

read_state() { python3 -c "
import json,sys
try:
    d=json.load(open('$1'))
    print($2)
except Exception as e:
    print('ERR:'+str(e))
" 2>/dev/null; }

note "=== BAD fixture (expect FAIL: 1 inbox-surfacing divergence, U-002) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --quiet
BAD_STATE="$HERE/bad/.mega-sdd/.sibling-consistency-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state file not written"
BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_INCON=$(read_state "$BAD_STATE" "d['summary']['inconsistent_count']")
BAD_CONCERN=$(read_state "$BAD_STATE" "(d['inconsistent'][0]['concern'] if d['inconsistent'] else '-')")
BAD_UNIT=$(read_state "$BAD_STATE" "(d['inconsistent'][0]['unit'] if d['inconsistent'] else '-')")
note "bad: status=$BAD_STATUS inconsistent=$BAD_INCON unit=$BAD_UNIT concern=$BAD_CONCERN"
[ "$BAD_STATUS" = "FAIL" ] || fail "bad: status expected FAIL, got '$BAD_STATUS'"
[ "$BAD_INCON" = "1" ] || fail "bad: inconsistent expected 1, got '$BAD_INCON'"
[ "$BAD_CONCERN" = "inbox-surfacing" ] || fail "bad: concern expected inbox-surfacing, got '$BAD_CONCERN'"
[ "$BAD_UNIT" = "U-002" ] || fail "bad: flagged unit expected U-002, got '$BAD_UNIT'"

note ""
note "=== GOOD fixture (expect PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --quiet
GOOD_STATE="$HERE/good/.mega-sdd/.sibling-consistency-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state file not written"
GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
GOOD_INCON=$(read_state "$GOOD_STATE" "d['summary']['inconsistent_count']")
note "good: status=$GOOD_STATUS inconsistent=$GOOD_INCON"
[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_INCON" = "0" ] || fail "good: inconsistent expected 0, got '$GOOD_INCON'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — flow_step: operator + inbox-surfacing concern flag bad/, pass good/."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."
  exit 1
fi
