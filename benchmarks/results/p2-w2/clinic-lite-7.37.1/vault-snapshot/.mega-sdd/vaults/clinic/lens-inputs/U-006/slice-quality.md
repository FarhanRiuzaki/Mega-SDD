---
id: U-006
title: Add the token-authorized cancel and reschedule BFF routes
context_source: context.md#F-U-002
prd_source: [PRD/prd-clinic.md:191, PRD/prd-clinic.md:192, PRD/prd-clinic.md:155, PRD/prd-clinic.md:167, PRD/prd-clinic.md:207, PRD/prd-clinic.md:210]
task_type: create
grounding_confidence: LOW
risk: high
module: M-clinic-bff
depends_on: [U-001]
target_files:
  - path: src/app/api/appointments/[id]/cancel/route.ts
    operation: create
  - path: src/app/api/appointments/[id]/cancel/route.test.ts
    operation: create
  - path: src/app/api/v1/appointments/token/[token]/route.ts
    operation: create
  - path: src/app/api/v1/appointments/token/[token]/route.test.ts
    operation: create
existing_interfaces:
  - file: src/libs/api/route-handler.ts
    symbol: proxyGet
    note: "reuse unchanged for loading an appointment by token"
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "cancels through upstream when a token is posted"
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "rejects a cancel request without a token with 400"
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "exposes no GET handler so an email link cannot cancel by itself"
  - type: test
    command: "pnpm test:run appointments/token --reporter=verbose"
    expects: "loads the appointment for a token from upstream"
  - type: test
    command: "pnpm test:run appointments/token --reporter=verbose"
    expects: "rejects a reschedule payload without a valid start time with 400"
  - type: test
    command: "pnpm test:run appointments/token --reporter=verbose"
    expects: "reschedules through upstream when a valid start time is provided"
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "never echoes the token back in the response body"
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "does not call upstream when the cancel payload fails validation"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-FL-1, OQ-CLINIC-001, OQ-CLINIC-003]
---

# Unit U-006 — Add the token-authorized cancel and reschedule BFF routes

## Goal


Create the PRD §Clinic.3 cancel Route Handler `POST /api/appointments/[id]/cancel` (+ token) and the `/api/v1/appointments/token/[token]` route that loads an appointment by token (GET) and reschedules it (PUT), validating input before forwarding to the upstream API.

## Anchors


- src/libs/api/route-handler.ts:19-50 — `respond()` mapping and `proxyGet` with dynamic params (`({ token }) => ...`)
- src/app/api/v1/users/[id]/route.ts:1-5 — dynamic-segment proxy route shape
- src/libs/api/server.ts:9-27 — `apiServer.post` / `apiServer.put` return the envelope

## Claims


- C-U006-01 "proxyGet supports dynamic route params" — expect: src/libs/api/route-handler.ts:proxyGet
- C-U006-02 "dynamic-segment proxy routes already exist" — expect: src/app/api/v1/users/[id]/route.ts — must-exist
- C-U006-03 "no cancel route exists yet" — expect: src/app/api/appointments — must-not-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/api/route-handler.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file src/app/api/appointments/[id]/cancel/route.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST export only POST from the cancel route so that a GET request cannot cancel an appointment (source: PRD §Clinic.1 F-U-002 step 2)
  Source: PRD §Clinic.1 F-U-002 step 2
- MUST parse the cancel body with cancelPayloadSchema and the reschedule body with reschedulePayloadSchema before calling upstream, answering 400 on failure (constitution B-001)
  Source: constitution.md §B B-001
- MUST forward the token only to the upstream API and never echo it in a response or log (constitution B-002)
  Source: constitution.md §B B-002

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `reschedules through upstream when a valid start time is provided`: a valid PUT calls apiServer.put with /v1/appointments/token/{token} and a body of exactly { startTime } and returns the upstream envelope.
- Adversarial addition — `never echoes the token back in the response body`: for both the success and the 400 case the serialized response body does not contain the raw token.
- Adversarial addition — `does not call upstream when the cancel payload fails validation`: apiServer.post is never invoked when the body is missing, empty or fails cancelPayloadSchema.
- TBD: OQ-FL-1 — the page where the patient confirms a cancellation is not built; only the API exists.
- TBD: OQ-CLINIC-003 — no cancellation/reschedule window is enforced here; the upstream decides.
- OQ-CLINIC-001 (P1, open): no regulation-specific handling is invented; nothing is persisted or logged in this tier.

## Out of scope


- The reschedule page — U-014
- Client-side calls — U-009
