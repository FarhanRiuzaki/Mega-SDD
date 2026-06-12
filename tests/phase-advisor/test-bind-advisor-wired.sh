#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/skills/bind-codebase/SKILL.md"
err=0
grep -qiE 'phase-advisor' "$f" || { echo "bind does not dispatch phase-advisor"; err=1; }
grep -q 'advisor-checklist' "$f" || { echo "bind does not reference the binding advisor checklist"; err=1; }
grep -qE 'no-advisor' "$f" || { echo "bind missing --no-advisor flag"; err=1; }
grep -qiE 'CONFLICT-NNN|canonical .*CONFLICT' "$f" || { echo "bind materialization does not specify canonical CONFLICT-NNN"; err=1; }
grep -qiE 'before .*aggregate|Step 2.12|before Step 3' "$f" || { echo "bind advisor not ordered before aggregate counts"; err=1; }
grep -qiE 'never .*downgrade|human-only|flag .*only' "$f" || { echo "bind missing moat-asymmetry"; err=1; }
exit $err
