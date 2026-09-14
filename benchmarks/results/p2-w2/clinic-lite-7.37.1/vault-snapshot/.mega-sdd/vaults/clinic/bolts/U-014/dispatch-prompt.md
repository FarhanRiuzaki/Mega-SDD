═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-014
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-014

UNIT: U-014 "Build the token reschedule page"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-014
title: Build the token reschedule page
context_source: context.md#F-U-004
prd_source: [PRD/prd-clinic.md:165, PRD/prd-clinic.md:166, PRD/prd-clinic.md:167, PRD/prd-clinic.md:192, PRD/prd-clinic.md:210]
task_type: create
grounding_confidence: LOW
risk: high
module: M-patient-self-service
depends_on: [U-003, U-009, U-012]
target_files:
  - path: src/features/appointments/components/RescheduleForm/index.tsx
    operation: create
  - path: src/features/appointments/components/RescheduleForm/index.test.tsx
    operation: create
  - path: src/app/(patient)/reschedule/[token]/page.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "shows the current appointment for the token"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "reschedules to the chosen free slot"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "shows an error when the token is invalid"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "announces the rescheduled confirmation in a status region"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "sends only startTime in the reschedule request body"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "hides the slot picker for a cancelled appointment"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "never renders the token value anywhere on the page"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-001, OQ-CLINIC-003, OQ-FL-1]
---

# Unit U-014 — Build the token reschedule page

## Goal

Create the public `/reschedule/[token]` page and its `RescheduleForm`, which shows the patient's current appointment and moves it to a newly chosen free slot.

## Context (read first)

F-U-004: the patient opens the reschedule link (same one-time token), sees the current appointment, picks a new available slot and confirms; the upstream frees the old slot and books the new one atomically (AC-006, OQ-AR-1) and re-sends the confirmation. The token is the only authorization (constitution B-002) and the route is public (U-010), inside the `(patient)` layout (U-011). The status chip (U-003) shows the current status; an invalid or used token must show a clear error instead of a broken page.

## Anchors

- src/features/users/components/UserDetailDialog.tsx — loading / error / detail rendering of a single record via a query hook
- src/app/(dashboard)/users/[id]/page.tsx — dynamic-segment page reading its param

## Claims

- C-U014-01 "detail rendering with a query hook exists in the users feature" — expect: src/features/users/components/UserDetailDialog.tsx — must-exist
- C-U014-02 "the slot picker exists" — expect: src/features/appointments/components/SlotPicker/index.tsx — must-exist
- C-U014-03 "the status chip exists" — expect: src/features/appointments/components/AppointmentStatusChip/index.tsx — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/app/(patient)/reschedule/[token]/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST authorize only through the token from the URL and never ask the patient to log in (constitution B-002)
  Source: constitution.md §B B-002
- MUST offer only free slots of the same doctor through SlotPicker and the availability hook (source: PRD §Clinic.1 F-U-004 step 2)
  Source: PRD §Clinic.1 F-U-004 step 2
- MUST announce the rescheduled confirmation in a role status aria-live region (constitution F-001)
  Source: constitution.md §F F-001
- MUST NOT render the token itself anywhere on the page (constitution B-002)
  Source: constitution.md §B B-002

## Implementation steps

1. Create `src/app/(patient)/reschedule/[token]/page.tsx` (async, `params: Promise<{ token: string }>`) exporting `metadata = { title: 'Reschedule appointment' }` and rendering `<RescheduleForm token={token} />`.
2. Create the client component `RescheduleForm`: load `useAppointmentByToken(token)`; while loading show a progress indicator; on error show a text message that the link is invalid or already used; otherwise show the current appointment (doctor, service, date, time and `AppointmentStatusChip`), and when its status is not `booked` show that it can no longer be changed instead of the picker.
3. For a booked appointment render `SlotPicker` wired to `useAvailability(appointment.doctorId, date)` using a small react-hook-form + `rescheduleSchema` form; the confirm button submits `useRescheduleAppointment` with `{ token, startTime: `${date}T${startTime}` }` and on success shows a `role='status' aria-live='polite'` panel with the new date and time and a note that a confirmation email is on its way; a rejected submission keeps the form and shows the upstream message as text.
4. Write `index.test.tsx` (MSW `server.use` for the token and availability routes) with every test named exactly as the acceptance_test `expects` strings (see Acceptance criteria for the adversarial additions); the adversarial cases must assert the PUT body carries only `startTime` and that a cancelled appointment shows no slot picker.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `sends only startTime in the reschedule request body`: the captured PUT body is exactly { startTime } with no token, doctorId or id.
- Adversarial addition — `hides the slot picker for a cancelled appointment`: for a cancelled appointment the slot picker and confirm button are absent and a not-changeable message is shown.
- Adversarial addition — `never renders the token value anywhere on the page`: on both the valid-token and the invalid-token path the raw token string never appears in the document.
- TBD: OQ-CLINIC-003 — no reschedule window is enforced client-side.
- TBD: OQ-FL-1 — this page offers no cancel action until the cancel confirmation screen is decided.
- OQ-CLINIC-001 (P1, open): no regulation-specific behavior is invented.

## Out of scope

- The cancel API — U-006
- Booking — U-013

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-014
  vault_sha256: a9f0016ad50b4f11947a8e09dae107c8be0c42dccbdb644a00c17c12159b8326
  claims: (none cited)
  anchors_consulted: (none)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - file src/app/(patient)/reschedule/[token]/page.tsx MUST exist after bolt
    - MUST authorize only through the token from the URL and never ask the patient to log in (constitution B-002)
    - MUST offer only free slots of the same doctor through SlotPicker and the availability hook (source: PRD §Clinic.1 F-U-004 step 2)
    - MUST announce the rescheduled confirmation in a role status aria-live region (constitution F-001)
    - MUST NOT render the token itself anywhere on the page (constitution B-002)
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

## Framework pack rules (filtered by your target_files glob match)

- framework-pack-naming-rule-001 (from next.md §Hard Rules emitted; matched glob `app/**/page.tsx` against `src/app/(patient)/reschedule/[token]/page.tsx`)
  └─ Page files MUST be named page.tsx (not index.tsx, component.tsx, etc.) in the App Router
     rule_type: NAMING_RULE
     pattern: '^page\.(tsx|jsx|ts|js)$'
     rationale: Next.js App Router only renders the reserved filename page.tsx as a route; other filenames are treated as co-located modules, not routes
(+1 more matching pack rule(s) — Tier 3: read the full pack)

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §B-002: Patients never log in; cancel and reschedule are authorized only by the one-time signed email token (source: PRD §3; PRD §6.3 Auth)
- §F-001: Every page meets WCAG 2.2 AA — contrast ≥ 4.5:1 text / 3:1 UI, visible unobscured focus, targets ≥ 24×24 (44×44 touch), labelled inputs with in-text error identification, `role="status"` / `aria-live` for confirmations and slot updates, semantic landmarks, full keyboard reachability (source: PRD §6.1; PRD §8.4; PRD §Clinic.5 AC-007)

(selector: `\b[A-F]-\d{3}\b` cited in U-014.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

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
consumed_t1: 10517 bytes (cap 12288)
consumed_t2: 5106 bytes (cap 10240, hard 12288)
total: 15623 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 20837    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - validation_hints: drop expected-output patterns; keep test commands only (saved 507 bytes)
  - validation_hints: drop section entirely (drop floor) (saved 853 bytes)
  - depends_on_summaries: keep 1 most-recent upstream (drop floor) (saved 302 bytes)
  - framework_pack_rules: top 1 rules (chain order, then in-file order) — drop floor: keep top 1 always (saved 335 bytes)
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
