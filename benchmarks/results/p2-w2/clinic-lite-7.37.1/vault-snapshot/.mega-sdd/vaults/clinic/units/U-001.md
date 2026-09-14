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

## Context (read first)

The entities come from `context.md#Data-model` (PRD §Clinic.4): staff with role `doctor | receptionist`, patient, service (price display-only, BR-005) and appointment with `status` (`booked | cancelled | completed`) and `booking_channel` (`online | staff`, BR-006). F-U-001 step 5 requires name, email, phone and reason for visit to be validated on the client and on the server, so the same schemas are reused by the booking wizard (U-013), the walk-in dialog (U-018), the reschedule form (U-014) and the BFF route handlers (U-005, U-006, U-007). Field names follow the house camelCase shape of the upstream API recommended in OQ-AR-1; no persistence happens in this repository (OQ-CN-1 recommendation).

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

## Implementation steps

1. Create `src/features/appointments/types/index.ts` with the literal unions `AppointmentStatus = 'booked' | 'cancelled' | 'completed'` and `BookingChannel = 'online' | 'staff'` (plus exported `APPOINTMENT_STATUSES` / `BOOKING_CHANNELS` arrays), and the interfaces `IDoctor` (`id`, `name`, `specialty?`, `workingHours?: { start: string; end: string } | null`), `IPatient` (`id`, `name`, `email`, `phone`), `IService` (`id`, `name`, `durationMinutes`, `price`), `IAppointment` (`id`, `patientId`, `doctorId`, `serviceId`, `startTime`, `endTime`, `status`, `reasonForVisit`, `bookingChannel`, `reminderAt?`, `reminderSent?`, plus optional display summaries `patient?`, `doctor?`, `service?`) and `IAvailability` (`doctorId`, `date`, `bookedStartTimes: string[]`, `workingHours?`), following the naming of the users feature anchor.
2. Add the payload types `TCreateAppointmentPayload` (`doctorId`, `serviceId`, `startTime`, `patient: { name, email, phone }`, `reasonForVisit`, `bookingChannel`, `override?: boolean`), `TReschedulePayload` (`startTime`), `TCancelPayload` (`token`) and `TReassignPayload` (`doctorId`) in the same file.
3. Create `src/features/appointments/schemas/booking/index.ts` exporting `bookingSchema` (form: `doctorId`, `serviceId`, `date` as `YYYY-MM-DD`, `startTime` as `HH:mm`, `name`, `email`, `phone`, `reasonForVisit` — every text field trimmed and non-empty, email via `z.email`), `BookingFormValues`, `bookingFormDefaults`, and `BOOKING_STEP_FIELDS` mapping the four wizard steps (`doctorService`, `dateTime`, `details`, `review`) to the field names each step validates with `trigger(fields)`, so every schema field belongs to exactly one step.
4. In the same module export `walkInSchema` (`bookingSchema` plus `override: z.boolean()`), `rescheduleSchema` (`date`, `startTime`) with its defaults, and the server-side payload schemas `createAppointmentPayloadSchema`, `reschedulePayloadSchema` (`startTime` as an ISO-like `YYYY-MM-DDTHH:mm` string), `cancelPayloadSchema` (non-empty `token`) and `reassignPayloadSchema` (non-empty `doctorId`), each with its inferred type.
5. Write `index.test.ts` with the four tests named exactly as the acceptance_test `expects` strings: a complete booking parses; an invalid email fails with a readable message; whitespace-only `name` and `reasonForVisit` fail; the union of `BOOKING_STEP_FIELDS` equals the `bookingSchema` keys with no duplicates.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-3 — date/time strings stay timezone-free until the clinic timezone is decided.
- TBD: OQ-DM-1 — nothing here assumes how long services occupy slots.

## Out of scope

- Slot generation and availability rules — U-002
- Status labels and the status chip — U-003
- API calls — U-009
