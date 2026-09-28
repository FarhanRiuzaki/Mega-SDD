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
# 7.29.1 re-baseline (RECORDED — leftover sweep): the dead "memory review" side lane
# (lane removed v7.3.0) left the anchor and the emit verb gained its |html|summary
# args: 3846 → 3844. Still a shrink; the 4030 cap stands.
# 8.4.0 re-baseline (spec 2026-09-16-doc-audit-debt-gate-design.md §3): the Hard-gate line now carries the lite-lane
# qualifier (binding_conflict at execute-bolts dispatch) — +125 B, still under the 4030 cap.
# 2026-09-27 re-baseline (research/2026-09-27-lane-router-results.md): the tier-L row names the lane router
# (route-lane.sh → direct / assisted / guarded) — +13 B, still under the 4030 cap.
# 9.0 P1 re-baseline (RECORDED — spec 2026-09-27-v9-simplification-design.md; classic skills deleted):
# the Hard-gate line no longer names the deleted `bind-codebase` / classic `binding.md`; it now pins the
# surviving JIT per-unit gate (bolts/U-XXX/binding.json, pre-flight 3.9, binding_conflict, resolve-oq --binding).
# That line is the ONLY change above the marker: 3982 → 3952 (−30 B, a shrink; the 4030 cap stands).
# 9.0 §8.5 re-baseline (RECORDED — research/2026-09-28-p2-inline-results.md; execute-bolts inline by default): the
# Hard-gate line states the run-start quarantine (JIT bind up front + per task) and scopes the dispatch gate to
# `--agents`. That line is the ONLY change above the marker: 3952 → 3988 (+36 B, under the 4030 cap).
[ "$n" -eq 3988 ] && ok "C1 anchor-core byte length unchanged ($n)" || fail "C1 anchor core changed: $n bytes (baseline 3988, 9.0 §8.5: Hard-gate line states the inline run-start gate — spec 2026-09-27-v9-simplification-design.md; under the 4030 cap)"
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
# 9.0 P1 re-baseline (RECORDED — same single Hard-gate line change as C1, which sits inside
# this region too): 1619 → 1589 (−30 B, identical delta to C1).
# 9.0 §8.5 re-baseline (RECORDED — same single Hard-gate line change as C1): 1589 → 1625 (+36 B, identical delta).
[ "$cn" -eq 1625 ] && ok "C1b compact-core byte length unchanged ($cn)" || fail "C1b compact core changed: $cn bytes (baseline 1625, 9.0 §8.5 Hard-gate line states the inline run-start gate)"
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

echo
echo "playwright-embed contracts: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
