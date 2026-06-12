#!/usr/bin/env bash
set -u
tmp="tests/fixtures/pack-kit/.scratch"; rm -rf "$tmp"; mkdir -p "$tmp"
out=$(SCAFFOLD_DEST_DIR="$tmp" bash plugins/mega-sdd/scripts/scaffold-pack.sh fastapi 2>&1); rc=$?
[ $rc -eq 0 ] || { echo "scaffold failed: $out"; exit 1; }
f="$tmp/fastapi.md"
[ -f "$f" ] || { echo "no skeleton produced"; exit 1; }
for s in "## File location standards" "## Deep-scan file hints" "## Authz mapping" "## UI detection" "## Reuse discovery"; do grep -qF "$s" "$f" || { echo "skeleton missing $s"; exit 1; }; done
grep -q 'framework: fastapi' "$f" || { echo "frontmatter not filled"; exit 1; }
SCAFFOLD_DEST_DIR="$tmp" bash plugins/mega-sdd/scripts/scaffold-pack.sh fastapi >/dev/null 2>&1 && { echo "clobbered existing"; exit 1; }
rm -rf "$tmp"; exit 0
