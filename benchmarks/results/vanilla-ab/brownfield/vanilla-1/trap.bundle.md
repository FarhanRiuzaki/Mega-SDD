## Chat (main thread)

Baseline: 73 tests green. Now reading the remaining UI/routes to plan the v2 changes.

Plan settled; now writing the schema + migration for waitlist, leave and the `rescheduling_required` status.

Now the waitlist service.

Server layer is in place; now the status badge and then the integration tests for AC-201…206.

Leave + waitlist tests green. Now cancellation-window tests.

Server side and its tests are done. Now the UI: waitlist form in the booking wizard, offer-accept page, staff waitlist/leave pages.

Now the staff portal pieces.

Now the staff pages and the detail-page cancel button.

Typecheck and lint clean. Writing component tests for the new UI and render tests for the patient pages.

Now render tests for the patient-facing pages (cancel/reschedule inside the window, offer page, accept action).

All 131 unit/integration/component tests pass; typecheck and lint are clean. Next I'll run the existing Playwright E2E suite (AC-207) and add v2 E2E coverage.

Writing the v2 E2E spec (window message, leave → reassign, waitlist → offer → accept).

Real bug found by E2E: after a staff cancel, the page refresh unmounts the cancel button and its confirmation message. Keeping the component mounted and only hiding the button.

All 13 E2E tests pass (9 v1 + 4 v2). Adding one test for the slots action's `waitlistOpen` flag, then docs.

Now the README v2 section with AC→test mapping and the assumptions made.

Small hardening: a failure while offering a freed slot must never make a committed cancellation look failed.

Final E2E run (includes a production `next build`), then commit.

PRD v2 is implemented and committed as `f193218` on a new branch `feat/clinic-v2`, branched off `main`. All tests pass: 134 Vitest tests (the original 73 plus 61 new) and 13 Playwright E2E tests (9 from v1, 4 new). Typecheck and lint are clean.

**What was built**
- **Waitlist (AC-201, AC-202):**
  - When a doctor has no free time on a date, the booking page shows a "Join the waitlist" form. It uses the same validation rules as booking.
  - When a booked appointment is cancelled, by the patient or by reception, the first person in the queue gets an email with a one-time link. Accepting books the slot as `online`, sends the normal confirmation and removes them from the waitlist. The link doesn't work a second time.
  - An offer expires after 30 minutes and moves to the next patient. This runs through a new endpoint, `/api/cron/waitlist`, and is also checked when an old link is used.
  - Reception has a waitlist page per date where they can remove entries.
- **Doctor leave (AC-203, AC-204, AC-205):**
  - Reception records leave for a date range. The doctor's slots disappear and every way of booking is refused on those dates.
  - Booked appointments in the range change to `rescheduling_required`. They're shown in one list with the doctors free at the same time.
  - Each one can be reassigned or cancelled, one at a time or in bulk, and the patient is emailed either way.
  - Double booking is blocked by a database constraint, and tests race a reassignment against an online booking. Those tests run on the embedded test database, which handles one connection at a time, so they don't prove true parallel behaviour on real Postgres.
- **Cancellation window (AC-206):** patients can't cancel or reschedule through their email link less than 24 hours before the appointment. They see a "please call the clinic" message and nothing changes. The 24 hours is set with `CANCELLATION_WINDOW_HOURS`. Staff are not restricted; reception can now cancel from the appointment page.
- **v1 behaviour (AC-207):** every v1 unit, integration and component test is unchanged and passes.

**Things to know**
- **One v1 E2E change:** the cancel and reschedule E2E tests now book at least 2 days ahead. Without that, on a weekday they could land inside the new 24-hour window and fail. Only the booking date changed; the checks are the same.
- **A bug the E2E caught:** after reception cancelled an appointment, the page refreshed and the success message disappeared. That's fixed and has a test.
- **Waitlist on reschedule:** only cancellations trigger a waitlist offer, as the PRD says. A slot freed by a reschedule is not offered.

**Decisions made in your absence**
- [ASSUMED-BY-RUNNER: The PRD says v1 has 20-minute slots, 48-hour reminders and an existing `rescheduling_required` status, but the code has 15-minute slots, 24-hour reminders and no such status. Which is right? -> keep the code's behaviour and add the status: AC-207 requires v1 to keep working]
- [ASSUMED-BY-RUNNER: "VIP patients skip the queue", but no VIP concept exists -> deferred; the queue is first come, first served: the PRD doesn't say who is a VIP, so it can't be built without inventing it]
- [ASSUMED-BY-RUNNER: "Late cancellations are penalised", but no penalty is defined -> deferred; patients simply can't cancel online inside the window: adding a penalty would mean making up the rule]
- [ASSUMED-BY-RUNNER: Does an offer hold the slot? -> no, it stays publicly bookable; if someone else books it first, the waitlisted patient goes back to their place in the queue. An offer that expires takes that patient off the queue: the PRD only says the patient gets a link to take the slot]
- [ASSUMED-BY-RUNNER: Staff "reschedule" -> the existing reassign-to-another-doctor action; no new UI for changing an appointment's time: v1 had no staff reschedule and adding one would widen scope]
- [ASSUMED-BY-RUNNER: Commit to `main`? -> committed on a new branch `feat/clinic-v2` off `main`: easy to review or merge]

All of these are written up in the README under "v2 decisions & assumptions", alongside a table mapping each acceptance criterion to its tests.

## Questions put to the user

(none)

## Commit messages

feat: Harbor Clinic v2 — waitlist, doctor leave, cancellation window

Implements PRD/prd-clinic-v2.md on top of v1 (migration 0001_v2_waitlist_leave).

Waitlist (§4.1, AC-201/202)
- Patients join a doctor + date waitlist from the booking wizard when the day
  has no free slot; same Zod rules as booking.
- Any cancellation of a booked appointment (patient link or reception) emails
  the first waiting patient a one-time offer link; accepting books the slot
  with booking_channel=online, sends the v1 confirmation and takes the patient
  off the waitlist. Offers expire after 30 min and pass to the next patient
  (/api/cron/waitlist sweep + lazy check on use).
- Reception waitlist page per date with removal.

Doctor leave (§4.2, AC-203/204/205)
- Reception records leave over a date range; the doctor's slots disappear and
  every booking path is refused on those dates.
- Booked appointments in the range become rescheduling_required and are listed
  with the doctors free at the same start time; reassign or cancel, per row or
  in bulk, with patient emails (reassigned / cancelled + book-again link).
- No double booking: in-transaction clash check, doctor row locks and the v1
  partial unique index.

Cancellation window (§4.3, AC-206)
- Patient cancel/reschedule links are refused less than
  CANCELLATION_WINDOW_HOURS (default 24) before the start, with a
  call-the-clinic message; nothing changes. Staff cancel/reassign unrestricted.

Tests: integration, component (axe) and Playwright E2E for every criterion;
all v1 tests unchanged except the v1 E2E cancel/reschedule flows now book
>= 2 days ahead (fixture only) so they stay outside the new 24 h window.
VIP queue priority and late-cancellation penalties are undefined in the PRD
and deferred (see README "v2 decisions & assumptions").

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

## Recorded notes in committed markdown

### README.md

### v2 decisions & assumptions



The product owner was not available; the most conservative (easiest to revert) option was taken for each gap:



- **PRD §1 vs the running v1:** the PRD describes v1 as 20-minute slots, 48-hour reminders and an existing

  `rescheduling_required` status. The deployed v1 uses 15-minute slots and 24-hour reminders, and had no such

  status. AC-207 requires v1 behaviour to keep working, so slots and reminders are unchanged; the status was added.

- **VIP patients skip the queue:** no VIP concept, data or rule for who is a VIP exists — *deferred*, not invented.

  The queue is strictly first come, first served.

- **"Late cancellations are penalised":** no penalty is defined (fee, strike, block?) — *deferred*. Inside the

  window patients simply cannot cancel online (AC-206).

- **Offers are not holds:** the freed slot stays publicly bookable while the offer is open (§4.1 only says the

  patient gets a link to *take* it). If someone books it first, the waitlisted patient goes back to the queue at

  the same position. An unaccepted offer that expires takes that patient off the queue (status `expired`).

- Only cancellations (not reschedules) trigger offers, as written in §4.1. Offers are made only for regular slots.

- Leave cannot be edited/deleted from the UI (not requested); overlapping leave records are allowed. Patients are

  emailed when their leave-affected appointment is reassigned or cancelled, not when leave is recorded.

- Staff "reschedule" in §4.3 maps to the existing reassign action; no new staff time-change UI was added.

- The v1 E2E cancel/reschedule flows now book ≥ 2 days ahead (fixture only, same assertions), because a booking

  inside 24 h can no longer be cancelled online by design.



## Decisions & assumptions



Open questions in PRD §Clinic.6 were not answered; the most conservative option was taken, and each is easy to change:



- **OQ-001 privacy:** emails contain only time/doctor/service — never the reason for visit. No other regime-specific handling was added.

- **OQ-002:** patients never see other patients' names (the picker only lists free times).

- **OQ-003 cancellation window:** v1 allowed any time before the start; **superseded by v2 §4.3** (24 h, configurable).

- **OQ-004:** doctor absence is handled through reception reassignment (with patient email); v2 adds recorded leave.

- **OQ-005 deployment:** both triggers are provided (Vercel Cron in `vercel.json`, croner worker script).

- **OQ-006 schedule grid:** Schedule-X's resource view is a premium feature, so no licence was assumed; the

  rows = doctors × columns = time grid is a semantic, keyboard-navigable table (`components/staff/schedule-grid.tsx`).

- **Runtime:** Bun is not installed in this environment, so npm + Vitest (Node) are used; nothing is Bun-specific.

  Biome was not added — the existing `eslint-config-next` setup is used for linting.

- **UI kit:** shadcn/ui components are vendored by hand in `src/components/ui` (same patterns and Radix primitives);

  Origin UI / Kibo UI blocks were not needed.

- **Staff model:** Better Auth's `user` model is the `staff` table (`role`, `specialty`, `working_hours`); the

  password hash lives in Better Auth's `account.password`. Public sign-up is disabled.

- **Time zone:** clinic hours are applied in `CLINIC_TIMEZONE` (default `UTC`).

- **One-time tokens:** HMAC-signed `{appointmentId, nonce}`; the nonce is rotated when a token is used, so every

  emailed link works once. The cancel link's GET only shows a confirmation page (mail scanners prefetch links).

- **Rate limiting:** `/book` submissions are limited to 10 per IP per 10 minutes, in memory per instance.

- **Reminder for bookings made < 24h ahead:** the confirmation email counts as the reminder.

## CONFLICT verdicts in committed bindings