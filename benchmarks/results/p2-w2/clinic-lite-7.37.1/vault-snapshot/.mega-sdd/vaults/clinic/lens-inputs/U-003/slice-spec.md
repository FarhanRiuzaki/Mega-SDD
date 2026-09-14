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

## Context (read first)

PRD §8.2 says status is never color-only — booked, cancelled and completed must be encoded by text + icon + color — and AC-007 makes this an acceptance criterion for every page. The house rule (constitution A-005) centralizes value→label maps in `src/libs/label-maps.ts`, so the labels go there and the chip only renders them. The doctor schedule (U-016), reschedule page (U-014) and reception board (U-019) all render this chip.

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

## Implementation steps

1. Append to `src/libs/label-maps.ts` two maps typed against the U-001 unions: `APPOINTMENT_STATUS_LABELS: Record<AppointmentStatus, string>` = `{ booked: 'Booked', cancelled: 'Cancelled', completed: 'Completed' }` and `BOOKING_CHANNEL_LABELS: Record<BookingChannel, string>` = `{ online: 'Online', staff: 'Staff' }`, leaving every existing map byte-identical.
2. Create the client component `AppointmentStatusChip` (`{ status: AppointmentStatus; size?: 'small' | 'medium' }`) that renders an MUI `Chip` whose label is the mapped text and whose icon is a distinct tabler icon per status (for example `tabler-calendar-check`, `tabler-calendar-x`, `tabler-circle-check`, marked `aria-hidden`), with a color per status chosen so the label text keeps 4.5:1 contrast — prefer an outlined/tonal variant with dark text over a filled chip with white text on a light hue; if an icon class does not render, rerun `pnpm build:icons` rather than importing icon components.
3. Write `index.test.tsx` using `renderWithProviders` with the three tests named exactly as the acceptance_test `expects` strings: each status shows its text label; the three statuses render three different icon classes; and an adversarial check that the pre-existing exports (for example `ACCOUNT_TYPE_LABELS.CASA === 'CASA'`) are still present.

## Migration notes

- **REMOVE**: nothing.
- **KEEP**: every existing export in `src/libs/label-maps.ts` (`TUJUAN_LABELS` … `ACCOUNT_TYPE_LABELS`) and the header comment, unchanged.
- **ADD**: `APPOINTMENT_STATUS_LABELS`, `BOOKING_CHANNEL_LABELS` (with the type import from `@/features/appointments/types`), and the new `AppointmentStatusChip` component folder.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).

## Out of scope

- Theme primary color — U-004
- Where the chip is placed — U-014, U-016, U-019
