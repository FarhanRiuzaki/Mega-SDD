---
unit: U-005
status: success
attempted_at: 2026-09-14T11:57:01+00:00
duration_seconds: 525017
commits: [8ff408721e9e5d756915c99175920ec10feba50c]
files_touched: [src/app/api/v1/appointments/availability/route.test.ts, src/app/api/v1/appointments/availability/route.ts, src/app/api/v1/appointments/route.test.ts, src/app/api/v1/appointments/route.ts, src/app/api/v1/doctors/route.ts, src/app/api/v1/services/route.ts]
tests_run: ["pnpm test:run src/app/api/v1/appointments/availability/route.test.ts --reporter=verbose", "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"]
test_results: "0 acceptance entries passed / 9 not passing (see acceptance.json)"
retries: 0
target_hashes:
  src/app/api/v1/doctors/route.ts: 435395586c59ff0834b8b66657c2eb75bb71ffc0aca548082a979e3d887f1010
  src/app/api/v1/services/route.ts: fa07ee083c5ee1f42c9d4f5a961c1f1dfd53214fc98676e20b6fb44712afd2dd
  src/app/api/v1/appointments/availability/route.ts: 91cd98032f8170ce3a9930ccb5d56610edc944446aab4d01fac9c2c30a2441ae
  src/app/api/v1/appointments/availability/route.test.ts: 7c62d400e776db4f9d2b6fe6470936deee034a8d36e98596b28e8a4849d8c44a
  src/app/api/v1/appointments/route.ts: 3a051847fba1c22cd3b086a770995e23daa3711255b0c9c16e1995f80a83fc12
  src/app/api/v1/appointments/route.test.ts: 7c28f4935584694c2b1beea92f59aaa45e92501ac73ec31b46be364ffa30344c
---

# Bolt Report — U-005

## Summary
(see implementer report)
# Bolt report — U-005 "Add the public booking BFF routes (doctors, services, availability, create appointment)"

- **Status:** DONE_WITH_CONCERNS. The receptionist role literal is the whole authorization gate, and no test checks it against the real session or upstream (see `uncertain_decisions` and `acceptance_test_concern`).
- **Commit:** 8ff408721e9e5d756915c99175920ec10feba50c — `feat(U-005): Add the public booking BFF routes (doctors, services, availability, create appointment)` (trailers: `Unit: U-005`, `SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-005`, `SDD-Acceptance: v5`)

## What was implemented

- `src/app/api/v1/doctors/route.ts` — `export const GET = proxyGet('/v1/doctors')`
- `src/app/api/v1/services/route.ts` — `export const GET = proxyGet('/v1/services')`
- `src/app/api/v1/appointments/availability/route.ts` — `proxyGet('/v1/appointments/availability', { forwardQuery: true })`
- `src/app/api/v1/appointments/route.ts` — hand-written `POST(req: Request)`:
  1. `req.json()` in try/catch → 400 `INVALID_JSON` envelope
  2. `createAppointmentPayloadSchema.safeParse` → 400 `VALIDATION_ERROR` with `issues[0].message`
  3. if `bookingChannel === 'staff' || override === true` → `getServerSession(authOptions)`, `new JWTPermissionChecker(session?.user?.permissions ?? [], session?.user?.roles ?? []).hasRole('receptionist')`, else 403 `FORBIDDEN` (null session degrades to no roles, so no throw)
  4. `apiServer.post('/v1/appointments', parsed.data)` → status `res.success === false ? 400 : 200` (same as `respond()`)
- Tests: `src/app/api/v1/appointments/route.test.ts` (8 acceptance-named tests plus 1 extra: `maps a failed upstream envelope to 400`), `src/app/api/v1/appointments/availability/route.test.ts` (1 acceptance-named test).

## Tests

- TDD red: both suites failed before implementation because vite import analysis could not resolve `./route` (module absent), which is the correct reason.
- Green: `pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose` → 9/9 passed; `pnpm test:run src/app/api/v1/appointments/availability/route.test.ts --reporter=verbose` → 1/1 passed.
- Deliberate deviation: `route.test.ts` has one test that is not in the `acceptance_test` list, `maps a failed upstream envelope to 400`. It covers the envelope→status mapping I copied from the private `respond()` in `route-handler.ts`, which I'm not allowed to modify. All 8 `expects` strings for this file, and the 1 for availability, are present word for word and passing.
- Full suite `pnpm test:run` → 12 files, 77 tests passed.
- `pnpm exec tsc --noEmit` → 0 errors. `eslint` on the 6 files → no issues (one import/order error in the availability test was fixed before commit).

## Hard rules honored

- DO NOT add new package.json dependencies: package.json is unchanged (`git diff --quiet` confirmed).
- DO NOT modify src/libs/api/route-handler.ts: the file is unchanged; `proxyGet` is imported as-is.
- file:src/app/api/v1/**/route.ts MUST follow kebab-case naming: the segments `doctors`, `services`, `appointments` and `availability` are all lower-case single words, and every file is named `route.ts`.
- MUST parse the POST body with createAppointmentPayloadSchema before any upstream call and answer 400 on failure: `safeParse` runs before the role gate and `apiServer.post`, and the tests assert `post` is never called on a 400.
- MUST reject bookingChannel staff or override true unless the session holds the receptionist role: the gate has two independent triggers, and the tests cover staff, staff+override, online+override, a null session, and non-receptionist roles.
- MUST call apiServer, never apiClient: only `@/libs/api/server` is imported (directly, or via `route-handler`).
- MUST NOT log request bodies or patient data: there are no `console.*` calls in any of the files.

## Provenance

- The trailer is present in all 6 files. The `Implements claim:` line is OMITTED because the dispatch's Provenance values block says `claims: (none cited)`.

## reuse_decisions

```yaml
reuse_decisions:
  - candidate: "src/libs/api/route-handler.ts:proxyGet"
    decision: reused
  - candidate: "src/libs/jwt-permission/index.ts:JWTPermissionChecker.hasRole"
    decision: reused
  - candidate: "src/features/appointments/schemas/booking/index.ts:createAppointmentPayloadSchema"
    decision: reused
  - candidate: "src/libs/api/server.ts:apiServer"
    decision: reused
  - candidate: "src/libs/api/route-handler.ts:proxyPost"
    decision: not_applicable
    reason: "proxyPost forwards the raw req.json() body with no validation or role gate; the unit requires zod parse + receptionist check before upstream, so POST is hand-written (constitution C-002 allows this for server-side logic)."
  - candidate: "src/libs/api/route-handler.ts:respond (envelope→status mapping)"
    decision: reimplemented
    reason: "respond() is module-private (not exported) and route-handler.ts is DO NOT MODIFY; the one-line mapping `res.success === false ? 400 : 200` is mirrored inline, matching the U-008 cron route precedent."
  - candidate: "reuse-index.yaml (full scan)"
    decision: not_applicable
    reason: "reuse-index.yaml is absent at .mega-sdd/codebase/reuse-index.yaml (recorded in the dispatch omissions appendix); used the unit's existing_interfaces plus a grep for any receptionist role constant (none exists in src/)."
```

## Self-report

```yaml
bolt_self_report:
  model_used: "Opus 5"
  confidence: 0.7
  certain_decisions:
    - "The POST order is: JSON parse (400), then zod safeParse (400), then the role gate (403), then upstream. No upstream call happens on any rejection."
    - "The role gate fires on bookingChannel === 'staff' OR override === true, independently."
    - "Only parsed.data is forwarded, and the test asserts exact equality with the clean payload, so any unknown field leaking would fail it."
    - "An anonymous online booking never calls getServerSession, so the public /book path needs no session."
  uncertain_decisions:
    - decision: "Role literal 'receptionist' is a module-local constant in the route"
      rationale: "The unit text names the role 'receptionist'; no role constant exists in src/ to reuse, and hasRole matching is case-insensitive."
      fallback_if_wrong: "If upstream emits a different role name (for example 'front_desk'), change RECEPTIONIST_ROLE, or move it to a shared constant once the role catalogue is decided."
    - decision: "Error envelope codes INVALID_JSON / VALIDATION_ERROR / FORBIDDEN"
      rationale: "No project-wide error code catalogue exists; these follow the UNAUTHORIZED precedent in the U-008 cron route."
      fallback_if_wrong: "Rename the codes to match the upstream catalogue once it is known; the status codes are the contract the tests pin."
  acceptance_test_concern: "The suite mocks apiServer and getServerSession, so it cannot catch a mismatch between the real session shape and session.user.roles (for example, upstream putting roles on permissions only). Proposed extra assertions: (1) an integration-style test through the real authOptions session callback proving roles reach session.user.roles; (2) a test that the doctors and services proxies forward to /v1/doctors and /v1/services (they are one-liners and not covered by any acceptance entry)."
  retry_history:
    - attempt: 1
      failure: "eslint import/order: `next/server` import should occur before import of `vitest` (availability/route.test.ts:14)"
      fix: "Moved the next/server import above vitest before commit; re-lint clean, test still green."
```

## Rollback hints

```yaml
- step_id: step-1-create-doctors-route
  step_type: file_created
  evidence: "created src/app/api/v1/doctors/route.ts (one-line proxyGet)"
  compensating_action: "git rm src/app/api/v1/doctors/route.ts"
  idempotent: true
- step_id: step-2-create-services-route
  step_type: file_created
  evidence: "created src/app/api/v1/services/route.ts (one-line proxyGet)"
  compensating_action: "git rm src/app/api/v1/services/route.ts"
  idempotent: true
- step_id: step-3-create-availability-route
  step_type: file_created
  evidence: "created src/app/api/v1/appointments/availability/route.ts and route.test.ts"
  compensating_action: "git rm src/app/api/v1/appointments/availability/route.ts src/app/api/v1/appointments/availability/route.test.ts"
  idempotent: true
- step_id: step-4-create-appointments-post-route
  step_type: file_created
  evidence: "created src/app/api/v1/appointments/route.ts and route.test.ts"
  compensating_action: "git rm src/app/api/v1/appointments/route.ts src/app/api/v1/appointments/route.test.ts"
  idempotent: true
- step_id: step-5-run-acceptance-tests
  step_type: test_command_run
  evidence: "pnpm test:run on both acceptance files: 9/9 and 1/1 passed; full suite 77/77"
  compensating_action: ""
  idempotent: true
- step_id: step-6-commit
  step_type: git_commit
  evidence: "commit 8ff408721e9e5d756915c99175920ec10feba50c (6 files, +362)"
  compensating_action: "git revert --no-edit 8ff408721e9e5d756915c99175920ec10feba50c"
  idempotent: false
```

## Review panel
- Tier: **full** · signals_fired: ['auth_globs', 'file_count', 'vocabulary', 'risk_field'] · lenses: spec, quality, security, standards · implementer model routing: inherit (session model)
- L0: run-code-gates.sh --write per unit commit (8ff4087) — no blocking finding
- Ledger `findings.json` (merge-panel-findings.sh): attempt 1 · gate clear · open 0 · advisory 5 · resolved 0

| id | severity | file:line | lens | status | title |
|---|---|---|---|---|---|
| F-1 | Minor | src/app/api/v1/appointments/route.ts:72 | quality | advisory | Envelope-to-status mapping re-implemented a third time |
| F-2 | Minor | src/app/api/v1/appointments/availability/route.test.ts:25 | quality | advisory | Availability test covers only the success case |
| F-3 | Important | src/app/api/v1/appointments/availability/route.ts:16 | security | advisory | Input validation: public availability GET forwards every query param unchecked |
| F-4 | Important | src/libs/auth.ts:120 | security | advisory | Authz: the receptionist gate trusts a role claim clients can forge (pre-existing bug) |
| F-5 | Minor | src/app/api/v1/appointments/route.ts:48 | security | advisory | CSRF: cookie-authorized state-changing POST has no Origin check |

## Post-flight
- Hard rules: postflight.json status **pass** (DO_NOT_ADD_DEPS=pass, DO_NOT_MODIFY=pass, NAMING_RULE=pass)
- Acceptance: acceptance.json status **pass** (0/9 executed entries pass)
- ✓ Drift check: clean (lite lane — no binding.md anchors; no LOCKED entities in the vault)

