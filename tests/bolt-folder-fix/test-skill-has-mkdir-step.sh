#!/usr/bin/env bash
# The execute-bolts per-unit procedure MUST create the bolt dir deterministically.
set -u
f="plugins/mega-sdd/skills/execute-bolts/SKILL.md"
grep -qE 'mkdir -p .*<vault>/bolts/U-XXX' "$f" || { echo "SKILL.md missing deterministic 'mkdir -p <vault>/bolts/U-XXX/' step"; exit 1; }
grep -qiE 'bolt_artifacts_missing' "$f" || { echo "SKILL.md does not reference the bolt_artifacts_missing gate"; exit 1; }
exit 0
