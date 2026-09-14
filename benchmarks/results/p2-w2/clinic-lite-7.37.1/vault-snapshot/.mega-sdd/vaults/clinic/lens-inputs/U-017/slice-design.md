---
id: U-017
title: Build the reassign appointment dialog
context_source: context.md#F-S-002
prd_source: [PRD/prd-clinic.md:177]
task_type: create
grounding_confidence: LOW
risk: medium
module: M-staff
depends_on: [U-009]
target_files:
  - path: src/features/appointments/components/ReassignDialog/index.tsx
    operation: create
  - path: src/features/appointments/components/ReassignDialog/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReassignDialog/index.test.tsx --reporter=verbose"
    expects: "lists only the other doctors as reassignment targets"
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReassignDialog/index.test.tsx --reporter=verbose"
    expects: "reassigns the appointment to the chosen doctor"
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReassignDialog/index.test.tsx --reporter=verbose"
    expects: "keeps the dialog open and shows the error when reassignment fails"
binding_refs: [OQ-CN-1, OQ-AR-1]
---## Goal


Create `ReassignDialog`, which lets a receptionist move an appointment to a different doctor and tells them the patient will be notified by email.

## Context (read first)


F-S-002 step 3: the receptionist can reassign an appointment to a different doctor, with a patient notification email that the upstream API sends (OQ-AR-1). The dialog is opened from the reception board (U-019) and calls `useReassignAppointment` from U-009; the server route only accepts receptionists (U-007).

## Anchors


- src/features/users/components/UserFormDialog.tsx — MUI dialog with a form, submit button state and close handling
- src/components/dialog/DeleteConfirmDialog.tsx — confirm-dialog layout with loading state

## Claims


- C-U017-01 "the project has a confirm dialog pattern" — expect: src/components/dialog/DeleteConfirmDialog.tsx — must-exist
- C-U017-02 "the appointments hooks exist" — expect: src/features/appointments/hooks/useAppointments/index.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/components/ReassignDialog/index.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST exclude the appointment's current doctor from the target list (source: PRD §Clinic.1 F-S-002 step 3)
  Source: PRD §Clinic.1 F-S-002 step 3
- MUST label the doctor select and show a failed reassignment as text inside the dialog (constitution F-001)
  Source: constitution.md §F F-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).

## Out of scope


- Placing the dialog on the board — U-019
