---
title: "Clinic Appointment System (Multi-scope test fixture)"
type: PRD
version: "1.0"
status: draft
date: 2026-05-23
authors: ["Test Suite"]
industry: healthcare
stakeholders:
  - { role: "BE Architect", name: "Test BE", email: "be@test.local" }
  - { role: "MW Architect", name: "Test MW", email: "mw@test.local" }
  - { role: "FE Architect", name: "Test FE", email: "fe@test.local" }

scopes:
  BE:
    name: "Backend API"
    pics: ["Test BE"]
    priority: 1
    sections: ["§Backend"]
  MW:
    name: "Integration Middleware"
    pics: ["Test MW"]
    priority: 2
    sections: ["§Middleware"]
    depends_on_locked_contracts: ["be-mw-appointment-events"]
  FE:
    name: "Frontend Web"
    pics: ["Test FE"]
    priority: 3
    sections: ["§Frontend"]
    depends_on_locked_contracts: ["be-fe-appointment-api"]

universal_sections: ["§1", "§2", "§3", "§4"]

cross_scope_dependencies:
  - { from: FE, to: BE, contract: "REST API per §Backend.3" }
  - { from: BE, to: MW, contract: "AppointmentCreated event" }
---

# §1. Executive Summary

Clinic appointment booking system. Patients book online; doctors view schedule; system sends reminders.

# §2. Goals

- Patients self-book without phone
- Reduce no-shows via 24h email reminders
- Staff sees daily schedule at a glance

# §3. Stakeholders

- Patient: books own appointments
- Doctor: views own schedule
- Receptionist: manages all schedules

# §4. Glossary

| Term | Definition |
|---|---|
| Appointment | Scheduled patient visit with a doctor |
| Slot | 15-minute time block on doctor's schedule |

---

# §Backend

## §Backend.1 Functional
- FR-BE-001: POST /api/appointments creates appointment + reserves slot
- FR-BE-002: GET /api/appointments/{id} returns appointment detail
- FR-BE-003: Emit AppointmentCreated event after persistence

## §Backend.3 API
| Endpoint | Method | Auth |
|---|---|---|
| /api/appointments | POST | Bearer |
| /api/appointments/{id} | GET | Bearer |

## §Backend.4 Data Model
- appointment: id, patient_id, doctor_id, start_time, status

---

# §Middleware

## §Middleware.1 Integration
- Email provider (SendGrid) for reminders
- SMS provider (Twilio) for backup reminders

## §Middleware.2 Events
- AppointmentCreated → trigger reminder schedule
- AppointmentCancelled → release reminder

---

# §Frontend

## §Frontend.1 User Flows
- F-001 Patient books appointment
- F-002 Doctor views schedule

## §Frontend.2 UI
- Page: /book — calendar widget
- Page: /doctor/schedule — day/week view
