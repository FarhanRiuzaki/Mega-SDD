#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for validate-sibling-consistency.sh (Task B).
#
# Asserts the validator FLAGS the bad/ fixture (1 branch-scoping divergence +
# 3 missing branch() relations across the sibling set) and PASSES the good/
# fixture (uniform BranchScoped trait + branch() relation declared).
#
# Run: bash tests/fixtures/code-delivery/sibling-consistency/verify.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-sibling-consistency.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }

if [ ! -f "$VALIDATOR" ]; then
  fail "validate-sibling-consistency.sh not found at $VALIDATOR"
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

# ─── BAD fixture: must FAIL, flag 1 divergence + 3 missing relations ─────────
note "=== BAD fixture (expect FAIL: 1 inconsistent + 1 missing_relation (cross-sibling divergence)) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --quiet
BAD_EXIT=$?
BAD_STATE="$HERE/bad/.mega-sdd/.sibling-consistency-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state file not written at $BAD_STATE"

BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_INCON=$(read_state "$BAD_STATE" "len(d.get('inconsistent',[]))")
BAD_MISSING=$(read_state "$BAD_STATE" "len(d.get('missing_relations',[]))")
note "bad: status=$BAD_STATUS exit=$BAD_EXIT inconsistent=$BAD_INCON missing_relations=$BAD_MISSING"

[ "$BAD_STATUS" = "FAIL" ] || fail "bad: status expected FAIL, got '$BAD_STATUS'"
[ "$BAD_EXIT" = "1" ] || fail "bad: exit expected 1 (FAIL), got '$BAD_EXIT'"
[ "$BAD_INCON" = "1" ] || fail "bad: inconsistent expected 1, got '$BAD_INCON'"
[ "$BAD_MISSING" = "1" ] || fail "bad: missing_relations expected 1, got '$BAD_MISSING'"

# ─── GOOD fixture: must PASS, no divergence / no missing relation ────────────
note ""
note "=== GOOD fixture (expect PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --quiet
GOOD_EXIT=$?
GOOD_STATE="$HERE/good/.mega-sdd/.sibling-consistency-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state file not written at $GOOD_STATE"

GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
GOOD_INCON=$(read_state "$GOOD_STATE" "len(d.get('inconsistent',[]))")
GOOD_MISSING=$(read_state "$GOOD_STATE" "len(d.get('missing_relations',[]))")
note "good: status=$GOOD_STATUS exit=$GOOD_EXIT inconsistent=$GOOD_INCON missing_relations=$GOOD_MISSING"

[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_EXIT" = "0" ] || fail "good: exit expected 0 (PASS), got '$GOOD_EXIT'"
[ "$GOOD_INCON" = "0" ] || fail "good: inconsistent expected 0, got '$GOOD_INCON'"
[ "$GOOD_MISSING" = "0" ] || fail "good: missing_relations expected 0, got '$GOOD_MISSING'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — validator flags bad/, passes good/."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."
  exit 1
fi
