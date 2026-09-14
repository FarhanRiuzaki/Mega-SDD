---
id: U-019
title: Build the reception board page with all doctors' schedules
context_source: context.md#F-S-002
prd_source: [PRD/prd-clinic.md:175, PRD/prd-clinic.md:176, PRD/prd-clinic.md:194, PRD/prd-clinic.md:108, PRD/prd-clinic.md:209]
task_type: create
grounding_confidence: LOW
risk: medium
module: M-staff
depends_on: [U-002, U-003, U-009, U-017, U-018]
target_files:
  - path: src/features/appointments/components/ReceptionBoard/index.tsx
    operation: create
  - path: src/features/appointments/components/ReceptionBoard/columns.tsx
    operation: create
  - path: src/features/appointments/components/ReceptionBoard/index.test.tsx
    operation: create
  - path: src/app/(dashboard)/staff/reception/page.tsx
    operation: create
existing_interfaces:
  - file: src/components/table/BaseTable.tsx
    symbol: BaseTable
    note: "reuse unchanged for the reception board data table"
  - file: src/components/rbac/ProtectedRoute.tsx
    symbol: ProtectedRoute
    note: "reuse unchanged with require.roles"
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReceptionBoard/index.test.tsx --reporter=verbose"
    expects: "lists every doctor appointment for the selected date"
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReceptionBoard/index.test.tsx --reporter=verbose"
    expects: "renders one schedule row per doctor"
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReceptionBoard/index.test.tsx --reporter=verbose"
    expects: "opens the reassign dialog for a row"
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReceptionBoard/index.test.tsx --reporter=verbose"
    expects: "opens the walk-in dialog from the board"
  - type: manual
    desc: "Sign in as a receptionist, open /staff/reception: every doctor's appointments for the chosen date appear in the grid and the table; a doctor-only user gets the Access Denied panel."
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-AR-2, OQ-CLINIC-006]
---

# Unit U-019 — Build the reception board page with all doctors' schedules

## Anchors


- src/features/users/components/table/index.tsx:1-128 — `BaseTable` usage with `customActions`, row actions and dialogs driven by state
- src/features/users/components/table/columns.tsx — column definitions in a sibling `columns.tsx`
- src/app/(dashboard)/users/page.tsx:1-17 — page wrapped in `ProtectedRoute`

## Claims


- C-U019-01 "BaseTable is the house data table" — expect: src/components/table/BaseTable.tsx:BaseTable
- C-U019-02 "ProtectedRoute supports role requirements" — expect: src/components/rbac/ProtectedRoute.tsx:ProtectedRoute
- C-U019-03 "the reassign dialog exists" — expect: src/features/appointments/components/ReassignDialog/index.tsx — must-exist
- C-U019-04 "the walk-in dialog exists" — expect: src/features/appointments/components/WalkInDialog/index.tsx — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/components/table/BaseTable.tsx
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- DO NOT modify src/data/navigation/verticalMenuData.tsx
  Source: context.md OQ-AR-2 (no menu entry until permission names are decided)
- DO NOT modify src/data/navigation/horizontalMenuData.tsx
  Source: context.md OQ-AR-2 (no menu entry until permission names are decided)
- file src/app/(dashboard)/staff/reception/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST guard the page with ProtectedRoute requiring the receptionist role (constitution B-005)
  Source: constitution.md §B B-005
- MUST render status with AppointmentStatusChip and the booking channel with BOOKING_CHANNEL_LABELS (constitution F-002, A-005)
  Source: constitution.md §F F-002, §A A-005
- MUST keep the grid and the table keyboard-reachable with labelled controls (constitution F-001)
  Source: constitution.md §F F-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-AR-2 — no navigation menu entry until permission names are decided; reach the page by URL.



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
