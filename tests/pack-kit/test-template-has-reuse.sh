#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/references/framework-conventions/_template.md"
grep -q '## Reuse discovery' "$f" || { echo "_template.md missing ## Reuse discovery"; exit 1; }
grep -q 'reuse_hints' "$f" || { echo "_template.md Reuse discovery missing reuse_hints"; exit 1; }
exit 0
