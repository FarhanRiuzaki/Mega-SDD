---
id: U-011
title: Add the branded patient shell layout
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:124, PRD/prd-clinic.md:128, PRD/prd-clinic.md:182]
task_type: create
grounding_confidence: LOW
risk: low
module: M-patient-booking
depends_on: []
target_files:
  - path: src/app/(patient)/layout.tsx
    operation: create
  - path: src/features/appointments/components/PatientShell/index.tsx
    operation: create
  - path: src/features/appointments/components/PatientShell/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/PatientShell/index.test.tsx --reporter=verbose"
    expects: "renders header main and footer landmarks"
  - type: test
    command: "pnpm test:run src/features/appointments/components/PatientShell/index.test.tsx --reporter=verbose"
    expects: "links the header navigation to the booking page"
  - type: test
    command: "pnpm test:run src/features/appointments/components/PatientShell/index.test.tsx --reporter=verbose"
    expects: "shows the product name as the brand text"
  - type: manual
    desc: "Open /book at a 375px-wide viewport: header, content and footer fit without horizontal scrolling and every link is reachable by keyboard with a visible focus ring."
binding_refs: [OQ-CN-1, OQ-CN-5]
---

# Unit U-011 — Add the branded patient shell layout

## Anchors


- src/app/(blank-layout-pages)/layout.tsx:1-29 — async layout wrapping children in `Providers direction='ltr'`; mirror it
- src/components/Providers.tsx:18-40 — provider stack (NextAuth → TanStack Query → VerticalNav → Settings → Theme)

## Claims


- C-U011-01 "Providers wraps the MUI theme and query client" — expect: src/components/Providers.tsx — must-exist
- C-U011-02 "no patient route group exists yet" — expect: src/app/(patient) — must-not-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/components/Providers.tsx
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file src/app/(patient)/layout.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST render semantic header, main and footer landmarks with a keyboard-reachable navigation and visible focus (constitution F-001)
  Source: constitution.md §F F-001
- MUST NOT show a logo image or clinic name that the PRD does not provide (context.md OQ-CN-5)
  Source: context.md OQ-CN-5
- MUST stay usable at a 375px viewport without horizontal scrolling (source: PRD §Clinic.2 NFR-001)
  Source: PRD §Clinic.2 NFR-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-5 — replace the text brand with the clinic's name and logo once provided.



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
