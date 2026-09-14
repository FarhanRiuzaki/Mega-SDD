═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-010
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-010

UNIT: U-010 "Open the patient pages and staff login in the route proxy"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-010
title: Open the patient pages and staff login in the route proxy
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:53, PRD/prd-clinic.md:190, PRD/prd-clinic.md:192, PRD/prd-clinic.md:195]
task_type: extend
grounding_confidence: LOW
risk: high
module: M-platform
depends_on: []
target_files:
  - path: src/proxy.ts
    operation: modify
  - path: src/proxy.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+4 gaps merged)
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "lets an anonymous visitor open the booking page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "lets an anonymous visitor open a reschedule link"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "lets an anonymous visitor open the staff login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "still redirects an anonymous visitor on a staff page to the login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "bounces a signed-in user from the staff login page to home"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "redirects an anonymous visitor on reschedule without a token or a substring collision to the login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "redirects an anonymous visitor on a book prefixed but unrelated path to the login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "still bounces a signed-in user from the login page to home"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "still clears cookies and redirects to login on a refresh error even for the booking page"
binding_refs: [OQ-CN-1]
---

# Unit U-010 — Open the patient pages and staff login in the route proxy

## Goal

Extend `src/proxy.ts` so anonymous visitors can reach `/book`, `/reschedule/<token>` and `/staff/login`, while every other page keeps redirecting anonymous users to `/login`.

## Context (read first)

Patients never log in (PRD §3) and PRD §Clinic.3 lists `/book` as public and `/reschedule/[token]` as token-authorized, but today the Next.js 16 proxy (`src/proxy.ts`, the renamed middleware) redirects every non-public path to `/login`, which would lock patients out. `/staff/login` (U-015) is a new public auth page that must behave like `/login`: anonymous users may open it and signed-in users are bounced to `/home`. The refresh-token handling and the matcher must not change.

## Anchors

- src/proxy.ts:7-37 — `proxy(request)` with `publicRoutes`, the RefreshTokenError branch, the auth-page bounce and the matcher config

## Claims

- C-U010-01 "the Next.js 16 proxy guards every page" — expect: src/proxy.ts — must-exist
- C-U010-02 "no proxy test exists yet" — expect: src/proxy.test.ts — must-not-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/auth.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- MUST keep the exported `proxy(request: Request)` function name and the exported `config.matcher` value unchanged (source: CLAUDE.md §Auth & routing)
  Source: CLAUDE.md §Auth & routing
- MUST keep the RefreshTokenError branch clearing both session cookies and redirecting to /login before any other rule
  Source: src/proxy.ts:14-22 — CLAUDE.md §Auth & routing
- MUST match the reschedule route only as the /reschedule/ prefix followed by a token segment, never by substring (constitution B-002)
  Source: constitution.md §B B-002
- MUST NOT make any /staff path other than /staff/login public (constitution B-005)
  Source: constitution.md §B B-005

## Implementation steps

1. In `src/proxy.ts`, split the current `publicRoutes` into `authPages = ['/login', '/register', '/staff/login']` (anonymous allowed, signed-in bounced to `/home`) and patient pages — the exact path `/book` plus the prefix `/reschedule/` followed by a non-empty segment — which are reachable by everyone, signed in or not.
2. Keep the evaluation order: first the RefreshTokenError branch, then let patient pages through, then bounce signed-in users away from `authPages`, then redirect anonymous users on every other path to `/login`, leaving the matcher config byte-identical.
3. Write `src/proxy.test.ts` mocking `next-auth`'s `getServerSession` (anonymous vs. a session with `accessToken`) and calling `proxy(new Request('http://localhost:3000/<path>'))`, with every test named exactly as the acceptance_test `expects` strings (see Acceptance criteria for the adversarial additions); the adversarial cases must show `/staff/schedule` and `/rescheduled` / `/reschedule` without a token still redirect anonymous visitors to `/login`.

## Migration notes

- **REMOVE**: the single `publicRoutes` list and its `includes(pathname)` check.
- **KEEP**: the RefreshTokenError cookie-clearing redirect, the `/home` bounce for signed-in users on auth pages, the anonymous → `/login` redirect, the `export const config` matcher.
- **ADD**: `/staff/login` as an auth page; `/book` and `/reschedule/<token>` as always-public patient pages; `src/proxy.test.ts`.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `redirects an anonymous visitor on reschedule without a token or a substring collision to the login page`: anonymous GET /reschedule and GET /rescheduled both redirect to /login.
- Adversarial addition — `redirects an anonymous visitor on a book prefixed but unrelated path to the login page`: anonymous GET /book/admin (a path sharing the /book prefix) still redirects to /login.
- Adversarial addition — `still bounces a signed-in user from the login page to home`: a signed-in user on /login is still redirected to /home after the refactor.
- Adversarial addition — `still clears cookies and redirects to login on a refresh error even for the booking page`: a RefreshTokenError session on /book is redirected to /login with both session cookies deleted.

## Out of scope

- Role checks for `/staff/schedule` and `/staff/reception` — page guards (U-016, U-019) and server scoping (U-007)
- The staff login page itself — U-015

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-010
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted:
    - src/proxy.ts:7
  anchors_verified: 1/1 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - DO NOT modify src/libs/auth.ts
    - MUST keep the exported `proxy(request: Request)` function name and the exported `config.matcher` value unchanged (source: CLAUDE.md §Auth & routing)
    - MUST keep the RefreshTokenError branch clearing both session cookies and redirecting to /login before any other rule
    - MUST match the reschedule route only as the /reschedule/ prefix followed by a token segment, never by substring (constitution B-002)
    - MUST NOT make any /staff path other than /staff/login public (constitution B-005)
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
  - src/libs/auth.ts  (source: U-010.md `## Hard rules`)
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

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §B-002: Patients never log in; cancel and reschedule are authorized only by the one-time signed email token (source: PRD §3; PRD §6.3 Auth)
- §B-005: Staff surfaces require the matching role — `/staff/schedule` the `doctor` role, `/staff/reception` the `receptionist` role — and a doctor's schedule data is limited to that doctor's own appointments (source: PRD §Clinic.3; PRD §Clinic.5 AC-005)

(selector: `\b[A-F]-\d{3}\b` cited in U-010.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

### Existing symbols (REUSE — extend, don't recreate)

index@8af59196 · 592 symbols · built by scripts/build-symbol-index.sh
- src/proxy.ts:7 typescript-function `proxy` — async function proxy(request: Request) {

## Validation hints (specific, not vague)

After implementation, run:
```bash
pnpm test:run src/proxy.test.ts --reporter=verbose
```
Expected output pattern: lets an anonymous visitor open the booking page
```bash
pnpm test:run src/proxy.test.ts --reporter=verbose
```
Expected output pattern: lets an anonymous visitor open a reschedule link
```bash
pnpm test:run src/proxy.test.ts --reporter=verbose
```
Expected output pattern: lets an anonymous visitor open the staff login page
```bash
pnpm test:run src/proxy.test.ts --reporter=verbose
```
Expected output pattern: still redirects an anonymous visitor on a staff page to the login page
```bash
pnpm test:run src/proxy.test.ts --reporter=verbose
```
Expected output pattern: bounces a signed-in user from the staff login page to home
```bash
pnpm test:run src/proxy.test.ts --reporter=verbose
```
Expected output pattern: redirects an anonymous visitor on reschedule without a token or a substring collision to the login page
```bash
pnpm test:run src/proxy.test.ts --reporter=verbose
```
Expected output pattern: redirects an anonymous visitor on a book prefixed but unrelated path to the login page
```bash
pnpm test:run src/proxy.test.ts --reporter=verbose
```
Expected output pattern: still bounces a signed-in user from the login page to home
```bash
pnpm test:run src/proxy.test.ts --reporter=verbose
```
Expected output pattern: still clears cookies and redirects to login on a refresh error even for the booking page

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 10543 bytes (cap 12288)
consumed_t2: 2367 bytes (cap 10240, hard 12288)
total: 12910 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 17391    bytes  # THIS WHOLE FILE; the gap from `total` is the four
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
- depends_on_summaries: unit has no depends_on entries
- framework_pack_rules: no pack rule path_glob matched this unit's target_files (chain: next.md _universal.md) — the 'keep top 1' floor is vacuous on an empty set, no rule invented
- reuse_slice: reuse-index.yaml absent at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/reuse-index.yaml (the T1 pointer line is omitted too)
- starterkit_slice: no starterkit-context.yaml at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice: unit is not ui_bearing (no target_files path matched the pack view_glob or any universal frontend shape)
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- design_slice_path: unit is not ui_bearing, so no design lens is dispatched for it — no lens-input file is written and the `design_slice_path` key is ABSENT (a rubric with no reader is a cost, not a contribution)
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
