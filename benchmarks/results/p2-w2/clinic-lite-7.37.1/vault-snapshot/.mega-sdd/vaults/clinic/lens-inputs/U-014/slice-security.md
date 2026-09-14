---
id: U-014
title: Build the token reschedule page
context_source: context.md#F-U-004
prd_source: [PRD/prd-clinic.md:165, PRD/prd-clinic.md:166, PRD/prd-clinic.md:167, PRD/prd-clinic.md:192, PRD/prd-clinic.md:210]
task_type: create
grounding_confidence: LOW
risk: high
module: M-patient-self-service
depends_on: [U-003, U-009, U-012]
target_files:
  - path: src/features/appointments/components/RescheduleForm/index.tsx
    operation: create
  - path: src/features/appointments/components/RescheduleForm/index.test.tsx
    operation: create
  - path: src/app/(patient)/reschedule/[token]/page.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "shows the current appointment for the token"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "reschedules to the chosen free slot"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "shows an error when the token is invalid"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "announces the rescheduled confirmation in a status region"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "sends only startTime in the reschedule request body"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "hides the slot picker for a cancelled appointment"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "never renders the token value anywhere on the page"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-001, OQ-CLINIC-003, OQ-FL-1]
---

# Unit U-014 — Build the token reschedule page

## Anchors


- src/features/users/components/UserDetailDialog.tsx — loading / error / detail rendering of a single record via a query hook
- src/app/(dashboard)/users/[id]/page.tsx — dynamic-segment page reading its param

## Claims


- C-U014-01 "detail rendering with a query hook exists in the users feature" — expect: src/features/users/components/UserDetailDialog.tsx — must-exist
- C-U014-02 "the slot picker exists" — expect: src/features/appointments/components/SlotPicker/index.tsx — must-exist
- C-U014-03 "the status chip exists" — expect: src/features/appointments/components/AppointmentStatusChip/index.tsx — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/app/(patient)/reschedule/[token]/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST authorize only through the token from the URL and never ask the patient to log in (constitution B-002)
  Source: constitution.md §B B-002
- MUST offer only free slots of the same doctor through SlotPicker and the availability hook (source: PRD §Clinic.1 F-U-004 step 2)
  Source: PRD §Clinic.1 F-U-004 step 2
- MUST announce the rescheduled confirmation in a role status aria-live region (constitution F-001)
  Source: constitution.md §F F-001
- MUST NOT render the token itself anywhere on the page (constitution B-002)
  Source: constitution.md §B B-002

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `sends only startTime in the reschedule request body`: the captured PUT body is exactly { startTime } with no token, doctorId or id.
- Adversarial addition — `hides the slot picker for a cancelled appointment`: for a cancelled appointment the slot picker and confirm button are absent and a not-changeable message is shown.
- Adversarial addition — `never renders the token value anywhere on the page`: on both the valid-token and the invalid-token path the raw token string never appears in the document.
- TBD: OQ-CLINIC-003 — no reschedule window is enforced client-side.
- TBD: OQ-FL-1 — this page offers no cancel action until the cancel confirmation screen is decided.
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
