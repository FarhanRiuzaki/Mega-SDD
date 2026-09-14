---
unit: U-004
status: success
attempted_at: 2026-09-14T09:59:09Z   # derived: last implementer commit d24c960 10:08:53Z minus implementer duration 584s (dispatch-prompt mtime rewritten by the formatter incident)
duration_seconds: 584
commits: [3629a3b169e4de12b905dfdb64fb79abdfa15441, d24c960e95412a5066c3f8f14bb9679b9bd64f0a, 1e5af0618f68d5314464136367c657cc8f25f06b]
files_touched: [src/features/contact/schemas/contact.schema.ts, src/features/contact/types/index.ts, src/app/api/v1/contact-messages/route.ts, src/app/api/v1/contact-messages/route.test.ts]
tests_run: ["pnpm test:run src/app/api/v1/contact-messages", "pnpm test:run"]
test_results: "acceptance 15/15 passed; full suite 49/49 at bolt time"
retries: 0
model_routed: inherit   # session model; router implementer_model was opus (tier full)
target_hashes:
  src/features/contact/schemas/contact.schema.ts: 6fa5e0f03ac288b5e3f27204e302c430843caba6fea40eda85b838262f550e46
  src/features/contact/types/index.ts: 549c5d1f536ca28ce282e3d9c15d4a064d951c63ce248438a23c9d00e1239b75
  src/app/api/v1/contact-messages/route.ts: 889feb2dd3fa72e805c278a167ae6ff58f30ce32de6047ef0fd4ecec64cce47a
  src/app/api/v1/contact-messages/route.test.ts: 952e832fee4234e9d161d0c678e89e2ae709ca5c356c70d8e51c1a3e60d024c6
---

# Bolt report — U-004 "Buat schema pesan kontak dan route handler penyimpanan"

**Status:** DONE_WITH_CONCERNS
**Commit:** 3629a3b169e4de12b905dfdb64fb79abdfa15441 — `feat(U-004): Buat schema pesan kontak dan route handler penyimpanan` (trailers: `Unit: U-004`, `SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-004`, `SDD-Acceptance: v5`)

## What was implemented

- `src/features/contact/schemas/contact.schema.ts`: `contactFormSchema` (zod 4). `name` is trimmed, required and at most 100 characters. `email` is required, must be a valid address and is at most 255 characters. `message` is trimmed, required and at most 2000 characters. Every error message is in Indonesian: `Nama/Email/Pesan wajib diisi`, `Format email tidak valid`, `… maksimal N karakter`. Also exported: `ContactFormValues`, `contactFormDefaults` (empty strings, consumed by U-005), and the limit constants `CONTACT_*_MAX`.
- `src/features/contact/types/index.ts`: `IContactMessage` (the upstream record, snake_case `created_at`), `TCreateContactMessagePayload` (form values plus `created_at`) and `TContactFieldErrors`.
- `src/app/api/v1/contact-messages/route.ts`: `POST` behaves as follows:
  - A body that isn't valid JSON returns 400 `{success:false, code:'INVALID_JSON', data:null}`.
  - It runs `safeParse`. If validation fails it returns 400 `{success:false, code:'VALIDATION_ERROR', message, data:{fieldErrors}}` (built with `z.flattenError`) and never calls the upstream.
  - If validation passes it calls `apiServer.post('/v1/contact-messages', {name, email, message, created_at: new Date().toISOString()})` and returns that envelope, with the same status mapping as `respond()` (failed envelope → 400, otherwise 200).
- `src/app/api/v1/contact-messages/route.test.ts`: 15 tests (details below).

## Tests

- **TDD:** the test was written first. Its pre-implementation run failed for the right reason: `Error: Failed to resolve import "./route" from "src/app/api/v1/contact-messages/route.test.ts". Does the file exist?`
- **Acceptance:** `pnpm test:run src/app/api/v1/contact-messages` → **15 passed (15)**.
- **Cases covered:**
  - Valid payload → 200, and the upstream receives an ISO `created_at` inside the request's time window.
  - Invalid email → 400, `fieldErrors.email = ['Format email tidak valid']`, no errors on the other fields, upstream not called.
  - Each of these → 400 with a field error and the upstream not called: name of 101 characters, whitespace-only name, message of 2001 characters, whitespace-only message, email over 255 characters, empty name, empty email, empty message.
  - `{}` → all three Indonesian "wajib" messages.
  - Malformed JSON → 400, upstream not called.
  - Boundary values (name of exactly 100, message of exactly 2000) → 200.
  - Name and message are forwarded trimmed.
  - Upstream 500 → 400 failed envelope.
- **Mutation check:** I temporarily removed `.trim()` from `name` and 2 tests failed (the trimmed-forward test and the whitespace-only-name test). The schema was restored afterwards.
- **Full suite:** `pnpm test:run` → 6 files, 49 passed.
- **Lint and format:** `eslint` and `prettier --check` are clean on all 4 files. `tsc --noEmit` reports no errors in these files; the only errors are stale `.next/**/validator.ts` stubs for sibling pages (beranda/kontak/tentang-kami) that aren't built yet.

## Hard rules honored

- DO NOT add new package.json dependencies: honored, `package.json` untouched (zod, msw and next were already installed).
- DO NOT modify src/libs/api/server.ts: honored, untouched.
- DO NOT modify src/libs/api/route-handler.ts: honored, untouched.
- file src/app/api/v1/contact-messages/route.ts MUST exist after bolt: honored, created and committed.
- MUST validate name, email and message with the zod schema on the server before calling apiServer: honored. `safeParse` runs first and every invalid case returns before `apiServer.post`; the test asserts the upstream call count stays 0.
- MUST reach the upstream only through apiServer inside the route handler: honored. The route's only network call is `apiServer.post`.
- Framework pack: the file is named `route.ts`. It is a Route Handler, not a Server Action, so no `"use server"` is needed.

## reuse_decisions

```yaml
reuse_decisions:
  - candidate: "reuse-index.yaml (Iron Rule 4b full scan)"
    decision: not_applicable
    reason: "File is absent at .mega-sdd/codebase/reuse-index.yaml (recorded in the dispatch PROVENANCE omissions). The full-index scan could not be run, so none is claimed. As a substitute I grepped .mega-sdd/codebase/symbol-index.json for contact/validation/schema/flatten helpers and found only the per-feature form schemas (users/profile/roles/permissions/password), none of which fits."
  - candidate: "src/libs/api/route-handler.ts:proxyPost"
    decision: not_applicable
    reason: "Forwards the raw body with no hook for validation, so it cannot satisfy 'validate before calling apiServer' or the created_at stamping. Modifying it is forbidden by a Hard rule."
  - candidate: "src/libs/api/route-handler.ts:respond"
    decision: reimplemented
    reason: "Not exported from route-handler.ts, and Hard rules forbid modifying that file. Its one-line status mapping (success === false ? 400 : 200) is reproduced inline in route.ts."
  - candidate: "src/libs/api/server.ts:apiServer"
    decision: reused
  - candidate: "src/features/users/schemas/user.schema.ts (schema + inferred type + defaults pattern)"
    decision: reused
    reason: "Followed the pattern: contactFormSchema / ContactFormValues / contactFormDefaults."
  - candidate: "src/test/handlers.ts:server (MSW)"
    decision: reused
  - candidate: "zod z.flattenError"
    decision: reused
    reason: "Non-deprecated zod 4.3.6 API for the fieldErrors map; confirmed present by a probe."
```

## Provenance trailer notes

- The trailer is present in all 4 created files. `Hard Rules active:` lists the six rule texts verbatim.
- **The `Implements claim:` line is OMITTED** because the Provenance values block says `claims: (none cited)`. I did not derive a claim id myself.
- The version is `7.37.0`, taken from the dispatch's Contracts line ("mega-sdd v7.37.0").

## Review panel

_Controller-written (execute-bolts, lite lane)._

- **Tier:** `full` (router `resolve-review-tier.sh`; `signals_fired: [auth_globs, file_count]`, `unit_tier: l`) → lenses: **spec, quality, security, standards**. Design lens not dispatched: not UI-bearing (the dispatch builder returned no `design_slice_path`).
- **Round 1 merge** (`merge-panel-findings.sh`, head `1e5af06`): **gate `clear`**. open 0 · advisory 4 · resolved 0 · dropped_no_evidence 0 · spec verdict **pass**. Ledger: `findings.json` (script-written). Standards found nothing.

| Severity | file:line | Lens | Status | Finding |
|---|---|---|---|---|
| Minor | src/app/api/v1/contact-messages/route.ts:56 | security | advisory | The upstream's error `code`/`message` goes back verbatim to anonymous callers. Other proxy routes do the same, but this is the first public one. Fix-forward: return a fixed public message and log the upstream code server-side |
| Minor | src/app/api/v1/contact-messages/route.test.ts:75 | quality | advisory | Success-path test asserts only `success: true`; should assert the full upstream envelope |
| Minor | src/app/api/v1/contact-messages/route.test.ts:80 | quality | advisory | No test pins that only `{name,email,message,created_at}` go upstream (extra keys) |
| Minor | src/app/api/v1/contact-messages/route.test.ts:159 | quality | advisory | Malformed-JSON test does not assert `code: 'INVALID_JSON'` |

- **L0 code gates** (`run-code-gates.sh --pack=.mega-sdd/toolchain/scoped-toolchain.md`, range `302055e..3629a3b`, status `pass`):
  - format: the scoped `prettier --write` rewrapped one line of `contact.schema.ts` (`fix_applied: true`). The controller committed that fix under the unit's identity as `1e5af06` (`style(U-004)`).
  - lint: pass, scoped to this diff
  - typecheck (`tsc --noEmit`, project-wide): FAIL, findings-only. The errors are only TS2307 in generated `.next/types/validator.ts` for not-yet-built sibling pages; none is introduced by this diff.
  - secrets: 0 (gitleaks)
  - SAST: 0 (semgrep)
  - new deps: 0
  - dep authorization: 0 unauthorized
- **Post-flight:** pass. 6 rules, 2 directive advisory. Re-run after `1e5af06`.
- **Acceptance (B4):** pass, 1 executed. Re-run after `1e5af06`.
- **Drift check:** clean. No LOCKED entities. Storage follows the OQ-AR-1 recommendation (deferred, runner-assumed).
- **JIT bind:** 10 CONFIRMED + 1 OQ, 0 model tokens. The OQ is C-U004-01: `apiServer` is declared as a `const`, which the symbol index does not capture. It does not block.

## Self-assessment

```yaml
bolt_self_report:
  model_used: "Opus 5"
  confidence: 0.85
  certain_decisions:
    - "Validation runs server-side via contactFormSchema.safeParse before any apiServer call; invalid input returns 400 without an upstream request (asserted by an MSW call counter)."
    - "created_at is stamped by the route handler as new Date().toISOString() and forwarded upstream."
    - "Upstream reached only through apiServer.post('/v1/contact-messages', ...); status mapping mirrors respond()."
    - "Trim runs before min/max so whitespace-only name/message is rejected (proven by a mutation check)."
  uncertain_decisions:
    - decision: "The test runs in the default jsdom environment instead of the '// @vitest-environment node' pragma named in Implementation step 3."
      rationale: "vitest.config.ts applies setupFiles ['./src/test/setup.ts'] globally, and setup.ts:41 touches `window` at top level. Probing under node env gave 'ReferenceError: window is not defined' at src/test/setup.ts:41, and there is no per-file way to skip setupFiles. Fixing that requires editing setup.ts or vitest.config.ts, neither of which is in target_files. A probe confirmed that NextRequest, apiServer, MSW and NextResponse.json all behave correctly under jsdom."
      fallback_if_wrong: "In a unit that owns src/test/setup.ts, guard the window polyfills with `typeof window !== 'undefined'` (or add a per-glob environment override in vitest.config.ts), then add the node pragma to route.test.ts."
    - decision: "Malformed JSON returns code 'INVALID_JSON' with data null."
      rationale: "The spec requires only 400 for this case and names no code; VALIDATION_ERROR is reserved for the fieldErrors shape."
      fallback_if_wrong: "Switch to code 'VALIDATION_ERROR' with data { fieldErrors: {} }; U-005's apiClient only relies on !res.ok."
    - decision: "Email is not trimmed. A missing or empty email reports 'Email wajib diisi'; any other invalid value reports 'Format email tidak valid'."
      rationale: "The spec lists trim only for name and message. A leading or trailing space in an email is therefore rejected as an invalid format rather than silently corrected."
      fallback_if_wrong: "Use z.string().trim().pipe(z.email(...)) if the product wants whitespace tolerated."
    - decision: "The route handler does not wrap apiServer.post in try/catch, so a network-level fetch rejection bubbles up as a Next 500."
      rationale: "This matches proxyPost's behaviour. An upstream non-OK response is already converted into a failed envelope by apiServer.onError (tested: 500 → 400)."
      fallback_if_wrong: "Catch and return 502 { success:false, code:'UPSTREAM_UNAVAILABLE' }."
  acceptance_test_concern: "The unit's listed cases only proved rejection and 200-on-valid. I added assertions for: the forwarded name and message are the trimmed values; boundary lengths 100/2000 are accepted; email over 255 is rejected; an upstream 500 maps to a 400 failed envelope; Indonesian messages for missing fields. Still untested: a network-level upstream failure (fetch rejection) and the real upstream's response contract for /v1/contact-messages, which is assumed from OQ-AR-1."
  retry_history:
    - attempt: 1
      failure: "Error: Failed to resolve import \"./route\" from \"src/app/api/v1/contact-messages/route.test.ts\". Does the file exist? (intended TDD red)"
      fix: "Implemented contact.schema.ts, types/index.ts, route.ts"
    - attempt: 2
      failure: "ESLint import/order (3x) in route.test.ts"
      fix: "eslint --fix (reordered next/server before msw/vitest); tests re-run 15/15"
```

## Concerns

1. **Environment pragma deviation** (see above). The spec asked for `// @vitest-environment node`, but the shared harness can't load under it. The test runs under jsdom and a comment in the test file explains why.
2. **Public reachability is not verified here.** context.md notes that `src/proxy.ts` guards non-auth pages. Its matcher already excludes `/api`, so this route handler is reachable without a session (U-001 handled the page guard). An anonymous visitor means `getServerSession` returns null, so `apiServer` sends no bearer. Whether the upstream accepts an unauthenticated `POST /v1/contact-messages` is an upstream contract question outside this repo (OQ-AR-1).
3. **Spam and rate limiting** are not addressed (OQ-CN-1 is deferred), by design.
4. **The anti-context `DO NOT WRITE` block doesn't apply here.** All six items are DB-schema patterns (PK, timestamps, VARCHAR sizing, delimited columns, date typing, FK constraints). This unit writes no DDL: the `contact_messages` table lives upstream per OQ-AR-1. The zod limits mirror the PRD column sizes (name 100, email 255, message 2000).
5. **Note for U-005:** a server rejection comes back as HTTP 400 with `data.fieldErrors` (`Partial<Record<'name'|'email'|'message', string[]>>`, typed `TContactFieldErrors`). U-005 should confirm whether `apiClient`'s throw-on-!ok keeps that envelope body before mapping the errors into react-hook-form (U-005 must not modify `src/libs/api/client.ts`).

## Rollback hints

```yaml
- step_id: step-1-test
  step_type: file_created
  evidence: "created src/app/api/v1/contact-messages/route.test.ts (175 lines)"
  compensating_action: "git rm -f src/app/api/v1/contact-messages/route.test.ts"
  idempotent: true
- step_id: step-2-schema
  step_type: file_created
  evidence: "created src/features/contact/schemas/contact.schema.ts (48 lines)"
  compensating_action: "git rm -f src/features/contact/schemas/contact.schema.ts"
  idempotent: true
- step_id: step-3-types
  step_type: file_created
  evidence: "created src/features/contact/types/index.ts (30 lines)"
  compensating_action: "git rm -f src/features/contact/types/index.ts"
  idempotent: true
- step_id: step-4-route
  step_type: file_created
  evidence: "created src/app/api/v1/contact-messages/route.ts (57 lines)"
  compensating_action: "git rm -f src/app/api/v1/contact-messages/route.ts"
  idempotent: true
- step_id: step-5-tests
  step_type: test_command_run
  evidence: "pnpm test:run src/app/api/v1/contact-messages → 15 passed; pnpm test:run → 49 passed"
  compensating_action: "(none — read-only)"
  idempotent: true
- step_id: step-6-commit
  step_type: git_commit
  evidence: "3629a3b169e4de12b905dfdb64fb79abdfa15441 feat(U-004): Buat schema pesan kontak dan route handler penyimpanan"
  compensating_action: "git revert --no-edit 3629a3b169e4de12b905dfdb64fb79abdfa15441"
  idempotent: false
- step_id: step-7-report-commit
  step_type: git_commit
  evidence: "follow-up commit 'docs(U-004): bolt report' adding only this file (U-001 precedent tracks its bolt-report.md; --amend is denied by the wave rail, so it is a separate commit)"
  compensating_action: "git rm -f .mega-sdd/vaults/company-profile/bolts/U-004/bolt-report.md && git commit -m 'revert U-004 bolt report'"
  idempotent: false
```
