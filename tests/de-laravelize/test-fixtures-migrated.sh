#!/usr/bin/env bash
set -u
err=0
while IFS= read -r f; do
  if grep -qE '^[[:space:]]*rbac:' "$f"; then echo "old rbac: shape in $f"; err=1; fi
  if grep -qE '^[[:space:]]*guard:' "$f"; then echo "old auth.guard in $f"; err=1; fi
done < <(find tests -name starterkit-context.yaml)
exit $err
