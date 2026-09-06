#!/usr/bin/env bash
# test-pagerank-removed.sh — D1 (spec 2026-08-02-reuse-first-grounding-index.md).
# Successor of test-pagerank-spawn-gate.sh: that suite pinned the spawn-cost gate
# that kept the PageRank pass from hanging Windows/EDR machines (~37 min at 10k
# files). 5.29.0 removed the PASS itself — the whole hazard class is gone, and
# this suite pins that it STAYS gone (no resurrection, no dangling citations,
# flag-compat honored).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }

if [ -e "$P/skills/generate-units/references/pagerank-targeting.md" ]; then
  fail "pagerank-targeting.md resurrected"
else
  ok "pagerank-targeting.md removed"
fi

GU="$P/skills/generate-units"
grep -qF "REMOVED 5.29.0" "$GU/SKILL.md" \
  && ok "SKILL Step 7.5 carries the removal tombstone (numbering preserved)" \
  || fail "SKILL 7.5 tombstone missing"
grep -qF "accepted NO-OP since 5.29.0" "$GU/SKILL.md" \
  && ok "--skip-pagerank stays listed as an accepted no-op (compat shim; removal rides the next MAJOR)" \
  || fail "--skip-pagerank flag-compat line missing"
if grep -qiE "spawn-cost gate FIRST|symbol-reference graph|personalized PageRank" "$GU/references/task-typing.md"; then
  fail "task-typing still carries the pass's procedure"
else
  ok "task-typing 7.5 reduced to the tombstone"
fi
if grep -qF "estimated symbol-graph build > 60 s" "$GU/references/halt-protocol.md" \
   && ! grep -qF "REMOVED 5.29.0" "$GU/references/halt-protocol.md"; then
  fail "halt-protocol confirm gate survived without the tombstone"
else
  ok "halt-protocol confirm gate tombstoned"
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
