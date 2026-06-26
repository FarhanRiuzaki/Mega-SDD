---
description: Migrate mega-sdd outputs from the legacy scattered layout to the canonical .mega-sdd/ consolidation. Walks legacy paths (docs/mega-sdd/vaults/, .mega-sdd-memory/, top-level codebase-map.md, etc.), shows preview, asks confirm, moves via git mv when in git repo (preserves history), updates internal references in vault.json + binding.md + per-file frontmatter. Idempotent; safe to re-run.
argument-hint: "[--dry-run] [--from=auto|<layout>] [--to=new] [--auto-confirm]"
---

Migrate mega-sdd outputs to the canonical layout per `plugins/mega-sdd/references/paths.md`.

User arguments: $ARGUMENTS

Flag parsing:
- `--dry-run` — Preview moves without writing
- `--from=auto|legacy|mixed` — Source layout (default: auto-detect)
- `--to=new` — Target layout (default: new; canonical `.mega-sdd/` consolidation). The reverse `--to=legacy` rollback is **NOT YET IMPLEMENTED** (manual file moves required — see the rollback note below); it is intentionally omitted from the argument-hint until the reverse direction ships.
- `--auto-confirm` — Skip per-move AskUserQuestion (DANGEROUS without --dry-run first)

## Procedure

### Step 1 — Detect current layout

Probe for legacy paths:

```bash
LEGACY_VAULTS_DIR=""
[ -d "./docs/mega-sdd/vaults" ] && LEGACY_VAULTS_DIR="./docs/mega-sdd/vaults"

LEGACY_KB_DIR=""
for candidate in ./docs/knowledge-base ./old-reference/knowledge-base; do
  [ -d "$candidate" ] && LEGACY_KB_DIR="$candidate" && break
done

LEGACY_CODEBASE_MAP=""
[ -f "./codebase-map.md" ] && LEGACY_CODEBASE_MAP="./codebase-map.md"

LEGACY_MEMORY_DIR=""
[ -d "./.mega-sdd-memory" ] && LEGACY_MEMORY_DIR="./.mega-sdd-memory"

# Detect if .mega-sdd/ already exists (partial migration or fresh v3.4 project)
TARGET_ROOT="./.mega-sdd"
TARGET_EXISTS=false
[ -d "$TARGET_ROOT" ] && TARGET_EXISTS=true
```

### Step 2 — Build migration plan

Generate per-artifact moves:

```
Migration plan:

Vaults:
  FROM: ./docs/mega-sdd/vaults/<slug>/
  TO:   ./.mega-sdd/vaults/<slug>/
  Count: N vaults detected

Knowledge base:
  FROM: ./docs/knowledge-base/
  TO:   ./.mega-sdd/knowledge-base/

Codebase map:
  FROM: ./codebase-map.md
  TO:   ./.mega-sdd/codebase/codebase-map.md

Project memory:
  FROM: ./.mega-sdd-memory/
  TO:   ./.mega-sdd/memory/

Per-vault internal state (checkpoints + symbol-graph cache):
  FROM: <vault>/.mega-sdd/  →  <vault>/.internal/  (rename to avoid nesting under top-level .mega-sdd/)

Configuration:
  CREATE: ./.mega-sdd/config.yaml (v3.4 default)
```

### Step 3 — Show preview + confirm

Display the plan in chat. Total file count, total size moved, expected operations. Then `AskUserQuestion`:

```
Proposed migration: <N> directories + <M> files moved to ./.mega-sdd/

Options:
  1. Proceed (use git mv where in git; otherwise mv)
  2. Dry-run preview only (show what would happen; no changes)
  3. Cancel
```

Skip if `--auto-confirm` set. Halt if `--dry-run` set (just print plan).

### Step 4 — Execute moves

For each source path, target path pair:

```bash
# Pre-flight: ensure target parent exists
mkdir -p "$(dirname "$TARGET")"

# In git repo: use git mv to preserve history
if [ -d ".git" ] && git ls-files --error-unmatch "$SOURCE" &>/dev/null; then
  git mv "$SOURCE" "$TARGET"
else
  mv "$SOURCE" "$TARGET"
fi

# Log to migration-log.md
echo "  - ✓ $SOURCE → $TARGET" >> ./.mega-sdd/migration-log.md
```

Per-vault internal rename:

```bash
# For each vault that has <vault>/.mega-sdd/ subdir, rename to <vault>/.internal/
# (avoids confusion with top-level .mega-sdd/)
for vault in .mega-sdd/vaults/*/; do
  if [ -d "$vault/.mega-sdd" ]; then
    git mv "$vault/.mega-sdd" "$vault/.internal" 2>/dev/null || mv "$vault/.mega-sdd" "$vault/.internal"
  fi
done
```

### Step 5 — Update internal references

Files that reference paths need updates:

```bash
# Update vault.json files
for vjson in .mega-sdd/vaults/*/vault.json; do
  # Replace any legacy path references in JSON
  sed -i.bak 's|docs/mega-sdd/vaults/|.mega-sdd/vaults/|g' "$vjson"
  sed -i.bak 's|docs/knowledge-base/|.mega-sdd/knowledge-base/|g' "$vjson"
  sed -i.bak 's|/\.mega-sdd-memory/|/.mega-sdd/memory/|g' "$vjson"
  sed -i.bak "s|<vault>/.mega-sdd/|<vault>/.internal/|g" "$vjson"
  rm "${vjson}.bak"
done

# Update binding.md files (HTML comment binding annotations)
for bmd in .mega-sdd/vaults/*/binding.md .mega-sdd/vaults/*/bound/*.md; do
  [ -f "$bmd" ] && sed -i.bak \
    -e 's|docs/mega-sdd/vaults/|.mega-sdd/vaults/|g' \
    -e 's|docs/knowledge-base/|.mega-sdd/knowledge-base/|g' \
    -e 's|/\.mega-sdd-memory/|/.mega-sdd/memory/|g' \
    -e "s|<vault>/.mega-sdd/checkpoints|<vault>/.internal/checkpoints|g" \
    "$bmd" && rm "${bmd}.bak"
done

# Update memory file frontmatter source_run citations
# (Lower priority; old citations remain valid as historical record)
```

### Step 6 — Create config.yaml

If not already present, write `<project>/.mega-sdd/config.yaml` per `references/paths.md` §Config file format:

```yaml
mega_sdd_schema: 1
output_root: .mega-sdd/
layout: new
defaults:
  memory_enabled: true
  emit_agents_md: true
  defensive_generation: true
probe_paths:
  vault_candidates:
    - .mega-sdd/vaults/
    - docs/mega-sdd/vaults/    # legacy fallback
  knowledge_base_candidates:
    - .mega-sdd/knowledge-base/
    - docs/knowledge-base/
    - old-reference/knowledge-base/
```

### Step 7 — Final verification + report

```bash
# Verify expected paths exist
for expected in .mega-sdd/vaults .mega-sdd/codebase .mega-sdd/memory .mega-sdd/config.yaml; do
  [ -e "$expected" ] && echo "  ✓ $expected" || echo "  ⚠️ $expected MISSING"
done

# Verify legacy paths cleared (where moves happened)
for legacy in docs/mega-sdd/vaults codebase-map.md .mega-sdd-memory; do
  [ -e "$legacy" ] && echo "  ⚠️ $legacy still exists (not moved)" || echo "  ✓ $legacy cleared"
done

# Print final structure tree
echo ""
echo "New layout:"
find .mega-sdd -maxdepth 3 -type d | sort
```

### Step 8 — Append summary to migration-log.md

```markdown
# Mega-SDD Path Migration Log

## Migration <ISO8601 timestamp>

- Source layout: legacy (scattered paths)
- Target layout: new (canonical `.mega-sdd/`)
- Total files moved: <N>
- Vaults migrated: <list>
- KB migrated: yes | no | n/a
- Codebase map migrated: yes | no | n/a
- Memory migrated: yes | no | n/a
- Tool used: git mv (history preserved) | mv (fallback)
- Errors: <list or "none">

To rollback: git revert HEAD (if migration in git) OR run /mega-sdd:migrate-paths --to=legacy (NOT YET IMPLEMENTED — manual file moves required).
```

## Hard rails (anti-data-loss)

- **Idempotent**: re-running on already-migrated project is no-op (detects new layout already present)
- **git mv used in git repos** — file history preserved across migration
- **Backups created via .bak suffix** for sed in-place edits; cleaned up after success
- **Dry-run mandatory** for first-time users — preview before commit
- **AskUserQuestion confirm** unless `--auto-confirm` explicit
- **Pre-flight check**: target parent exists OR mkdir -p before move
- **Reference update** is critical — without it, vault.json citations break

## Halt conditions

- Working tree dirty (uncommitted changes) → halt; ask user to commit/stash first
- Target path exists AND non-empty AND `--from=auto` → halt; ask explicit `--from=legacy` to confirm overwrite intent
- git mv fails (e.g., target outside git tree) → fall back to plain `mv` with warning
- Reference update sed fails → halt with file path; user resolves manually

## See also

- `plugins/mega-sdd/references/paths.md` — canonical layout definition
- Iter 10 spec (this iter) — folder consolidation rationale
- Iter 9 audit — Gap E2E-6 (archive `.mega-sdd/` on vault delete) — naturally fixed by v3.4 consolidation
