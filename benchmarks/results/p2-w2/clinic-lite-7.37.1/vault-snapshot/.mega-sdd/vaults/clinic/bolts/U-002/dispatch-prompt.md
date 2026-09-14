═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-002
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-002

UNIT: U-002 "Implement the bookable slot rules library"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-002
title: Implement the bookable slot rules library
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:70, PRD/prd-clinic.md:147, PRD/prd-clinic.md:148, PRD/prd-clinic.md:206]
task_type: create
grounding_confidence: LOW
risk: low
module: M-clinic-core
depends_on: []
target_files:
  - path: src/features/appointments/utils/slots/index.ts
    operation: create
  - path: src/features/appointments/utils/slots/index.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "generates 28 fifteen-minute slots from 09:00 to 16:45 without lunch"
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "narrows slots to the doctor working hours within the global bounds"
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "hides booked start times from the available slots"
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "rejects past dates and weekends"
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "hides slots earlier than now on the current day"
binding_refs: [OQ-CN-1, OQ-CN-3, OQ-DM-1]
---

# Unit U-002 — Implement the bookable slot rules library

## Goal

Provide pure, dependency-free functions that turn BR-001 / BR-002 into the list of bookable 15-minute slots for a doctor and date, used by the patient picker and the staff views.

## Context (read first)

BR-001 (PRD §5) fixes bookable hours at 09:00–17:00 in 15-minute slots with no slots during the 12:00–13:00 lunch break, and a doctor's `working_hours` may only narrow that window. F-U-001 steps 3–4 disable past, weekend and out-of-hours choices and hide taken slots, and AC-002 requires the picker to hide booked slots (the database-level rejection of a concurrent insert is upstream, OQ-AR-1). The slot picker (U-012) and both staff views (U-016, U-019) import these helpers, so the rules live in exactly one place.

## Anchors

- src/libs/api/query-params/index.ts — pure helper module with a co-located `index.test.ts`; mirror this folder-with-test shape
- src/libs/api/query-params/index.test.ts — Vitest style used for pure helpers

## Claims

- C-U002-01 "pure helpers with tests live in a folder with index.ts and index.test.ts" — expect: src/libs/api/query-params/index.test.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/utils/slots/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep the module free of React, network and date-library imports so it stays a pure function module (constitution A-002)
  Source: constitution.md §A A-002
- MUST treat 09:00–17:00 and the 12:00–13:00 lunch break as hard outer bounds that working hours can only narrow (source: PRD §5 BR-001)
  Source: PRD §5 BR-001

## Anti-patterns

- Don't convert between timezones — the clinic timezone is open (OQ-CN-3); work on `YYYY-MM-DD` dates and `HH:mm` times.
- Don't mark the slots after a longer service as taken — whether a long visit blocks following slots is open (OQ-DM-1); only booked start times are hidden.

## Implementation steps

1. Create `src/features/appointments/utils/slots/index.ts` exporting `BOOKING_HOURS` (`{ start: '09:00', end: '17:00', lunchStart: '12:00', lunchEnd: '13:00', slotMinutes: 15 }`) and `generateDaySlots(window?: { start: string; end: string } | null): string[]`, which walks from 09:00 in 15-minute steps, skips every start inside 12:00–13:00, stops before 17:00, and when a window is given clamps it into the global bounds before filtering — so an out-of-range window never adds slots.
2. Add `isBookableDate(date: string, today: string): boolean` (false for any date before `today` and for Saturdays and Sundays, parsing `YYYY-MM-DD` as a local calendar date without timezone math) and `availableSlots({ date, today, bookedStartTimes, window, now })`, which returns `generateDaySlots(window)` minus `bookedStartTimes`, returns an empty list for a non-bookable date, and on the current day (`date === today`) also drops slots whose start is not later than `now` (`HH:mm`).
3. Write `index.test.ts` with the five tests named exactly as the acceptance_test `expects` strings, including the adversarial cases: a working-hours window wider than 09:00–17:00 still yields no slot before 09:00 or at/after 17:00, and no generated slot ever falls between 12:00 and 12:45.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-3 — "today" and "now" are passed in by the caller; the timezone that produces them is not decided here.
- TBD: OQ-DM-1 — only booked start times are removed.

## Out of scope

- Rendering the picker — U-012
- Fetching booked start times — U-009

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-002
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted: (none)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - file src/features/appointments/utils/slots/index.ts MUST exist after bolt
    - MUST keep the module free of React, network and date-library imports so it stays a pure function module (constitution A-002)
    - MUST treat 09:00–17:00 and the 12:00–13:00 lunch break as hard outer bounds that working hours can only narrow (source: PRD §5 BR-001)
```

## Acceptance-test provenance NOTE

> NOTE: This unit's `acceptance_test` has weak blind-spot coverage
> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that
> wrote the unit body — the test may inherit the same blind spots as the spec
> and fail to catch behavioral bugs your implementation introduces.
>
> If your implementation passes this test but feels under-validated:
>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`
>     explaining what you suspect the test might miss
>   - Propose 1-2 additional assertions you'd add to strengthen coverage
>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested

## Anti-context (negative space = freedom + protection)

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

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §A-002: A module with its own test lives in a folder — `foo/index.ts` + `foo/index.test.ts`; files with no test stay flat (source: CLAUDE.md:25)

(selector: `\b[A-F]-\d{3}\b` cited in U-002.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

## Validation hints (specific, not vague)

After implementation, run:
```bash
pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose
```
Expected output pattern: generates 28 fifteen-minute slots from 09:00 to 16:45 without lunch
```bash
pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose
```
Expected output pattern: narrows slots to the doctor working hours within the global bounds
```bash
pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose
```
Expected output pattern: hides booked start times from the available slots
```bash
pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose
```
Expected output pattern: rejects past dates and weekends
```bash
pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose
```
Expected output pattern: hides slots earlier than now on the current day

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 8804 bytes (cap 12288)
consumed_t2: 1355 bytes (cap 10240, hard 12288)
total: 10159 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 14888    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - (none)
instruction_to_subagent:
  If your self-assessment relies on a truncated section listed above, mark its
  confidence MEDIUM (not HIGH) and note the truncation in bolt-report.md.
  Truncation is transparency, not failure.
```

═══════════════════════════════════════════
TIER 3 — Reference-on-demand (NOT embedded; use Read tool)
═══════════════════════════════════════════

- Full upstream bolt-reports: `/Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic/bolts/U-XXX/bolt-report.md`
- Full constitution: `/Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic/constitution.md`
- Full framework pack: `/Users/<user>/.claude/plugins/cache/mega-sdd/mega-sdd/7.37.1/references/framework-conventions/<pack>.md`

═══════════════════════════════════════════
PROVENANCE — omissions (audit trail; NOT part of the T1/T2 byte accounting)
═══════════════════════════════════════════

Every absent or unresolvable input is recorded here rather than invented (invariant #5).

- t1.reuse_index_line: reuse-index.yaml absent at ./.mega-sdd/codebase/reuse-index.yaml — the Iron Rule 4 pointer line is NOT emitted for a file that does not exist (run scan-codebase to produce the index)
- t1.anti_context.do_not_modify.data_mutation_policy: no <kb>/99-rebuild-architecture/data-mutation-policy.md under /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3 (searched .mega-sdd/, docs/, old-reference/ knowledge-base roots) — this source contributes nothing; the unit `## Hard rules` half is NOT relabelled to stand in for it
- t1.anti_context.do_not_modify: neither source produced an entry (data-mutation-policy.md [LOCKED] rows nor the unit's `## Hard rules` DO NOT/MUST NOT/NEVER modify lines) — line omitted
- depends_on_summaries: unit has no depends_on entries
- framework_pack_rules: no pack rule path_glob matched this unit's target_files (chain: next.md _universal.md) — the 'keep top 1' floor is vacuous on an empty set, no rule invented
- reuse_slice: reuse-index.yaml absent at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/reuse-index.yaml (the T1 pointer line is omitted too)
- symbol_slice: no indexed symbol in or beside target_files
- starterkit_slice: no starterkit-context.yaml at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice: unit is not ui_bearing (no target_files path matched the pack view_glob or any universal frontend shape)
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- design_slice_path: unit is not ui_bearing, so no design lens is dispatched for it — no lens-input file is written and the `design_slice_path` key is ABSENT (a rubric with no reader is a cost, not a contribution)
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
