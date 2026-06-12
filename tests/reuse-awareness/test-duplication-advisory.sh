#!/usr/bin/env bash
set -u
err=0
v="plugins/mega-sdd/scripts/validate-reuse-duplication.sh"
[ -f "$v" ] || { echo "missing validate-reuse-duplication.sh"; err=1; }
[ -x "$v" ] || { echo "validator not executable"; err=1; }
grep -qiE 'advisory|never block|exit 0' "$v" || { echo "validator not marked advisory"; err=1; }
grep -q 'validate-reuse-duplication' plugins/mega-sdd/hooks/pre-tool-use && { echo "duplication check wrongly wired into PreToolUse (must stay advisory)"; err=1; }
exit $err
