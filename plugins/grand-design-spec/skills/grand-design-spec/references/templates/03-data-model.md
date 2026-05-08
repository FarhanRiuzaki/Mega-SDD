# 03 — Data Model

> **TL;DR**: Skema database — entitas, field, relasi, dan constraint.
> **Untuk siapa**: BE Developer, DBA, IT Architect.
> **Baca kalau**: lo lagi design schema, write migration, atau review query plan.

## Entities (DBML)

```dbml
Table <entity_name> {
  id bigint [pk, increment]
  <field> <type> [<constraints>, note: '<purpose>']
  created_at timestamp [default: `now()`]
  updated_at timestamp
  deleted_at timestamp [null]
}

Table <next_entity> {
  id bigint [pk, increment]
  <field> <type>
}

Ref: <table>.<fk_field> > <other_table>.id  // many-to-one
Ref: <table>.<fk_field> - <other_table>.id  // one-to-one
```

> Default to DBML for consistency with existing project conventions. Fall back to entity tables only if DBML cannot express something.

## Entity descriptions

### <entity_name>

- **Purpose**: <1 line>
- **Key fields**:
  - `<field>` — <type, why it exists>
- **Relations**:
  - belongs to `<other_entity>` via `<fk>`
  - has many `<other_entity>`

### <next_entity>

<repeat>

## Constraints

- **Uniqueness**: `<table>.<field>` must be unique within `<scope>`
- **Soft delete**: `<table>` uses `deleted_at` (per project convention)
- **Audit**: `<table>` requires `created_by`, `updated_by` (FK to users)
- **Indexes**: `<table>(<field>)` for `<query pattern>`

> Only state constraints with explicit source or that follow project conventions Han already confirmed.

---

## Sources

- PRD §<X.Y>
- Existing schema: <file or system reference>

## Out of Scope

- <e.g. "Historical data migration from legacy system">
- <if unknown: "TBD - confirm with PO">

## Open Questions

- [ ] **OQ-DM-1** [P{1|2|3}]: <e.g. "PRD mentions 'order status' but does not enumerate states">
- [ ] **OQ-DM-2** [P{1|2|3}]: <e.g. "Multi-tenant strategy: shared tables with tenant_id, or schema-per-tenant?">
