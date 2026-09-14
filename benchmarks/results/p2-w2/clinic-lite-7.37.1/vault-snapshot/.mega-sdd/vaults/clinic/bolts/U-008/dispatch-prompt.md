═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-008
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-008

UNIT: U-008 "Add the CRON_SECRET-guarded reminder sweep trigger route"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-008
title: Add the CRON_SECRET-guarded reminder sweep trigger route
context_source: context.md#F-U-003
prd_source: [PRD/prd-clinic.md:196, PRD/prd-clinic.md:160, PRD/prd-clinic.md:208, PRD/prd-clinic.md:94]
task_type: extend
grounding_confidence: LOW
risk: high
module: M-clinic-bff
depends_on: []
target_files:
  - path: src/app/api/cron/reminders/route.ts
    operation: create
  - path: src/app/api/cron/reminders/route.test.ts
    operation: create
  - path: .env.example
    operation: modify
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "rejects a request without the cron secret with 401"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "rejects every request when CRON_SECRET is not configured"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "triggers the upstream reminder sweep when the secret matches"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "rejects a request with an incorrect secret value with 401"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "rejects a request whose bearer token has a different length than the secret with 401"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "triggers the upstream reminder sweep via GET when the secret matches"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-005, OQ-CN-2]
---

# Unit U-008 — Add the CRON_SECRET-guarded reminder sweep trigger route

## Goal

Create the PRD §Clinic.3 Route Handler `/api/cron/reminders` that authenticates the scheduler with `CRON_SECRET` and triggers the upstream DB-backed due-reminders sweep, and document `CRON_SECRET` in `.env.example`.

## Context (read first)

F-U-003 and AC-004 require a DB-backed sweep that sends each reminder 24h ± 5 min before `start_time` exactly once (never per-appointment in-memory timers — constitution D-001), and PRD §Clinic.3 protects the trigger with `CRON_SECRET` (constitution B-004). Per the OQ-AR-1 recommendation the upstream API owns the sweep, the `reminder_sent` flag and the email, so this route authenticates the caller and forwards one sweep request. The OQ-CLINIC-005 recommendation (self-hosted, external scheduler) and Vercel Cron both call the same URL with `Authorization: Bearer <CRON_SECRET>`, so the handler answers GET and POST.

## Anchors

- src/libs/api/route-handler.ts:19-21 — `respond()` envelope→status mapping to mirror
- src/libs/api/server.ts:9-27 — `apiServer.post` returns an envelope
- .env.example:1-28 — env documentation style (section banners, comments, empty secret values)

## Claims

- C-U008-01 ".env.example documents environment variables" — expect: .env.example — must-exist
- C-U008-02 "no cron route exists yet" — expect: src/app/api/cron — must-not-exist
- C-U008-03 "apiServer is the server-side fetcher" — expect: src/libs/api/server.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/app/api/cron/reminders/route.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST reject every request with 401 when CRON_SECRET is unset or the Authorization header does not equal Bearer followed by CRON_SECRET (constitution B-004)
  Source: constitution.md §B B-004
- MUST compare the secret with a constant-time comparison from node:crypto (constitution B-003)
  Source: constitution.md §B B-003
- NEVER schedule reminders with timers inside this app — the route only triggers the upstream sweep (constitution D-001)
  Source: constitution.md §D D-001
- MUST add CRON_SECRET to .env.example with an empty value and never commit a real secret (constitution B-003)
  Source: constitution.md §B B-003

## Implementation steps

1. Create `src/app/api/cron/reminders/route.ts` with one `handler(req)` exported as both `GET` and `POST`: read `process.env.CRON_SECRET` at request time, answer a 401 envelope when it is missing/empty or when the `authorization` header is not exactly `Bearer <secret>`, comparing equal-length buffers with `crypto.timingSafeEqual` (a length mismatch is a 401 without comparing).
2. When authorized, call `apiServer.post('/v1/reminders/sweep', {})` and return its envelope with the same success→200 / failure→4xx mapping as `respond()` in the route-handler anchor; never log the header or the secret.
3. Append a `# Reminder cron` banner block to `.env.example` with a comment explaining that the scheduler (external cron or Vercel Cron) must send `Authorization: Bearer <CRON_SECRET>` and a line `CRON_SECRET=` (generate per environment, e.g. `openssl rand -base64 32`), then write `route.test.ts` (mocking `@/libs/api/server`, setting and unsetting `process.env.CRON_SECRET` per test) with every test named exactly as the acceptance_test `expects` strings (see Acceptance criteria for the adversarial additions), asserting the upstream mock is not called on any 401.

## Migration notes

- **REMOVE**: nothing.
- **KEEP**: every existing variable, comment and banner in `.env.example`.
- **ADD**: a reminder-cron section with `CRON_SECRET=` in `.env.example`; the new route and its test.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `rejects a request with an incorrect secret value with 401`: a well-formed Bearer header with the wrong value answers 401 and the sweep is not triggered.
- Adversarial addition — `rejects a request whose bearer token has a different length than the secret with 401`: a token of a different length than CRON_SECRET answers 401 without throwing from timingSafeEqual.
- Adversarial addition — `triggers the upstream reminder sweep via GET when the secret matches`: the GET export with the correct secret calls apiServer.post('/v1/reminders/sweep', {}) exactly like POST.
- TBD: OQ-AR-1 — the 24h ± 5 min window, `reminder_sent` idempotency and the email are upstream responsibilities.
- TBD: OQ-CLINIC-005 — which scheduler calls this route is a deployment decision; the route is the same for both options.
- TBD: OQ-CN-2 — delivery within 5 minutes (NFR-003) is not measurable in this tier.

## Out of scope

- Scheduler configuration (vercel.json or host cron)
- Email templates

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-008
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted:
    - src/libs/api/route-handler.ts:19
    - src/libs/api/server.ts:9
    - .env.example:1
  anchors_verified: 3/3 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - file src/app/api/cron/reminders/route.ts MUST exist after bolt
    - MUST reject every request with 401 when CRON_SECRET is unset or the Authorization header does not equal Bearer followed by CRON_SECRET (constitution B-004)
    - MUST compare the secret with a constant-time comparison from node:crypto (constitution B-003)
    - NEVER schedule reminders with timers inside this app — the route only triggers the upstream sweep (constitution D-001)
    - MUST add CRON_SECRET to .env.example with an empty value and never commit a real secret (constitution B-003)
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

## Framework pack rules (filtered by your target_files glob match)

- framework-pack-custom-001 (from next.md §Hard Rules emitted; matched glob `app/**/*.ts` against `src/app/api/cron/reminders/route.ts`)
  └─ Server Actions MUST be in files with "use server" directive OR in async functions tagged "use server"
     rule_type: CUSTOM
     rationale: Server Actions without the directive run as Client-side code, exposing server logic or causing runtime errors
- framework-pack-naming-rule-001 (from next.md §Hard Rules emitted; matched glob `app/**/route.ts` against `src/app/api/cron/reminders/route.ts`)
  └─ Route Handler files MUST be named route.ts (not handler.ts, api.ts, etc.)
     rule_type: NAMING_RULE
     pattern: '^route\.(ts|js)$'
     rationale: Next.js file-based routing only recognizes the reserved name route.ts for HTTP handlers

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §B-003: Server secrets (`NEXTAUTH_SECRET`, `CRON_SECRET`) are read only in server code, never prefixed `NEXT_PUBLIC_`, and real secrets are never committed (source: CLAUDE.md:35; PRD §Clinic.3 reminder cron)
- §B-004: The reminder cron endpoint rejects every caller that does not present `CRON_SECRET` (source: PRD §Clinic.3)
- §D-001: NEVER schedule reminders with per-appointment in-memory timers — reminders come from a DB-backed, idempotent due-reminders sweep (source: PRD §6.3 Scheduled reminders; PRD §Clinic.5 AC-004)

(selector: `\b[A-F]-\d{3}\b` cited in U-008.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

## Validation hints (specific, not vague)

After implementation, run:
```bash
pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose
```
Expected output pattern: rejects a request without the cron secret with 401
```bash
pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose
```
Expected output pattern: rejects every request when CRON_SECRET is not configured
```bash
pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose
```
Expected output pattern: triggers the upstream reminder sweep when the secret matches
```bash
pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose
```
Expected output pattern: rejects a request with an incorrect secret value with 401
```bash
pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose
```
Expected output pattern: rejects a request whose bearer token has a different length than the secret with 401
```bash
pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose
```
Expected output pattern: triggers the upstream reminder sweep via GET when the secret matches

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 10689 bytes (cap 12288)
consumed_t2: 2776 bytes (cap 10240, hard 12288)
total: 13465 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 18012    bytes  # THIS WHOLE FILE; the gap from `total` is the four
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
- depends_on_summaries: unit has no depends_on entries
- reuse_slice: reuse-index.yaml absent at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/reuse-index.yaml (the T1 pointer line is omitted too)
- symbol_slice: no indexed symbol in or beside target_files
- starterkit_slice: no starterkit-context.yaml at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice: unit is not ui_bearing (no target_files path matched the pack view_glob or any universal frontend shape)
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- design_slice_path: unit is not ui_bearing, so no design lens is dispatched for it — no lens-input file is written and the `design_slice_path` key is ABSENT (a rubric with no reader is a cost, not a contribution)
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
