#!/usr/bin/env bash
# test-playwright-embed-contracts.sh — P1 contract pins for the Playwright embed
# (spec: docs/superpowers/specs/2026-08-12-playwright-embed-design.md).
# Every arm greps SHIPPED surfaces; run </dev/null like the sibling suites.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
has()  { grep -qF "$2" "$1"; }

echo "── A: .mcp.json shape (D0) ──"
MCP="$P/.mcp.json"
# A1: file exists and is valid JSON
if [ -f "$MCP" ] && python3 -c "import json;json.load(open('$MCP'))" 2>/dev/null; then
  ok "A1 .mcp.json exists + valid JSON"
else
  fail "A1 .mcp.json missing or invalid JSON"
fi
# A2: exactly one server, named playwright, stdio via npx
if python3 - "$MCP" <<'PY' 2>/dev/null
import json,sys
d=json.load(open(sys.argv[1]))
s=d.get("mcpServers",{})
assert list(s.keys())==["playwright"], s.keys()
pw=s["playwright"]
assert pw.get("type")=="stdio" and pw.get("command")=="npx", pw
assert "env" not in pw and "alwaysLoad" not in pw
PY
then
  ok "A2 exactly one stdio server 'playwright' via npx"
else
  fail "A2 server shape wrong"
fi
# A3: version pinned EXACT — a floating tag is the registry-rot class
if grep -qE '@playwright/mcp@[0-9]+\.[0-9]+\.[0-9]+"' "$MCP" 2>/dev/null && ! grep -qE '@(latest|next|beta|alpha)"' "$MCP" 2>/dev/null; then
  ok "A3 @playwright/mcp pinned to an exact version (no floating tag)"
else
  fail "A3 pin is floating or malformed"
fi
# A4: the release checklist reviews the pin at each bump
if grep -qF ".mcp.json" "$P/CLAUDE.md"; then
  ok "A4 CLAUDE.md §Versioning names the .mcp.json pin"
else
  fail "A4 release checklist missing the .mcp.json pin review"
fi

echo "── B: slice-design containment (D1) ──"
SD="$P/skills/slice-design/SKILL.md"
# B1: skill exists
if [ -f "$SD" ]; then
  ok "B1 slice-design SKILL.md exists"
  # B2: description declares command-invocation-only and carries NO census list
  DESC=$(grep '^description:' "$SD" | head -1)
  echo "$DESC" | grep -qF "Command-invocation only" && ok "B2a description declares command-invocation only" || fail "B2a missing command-only declaration"
  echo "$DESC" | grep -qF "never auto-triggers" && ok "B2b description disclaims auto-trigger" || fail "B2b missing auto-trigger disclaimer"
  echo "$DESC" | grep -qF 'Triggers —' && fail "B2c description carries a trigger census (census leak)" || ok "B2c no trigger census in description"
  # B3: the binding containment sentences exist in the body
  has "$SD" "NEVER writes the vault" && ok "B3a no-vault-write pin" || fail "B3a no-vault-write sentence missing"
  has "$SD" "NEVER starts, installs, or backgrounds a dev server" && ok "B3b server-ownership pin" || fail "B3b server-ownership sentence missing"
  has "$SD" "cap: 3 compare rounds" && ok "B3c compare-round cap pin" || fail "B3c round-cap sentence missing"
  has "$SD" "render was NOT verified" && ok "B3d honest-skip wording pin" || fail "B3d honest-skip sentence missing"
  has "$SD" ".mega-sdd/slices/" && ok "B3e report-location pin" || fail "B3e report location missing"
  # B4: reference routed one level deep
  has "$SD" "references/slice-procedure.md" && ok "B4 slice-procedure routed from SKILL" || fail "B4 reference unrouted"
else
  fail "B1 slice-design SKILL.md missing (B2-B4 skipped)"
fi

echo
echo "playwright-embed contracts: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
