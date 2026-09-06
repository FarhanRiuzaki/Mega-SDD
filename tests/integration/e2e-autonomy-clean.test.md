# E2E: Autonomy Layer — Full Pipeline Clean Run (Iter 4)

> **Prose walkthrough, not CI (note added 7.29.1).** The `./fixtures/e2e-*-fixture/` paths are illustrative — they were never committed; run the same steps with your own PRD. The typed `/mega-sdd:auto` form was removed at 6.0.0: use `/mega-sdd <prd> --deep` and `/mega-sdd --resume`.

End-to-end integration test for `--deep` mode running pipeline-end with NO blockers. Validates auto-continue + progress indication + handoff YAML protocol.

## Fixture

**Repo state**: Fresh Laravel project at `./fixtures/e2e-autonomy-clean-fixture/`:
- `composer.json` + `package.json` present
- Empty `app/` directory (no existing code; greenfield-ish brownfield)
- `prd-leave-management.md` PRD describing a new leave management module
- No existing vault

**Expected behavior**: PRD is clean (no contradictions, no missing critical sections). Auto-classifier tags most OQs as `tech` with `scan` resolution. Binding finds NO conflicts. No Hard rule violations. Full chain runs end-to-end.

## Test steps

### Step 1: Invocation
**Run:** `/mega-sdd ./fixtures/e2e-autonomy-clean-fixture/prd-leave-management.md --deep`

**Expect**:
- Input detected as PRD (`.md` extension)
- Chain proposed: 5 phases — `generate-intent → scan-codebase → bind-codebase → generate-units → execute-bolts`
- Single upfront `AskUserQuestion`: "Run all 5 phases end-to-end? [Run / Edit / Cancel]"

### Step 2: User confirms (Run)

**Expect** in chat:
```
▶ Phase 1 of 5: invoking generate-intent (./fixtures/e2e-autonomy-clean-fixture/prd-leave-management.md --auto)
... (generate-intent output)
✓ Phase 1 of 5: generate-intent → status: completed, items: 12 OQs, blocked: 0
   (12 OQs: 8 tech-scan, 2 tech-recommend, 2 business-blocking)
▶ Phase 2 of 5: invoking scan-codebase (./ --auto)
... (scan output)
✓ Phase 2 of 5: scan-codebase → status: completed
▶ Phase 3 of 5: invoking bind-codebase (./vault-path/ --auto)
... (binding output)
✓ Phase 3 of 5: bind-codebase → status: completed, items: 24 claims, blocked: 0
   (Tech-scan auto-resolved: 8; tech-recommend surfaced for review: 2)
▶ Phase 4 of 5: invoking generate-units (./vault-bound/ --auto)
... (units output)
✓ Phase 4 of 5: generate-units → status: completed, items: 7 units, blocked: 0
   (7 units: 7 create, 0 verify — greenfield-ish; no existing implementation)
▶ Phase 5 of 5: invoking execute-bolts (--all --parallel --auto)
... (bolt execution per unit, including pre/post-flight Hard rule validation)
✓ Phase 5 of 5: execute-bolts → status: completed, items: 7 units, blocked: 0

📋 Final summary:
   Phases completed: 5 of 5
   Phases paused: 0
   Phases halted: 0
   Artifacts produced:
     - /path/to/vault/
     - /path/to/codebase-map.md
     - /path/to/binding.md
     - /path/to/vault-bound/
     - /path/to/units/U-001.md ... U-007.md
     - /path/to/bolts/U-001/ ... U-007/

Pipeline complete. Suggested next: /mega-sdd:detect-drift to verify all bolts honored the vault.
```

### Step 3: Artifact verification

After chain completes, the filesystem should have:
- Vault at `./fixtures/e2e-autonomy-clean-fixture/docs/mega-sdd/vaults/leave-management/`
- 7 unit files at `<vault>/units/U-*.md`
- 7 bolt report dirs at `<vault>/bolts/U-*/`
- Each unit's `task_type: create`
- Each unit's `## Anchors` may be empty (greenfield) or cite generic Laravel patterns
- Each unit's `## Hard rules` parses (or is empty)
- Each bolt's `preflight.json` + `postflight.json` exists
- All acceptance tests pass

## Validation checks

### V1: Handoff YAML emitted by each skill
- Verify chat output (or skill artifact) contains `handoff:` YAML block at end of each phase
- `emitted_by` matches the invoking skill
- `status: completed` for all 5 phases

### V2: Auto-continue without user intervention
- User confirms ONCE (step 2); no additional prompts during phases 2-5
- Each phase starts immediately after the previous emits `status: completed`

### V3: Progress indication
- Every phase emits `▶ Phase N of M: invoking …` before invocation
- Every phase emits `✓ Phase N of M: … → status: completed, …` after
- Phase numbers correctly reflect chain position (1 of 5, 2 of 5, etc.)

### V4: Halt protocol preserved (negative validation)
- No blocker YAMLs surfaced (chain is clean by construction)
- No `--skip-preflight` bypass (Hard rules pre/post-flight ran on each unit; nothing violated)

### V5: Backward compatibility (negative validation)
- Existing `/mega-sdd:orchestrate-flow` (no --deep) runs would still produce 3-skill chain on the same fixture
- Standalone `/mega-sdd:generate-intent ./prd-leave-management.md` runs would NOT emit handoff YAML and produces same output as v1.3 vault

## Pass criteria

Steps 1-3 succeed in a fresh run on the fixture. All 5 V-checks pass. Wall-clock time: ≤ 10 minutes (depends on test suite size).
