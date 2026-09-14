═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-004
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-004

UNIT: U-004 "Buat schema pesan kontak dan route handler penyimpanan"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)

---

id: U-004
title: Buat schema pesan kontak dan route handler penyimpanan
prd_source: [PRD/prd-company-profile.md#halaman-kontak, PRD/prd-company-profile.md#alur, PRD/prd-company-profile.md#f-u-001-kirim-pesan-kontak]
context_source: context.md#F-U-001
task_type: create
grounding_confidence: MEDIUM
risk: medium
module: M-default
depends_on: []
target_files:

- path: src/features/contact/schemas/contact.schema.ts
  operation: create
- path: src/features/contact/types/index.ts
  operation: create
- path: src/app/api/v1/contact-messages/route.ts
  operation: create
- path: src/app/api/v1/contact-messages/route.test.ts
  operation: create
  existing_interfaces: []
  allowed_new_deps: []
  acceptance_test:
- type: test
  command: "pnpm test:run src/app/api/v1/contact-messages"
  expects: "passed"
  binding_refs: [OQ-AR-1]

---

# Unit U-004 — Buat schema pesan kontak dan route handler penyimpanan

## Goal

`POST /api/v1/contact-messages` memvalidasi nama/email/pesan di server lalu menyimpan pesan valid (dengan `created_at`) ke upstream.

## Context (read first)

Ini langkah 3–5 F-U-001 sisi server (context.md#F-U-001): aturan field dari PRD §Halaman Kontak dan batas `email` varchar(255) dari §Data model. Penyimpanan mengikuti rekomendasi OQ-AR-1 — upstream `POST /v1/contact-messages` via `apiServer`, route handler mengisi `created_at`.

## Anchors

- src/libs/api/server.ts:9 — `apiServer` (envelope `ApiResponse<T>`, tidak throw)
- src/libs/api/route-handler.ts:19 — `respond()`: envelope gagal → status 400, sukses → 200
- src/features/users/schemas/user.schema.ts:3 — pola schema zod + tipe inferensi + defaults
- src/app/api/v1/users/route.ts:1 — pola lokasi route proxy `/api/v1/*`

## Claims

- C-U004-01 "apiServer adalah fetcher server yang mengembalikan envelope ApiResponse" — expect: src/libs/api/server.ts:apiServer
- C-U004-02 "belum ada route contact-messages" — expect: src/app/api/v1/contact-messages — must-not-exist
- C-U004-03 "belum ada schema kontak" — expect: src/features/contact/schemas — must-not-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: OQ-AR-1 recommendation — no new DB dependency; allowed_new_deps: []
- DO NOT modify src/libs/api/server.ts
  Source: constitution.md §C-001 — shared data-flow layer
- DO NOT modify src/libs/api/route-handler.ts
  Source: constitution.md §C-001 — shared data-flow layer
- file src/app/api/v1/contact-messages/route.ts MUST exist after bolt
  Source: OQ-AR-1 recommendation
- MUST validate name, email and message with the zod schema on the server before calling apiServer
  Source: constitution.md §B-002
- MUST reach the upstream only through apiServer inside the route handler
  Source: constitution.md §B-003, constitution.md §C-001

## Implementation steps

1. Buat `contact.schema.ts` (+ tipe di `types/index.ts`) dengan zod: `name` di-trim, wajib, ≤ 100; `email` wajib, format email valid, ≤ 255; `message` di-trim, wajib, ≤ 2000 — pesan error berbahasa Indonesia per field — plus `contactFormDefaults` kosong untuk form U-005.
2. Buat `route.ts` dengan `POST` yang mem-parse body (JSON rusak → 400), menjalankan `safeParse`, dan saat gagal mengembalikan 400 envelope `{ success: false, code: 'VALIDATION_ERROR', message, data: { fieldErrors } }` tanpa memanggil upstream; saat valid meneruskan `{ name, email, message, created_at: new Date().toISOString() }` lewat `apiServer.post('/v1/contact-messages', …)` dan mengembalikan envelope-nya dengan status seperti `respond()`.
3. Tulis `route.test.ts` (`// @vitest-environment node`, mock `getServerSession` → null, MSW handler upstream di `${NEXT_PUBLIC_API_URL}/v1/contact-messages`) yang membuktikan: payload valid → 200 dan upstream menerima `created_at` ISO; email tidak valid → 400 dengan `fieldErrors.email` dan upstream tidak dipanggil; nama 101 karakter, nama berisi spasi saja, pesan 2001 karakter, field kosong, dan JSON rusak → 400.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.0)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-004
  vault_sha256: c41836e0b3f24c9d00828b99f03dc0569b5f77cdf5cdb3e190d15946c4df9b8e
  claims: (none cited)
  anchors_consulted:
    - src/libs/api/server.ts:9
    - src/libs/api/route-handler.ts:19
    - src/features/users/schemas/user.schema.ts:3
    - src/app/api/v1/users/route.ts:1
  anchors_verified: 4/4 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - DO NOT modify src/libs/api/server.ts
    - DO NOT modify src/libs/api/route-handler.ts
    - file src/app/api/v1/contact-messages/route.ts MUST exist after bolt
    - MUST validate name, email and message with the zod schema on the server before calling apiServer
    - MUST reach the upstream only through apiServer inside the route handler
```

## Acceptance-test provenance NOTE

> NOTE: This unit's `acceptance_test` has weak blind-spot coverage
> (\_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that
> wrote the unit body — the test may inherit the same blind spots as the spec
> and fail to catch behavioral bugs your implementation introduces.
>
> If your implementation passes this test but feels under-validated:
>
> - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`
>   explaining what you suspect the test might miss
> - Propose 1-2 additional assertions you'd add to strengthen coverage
> - Mark `confidence` no higher than MEDIUM for behaviors not directly tested

## Anti-context (negative space = freedom + protection)

DO NOT MODIFY:

- src/libs/api/server.ts (source: U-004.md `## Hard rules`)
- src/libs/api/route-handler.ts (source: U-004.md `## Hard rules`)
  DO NOT WRITE:
- Tables without `id` primary key (denormalized intermediate tables OK as composite PK) (from \_universal.md §Forbidden patterns)
- Tables without `created_at` + `updated_at` timestamps (unless explicitly immutable like audit logs) (from \_universal.md §Forbidden patterns)
- VARCHAR(255) used as default type for everything (use proper sized/typed columns) (from \_universal.md §Forbidden patterns)
- Comma-delimited values in single columns (use junction tables) (from \_universal.md §Forbidden patterns)
- Date/time stored as VARCHAR/INT (use proper TIMESTAMP/DATETIME types) (from \_universal.md §Forbidden patterns)
- Foreign keys without explicit constraint (`ON DELETE`/`ON UPDATE` defined) (from \_universal.md §Forbidden patterns)
  DO NOT COMMIT IF: any `acceptance_test` command in this unit fails; any `## Hard rules` line above is violated; a modified file is missing its provenance trailer

═══════════════════════════════════════════
TIER 2 — Conditional context (target ≤10KB total)
═══════════════════════════════════════════

## Framework pack rules (filtered by your target_files glob match)

- framework-pack-custom-001 (from next.md §Hard Rules emitted; matched glob `app/**/*.ts` against `src/app/api/v1/contact-messages/route.ts`)
  └─ Server Actions MUST be in files with "use server" directive OR in async functions tagged "use server"
  rule_type: CUSTOM
  rationale: Server Actions without the directive run as Client-side code, exposing server logic or causing runtime errors
- framework-pack-naming-rule-001 (from next.md §Hard Rules emitted; matched glob `app/**/route.ts` against `src/app/api/v1/contact-messages/route.ts`)
  └─ Route Handler files MUST be named route.ts (not handler.ts, api.ts, etc.)
  rule_type: NAMING_RULE
  pattern: '^route\.(ts|js)$'
  rationale: Next.js file-based routing only recognizes the reserved name route.ts for HTTP handlers

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §B-002: Field form kontak (nama, email, pesan) divalidasi di sisi server sebelum disimpan (source: PRD §Halaman Kontak)
- §B-003: URL upstream dan bearer token tetap server-side; browser hanya memanggil proxy same-origin `/api/v1/*` (source: CLAUDE.md §Next.js API routes are thin proxies)
- §C-001: Alur data page → hook → repository → `apiClient` → proxy `/api/v1` → `apiServer` → upstream; `apiServer` hanya dari route handler / RSC, `apiClient` hanya dari komponen `'use client'` (source: CLAUDE.md §Data flow, CLAUDE.md §Conventions worth following)

(selector: `\b[A-F]-\d{3}\b` cited in U-004.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

## Validation hints (specific, not vague)

After implementation, run:

```bash
pnpm test:run src/app/api/v1/contact-messages
```

Expected output pattern: passed

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 7913 bytes (cap 12288)
consumed_t2: 1868 bytes (cap 10240, hard 12288)
total: 9781 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 14140    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - (none)
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
- depends_on_summaries: unit has no depends_on entries
- reuse_slice: reuse-index.yaml absent at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/codebase/reuse-index.yaml (the T1 pointer line is omitted too)
- symbol_slice: no indexed symbol in or beside target_files
- starterkit_slice: no starterkit-context.yaml at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice: unit is not ui_bearing (no target_files path matched the pack view_glob or any universal frontend shape)
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/vaults/company-profile
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- design_slice_path: unit is not ui_bearing, so no design lens is dispatched for it — no lens-input file is written and the `design_slice_path` key is ABSENT (a rubric with no reader is a cost, not a contribution)
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
