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

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-3 — "today" and "now" are passed in by the caller; the timezone that produces them is not decided here.
- TBD: OQ-DM-1 — only booked start times are removed.



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
