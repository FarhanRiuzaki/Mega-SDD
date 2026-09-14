---
id: U-001
title: Define appointment domain types and zod payload schemas
context_source: context.md#Data-model
prd_source: [PRD/prd-clinic.md:202, PRD/prd-clinic.md:149, PRD/prd-clinic.md:95]
task_type: create
grounding_confidence: LOW
risk: low
module: M-clinic-core
depends_on: []
target_files:
  - path: src/features/appointments/types/index.ts
    operation: create
  - path: src/features/appointments/schemas/booking/index.ts
    operation: create
  - path: src/features/appointments/schemas/booking/index.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "accepts a complete booking"
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "rejects an invalid email with a readable message"
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "rejects whitespace-only name and reason"
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "covers every booking field in exactly one wizard step"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-DM-1, OQ-CN-3]
---

# Unit U-001 — Define appointment domain types and zod payload schemas

## Anchors


- src/features/users/types/index.ts:1-29 — `I`-prefixed entity interfaces and `T`-prefixed payload types; follow this naming
- src/features/users/schemas/user.schema.ts:1-30 — a schema file exports schema + inferred type + defaults
- src/libs/api/query-params/index.ts — a module that owns a test lives in `<name>/index.ts` + `<name>/index.test.ts`

## Claims


- C-U001-01 "feature types follow the users feature shape" — expect: src/features/users/types/index.ts — must-exist
- C-U001-02 "schema files export schema, inferred type and defaults" — expect: src/features/users/schemas/user.schema.ts — must-exist
- C-U001-03 "the folder-with-test module pattern is established" — expect: src/libs/api/query-params/index.test.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/types/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- file src/features/appointments/schemas/booking/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST export every schema together with its inferred type and its defaults (constitution A-004)
  Source: constitution.md §A A-004
- MUST keep the schema module and its test together in schemas/booking/ (constitution A-002)
  Source: constitution.md §A A-002
- MUST NOT add any payment or price-calculation field beyond the display-only service price (constitution C-005)
  Source: constitution.md §C C-005

## Anti-patterns


- Don't invent entity fields the PRD §Clinic.4 data model does not list; display-only embedded summaries (`patient`, `doctor`, `service`) on an appointment are allowed because staff views must show patient name and reason for visit (context.md#F-S-001).
- Don't encode timezone conversions — the timezone is still open (OQ-CN-3); keep `date` as `YYYY-MM-DD` and times as `HH:mm`.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-3 — date/time strings stay timezone-free until the clinic timezone is decided.
- TBD: OQ-DM-1 — nothing here assumes how long services occupy slots.



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
