═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-011
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-011

UNIT: U-011 "Add the branded patient shell layout"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-011
title: Add the branded patient shell layout
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:124, PRD/prd-clinic.md:128, PRD/prd-clinic.md:182]
task_type: create
grounding_confidence: LOW
risk: low
module: M-patient-booking
depends_on: []
target_files:
  - path: src/app/(patient)/layout.tsx
    operation: create
  - path: src/features/appointments/components/PatientShell/index.tsx
    operation: create
  - path: src/features/appointments/components/PatientShell/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/PatientShell/index.test.tsx --reporter=verbose"
    expects: "renders header main and footer landmarks"
  - type: test
    command: "pnpm test:run src/features/appointments/components/PatientShell/index.test.tsx --reporter=verbose"
    expects: "links the header navigation to the booking page"
  - type: test
    command: "pnpm test:run src/features/appointments/components/PatientShell/index.test.tsx --reporter=verbose"
    expects: "shows the product name as the brand text"
  - type: manual
    desc: "Open /book at a 375px-wide viewport: header, content and footer fit without horizontal scrolling and every link is reachable by keyboard with a visible focus ring."
binding_refs: [OQ-CN-1, OQ-CN-5]
---

# Unit U-011 — Add the branded patient shell layout

## Goal

Create the `(patient)` route-group layout and a `PatientShell` with a branded header (brand text + navigation), a main landmark and a footer, used by `/book` and `/reschedule/[token]`.

## Context (read first)

PRD §8.3 asks for page furniture — a branded header (logo + nav) and footer with width-filling composition — instead of a lone centered card, §8.4 requires semantic landmarks and keyboard reachability, and NFR-001 makes the patient flow work at 375px. Patient pages live outside the `(dashboard)` group, so they need their own layout wrapping `Providers` (theme, query client, session) without the admin navigation. The clinic's name and logo are not provided (OQ-CN-5), so the header shows the PRD product name "Clinic Appointment System" as text.

## Anchors

- src/app/(blank-layout-pages)/layout.tsx:1-29 — async layout wrapping children in `Providers direction='ltr'`; mirror it
- src/components/Providers.tsx:18-40 — provider stack (NextAuth → TanStack Query → VerticalNav → Settings → Theme)

## Claims

- C-U011-01 "Providers wraps the MUI theme and query client" — expect: src/components/Providers.tsx — must-exist
- C-U011-02 "no patient route group exists yet" — expect: src/app/(patient) — must-not-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/components/Providers.tsx
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file src/app/(patient)/layout.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST render semantic header, main and footer landmarks with a keyboard-reachable navigation and visible focus (constitution F-001)
  Source: constitution.md §F F-001
- MUST NOT show a logo image or clinic name that the PRD does not provide (context.md OQ-CN-5)
  Source: context.md OQ-CN-5
- MUST stay usable at a 375px viewport without horizontal scrolling (source: PRD §Clinic.2 NFR-001)
  Source: PRD §Clinic.2 NFR-001

## Implementation steps

1. Create `src/app/(patient)/layout.tsx` as an async server layout that mirrors the blank-layout anchor: `<Providers direction='ltr'><PatientShell>{children}</PatientShell></Providers>`, with `metadata` title template `%s — Clinic Appointment System`.
2. Create the client component `PatientShell` rendering a `<header>` containing the brand text "Clinic Appointment System" (a heading-styled `Link` to `/book`) and a `<nav aria-label='Primary'>` with the link "Book an appointment" to `/book`, a `<main id='main-content'>` that lets its children fill the available width (MUI `Container maxWidth='lg'` with responsive padding), and a `<footer>` with the product name and the current year; apply the primary color only to the brand text and active link, keep targets ≥ 44px tall on touch, and use MUI breakpoints so the header wraps cleanly at 375px.
3. Write `index.test.tsx` with `renderWithProviders` and the three tests named exactly as the acceptance_test `expects` strings (landmarks by role `banner`, `main`, `contentinfo`; the nav link's `href` is `/book`; the brand text is present and no `img` is rendered).

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-5 — replace the text brand with the clinic's name and logo once provided.

## Out of scope

- The booking wizard — U-013
- The reschedule page — U-014

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-011
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted:
    - src/app/(blank-layout-pages)/layout.tsx:1
    - src/components/Providers.tsx:18
  anchors_verified: 2/2 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - DO NOT modify src/components/Providers.tsx
    - file src/app/(patient)/layout.tsx MUST exist after bolt
    - MUST render semantic header, main and footer landmarks with a keyboard-reachable navigation and visible focus (constitution F-001)
    - MUST NOT show a logo image or clinic name that the PRD does not provide (context.md OQ-CN-5)
    - MUST stay usable at a 375px viewport without horizontal scrolling (source: PRD §Clinic.2 NFR-001)
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
  - src/components/Providers.tsx  (source: U-011.md `## Hard rules`)
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

## Framework pack rules (filtered by your target_files glob match)

- framework-pack-custom-001 (from next.md §Hard Rules emitted; matched glob `app/**/*.tsx` against `src/app/(patient)/layout.tsx`)
  └─ Data mutations MUST go through Server Actions or Route Handlers, not direct DB calls from Client Components
     rule_type: CUSTOM
     rationale: Client Components cannot securely access databases or secrets; mutations must be server-side

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §F-001: Every page meets WCAG 2.2 AA — contrast ≥ 4.5:1 text / 3:1 UI, visible unobscured focus, targets ≥ 24×24 (44×44 touch), labelled inputs with in-text error identification, `role="status"` / `aria-live` for confirmations and slot updates, semantic landmarks, full keyboard reachability (source: PRD §6.1; PRD §8.4; PRD §Clinic.5 AC-007)

(selector: `\b[A-F]-\d{3}\b` cited in U-011.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

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
consumed_t1: 8854 bytes (cap 12288)
consumed_t2: 4299 bytes (cap 10240, hard 12288)
total: 13153 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 17916    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - validation_hints: drop expected-output patterns; keep test commands only (saved 380 bytes)
  - validation_hints: drop section entirely (drop floor) (saved 399 bytes)
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
- depends_on_summaries: unit has no depends_on entries
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
