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

# ============================================================================
# DEFER resolution-awareness (round-2 Batch A1): a DEFER-resolved CONFLICT
# downgrades to an OQ (resolve-oq/references/binding-mode.md:45) — NO unit cites
# CONFLICT-N (task-typing.md:31 "DEFER became an OQ"), and the documented path is
# DEFER-only → generate-units with NO re-bind (binding-mode.md:58). The validator
# must NOT hard-block that path via conflict_id_dropped. KEEP_VAULT keeps its
# un-droppable citation obligation (task-typing.md:30); unknown action fail-closed.
# ============================================================================

# From here on CONFLICT-1 is NOT cited by any unit (the DEFER→OQ reality).
cat > "${VAULT}/units/U-001.md" <<'EOF'
---
id: U-001
title: Product model
binding_refs: []
---
# U-001
EOF

# --- Case 4 (DEFER, uncited): must PASS (advisory, not a blocking drop) ---
cat > "${VAULT}/binding.md" <<'EOF'
# Binding — v1

## Conflicts (0)

### ✅ CONFLICT-1 RESOLVED (DEFER) — `App\Models\Product` name collision
- **Vault doc**: 01-entities.md §Product
- **Codebase artifact**: app/Models/Product.php
- **Resolution**: ✅ RESOLVED (DEFER) 2026-07-05 — downgraded to OQ; re-resolve later
EOF
bash "$VALIDATOR" --cwd="$ROOT" --quiet >/dev/null 2>&1; code=$?
grep -q '"type": "conflict_id_dropped"' "$STATE" && { echo "FAIL: a DEFER-resolved uncited CONFLICT must NOT fire conflict_id_dropped (it downgraded to an OQ)"; cat "$STATE"; exit 1; }
grep -q '"type": "conflict_id_deferred_uncited"' "$STATE" || { echo "FAIL: expected advisory conflict_id_deferred_uncited extra for a DEFER-resolved uncited conflict"; cat "$STATE"; exit 1; }
[ "$code" = "0" ] || { echo "FAIL: DEFER-resolved uncited conflict must PASS (exit 0), got $code"; cat "$STATE"; exit 1; }
echo "PASS (DEFER-resolved uncited conflict is advisory, not a hard block)"

# --- Case 5 (KEEP_VAULT, uncited): must FAIL — citation obligation is deliberate ---
cat > "${VAULT}/binding.md" <<'EOF'
# Binding — v1

## Conflicts (0)

### ✅ CONFLICT-1 RESOLVED (KEEP_VAULT) — `App\Models\Product` name collision
- **Vault doc**: 01-entities.md §Product
- **Codebase artifact**: app/Models/Product.php
- **Resolution**: ✅ RESOLVED (KEEP_VAULT — code update pending) 2026-07-05 — vault is correct
EOF
bash "$VALIDATOR" --cwd="$ROOT" --quiet >/dev/null 2>&1; code=$?
grep -q '"type": "conflict_id_dropped"' "$STATE" || { echo "FAIL: a KEEP_VAULT-resolved uncited CONFLICT MUST still drop (un-droppable citation obligation, task-typing.md:30)"; cat "$STATE"; exit 1; }
[ "$code" = "1" ] || { echo "FAIL: KEEP_VAULT uncited conflict must FAIL (exit 1), got $code"; cat "$STATE"; exit 1; }
echo "PASS (KEEP_VAULT uncited conflict still blocks — obligation preserved)"

# --- Case 6 (RESOLVED, unknown/absent action, uncited): fail-closed => FAIL ---
cat > "${VAULT}/binding.md" <<'EOF'
# Binding — v1

## Conflicts (0)

### ✅ CONFLICT-1 RESOLVED — `App\Models\Product` name collision
- **Vault doc**: 01-entities.md §Product
- **Resolution**: ✅ RESOLVED 2026-07-05 — (no action tag)
EOF
bash "$VALIDATOR" --cwd="$ROOT" --quiet >/dev/null 2>&1; code=$?
grep -q '"type": "conflict_id_dropped"' "$STATE" || { echo "FAIL: a RESOLVED-but-unknown-action uncited CONFLICT must fail-closed (conflict_id_dropped)"; cat "$STATE"; exit 1; }
[ "$code" = "1" ] || { echo "FAIL: unknown-action uncited conflict must fail-closed (exit 1), got $code"; cat "$STATE"; exit 1; }
echo "PASS (unknown resolution action fails closed — only DEFER is exempt)"

# --- Case 7 (DEFER via Resolution LINE, heading has ✅ but no action paren): PASS ---
# BLOCKER-1 guard: the action must be read from the SAME surfaces Pass 3b reads the
# resolution marker from (heading OR `- **Resolution**:` line), not the heading alone.
cat > "${VAULT}/binding.md" <<'EOF'
# Binding — v1

## Conflicts (0)

### ✅ CONFLICT-1 — `App\Models\Product` name collision
- **Vault doc**: 01-entities.md §Product
- **Codebase artifact**: app/Models/Product.php
- **Resolution**: ✅ RESOLVED (DEFER) 2026-07-05 — downgraded to OQ; re-resolve later
EOF
bash "$VALIDATOR" --cwd="$ROOT" --quiet >/dev/null 2>&1; code=$?
grep -q '"type": "conflict_id_dropped"' "$STATE" && { echo "FAIL: DEFER action on the Resolution line (not the heading) must still exempt — BLOCKER-1"; cat "$STATE"; exit 1; }
grep -q '"type": "conflict_id_deferred_uncited"' "$STATE" || { echo "FAIL: expected advisory extra when DEFER is on the Resolution line"; cat "$STATE"; exit 1; }
[ "$code" = "0" ] || { echo "FAIL: DEFER-on-Resolution-line must PASS (exit 0), got $code"; cat "$STATE"; exit 1; }
echo "PASS (DEFER read from the Resolution line, not just the heading — BLOCKER-1)"

# --- Case 8 (F1 guard): a STRAY 'RESOLVED (DEFER)' token in a rationale bullet must NOT
#     demote a KEEP_VAULT conflict — the action is read ONLY from the heading or the
#     dedicated `- **Resolution**:` line, never an arbitrary earlier bullet (invariant #2) ---
cat > "${VAULT}/binding.md" <<'EOF'
# Binding — v1

## Conflicts (0)

### ✅ CONFLICT-1 — `App\Models\Product` name collision
- **Vault doc**: 01-entities.md §Product
- Considered RESOLVED (DEFER) but the vault is authoritative → KEEP_VAULT
- **Resolution**: ✅ RESOLVED (KEEP_VAULT — code update pending) 2026-07-05 — vault is correct
EOF
bash "$VALIDATOR" --cwd="$ROOT" --quiet >/dev/null 2>&1; code=$?
grep -q '"type": "conflict_id_dropped"' "$STATE" || { echo "FAIL: a stray 'RESOLVED (DEFER)' bullet must NOT demote a KEEP_VAULT conflict — action must be read from the heading/Resolution line only (F1)"; cat "$STATE"; exit 1; }
grep -q '"type": "conflict_id_deferred_uncited"' "$STATE" && { echo "FAIL: KEEP_VAULT with a stray DEFER bullet must NOT be classed advisory"; cat "$STATE"; exit 1; }
[ "$code" = "1" ] || { echo "FAIL: KEEP_VAULT with stray DEFER bullet must FAIL (exit 1), got $code"; cat "$STATE"; exit 1; }
echo "PASS (stray DEFER token in a bullet does not demote KEEP_VAULT — anchored extraction, F1)"

echo "ALL PASS"
