---
id: U-002
title: Implement the bookable slot rules library
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:70, PRD/prd-clinic.md:147, PRD/prd-clinic.md:148, PRD/prd-clinic.md:206]
task_type: create
grounding_confidence: LOW
risk: low
module: M-clinic-core
depends_on: []
target_files:
  - path: src/features/appointments/utils/slots/index.ts
    operation: create
  - path: src/features/appointments/utils/slots/index.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "generates 28 fifteen-minute slots from 09:00 to 16:45 without lunch"
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "narrows slots to the doctor working hours within the global bounds"
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "hides booked start times from the available slots"
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "rejects past dates and weekends"
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "hides slots earlier than now on the current day"
binding_refs: [OQ-CN-1, OQ-CN-3, OQ-DM-1]
---

# Unit U-002 — Implement the bookable slot rules library

## Goal

Provide pure, dependency-free functions that turn BR-001 / BR-002 into the list of bookable 15-minute slots for a doctor and date, used by the patient picker and the staff views.

## Context (read first)

BR-001 (PRD §5) fixes bookable hours at 09:00–17:00 in 15-minute slots with no slots during the 12:00–13:00 lunch break, and a doctor's `working_hours` may only narrow that window. F-U-001 steps 3–4 disable past, weekend and out-of-hours choices and hide taken slots, and AC-002 requires the picker to hide booked slots (the database-level rejection of a concurrent insert is upstream, OQ-AR-1). The slot picker (U-012) and both staff views (U-016, U-019) import these helpers, so the rules live in exactly one place.

## Anchors

- src/libs/api/query-params/index.ts — pure helper module with a co-located `index.test.ts`; mirror this folder-with-test shape
- src/libs/api/query-params/index.test.ts — Vitest style used for pure helpers

## Claims

- C-U002-01 "pure helpers with tests live in a folder with index.ts and index.test.ts" — expect: src/libs/api/query-params/index.test.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/utils/slots/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep the module free of React, network and date-library imports so it stays a pure function module (constitution A-002)
  Source: constitution.md §A A-002
- MUST treat 09:00–17:00 and the 12:00–13:00 lunch break as hard outer bounds that working hours can only narrow (source: PRD §5 BR-001)
  Source: PRD §5 BR-001

## Anti-patterns

- Don't convert between timezones — the clinic timezone is open (OQ-CN-3); work on `YYYY-MM-DD` dates and `HH:mm` times.
- Don't mark the slots after a longer service as taken — whether a long visit blocks following slots is open (OQ-DM-1); only booked start times are hidden.

## Implementation steps

1. Create `src/features/appointments/utils/slots/index.ts` exporting `BOOKING_HOURS` (`{ start: '09:00', end: '17:00', lunchStart: '12:00', lunchEnd: '13:00', slotMinutes: 15 }`) and `generateDaySlots(window?: { start: string; end: string } | null): string[]`, which walks from 09:00 in 15-minute steps, skips every start inside 12:00–13:00, stops before 17:00, and when a window is given clamps it into the global bounds before filtering — so an out-of-range window never adds slots.
2. Add `isBookableDate(date: string, today: string): boolean` (false for any date before `today` and for Saturdays and Sundays, parsing `YYYY-MM-DD` as a local calendar date without timezone math) and `availableSlots({ date, today, bookedStartTimes, window, now })`, which returns `generateDaySlots(window)` minus `bookedStartTimes`, returns an empty list for a non-bookable date, and on the current day (`date === today`) also drops slots whose start is not later than `now` (`HH:mm`).
3. Write `index.test.ts` with the five tests named exactly as the acceptance_test `expects` strings, including the adversarial cases: a working-hours window wider than 09:00–17:00 still yields no slot before 09:00 or at/after 17:00, and no generated slot ever falls between 12:00 and 12:45.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-3 — "today" and "now" are passed in by the caller; the timezone that produces them is not decided here.
- TBD: OQ-DM-1 — only booked start times are removed.

## Out of scope

- Rendering the picker — U-012
- Fetching booked start times — U-009
