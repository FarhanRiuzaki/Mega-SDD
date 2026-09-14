---
unit: U-015
status: success
attempted_at: 2026-09-14T15:31:43+00:00
duration_seconds: 407621
commits: [c6c1b5779fb5827b2da246d828692bac2e35ce7b]
files_touched: [src/app/(blank-layout-pages)/staff/login/page.test.tsx, src/app/(blank-layout-pages)/staff/login/page.tsx]
tests_run: ["pnpm test:run staff/login/page --reporter=verbose"]
test_results: "0 acceptance entries passed / 2 not passing (see acceptance.json)"
retries: 0
target_hashes:
  src/app/(blank-layout-pages)/staff/login/page.tsx: dc6215d9f434ee0bfc3997d11a5ca7196168cfbaabd41ee9b9a691726e3b9d57
  src/app/(blank-layout-pages)/staff/login/page.test.tsx: 0de0304643b424e41b3308d0a8cec38d0d26ef3928b68ee061f8c05bb9fbeb8b
---

# Bolt Report — U-015

## Summary
(see implementer report)
# Bolt report — U-015 "Add the /staff/login page on the existing credentials login"

- **Status:** DONE_WITH_CONCERNS
- **Commit:** c6c1b5779fb5827b2da246d828692bac2e35ce7b — `feat(U-015): Add the /staff/login page on the existing credentials login` (trailers: `Unit: U-015`, `SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-015`, `SDD-Acceptance: v5`)

## What was implemented

- `src/app/(blank-layout-pages)/staff/login/page.tsx` (create): a copy of the `/login` anchor with a different title. It sets `metadata = { title: 'Staff login', description: 'Clinic staff sign-in' }`, awaits `getServerMode()` and renders the shared `<Login mode={mode} />` view. The `(blank-layout-pages)` route group already wraps it in `BlankLayout`, and `src/proxy.ts:21` already lists `/staff/login` as a sign-in page (U-010), so no other files needed changes.
- `src/app/(blank-layout-pages)/staff/login/page.test.tsx` (create): mocks `@core/utils/serverHelpers` (`getServerMode` returns `'light'`) and `@views/Login` (a stub that echoes `mode`), then renders the awaited page. The two tests are named exactly after the `acceptance_test` `expects` strings.

## Tests

Written first, as TDD. The red run (before `page.tsx` existed) failed as expected: vite `import-analysis` could not resolve `./page`, with `Test Files 1 failed`.

Green run, after the commit's content was written:

| Command | Result |
|---|---|
| `pnpm test:run 'src/app/(blank-layout-pages)/staff/login/page.test.tsx' --reporter=verbose` (unit command, path quoted) | 2/2 passed |
| `pnpm test:run staff/login/page --reporter=verbose` (paren-free filter, same style as U-007) | 2/2 passed. It selects only this file (`Test Files 1 passed (1)`) |
| `pnpm exec eslint` on both files | no issues |
| `tsc --noEmit` | 0 errors in U-015 files. There is 1 error elsewhere: `src/app/api/appointments/[id]/cancel/route.test.ts(15,30) TS2307 Cannot find module './route'`. That file is not this unit's; it looks like a sibling bolt's test written before its route |

- **Route collision check:** a Glob of `src/app/**/staff/**/page.tsx` finds only `(blank-layout-pages)/staff/login/page.tsx` (this unit) and `(dashboard)/staff/schedule/page.tsx`. Those are different URLs, so no two pages resolve to `/staff/login`.
- **No menu entry:** the CLAUDE.md rule to add pages to both menu files applies to `(dashboard)` routes. Sign-in pages such as `/login` are not in the navigation, so `/staff/login` is left out as well.

## Concerns

1. **The acceptance command as written cannot run in a shell.** `pnpm test:run src/app/(blank-layout-pages)/staff/login/page.test.tsx ...` has unquoted parentheses:
   - bash: `syntax error near unexpected token '('`
   - zsh: `(blank-layout-pages)` is read as a glob group, so it reports `no matches found`

   This happens no matter what the implementation is. The controller should re-execute it either with the path quoted or as `pnpm test:run staff/login/page --reporter=verbose`. Both forms were verified green, as shown in the table above. The unit spec's command string would need quoting to be fixed at the source.
2. **Design ceiling comes from `@views/Login`.** The T2 design block asks for page furniture, a two-column composition and so on. This page deliberately adds no markup of its own: the unit says to reuse `@views/Login` "exactly like `/login`", and Hard rule `DO NOT modify src/views/Login.tsx` forbids touching the view where all of that lives. Any staff-login restyle belongs in a unit that owns `src/views/Login.tsx`.
3. **acceptance_test_concern:** the tests mock `@views/Login`, so they prove the page delegates to that view with the server mode and carries the right metadata. They do not prove the real form renders or signs in; that belongs to `Login` itself. After sign-in, `Login` redirects to `redirectTo ?? '/'`, which goes to `/home`. Two assertions could be added later: (a) the page passes through a `'dark'` mode unchanged, and (b) an e2e check that `/staff/login` stays reachable while signed out, via `proxy`. That route is already covered by `src/proxy.test.ts` from U-010.

## Hard rules honored

- DO NOT add new package.json dependencies: no manifest change (`git show --stat HEAD` lists only the 2 new files).
- DO NOT modify src/views/Login.tsx: untouched.
- DO NOT modify src/libs/auth.ts: untouched.
- file src/app/(blank-layout-pages)/staff/login/page.tsx MUST exist after bolt: created in c6c1b57.
- Pack rule: page file is named `page.tsx`.

## Provenance

The trailer is in both files. The `Implements claim:` line was **omitted** because the dispatch Provenance block says `claims: (none cited)`. It was not back-derived from the `## Claims` must-exist entries.

## reuse_decisions

- `{candidate: "@views/Login", decision: reused, reason: "unit goal: staff use the existing next-auth credentials flow"}`
- `{candidate: "@core/utils/serverHelpers#getServerMode", decision: reused}`
- `{candidate: "reuse-index.yaml full scan", decision: not_applicable, reason: "index absent at .mega-sdd/codebase/reuse-index.yaml per dispatch PROVENANCE omissions appendix"}`

## Self-report

```yaml
bolt_self_report:
  model_used: "Opus 5"
  confidence: 0.9
  certain_decisions:
    - "Page mirrors src/app/(blank-layout-pages)/login/page.tsx; only metadata differs"
    - "No proxy/layout change needed: route group supplies BlankLayout and proxy.ts already lists /staff/login"
    - "Implements claim trailer line omitted (claims: none cited)"
  uncertain_decisions:
    - decision: "Kept the unit's acceptance command unchanged; verified a quoted form and a paren-free filter form instead"
      rationale: "The literal command fails to parse in bash/zsh because of the unquoted route-group parens; the unit spec is outside target_files"
      fallback_if_wrong: "Controller runs `pnpm test:run staff/login/page --reporter=verbose` or quotes the path"
    - decision: "No custom staff-login UI"
      rationale: "Unit says reuse @views/Login exactly like /login; Login.tsx is hard-rule protected"
      fallback_if_wrong: "A follow-up unit owning src/views/Login.tsx adds staff-specific furniture"
  retry_history:
    - attempt: 1
      failure: "TDD red (intended): vite:import-analysis failed to resolve \"./page\" from page.test.tsx; Test Files 1 failed"
      fix: "Created page.tsx; 2/2 passed"
```

## Rollback hints

```yaml
- step_id: step-1-create-test
  step_type: file_created
  evidence: "created src/app/(blank-layout-pages)/staff/login/page.test.tsx (39 lines)"
  compensating_action: "git rm -f -- 'src/app/(blank-layout-pages)/staff/login/page.test.tsx'"
  idempotent: true
- step_id: step-2-create-page
  step_type: file_created
  evidence: "created src/app/(blank-layout-pages)/staff/login/page.tsx (33 lines)"
  compensating_action: "git rm -f -- 'src/app/(blank-layout-pages)/staff/login/page.tsx'"
  idempotent: true
- step_id: step-3-test-run
  step_type: test_command_run
  evidence: "pnpm test:run 'src/app/(blank-layout-pages)/staff/login/page.test.tsx' --reporter=verbose -> 2 passed"
  compensating_action: ""
  idempotent: true
- step_id: step-4-commit
  step_type: git_commit
  evidence: "c6c1b5779fb5827b2da246d828692bac2e35ce7b"
  compensating_action: "git revert --no-edit c6c1b5779fb5827b2da246d828692bac2e35ce7b"
  idempotent: false
```

## Review panel
- Tier: **full** · signals_fired: ['vocabulary'] · lenses: spec, security, standards · implementer model routing: inherit (session model)
- L0: run-code-gates.sh --write per unit commit (c6c1b57) — no blocking finding
- Ledger `findings.json` (merge-panel-findings.sh): attempt 1 · gate clear · open 0 · advisory 3 · resolved 0

| id | severity | file:line | lens | status | title |
|---|---|---|---|---|---|
| F-1 | Minor | src/views/Login.tsx:133 | security | advisory | Open redirect: unvalidated `redirectTo` now reachable via /staff/login |
| F-2 | Important | src/app/(blank-layout-pages)/staff/login/page.test.tsx:13 | standards | advisory | Test imports `render`/`screen` directly from `@testing-library/react` instead of the house harness |
| F-3 | Minor | src/@layouts/BlankLayout.tsx:30 | design | advisory | No <main> landmark on (blank-layout-pages) routes |

## Post-flight
- Hard rules: postflight.json status **pass** (DO_NOT_ADD_DEPS=pass, DO_NOT_MODIFY=pass, DO_NOT_MODIFY=pass, FILE_PRESENCE_RULE=pass)
- Acceptance: acceptance.json status **pass** (0/2 executed entries pass)
- ✓ Drift check: clean (lite lane — no binding.md anchors; no LOCKED entities in the vault)

