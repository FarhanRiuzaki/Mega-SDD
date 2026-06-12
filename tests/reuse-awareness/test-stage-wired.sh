#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/skills/scan-codebase/references/deep-scan-stage.md"
err=0
grep -q 'reuse-extractor' "$f" || { echo "stage does not list reuse-extractor"; err=1; }
grep -qE 'reuse-index\.yaml' "$f" || { echo "stage does not emit reuse-index.yaml"; err=1; }
grep -qE '\breuse\b' "$f" || { echo "reuse not referenced as a slice"; err=1; }
exit $err
