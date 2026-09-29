#!/usr/bin/env bash
# test-p3-carried-pins.sh — pins carried out of tests/surface/test-p7-bolt-loop-efficiency.sh
# before that per-unit suite is deleted (P3 plan research/2026-09-28-p3-deletion-plan.md §3d):
#   M8  the emitted consumer-guide template keeps vault ids OUT of code comments
#       (re-pointed from the removed generate-intent template to plan's)
#   F1  halts-and-handoff keeps the evidence-commit batching section (spec D7)
#   F2  no standalone gate-state-refresh commit
# Run: bash tests/surface/test-p3-carried-pins.sh </dev/null
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
FAIL=0
note() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

TPL="$P/skills/plan/references/templates/ai-consumer-guide.md"
HH="$P/skills/execute-bolts/references/halts-and-handoff.md"
for f in "$TPL" "$HH"; do [ -f "$f" ] || note "missing $f"; done

# M8: the positive rule is present, and the old teaching is absent
grep -qF "Never put a vault claim/flow/OQ id in a CODE COMMENT" "$TPL" || note "M8 ai-consumer-guide template lost the no-ids-in-code-comments rule"
grep -q "commit messages or code comments" "$TPL" && note "M8 ai-consumer-guide template teaches comment citations"

# F1/F2: evidence-commit batching (D7)
grep -q "Evidence-commit batching" "$HH" || note "F1 batching section"
grep -q "refresh gate state.* is never emitted\|standalone gate-state-refresh commit" "$HH" || note "F2 no standalone refresh commits"

if [ "$FAIL" -eq 0 ]; then echo "PASS: p3 carried pins (M8, F1, F2)"; exit 0; fi
echo "FAILURES: $FAIL"; exit 1
