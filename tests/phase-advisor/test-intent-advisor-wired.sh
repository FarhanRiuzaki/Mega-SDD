#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/skills/generate-intent/SKILL.md"
err=0
grep -qiE 'phase-advisor' "$f" || { echo "intent does not dispatch phase-advisor"; err=1; }
grep -q 'advisor-checklist' "$f" || { echo "intent does not reference the intent advisor checklist"; err=1; }
grep -qE 'no-advisor' "$f" || { echo "intent missing --no-advisor flag"; err=1; }
grep -qiE 'before .*self-check|before .*Step 4|before delivery|before finaliz' "$f" || { echo "intent advisor not ordered before finalize"; err=1; }
grep -qiE 'OQ|flag' "$f" || { echo "intent materialization not specified"; err=1; }
exit $err
