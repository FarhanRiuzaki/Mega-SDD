#!/usr/bin/env bash
# Generic, wave-proof gate: every pack_tier: full pack must lint clean AND be
# registered as 'ready'. Future framework packs are covered automatically.
set -u
conv="plugins/mega-sdd/references/framework-conventions"
reg="$conv/_registry.md"
rc=0
for f in "$conv"/*.md; do
  base=$(basename "$f")
  case "$base" in
    _*|README.md) continue ;;
  esac
  # only enforce on packs that declare pack_tier: full
  tier=$(awk '/^---/{n++; if(n==1)next; if(n==2)exit} n==1' "$f" | grep -m1 '^pack_tier:' | sed 's/pack_tier:[[:space:]]*//' | tr -d '"'"'" | tr -d '[:space:]')
  [ "$tier" = "full" ] || continue
  fw="${base%.md}"
  if ! bash plugins/mega-sdd/scripts/validate-pack.sh "$f" >/dev/null 2>&1; then
    echo "FAIL: $base (pack_tier: full) has lint violations"; rc=1
  fi
  grep -qiE "^\| $fw .*ready" "$reg" || { echo "FAIL: $fw not 'ready' in registry"; rc=1; }
done
exit $rc
