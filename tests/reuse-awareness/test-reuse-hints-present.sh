#!/usr/bin/env bash
set -u
err=0
for p in laravel django _universal; do
  grep -q '## Reuse discovery' "plugins/mega-sdd/references/framework-conventions/$p.md" || { echo "$p.md missing ## Reuse discovery"; err=1; }
done
grep -qE 'app/Helpers|app/Services|app/Console/Commands|app/Models' plugins/mega-sdd/references/framework-conventions/laravel.md || { echo "laravel reuse discovery not populated"; err=1; }
sec=$(sed -n '/## Reuse discovery/,/^## /p' plugins/mega-sdd/references/framework-conventions/_universal.md)
echo "$sec" | grep -qE 'app/Helpers|\.blade' && { echo "_universal reuse discovery leaks Laravel"; err=1; }
exit $err
