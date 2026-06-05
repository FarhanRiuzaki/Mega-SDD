#!/usr/bin/env bash
# Moat regression: an UNRESOLVED CONFLICT in binding.md must block the binding->units
# boundary even when the CONFLICT-ID is cited in a unit's frontmatter (so the existing
# propagation check passes). This is the B1-1 gap: invariant #2 promises "unresolved
# CONFLICTs block", but the validator only checked ID propagation, not resolution status.
# Per binding-contract.md: an active CONFLICT carries `Verdict: CONFLICT (BLOCKING)`;
# a resolved one is "marked ✅ / RESOLVED" and is exempt.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/scripts/validate-handoff-binding-units.sh"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

VAULT="${ROOT}/.mega-sdd/vaults/v1"
mkdir -p "${VAULT}/units"
STATE="${ROOT}/.mega-sdd/.validation-blockers.json"

# binding.md with one ACTIVE (unresolved) conflict.
cat > "${VAULT}/binding.md" <<'EOF'
# Binding — v1

## Conflicts (1)

### CONFLICT-1 — `App\Models\Product` name collision
- **Vault doc**: 01-entities.md §Product
- **Codebase artifact**: app/Models/Product.php
- **conflict_class**: naming-collision
- **resolution_complexity**: low
- **Verdict**: CONFLICT (BLOCKING)
- **Suggested action**: KEEP_VAULT | KEEP_CODE | DEFER | SPLIT
EOF

# A unit that CITES CONFLICT-1 in frontmatter — clears the propagation (drop) check,
# so any FAIL must come from the new unresolved-conflict check, not a dropped ID.
cat > "${VAULT}/units/U-001.md" <<'EOF'
---
id: U-001
title: Product model
binding_refs: [CONFLICT-1]
---
# U-001
EOF

# --- Case 1 (negative): active conflict + cited => must FAIL with conflict_unresolved ---
bash "$VALIDATOR" --cwd="$ROOT" --quiet >/dev/null 2>&1; code=$?
grep -q '"type": "conflict_unresolved"' "$STATE" || { echo "FAIL: expected conflict_unresolved drop for an active CONFLICT-1"; cat "$STATE"; exit 1; }
[ "$code" = "1" ] || { echo "FAIL: expected exit 1 for an unresolved conflict, got $code"; cat "$STATE"; exit 1; }
echo "PASS (active conflict blocks even when cited)"

# --- Case 2 (positive): mark CONFLICT-1 resolved (✅ RESOLVED) => must PASS ---
cat > "${VAULT}/binding.md" <<'EOF'
# Binding — v1

## Conflicts (0)

### CONFLICT-1 — `App\Models\Product` name collision ✅ RESOLVED
- **Vault doc**: 01-entities.md §Product
- **Codebase artifact**: app/Models/Product.php
- **Verdict**: RESOLVED (KEEP_CODE — vault patched to match code)
EOF
bash "$VALIDATOR" --cwd="$ROOT" --quiet >/dev/null 2>&1; code=$?
grep -q '"type": "conflict_unresolved"' "$STATE" && { echo "FAIL: a RESOLVED conflict must not fire conflict_unresolved"; cat "$STATE"; exit 1; }
[ "$code" = "0" ] || { echo "FAIL: expected exit 0 after resolution, got $code"; cat "$STATE"; exit 1; }
echo "PASS (resolved conflict is exempt)"

# --- Case 3 (clean): no CONFLICT headings at all => PASS, no false positive ---
cat > "${VAULT}/binding.md" <<'EOF'
# Binding — v1

## Conflicts (0)

All claims CONFIRMED. No conflicts.
EOF
bash "$VALIDATOR" --cwd="$ROOT" --quiet >/dev/null 2>&1; code=$?
grep -q '"type": "conflict_unresolved"' "$STATE" && { echo "FAIL: clean binding must not fire conflict_unresolved"; cat "$STATE"; exit 1; }
[ "$code" = "0" ] || { echo "FAIL: expected exit 0 for a clean binding, got $code"; cat "$STATE"; exit 1; }
echo "PASS (clean binding — no false positive)"

echo "ALL PASS"
