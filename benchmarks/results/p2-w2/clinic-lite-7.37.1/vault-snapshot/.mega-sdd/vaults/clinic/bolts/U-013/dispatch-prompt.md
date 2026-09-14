═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-013
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-013

UNIT: U-013 "Build the patient booking wizard and the /book page"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-013
title: Build the patient booking wizard and the /book page
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:142, PRD/prd-clinic.md:145, PRD/prd-clinic.md:146, PRD/prd-clinic.md:151, PRD/prd-clinic.md:80, PRD/prd-clinic.md:111, PRD/prd-clinic.md:205]
task_type: create
grounding_confidence: LOW
risk: high
module: M-patient-booking
depends_on: [U-001, U-009, U-012]
target_files:
  - path: src/features/appointments/components/BookingWizard/index.tsx
    operation: create
  - path: src/features/appointments/components/BookingWizard/index.test.tsx
    operation: create
  - path: src/app/(patient)/book/page.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+4 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "walks through all steps and books with the online channel"
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "blocks the next step until the current step fields are valid"
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "announces the booking confirmation in a status region"
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "returns to the date step when the slot was taken meanwhile"
  - type: manual
    desc: "Book an appointment at /book on a 375px viewport using only the keyboard: every step is reachable, errors are read as text, and the confirmation is announced."
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "does not send an override flag in the booking request"
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "does not claim the confirmation email has already been sent"
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "keeps patient details filled in after a slot conflict returns to the date step"
  - type: test
    command: "pnpm test:run src/features/appointments/components/BookingWizard/index.test.tsx --reporter=verbose"
    expects: "does not persist patient data in localStorage or cookies"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-001, OQ-CN-3, OQ-CN-4, OQ-DM-1]
---

# Unit U-013 — Build the patient booking wizard and the /book page

## Goal

Create the multi-step `BookingWizard` (doctor & service → date & time → your details → review & confirm) that books with `booking_channel = online`, and the public `/book` page that renders it.

## Context (read first)

F-U-001 is the primary patient flow: select doctor and service, pick a date and a free slot, enter name, email, phone and reason for visit (validated client and server — U-005 re-validates), confirm, and receive a confirmation email with a cancel/reschedule link (sent upstream, OQ-AR-1). PRD §8.1 fixes the form technique — one `<form>`, a single react-hook-form instance and per-step zod validation via `trigger(fields)` — and §8.4 requires `role="status"` / `aria-live` for the booking confirmation. AC-002 says a concurrent insert of the same slot is rejected, so an upstream rejection must send the patient back to choose another slot; the page lives in the `(patient)` group (U-011 layout) and is public (U-010).

## Anchors

- src/features/users/components/UserFormDialog.tsx — react-hook-form + `zodResolver` + MUI field wiring used in the project
- src/features/users/components/table/index.tsx:1-40 — feature component composition with hooks and MUI
- src/app/(blank-layout-pages)/login/page.tsx:1-22 — page file with `metadata`

## Claims

- C-U013-01 "the project wires forms with react-hook-form and zodResolver" — expect: src/features/users/components/UserFormDialog.tsx — must-exist
- C-U013-02 "the booking schema module exists" — expect: src/features/appointments/schemas/booking/index.ts — must-exist
- C-U013-03 "the appointments hooks exist" — expect: src/features/appointments/hooks/useAppointments/index.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/app/(patient)/book/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST use one form element with a single react-hook-form instance and validate each step with trigger on that step's BOOKING_STEP_FIELDS entry (source: PRD §8.1 Forms)
  Source: PRD §8.1 Forms
- MUST send bookingChannel online and never send the override flag from the patient wizard (constitution C-006)
  Source: constitution.md §C C-006
- MUST announce the booking confirmation in a role status aria-live region and show validation errors as text next to their inputs (constitution F-001)
  Source: constitution.md §F F-001
- MUST NOT store patient data in localStorage, cookies or logs (constitution F-004)
  Source: constitution.md §F F-004

## Anti-patterns

- Don't build four separate forms — the PRD asks for one form with per-step validation.
- Don't show the email as already sent from the client; say that a confirmation email with a cancel/reschedule link is on its way (the upstream sends it).

## Implementation steps

1. Create the client component `BookingWizard`: one `useForm<BookingFormValues>({ resolver: zodResolver(bookingSchema), defaultValues: bookingFormDefaults })`, an MUI `Stepper` with the four steps, and Next / Back buttons where Next calls `trigger(BOOKING_STEP_FIELDS[step])` and advances only when it resolves true; lay the steps out two-column on desktop (step content + a booking summary aside) collapsing to one column below the `md` breakpoint.
2. Step 1 renders labelled selects fed by `useDoctors` and `useServices` (service label shows its name and, when present, the display-only price); step 2 renders `SlotPicker` with `today`/`now` from the browser clock, `bookedStartTimes` and `workingHours` from `useAvailability(doctorId, date)`; step 3 renders labelled name, email, phone and reason-for-visit fields with in-text errors; step 4 reviews every choice and submits `useCreateAppointment` with `{ doctorId, serviceId, startTime: `${date}T${startTime}`, patient: { name, email, phone }, reasonForVisit, bookingChannel: 'online' }`.
3. On success replace the form with a confirmation panel inside `<div role='status' aria-live='polite'>` listing doctor, service, date and time and saying a confirmation email with a cancel/reschedule link is on its way; on a rejected submission keep the entered details, clear `startTime`, return to step 2 and show the upstream message as text so the patient can choose another slot.
4. Create `src/app/(patient)/book/page.tsx` exporting `metadata = { title: 'Book an appointment' }` and rendering `<BookingWizard />`, then write `index.test.tsx` (MSW `server.use` for doctors, services, availability and appointments) with every test named exactly as the acceptance_test `expects` strings (see Acceptance criteria for the adversarial additions); the adversarial cases must assert the POST body carries `bookingChannel: 'online'` and no `override`, and that a 400 from the appointments route lands the user on the date & time step with the details still filled in.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `does not send an override flag in the booking request`: the captured POST body has no override key and bookingChannel is online.
- Adversarial addition — `does not claim the confirmation email has already been sent`: the status region says the email is on its way and never says it has been sent.
- Adversarial addition — `keeps patient details filled in after a slot conflict returns to the date step`: after the rejection and moving forward again, name, email, phone and reason still hold the typed values.
- Adversarial addition — `does not persist patient data in localStorage or cookies`: after submitting, neither localStorage nor document.cookie contains any entered name, email or phone.
- TBD: OQ-CN-4 — no client-side rate limiting.
- TBD: OQ-CN-3 — `today` / `now` come from the browser clock until the clinic timezone is decided.
- OQ-CLINIC-001 (P1, open): no consent text or retention notice is invented; add it when the regulation is decided.

## Out of scope

- Cancel and reschedule — U-006, U-014
- The patient shell — U-011

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-013
  vault_sha256: a9f0016ad50b4f11947a8e09dae107c8be0c42dccbdb644a00c17c12159b8326
  claims: (none cited)
  anchors_consulted:
    - src/features/users/components/table/index.tsx:1
    - src/app/(blank-layout-pages)/login/page.tsx:1
  anchors_verified: 2/2 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - file src/app/(patient)/book/page.tsx MUST exist after bolt
    - MUST use one form element with a single react-hook-form instance and validate each step with trigger on that step's BOOKING_STEP_FIELDS entry (source: PRD §8.1 Forms)
    - MUST send bookingChannel online and never send the override flag from the patient wizard (constitution C-006)
    - MUST announce the booking confirmation in a role status aria-live region and show validation errors as text next to their inputs (constitution F-001)
    - MUST NOT store patient data in localStorage, cookies or logs (constitution F-004)
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

- framework-pack-naming-rule-001 (from next.md §Hard Rules emitted; matched glob `app/**/page.tsx` against `src/app/(patient)/book/page.tsx`)
  └─ Page files MUST be named page.tsx (not index.tsx, component.tsx, etc.) in the App Router
     rule_type: NAMING_RULE
     pattern: '^page\.(tsx|jsx|ts|js)$'
     rationale: Next.js App Router only renders the reserved filename page.tsx as a route; other filenames are treated as co-located modules, not routes
(+1 more matching pack rule(s) — Tier 3: read the full pack)

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §C-006: Every appointment records `booking_channel` — `online` for patient bookings, `staff` for receptionist-created appointments (source: PRD §5 BR-006)
- §F-001: Every page meets WCAG 2.2 AA — contrast ≥ 4.5:1 text / 3:1 UI, visible unobscured focus, targets ≥ 24×24 (44×44 touch), labelled inputs with in-text error identification, `role="status"` / `aria-live` for confirmations and slot updates, semantic landmarks, full keyboard reachability (source: PRD §6.1; PRD §8.4; PRD §Clinic.5 AC-007)
- §F-004: Patient personal data (name, email, phone, reason for visit) is handled per the applicable regional privacy regulation; until OQ-CLINIC-001 is answered no regulation-specific behavior is invented and no patient data is logged or persisted in this Next.js tier (source: PRD §6.1; context.md OQ-CLINIC-001)

(selector: `\b[A-F]-\d{3}\b` cited in U-013.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

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
consumed_t1: 12844 bytes (cap 12288)
consumed_t2: 5425 bytes (cap 10240, hard 12288)
total: 18269 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 23483    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - validation_hints: drop expected-output patterns; keep test commands only (saved 852 bytes)
  - validation_hints: drop section entirely (drop floor) (saved 957 bytes)
  - depends_on_summaries: keep 1 most-recent upstream (drop floor) (saved 339 bytes)
  - framework_pack_rules: top 1 rules (chain order, then in-file order) — drop floor: keep top 1 always (saved 321 bytes)
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
