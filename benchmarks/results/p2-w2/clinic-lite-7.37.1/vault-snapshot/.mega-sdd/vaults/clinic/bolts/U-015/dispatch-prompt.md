═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-015
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-015

UNIT: U-015 "Add the /staff/login page on the existing credentials login"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-015
title: Add the /staff/login page on the existing credentials login
context_source: context.md#F-S-001
prd_source: [PRD/prd-clinic.md:195, PRD/prd-clinic.md:170]
task_type: create
grounding_confidence: LOW
risk: medium
module: M-staff
depends_on: []
target_files:
  - path: src/app/(blank-layout-pages)/staff/login/page.tsx
    operation: create
  - path: src/app/(blank-layout-pages)/staff/login/page.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (no gaps)
  - type: test
    command: "pnpm test:run src/app/(blank-layout-pages)/staff/login/page.test.tsx --reporter=verbose"
    expects: "renders the existing credentials login view for staff"
  - type: test
    command: "pnpm test:run src/app/(blank-layout-pages)/staff/login/page.test.tsx --reporter=verbose"
    expects: "sets the staff login page title"
binding_refs: [OQ-CN-1]
---

# Unit U-015 — Add the /staff/login page on the existing credentials login

## Goal

Expose PRD §Clinic.3's `/staff/login` by rendering the existing next-auth credentials `Login` view.

## Context (read first)

F-S-001/F-S-002 start with a staff login and PRD §Clinic.3 names `/staff/login`; per the OQ-CN-1 recommendation staff keep the existing next-auth credentials flow, so this page reuses `@views/Login` exactly like `/login`.

## Anchors

- src/app/(blank-layout-pages)/login/page.tsx:1-22 — the page to mirror (metadata + `getServerMode` + `<Login mode={mode} />`)

## Claims

- C-U015-01 "the credentials login page exists" — expect: src/app/(blank-layout-pages)/login/page.tsx — must-exist
- C-U015-02 "the Login view exists" — expect: src/views/Login.tsx — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/views/Login.tsx
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- DO NOT modify src/libs/auth.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file src/app/(blank-layout-pages)/staff/login/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE

## Implementation steps

1. Create `src/app/(blank-layout-pages)/staff/login/page.tsx` mirroring the login page anchor, with `metadata = { title: 'Staff login', description: 'Clinic staff sign-in' }`.
2. Write `page.test.tsx` mocking `@core/utils/serverHelpers` (`getServerMode` → `'light'`) and `@views/Login` (a stub echoing `mode`), rendering the awaited page, with the two tests named exactly as the acceptance_test `expects` strings.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-015
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted:
    - src/app/(blank-layout-pages)/login/page.tsx:1
  anchors_verified: 1/1 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - DO NOT modify src/views/Login.tsx
    - DO NOT modify src/libs/auth.ts
    - file src/app/(blank-layout-pages)/staff/login/page.tsx MUST exist after bolt
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
  - src/views/Login.tsx  (source: U-015.md `## Hard rules`)
  - src/libs/auth.ts  (source: U-015.md `## Hard rules`)
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

- framework-pack-naming-rule-001 (from next.md §Hard Rules emitted; matched glob `app/**/page.tsx` against `src/app/(blank-layout-pages)/staff/login/page.tsx`)
  └─ Page files MUST be named page.tsx (not index.tsx, component.tsx, etc.) in the App Router
     rule_type: NAMING_RULE
     pattern: '^page\.(tsx|jsx|ts|js)$'
     rationale: Next.js App Router only renders the reserved filename page.tsx as a route; other filenames are treated as co-located modules, not routes
(+1 more matching pack rule(s) — Tier 3: read the full pack)

## Design system (UI-bearing unit — per context-enrichment.md §Design slice)


Design system: style=clinical, trustworthy, anti-generic — brand color on high-signal elements only · palette=primary teal-700 #0E7490 (white foreground, 5.36:1); accent/success green-700 #15803D (5.02:1); raw #0891B2 / #16A34A only for fills, charts and icon accents · typography=humanist sans body with a real type scale; optional serif display headers · a11y=WCAG 2.2 AA — source: vault.json design_system (provenance excluded, audit-only)
UX floor: (ux-rules.md — Accessibility/Forms/Feedback rows)
  - Accessibility/Color Contrast: DO Minimum 4.5:1 ratio for normal text; DON'T Low contrast text [High]
  - Accessibility/Color Only: DO Use icons/text in addition to color; DON'T Red/green only for error/success [High]
  - Accessibility/Alt Text: DO Descriptive alt text for meaningful images; DON'T Empty or missing alt attributes [High]
  - Accessibility/Heading Hierarchy: DO Use sequential heading levels h1-h6; DON'T Skip heading levels or misuse for styling [Medium]
  - Accessibility/ARIA Labels: DO Add aria-label for icon-only buttons; DON'T Icon buttons without labels [High]
  - Accessibility/Keyboard Navigation: DO Tab order matches visual order; DON'T Keyboard traps or illogical tab order [High]
  - Accessibility/Screen Reader: DO Use semantic HTML and ARIA properly; DON'T Div soup with no semantics [Medium]
  - Accessibility/Form Labels: DO Use label with for attribute or wrap input; DON'T Placeholder-only inputs [High]
  - Accessibility/Error Messages: DO Use aria-live or role=alert for errors; DON'T Visual-only error indication [High]
  - Accessibility/Skip Links: DO Provide skip to main content link; DON'T No skip link on nav-heavy pages [Medium]
  - Forms/Input Labels: DO Always show label above or beside input; DON'T Placeholder as only label [High]
  - Forms/Error Placement: DO Show error below related input; DON'T Single error message at top of form [Medium]
  - Forms/Inline Validation: DO Validate on blur for most fields; DON'T Validate only on submit [Medium]
  - Forms/Input Types: DO Use email tel number url etc; DON'T Text input for everything [Medium]
  - Forms/Autofill Support: DO Use autocomplete attribute properly; DON'T Block or ignore autofill [Medium]
  - Forms/Required Indicators: DO Use asterisk or (required) text; DON'T No indication of required fields [Medium]
  - Forms/Password Visibility: DO Toggle to show/hide password; DON'T No visibility toggle [Medium]
  - Forms/Submit Feedback: DO Show loading then success/error state; DON'T No feedback after submit [High]
  - Forms/Input Affordance: DO Use distinct input styling; DON'T Inputs that look like plain text [Medium]
  - Forms/Mobile Keyboards: DO Use inputmode attribute; DON'T Default keyboard for all inputs [Medium]
  - Feedback/Loading Indicators: DO Show spinner/skeleton for operations > 300ms; DON'T No feedback during loading [High]
  - Feedback/Empty States: DO Show helpful message and action; DON'T Blank empty screens [Medium]
  - Feedback/Error Recovery: DO Provide clear next steps; DON'T Error without recovery path [Medium]
  - Feedback/Progress Indicators: DO Step indicators or progress bar; DON'T No indication of progress [Medium]
  - Feedback/Toast Notifications: DO Auto-dismiss after 3-5 seconds; DON'T Toasts that never disappear [Medium]
  - Feedback/Confirmation Messages: DO Brief success message; DON'T Silent success [Medium]
  - Accessibility/Motion Sensitivity: DO Respect prefers-reduced-motion; DON'T Force scroll effects [High]
Modern baseline (non-negotiables — the FLOOR):
1. **Design tokens first.** Define/extend a token layer (CSS custom properties
   or the framework's token mechanism) for color, spacing, radius, and type
   scale — then USE it. Hardcoded one-off hex/px values scattered per element
   are the #1 "kuno" tell. The vault `design_system.palette` is the source for
   color tokens; never invent a second palette.
2. **Spacing system, not ad-hoc gaps.** 4/8px scale (4, 8, 12, 16, 24, 32, 48,
   64). Consistent vertical rhythm; whitespace is a design element — cramped
   tables-of-inputs read as 1995.
3. **Typographic scale.** One pairing (per `design_system.typography` /
   `typography-pairings.md`), loaded properly; a modular scale (e.g. 1.25) for
   h1→small; line-height ≥1.5 body; max line length ~65–75ch. Never default
   Times/system-serif walls of text.
4. **Layout is composed, not stacked.** A real page shell: constrained content
   width (e.g. max-w + centered), header/nav, generous section spacing,
   CSS grid/flex for structure. Responsive at 375px AND desktop — mobile is a
   layout, not an afterthought.
5. **Interactive states exist.** Every button/input/link has hover, focus
   (VISIBLE focus ring), active, and disabled states. Transitions are subtle
   (~150–250ms ease) and purposeful — no state changes that just snap.
6. **Feedback states exist.** Loading (skeleton or spinner with label), empty
   ("no appointments yet" + the action to create one), and error (inline,
   human language, recovery path) — for every async surface. A blank div while
   fetching is a defect.
7. **Forms are designed.** Labels above inputs, visible focus, inline
   validation messages near the field, primary action visually dominant,
   destructive actions visually distinct + confirmed via the project's dialog
   idiom (never native `alert`/`confirm`).
8. **Accessibility floor = WCAG AA** (or the vault `design_system.a11y_level`):
   contrast ≥4.5:1 body text, semantic landmarks (header/nav/main), every
   input labelled, keyboard-reachable interactive elements, alt text.
9. **Tables are for data — styled.** Density options, right-aligned numerics,
   formatted money/dates, row hover, sticky header on long lists; on mobile,
   collapse to cards or allow horizontal scroll deliberately.
10. **Distinctive, not generic.** Commit to the vault's chosen style (e.g.
    "Accessible & Ethical + Minimalism") and express it in 2–3 memorable moves
    (a signature accent usage, a distinctive radius/elevation language, a
    typographic personality) — avoid the interchangeable bootstrap-default and
    purple-gradient-AI looks alike.
Ceiling moves (clear the floor, then DO these — a floor-only view is "basic/generic"):
The non-negotiables above are the FLOOR: passing them means "not broken, not
default-browser, accessible." It does NOT mean done. A view that satisfies all
10 and stops there reads as **correct but generic** — a lone centered card on an
empty page, flat hierarchy, no personality. Field finding (clinic-project): the
floor passed; the result was still "basic banget." Every UI bolt MUST also make
the page feel like a designed product:

1. **Page furniture.** A real branded header (logo/wordmark + primary nav) and a
   footer — not a bare `<h1>` over a centered card. The app should feel like it
   has a frame, not float in whitespace.
2. **Composition, not a lone card.** Fill the width with intent: a two-column
   layout (primary action + a supporting panel — summary, help, illustration,
   trust signals), a hero on landing/empty pages, or a content grid. A single
   centered 480px card on a 1280px page is the #1 "basic" tell.
3. **Iconography.** Use an icon set (lucide, heroicons, the stack's idiom) for
   actions, nav, status, and empty states. Icon + label, never icon-only for
   primary actions. Plain-text-only UIs read as unfinished.
4. **Visual hierarchy with depth.** More than one type size and weight in play;
   section headers, supporting text, and metadata visually distinct. Use
   elevation/borders/background tints to group — not everything on one flat plane.
5. **A signature.** Commit to 2–3 memorable expressions of the chosen style: a
   distinctive accent usage, a consistent radius/elevation language, an
   illustrative or photographic moment, a confident empty-state. Pick the style's
   personality and show it — don't render the interchangeable default.
6. **Motion with purpose.** Entrance/hover/transition micro-interactions
   (subtle, 150–250ms) on the primary surfaces — buttons, cards, step changes.
7. **Density that fits the product.** A clinical tool, a consumer booking flow,
   and a dashboard have different densities — match the product, don't ship the
   same sparse centered form for everything.

A design-reviewer judging a UI bolt treats "floor met, ceiling absent" as an
**Important** finding (generic/undesigned), not a pass. When a rendered
screenshot of the running view is available, judge the ceiling from the render —
the floor is provable from code, the ceiling usually is not.
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
consumed_t1: 6422 bytes (cap 12288)
consumed_t2: 10058 bytes (cap 10240, hard 12288)
total: 16480 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 21308    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - validation_hints: drop expected-output patterns; keep test commands only (saved 136 bytes)
  - validation_hints: drop section entirely (drop floor) (saved 269 bytes)
  - framework_pack_rules: top 1 rules (chain order, then in-file order) — drop floor: keep top 1 always (saved 339 bytes)
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
- constitution_clauses: unit cites no [A-F]-NNN clause id
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
