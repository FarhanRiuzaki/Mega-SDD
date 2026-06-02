#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for the oq_misclassified_tech check in
# validate-vault-oqs.sh (Iter-79 U-GI).
#
# Proves the validator now independently re-applies the Auto-classifier heuristic table to
# EVERY OQ (not just already-[tech]-tagged ones), catching a tech-reading OQ lazily tagged
# business:
#   - bad/  : OQ "what test framework…" tagged [business] → oq_misclassified_tech (FAIL)
#   - good/ : same OQ tagged [tech] + mode: scan + scan_target → no mis-tag (PASS)
#
# Run: bash tests/fixtures/code-delivery/oq-misclassify/verify.sh

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-vault-oqs.sh"
FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }
[ -f "$VALIDATOR" ] || { fail "validate-vault-oqs.sh not found"; exit 1; }
read_state() { python3 -c "
import json,sys
try: d=json.load(open('$1')); print($2)
except Exception as e: print('ERR:'+str(e))
" 2>/dev/null; }

ARCH="vaults/demo-phase/02-architecture.md"

note "=== BAD (expect oq_misclassified_tech present) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --file-path="$HERE/bad/.mega-sdd/$ARCH" --quiet
BAD_STATE="$HERE/bad/.mega-sdd/.vault-oqs-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state not written"
BAD_MIS=$(read_state "$BAD_STATE" "sum(1 for i in d.get('issues',[]) if i.get('halt_type')=='oq_misclassified_tech')")
note "bad: oq_misclassified_tech=$BAD_MIS"
[ "$BAD_MIS" = "1" ] || fail "bad: oq_misclassified_tech expected 1, got '$BAD_MIS'"

note ""
note "=== GOOD (expect no oq_misclassified_tech) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --file-path="$HERE/good/.mega-sdd/$ARCH" --quiet
GOOD_STATE="$HERE/good/.mega-sdd/.vault-oqs-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state not written"
GOOD_MIS=$(read_state "$GOOD_STATE" "sum(1 for i in d.get('issues',[]) if i.get('halt_type')=='oq_misclassified_tech')")
GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
note "good: status=$GOOD_STATUS oq_misclassified_tech=$GOOD_MIS"
[ "$GOOD_MIS" = "0" ] || fail "good: oq_misclassified_tech expected 0, got '$GOOD_MIS'"
[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — oq_misclassified_tech flags bad/, clears good/."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."; exit 1
fi
