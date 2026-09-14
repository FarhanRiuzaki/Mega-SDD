# Pending sync decisions
**Last sync run**: 2026-09-14 (detect-drift post-bolt auto-gate, HEAD `048b3c6`) · **Open items**: 14

> Direction calls queued by `detect-drift`, which runs forked and non-interactive. Each item needs a person to choose between fixing the code (FIX_CODE) and updating the vault (UPDATE_VAULT). Full evidence for every item is in `DRIFT-REPORT.md`. Mark items `✅ RESOLVED <date>` in place; do not delete them.

## 1. CONFLICTs (BLOCKING — gate closed for affected units)
- (none — lite lane, no `binding.md`)

## 2. Drift direction calls (vault stale vs code regressed — your call)

### HIGH
- [ ] DRIFT-C1 [HIGH] decision-violation §B-005: vault says staff surfaces are role-gated and doctors are limited to their own schedule. In code, the role and id claims can be forged through `useSession().update()`, because the token is merged at `src/libs/auth.ts:120-122` (pre-existing code, not from a bolt).
      (source: DRIFT-REPORT.md §DRIFT-C1; anchor src/libs/auth.ts:120; affected: U-005, U-007, U-016, U-019) — FIX_CODE needs a new unit that owns auth.ts
- [ ] DRIFT-F1 [HIGH] behavior-drift BR-002: vault says taken slots are hidden. In code, reschedule and walk-in pass raw `bookedStartTimes` to an exact-`HH:mm` matcher, while only the booking wizard normalises them.
      (source: DRIFT-REPORT.md §DRIFT-F1; anchors src/features/appointments/components/RescheduleForm/index.tsx:304, src/features/appointments/components/WalkInDialog/index.tsx:94, src/features/appointments/utils/slots/index.ts:134; affected: U-014, U-018)
- [ ] DRIFT-E1 [HIGH] missing-in-vault: the BFF and upstream request/response contract is not in the vault. The paths appear only in the OQ-AR-1 recommendation. The undocumented parts are the nested `patient{}`, the `override` flag, the `IAvailability` shape, the local `startTime` format, and the receptionist-only rule for `staff`/`override`.
      (source: DRIFT-REPORT.md §DRIFT-E1; anchors src/features/appointments/types/index.ts:73, src/app/api/v1/appointments/route.ts:62)
- [ ] DRIFT-S1 [HIGH] type-drift: vault has `staff.working_hours json`. Code has `TWorkingHours {start, end}`, a single daily window.
      (source: DRIFT-REPORT.md §DRIFT-S1; anchor src/features/appointments/types/index.ts:26)
- [ ] DRIFT-D3 [HIGH] decision-unwritten: vault says "an appointment can be reassigned", with no condition. Code allows reassignment only for `booked` appointments.
      (source: DRIFT-REPORT.md §DRIFT-D3; anchor src/features/appointments/components/ReceptionBoard/columns.tsx:102)
- [ ] DRIFT-F3 [HIGH] behavior-drift [low confidence — verify manually]: vault says the override applies "outside slot times". In code, the override also skips the past-date and weekend bounds.
      (source: DRIFT-REPORT.md §DRIFT-F3; anchor src/features/appointments/components/WalkInDialog/index.tsx:117)

### MEDIUM
- [ ] DRIFT-C2 [MEDIUM] decision-violation §A-003: the test imports `render` from `@testing-library/react` instead of using `renderWithProviders`.
      (source: DRIFT-REPORT.md §DRIFT-C2; anchor src/app/(blank-layout-pages)/staff/login/page.test.tsx:13)
- [ ] DRIFT-C3 [MEDIUM] decision-violation §A-004: the four server payload schemas export a schema and a type but no defaults. Deciding needs a ruling on whether the clause applies per file or per schema.
      (source: DRIFT-REPORT.md §DRIFT-C3; anchor src/features/appointments/schemas/booking/index.ts:120)
- [ ] DRIFT-C4 [MEDIUM] decision-violation §A-002: `AppointmentDetailDialog/` is a folder with no test.
      (source: DRIFT-REPORT.md §DRIFT-C4; anchor src/features/appointments/components/AppointmentDetailDialog/index.tsx:1)

### LOW (vault-acknowledged — code follows or answers a deferred OQ)
- [ ] DRIFT-D1 [LOW] decision-unwritten: OQ-DM-1 is answered in code as "only the start slot is blocked".
      (source: DRIFT-REPORT.md §DRIFT-D1; anchor src/features/appointments/utils/slots/index.ts:129) — route: `resolve-oq` OQ-DM-1
- [ ] DRIFT-D2 [LOW] decision-unwritten: OQ-CN-3 is answered in code as "the patient's browser clock decides which dates and slots are past".
      (source: DRIFT-REPORT.md §DRIFT-D2; anchor src/features/appointments/components/BookingWizard/index.tsx:116) — route: `resolve-oq` OQ-CN-3
- [ ] DRIFT-F2 [LOW] missing-in-code: F-U-002 has no patient-facing cancel landing or confirmation page. The hook and the POST route exist, but nothing calls them.
      (source: DRIFT-REPORT.md §DRIFT-F2; anchor src/features/appointments/hooks/useAppointments/index.ts:105) — route: `resolve-oq` OQ-FL-1, then a new unit
- [ ] DRIFT-E2 [LOW] missing-in-code: `/book` has no rate limiting.
      (source: DRIFT-REPORT.md §DRIFT-E2; anchor src/app/api/v1/appointments/route.ts:46) — route: `resolve-oq` OQ-CN-4
- [ ] DRIFT-S2 [LOW] missing-in-code: the client types omit upstream-owned columns (`created_at`, `updated_at`, the staff credentials), and the reminder fields are optional.
      (source: DRIFT-REPORT.md §DRIFT-S2; anchor src/features/appointments/types/index.ts:54) — fold into OQ-AR-1

## 3. Write-back drafts awaiting human triage
- (none — `--auto-apply=safe` not set; no patches drafted or applied)
