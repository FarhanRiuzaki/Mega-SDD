#!/usr/bin/env bash
# test-pretooluse-shortcircuit.sh — pins the PreToolUse fast negative short-circuit.
#
# The PreToolUse hook spawns python3 to parse stdin JSON. Because the matcher is
# global (Skill|Bash|Edit|Write), every such tool call in EVERY project paid that
# cold-start, even non-mega-sdd projects where the hook just no-ops. A pure-shell
# negative short-circuit now exits 0 BEFORE the python parse when there is no
# .mega-sdd ancestor.
#
# The short-circuit is MOAT-NEUTRAL ONLY IF it resolves the project root with the
# SAME walk-up the authoritative gate uses (resolve_project_root), not a naive
# ${CWD}/.mega-sdd check. A naive check would WRONGLY short-circuit (and skip the
# gate) whenever the model cd'd into a subfolder of a real mega-sdd project. SC2
# is the regression pin for exactly that moat-breach direction.
#
# CI-safe: bash + python3 only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/pre-tool-use"

[ -f "$HOOK" ] || { echo "FAIL: hook not found at $HOOK"; exit 1; }

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
denied() { printf '%s' "$1" | grep -q '"permissionDecision": "deny"'; }

echo "── PART A: static structure pins ──"
# SC0 — the short-circuit exists AND precedes the python3 parse (else it saves nothing).
SC_LINE=$(grep -n 'Fast negative short-circuit' "$HOOK" | head -1 | cut -d: -f1)
PY_LINE=$(grep -n 'Parse via python3' "$HOOK" | head -1 | cut -d: -f1)
if [ -n "$SC_LINE" ] && [ -n "$PY_LINE" ] && [ "$SC_LINE" -lt "$PY_LINE" ]; then
  pass "SC0: short-circuit precedes the python3 parse (line $SC_LINE < $PY_LINE)"
else
  fail "SC0: short-circuit missing or not before python3 parse (sc='$SC_LINE' py='$PY_LINE')"
fi
# SC0b — it uses the walk-up resolver, not a naive ${CWD}/.mega-sdd check (moat safety).
grep -qF 'resolve_project_root "$SC_CWD"' "$HOOK" \
  && pass "SC0b: short-circuit uses resolve_project_root walk-up (not a naive CWD check)" \
  || fail "SC0b: short-circuit does NOT use the walk-up resolver (moat-breach risk for nested cwd)"
bash -n "$HOOK" && pass "SC0c: pre-tool-use bash -n clean" || fail "SC0c: syntax error after edit"

echo "── PART B: behavioral ──"

# SC1 — no .mega-sdd ancestor → the optimization fires → hook ALLOWS (no deny output).
NOSDD="$(mktemp -d)"
trap 'rm -rf "$NOSDD" "${ROOT:-}"' EXIT
out=$(printf '{"cwd": "%s", "tool_name": "Skill", "tool_input": {"skill": "mega-sdd:execute-bolts"}}' "$NOSDD" \
        | bash "$HOOK" 2>/dev/null)
[ -z "$out" ] && pass "SC1: non-mega-sdd project → hook allows (empty output, no block)" \
  || { fail "SC1: unexpected output in a non-SDD project"; echo "    out=[$out]"; }

# SC2 — MOAT-BREACH GUARD. cwd is a real SUBFOLDER (src/module) under a mega-sdd project
# whose gate FAILs on a REAL violation: a verify+HIGH unit with an ungrounded acceptance
# criterion (A1 / verify_grounding_untrusted). This survives the execute-bolts gate's
# UNCONDITIONAL re-derivation (hook lines ~398-427) — a hand-planted state file would be
# overwritten by that re-derivation before the aggregator reads it, so it can no longer
# prove anything. The short-circuit must NOT exit early; the walk-up must find the ancestor
# .mega-sdd and let the gate BLOCK execute-bolts.
ROOT="$(mktemp -d)"
mkdir -p "$ROOT/.mega-sdd/vaults/v1/units" "$ROOT/src/module"
printf -- '---\nid: U-001\ntitle: Verify widget index renders\ntask_type: verify\ngrounding_confidence: HIGH\nvault_source: 01-entities.md\ntarget_files: []\nacceptance_test: "GET /widgets returns 200"\n---\n# U-001\n\n## Anchors\n- app/Http/Controllers/WidgetController.php:1 - from binding\n\n## Acceptance criteria\n- The widget index lists every active widget [ungrounded]\n' \
  > "$ROOT/.mega-sdd/vaults/v1/units/U-001.md"
SUB="$ROOT/src/module"
out=$(printf '{"cwd": "%s", "tool_name": "Skill", "tool_input": {"skill": "mega-sdd:execute-bolts"}}' "$SUB" \
        | bash "$HOOK" 2>/dev/null)
if denied "$out" && printf '%s' "$out" | grep -q 'grounding_confidence: HIGH'; then
  pass "SC2: nested cwd under .mega-sdd does NOT short-circuit — gate still fires"
else
  fail "SC2: short-circuit WRONGLY bypassed the gate for a nested cwd (moat breach)"; echo "    out=[$out]"
fi

# SC3 — sanity: top-level cwd of the same failing project still blocks (no regression).
out=$(printf '{"cwd": "%s", "tool_name": "Skill", "tool_input": {"skill": "mega-sdd:execute-bolts"}}' "$ROOT" \
        | bash "$HOOK" 2>/dev/null)
denied "$out" && pass "SC3: top-level cwd with failing gate still blocks (no regression)" \
  || { fail "SC3: top-level gate stopped firing after the short-circuit edit"; echo "    out=[$out]"; }

echo
if [ "$fails" -eq 0 ]; then
  echo "test-pretooluse-shortcircuit: ALL PASS"
  exit 0
else
  echo "test-pretooluse-shortcircuit: $fails FAILURE(S)"
  exit 1
fi
