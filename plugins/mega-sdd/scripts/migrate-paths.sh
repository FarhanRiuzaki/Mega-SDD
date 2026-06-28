#!/usr/bin/env bash
# migrate-paths.sh — migrate mega-sdd outputs from the legacy scattered layout
# to the canonical .mega-sdd/ consolidation (per references/paths.md).
#
# This is the deterministic, destructive core extracted from
# commands/migrate-paths.md (audit finding C6). The interactive confirm gate
# and the user-facing dirty-tree HALT live in the command; this script
# self-guards (idempotent no-op + dirty-tree refusal + target-exists conflict)
# so that direct or --auto-confirm invocation is still safe.
#
# Usage: migrate-paths.sh [--dry-run] [--from=auto|legacy|mixed]
#                         [--cwd=<path>] [--auto-confirm]
#   --dry-run       Preview every move/rewrite; mutate nothing.
#   --from=auto     Source layout (default auto). --from=legacy confirms intent
#                   to migrate into a pre-existing, non-empty .mega-sdd/vaults/.
#   --cwd=<path>    Operate on this project root (default: current directory).
#   --auto-confirm  Accepted + ignored here (the confirm gate lives in the
#                   command); the dirty-tree guard below is the safety backstop.
#
# Exit: 0 = migrated OR already-canonical no-op
#       1 = error (target-exists conflict; reference-update failure via set -e)
#       2 = refused (dirty git tree without --dry-run) | usage error
set -euo pipefail

DRY_RUN=0
FROM=auto
ROOT="."
for arg in "$@"; do
  case "$arg" in
    --dry-run)      DRY_RUN=1 ;;
    --from=*)       FROM="${arg#*=}" ;;
    --cwd=*)        ROOT="${arg#*=}" ;;
    --to=*)         : ;;  # accepted + ignored: 'new' is the only implemented
                          # target (the default); --to=legacy rollback is unbuilt
    --auto-confirm) : ;;  # no-op: confirm lives in the command
    -h|--help)      sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "migrate-paths: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

[ -d "$ROOT" ] || { echo "migrate-paths: --cwd is not a directory: $ROOT" >&2; exit 2; }
cd "$ROOT"

# run CMD... — echo under --dry-run, execute otherwise. ALL mutations route here.
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

TARGET_ROOT="./.mega-sdd"

# --------------------------------------------------------------------------
# Step 1 — detect legacy layout
# --------------------------------------------------------------------------
LEGACY_VAULTS_DIR=""
# Only count it as legacy when it actually holds vaults — an empty leftover
# parent from a prior run must not block the idempotency no-op below.
if [ -d "./docs/mega-sdd/vaults" ] && [ -n "$(ls -A "./docs/mega-sdd/vaults" 2>/dev/null)" ]; then
  LEGACY_VAULTS_DIR="./docs/mega-sdd/vaults"
fi

LEGACY_KB_DIR=""
for candidate in ./docs/knowledge-base ./old-reference/knowledge-base; do
  [ -d "$candidate" ] && LEGACY_KB_DIR="$candidate" && break
done

LEGACY_CODEBASE_MAP=""
[ -f "./codebase-map.md" ] && LEGACY_CODEBASE_MAP="./codebase-map.md"

LEGACY_MEMORY_DIR=""
[ -d "./.mega-sdd-memory" ] && LEGACY_MEMORY_DIR="./.mega-sdd-memory"

# --------------------------------------------------------------------------
# Guard 1 (idempotency) — MUST precede the dirty-tree guard. A completed
# migration leaves the tree dirty (staged git-mv renames + new config/log), so
# a clean re-run has to no-op HERE, before the dirty guard would wrongly fire.
# --------------------------------------------------------------------------
if [ -z "$LEGACY_VAULTS_DIR" ] && [ -z "$LEGACY_KB_DIR" ] \
   && [ -z "$LEGACY_CODEBASE_MAP" ] && [ -z "$LEGACY_MEMORY_DIR" ]; then
  echo "migrate-paths: no legacy paths detected — layout already canonical (.mega-sdd/). No-op."
  exit 0
fi

# --------------------------------------------------------------------------
# Detect git work tree (used by the dirty guard + git mv / plain mv selection)
# --------------------------------------------------------------------------
IN_GIT=0
if [ -d ".git" ] || git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IN_GIT=1
fi

# --------------------------------------------------------------------------
# Guard 2 (dirty tree) — refuse to mutate an uncommitted tree unless --dry-run.
# Mirrors the command's dirty-tree HALT; this script-level backstop is what
# makes --auto-confirm / direct invocation safe.
# --------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 0 ] && [ "$IN_GIT" -eq 1 ]; then
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "migrate-paths: refusing to migrate — git working tree is dirty." >&2
    echo "  Commit or stash your changes first, then re-run (or pass --dry-run to preview)." >&2
    exit 2
  fi
fi

# --------------------------------------------------------------------------
# Guard 3 (target-exists conflict) — a non-empty .mega-sdd/vaults/ under
# --from=auto means a partial/prior migration; refuse rather than nest/clobber.
# Explicit --from=legacy confirms overwrite intent.
# --------------------------------------------------------------------------
if [ -n "$LEGACY_VAULTS_DIR" ] && [ -d "$TARGET_ROOT/vaults" ] \
   && [ -n "$(ls -A "$TARGET_ROOT/vaults" 2>/dev/null)" ] && [ "$FROM" = "auto" ]; then
  echo "migrate-paths: $TARGET_ROOT/vaults already exists and is non-empty." >&2
  echo "  Pass --from=legacy to confirm overwrite intent, or resolve the conflict manually." >&2
  exit 1
fi

echo "migrate-paths: migrating to canonical .mega-sdd/ layout (dry-run=$DRY_RUN, in-git=$IN_GIT)"

# move_path SRC DST — git mv when SRC is tracked, else plain mv; ensure parent.
move_path() {
  local src="$1" dst="$2"
  run mkdir -p "$(dirname "$dst")"
  if [ "$IN_GIT" -eq 1 ] && git ls-files --error-unmatch "$src" >/dev/null 2>&1; then
    run git mv "$src" "$dst"
  else
    run mv "$src" "$dst"
  fi
  if [ "$DRY_RUN" -eq 1 ]; then echo "  • plan: $src → $dst"; else echo "  ✓ moved: $src → $dst"; fi
}

# --------------------------------------------------------------------------
# Step 4 — execute moves (vaults FIRST so the internal-rename loop below runs
# on the post-move location, matching the original command's ordering)
# --------------------------------------------------------------------------
if [ -n "$LEGACY_VAULTS_DIR" ]; then
  run mkdir -p "$TARGET_ROOT/vaults"
  for vdir in "$LEGACY_VAULTS_DIR"/*/; do
    [ -d "$vdir" ] || continue
    slug="$(basename "$vdir")"
    move_path "${vdir%/}" "$TARGET_ROOT/vaults/$slug"
  done
  # Tidy the now-empty legacy parent(s) so a re-run sees a clean canonical
  # layout (idempotency). rmdir is data-safe: it refuses a non-empty directory.
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  • plan: rmdir empty $LEGACY_VAULTS_DIR (+ ./docs/mega-sdd if empty)"
  else
    rmdir "$LEGACY_VAULTS_DIR" 2>/dev/null || true
    rmdir "./docs/mega-sdd" 2>/dev/null || true
  fi
fi
[ -n "$LEGACY_KB_DIR" ]       && move_path "$LEGACY_KB_DIR"       "$TARGET_ROOT/knowledge-base"
[ -n "$LEGACY_CODEBASE_MAP" ] && move_path "$LEGACY_CODEBASE_MAP" "$TARGET_ROOT/codebase/codebase-map.md"
[ -n "$LEGACY_MEMORY_DIR" ]   && move_path "$LEGACY_MEMORY_DIR"   "$TARGET_ROOT/memory"

# Per-vault internal rename: <vault>/.mega-sdd/ → <vault>/.internal/ (avoids
# confusion with the top-level .mega-sdd/). Runs on the POST-move location.
for vault in "$TARGET_ROOT"/vaults/*/; do
  [ -d "$vault" ] || continue
  if [ -d "${vault}.mega-sdd" ]; then
    if [ "$IN_GIT" -eq 1 ] && git ls-files --error-unmatch "${vault}.mega-sdd" >/dev/null 2>&1; then
      run git mv "${vault}.mega-sdd" "${vault}.internal"
    else
      run mv "${vault}.mega-sdd" "${vault}.internal"
    fi
    if [ "$DRY_RUN" -eq 1 ]; then echo "  • plan: ${vault}.mega-sdd → ${vault}.internal"; else echo "  ✓ renamed: ${vault}.mega-sdd → ${vault}.internal"; fi
  fi
done

# --------------------------------------------------------------------------
# Step 5 — update internal references (legacy path strings in vault.json +
# binding.md). One unified rewrite set; non-matching patterns are no-ops.
# --------------------------------------------------------------------------
rewrite_refs() {
  local f="$1"
  [ -f "$f" ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  • plan: rewrite legacy path refs in $f"
    return 0
  fi
  sed -i.bak \
    -e 's|docs/mega-sdd/vaults/|.mega-sdd/vaults/|g' \
    -e 's|docs/knowledge-base/|.mega-sdd/knowledge-base/|g' \
    -e 's|/\.mega-sdd-memory/|/.mega-sdd/memory/|g' \
    -e 's|<vault>/\.mega-sdd/|<vault>/.internal/|g' \
    "$f" && rm -f "${f}.bak"
  echo "  ✓ rewrote refs: $f"
}

for vjson in "$TARGET_ROOT"/vaults/*/vault.json; do
  [ -f "$vjson" ] || continue
  rewrite_refs "$vjson"
done
for bmd in "$TARGET_ROOT"/vaults/*/binding.md "$TARGET_ROOT"/vaults/*/bound/*.md; do
  [ -f "$bmd" ] || continue
  rewrite_refs "$bmd"
done

# --------------------------------------------------------------------------
# Step 6 — create config.yaml (clobber-guard: never overwrite a user's config)
# --------------------------------------------------------------------------
CONFIG="$TARGET_ROOT/config.yaml"
if [ -e "$CONFIG" ]; then
  echo "  ⊘ config.yaml exists — preserved (not overwritten)"
elif [ "$DRY_RUN" -eq 1 ]; then
  echo "  • plan: create $CONFIG"
else
  mkdir -p "$TARGET_ROOT"
  cat > "$CONFIG" <<'YAML'
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
YAML
  echo "  ✓ created $CONFIG"
fi

# --------------------------------------------------------------------------
# Step 7 — verification (advisory; warnings do not fail the run)
# --------------------------------------------------------------------------
echo "Verifying canonical paths:"
for expected in "$TARGET_ROOT/vaults" "$TARGET_ROOT/config.yaml"; do
  if [ -e "$expected" ] || [ "$DRY_RUN" -eq 1 ]; then echo "  ✓ $expected"; else echo "  ⚠️  $expected MISSING"; fi
done
echo "Verifying legacy paths cleared:"
for legacy in "$LEGACY_VAULTS_DIR" "$LEGACY_CODEBASE_MAP" "$LEGACY_MEMORY_DIR"; do
  [ -n "$legacy" ] || continue
  if [ -e "$legacy" ] && [ "$DRY_RUN" -eq 0 ]; then echo "  ⚠️  $legacy still exists (not moved)"; else echo "  ✓ $legacy cleared"; fi
done

# --------------------------------------------------------------------------
# Step 8 — append migration-log.md (real runs only)
# --------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
  LOG="$TARGET_ROOT/migration-log.md"
  mkdir -p "$TARGET_ROOT"
  if [ ! -f "$LOG" ]; then printf '# Mega-SDD Path Migration Log\n' > "$LOG"; fi
  {
    printf '\n## Migration %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
    printf -- '- Source layout: legacy (scattered paths)\n'
    printf -- '- Target layout: new (canonical `.mega-sdd/`)\n'
    printf -- '- Tool used: %s\n' "$([ "$IN_GIT" -eq 1 ] && echo 'git mv (history preserved)' || echo 'mv (fallback)')"
  } >> "$LOG"
  echo "migrate-paths: done. Log appended to $LOG"
else
  echo "migrate-paths: dry-run complete — no changes written."
fi

exit 0
