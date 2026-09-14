---
unit: U-003
status: success
attempted_at: 2026-09-14T23:33:00+07:00
duration_seconds: 610
commits: [3e415808af221b2874a4019fc505736159974722]
files_touched: [src/app/(blank-layout-pages)/beranda/page.tsx, src/views/company-profile/HomeView/index.tsx, src/views/company-profile/HomeView/index.test.tsx]
tests_run: ["pnpm test:run src/views/company-profile/HomeView/index.test.tsx"]
test_results: "5 passed / 0 failed"
retries: 0
target_hashes:
  src/app/(blank-layout-pages)/beranda/page.tsx: 72b18fdae5a758437332b563c8d111180ab7f54f77ca76a66518fe45e3fa67f2
  src/views/company-profile/HomeView/index.test.tsx: 35fa8d013d5da047fdbc7f9c171b0a11341998c073cefa1cb335bab61e362b77
  src/views/company-profile/HomeView/index.tsx: fa44b706792f7c998d8b9d9c717047c50ef621a14af261e6ec05295ec835749a
---

# Bolt Report — U-003

## Summary
Built the public Beranda page: thin `page.tsx` (metadata title Beranda) rendering `HomeView`, which shows the config name as the only h1, the tagline, a `Kontak` button to `/kontak`, and the three services as MUI cards in a Grid `xs:12 / md:4` (stacks at 375px, three-across from md). All organisation/service text comes from the U-002 config. Model: inherit (router unit_tier m, no W2 cell). TDD red (missing module) → green.

## Acceptance criteria status
- [x] `pnpm test:run src/views/company-profile/HomeView/index.test.tsx` — acceptance.json pass (`Test Files  1 passed (1)`)
- [ ] TBD OQ-AR-1 / OQ-FL-2 / OQ-CN-1 — deferred P2, resurfaced in _summary.md

## Review panel
- Tier: standard · signals_fired: [] · lenses: [spec, quality, standards] + design (UI-bearing) · round 1 · spec VERDICT: pass · ledger: open 0 / advisory 7 · dropped_no_evidence: 0 · gate: clear
- Important advisories: F-6 test imports view via `@views` alias instead of `'.'` (index.test.tsx:14); F-7 `@configs` vs `@/configs` alias split (HomeView/index.tsx:29)
- Minor advisories: "Layanan Kami" label view-authored; untested page metadata; Grid-class layout test; overlapping hover transitions; unrequested numbered avatar badge
- Design lens: clean (code-only, no render). L0: pass · reuse rows: 0.

## Post-flight
Hard Rules ✓ (3 rules, 1 directive advisory) | PBT n/a | Drift check: clean ✓ (vault carries no LOCKED entities)

## Failures (if any)
None.

```yaml
bolt_self_report:
  model_used: 'Opus 5'
  confidence: 0.8
  certain_decisions:
    - 'All organisation/tagline/service copy read from companyProfile; test asserts against config values, not literals'
    - 'MUI 7 Grid size={{ xs: 12, md: 4 }} API (house precedent src/app/(dashboard)/profile/page.tsx:9)'
    - 'page.tsx follows the login page shape: metadata export + render the view'
    - 'No navigation to Tentang Kami added (OQ-FL-2 deferred)'
  uncertain_decisions:
    - decision: "HomeView carries 'use client' although it uses no hooks"
      rationale: "every existing src/views/* view is a client component, and NotFound.tsx uses Button component={Link} under 'use client'; keeping the view client-side avoids passing next/link as a prop across the RSC boundary, which cannot be verified in Vitest"
      fallback_if_wrong: 'drop the directive to make HomeView a Server Component and confirm with pnpm build'
    - decision: 'Responsive behavior (375px / desktop) verified only via Grid size classes'
      rationale: 'jsdom has no layout engine; matchMedia is stubbed'
      fallback_if_wrong: 'add a browser-level viewport test (confidence for the responsive claim capped at MEDIUM)'
    - decision: 'metadata.description uses the config tagline'
      rationale: "avoids a second hard-coded description string; spec only mandates title 'Beranda'"
      fallback_if_wrong: 'remove the description field'
  retry_history:
    - attempt: 1
      failure: 'Test Files  1 failed (1) — Failed to resolve import "@views/company-profile/HomeView" (intentional TDD red, before implementation)'
      fix: 'created src/views/company-profile/HomeView/index.tsx'
```

## Rollback hints

```yaml
- step_id: step-1-create-test
  step_type: file_created
  evidence: 'created src/views/company-profile/HomeView/index.test.tsx'
  compensating_action: 'git rm -f src/views/company-profile/HomeView/index.test.tsx'
  idempotent: true
- step_id: step-2-create-page
  step_type: file_created
  evidence: 'created src/app/(blank-layout-pages)/beranda/page.tsx'
  compensating_action: "git rm -f 'src/app/(blank-layout-pages)/beranda/page.tsx'"
  idempotent: true
- step_id: step-3-create-view
  step_type: file_created
  evidence: 'created src/views/company-profile/HomeView/index.tsx'
  compensating_action: 'git rm -f src/views/company-profile/HomeView/index.tsx'
  idempotent: true
- step_id: step-4-run-acceptance
  step_type: test_command_run
  evidence: 'pnpm test:run src/views/company-profile/HomeView/index.test.tsx -> Test Files  1 passed (1)'
  compensating_action: ''
  idempotent: true
- step_id: step-5-commit
  step_type: git_commit
  evidence: 'commit feat(U-003): Build the public Beranda page on bench/p0-company-profile'
  compensating_action: "git revert --no-edit $(git log --format=%H --grep='^Unit: U-003$' -n 1)"
  idempotent: false
```
