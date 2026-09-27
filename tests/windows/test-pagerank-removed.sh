#!/usr/bin/env bash
# test-pagerank-removed.sh — D1 (spec 2026-08-02-reuse-first-grounding-index.md).
# Successor of test-pagerank-spawn-gate.sh: that suite pinned the spawn-cost gate
# that kept the PageRank pass from hanging Windows/EDR machines (~37 min at 10k
# files). 5.29.0 removed the PASS itself — the whole hazard class is gone, and
# this suite pins that it STAYS gone (no resurrection, no dangling citations).
# 9.0 (P1): generate-units was removed; its Step 7.5 tombstone and the
# `--skip-pagerank` accepted-no-op shim (promised "through the 5.x cycle",
# CHANGELOG 5.29.0) went with it — those two assertions are retired. The
# surviving contracts it relocated (task-typing -> plan/references/, its halt
# guidance -> references/halt-families/units.md) are re-pinned below.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }

# resurrection check spans the whole plugin (the reference's old home,
# skills/generate-units/, is gone in 9.0; a re-add under plan/ must fail too)
RESURRECTED=$(find "$P" -name 'pagerank-targeting*' 2>/dev/null || true)
if [ -n "$RESURRECTED" ]; then
  fail "pagerank-targeting.md resurrected: $RESURRECTED"
else
  ok "pagerank-targeting.md removed (no copy anywhere under the plugin)"
fi

# task-typing relocated to plan/references/ in 9.0 (P1) — the file must exist
# (else the negative grep is vacuous) and must not carry the pass's procedure
TT="$P/skills/plan/references/task-typing.md"
if [ ! -f "$TT" ]; then
  fail "relocated task-typing missing at $TT"
elif grep -qiE "spawn-cost gate FIRST|symbol-reference graph|personalized PageRank" "$TT"; then
  fail "task-typing still carries the pass's procedure"
else
  ok "task-typing (plan/references) carries no trace of the pass's procedure"
fi
# generate-units' halt guidance relocated to references/halt-families/units.md
# in 9.0 (P1) — the symbol-graph confirm gate must not come back untombstoned
HU="$P/references/halt-families/units.md"
if [ ! -f "$HU" ]; then
  fail "relocated units halt family missing at $HU"
elif grep -qF "estimated symbol-graph build > 60 s" "$HU" \
   && ! grep -qF "REMOVED 5.29.0" "$HU"; then
  fail "units halt family: symbol-graph confirm gate survived without the tombstone"
else
  ok "units halt family carries no live symbol-graph confirm gate"
fi

# no surface outside spec/CHANGELOG/tests may still CITE the removed reference —
# EXTENSIONLESS spelling included (the pre-change files wrote "the
# pagerank-targeting reference"), commands/ + agents/ + the top-level README in scope
DANGLING=$(grep -rl "pagerank-targeting" "$P/skills" "$P/references" "$P/scripts" "$P/hooks" "$P/commands" "$P/agents" 2>/dev/null || true)
if [ -n "$DANGLING" ]; then
  fail "dangling citations of pagerank-targeting: $DANGLING"
else
  ok "zero dangling citations in skills/references/scripts/hooks/commands/agents"
fi
# prose sweep: no LIVE surface may still TEACH the pass (tombstone lines exempt
# by their own wording; historical records — research/, CHANGELOG — out of scope)
TEACH=$(grep -rn "PageRank" "$P/skills" "$P/references" "$ROOT/README.md" 2>/dev/null \
        | grep -v "REMOVED 5.29.0\|removed 5.29.0\|was removed\|skip-pagerank\|PageRank pass" || true)
if [ -n "$TEACH" ]; then
  fail "a live surface still teaches PageRank: $TEACH"
else
  ok "no live surface teaches the removed pass (README + skills + references swept)"
fi

grep -qF "symbol-graph.json caches from <5.29.0 are inert" "$P/references/paths.md" \
  && ok "paths.md: stale caches declared inert (no migration needed)" \
  || fail "paths.md inert-cache note missing"

# the replacement is real: the write-time symbol_slice ships (R2, v5.28.0)
grep -qF 'add_section("symbol_slice"' "$P/scripts/build-dispatch-prompt.sh" \
  && ok "the replacement (dispatch symbol_slice) is present — removal is not a regression to nothing" \
  || fail "symbol_slice missing from the dispatch builder"

[ "$FAILED" = "0" ] && echo "ALL PAGERANK-REMOVED PROOFS OK" || echo "pagerank-removed proofs FAILED"
exit $FAILED
