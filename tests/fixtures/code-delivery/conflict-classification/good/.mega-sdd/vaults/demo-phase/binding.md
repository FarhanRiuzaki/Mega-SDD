---
vault: demo-phase
mode: existing
verdict: PASS_WITH_OQ
---

# Binding — demo-phase

## Conflicts (2)

| Conflict | Status | Note |
|---|---|---|
| **CONFLICT-1** | ACTIVE | `App\Models\Product` name collision |
| **CONFLICT-2** | RESOLVED | demo Product removed 2026-05-29 |

### CONFLICT-1 — `App\Models\Product` name collision

- **Claim**: C-001
- **Vault doc**: 01-entities.md §Product
- **Codebase artifact**: `app/Models/Product.php` (pre-existing demo scaffold)
- **conflict_class**: naming-collision
- **resolution_complexity**: low
- **Verdict**: CONFLICT (BLOCKING) — vault Product and demo Product are different entities sharing a class name.
- **Suggested action**: KEEP_VAULT (rename/remove demo Product).

### ✅ CONFLICT-2 RESOLVED — 2026-05-29T10:30:00Z

- Resolved via removal of the demo Setting seeder collision. No further action.

## Verdict

PASS_WITH_OQ — 1 active CONFLICT pending resolution (classified).
