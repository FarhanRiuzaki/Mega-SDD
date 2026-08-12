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

echo
echo "playwright-embed contracts: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
