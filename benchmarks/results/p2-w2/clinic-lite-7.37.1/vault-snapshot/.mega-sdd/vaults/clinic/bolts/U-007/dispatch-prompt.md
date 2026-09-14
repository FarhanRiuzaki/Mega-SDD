═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-007
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-007

UNIT: U-007 "Add the role-scoped staff schedule and reassign BFF routes"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-007
title: Add the role-scoped staff schedule and reassign BFF routes
context_source: context.md#F-S-001
prd_source: [PRD/prd-clinic.md:209, PRD/prd-clinic.md:171, PRD/prd-clinic.md:176, PRD/prd-clinic.md:177, PRD/prd-clinic.md:193, PRD/prd-clinic.md:194]
task_type: create
grounding_confidence: LOW
risk: high
module: M-clinic-bff
depends_on: [U-001]
target_files:
  - path: src/app/api/v1/appointments/schedule/route.ts
    operation: create
  - path: src/app/api/v1/appointments/schedule/route.test.ts
    operation: create
  - path: src/app/api/v1/appointments/[id]/reassign/route.ts
    operation: create
  - path: src/app/api/v1/appointments/[id]/reassign/route.test.ts
    operation: create
existing_interfaces:
  - file: src/libs/jwt-permission/index.ts
    symbol: JWTPermissionChecker
    note: "reuse unchanged for doctor / receptionist role checks"
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "forces the doctor id to the signed-in doctor"
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "passes the receptionist query through for all doctors"
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "rejects a schedule request from a user without a staff role with 403"
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "rejects an unauthenticated schedule request with 401"
  - type: test
    command: "pnpm test:run reassign/route --reporter=verbose"
    expects: "rejects a reassign request from a non-receptionist with 403"
  - type: test
    command: "pnpm test:run reassign/route --reporter=verbose"
    expects: "forwards a valid reassign to upstream"
  - type: test
    command: "pnpm test:run reassign/route --reporter=verbose"
    expects: "rejects an invalid reassign payload with 400 without calling upstream"
  - type: test
    command: "pnpm test:run reassign/route --reporter=verbose"
    expects: "rejects an unauthenticated reassign request with 401"
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "treats a user with both doctor and receptionist roles as a receptionist"
binding_refs: [OQ-CN-1, OQ-AR-1]
---

# Unit U-007 — Add the role-scoped staff schedule and reassign BFF routes

## Goal

Create `GET /api/v1/appointments/schedule`, which limits a doctor to their own appointments and lets a receptionist read every doctor's, and `POST /api/v1/appointments/[id]/reassign`, which only a receptionist may call.

## Context (read first)

AC-005 requires doctors to see only their own schedule and receptionists to see all, enforced on the server and not only in the UI (constitution B-005); the Next.js pack's security idioms name "protecting only the page UI while the API route stays open" as the classic bypass. Staff are the authenticated users of the existing next-auth credentials flow (OQ-CN-1 recommendation), so the doctor's id is `session.user.id` and roles come from `session.user.roles`. F-S-002 step 3 lets the receptionist reassign an appointment; the patient notification email is sent by the upstream API (OQ-AR-1).

## Anchors

- src/libs/api/route-handler.ts:19-41 — `respond()` mapping and the query-forwarding approach of `proxyGet`
- src/libs/api/server.ts:9-27 — `apiServer.get(path, { params })`
- src/libs/auth.ts:134-152 — session carries `user.id`, `user.roles`, `user.permissions`
- src/libs/jwt-permission/index.ts:29 — `JWTPermissionChecker.hasRole`

## Claims

- C-U007-01 "JWTPermissionChecker implements role checks" — expect: src/libs/jwt-permission/index.ts:JWTPermissionChecker
- C-U007-02 "the session exposes user id and roles" — expect: src/types/next-auth.d.ts — must-exist
- C-U007-03 "apiServer is the server-side fetcher" — expect: src/libs/api/server.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/auth.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file src/app/api/v1/appointments/schedule/route.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST answer 401 without a session and 403 for a session with neither the doctor nor the receptionist role (constitution B-005)
  Source: constitution.md §B B-005
- MUST overwrite any doctorId query parameter with session.user.id when the caller is a doctor without the receptionist role (constitution B-005)
  Source: constitution.md §B B-005
- MUST allow reassign only for the receptionist role and parse the body with reassignPayloadSchema before calling upstream (constitution B-001)
  Source: constitution.md §B B-001
- MUST call apiServer, never apiClient, inside these Route Handlers (constitution C-001)
  Source: constitution.md §C C-001

## Implementation steps

1. Create `src/app/api/v1/appointments/schedule/route.ts` exporting `GET(req)`: load `getServerSession(authOptions)` (none → 401 envelope), build a `JWTPermissionChecker` from the session, and if the caller has the `receptionist` role forward the incoming query (`from`, `to`, optional `doctorId`) unchanged; else if the caller has the `doctor` role forward the query with `doctorId` forced to `session.user.id`; otherwise answer 403 — then call `apiServer.get('/v1/appointments/schedule', { params })` and map the envelope like `respond()`.
2. Create `src/app/api/v1/appointments/[id]/reassign/route.ts` exporting `POST(req, { params })`: require a session with the `receptionist` role (401 / 403 otherwise), parse the body with `reassignPayloadSchema` (400 on failure), then call `apiServer.post(`/v1/appointments/${id}/reassign`, { doctorId })` and map the envelope.
3. Write both `route.test.ts` files (mocking `next-auth`'s `getServerSession` and `@/libs/api/server`) with every test named exactly as the acceptance_test `expects` strings (see Acceptance criteria for the adversarial additions); the adversarial cases must show a doctor passing `doctorId=someone-else` still gets their own id forwarded, a user holding both roles is treated as a receptionist, and the upstream mock is not called on 401/403/400.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `rejects an invalid reassign payload with 400 without calling upstream`: a body failing reassignPayloadSchema answers 400 and apiServer.post is not called.
- Adversarial addition — `rejects an unauthenticated reassign request with 401`: with getServerSession resolving null the reassign route answers 401 (not 403 or 500) and upstream is not called.
- Adversarial addition — `treats a user with both doctor and receptionist roles as a receptionist`: a session with roles doctor and receptionist forwards an explicit doctorId query unchanged.
- TBD: OQ-AR-1 — the upstream also enforces data scope with the bearer token; this route is the defense-in-depth layer.

## Out of scope

- Public booking routes — U-005
- Schedule UI — U-016, U-019

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-007
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted:
    - src/libs/api/route-handler.ts:19
    - src/libs/api/server.ts:9
    - src/libs/auth.ts:134
    - src/libs/jwt-permission/index.ts:29
  anchors_verified: 4/4 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - DO NOT modify src/libs/auth.ts
    - file src/app/api/v1/appointments/schedule/route.ts MUST exist after bolt
    - MUST answer 401 without a session and 403 for a session with neither the doctor nor the receptionist role (constitution B-005)
    - MUST overwrite any doctorId query parameter with session.user.id when the caller is a doctor without the receptionist role (constitution B-005)
    - MUST allow reassign only for the receptionist role and parse the body with reassignPayloadSchema before calling upstream (constitution B-001)
    - MUST call apiServer, never apiClient, inside these Route Handlers (constitution C-001)
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
  - src/libs/auth.ts  (source: U-007.md `## Hard rules`)
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

- U-001 "Define appointment domain types and zod payload schemas" → committed at (no commit recorded)
  └─ [unknown] Field names, unions and interfaces follow the unit's implementation-step enumeration literally (no createdAt/updatedAt added, no price siblings). — src: /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic/bolts/U-001/bolt-report.md

## Framework pack rules (filtered by your target_files glob match)

- framework-pack-custom-001 (from next.md §Hard Rules emitted; matched glob `app/**/*.ts` against `src/app/api/v1/appointments/schedule/route.ts`)
  └─ Server Actions MUST be in files with "use server" directive OR in async functions tagged "use server"
     rule_type: CUSTOM
     rationale: Server Actions without the directive run as Client-side code, exposing server logic or causing runtime errors
- framework-pack-naming-rule-001 (from next.md §Hard Rules emitted; matched glob `app/**/route.ts` against `src/app/api/v1/appointments/schedule/route.ts`)
  └─ Route Handler files MUST be named route.ts (not handler.ts, api.ts, etc.)
     rule_type: NAMING_RULE
     pattern: '^route\.(ts|js)$'
     rationale: Next.js file-based routing only recognizes the reserved name route.ts for HTTP handlers

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §B-001: Untrusted input (booking form, token requests, walk-in form) is validated with zod in the browser and again at the server boundary (source: PRD §Clinic.1 F-U-001 step 5; PRD §6.3 Validation)
- §B-005: Staff surfaces require the matching role — `/staff/schedule` the `doctor` role, `/staff/reception` the `receptionist` role — and a doctor's schedule data is limited to that doctor's own appointments (source: PRD §Clinic.3; PRD §Clinic.5 AC-005)
- §C-001: Browser code calls `apiClient` (same-origin `/api` proxy, no Authorization header); Route Handlers and Server Components call `apiServer`; the two are never mixed (source: CLAUDE.md:65; CLAUDE.md:134)

(selector: `\b[A-F]-\d{3}\b` cited in U-007.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

## Validation hints (specific, not vague)

After implementation, run:
```bash
pnpm test:run appointments/schedule/route --reporter=verbose
```
Expected output pattern: forces the doctor id to the signed-in doctor
```bash
pnpm test:run appointments/schedule/route --reporter=verbose
```
Expected output pattern: passes the receptionist query through for all doctors
```bash
pnpm test:run appointments/schedule/route --reporter=verbose
```
Expected output pattern: rejects a schedule request from a user without a staff role with 403
```bash
pnpm test:run appointments/schedule/route --reporter=verbose
```
Expected output pattern: rejects an unauthenticated schedule request with 401
```bash
pnpm test:run reassign/route --reporter=verbose
```
Expected output pattern: rejects a reassign request from a non-receptionist with 403
```bash
pnpm test:run reassign/route --reporter=verbose
```
Expected output pattern: forwards a valid reassign to upstream
```bash
pnpm test:run reassign/route --reporter=verbose
```
Expected output pattern: rejects an invalid reassign payload with 400 without calling upstream
```bash
pnpm test:run reassign/route --reporter=verbose
```
Expected output pattern: rejects an unauthenticated reassign request with 401
```bash
pnpm test:run appointments/schedule/route --reporter=verbose
```
Expected output pattern: treats a user with both doctor and receptionist roles as a receptionist

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 11480 bytes (cap 12288)
consumed_t2: 3702 bytes (cap 10240, hard 12288)
total: 15182 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 19485    bytes  # THIS WHOLE FILE; the gap from `total` is the four
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
- reuse_slice: reuse-index.yaml absent at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/reuse-index.yaml (the T1 pointer line is omitted too)
- symbol_slice: no indexed symbol in or beside target_files
- starterkit_slice: no starterkit-context.yaml at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice: unit is not ui_bearing (no target_files path matched the pack view_glob or any universal frontend shape)
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- design_slice_path: unit is not ui_bearing, so no design lens is dispatched for it — no lens-input file is written and the `design_slice_path` key is ABSENT (a rubric with no reader is a cost, not a contribution)
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
