#!/usr/bin/env bash
# Detect v1 Hard Rule grammar candidates for migration → v2 ast-grep YAML rules.
# Invoked by /mega-sdd:migrate-rules command
#
# Usage: migrate-v1-rules.sh <vault-path> [--dry-run] [--auto-confirm] [--to=v2]
#
# Per ITER6-OQ-2 (explicit migration, user confirms per unit).
#
# HONEST SCOPE (S6 EB-HONEST-1): this script is a DETECTOR/SCAFFOLD — it walks
# units, identifies v1 rules, and logs what it found. The actual v1 → v2 YAML
# transformation is performed by the /mega-sdd:migrate-rules skill invocation
# (Claude-driven pattern mapping per hard-rule-grammar-v2.md §Mapping v1 → v2).
# This script modifies NO unit file and its log says `detected`, never
# `migrated` — a "migrated" claim with byte-identical files is a fabricated
# audit record (moat invariant #5).

set -euo pipefail

VAULT_PATH="${1:?Usage: $0 <vault-path> [--dry-run] [--auto-confirm] [--to=v2]}"
shift

DRY_RUN=0
AUTO_CONFIRM=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --auto-confirm) AUTO_CONFIRM=1 ;;
    --to=v2) ;;  # default + only implemented direction
    --to=v1) echo "ERROR: --to=v1 (reverse migration) is not implemented — it was never built; only v1 → v2 is supported. v1 grammar is still executed natively at pre/post-flight, so author v1 rules by hand if ast-grep is unavailable." >&2; exit 1 ;;
    --to=*) echo "ERROR: unknown --to target '${arg#*=}' (only v2 is supported)" >&2; exit 1 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

if [[ ! -d "$VAULT_PATH/units" ]]; then
  echo "ERROR: $VAULT_PATH/units not found" >&2
  exit 1
fi

# Interactive confirm needs a TTY — under set -euo pipefail a failed `read -p`
# on a non-tty stdin aborted mid-walk leaving .tmp litter behind (S6 EB-HONEST-1).
if [[ $AUTO_CONFIRM -eq 0 && $DRY_RUN -eq 0 && ! -t 0 ]]; then
  echo "ERROR: interactive per-unit confirm needs a TTY — pass --auto-confirm (or --dry-run) in non-interactive runs" >&2
  exit 1
fi

LOG_FILE="$VAULT_PATH/units/.migration-log.md"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
trap 'rm -f "$LOG_FILE.tmp"' EXIT

# Initialize log
{
  echo "# Hard Rule Grammar v1 → v2 Migration Log"
  echo ""
  echo "**Detection started**: $TIMESTAMP"
  echo "**Tool**: migrate-v1-rules.sh (detector — the v2 transform runs in the /mega-sdd:migrate-rules skill)"
  echo "**Mode**: $([ $DRY_RUN -eq 1 ] && echo dry-run || echo detect)"
  echo ""
} > "$LOG_FILE.tmp"

UNITS_PROCESSED=0
UNITS_DETECTED=0
UNITS_SKIPPED=0

for UNIT_FILE in "$VAULT_PATH"/units/U-*.md; do
  [[ -f "$UNIT_FILE" ]] || continue
  UNIT_ID=$(basename "$UNIT_FILE" .md)
  UNITS_PROCESSED=$((UNITS_PROCESSED + 1))

  # Extract v1 rules from ## Hard rules section — ALL 5 v1 productions
  # (S6 EB-HONEST-1: the old detector missed NAMING_RULE / SIGNATURE_RULE /
  # FILE_PRESENCE_RULE, leaving those units unmigrated as exactly the
  # mixed-grammar shape hard-rule-scan.md halts on).
  V1_RULES=$(awk '
    /^## Hard rules/ { in_section=1; next }
    /^## / && in_section { in_section=0 }
    in_section && /^- / && (/^- DO NOT/ || /MUST follow .*(kebab-case|camelCase|snake_case|PascalCase)/ || /^- function .* MUST preserve signature/ || /^- file .* MUST exist after bolt/ || /^- (file:|function |file )/) { print }
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
    read -p "Queue this unit for migration? [Y/n/skip] " RESPONSE
    case "$RESPONSE" in
      [Nn]*|skip) UNITS_SKIPPED=$((UNITS_SKIPPED + 1)); continue ;;
    esac
  fi

  # The v1 → v2 YAML transformation runs in the mega-sdd:migrate-rules skill
  # (Claude-driven); this scaffold only detects + queues. It writes NOTHING
  # into the unit — do not log otherwise.
  echo "  → detected; transform delegated to /mega-sdd:migrate-rules (skill invocation)"
  UNITS_DETECTED=$((UNITS_DETECTED + 1))

  {
    echo "## $UNIT_ID — $(if [ $DRY_RUN -eq 1 ]; then echo "would-queue"; else echo "detected (delegated to skill)"; fi)"
    echo "- v1 rules: $(echo "$V1_RULES" | wc -l | tr -d ' ')"
    echo "- timestamp: $TIMESTAMP"
    echo ""
  } >> "$LOG_FILE.tmp"
done

# Finalize log
{
  echo "## Summary"
  echo "- Units processed: $UNITS_PROCESSED"
  echo "- Units with v1 rules detected: $UNITS_DETECTED"
  echo "- Units skipped: $UNITS_SKIPPED"
  echo ""
  echo "> This log records DETECTION only. A unit counts as migrated when the"
  echo "> /mega-sdd:migrate-rules skill has emitted its v2 YAML blocks in place"
  echo "> (v1 rules preserved as HTML comments) and the unit re-validates."
  echo ""
  echo "**Detection ended**: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
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
  echo "Detection log: $LOG_FILE"
  echo "No unit files were modified — run the /mega-sdd:migrate-rules skill step to emit the v2 YAML."
fi
trap - EXIT

echo ""
echo "Done."
