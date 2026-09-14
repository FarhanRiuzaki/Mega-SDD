═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-019
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-019

UNIT: U-019 "Build the reception board page with all doctors' schedules"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-019
title: Build the reception board page with all doctors' schedules
context_source: context.md#F-S-002
prd_source: [PRD/prd-clinic.md:175, PRD/prd-clinic.md:176, PRD/prd-clinic.md:194, PRD/prd-clinic.md:108, PRD/prd-clinic.md:209]
task_type: create
grounding_confidence: LOW
risk: medium
module: M-staff
depends_on: [U-002, U-003, U-009, U-017, U-018]
target_files:
  - path: src/features/appointments/components/ReceptionBoard/index.tsx
    operation: create
  - path: src/features/appointments/components/ReceptionBoard/columns.tsx
    operation: create
  - path: src/features/appointments/components/ReceptionBoard/index.test.tsx
    operation: create
  - path: src/app/(dashboard)/staff/reception/page.tsx
    operation: create
existing_interfaces:
  - file: src/components/table/BaseTable.tsx
    symbol: BaseTable
    note: "reuse unchanged for the reception board data table"
  - file: src/components/rbac/ProtectedRoute.tsx
    symbol: ProtectedRoute
    note: "reuse unchanged with require.roles"
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReceptionBoard/index.test.tsx --reporter=verbose"
    expects: "lists every doctor appointment for the selected date"
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReceptionBoard/index.test.tsx --reporter=verbose"
    expects: "renders one schedule row per doctor"
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReceptionBoard/index.test.tsx --reporter=verbose"
    expects: "opens the reassign dialog for a row"
  - type: test
    command: "pnpm test:run src/features/appointments/components/ReceptionBoard/index.test.tsx --reporter=verbose"
    expects: "opens the walk-in dialog from the board"
  - type: manual
    desc: "Sign in as a receptionist, open /staff/reception: every doctor's appointments for the chosen date appear in the grid and the table; a doctor-only user gets the Access Denied panel."
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-AR-2, OQ-CLINIC-006]
---

# Unit U-019 — Build the reception board page with all doctors' schedules

## Goal

Create `/staff/reception` for the `receptionist` role: a per-date schedule grid with one row per doctor, a reception board data table of the day's appointments, and entry points to reassign an appointment and to create a walk-in.

## Context (read first)

F-S-002: the receptionist sees all doctors' schedules plus a reception board (data table), can reassign an appointment and can create walk-in / phone appointments (with the emergency override). PRD §8.1 puts data tables on TanStack Table via the house `BaseTable` and describes the grid as rows = doctors, columns = time (built with MUI per the OQ-CLINIC-006 recommendation). The schedule route (U-007) returns every doctor's appointments for a receptionist; the dialogs come from U-017 and U-018; no menu entry yet (OQ-AR-2).

## Anchors

- src/features/users/components/table/index.tsx:1-128 — `BaseTable` usage with `customActions`, row actions and dialogs driven by state
- src/features/users/components/table/columns.tsx — column definitions in a sibling `columns.tsx`
- src/app/(dashboard)/users/page.tsx:1-17 — page wrapped in `ProtectedRoute`

## Claims

- C-U019-01 "BaseTable is the house data table" — expect: src/components/table/BaseTable.tsx:BaseTable
- C-U019-02 "ProtectedRoute supports role requirements" — expect: src/components/rbac/ProtectedRoute.tsx:ProtectedRoute
- C-U019-03 "the reassign dialog exists" — expect: src/features/appointments/components/ReassignDialog/index.tsx — must-exist
- C-U019-04 "the walk-in dialog exists" — expect: src/features/appointments/components/WalkInDialog/index.tsx — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/components/table/BaseTable.tsx
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- DO NOT modify src/data/navigation/verticalMenuData.tsx
  Source: context.md OQ-AR-2 (no menu entry until permission names are decided)
- DO NOT modify src/data/navigation/horizontalMenuData.tsx
  Source: context.md OQ-AR-2 (no menu entry until permission names are decided)
- file src/app/(dashboard)/staff/reception/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST guard the page with ProtectedRoute requiring the receptionist role (constitution B-005)
  Source: constitution.md §B B-005
- MUST render status with AppointmentStatusChip and the booking channel with BOOKING_CHANNEL_LABELS (constitution F-002, A-005)
  Source: constitution.md §F F-002, §A A-005
- MUST keep the grid and the table keyboard-reachable with labelled controls (constitution F-001)
  Source: constitution.md §F F-001

## Implementation steps

1. Create `src/app/(dashboard)/staff/reception/page.tsx` like the users page anchor with `<ProtectedRoute require={{ roles: ['receptionist'] }}><ReceptionBoard /></ProtectedRoute>`.
2. Create the client component `ReceptionBoard`: a labelled date field (default today) drives `useSchedule({ from: date, to: date })`; above the table render the schedule grid with one row per doctor present in `useDoctors()` and one column per `generateDaySlots()` time, each appointment a focusable cell with patient name and `AppointmentStatusChip`; handle loading, error and empty states.
3. Create `columns.tsx` (time, doctor, patient, service, status chip, channel label, and a row action "Reassign") and render the day's appointments with `BaseTable` (`title='Reception board'`, client-side pagination), passing a "New walk-in" button through `customActions`; row "Reassign" opens `ReassignDialog` with that appointment and the button opens `WalkInDialog` with `defaultDate={date}`.
4. Write `index.test.tsx` (MSW `server.use` for doctors, schedule, and the dialogs' routes) with the four tests named exactly as the acceptance_test `expects` strings; the adversarial case must assert a doctor with no appointments still gets an (empty) grid row.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-AR-2 — no navigation menu entry until permission names are decided; reach the page by URL.

## Out of scope

- The dialogs' internals — U-017, U-018
- Automatic handling of a sick doctor's appointments (OQ-CLINIC-004)

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-019
  vault_sha256: d74596d8b27f8776dfd7ba768ef322176137d0b7b4d9d2f0da7159150f23b487
  claims: (none cited)
  anchors_consulted:
    - src/features/users/components/table/index.tsx:1
    - src/app/(dashboard)/users/page.tsx:1
  anchors_verified: 2/2 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - DO NOT modify src/components/table/BaseTable.tsx
    - DO NOT modify src/data/navigation/verticalMenuData.tsx
    - DO NOT modify src/data/navigation/horizontalMenuData.tsx
    - file src/app/(dashboard)/staff/reception/page.tsx MUST exist after bolt
    - MUST guard the page with ProtectedRoute requiring the receptionist role (constitution B-005)
    - MUST render status with AppointmentStatusChip and the booking channel with BOOKING_CHANNEL_LABELS (constitution F-002, A-005)
    - MUST keep the grid and the table keyboard-reachable with labelled controls (constitution F-001)
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
  - src/components/table/BaseTable.tsx  (source: U-019.md `## Hard rules`)
  - src/data/navigation/verticalMenuData.tsx  (source: U-019.md `## Hard rules`)
  - src/data/navigation/horizontalMenuData.tsx  (source: U-019.md `## Hard rules`)
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

- U-018 "Build the walk-in appointment dialog with emergency override" → committed at d1433eecb98ccc06dfae302d302d94d8845e10d1
  └─ [success] bookingChannel 'staff' is hard-coded in the submit payload; override is always sent as a boolean — src: /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic/bolts/U-018/bolt-report.md
(+4 more upstream bolt-report(s) — Tier 3: read <vault>/bolts/U-XXX/bolt-report.md)

## Framework pack rules (filtered by your target_files glob match)

- framework-pack-naming-rule-001 (from next.md §Hard Rules emitted; matched glob `app/**/page.tsx` against `src/app/(dashboard)/staff/reception/page.tsx`)
  └─ Page files MUST be named page.tsx (not index.tsx, component.tsx, etc.) in the App Router
     rule_type: NAMING_RULE
     pattern: '^page\.(tsx|jsx|ts|js)$'
     rationale: Next.js App Router only renders the reserved filename page.tsx as a route; other filenames are treated as co-located modules, not routes
(+1 more matching pack rule(s) — Tier 3: read the full pack)

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §A-005: Static `SelectOption` lists extend `src/libs/constants.ts` and value→label display maps extend `src/libs/label-maps.ts` instead of being redeclared locally (source: CLAUDE.md:105)
- §B-005: Staff surfaces require the matching role — `/staff/schedule` the `doctor` role, `/staff/reception` the `receptionist` role — and a doctor's schedule data is limited to that doctor's own appointments (source: PRD §Clinic.3; PRD §Clinic.5 AC-005)
- §F-001: Every page meets WCAG 2.2 AA — contrast ≥ 4.5:1 text / 3:1 UI, visible unobscured focus, targets ≥ 24×24 (44×44 touch), labelled inputs with in-text error identification, `role="status"` / `aria-live` for confirmations and slot updates, semantic landmarks, full keyboard reachability (source: PRD §6.1; PRD §8.4; PRD §Clinic.5 AC-007)
- §F-002: Appointment status is never conveyed by color alone — text + icon + color (source: PRD §8.2; PRD §Clinic.5 AC-007)

(selector: `\b[A-F]-\d{3}\b` cited in U-019.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

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
consumed_t1: 10742 bytes (cap 12288)
consumed_t2: 5571 bytes (cap 10240, hard 12288)
total: 16313 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 21327    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - validation_hints: drop expected-output patterns; keep test commands only (saved 457 bytes)
  - validation_hints: drop section entirely (drop floor) (saved 517 bytes)
  - depends_on_summaries: keep 3 most-recent upstreams (by attempted_at desc) (saved 656 bytes)
  - depends_on_summaries: keep 1 most-recent upstream (drop floor) (saved 727 bytes)
  - framework_pack_rules: top 1 rules (chain order, then in-file order) — drop floor: keep top 1 always (saved 334 bytes)
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
