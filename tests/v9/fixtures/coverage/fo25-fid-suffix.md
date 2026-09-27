# PRD: Clinic

## §Clinic.1 Functional Requirements (User Flows)

### F-U-001 — Patient books appointment
The patient MUST pick a free slot; the booking MUST be confirmed by SMS.

### F-U-001-B — Slot already taken (alternate)
Booking MUST fail with a "slot taken" message and offer the next 3 free slots.

### F-U-002 — Patient cancels appointment
Cancellation MUST be allowed until 2 hours before the slot.

### F-U-002.1 — Late cancellation fee
A late cancellation MUST be charged Rp50.000.
