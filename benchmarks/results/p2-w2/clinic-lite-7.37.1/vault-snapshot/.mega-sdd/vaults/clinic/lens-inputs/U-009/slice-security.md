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
