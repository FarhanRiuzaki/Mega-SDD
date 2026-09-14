---
unit: U-010
status: success
attempted_at: 2026-09-14T11:34:52+00:00
duration_seconds: 408
commits: [101b34534f1089529643fea2327eb1114d330f7d]
files_touched: [src/proxy.ts, src/proxy.test.ts]
tests_run: ["pnpm test:run src/proxy.test.ts --reporter=verbose", "pnpm test:run"]
test_results: "10 passed / 0 failed (unit); 57 passed / 0 failed (full suite at bolt time, per implementer)"
retries: 0
target_hashes:
  src/proxy.ts: 1a990872b284cc2cb7ffb94c86d0b40798182f687c9120936733074d5c3ac07c
  src/proxy.test.ts: 7941a45fc089af425c17dce68a9715e744aef50bb53b8e17eda4780b20f367c4
---

# Bolt Report — U-010

## Summary
`src/proxy.ts` now splits the old `publicRoutes` list into exact-match sign-in pages (`/login`, `/register`, `/staff/login` — signed-in users bounced to `/home`) and always-public patient pages (`/book` exact, `/reschedule/<one token segment>` via `/^\/reschedule\/[^/]+$/`). Evaluation order is RefreshTokenError → patient pages → sign-in bounce → anonymous redirect; the exported `proxy(request: Request)` signature and `config.matcher` are byte-identical. `src/proxy.test.ts` carries the 9 acceptance tests (exact names) plus one extra (signed-in user on patient pages). Model routing: `inherit` (session model; no `model` param passed).

## Acceptance criteria status
- [x] lets an anonymous visitor open the booking page
- [x] lets an anonymous visitor open a reschedule link
- [x] lets an anonymous visitor open the staff login page
- [x] still redirects an anonymous visitor on a staff page to the login page
- [x] bounces a signed-in user from the staff login page to home
- [x] redirects an anonymous visitor on reschedule without a token or a substring collision to the login page
- [x] redirects an anonymous visitor on a book prefixed but unrelated path to the login page
- [x] still bounces a signed-in user from the login page to home
- [x] still clears cookies and redirects to login on a refresh error even for the booking page
(evidence: `bolts/U-010/acceptance.json` status pass — script-written by run-acceptance-tests.sh)

## Review panel
- Tier: **full** · signals_fired: [vocabulary, risk_field] · lenses: spec, quality, security, standards · design lens: skipped (non-UI unit — target_files are the route proxy and its test)
- L0 (`lens-inputs/U-010/l0-results.json`, run-code-gates.sh): exit 0 — no blocking finding, no SKIPs; reuse-duplication rows: 0
- Round 1 merged by `merge-panel-findings.sh`: gate **clear** · open 0 · advisory 1 · dropped_no_evidence 0 · spec verdict pass

| id | severity | file:line | lens | status | title |
|---|---|---|---|---|---|
| F-1 | Important | src/proxy.ts:59 | quality | advisory | Signed-in pass-through on a protected page is never tested |

## Post-flight
- Hard rules: `postflight.json` status pass (DO_NOT_ADD_DEPS pass, DO_NOT_MODIFY src/libs/auth.ts pass; directives advisory)
- ✓ Drift check: clean (no binding.md anchors in the lite lane; no LOCKED entities in the vault)

## Failures (if any)
None.

## Rollback hints
```yaml
- step_id: step-1-create-proxy-test
  step_type: file_created
  evidence: "created src/proxy.test.ts (114 lines, 10 tests)"
  compensating_action: "git rm src/proxy.test.ts"
  idempotent: true
- step_id: step-2-modify-proxy
  step_type: file_modified
  evidence: "src/proxy.ts: publicRoutes replaced by authPages + isPatientPage; provenance header added"
  compensating_action: "git checkout 101b34534f1089529643fea2327eb1114d330f7d~1 -- src/proxy.ts"
  idempotent: true
- step_id: step-3-commit
  step_type: git_commit
  evidence: "101b34534f1089529643fea2327eb1114d330f7d"
  compensating_action: "git revert --no-edit 101b34534f1089529643fea2327eb1114d330f7d"
  idempotent: false
```

```yaml
bolt_self_report:
  model_used: "Opus 5"
  confidence: 0.9
  certain_decisions:
    - "Sign-in pages matched exactly with includes(), so only /staff/login is public under /staff"
    - "Reschedule matched by an anchored single-segment pattern, never by substring"
    - "Refresh-error branch kept first; matcher and proxy signature byte-identical"
  uncertain_decisions:
    - decision: "Reschedule allows exactly one segment; /reschedule/abc/extra redirects"
      rationale: "Unit says 'a token segment'; one segment is the narrowest reading"
      fallback_if_wrong: "Widen to /^\\/reschedule\\/[^/]+(\\/.*)?$/ if tokens can contain slashes"
  retry_history:
    - attempt: 1
      failure: "Red phase (expected): 4 failed | 6 passed"
      fix: "Implemented the sign-in/patient page split; 10/10 passed"
    - attempt: 2
      failure: "src/proxy.test.ts(101,36): error TS2339: Property 'getSetCookie' does not exist on type 'Headers'."
      fix: "Read headers.get('set-cookie') and assert both cookies are emitted expired"
  acceptance_test_concern: "The 9 required tests do not cover a signed-in user on a protected page (/home, /staff/schedule) nor the /book/ trailing-slash case; the quality lens raised the same gap (F-1, advisory)."
```
