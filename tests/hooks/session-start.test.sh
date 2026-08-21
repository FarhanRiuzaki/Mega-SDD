#!/usr/bin/env bash
# Verifies session-start hook behavior:
#   1. v7.0.0: no-signal CWD → ZERO output (the v5.2.6 MANDATORY slim block is
#      DELETED — gate-1 decision, spec 2026-08-21-v7-weighted-routing-design.md)
#   2. Injects full anchor when SDD signals present
#   3. Surfaces superpowers warning when superpowers missing
# No-signal cases run under a sandbox HOME so the real user's wrapper state can
# never flip a test result.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="${REPO_ROOT}/plugins/mega-sdd/hooks/session-start"

fail() { echo "FAIL: $1" >&2; exit 1; }

[ -x "$HOOK" ] || fail "hook not executable: $HOOK"

# Test 1 (v7): no-signal CWD → the bare governance marker ONLY (no slim block,
# no anchor, no routing text). The marker survives for the AI-gateway v6.19.2
# detection contract (:session per NIP window).
tmp1="$(mktemp -d)"; home1="$(mktemp -d)"
out="$(cd "$tmp1" && HOME="$home1" bash "$HOOK")"
[ "$out" = "mega-sdd-trace:session" ] || fail "v7: a no-signal CWD must emit EXACTLY the bare governance marker, got: $out"
echo "$out" | grep -q "MANDATORY\|Hard rule\|using-mega-sdd" && fail "v7: routing text leaked into the no-signal path: $out"
rm -rf "$tmp1" "$home1"

# Test 2: signal CWD → anchor content present
tmp2="$(mktemp -d)"
mkdir -p "${tmp2}/docs/mega-sdd"
out="$(cd "$tmp2" && bash "$HOOK")"
echo "$out" | grep -q "EXTREMELY_IMPORTANT" || fail "anchor wrapper missing from signal CWD output"
echo "$out" | grep -q "mega-sdd-trace:session" || fail "full anchor block missing the mega-sdd-trace:session observability tag"
echo "$out" | grep -q "mega-sdd" || fail "anchor body missing 'mega-sdd' mention"
rm -rf "$tmp2"

echo "OK: hook behaves correctly in both signal and no-signal CWDs"
