#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for validate-preflight.sh (Iter-79 O-1, F2 closure).
#
# Predictive preflight: a fatal INPUT-precondition for the skill about to run is caught
# BEFORE the skill burns time and halts mid-way.
#   - bad/  : execute-bolts with a vault but NO units → FATAL (bolts_units_missing, exit 1)
#   - good/ : execute-bolts with units present → PASS (exit 0)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-preflight.sh"
FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }
[ -f "$VALIDATOR" ] || { fail "validate-preflight.sh not found"; exit 1; }
read_state() { python3 -c "
import json,sys
try: d=json.load(open('$1')); print($2)
except Exception as e: print('ERR:'+str(e))
" 2>/dev/null; }

note "=== BAD (execute-bolts, no units → FATAL) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --skill=mega-sdd:execute-bolts --quiet
BAD_EXIT=$?
BAD_STATE="$HERE/bad/.mega-sdd/.preflight-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state not written"
BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_CHECK=$(read_state "$BAD_STATE" "d.get('fatal_check_id')")
note "bad: status=$BAD_STATUS exit=$BAD_EXIT fatal_check_id=$BAD_CHECK"
[ "$BAD_STATUS" = "FATAL" ] || fail "bad: status expected FATAL, got '$BAD_STATUS'"
[ "$BAD_EXIT" = "1" ] || fail "bad: exit expected 1, got '$BAD_EXIT'"
[ "$BAD_CHECK" = "bolts_units_missing" ] || fail "bad: fatal_check_id expected bolts_units_missing, got '$BAD_CHECK'"

note ""
note "=== GOOD (execute-bolts, units present → PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --skill=mega-sdd:execute-bolts --quiet
GOOD_EXIT=$?
GOOD_STATE="$HERE/good/.mega-sdd/.preflight-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state not written"
GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
note "good: status=$GOOD_STATUS exit=$GOOD_EXIT"
[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_EXIT" = "0" ] || fail "good: exit expected 0, got '$GOOD_EXIT'"

note ""
if [ "$FAILED" -eq 0 ]; then note "ALL ASSERTIONS PASS — preflight FATALs bad/, PASSes good/."; exit 0
else note "VERIFY FAILED."; exit 1; fi
