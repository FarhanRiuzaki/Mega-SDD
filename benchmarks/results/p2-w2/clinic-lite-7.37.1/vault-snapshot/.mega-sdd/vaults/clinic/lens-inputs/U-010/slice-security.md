---
id: U-010
title: Open the patient pages and staff login in the route proxy
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:53, PRD/prd-clinic.md:190, PRD/prd-clinic.md:192, PRD/prd-clinic.md:195]
task_type: extend
grounding_confidence: LOW
risk: high
module: M-platform
depends_on: []
target_files:
  - path: src/proxy.ts
    operation: modify
  - path: src/proxy.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+4 gaps merged)
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "lets an anonymous visitor open the booking page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "lets an anonymous visitor open a reschedule link"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "lets an anonymous visitor open the staff login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "still redirects an anonymous visitor on a staff page to the login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "bounces a signed-in user from the staff login page to home"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "redirects an anonymous visitor on reschedule without a token or a substring collision to the login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "redirects an anonymous visitor on a book prefixed but unrelated path to the login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "still bounces a signed-in user from the login page to home"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "still clears cookies and redirects to login on a refresh error even for the booking page"
binding_refs: [OQ-CN-1]
---

# Unit U-010 — Open the patient pages and staff login in the route proxy

## Anchors


- src/proxy.ts:7-37 — `proxy(request)` with `publicRoutes`, the RefreshTokenError branch, the auth-page bounce and the matcher config

## Claims


- C-U010-01 "the Next.js 16 proxy guards every page" — expect: src/proxy.ts — must-exist
- C-U010-02 "no proxy test exists yet" — expect: src/proxy.test.ts — must-not-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/auth.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- MUST keep the exported `proxy(request: Request)` function name and the exported `config.matcher` value unchanged (source: CLAUDE.md §Auth & routing)
  Source: CLAUDE.md §Auth & routing
- MUST keep the RefreshTokenError branch clearing both session cookies and redirecting to /login before any other rule
  Source: src/proxy.ts:14-22 — CLAUDE.md §Auth & routing
- MUST match the reschedule route only as the /reschedule/ prefix followed by a token segment, never by substring (constitution B-002)
  Source: constitution.md §B B-002
- MUST NOT make any /staff path other than /staff/login public (constitution B-005)
  Source: constitution.md §B B-005

## Migration notes


- **REMOVE**: the single `publicRoutes` list and its `includes(pathname)` check.
- **KEEP**: the RefreshTokenError cookie-clearing redirect, the `/home` bounce for signed-in users on auth pages, the anonymous → `/login` redirect, the `export const config` matcher.
- **ADD**: `/staff/login` as an auth page; `/book` and `/reschedule/<token>` as always-public patient pages; `src/proxy.test.ts`.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `redirects an anonymous visitor on reschedule without a token or a substring collision to the login page`: anonymous GET /reschedule and GET /rescheduled both redirect to /login.
- Adversarial addition — `redirects an anonymous visitor on a book prefixed but unrelated path to the login page`: anonymous GET /book/admin (a path sharing the /book prefix) still redirects to /login.
- Adversarial addition — `still bounces a signed-in user from the login page to home`: a signed-in user on /login is still redirected to /home after the refactor.
- Adversarial addition — `still clears cookies and redirects to login on a refresh error even for the booking page`: a RefreshTokenError session on /book is redirected to /login with both session cookies deleted.



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
