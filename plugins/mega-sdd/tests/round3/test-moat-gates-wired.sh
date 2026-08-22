#!/usr/bin/env bash
# test-moat-gates-wired.sh — Round-3 audit gaps R3-3, R3-4, R3-14.
#
# The PreToolUse hook wires several BLOCKING gates that had no regression pin, so an
# accidental edit could silently un-wire one and the moat would erode unnoticed:
#   R3-3  scope-flag gate           (validate-scope-flag.sh + .scope-flag-state.json)
#   R3-4  the 5 kept code-delivery gates (flow-coverage, render-test, sibling-consistency,
#         ui-quality, cross-cutting) listed as enforced in plugins/mega-sdd/CLAUDE.md
#   R3-14 anti-self-bypass deny     (rm/overwrite of protected guard state files)
# plus factory-ledger + predictive preflight (both also hard-block here).
#
# PART A pins the wiring statically (grep + bash -n) — mirrors bolt-orphans/test-gates-wired.sh.
# PART B proves the behavior end-to-end by driving the hook with real tool-call JSON.
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

# Static wiring assertion: the hook must mention $1 (else a gate was un-wired).
wired() { grep -qF "$1" "$HOOK" && pass "wired: $2" || fail "NOT wired: $2 (missing '$1')"; }

echo "── PART A: static wiring pins ──"
# R3-3 scope-flag
wired "validate-scope-flag.sh"            "scope-flag validator invoked"
wired ".scope-flag-state.json"            "scope-flag state file read"
# R3-4 the 5 kept code-delivery gates (state file + label both present)
wired ".flow-coverage-state.json"         "flow-coverage gate state"
wired "flow-coverage"                     "flow-coverage gate label"
wired ".unit-spec-state.json"             "render-test gate state (unit-spec)"
wired "render_test_missing"               "render-test halt_type"
wired ".sibling-consistency-state.json"   "sibling-consistency gate state"
wired ".ui-quality-blockers.json"         "ui-quality gate state"
wired ".cross-cutting-state.json"         "cross-cutting-registration gate state"
# Batch-3 gates (B2 full-suite, B1 post-flight evidence, A1 per-AC grounding) —
# new PreToolUse hard-blocks that need their own un-wire pins.
wired ".batch-suite-gate-state.json"      "batch-suite-gate state (B2)"
wired "batch_suite_red"                    "batch-suite-gate halt (B2)"
wired ".bolt-postflight-state.json"       "postflight-evidence state (B1)"
wired "postflight-evidence"                "postflight-evidence label (B1)"
wired "verify_grounding_untrusted"         "verify-grounding halt (A1)"
# factory-ledger + preflight (also hard-block)
wired ".factory-ledger-state.json"        "factory-ledger gate state"
wired "validate-preflight.sh"             "predictive preflight invoked"
# R3-14 anti-self-bypass protected list (all four guard files)
wired '\.validation-blockers\.json'       "protected: validation-blockers"
wired '\.plan-pending'                    "protected: plan-pending"
wired '\.replan-budget'                   "protected: replan-budget"
wired '\.iter-classifier\.json'           "protected: iter-classifier"
# P2 v6.10.0: UAT automated-evidence artifact joins the roster (both lanes)
wired 'uat/evidence/'                     "protected: uat evidence result.json"
# Syntax of the edited surface
bash -n "$HOOK" && pass "pre-tool-use: bash -n clean" || fail "pre-tool-use: syntax error"

echo "── PART B: behavioral deny/allow ──"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
# A unit must exist or the predictive preflight (Branch 0) blocks execute-bolts first,
# before the gate aggregator is reached. Preflight only globs for U-*.md presence.
mkdir -p "$ROOT/.mega-sdd/vaults/v1/units"
printf -- '---\nid: U-001\n---\n# U-001\n' > "$ROOT/.mega-sdd/vaults/v1/units/U-001.md"

run_bolts() {
  printf '{"cwd": "%s", "tool_name": "Skill", "tool_input": {"skill": "mega-sdd:execute-bolts"}}' "$ROOT" \
    | bash "$HOOK" 2>/dev/null
}
run_bash() {
  # $1 = command string (must be JSON-safe; mktemp paths are)
  printf '{"cwd": "%s", "tool_name": "Bash", "tool_input": {"command": "%s"}}' "$ROOT" "$1" \
    | bash "$HOOK" 2>/dev/null
}
denied() { printf '%s' "$1" | grep -q '"permissionDecision": "deny"'; }

# B1 — clean tree (units present, no failing gate) => execute-bolts ALLOWED.
out=$(run_bolts)
denied "$out" && fail "B1: clean tree blocked execute-bolts (false positive)" \
  || pass "B1: clean tree allows execute-bolts"

# B2 — a kept code-delivery gate FAILing => execute-bolts BLOCKED, reason names the gate.
# Uses an ISOLATED fixture with a REAL flow-coverage shortfall (a Laravel flow whose 2
# input steps have zero matching Form-Request artifacts in the unit's target_files) so the
# FAIL SURVIVES the gate's unconditional re-derivation (pre-tool-use ~line 407). A
# hand-planted .flow-coverage-state.json would be overwritten before the aggregator reads
# it — which is exactly why the old planted-state form of this assertion went stale.
FC="$(mktemp -d)"
mkdir -p "$FC/.mega-sdd/codebase" "$FC/.mega-sdd/vaults/v1/units"
printf -- '---\nframework: laravel\n---\n# Codebase Map\n' > "$FC/.mega-sdd/codebase/codebase-map.md"
printf '# Flows\n\n### F-U-001 - Widget Approval (Maker -> Checker)\n\n1. Maker submits the widget for review\n2. Checker approves the widget\n' \
  > "$FC/.mega-sdd/vaults/v1/04-flows.md"
printf -- '---\nid: U-001\ntitle: Widget approval controller\ntask_type: create\ntarget_files:\n  - app/Http/Controllers/WidgetController.php\n---\n# U-001\n\n## Target files\n- app/Http/Controllers/WidgetController.php (edit)\n' \
  > "$FC/.mega-sdd/vaults/v1/units/U-001.md"
out=$(printf '{"cwd": "%s", "tool_name": "Skill", "tool_input": {"skill": "mega-sdd:execute-bolts"}}' "$FC" | bash "$HOOK" 2>/dev/null)
if denied "$out" && printf '%s' "$out" | grep -q 'flow-coverage'; then
  pass "B2: real flow-coverage shortfall blocks execute-bolts and names the gate"
else
  fail "B2: flow-coverage shortfall did not block (R3-4 gate not enforced)"; echo "    out=[$out]"
fi
rm -rf "$FC"

# B2a — batch-suite-gate RED (B2) => execute-bolts BLOCKED, reason names the gate.
printf '{"status":"FAIL","halt_type":"batch_suite_red","detail":"suite RED"}' \
  > "$ROOT/.mega-sdd/.batch-suite-gate-state.json"
out=$(run_bolts)
if denied "$out" && printf '%s' "$out" | grep -q 'batch-suite-gate'; then
  pass "B2a: batch-suite-gate RED blocks execute-bolts and names the gate"
else
  fail "B2a: batch-suite-gate FAIL did not block (B2 gate not enforced)"; echo "    out=[$out]"
fi
rm -f "$ROOT/.mega-sdd/.batch-suite-gate-state.json"

# B2b — postflight-evidence FAIL (B1) => execute-bolts BLOCKED, reason names the gate.
printf '{"status":"FAIL","issues_count":1,"issues":[{"halt_type":"postflight_evidence_missing","unit_id":"U-001"}]}' \
  > "$ROOT/.mega-sdd/.bolt-postflight-state.json"
out=$(run_bolts)
if denied "$out" && printf '%s' "$out" | grep -q 'no passing postflight.json'; then
  pass "B2b: postflight-evidence FAIL blocks execute-bolts and names the gate"
else
  fail "B2b: postflight-evidence FAIL did not block (B1 gate not enforced)"; echo "    out=[$out]"
fi
rm -f "$ROOT/.mega-sdd/.bolt-postflight-state.json"

# B2c — verify-grounding (A1): a REAL verify+HIGH unit with an ungrounded acceptance
# criterion => execute-bolts BLOCKED. Isolated fixture; the FAIL is re-derived from the
# unit text (validate-unit-spec at the gate), so it survives re-derivation.
VG="$(mktemp -d)"
mkdir -p "$VG/.mega-sdd/vaults/v1/units"
printf -- '---\nid: U-001\ntitle: Verify widget index renders\ntask_type: verify\ngrounding_confidence: HIGH\nvault_source: 01-entities.md\ntarget_files: []\nacceptance_test: "GET /widgets returns 200"\n---\n# U-001\n\n## Anchors\n- app/Http/Controllers/WidgetController.php:1 - from binding\n\n## Acceptance criteria\n- The widget index lists every active widget [ungrounded]\n' \
  > "$VG/.mega-sdd/vaults/v1/units/U-001.md"
out=$(printf '{"cwd": "%s", "tool_name": "Skill", "tool_input": {"skill": "mega-sdd:execute-bolts"}}' "$VG" | bash "$HOOK" 2>/dev/null)
if denied "$out" && printf '%s' "$out" | grep -q 'grounding_confidence: HIGH'; then
  pass "B2c: real verify+HIGH ungrounded unit blocks execute-bolts and names the gate"
else
  fail "B2c: verify-grounding FAIL did not block (A1 gate not enforced)"; echo "    out=[$out]"
fi
rm -rf "$VG"

# B3 — anti-self-bypass: rm of a protected guard state file => BLOCKED (R3-14).
out=$(run_bash "rm $ROOT/.mega-sdd/.validation-blockers.json")
denied "$out" && pass "B3: rm of protected .validation-blockers.json is blocked" \
  || { fail "B3: anti-self-bypass did NOT block rm of protected file"; echo "    out=[$out]"; }

# B4 — anti-self-bypass precision: rm of a NON-protected file => ALLOWED.
out=$(run_bash "rm $ROOT/scratch-notes.txt")
denied "$out" && { fail "B4: anti-self-bypass blocked a benign rm (over-broad)"; echo "    out=[$out]"; } \
  || pass "B4: rm of a non-protected file is allowed (guard is precise)"

# B5 — P2 v6.10.0: rm of a vault UAT evidence result.json => BLOCKED (both-tree
# behavioral coverage; the full evasion battery lives in
# tests/postflight-evidence/test-uat-evidence-guard.sh).
out=$(run_bash "rm $ROOT/.mega-sdd/vaults/app/uat/evidence/UAT-001/20260812T100000Z/result.json")
denied "$out" && pass "B5: rm of uat evidence result.json is blocked" \
  || { fail "B5: uat evidence guard did NOT block rm"; echo "    out=[$out]"; }

echo
if [ "$fails" -eq 0 ]; then
  echo "test-moat-gates-wired: ALL PASS"
  exit 0
else
  echo "test-moat-gates-wired: $fails FAILURE(S)"
  exit 1
fi
