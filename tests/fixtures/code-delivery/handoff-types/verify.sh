#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for the typed next_action.confidence + conditional
# type checks in validate-handoff-yaml.sh (Iter-79 O-3/O-4).
#
# Promotes confidence from a prose/chat string to a TYPED, validated handoff field
# (the F4 foundation the iter-33 audit found missing). Parser-tolerant; fires only on a
# PRESENT field of the wrong shape (never required-on-absence → cannot break a live chain).
#   - bad/  : next_action.confidence: 1.5 (out of [0,1]) → FAIL handoff_type_mismatch
#   - good/ : next_action.confidence: 0.92 → PASS
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-handoff-yaml.sh"
FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }
[ -f "$VALIDATOR" ] || { fail "validate-handoff-yaml.sh not found"; exit 1; }
jget() { python3 -c "import json,sys;d=json.load(sys.stdin);print($1)" 2>/dev/null; }

note "=== BAD (expect FAIL handoff_type_mismatch: confidence 1.5) ==="
BAD_OUT=$(bash "$VALIDATOR" --cwd="$HERE/bad" --response-file="$HERE/bad/handoff.txt" 2>&1)
BAD_STATUS=$(printf '%s' "$BAD_OUT" | jget "d['status']")
BAD_HALT=$(printf '%s' "$BAD_OUT" | jget "d.get('halt_type','-')")
BAD_HASCONF=$(printf '%s' "$BAD_OUT" | jget "str(any('confidence' in e for e in d.get('details',{}).get('type_errors',[])))")
note "bad: status=$BAD_STATUS halt=$BAD_HALT confidence_flagged=$BAD_HASCONF"
[ "$BAD_STATUS" = "FAIL" ] || fail "bad: status expected FAIL, got '$BAD_STATUS'"
[ "$BAD_HALT" = "handoff_type_mismatch" ] || fail "bad: halt_type expected handoff_type_mismatch, got '$BAD_HALT'"
[ "$BAD_HASCONF" = "True" ] || fail "bad: expected a confidence type error"

note ""
note "=== GOOD (expect PASS) ==="
GOOD_OUT=$(bash "$VALIDATOR" --cwd="$HERE/good" --response-file="$HERE/good/handoff.txt" 2>&1)
GOOD_STATUS=$(printf '%s' "$GOOD_OUT" | jget "d['status']")
note "good: status=$GOOD_STATUS"
[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"

note ""
if [ "$FAILED" -eq 0 ]; then note "ALL ASSERTIONS PASS — confidence typed+validated; bad/ FAILs, good/ PASSes."; exit 0
else note "VERIFY FAILED."; exit 1; fi
