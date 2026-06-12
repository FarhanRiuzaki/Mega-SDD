#!/usr/bin/env bash
# Pin: the Security idioms slice reaches the security lens + the implementer.
set -u
err=0
rp="plugins/mega-sdd/skills/execute-bolts/references/review-panel.md"
tpl="plugins/mega-sdd/references/framework-conventions/_template.md"
grep -q 'Security idioms' "$rp" || { echo "review-panel.md: security lens does not receive the Security idioms slice"; err=1; }
grep -qi 'security-reviewer' "$tpl" || { echo "_template.md: section spec does not name its consumer"; err=1; }
grep -qi 'bolt-implementer' "$tpl" || { echo "_template.md: section spec does not name the implementer consumption path"; err=1; }
exit $err
