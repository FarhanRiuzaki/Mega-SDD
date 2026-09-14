═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-004
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-004

UNIT: U-004 "Make teal-700 the default primary color"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-004
title: Make teal-700 the default primary color
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:115, PRD/prd-clinic.md:116]
task_type: extend
grounding_confidence: LOW
risk: low
module: M-platform
depends_on: []
target_files:
  - path: src/configs/primaryColorConfig.ts
    operation: delete
  - path: src/configs/primaryColorConfig/index.ts
    operation: create
  - path: src/configs/primaryColorConfig/index.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose"
    expects: "uses teal-700 as the default primary color"
  - type: test
    command: "pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose"
    expects: "keeps white-on-primary contrast at or above 4.5 to 1"
  - type: test
    command: "pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose"
    expects: "never uses a raw brand hue as a main color"
binding_refs: [OQ-CN-1]
---

# Unit U-004 — Make teal-700 the default primary color

## Goal

Change the default primary preset to the AA-safe teal-700 `#0E7490` from PRD §8.2, and give the config module its own test by promoting it to a folder.

## Context (read first)

PRD §8.2 sets `--primary` to teal-700 `#0E7490` (5.36:1 with white text) and forbids the raw brand `#0891B2` / `#16A34A` as a primary with white foreground. The theme reads its primary from `settings.primaryColor`, whose default is `primaryColorConfig[2].main` (vendored `settingsContext`), so replacing the third preset changes the product default without touching vendored template files (constitution C-004). The module gains a test, so it moves to `primaryColorConfig/index.ts` (constitution A-002) and every `@configs/primaryColorConfig` import keeps resolving.

## Anchors

- src/configs/primaryColorConfig.ts:1-42 — current preset list; the third entry (`primary-3`, orange `#FFAB1D`) is the default
- src/@core/contexts/settingsContext.tsx:63 — `primaryColor: primaryColorConfig[2].main` (read-only reference; vendored)
- src/components/theme/index.tsx:68-79 — theme derives light/dark from `settings.primaryColor` (read-only reference; vendored)

## Claims

- C-U004-01 "the primary preset module exists as a flat file today" — expect: src/configs/primaryColorConfig.ts — must-exist
- C-U004-02 "the vendored settings context reads the default from preset index 2" — expect: src/@core/contexts/settingsContext.tsx — must-exist
- C-U004-03 "PrimaryColorConfig is the exported preset type" — expect: src/configs/primaryColorConfig.ts:PrimaryColorConfig

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/@core/contexts/settingsContext.tsx
  Source: CLAUDE.md:41 (template internals are vendored) — constitution.md §C C-004
- DO NOT modify src/components/theme/index.tsx
  Source: CLAUDE.md:41 (template internals are vendored) — constitution.md §C C-004
- file src/configs/primaryColorConfig/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep the `PrimaryColorConfig` type export and the default export array shape so existing imports compile (constitution C-004)
  Source: constitution.md §C C-004
- MUST use teal-700 #0E7490 as the default primary and never raw #0891B2 or #16A34A as a main color (constitution F-003)
  Source: constitution.md §F F-003

## Implementation steps

1. Move the contents of `src/configs/primaryColorConfig.ts` to `src/configs/primaryColorConfig/index.ts` (delete the flat file), keeping the `PrimaryColorConfig` type, the five-entry array and the default export exactly as they are except for the third entry.
2. Replace the third entry with `{ name: 'primary-3', light: '#0891B2', main: '#0E7490' }` — the lighter raw brand teal is allowed only as the `light` fill hue per PRD §8.2 — and leave the other four presets untouched.
3. Write `index.test.ts` with the three tests named exactly as the acceptance_test `expects` strings: index 2 `main` is `#0E7490`; a small WCAG relative-luminance helper inside the test computes white-on-`#0E7490` contrast ≥ 4.5; and no entry's `main` equals `#0891B2` or `#16A34A`.

## Migration notes

- **REMOVE**: the flat file `src/configs/primaryColorConfig.ts` (its content moves into the folder module) and the orange values of preset `primary-3`.
- **KEEP**: the `PrimaryColorConfig` type, presets `primary-1`, `primary-2`, `primary-4`, `primary-5`, the array order and the default export.
- **ADD**: `src/configs/primaryColorConfig/index.ts` with preset `primary-3` = teal-700, and `index.test.ts`.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- Browsers holding an old settings cookie keep their saved color until the customizer is reset (existing behavior, themeConfig.ts header comment).

## Out of scope

- Success/accent green-700 theme wiring — would require editing the vendored theme; the status chip (U-003) applies status colors locally
- Typography and radius changes from PRD §8.3

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-004
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted:
    - src/configs/primaryColorConfig.ts:1
    - src/@core/contexts/settingsContext.tsx:63
    - src/components/theme/index.tsx:68
  anchors_verified: 3/3 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - DO NOT modify src/@core/contexts/settingsContext.tsx
    - DO NOT modify src/components/theme/index.tsx
    - file src/configs/primaryColorConfig/index.ts MUST exist after bolt
    - MUST keep the `PrimaryColorConfig` type export and the default export array shape so existing imports compile (constitution C-004)
    - MUST use teal-700 #0E7490 as the default primary and never raw #0891B2 or #16A34A as a main color (constitution F-003)
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

DO NOT MODIFY:
  - src/@core/contexts/settingsContext.tsx  (source: U-004.md `## Hard rules`)
  - src/components/theme/index.tsx  (source: U-004.md `## Hard rules`)
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
- §C-004: Template internals (`src/@core`, `src/@layouts`, `src/@menu`, `src/components/{layout,theme}`) are vendored — extend through `src/components/*`, `src/features/*` and `src/configs/*` (source: CLAUDE.md:41)
- §F-003: The primary color is teal-700 `#0E7490`; raw `#0891B2` / `#16A34A` are never used with white text (source: PRD §8.2)

(selector: `\b[A-F]-\d{3}\b` cited in U-004.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

### Existing symbols (REUSE — extend, don't recreate)

index@8af59196 · 592 symbols · built by scripts/build-symbol-index.sh
- src/configs/primaryColorConfig.ts:1 typescript-type-alias `PrimaryColorConfig` — type PrimaryColorConfig = {
- src/configs/themeConfig.ts:22 typescript-type-alias `Navbar` — type Navbar = {
- src/configs/themeConfig.ts:30 typescript-type-alias `Footer` — type Footer = {
- src/configs/themeConfig.ts:36 typescript-type-alias `Config` — type Config = {

## Validation hints (specific, not vague)

After implementation, run:
```bash
pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose
```
Expected output pattern: uses teal-700 as the default primary color
```bash
pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose
```
Expected output pattern: keeps white-on-primary contrast at or above 4.5 to 1
```bash
pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose
```
Expected output pattern: never uses a raw brand hue as a main color

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 9248 bytes (cap 12288)
consumed_t2: 1803 bytes (cap 10240, hard 12288)
total: 11051 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 15531    bytes  # THIS WHOLE FILE; the gap from `total` is the four
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
- depends_on_summaries: unit has no depends_on entries
- framework_pack_rules: no pack rule path_glob matched this unit's target_files (chain: next.md _universal.md) — the 'keep top 1' floor is vacuous on an empty set, no rule invented
- reuse_slice: reuse-index.yaml absent at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/reuse-index.yaml (the T1 pointer line is omitted too)
- starterkit_slice: no starterkit-context.yaml at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice: unit is not ui_bearing (no target_files path matched the pack view_glob or any universal frontend shape)
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- design_slice_path: unit is not ui_bearing, so no design lens is dispatched for it — no lens-input file is written and the `design_slice_path` key is ABSENT (a rubric with no reader is a cost, not a contribution)
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
