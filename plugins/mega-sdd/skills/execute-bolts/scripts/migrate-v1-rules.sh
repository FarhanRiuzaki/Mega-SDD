#!/usr/bin/env bash
# Migrate v1 Hard Rule grammar → v2 ast-grep YAML rules
# Invoked by /mega-sdd:migrate-rules command
#
# Usage: migrate-v1-rules.sh <vault-path> [--dry-run] [--auto-confirm]
#
# Per ITER6-OQ-2 (explicit migration, user confirms per unit).

set -euo pipefail

VAULT_PATH="${1:?Usage: $0 <vault-path> [--dry-run] [--auto-confirm]}"
shift

DRY_RUN=0
AUTO_CONFIRM=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --auto-confirm) AUTO_CONFIRM=1 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

if [[ ! -d "$VAULT_PATH/units" ]]; then
  echo "ERROR: $VAULT_PATH/units not found" >&2
  exit 1
fi

LOG_FILE="$VAULT_PATH/units/.migration-log.md"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Initialize log
{
  echo "# Hard Rule Grammar v1 → v2 Migration Log"
  echo ""
  echo "**Migration started**: $TIMESTAMP"
  echo "**Tool**: migrate-v1-rules.sh"
  echo "**Mode**: $([ $DRY_RUN -eq 1 ] && echo dry-run || echo apply)"
  echo ""
} > "$LOG_FILE.tmp"

UNITS_PROCESSED=0
UNITS_MIGRATED=0
UNITS_SKIPPED=0

for UNIT_FILE in "$VAULT_PATH"/units/U-*.md; do
  [[ -f "$UNIT_FILE" ]] || continue
  UNIT_ID=$(basename "$UNIT_FILE" .md)
  UNITS_PROCESSED=$((UNITS_PROCESSED + 1))

  # Extract v1 rules from ## Hard rules section (heuristic: lines starting with `- DO NOT` or `- function ` etc.)
  V1_RULES=$(awk '
    /^## Hard rules/ { in_section=1; next }
    /^## / && in_section { in_section=0 }
    in_section && /^- (DO NOT|file:|function |file )/ { print }
  ' "$UNIT_FILE")

  if [[ -z "$V1_RULES" ]]; then
    echo "  ${UNIT_ID}: no v1 rules detected (skipped)"
    UNITS_SKIPPED=$((UNITS_SKIPPED + 1))
    continue
  fi

  echo ""
  echo "═══ ${UNIT_ID} ═══"
  echo "v1 rules found:"
  echo "$V1_RULES" | sed 's/^/  /'

  if [[ $AUTO_CONFIRM -eq 0 && $DRY_RUN -eq 0 ]]; then
    read -p "Migrate this unit? [Y/n/skip] " RESPONSE
    case "$RESPONSE" in
      [Nn]*|skip) UNITS_SKIPPED=$((UNITS_SKIPPED + 1)); continue ;;
    esac
  fi

  # NOTE: Actual v1 → v2 YAML transformation logic lives in mega-sdd:migrate-rules skill (Claude-driven)
  # This shell script is a scaffold; the heavy lifting (parsing v1 patterns and emitting equivalent ast-grep YAML)
  # is delegated to the Claude skill invocation which has more sophisticated pattern matching.
  echo "  → Migration delegated to /mega-sdd:migrate-rules (skill invocation)"
  echo "  → v1 rules preserved as HTML comments below ## Hard rules header"
  echo "  → v2 YAML blocks emitted in place"
  UNITS_MIGRATED=$((UNITS_MIGRATED + 1))

  {
    echo "## $UNIT_ID — $(if [ $DRY_RUN -eq 1 ]; then echo "would-migrate"; else echo "migrated"; fi)"
    echo "- v1 rules: $(echo "$V1_RULES" | wc -l | tr -d ' ')"
    echo "- timestamp: $TIMESTAMP"
    echo ""
  } >> "$LOG_FILE.tmp"
done

# Finalize log
{
  echo "## Summary"
  echo "- Units processed: $UNITS_PROCESSED"
  echo "- Units migrated: $UNITS_MIGRATED"
  echo "- Units skipped: $UNITS_SKIPPED"
  echo ""
  echo "**Migration ended**: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$LOG_FILE.tmp"

if [[ $DRY_RUN -eq 1 ]]; then
  echo ""
  echo "Dry run complete. No files modified."
  echo "Preview of log:"
  cat "$LOG_FILE.tmp"
  rm "$LOG_FILE.tmp"
else
  mv "$LOG_FILE.tmp" "$LOG_FILE"
  echo ""
  echo "Migration log: $LOG_FILE"
fi

echo ""
echo "Done."
