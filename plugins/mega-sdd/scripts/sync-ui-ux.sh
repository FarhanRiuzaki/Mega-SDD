#!/usr/bin/env bash
# Sync vendored (distilled) ui-ux-pro-max design intelligence into mega-sdd.
# Usage: bash scripts/sync-ui-ux.sh [UI_UX_DIR]
# Distillation runs at SYNC TIME ONLY; mega-sdd runtime reads the committed output.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${PLUGIN_ROOT}/references/design-intelligence"
DEFAULT_CACHE="${HOME}/.claude/plugins/cache/ui-ux-pro-max-skill/ui-ux-pro-max"
UX_DIR="${1:-}"
if [ -z "$UX_DIR" ] && [ -d "$DEFAULT_CACHE" ]; then
  UX_DIR="$(find "$DEFAULT_CACHE" -maxdepth 1 -type d -name '[0-9]*' | sort -V | tail -1)"
fi
if [ -z "$UX_DIR" ] || [ ! -d "$UX_DIR" ]; then
  echo "ERROR: ui-ux-pro-max source not found. Pass path as arg or install the plugin." >&2
  exit 1
fi
DATA="${UX_DIR}/src/ui-ux-pro-max/data"
[ -d "$DATA" ] || { echo "ERROR: data dir missing: $DATA" >&2; exit 1; }
echo "Distilling from: $DATA"
mkdir -p "$OUT_DIR"
python3 "${SCRIPT_DIR}/_lib/distill-ui-ux.py" --data="$DATA" --out="$OUT_DIR"

UX_VERSION="$(basename "$UX_DIR")"
TODAY="$(date -u +%Y-%m-%d)"
ATTR="${OUT_DIR}/ATTRIBUTION.md"
if [ -f "$ATTR" ]; then
  sed -i.bak \
    -e "s|^- \*\*Distilled from version:\*\*.*$|- **Distilled from version:** ${UX_VERSION}|" \
    -e "s|^- \*\*Distilled on date:\*\*.*$|- **Distilled on date:** ${TODAY}|" \
    "$ATTR"
  rm -f "${ATTR}.bak"
fi
echo "Sync complete. Review diffs and commit."
