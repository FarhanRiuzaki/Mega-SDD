#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for validate-flow-coverage.sh (Task A).
#
# Asserts the validator FLAGS the bad/ fixture (2 missing Form Requests +
# 1 dead edit.blade.php scaffold stub) and PASSES the good/ fixture.
#
# Run: bash tests/fixtures/code-delivery/flow-coverage/verify.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-flow-coverage.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }

if [ ! -f "$VALIDATOR" ]; then
  fail "validate-flow-coverage.sh not found at $VALIDATOR"
  exit 1
fi

# Read a key out of a state file via python3.
read_state() { # <state_file> <python-expr-on-d>
  python3 -c "
import json,sys
try:
    d=json.load(open('$1'))
    print($2)
except Exception as e:
    print('ERR:'+str(e))
" 2>/dev/null
}

# ─── BAD fixture: must FAIL, flag 2 missing FRs + 1 dead stub ────────────────
note "=== BAD fixture (expect FAIL: 2 missing FRs + 1 dead stub) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --quiet
BAD_EXIT=$?
BAD_STATE="$HERE/bad/.mega-sdd/.flow-coverage-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state file not written at $BAD_STATE"

BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_MISSING=$(read_state "$BAD_STATE" "sum(m.get('shortfall',1) for m in d.get('missing_artifacts',[]))")
BAD_DEAD=$(read_state "$BAD_STATE" "len(d.get('dead_scaffold',[]))")
note "bad: status=$BAD_STATUS exit=$BAD_EXIT missing_FRs=$BAD_MISSING dead_stubs=$BAD_DEAD"

[ "$BAD_STATUS" = "FAIL" ] || fail "bad: status expected FAIL, got '$BAD_STATUS'"
[ "$BAD_EXIT" = "1" ] || fail "bad: exit expected 1 (FAIL), got '$BAD_EXIT'"
[ "$BAD_MISSING" = "2" ] || fail "bad: missing Form Requests expected 2, got '$BAD_MISSING'"
[ "$BAD_DEAD" = "1" ] || fail "bad: dead scaffold stubs expected 1, got '$BAD_DEAD'"

# ─── GOOD fixture: must PASS, no missing / no dead ───────────────────────────
note ""
note "=== GOOD fixture (expect PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --quiet
GOOD_EXIT=$?
GOOD_STATE="$HERE/good/.mega-sdd/.flow-coverage-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state file not written at $GOOD_STATE"

GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
GOOD_MISSING=$(read_state "$GOOD_STATE" "len(d.get('missing_artifacts',[]))")
GOOD_DEAD=$(read_state "$GOOD_STATE" "len(d.get('dead_scaffold',[]))")
note "good: status=$GOOD_STATUS exit=$GOOD_EXIT missing=$GOOD_MISSING dead=$GOOD_DEAD"

[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_EXIT" = "0" ] || fail "good: exit expected 0 (PASS), got '$GOOD_EXIT'"
[ "$GOOD_MISSING" = "0" ] || fail "good: missing_artifacts expected 0, got '$GOOD_MISSING'"
[ "$GOOD_DEAD" = "0" ] || fail "good: dead_scaffold expected 0, got '$GOOD_DEAD'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — validator flags bad/, passes good/."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."
  exit 1
fi
