---
id: U-016
title: Build the doctor schedule page with today and week views
context_source: context.md#F-S-001
prd_source: [PRD/prd-clinic.md:170, PRD/prd-clinic.md:171, PRD/prd-clinic.md:172, PRD/prd-clinic.md:193, PRD/prd-clinic.md:110, PRD/prd-clinic.md:209]
task_type: create
grounding_confidence: LOW
risk: medium
module: M-staff
depends_on: [U-002, U-003, U-009]
target_files:
  - path: src/features/appointments/components/DoctorSchedule/index.tsx
    operation: create
  - path: src/features/appointments/components/DoctorSchedule/index.test.tsx
    operation: create
  - path: src/features/appointments/components/AppointmentDetailDialog/index.tsx
    operation: create
  - path: src/app/(dashboard)/staff/schedule/page.tsx
    operation: create
existing_interfaces:
  - file: src/components/rbac/ProtectedRoute.tsx
    symbol: ProtectedRoute
    note: "reuse unchanged with require.roles"
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/DoctorSchedule/index.test.tsx --reporter=verbose"
    expects: "shows the signed-in doctor appointments for today"
  - type: test
    command: "pnpm test:run src/features/appointments/components/DoctorSchedule/index.test.tsx --reporter=verbose"
    expects: "switches to the week view"
  - type: test
    command: "pnpm test:run src/features/appointments/components/DoctorSchedule/index.test.tsx --reporter=verbose"
    expects: "opens appointment details with patient name and reason for visit"
  - type: test
    command: "pnpm test:run src/features/appointments/components/DoctorSchedule/index.test.tsx --reporter=verbose"
    expects: "shows an empty state when there are no appointments"
  - type: manual
    desc: "Sign in as a doctor, open /staff/schedule: only your own appointments appear in today and week views; sign in as a user without the doctor role: the Access Denied panel is shown."
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-AR-2, OQ-CLINIC-006]
---## Goal


Create `/staff/schedule` for the `doctor` role: a schedule grid with a today view and a week view of the doctor's own appointments, and a detail dialog showing patient name and reason for visit.

## Context (read first)


F-S-001: after login the doctor sees today and week views of their own column only and drills into appointment details (patient name, reason for visit). The server already limits a doctor to their own appointments (U-007, AC-005); the page adds the role guard with `ProtectedRoute` (constitution B-005). The OQ-CLINIC-006 recommendation builds the grid with MUI instead of Schedule-X, rows are the day's 15-minute slots from U-002 and the week view shows Monday–Friday because weekends are not bookable (F-U-001 step 3). There is no menu entry yet because menu gating needs permission names (OQ-AR-2).

## Anchors


- src/app/(dashboard)/users/page.tsx:1-17 — page wrapping a feature component in `ProtectedRoute require={...}`
- src/components/rbac/ProtectedRoute.tsx:18-60 — `require.roles` support and the Access Denied panel
- src/features/users/components/UserDetailDialog.tsx — MUI dialog pattern for a record's details
- src/components/misc/EmptyState.tsx — empty-state component

## Claims


- C-U016-01 "ProtectedRoute supports role requirements" — expect: src/components/rbac/ProtectedRoute.tsx:ProtectedRoute
- C-U016-02 "an EmptyState component exists" — expect: src/components/misc/EmptyState.tsx — must-exist
- C-U016-03 "the appointments hooks exist" — expect: src/features/appointments/hooks/useAppointments/index.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/components/rbac/ProtectedRoute.tsx
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- DO NOT modify src/data/navigation/verticalMenuData.tsx
  Source: context.md OQ-AR-2 (no menu entry until permission names are decided)
- DO NOT modify src/data/navigation/horizontalMenuData.tsx
  Source: context.md OQ-AR-2 (no menu entry until permission names are decided)
- file src/app/(dashboard)/staff/schedule/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST guard the page with ProtectedRoute requiring the doctor role (constitution B-005)
  Source: constitution.md §B B-005
- MUST render appointment status with AppointmentStatusChip so status is never color-only (constitution F-002)
  Source: constitution.md §F F-002
- MUST keep the grid keyboard-reachable with each appointment cell a focusable button that opens the detail dialog (constitution F-001)
  Source: constitution.md §F F-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-AR-2 — no navigation menu entry until permission names are decided; reach the page by URL.

## Out of scope


- The receptionist board — U-019
- Editing appointments from the doctor view (not in F-S-001)
