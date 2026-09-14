═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-012
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-012

UNIT: U-012 "Build the accessible date and slot picker component"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-012
title: Build the accessible date and slot picker component
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:147, PRD/prd-clinic.md:148, PRD/prd-clinic.md:109, PRD/prd-clinic.md:128]
task_type: create
grounding_confidence: LOW
risk: low
module: M-patient-booking
depends_on: [U-002]
target_files:
  - path: src/features/appointments/components/SlotPicker/index.tsx
    operation: create
  - path: src/features/appointments/components/SlotPicker/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/SlotPicker/index.test.tsx --reporter=verbose"
    expects: "shows only free slots for the chosen date"
  - type: test
    command: "pnpm test:run src/features/appointments/components/SlotPicker/index.test.tsx --reporter=verbose"
    expects: "announces the number of available slots in a live region"
  - type: test
    command: "pnpm test:run src/features/appointments/components/SlotPicker/index.test.tsx --reporter=verbose"
    expects: "flags a weekend date with an in-text error"
  - type: test
    command: "pnpm test:run src/features/appointments/components/SlotPicker/index.test.tsx --reporter=verbose"
    expects: "selects a slot by keyboard"
  - type: manual
    desc: "At 375px width, tab through the date field and the slot buttons: each slot is at least 44px tall, focus is visible, and the live region reads the slot count after the date changes."
binding_refs: [OQ-CN-1, OQ-CN-3, OQ-DM-1, OQ-CLINIC-006]
---

# Unit U-012 — Build the accessible date and slot picker component

## Goal

Create a controlled `SlotPicker` that lets a user choose a bookable date and one free 15-minute slot, with in-text errors and a live region announcing slot availability.

## Context (read first)

F-U-001 steps 3–4 disable past, weekend and out-of-hours dates and show only free 15-minute slots between 09:00 and 17:00 without the lunch hour; the rules live in U-002. PRD §8.1 names a calendar-style date picker and §8.4 requires labelled inputs with in-text errors, `aria-live` slot-availability updates, ≥ 24×24 targets (44×44 touch) and full keyboard reachability. No date-picker library is installed and the OQ-CN-1 recommendation adds none, so the date uses the existing `CustomTextField` with `type='date'`; the picker is data-agnostic (booked times come in as props) so the wizard (U-013), the reschedule form (U-014) and the walk-in dialog (U-018) reuse it.

## Anchors

- src/@core/components/mui/TextField.tsx — `CustomTextField`, the project's labelled text field
- src/components/table/BaseTable.tsx:1-30 — client component conventions and MUI import style

## Claims

- C-U012-01 "CustomTextField is the project's labelled input" — expect: src/@core/components/mui/TextField.tsx — must-exist
- C-U012-02 "the slot rules module exists" — expect: src/features/appointments/utils/slots/index.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/components/SlotPicker/index.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST take every slot decision from the U-002 helpers instead of re-implementing hours, lunch or weekend rules (source: PRD §5 BR-001)
  Source: PRD §5 BR-001
- MUST hide taken slots rather than show them disabled or labelled, so no other patient's booking is revealed (constitution B-006)
  Source: constitution.md §B B-006
- MUST label the date input, show errors as text, announce availability in an aria-live polite status region and keep every slot button at least 44px tall (constitution F-001)
  Source: constitution.md §F F-001

## Implementation steps

1. Create the client component `SlotPicker` with props `{ date: string; onDateChange(date: string): void; today: string; now?: string; bookedStartTimes: string[]; window?: { start: string; end: string } | null; value: string | null; onChange(time: string | null): void; isLoading?: boolean; error?: string | null; dateLabel?: string }`, rendering a labelled `CustomTextField type='date'` with `min={today}` and, when `isBookableDate(date, today)` is false, an in-text helper error such as "Choose a weekday from today onwards" and no slots.
2. Below the date render the result of `availableSlots({ date, today, bookedStartTimes, window, now })` as an MUI `ToggleButtonGroup` (exclusive, wrapping, each button ≥ 44px tall with the `HH:mm` label as its accessible name), clear `value` via `onChange(null)` when the date changes, show a loading indicator while `isLoading`, the `error` text when given, and an empty-state sentence when no slot is free; keep a `<div role='status' aria-live='polite'>` that states how many slots are available for the chosen date.
3. Write `index.test.tsx` with `renderWithProviders` and the four tests named exactly as the acceptance_test `expects` strings; the adversarial cases must prove a booked `10:00` is absent from the DOM (not merely disabled) and that changing the date resets a previously selected slot.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-3 — `today` / `now` are provided by the caller.

## Out of scope

- Fetching availability — U-009 hooks, wired by U-013 / U-014 / U-018

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-012
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted:
    - src/components/table/BaseTable.tsx:1
  anchors_verified: 1/1 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - file src/features/appointments/components/SlotPicker/index.tsx MUST exist after bolt
    - MUST take every slot decision from the U-002 helpers instead of re-implementing hours, lunch or weekend rules (source: PRD §5 BR-001)
    - MUST hide taken slots rather than show them disabled or labelled, so no other patient's booking is revealed (constitution B-006)
    - MUST label the date input, show errors as text, announce availability in an aria-live polite status region and keep every slot button at least 44px tall (constitution F-001)
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

- U-002 "Implement the bookable slot rules library" → committed at d0cc5988506a42657f784c21a0e9feec5679bbcf
  └─ [success] Lunch is the half-open interval [12:00, 13:00), which gives 28 slots with 13:00 bookable — src: /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic/bolts/U-002/bolt-report.md

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §B-006: Patient-facing views never expose other patients' data — taken slots are hidden, not labelled (source: PRD §Clinic.1 F-U-001 step 4)
- §F-001: Every page meets WCAG 2.2 AA — contrast ≥ 4.5:1 text / 3:1 UI, visible unobscured focus, targets ≥ 24×24 (44×44 touch), labelled inputs with in-text error identification, `role="status"` / `aria-live` for confirmations and slot updates, semantic landmarks, full keyboard reachability (source: PRD §6.1; PRD §8.4; PRD §Clinic.5 AC-007)

(selector: `\b[A-F]-\d{3}\b` cited in U-012.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

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
consumed_t1: 9318 bytes (cap 12288)
consumed_t2: 4413 bytes (cap 10240, hard 12288)
total: 13731 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 18811    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - validation_hints: drop expected-output patterns; keep test commands only (saved 461 bytes)
  - validation_hints: drop section entirely (drop floor) (saved 501 bytes)
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
- symbol_slice: no indexed symbol in or beside target_files
- starterkit_slice: no starterkit-context.yaml at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice.style[clinical]: style token matches no style-principles.md row — omitted, never substituted
- design_slice.style[trustworthy]: style token matches no style-principles.md row — omitted, never substituted
- design_slice.style[anti-generic — brand color on high-signal elements only]: style token matches no style-principles.md row — omitted, never substituted
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic
- validation_hints: truncated to its drop floor (section dropped) by the T2 cascade
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
