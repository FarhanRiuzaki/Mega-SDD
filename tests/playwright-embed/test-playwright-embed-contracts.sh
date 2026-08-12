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
# A2: exactly two servers — playwright + context7 (6.9.0) — both stdio via npx
if python3 - "$MCP" <<'PY' 2>/dev/null
import json,sys
d=json.load(open(sys.argv[1]))
s=d.get("mcpServers",{})
assert sorted(s.keys())==["context7","playwright"], s.keys()
for name,srv in s.items():
    assert srv.get("type")=="stdio" and srv.get("command")=="npx", (name,srv)
    assert "env" not in srv and "alwaysLoad" not in srv, (name,srv)
PY
then
  ok "A2 exactly two stdio servers (playwright + context7) via npx"
else
  fail "A2 server set/shape wrong"
fi
# A3: version pinned EXACT — a floating tag is the registry-rot class
if grep -qE '@playwright/mcp@[0-9]+\.[0-9]+\.[0-9]+"' "$MCP" 2>/dev/null && ! grep -qE '@(latest|next|beta|alpha)"' "$MCP" 2>/dev/null; then
  ok "A3 @playwright/mcp pinned to an exact version (no floating tag)"
else
  fail "A3 pin is floating or malformed"
fi
# A5: context7 pinned EXACT (6.9.0; the A3 floating-tag grep covers the whole file)
if grep -qE '@upstash/context7-mcp@[0-9]+\.[0-9]+\.[0-9]+"' "$MCP" 2>/dev/null; then
  ok "A5 @upstash/context7-mcp pinned to an exact version"
else
  fail "A5 context7 pin missing or floating"
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

echo "── C: anchor-core budget guard (D1 containment) ──"
UMS="$P/skills/using-mega-sdd/SKILL.md"
CORE=$(awk 'BEGIN{dash=0;body=0}
  /^---[[:space:]]*$/{dash++; if(dash==2)body=1; next}
  body==0{next}
  /ANCHOR-CORE ends/{exit}
  {print}' "$UMS")
# C1: the anchor core does NOT grow for /slice — byte baseline captured at 6.8.0
# with the SAME awk hooks/session-start uses for the full-core injection.
# Re-baseline ONLY with a recorded decision (this is the census-budget moat).
n=$(printf '%s' "$CORE" | wc -c | tr -d ' ')
[ "$n" -eq 3415 ] && ok "C1 anchor-core byte length unchanged ($n)" || fail "C1 anchor core changed: $n bytes (baseline 3415)"
# C1b: the COMPACT-mode extraction ('## Hard rule' awk, session-start:150-153 —
# no frontmatter strip) is pinned separately: a line matching /^## Hard rule/ or
# 'ANCHOR-CORE ends' inside the frontmatter would move THIS region without
# moving C1's (round finding, guard-scope gap).
CCORE=$(awk 'BEGIN{take=0}
  /^## Hard rule/{take=1}
  /ANCHOR-CORE ends/{exit}
  take==1{print}' "$UMS")
cn=$(printf '%s' "$CCORE" | wc -c | tr -d ' ')
[ "$cn" -eq 1187 ] && ok "C1b compact-core byte length unchanged ($cn)" || fail "C1b compact core changed: $cn bytes (baseline 1187)"
# C2: no slice mention above the marker (both variants)
printf '%s' "$CORE" | grep -qi "slice" && fail "C2 'slice' leaked into the anchor core" || ok "C2 anchor core slice-free"
printf '%s' "$CCORE" | grep -qi "slice" && fail "C2b 'slice' leaked into the compact core" || ok "C2b compact core slice-free"
# C3: the body mention exists (below the marker)
grep -qF "/mega-sdd:slice" "$UMS" && ok "C3 body mentions /mega-sdd:slice" || fail "C3 body mention missing"

echo "── D: install-deps Playwright detect-and-offer (D0) ──"
ID="$P/skills/install-deps/SKILL.md"
has "$ID" "npx playwright install chromium" && ok "D1 offer command present" || fail "D1 offer command missing"
has "$ID" "never auto-run" && ok "D2 offer-only wording present" || fail "D2 offer-only wording missing"
has "$ID" "ms-playwright" && ok "D3 cache-path probe documented" || fail "D3 browser cache probe missing"
# D4: NO tool-matrix row for playwright — the Chrome notes-line precedent holds
grep -qE '^  - id: *playwright' "$P/skills/install-deps/references/tool-matrix.yaml" \
  && fail "D4 a playwright tool-matrix row appeared (spec forbids it — ==10 pins + verify_cmd registry-fetch hazard)" \
  || ok "D4 no playwright tool-matrix row"

echo "── E: context7 consult wiring (6.9.0) ──"
BI="$P/agents/bolt-implementer.md"
SP="$P/skills/slice-design/references/slice-procedure.md"
# E1/E2: both code-emitting surfaces carry the optional consult guidance
grep -qi "context7" "$BI" && ok "E1 bolt-implementer carries the Context7 consult guidance" || fail "E1 bolt-implementer guidance missing"
grep -qi "context7" "$SP" && ok "E2 slice-procedure carries the Context7 consult guidance" || fail "E2 slice-procedure guidance missing"
# E3: the guidance is non-gating on the agent surface
grep -qF "never load-bearing" "$BI" && ok "E3 bolt-implementer guidance is non-gating (never load-bearing)" || fail "E3 non-gating wording missing"
# E4: the dispatch builder is context7-FREE — the golden-corpus firewall
grep -qi "context7" "$P/scripts/build-dispatch-prompt.sh" && fail "E4 context7 leaked into build-dispatch-prompt.sh (golden corpus firewall breach)" || ok "E4 dispatch builder context7-free"

echo
echo "playwright-embed contracts: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
