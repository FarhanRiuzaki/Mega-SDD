═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-006
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-006

UNIT: U-006 "Build the public Kontak page with the contact form"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-006
title: Build the public Kontak page with the contact form
prd_source:
  - PRD/prd-company-profile.md#halaman-kontak
  - PRD/prd-company-profile.md#f-u-001-kirim-pesan-kontak
context_source: context.md#F-U-001
task_type: create
grounding_confidence: MEDIUM
module: M-default
depends_on: [U-005]
target_files:
  - path: src/app/(blank-layout-pages)/kontak/page.tsx
    operation: create
  - path: src/features/contact/repositories/contact.repository.ts
    operation: create
  - path: src/features/contact/hooks/useContact.ts
    operation: create
  - path: src/features/contact/components/ContactForm/index.tsx
    operation: create
  - path: src/features/contact/components/ContactForm/index.test.tsx
    operation: create
existing_interfaces:
  - file: src/libs/api/client.ts
    symbol: apiClient
    note: "consume as-is; throws Error(message) on non-OK"
allowed_new_deps: []
acceptance_test:
  - type: test
    command: "pnpm test:run src/features/contact/components/ContactForm/index.test.tsx"
    expects: "Test Files  1 passed (1)"
binding_refs:
  - OQ-DM-1
  - OQ-FL-1
  - OQ-AR-1
---

# Unit U-006 — Build the public Kontak page with the contact form

## Goal

Render the Kontak page with a labelled Nama / Email / Pesan form that submits through the house data flow, shows "Pesan terkirim" inline on success, and keeps the typed values with per-field errors on failure.

## Context (read first)

This implements the visitor side of F-U-001 (PRD §Halaman Kontak; context.md#F-U-001): page → hook → repository → apiClient → `/api/v1/contact-messages` created by U-005 (constitution C-001, B-003), with the same `contactMessageSchema` driving the per-field errors that the server enforces. The PRD asks for the success message on the same page, so feedback is an inline MUI `Alert`, not a snackbar.

## Anchors

- src/features/users/repositories/user.repository.ts:1-19 — repository returns the raw `apiClient` call
- src/features/users/hooks/useUsers.ts:1-20 — `'use client'` TanStack hook file shape
- src/features/contact/schemas/contact.schema.ts — `contactMessageSchema` + defaults created by U-005
- src/test/utils.tsx:37-42 — `renderWithProviders` returns a configured `user`

## Claims

- C-U006-01 "no kontak route exists yet" — expect: src/app/(blank-layout-pages)/kontak — must-not-exist
- C-U006-02 "apiClient browser fetcher exists" — expect: src/libs/api/client.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Ref: CLAUDE.md §Stack & Commands — the existing stack (MUI, next/link, react-hook-form, zod, TanStack Query, MSW) covers this unit; allowed_new_deps is empty
- NEVER use dangerouslySetInnerHTML or render raw visitor HTML (constitution B-002)
- NEVER call enqueueSnackbar in the repository (constitution C-002)

## Implementation steps

1. Create `contact.repository.ts` (`submitContactMessage` → `apiClient.post('/v1/contact-messages', body)`) and `useContact.ts` (`'use client'`, `useSubmitContactMessage` built on `useMutation` with no snackbar), then the `'use client'` `ContactForm` using react-hook-form + `zodResolver(contactMessageSchema)` with labelled MUI `TextField`s `Nama`, `Email`, `Pesan` (multiline), a native submit `Button` `Kirim`, field `helperText` errors, an inline success `Alert` reading `Pesan terkirim`, and an inline error `Alert` with the thrown message when the server rejects.
2. Create `src/app/(blank-layout-pages)/kontak/page.tsx` that exports `metadata` with title `Kontak` and renders a `Kontak` heading plus `ContactForm`.
3. Write `index.test.tsx` with `renderWithProviders` and MSW on `/api/v1/contact-messages` asserting: all three fields are reachable by label; an invalid email shows its error under Email, keeps the typed name and message, and sends no request; a valid submit shows `Pesan terkirim`; a 400 response shows the error alert and the typed values stay in the fields.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
OQ-DM-1 resolved (plan, runner-assumed): the form submits to `/api/v1/contact-messages` (U-005), which forwards to the upstream that owns `contact_messages`. TBD: OQ-FL-1 — final per-field error copy. TBD: OQ-AR-1 — final page URL (provisional `/kontak`).

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-006
  vault_sha256: 8b2467da2b9428545b2658e275ec9b299e561fb17b564538eeb0bb97818e6edf
  claims: (none cited)
  anchors_consulted:
    - src/features/users/repositories/user.repository.ts:1
    - src/features/users/hooks/useUsers.ts:1
    - src/test/utils.tsx:37
  anchors_verified: 3/3 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - NEVER use dangerouslySetInnerHTML or render raw visitor HTML (constitution B-002)
    - NEVER call enqueueSnackbar in the repository (constitution C-002)
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

- U-005 "Add the contact-message schema and the server-validating submit route" → committed at b243a5b0d100cbc5d1b867bf3b3c79866ba502c7
  └─ [success] Validation runs before any apiServer call; invalid/malformed bodies never reach upstream (zero-call counter asserted) — src: /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/vaults/company-profile/bolts/U-005/bolt-report.md

## Framework pack rules (filtered by your target_files glob match)

- framework-pack-naming-rule-001 (from next.md §Hard Rules emitted; matched glob `app/**/page.tsx` against `src/app/(blank-layout-pages)/kontak/page.tsx`)
  └─ Page files MUST be named page.tsx (not index.tsx, component.tsx, etc.) in the App Router
     rule_type: NAMING_RULE
     pattern: '^page\.(tsx|jsx|ts|js)$'
     rationale: Next.js App Router only renders the reserved filename page.tsx as a route; other filenames are treated as co-located modules, not routes
(+1 more matching pack rule(s) — Tier 3: read the full pack)

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §B-002: Input pengunjung hanya ditampilkan lewat escaping bawaan React; NEVER render HTML mentah dari pengunjung (tanpa `dangerouslySetInnerHTML`) (source: PRD §Non-functional — Keamanan)
- §B-003: Base URL upstream dan bearer token tetap di sisi server; browser hanya memanggil proxy same-origin `/api/v1` lewat `apiClient` (source: CLAUDE.md §Data flow; CLAUDE.md §Next.js API routes are thin proxies)
- §C-001: Alur data page → hook → repository → apiClient → proxy `/api/v1` → apiServer → upstream (source: CLAUDE.md §Data flow)
- §C-002: Repository mengembalikan response mentah; tidak ada `enqueueSnackbar` di repository (source: CLAUDE.md §Conventions worth following)

(selector: `\b[A-F]-\d{3}\b` cited in U-006.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

## Design system (UI-bearing unit — per context-enrichment.md §Design slice)


No design_system in this vault — raise it as an OQ at chain end; do not invent a palette or a type pairing.
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
consumed_t1: 7743 bytes (cap 12288)
consumed_t2: 4939 bytes (cap 10240, hard 12288)
total: 12682 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 17272    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - validation_hints: drop expected-output patterns; keep test commands only (saved 50 bytes)
  - validation_hints: drop section entirely (drop floor) (saved 154 bytes)
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

- Full upstream bolt-reports: `/Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/vaults/company-profile/bolts/U-XXX/bolt-report.md`
- Full constitution: `/Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/vaults/company-profile/constitution.md`
- Full framework pack: `/Users/<user>/.claude/plugins/cache/mega-sdd/mega-sdd/7.37.1/references/framework-conventions/<pack>.md`

═══════════════════════════════════════════
PROVENANCE — omissions (audit trail; NOT part of the T1/T2 byte accounting)
═══════════════════════════════════════════

Every absent or unresolvable input is recorded here rather than invented (invariant #5).

- t1.reuse_index_line: reuse-index.yaml absent at ./.mega-sdd/codebase/reuse-index.yaml — the Iron Rule 4 pointer line is NOT emitted for a file that does not exist (run scan-codebase to produce the index)
- t1.anti_context.do_not_modify.data_mutation_policy: no <kb>/99-rebuild-architecture/data-mutation-policy.md under . (searched .mega-sdd/, docs/, old-reference/ knowledge-base roots) — this source contributes nothing; the unit `## Hard rules` half is NOT relabelled to stand in for it
- t1.anti_context.do_not_modify: neither source produced an entry (data-mutation-policy.md [LOCKED] rows nor the unit's `## Hard rules` DO NOT/MUST NOT/NEVER modify lines) — line omitted
- reuse_slice: reuse-index.yaml absent at ./.mega-sdd/codebase/reuse-index.yaml (the T1 pointer line is omitted too)
- symbol_slice: no indexed symbol in or beside target_files
- starterkit_slice: no starterkit-context.yaml at ./.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice.system: vault.json carries no design_system — the raise-an-OQ note is emitted in its place, and no palette/typography/a11y value is defaulted
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/vaults/company-profile
- validation_hints: truncated to its drop floor (section dropped) by the T2 cascade
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
