#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for validate-fanout-parity.sh (Iter-79 A2).
#
# Proves the fan-out parity gate catches "LC is always the survivor": among view-bearing
# siblings, an obligation one sibling declares but a peer omits is flagged.
#   - bad/  : U-002 (view-bearing) lacks the `## UI contract` + render test that survivor
#             U-001 declares → FAIL, 2 divergences (ui_contract + render_test).
#   - good/ : both siblings declare both → PASS.
#
# Run: bash tests/fixtures/code-delivery/fanout-parity/verify.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-fanout-parity.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }

[ -f "$VALIDATOR" ] || { fail "validate-fanout-parity.sh not found"; exit 1; }

read_state() { python3 -c "
import json,sys
try:
    d=json.load(open('$1'))
    print($2)
except Exception as e:
    print('ERR:'+str(e))
" 2>/dev/null; }

note "=== BAD fixture (expect FAIL: 2 divergences on U-002) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --quiet
BAD_EXIT=$?
BAD_STATE="$HERE/bad/.mega-sdd/.fanout-parity-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state file not written"
BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_CNT=$(read_state "$BAD_STATE" "d['summary']['divergence_count']")
BAD_OBLIG=$(read_state "$BAD_STATE" "','.join(sorted(x['obligation'] for x in d['divergences']))")
note "bad: status=$BAD_STATUS exit=$BAD_EXIT divergences=$BAD_CNT obligations=$BAD_OBLIG"
[ "$BAD_STATUS" = "FAIL" ] || fail "bad: status expected FAIL, got '$BAD_STATUS'"
[ "$BAD_EXIT" = "1" ] || fail "bad: exit expected 1, got '$BAD_EXIT'"
[ "$BAD_CNT" = "2" ] || fail "bad: divergence_count expected 2, got '$BAD_CNT'"
[ "$BAD_OBLIG" = "render_test,ui_contract" ] || fail "bad: obligations expected render_test,ui_contract, got '$BAD_OBLIG'"

note ""
note "=== GOOD fixture (expect PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --quiet
GOOD_EXIT=$?
GOOD_STATE="$HERE/good/.mega-sdd/.fanout-parity-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state file not written"
GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
GOOD_CNT=$(read_state "$GOOD_STATE" "d['summary']['divergence_count']")
note "good: status=$GOOD_STATUS exit=$GOOD_EXIT divergences=$GOOD_CNT"
[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_EXIT" = "0" ] || fail "good: exit expected 0, got '$GOOD_EXIT'"
[ "$GOOD_CNT" = "0" ] || fail "good: divergence_count expected 0, got '$GOOD_CNT'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — fan-out parity flags bad/, passes good/."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."
  exit 1
fi
