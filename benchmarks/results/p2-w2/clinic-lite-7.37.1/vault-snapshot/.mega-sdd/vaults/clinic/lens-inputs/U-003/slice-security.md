---
id: U-003
title: Add appointment status labels and an accessible status chip
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:119, PRD/prd-clinic.md:211]
task_type: extend
grounding_confidence: LOW
risk: low
module: M-clinic-core
depends_on: [U-001]
target_files:
  - path: src/libs/label-maps.ts
    operation: modify
  - path: src/features/appointments/components/AppointmentStatusChip/index.tsx
    operation: create
  - path: src/features/appointments/components/AppointmentStatusChip/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"
    expects: "renders the text label for every status"
  - type: test
    command: "pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"
    expects: "renders a distinct icon for every status"
  - type: test
    command: "pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"
    expects: "keeps existing label maps unchanged"
binding_refs: [OQ-CN-1]
---

# Unit U-003 — Add appointment status labels and an accessible status chip

## Anchors


- src/libs/label-maps.ts:1-56 — existing `Record<string, string>` label maps; append the new maps in the same style
- src/features/users/components/table/index.tsx:1-20 — client component import ordering used in features

## Claims


- C-U003-01 "label-maps.ts is the central value→label module" — expect: src/libs/label-maps.ts — must-exist
- C-U003-02 "ACCOUNT_TYPE_LABELS is an existing export that must survive" — expect: src/libs/label-maps.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/components/AppointmentStatusChip/index.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep every existing export of src/libs/label-maps.ts unchanged (constitution A-005)
  Source: constitution.md §A A-005
- MUST NOT convey status by color alone — every status renders its text label and an icon (constitution F-002)
  Source: constitution.md §F F-002
- MUST keep the chip text contrast at or above 4.5:1 against its background (constitution F-001)
  Source: constitution.md §F F-001
- MUST use Iconify tabler classes for the icons (constitution A-006)
  Source: constitution.md §A A-006

## Migration notes


- **REMOVE**: nothing.
- **KEEP**: every existing export in `src/libs/label-maps.ts` (`TUJUAN_LABELS` … `ACCOUNT_TYPE_LABELS`) and the header comment, unchanged.
- **ADD**: `APPOINTMENT_STATUS_LABELS`, `BOOKING_CHANNEL_LABELS` (with the type import from `@/features/appointments/types`), and the new `AppointmentStatusChip` component folder.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).



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
