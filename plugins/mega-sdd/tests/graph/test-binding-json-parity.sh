#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
V="${PLUGIN_ROOT}/scripts/validate-binding-json.sh"
FX="${SCRIPT_DIR}/fixtures"
rc=0

bash "$V" --vault "${FX}/binding-ok" >/dev/null 2>&1
[ $? -eq 0 ] || { echo "FAIL: binding-ok should PASS"; rc=1; }

bash "$V" --vault "${FX}/binding-mismatch" >/dev/null 2>&1
[ $? -eq 2 ] || { echo "FAIL: binding-mismatch should FAIL (exit 2)"; rc=1; }

[ $rc -eq 0 ] && echo "PASS: test-binding-json-parity"
exit $rc
