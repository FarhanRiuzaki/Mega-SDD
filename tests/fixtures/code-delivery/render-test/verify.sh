#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for the render-test-per-module gate (Task D).
#
# Asserts validate-unit-spec.sh FLAGS the bad/ fixture (a unit shipping a
# resources/views/**/show.blade.php detail view with NO acceptance_test of
# type `render` => render_test_missing) and PASSES the good/ fixture (same unit
# WITH a structured `type: render` acceptance_test).
#
# Detection must be STRUCTURED, not fuzzy: the bad fixture carries a PROSE test
# bullet named `test_show_route_renders_for_an_existing_widget` to prove a
# grep-for-"render" would false-negative — only a structured acceptance_test
# entry satisfies the gate.
#
# Run: bash tests/fixtures/code-delivery/render-test/verify.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-unit-spec.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }

if [ ! -f "$VALIDATOR" ]; then
  fail "validate-unit-spec.sh not found at $VALIDATOR"
  exit 1
fi

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

# ─── BAD fixture: must FAIL with a render_test_missing issue ─────────────────
note "=== BAD fixture (expect FAIL: render_test_missing) ==="
BAD_UNIT="$HERE/bad/.mega-sdd/vaults/demo-phase/units/U-001.md"
bash "$VALIDATOR" --cwd="$HERE/bad" --file-path="$BAD_UNIT" --quiet
BAD_EXIT=$?
BAD_STATE="$HERE/bad/.mega-sdd/.unit-spec-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state file not written at $BAD_STATE"

BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_RENDER=$(read_state "$BAD_STATE" "sum(1 for i in d.get('issues',[]) if i.get('halt_type')=='render_test_missing')")
note "bad: status=$BAD_STATUS exit=$BAD_EXIT render_test_missing=$BAD_RENDER"

[ "$BAD_STATUS" = "FAIL" ] || fail "bad: status expected FAIL, got '$BAD_STATUS'"
[ "$BAD_EXIT" = "1" ] || fail "bad: exit expected 1 (FAIL), got '$BAD_EXIT'"
[ "$BAD_RENDER" = "1" ] || fail "bad: render_test_missing issue expected 1, got '$BAD_RENDER'"

# ─── GOOD fixture: must PASS, no render_test_missing ────────────────────────
note ""
note "=== GOOD fixture (expect PASS) ==="
GOOD_UNIT="$HERE/good/.mega-sdd/vaults/demo-phase/units/U-001.md"
bash "$VALIDATOR" --cwd="$HERE/good" --file-path="$GOOD_UNIT" --quiet
GOOD_EXIT=$?
GOOD_STATE="$HERE/good/.mega-sdd/.unit-spec-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state file not written at $GOOD_STATE"

GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
GOOD_RENDER=$(read_state "$GOOD_STATE" "sum(1 for i in d.get('issues',[]) if i.get('halt_type')=='render_test_missing')")
note "good: status=$GOOD_STATUS exit=$GOOD_EXIT render_test_missing=$GOOD_RENDER"

[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_EXIT" = "0" ] || fail "good: exit expected 0 (PASS), got '$GOOD_EXIT'"
[ "$GOOD_RENDER" = "0" ] || fail "good: render_test_missing expected 0, got '$GOOD_RENDER'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — validator flags bad/, passes good/."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."
  exit 1
fi
