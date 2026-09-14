---
id: U-008
title: Add the CRON_SECRET-guarded reminder sweep trigger route
context_source: context.md#F-U-003
prd_source: [PRD/prd-clinic.md:196, PRD/prd-clinic.md:160, PRD/prd-clinic.md:208, PRD/prd-clinic.md:94]
task_type: extend
grounding_confidence: LOW
risk: high
module: M-clinic-bff
depends_on: []
target_files:
  - path: src/app/api/cron/reminders/route.ts
    operation: create
  - path: src/app/api/cron/reminders/route.test.ts
    operation: create
  - path: .env.example
    operation: modify
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "rejects a request without the cron secret with 401"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "rejects every request when CRON_SECRET is not configured"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "triggers the upstream reminder sweep when the secret matches"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "rejects a request with an incorrect secret value with 401"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "rejects a request whose bearer token has a different length than the secret with 401"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "triggers the upstream reminder sweep via GET when the secret matches"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-005, OQ-CN-2]
---

# Unit U-008 — Add the CRON_SECRET-guarded reminder sweep trigger route

## Goal

Create the PRD §Clinic.3 Route Handler `/api/cron/reminders` that authenticates the scheduler with `CRON_SECRET` and triggers the upstream DB-backed due-reminders sweep, and document `CRON_SECRET` in `.env.example`.

## Context (read first)

F-U-003 and AC-004 require a DB-backed sweep that sends each reminder 24h ± 5 min before `start_time` exactly once (never per-appointment in-memory timers — constitution D-001), and PRD §Clinic.3 protects the trigger with `CRON_SECRET` (constitution B-004). Per the OQ-AR-1 recommendation the upstream API owns the sweep, the `reminder_sent` flag and the email, so this route authenticates the caller and forwards one sweep request. The OQ-CLINIC-005 recommendation (self-hosted, external scheduler) and Vercel Cron both call the same URL with `Authorization: Bearer <CRON_SECRET>`, so the handler answers GET and POST.

## Anchors

- src/libs/api/route-handler.ts:19-21 — `respond()` envelope→status mapping to mirror
- src/libs/api/server.ts:9-27 — `apiServer.post` returns an envelope
- .env.example:1-28 — env documentation style (section banners, comments, empty secret values)

## Claims

- C-U008-01 ".env.example documents environment variables" — expect: .env.example — must-exist
- C-U008-02 "no cron route exists yet" — expect: src/app/api/cron — must-not-exist
- C-U008-03 "apiServer is the server-side fetcher" — expect: src/libs/api/server.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/app/api/cron/reminders/route.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST reject every request with 401 when CRON_SECRET is unset or the Authorization header does not equal Bearer followed by CRON_SECRET (constitution B-004)
  Source: constitution.md §B B-004
- MUST compare the secret with a constant-time comparison from node:crypto (constitution B-003)
  Source: constitution.md §B B-003
- NEVER schedule reminders with timers inside this app — the route only triggers the upstream sweep (constitution D-001)
  Source: constitution.md §D D-001
- MUST add CRON_SECRET to .env.example with an empty value and never commit a real secret (constitution B-003)
  Source: constitution.md §B B-003

## Implementation steps

1. Create `src/app/api/cron/reminders/route.ts` with one `handler(req)` exported as both `GET` and `POST`: read `process.env.CRON_SECRET` at request time, answer a 401 envelope when it is missing/empty or when the `authorization` header is not exactly `Bearer <secret>`, comparing equal-length buffers with `crypto.timingSafeEqual` (a length mismatch is a 401 without comparing).
2. When authorized, call `apiServer.post('/v1/reminders/sweep', {})` and return its envelope with the same success→200 / failure→4xx mapping as `respond()` in the route-handler anchor; never log the header or the secret.
3. Append a `# Reminder cron` banner block to `.env.example` with a comment explaining that the scheduler (external cron or Vercel Cron) must send `Authorization: Bearer <CRON_SECRET>` and a line `CRON_SECRET=` (generate per environment, e.g. `openssl rand -base64 32`), then write `route.test.ts` (mocking `@/libs/api/server`, setting and unsetting `process.env.CRON_SECRET` per test) with every test named exactly as the acceptance_test `expects` strings (see Acceptance criteria for the adversarial additions), asserting the upstream mock is not called on any 401.

## Migration notes

- **REMOVE**: nothing.
- **KEEP**: every existing variable, comment and banner in `.env.example`.
- **ADD**: a reminder-cron section with `CRON_SECRET=` in `.env.example`; the new route and its test.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `rejects a request with an incorrect secret value with 401`: a well-formed Bearer header with the wrong value answers 401 and the sweep is not triggered.
- Adversarial addition — `rejects a request whose bearer token has a different length than the secret with 401`: a token of a different length than CRON_SECRET answers 401 without throwing from timingSafeEqual.
- Adversarial addition — `triggers the upstream reminder sweep via GET when the secret matches`: the GET export with the correct secret calls apiServer.post('/v1/reminders/sweep', {}) exactly like POST.
- TBD: OQ-AR-1 — the 24h ± 5 min window, `reminder_sent` idempotency and the email are upstream responsibilities.
- TBD: OQ-CLINIC-005 — which scheduler calls this route is a deployment decision; the route is the same for both options.
- TBD: OQ-CN-2 — delivery within 5 minutes (NFR-003) is not measurable in this tier.

## Out of scope

- Scheduler configuration (vercel.json or host cron)
- Email templates
