# 03 — Data Model

## Entities (DBML)

```dbml
// Purpose: Staff account (doctor / receptionist), owned by Better Auth schema
Table staff {
  id bigint [pk, increment]
  name varchar
  email varchar [unique]
  role varchar
  specialty varchar
  working_hours json
}

// Purpose: Patient contact record (no login)
Table patient {
  id bigint [pk, increment]
  name varchar
  email varchar
  phone varchar
}

// Purpose: Visit type (consultation / follow-up / vaccination), price display-only
Table service {
  id bigint [pk, increment]
  name varchar
  duration_minutes int
  price int
}

// Purpose: The scheduled visit; unique (doctor_id, start_time) where booked (BR-002)
Table appointment {
  id bigint [pk, increment]
  patient_id bigint
  doctor_id bigint
  service_id bigint
  start_time timestamp
  end_time timestamp
  status varchar
  reason_for_visit text
  booking_channel varchar
  reminder_at timestamp
  reminder_sent bool
  indexes {
    (doctor_id, start_time) [unique]
  }
}

Ref: appointment.patient_id > patient.id
Ref: appointment.doctor_id > staff.id
Ref: appointment.service_id > service.id
```

## Open Questions

- [ ] **OQ-CLINIC-003** [P2] [business]: What is the cancellation window — any time up to the appointment, or N hours before? (Applies to reschedule too.)
