═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-005
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-005

UNIT: U-005 "Buat Halaman Kontak dengan form kirim pesan"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-005
title: Buat Halaman Kontak dengan form kirim pesan
prd_source: [PRD/prd-company-profile.md#halaman-kontak, PRD/prd-company-profile.md#f-u-001-kirim-pesan-kontak]
context_source: context.md#F-U-001
task_type: create
grounding_confidence: MEDIUM
risk: medium
module: M-default
depends_on: [U-004]
target_files:
  - path: src/features/contact/repositories/contact.repository.ts
    operation: create
  - path: src/features/contact/hooks/useContact.ts
    operation: create
  - path: src/features/contact/components/ContactForm/index.tsx
    operation: create
  - path: src/features/contact/components/ContactForm/index.test.tsx
    operation: create
  - path: src/app/(blank-layout-pages)/kontak/page.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:
  - type: test
    command: "pnpm test:run src/features/contact/components/ContactForm"
    expects: "passed"
  - type: manual
    desc: "Buka /kontak, isi form hanya dengan keyboard (Tab antar field berlabel, Enter/Space di tombol Kirim); pesan valid menampilkan 'Pesan terkirim'"
binding_refs: [OQ-AR-1, OQ-AR-2, OQ-FL-1]
---

# Unit U-005 — Buat Halaman Kontak dengan form kirim pesan

## Goal

Halaman `/kontak` punya form nama/email/pesan yang menampilkan error per field tanpa mengosongkan isian, dan "Pesan terkirim" saat sukses.

## Context (read first)

Ini langkah 1–2 dan hasil tampilan F-U-001 (context.md#F-U-001), memakai schema dari U-004 dan endpoint `/api/v1/contact-messages` (OQ-AR-1). Perilaku reset form setelah sukses belum diputuskan (OQ-FL-1, deferred) — jangan mengosongkan form.

## Anchors

- src/features/users/repositories/user.repository.ts:14 — pola repository `apiClient.post`
- src/libs/api/client.ts:10 — `apiClient` ke proxy same-origin, throw saat `!res.ok`
- src/test/utils.tsx:36 — `renderWithProviders`; src/test/handlers.ts:72 — `server` MSW untuk `server.use(...)`

## Claims

- C-U005-01 "apiClient memanggil proxy same-origin /api dan throw saat respons tidak ok" — expect: src/libs/api/client.ts:apiClient
- C-U005-02 "harness test menyediakan renderWithProviders" — expect: src/test/utils.tsx:renderWithProviders
- C-U005-03 "belum ada halaman kontak" — expect: src/app/(blank-layout-pages)/kontak — must-not-exist
- C-U005-04 "belum ada komponen form kontak" — expect: src/features/contact/components — must-not-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md#Constraints — stack existing (package.json); allowed_new_deps: []
- DO NOT modify src/libs/api/client.ts
  Source: constitution.md §C-001 — shared data-flow layer
- DO NOT modify src/features/contact/schemas/contact.schema.ts
  Source: U-004 target_files — U-004 owns the schema
- file src/features/contact/components/ContactForm/index.test.tsx MUST exist after bolt
  Source: frontmatter acceptance_test; constitution.md §A-003
- NEVER render visitor input through dangerouslySetInnerHTML
  Source: constitution.md §B-001
- MUST give every form field a visible label and keep the form operable by keyboard
  Source: constitution.md §A-004

## Implementation steps

1. Buat `contact.repository.ts` (`sendContactMessage` → `apiClient.post('/v1/contact-messages', body)`) dan `useContact.ts` dengan `useMutation`; sukses ditampilkan inline di halaman, bukan snackbar, karena PRD meminta pesan sukses di halaman yang sama.
2. Buat `ContactForm` (`'use client'`, react-hook-form + `zodResolver` dengan schema U-004) berisi field berlabel nama/email/pesan dengan error per field; kirim → mutate; sukses → alert "Pesan terkirim"; penolakan server → alert error; isian tidak pernah di-reset. Lalu `page.tsx` di `(blank-layout-pages)/kontak` merender form dengan `metadata`.
3. Tulis `index.test.tsx`: email tidak valid → error tampil di field email, nama + pesan tetap terisi, tidak ada request; payload valid (MSW `POST /api/v1/contact-messages`) → "Pesan terkirim"; server membalas 400 → isian tetap terisi.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.0)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-005
  vault_sha256: 5a6df0df8f66565fcc41f0c03a0c5938790763275cffaa6b25ff9be14a7f41e2
  claims: (none cited)
  anchors_consulted:
    - src/features/users/repositories/user.repository.ts:14
    - src/libs/api/client.ts:10
    - src/test/utils.tsx:36
    - src/test/handlers.ts:72
  anchors_verified: 4/4 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - DO NOT modify src/libs/api/client.ts
    - DO NOT modify src/features/contact/schemas/contact.schema.ts
    - file src/features/contact/components/ContactForm/index.test.tsx MUST exist after bolt
    - NEVER render visitor input through dangerouslySetInnerHTML
    - MUST give every form field a visible label and keep the form operable by keyboard
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
  - src/libs/api/client.ts  (source: U-005.md `## Hard rules`)
  - src/features/contact/schemas/contact.schema.ts  (source: U-005.md `## Hard rules`)
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

- U-004 "Buat schema pesan kontak dan route handler penyimpanan" → committed at 3629a3b169e4de12b905dfdb64fb79abdfa15441
  └─ [success] Validation runs server-side via contactFormSchema.safeParse before any apiServer call; invalid input returns 400 without an upstream request (asserted by an MSW…(truncated) — src: /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/vaults/company-profile/bolts/U-004/bolt-report.md

## Framework pack rules (filtered by your target_files glob match)

- framework-pack-naming-rule-001 (from next.md §Hard Rules emitted; matched glob `app/**/page.tsx` against `src/app/(blank-layout-pages)/kontak/page.tsx`)
  └─ Page files MUST be named page.tsx (not index.tsx, component.tsx, etc.) in the App Router
     rule_type: NAMING_RULE
     pattern: '^page\.(tsx|jsx|ts|js)$'
     rationale: Next.js App Router only renders the reserved filename page.tsx as a route; other filenames are treated as co-located modules, not routes
(+1 more matching pack rule(s) — Tier 3: read the full pack)

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §A-003: Test memakai Vitest + React Testing Library + MSW dari harness `src/test/`; `pnpm test:run` harus lulus (source: CLAUDE.md §Stack & Commands)
- §A-004: Semua field form berlabel dan navigasi keyboard berfungsi (source: PRD §Non-functional — Aksesibilitas)
- §B-001: Input pengunjung di-escape saat ditampilkan; tidak ada HTML mentah dari pengunjung — `dangerouslySetInnerHTML` tidak dipakai untuk data pengunjung (source: PRD §Non-functional — Keamanan)
- §C-001: Alur data page → hook → repository → `apiClient` → proxy `/api/v1` → `apiServer` → upstream; `apiServer` hanya dari route handler / RSC, `apiClient` hanya dari komponen `'use client'` (source: CLAUDE.md §Data flow, CLAUDE.md §Conventions worth following)

(selector: `\b[A-F]-\d{3}\b` cited in U-005.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

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
consumed_t1: 7925 bytes (cap 12288)
consumed_t2: 5036 bytes (cap 10240, hard 12288)
total: 12961 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 17573    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - validation_hints: drop expected-output patterns; keep test commands only (saved 186 bytes)
  - validation_hints: drop section entirely (drop floor) (saved 139 bytes)
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
- Full framework pack: `/Users/<user>/.claude/plugins/cache/mega-sdd/mega-sdd/7.37.0/references/framework-conventions/<pack>.md`

═══════════════════════════════════════════
PROVENANCE — omissions (audit trail; NOT part of the T1/T2 byte accounting)
═══════════════════════════════════════════

Every absent or unresolvable input is recorded here rather than invented (invariant #5).

- t1.reuse_index_line: reuse-index.yaml absent at ./.mega-sdd/codebase/reuse-index.yaml — the Iron Rule 4 pointer line is NOT emitted for a file that does not exist (run scan-codebase to produce the index)
- t1.anti_context.do_not_modify.data_mutation_policy: no <kb>/99-rebuild-architecture/data-mutation-policy.md under /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite (searched .mega-sdd/, docs/, old-reference/ knowledge-base roots) — this source contributes nothing; the unit `## Hard rules` half is NOT relabelled to stand in for it
- reuse_slice: reuse-index.yaml absent at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/codebase/reuse-index.yaml (the T1 pointer line is omitted too)
- symbol_slice: no indexed symbol in or beside target_files
- starterkit_slice: no starterkit-context.yaml at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice.system: vault.json carries no design_system — the raise-an-OQ note is emitted in its place, and no palette/typography/a11y value is defaulted
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/vaults/company-profile
- validation_hints: truncated to its drop floor (section dropped) by the T2 cascade
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
