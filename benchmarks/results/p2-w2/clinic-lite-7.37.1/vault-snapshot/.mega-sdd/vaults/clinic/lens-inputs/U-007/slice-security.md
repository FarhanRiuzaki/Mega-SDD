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

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `rejects an invalid reassign payload with 400 without calling upstream`: a body failing reassignPayloadSchema answers 400 and apiServer.post is not called.
- Adversarial addition — `rejects an unauthenticated reassign request with 401`: with getServerSession resolving null the reassign route answers 401 (not 403 or 500) and upstream is not called.
- Adversarial addition — `treats a user with both doctor and receptionist roles as a receptionist`: a session with roles doctor and receptionist forwards an explicit doctorId query unchanged.
- TBD: OQ-AR-1 — the upstream also enforces data scope with the bearer token; this route is the defense-in-depth layer.



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
