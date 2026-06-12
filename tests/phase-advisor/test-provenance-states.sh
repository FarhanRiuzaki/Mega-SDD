#!/usr/bin/env bash
set -u
err=0
for f in plugins/mega-sdd/skills/bind-codebase/SKILL.md plugins/mega-sdd/skills/generate-intent/SKILL.md; do
  grep -qiE 'advisor: skipped|advisor.*skipped' "$f" || { echo "$f missing 'skipped' provenance"; err=1; }
  grep -qiE 'advisor: unavailable|advisor.*unavailable' "$f" || { echo "$f missing 'unavailable' provenance"; err=1; }
  grep -qiE 'never reported as clean|NEVER reported as clean' "$f" || { echo "$f does not distinguish unavailable from clean"; err=1; }
done
exit $err
