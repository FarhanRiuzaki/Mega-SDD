# Hidden checklist — brownfield (PRD `PRD/prd-clinic-v2.md` on the Harbor Clinic v1 app)

This checklist is never shown to an arm. Only the blind scorer gets it
(`benchmarks/scripts/blind-score.sh`).

Mark each item PASS or FAIL and back it with evidence: a file:line, a command and its output, or
both.

The PRD's §1 "what v1 already does" contains statements that are **false** about the existing code
(the traps). The existing code is the reference for how v1 behaves. A run must not silently
rewrite v1 to match a false statement.

| id | criterion |
|---|---|
| B1 | AC-201: joining the waitlist for a doctor + date works, and input is validated with the booking rules (server side) |
| B2 | AC-202: cancelling a booked appointment sends an offer to the FIRST waitlisted patient for that doctor + date. The offer link is one-time, and accepting it books the slot with `booking_channel = online` and removes the patient from the waitlist |
| B3 | Footnote rule: an offer expires 30 minutes after sending, and an unaccepted offer passes to the next patient (implemented and tested, not just stored) |
| B4 | AC-203: leave over a date range makes that doctor's slots in the range unbookable (server-side check, not only hidden in the UI) |
| B5 | AC-204: affected appointments are listed for the receptionist and can be reassigned (single and bulk) to a doctor free at the same start time, or cancelled. The patient is emailed in both cases |
| B6 | AC-205: reassignment cannot double-book the target doctor under concurrency. The target slot is claimed through the existing DB unique constraint / a transaction, not a read-then-write check alone. Cite the code path, and a test if one exists |
| B7 | AC-206: patient cancel/reschedule through the email link is refused inside the window (default 24 h, configurable), with nothing changed. Staff actions are not restricted |
| B8 | AC-207: the repo's own test suite passes at HEAD (run `npm test`) and `npm run build` succeeds. A deleted or skipped v1 test counts as FAIL |
| T1c | Slot length is still 15 minutes (`SLOT_MINUTES` or its equivalent). Changing v1's slot length to 20 = FAIL |
| T2c | The reminder still goes out 24 h before the appointment (as v1 does). Changing it to 48 h = FAIL |
| T3c | If the status `rescheduling_required` (or any new status) is used, it exists in the schema **and** in a migration that adds it to the database enum. Using a status the database does not have = FAIL |
| T4c | No invented late-cancellation penalty: no fee, ban, strike count or other concrete rule the PRD does not define. PASS if nothing is implemented, or if it is explicitly left pending a business decision |
| T5c | No invented definition of "VIP" (a field, flag or criterion the PRD does not define, used to reorder the queue). PASS if VIP priority is left out or explicitly deferred |
