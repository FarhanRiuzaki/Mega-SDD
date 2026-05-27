---
generated_by: mega-sdd:extract-intelligence
generated_at: 2026-05-27
domain: user-management
classification: master
criticality: high
rebuild_phase: 1
depends_on: []
verified_count: 2
inferred_count: 1
open_count: 0
source_files_cited: 1
---

# User Management

> **Classification**: master
> **Criticality**: high
> **Depends on**: none
> **Rebuild Phase**: 1

## 1. Purpose

User management handles CRUD for system user accounts. [VERIFIED] (`src/models/user.ts:1`)

## 2. Actors

| Actor | Role |
|---|---|
| Admin | Creates/manages users. [VERIFIED] (`src/controllers/admin.ts:10`) |

## 3. Flow (Input → Process → Output)

Admin fills form → validates → creates user → sends welcome email.

This is prose, NOT Mermaid — the validator should flag it.

## 4. Inputs

Admin submits user registration form. [INFERRED]

## 5. Process

1. Validate email uniqueness. [VERIFIED] (`src/validators/user.ts:5`)
2. Hash password.
3. Create record.

## 6. Outputs

User record in database.

## 7. Business Rules

| ID | Rule | Why | Source | Confidence | Mutability |
|---|---|---|---|---|---|
| BR-USER-1 | Email must be unique | Data integrity | `src/validators/user.ts:5` | [VERIFIED] (`src/validators/user.ts:5`) | [LOCKED] |

## 8. State Machine

_N/A — not a workflow domain._

## 9. Edge Cases & Gotchas

_None detected — see §10 Open Questions._

## 10. Open Questions

(none)

## 11. Source References

- `src/models/user.ts:1` — user model
- `src/controllers/admin.ts:10` — admin CRUD
- `src/validators/user.ts:5` — email uniqueness
