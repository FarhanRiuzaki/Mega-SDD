#!/usr/bin/env bash
# Moat regression — binding->units gate truth under a CORRUPT cached state.
#
# HISTORY: this test originally pinned "fail-closed on a PRESENT-but-unparseable
# .validation-blockers.json" (AUDIT Round-2 L4). That premise was SUPERSEDED by the
# S5/S6 hardening: the execute-bolts PreToolUse gate now RE-DERIVES the moat state from
# ground truth (validate-handoff-binding-units.sh, pre-tool-use ~line 398) BEFORE the
# aggregator reads it — so a corrupt/stale/forged cache is OVERWRITTEN with current truth
# and never trusted. Re-derivation is STRONGER than fail-closed: it enforces the real
# binding state in BOTH directions, not just "block on garbage". (The aggregator's
# parse-fail fail-closed branch survives only as a backstop for the narrow case where
# re-derivation itself cannot run — not exercised here.)
#
# The NEW contract this test pins: a corrupt .validation-blockers.json can neither HIDE a
# real unresolved CONFLICT (no false-pass) nor SPURIOUSLY block a clean tree (no
# false-block) — because the gate re-derives it. Ground truth wins.
# CI-safe: bash + python3 only (no git required).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOOK="${PLUGIN_ROOT}/hooks/pre-tool-use"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

run_hook() {
  # A mega-sdd:execute-bolts Skill call from $ROOT — drives the gate aggregator.
  printf '{"cwd": "%s", "tool_name": "Skill", "tool_input": {"skill": "mega-sdd:execute-bolts"}}' "$ROOT" \
    | bash "$HOOK" 2>/dev/null
}
blocked() { printf '%s' "$1" | grep -q '"permissionDecision": "deny"'; }
disk_status() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("status"))' "${ROOT}/.mega-sdd/.validation-blockers.json" 2>&1; }

# A real unresolved CONFLICT: a canonical `### CONFLICT-N` heading with no RESOLVED marker
# is active fail-closed in the validator. ASCII hyphen only (the moat reader does not use
# errors="replace" — an em-dash would be a latent non-ASCII-codec dependency).
seed_conflict() {
  mkdir -p "${ROOT}/.mega-sdd/vaults/v1/units"
  printf '# Binding v1\n\n### CONFLICT-1 - Product name collision\n' > "${ROOT}/.mega-sdd/vaults/v1/binding.md"
  printf -- '---\nid: U-001\ntitle: Product model\nbinding_refs: [CONFLICT-1]\n---\n# U-001\n' \
    > "${ROOT}/.mega-sdd/vaults/v1/units/U-001.md"
}
seed_clean() {
  rm -rf "${ROOT}/.mega-sdd/vaults"
  mkdir -p "${ROOT}/.mega-sdd/vaults/v1/units"
  printf '# Binding v1\n\nNo conflicts.\n' > "${ROOT}/.mega-sdd/vaults/v1/binding.md"
  printf -- '---\nid: U-001\ntitle: Product model\n---\n# U-001\n' > "${ROOT}/.mega-sdd/vaults/v1/units/U-001.md"
}
CORRUPT='{ this is not valid json ]]'

# --- Case A: corrupt cache + REAL CONFLICT => gate re-derives => BLOCK (no false-pass) ---
seed_conflict
printf '%s' "$CORRUPT" > "${ROOT}/.mega-sdd/.validation-blockers.json"
out=$(run_hook)
blocked "$out" || { echo "FAIL: corrupt cache HID a real CONFLICT (false-pass) — re-derivation did not enforce ground truth"; echo "out=[$out]"; exit 1; }
printf '%s' "$out" | grep -qi "conflict_unresolved\|binding->units" || { echo "FAIL: block reason should name the re-derived binding->units conflict"; echo "out=[$out]"; exit 1; }
[ "$(disk_status)" = "FAIL" ] || { echo "FAIL: corrupt cache was not overwritten with the re-derived FAIL (got $(disk_status))"; exit 1; }
echo "PASS (corrupt cache cannot hide a real CONFLICT — re-derived to FAIL, gate blocks)"

# --- Case B: corrupt cache + CLEAN tree => gate re-derives => ALLOW (no false-block) ---
seed_clean
printf '%s' "$CORRUPT" > "${ROOT}/.mega-sdd/.validation-blockers.json"
out=$(run_hook)
blocked "$out" && { echo "FAIL: corrupt cache SPURIOUSLY blocked a clean tree (false-block) — re-derivation must supersede it"; echo "out=[$out]"; exit 1; }
[ "$(disk_status)" = "PASS" ] || { echo "FAIL: corrupt cache was not overwritten with the re-derived PASS (got $(disk_status))"; exit 1; }
echo "PASS (corrupt cache cannot spuriously block a clean tree — re-derived to PASS, gate allows)"

# --- Case C: ABSENT cache + clean tree => ALLOW (absent = never evaluated, unchanged) ---
seed_clean
rm -f "${ROOT}/.mega-sdd/.validation-blockers.json"
out=$(run_hook)
blocked "$out" && { echo "FAIL: absent cache + clean tree must allow"; echo "out=[$out]"; exit 1; }
echo "PASS (absent cache + clean tree allows)"

# --- Case D: ABSENT cache + real CONFLICT => re-derives => BLOCK ---
seed_conflict
rm -f "${ROOT}/.mega-sdd/.validation-blockers.json"
out=$(run_hook)
blocked "$out" || { echo "FAIL: absent cache + real CONFLICT must re-derive to FAIL and block"; echo "out=[$out]"; exit 1; }
echo "PASS (absent cache + real CONFLICT re-derives to FAIL, gate blocks)"

echo "ALL PASS"
