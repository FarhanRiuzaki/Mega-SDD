#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/references/starterkit-context-schema.md"
err=0
grep -q '^## §authz block' "$f" || { echo "missing §authz block"; err=1; }
grep -q 'declarations:' "$f" || { echo "missing authz.declarations"; err=1; }
grep -q 'mechanism:' "$f" || { echo "missing mechanism field"; err=1; }
grep -q 'role_source:' "$f" || { echo "missing role_source"; err=1; }
grep -q 'lib_source:' "$f" || { echo "missing lib_source"; err=1; }
grep -qE 'enum: sanctum \| breeze' "$f" && { echo "auth.lib still a closed Laravel enum"; err=1; }
grep -qE 'enum: spatie/permission' "$f" && { echo "authz.lib still a closed Laravel enum"; err=1; }
grep -qE '^\s*gates:' "$f" && { echo "old rbac.gates field still present"; err=1; }
grep -qE '^\s*policies:' "$f" && { echo "old rbac.policies field still present"; err=1; }
exit $err
