#!/usr/bin/env bash
set -u
golden="tests/de-laravelize/golden-laravel-tokens.txt"
pack="plugins/mega-sdd/references/framework-conventions/laravel.md"
err=0
while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  case "$tok" in \#*) continue;; esac
  grep -qF "$tok" "$pack" || { echo "NOT RELOCATED: $tok"; err=1; }
done < "$golden"
exit $err
