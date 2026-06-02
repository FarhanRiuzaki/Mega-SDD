#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for the decomposition-altitude signal in
# validate-flow-coverage.sh (Iter-79 A1).
#
# ADVISORY signal (does NOT flip status — symptom gates already neutralize damage):
#   - bad/  : a 4-input-step flow absorbed by ONE unit → status PASS but
#             altitude_concentration_count=1 (decomposition_altitude_high).
#   - good/ : same flow split across two units → altitude_concentration_count=0.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-flow-coverage.sh"
FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }
[ -f "$VALIDATOR" ] || { fail "validate-flow-coverage.sh not found"; exit 1; }
read_state() { python3 -c "
import json,sys
try: d=json.load(open('$1')); print($2)
except Exception as e: print('ERR:'+str(e))
" 2>/dev/null; }

note "=== BAD (expect altitude_concentration_count=1, status PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --quiet
BAD_STATE="$HERE/bad/.mega-sdd/.flow-coverage-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state not written"
BAD_ALT=$(read_state "$BAD_STATE" "d['summary']['altitude_concentration_count']")
BAD_UNIT=$(read_state "$BAD_STATE" "(d['altitude_concentration'][0]['absorbing_unit'] if d.get('altitude_concentration') else '-')")
note "bad: altitude=$BAD_ALT absorbing_unit=$BAD_UNIT"
[ "$BAD_ALT" = "1" ] || fail "bad: altitude_concentration_count expected 1, got '$BAD_ALT'"
[ "$BAD_UNIT" = "U-001" ] || fail "bad: absorbing_unit expected U-001, got '$BAD_UNIT'"

note ""
note "=== GOOD (expect altitude_concentration_count=0) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --quiet
GOOD_STATE="$HERE/good/.mega-sdd/.flow-coverage-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state not written"
GOOD_ALT=$(read_state "$GOOD_STATE" "d['summary']['altitude_concentration_count']")
note "good: altitude=$GOOD_ALT"
[ "$GOOD_ALT" = "0" ] || fail "good: altitude_concentration_count expected 0, got '$GOOD_ALT'"

note ""
if [ "$FAILED" -eq 0 ]; then note "ALL ASSERTIONS PASS — altitude signal flags bad/, clears good/."; exit 0
else note "VERIFY FAILED."; exit 1; fi
