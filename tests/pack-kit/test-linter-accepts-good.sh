#!/usr/bin/env bash
set -u
bash plugins/mega-sdd/scripts/validate-pack.sh plugins/mega-sdd/references/framework-conventions/laravel.md
rc=$?; [ $rc -eq 0 ] || { echo "linter rejected the reference laravel.md (rc=$rc)"; exit 1; }
exit 0
