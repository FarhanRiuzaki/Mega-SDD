# Binding — sample-vault

## Summary

| Claims | Confirmed | Conflict | OQ |
|---|---|---|---|
| 8 | 6 | 1 | 1 |

## Confirmed Claims

| ID | Vault claim | Codebase evidence |
|---|---|---|
| C-001 | user entity with UUID PK | src/models/user.ts:12 |
| C-002 | leave_request entity | src/models/leave-request.ts:5 |
| C-003 | REST API with Express | src/app.ts:1 |
| C-004 | PostgreSQL database | docker-compose.yml:15 |
| C-005 | Auth middleware on routes | src/middleware/auth.ts:8 — per constitution A-001, B-002 |
| C-006 | ESM imports | tsconfig.json:3 — per constitution A-003 |

## Section 1 — CONFLICTS

### CONFLICT-1: `role` field ↔ existing RBAC

```yaml
binding_conflict:
  id: CONFLICT-1
  type: entity_field_collision
  severity: MEDIUM
  vault_entity: user
  vault_field: role (string enum)
  code_analog:
    table: users
    field: role_id (FK to roles table)
  decision_options:
    A_reuse:
      label: Reuse existing roles FK
    B_replace:
      label: Replace with string enum
```

**Resolution**: Pending stakeholder decision.

## OQ Resolution Table

| OQ-ID | Resolution | Binding note |
|---|---|---|
| OQ-AR-1 | Pending | Caching strategy TBD |
| OQ-DM-1 | Use UUID PKs | Confirmed in codebase (src/models/user.ts:12) |

## Constitution References

Clauses cited in this binding: A-001, A-003, B-001, B-002, C-001
