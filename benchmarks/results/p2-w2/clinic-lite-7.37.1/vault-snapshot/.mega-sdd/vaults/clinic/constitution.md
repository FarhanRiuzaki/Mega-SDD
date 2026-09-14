# Project Constitution — Clinic Appointment System

**Status**: Active
**Version**: 1.0
**Last reviewed**: 2026-09-14
**Sign-off**: [Pending] — Engineering Lead / Product Owner

> Every clause cites its source. Clauses are injected into unit `## Hard rules` at plan time and validated at execute-bolts. A rule no source states is an Open Question in `context.md`, never a clause here.

---

## §A. Coding standards (Non-negotiable)

- A-001: Clinic domain code lives under `src/features/appointments/` using the house sub-folders `components/`, `hooks/`, `repositories/`, `schemas/`, `types/` (plus `utils/` for pure helpers) (source: CLAUDE.md §Feature-based layout)
- A-002: A module with its own test lives in a folder — `foo/index.ts` + `foo/index.test.ts`; files with no test stay flat (source: CLAUDE.md:25)
- A-003: Tests run on Vitest + React Testing Library + MSW; components render through `renderWithProviders` (source: CLAUDE.md §Stack & Commands; src/test/utils.tsx:36; PRD §6.3 Testing)
- A-004: Forms use react-hook-form + zod resolvers; each schema file exports the schema, its inferred type and its defaults (source: CLAUDE.md:105; PRD §8.1 Forms)
- A-005: Static `SelectOption` lists extend `src/libs/constants.ts` and value→label display maps extend `src/libs/label-maps.ts` instead of being redeclared locally (source: CLAUDE.md:105)
- A-006: Icons are Iconify classes `<i className='tabler-<name>' />`, not individually imported icon components (source: CLAUDE.md §Iconify)

## §B. Security baselines

- B-001: Untrusted input (booking form, token requests, walk-in form) is validated with zod in the browser and again at the server boundary (source: PRD §Clinic.1 F-U-001 step 5; PRD §6.3 Validation)
- B-002: Patients never log in; cancel and reschedule are authorized only by the one-time signed email token (source: PRD §3; PRD §6.3 Auth)
- B-003: Server secrets (`NEXTAUTH_SECRET`, `CRON_SECRET`) are read only in server code, never prefixed `NEXT_PUBLIC_`, and real secrets are never committed (source: CLAUDE.md:35; PRD §Clinic.3 reminder cron)
- B-004: The reminder cron endpoint rejects every caller that does not present `CRON_SECRET` (source: PRD §Clinic.3)
- B-005: Staff surfaces require the matching role — `/staff/schedule` the `doctor` role, `/staff/reception` the `receptionist` role — and a doctor's schedule data is limited to that doctor's own appointments (source: PRD §Clinic.3; PRD §Clinic.5 AC-005)
- B-006: Patient-facing views never expose other patients' data — taken slots are hidden, not labelled (source: PRD §Clinic.1 F-U-001 step 4)

## §C. Architecture invariants

- C-001: Browser code calls `apiClient` (same-origin `/api` proxy, no Authorization header); Route Handlers and Server Components call `apiServer`; the two are never mixed (source: CLAUDE.md:65; CLAUDE.md:134)
- C-002: `/api/v1/**` proxy routes are one-liners built with `proxyGet` / `proxyPost` / `proxyPut` / `proxyDelete`; a hand-written handler is allowed only when the route adds server-side logic such as session scoping or a secret check (source: CLAUDE.md §Next.js API routes are thin proxies; src/libs/api/route-handler.ts:31)
- C-003: Repositories return the raw response; hooks own `enqueueSnackbar` feedback and query invalidation, built from `createQueryKeys` and `make{Create,Update,Delete}Mutation` (source: CLAUDE.md:132; CLAUDE.md:68)
- C-004: Template internals (`src/@core`, `src/@layouts`, `src/@menu`, `src/components/{layout,theme}`) are vendored — extend through `src/components/*`, `src/features/*` and `src/configs/*` (source: CLAUDE.md:41)
- C-005: There are no payment code paths — service price is display-only (source: PRD §5 BR-005; PRD §7)
- C-006: Every appointment records `booking_channel` — `online` for patient bookings, `staff` for receptionist-created appointments (source: PRD §5 BR-006)

## §D. Anti-patterns

- D-001: NEVER schedule reminders with per-appointment in-memory timers — reminders come from a DB-backed, idempotent due-reminders sweep (source: PRD §6.3 Scheduled reminders; PRD §Clinic.5 AC-004)
- D-002: NEVER add SMS reminders, a multi-language UI, patient accounts, recurring appointments or patient medical records in v1 (source: PRD §7)

## §E. Performance constraints

- E-001: Appointment lookup completes in under 200ms at the median (source: PRD §6.2; PRD §Clinic.2 NFR-002)
- E-002: A reminder email is delivered within 5 minutes of its scheduled send time (source: PRD §6.2; PRD §Clinic.2 NFR-003)

## §F. Compliance

- F-001: Every page meets WCAG 2.2 AA — contrast ≥ 4.5:1 text / 3:1 UI, visible unobscured focus, targets ≥ 24×24 (44×44 touch), labelled inputs with in-text error identification, `role="status"` / `aria-live` for confirmations and slot updates, semantic landmarks, full keyboard reachability (source: PRD §6.1; PRD §8.4; PRD §Clinic.5 AC-007)
- F-002: Appointment status is never conveyed by color alone — text + icon + color (source: PRD §8.2; PRD §Clinic.5 AC-007)
- F-003: The primary color is teal-700 `#0E7490`; raw `#0891B2` / `#16A34A` are never used with white text (source: PRD §8.2)
- F-004: Patient personal data (name, email, phone, reason for visit) is handled per the applicable regional privacy regulation; until OQ-CLINIC-001 is answered no regulation-specific behavior is invented and no patient data is logged or persisted in this Next.js tier (source: PRD §6.1; context.md OQ-CLINIC-001)
