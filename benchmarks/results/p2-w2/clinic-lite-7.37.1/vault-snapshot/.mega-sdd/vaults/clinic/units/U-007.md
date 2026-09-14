---
id: U-007
title: Add the role-scoped staff schedule and reassign BFF routes
context_source: context.md#F-S-001
prd_source: [PRD/prd-clinic.md:209, PRD/prd-clinic.md:171, PRD/prd-clinic.md:176, PRD/prd-clinic.md:177, PRD/prd-clinic.md:193, PRD/prd-clinic.md:194]
task_type: create
grounding_confidence: LOW
risk: high
module: M-clinic-bff
depends_on: [U-001]
target_files:
  - path: src/app/api/v1/appointments/schedule/route.ts
    operation: create
  - path: src/app/api/v1/appointments/schedule/route.test.ts
    operation: create
  - path: src/app/api/v1/appointments/[id]/reassign/route.ts
    operation: create
  - path: src/app/api/v1/appointments/[id]/reassign/route.test.ts
    operation: create
existing_interfaces:
  - file: src/libs/jwt-permission/index.ts
    symbol: JWTPermissionChecker
    note: "reuse unchanged for doctor / receptionist role checks"
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "forces the doctor id to the signed-in doctor"
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "passes the receptionist query through for all doctors"
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "rejects a schedule request from a user without a staff role with 403"
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "rejects an unauthenticated schedule request with 401"
  - type: test
    command: "pnpm test:run reassign/route --reporter=verbose"
    expects: "rejects a reassign request from a non-receptionist with 403"
  - type: test
    command: "pnpm test:run reassign/route --reporter=verbose"
    expects: "forwards a valid reassign to upstream"
  - type: test
    command: "pnpm test:run reassign/route --reporter=verbose"
    expects: "rejects an invalid reassign payload with 400 without calling upstream"
  - type: test
    command: "pnpm test:run reassign/route --reporter=verbose"
    expects: "rejects an unauthenticated reassign request with 401"
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "treats a user with both doctor and receptionist roles as a receptionist"
binding_refs: [OQ-CN-1, OQ-AR-1]
---

# Unit U-007 — Add the role-scoped staff schedule and reassign BFF routes

## Goal

Create `GET /api/v1/appointments/schedule`, which limits a doctor to their own appointments and lets a receptionist read every doctor's, and `POST /api/v1/appointments/[id]/reassign`, which only a receptionist may call.

## Context (read first)

AC-005 requires doctors to see only their own schedule and receptionists to see all, enforced on the server and not only in the UI (constitution B-005); the Next.js pack's security idioms name "protecting only the page UI while the API route stays open" as the classic bypass. Staff are the authenticated users of the existing next-auth credentials flow (OQ-CN-1 recommendation), so the doctor's id is `session.user.id` and roles come from `session.user.roles`. F-S-002 step 3 lets the receptionist reassign an appointment; the patient notification email is sent by the upstream API (OQ-AR-1).

## Anchors

- src/libs/api/route-handler.ts:19-41 — `respond()` mapping and the query-forwarding approach of `proxyGet`
- src/libs/api/server.ts:9-27 — `apiServer.get(path, { params })`
- src/libs/auth.ts:134-152 — session carries `user.id`, `user.roles`, `user.permissions`
- src/libs/jwt-permission/index.ts:29 — `JWTPermissionChecker.hasRole`

## Claims

- C-U007-01 "JWTPermissionChecker implements role checks" — expect: src/libs/jwt-permission/index.ts:JWTPermissionChecker
- C-U007-02 "the session exposes user id and roles" — expect: src/types/next-auth.d.ts — must-exist
- C-U007-03 "apiServer is the server-side fetcher" — expect: src/libs/api/server.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/auth.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file src/app/api/v1/appointments/schedule/route.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST answer 401 without a session and 403 for a session with neither the doctor nor the receptionist role (constitution B-005)
  Source: constitution.md §B B-005
- MUST overwrite any doctorId query parameter with session.user.id when the caller is a doctor without the receptionist role (constitution B-005)
  Source: constitution.md §B B-005
- MUST allow reassign only for the receptionist role and parse the body with reassignPayloadSchema before calling upstream (constitution B-001)
  Source: constitution.md §B B-001
- MUST call apiServer, never apiClient, inside these Route Handlers (constitution C-001)
  Source: constitution.md §C C-001

## Implementation steps

1. Create `src/app/api/v1/appointments/schedule/route.ts` exporting `GET(req)`: load `getServerSession(authOptions)` (none → 401 envelope), build a `JWTPermissionChecker` from the session, and if the caller has the `receptionist` role forward the incoming query (`from`, `to`, optional `doctorId`) unchanged; else if the caller has the `doctor` role forward the query with `doctorId` forced to `session.user.id`; otherwise answer 403 — then call `apiServer.get('/v1/appointments/schedule', { params })` and map the envelope like `respond()`.
2. Create `src/app/api/v1/appointments/[id]/reassign/route.ts` exporting `POST(req, { params })`: require a session with the `receptionist` role (401 / 403 otherwise), parse the body with `reassignPayloadSchema` (400 on failure), then call `apiServer.post(`/v1/appointments/${id}/reassign`, { doctorId })` and map the envelope.
3. Write both `route.test.ts` files (mocking `next-auth`'s `getServerSession` and `@/libs/api/server`) with every test named exactly as the acceptance_test `expects` strings (see Acceptance criteria for the adversarial additions); the adversarial cases must show a doctor passing `doctorId=someone-else` still gets their own id forwarded, a user holding both roles is treated as a receptionist, and the upstream mock is not called on 401/403/400.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `rejects an invalid reassign payload with 400 without calling upstream`: a body failing reassignPayloadSchema answers 400 and apiServer.post is not called.
- Adversarial addition — `rejects an unauthenticated reassign request with 401`: with getServerSession resolving null the reassign route answers 401 (not 403 or 500) and upstream is not called.
- Adversarial addition — `treats a user with both doctor and receptionist roles as a receptionist`: a session with roles doctor and receptionist forwards an explicit doctorId query unchanged.
- TBD: OQ-AR-1 — the upstream also enforces data scope with the bearer token; this route is the defense-in-depth layer.

## Out of scope

- Public booking routes — U-005
- Schedule UI — U-016, U-019
