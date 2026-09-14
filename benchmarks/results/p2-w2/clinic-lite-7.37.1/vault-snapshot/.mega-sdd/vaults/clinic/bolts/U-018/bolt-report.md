---
unit: U-018
status: success
attempted_at: 2026-09-14T14:57:12+00:00
duration_seconds: 872192
commits: [d1433eecb98ccc06dfae302d302d94d8845e10d1, f1c0025869872bc1919e52352a8f7598b2c4c5ab, 6bf6e1d1ce6edef834f88fca0e63f4d40562ef33]
files_touched: [src/features/appointments/components/WalkInDialog/index.test.tsx, src/features/appointments/components/WalkInDialog/index.tsx]
tests_run: ["pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"]
test_results: "0 acceptance entries passed / 6 not passing (see acceptance.json)"
retries: 0
target_hashes:
  src/features/appointments/components/WalkInDialog/index.tsx: 9e6af444a775f36c568d94ce774d08cbf71322f63b1d468e76d5ad7b45161686
  src/features/appointments/components/WalkInDialog/index.test.tsx: 759bf0ab85aea84cf30bee64d1cb7c7636ce908476c3d61742bf773160486665
---

# Bolt Report — U-018

## Summary
(see implementer report)

## Review panel
- Tier: **standard** · signals_fired: ['risk_field'] · lenses: spec, quality, standards · implementer model routing: inherit (session model)
- L0: run-code-gates.sh --write per unit commit (d1433ee, f1c0025, 6bf6e1d) — no blocking finding
- Ledger `findings.json` (merge-panel-findings.sh): attempt 1 · gate clear · open 0 · advisory 6 · resolved 0

| id | severity | file:line | lens | status | title |
|---|---|---|---|---|---|
| F-1 | Important | src/features/appointments/components/WalkInDialog/index.tsx:175 | quality | advisory | duplicate: doctor select copied from ReassignDialog |
| F-2 | Important | src/features/appointments/components/WalkInDialog/index.test.tsx:191 | quality | advisory | No test covers the submit-time off-grid guard (OFF_GRID_TIME_ERROR) |
| F-3 | Minor | src/features/appointments/components/WalkInDialog/index.tsx:372 | quality | advisory | same two error lines copied into both non-override branches |
| F-4 | Minor | src/features/appointments/components/WalkInDialog/index.test.tsx:229 | quality | advisory | The fix commit's missing-date error is untested |
| F-5 | Minor | src/features/appointments/components/WalkInDialog/index.tsx:174 | quality | advisory | two-column grid sx literal repeated 3 times |
| F-6 | Minor | src/features/appointments/components/WalkInDialog/index.tsx:214 | design | advisory | Doctor/service selects have no explicit empty-list state |

## Post-flight
- Hard rules: postflight.json status **pass** (DO_NOT_ADD_DEPS=pass, FILE_PRESENCE_RULE=pass)
- Acceptance: acceptance.json status **pass** (0/6 executed entries pass)
- ✓ Drift check: clean (lite lane — no binding.md anchors; no LOCKED entities in the vault)

## Rollback hints
```yaml
- step_id: step-1-test
  step_type: file_created
  evidence: "src/features/appointments/components/WalkInDialog/index.test.tsx (365 lines)"
  compensating_action: "git rm src/features/appointments/components/WalkInDialog/index.test.tsx"
  idempotent: true
- step_id: step-2-component
  step_type: file_created
  evidence: "src/features/appointments/components/WalkInDialog/index.tsx (509 lines)"
  compensating_action: "git rm src/features/appointments/components/WalkInDialog/index.tsx"
  idempotent: true
- step_id: step-3-commit
  step_type: git_commit
  evidence: "d1433eecb98ccc06dfae302d302d94d8845e10d1 feat(U-018)"
  compensating_action: "git revert --no-edit d1433eecb98ccc06dfae302d302d94d8845e10d1"
  idempotent: false
- step_id: step-4-fix-commit
  step_type: git_commit
  evidence: "fc585a39c329cb037d024a5e562608023d0e6896 fix(U-018): render errors.date in the no-doctor branch"
  compensating_action: "git revert --no-edit fc585a39c329cb037d024a5e562608023d0e6896"
  idempotent: false
```

```yaml
bolt_self_report:
  model_used: "Opus 5"
  confidence: 0.85
  certain_decisions:
    - "bookingChannel 'staff' is hard-coded in the submit payload; override is always sent as a boolean"
    - "Override on replaces SlotPicker with its own date field plus a type='time' field, so exactly one date input is mounted"
    - "The chosen time is cleared on every override toggle and on doctor change while override is off"
    - "The form uses noValidate so zod produces every error message"
  uncertain_decisions:
    - decision: "Submit-time check uses availableSlots rather than generateDaySlots"
      rationale: "Matches what SlotPicker offers and blocks a slot that became booked after it was picked"
      fallback_if_wrong: "Check against generateDaySlots(workingHours) only"
    - decision: "The slot grid is shown only after a doctor is chosen"
      rationale: "Availability is per doctor"
      fallback_if_wrong: "Always render SlotPicker, with isLoading while no doctor is chosen"
    - decision: "Override-mode date field has no weekend or past-date restriction"
      rationale: "The override skips booking restrictions; the spec defines no date rule for emergencies"
      fallback_if_wrong: "Add min={today} to the override date field"
  acceptance_test_concern: "The submit-time 'slot no longer free' check is unreachable through the UI and untested; availability not fetched while override is on is not asserted; the non-receptionist 403 path is untested."
  retry_history:
    - attempt: 1
      failure: "Failed to resolve import '.' (expected red phase)"
      fix: "Implemented WalkInDialog/index.tsx"
    - attempt: 2
      failure: "Review found errors.date had no render path in the no-doctor branch"
      fix: "Added the FormHelperText line; follow-up commit fc585a3"
```
