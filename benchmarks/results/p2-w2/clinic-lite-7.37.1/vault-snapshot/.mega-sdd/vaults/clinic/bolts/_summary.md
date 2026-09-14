# Bolts Summary — Klinik Sehat Bersama (clinic appointment booking)
**Generated**: 2026-09-14T15:34:27+00:00 (mega-sdd execute-bolts)
**Scope**: — (single-scope vault `clinic`)
**Batch**: --all --lite (lite lane: plan → execute-bolts)
**Duration**: 2026-09-14 18:25 → 22:31 +0700 wall-clock (~4h06m, including two session breaks and one network-drop re-dispatch); sum of implementer time 196m49s
**Avg AI confidence**: 0.81

## Status table
| Unit | Title | Status | Duration | Retries | Confidence | Halt type | Commit | Acceptance | Panel advisory (Important/Minor) |
|---|---|---|---|---|---|---|---|---|---|
| U-001 | Define appointment domain types and zod payload schemas | ✓ done | 10m13s | 1 | 0.8 | — | 5fd9c1b | pass | 3/4 |
| U-002 | Implement the bookable slot rules library | ✓ done | 7m12s | 1 | 0.6 | — | d0cc598, 121df3b | pass | 0/0 |
| U-003 | Add appointment status labels and an accessible status chip | ✓ done | 5m04s | 0 | 0.85 | — | b1166a2 | pass | 0/3 |
| U-004 | Make teal-700 the default primary color | ✓ done | 7m24s | 1 | 0.85 | — | ac7e9bd | pass | 1/2 |
| U-005 | Add the public booking BFF routes (doctors, services, availability, create appointment) | ✓ done | 8m45s | 1 | 0.7 | — | 8ff4087 | pass | 2/3 |
| U-006 | Add the token-authorized cancel and reschedule BFF routes | ✓ done | 9m40s | 0 | 0.85 | — | 99a8480 | pass | 1/0 |
| U-007 | Add the role-scoped staff schedule and reassign BFF routes | ✓ done | 6m44s | 0 | 0.75 | — | e122613 | pass | 4/2 |
| U-008 | Add the CRON_SECRET-guarded reminder sweep trigger route | ✓ done | 7m53s | 1 | 0.9 | — | e7e9ba9 | pass | 1/1 |
| U-009 | Add the appointments repository and TanStack Query hooks | ✓ done | 8m36s | 2 | 0.85 | — | 1705313 | pass | 1/3 |
| U-010 | Open the patient pages and staff login in the route proxy | ✓ done | 6m47s | 2 | 0.9 | — | 101b345 | pass | 1/0 |
| U-011 | Add the branded patient shell layout | ✓ done | 9m18s | 1 | 0.8 | — | 6bd8691 | pass | 1/4 |
| U-012 | Build the accessible date and slot picker component | ✓ done | 12m59s | 2 | 0.75 | — | a0aef4a | pass | 0/0 |
| U-013 | Build the patient booking wizard and the /book page | ✓ done | 25m20s | 3 | 0.8 | — | b1544b1 | pass | 4/7 |
| U-014 | Build the token reschedule page | ✓ done | 15m11s | 3 | 0.85 | — | b322b3c | pass | 2/8 |
| U-015 | Add the /staff/login page on the existing credentials login | ✓ done | 6m47s | 1 | 0.9 | — | c6c1b57 | pass | 1/2 |
| U-016 | Build the doctor schedule page with today and week views | ✓ done | 12m46s | 2 | 0.85 | — | f437fa0, 12262bd | pass | 3/3 |
| U-017 | Build the reassign appointment dialog | ✓ done | 7m16s | 0 | 0.8 | — | 472970e | pass | 0/0 |
| U-018 | Build the walk-in appointment dialog with emergency override | ✓ done | 14m32s | 2 | 0.85 | — | d1433ee, f1c0025, 6bf6e1d | pass | 2/4 |
| U-019 | Build the reception board page with all doctors' schedules | ✓ done | 14m13s | 1 | 0.8 | — | db10a45, def8f8c | pass | 2/4 |

**Totals:** 19/19 done, 0 halted, 0 quarantined, 24 implementer-reported retries. Every panel merge: `gate: clear`, spec lens `pass`, 0 open / 0 Critical findings.

## Halts open (0)
None. No unit is quarantined, so there is no **Karantina** table.

## Halts resolved in-run (fixed in code or spec, never by editing evidence)
- U-008, U-014, U-006 — `secret_in_code` (gitleaks `generic-api-key` on test-only token/secret literals). Fix: the test values are now generated per run (`crypto.randomUUID()`), and the offending commits were rewritten with plumbing (commit-tree + update-ref) so the literal count in branch history is 0. Every rewritten commit was re-gated with L0, postflight and acceptance (all green).
- U-015 — `acceptance_red` caused by the unit spec, not the code: the acceptance command passed `src/app/(blank-layout-pages)/…` unquoted, and `/bin/sh` fails with a syntax error before Vitest starts. Fix: the spec now uses the equivalent filter `staff/login/page`, with the same `expects` strings (commit `chore(sdd): make U-015 acceptance command shell-safe`). Acceptance was re-run and passes 2/2.
- U-008 — anchor range `.env.example:1-30` was a CONFLICT (the file has 28 lines). Resolved KEEP_CODE by correcting the anchor (`dcf69b5`).
- U-004, U-011, U-016, U-017 — implementers were killed mid-run by a local network drop (API ENOTFOUND). No partial commits or files were left. Preflight was recaptured and all four were re-dispatched.
- U-003, U-018, U-019, U-002, U-016 — the L0 formatter autofix left the tree dirty. It was committed as `style(U-XXX): apply L0 formatter autofix` with the Unit, SDD-PROVENANCE and SDD-Acceptance trailers, then L0 was re-run per commit.

## Hard rule violations across batch (by rule)
| Rule | Source | Violations | Resolution |
|---|---|---|---|
| — | — | 0 | Every `postflight.json` has `status: pass` (DO_NOT_ADD_DEPS / DO_NOT_MODIFY / FILE_PRESENCE_RULE). |

## Batch completion — full-suite gate (B2)
- `run-full-suite.sh`: **green** (runner `pnpm test`, exit 0) at HEAD `a9745a5c130b`.
- Out-of-band bypass guard (window `dcf69b5..HEAD`, excluding bolt commits): bypass_commits: [] — no commit touched a unit target file without SDD-PROVENANCE.
- Per-bolt drift check: clean for all 19 units. The vault has no LOCKED/INTENT/ARTIFACT tiers and no binding.md, and each bolt-report records `✓ Drift check: clean`. The batch-end detect-drift gate runs next.

## Self-assessment summary (uncertain decisions across batch)
- U-001: "createAppointmentPayloadSchema.startTime uses the same local `YYYY-MM-DDTHH:mm` format as reschedulePayloadSchema." — fallback: Swap the create payload's startTime to a plain non-empty string or split it into date + time fields.
- U-001: "phone is validated as trimmed non-empty only (no format regex)." — fallback: Add a pattern check in the shared phone field once a format is specified.
- U-001: "Payload schemas export schema + inferred type but no defaults." — fallback: Export empty-string defaults objects for each payload schema.
- U-001: "IAppointment embedded summaries typed as the full IPatient / IDoctor / IService (all optional)." — fallback: Narrow to Pick<> subsets once the upstream response shape is known.
- U-002: "now is optional; when it is omitted on the current day, no time filtering happens" — fallback: Make now required in AvailableSlotsInput, or return [] on the current day when it is missing
- U-002: "A malformed window or a malformed now on the current day returns []; malformed dates are not bookable" — fallback: Treat a malformed window as null (full day) instead
- U-002: "bookedStartTimes are matched exactly as HH:mm strings, with no normalization" — fallback: Normalize with slice(0, 5) in the U-009 hook before calling availableSlots
- U-003: "booked -> primary, cancelled -> error, completed -> success tint colors" — fallback: switch booked to 'info' in STATUS_PRESENTATION (contrast unaffected)
- U-003: "Provenance block placed above 'use client' in index.tsx" — fallback: move 'use client' to line 1 and put the block after it
- U-004: "No dark key on preset 3" — fallback: add dark: '#0D6882'
- U-004: "Contrast helper written in the test instead of MUI getContrastRatio" — fallback: import { getContrastRatio } from '@mui/material/styles' in the test
- U-005: "Role literal 'receptionist' is a module-local constant in the route" — fallback: If upstream emits a different role name (for example 'front_desk'), change RECEPTIONIST_ROLE, or move it to a shared constant once the role catalogue is decided.
- U-005: "Error envelope codes INVALID_JSON / VALIDATION_ERROR / FORBIDDEN" — fallback: Rename the codes to match the upstream catalogue once it is known; the status codes are the contract the tests pin.
- U-006: "Return upstream envelopes verbatim (success and failure)." — fallback: Strip any occurrence of the token from the upstream envelope before responding, or return only { success, code, message, data: { id, status } }.
- U-006: "Invalid JSON answers 400 INVALID_JSON, distinct from VALIDATION_ERROR." — fallback: Collapse both into VALIDATION_ERROR.
- U-007: "The schedule route forwards every incoming query key (Object.fromEntries of searchParams), not just from/to/doctorId" — fallback: If the upstream accepts another filter that widens the scope (e.g. doctorIds, all=true), whitelist the doctor path to { from, to, doctorId }. The U-005 panel raised a similar advisory (F-3) on the availability route.
- U-007: "A session whose token refresh failed (session.error = 'RefreshTokenError') is not treated as 401 here" — fallback: Add `|| session.error` to the 401 guard in both routes.
- U-007: "Role literals 'doctor' and 'receptionist' are module-local constants" — fallback: Move them to a shared constant once a role catalogue exists.
- U-008: "The handler parameter is typed as the Web Request rather than NextRequest" — fallback: Change the parameter type to NextRequest (type-only change)
- U-008: "The test spies on timingSafeEqual by mocking both 'node:crypto' and 'crypto' with one hoisted spy" — fallback: Drop the spy assertions. The 401/200 behaviour assertions stand on their own
- U-008: "Two extra tests beyond the six named acceptance tests" — fallback: Delete the two extra it() blocks. The acceptance tests are unaffected
- U-009: "makeUpdateMutation for cancel and reassign" — fallback: Hand-written useMutation with the same snackbar and refresh body
- U-009: "Hooks return the raw envelope (no select)" — fallback: Add select: r => r.data per hook and update consumers
- U-009: "useSchedule enabled only when from and to are set" — fallback: Remove the guard
- U-010: "Reschedule allows exactly one segment; /reschedule/abc/extra redirects" — fallback: Widen to /^\\/reschedule\\/[^/]+(\\/.*)?$/ if tokens can contain slashes
- U-011: "Added a skip-to-main-content link, off-screen until focused" — fallback: Delete the skip-link Typography block; the landmarks and nav still satisfy the tests.
- U-011: "Decorative tabler-calendar-plus icon (aria-hidden) on the nav link" — fallback: Remove the <i> element from NAV_ITEMS rendering.
- U-011: "Primary-colored brand text in dark mode" — fallback: Theme owner sets a lighter dark-mode primary.main, or the shell switches to text.primary in dark mode.
- U-012: "A non-null error hides the slot grid and shows ErrMsg" — fallback: Keep the slots visible whenever isLoading is false and show the error text above them
- U-012: "An empty date shows a neutral hint, not the error" — fallback: Treat an empty date as not bookable and show the error
- U-012: "Visual treatment based on a design section the dispatch truncated by 6215 bytes" — fallback: Adjust in review against the full design slice
- U-013: "Convert bookedStartTimes to HH:mm" — fallback: Settle the availability format with the upstream and remove the conversion
- U-013: "Show the price with formatNumber and no currency symbol" — fallback: Add a currency formatter once decided
- U-013: "Kept BookingWizard/index.tsx as one 831-line file" — fallback: Move layout pieces and step renderers into sibling files
- U-014: "bookedStartTimes passed through as HH:mm with no conversion" — fallback: Convert entries to their HH:mm tail before passing them to SlotPicker
- U-014: "today/now default to the browser clock" — fallback: Get today/now from a clinic-timezone helper once decided
- U-014: "Focus moves to the confirmation heading on success" — fallback: Remove the focus effect and rely on the live region
- U-015: "Kept the unit's acceptance command unchanged; verified a quoted form and a paren-free filter form instead" — fallback: Controller runs `pnpm test:run staff/login/page --reporter=verbose` or quotes the path
- U-015: "No custom staff-login UI" — fallback: A follow-up unit owning src/views/Login.tsx adds staff-specific furniture
- U-016: "Today view starts on today even on a weekend" — fallback: clamp the initial anchor to the nearest working day
- U-016: "on a weekend, the week view shows the Monday-Friday that just ended" — fallback: show the upcoming Monday-Friday on Sat/Sun
- U-016: "off-grid start times get their own row" — fallback: bucket into the latest slot at or before the start time
- U-017: "Reset the selection and error in the Dialog's transition onExited" — fallback: Reset in handleClose and after success, or key the content by appointment.id
- U-017: "Block closing while the request runs" — fallback: Allow closing, as UserFormDialog does
- U-018: "Submit-time check uses availableSlots rather than generateDaySlots" — fallback: Check against generateDaySlots(workingHours) only
- U-018: "The slot grid is shown only after a doctor is chosen" — fallback: Always render SlotPicker, with isLoading while no doctor is chosen
- U-018: "Override-mode date field has no weekend or past-date restriction" — fallback: Add min={today} to the override date field
- U-019: "Reassign disabled for cancelled/completed appointments" — fallback: Enable it for all statuses and let the upstream reject
- U-019: "A grid cell opens AppointmentDetailDialog" — fallback: Have the grid cell open ReassignDialog
- U-019: "Commit message has a blank line before Co-Authored-By" — fallback: Amend the message so Co-Authored-By follows the trailers directly, once no bolts are in flight

## Advisory findings worth a follow-up (not blocking; carried in each `findings.json`)
- **Security, pre-existing, out of scope:** `src/libs/auth.ts:120-121`. The jwt callback with `trigger === 'update'` merges client-supplied session data into the token, so roles or id can be forged through `useSession().update()`. This matters because the clinic role gates (receptionist/doctor) depend on those claims. Needs a dedicated unit that owns `auth.ts`.
- **Security, inherited by U-015:** `src/views/Login.tsx:133-136`. `redirectTo` is not validated before `router.replace`, which is an open redirect after sign-in and is now also reachable through `/staff/login`.
- The schedule and availability BFF routes forward every query param upstream (U-005/U-007).
- The cron sweep route has no upstream credential contract yet (OQ-AR-1).
- Normalisation of the `bookedStartTimes` format: U-013 normalises through `toSlotTime`, while U-014 and U-018 pass raw values.
- Duplication to extract in a follow-up refactor unit: the validate-and-reject/`respond` helpers (now in 4 routes), the DetailRow/SummaryItem primitives, and the appointment card and grid helpers shared by DoctorSchedule and ReceptionBoard.
- U-015 standards: the test imports `render` from `@testing-library/react` instead of `@/test/utils`. U-015 design: the staff login shows the unbranded template copy, and the shared Login view has no submit-pending state.

## Deferred open questions (15)
- OQ-CLINIC-001 · P1 · defer_to: stakeholder · [ ]  [P1] [business]: Which patient-data-privacy regulation applies in our region (HIPAA / GDPR-equivalent), and what does it require for storage and …
- OQ-CLINIC-002 · P1 · defer_to: stakeholder · [ ]  [P1] [business]: Should patients see other patients' names in any schedule view? (privacy implications; source: PRD §Clinic.6 Open Questions (sco…
- OQ-CN-1 · P1 · defer_to: stakeholder · [ ]  [P1] [tech / recommend] [conf: medium]: The PRD §6.3 Technology Stack (Bun, PostgreSQL + Drizzle, Better Auth, shadcn/ui, Resend; see also §8.1 C…
- OQ-AR-1 · P1 · defer_to: stakeholder · [ ]  [P1] [tech / recommend] [conf: medium] [origin: context.mdData-model]: This codebase has no database, yet PRD §Clinic.4 puts key rules in the dat…
- OQ-CN-2 · P2 · defer_to: stakeholder · [ ]  [P2] [tech / blocking] [conf: low]: How are the §6.2 Performance targets (median appointment lookup under 200ms, reminder email within 5 minutes,…
- OQ-CN-3 · P2 · defer_to: stakeholder · [ ]  [P2] [business]: Which timezone do the 09:00–17:00 bookable hours and the 24-hour reminder use — the clinic's local time or the patient's own dev…
- OQ-DM-1 · P2 · defer_to: stakeholder · [ ]  [P2] [business] [origin: context.mdData-model]: A service's duration can be longer than the 15-minute slot. Does a longer visit (for example a 30…
- OQ-FL-1 · P2 · defer_to: stakeholder · [ ]  [P2] [business] [origin: context.mdF-U-002]: Where does the patient confirm a cancellation and see the confirmation page (F-U-002 steps 2 and 4)?…
- OQ-AR-2 · P2 · defer_to: stakeholder · [ ]  [P2] [tech / blocking] [conf: low] [origin: context.mdF-S-001]: The staff navigation menu can only be restricted by permission names, but the PRD…
- OQ-CN-4 · P2 · defer_to: stakeholder · [ ]  [P2] [business] [origin: context.mdConstraints]: The public booking page must be rate-limited (PRD §Clinic.3), but no limit is stated. How many b…
- OQ-CLINIC-003 · P2 · defer_to: stakeholder · [ ]  [P2] [business]: What is the cancellation window — any time up to the appointment, or N hours before? (Applies to reschedule too.) (source: PRD §…
- OQ-CLINIC-004 · P2 · defer_to: stakeholder · [ ]  [P2] [business]: If a doctor calls in sick, how does the system handle their booked appointments (auto-notify + reassign, or manual)? (source: PR…
- OQ-CLINIC-005 · P2 · defer_to: stakeholder · [ ]  [P2] [tech / recommend] [conf: medium]: Deployment target — Vercel (Bun beta runtime + Vercel Cron, Pro tier for sub-daily cron) or self-hosted (…
- OQ-CLINIC-006 · P3 · defer_to: stakeholder · [ ]  [P3] [tech / recommend] [conf: medium]: Doctor schedule grid — confirm Schedule-X's current free-vs-premium view split is acceptable, or budget f…
- OQ-CN-5 · P3 · defer_to: stakeholder · [ ]  [P3] [business] [origin: context.mdConstraints]: The branded patient header and footer need the clinic's name and logo (PRD §8.3), but neither is…
Re-run: `/mega-sdd:resolve-oq` to answer them. Until then, each unit's `TBD: OQ-…` acceptance lines stay working assumptions.

## Next steps
- Halts to resolve: 0.
- detect-drift auto-gate (hybrid, DEFAULT-ON) runs now, then `/mega-sdd:analyze`.
- Answer the deferred OQs, P1 first: OQ-CLINIC-001, OQ-CLINIC-002, OQ-CN-1 (stack), OQ-AR-1 (upstream API contract).
- Schedule a hardening unit for `src/libs/auth.ts` (session-update role forgery) and `src/views/Login.tsx` (open redirect).

**Rendered HTML**: `.mega-sdd/vaults/clinic/bolts/html/_summary.html` (render-html.sh, offline; html/ is git-excluded because the output is large).
**Known stale artifact**: `units/_index.md` still shows every unit as `pending`. No script writes that column; completion comes from `.memory/bolt-outcomes.json` via `query-graph.sh --modules`, which shows 19/19 units-complete. It was deliberately left unedited.
