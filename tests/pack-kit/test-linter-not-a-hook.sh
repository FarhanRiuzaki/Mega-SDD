#!/usr/bin/env bash
set -u
grep -rq 'validate-pack' plugins/mega-sdd/hooks/ 2>/dev/null && { echo "validate-pack wrongly wired into a hook (must stay author/CI tool)"; exit 1; }
exit 0
