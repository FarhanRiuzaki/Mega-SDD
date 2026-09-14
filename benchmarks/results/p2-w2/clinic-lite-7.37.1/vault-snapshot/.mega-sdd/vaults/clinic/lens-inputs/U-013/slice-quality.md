---
id: U-013
title: Build the patient booking wizard and the /book page
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:142, PRD/prd-clinic.md:145, PRD/prd-clinic.md:146, PRD/prd-clinic.md:151, PRD/prd-clinic.md:80, PRD/prd-clinic.md:111, PRD/prd-clinic.md:205]
task_type: create
grounding_confidence: LOW
risk: high
module: M-patient-booking
depends_on: [U-001, U-009, U-012]
target_files:
  - path: src/features/appointments/components/BookingWizard/index.tsx
    operation: create
  - path: src/features/appointments/components/BookingWizard/index.test.tsx
    operation: create
  - path: src/app/(patient)/book/page.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+4 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "walks through all steps and books with the online channel"
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "blocks the next step until the current step fields are valid"
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "announces the booking confirmation in a status region"
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "returns to the date step when the slot was taken meanwhile"
  - type: manual
    desc: "Book an appointment at /book on a 375px viewport using only the keyboard: every step is reachable, errors are read as text, and the confirmation is announced."
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "does not send an override flag in the booking request"
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "does not claim the confirmation email has already been sent"
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "keeps patient details filled in after a slot conflict returns to the date step"
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "does not persist patient data in localStorage or cookies"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-001, OQ-CN-3, OQ-CN-4, OQ-DM-1]
---

# Unit U-013 — Build the patient booking wizard and the /book page

## Goal


Create the multi-step `BookingWizard` (doctor & service → date & time → your details → review & confirm) that books with `booking_channel = online`, and the public `/book` page that renders it.

## Anchors


- src/features/users/components/UserFormDialog.tsx — react-hook-form + `zodResolver` + MUI field wiring used in the project
- src/features/users/components/table/index.tsx:1-40 — feature component composition with hooks and MUI
- src/app/(blank-layout-pages)/login/page.tsx:1-22 — page file with `metadata`

## Claims


- C-U013-01 "the project wires forms with react-hook-form and zodResolver" — expect: src/features/users/components/UserFormDialog.tsx — must-exist
- C-U013-02 "the booking schema module exists" — expect: src/features/appointments/schemas/booking/index.ts — must-exist
- C-U013-03 "the appointments hooks exist" — expect: src/features/appointments/hooks/useAppointments/index.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/app/(patient)/book/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST use one form element with a single react-hook-form instance and validate each step with trigger on that step's BOOKING_STEP_FIELDS entry (source: PRD §8.1 Forms)
  Source: PRD §8.1 Forms
- MUST send bookingChannel online and never send the override flag from the patient wizard (constitution C-006)
  Source: constitution.md §C C-006
- MUST announce the booking confirmation in a role status aria-live region and show validation errors as text next to their inputs (constitution F-001)
  Source: constitution.md §F F-001
- MUST NOT store patient data in localStorage, cookies or logs (constitution F-004)
  Source: constitution.md §F F-004

## Anti-patterns


- Don't build four separate forms — the PRD asks for one form with per-step validation.
- Don't show the email as already sent from the client; say that a confirmation email with a cancel/reschedule link is on its way (the upstream sends it).

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `does not send an override flag in the booking request`: the captured POST body has no override key and bookingChannel is online.
- Adversarial addition — `does not claim the confirmation email has already been sent`: the status region says the email is on its way and never says it has been sent.
- Adversarial addition — `keeps patient details filled in after a slot conflict returns to the date step`: after the rejection and moving forward again, name, email, phone and reason still hold the typed values.
- Adversarial addition — `does not persist patient data in localStorage or cookies`: after submitting, neither localStorage nor document.cookie contains any entered name, email or phone.
- TBD: OQ-CN-4 — no client-side rate limiting.
- TBD: OQ-CN-3 — `today` / `now` come from the browser clock until the clinic timezone is decided.
- OQ-CLINIC-001 (P1, open): no consent text or retention notice is invented; add it when the regulation is decided.

## Out of scope


- Cancel and reschedule — U-006, U-014
- The patient shell — U-011
