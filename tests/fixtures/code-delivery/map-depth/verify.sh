#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for the depth check in validate-codebase-map.sh
# (Iter-79 U-SC).
#
# The map's only consumer (bind-codebase field-level diff) needs precision_tier: ast +
# signature-bearing §2 rows; the prior validator checked §2 ROW COUNT only. New advisory
# depth check:
#   - bad/  : precision_tier: ast but §2 rows are bare symbol names → WARN
#             (codebase_map_depth_claim_unmet)
#   - good/ : precision_tier: ast with signature-bearing §2 rows → PASS (interface_depth PASS)
#
# Run: bash tests/fixtures/code-delivery/map-depth/verify.sh

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-codebase-map.sh"
FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }
[ -f "$VALIDATOR" ] || { fail "validate-codebase-map.sh not found"; exit 1; }
read_state() { python3 -c "
import json,sys
try: d=json.load(open('$1')); print($2)
except Exception as e: print('ERR:'+str(e))
" 2>/dev/null; }

note "=== BAD (expect codebase_map_depth_claim_unmet) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --quiet
BAD_STATE="$HERE/bad/.mega-sdd/.codebase-map-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state not written"
BAD_DEPTH=$(read_state "$BAD_STATE" "sum(1 for i in d.get('issues',[]) if i.get('halt_type')=='codebase_map_depth_claim_unmet')")
note "bad: depth_claim_unmet=$BAD_DEPTH"
[ "$BAD_DEPTH" = "1" ] || fail "bad: codebase_map_depth_claim_unmet expected 1, got '$BAD_DEPTH'"

note ""
note "=== GOOD (expect interface_depth PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --quiet
GOOD_STATE="$HERE/good/.mega-sdd/.codebase-map-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state not written"
GOOD_DEPTH=$(read_state "$GOOD_STATE" "next((c['status'] for c in d.get('checks',[]) if c['check']=='interface_depth'),'-')")
note "good: interface_depth=$GOOD_DEPTH"
[ "$GOOD_DEPTH" = "PASS" ] || fail "good: interface_depth expected PASS, got '$GOOD_DEPTH'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — depth check WARNs bad/, PASSes good/."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."; exit 1
fi
