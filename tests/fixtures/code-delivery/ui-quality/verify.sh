#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for the UI scaffold-tells quality gate (Task E).
#
# Asserts validate-ui-quality.sh FLAGS the bad/ fixture (a Blade view carrying raw
# scaffold tells — a Controller-class page title, "Customer Id"/"Branch Id" labels,
# raw UUID FK echoes, an unformatted money field, and a native confirm() dialog) and
# PASSES the good/ fixture (humanized labels, FKs resolved via relations, number_format,
# app layout + responsive grid, SweetAlert instead of native dialog).
#
# VACUOUS-PASS GUARD: both fixtures are rooted with .mega-sdd/codebase/
# starterkit-context.yaml (framework_pack: laravel-base-26) and a real view under
# resources/views/, so the pack resolves AND view_glob matches. Each assertion checks
# views_scanned >= 1, so a green result proves a real scan — not a SKIP masquerading
# as exit 0.
#
# Run: bash tests/fixtures/code-delivery/ui-quality/verify.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-ui-quality.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }

if [ ! -f "$VALIDATOR" ]; then
  fail "validate-ui-quality.sh not found at $VALIDATOR"
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

# ─── BAD fixture: must FAIL with the expected scaffold tells ─────────────────
note "=== BAD fixture (expect FAIL: 5 scaffold tells) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --quiet
BAD_EXIT=$?
BAD_STATE="$HERE/bad/.mega-sdd/.ui-quality-blockers.json"
[ -f "$BAD_STATE" ] || fail "bad: state file not written at $BAD_STATE"

BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_SCANNED=$(read_state "$BAD_STATE" "d.get('views_scanned',0)")
BAD_TELLS=$(read_state "$BAD_STATE" "sorted({v['id'] for v in d.get('violations',[]) if v.get('kind')=='scaffold_tell'})")
note "bad: status=$BAD_STATUS exit=$BAD_EXIT views_scanned=$BAD_SCANNED"
note "bad: tells matched = $BAD_TELLS"

[ "$BAD_STATUS" = "FAIL" ] || fail "bad: status expected FAIL, got '$BAD_STATUS'"
[ "$BAD_EXIT" = "1" ] || fail "bad: exit expected 1 (FAIL), got '$BAD_EXIT'"
[ "$BAD_SCANNED" -ge 1 ] 2>/dev/null || fail "bad: views_scanned expected >=1 (real scan, not SKIP), got '$BAD_SCANNED'"

for tid in title-is-controller label-is-column-id raw-uuid-fk money-without-format native-alert; do
  HIT=$(read_state "$BAD_STATE" "sum(1 for v in d.get('violations',[]) if v.get('id')=='$tid')")
  if [ "$HIT" = "0" ] || [ "$HIT" = "ERR:"* ]; then
    fail "bad: expected scaffold_tell '$tid' to fire, but it did not"
  else
    note "  OK tell fired: $tid (x$HIT)"
  fi
done

# ─── GOOD fixture: must PASS, no violations, real scan ──────────────────────
note ""
note "=== GOOD fixture (expect PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --quiet
GOOD_EXIT=$?
GOOD_STATE="$HERE/good/.mega-sdd/.ui-quality-blockers.json"
[ -f "$GOOD_STATE" ] || fail "good: state file not written at $GOOD_STATE"

GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
GOOD_SCANNED=$(read_state "$GOOD_STATE" "d.get('views_scanned',0)")
GOOD_VIOL=$(read_state "$GOOD_STATE" "len(d.get('violations',[]))")
note "good: status=$GOOD_STATUS exit=$GOOD_EXIT views_scanned=$GOOD_SCANNED violations=$GOOD_VIOL"

[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_EXIT" = "0" ] || fail "good: exit expected 0 (PASS), got '$GOOD_EXIT'"
[ "$GOOD_SCANNED" -ge 1 ] 2>/dev/null || fail "good: views_scanned expected >=1 (real scan, not SKIP), got '$GOOD_SCANNED'"
[ "$GOOD_VIOL" = "0" ] || fail "good: violations expected 0, got '$GOOD_VIOL'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — validator flags bad/, passes good/ (both via a real scan)."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."
  exit 1
fi
