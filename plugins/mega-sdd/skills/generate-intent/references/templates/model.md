---
type: prose
doc_id: model
vault_version: "{{VAULT_VERSION}}"
aliases: [Data Model, DBML, Schema]
tags: ["vault/{{PROJECT_SLUG}}", "doc/data-model"]
---

# Data Model

> **TL;DR**: Database schema — entities, fields, relations, constraints.
> **Audience**: BE Developer, DBA, IT Architect.
> **Read when**: designing schema, writing a migration, reviewing a query plan.

> **Note**: TL;DR placeholders shown in English. At runtime, render them in the PRD's language.

## Entities (DBML)

```dbml
// Purpose: <1 line — what this entity is for>
Table <entity_name> {
  id bigint [pk, increment]
  <field> <type> [<constraints>, note: '<purpose>']
  created_at timestamp [default: `now()`]
  updated_at timestamp
}

Ref: <table>.<fk_field> > <other_table>.id  // many-to-one
```

> Default to DBML. The `// Purpose:` comment above each Table is machine-read into vault.json `entities[].purpose` by derive-vault-json.sh.

<!-- compact-skip -->
## Entity descriptions

### <entity_name>

- **Purpose**: <1 line>
- **Key fields**: `<field>` — <type, why it exists>
- **Relations**: belongs to `<other_entity>` via `<fk>`
<!-- /compact-skip -->

## Constraints

- **Uniqueness**: `<table>.<field>` unique within `<scope>`
- **Indexes**: `<table>(<field>)` for `<query pattern>`

> Only constraints with explicit source or confirmed project convention.

---

## Sources

- PRD §<X.Y> · Existing schema: <file or system reference>

## Out of Scope

- <e.g. "Historical data migration from legacy system">

<!-- NO Open Questions section here (layout-2): ALL OQs live in
     constraints.md `## Open Questions`, each line carrying
     `[origin: model.md#<anchor>]` — derive-vault-json exits 2 on an OQ
     checkbox line found in this file. -->
