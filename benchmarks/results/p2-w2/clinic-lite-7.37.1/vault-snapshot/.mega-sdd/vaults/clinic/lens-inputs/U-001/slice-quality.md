---
id: U-001
title: Define appointment domain types and zod payload schemas
context_source: context.md#Data-model
prd_source: [PRD/prd-clinic.md:202, PRD/prd-clinic.md:149, PRD/prd-clinic.md:95]
task_type: create
grounding_confidence: LOW
risk: low
module: M-clinic-core
depends_on: []
target_files:
  - path: src/features/appointments/types/index.ts
    operation: create
  - path: src/features/appointments/schemas/booking/index.ts
    operation: create
  - path: src/features/appointments/schemas/booking/index.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "accepts a complete booking"
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "rejects an invalid email with a readable message"
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "rejects whitespace-only name and reason"
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "covers every booking field in exactly one wizard step"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-DM-1, OQ-CN-3]
---

# Unit U-001 — Define appointment domain types and zod payload schemas

## Goal


Create the clinic domain types (doctor/staff, patient, service, appointment, availability) and the zod schemas that validate the booking form, the walk-in form and the server-side request payloads, so every later unit shares one contract.

## Anchors


- src/features/users/types/index.ts:1-29 — `I`-prefixed entity interfaces and `T`-prefixed payload types; follow this naming
- src/features/users/schemas/user.schema.ts:1-30 — a schema file exports schema + inferred type + defaults
- src/libs/api/query-params/index.ts — a module that owns a test lives in `<name>/index.ts` + `<name>/index.test.ts`

## Claims


- C-U001-01 "feature types follow the users feature shape" — expect: src/features/users/types/index.ts — must-exist
- C-U001-02 "schema files export schema, inferred type and defaults" — expect: src/features/users/schemas/user.schema.ts — must-exist
- C-U001-03 "the folder-with-test module pattern is established" — expect: src/libs/api/query-params/index.test.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/types/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- file src/features/appointments/schemas/booking/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST export every schema together with its inferred type and its defaults (constitution A-004)
  Source: constitution.md §A A-004
- MUST keep the schema module and its test together in schemas/booking/ (constitution A-002)
  Source: constitution.md §A A-002
- MUST NOT add any payment or price-calculation field beyond the display-only service price (constitution C-005)
  Source: constitution.md §C C-005

## Anti-patterns


- Don't invent entity fields the PRD §Clinic.4 data model does not list; display-only embedded summaries (`patient`, `doctor`, `service`) on an appointment are allowed because staff views must show patient name and reason for visit (context.md#F-S-001).
- Don't encode timezone conversions — the timezone is still open (OQ-CN-3); keep `date` as `YYYY-MM-DD` and times as `HH:mm`.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-3 — date/time strings stay timezone-free until the clinic timezone is decided.
- TBD: OQ-DM-1 — nothing here assumes how long services occupy slots.

## Out of scope


- Slot generation and availability rules — U-002
- Status labels and the status chip — U-003
- API calls — U-009
