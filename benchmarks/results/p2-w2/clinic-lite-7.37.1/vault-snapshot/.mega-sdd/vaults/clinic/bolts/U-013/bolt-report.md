---
unit: U-013
status: success
attempted_at: 2026-09-14T14:57:13+00:00
duration_seconds: 1520944
commits: [b1544b1f2e959a7c0ab35e6a44b9c3705b78cfe6]
files_touched: [src/app/(patient)/book/page.tsx, src/features/appointments/components/BookingWizard/index.test.tsx, src/features/appointments/components/BookingWizard/index.tsx]
tests_run: ["pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"]
test_results: "0 acceptance entries passed / 9 not passing (see acceptance.json)"
retries: 0
target_hashes:
  src/features/appointments/components/BookingWizard/index.tsx: 6c821674439752c721bbe4c6f31d32ca60bbd7e601da7523a7ac36d1458225a2
  src/features/appointments/components/BookingWizard/index.test.tsx: 1ad7e6d1971fa8b912729f535f533fdc58ba811514b6a423c17a3e88adb3a9e1
  src/app/(patient)/book/page.tsx: 88e78796cb3e8c98f5fef9b4bd6d913f92102c800657145f4d94070f4e660860
---

# Bolt Report — U-013

## Summary
(see implementer report)

## Review panel
- Tier: **full** · signals_fired: ['vocabulary', 'risk_field'] · lenses: spec, quality, security, standards · implementer model routing: inherit (session model)
- L0: run-code-gates.sh --write per unit commit (b1544b1) — no blocking finding
- Ledger `findings.json` (merge-panel-findings.sh): attempt 1 · gate clear · open 0 · advisory 11 · resolved 0

| id | severity | file:line | lens | status | title |
|---|---|---|---|---|---|
| F-1 | Important | src/features/appointments/components/BookingWizard/index.tsx:114 | quality | advisory | hand-rolled pad/readBrowserClock duplicates dayjs usage |
| F-2 | Important | src/features/appointments/components/BookingWizard/index.tsx:129 | quality | advisory | toSlotTime fixes an unclear API field format in only one of three consumers |
| F-3 | Important | src/features/appointments/components/BookingWizard/index.tsx:794 | quality | advisory | DetailList/DetailItem copy RescheduleForm's summary list |
| F-4 | Important | src/features/appointments/components/BookingWizard/index.test.tsx:222 | quality | advisory | No tests for the new error and start-over paths |
| F-5 | Minor | src/features/appointments/components/BookingWizard/index.tsx:738 | quality | advisory | Placeholder copied verbatim from WalkInDialog |
| F-6 | Minor | src/features/appointments/components/BookingWizard/index.tsx:266 | quality | advisory | Every booking failure shown as a slot conflict; message shown twice (snackbar + Alert) |
| F-7 | Minor | src/features/appointments/components/BookingWizard/index.tsx:1 | quality | advisory | 831 lines in one module |
| F-8 | Minor | src/features/appointments/components/BookingWizard/index.tsx:308 | quality | advisory | doctor and service Controller blocks near-identical |
| F-9 | Minor | src/features/appointments/components/BookingWizard/index.test.tsx:519 | quality | advisory | Console spies restored at end of test body |
| F-10 | Minor | src/features/appointments/components/BookingWizard/index.tsx:265 | security | advisory | Patient PII stays in the mutation state after booking |
| F-11 | Minor | src/features/appointments/components/BookingWizard/index.tsx:614 | design | advisory | Stepper step labels hidden with display:none below sm |

## Post-flight
- Hard rules: postflight.json status **pass** (DO_NOT_ADD_DEPS=pass, FILE_PRESENCE_RULE=pass)
- Acceptance: acceptance.json status **pass** (0/8 executed entries pass)
- ✓ Drift check: clean (lite lane — no binding.md anchors; no LOCKED entities in the vault)

## Rollback hints
```yaml
- step_id: step-1-test
  step_type: file_created
  evidence: "src/features/appointments/components/BookingWizard/index.test.tsx (521 lines)"
  compensating_action: "git rm src/features/appointments/components/BookingWizard/index.test.tsx"
  idempotent: true
- step_id: step-2-wizard
  step_type: file_created
  evidence: "src/features/appointments/components/BookingWizard/index.tsx (831 lines)"
  compensating_action: "git rm src/features/appointments/components/BookingWizard/index.tsx"
  idempotent: true
- step_id: step-3-page
  step_type: file_created
  evidence: "src/app/(patient)/book/page.tsx (27 lines)"
  compensating_action: "git rm 'src/app/(patient)/book/page.tsx'"
  idempotent: true
- step_id: step-4-commit
  step_type: git_commit
  evidence: "095041fcec23a88ec6c2269b09a6bc57507a8baa feat(U-013)"
  compensating_action: "git revert --no-edit 095041fcec23a88ec6c2269b09a6bc57507a8baa"
  idempotent: false
```

```yaml
bolt_self_report:
  model_used: "Opus 5"
  confidence: 0.8
  certain_decisions:
    - "One form and one useForm instance; Next calls trigger on BOOKING_STEP_FIELDS[step] with shouldFocus"
    - "Request is built field by field with bookingChannel 'online' and no override key; the test checks the exact key set"
    - "The role=status aria-live=polite region is mounted from the start and filled on success; the email copy says 'is on its way'"
    - "On rejection: keep details, clear startTime, go to the date & time step, show the upstream message, refetch availability"
  uncertain_decisions:
    - decision: "Convert bookedStartTimes to HH:mm"
      rationale: "SlotPicker expects HH:mm but the U-009 fixture used full date-times"
      fallback_if_wrong: "Settle the availability format with the upstream and remove the conversion"
    - decision: "Show the price with formatNumber and no currency symbol"
      rationale: "No currency is specified in the PRD/context/constitution"
      fallback_if_wrong: "Add a currency formatter once decided"
    - decision: "Kept BookingWizard/index.tsx as one 831-line file"
      rationale: "Instructions forbid splitting without guidance"
      fallback_if_wrong: "Move layout pieces and step renderers into sibling files"
  acceptance_test_concern: "The 'not sent' check only looks for the word 'sent'; test 3 depends on a single status region; the booked-times fixture is HH:mm only; the manual 375px keyboard entry was not run."
  retry_history:
    - attempt: 1
      failure: "Failed to resolve import \".\" (expected red phase)"
      fix: "Implemented BookingWizard and the /book page"
    - attempt: 2
      failure: "TypeError: localStorage.clear is not a function (Node v25 localStorage global)"
      fix: "Test installs in-memory Storage with vi.stubGlobal"
    - attempt: 3
      failure: "ESLint: 3 padding-line-between-statements errors"
      fix: "eslint --fix and prettier --write; re-ran lint, format and tests"
```
