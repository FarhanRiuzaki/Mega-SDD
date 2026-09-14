---
id: U-018
title: Build the walk-in appointment dialog with emergency override
context_source: context.md#F-S-002
prd_source: [PRD/prd-clinic.md:178, PRD/prd-clinic.md:179]
task_type: create
grounding_confidence: LOW
risk: high
module: M-staff
depends_on: [U-001, U-009, U-012]
target_files:
  - path: src/features/appointments/components/WalkInDialog/index.tsx
    operation: create
  - path: src/features/appointments/components/WalkInDialog/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "creates a walk-in appointment with the staff channel"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "allows a time outside the slot grid only with the emergency override"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "validates patient details before submitting"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "keeps the dialog open and shows an error message when appointment creation fails"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "does not call the create appointment endpoint when patient details are invalid"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "resets the selected time when the emergency override switch is turned off"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-001]
---

# Unit U-018 — Build the walk-in appointment dialog with emergency override

## Anchors


- src/features/users/components/UserFormDialog.tsx — MUI dialog + react-hook-form + zodResolver pattern
- src/@core/components/mui/TextField.tsx — `CustomTextField` for labelled inputs

## Claims


- C-U018-01 "the project wires dialog forms with react-hook-form" — expect: src/features/users/components/UserFormDialog.tsx — must-exist
- C-U018-02 "the slot picker exists" — expect: src/features/appointments/components/SlotPicker/index.tsx — must-exist
- C-U018-03 "the booking schema module exists" — expect: src/features/appointments/schemas/booking/index.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/components/WalkInDialog/index.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST send bookingChannel staff for every appointment created from this dialog (constitution C-006)
  Source: constitution.md §C C-006
- MUST offer a free time outside the slot grid only while the emergency override switch is on (source: PRD §Clinic.1 F-S-002 step 4)
  Source: PRD §Clinic.1 F-S-002 step 4
- MUST validate patient details with walkInSchema before submitting and show errors as text (constitution B-001)
  Source: constitution.md §B B-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `keeps the dialog open and shows an error message when appointment creation fails`: with a failing POST /api/v1/appointments, onClose is not called and the error text is rendered in the dialog.
- Adversarial addition — `does not call the create appointment endpoint when patient details are invalid`: submitting with a blank or invalid name, email or reason sends no request to the appointments route.
- Adversarial addition — `resets the selected time when the emergency override switch is turned off`: after entering an off-grid time with override on, switching it off clears the time so it cannot be submitted with override false.
- OQ-CLINIC-001 (P1, open): no regulation-specific behavior is invented.



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
