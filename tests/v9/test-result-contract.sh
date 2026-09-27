#!/usr/bin/env bash
# Owner principle (spec 2026-09-27-v9-simplification-design.md §0.1): consistent, result-oriented
# output — every lane ends with the SAME result contract. Pins the four report items and the
# delivery-check PASS precondition verbatim in both places that end a run: the direct/assisted
# lane procedure and the guarded lane's execute-bolts hand-off.
set -u
P="$(cd "$(dirname "$0")/../.." && pwd)/plugins/mega-sdd"
rc=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; rc=1; }
for f in references/direct-lane.md skills/execute-bolts/SKILL.md; do
  for item in "a table of every criterion with its status and the test that covers it" \
              "the delivery-check verdict" \
              "every assumption and decision you made" \
              "the commits" \
              'VERDICT: PASS'; do
    grep -qF -- "$item" "$P/$f" && ok "$f carries: $item" || bad "$f is missing the result-contract item: $item"
  done
done
grep -q 'delivery-check.sh' "$P/skills/execute-bolts/SKILL.md" && grep -q 'delivery-check.sh' "$P/references/direct-lane.md" \
  && ok "both lanes run scripts/delivery-check.sh" || bad "a lane no longer runs delivery-check.sh"
exit $rc
