#!/usr/bin/env bash
# test-install-deps-diet.sh — pins spec 2026-08-17-token-lard-cuts-p1 D3:
# install-deps SKILL.md dieted to a router; probe/verify contract relocated to
# references/audit-and-verify.md WITHOUT content loss, and the sharpest verdict
# carve-outs stay inline in the body. Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/plugins/mega-sdd/skills/install-deps/SKILL.md"
R="$ROOT/plugins/mega-sdd/skills/install-deps/references/audit-and-verify.md"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

[ -f "$R" ] && ok "ref file exists" || fail "audit-and-verify.md missing"

# 1) byte cap — the diet must not silently regrow (spec-amended cap 19,000).
B=$(wc -c < "$S" | tr -d ' ')
[ "$B" -le 19000 ] && ok "body $B <= 19000 bytes" || fail "body regrew to $B bytes (> 19000)"

# 2) SKILL routes to the new ref (no orphan — install-deps-audit-lesson class).
grep -q 'references/audit-and-verify.md' "$S" && ok "SKILL routes to audit-and-verify.md" || fail "orphan ref: SKILL never names audit-and-verify.md"
# 2b) round catch (P1 MAJOR): the diet must not orphan the refs the moved prose
#     used to route — SKILL.md itself must keep DIRECT pointers (one-level rule).
grep -q 'references/windows-path.md' "$S" && ok "SKILL still routes windows-path.md directly" || fail "windows-path.md orphaned two levels deep"
grep -q 'references/tooling-install.md' "$S" && ok "SKILL still routes tooling-install.md directly" || fail "tooling-install.md orphaned two levels deep"

# 3) relocated content is REALLY in the ref (moved, not deleted).
for probe in 'sh -c "<verify_cmd>"' 'stock macOS ships neither' 'reintroduces exactly the false-`missing` bug' 'WindowsApps' 'mega_sdd_python_remedy' 'HKCU\Environment\Path' 'rc 7' ; do
  grep -qF "$probe" "$R" && ok "ref carries: $probe" || fail "ref LOST: $probe"
done

# 4) the sharp verdicts stay inline in the body (a model that skips the ref
#    must still never mint false-missing / false-unverified).
grep -q '124/137/127 are NEVER `missing`' "$S" && ok "body keeps 124/137/127-never-missing" || fail "body lost the never-missing carve-out"
grep -q 'never `unverified`' "$S" && ok "body keeps 127-never-unverified" || fail "body lost the never-unverified carve-out"
grep -q 'fix-windows-path.sh' "$S" && ok "body keeps the Windows-branch probe entry" || fail "body lost fix-windows-path entry"

# 5) the fat blocks are gone from the body (the diet actually happened).
grep -qF 'MSYS2 runtime injects a thread' "$S" && fail "body still carries the MSYS2 timeout essay" || ok "MSYS2 essay relocated"
grep -qF 'semgrep --version` prints an upgrade banner' "$S" && fail "body still carries the stdout-banner note" || ok "stdout-banner note relocated"

# 6) playwright-embed pins (D1-D3 of that suite) still hold in the body.
grep -qF 'npx playwright install chromium' "$S" && ok "playwright offer command intact" || fail "playwright offer command lost"
grep -qF 'ms-playwright' "$S" && ok "playwright cache probe intact" || fail "playwright cache probe lost"

# 7) ref >100 lines carries a Contents ToC (house standard).
grep -q '^## Contents' "$R" && ok "ref has Contents ToC" || fail "ref missing ToC"

echo
echo "install-deps diet: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
