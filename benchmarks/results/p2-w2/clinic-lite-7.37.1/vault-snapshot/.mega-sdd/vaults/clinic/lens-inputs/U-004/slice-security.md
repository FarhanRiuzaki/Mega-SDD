---
id: U-004
title: Make teal-700 the default primary color
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:115, PRD/prd-clinic.md:116]
task_type: extend
grounding_confidence: LOW
risk: low
module: M-platform
depends_on: []
target_files:
  - path: src/configs/primaryColorConfig.ts
    operation: delete
  - path: src/configs/primaryColorConfig/index.ts
    operation: create
  - path: src/configs/primaryColorConfig/index.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose"
    expects: "uses teal-700 as the default primary color"
  - type: test
    command: "pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose"
    expects: "keeps white-on-primary contrast at or above 4.5 to 1"
  - type: test
    command: "pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose"
    expects: "never uses a raw brand hue as a main color"
binding_refs: [OQ-CN-1]
---

# Unit U-004 — Make teal-700 the default primary color

## Anchors


- src/configs/primaryColorConfig.ts:1-42 — current preset list; the third entry (`primary-3`, orange `#FFAB1D`) is the default
- src/@core/contexts/settingsContext.tsx:63 — `primaryColor: primaryColorConfig[2].main` (read-only reference; vendored)
- src/components/theme/index.tsx:68-79 — theme derives light/dark from `settings.primaryColor` (read-only reference; vendored)

## Claims


- C-U004-01 "the primary preset module exists as a flat file today" — expect: src/configs/primaryColorConfig.ts — must-exist
- C-U004-02 "the vendored settings context reads the default from preset index 2" — expect: src/@core/contexts/settingsContext.tsx — must-exist
- C-U004-03 "PrimaryColorConfig is the exported preset type" — expect: src/configs/primaryColorConfig.ts:PrimaryColorConfig

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/@core/contexts/settingsContext.tsx
  Source: CLAUDE.md:41 (template internals are vendored) — constitution.md §C C-004
- DO NOT modify src/components/theme/index.tsx
  Source: CLAUDE.md:41 (template internals are vendored) — constitution.md §C C-004
- file src/configs/primaryColorConfig/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep the `PrimaryColorConfig` type export and the default export array shape so existing imports compile (constitution C-004)
  Source: constitution.md §C C-004
- MUST use teal-700 #0E7490 as the default primary and never raw #0891B2 or #16A34A as a main color (constitution F-003)
  Source: constitution.md §F F-003

## Migration notes


- **REMOVE**: the flat file `src/configs/primaryColorConfig.ts` (its content moves into the folder module) and the orange values of preset `primary-3`.
- **KEEP**: the `PrimaryColorConfig` type, presets `primary-1`, `primary-2`, `primary-4`, `primary-5`, the array order and the default export.
- **ADD**: `src/configs/primaryColorConfig/index.ts` with preset `primary-3` = teal-700, and `index.test.ts`.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- Browsers holding an old settings cookie keep their saved color until the customizer is reset (existing behavior, themeConfig.ts header comment).



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
