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
# 9.0 P1: generate-intent (setup-flow.md / auto-and-handoff.md) was deleted; the spec phase is
# `plan` (guarded pipeline plan -> execute-bolts). Checks 2/3/6 are repointed to plan's surviving prose.
PL="$P/skills/plan/SKILL.md"; PP="$P/skills/plan/references/plan-procedure.md"
SC="$P/skills/plan/references/scope-flow.md"; BI="$P/skills/plan/references/brief-input.md"
RO="$P/skills/resolve-oq/SKILL.md"; EB="$P/skills/execute-bolts/SKILL.md"; OF="$P/skills/orchestrate-flow/SKILL.md"

# 1. orchestrate-flow Step 6 stays suppressed when the front door confirmed (audit A-1)
grep -q 'Confirmation ownership' "$OF" && grep -q 'SKIP this prompt' "$OF" && pass "1: Step 6 chain confirm suppressed by front-door ownership (1 confirm, not 2)" || fail "1: confirmation ownership clause missing"
# 2. project shape is never a prompt (audit A-3). 9.0: plan infers the shape into its Step-2 working
#    table (an unstated shape is an OQ, never a setup prompt); Step 6 is the phase's ONLY interaction
#    point; the guarded brief path runs the seed-PRD Q&A (whose topic 1 is project shape) at cap 0.
grep -q 'product, shape, screens' "$PL" && grep -q 'the only interaction point of this phase' "$PL" \
  && grep -q 'Never a second ask in this phase' "$PP" && grep -q '\*\*0\*\* — no pre-plan Q&A' "$BI" \
  && ! grep -rqE 'PROJECT_SHAPE. confirmation when inference confidence is low' "$P/skills/plan" \
  && pass "2: project shape inferred by plan, never asked (single batched ask; brief Q&A cap 0)" || fail "2: project shape became an interactive stop"
# 3. retrofit bridge carve-out (audit A-2: the largest conditional stop, 0–2 asks). 9.0: plan scope-flow
#    Step 0.9 c — no retrofit prompt/subagent, interactive and --auto alike.
grep -q 'scope_inferred: single' "$SC" && grep -q 'no retrofit prompt, no retrofit subagent' "$SC" \
  && pass "3: legacy PRD without scopes: → single-scope RECORDED (no retrofit ask), retrofit offered in the report" || fail "3: retrofit bridge has no carve-out"
# 4. L0 toolchain decision folded into the express batched ask (audit A-5)
grep -q 'l0-toolchain-decision.json' "$RO" && grep -q 'W1' "$EB" && grep -q 'stays silent' "$EB" \
  && pass "4: L0 toolchain item rides the batched OQ ask; execute-bolts 3.8 is silent afterwards" || fail "4: L0 fold missing"
# 5. Defer / OOS sub-fields recorded from the same answer (audit A-4b)
grep -q 'no second `AskUserQuestion`' "$RO" && pass "5: Defer/OOS sub-fields recorded from the same batched answer (no follow-up prompt on the express path)" || fail "5: Defer follow-up still a separate prompt"
# 6. Figma-without-MCP and destructive overwrite keep their rails. 9.0 plan: Figma unreachable → OQ
#    (never invented UI); an existing vault → refuse unless --regenerate (never silently overwrite).
grep -q 'no MCP and no screenshots → OQ, never invented UI' "$PL" && grep -q 'refuse unless `--regenerate` (never silently overwrite' "$PL" \
  && pass "6: Figma-no-MCP → OQ + existing vault refused without --regenerate (never invent UI / never clobber)" || fail "6: rails removed"

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
