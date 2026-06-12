#!/usr/bin/env bash
set -u
err=0
for pair in "security-reviewer:opus" "standards-reviewer:sonnet"; do
  name="${pair%%:*}"; tier="${pair##*:}"
  a="plugins/mega-sdd/agents/${name}.md"
  [ -f "$a" ] || { echo "missing ${name}.md"; err=1; continue; }
  fm=$(sed -n '1,10p' "$a")
  echo "$fm" | grep -q "name: ${name}" || { echo "${name}: bad name"; err=1; }
  echo "$fm" | grep -q "model: ${tier}" || { echo "${name}: must be ${tier} (model-tiers catalog)"; err=1; }
  echo "$fm" | grep -qE 'tools:.*Read' || { echo "${name}: needs Read tool"; err=1; }
  # read-only: no Write/Edit in tools; no forbidden plugin-agent keys
  echo "$fm" | grep -E '^tools:' | grep -qiE 'Write|Edit' && { echo "${name}: must be read-only (no Write/Edit)"; err=1; }
  echo "$fm" | grep -qiE 'hooks:|mcpServers:|permissionMode:' && { echo "${name}: forbidden plugin-agent frontmatter key"; err=1; }
  grep -qi 'blind' "$a" || { echo "${name}: body missing blind-review discipline"; err=1; }
  grep -qi 'file:line' "$a" || { echo "${name}: body missing file:line evidence discipline"; err=1; }
  grep -qE 'Critical' "$a" || { echo "${name}: body missing severity grades"; err=1; }
done
# security lens covers the AI-specific classes
s="plugins/mega-sdd/agents/security-reviewer.md"
if [ -f "$s" ]; then
  for t in "input validation" "authz" "ecrets" "depend" "fail-open" "drift"; do
    grep -qi "$t" "$s" || { echo "security-reviewer: missing class: $t"; err=1; }
  done
fi
# standards lens forbids machine-fixable nits + enforces surrounding-code ground truth
t="plugins/mega-sdd/agents/standards-reviewer.md"
if [ -f "$t" ]; then
  grep -qi 'formatter' "$t" || { echo "standards-reviewer: missing formatter exclusion"; err=1; }
  grep -qi 'sibling' "$t" || { echo "standards-reviewer: missing surrounding-code ground truth"; err=1; }
fi
# quality lens stays out of security + machine territory, prioritizes duplication/reuse
q="plugins/mega-sdd/agents/code-quality-reviewer.md"
if [ -f "$q" ]; then
  grep -qiE 'failure-to-reuse|reuse-index' "$q" || { echo "code-quality-reviewer: missing duplication/reuse priority"; err=1; }
  grep -qiE 'security lens|other panel lenses' "$q" || { echo "code-quality-reviewer: missing lens-boundary (security moved out)"; err=1; }
  grep -qi 'blind' "$q" || { echo "code-quality-reviewer: missing blind-review discipline"; err=1; }
fi
exit $err
