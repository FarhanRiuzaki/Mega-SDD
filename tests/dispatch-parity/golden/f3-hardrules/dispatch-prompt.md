═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-003
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-003

UNIT: U-003 "Refactor the interest calculator with locked signatures"
SCOPE: S-01 (Core) — framework: _universal.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-003
title: Refactor the interest calculator with locked signatures
task_type: modify
scope: S-01
scope_name: Core
module: core
risk: high
status: pending
target_files:
  - path: app/Services/InterestCalculator.php
    operation: modify
  - path: app/Services/RateTable.php
    operation: modify
  - path: tests/Unit/InterestCalculatorTest.php
    operation: create
acceptance_test:
  - command: "run the interest calculator unit test"
    _authored_by: adversarial-reviewed
---

## Intent

Refactor the interest calculator to read rates from RateTable while keeping
every public signature stable.

## Hard rules

- DO NOT modify app/Models/Account.php
- DO NOT modify config/banking.php
- SIGNATURE LOCK: InterestCalculator::calculate(float $principal, int $days): float
- Citation: 05-decisions.md D-004

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v@VER@)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-003
  claims: (none cited)
  anchors_consulted: (none)
  hard_rules_active:
    - DO NOT modify app/Models/Account.php
    - DO NOT modify config/banking.php
    - SIGNATURE LOCK: InterestCalculator::calculate(float $principal, int $days): float
    - Citation: 05-decisions.md D-004
```

Reuse index: .mega-sdd/codebase/reuse-index.yaml — your PRIMARY reuse lookup
surface (Iron Rule 4): scan the FULL index with Read/Grep before writing any
new capability; reuse_candidates below is only a hint.

## Anti-context (negative space = freedom + protection)

DO NOT MODIFY:
  - app/Models/Account.php  (source: U-003.md `## Hard rules`)
  - config/banking.php  (source: U-003.md `## Hard rules`)
DO NOT WRITE:
  - Tables without `id` primary key (denormalized intermediate tables OK as composite PK)  (from _universal.md §Forbidden patterns)
  - Tables without `created_at` + `updated_at` timestamps (unless explicitly immutable like audit logs)  (from _universal.md §Forbidden patterns)
  - VARCHAR(255) used as default type for everything (use proper sized/typed columns)  (from _universal.md §Forbidden patterns)
  - Comma-delimited values in single columns (use junction tables)  (from _universal.md §Forbidden patterns)
  - Date/time stored as VARCHAR/INT (use proper TIMESTAMP/DATETIME types)  (from _universal.md §Forbidden patterns)
  - Foreign keys without explicit constraint (`ON DELETE`/`ON UPDATE` defined)  (from _universal.md §Forbidden patterns)
DO NOT COMMIT IF: any `acceptance_test` command in this unit fails; any `## Hard rules` line above is violated; a modified file is missing its provenance trailer

═══════════════════════════════════════════
TIER 2 — Conditional context (target ≤10KB total)
═══════════════════════════════════════════

## Validation hints (specific, not vague)

After implementation, run:
```bash
run the interest calculator unit test
```

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: @N@ bytes (cap 12288)
consumed_t2: 119 bytes (cap 10240, hard 12288)
total: 3756 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: @N@     bytes  # THIS WHOLE FILE. The difference from `total` is
                            # exactly four blocks plus the blank lines joining
                            # them: the TIER 2 banner, this tracker block, the
                            # TIER 3 pointer list and the PROVENANCE appendix.
                            # The title banner and the TIER 1 banner are NOT in
                            # that gap — they are already inside consumed_t1.
                            # None of the four is budgeted and none is ever
                            # truncated. Reason about truncation from the list
                            # below, not from either number.
truncations_applied:
  - (none)
instruction_to_subagent:
  If your self-assessment references information that came from a truncated
  section (listed above), mark its confidence as MEDIUM (not HIGH) and note
  the truncation explicitly in your bolt-report.md self-assessment section.
  Truncation is NOT a failure — it's transparency.
```

═══════════════════════════════════════════
TIER 3 — Reference-on-demand (NOT embedded; use Read tool)
═══════════════════════════════════════════

- Full upstream bolt-reports: `@PROJ@/.mega-sdd/vaults/v1/bolts/U-XXX/bolt-report.md`
- Full constitution: `@PROJ@/.mega-sdd/vaults/v1/constitution.md`
- Full KB domain files: `.mega-sdd/knowledge-base/10-domains/`
- Full memory tables: `@PROJ@/.mega-sdd/memory/`
- Full framework pack: `@PLUGIN@/references/framework-conventions/<pack>.md`

═══════════════════════════════════════════
PROVENANCE — omissions (audit trail; NOT part of the T1/T2 byte accounting)
═══════════════════════════════════════════

Every absent or unresolvable input is recorded here rather than invented (invariant #5).

- provenance.vault_sha256: vault.json absent or unreadable at @PROJ@/.mega-sdd/vaults/v1/vault.json — value OMITTED, never placeholder-filled
- t1.acceptance_test_note: _authored_by=adversarial-reviewed has strong provenance — NOTE omitted per bolt-dispatch-prompt.md:96-97
- t1.anti_context.do_not_modify.data_mutation_policy: no <kb>/99-rebuild-architecture/data-mutation-policy.md under @PROJ@ (searched .mega-sdd/, docs/, old-reference/ knowledge-base roots) — this source contributes nothing; the unit `## Hard rules` half is NOT relabelled to stand in for it
- depends_on_summaries: unit has no depends_on entries
- framework_pack_rules: no pack rule path_glob matched this unit's target_files (chain: _universal.md) — the 'keep top 1' floor is vacuous on an empty set, no rule invented
- constitution_clauses: no constitution.md in @PROJ@/.mega-sdd/vaults/v1 (absence IS the --no-constitution opt-out)
- kb_anti_patterns: the join key 'domain tags' (context-enrichment.md:76) is a phantom field — no unit schema, validator or writer defines it; substituting module:/vault_source would be a fabricated inclusion. Section omitted until the spec designates a join key.
- historical_memory: no outcomes.md run passed the relevance filter (unit id / target-file basename overlap), no matching bolt-outcomes.json entry and no eligible instinct. Memory files are gitignored-by-default post-run artifacts, so absent is the normal state; an unfiltered dump under a header that says 'relevant' is not the alternative.
- reuse_slice: reuse-index.yaml absent at @PROJ@/.mega-sdd/codebase/reuse-index.yaml (the UNCONDITIONAL T1 path line still ships)
- symbol_slice: symbol-index.json absent at @PROJ@/.mega-sdd/codebase/symbol-index.json (run scripts/build-symbol-index.sh; exit 3 there = ast-grep not installed)
- starterkit_slice: no starterkit-context.yaml at @PROJ@/.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice: unit is not ui_bearing (no target_files path matched the pack view_glob or any universal frontend shape)
- confidence_labels: unit has no binding_refs (greenfield / standalone generate-units)
- design_slice_path: unit is not ui_bearing, so no design lens is dispatched for it — no lens-input file is written and the `design_slice_path` key is ABSENT (a rubric with no reader is a cost, not a contribution)
