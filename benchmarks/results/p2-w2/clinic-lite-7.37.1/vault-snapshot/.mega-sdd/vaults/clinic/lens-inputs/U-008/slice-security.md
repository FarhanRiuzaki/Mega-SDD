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
