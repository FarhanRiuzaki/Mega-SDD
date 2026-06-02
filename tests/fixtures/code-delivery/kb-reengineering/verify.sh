#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for validate-kb-reengineering.sh (Iter-79 U-EI).
#   - bad/  : KB carries mutability markers but no 99-rebuild-architecture/ → WARN
#             (kb_reengineering_missing).
#   - good/ : full synthesis (mutation-policy + erd departures + phasing) → PASS.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-kb-reengineering.sh"
FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }
[ -f "$VALIDATOR" ] || { fail "validate-kb-reengineering.sh not found"; exit 1; }
read_state() { python3 -c "
import json,sys
try: d=json.load(open('$1')); print($2)
except Exception as e: print('ERR:'+str(e))
" 2>/dev/null; }

note "=== BAD (expect WARN: kb_reengineering_missing) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --quiet
BAD_STATE="$HERE/bad/.mega-sdd/.kb-reengineering-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state not written"
BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_MISS=$(read_state "$BAD_STATE" "sum(1 for i in d.get('issues',[]) if i.get('halt_type')=='kb_reengineering_missing')")
note "bad: status=$BAD_STATUS kb_reengineering_missing=$BAD_MISS"
[ "$BAD_STATUS" = "WARN" ] || fail "bad: status expected WARN, got '$BAD_STATUS'"
[ "$BAD_MISS" = "1" ] || fail "bad: kb_reengineering_missing expected 1, got '$BAD_MISS'"

note ""
note "=== GOOD (expect PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --quiet
GOOD_STATE="$HERE/good/.mega-sdd/.kb-reengineering-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state not written"
GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
note "good: status=$GOOD_STATUS"
[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"

note ""
if [ "$FAILED" -eq 0 ]; then note "ALL ASSERTIONS PASS — kb-reengineering WARNs bad/, PASSes good/."; exit 0
else note "VERIFY FAILED."; exit 1; fi
