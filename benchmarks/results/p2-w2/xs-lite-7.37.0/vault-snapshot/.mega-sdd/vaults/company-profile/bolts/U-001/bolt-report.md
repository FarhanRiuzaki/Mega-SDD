---
unit: U-001
status: success
attempted_at: 2026-09-14T09:57:54Z   # derived: commit 10:03:08Z minus implementer duration 314s (dispatch-prompt mtime was rewritten by the repo-wide formatter incident, see Review panel)
duration_seconds: 314
commits: [eb286089c22e9e21585762e4a4c6441e5a88c625]
files_touched: [src/proxy.ts, src/proxy.test.ts]
tests_run: ["pnpm test:run src/proxy.test.ts", "pnpm test:run"]
test_results: "acceptance 8/8 passed; full suite 34/34 at bolt time"
retries: 0
model_routed: sonnet
w2_model_cell: "xs→sonnet"
target_hashes:
  src/proxy.ts: 02247868589fa3a81d2c088e732e81fc2d9ed6f2c83eeae7e6aeb7abc8d4bc93
  src/proxy.test.ts: 43ffcdf1884aa452a11a65b81b1005092fe837565c863c728c7ff24304b99787
---

# Bolt Report — U-001 "Loloskan halaman profil publik di route guard proxy"

## Status: DONE

## What was implemented

`src/proxy.ts` now carries a second, separate route list — `publicProfileRoutes`
(`/beranda`, `/tentang-kami`, `/kontak`) — that passes the guard with or without
a session. The existing `publicRoutes` list (`/login`, `/register`) and its
"logged-in user on an auth page bounces to `/home`" branch are untouched: the
bounce-to-`/home` check only reads `isPublicRoute`, never the new
`isPublicProfileRoute` flag, so it stays scoped to the auth pages exactly as
the Hard rule/Anchor at src/proxy.ts:24 requires. The unauthenticated redirect
branch (previously src/proxy.ts:28) gained one extra condition:
`!isPublicRoute && !isPublicProfileRoute`.

`src/proxy.test.ts` was created beside it (Vitest + RTL harness) covering:
- no session: all three public-profile routes pass through (no `location` header)
- no session: `/users` redirects to `/login`
- with session: all three public-profile routes still pass through
- with session: `/login` bounces to `/home`

## TDD — red phase evidence

Per workflow step 2 (unit's `acceptance_test.type: test`), the test was proven to
fail for the right reason before landing the fix:

1. Implemented `src/proxy.ts` and `src/proxy.test.ts` together, confirmed green.
2. Reverted only the guard condition back to `!session?.accessToken && !isPublicRoute`
   (dropping `&& !isPublicProfileRoute`) and re-ran `pnpm test:run src/proxy.test.ts`.
3. Result: exactly the 3 no-session public-profile-route cases failed
   (`expected 'http://localhost:3000/login' to be null`) — the 5 other cases
   passed regardless, because with a session the old code already fell through
   to `next()`, and `/users`→`/login` / `/login`→`/home` behavior is unchanged
   by this unit. Those 5 are regression guards, not proof of the new behavior;
   only the 3 no-session cases demonstrate the fix.
4. Restored the fix (`&& !isPublicProfileRoute`), re-ran — all 8 tests green.

## Tests run

- `pnpm test:run src/proxy.test.ts` → 8 passed (acceptance_test command, matches `expects: passed`)
- `pnpm test:run` (full suite) → 5 files / 34 tests passed, no regressions
- `pnpm lint src/proxy.ts src/proxy.test.ts` → no issues

## Files changed

- `src/proxy.ts` (modified) — added `publicProfileRoutes` + guard condition + provenance trailer
- `src/proxy.test.ts` (created) — acceptance test per frontmatter `acceptance_test`
- `.mega-sdd/vaults/company-profile/bolts/U-001/bolt-report.md` (this file)

## Hard rules honored

- DO NOT add new package.json dependencies — no `package.json`/lockfile touched.
- DO NOT modify next.config.ts — untouched.
- file src/proxy.test.ts MUST exist after bolt — created.
- ALWAYS keep src/proxy.test.ts beside src/proxy.ts — created in the same directory (`src/`).

## reuse_decisions

- `reuse-index.yaml`: not found anywhere in the repo (`find … -iname reuse-index.yaml` → 0 results); dispatch's T1 `reuse_index_line` and T2 `reuse_slice` are both recorded as absent inputs. No existing helper/mock for `getServerSession` was found in `src/**/*.test.ts*` either (only `src/test/setup.ts` mocks `next-auth/react`, a different module than `next-auth`). Decision: `not_applicable` — wrote a fresh, file-local `vi.mock('next-auth', …)` because nothing in the codebase covers it.

## Provenance / deviation note

- `Implements claim:` trailer line omitted deliberately — the dispatch's
  `Provenance values` block states `claims: (none cited)`, so there is nothing
  to cite; this is the correct application of "if a value is absent, omit that
  trailer line," not an oversight.
- Unit id / vault sha / anchors / hard-rules trailer lines ARE present verbatim
  in `src/proxy.ts` (top-of-file comment block), sourced from the dispatch's
  `Provenance values` block.

## Self-review findings and concerns

- `publicProfileRoutes.includes(pathname)` is an exact string match, mirroring
  the existing `publicRoutes` idiom at src/proxy.ts:11 — `/beranda/` (trailing
  slash) or any sub-path under these three routes would still be bounced to
  `/login` when unauthenticated. The unit names exactly three literal paths and
  the codebase's existing pattern is exact-match, so left as-is; flagging for
  a possible future unit if profile pages grow nested routes.
- No other concerns; all four Hard rules verified, acceptance test matches the
  frontmatter command/expects exactly, full suite has no regressions.

## Review panel

_Controller-written (execute-bolts, lite lane)._

- **Tier:** `minimal` (router `resolve-review-tier.sh`; `signals_fired: []`, `unit_tier: xs`) → lenses: **spec**. Design lens not dispatched: not UI-bearing (the dispatch builder returned no `design_slice_path`).
- **Round 1 merge** (`merge-panel-findings.sh`, head `eb28608`): **gate `clear`**. open 0 · advisory 1 · resolved 0 · dropped_no_evidence 0 · spec verdict **pass**. Ledger: `findings.json` (script-written).

| Severity | file:line | Lens | Status | Finding |
|---|---|---|---|---|
| Minor | src/proxy.test.ts:1 | spec | advisory | `// @vitest-environment node` pragma from step 2 omitted. Code-justified: `src/test/setup.ts:41` touches `window` at module scope; the fix is out of this unit's whitelist |

- **L0 code gates** (`run-code-gates.sh --pack=.mega-sdd/toolchain/scoped-toolchain.md`, range `3d4b926..eb28608`, status `pass`):
  - format and lint: pass, scoped to this diff
  - typecheck (`tsc --noEmit`, project-wide): FAIL, findings-only. Every error is TS2307 in generated `.next/types/validator.ts` / `.next/dev/types/validator.ts` for the not-yet-built sibling pages beranda/kontak/tentang-kami. None is introduced by this diff.
  - secrets: 0 (gitleaks)
  - SAST: 0 (semgrep)
  - new deps: 0
  - dep authorization: enforced, 0 unauthorized
- **Formatter incident (recorded, not this unit's code):**
  - The first L0 run used the detected toolchain (`npx prettier --check .` → `npx prettier --write .`). The repo baseline is not prettier-clean, so the fix rewrote **62 tracked files outside every unit whitelist**, including `pnpm-lock.yaml`, `tsconfig.json` and the PRD, plus untracked vault artifacts. The untracked `dispatch-prompt.md` files were among them, so their mtimes are unreliable.
  - All 62 tracked files were restored to HEAD (`git restore`). Their diffs were verified formatting-only first.
  - The gates were re-run with a scoped pack `## Toolchain` override: format and lint on the bolt's own diff, tsc still project-wide.
  - U-001's own files were already format-clean.
- **Post-flight:** pass. 4 rules, 1 directive advisory.
- **Acceptance (B4):** pass, 1 executed, 0 pending manual.
- **Drift check:** clean. No LOCKED entities. The change matches `context.md#Constraints` (route guard must admit the three public pages).
- **JIT bind:** 8/8 claims CONFIRMED, 0 model tokens.

## bolt_self_report

```yaml
bolt_self_report:
  model_used: "Sonnet 5"
  confidence: 0.9
  certain_decisions:
    - "Added publicProfileRoutes as a separate list from publicRoutes, per Implementation step 1, so the /home bounce (src/proxy.ts:24) stays scoped to /login and /register only."
    - "Guard condition became `!session?.accessToken && !isPublicRoute && !isPublicProfileRoute` — minimal one-condition change, no restructuring of the existing branches."
    - "Kept RefreshTokenError branch and config matcher untouched per Migration notes KEEP list."
  uncertain_decisions:
    - decision: "Dropped the `// @vitest-environment node` docblock named in Implementation step 2 and ran the test under the default jsdom environment instead."
      rationale: "vitest.config.ts setupFiles (src/test/setup.ts) runs unconditionally regardless of per-file environment override, and it dereferences `window` at module scope (src/test/setup.ts:41) with no guard — under node environment this throws `ReferenceError: window is not defined` before any test runs. vitest.config.ts and src/test/setup.ts are both outside U-001's target_files (src/proxy.ts, src/proxy.test.ts), so editing either to add a guard would be scope creep. Verified empirically: with the docblock removed, all 8 tests (and the full 34-test suite) pass under jsdom, since proxy() only touches Request/URL/NextResponse — all available in jsdom — and next-auth is mocked directly rather than relying on the jsdom-oriented next-auth/react mock in setup.ts."
      fallback_if_wrong: "Add a guarded `if (typeof window !== 'undefined')` around the jsdom-polyfill block in src/test/setup.ts (out of scope for U-001; would need its own unit/dispatch) and restore `// @vitest-environment node`."
  retry_history:
    - attempt: 1
      failure: "ReferenceError: window is not defined at src/test/setup.ts:41 when running src/proxy.test.ts with `// @vitest-environment node`."
      fix: "Removed the `// @vitest-environment node` docblock; ran the test under the project's default jsdom environment instead (see uncertain_decisions above)."
```

## Rollback hints

```yaml
- step_id: step-1-edit-proxy
  step_type: file_modified
  evidence: "src/proxy.ts — added publicProfileRoutes list + isPublicProfileRoute check + updated guard condition on the unauthenticated-redirect branch; added provenance trailer comment"
  compensating_action: "git checkout -- src/proxy.ts"
  idempotent: true
- step_id: step-2-create-proxy-test
  step_type: file_created
  evidence: "src/proxy.test.ts created — Vitest suite covering session/no-session x public-profile-route/protected-route matrix"
  compensating_action: "rm src/proxy.test.ts"
  idempotent: true
- step_id: step-3-run-tests
  step_type: test_command_run
  evidence: "pnpm test:run src/proxy.test.ts -> 8 passed; pnpm test:run (full suite) -> 34 passed; red-phase check confirmed 3 expected failures before restoring the fix"
  compensating_action: "(none — verification only, nothing to roll back)"
  idempotent: true
```
