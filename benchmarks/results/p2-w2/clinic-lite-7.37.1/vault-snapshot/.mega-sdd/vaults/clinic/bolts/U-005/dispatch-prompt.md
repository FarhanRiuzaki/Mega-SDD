═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-005
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-005

UNIT: U-005 "Add the public booking BFF routes (doctors, services, availability, create appointment)"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-005
title: Add the public booking BFF routes (doctors, services, availability, create appointment)
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:190, PRD/prd-clinic.md:150, PRD/prd-clinic.md:205, PRD/prd-clinic.md:178]
task_type: create
grounding_confidence: LOW
risk: high
module: M-clinic-bff
depends_on: [U-001]
target_files:
  - path: src/app/api/v1/doctors/route.ts
    operation: create
  - path: src/app/api/v1/services/route.ts
    operation: create
  - path: src/app/api/v1/appointments/availability/route.ts
    operation: create
  - path: src/app/api/v1/appointments/availability/route.test.ts
    operation: create
  - path: src/app/api/v1/appointments/route.ts
    operation: create
  - path: src/app/api/v1/appointments/route.test.ts
    operation: create
existing_interfaces:
  - file: src/libs/api/route-handler.ts
    symbol: proxyGet
    note: "reuse unchanged for the GET proxies"
  - file: src/libs/jwt-permission/index.ts
    symbol: JWTPermissionChecker
    note: "reuse unchanged for the receptionist role check"
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+4 gaps merged)
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "rejects an invalid booking payload with 400 before calling upstream"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "forwards a valid online booking to the upstream appointments endpoint"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "rejects a staff-channel or override booking without the receptionist role"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "allows a receptionist to create a staff-channel override booking"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/availability/route.test.ts --reporter=verbose"
    expects: "forwards doctorId and date to the upstream availability endpoint"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "returns 400 when the request body is not valid JSON"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "rejects a staff-channel booking from a completely unauthenticated caller with 403 not 500"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "rejects an online booking with override true from a non-receptionist"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "strips unknown fields from the payload before forwarding to upstream"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CN-4, OQ-CLINIC-001]
---

# Unit U-005 — Add the public booking BFF routes (doctors, services, availability, create appointment)

## Goal

Create the same-origin Route Handlers the booking wizard and walk-in dialog call: GET doctors, GET services, GET availability, and a POST appointments handler that validates the payload with zod and only lets a receptionist create `staff`-channel or override bookings.

## Context (read first)

Following the OQ-CN-1 / OQ-AR-1 recommendations, browser traffic goes through `/api/v1/*` proxies that forward to the upstream API with `apiServer` (constitution C-001, C-002), and the upstream owns persistence and the (doctor_id, start_time) uniqueness of PRD §Clinic.4. PRD §Clinic.3 marks `/book` public, so anonymous patients hit these routes; F-U-001 step 5 requires server-side validation (constitution B-001), BR-006 fixes `online` for patient bookings, and F-S-002 steps 4–5 reserve `staff` bookings and the emergency override for the receptionist. The POST handler is therefore hand-written (session + zod + role check) while the three GETs stay one-line proxies.

## Anchors

- src/libs/api/route-handler.ts:31-50 — `proxyGet` / `proxyPost` factories and the `respond()` envelope→status mapping at line 19 to mirror
- src/app/api/v1/users/route.ts:1-4 — one-line proxy route shape
- src/libs/api/server.ts:9-27 — `apiServer` returns a `{ success: false }` envelope instead of throwing
- src/libs/auth.ts:39 — `authOptions` for `getServerSession`
- src/libs/jwt-permission/index.ts:29 — `JWTPermissionChecker.hasRole` (case-insensitive)

## Claims

- C-U005-01 "proxyGet exists in the route-handler factory" — expect: src/libs/api/route-handler.ts:proxyGet
- C-U005-02 "JWTPermissionChecker implements hasRole" — expect: src/libs/jwt-permission/index.ts:JWTPermissionChecker
- C-U005-03 "apiServer is the server-side fetcher" — expect: src/libs/api/server.ts — must-exist
- C-U005-04 "next-auth options live in libs/auth.ts" — expect: src/libs/auth.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/api/route-handler.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file:src/app/api/v1/**/route.ts MUST follow kebab-case naming
  Source: framework pack next.md §Naming standards (route segment folders are kebab-case)
- MUST parse the POST body with createAppointmentPayloadSchema before any upstream call and answer 400 on failure (constitution B-001)
  Source: constitution.md §B B-001
- MUST reject bookingChannel staff or override true unless the session holds the receptionist role (constitution C-006)
  Source: constitution.md §C C-006
- MUST call apiServer, never apiClient, inside these Route Handlers (constitution C-001)
  Source: constitution.md §C C-001
- MUST NOT log request bodies or patient data (constitution F-004)
  Source: constitution.md §F F-004

## Anti-patterns

- Don't forward `Object.fromEntries`-style raw bodies — forward only the zod-parsed data (mass-assignment rail of the Next.js pack).
- Don't implement an in-memory rate limiter — the limit value and its owner are open (OQ-CN-4).

## Implementation steps

1. Create the one-line GET proxies following `src/app/api/v1/users/route.ts`: `src/app/api/v1/doctors/route.ts` → `proxyGet('/v1/doctors')`, `src/app/api/v1/services/route.ts` → `proxyGet('/v1/services')`, and `src/app/api/v1/appointments/availability/route.ts` → `proxyGet('/v1/appointments/availability', { forwardQuery: true })` so `doctorId` and `date` reach upstream.
2. Create `src/app/api/v1/appointments/route.ts` exporting a hand-written `POST(req)`: read the JSON body (a malformed body is a 400), run `createAppointmentPayloadSchema.safeParse`, and on failure return a 400 `ApiResponse` envelope with the first zod message; then, when `bookingChannel === 'staff'` or `override === true`, load `getServerSession(authOptions)` and require `new JWTPermissionChecker(session.user.permissions, session.user.roles).hasRole('receptionist')`, answering 403 otherwise; finally call `apiServer.post('/v1/appointments', parsed.data)` and map the envelope to a status exactly like `respond()` in the route-handler anchor.
3. Write `route.test.ts` (mocking `@/libs/api/server` and `next-auth`'s `getServerSession`) and `availability/route.test.ts` with every test named exactly as the acceptance_test `expects` strings (see Acceptance criteria for the adversarial additions); the adversarial cases must prove the upstream mock is NOT called on a 400/403 and that an anonymous caller sending `override: true` with `bookingChannel: 'online'` is still rejected.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `returns 400 when the request body is not valid JSON`: an unparsable body answers 400 (no thrown 500) and apiServer.post is never called.
- Adversarial addition — `rejects a staff-channel booking from a completely unauthenticated caller with 403 not 500`: with getServerSession resolving null, a staff-channel payload answers 403 without throwing and upstream is not called.
- Adversarial addition — `rejects an online booking with override true from a non-receptionist`: bookingChannel online plus override true without the receptionist role answers 403 — the override branch is gated on its own.
- Adversarial addition — `strips unknown fields from the payload before forwarding to upstream`: an extra client field (for example status) is absent from the body apiServer.post receives — only the zod-parsed shape is forwarded.
- TBD: OQ-CN-4 — rate limiting of the public booking surface is not implemented until its limit and owner are decided.
- TBD: OQ-AR-1 — upstream paths follow the recommended `/v1/...` mirror.
- OQ-CLINIC-001 (P1, open): regulation-specific handling of the patient data in the payload is not invented here; the handler only validates and forwards.

## Out of scope

- Token cancel/reschedule routes — U-006
- Staff schedule and reassign routes — U-007
- Calling these routes from the browser — U-009

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-005
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted:
    - src/libs/api/route-handler.ts:31
    - src/app/api/v1/users/route.ts:1
    - src/libs/api/server.ts:9
    - src/libs/auth.ts:39
    - src/libs/jwt-permission/index.ts:29
  anchors_verified: 5/5 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - DO NOT modify src/libs/api/route-handler.ts
    - file:src/app/api/v1/**/route.ts MUST follow kebab-case naming
    - MUST parse the POST body with createAppointmentPayloadSchema before any upstream call and answer 400 on failure (constitution B-001)
    - MUST reject bookingChannel staff or override true unless the session holds the receptionist role (constitution C-006)
    - MUST call apiServer, never apiClient, inside these Route Handlers (constitution C-001)
    - MUST NOT log request bodies or patient data (constitution F-004)
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

## Upstream bolts (depends_on chain — 1-line summary each)

- U-001 "Define appointment domain types and zod payload schemas" → committed at (no commit recorded)
  └─ [unknown] Field names, unions and interfaces follow the unit's implementation-step enumeration literally (no createdAt/updatedAt added, no price siblings). — src: /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic/bolts/U-001/bolt-report.md

## Framework pack rules (filtered by your target_files glob match)

- framework-pack-custom-001 (from next.md §Hard Rules emitted; matched glob `app/**/*.ts` against `src/app/api/v1/doctors/route.ts`)
  └─ Server Actions MUST be in files with "use server" directive OR in async functions tagged "use server"
     rule_type: CUSTOM
     rationale: Server Actions without the directive run as Client-side code, exposing server logic or causing runtime errors
- framework-pack-naming-rule-001 (from next.md §Hard Rules emitted; matched glob `app/**/route.ts` against `src/app/api/v1/doctors/route.ts`)
  └─ Route Handler files MUST be named route.ts (not handler.ts, api.ts, etc.)
     rule_type: NAMING_RULE
     pattern: '^route\.(ts|js)$'
     rationale: Next.js file-based routing only recognizes the reserved name route.ts for HTTP handlers

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §B-001: Untrusted input (booking form, token requests, walk-in form) is validated with zod in the browser and again at the server boundary (source: PRD §Clinic.1 F-U-001 step 5; PRD §6.3 Validation)
- §C-001: Browser code calls `apiClient` (same-origin `/api` proxy, no Authorization header); Route Handlers and Server Components call `apiServer`; the two are never mixed (source: CLAUDE.md:65; CLAUDE.md:134)
- §C-002: api/v1/**` proxy routes are one-liners built with `proxyGet` / `proxyPost` / `proxyPut` / `proxyDelete`; a hand-written handler is allowed only when the route adds server-side logic such as session scoping or a secret check (source: CLAUDE.md §Next.js API routes are thin proxies; src/libs/api/route-handler.ts:31)
- §C-006: Every appointment records `booking_channel` — `online` for patient bookings, `staff` for receptionist-created appointments (source: PRD §5 BR-006)
- §F-004: Patient personal data (name, email, phone, reason for visit) is handled per the applicable regional privacy regulation; until OQ-CLINIC-001 is answered no regulation-specific behavior is invented and no patient data is logged or persisted in this Next.js tier (source: PRD §6.1; context.md OQ-CLINIC-001)

(selector: `\b[A-F]-\d{3}\b` cited in U-005.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

## Validation hints (specific, not vague)

After implementation, run:
```bash
pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose
```
Expected output pattern: rejects an invalid booking payload with 400 before calling upstream
```bash
pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose
```
Expected output pattern: forwards a valid online booking to the upstream appointments endpoint
```bash
pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose
```
Expected output pattern: rejects a staff-channel or override booking without the receptionist role
```bash
pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose
```
Expected output pattern: allows a receptionist to create a staff-channel override booking
```bash
pnpm test:run src/app/api/v1/appointments/availability/route.test.ts --reporter=verbose
```
Expected output pattern: forwards doctorId and date to the upstream availability endpoint
```bash
pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose
```
Expected output pattern: returns 400 when the request body is not valid JSON
```bash
pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose
```
Expected output pattern: rejects a staff-channel booking from a completely unauthenticated caller with 403 not 500
```bash
pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose
```
Expected output pattern: rejects an online booking with override true from a non-receptionist
```bash
pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose
```
Expected output pattern: strips unknown fields from the payload before forwarding to upstream

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 13263 bytes (cap 12288)
consumed_t2: 4516 bytes (cap 10240, hard 12288)
total: 17779 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 22082    bytes  # THIS WHOLE FILE; the gap from `total` is the four
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
