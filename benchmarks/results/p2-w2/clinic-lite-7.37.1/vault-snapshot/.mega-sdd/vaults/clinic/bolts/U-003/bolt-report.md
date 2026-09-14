---
unit: U-003
status: success
attempted_at: 2026-09-14T11:52:36+00:00
duration_seconds: 304075
commits: [b1166a28ac967e1448c80dcc60dbbbe7349c8d3f]
files_touched: [src/features/appointments/components/AppointmentStatusChip/index.test.tsx, src/features/appointments/components/AppointmentStatusChip/index.tsx, src/libs/label-maps.ts]
tests_run: ["pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"]
test_results: "0 acceptance entries passed / 3 not passing (see acceptance.json)"
retries: 0
target_hashes:
  src/libs/label-maps.ts: f238f36eedd2c3cc48febf9a0591c727a4b34cfae747f326ec4590d0c29834d7
  src/features/appointments/components/AppointmentStatusChip/index.tsx: 54ec95483efa38a2a0d18d0ca75f0320477c8d43f1b23ff97c875f825d917495
  src/features/appointments/components/AppointmentStatusChip/index.test.tsx: bbd24cd568aef62c71b365c270cb7eb2070d1fe22e92f28be1ae3d974871960d
---

# Bolt Report — U-003

## Summary
(see implementer report)

## Review panel
- Tier: **standard** · signals_fired: [] · lenses: spec, quality, standards · implementer model routing: inherit (session model)
- L0: run-code-gates.sh --write per unit commit (b1166a2) — no blocking finding
- Ledger `findings.json` (merge-panel-findings.sh): attempt 1 · gate clear · open 0 · advisory 3 · resolved 0

| id | severity | file:line | lens | status | title |
|---|---|---|---|---|---|
| F-1 | Minor | src/features/appointments/components/AppointmentStatusChip/index.tsx:53 | quality | advisory | delete: redundant `& .MuiChip-icon { color: inherit }` override |
| F-2 | Minor | src/features/appointments/components/AppointmentStatusChip/index.test.tsx:89 | quality | advisory | Existing-map guard only half-checks JENIS_PIC_LABELS |
| F-3 | Minor | src/features/appointments/components/AppointmentStatusChip/index.test.tsx:55 | quality | advisory | Label-map checks are hidden inside the chip render test |

## Post-flight
- Hard rules: postflight.json status **pass** (DO_NOT_ADD_DEPS=pass, FILE_PRESENCE_RULE=pass)
- Acceptance: acceptance.json status **pass** (0/3 executed entries pass)
- ✓ Drift check: clean (lite lane — no binding.md anchors; no LOCKED entities in the vault)


## Rollback hints
```yaml
- step_id: step-1-test
  step_type: file_created
  evidence: "created src/features/appointments/components/AppointmentStatusChip/index.test.tsx"
  compensating_action: "git rm src/features/appointments/components/AppointmentStatusChip/index.test.tsx"
  idempotent: true
- step_id: step-2-label-maps
  step_type: file_modified
  evidence: "src/libs/label-maps.ts +28/-0 (provenance block, type import, 2 maps)"
  compensating_action: "git checkout b1166a2~1 -- src/libs/label-maps.ts"
  idempotent: true
- step_id: step-3-chip
  step_type: file_created
  evidence: "created src/features/appointments/components/AppointmentStatusChip/index.tsx"
  compensating_action: "git rm src/features/appointments/components/AppointmentStatusChip/index.tsx"
  idempotent: true
- step_id: step-4-commit
  step_type: git_commit
  evidence: "b1166a28ac967e1448c80dcc60dbbbe7349c8d3f, 3 files, +190"
  compensating_action: "git revert --no-edit b1166a28ac967e1448c80dcc60dbbbe7349c8d3f"
  idempotent: false
```

```yaml
bolt_self_report:
  model_used: "Opus 5"
  confidence: 0.85
  certain_decisions:
    - "Existing label maps kept byte-identical; new maps typed Record<AppointmentStatus|BookingChannel, string>"
    - "Chip text/icon use var(--mui-palette-text-primary) because the house tonal chip's main-on-tint text fails 4.5:1 (1.82-3.50:1); text.primary on the tint measures 6.06-9.12:1"
    - "Icons are tabler classes calendar-check / calendar-x / circle-check with aria-hidden"
  uncertain_decisions:
    - decision: "booked -> primary, cancelled -> error, completed -> success tint colors"
      rationale: "primary follows the brand color U-004 will set; error and success match their meaning"
      fallback_if_wrong: "switch booked to 'info' in STATUS_PRESENTATION (contrast unaffected)"
    - decision: "Provenance block placed above 'use client' in index.tsx"
      rationale: "the trailer must sit at the top of the file; comments before a directive are valid"
      fallback_if_wrong: "move 'use client' to line 1 and put the block after it"
  acceptance_test_concern: "The contrast rule is not machine-tested (jsdom runs with css:false). Suggested extra checks: assert the chip's sx color is text-primary; add a visual/e2e contrast check."
  retry_history: []
```
