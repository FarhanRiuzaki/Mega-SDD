#!/usr/bin/env bash
# Pin: the floor-vs-ceiling gap is closed end-to-end (baseline -> slice ->
# dispatch -> lens) and capture-views skips gracefully.
set -u
err=0
mb="plugins/mega-sdd/references/design-intelligence/modern-baseline.md"
ag="plugins/mega-sdd/agents/design-reviewer.md"
ce="plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md"
bp="plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md"
rp="plugins/mega-sdd/skills/execute-bolts/references/review-panel.md"
cap="plugins/mega-sdd/scripts/capture-views.sh"
pc="plugins/mega-sdd/references/project-config.md"

# baseline carries the ceiling contract + floor-is-not-the-goal framing
grep -q '## Ceiling moves' "$mb" || { echo "modern-baseline missing Ceiling moves"; err=1; }
grep -qi 'floor is NOT the goal' "$mb" || { echo "modern-baseline missing floor!=done framing"; err=1; }
for move in 'Page furniture' 'lone card' 'Iconography' 'signature'; do
  grep -qi "$move" "$mb" || { echo "ceiling move missing: $move"; err=1; }
done
# design lens demands the ceiling + judges render when present
grep -qi 'Floor vs ceiling' "$ag" || { echo "design-reviewer missing floor-vs-ceiling judgment"; err=1; }
grep -qi 'screenshots' "$ag" || { echo "design-reviewer missing render-judgment path"; err=1; }
grep -qi 'never imply you saw a render you' "$ag" || { echo "design-reviewer missing no-fabricated-render rail"; err=1; }
# slice + dispatch inject ceiling moves
grep -q 'Ceiling moves' "$ce" || { echo "design slice missing ceiling moves"; err=1; }
grep -q 'Ceiling moves' "$bp" || { echo "dispatch prompt missing ceiling moves"; err=1; }
# panel documents live-app capture + graceful skip
grep -qi 'capture-views.sh' "$rp" || { echo "review-panel missing live-app capture"; err=1; }
grep -qi 'never reported as fine' "$rp" || { echo "review-panel missing un-captured!=fine rail"; err=1; }
# config preview_url
grep -q 'preview_url' "$pc" || { echo "project-config missing preview_url"; err=1; }

# capture-views: executable, syntax, graceful skips
[ -x "$cap" ] || { echo "capture-views not executable"; err=1; }
bash -n "$cap" || { echo "capture-views syntax error"; err=1; }
out=$("$cap" --url=http://localhost:59999 --routes=/x --out=/tmp/cv-test-$$ 2>&1)
echo "$out" | grep -q '"skipped":true' || { echo "no-server must skip"; err=1; }
echo "$out" | grep -qi 'not reachable' || { echo "no-server skip missing reason"; err=1; }
out=$("$cap" --url=http://x 2>&1)
echo "$out" | grep -q '"skipped":true' || { echo "missing-args must skip"; err=1; }
# stack-agnostic: a system-chrome path exists (no hard Node dependency) and the
# docstring states the app can be any stack
grep -qi 'STACK-AGNOSTIC' "$cap" || { echo "capture-views not declared stack-agnostic"; err=1; }
grep -qi 'system.chrome\|Chromium' "$cap" || { echo "capture-views missing no-Node chrome driver"; err=1; }
grep -qiE 'Laravel|Django|any stack' "$cap" || { echo "capture-views missing non-JS stack coverage"; err=1; }
exit $err
