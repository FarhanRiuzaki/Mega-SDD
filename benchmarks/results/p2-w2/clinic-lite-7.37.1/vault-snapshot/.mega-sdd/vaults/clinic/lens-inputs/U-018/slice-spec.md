---
id: U-018
title: Build the walk-in appointment dialog with emergency override
context_source: context.md#F-S-002
prd_source: [PRD/prd-clinic.md:178, PRD/prd-clinic.md:179]
task_type: create
grounding_confidence: LOW
risk: high
module: M-staff
depends_on: [U-001, U-009, U-012]
target_files:
  - path: src/features/appointments/components/WalkInDialog/index.tsx
    operation: create
  - path: src/features/appointments/components/WalkInDialog/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "creates a walk-in appointment with the staff channel"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "allows a time outside the slot grid only with the emergency override"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "validates patient details before submitting"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "keeps the dialog open and shows an error message when appointment creation fails"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "does not call the create appointment endpoint when patient details are invalid"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "resets the selected time when the emergency override switch is turned off"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-001]
---

# Unit U-018 — Build the walk-in appointment dialog with emergency override

## Goal

Create `WalkInDialog`, which lets a receptionist create an appointment for a walk-in or phone patient with `booking_channel = staff`, including an emergency override for times outside the slot grid.

## Context (read first)

F-S-002 steps 4–5: the receptionist can override booking restrictions for an emergency walk-in outside slot times and create appointments for walk-in / phone patients with `booking_channel = staff` (BR-006). The dialog reuses the U-001 `walkInSchema`, the `SlotPicker` (U-012) for normal slots and `useCreateAppointment` (U-009); the BFF (U-005) only accepts `staff` or override bookings from a receptionist, so the UI and the server agree.

## Anchors

- src/features/users/components/UserFormDialog.tsx — MUI dialog + react-hook-form + zodResolver pattern
- src/@core/components/mui/TextField.tsx — `CustomTextField` for labelled inputs

## Claims

- C-U018-01 "the project wires dialog forms with react-hook-form" — expect: src/features/users/components/UserFormDialog.tsx — must-exist
- C-U018-02 "the slot picker exists" — expect: src/features/appointments/components/SlotPicker/index.tsx — must-exist
- C-U018-03 "the booking schema module exists" — expect: src/features/appointments/schemas/booking/index.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/components/WalkInDialog/index.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST send bookingChannel staff for every appointment created from this dialog (constitution C-006)
  Source: constitution.md §C C-006
- MUST offer a free time outside the slot grid only while the emergency override switch is on (source: PRD §Clinic.1 F-S-002 step 4)
  Source: PRD §Clinic.1 F-S-002 step 4
- MUST validate patient details with walkInSchema before submitting and show errors as text (constitution B-001)
  Source: constitution.md §B B-001

## Implementation steps

1. Create the client component `WalkInDialog` with props `{ open: boolean; onClose(): void; defaultDate?: string }`, one `useForm` with `zodResolver(walkInSchema)`, labelled selects for doctor and service (`useDoctors`, `useServices`), and patient name, email, phone and reason-for-visit fields with in-text errors.
2. Render a labelled "Emergency override" switch: while off, time selection is `SlotPicker` fed by `useAvailability(doctorId, date)`; while on, a labelled `type='time'` input accepts any `HH:mm` and the dialog states that the time is outside the regular slots; submit calls `useCreateAppointment` with `{ doctorId, serviceId, startTime: `${date}T${startTime}`, patient: { name, email, phone }, reasonForVisit, bookingChannel: 'staff', override }` and closes on success, keeping the form and showing the error text on failure.
3. Write `index.test.tsx` (MSW `server.use` for doctors, services, availability and appointments) with every test named exactly as the acceptance_test `expects` strings (see Acceptance criteria for the adversarial additions); the adversarial cases must assert the POST body carries `bookingChannel: 'staff'`, `override: false` for a normal slot and `override: true` with an off-grid time such as `18:10` only when the switch is on.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `keeps the dialog open and shows an error message when appointment creation fails`: with a failing POST /api/v1/appointments, onClose is not called and the error text is rendered in the dialog.
- Adversarial addition — `does not call the create appointment endpoint when patient details are invalid`: submitting with a blank or invalid name, email or reason sends no request to the appointments route.
- Adversarial addition — `resets the selected time when the emergency override switch is turned off`: after entering an off-grid time with override on, switching it off clears the time so it cannot be submitted with override false.
- OQ-CLINIC-001 (P1, open): no regulation-specific behavior is invented.

## Out of scope

- Placing the dialog on the board — U-019
