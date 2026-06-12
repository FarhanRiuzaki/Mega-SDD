#!/usr/bin/env bash
# Pin: the greenfield design pipe is closed end-to-end —
# vault design_system -> design slice -> dispatch prompt -> design lens.
set -u
err=0
ce="plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md"
bp="plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md"
rp="plugins/mega-sdd/skills/execute-bolts/references/review-panel.md"
sb="plugins/mega-sdd/skills/execute-bolts/references/superpowers-bridge.md"
mb="plugins/mega-sdd/references/design-intelligence/modern-baseline.md"
ag="plugins/mega-sdd/agents/design-reviewer.md"
mt="plugins/mega-sdd/references/model-tiers.md"

# the baseline exists with the two injectable digests
[ -f "$mb" ] || { echo "missing modern-baseline.md"; err=1; }
if [ -f "$mb" ]; then
  grep -q '## Non-negotiables' "$mb" || { echo "modern-baseline missing Non-negotiables"; err=1; }
  grep -qi 'anti-kuno' "$mb" || { echo "modern-baseline missing anti-kuno tells"; err=1; }
  grep -qi 'starterkit' "$mb" || { echo "modern-baseline missing precedence (starterkit authoritative)"; err=1; }
fi
# context-enrichment: design slice independent of starterkit, greenfield path
if [ -f "$ce" ]; then
  grep -q '## Design slice' "$ce" || { echo "context-enrichment missing Design slice section"; err=1; }
  grep -qi 'INDEPENDENT of starterkit' "$ce" || { echo "design slice not declared starterkit-independent"; err=1; }
  grep -q 'ui_bearing' "$ce" || { echo "design slice missing ui_bearing detection"; err=1; }
  grep -q 'modern-baseline.md' "$ce" || { echo "design slice does not pull modern-baseline"; err=1; }
fi
# dispatch prompt carries the section + anti-halu rails
if [ -f "$bp" ]; then
  grep -q '## Design system (UI-bearing unit' "$bp" || { echo "dispatch prompt missing design section"; err=1; }
  grep -qi 'never invent a second palette' "$bp" || { echo "dispatch prompt missing palette rail"; err=1; }
fi
# design lens: agent exists, read-only, sonnet, blind, evidence-disciplined
[ -f "$ag" ] || { echo "missing design-reviewer agent"; err=1; }
if [ -f "$ag" ]; then
  fm=$(sed -n '1,10p' "$ag")
  echo "$fm" | grep -q 'model: sonnet' || { echo "design-reviewer must be sonnet (catalog)"; err=1; }
  echo "$fm" | grep -E '^tools:' | grep -qiE 'Write|Edit' && { echo "design-reviewer must be read-only"; err=1; }
  echo "$fm" | grep -qiE 'hooks:|mcpServers:|permissionMode:' && { echo "forbidden plugin-agent key"; err=1; }
  grep -qi 'blind' "$ag" || { echo "design-reviewer missing blind discipline"; err=1; }
  grep -qi 'file:line' "$ag" || { echo "design-reviewer missing evidence discipline"; err=1; }
fi
# panel: design lens row + additive join rule
if [ -f "$rp" ]; then
  grep -q 'design-reviewer' "$rp" || { echo "review-panel missing design lens"; err=1; }
  grep -qi 'Additive design lens' "$rp" || { echo "review-panel missing additive join rule"; err=1; }
fi
grep -q 'design-reviewer' "$sb" || { echo "superpowers-bridge missing design-reviewer"; err=1; }
grep -q 'design-reviewer' "$mt" || { echo "model-tiers missing design-reviewer row"; err=1; }
exit $err
