#!/usr/bin/env bash
# Memory Schema Migration TEMPLATE
# Per Iter 9 audit fix (Gap E2E-1 / D-3): ship scaffold for future migrations.
#
# Naming convention: <from>-to-<to>.sh (e.g., 1-to-2.sh)
# Invoked by: mega-sdd:memory skill when memory_schema version mismatch detected
#
# Usage: ./template-migration.sh <memory-dir>
#
# This is a TEMPLATE — copy + customize per actual schema change.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <memory-dir>" >&2
  echo "Example: $0 ~/.mega-sdd/memory/" >&2
  exit 1
fi

MEMORY_DIR="${1}"
FROM_VERSION="1"  # Customize per migration
TO_VERSION="2"    # Customize per migration
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BACKUP_DIR="${MEMORY_DIR%/}.backup.${FROM_VERSION}-to-${TO_VERSION}.${TIMESTAMP}"

if [[ ! -d "$MEMORY_DIR" ]]; then
  echo "ERROR: $MEMORY_DIR not found" >&2
  exit 1
fi

# Step 1: Backup
echo "Creating backup: $BACKUP_DIR"
cp -R "$MEMORY_DIR" "$BACKUP_DIR"

# Step 2: Validate frontmatter version (template — customize)
echo "Validating $FROM_VERSION schema..."
for file in "$MEMORY_DIR"/*.md; do
  [[ -f "$file" ]] || continue
  CURRENT_VER=$(grep -m1 "^memory_schema:" "$file" | awk '{print $2}' || echo "0")
  if [[ "$CURRENT_VER" != "$FROM_VERSION" ]]; then
    echo "WARN: $file has schema $CURRENT_VER, expected $FROM_VERSION; skipping"
    continue
  fi
done

# Step 3: Apply transformations (template — customize per migration needs)
# Examples:
#   - Add new field to frontmatter: sed -i.bak '/^scope:/a new_field: default_value' "$file"
#   - Rename field: sed -i.bak 's/^old_name:/new_name:/' "$file"
#   - Restructure table: more complex; use awk or Python
#
# For this template, just bump the version stamp:
for file in "$MEMORY_DIR"/*.md; do
  [[ -f "$file" ]] || continue
  if grep -q "^memory_schema: $FROM_VERSION" "$file"; then
    sed -i.bak "s/^memory_schema: $FROM_VERSION/memory_schema: $TO_VERSION/" "$file"
    rm -f "$file.bak"
    echo "  Migrated: $file"
  fi
done

# Step 4: Append to learning-log
LOG_FILE="$HOME/.mega-sdd/memory/learning-log.md"
if [[ -f "$LOG_FILE" ]]; then
  cat >> "$LOG_FILE" <<EOF

## Migration $FROM_VERSION → $TO_VERSION — $TIMESTAMP

- **Source dir**: $MEMORY_DIR
- **Backup**: $BACKUP_DIR
- **Files migrated**: $(ls "$MEMORY_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
- **Rollback**: restore from \`$BACKUP_DIR\` if migration unexpected
EOF
fi

echo ""
echo "Migration complete. Backup: $BACKUP_DIR"
echo "Rollback: rm -rf '$MEMORY_DIR' && mv '$BACKUP_DIR' '$MEMORY_DIR'"
