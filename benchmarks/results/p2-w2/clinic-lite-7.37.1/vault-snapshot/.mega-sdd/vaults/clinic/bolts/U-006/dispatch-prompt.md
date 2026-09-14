═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-006
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-006

UNIT: U-006 "Add the token-authorized cancel and reschedule BFF routes"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-006
title: Add the token-authorized cancel and reschedule BFF routes
context_source: context.md#F-U-002
prd_source: [PRD/prd-clinic.md:191, PRD/prd-clinic.md:192, PRD/prd-clinic.md:155, PRD/prd-clinic.md:167, PRD/prd-clinic.md:207, PRD/prd-clinic.md:210]
task_type: create
grounding_confidence: LOW
risk: high
module: M-clinic-bff
depends_on: [U-001]
target_files:
  - path: src/app/api/appointments/[id]/cancel/route.ts
    operation: create
  - path: src/app/api/appointments/[id]/cancel/route.test.ts
    operation: create
  - path: src/app/api/v1/appointments/token/[token]/route.ts
    operation: create
  - path: src/app/api/v1/appointments/token/[token]/route.test.ts
    operation: create
existing_interfaces:
  - file: src/libs/api/route-handler.ts
    symbol: proxyGet
    note: "reuse unchanged for loading an appointment by token"
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "cancels through upstream when a token is posted"
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "rejects a cancel request without a token with 400"
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "exposes no GET handler so an email link cannot cancel by itself"
  - type: test
    command: "pnpm test:run appointments/token --reporter=verbose"
    expects: "loads the appointment for a token from upstream"
  - type: test
    command: "pnpm test:run appointments/token --reporter=verbose"
    expects: "rejects a reschedule payload without a valid start time with 400"
  - type: test
    command: "pnpm test:run appointments/token --reporter=verbose"
    expects: "reschedules through upstream when a valid start time is provided"
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "never echoes the token back in the response body"
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "does not call upstream when the cancel payload fails validation"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-FL-1, OQ-CLINIC-001, OQ-CLINIC-003]
---

# Unit U-006 — Add the token-authorized cancel and reschedule BFF routes

## Goal

Create the PRD §Clinic.3 cancel Route Handler `POST /api/appointments/[id]/cancel` (+ token) and the `/api/v1/appointments/token/[token]` route that loads an appointment by token (GET) and reschedules it (PUT), validating input before forwarding to the upstream API.

## Context (read first)

Patients never log in; cancel and reschedule are authorized only by the one-time signed email token (PRD §3, constitution B-002), and per the OQ-AR-1 recommendation the upstream API issues and verifies that token and performs the atomic cancel / reschedule (AC-003, AC-006). F-U-002 requires a confirmation step before cancelling, so the cancel route accepts only POST — a GET from an email link must never cancel by itself. Where the patient confirms the cancellation is still open (OQ-FL-1), so this unit ships only the API side.

## Anchors

- src/libs/api/route-handler.ts:19-50 — `respond()` mapping and `proxyGet` with dynamic params (`({ token }) => ...`)
- src/app/api/v1/users/[id]/route.ts:1-5 — dynamic-segment proxy route shape
- src/libs/api/server.ts:9-27 — `apiServer.post` / `apiServer.put` return the envelope

## Claims

- C-U006-01 "proxyGet supports dynamic route params" — expect: src/libs/api/route-handler.ts:proxyGet
- C-U006-02 "dynamic-segment proxy routes already exist" — expect: src/app/api/v1/users/[id]/route.ts — must-exist
- C-U006-03 "no cancel route exists yet" — expect: src/app/api/appointments — must-not-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/api/route-handler.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file src/app/api/appointments/[id]/cancel/route.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST export only POST from the cancel route so that a GET request cannot cancel an appointment (source: PRD §Clinic.1 F-U-002 step 2)
  Source: PRD §Clinic.1 F-U-002 step 2
- MUST parse the cancel body with cancelPayloadSchema and the reschedule body with reschedulePayloadSchema before calling upstream, answering 400 on failure (constitution B-001)
  Source: constitution.md §B B-001
- MUST forward the token only to the upstream API and never echo it in a response or log (constitution B-002)
  Source: constitution.md §B B-002

## Implementation steps

1. Create `src/app/api/appointments/[id]/cancel/route.ts` exporting only `POST(req, { params })`: await `params` for `id`, parse the JSON body with `cancelPayloadSchema` (a missing or empty `token` or a malformed body is a 400 envelope), then call `apiServer.post(`/v1/appointments/${id}/cancel`, { token })` and map the envelope to a status like `respond()` in the route-handler anchor.
2. Create `src/app/api/v1/appointments/token/[token]/route.ts` with `GET = proxyGet(({ token }) => `/v1/appointments/token/${token}`)` and a hand-written `PUT` that parses the body with `reschedulePayloadSchema` (400 on failure) and forwards `{ startTime }` with `apiServer.put` to the same upstream path, encoding the token with `encodeURIComponent` in both handlers.
3. Write the two `route.test.ts` files (mocking `@/libs/api/server`) with every test named exactly as the acceptance_test `expects` strings (see Acceptance criteria for the adversarial additions); the adversarial cases must assert the upstream mock is not called on a 400 and that the cancel module has no `GET` export.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `reschedules through upstream when a valid start time is provided`: a valid PUT calls apiServer.put with /v1/appointments/token/{token} and a body of exactly { startTime } and returns the upstream envelope.
- Adversarial addition — `never echoes the token back in the response body`: for both the success and the 400 case the serialized response body does not contain the raw token.
- Adversarial addition — `does not call upstream when the cancel payload fails validation`: apiServer.post is never invoked when the body is missing, empty or fails cancelPayloadSchema.
- TBD: OQ-FL-1 — the page where the patient confirms a cancellation is not built; only the API exists.
- TBD: OQ-CLINIC-003 — no cancellation/reschedule window is enforced here; the upstream decides.
- OQ-CLINIC-001 (P1, open): no regulation-specific handling is invented; nothing is persisted or logged in this tier.

## Out of scope

- The reschedule page — U-014
- Client-side calls — U-009

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-006
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted:
    - src/libs/api/route-handler.ts:19
    - src/app/api/v1/users/[id]/route.ts:1
    - src/libs/api/server.ts:9
  anchors_verified: 3/3 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - DO NOT modify src/libs/api/route-handler.ts
    - file src/app/api/appointments/[id]/cancel/route.ts MUST exist after bolt
    - MUST export only POST from the cancel route so that a GET request cannot cancel an appointment (source: PRD §Clinic.1 F-U-002 step 2)
    - MUST parse the cancel body with cancelPayloadSchema and the reschedule body with reschedulePayloadSchema before calling upstream, answering 400 on failure (constitution B-001)
    - MUST forward the token only to the upstream API and never echo it in a response or log (constitution B-002)
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
  - src/libs/api/route-handler.ts  (source: U-006.md `## Hard rules`)
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

- framework-pack-custom-001 (from next.md §Hard Rules emitted; matched glob `app/**/*.ts` against `src/app/api/appointments/[id]/cancel/route.ts`)
  └─ Server Actions MUST be in files with "use server" directive OR in async functions tagged "use server"
     rule_type: CUSTOM
     rationale: Server Actions without the directive run as Client-side code, exposing server logic or causing runtime errors
- framework-pack-naming-rule-001 (from next.md §Hard Rules emitted; matched glob `app/**/route.ts` against `src/app/api/appointments/[id]/cancel/route.ts`)
  └─ Route Handler files MUST be named route.ts (not handler.ts, api.ts, etc.)
     rule_type: NAMING_RULE
     pattern: '^route\.(ts|js)$'
     rationale: Next.js file-based routing only recognizes the reserved name route.ts for HTTP handlers

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §B-001: Untrusted input (booking form, token requests, walk-in form) is validated with zod in the browser and again at the server boundary (source: PRD §Clinic.1 F-U-001 step 5; PRD §6.3 Validation)
- §B-002: Patients never log in; cancel and reschedule are authorized only by the one-time signed email token (source: PRD §3; PRD §6.3 Auth)

(selector: `\b[A-F]-\d{3}\b` cited in U-006.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

## Validation hints (specific, not vague)

After implementation, run:
```bash
pnpm test:run src/app/api/appointments --reporter=verbose
```
Expected output pattern: cancels through upstream when a token is posted
```bash
pnpm test:run src/app/api/appointments --reporter=verbose
```
Expected output pattern: rejects a cancel request without a token with 400
```bash
pnpm test:run src/app/api/appointments --reporter=verbose
```
Expected output pattern: exposes no GET handler so an email link cannot cancel by itself
```bash
pnpm test:run appointments/token --reporter=verbose
```
Expected output pattern: loads the appointment for a token from upstream
```bash
pnpm test:run appointments/token --reporter=verbose
```
Expected output pattern: rejects a reschedule payload without a valid start time with 400
```bash
pnpm test:run appointments/token --reporter=verbose
```
Expected output pattern: reschedules through upstream when a valid start time is provided
```bash
pnpm test:run src/app/api/appointments --reporter=verbose
```
Expected output pattern: never echoes the token back in the response body
```bash
pnpm test:run src/app/api/appointments --reporter=verbose
```
Expected output pattern: does not call upstream when the cancel payload fails validation

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 11059 bytes (cap 12288)
consumed_t2: 3224 bytes (cap 10240, hard 12288)
total: 14283 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 18586    bytes  # THIS WHOLE FILE; the gap from `total` is the four
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
