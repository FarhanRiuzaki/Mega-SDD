#!/usr/bin/env bash
# v8 P1.e W1 zero-idle (spec 2026-09-10 App. F6; audit research/2026-09-10-p0-interaction-audit.md §A/§E):
# the happy-path 3-screen express run may stop for a human at EXACTLY two points —
# the front-door chain confirmation and ONE batched ask (OQ P1 business + the L0
# toolchain item + Defer/OOS sub-fields). This suite is a STATIC pin over the prose
# that governs each conditional stop the audit found; the LIVE count comes from
# the extractor's `interaction_points` on the owner's P5 run (never asserted here).
# Run: bash tests/w1-zero-idle/test-happy-path-ask-sites.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
P="$(cd "$(dirname "$0")/../.." && pwd)/plugins/mega-sdd"
SF="$P/skills/generate-intent/references/setup-flow.md"; AH="$P/skills/generate-intent/references/auto-and-handoff.md"
RO="$P/skills/resolve-oq/SKILL.md"; EB="$P/skills/execute-bolts/SKILL.md"; OF="$P/skills/orchestrate-flow/SKILL.md"

# 1. orchestrate-flow Step 6 stays suppressed when the front door confirmed (audit A-1)
grep -q 'Confirmation ownership' "$OF" && grep -q 'SKIP this prompt' "$OF" && pass "1: Step 6 chain confirm suppressed by front-door ownership (1 confirm, not 2)" || fail "1: confirmation ownership clause missing"
# 2. PROJECT_SHAPE low-confidence never prompts under --auto (audit A-3)
grep -q 'never a prompt under `--auto`' "$AH" && ! grep -qE 'PROJECT_SHAPE. confirmation when inference confidence is low' "$SF" \
  && pass "2: PROJECT_SHAPE low-confidence → recorded, never asked under --auto" || fail "2: PROJECT_SHAPE still interactive under --auto"
# 3. retrofit bridge carve-out (audit A-2: the largest conditional stop, 0–2 asks)
grep -q 'scope_inferred: single' "$SF" && pass "3: legacy PRD without scopes: → single-scope RECORDED under --auto, retrofit offered in the report" || fail "3: retrofit bridge has no --auto carve-out"
# 4. L0 toolchain decision folded into the express batched ask (audit A-5)
grep -q 'l0-toolchain-decision.json' "$RO" && grep -q 'W1' "$EB" && grep -q 'stays silent' "$EB" \
  && pass "4: L0 toolchain item rides the batched OQ ask; execute-bolts 3.8 is silent afterwards" || fail "4: L0 fold missing"
# 5. Defer / OOS sub-fields recorded from the same answer (audit A-4b)
grep -q 'no second `AskUserQuestion`' "$RO" && pass "5: Defer/OOS sub-fields recorded from the same batched answer (no follow-up prompt on the express path)" || fail "5: Defer follow-up still a separate prompt"
# 6. Figma-without-MCP and destructive overwrite remain interactive (rails, not idle)
grep -q 'Figma' "$SF" && grep -qi 'destructive' "$SF" && pass "6: Figma-no-MCP + destructive overwrite stay interactive (never invent UI / never clobber)" || fail "6: rails removed"

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
