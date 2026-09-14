---
id: U-003
title: Add appointment status labels and an accessible status chip
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:119, PRD/prd-clinic.md:211]
task_type: extend
grounding_confidence: LOW
risk: low
module: M-clinic-core
depends_on: [U-001]
target_files:
  - path: src/libs/label-maps.ts
    operation: modify
  - path: src/features/appointments/components/AppointmentStatusChip/index.tsx
    operation: create
  - path: src/features/appointments/components/AppointmentStatusChip/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"
    expects: "renders the text label for every status"
  - type: test
    command: "pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"
    expects: "renders a distinct icon for every status"
  - type: test
    command: "pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"
    expects: "keeps existing label maps unchanged"
binding_refs: [OQ-CN-1]
---

# Unit U-003 — Add appointment status labels and an accessible status chip

## Goal


Add the value→label maps for appointment status and booking channel to the shared label-maps module and a reusable `AppointmentStatusChip` that encodes status by text + icon + color.

## Anchors


- src/libs/label-maps.ts:1-56 — existing `Record<string, string>` label maps; append the new maps in the same style
- src/features/users/components/table/index.tsx:1-20 — client component import ordering used in features

## Claims


- C-U003-01 "label-maps.ts is the central value→label module" — expect: src/libs/label-maps.ts — must-exist
- C-U003-02 "ACCOUNT_TYPE_LABELS is an existing export that must survive" — expect: src/libs/label-maps.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/components/AppointmentStatusChip/index.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep every existing export of src/libs/label-maps.ts unchanged (constitution A-005)
  Source: constitution.md §A A-005
- MUST NOT convey status by color alone — every status renders its text label and an icon (constitution F-002)
  Source: constitution.md §F F-002
- MUST keep the chip text contrast at or above 4.5:1 against its background (constitution F-001)
  Source: constitution.md §F F-001
- MUST use Iconify tabler classes for the icons (constitution A-006)
  Source: constitution.md §A A-006

## Migration notes


- **REMOVE**: nothing.
- **KEEP**: every existing export in `src/libs/label-maps.ts` (`TUJUAN_LABELS` … `ACCOUNT_TYPE_LABELS`) and the header comment, unchanged.
- **ADD**: `APPOINTMENT_STATUS_LABELS`, `BOOKING_CHANNEL_LABELS` (with the type import from `@/features/appointments/types`), and the new `AppointmentStatusChip` component folder.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).

## Out of scope


- Theme primary color — U-004
- Where the chip is placed — U-014, U-016, U-019
