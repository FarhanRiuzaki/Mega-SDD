#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for the operator-workflow-UX rails added to
# validate-vault-oqs.sh (Task G).
#
# Asserts the validator FLAGS the bad/ fixture (workflow flow present, no
# operator-surface requirement, no Design-Source OQ -> operator_surface_missing)
# and PASSES the good/ fixture (operator surface present + a Design-Source OQ).
#
# Run: bash tests/fixtures/code-delivery/operator-ux/verify.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-vault-oqs.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }

if [ ! -f "$VALIDATOR" ]; then
  fail "validate-vault-oqs.sh not found at $VALIDATOR"
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

# ─── BAD fixture: must FAIL, flag operator_surface_missing ──────────────────
note "=== BAD fixture (expect FAIL: operator_surface_missing) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" \
  --file-path="$HERE/bad/.mega-sdd/vaults/demo-phase/vault.json" --quiet
BAD_EXIT=$?
BAD_STATE="$HERE/bad/.mega-sdd/.vault-oqs-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state file not written at $BAD_STATE"

BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_OPSURF=$(read_state "$BAD_STATE" "sum(1 for i in d.get('issues',[]) if i.get('halt_type')=='operator_surface_missing')")
note "bad: status=$BAD_STATUS exit=$BAD_EXIT operator_surface_missing=$BAD_OPSURF"

[ "$BAD_STATUS" = "FAIL" ] || fail "bad: status expected FAIL, got '$BAD_STATUS'"
[ "$BAD_EXIT" = "1" ] || fail "bad: exit expected 1 (FAIL), got '$BAD_EXIT'"
[ "$BAD_OPSURF" = "1" ] || fail "bad: operator_surface_missing expected 1, got '$BAD_OPSURF'"

# ─── GOOD fixture: must PASS (operator surface + Design-Source OQ) ───────────
note ""
note "=== GOOD fixture (expect PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" \
  --file-path="$HERE/good/.mega-sdd/vaults/demo-phase/vault.json" --quiet
GOOD_EXIT=$?
GOOD_STATE="$HERE/good/.mega-sdd/.vault-oqs-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state file not written at $GOOD_STATE"

GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
GOOD_OPSURF=$(read_state "$GOOD_STATE" "sum(1 for i in d.get('issues',[]) if i.get('halt_type') in ('operator_surface_missing','design_source_oq_missing'))")
note "good: status=$GOOD_STATUS exit=$GOOD_EXIT operator/design issues=$GOOD_OPSURF"

[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_EXIT" = "0" ] || fail "good: exit expected 0 (PASS), got '$GOOD_EXIT'"
[ "$GOOD_OPSURF" = "0" ] || fail "good: operator/design issues expected 0, got '$GOOD_OPSURF'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — validator flags bad/, passes good/."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."
  exit 1
fi
