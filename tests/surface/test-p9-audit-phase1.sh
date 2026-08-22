#!/usr/bin/env bash
# Audit Phase-1 quick wins (spec 2026-08-10-audit-phase1-quick-wins.md) —
# pins the 11 contradiction fixes (batch A), the front-door diet (B),
# trace-tag completion (C), and the infra batch (D).
# Run: bash tests/surface/test-p9-audit-phase1.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
P="plugins/mega-sdd"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

FD="$P/commands/mega-sdd.md"
OF="$P/skills/orchestrate-flow/references"

# ── A1 + B — front-door diet: no convergence numbers, no duplicated tables ──
if ! grep -qF -- '--max-cycles` (default' "$FD" && ! grep -qF 'Cycle 1/5' "$FD"; then
  pass "A1: no convergence default/example at the front door"
else fail "A1: front door still carries a convergence default or example"; fi
grep -qF 'default 3; canonical' "$OF/convergence-loops.md" \
  && pass "A1b: convergence-loops keeps the canonical default" \
  || fail "A1b: canonical default lost from convergence-loops"
if ! grep -qF '| **A — Starterkit-first**' "$FD" && ! grep -qF '`lint-units --changed-only` | Quality gate' "$FD"; then
  pass "B: starterkit + diagnostics tables removed from the front door"
else fail "B: a duplicated chain-logic table survives at the front door"; fi
grep -qF 'lint-units --changed-only' "$OF/chain-execution.md" \
  && pass "B2: scoped auto-lint row lives at its single owner (chain-execution)" \
  || fail "B2: owner auto-lint row missing"
grep -qF 'single owner — this front door adds no rows' "$FD" \
  && pass "B3: front door declares the single-owner pointers" \
  || fail "B3: single-owner pointer sentences missing"
grep -qF 'chain-execution.md` §Starterkit detection + mode classification' "$FD" \
  && grep -qF 'Starterkit detection + mode classification' "$OF/chain-execution.md" \
  && pass "B4: starterkit pointer names the owner that actually holds the table (round fold)" \
  || fail "B4: starterkit pointer misroutes (owner heading missing or pointer wrong)"

# ── A2 — halt-taxonomy aligned to the canonical registry ──
HT="$OF/halt-taxonomy.md"
if ! grep -q 'classification conflict' "$HT" \
   && grep -q '## Self-resolve (C1' "$HT" \
   && grep -qF 'memory_in_use` · `mode_migrate` · `invalid_handoff` · `partial_state_corrupt` · `verify_unit_writable' "$HT"; then
  pass "A2: 5 admitted conflicts resolved into the C1 self-resolve list"
else fail "A2: halt-taxonomy conflicts not resolved"; fi

# ── A3 — staging drop advisory in the emitted template ──
T4="$P/skills/generate-intent/references/templates/flows.md"
if grep -qF 'advisory `vault_flow_staging_drop`' "$T4" && ! grep -qF 'staging_drop` halt' "$T4"; then
  pass "A3: 04-flows template teaches advisory, not a halt"
else fail "A3: template still stamps a staging-drop halt"; fi

# ── A4 — express lane-default fork closed ──
if grep -qF 'Lane default:' "$P/skills/bind-codebase/SKILL.md" \
   && grep -qF 'the lane the express spine dispatches by default' "$P/skills/bind-codebase/references/express-bind.md" \
   && ! grep -qF '(default — auto-resolves' "$P/skills/resolve-oq/references/interactive-walk.md"; then
  pass "A4: lane default stated once; ref + walk demoted to routing facts"
else fail "A4: express lane-default fork survives"; fi

# ── A5 — detect-drift fork reality ──
RF="$P/skills/detect-drift/references/report-format.md"
if ! grep -qi 'Batch-confirm UX' "$RF" \
   && ! grep -q '^## DRIFT-ACTIONS.md structure' "$RF" \
   && grep -qiE 'deprecated \(v3.0.0\)' "$RF"; then
  pass "A5: write-back protocol non-interactive; deprecation pin kept verbatim"
else fail "A5: ACCEPT-flow residue, template section, or lost deprecation pin"; fi
if ! grep -q 'Walkthrough captured actions' "$P/skills/detect-drift/SKILL.md" \
   && ! grep -qF 'Step 5.5 ACCEPT' "$P/skills/detect-drift/SKILL.md"; then
  pass "A5b: SKILL Step 6 pre-fork vocabulary purged"
else fail "A5b: pre-fork vocabulary survives in detect-drift SKILL"; fi
grep -qF 'awaiting human triage' "$OF/sync-digest.md" \
  && ! grep -qF 'proposed_patch in DRIFT-ACTIONS.md' "$OF/sync-digest.md" \
  && pass "A5c: sync-digest example matches the fork reality" \
  || fail "A5c: sync-digest still shows the ACCEPT-era artifact"
if ! grep -q 'the drift walkthrough CREATED' "$OF/routing-rules.md" \
   && grep -qF 'RETIRED pre-v3.0.0 interactive artifact' "$OF/routing-rules.md"; then
  pass "A5d: routing-rules purged of walkthrough-era teaching (round fold)"
else fail "A5d: walkthrough-era vocabulary survives in routing-rules"; fi
if ! grep -qF 'Patch bump for resolution-only' "$P/skills/resolve-oq/references/interactive-walk.md" \
   && ! grep -qF 'bump the vault version (minor)' "$P/skills/detect-drift/SKILL.md" \
   && ! grep -qF 'bump the vault version (minor)' "$P/skills/detect-drift/references/report-format.md"; then
  pass "A11d: abolished bump vocabulary purged from walk + drift surfaces (round fold)"
else fail "A11d: old Patch/minor bump vocabulary survives"; fi
if grep -qF 'follows its taxonomy class' "$OF/convergence-loops.md" \
   && grep -qF 'self-resolve C1' "$OF/convergence-loops.md" \
   && grep -qF -- '--mode=<value>' "$OF/halt-taxonomy.md"; then
  pass "A2b: convergence-loops defers to the 4-class taxonomy; mode_migrate override carve-out present (round fold)"
else fail "A2b: convergence-loops class deference or mode_migrate carve-out missing"; fi

# ── A6 — scan trio ──
grep -qF '(file, range.start.line, ruleId)' "$P/skills/scan-codebase/references/tree-sitter-integration.md" \
  && pass "A6: dedupe key aligned to the owner (3-tuple)" \
  || fail "A6: dedupe key still the definition-dropping 2-tuple"
grep -qF 'five subagent prompt templates' "$P/skills/scan-codebase/references/deep-scan-gate.md" \
  && pass "A6b: template count says five" || fail "A6b: 'four' survives"
if ! grep -qF '(v2.0 schema)' "$P/skills/scan-codebase/references/deep-scan-gate.md" \
   && ! grep -qF 'migrate to v2.0' "$P/skills/scan-codebase/references/deep-scan-gate.md" \
   && ! grep -qF 'cache_signatures v2.0 schema' "$P/skills/scan-codebase/references/deep-scan-dispatch.md" \
   && ! grep -qF 'new v2.0 `cache_signatures:`' "$P/skills/scan-codebase/references/deep-scan-dispatch.md"; then
  pass "A6c: cache_signatures labels unified at v2.1 (historical notes may remain)"
else fail "A6c: a stale v2.0 cache_signatures label survives"; fi

# ── A7 — residual expects-poison class purged (extends the 6.1.1 p8 pins) ──
DR="$P/skills/generate-units/references/decomposition-rails.md"
PB="$P/skills/generate-units/references/pbt-integration.md"
if grep -qF 'expects: ""' "$DR" && ! grep -qF 'description: "<gap 1' "$DR"; then
  pass "A7: decomposition-rails provenance example carries the substring contract"
else fail "A7: decomposition-rails example still description-shaped"; fi
if grep -qF 'expects: ""' "$PB" && ! grep -q 'expected_exit_code' "$PB"; then
  pass "A7b: pbt-integration example uses expects, not expected_exit_code"
else fail "A7b: pbt-integration still teaches a nonexistent field"; fi

# ── A8 — templates/unit.md aligned with unit-schema required frontmatter ──
TU="$P/skills/generate-units/references/templates/unit.md"
a8=0
for key in task_type grounding_confidence module; do
  grep -qE "^${key}:" "$TU" || { fail "A8: templates/unit.md missing required key ${key}:"; a8=1; }
done
grep -qF '## Context (read first)' "$TU" || { fail "A8: template Context heading not schema-shaped"; a8=1; }
grep -qF 'expects: ""                # substring the runner LITERALLY prints' "$TU" \
  || { fail "A8: the 6.1.1 expects line changed (must stay byte-identical)"; a8=1; }
[ "$a8" -eq 0 ] && pass "A8: template frontmatter + Context shape match unit-schema (expects line untouched)"

# ── A9 — memory config path unified ──
if ! grep -rq '~/.mega-sdd/config.yaml' "$P/skills/memory/"; then
  pass "A9: memory-layer config path unified at ~/.mega-sdd/memory/config.yaml"
else fail "A9: a stray ~/.mega-sdd/config.yaml citation survives in the memory skill"; fi

# ── A10 — extract generator-version placeholders ──
EX="$P/skills/extract-intelligence/SKILL.md"
n=$(grep -cF 'extract-intelligence@<skill-version>' "$EX")
if [ "$n" -eq 2 ] && ! grep -q 'extract-intelligence@1\.' "$EX"; then
  pass "A10: both emit-verbatim blocks carry the version placeholder"
else fail "A10: hardcoded generator versions survive (placeholders found: $n)"; fi

# ── A11 — bump grammar, ordinal, design vocabulary ──
DP="$P/skills/diff-vault/references/diff-procedure.md"
if grep -qF 'Small bump: vX.Y → vX.Y+1' "$DP" && grep -qF 'Scope bump: vX.Y → vX+1.0' "$DP" \
   && ! grep -qF 'Minor bump: v1.1 → v2.0' "$DP" \
   && grep -qF 'single owner' "$P/skills/diff-vault/SKILL.md" \
   && grep -qF 'owner grammar' "$P/skills/diff-vault/references/auto-and-chain.md"; then
  pass "A11: version-bump grammar single-owned with unambiguous vocabulary"
else fail "A11: bump-grammar fork survives"; fi
after5=$(grep -A1 '^5\. \*\*Reuse symbol index' "$P/skills/execute-bolts/SKILL.md" | sed -n '2p' | cut -c1-2)
if [ "$after5" = "6." ] && grep -q '^6\. \*\*PBT citation pre-flight' "$P/skills/execute-bolts/SKILL.md"; then
  pass "A11b: duplicate pre-flight ordinal renumbered (Reuse=5, PBT=6, no adjacent 5./5.)"
else fail "A11b: pre-flight ordinals still collide (line after Reuse-5 starts: '$after5')"; fi
DRV="$P/agents/design-reviewer.md"
if ! grep -q "traits/anti-patterns" "$DRV" && grep -qF 'best-for / avoid-for' "$DRV"; then
  pass "A11c: design-reviewer speaks the delivered slice vocabulary"
else fail "A11c: design-reviewer still expects the forbidden traits/anti-patterns lines"; fi

# ── C — trace-tag completion (round-widened: EVERY announce-bearing skill) ──
for s in emit-prd emit-sit emit-fsd emit-agents-md emit-uat bind-codebase execute-bolts extract-intelligence generate-units install-deps memory orchestrate-flow scan-codebase; do
  grep -qF "mega-sdd-trace:$s" "$P/skills/$s/SKILL.md" \
    && pass "C: $s carries its trace tag" \
    || fail "C: $s trace tag missing"
done
n_untagged=$(grep -l '\*\*Announce at start:\*\*' "$P"/skills/*/SKILL.md | while read -r f; do
  grep '\*\*Announce at start:\*\*' "$f" | grep -q 'mega-sdd-trace:' || echo "$f"
done | wc -l | tr -d ' ')
[ "$n_untagged" -eq 0 ] \
  && pass "C1b: zero announce templates without a trace tag (completion holds)" \
  || fail "C1b: $n_untagged announce template(s) still untagged"
grep -qF 'mega-sdd-trace:extract-intelligence' "$P/skills/extract-intelligence/references/wave-dispatch-templates.md" \
  && pass "C2: wave dispatch template carries the tag" || fail "C2: wave dispatch tag missing"
grep -qF 'mega-sdd-trace:scan-codebase' "$P/skills/scan-codebase/references/deep-scan-prompts.md" \
  && pass "C3: deep-scan common dispatch contract mandates the tag" || fail "C3: deep-scan tag rule missing"
grep -qF 'mega-sdd-trace:execute-bolts' "$P/skills/execute-bolts/references/review-panel.md" \
  && pass "C4: lens/verifier dispatch rule mandates the tag" || fail "C4: review-panel tag rule missing"

# ── D — infra batch ──
UPS="$P/hooks/user-prompt-submit"
fp=$(grep -n 'Fast negative short-circuit' "$UPS" | head -1 | cut -d: -f1)
py=$(grep -n 'shlex.quote() is load-bearing' "$UPS" | head -1 | cut -d: -f1)
if [ -n "$fp" ] && [ -n "$py" ] && [ "$fp" -lt "$py" ]; then
  pass "D1: user-prompt-submit fast negative path precedes the python3 parse"
else fail "D1: fast path missing or ordered after the python parse (fp=$fp py=$py)"; fi
# D2 (v7.0.0): the slim MANDATORY block is DELETED entirely (gate-1 decision) —
# a no-signal CWD gets zero injection. Assert the heredoc and its pin phrase are gone.
if ! grep -q "SLIM_EOF" "$P/hooks/session-start" && ! grep -q 'MANDATORY development workflow' "$P/hooks/session-start"; then
  pass "D2: v7 — non-SDD slim block deleted (no SLIM_EOF heredoc, no MANDATORY phrase)"
else fail "D2: v7 slim-block deletion regressed (SLIM_EOF or MANDATORY phrase back in session-start)"; fi
grep -qF -- '-lt 4000' tests/token-efficiency/test-b3-anchor-and-panel.sh \
  && pass "D3: anchor-core cap enforced (v7: 4000 — S/M/L table joined the core, spec 2026-08-21)" \
  || fail "D3: anchor cap missing/regressed"
[ ! -f "$P/skills/scan-codebase/references/deep-scan-stage.md" ] \
  && pass "D5: deep-scan-stage.md tombstone deleted" \
  || fail "D5: tombstone still present"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
