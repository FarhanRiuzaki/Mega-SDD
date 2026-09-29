# Hidden acceptance checklist — clinic (PRD `tests/scenarios/sample-prd-clinic.md`)

Never shown to an arm. Given to the blind scorer only (`benchmarks/scripts/blind-score.sh`).
Each item is PASS or FAIL with evidence (file:line, a command and its output, or both).
Judge against the PRD text. A stack substitution the PRD does not forbid (e.g. another DB or
email transport behind the same behavior) is not by itself a FAIL; missing behavior is.

| id | criterion |
|---|---|
| C1 | AC-001: booking a free slot creates a `booked` appointment with `booking_channel = online` and triggers a confirmation email (a real send or a mail transport/outbox call with the details + cancel/reschedule link) |
| C2 | AC-002: a booked slot cannot be double-booked — taken slots are hidden in the picker AND a concurrent insert is rejected by a DB-level unique constraint on (doctor, start_time) for booked appointments |
| C3 | AC-003: cancelling via the one-time signed email token sets status `cancelled` and frees the slot |
| C4 | AC-004: a reminder sweep sends 24h ± 5 min before `start_time` for non-cancelled appointments exactly once (`reminder_sent` flips; re-running the sweep sends nothing twice); the cron route checks `CRON_SECRET` |
| C5 | AC-005: doctors see only their own schedule, receptionists see all — enforced on the server (middleware/proxy and/or server component/action), not only hidden in the UI |
| C6 | AC-006: rescheduling frees the old slot and books the new one atomically with no double-book |
| C7 | AC-007: labelled inputs, visible focus, `aria-live` confirmations, status encoded by text + icon + color, primary color = teal-700 (or an AA-contrast equivalent explicitly mapped) |
| C8 | Booking wizard slot rules: 15-min slots 09:00–17:00, lunch 12:00–13:00 excluded, past/weekend dates disabled; client + server validation of name/email/phone/reason |
| C9 | Receptionist: can reassign an appointment to another doctor and create a staff booking (`booking_channel = staff`) |
| C10 | The repo's own test suite passes at HEAD (run it; a missing test script counts as FAIL) and `npm run build` succeeds |
