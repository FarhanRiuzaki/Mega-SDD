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



---
# Lens context — constitution §B (Security baselines)
## §B. Security baselines

- B-001: Untrusted input (booking form, token requests, walk-in form) is validated with zod in the browser and again at the server boundary (source: PRD §Clinic.1 F-U-001 step 5; PRD §6.3 Validation)
- B-002: Patients never log in; cancel and reschedule are authorized only by the one-time signed email token (source: PRD §3; PRD §6.3 Auth)
- B-003: Server secrets (`NEXTAUTH_SECRET`, `CRON_SECRET`) are read only in server code, never prefixed `NEXT_PUBLIC_`, and real secrets are never committed (source: CLAUDE.md:35; PRD §Clinic.3 reminder cron)
- B-004: The reminder cron endpoint rejects every caller that does not present `CRON_SECRET` (source: PRD §Clinic.3)
- B-005: Staff surfaces require the matching role — `/staff/schedule` the `doctor` role, `/staff/reception` the `receptionist` role — and a doctor's schedule data is limited to that doctor's own appointments (source: PRD §Clinic.3; PRD §Clinic.5 AC-005)
- B-006: Patient-facing views never expose other patients' data — taken slots are hidden, not labelled (source: PRD §Clinic.1 F-U-001 step 4)


# Lens context — framework pack `next` §Security idioms
## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — `zod` parse at the server boundary: inside every Server Action (`formData` → schema) and Route Handler (`await request.json()` → schema); the bypass is trusting the payload shape because "the form only sends these fields" — client-side validation is not validation, both surfaces are directly callable.
- **SQL injection** — Prisma/Drizzle parameterize; `prisma.$queryRawUnsafe` or building SQL with string concatenation inside a tagged template reintroduces SQLi — use the tagged-template bindings (`sql\`… ${v}\``) or stay in the ORM query API.
- **XSS / output escaping** — React auto-escapes JSX output; `dangerouslySetInnerHTML` is the named bypass, valid only for server-sanitized HTML. Also watch user-controlled `href` values rendering `javascript:` URLs.
- **CSRF** — Server Actions have built-in origin checking (POST-only + Origin/Host match); Route Handlers do NOT — a cookie-authenticated handler needs `SameSite` cookies plus an explicit origin check. The bypass is a state-changing Route Handler (or a mutating GET) that trusts cookies with no origin/token check.
- **AuthN/AuthZ enforcement point** — `middleware.ts` for coarse redirects, but real authorization is the session check inside each Route Handler, Server Action, and data-access function; the classic bypass is protecting only the page UI (or only middleware) while the API route and server action underneath stay open to direct requests.
- **Password hashing** — `bcrypt`/`argon2` in server-only code (Server Actions, Route Handlers, `lib/` server modules); never imported into a `"use client"` file.
- **Mass assignment** — the zod schema's parsed output is the field allowlist; the bypass is `Object.fromEntries(formData)` or a raw body passed straight into `prisma.user.update({ data })`, letting an extra `role` field escalate privileges.
- **Secrets / config** — anything prefixed `NEXT_PUBLIC_` is compiled into the client bundle; server secrets stay unprefixed and are read only in server code. The bypass is importing a server-env module from a `"use client"` component, or "temporarily" renaming a secret to `NEXT_PUBLIC_` to make a build pass (pack hard rule).
- **File uploads** — handle uploads server-side only (Route Handler/Server Action) with size caps and a mimetype allowlist, stored outside `public/`; for `next/image` remote sources, constrain `images.remotePatterns` in `next.config` so the optimizer is not an open image proxy.
