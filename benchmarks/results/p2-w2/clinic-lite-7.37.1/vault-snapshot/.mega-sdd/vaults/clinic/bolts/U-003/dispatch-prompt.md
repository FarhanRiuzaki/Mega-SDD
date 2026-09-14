═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-003
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-003

UNIT: U-003 "Add appointment status labels and an accessible status chip"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-003
title: Add appointment status labels and an accessible status chip
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:119, PRD/prd-clinic.md:211]
task_type: extend
grounding_confidence: LOW
risk: low
module: M-clinic-core
depends_on: [U-001]
target_files:
  - path: src/libs/label-maps.ts
    operation: modify
  - path: src/features/appointments/components/AppointmentStatusChip/index.tsx
    operation: create
  - path: src/features/appointments/components/AppointmentStatusChip/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"
    expects: "renders the text label for every status"
  - type: test
    command: "pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"
    expects: "renders a distinct icon for every status"
  - type: test
    command: "pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"
    expects: "keeps existing label maps unchanged"
binding_refs: [OQ-CN-1]
---

# Unit U-003 — Add appointment status labels and an accessible status chip

## Goal

Add the value→label maps for appointment status and booking channel to the shared label-maps module and a reusable `AppointmentStatusChip` that encodes status by text + icon + color.

## Context (read first)

PRD §8.2 says status is never color-only — booked, cancelled and completed must be encoded by text + icon + color — and AC-007 makes this an acceptance criterion for every page. The house rule (constitution A-005) centralizes value→label maps in `src/libs/label-maps.ts`, so the labels go there and the chip only renders them. The doctor schedule (U-016), reschedule page (U-014) and reception board (U-019) all render this chip.

## Anchors

- src/libs/label-maps.ts:1-56 — existing `Record<string, string>` label maps; append the new maps in the same style
- src/features/users/components/table/index.tsx:1-20 — client component import ordering used in features

## Claims

- C-U003-01 "label-maps.ts is the central value→label module" — expect: src/libs/label-maps.ts — must-exist
- C-U003-02 "ACCOUNT_TYPE_LABELS is an existing export that must survive" — expect: src/libs/label-maps.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/components/AppointmentStatusChip/index.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep every existing export of src/libs/label-maps.ts unchanged (constitution A-005)
  Source: constitution.md §A A-005
- MUST NOT convey status by color alone — every status renders its text label and an icon (constitution F-002)
  Source: constitution.md §F F-002
- MUST keep the chip text contrast at or above 4.5:1 against its background (constitution F-001)
  Source: constitution.md §F F-001
- MUST use Iconify tabler classes for the icons (constitution A-006)
  Source: constitution.md §A A-006

## Implementation steps

1. Append to `src/libs/label-maps.ts` two maps typed against the U-001 unions: `APPOINTMENT_STATUS_LABELS: Record<AppointmentStatus, string>` = `{ booked: 'Booked', cancelled: 'Cancelled', completed: 'Completed' }` and `BOOKING_CHANNEL_LABELS: Record<BookingChannel, string>` = `{ online: 'Online', staff: 'Staff' }`, leaving every existing map byte-identical.
2. Create the client component `AppointmentStatusChip` (`{ status: AppointmentStatus; size?: 'small' | 'medium' }`) that renders an MUI `Chip` whose label is the mapped text and whose icon is a distinct tabler icon per status (for example `tabler-calendar-check`, `tabler-calendar-x`, `tabler-circle-check`, marked `aria-hidden`), with a color per status chosen so the label text keeps 4.5:1 contrast — prefer an outlined/tonal variant with dark text over a filled chip with white text on a light hue; if an icon class does not render, rerun `pnpm build:icons` rather than importing icon components.
3. Write `index.test.tsx` using `renderWithProviders` with the three tests named exactly as the acceptance_test `expects` strings: each status shows its text label; the three statuses render three different icon classes; and an adversarial check that the pre-existing exports (for example `ACCOUNT_TYPE_LABELS.CASA === 'CASA'`) are still present.

## Migration notes

- **REMOVE**: nothing.
- **KEEP**: every existing export in `src/libs/label-maps.ts` (`TUJUAN_LABELS` … `ACCOUNT_TYPE_LABELS`) and the header comment, unchanged.
- **ADD**: `APPOINTMENT_STATUS_LABELS`, `BOOKING_CHANNEL_LABELS` (with the type import from `@/features/appointments/types`), and the new `AppointmentStatusChip` component folder.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).

## Out of scope

- Theme primary color — U-004
- Where the chip is placed — U-014, U-016, U-019

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-003
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted:
    - src/libs/label-maps.ts:1
    - src/features/users/components/table/index.tsx:1
  anchors_verified: 2/2 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - file src/features/appointments/components/AppointmentStatusChip/index.tsx MUST exist after bolt
    - MUST keep every existing export of src/libs/label-maps.ts unchanged (constitution A-005)
    - MUST NOT convey status by color alone — every status renders its text label and an icon (constitution F-002)
    - MUST keep the chip text contrast at or above 4.5:1 against its background (constitution F-001)
    - MUST use Iconify tabler classes for the icons (constitution A-006)
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

## Upstream bolts (depends_on chain — 1-line summary each)

- U-001 "Define appointment domain types and zod payload schemas" → committed at (no commit recorded)
  └─ [unknown] Field names, unions and interfaces follow the unit's implementation-step enumeration literally (no createdAt/updatedAt added, no price siblings). — src: /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic/bolts/U-001/bolt-report.md

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §A-005: Static `SelectOption` lists extend `src/libs/constants.ts` and value→label display maps extend `src/libs/label-maps.ts` instead of being redeclared locally (source: CLAUDE.md:105)
- §A-006: Icons are Iconify classes `<i className='tabler-<name>' />`, not individually imported icon components (source: CLAUDE.md §Iconify)
- §F-001: Every page meets WCAG 2.2 AA — contrast ≥ 4.5:1 text / 3:1 UI, visible unobscured focus, targets ≥ 24×24 (44×44 touch), labelled inputs with in-text error identification, `role="status"` / `aria-live` for confirmations and slot updates, semantic landmarks, full keyboard reachability (source: PRD §6.1; PRD §8.4; PRD §Clinic.5 AC-007)
- §F-002: Appointment status is never conveyed by color alone — text + icon + color (source: PRD §8.2; PRD §Clinic.5 AC-007)

(selector: `\b[A-F]-\d{3}\b` cited in U-003.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

### Existing symbols (REUSE — extend, don't recreate)

+7 more — query via scripts/query-symbol-index.sh

## Design system (UI-bearing unit — per context-enrichment.md §Design slice)


Design system: style=clinical, trustworthy, anti-generic — brand color on high-signal elements only · palette=primary teal-700 #0E7490 (white foreground, 5.36:1); accent/success green-700 #15803D (5.02:1); raw #0891B2 / #16A34A only for fills, charts and icon accents · typography=humanist sans body with a real type scale; optional serif display headers · a11y=WCAG 2.2 AA — source: vault.json design_system (provenance excluded, audit-only)
UX floor: (ux-rules.md — Accessibility/Forms/Feedback rows, Severity: High)
  - Accessibility/Color Contrast: DO Minimum 4.5:1 ratio for normal text; DON'T Low contrast text [High]
  - Accessibility/Color Only: DO Use icons/text in addition to color; DON'T Red/green only for error/success [High]
  - Accessibility/Alt Text: DO Descriptive alt text for meaningful images; DON'T Empty or missing alt attributes [High]
  - Accessibility/ARIA Labels: DO Add aria-label for icon-only buttons; DON'T Icon buttons without labels [High]
  - Accessibility/Keyboard Navigation: DO Tab order matches visual order; DON'T Keyboard traps or illogical tab order [High]
  - Accessibility/Form Labels: DO Use label with for attribute or wrap input; DON'T Placeholder-only inputs [High]
  - Accessibility/Error Messages: DO Use aria-live or role=alert for errors; DON'T Visual-only error indication [High]
  - Forms/Input Labels: DO Always show label above or beside input; DON'T Placeholder as only label [High]
  - Forms/Submit Feedback: DO Show loading then success/error state; DON'T No feedback after submit [High]
  - Feedback/Loading Indicators: DO Show spinner/skeleton for operations > 300ms; DON'T No feedback during loading [High]
  - Accessibility/Motion Sensitivity: DO Respect prefers-reduced-motion; DON'T Force scroll effects [High]
Modern baseline (non-negotiables — the FLOOR):
  - Design tokens first.
  - Spacing system, not ad-hoc gaps.
  - Typographic scale.
  - Layout is composed, not stacked.
  - Interactive states exist.
  - Feedback states exist.
  - Forms are designed.
  - Accessibility floor = WCAG AA
  - Tables are for data — styled.
  - Distinctive, not generic.
Ceiling moves (clear the floor, then DO these — a floor-only view is "basic/generic"):
  - Page furniture.
  - Composition, not a lone card.
  - Iconography.
  - Visual hierarchy with depth.
  - A signature.
  - Motion with purpose.
  - Density that fits the product.
Anti-kuno tells (a match in your output = defect):
- Unstyled default browser controls / default link blue / default focus-less buttons.
- Layout via nested `<table>` or `<br>` stacks; no page shell (content hugging the left edge full-width).
- No spacing system: arbitrary `margin: 3px 7px 11px`, cramped forms.
- System-default typography wall (no scale, no pairing, line-height 1).
- Raw `<input>` rows with placeholder-as-label, no validation states.
- Native `alert()`/`confirm()`; raw URL text as actions ("click here").
- Unformatted data: ISO timestamps shown raw, unformatted money, raw FK ids.
- Zero hover/focus/disabled treatment; zero loading/empty/error states.
- Inline `style=` attributes everywhere instead of the token layer.

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 9011 bytes (cap 12288)
consumed_t2: 4894 bytes (cap 10240, hard 12288)
total: 13905 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 19013    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - validation_hints: drop expected-output patterns; keep test commands only (saved 192 bytes)
  - validation_hints: drop section entirely (drop floor) (saved 426 bytes)
  - symbol_slice: hint line only — never fully dropped (drop floor) (saved 727 bytes)
  - design_slice: modern-baseline -> bolded lead clauses verbatim; ux-rules -> Severity: High rows (saved 6215 bytes)
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
- framework_pack_rules: no pack rule path_glob matched this unit's target_files (chain: next.md _universal.md) — the 'keep top 1' floor is vacuous on an empty set, no rule invented
- reuse_slice: reuse-index.yaml absent at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/reuse-index.yaml (the T1 pointer line is omitted too)
- starterkit_slice: no starterkit-context.yaml at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice.style[clinical]: style token matches no style-principles.md row — omitted, never substituted
- design_slice.style[trustworthy]: style token matches no style-principles.md row — omitted, never substituted
- design_slice.style[anti-generic — brand color on high-signal elements only]: style token matches no style-principles.md row — omitted, never substituted
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic
- validation_hints: truncated to its drop floor (section dropped) by the T2 cascade
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
