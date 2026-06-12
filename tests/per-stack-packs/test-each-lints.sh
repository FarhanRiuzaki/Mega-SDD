#!/usr/bin/env bash
set -u
for fw in fastapi next express nestjs django; do
  bash plugins/mega-sdd/scripts/validate-pack.sh "plugins/mega-sdd/references/framework-conventions/$fw.md" >/dev/null 2>&1 \
    || { echo "$fw.md has lint violations"; exit 1; }
done
exit 0
