═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-018
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-018

UNIT: U-018 "Build the walk-in appointment dialog with emergency override"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-018
title: Build the walk-in appointment dialog with emergency override
context_source: context.md#F-S-002
prd_source: [PRD/prd-clinic.md:178, PRD/prd-clinic.md:179]
task_type: create
grounding_confidence: LOW
risk: high
module: M-staff
depends_on: [U-001, U-009, U-012]
target_files:
  - path: src/features/appointments/components/WalkInDialog/index.tsx
    operation: create
  - path: src/features/appointments/components/WalkInDialog/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "creates a walk-in appointment with the staff channel"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "allows a time outside the slot grid only with the emergency override"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "validates patient details before submitting"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "keeps the dialog open and shows an error message when appointment creation fails"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "does not call the create appointment endpoint when patient details are invalid"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "resets the selected time when the emergency override switch is turned off"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-001]
---

# Unit U-018 — Build the walk-in appointment dialog with emergency override

## Goal

Create `WalkInDialog`, which lets a receptionist create an appointment for a walk-in or phone patient with `booking_channel = staff`, including an emergency override for times outside the slot grid.

## Context (read first)

F-S-002 steps 4–5: the receptionist can override booking restrictions for an emergency walk-in outside slot times and create appointments for walk-in / phone patients with `booking_channel = staff` (BR-006). The dialog reuses the U-001 `walkInSchema`, the `SlotPicker` (U-012) for normal slots and `useCreateAppointment` (U-009); the BFF (U-005) only accepts `staff` or override bookings from a receptionist, so the UI and the server agree.

## Anchors

- src/features/users/components/UserFormDialog.tsx — MUI dialog + react-hook-form + zodResolver pattern
- src/@core/components/mui/TextField.tsx — `CustomTextField` for labelled inputs

## Claims

- C-U018-01 "the project wires dialog forms with react-hook-form" — expect: src/features/users/components/UserFormDialog.tsx — must-exist
- C-U018-02 "the slot picker exists" — expect: src/features/appointments/components/SlotPicker/index.tsx — must-exist
- C-U018-03 "the booking schema module exists" — expect: src/features/appointments/schemas/booking/index.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/components/WalkInDialog/index.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST send bookingChannel staff for every appointment created from this dialog (constitution C-006)
  Source: constitution.md §C C-006
- MUST offer a free time outside the slot grid only while the emergency override switch is on (source: PRD §Clinic.1 F-S-002 step 4)
  Source: PRD §Clinic.1 F-S-002 step 4
- MUST validate patient details with walkInSchema before submitting and show errors as text (constitution B-001)
  Source: constitution.md §B B-001

## Implementation steps

1. Create the client component `WalkInDialog` with props `{ open: boolean; onClose(): void; defaultDate?: string }`, one `useForm` with `zodResolver(walkInSchema)`, labelled selects for doctor and service (`useDoctors`, `useServices`), and patient name, email, phone and reason-for-visit fields with in-text errors.
2. Render a labelled "Emergency override" switch: while off, time selection is `SlotPicker` fed by `useAvailability(doctorId, date)`; while on, a labelled `type='time'` input accepts any `HH:mm` and the dialog states that the time is outside the regular slots; submit calls `useCreateAppointment` with `{ doctorId, serviceId, startTime: `${date}T${startTime}`, patient: { name, email, phone }, reasonForVisit, bookingChannel: 'staff', override }` and closes on success, keeping the form and showing the error text on failure.
3. Write `index.test.tsx` (MSW `server.use` for doctors, services, availability and appointments) with every test named exactly as the acceptance_test `expects` strings (see Acceptance criteria for the adversarial additions); the adversarial cases must assert the POST body carries `bookingChannel: 'staff'`, `override: false` for a normal slot and `override: true` with an off-grid time such as `18:10` only when the switch is on.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `keeps the dialog open and shows an error message when appointment creation fails`: with a failing POST /api/v1/appointments, onClose is not called and the error text is rendered in the dialog.
- Adversarial addition — `does not call the create appointment endpoint when patient details are invalid`: submitting with a blank or invalid name, email or reason sends no request to the appointments route.
- Adversarial addition — `resets the selected time when the emergency override switch is turned off`: after entering an off-grid time with override on, switching it off clears the time so it cannot be submitted with override false.
- OQ-CLINIC-001 (P1, open): no regulation-specific behavior is invented.

## Out of scope

- Placing the dialog on the board — U-019

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-018
  vault_sha256: a9f0016ad50b4f11947a8e09dae107c8be0c42dccbdb644a00c17c12159b8326
  claims: (none cited)
  anchors_consulted: (none)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - file src/features/appointments/components/WalkInDialog/index.tsx MUST exist after bolt
    - MUST send bookingChannel staff for every appointment created from this dialog (constitution C-006)
    - MUST offer a free time outside the slot grid only while the emergency override switch is on (source: PRD §Clinic.1 F-S-002 step 4)
    - MUST validate patient details with walkInSchema before submitting and show errors as text (constitution B-001)
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

- U-009 "Add the appointments repository and TanStack Query hooks" → committed at 1705313e88a33d38b5a82f6c9b12c300591fc930
  └─ [success] Repository paths match the U-005/U-006/U-007 routes; cancel is outside /v1 — src: /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic/bolts/U-009/bolt-report.md
(+1 more upstream bolt-report(s) — Tier 3: read <vault>/bolts/U-XXX/bolt-report.md)

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §B-001: Untrusted input (booking form, token requests, walk-in form) is validated with zod in the browser and again at the server boundary (source: PRD §Clinic.1 F-U-001 step 5; PRD §6.3 Validation)
- §C-006: Every appointment records `booking_channel` — `online` for patient bookings, `staff` for receptionist-created appointments (source: PRD §5 BR-006)

(selector: `\b[A-F]-\d{3}\b` cited in U-018.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

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
consumed_t1: 9894 bytes (cap 12288)
consumed_t2: 4361 bytes (cap 10240, hard 12288)
total: 14255 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 19527    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - validation_hints: drop expected-output patterns; keep test commands only (saved 550 bytes)
  - validation_hints: drop section entirely (drop floor) (saved 729 bytes)
  - depends_on_summaries: keep 1 most-recent upstream (drop floor) (saved 339 bytes)
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
- depends_on.U-012: no bolt-report.md for upstream U-012 — entry OMITTED (no commit sha from any source)
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
