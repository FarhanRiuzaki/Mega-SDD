---
id: U-014
title: Build the token reschedule page
context_source: context.md#F-U-004
prd_source: [PRD/prd-clinic.md:165, PRD/prd-clinic.md:166, PRD/prd-clinic.md:167, PRD/prd-clinic.md:192, PRD/prd-clinic.md:210]
task_type: create
grounding_confidence: LOW
risk: high
module: M-patient-self-service
depends_on: [U-003, U-009, U-012]
target_files:
  - path: src/features/appointments/components/RescheduleForm/index.tsx
    operation: create
  - path: src/features/appointments/components/RescheduleForm/index.test.tsx
    operation: create
  - path: src/app/(patient)/reschedule/[token]/page.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "shows the current appointment for the token"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "reschedules to the chosen free slot"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "shows an error when the token is invalid"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "announces the rescheduled confirmation in a status region"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "sends only startTime in the reschedule request body"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "hides the slot picker for a cancelled appointment"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "never renders the token value anywhere on the page"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-001, OQ-CLINIC-003, OQ-FL-1]
---

# Unit U-014 — Build the token reschedule page

## Goal

Create the public `/reschedule/[token]` page and its `RescheduleForm`, which shows the patient's current appointment and moves it to a newly chosen free slot.

## Context (read first)

F-U-004: the patient opens the reschedule link (same one-time token), sees the current appointment, picks a new available slot and confirms; the upstream frees the old slot and books the new one atomically (AC-006, OQ-AR-1) and re-sends the confirmation. The token is the only authorization (constitution B-002) and the route is public (U-010), inside the `(patient)` layout (U-011). The status chip (U-003) shows the current status; an invalid or used token must show a clear error instead of a broken page.

## Anchors

- src/features/users/components/UserDetailDialog.tsx — loading / error / detail rendering of a single record via a query hook
- src/app/(dashboard)/users/[id]/page.tsx — dynamic-segment page reading its param

## Claims

- C-U014-01 "detail rendering with a query hook exists in the users feature" — expect: src/features/users/components/UserDetailDialog.tsx — must-exist
- C-U014-02 "the slot picker exists" — expect: src/features/appointments/components/SlotPicker/index.tsx — must-exist
- C-U014-03 "the status chip exists" — expect: src/features/appointments/components/AppointmentStatusChip/index.tsx — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/app/(patient)/reschedule/[token]/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST authorize only through the token from the URL and never ask the patient to log in (constitution B-002)
  Source: constitution.md §B B-002
- MUST offer only free slots of the same doctor through SlotPicker and the availability hook (source: PRD §Clinic.1 F-U-004 step 2)
  Source: PRD §Clinic.1 F-U-004 step 2
- MUST announce the rescheduled confirmation in a role status aria-live region (constitution F-001)
  Source: constitution.md §F F-001
- MUST NOT render the token itself anywhere on the page (constitution B-002)
  Source: constitution.md §B B-002

## Implementation steps

1. Create `src/app/(patient)/reschedule/[token]/page.tsx` (async, `params: Promise<{ token: string }>`) exporting `metadata = { title: 'Reschedule appointment' }` and rendering `<RescheduleForm token={token} />`.
2. Create the client component `RescheduleForm`: load `useAppointmentByToken(token)`; while loading show a progress indicator; on error show a text message that the link is invalid or already used; otherwise show the current appointment (doctor, service, date, time and `AppointmentStatusChip`), and when its status is not `booked` show that it can no longer be changed instead of the picker.
3. For a booked appointment render `SlotPicker` wired to `useAvailability(appointment.doctorId, date)` using a small react-hook-form + `rescheduleSchema` form; the confirm button submits `useRescheduleAppointment` with `{ token, startTime: `${date}T${startTime}` }` and on success shows a `role='status' aria-live='polite'` panel with the new date and time and a note that a confirmation email is on its way; a rejected submission keeps the form and shows the upstream message as text.
4. Write `index.test.tsx` (MSW `server.use` for the token and availability routes) with every test named exactly as the acceptance_test `expects` strings (see Acceptance criteria for the adversarial additions); the adversarial cases must assert the PUT body carries only `startTime` and that a cancelled appointment shows no slot picker.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `sends only startTime in the reschedule request body`: the captured PUT body is exactly { startTime } with no token, doctorId or id.
- Adversarial addition — `hides the slot picker for a cancelled appointment`: for a cancelled appointment the slot picker and confirm button are absent and a not-changeable message is shown.
- Adversarial addition — `never renders the token value anywhere on the page`: on both the valid-token and the invalid-token path the raw token string never appears in the document.
- TBD: OQ-CLINIC-003 — no reschedule window is enforced client-side.
- TBD: OQ-FL-1 — this page offers no cancel action until the cancel confirmation screen is decided.
- OQ-CLINIC-001 (P1, open): no regulation-specific behavior is invented.

## Out of scope

- The cancel API — U-006
- Booking — U-013
