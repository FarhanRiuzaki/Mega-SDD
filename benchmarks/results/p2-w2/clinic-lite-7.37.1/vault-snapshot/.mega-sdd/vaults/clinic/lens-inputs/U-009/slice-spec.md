---
id: U-009
title: Add the appointments repository and TanStack Query hooks
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:145, PRD/prd-clinic.md:165, PRD/prd-clinic.md:175]
task_type: create
grounding_confidence: LOW
risk: medium
module: M-clinic-core
depends_on: [U-001]
target_files:
  - path: src/features/appointments/repositories/appointment.repository.ts
    operation: create
  - path: src/features/appointments/hooks/useAppointments/index.ts
    operation: create
  - path: src/features/appointments/hooks/useAppointments/index.test.tsx
    operation: create
existing_interfaces:
  - file: src/libs/query-keys/index.ts
    symbol: createQueryKeys
    note: "reuse unchanged"
  - file: src/libs/api/crud-hooks.ts
    symbol: makeCreateMutation
    note: "reuse unchanged"
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "loads doctors and services from the clinic proxy routes"
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "requests availability only when doctor and date are chosen"
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "posts a booking to the appointments proxy route"
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "cancels through the token cancel route outside the v1 prefix"
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "reassigns an appointment and refreshes the schedule"
binding_refs: [OQ-CN-1, OQ-AR-1]
---

# Unit U-009 — Add the appointments repository and TanStack Query hooks

## Goal

Create the browser data-access layer for every clinic call — one repository of `apiClient` functions and the TanStack Query hooks that wrap them with query keys, snackbars and invalidation.

## Context (read first)

The house data flow is page → hook → repository → `apiClient` → `/api/v1` proxy (CLAUDE.md §Data flow, constitution C-001 / C-003): repositories return the raw envelope and hooks own snackbars and invalidation through `createQueryKeys` and `make{Create,Update,Delete}Mutation`. The paths match the BFF routes of U-005, U-006 and U-007 (the cancel route lives outside `/v1` because PRD §Clinic.3 names `/api/appointments/[id]/cancel`). The booking wizard (U-013), reschedule form (U-014), schedule views (U-016, U-019) and dialogs (U-017, U-018) consume these hooks.

## Anchors

- src/features/users/repositories/user.repository.ts:1-19 — repository functions over `apiClient` with `/v1/...` paths
- src/features/users/hooks/useUsers.ts:1-51 — query keys + `useQuery` + mutation factories
- src/libs/api/crud-hooks.ts:21-61 — `makeCreateMutation` / `makeUpdateMutation` contracts (snackbar + invalidate)
- src/libs/api/client.ts:10-18 — `apiClient` base `/api`, throws on non-OK
- src/test/utils.tsx:36 — `renderWithProviders`; tests override MSW handlers per case with `server.use`

## Claims

- C-U009-01 "createQueryKeys is the query-key factory" — expect: src/libs/query-keys/index.ts:createQueryKeys
- C-U009-02 "makeCreateMutation wires snackbar and invalidation" — expect: src/libs/api/crud-hooks.ts:makeCreateMutation
- C-U009-03 "renderWithProviders is the component test helper" — expect: src/test/utils.tsx:renderWithProviders
- C-U009-04 "apiClient is the browser fetcher" — expect: src/libs/api/client.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/test/handlers.ts
  Source: src/test/handlers.ts:14-21 (tests override default handlers per case with server.use)
- file src/features/appointments/repositories/appointment.repository.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep repositories free of enqueueSnackbar and return the raw envelope (constitution C-003)
  Source: constitution.md §C C-003
- MUST build query keys with createQueryKeys and CRUD mutations with the crud-hooks factories where they fit (constitution C-003)
  Source: constitution.md §C C-003
- MUST call only apiClient from this client-side layer (constitution C-001)
  Source: constitution.md §C C-001

## Implementation steps

1. Create `appointment.repository.ts` with `fetchDoctors`, `fetchServices`, `fetchAvailability({ doctorId, date })` (GET `/v1/appointments/availability` with params), `createAppointment(payload)` (POST `/v1/appointments`), `fetchAppointmentByToken({ token })` (GET `/v1/appointments/token/${encodeURIComponent(token)}`), `rescheduleAppointment({ token, startTime })` (PUT same path), `cancelAppointment({ id, token })` (POST `/appointments/${id}/cancel` — outside `/v1`, resolving to `/api/appointments/...`), `fetchSchedule({ from, to, doctorId? })` (GET `/v1/appointments/schedule`) and `reassignAppointment({ id, doctorId })` (POST `/v1/appointments/${id}/reassign`), typed with the U-001 types and following the users repository anchor.
2. Create `hooks/useAppointments/index.ts` (`'use client'`) exporting `appointmentKeys`, `doctorKeys`, `serviceKeys` (from `createQueryKeys`), `useDoctors`, `useServices`, `useAvailability(doctorId, date)` (`enabled` only when both are set; key `[...appointmentKeys.all(), 'availability', doctorId, date]`), `useCreateAppointment` (`makeCreateMutation`, success message `Appointment booked`, invalidating `appointmentKeys.all()` so availability refetches), `useAppointmentByToken(token)`, `useRescheduleAppointment`, `useCancelAppointment`, `useSchedule(params)` and `useReassignAppointment` (invalidating the schedule queries); mutations not covered by the factories use `useMutation` with the same snackbar/invalidate pattern as `crud-hooks.ts`.
3. Write `index.test.tsx` rendering small probe components through `renderWithProviders`, overriding MSW handlers with `server.use` for `/api/v1/doctors`, `/api/v1/services`, `/api/v1/appointments/availability`, `/api/v1/appointments`, `/api/appointments/:id/cancel`, `/api/v1/appointments/:id/reassign` and `/api/v1/appointments/schedule`, with the five tests named exactly as the acceptance_test `expects` strings; the adversarial cases must assert no availability request is sent while `doctorId` or `date` is empty and that the schedule is refetched after a successful reassign.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-AR-1 — upstream response shapes follow the recommended contract; the envelope `data` is typed with the U-001 types.

## Out of scope

- The BFF routes themselves — U-005, U-006, U-007
- Any UI — U-012 onwards
