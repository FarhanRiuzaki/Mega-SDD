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

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-AR-1 — upstream response shapes follow the recommended contract; the envelope `data` is typed with the U-001 types.

## Out of scope


- The BFF routes themselves — U-005, U-006, U-007
- Any UI — U-012 onwards
