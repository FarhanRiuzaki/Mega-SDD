#!/usr/bin/env bash
# test-p3-oq-defer-risk-router.sh — v6 P3 proof suite (spec §P3.5). The router
# fixtures (§1/1b) left with resolve-review-tier.sh in P3 (spec v9 §8.6).
#   2. OQ prose pins — batched P1 walk, auto-defer recorded + rails re-scoped,
#      A6 resurface surfaces (metrics id list, _summary section, Step 9 +
#      appendix bullets).
#   3. Lean-by-default — orchestrate paragraph, Stop-aggregate condition
#      (classic|full fires, lean never). (The advisor legs died v7.4.0.)
# CI-safe: bash + python3 only.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
P="$REPO_ROOT/plugins/mega-sdd"
fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

# ── 2. OQ prose pins ─────────────────────────────────────────────────────────
RO="$P/skills/resolve-oq"
grep -qF 'express-batched' "$RO/SKILL.md" && grep -qF 'ceil(N/4)' "$RO/SKILL.md" \
  && pass "SKILL: express-batched scope + chunking rule" || fail "batched scope missing"
grep -qF 'auto-deferred (P<n>, express)' "$RO/SKILL.md" \
  && pass "SKILL: mechanical defer reason format" || fail "defer reason missing"
# 9.0 P1: the classic spine is retired, so the "every classic-spine invocation"
# clause went with it; the surviving rail (a standalone/explicit invocation
# keeps the interactive walk, auto-defer never applies there) is repointed.
grep -qF 'A standalone/explicit invocation (any spine) keeps the fully interactive walk — auto-defer NEVER applies there' "$RO/SKILL.md" \
  && pass "SKILL: interactive walk preserved outside the express chain" || fail "rail re-scope missing"
grep -qF 'this rail governs ANSWERS' "$RO/SKILL.md" \
  && pass "SKILL: refuse-rail scoped to answers (defer invents nothing)" || fail "refuse-rail scope missing"
grep -qF 'Express-batched variant' "$RO/references/interactive-walk.md" \
  && pass "walk: batched variant (same grammar, fewer round trips)" || fail "walk variant missing"
grep -qF 'ALWAYS stay interactive on the BLOCKING tier' "$RO/references/auto-memory-handoff.md" \
  && pass "handoff ref: substance-prompt rail re-scoped" || fail "handoff rail missing"
grep -qF 'ID LIST, never a bare count' "$RO/references/auto-memory-handoff.md" \
  && pass "metrics.items_deferred is an id list (a count cannot re-surface)" || fail "metrics id list missing"

# A6 surfaces
grep -qF '## Deferred open questions (N)' "$P/skills/execute-bolts/references/halts-and-handoff.md" \
  && pass "_summary.md gains the deferred-OQ section" || fail "_summary section missing"
grep -qF 'Deferred open questions (P3/A6)' "$P/skills/orchestrate-flow/references/chain-execution.md" \
  && pass "--deep appendix carries the deferred-OQ bullet" || fail "appendix bullet missing"
grep -qF 'Deferred-OQ resurface (P3/A6, ALWAYS' "$P/skills/orchestrate-flow/SKILL.md" \
  && pass "Step 9 resurfaces deferred OQs (deep or not)" || fail "Step 9 line missing"

# ── 3. Lean default ──────────────────────────────────────────────────────────

OF="$P/skills/orchestrate-flow/SKILL.md"
# 9.0 P1: express is the only spine, so the "on the express spine" qualifier
# (and the classic-spine keep-them branch) was dropped; lean-by-default survives.
grep -qF 'Diagnostics are LEAN-BY-DEFAULT (P3):** the ADVISORY diagnostics in this loop' "$OF" \
  && pass "diagnostics lean-by-default (express is the only spine)" || fail "lean default missing"
# v7.4.0 (Fase 5 №5): the phase-advisor was REMOVED — the scope-gated
# default-on sentence must be GONE, not merely reworded (negative pin).
if grep -qF 'advisor legs stay default-on' "$OF"; then
  fail "advisor default-on sentence is back — the phase-advisor was removed v7.4.0"
else
  pass "advisor legs stay removed from the chain loop (v7.4.0)"
fi
grep -qF 'spine:' "$P/hooks/stop" && grep -qF 'profile:[[:space:]]*[\"'"'"']?full' "$P/hooks/stop" \
  && pass "Stop aggregate keyed to classic|full opt-in" || fail "stop condition missing"
grep -qF 'HONESTY NOTE (P3)' "$P/scripts/_lib/state_probes.py" \
  && pass "pending_p0_p1 docstring honesty (no P0 exists)" || fail "docstring note missing"
grep -qF 'spine: express' "$P/references/project-config.md" \
  && pass "project-config documents spine + profile semantics" || fail "config doc missing"

echo
if [ "$fails" -eq 0 ]; then echo "test-p3-oq-defer-risk-router: ALL PASS"; exit 0
else echo "test-p3-oq-defer-risk-router: $fails FAILURE(S)"; exit 1; fi
