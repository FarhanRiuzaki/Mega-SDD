#!/usr/bin/env bash
set -u
r="plugins/mega-sdd/references/framework-conventions/_registry.md"
for fw in fastapi next express nestjs django; do
  grep -qiE "^\| $fw .*ready" "$r" || { echo "$fw not ready in registry"; exit 1; }
done
exit 0
