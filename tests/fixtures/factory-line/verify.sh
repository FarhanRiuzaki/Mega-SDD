#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for validate-factory-ledger.sh.
# Asserts: good/ PASS+converged; schema-bad/ FAIL(ledger_schema); cap-bad/ FAIL(phase_stuck); spin-bad/ FAIL(anti_spin).
# Run: bash tests/fixtures/factory-line/verify.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-factory-ledger.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }
[ -f "$VALIDATOR" ] || { fail "validate-factory-ledger.sh not found at $VALIDATOR"; exit 1; }

read_state() { # <state_file> <python-expr-on-d>
  python3 -c "
import json
try:
    d=json.load(open('$1')); print($2)
except Exception as e:
    print('ERR:'+str(e))
" 2>/dev/null
}

check() { # <case-dir> <expect-status> <expect-exit> <expect-halt-or-EMPTY>
  local dir="$1" exp_status="$2" exp_exit="$3" exp_halt="$4"
  bash "$VALIDATOR" --cwd="$HERE/$dir" --quiet; local code=$?
  local sf="$HERE/$dir/.mega-sdd/.factory-ledger-state.json"
  [ -f "$sf" ] || { fail "$dir: state file not written"; return; }
  local st ht; st=$(read_state "$sf" "d.get('status')"); ht=$(read_state "$sf" "d.get('halt_type')")
  note "$dir: status=$st halt=$ht exit=$code"
  [ "$st" = "$exp_status" ] || fail "$dir: status expected $exp_status, got '$st'"
  [ "$code" = "$exp_exit" ] || fail "$dir: exit expected $exp_exit, got '$code'"
  if [ -n "$exp_halt" ]; then [ "$ht" = "$exp_halt" ] || fail "$dir: halt_type expected $exp_halt, got '$ht'"; fi
}

note "=== good (expect PASS, exit 0) ===";        check good      PASS 0 ""
GOOD_CONV=$(read_state "$HERE/good/.mega-sdd/.factory-ledger-state.json" "d.get('convergence_status')")
[ "$GOOD_CONV" = "done" ] || fail "good: convergence_status expected done, got '$GOOD_CONV'"
note "=== schema-bad (expect FAIL, exit 1) ===";  check schema-bad FAIL 1 ledger_schema
note "=== cap-bad (expect FAIL, exit 1) ===";     check cap-bad    FAIL 1 phase_stuck
note "=== spin-bad (expect FAIL, exit 1) ===";    check spin-bad   FAIL 1 anti_spin
note "=== spin-recover (stall then recover; expect PASS, exit 0, converged) ==="; check spin-recover PASS 0 ""
SR_CONV=$(read_state "$HERE/spin-recover/.mega-sdd/.factory-ledger-state.json" "d.get('convergence_status')")
[ "$SR_CONV" = "done" ] || fail "spin-recover: convergence_status expected done, got '$SR_CONV'"

note ""
[ "$FAILED" -eq 0 ] && { note "ALL ASSERTIONS PASS"; exit 0; } || { note "VERIFY FAILED — see FAIL lines"; exit 1; }
