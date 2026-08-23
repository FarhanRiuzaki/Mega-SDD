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

echo "── B: slice-design removal (v7.4.0 — stays deleted) ──"
if [ -e "$P/skills/slice-design" ] || [ -e "$P/commands/slice.md" ]; then
  fail "B1 slice-design skill/command is back (removed v7.4.0 by owner decision)"
else
  ok "B1 slice-design + /mega-sdd:slice stay removed"
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
# v7.0.0 re-baseline (RECORDED decision — gate-1, spec 2026-08-21 §2.1): the S/M/L
# weight table joined the core; 3415 → 3916; v7.3.0 observability removal
# (trace tag + related lines) shrank it to 3625. The pin still freezes the census budget.
[ "$n" -eq 3826 ] && ok "C1 anchor-core byte length unchanged ($n)" || fail "C1 anchor core changed: $n bytes (baseline 3826, v7.3.1: +gateway-marker rule, under the 4030 cap)"
# C1b: the COMPACT-mode extraction ('## Hard rule' awk, session-start:150-153 —
# no frontmatter strip) is pinned separately: a line matching /^## Hard rule/ or
# 'ANCHOR-CORE ends' inside the frontmatter would move THIS region without
# moving C1's (round finding, guard-scope gap).
CCORE=$(awk 'BEGIN{take=0}
  /^## Hard rule/{take=1}
  /ANCHOR-CORE ends/{exit}
  take==1{print}' "$UMS")
cn=$(printf '%s' "$CCORE" | wc -c | tr -d ' ')
# v7.0.0 re-baseline: the M/L-scoped Hard rule block grew (tier-S prohibitions).
[ "$cn" -eq 1474 ] && ok "C1b compact-core byte length unchanged ($cn)" || fail "C1b compact core changed: $cn bytes (baseline 1474, v7.3.1)"
# C2: no slice mention above the marker (both variants)
printf '%s' "$CORE" | grep -qi "slice" && fail "C2 'slice' leaked into the anchor core" || ok "C2 anchor core slice-free"
printf '%s' "$CCORE" | grep -qi "slice" && fail "C2b 'slice' leaked into the compact core" || ok "C2b compact core slice-free"
# C3 (v7.4.0): the body mention is GONE with the command
grep -qF "/mega-sdd:slice" "$UMS" && fail "C3 anchor body still advertises the removed /mega-sdd:slice" || ok "C3 anchor body slice-mention removed"

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
# E1: the remaining code-emitting surface carries the optional consult guidance
# (E2/E3b retired v7.4.0 — slice-procedure died with the slice-design skill)
grep -qi "context7" "$BI" && ok "E1 bolt-implementer carries the Context7 consult guidance" || fail "E1 bolt-implementer guidance missing"
# E3: the guidance is non-gating
grep -qF "never load-bearing" "$BI" && ok "E3 bolt-implementer guidance is non-gating (never load-bearing)" || fail "E3 non-gating wording missing"
# E4: the dispatch builder is context7-FREE — the golden-corpus firewall
# (existence-guarded: grep of a missing path would land in the ok branch — fail-open)
if [ -f "$P/scripts/build-dispatch-prompt.sh" ]; then
  grep -qi "context7" "$P/scripts/build-dispatch-prompt.sh" && fail "E4 context7 leaked into build-dispatch-prompt.sh (golden corpus firewall breach)" || ok "E4 dispatch builder context7-free"
else
  fail "E4 build-dispatch-prompt.sh missing (firewall arm cannot run — re-point it at the builder's new home)"
fi

echo "── F: design lens interactive capture (D3, 6.11.0) ──"
RP="$P/skills/execute-bolts/references/review-panel.md"
DR="$P/agents/design-reviewer.md"
# F1: the MCP rung sits at the TOP of the capture ladder
grep -q "Playwright MCP" "$RP" && ok "F1a review-panel names the MCP rung" || fail "F1a MCP rung missing"
python3 - "$RP" <<'PY' && ok "F1b ladder order: MCP rung precedes the static drivers (region-scoped)" || fail "F1b ladder order wrong"
import sys
s = open(sys.argv[1], encoding="utf-8").read()
# scope to §Live-app capture (round minor: a whole-file find goes vacuous the
# moment 'Playwright MCP' is mentioned anywhere above the ladder)
start = s.find("**Live-app capture")
end = s.find("Named candidate", start)
assert 0 <= start < end, (start, end)
region = s[start:end]
i_mcp = region.find("Playwright MCP")
i_chrome = region.find("system Chrome/Chromium first")
assert 0 <= i_mcp < i_chrome, (i_mcp, i_chrome)
PY
# F2: the naming contract extension (state-suffixed, route+width keyed — no collisions)
grep -qF -- '<slug>-<state>-<width>.png' "$RP" && ok "F2a naming contract literal present" || fail "F2a naming contract missing"
grep -qE 'base\|hover\|focus\|error|base \| hover \| focus \| error' "$RP" && ok "F2b state enum present" || fail "F2b state enum missing"
# F3: the controller synthesizes the SAME envelope; shot entries extend per rung
# (round MAJOR: the static script never emits `state` — identity was a misattribution)
grep -qF 'record ENVELOPE' "$RP" && grep -qF 'One envelope, per-rung shot extension' "$RP" \
  && ok "F3 envelope-identity + per-rung shot extension pinned honestly" || fail "F3 envelope wording missing"
# F4: doctrine survives — capture never a gate (verbatim), honest no-render statement
grep -qF 'Capture is never a gate; an un-captured render is never reported as fine.' "$RP" \
  && ok "F4 never-a-gate sentence verbatim" || fail "F4 never-a-gate sentence lost"
# F5: design-reviewer input contract notes the state-capture classes + naming literal
# (the hover|focus clause alone was vacuous — pre-D3 text already matched it)
grep -qi "interaction state" "$DR" && grep -qF -- '<slug>-<state>-<width>.png' "$DR" \
  && ok "F5 design-reviewer notes state captures + naming contract" || fail "F5 reviewer input note missing"
# F6: the lens-inputs known-open candidate is still carried (NOT bundled into D3)
grep -qF 'deliberately NOT changed here' "$RP" && ok "F6 lens-inputs known-open note untouched" || fail "F6 known-open note lost"

echo
echo "playwright-embed contracts: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
