#!/usr/bin/env bash
# sync-vendored.sh — the ONE maintainer-only, release-time vendoring sync
# (v7 Fase 2 merge group 1: sync-superpowers.sh + sync-ui-ux.sh combined).
#
# Leg 1 — superpowers skills → skills/_vendored/ (+ ATTRIBUTION.md stamps)
# Leg 2 — ui-ux-pro-max distillation → references/design-intelligence/
#         (distillation runs at SYNC TIME ONLY; runtime reads committed output)
#
# Usage: bash scripts/sync-vendored.sh [--superpowers=DIR] [--ui-ux=DIR]
#        (no args: auto-resolve the newest installed plugin cache per leg)
# Each leg is INDEPENDENT: a missing source SKIPs that leg with a warning and
# the other still runs; exit 1 only when BOTH sources are unresolvable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SP_DIR=""
UX_DIR=""
for arg in "$@"; do
  case "$arg" in
    --superpowers=*) SP_DIR="${arg#*=}" ;;
    --ui-ux=*) UX_DIR="${arg#*=}" ;;
    *) echo "usage: sync-vendored.sh [--superpowers=DIR] [--ui-ux=DIR]" >&2; exit 2 ;;
  esac
done

LEGS_RUN=0

# ─── Leg 1: superpowers ──────────────────────────────────────────────────────
VENDORED_DIR="${PLUGIN_ROOT}/skills/_vendored"
DEFAULT_SP_CACHE="${HOME}/.claude/plugins/cache/claude-plugins-official/superpowers"
if [ -z "$SP_DIR" ] && [ -d "$DEFAULT_SP_CACHE" ]; then
  SP_DIR="$(find "$DEFAULT_SP_CACHE" -maxdepth 1 -type d -name "[0-9]*" | sort -V | tail -1)"
fi

if [ -n "$SP_DIR" ] && [ -d "$SP_DIR" ]; then
  echo "Syncing superpowers from: $SP_DIR"
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
  # Commit identifier sources: git clone → release marker → version-only.
  if [ -d "${SP_DIR}/.git" ]; then
    SP_COMMIT="$(git -C "$SP_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")"
  fi
  if [ "$SP_COMMIT" = "unknown" ] && [ -f "${SP_DIR}/.version-bump.json" ]; then
    v="$(jq -r '.commit // empty' "${SP_DIR}/.version-bump.json" 2>/dev/null)"
    [ -n "$v" ] && SP_COMMIT="$v"
  fi
  if [ "$SP_COMMIT" = "unknown" ]; then
    SP_COMMIT="version=${SP_VERSION}"
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
  LEGS_RUN=$((LEGS_RUN + 1))
else
  echo "WARN: superpowers source not found — leg SKIPPED (pass --superpowers=DIR or install the plugin)." >&2
fi

# ─── Leg 2: ui-ux-pro-max distillation ───────────────────────────────────────
OUT_DIR="${PLUGIN_ROOT}/references/design-intelligence"
DEFAULT_UX_CACHE="${HOME}/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max"
if [ -z "$UX_DIR" ] && [ -d "$DEFAULT_UX_CACHE" ]; then
  UX_DIR="$(find "$DEFAULT_UX_CACHE" -maxdepth 1 -type d -name '[0-9]*' | sort -V | tail -1)"
fi

if [ -n "$UX_DIR" ] && [ -d "$UX_DIR" ] && [ -d "${UX_DIR}/src/ui-ux-pro-max/data" ]; then
  DATA="${UX_DIR}/src/ui-ux-pro-max/data"
  echo "Distilling ui-ux from: $DATA"
  mkdir -p "$OUT_DIR"
  python3 "${SCRIPT_DIR}/_lib/distill-ui-ux.py" --data="$DATA" --out="$OUT_DIR"

  UX_VERSION="$(basename "$UX_DIR")"
  TODAY="$(date -u +%Y-%m-%d)"
  ATTR_UX="${OUT_DIR}/ATTRIBUTION.md"
  if [ -f "$ATTR_UX" ]; then
    sed -i.bak \
      -e "s|^- \*\*Distilled from version:\*\*.*$|- **Distilled from version:** ${UX_VERSION}|" \
      -e "s|^- \*\*Distilled on date:\*\*.*$|- **Distilled on date:** ${TODAY}|" \
      "$ATTR_UX"
    rm -f "${ATTR_UX}.bak"
  fi
  LEGS_RUN=$((LEGS_RUN + 1))
else
  echo "WARN: ui-ux-pro-max source not found — leg SKIPPED (pass --ui-ux=DIR or install the plugin)." >&2
fi

if [ "$LEGS_RUN" -eq 0 ]; then
  echo "ERROR: no vendoring source resolvable — nothing synced." >&2
  exit 1
fi
echo "Sync complete (${LEGS_RUN} leg(s)). Review diffs and commit."
