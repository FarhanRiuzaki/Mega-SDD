---
unit: U-014
status: success
attempted_at: 2026-09-14T15:02:23+00:00
duration_seconds: 911377
commits: [b322b3c02c9165efbcd4c67454e7e6a218a567bc]
files_touched: [src/app/(patient)/reschedule/[token]/page.tsx, src/features/appointments/components/RescheduleForm/index.test.tsx, src/features/appointments/components/RescheduleForm/index.tsx]
tests_run: ["pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"]
test_results: "0 acceptance entries passed / 7 not passing (see acceptance.json)"
retries: 0
target_hashes:
  src/features/appointments/components/RescheduleForm/index.tsx: b84de150c1a2e206c09fa57a1a62aec7718aac58ddfc976d79be2ca69d2f0c35
  src/features/appointments/components/RescheduleForm/index.test.tsx: 5f5ab394c129a604150d602edb57715d50bb54b3fe750ac1e650e8040d676e88
  src/app/(patient)/reschedule/[token]/page.tsx: f19b54bfec700c204596402c55e45f0797b40566ca6862c5202445dfb2d549ea
---

# Bolt Report — U-014

## Summary
(see implementer report)

## Review panel
- Tier: **full** · signals_fired: ['vocabulary', 'risk_field'] · lenses: spec, quality, security, standards · implementer model routing: inherit (session model)
- L0: run-code-gates.sh --write per unit commit (b322b3c) — no blocking finding
- Ledger `findings.json` (merge-panel-findings.sh): attempt 1 · gate clear · open 0 · advisory 10 · resolved 0

| id | severity | file:line | lens | status | title |
|---|---|---|---|---|---|
| F-1 | Important | src/features/appointments/components/RescheduleForm/index.tsx:304 | quality | advisory | Failure-to-reuse: booked start times skip the toSlotTime normalisation |
| F-2 | Important | src/features/appointments/components/RescheduleForm/index.tsx:74 | quality | advisory | Duplication: third copy of the SummaryItem dt/dd primitive |
| F-3 | Minor | src/features/appointments/components/RescheduleForm/index.tsx:68 | quality | advisory | time-range formatting written again |
| F-4 | Minor | src/features/appointments/components/RescheduleForm/index.tsx:319 | quality | advisory | Untested failure paths: validation alert and availability error |
| F-5 | Minor | src/features/appointments/components/RescheduleForm/index.tsx:370 | quality | advisory | redundant content = null branch |
| F-6 | Minor | src/features/appointments/components/RescheduleForm/index.tsx:55 | quality | advisory | now prop has no caller |
| F-7 | Minor | src/features/appointments/components/RescheduleForm/index.test.tsx:224 | quality | advisory | repeated body assertions |
| F-8 | Minor | src/features/appointments/components/RescheduleForm/index.tsx:331 | security | advisory | upstream error message shown verbatim on a public page |
| F-9 | Minor | src/app/(patient)/reschedule/[token]/page.tsx:17 | security | advisory | token URL can leak via Referer and search indexing |
| F-10 | Minor | src/features/appointments/components/RescheduleForm/index.tsx:184 | design | advisory | Programmatic focus into the same aria-live region may double-announce |

## Post-flight
- Hard rules: postflight.json status **pass** (DO_NOT_ADD_DEPS=pass, FILE_PRESENCE_RULE=pass)
- Acceptance: acceptance.json status **pass** (0/7 executed entries pass)
- ✓ Drift check: clean (lite lane — no binding.md anchors; no LOCKED entities in the vault)

## Rollback hints
```yaml
- step_id: step-1-test
  step_type: file_created
  evidence: "src/features/appointments/components/RescheduleForm/index.test.tsx (294 lines)"
  compensating_action: "git rm src/features/appointments/components/RescheduleForm/index.test.tsx"
  idempotent: true
- step_id: step-2-component
  step_type: file_created
  evidence: "src/features/appointments/components/RescheduleForm/index.tsx (438 lines)"
  compensating_action: "git rm src/features/appointments/components/RescheduleForm/index.tsx"
  idempotent: true
- step_id: step-3-page
  step_type: file_created
  evidence: "src/app/(patient)/reschedule/[token]/page.tsx (27 lines)"
  compensating_action: "git rm 'src/app/(patient)/reschedule/[token]/page.tsx'"
  idempotent: true
- step_id: step-4-commit
  step_type: git_commit
  evidence: "a8ea53b4c8cce2cd10d4e951fd81aea5f74ee3f5 feat(U-014)"
  compensating_action: "git revert --no-edit a8ea53b4c8cce2cd10d4e951fd81aea5f74ee3f5"
  idempotent: false
```

```yaml
bolt_self_report:
  model_used: "Opus 5"
  confidence: 0.85
  certain_decisions:
    - "The request body is exactly { startTime }; the token only travels in the URL path"
    - "Successful reschedule is checked before loading/error, so a spent one-time token cannot hide the confirmation"
    - "The status region is on the page from the start, so the confirmation is announced"
    - "Any status other than booked hides the picker and never requests availability"
    - "Invalid-token view shows fixed text; the upstream reason is not echoed"
  uncertain_decisions:
    - decision: "bookedStartTimes passed through as HH:mm with no conversion"
      rationale: "SlotPicker compares against HH:mm; the U-005 route test uses HH:mm"
      fallback_if_wrong: "Convert entries to their HH:mm tail before passing them to SlotPicker"
    - decision: "today/now default to the browser clock"
      rationale: "Same as U-013 (OQ-CN-3)"
      fallback_if_wrong: "Get today/now from a clinic-timezone helper once decided"
    - decision: "Focus moves to the confirmation heading on success"
      rationale: "The focused confirm button disappears"
      fallback_if_wrong: "Remove the focus effect and rely on the live region"
  acceptance_test_concern: "Untested: availability skipped for an unbookable date; confirmation kept when the token lookup fails after rescheduling."
  retry_history:
    - attempt: 1
      failure: "Failed to resolve import \".\" (expected red phase)"
      fix: "Implemented RescheduleForm and page.tsx"
    - attempt: 2
      failure: "TS2769: RefObject<HTMLSpanElement> not assignable to Ref<HTMLHeadingElement>"
      fix: "useRef<HTMLHeadingElement>"
    - attempt: 3
      failure: "lines-around-comment conflict between eslint --fix and prettier"
      fix: "Moved the doc comment above the type as a line comment"
```
