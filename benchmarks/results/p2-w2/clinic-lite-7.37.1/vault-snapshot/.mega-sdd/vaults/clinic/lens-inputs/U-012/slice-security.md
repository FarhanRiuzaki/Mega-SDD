---
id: U-012
title: Build the accessible date and slot picker component
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:147, PRD/prd-clinic.md:148, PRD/prd-clinic.md:109, PRD/prd-clinic.md:128]
task_type: create
grounding_confidence: LOW
risk: low
module: M-patient-booking
depends_on: [U-002]
target_files:
  - path: src/features/appointments/components/SlotPicker/index.tsx
    operation: create
  - path: src/features/appointments/components/SlotPicker/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/SlotPicker/index.test.tsx --reporter=verbose"
    expects: "shows only free slots for the chosen date"
  - type: test
    command: "pnpm test:run src/features/appointments/components/SlotPicker/index.test.tsx --reporter=verbose"
    expects: "announces the number of available slots in a live region"
  - type: test
    command: "pnpm test:run src/features/appointments/components/SlotPicker/index.test.tsx --reporter=verbose"
    expects: "flags a weekend date with an in-text error"
  - type: test
    command: "pnpm test:run src/features/appointments/components/SlotPicker/index.test.tsx --reporter=verbose"
    expects: "selects a slot by keyboard"
  - type: manual
    desc: "At 375px width, tab through the date field and the slot buttons: each slot is at least 44px tall, focus is visible, and the live region reads the slot count after the date changes."
binding_refs: [OQ-CN-1, OQ-CN-3, OQ-DM-1, OQ-CLINIC-006]
---

# Unit U-012 — Build the accessible date and slot picker component

## Anchors


- src/@core/components/mui/TextField.tsx — `CustomTextField`, the project's labelled text field
- src/components/table/BaseTable.tsx:1-30 — client component conventions and MUI import style

## Claims


- C-U012-01 "CustomTextField is the project's labelled input" — expect: src/@core/components/mui/TextField.tsx — must-exist
- C-U012-02 "the slot rules module exists" — expect: src/features/appointments/utils/slots/index.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/components/SlotPicker/index.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST take every slot decision from the U-002 helpers instead of re-implementing hours, lunch or weekend rules (source: PRD §5 BR-001)
  Source: PRD §5 BR-001
- MUST hide taken slots rather than show them disabled or labelled, so no other patient's booking is revealed (constitution B-006)
  Source: constitution.md §B B-006
- MUST label the date input, show errors as text, announce availability in an aria-live polite status region and keep every slot button at least 44px tall (constitution F-001)
  Source: constitution.md §F F-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-3 — `today` / `now` are provided by the caller.



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
