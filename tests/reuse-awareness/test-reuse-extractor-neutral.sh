#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md"
err=0
grep -q '## reuse-extractor prompt' "$f" || { echo "missing reuse-extractor prompt"; err=1; }
grep -q '<REUSE_FILE_HINTS>' "$f" || { echo "missing <REUSE_FILE_HINTS>"; err=1; }
body=$(sed -n '/## reuse-extractor prompt/,/^## [a-z]/p' "$f")
echo "$body" | grep -nE 'app/Helpers|app/Models|app/Services|app/Console|\.blade\.php|artisan|Eloquent' && { echo "Laravel leak in reuse prompt"; err=1; }
exit $err
