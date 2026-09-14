---
unit: U-006
status: success
attempted_at: 2026-09-14T23:37:00+07:00
duration_seconds: 908
commits: [37ff5ebf0ef1d947d04bab259bd273543507c1ed, cdbdccb4baf0298fb52876ee14905a6875c27567]
files_touched: [src/app/(blank-layout-pages)/kontak/page.tsx, src/features/contact/components/ContactForm/index.test.tsx, src/features/contact/components/ContactForm/index.tsx, src/features/contact/hooks/useContact.ts, src/features/contact/repositories/contact.repository.ts]
tests_run: ["pnpm test:run src/features/contact/components/ContactForm/index.test.tsx"]
test_results: "9 passed / 0 failed"
retries: 0
target_hashes:
  src/app/(blank-layout-pages)/kontak/page.tsx: 4108f955ce3ce8fd5ff450318dd166faa2ebd81ba2c05958b84f97c1bbcf7bfb
  src/features/contact/components/ContactForm/index.test.tsx: 0d175a3cd93c51d3d08dc93bba00904c6f213901bc0e62490a126b746c74de98
  src/features/contact/components/ContactForm/index.tsx: c514b521de9946ae28c1405d73cba4d7d35bcb7e7dc37844c0717da965d57176
  src/features/contact/hooks/useContact.ts: fea1f3a0ffd32385c82d11e24a4f1926e009c2cf6c1fd7d5651b00c0e25a1c2c
  src/features/contact/repositories/contact.repository.ts: 81e3b55f1f1877127335b87eda24f0c4f0076e82a4af6bfa46bb648033e333ac
---

# Bolt Report — U-006

## Summary
Built the public Kontak page (`page.tsx`, metadata title Kontak) with `ContactForm`: labelled Nama / Email / Pesan fields (react-hook-form + `zodResolver(contactMessageSchema)` from U-005), a Kirim button (disabled + spinner while sending), inline `Alert` "Pesan terkirim" on success and an inline error Alert with the server message on rejection, values kept on failure. Data flow: `useSubmitContactMessage` (useMutation, no snackbar) → `submitContactMessage` repository → `apiClient.post('/v1/contact-messages')`. Two commits: the feature, then a test-only tightening of exact accessible names. Model: inherit (router unit_tier m). Implementer status DONE_WITH_CONCERNS (server fieldErrors cannot map per field because apiClient keeps only the message; success keyed on HTTP status; form clears after success; own page intro copy).

## Acceptance criteria status
- [x] `pnpm test:run src/features/contact/components/ContactForm/index.test.tsx` — acceptance.json pass (`Test Files  1 passed (1)`, 9 tests)
- [x] OQ-DM-1 resolved (plan, runner-assumed) — submits to /api/v1/contact-messages (U-005)
- [ ] TBD OQ-FL-1 / OQ-AR-1 — deferred P2, resurfaced in _summary.md

## Review panel
- Tier: standard · signals_fired: [file_count] · lenses: [spec, quality, standards] + design (UI-bearing) · round 1 · spec VERDICT: pass · ledger: open 0 / advisory 11 · gate: clear
- Important advisories: F-7 page-level assertions/import of the app route inside ContactForm's test (index.test.tsx:175); F-10 Kontak page is a lone centered card with no page shell or back link, unlike its siblings (page.tsx:35)
- Minor advisories: unrequested overline / intro copy / meta description; page inlines markup (no View file in target_files); send icon lacks aria-hidden; a never-failing "plain text" test; untested reset/stale-banner branches
- Reuse-duplication rows (5× `onSubmit` name matches) refuted by the quality lens. L0: pass over 37ff5eb^..cdbdccb.

## Post-flight
Hard Rules ✓ (3 rules, 2 directive advisory) | PBT n/a | Drift check: clean ✓ (vault carries no LOCKED entities)

## Failures (if any)
None.

```yaml
bolt_self_report:
  model_used: 'Opus 5'
  confidence: 0.85
  certain_decisions:
    - 'Repository returns the raw apiClient.post envelope and has no notistack import (constitution C-002; anchor user.repository.ts).'
    - 'Hook is a bare useMutation with no snackbar: makeCreateMutation is not used because it hard-wires enqueueSnackbar and the unit mandates inline Alert feedback.'
    - 'Per-field errors come from zodResolver(contactMessageSchema); a server 400 shows the thrown message in one inline error Alert, because apiClient (consume as-is) discards data.fieldErrors.'
    - "<form noValidate> so the browser's native email check never replaces zod's per-field error, keeping the 'sends no request' behavior deterministic."
    - "page.tsx stays a server component exporting metadata { title: 'Kontak' }; ContactForm is the client island."
    - 'Explicit field ids so helperText is linked via aria-describedby (accessible error description) and labels are unambiguous.'
  uncertain_decisions:
    - decision: 'Reset the form to empty after a successful submit.'
      rationale: "The spec and PRD are silent. Clearing prevents an accidental duplicate send and pairs with the 'Pesan terkirim' confirmation; the PRD's 'form stays filled' requirement applies only to failure, which is honored."
      fallback_if_wrong: 'Drop the onSuccess resetForm call in ContactForm so the values stay after success too.'
    - decision: "A new attempt that fails client validation clears the previous success/error banner (handleSubmit's onInvalid calls mutation.reset)."
      rationale: "Avoids a stale 'Pesan terkirim' sitting above fresh field errors; not asked for by the spec, but a small feedback-state correctness fix."
      fallback_if_wrong: 'Remove the onInvalid argument from handleSubmit.'
    - decision: "Fields carry MUI `required` (visible asterisk + native required/aria-required). The tests reach them by EXACT label-derived accessible name — getByRole('textbox', { name: 'Nama' | 'Email' | 'Pesan' }) — and assert toBeRequired() on each."
      rationale: "Every field is mandatory per the PRD, and the required marker is the accessible way to say so. MUI renders the asterisk aria-hidden, so each field's accessible name is exactly its label text. The first commit used a /^Nama/ regex, which would also have matched e.g. 'Nama Lengkap'; a follow-up test commit pins the exact names and asserts the required state explicitly (9/9 pass)."
      fallback_if_wrong: 'Remove `required` from the three fields and drop the three toBeRequired() assertions; the exact-name queries stay valid either way.'
    - decision: 'Added a metadata description and a one-line intro, both my own copy, and an overline with companyProfile.name.'
      rationale: 'Page furniture for a public page; the PRD specifies no page copy beyond the form.'
      fallback_if_wrong: 'Delete the description / intro Typography; the spec only requires the title and the Kontak heading.'
  retry_history:
    - attempt: 1
      failure: 'RED (expected): Test Files 1 failed (1) — vite:import-analysis could not resolve `import ContactForm from "."` at index.test.tsx:18:24 (component not yet created).'
      fix: 'Implemented repository, hook, ContactForm and page; the same command then passed 9/9.'
    - attempt: 2
      failure: "eslint: padding-line-between-statements — 'Expected blank line before this statement.' at index.test.tsx:143:5 (the `const { user }` after the multiline `const bodies = captureSubmissions(...)` in the 400 test)."
      fix: 'Inserted the blank line; eslint then reported no issues and the test still passed 9/9.'
```

## Rollback hints

```yaml
- step_id: step-1-create-test
  step_type: file_created
  evidence: 'created src/features/contact/components/ContactForm/index.test.tsx (9 tests: labels, invalid email/no request, empty fields, trimmed body + success, pending state, 400 + values kept, markup as text, page metadata, page heading)'
  compensating_action: 'git rm -f src/features/contact/components/ContactForm/index.test.tsx'
  idempotent: true
- step_id: step-2-create-repository
  step_type: file_created
  evidence: "created src/features/contact/repositories/contact.repository.ts (submitContactMessage -> apiClient.post('/v1/contact-messages', body))"
  compensating_action: 'git rm -f src/features/contact/repositories/contact.repository.ts'
  idempotent: true
- step_id: step-3-create-hook
  step_type: file_created
  evidence: 'created src/features/contact/hooks/useContact.ts (useSubmitContactMessage = useMutation, no snackbar)'
  compensating_action: 'git rm -f src/features/contact/hooks/useContact.ts'
  idempotent: true
- step_id: step-4-create-form
  step_type: file_created
  evidence: 'created src/features/contact/components/ContactForm/index.tsx (react-hook-form + zodResolver, Nama/Email/Pesan, Kirim, inline success/error Alerts)'
  compensating_action: 'git rm -f src/features/contact/components/ContactForm/index.tsx'
  idempotent: true
- step_id: step-5-create-page
  step_type: file_created
  evidence: "created src/app/(blank-layout-pages)/kontak/page.tsx (server component, metadata title 'Kontak', h1 Kontak + ContactForm)"
  compensating_action: "git rm -f 'src/app/(blank-layout-pages)/kontak/page.tsx'"
  idempotent: true
- step_id: step-6-run-tests
  step_type: test_command_run
  evidence: 'pnpm test:run src/features/contact/components/ContactForm/index.test.tsx -> Test Files 1 passed (1), Tests 9 passed (9); contact-scoped run -> 2 files / 22 tests passed; eslint + prettier + tsc clean on the five files'
  compensating_action: '(none — read-only verification, nothing to roll back)'
  idempotent: true
- step_id: step-7-commit
  step_type: git_commit
  evidence: 'single commit feat(U-006): Build the public Kontak page with the contact form, with Unit / SDD-PROVENANCE / SDD-Acceptance trailers'
  compensating_action: 'git revert --no-edit 37ff5ebf0ef1d947d04bab259bd273543507c1ed'
  idempotent: false
- step_id: step-8-tighten-label-queries
  step_type: git_commit
  evidence: "follow-up commit test(U-006): pin exact accessible names and assert required state in ContactForm tests — changes only index.test.tsx (getByRole textbox with exact names 'Nama'/'Email'/'Pesan', button 'Kirim', toBeRequired() x3) and this report. 9/9 pass, full suite 10 files / 73 tests pass, eslint + prettier clean. Same Unit / SDD-PROVENANCE / SDD-Acceptance trailers."
  compensating_action: "git revert --no-edit $(git log --format=%H -1 --grep='^test(U-006)')"
  idempotent: false
```
