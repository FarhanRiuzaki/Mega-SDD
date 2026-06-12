#!/usr/bin/env bash
# Functional: project-index script + wiring of the multi-PRD lifecycle contract.
set -u
err=0
S=plugins/mega-sdd/scripts/build-project-index.sh
[ -x "$S" ] || { echo "build-project-index.sh missing/non-exec"; exit 1; }
SABS="$PWD/$S"

# fixture project with two vaults: one shipped, one intent-only
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.mega-sdd/vaults/epic-1/units" "$T/.mega-sdd/vaults/epic-1/bolts/U-001" \
         "$T/.mega-sdd/vaults/epic-2"
printf -- '---\nid: U-001\n---\n' > "$T/.mega-sdd/vaults/epic-1/units/U-001.md"
echo "# r" > "$T/.mega-sdd/vaults/epic-1/bolts/U-001/bolt-report.md"
printf '## Product\n\nEpic one booking.\n' > "$T/.mega-sdd/vaults/epic-1/01-overview.md"
echo '{"title":"Booking","vault_version":"1.0"}' > "$T/.mega-sdd/vaults/epic-1/vault.json"
printf '## Product\n\nEpic two analytics.\n' > "$T/.mega-sdd/vaults/epic-2/01-overview.md"

bash "$SABS" --cwd="$T"
IDX="$T/.mega-sdd/project.md"
[ -f "$IDX" ] || { echo "project.md not written"; err=1; }
if [ -f "$IDX" ]; then
  grep -q 'type: project-index' "$IDX" || { echo "missing frontmatter"; err=1; }
  grep -q 'vault_count: 2' "$IDX" || { echo "wrong vault_count"; err=1; }
  grep -q '`epic-1`' "$IDX" || { echo "epic-1 row missing"; err=1; }
  grep -q 'shipped' "$IDX" || { echo "epic-1 not marked shipped (1 unit, 1 bolt)"; err=1; }
  grep -q '`epic-2`' "$IDX" || { echo "epic-2 row missing"; err=1; }
  grep -qi 'project constitution' "$IDX" || { echo "lifecycle section missing constitution pointer"; err=1; }
fi
# empty project -> valid empty index, exit 0
T2=$(mktemp -d); mkdir -p "$T2/.mega-sdd"; bash "$SABS" --cwd="$T2"; [ $? -eq 0 ] || { echo "empty project must exit 0"; err=1; }
grep -qi 'No vaults yet' "$T2/.mega-sdd/project.md" || { echo "empty index missing placeholder"; err=1; }
rm -rf "$T2"
# non-mega-sdd dir -> no write, exit 0
T3=$(mktemp -d); bash "$SABS" --cwd="$T3"; [ -f "$T3/.mega-sdd/project.md" ] && { echo "non-sdd wrote index"; err=1; }; rm -rf "$T3"

# wiring pins
REF=plugins/mega-sdd/references/multi-prd-lifecycle.md
[ -f "$REF" ] || { echo "multi-prd-lifecycle.md missing"; err=1; }
if [ -f "$REF" ]; then
  for t in "diff-vault" "new vault" "sync" "project constitution" "when unsure" "Doc-type agnostic"; do
    grep -qi "$t" "$REF" || { echo "lifecycle ref missing: $t"; err=1; }
  done
fi
grep -q 'Multi-PRD lane' plugins/mega-sdd/skills/using-mega-sdd/SKILL.md || { echo "router not wired in using-mega-sdd"; err=1; }
grep -q 'build-project-index.sh' plugins/mega-sdd/scripts/run-analyze.sh || { echo "index regen not wired in analyze"; err=1; }
grep -qi 'Project constitution gate' plugins/mega-sdd/skills/bind-codebase/SKILL.md || { echo "project-constitution gate not in bind-codebase"; err=1; }
bash -n "$S" || { echo "index script syntax error"; err=1; }
exit $err
