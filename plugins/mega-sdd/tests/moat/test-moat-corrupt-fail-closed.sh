#!/usr/bin/env bash
# Moat regression (AUDIT Round-2 L4): the binding->units moat state file
# .validation-blockers.json must FAIL CLOSED at the PreToolUse gate when it is
# PRESENT but unparseable (a torn/garbage write must NOT silently open the gate —
# invariant #2). The aggregator's generic loader returns None on any parse error
# and every other gate is fail-open `if d and status==FAIL`; without this fix a
# corrupt moat state would silently pass execute-bolts. Absent (never evaluated)
# must still ALLOW; a valid FAIL must still BLOCK; a valid PASS must ALLOW.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOOK="${PLUGIN_ROOT}/hooks/pre-tool-use"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "${ROOT}/.mega-sdd/vaults/v1/units"
# A unit must exist or the predictive-preflight gate (Branch 0) blocks first,
# before the moat aggregator is reached. Preflight only globs for U-*.md presence.
printf -- '---\nid: U-001\n---\n# U-001\n' > "${ROOT}/.mega-sdd/vaults/v1/units/U-001.md"
STATE="${ROOT}/.mega-sdd/.validation-blockers.json"

run_hook() {
  # A mega-sdd:execute-bolts Skill call from $ROOT — drives the gate aggregator.
  printf '{"cwd": "%s", "tool_name": "Skill", "tool_input": {"skill": "mega-sdd:execute-bolts"}}' "$ROOT" \
    | bash "$HOOK" 2>/dev/null
}
blocked() { printf '%s' "$1" | grep -q '"permissionDecision": "deny"'; }

# --- Case 1 (corrupt): garbage moat state => must BLOCK (fail-closed) ---
printf '{ this is not valid json ]]' > "$STATE"
out=$(run_hook)
blocked "$out" || { echo "FAIL: corrupt moat state did NOT block (fail-open leak)"; echo "out=[$out]"; exit 1; }
printf '%s' "$out" | grep -qi "UNPARSEABLE" || { echo "FAIL: block reason should name the unparseable moat state"; echo "out=[$out]"; exit 1; }
echo "PASS (corrupt moat state fails closed)"

# --- Case 2 (absent): no moat state => must ALLOW (absent != corrupt) ---
rm -f "$STATE"
out=$(run_hook)
blocked "$out" && { echo "FAIL: absent moat state must not block (absent = never evaluated)"; echo "out=[$out]"; exit 1; }
echo "PASS (absent moat state allows — unchanged)"

# --- Case 3 (valid FAIL): status FAIL => must BLOCK (existing behavior intact) ---
printf '{"status": "FAIL", "drops": [{"type": "missing_oq", "oq_id": "OQ-1"}]}' > "$STATE"
out=$(run_hook)
blocked "$out" || { echo "FAIL: valid status:FAIL moat state must block"; echo "out=[$out]"; exit 1; }
echo "PASS (valid FAIL still blocks)"

# --- Case 4 (valid PASS): status PASS => must ALLOW ---
printf '{"status": "PASS", "drops": []}' > "$STATE"
out=$(run_hook)
blocked "$out" && { echo "FAIL: valid status:PASS moat state must not block"; echo "out=[$out]"; exit 1; }
echo "PASS (valid PASS allows)"

echo "ALL PASS"
