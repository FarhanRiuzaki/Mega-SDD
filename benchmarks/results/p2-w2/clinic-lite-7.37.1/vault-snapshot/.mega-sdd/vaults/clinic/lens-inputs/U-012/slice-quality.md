---
id: U-012
title: Build the accessible date and slot picker component
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:147, PRD/prd-clinic.md:148, PRD/prd-clinic.md:109, PRD/prd-clinic.md:128]
task_type: create
grounding_confidence: LOW
risk: low
module: M-patient-booking
depends_on: [U-002]
target_files:
  - path: src/features/appointments/components/SlotPicker/index.tsx
    operation: create
  - path: src/features/appointments/components/SlotPicker/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/SlotPicker/index.test.tsx --reporter=verbose"
    expects: "shows only free slots for the chosen date"
  - type: test
    command: "pnpm test:run src/features/appointments/components/SlotPicker/index.test.tsx --reporter=verbose"
    expects: "announces the number of available slots in a live region"
  - type: test
    command: "pnpm test:run src/features/appointments/components/SlotPicker/index.test.tsx --reporter=verbose"
    expects: "flags a weekend date with an in-text error"
  - type: test
    command: "pnpm test:run src/features/appointments/components/SlotPicker/index.test.tsx --reporter=verbose"
    expects: "selects a slot by keyboard"
  - type: manual
    desc: "At 375px width, tab through the date field and the slot buttons: each slot is at least 44px tall, focus is visible, and the live region reads the slot count after the date changes."
binding_refs: [OQ-CN-1, OQ-CN-3, OQ-DM-1, OQ-CLINIC-006]
---

# Unit U-012 — Build the accessible date and slot picker component

## Goal


Create a controlled `SlotPicker` that lets a user choose a bookable date and one free 15-minute slot, with in-text errors and a live region announcing slot availability.

## Anchors


- src/@core/components/mui/TextField.tsx — `CustomTextField`, the project's labelled text field
- src/components/table/BaseTable.tsx:1-30 — client component conventions and MUI import style

## Claims


- C-U012-01 "CustomTextField is the project's labelled input" — expect: src/@core/components/mui/TextField.tsx — must-exist
- C-U012-02 "the slot rules module exists" — expect: src/features/appointments/utils/slots/index.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/components/SlotPicker/index.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST take every slot decision from the U-002 helpers instead of re-implementing hours, lunch or weekend rules (source: PRD §5 BR-001)
  Source: PRD §5 BR-001
- MUST hide taken slots rather than show them disabled or labelled, so no other patient's booking is revealed (constitution B-006)
  Source: constitution.md §B B-006
- MUST label the date input, show errors as text, announce availability in an aria-live polite status region and keep every slot button at least 44px tall (constitution F-001)
  Source: constitution.md §F F-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-3 — `today` / `now` are provided by the caller.

## Out of scope


- Fetching availability — U-009 hooks, wired by U-013 / U-014 / U-018
