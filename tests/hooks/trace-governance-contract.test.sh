#!/usr/bin/env bash
# trace-governance-contract.test.sh — pins the STABLE GOVERNANCE CONTRACT
# (spec 2026-08-17-artifact-publisher-gateway.md §Amendment v6.19.2):
# the office AI-gateway enforces "mega-code sessions MUST run mega-sdd" by
# detecting `mega-sdd-trace:session` / `mega-sdd-trace:turn` in request
# bodies. These marker strings must NEVER be renamed. Session-marker
# emission paths are pinned in tests/hooks/session-start.test.sh; this file
# pins the per-turn marker + its documented opt-out. Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/plugins/mega-sdd/hooks/user-prompt-submit"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

P="$TMP/proj"; mkdir -p "$P/.mega-sdd"

echo "── t1: .mega-sdd project → turn marker emitted (the gateway detection contract) ──"
OUT=$(printf '{"cwd":"%s"}' "$P" | bash "$HOOK" 2>/dev/null)
printf '%s' "$OUT" | grep -q '^mega-sdd-trace:turn$' \
  && ok "t1 mega-sdd-trace:turn emitted verbatim" || fail "t1 marker missing/renamed: [$OUT]"

echo "── t2: trace_tag false → turn marker suppressed (documented opt-out) ──"
printf 'trace_tag: false\n' > "$P/.mega-sdd/config.yaml"
OUT=$(printf '{"cwd":"%s"}' "$P" | bash "$HOOK" 2>/dev/null)
printf '%s' "$OUT" | grep -q 'mega-sdd-trace:turn' \
  && fail "t2 marker emitted despite trace_tag: false" || ok "t2 opt-out suppresses the turn marker"
rm -f "$P/.mega-sdd/config.yaml"

echo "── t3: non-mega-sdd cwd → silent (marker only ever means mega-sdd is live) ──"
P2="$TMP/plain"; mkdir -p "$P2"
OUT=$(printf '{"cwd":"%s"}' "$P2" | bash "$HOOK" 2>/dev/null)
[ -z "$OUT" ] && ok "t3 no marker outside mega-sdd projects" || fail "t3 unexpected output: [$OUT]"

echo "── t4: contract strings present verbatim in BOTH emitting hooks (rename tripwire) ──"
grep -q 'mega-sdd-trace:session' "$ROOT/plugins/mega-sdd/hooks/session-start" \
  && grep -q 'echo "mega-sdd-trace:turn"' "$HOOK" \
  && ok "t4 both marker strings verbatim in hooks" || fail "t4 a governance marker string was renamed"

echo
echo "trace-governance-contract: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
