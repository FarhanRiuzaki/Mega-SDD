#!/usr/bin/env bash
set -u
bash plugins/mega-sdd/scripts/validate-pack.sh --check-registry || { echo "_registry.md stale — run --registry"; exit 1; }
r="plugins/mega-sdd/references/framework-conventions/_registry.md"
grep -qiE 'laravel.*ready' "$r" || { echo "laravel not ready in registry"; exit 1; }
# django was a thin proof-pack in 3b; promoted to a full pack in 3c (per-stack-packs)
grep -qiE 'django.*ready' "$r" || { echo "django not ready in registry"; exit 1; }
grep -qiE 'none' "$r" || { echo "registry lists no 'none' framework"; exit 1; }
exit 0
