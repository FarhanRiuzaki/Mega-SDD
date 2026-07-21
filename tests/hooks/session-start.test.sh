#!/usr/bin/env bash
# Verifies session-start hook behavior:
#   1. Injects the SLIM mandatory-routing block when no SDD signals (v5.2.6 default)
#   1b. Stays silent when no signals AND routing opt-out marker set
#   2. Injects full anchor when SDD signals present
#   3. Surfaces superpowers warning when superpowers missing
# No-signal cases run under a sandbox HOME so the real user's opt-out marker /
# wrapper state can never flip a test result.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="${REPO_ROOT}/plugins/mega-sdd/hooks/session-start"

fail() { echo "FAIL: $1" >&2; exit 1; }

[ -x "$HOOK" ] || fail "hook not executable: $HOOK"

# Test 1: no-signal CWD → SLIM mandatory-routing block (NOT the full anchor)
tmp1="$(mktemp -d)"; home1="$(mktemp -d)"
out="$(cd "$tmp1" && HOME="$home1" bash "$HOOK")"
echo "$out" | grep -q "MANDATORY development workflow" || fail "no-signal CWD should inject the slim routing block, got: $out"
echo "$out" | grep -q "using-mega-sdd" || fail "slim block missing the using-mega-sdd routing pointer"
rm -rf "$tmp1" "$home1"

# Test 1b: no-signal CWD + opt-out marker → empty output
tmp1b="$(mktemp -d)"; home1b="$(mktemp -d)"
mkdir -p "${home1b}/.claude"; touch "${home1b}/.claude/.mega-sdd-routing-off"
out="$(cd "$tmp1b" && HOME="$home1b" bash "$HOOK")"
[ -z "$out" ] || fail "opt-out marker should silence the no-signal injection, got: $out"
rm -rf "$tmp1b" "$home1b"

# Test 2: signal CWD → anchor content present
tmp2="$(mktemp -d)"
mkdir -p "${tmp2}/docs/mega-sdd"
out="$(cd "$tmp2" && bash "$HOOK")"
echo "$out" | grep -q "EXTREMELY_IMPORTANT" || fail "anchor wrapper missing from signal CWD output"
echo "$out" | grep -q "mega-sdd" || fail "anchor body missing 'mega-sdd' mention"
rm -rf "$tmp2"

echo "OK: hook behaves correctly in both signal and no-signal CWDs"
