---
id: U-005
title: Add the public booking BFF routes (doctors, services, availability, create appointment)
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:190, PRD/prd-clinic.md:150, PRD/prd-clinic.md:205, PRD/prd-clinic.md:178]
task_type: create
grounding_confidence: LOW
risk: high
module: M-clinic-bff
depends_on: [U-001]
target_files:
  - path: src/app/api/v1/doctors/route.ts
    operation: create
  - path: src/app/api/v1/services/route.ts
    operation: create
  - path: src/app/api/v1/appointments/availability/route.ts
    operation: create
  - path: src/app/api/v1/appointments/availability/route.test.ts
    operation: create
  - path: src/app/api/v1/appointments/route.ts
    operation: create
  - path: src/app/api/v1/appointments/route.test.ts
    operation: create
existing_interfaces:
  - file: src/libs/api/route-handler.ts
    symbol: proxyGet
    note: "reuse unchanged for the GET proxies"
  - file: src/libs/jwt-permission/index.ts
    symbol: JWTPermissionChecker
    note: "reuse unchanged for the receptionist role check"
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+4 gaps merged)
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "rejects an invalid booking payload with 400 before calling upstream"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "forwards a valid online booking to the upstream appointments endpoint"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "rejects a staff-channel or override booking without the receptionist role"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "allows a receptionist to create a staff-channel override booking"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/availability/route.test.ts --reporter=verbose"
    expects: "forwards doctorId and date to the upstream availability endpoint"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "returns 400 when the request body is not valid JSON"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "rejects a staff-channel booking from a completely unauthenticated caller with 403 not 500"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "rejects an online booking with override true from a non-receptionist"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "strips unknown fields from the payload before forwarding to upstream"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CN-4, OQ-CLINIC-001]
---

# Unit U-005 — Add the public booking BFF routes (doctors, services, availability, create appointment)

## Anchors


- src/libs/api/route-handler.ts:31-50 — `proxyGet` / `proxyPost` factories and the `respond()` envelope→status mapping at line 19 to mirror
- src/app/api/v1/users/route.ts:1-4 — one-line proxy route shape
- src/libs/api/server.ts:9-27 — `apiServer` returns a `{ success: false }` envelope instead of throwing
- src/libs/auth.ts:39 — `authOptions` for `getServerSession`
- src/libs/jwt-permission/index.ts:29 — `JWTPermissionChecker.hasRole` (case-insensitive)

## Claims


- C-U005-01 "proxyGet exists in the route-handler factory" — expect: src/libs/api/route-handler.ts:proxyGet
- C-U005-02 "JWTPermissionChecker implements hasRole" — expect: src/libs/jwt-permission/index.ts:JWTPermissionChecker
- C-U005-03 "apiServer is the server-side fetcher" — expect: src/libs/api/server.ts — must-exist
- C-U005-04 "next-auth options live in libs/auth.ts" — expect: src/libs/auth.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/api/route-handler.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file:src/app/api/v1/**/route.ts MUST follow kebab-case naming
  Source: framework pack next.md §Naming standards (route segment folders are kebab-case)
- MUST parse the POST body with createAppointmentPayloadSchema before any upstream call and answer 400 on failure (constitution B-001)
  Source: constitution.md §B B-001
- MUST reject bookingChannel staff or override true unless the session holds the receptionist role (constitution C-006)
  Source: constitution.md §C C-006
- MUST call apiServer, never apiClient, inside these Route Handlers (constitution C-001)
  Source: constitution.md §C C-001
- MUST NOT log request bodies or patient data (constitution F-004)
  Source: constitution.md §F F-004

## Anti-patterns


- Don't forward `Object.fromEntries`-style raw bodies — forward only the zod-parsed data (mass-assignment rail of the Next.js pack).
- Don't implement an in-memory rate limiter — the limit value and its owner are open (OQ-CN-4).

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `returns 400 when the request body is not valid JSON`: an unparsable body answers 400 (no thrown 500) and apiServer.post is never called.
- Adversarial addition — `rejects a staff-channel booking from a completely unauthenticated caller with 403 not 500`: with getServerSession resolving null, a staff-channel payload answers 403 without throwing and upstream is not called.
- Adversarial addition — `rejects an online booking with override true from a non-receptionist`: bookingChannel online plus override true without the receptionist role answers 403 — the override branch is gated on its own.
- Adversarial addition — `strips unknown fields from the payload before forwarding to upstream`: an extra client field (for example status) is absent from the body apiServer.post receives — only the zod-parsed shape is forwarded.
- TBD: OQ-CN-4 — rate limiting of the public booking surface is not implemented until its limit and owner are decided.
- TBD: OQ-AR-1 — upstream paths follow the recommended `/v1/...` mirror.
- OQ-CLINIC-001 (P1, open): regulation-specific handling of the patient data in the payload is not invented here; the handler only validates and forwards.



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
