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

# Test 1 (v7.3.0): no-signal CWD → NOTHING (observability removed: the old
# no anchor, no routing text). The marker survives for the AI-gateway v6.19.2
# detection contract (:session per NIP window).
tmp1="$(mktemp -d)"; home1="$(mktemp -d)"
out="$(cd "$tmp1" && HOME="$home1" bash "$HOOK")"
[ -z "$out" ] || fail "v7.3.0: a no-signal CWD must emit NOTHING, got: $out"
echo "$out" | grep -q "MANDATORY\|Hard rule\|using-mega-sdd" && fail "v7: routing text leaked into the no-signal path: $out"
rm -rf "$tmp1" "$home1"

# Test 2: signal CWD → anchor content present
tmp2="$(mktemp -d)"
mkdir -p "${tmp2}/docs/mega-sdd"
out="$(cd "$tmp2" && bash "$HOOK")"
echo "$out" | grep -q "EXTREMELY_IMPORTANT" || fail "anchor wrapper missing from signal CWD output"
echo "$out" | grep -qE "^mega-sdd-trace:session$" && fail "v7.3.1: the :session marker must NOT return (gateway contract covers turn + skill tags only)" 
echo "$out" | grep -q "mega-sdd" || fail "anchor body missing 'mega-sdd' mention"
rm -rf "$tmp2"

# Test 3 — re-pinned 7.29.1 (was telemetry-range.test.sh r5/r6, deleted with the
# telemetry lane in v7.3.0 while the 7.0.0 entry still cited the pin): the C1
# self-resolve battery runs at GROUND, and session-start writes NO vault artifact.
GROUND="${REPO_ROOT}/plugins/mega-sdd/scripts/ground.sh"
r5="$(mktemp -d)"; mkdir -p "$r5/.mega-sdd/vaults/demo"
( cd "$r5" && git init -q . ) 2>/dev/null   # .git signal → expected_mode=existing
printf '{"mode": "greenfield"}\n' > "$r5/.mega-sdd/vaults/demo/vault.json"
c1_out="$(bash "$GROUND" --cwd="$r5" 2>&1 || true)"
echo "$c1_out" | grep -q 'self-resolved\] mode_migrate' || fail "r5: C1 mode_migrate self-resolve did not fire at GROUND: ${c1_out:0:200}"
grep -q '"mode": "existing"' "$r5/.mega-sdd/vaults/demo/vault.json" || fail "r5: GROUND did not rewrite vault.json mode → existing"
r6="$(mktemp -d)"; home6="$(mktemp -d)"; mkdir -p "$r6/.mega-sdd/vaults/demo"
( cd "$r6" && git init -q . ) 2>/dev/null
printf '{"mode": "greenfield"}\n' > "$r6/.mega-sdd/vaults/demo/vault.json"
( cd "$r6" && printf '{"source":"startup","session_id":"s"}' | HOME="$home6" bash "$HOOK" >/dev/null 2>&1 ) || true
grep -q '"mode": "greenfield"' "$r6/.mega-sdd/vaults/demo/vault.json" || fail "r6: session-start mutated vault.json (it must write no vault artifacts — C1 lives at GROUND)"
rm -rf "$r5" "$r6" "$home6"

echo "OK: hook behaves correctly in both signal and no-signal CWDs (+ r5 C1-at-GROUND, r6 no-vault-writes)"
