#!/usr/bin/env bash
set -u
a="plugins/mega-sdd/agents/phase-advisor.md"
s="plugins/mega-sdd/references/advisor-findings-schema.md"
err=0
[ -f "$a" ] || { echo "missing phase-advisor.md"; err=1; }
[ -f "$s" ] || { echo "missing advisor-findings-schema.md"; err=1; }
if [ -f "$a" ]; then
  fm=$(sed -n '1,12p' "$a")
  echo "$fm" | grep -q 'name: phase-advisor' || { echo "bad name"; err=1; }
  echo "$fm" | grep -q 'model: opus' || { echo "advisor must be opus"; err=1; }
  echo "$fm" | grep -qiE 'tools:.*Read' || { echo "needs Read tool"; err=1; }
  # read-only: must NOT have Write/Edit; must NOT have forbidden plugin-agent keys
  echo "$fm" | grep -qiE 'Write|Edit' && { echo "advisor must be read-only (no Write/Edit)"; err=1; }
  echo "$fm" | grep -qiE 'hooks:|mcpServers:|permissionMode:' && { echo "forbidden plugin-agent frontmatter key"; err=1; }
  grep -qiE 'adversarial|find what is wrong|refute|second opinion' "$a" || { echo "agent body not adversarial"; err=1; }
  grep -qiE 'evidence|_source|cite' "$a" || { echo "agent missing evidence-required discipline"; err=1; }
fi
if [ -f "$s" ]; then
  for t in false_confirmed missed_match false_conflict fabrication missed_oq misclassification; do
    grep -q "$t" "$s" || { echo "schema missing finding type: $t"; err=1; }
  done
  grep -qiE 'evidence' "$s" || { echo "schema missing evidence rail"; err=1; }
  grep -qiE 'never auto-downgrade|never auto-remove|human-only' "$s" || { echo "schema missing moat-asymmetry rail"; err=1; }
fi
exit $err
