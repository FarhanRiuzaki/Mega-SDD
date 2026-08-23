#!/usr/bin/env bash
set -u
err=0
rp="plugins/mega-sdd/skills/execute-bolts/references/review-panel.md"
sb="plugins/mega-sdd/skills/execute-bolts/references/superpowers-bridge.md"
sk="plugins/mega-sdd/skills/execute-bolts/SKILL.md"
pc="plugins/mega-sdd/references/project-config.md"
mt="plugins/mega-sdd/references/model-tiers.md"

[ -f "$rp" ] || { echo "missing review-panel.md"; err=1; }
if [ -f "$rp" ]; then
  for t in minimal standard full "ONE message" "evidence" "dedup" "max-retries"; do
    grep -qi "$t" "$rp" || { echo "review-panel.md missing: $t"; err=1; }
  done
  # blind protocol: lenses never see the implementer's report or each other
  grep -qiE "NEVER contains.*implementer|never the implementer" "$rp" || { echo "review-panel.md missing blind protocol"; err=1; }
  # risk signals present
  grep -qi 'auth_hints' "$rp" || { echo "review-panel.md missing auth-glob risk signal"; err=1; }
  grep -qi 'manifest' "$rp" || { echo "review-panel.md missing dep-manifest risk signal"; err=1; }
  # models cited from catalog, never hardcoded
  grep -q 'model-tiers.md' "$rp" || { echo "review-panel.md must cite model-tiers catalog"; err=1; }
fi

# bridge routes the panel, depth-1 rationale intact, no stale two-stage flow
if [ -f "$sb" ]; then
  grep -qi 'review panel' "$sb" || { echo "superpowers-bridge missing panel flow"; err=1; }
  grep -qi 'BLIND' "$sb" || { echo "superpowers-bridge missing blind dispatch"; err=1; }
  grep -q 'security-reviewer' "$sb" || { echo "superpowers-bridge missing security lens"; err=1; }
  grep -q 'standards-reviewer' "$sb" || { echo "superpowers-bridge missing standards lens"; err=1; }
  grep -qi 'depth-2' "$sb" || { echo "superpowers-bridge lost depth rationale"; err=1; }
fi

# SKILL.md routes review-panel.md + the tier flag
if [ -f "$sk" ]; then
  grep -q 'references/review-panel.md' "$sk" || { echo "SKILL.md does not route review-panel.md"; err=1; }
  grep -q -- '--review-panel=' "$sk" || { echo "SKILL.md missing --review-panel flag"; err=1; }
fi

# config key documented
grep -q 'review_panel' "$pc" || { echo "project-config.md missing review_panel key"; err=1; }

# model-tiers catalog rows exist
grep -q 'security-reviewer' "$mt" || { echo "model-tiers missing security-reviewer row"; err=1; }
grep -q 'standards-reviewer' "$mt" || { echo "model-tiers missing standards-reviewer row"; err=1; }

# no stale "two-stage" wording left in execute-bolts surfaces or plugin CLAUDE.md
stale=$(grep -rl 'two-stage' plugins/mega-sdd/skills/execute-bolts plugins/mega-sdd/CLAUDE.md 2>/dev/null || true)
[ -n "$stale" ] && { echo "stale two-stage wording in: $stale"; err=1; }
exit $err
