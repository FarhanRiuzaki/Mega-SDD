# PRD — Clinic Appointment System

**Status**: Draft
**Date**: 2026-05-21
**Author**: Product Team

A simple appointment-booking system for a small medical clinic. Patients book appointments online; staff view + manage schedule.

## 1. Goals

- Patients self-book appointments without calling the clinic
- Staff see daily schedule at a glance
- Reduce no-shows via email reminders 24 hours before appointment
- Initial scope: 1 clinic, 5 doctors, ~50 appointments per day

## 2. User roles

- **Patient**: books, reschedules, cancels own appointments
- **Doctor**: views own schedule
- **Receptionist**: views all schedules, manages appointment conflicts

## 3. User flows

### F-U-001 — Patient books appointment

1. Patient lands on /book page
2. Selects doctor + service type (consultation / follow-up / vaccination)
3. Picks date from calendar (shows doctor availability)
4. Picks time slot (15-min intervals; 9am-5pm; lunch break 12-1pm)
5. Enters: name, email, phone, reason for visit
6. Confirms booking
7. Receives email confirmation with appointment details

### F-U-002 — Patient cancels appointment

1. Patient clicks cancellation link from confirmation email
2. System asks for confirmation
3. On confirm: appointment marked cancelled; slot freed
4. Patient sees confirmation page

### F-U-003 — Patient receives reminder

1. 24 hours before appointment: system sends reminder email
2. Reminder includes appointment details + cancellation link
3. If patient hasn't cancelled by appointment time: appointment held as confirmed

### F-S-001 — Doctor views schedule

1. Doctor logs in (email + password)
2. Sees today's schedule + week view
3. Can drill into individual appointment details (patient name, reason for visit)

### F-S-002 — Receptionist manages conflicts

1. Receptionist logs in
2. Sees all doctors' schedules
3. Can reassign appointment to different doctor (with patient notification)
4. Can override booking restrictions (e.g., emergency walk-in outside slot times)

## 4. Data model (high level)

- **Patient**: id, name, email, phone, created_at
- **Doctor**: id, name, email, specialty, working_hours
- **Service**: id, name, duration_minutes, price (display only; not billed)
- **Appointment**: id, patient_id, doctor_id, service_id, start_time, end_time, status (booked/cancelled/completed), reason_for_visit, created_at, updated_at

## 5. Tech constraints

- Backend: PHP 8.3 + Laravel 11
- Frontend: Blade + Tailwind CSS + minimal vanilla JS
- Database: MySQL 8
- Email: SMTP via Laravel Mail
- Auth: Laravel Sanctum (doctors + receptionists); patients use one-time email token for cancellation

## 6. Non-functional

- Mobile responsive (patient booking flow especially)
- Appointment lookup < 200ms (median)
- 99% uptime expectation
- Email delivery within 5 minutes of scheduled send

## 7. Out of scope (v1)

- Multi-clinic support
- Payment processing (display price only; clinic handles billing in-person)
- SMS reminders (email only)
- Patient medical records
- Recurring appointments
- Multi-language UI (English only for v1)

## 8. Success metrics

- 50% of appointments booked online (vs phone) within 3 months
- No-show rate < 10% (down from current 18% via reminder)
- Staff time per appointment booking < 30 sec (down from 5 minutes phone-based)

## 9. Open questions

These need stakeholder input before development:

- **OQ-001**: Do we need to comply with patient data privacy regulations (HIPAA / GDPR equivalent for our region)?
- **OQ-002**: Should patients see other patients' names in the schedule view? (Privacy implications)
- **OQ-003**: What's the cancellation window — can patients cancel up to appointment time, or 2 hours before, or 24 hours?
- **OQ-004**: If doctor calls in sick, how does the system handle their booked appointments?
