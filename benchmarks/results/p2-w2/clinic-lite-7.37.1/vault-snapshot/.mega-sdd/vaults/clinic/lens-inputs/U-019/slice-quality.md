---
id: U-019
title: Build the reception board page with all doctors' schedules
context_source: context.md#F-S-002
prd_source: [PRD/prd-clinic.md:175, PRD/prd-clinic.md:176, PRD/prd-clinic.md:194, PRD/prd-clinic.md:108, PRD/prd-clinic.md:209]
task_type: create
grounding_confidence: LOW
risk: medium
module: M-staff
depends_on: [U-002, U-003, U-009, U-017, U-018]
target_files:
  - path: src/features/appointments/components/ReceptionBoard/index.tsx
    operation: create
  - path: src/features/appointments/components/ReceptionBoard/columns.tsx
    operation: create
  - path: src/features/appointments/components/ReceptionBoard/index.test.tsx
    operation: create
  - path: src/app/(dashboard)/staff/reception/page.tsx
    operation: create
existing_interfaces:
  - file: src/components/table/BaseTable.tsx
    symbol: BaseTable
    note: "reuse unchanged for the reception board data table"
  - file: src/components/rbac/ProtectedRoute.tsx
    symbol: ProtectedRoute
    note: "reuse unchanged with require.roles"
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReceptionBoard/index.test.tsx --reporter=verbose"
    expects: "lists every doctor appointment for the selected date"
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReceptionBoard/index.test.tsx --reporter=verbose"
    expects: "renders one schedule row per doctor"
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReceptionBoard/index.test.tsx --reporter=verbose"
    expects: "opens the reassign dialog for a row"
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReceptionBoard/index.test.tsx --reporter=verbose"
    expects: "opens the walk-in dialog from the board"
  - type: manual
    desc: "Sign in as a receptionist, open /staff/reception: every doctor's appointments for the chosen date appear in the grid and the table; a doctor-only user gets the Access Denied panel."
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-AR-2, OQ-CLINIC-006]
---

# Unit U-019 — Build the reception board page with all doctors' schedules

## Goal


Create `/staff/reception` for the `receptionist` role: a per-date schedule grid with one row per doctor, a reception board data table of the day's appointments, and entry points to reassign an appointment and to create a walk-in.

## Anchors


- src/features/users/components/table/index.tsx:1-128 — `BaseTable` usage with `customActions`, row actions and dialogs driven by state
- src/features/users/components/table/columns.tsx — column definitions in a sibling `columns.tsx`
- src/app/(dashboard)/users/page.tsx:1-17 — page wrapped in `ProtectedRoute`

## Claims


- C-U019-01 "BaseTable is the house data table" — expect: src/components/table/BaseTable.tsx:BaseTable
- C-U019-02 "ProtectedRoute supports role requirements" — expect: src/components/rbac/ProtectedRoute.tsx:ProtectedRoute
- C-U019-03 "the reassign dialog exists" — expect: src/features/appointments/components/ReassignDialog/index.tsx — must-exist
- C-U019-04 "the walk-in dialog exists" — expect: src/features/appointments/components/WalkInDialog/index.tsx — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/components/table/BaseTable.tsx
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- DO NOT modify src/data/navigation/verticalMenuData.tsx
  Source: context.md OQ-AR-2 (no menu entry until permission names are decided)
- DO NOT modify src/data/navigation/horizontalMenuData.tsx
  Source: context.md OQ-AR-2 (no menu entry until permission names are decided)
- file src/app/(dashboard)/staff/reception/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST guard the page with ProtectedRoute requiring the receptionist role (constitution B-005)
  Source: constitution.md §B B-005
- MUST render status with AppointmentStatusChip and the booking channel with BOOKING_CHANNEL_LABELS (constitution F-002, A-005)
  Source: constitution.md §F F-002, §A A-005
- MUST keep the grid and the table keyboard-reachable with labelled controls (constitution F-001)
  Source: constitution.md §F F-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-AR-2 — no navigation menu entry until permission names are decided; reach the page by URL.

## Out of scope


- The dialogs' internals — U-017, U-018
- Automatic handling of a sick doctor's appointments (OQ-CLINIC-004)
