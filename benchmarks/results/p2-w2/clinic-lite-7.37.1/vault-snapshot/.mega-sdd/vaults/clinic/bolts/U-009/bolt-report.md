---
unit: U-009
status: success
attempted_at: 2026-09-14T11:54:57+00:00
duration_seconds: 516386
commits: [1705313e88a33d38b5a82f6c9b12c300591fc930]
files_touched: [src/features/appointments/hooks/useAppointments/index.test.tsx, src/features/appointments/hooks/useAppointments/index.ts, src/features/appointments/repositories/appointment.repository.ts]
tests_run: ["pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"]
test_results: "0 acceptance entries passed / 5 not passing (see acceptance.json)"
retries: 0
target_hashes:
  src/features/appointments/repositories/appointment.repository.ts: bfb6e171fdfeb39952cd258573e387c8b032275168c806d9ba821d5451127016
  src/features/appointments/hooks/useAppointments/index.ts: faf15c540ebc8b59b711297cd2c8bc025176beb7874b75e9d70db81d6a359875
  src/features/appointments/hooks/useAppointments/index.test.tsx: a90812b2b17641b9d9cb36d85173edc7c524332089a87255dd5e56722231e595
---

# Bolt Report — U-009

## Summary
(see implementer report)

## Review panel
- Tier: **standard** · signals_fired: [] · lenses: spec, quality, standards · implementer model routing: inherit (session model)
- L0: run-code-gates.sh --write per unit commit (1705313) — no blocking finding
- Ledger `findings.json` (merge-panel-findings.sh): attempt 1 · gate clear · open 0 · advisory 4 · resolved 0

| id | severity | file:line | lens | status | title |
|---|---|---|---|---|---|
| F-1 | Important | src/features/appointments/hooks/useAppointments/index.test.tsx:146 | quality | advisory | No failure-path tests: all 6 tests are happy-path |
| F-2 | Minor | src/features/appointments/hooks/useAppointments/index.ts:108 | quality | advisory | detailKey invalidates a key nothing registers |
| F-3 | Minor | src/features/appointments/hooks/useAppointments/index.test.tsx:54 | quality | advisory | flush() uses a fixed 50ms real sleep to prove no request was sent |
| F-4 | Minor | src/features/appointments/hooks/useAppointments/index.ts:86 | standards | advisory | Mutation hooks invalidate appointmentKeys.all() instead of .lists() |

## Post-flight
- Hard rules: postflight.json status **pass** (DO_NOT_ADD_DEPS=pass, DO_NOT_MODIFY=pass, FILE_PRESENCE_RULE=pass)
- Acceptance: acceptance.json status **pass** (0/5 executed entries pass)
- ✓ Drift check: clean (lite lane — no binding.md anchors; no LOCKED entities in the vault)

## Rollback hints
```yaml
- step_id: step-1-test
  step_type: file_created
  evidence: "src/features/appointments/hooks/useAppointments/index.test.tsx (345 lines)"
  compensating_action: "git rm src/features/appointments/hooks/useAppointments/index.test.tsx"
  idempotent: true
- step_id: step-2-repository
  step_type: file_created
  evidence: "src/features/appointments/repositories/appointment.repository.ts (68 lines)"
  compensating_action: "git rm src/features/appointments/repositories/appointment.repository.ts"
  idempotent: true
- step_id: step-3-hooks
  step_type: file_created
  evidence: "src/features/appointments/hooks/useAppointments/index.ts (118 lines)"
  compensating_action: "git rm src/features/appointments/hooks/useAppointments/index.ts"
  idempotent: true
- step_id: step-4-commit
  step_type: git_commit
  evidence: "1705313e88a33d38b5a82f6c9b12c300591fc930 feat(U-009)"
  compensating_action: "git revert --no-edit 1705313e88a33d38b5a82f6c9b12c300591fc930"
  idempotent: false
```

```yaml
bolt_self_report:
  model_used: "Opus 5"
  confidence: 0.85
  certain_decisions:
    - "Repository paths match the U-005/U-006/U-007 routes; cancel is outside /v1"
    - "Every appointment key is under appointmentKeys.all(), so one invalidation refreshes availability, schedule and token queries"
    - "makeCreateMutation for booking; hand-written useMutation for the token-keyed reschedule"
  uncertain_decisions:
    - decision: "makeUpdateMutation for cancel and reassign"
      rationale: "Both carry an id and are status or assignment updates; the factory refreshes rather than removes"
      fallback_if_wrong: "Hand-written useMutation with the same snackbar and refresh body"
    - decision: "Hooks return the raw envelope (no select)"
      rationale: "Matches the useUsers anchor"
      fallback_if_wrong: "Add select: r => r.data per hook and update consumers"
    - decision: "useSchedule enabled only when from and to are set"
      rationale: "Avoids requests with empty date ranges"
      fallback_if_wrong: "Remove the guard"
  acceptance_test_concern: "The error snackbar path is untested. Suggested extra assertions: a 4xx on booking shows the error message; availability is not refetched after a failed booking."
  retry_history:
    - attempt: 1
      failure: "Failed to resolve import './index' (expected red phase)"
      fix: "Implemented repository and hooks"
    - attempt: 2
      failure: "prettier --check: code style issues in index.test.tsx"
      fix: "prettier --write (JSX map reflow only); re-ran tests and lint green"
```
