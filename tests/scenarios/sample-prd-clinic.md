---
# Canonical PRD frontmatter (per docs/templates/prd-template.md) — machine-read by mega-sdd.
#   generate-intent → Mode A PRD parse + scope picker;  emit-fsd → stakeholders[] sign-off table;
#   resolve-oq → industry seeds OQ context;  diff-vault → re-diffs when this file's sha256 changes.
title: "Clinic Appointment System"
type: PRD
version: "1.0"
status: draft
date: 2026-05-21
authors: ["Product Team"]
industry: healthcare

stakeholders:
  - { role: "Product Owner", name: "Product Team", email: "po@clinic.local" }
  - { role: "BE Architect", name: "Backend Lead", email: "be@clinic.local" }
  - { role: "FE Architect", name: "Frontend Lead", email: "fe@clinic.local" }
  - { role: "QA Lead", name: "QA Lead", email: "qa@clinic.local" }

# Single-scope project — one Laravel app, one team. The whole product is one scope.
# (For the multi-scope BE/MW/FE variant of this same product, see sample-prd-multi-scope.md.)
scopes:
  CLINIC:
    name: "Clinic Web App"
    pics: ["Backend Lead", "Frontend Lead"]
    priority: 1
    sections: ["§Clinic"]
    depends_on_locked_contracts: []

universal_sections: ["§1", "§2", "§3", "§4", "§5", "§6", "§7", "§9"]

cross_scope_dependencies: []
---

# §1. Executive Summary

A simple appointment-booking system for a small medical clinic. Patients book appointments online without calling the clinic; clinic staff view and manage the daily schedule. Initial scope is one clinic with 5 doctors handling roughly 50 appointments per day. The goal is to shift bookings off the phone and cut no-shows with automated email reminders.

# §2. Goals & Success Metrics

- Goal: patients self-book appointments without calling the clinic
- Goal: staff see the daily schedule at a glance
- Goal: reduce no-shows via email reminders 24 hours before the appointment
- Success metric: 50% of appointments booked online (vs phone) within 3 months
- Success metric: no-show rate < 10% (down from current 18%)
- Success metric: staff time per booking < 30 sec (down from ~5 min phone-based)

# §3. Stakeholders & User Roles

- **Patient**: books, reschedules, and cancels their own appointments
- **Doctor**: views their own schedule
- **Receptionist**: views all schedules, manages appointment conflicts
- **Product Owner / Clinic staff**: own the rollout and success metrics

# §4. Glossary

| Term | Definition |
|---|---|
| Appointment | A scheduled patient visit with a doctor (booked / cancelled / completed) |
| Slot | A 15-minute bookable time block on a doctor's schedule |
| Service | The visit type: consultation, follow-up, or vaccination |
| Reminder | The automated email sent 24h before an appointment |

# §5. Global Business Rules

- BR-001: Bookable hours are 09:00–17:00, in 15-minute slots, with a lunch break 12:00–13:00 (no slots).
- BR-002: A slot may hold at most one active (booked) appointment; cancelling frees the slot immediately.
- BR-003: A reminder email is sent 24 hours before the appointment and includes a cancellation link.
- BR-004: If the patient has not cancelled by the appointment time, the appointment is held as confirmed.
- BR-005: Service types are consultation, follow-up, and vaccination (price is display-only — billing is handled in person).

# §6. Constraints

## §6.1 Compliance
- Patient personal data (name, email, phone, reason for visit) is collected and stored; handle per applicable regional patient-privacy regulation (see §Clinic.6 OQ-CLINIC-001).

## §6.2 Performance
- Appointment lookup < 200ms (median).
- Reminder email delivered within 5 minutes of the scheduled send time.
- 99% uptime expectation.

## §6.3 Deployment
- Backend: PHP 8.3 + Laravel 11.
- Frontend: Blade + Tailwind CSS + minimal vanilla JS (mobile-responsive, booking flow especially).
- Database: MySQL 8.
- Email: SMTP via Laravel Mail.
- Auth: Laravel Sanctum for doctors + receptionists; patients use a one-time email token for cancellation (no patient login in v1).

# §7. Out of Scope (v1)

- Multi-clinic support
- Payment processing (display price only; clinic handles billing in person)
- SMS reminders (email only)
- Patient medical records
- Recurring appointments
- Multi-language UI (English only for v1)

# §9. Success Metrics

- Online booking share ≥ 50% of all appointments within 3 months of launch.
- No-show rate < 10% within 3 months (baseline 18%).
- Median staff time per booking < 30 seconds.

---

# §Clinic

> Scope owner: Backend Lead + Frontend Lead per frontmatter `scopes.CLINIC.pics`

## §Clinic.1 Functional Requirements (User Flows)

### F-U-001 — Patient books appointment
1. Patient lands on the `/book` page
2. Selects doctor + service type (consultation / follow-up / vaccination)
3. Picks a date from the calendar (shows doctor availability)
4. Picks a time slot (15-min intervals; 09:00–17:00; lunch break 12:00–13:00)
5. Enters: name, email, phone, reason for visit
6. Confirms booking
7. Receives an email confirmation with appointment details

### F-U-002 — Patient cancels appointment
1. Patient clicks the cancellation link from the confirmation email
2. System asks for confirmation
3. On confirm: appointment marked cancelled; slot freed
4. Patient sees a confirmation page

### F-U-003 — Patient receives reminder
1. 24 hours before the appointment: system sends a reminder email
2. Reminder includes appointment details + cancellation link
3. If the patient hasn't cancelled by appointment time: appointment held as confirmed

### F-S-001 — Doctor views schedule
1. Doctor logs in (email + password)
2. Sees today's schedule + a week view
3. Can drill into individual appointment details (patient name, reason for visit)

### F-S-002 — Receptionist manages conflicts
1. Receptionist logs in
2. Sees all doctors' schedules
3. Can reassign an appointment to a different doctor (with patient notification)
4. Can override booking restrictions (e.g., emergency walk-in outside slot times)

## §Clinic.2 Non-Functional Requirements
- NFR-001: Mobile-responsive across the patient booking flow (primary) and staff schedule views.
- NFR-002: Appointment lookup < 200ms (median).
- NFR-003: Email delivery within 5 minutes of the scheduled send.

## §Clinic.3 API / Pages

| Surface | Method / Route | Auth |
|---|---|---|
| Booking page | GET `/book` | public |
| Create appointment | POST `/appointments` | public (rate-limited) |
| Cancel via token | GET/POST `/appointments/{id}/cancel?token=…` | one-time email token |
| Doctor schedule | GET `/doctor/schedule` | Sanctum (doctor) |
| Receptionist schedules | GET `/reception/schedules` | Sanctum (receptionist) |

## §Clinic.4 Data Model
- **Patient**: id, name, email, phone, created_at
- **Doctor**: id, name, email, specialty, working_hours
- **Service**: id, name, duration_minutes, price (display only; not billed)
- **Appointment**: id, patient_id, doctor_id, service_id, start_time, end_time, status (booked/cancelled/completed), reason_for_visit, created_at, updated_at

## §Clinic.5 Acceptance Criteria
- AC-001: Booking a free slot creates a `booked` appointment and sends a confirmation email.
- AC-002: A booked slot cannot be double-booked; the slot picker hides taken slots.
- AC-003: Cancelling via the email token sets status `cancelled` and frees the slot.
- AC-004: A reminder email fires 24h ± 5min before `start_time` for non-cancelled appointments.
- AC-005: Doctors see only their own schedule; receptionists see all.

## §Clinic.6 Open Questions (scope-specific)

These need stakeholder input before development:

- **OQ-CLINIC-001** [P1] [business]: Which patient-data-privacy regulation applies in our region (HIPAA / GDPR-equivalent), and what does it require for storage + email handling?
- **OQ-CLINIC-002** [P1] [business]: Should patients see other patients' names in any schedule view? (privacy implications)
- **OQ-CLINIC-003** [P2] [business]: What is the cancellation window — any time up to the appointment, or N hours before?
- **OQ-CLINIC-004** [P2] [business]: If a doctor calls in sick, how does the system handle their booked appointments (auto-notify + reassign, or manual)?
