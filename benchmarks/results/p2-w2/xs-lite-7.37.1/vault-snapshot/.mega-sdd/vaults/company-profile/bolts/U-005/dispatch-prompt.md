═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-005
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-005

UNIT: U-005 "Add the contact-message schema and the server-validating submit route"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-005
title: Add the contact-message schema and the server-validating submit route
prd_source:
  - PRD/prd-company-profile.md#halaman-kontak
  - PRD/prd-company-profile.md#alur
  - PRD/prd-company-profile.md#f-u-001-kirim-pesan-kontak
  - PRD/prd-company-profile.md#data-model
context_source: context.md#F-U-001
task_type: create
grounding_confidence: MEDIUM
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
existing_interfaces:
  - file: src/libs/api/server.ts
    symbol: apiServer
    note: "consume as-is; returns the ApiResponse envelope and never throws"
allowed_new_deps: []
acceptance_test:
  - type: test
    command: "pnpm test:run src/app/api/v1/contact-messages/route.test.ts"
    expects: "Test Files  1 passed (1)"
binding_refs:
  - OQ-DM-1
  - OQ-FL-1
---

# Unit U-005 — Add the contact-message schema and the server-validating submit route

## Goal

Validate a contact message on the server with one shared zod schema and forward only valid messages, stamped with `created_at`, to the upstream that owns `contact_messages`.

## Context (read first)

F-U-001 steps 3–5 require server-side validation (name required ≤100, email required and valid, message required ≤2000) before saving to `contact_messages` (PRD §Halaman Kontak, §Data model; context.md#F-U-001; constitution B-001). `proxyPost` forwards bodies unvalidated, so this route hand-writes the POST but keeps the factory's envelope and status mapping; persistence goes through `apiServer` per OQ-DM-1.

## Anchors

- src/libs/api/route-handler.ts:19-21 — `respond()` maps a failed envelope to HTTP 400; mirror this status mapping
- src/app/api/v1/users/route.ts:1-4 — proxy route shape under `src/app/api/v1/**`
- src/libs/api/server.ts:9-26 — `apiServer.post` returns the `ApiResponse<T>` envelope
- src/features/users/schemas/user.schema.ts:1-25 — schema file exports schema + inferred type + defaults
- src/test/handlers.ts:1-20 — MSW `server` + envelope helper; upstream origin is `http://localhost:3000` in Vitest

## Claims

- C-U005-01 "no contact-messages proxy route exists yet" — expect: src/app/api/v1/contact-messages — must-not-exist
- C-U005-02 "apiServer server fetcher exists" — expect: src/libs/api/server.ts — must-exist
- C-U005-03 "createFetcher is the shared fetcher core" — expect: src/libs/api/base-fetcher.ts:createFetcher

## Hard rules

- DO NOT modify src/libs/api/route-handler.ts
  Source: constitution.md C-001 — the shared proxy factory serves every other /api/v1 route; this unit mirrors its status mapping instead
- DO NOT add new package.json dependencies
  Ref: CLAUDE.md §Stack & Commands — the existing stack (MUI, next/link, react-hook-form, zod, TanStack Query, MSW) covers this unit; allowed_new_deps is empty
- ALWAYS parse the request body with contactMessageSchema before calling apiServer, and forward only the parsed fields plus created_at
  Source: constitution.md B-001; PRD §Halaman Kontak — validasi sisi server

## Implementation steps

1. Create `src/features/contact/schemas/contact.schema.ts` exporting `contactMessageSchema` (trimmed `name` 1–100, `email` valid and ≤255, trimmed `message` 1–2000, Indonesian per-field messages copied from the PRD rules), `ContactMessageFormValues` and `contactMessageDefaults`, plus `src/features/contact/types/index.ts` with the saved `ContactMessage` shape from PRD §Data model.
2. Create `src/app/api/v1/contact-messages/route.ts` with a `POST` that safe-parses the JSON body: on failure return `{ success: false, code: 'VALIDATION_ERROR', message, data: { fieldErrors } }` with status 400 and never call upstream; on success `apiServer.post('/v1/contact-messages', { ...parsed, created_at: new Date().toISOString() })` and return the envelope with the same 400-on-failure mapping as `respond()`.
3. Write `route.test.ts` (mock `next-auth` `getServerSession` → `null`; MSW handler on `http://localhost:3000/v1/contact-messages`) covering: a valid body is forwarded with an ISO `created_at` and returns 200; an invalid email, a 101-character name, a 2001-character message and a missing field each return 400 with that field in `fieldErrors` and no upstream call; client-sent extra keys such as `id` or `created_at` are dropped or overwritten.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
OQ-DM-1 resolved (plan, runner-assumed): the upstream owns `contact_messages`; this route forwards valid messages to `POST /v1/contact-messages`. TBD: OQ-FL-1 — final per-field error copy (provisional text mirrors the PRD rules).

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-005
  vault_sha256: 8b2467da2b9428545b2658e275ec9b299e561fb17b564538eeb0bb97818e6edf
  claims: (none cited)
  anchors_consulted:
    - src/libs/api/route-handler.ts:19
    - src/app/api/v1/users/route.ts:1
    - src/libs/api/server.ts:9
    - src/features/users/schemas/user.schema.ts:1
    - src/test/handlers.ts:1
  anchors_verified: 5/5 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT modify src/libs/api/route-handler.ts
    - DO NOT add new package.json dependencies
    - ALWAYS parse the request body with contactMessageSchema before calling apiServer, and forward only the parsed fields plus created_at
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
  - src/libs/api/route-handler.ts  (source: U-005.md `## Hard rules`)
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

- §B-001: Input form kontak divalidasi di sisi server sebelum disimpan (source: PRD §Halaman Kontak; PRD §Alur › F-U-001 langkah 3)
- §C-001: Alur data page → hook → repository → apiClient → proxy `/api/v1` → apiServer → upstream (source: CLAUDE.md §Data flow)

(selector: `\b[A-F]-\d{3}\b` cited in U-005.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

## Validation hints (specific, not vague)

After implementation, run:
```bash
pnpm test:run src/app/api/v1/contact-messages/route.test.ts
```
Expected output pattern: Test Files  1 passed (1)

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 8539 bytes (cap 12288)
consumed_t2: 1604 bytes (cap 10240, hard 12288)
total: 10143 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 14293    bytes  # THIS WHOLE FILE; the gap from `total` is the four
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
- Full framework pack: `/Users/<user>/.claude/plugins/cache/mega-sdd/mega-sdd/7.37.1/references/framework-conventions/<pack>.md`

═══════════════════════════════════════════
PROVENANCE — omissions (audit trail; NOT part of the T1/T2 byte accounting)
═══════════════════════════════════════════

Every absent or unresolvable input is recorded here rather than invented (invariant #5).

- t1.reuse_index_line: reuse-index.yaml absent at ./.mega-sdd/codebase/reuse-index.yaml — the Iron Rule 4 pointer line is NOT emitted for a file that does not exist (run scan-codebase to produce the index)
- t1.anti_context.do_not_modify.data_mutation_policy: no <kb>/99-rebuild-architecture/data-mutation-policy.md under . (searched .mega-sdd/, docs/, old-reference/ knowledge-base roots) — this source contributes nothing; the unit `## Hard rules` half is NOT relabelled to stand in for it
- depends_on_summaries: unit has no depends_on entries
- reuse_slice: reuse-index.yaml absent at ./.mega-sdd/codebase/reuse-index.yaml (the T1 pointer line is omitted too)
- symbol_slice: no indexed symbol in or beside target_files
- starterkit_slice: no starterkit-context.yaml at ./.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice: unit is not ui_bearing (no target_files path matched the pack view_glob or any universal frontend shape)
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite/.mega-sdd/vaults/company-profile
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- design_slice_path: unit is not ui_bearing, so no design lens is dispatched for it — no lens-input file is written and the `design_slice_path` key is ABSENT (a rubric with no reader is a cost, not a contribution)
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
