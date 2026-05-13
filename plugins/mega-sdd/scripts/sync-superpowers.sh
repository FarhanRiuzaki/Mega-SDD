#!/usr/bin/env bash
# Sync vendored superpowers skills from upstream
# Usage: bash scripts/sync-superpowers.sh [SUPERPOWERS_DIR]
# If SUPERPOWERS_DIR not provided, uses default cache path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENDORED_DIR="${PLUGIN_ROOT}/skills/_vendored"

DEFAULT_SP_CACHE="${HOME}/.claude/plugins/cache/claude-plugins-official/superpowers"
SP_DIR="${1:-}"

# Auto-resolve latest version if not provided
if [ -z "$SP_DIR" ]; then
  if [ -d "$DEFAULT_SP_CACHE" ]; then
    SP_DIR="$(find "$DEFAULT_SP_CACHE" -maxdepth 1 -type d -name "[0-9]*" | sort -V | tail -1)"
  fi
fi

if [ -z "$SP_DIR" ] || [ ! -d "$SP_DIR" ]; then
  echo "ERROR: superpowers source not found. Pass path as arg or install superpowers plugin." >&2
  exit 1
fi

echo "Syncing from: $SP_DIR"

SKILLS_TO_VENDOR=(
  "executing-plans"
  "subagent-driven-development"
  "test-driven-development"
  "using-git-worktrees"
)

for skill in "${SKILLS_TO_VENDOR[@]}"; do
  src="${SP_DIR}/skills/${skill}"
  dst="${VENDORED_DIR}/${skill}"
  if [ ! -d "$src" ]; then
    echo "WARN: source skill missing: $src" >&2
    continue
  fi
  rm -rf "$dst"
  cp -R "$src" "$dst"
  echo "  vendored: ${skill}"
done

# Update ATTRIBUTION.md metadata
SP_VERSION="$(basename "$SP_DIR")"
SP_COMMIT="unknown"
if [ -d "${SP_DIR}/.git" ]; then
  SP_COMMIT="$(git -C "$SP_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")"
fi
TODAY="$(date -u +%Y-%m-%d)"

ATTR="${VENDORED_DIR}/ATTRIBUTION.md"
if [ -f "$ATTR" ]; then
  sed -i.bak \
    -e "s|^- \*\*Vendored from version:\*\*.*$|- **Vendored from version:** ${SP_VERSION}|" \
    -e "s|^- \*\*Vendored at commit:\*\*.*$|- **Vendored at commit:** ${SP_COMMIT}|" \
    -e "s|^- \*\*Vendored on date:\*\*.*$|- **Vendored on date:** ${TODAY}|" \
    "$ATTR"
  rm -f "${ATTR}.bak"
fi

echo "Sync complete. Review diffs and commit."
