---
# Canonical PRD frontmatter (per docs/templates/prd-template.md) — machine-read by mega-sdd.
#   generate-intent → Mode A PRD parse + scope picker;  emit-fsd → stakeholders[] sign-off table;
#   resolve-oq → industry seeds OQ context;  diff-vault → re-diffs when this file's sha256 changes.
# NOTE: this sample uses a concrete modern stack (Next.js + Bun + Postgres + shadcn/ui) to make
# the walkthrough realistic. mega-sdd is tech-agnostic — the SAME pipeline works for Laravel,
# Rails, Django, Gin, Axum, etc.; the stack here is illustrative, not a default.
title: "Clinic Appointment System"
type: PRD
version: "2.0"
status: draft
date: 2026-06-12
authors: ["Product Team"]
industry: healthcare

stakeholders:
  - { role: "Product Owner", name: "Product Team", email: "po@clinic.local" }
  - { role: "Tech Lead (Full-stack)", name: "Engineering Lead", email: "eng@clinic.local" }
  - { role: "UI/UX Designer", name: "Design Lead", email: "design@clinic.local" }
  - { role: "QA Lead", name: "QA Lead", email: "qa@clinic.local" }

# Single-scope project — one Next.js full-stack app, one team. The whole product is one scope.
# (For the multi-scope BE/MW/FE variant of this same product, see sample-prd-multi-scope.md.)
scopes:
  CLINIC:
    name: "Clinic Web App"
    pics: ["Engineering Lead", "Design Lead"]
    priority: 1
    sections: ["§Clinic"]
    depends_on_locked_contracts: []

universal_sections: ["§1", "§2", "§3", "§4", "§5", "§6", "§7", "§8", "§9"]

cross_scope_dependencies: []
---

# §1. Executive Summary

A simple appointment-booking system for a small medical clinic. Patients self-book, reschedule, and cancel appointments online without calling the clinic; clinic staff (doctors, receptionists) view and manage the daily schedule. Initial scope is one clinic with 5 doctors handling roughly 50 appointments per day. The goal is to shift bookings off the phone and cut no-shows with automated email reminders, on a modern, accessible (WCAG AA) web stack.

# §2. Goals & Success Metrics

- Goal: patients self-book appointments without calling the clinic.
- Goal: staff see the daily schedule at a glance (doctor: own; receptionist: all).
- Goal: reduce no-shows via an email reminder 24 hours before the appointment.
- Goal: a trustworthy, accessible, modern UI that meets WCAG 2.2 AA.
- Success metric: ≥ 50% of appointments booked online (vs phone) within 3 months of launch.
- Success metric: no-show rate < 10% within 3 months (baseline 18%).
- Success metric: median staff time per booking < 30 sec (down from ~5 min phone-based).

# §3. Stakeholders & User Roles

- **Patient**: books, reschedules, and cancels their own appointments. No login; cancel/reschedule via a one-time email token.
- **Doctor**: staff role; views their own schedule.
- **Receptionist**: staff role; views all schedules, manages conflicts, creates walk-in/phone appointments.
- **Product Owner / Clinic staff**: own the rollout and success metrics.

# §4. Glossary

| Term | Definition |
|---|---|
| Appointment | A scheduled patient visit with a doctor (booked / cancelled / completed). |
| Slot | A 15-minute bookable time block on a doctor's schedule. |
| Service | The visit type: consultation, follow-up, or vaccination. |
| Reminder | The automated email sent 24h before an appointment, with a cancellation link. |
| Booking channel | Whether an appointment was created `online` (patient) or by `staff` (receptionist). |

# §5. Global Business Rules

- BR-001: Bookable hours are 09:00–17:00, in 15-minute slots, lunch break 12:00–13:00 (no slots). Per-doctor `working_hours` may narrow availability within these global bounds.
- BR-002: A slot may hold at most one active (booked) appointment; cancelling frees the slot immediately. Concurrent booking of the same slot is prevented at the database level (unique constraint + transactional insert).
- BR-003: A reminder email is sent 24 hours before the appointment and includes a cancellation link.
- BR-004: If the patient has not cancelled by the appointment time, the appointment is held as confirmed.
- BR-005: Service types are consultation, follow-up, and vaccination (price is display-only — billing in person; no payment code paths).
- BR-006: Every appointment records its `booking_channel` (`online` | `staff`) so the §9 online-share metric is measured in-system.

# §6. Constraints

## §6.1 Compliance
- Patient personal data (name, email, phone, reason for visit) is collected and stored; handle per applicable regional patient-privacy regulation (see §Clinic.6 OQ-CLINIC-001). The UI must meet **WCAG 2.2 Level AA** (healthcare products fall under ADA Title III / Section 508 / ACA Section 1557 expectations).

## §6.2 Performance
- Appointment lookup < 200ms (median).
- Reminder email delivered within 5 minutes of the scheduled send time.
- 99% uptime expectation.

## §6.3 Technology Stack
- **Framework**: Next.js 16 (App Router) as a full-stack app — Server Components for reads, Server Actions for mutations, Route Handlers for the cron trigger + the email-token cancel/reschedule endpoints.
- **Runtime / package manager / test runner**: Bun 1.3.x (PM + test runner everywhere; Bun-as-production-server is beta — use Bun-on-Vercel beta on Vercel, else Node as the self-hosted server runtime; pin-and-watch).
- **Database**: PostgreSQL. **ORM/migrations**: Drizzle + drizzle-kit.
- **UI**: shadcn/ui on Tailwind v4 (OKLCH tokens, dark mode via next-themes) — see §8.
- **Auth**: Better Auth (DB-backed sessions, Drizzle adapter, RBAC) — staff only (doctor / receptionist). Patients unauthenticated; cancel/reschedule via a one-time signed email token.
- **Email**: Resend + React Email (SPF/DKIM/DMARC on the sending domain).
- **Scheduled reminders**: a DB-backed "due reminders" sweep (NOT per-appointment in-memory timers), triggered by Vercel Cron (on Vercel) or `croner` in a persistent Bun process (self-host).
- **Validation**: Zod v4. **Testing**: Vitest + React Testing Library (unit/component), Playwright (E2E). **Lint/format**: Biome + a thin `eslint-config-next`.

# §7. Out of Scope (v1)

- Multi-clinic support · payment processing (display price only) · SMS reminders (email only) · patient medical records · recurring appointments · multi-language UI (English only) · patient login/accounts (one-time email tokens only).

# §8. UI/UX & Architecture Contract

> Design + architecture ground truth. The floor (tokens, states, a11y) is not the goal; §8 also specifies the ceiling so the result is a designed, trustworthy product, not a generic scaffold.

## §8.1 Component foundation
- **Base**: shadcn/ui (Radix primitives — ARIA/focus/keyboard for free) + official shadcn **Blocks** (`dashboard-01` + a sidebar block for the staff shell). All MIT, source owned in-repo.
- **Extensions**: Origin UI + Kibo UI (MIT, `npx shadcn add`-installable, application-oriented). Avoid Aceternity / Magic UI (too flashy for a clinical product).
- **Data tables** (reception queue, patient list): TanStack Table + the shadcn data-table pattern.
- **Date picking**: shadcn **Calendar** (react-day-picker) with past/weekend/out-of-hours disabling.
- **Doctor schedule grid** (rows = doctors, columns = time — shadcn has no native scheduler): **Schedule-X** (MIT core, resource view) as default; FullCalendar resource-timeline only if a paid license is acceptable.
- **Charts**: shadcn Charts (Recharts; shares the token layer). **Forms**: react-hook-form + Zod + shadcn Form (multi-step booking: one `<form>`, single RHF instance, per-step Zod via `trigger(fields)`). **Icons**: lucide.

## §8.2 Theming & design tokens (brand palette, made AA-safe)
- shadcn CSS-variable semantic tokens in OKLCH; `:root` light + `.dark` overrides via next-themes; generated with tweakcn.
- Brand: teal `#0891B2` + green `#16A34A`. **Accessibility-critical (WCAG luminance):** raw `#0891B2` (3.68:1) and `#16A34A` (3.30:1) **FAIL AA for white text** — do NOT use as `--primary` with white foreground.
  - `--primary`: **teal-700 `#0E7490`** = `oklch(0.520 0.094 223.1)` (5.36:1 ✓), white foreground.
  - `--accent`/success: **green-700 `#15803D`** = `oklch(0.527 0.137 150.1)` (5.02:1 ✓).
  - Lighter brand hues reserved for fills, chart series, icon accents (3:1 UI threshold), never body/label text on a colored surface.
- Status is never color-only: booked/cancelled/completed encoded by text + icon + color.

## §8.3 Anti-generic ceiling
- Move off the default neutral palette; apply brand color selectively to high-signal elements.
- Humanist sans body (warmer than default Inter/Geist), optional serif display headers; a real type scale.
- Page furniture: branded header (logo + nav) + footer; width-filling composition (two-column booking, hero/empty-states) — not a lone centered card.
- Deliberate `--radius` + consistent shadow/border language. Restrained motion (transform/opacity only, 160–220ms). Clinical flows stay linear (no bento on the wizard/detail views).

## §8.4 Accessibility floor (WCAG 2.2 AA)
- Contrast ≥ 4.5:1 text / 3:1 UI (§8.2); visible, unobscured focus; target size ≥ 24×24 (44×44 touch); labelled inputs with in-text error identification; `role="status"`/`aria-live` for booking confirmations + slot-availability updates; semantic landmarks; full keyboard reachability.

# §9. Success Metrics

- Online booking share ≥ 50% within 3 months (measured via `booking_channel`).
- No-show rate < 10% within 3 months (baseline 18%).
- Median staff time per booking < 30 seconds.

---

# §Clinic

> Scope owner: Engineering Lead + Design Lead per frontmatter `scopes.CLINIC.pics`.

## §Clinic.1 Functional Requirements (User Flows)

### F-U-001 — Patient books appointment
1. Patient lands on `/book` (multi-step wizard).
2. Selects doctor + service type (consultation / follow-up / vaccination).
3. Picks a date (Calendar shows the doctor's availability; past/weekend/out-of-hours disabled).
4. Picks a time slot (15-min; 09:00–17:00; lunch 12:00–13:00; taken slots hidden).
5. Enters name, email, phone, reason for visit (validated client + server).
6. Confirms booking (`booking_channel = online`).
7. Receives an email confirmation with details + a cancel/reschedule link.

### F-U-002 — Patient cancels appointment
1. Patient clicks the cancellation link (one-time signed token) from the email.
2. System asks for confirmation.
3. On confirm: status `cancelled`; slot freed immediately.
4. Patient sees a confirmation page.

### F-U-003 — Patient receives reminder
1. 24h before, the DB-backed sweep sends a reminder (24h ± 5 min).
2. Reminder includes details + cancel/reschedule link.
3. If not cancelled by appointment time, held as confirmed.

### F-U-004 — Patient reschedules appointment
1. Patient clicks the reschedule link (same one-time token) from the email.
2. Sees the current appointment + picks a new available slot.
3. On confirm: the old slot is freed and the new slot booked atomically (no double-book); confirmation re-sent.

### F-S-001 — Doctor views schedule
1. Doctor logs in (Better Auth; `doctor` role).
2. Sees today + week view (Schedule-X resource view, own column only).
3. Drills into appointment details (patient name, reason for visit).

### F-S-002 — Receptionist manages conflicts
1. Receptionist logs in (`receptionist` role).
2. Sees all doctors' schedules (Schedule-X, all columns) + a reception board (data table).
3. Can reassign an appointment to a different doctor (with patient notification email).
4. Can override booking restrictions (emergency walk-in outside slot times).
5. Can create an appointment for a walk-in/phone patient (`booking_channel = staff`).

## §Clinic.2 Non-Functional Requirements
- NFR-001: Mobile-responsive across the patient booking flow (primary, works at 375px) and staff views; WCAG 2.2 AA throughout.
- NFR-002: Appointment lookup < 200ms (median).
- NFR-003: Email delivery within 5 minutes of the scheduled send.

## §Clinic.3 Surfaces (Next.js App Router)

| Surface | Type | Route | Auth |
|---|---|---|---|
| Booking wizard | RSC page + Server Action | `/book` | public (rate-limited) |
| Cancel via token | Route Handler | `/api/appointments/[id]/cancel` (+ token) | one-time signed token |
| Reschedule via token | RSC page + Server Action | `/reschedule/[token]` | one-time signed token |
| Doctor schedule | RSC page | `/staff/schedule` | Better Auth (`doctor`) |
| Reception board | RSC page | `/staff/reception` | Better Auth (`receptionist`) |
| Staff login | RSC page + Server Action | `/staff/login` | public → issues session |
| Reminder cron | Route Handler | `/api/cron/reminders` | `CRON_SECRET` |

## §Clinic.4 Data Model
- **Staff**: id, name, email, password_hash, role (`doctor` | `receptionist`), specialty (doctors), working_hours (doctors), created_at. *(Owned by Better Auth's schema via the Drizzle adapter.)*
- **Patient**: id, name, email, phone, created_at.
- **Service**: id, name, duration_minutes, price (display only; not billed).
- **Appointment**: id, patient_id, doctor_id (→ Staff), service_id, start_time, end_time, status (`booked` | `cancelled` | `completed`), reason_for_visit, booking_channel (`online` | `staff`), reminder_at, reminder_sent (bool), created_at, updated_at. **Unique constraint on (doctor_id, start_time) where status = booked** (enforces BR-002 at the DB level).

## §Clinic.5 Acceptance Criteria
- AC-001: Booking a free slot creates a `booked` appointment (`booking_channel = online`) and sends a confirmation email.
- AC-002: A booked slot cannot be double-booked; the picker hides taken slots AND a concurrent insert is rejected by the unique constraint.
- AC-003: Cancelling via the email token sets status `cancelled` and frees the slot.
- AC-004: A reminder fires 24h ± 5 min before `start_time` for non-cancelled appointments, exactly once (`reminder_sent` flips true; idempotent sweep).
- AC-005: Doctors see only their own schedule; receptionists see all (enforced proxy/middleware → Server Component → Server Action → UI).
- AC-006: Rescheduling frees the old slot and books the new one atomically with no double-book.
- AC-007 (UI): every page meets WCAG 2.2 AA — `--primary` uses teal-700 (not raw teal), visible focus, labelled inputs, `aria-live` confirmations, status encoded by text+icon+color.

## §Clinic.6 Open Questions (scope-specific)

- **OQ-CLINIC-001** [P1] [business]: Which patient-data-privacy regulation applies in our region (HIPAA / GDPR-equivalent), and what does it require for storage + email handling?
- **OQ-CLINIC-002** [P1] [business]: Should patients see other patients' names in any schedule view? (privacy implications)
- **OQ-CLINIC-003** [P2] [business]: What is the cancellation window — any time up to the appointment, or N hours before? (Applies to reschedule too.)
- **OQ-CLINIC-004** [P2] [business]: If a doctor calls in sick, how does the system handle their booked appointments (auto-notify + reassign, or manual)?
- **OQ-CLINIC-005** [P2] [tech]: Deployment target — Vercel (Bun beta runtime + Vercel Cron, Pro tier for sub-daily cron) or self-hosted (Node server + croner)? Determines the reminder-sweep trigger and the Bun-server posture.
- **OQ-CLINIC-006** [P3] [tech]: Doctor schedule grid — confirm Schedule-X's current free-vs-premium view split is acceptable, or budget for FullCalendar Premium.
