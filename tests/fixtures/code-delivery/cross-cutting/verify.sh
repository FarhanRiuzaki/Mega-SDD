#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for validate-cross-cutting-registration.sh (Task C).
#
# Asserts the validator FLAGS the bad/ fixture (5 model SOURCE files that reference the
# BranchScoped global scope + carry branch_id but never call addGlobalScope(new BranchScoped)
# in booted() — the 2bdfc1b execution-fidelity defect) and PASSES the good/ fixture (all 5
# register the scope). The Scope DEFINITION file (app/Models/Scopes/BranchScoped.php) carries
# no tenant key and MUST NOT be flagged (no false positive).
#
# Run: bash tests/fixtures/code-delivery/cross-cutting/verify.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-cross-cutting-registration.sh"
FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }
if [ ! -f "$VALIDATOR" ]; then fail "validate-cross-cutting-registration.sh not found at $VALIDATOR"; exit 1; fi
read_state() { python3 -c "
import json
try:
    d=json.load(open('$1')); print($2)
except Exception as e:
    print('ERR:'+str(e))
" 2>/dev/null; }

note "=== BAD fixture (expect FAIL: 5 missing_registration, decoy NOT flagged) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --quiet
BAD_EXIT=$?
BAD_STATE="$HERE/bad/.mega-sdd/.cross-cutting-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state file not written"
BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_MISS=$(read_state "$BAD_STATE" "len(d.get('missing_registration',[]))")
BAD_DECOY=$(read_state "$BAD_STATE" "sum(1 for x in d.get('missing_registration',[]) if 'Scopes/' in x.get('file',''))")
note "bad: status=$BAD_STATUS exit=$BAD_EXIT missing_registration=$BAD_MISS decoy_flagged=$BAD_DECOY"
[ "$BAD_STATUS" = "FAIL" ] || fail "bad: status expected FAIL, got '$BAD_STATUS'"
[ "$BAD_EXIT" = "1" ] || fail "bad: exit expected 1, got '$BAD_EXIT'"
[ "$BAD_MISS" = "5" ] || fail "bad: missing_registration expected 5, got '$BAD_MISS'"
[ "$BAD_DECOY" = "0" ] || fail "bad: the Scope DEFINITION must NOT be flagged (false positive), got $BAD_DECOY"

note ""
note "=== GOOD fixture (expect PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --quiet
GOOD_EXIT=$?
GOOD_STATE="$HERE/good/.mega-sdd/.cross-cutting-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state file not written"
GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
GOOD_MISS=$(read_state "$GOOD_STATE" "len(d.get('missing_registration',[]))")
note "good: status=$GOOD_STATUS exit=$GOOD_EXIT missing_registration=$GOOD_MISS"
[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_EXIT" = "0" ] || fail "good: exit expected 0, got '$GOOD_EXIT'"
[ "$GOOD_MISS" = "0" ] || fail "good: missing_registration expected 0, got '$GOOD_MISS'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — validator flags bad/ source, passes good/, decoy excluded."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."; exit 1
fi
