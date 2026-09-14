---
unit: U-005
status: success
attempted_at: 2026-09-14T10:28:00Z   # approx: TDD red run at 17:29:35 local (+0700) minus orientation time
completed_at: 2026-09-14T10:33:06Z
commits: [8f149e078641c76a86aaa0fbf984a498b27dd254]
files_touched:
  - src/features/contact/repositories/contact.repository.ts
  - src/features/contact/hooks/useContact.ts
  - src/features/contact/components/ContactForm/index.tsx
  - src/features/contact/components/ContactForm/index.test.tsx
  - src/app/(blank-layout-pages)/kontak/page.tsx
tests_run: ["pnpm test:run src/features/contact/components/ContactForm", "pnpm test:run"]
test_results: "acceptance 8/8 passed; full suite 8 files / 61 tests passed at bolt time"
retries: 0
model_routed: inherit
target_hashes:
  src/features/contact/repositories/contact.repository.ts: 57b44f2c178db8a9af8daece03f15ae103d0a0de1066fc993fc3879fd70e0e12
  src/features/contact/hooks/useContact.ts: 563acfc59e8e40773cc36dfa2b3539bdda02206f112a27cf2c72a6dc0350693d
  src/features/contact/components/ContactForm/index.tsx: 6869762b339cf9918edd98a31c370cef5f13c5e8d44abee9f05208bdccc50f2c
  src/features/contact/components/ContactForm/index.test.tsx: f9792d748f8da6ffd3365909329e543f5a8e9963900ff81eb4ed809dec41aaf5
  src/app/(blank-layout-pages)/kontak/page.tsx: 998695ece7bbaf1fd2bb51c78ba42c00ab6ee89f5c1a09769da21d89238c76f9
---

# Bolt report — U-005 "Buat Halaman Kontak dengan form kirim pesan"

**Status:** DONE_WITH_CONCERNS
**Commit:** 8f149e078641c76a86aaa0fbf984a498b27dd254 — `feat(U-005): Buat Halaman Kontak dengan form kirim pesan` (trailers: `Unit: U-005`, `SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-005`, `SDD-Acceptance: v5`). A sibling bolt (`docs(U-002): bolt report`, 1096995) landed on top afterwards; it touches none of this unit's paths.

## What was implemented

- `src/features/contact/repositories/contact.repository.ts`: `sendContactMessage(body: ContactFormValues)` → `apiClient.post<IContactMessage>('/v1/contact-messages', body)`. Follows the `createUser` line of the user repository and returns the raw envelope.
- `src/features/contact/hooks/useContact.ts`: `'use client'`, `useSendContactMessage()` = a bare `useMutation({ mutationFn: sendContactMessage })`. It has no snackbar, because the unit wants the outcome inline on the page, and no invalidation, because there is no contact query to refresh.
- `src/features/contact/components/ContactForm/index.tsx`: `'use client'` form built on react-hook-form + `zodResolver(contactFormSchema)` (U-004 schema, imported and not modified), with `contactFormDefaults`.
  - **Fields.** Name, email and message use `CustomTextField` (the blank-layout-page idiom, with the label always visible above the input). Each has an explicit id and label, `required` (asterisk plus the attribute) and `autoComplete` where it applies.
  - **Message field.** The message is multiline and shows a `n/2000 karakter` counter that turns into the error text when invalid.
  - **Validation.** The `<form>` has `noValidate`, so the Indonesian zod messages appear instead of native browser bubbles. Field errors link to the input through MUI's `aria-describedby`/`aria-invalid`, and RHF focuses the first invalid field.
  - **Submit outcomes.**
    - Success shows `<Alert severity='success'>Pesan terkirim</Alert>`.
    - A server rejection shows `<Alert severity='error'>{error.message}</Alert>`. Both use MUI's `role="alert"` and have a text plus icon, not colour alone.
    - A new client-side validation failure clears any earlier outcome (`mutation.reset()`).
  - **No reset.** The form is never reset, neither after a rejection nor after success (OQ-FL-1 is deferred).
  - **Submit button.** "Kirim" uses MUI's `loading` state while pending (loading feedback).
  - **Rendering visitor data.** Visitor data is rendered only as React text; `dangerouslySetInnerHTML` is not used anywhere.
- `src/app/(blank-layout-pages)/kontak/page.tsx`: a server component with `metadata` (`title: 'Kontak'`).
  - **Shell.** It uses the same page shell as the sibling Beranda page (`max-is-[1200px] mli-auto p-6 sm:p-10 md:p-12`), a "Kembali ke Beranda" link with a visible focus ring, and a responsive two-column grid (stacked below `md`).
  - **Left column.** An icon badge, the `h1` "Hubungi Kami", an intro, and field guidance built from the schema's `CONTACT_*_MAX` constants, so the limits never drift from validation.
  - **Right column.** A `Card` section titled "Kirim Pesan" that holds `<ContactForm />`.
  - **Styling.** It uses only theme tokens (`text-primary`, `bg-primaryLighter`, `color='text.secondary'`) and no invented palette.

## Tests

- **TDD red:** I wrote the test first. The first run failed because the component did not exist yet: vite `import-analysis` could not resolve `import ContactForm from "."` at `index.test.tsx:19:24` (`Test Files 1 failed`, `Tests no tests`).
- **Acceptance:** `pnpm test:run src/features/contact/components/ContactForm` → **8 passed (8)**. Cases:
  1. All three fields and the "Kirim" button are reachable by label (`getByLabelText`); the message field is a `<textarea>`.
  2. **Invalid email.** "Format email tidak valid" appears, and the email input is `aria-invalid` with that text as its accessible description. Name and message are not invalid and keep their values, the email keeps `bukan-email`, and **0 requests** are sent (MSW `vi.fn` counter).
  3. **Empty submit.** All three "… wajib diisi" messages appear, with 0 requests.
  4. **Valid submit.** The POST body is exactly `{name,email,message}`, "Pesan terkirim" appears as the only `role=alert`, and **all three fields keep their values after success** (this pins the deferred OQ-FL-1 "don't clear").
  5. Padded name and message are sent trimmed (zodResolver output).
  6. **Server 400** (`VALIDATION_ERROR` envelope). The error alert shows "Periksa kembali isian form", there is no success text, and all fields stay filled.
  7. A server message containing `<img src=x onerror=…>` is rendered as literal text and no `<img>` is created (B-001).
  8. **Keyboard only.** Tab moves Name → Email → Message → Kirim, typing works via the keyboard, and Enter on the button submits and shows "Pesan terkirim" (A-004).
- **Mutation check:** I temporarily injected `resetForm(contactFormDefaults)` on success. Test 4 failed at `expect(name).toHaveValue('Budi Santoso')`. The file was restored byte-identical (`cmp` passed) before the commit.
- **Full suite:** `pnpm test:run` → 8 files, **61 passed**.
- **Lint and format:** `eslint` is clean on all 5 files (after `eslint --fix` reordered the `next` imports in page.tsx), and `prettier --check` is clean.
- **Typecheck:** `tsc --noEmit` shows no errors in this unit's files. The only remaining errors are TS2307 in the generated `.next/**/validator.ts` for the not-yet-built `tentang-kami` page (U-003); the `kontak` stub error is cleared by this unit.
- **Manual acceptance** ("Buka /kontak, isi form hanya dengan keyboard…"): **not executed in a real browser by this bolt.** Test 8 exercises the same keyboard path under jsdom and RTL, but a real-browser check (focus ring, `next dev`, upstream reachable) is still with the controller or a human.

## Hard rules honored

- DO NOT add new package.json dependencies: honored, `package.json`/lockfile untouched. I used only msw, vitest, RTL, MUI, react-hook-form, `@hookform/resolvers`, zod and TanStack Query, all already installed.
- DO NOT modify src/libs/api/client.ts: honored, untouched (it is imported by the repository only).
- DO NOT modify src/features/contact/schemas/contact.schema.ts: honored, untouched (imported only).
- file src/features/contact/components/ContactForm/index.test.tsx MUST exist after bolt: honored, created and committed in 8f149e0.
- NEVER render visitor input through dangerouslySetInnerHTML: honored. `dangerouslySetInnerHTML` appears in none of the 5 files, and test 7 asserts that markup renders as text.
- MUST give every form field a visible label and keep the form operable by keyboard: honored. Labels are always visible, since `CustomTextField` forces `shrink: true` and places the label above the input. Tab order matches visual order and Enter submits (tests 1 and 8).
- Framework pack naming rule: the route file is `page.tsx`.
- Also not modified (outside scope): `src/test/handlers.ts` (contact endpoints are registered per-test via `server.use`), `src/test/setup.ts`, `vitest.config.ts`, `src/features/contact/types/index.ts`, and the navigation menu files. `/kontak` is a public blank-layout page, not a dashboard page.

## reuse_decisions

```yaml
reuse_decisions:
  - candidate: "reuse-index.yaml (Iron Rule 4b full scan)"
    decision: not_applicable
    reason: "The file is absent at .mega-sdd/codebase/reuse-index.yaml (recorded in the dispatch PROVENANCE omissions), so the full-index scan could not be run. As a substitute I grepped .mega-sdd/codebase/symbol-index.json for Form/Alert/Layout/Card/Mutation/contact symbols. Only per-feature forms (ProfileForm, *FormDialog) and the CRUD mutation factories exist, and none is a contact form."
  - candidate: "src/libs/api/client.ts:apiClient"
    decision: reused
  - candidate: "src/features/users/repositories/user.repository.ts:createUser (repository pattern)"
    decision: reused
    reason: "Pattern followed: one-line apiClient.post returning the raw envelope."
  - candidate: "src/libs/api/crud-hooks.ts:makeCreateMutation"
    decision: not_applicable
    reason: "It raises an enqueueSnackbar on success/error and requires a listKey to invalidate. The unit requires the success message inline on the same page, not a snackbar, and there is no contact list query to invalidate."
  - candidate: "src/libs/query-keys:createQueryKeys"
    decision: not_applicable
    reason: "The contact feature has no queries, so there are no cache keys to build."
  - candidate: "src/features/contact/schemas/contact.schema.ts (contactFormSchema, contactFormDefaults, ContactFormValues, CONTACT_MESSAGE_MAX, CONTACT_NAME_MAX)"
    decision: reused
    reason: "Same schema as the server route, so client field errors match the server's Indonesian messages. The limits in the page guidance and the message counter come from the constants."
  - candidate: "src/features/contact/types:IContactMessage"
    decision: reused
  - candidate: "src/features/contact/types:TContactFieldErrors"
    decision: not_applicable
    reason: "apiClient's onError (client.ts:13-17) throws new Error(body.message) and discards the envelope's data.fieldErrors, so the per-field map is unreachable from the browser. Hard rules forbid modifying client.ts. Per-field errors come from the client-side zodResolver (same schema); a server rejection surfaces as one error Alert. This answers U-004's concern #5."
  - candidate: "src/@core/components/mui/TextField (CustomTextField)"
    decision: reused
    reason: "The idiom of the blank-layout views (Login/Register). Its label always sits visibly above the input."
  - candidate: "src/features/profile/components/ProfileForm.tsx (full-page RHF + Alert + loading Button pattern)"
    decision: reused
    reason: "Pattern followed: Controller + zodResolver, top-of-form Alert, Button `loading`."
  - candidate: "src/test/utils.tsx:renderWithProviders, src/test/handlers.ts:server"
    decision: reused
  - candidate: "notistack enqueueSnackbar (project notification idiom)"
    decision: not_applicable
    reason: "The unit's Implementation step 1 explicitly calls for inline success instead of a snackbar. MUI Alert is used for inline feedback; there is no native alert()."
```

## Provenance trailer notes

- The trailer is present in all 5 created files, with the version `7.37.0` taken from the dispatch Contracts line ("mega-sdd v7.37.0") and the unit's vault sha256 `5a6df0df…41e2`. `Anchors consulted:` lists the 4 anchors, and `Hard Rules active:` lists the six rule texts verbatim.
- **The `Implements claim:` line is OMITTED.** The Provenance values block says `claims: (none cited)`. The unit body lists C-U005-01..04, but the block is the only permitted source, so I did not add them.
- In the two `'use client'` files the comment trailer sits above the directive, which is legal (comments don't count as statements). Lint and the test run confirm the directive is still honored.

## Concerns

1. **Server-side per-field errors are flattened.** Because `apiClient` keeps only `message`, a server 400 shows the single "Periksa kembali isian form" alert and does not highlight fields. In practice the client runs the identical schema first, so a server field rejection only happens if the two diverge. Surfacing `fieldErrors` would need a unit that owns `src/libs/api/client.ts` (for example, attaching the parsed body to the thrown Error).
2. **The manual acceptance item was not run in a real browser** (see Tests). jsdom covers the tab order and Enter-submit, but not the visual focus ring or live `next dev` routing through `src/proxy.ts`.
3. **The upstream contract is assumed.** `POST /v1/contact-messages` and an anonymous caller being accepted upstream are runner-assumed (OQ-AR-1). The MSW mocks encode U-004's envelope shape, not a verified upstream.
4. **OQ-FL-1 (clear after success) is deferred.** The form deliberately keeps its values after "Pesan terkirim", so a second click on Kirim sends a duplicate. Test 4 pins the current behaviour and must be updated if the product decides to clear.
5. **No design system in the vault.** The page uses template theme tokens only, as instructed (raise-an-OQ note in the dispatch). The design slice in the dispatch was truncated (Severity:High rows plus lead clauses only), so the design-quality confidence is MEDIUM.
6. **The "Kembali ke Beranda" link targets `/beranda`**, which sibling U-002 landed in 67d0b24 (OQ-AR-2 paths).

## Self-assessment

```yaml
bolt_self_report:
  model_used: "Opus 5"
  confidence: 0.85
  certain_decisions:
    - "Per-field errors come from zodResolver(contactFormSchema). An invalid email shows 'Format email tidak valid' on the email field, keeps the other values, and sends no request (MSW counter asserts 0)."
    - "The form is never reset: values are kept after a server 400 and after success (a mutation check proves the success-path assertion catches a reset)."
    - "Data flow is page -> useSendContactMessage (useMutation) -> sendContactMessage -> apiClient.post('/v1/contact-messages') -> same-origin proxy. There is no apiServer in client code."
    - "Every field has a visible label, the tab order is Nama -> Email -> Pesan -> Kirim, and Enter on Kirim submits."
    - "No dangerouslySetInnerHTML; a server message containing markup renders as text."
  uncertain_decisions:
    - decision: "A server rejection is shown as one error Alert with the server's message and is not mapped onto fields."
      rationale: "apiClient discards data.fieldErrors and client.ts is off-limits; the unit step 2 says 'penolakan server → alert error'."
      fallback_if_wrong: "In a unit that owns client.ts, attach the parsed error body to the thrown Error, then setError() per field from TContactFieldErrors."
    - decision: "A client-side validation failure calls mutation.reset(), which hides an earlier 'Pesan terkirim' or error alert."
      rationale: "Prevents a stale success banner from sitting above fresh field errors. The spec is silent on this."
      fallback_if_wrong: "Remove the onInvalid handler so earlier outcomes persist until the next successful request."
    - decision: "No maxLength attribute on inputs; the over-limit case is reported by the schema error instead."
      rationale: "PRD asks for error per field; a hard maxLength would silently truncate pasted text with no feedback. The message field shows a live n/2000 counter."
      fallback_if_wrong: "Add slotProps.htmlInput.maxLength from the CONTACT_*_MAX constants."
    - decision: "Page copy (heading 'Hubungi Kami', intro, guidance) was written in Indonesian without organisation details."
      rationale: "The organisation name lives in U-002's config, which is not a declared dependency of this unit. Importing it would couple to a sibling not listed in depends_on."
      fallback_if_wrong: "Import the organisation name from src/configs/companyProfile.ts (now landed) into the page heading or intro."
  acceptance_test_concern: "The unit's listed cases only covered invalid email, valid → 'Pesan terkirim', and 400 → fields kept. I added assertions for: values kept after success (OQ-FL-1 pin, mutation-verified), exact POST body plus trimming, required-field messages, aria-invalid plus accessible description on the email field, markup-as-text for server messages (B-001), and keyboard-only tab order plus Enter submit (A-004). Still untested: real-browser focus visibility and the live proxy/upstream round trip (OQ-AR-1); the loading state while pending is not asserted."
  retry_history:
    - attempt: 1
      failure: "vite:import-analysis — index.test.tsx:19:24 `import ContactForm from \".\"` could not be resolved; Test Files 1 failed, Tests no tests (intended TDD red)"
      fix: "Implemented contact.repository.ts, useContact.ts, ContactForm/index.tsx and kontak/page.tsx"
    - attempt: 2
      failure: "ESLint: 2 errors — import/order (2x) in src/app/(blank-layout-pages)/kontak/page.tsx"
      fix: "eslint --fix (moved the value import of next/link before the type import of next); eslint and prettier re-checked clean"
```

## Rollback hints

```yaml
- step_id: step-1-test
  step_type: file_created
  evidence: "created src/features/contact/components/ContactForm/index.test.tsx (222 lines)"
  compensating_action: "git rm -f src/features/contact/components/ContactForm/index.test.tsx"
  idempotent: true
- step_id: step-2-repository
  step_type: file_created
  evidence: "created src/features/contact/repositories/contact.repository.ts (22 lines)"
  compensating_action: "git rm -f src/features/contact/repositories/contact.repository.ts"
  idempotent: true
- step_id: step-3-hook
  step_type: file_created
  evidence: "created src/features/contact/hooks/useContact.ts (26 lines)"
  compensating_action: "git rm -f src/features/contact/hooks/useContact.ts"
  idempotent: true
- step_id: step-4-component
  step_type: file_created
  evidence: "created src/features/contact/components/ContactForm/index.tsx (141 lines)"
  compensating_action: "git rm -f src/features/contact/components/ContactForm/index.tsx"
  idempotent: true
- step_id: step-5-page
  step_type: file_created
  evidence: "created src/app/(blank-layout-pages)/kontak/page.tsx (95 lines)"
  compensating_action: "git rm -f 'src/app/(blank-layout-pages)/kontak/page.tsx'"
  idempotent: true
- step_id: step-6-tests
  step_type: test_command_run
  evidence: "pnpm test:run src/features/contact/components/ContactForm → 8 passed; pnpm test:run → 61 passed"
  compensating_action: "(none — read-only)"
  idempotent: true
- step_id: step-7-commit
  step_type: git_commit
  evidence: "8f149e078641c76a86aaa0fbf984a498b27dd254 feat(U-005): Buat Halaman Kontak dengan form kirim pesan"
  compensating_action: "git revert --no-edit 8f149e078641c76a86aaa0fbf984a498b27dd254"
  idempotent: false
- step_id: step-8-report-commit
  step_type: git_commit
  evidence: "follow-up commit 'docs(U-005): bolt report' adding only this file (U-004 precedent)"
  compensating_action: "git rm -f .mega-sdd/vaults/company-profile/bolts/U-005/bolt-report.md && git commit -m 'revert U-005 bolt report'"
  idempotent: false
```
