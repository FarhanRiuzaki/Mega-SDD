#!/usr/bin/env bash
# test-fsd-slots-glob.sh — Round-3 audit gap R3-12.
#
# validate-fsd-slots.sh's path filter (case "$FILE_PATH" in *fsd*.md ...) over-matched
# the plugin's OWN authoring files (skills/emit-fsd/SKILL.md, references/*.md), whose
# `{{slot}}` examples are documentation, not unfilled output — a false FAIL.
# Line 70 also promised code-fence exclusion that was never implemented.
#
# This pins the corrected behavior:
#   1. emit-fsd authoring files (path contains "fsd" but is not FSD output) -> NOT scanned.
#   2. A real FSD output (<vault>/fsd/FSD.md) with an unfilled slot -> still FAILs (detection kept).
#   3. A real FSD output whose only `{{slot}}` is inside a ``` code fence -> PASSes (fence exclusion).
#
# CI-safe: bash + python3 only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATOR="$PLUGIN_ROOT/scripts/validate-fsd-slots.sh"

[ -f "$VALIDATOR" ] || { echo "FAIL: validator not found at $VALIDATOR"; exit 1; }

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/.mega-sdd"

# --- Case 1: emit-fsd authoring file must NOT be treated as FSD output (no false FAIL) ---
mkdir -p "$ROOT/skills/emit-fsd"
AUTHORING="$ROOT/skills/emit-fsd/SKILL.md"
printf 'Documentation example: emit `{{section_title}}` then fill `{{body}}`.\n' > "$AUTHORING"
bash "$VALIDATOR" --cwd="$ROOT" --file-path="$AUTHORING" --quiet
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "emit-fsd authoring file (path contains 'fsd') is out of scope (exit 0)"
else
  fail "emit-fsd authoring file was scanned and FAILed (exit $rc) — glob over-matches"
fi

# --- Case 2: real FSD output with an unfilled slot must still FAIL (detection preserved) ---
mkdir -p "$ROOT/.mega-sdd/vaults/v1/fsd"
OUT="$ROOT/.mega-sdd/vaults/v1/fsd/FSD.md"
printf '# FSD\n\nOverview: {{unfilled_overview}}\n' > "$OUT"
bash "$VALIDATOR" --cwd="$ROOT" --file-path="$OUT" --quiet
rc=$?
if [ "$rc" -eq 1 ]; then
  pass "real FSD output with unfilled slot FAILs (exit 1)"
else
  fail "real FSD output with unfilled slot did NOT FAIL (exit $rc) — detection lost"
fi

# --- Case 3: real FSD output whose only slot is inside a code fence must PASS (fence exclusion) ---
FENCED="$ROOT/.mega-sdd/vaults/v1/fsd/FSD.md"
{
  printf '# FSD\n\nAll sections filled. Template syntax is documented below:\n\n'
  printf '```\n{{slot_name}} is replaced at emit time.\n```\n'
} > "$FENCED"
bash "$VALIDATOR" --cwd="$ROOT" --file-path="$FENCED" --quiet
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "FSD output with slot only inside code fence PASSes (exit 0)"
else
  fail "FSD output with fenced slot example FAILed (exit $rc) — fence exclusion missing"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "test-fsd-slots-glob: ALL PASS"
  exit 0
else
  echo "test-fsd-slots-glob: $fails FAILURE(S)"
  exit 1
fi
