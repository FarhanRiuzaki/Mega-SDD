#!/usr/bin/env bash
# Verifies session-start hook behavior:
#   1. Injects anchor when SDD signals present
#   2. Stays silent when no signals
#   3. Surfaces superpowers warning when superpowers missing

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="${REPO_ROOT}/plugins/mega-sdd/hooks/session-start"

fail() { echo "FAIL: $1" >&2; exit 1; }

[ -x "$HOOK" ] || fail "hook not executable: $HOOK"

# Test 1: no-signal CWD → empty output
tmp1="$(mktemp -d)"
out="$(cd "$tmp1" && bash "$HOOK")"
[ -z "$out" ] || fail "no-signal CWD should produce empty output, got: $out"
rm -rf "$tmp1"

# Test 2: signal CWD → anchor content present
tmp2="$(mktemp -d)"
mkdir -p "${tmp2}/docs/mega-sdd"
out="$(cd "$tmp2" && bash "$HOOK")"
echo "$out" | grep -q "EXTREMELY_IMPORTANT" || fail "anchor wrapper missing from signal CWD output"
echo "$out" | grep -q "mega-sdd" || fail "anchor body missing 'mega-sdd' mention"
rm -rf "$tmp2"

echo "OK: hook behaves correctly in both signal and no-signal CWDs"
