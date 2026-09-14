---
unit: U-002
status: success
attempted_at: 2026-09-14T10:27:00Z   # approximate: TDD red run 17:28 local (+07:00) minus reading time
duration_seconds: ~300
commits: [67d0b2430f7401d9d37c3b7e7ee0eb2e25ad702f]
files_touched: [src/configs/companyProfile.ts, src/views/company-profile/Beranda/index.tsx, src/views/company-profile/Beranda/index.test.tsx, "src/app/(blank-layout-pages)/beranda/page.tsx"]
tests_run: ["pnpm test:run src/views/company-profile/Beranda", "pnpm test:run"]
test_results: "acceptance 4/4 passed; full suite 53/53 tests passed, 1 file failed to load (sibling U-005 in-flight TDD red, not this unit)"
retries: 0
target_hashes:
  src/configs/companyProfile.ts: 41582704b6fb6fcdb7044c79d10afe4f4ccd77e080ccacafa9b535c6b73ad7f8
  src/views/company-profile/Beranda/index.tsx: 895f4ee57f9778b50bbaa0cab9714222246c4c56fd36a6b12d21c7b03946565d
  src/views/company-profile/Beranda/index.test.tsx: 09375d0dbc214f7aa9a058ac74156abf3fd93b7a80834b5eb640212ab775ad5e
  "src/app/(blank-layout-pages)/beranda/page.tsx": 39d22e201cc46f5cc4273e4287e2aa493b3386c0f6c5aa50fcccd9eb70394c45
---

# Bolt report — U-002 "Buat konfigurasi konten profil dan Halaman Beranda"

**Status:** DONE_WITH_CONCERNS
**Commit:** 67d0b2430f7401d9d37c3b7e7ee0eb2e25ad702f — `feat(U-002): Buat konfigurasi konten profil dan Halaman Beranda` (trailers: `Unit: U-002`, `SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-002`, `SDD-Acceptance: v5`)

## What was implemented

- `src/configs/companyProfile.ts`: typed placeholder content, following the `themeConfig` default-export pattern in `src/configs/`. It exports the types `CompanyService`, `TeamMember` and `CompanyProfile`, plus a default `companyProfile` with these fields:
  - `name` and `tagline` (one sentence).
  - `services`: typed as a **3-tuple** of `{ title, description }`, so the compiler enforces "exactly three".
  - `profileParagraphs`: typed `readonly [string, string, string?]`, so it must hold 2–3 paragraphs. It ships 3.
  - `team`: `readonly { name, role }[]` with no photo field. It ships 4 members.
  - The file also carries U-003's content (profile paragraphs and team) because U-003 has a Hard rule that forbids it from modifying this file.
- `src/views/company-profile/Beranda/index.tsx`: a `'use client'` view. It follows the Register.tsx anchor's shape (MUI plus `next/link`) but uses none of its context hooks (Logo, useSettings, useImageVariant), because the test harness only provides Query and Snackbar.
  - **Page shell:** a centred, padded `<main>` with `max-is-[1200px] mli-auto p-6 sm:p-10 md:p-12`.
  - **Hero:** a section tinted with the primary token (`--mui-palette-primary-lighterOpacity`). It holds a CustomAvatar icon, the org name as `h1`, the tagline, and a contained `Button component={Link} href='/kontak'` labelled "Hubungi Kami" with a decorative arrow.
  - **"Layanan Kami" section:** an `h2`, then a `Grid container spacing={6}` rendered as `ul role='list'` (named by the h2) with three `li` items at `size={{ xs: 12, md: 4 }}`. That gives one column at 375px and three side by side from `md` up.
  - **Service cards:** each card shows a CustomAvatar tabler icon, the service title as `h3`, and its description.
  - The icon and colour for each slot are presentational, held in the view as a 3-tuple, so the config shape stays exactly `{ title, description }` as the spec says.
  - Every icon is `aria-hidden`. There are no images.
- `src/app/(blank-layout-pages)/beranda/page.tsx`: a thin page that exports `metadata` (`title: 'Beranda | <name>'`, `description: <tagline>`) and renders `<Beranda />`. It drops Register's `async`/`getServerMode()` plumbing, which only exists to feed an illustration this page doesn't have.
- `src/views/company-profile/Beranda/index.test.tsx`: 4 tests. Every assertion uses values imported from the config.

## Tests

- **TDD:** the test was written first. Its pre-implementation run failed for the right reason: `Failed to resolve import "./index" from "src/views/company-profile/Beranda/index.test.tsx"` (the view and config didn't exist yet).
- **Acceptance:** `pnpm test:run src/views/company-profile/Beranda` → **4 passed (4)**. It was re-run and passed again right before the commit, chained with `&&` so the commit could only land on green.
- **Cases:**
  - An `h1` heading named after `companyProfile.name`.
  - The tagline text.
  - The list named "Layanan Kami" has **exactly 3** `listitem`s, and each one contains its config service's title as an `h3` plus its description (in order).
  - A link named /hubungi kami/i with `href='/kontak'`.
- **Mutation check:** I changed `href='/kontak'` to `href='/salah'`. Only the `/kontak` test failed (1 failed, 3 passed). The file was then restored and `cmp` confirmed it byte-identical.
- **Full suite:** `pnpm test:run` → 53/53 tests passed across 7 files. One file failed to load: `src/features/contact/components/ContactForm/index.test.tsx` (`Failed to resolve import "."`). That file belongs to sibling **U-005**, which was in flight in the same tree during its own TDD red. U-002 did not touch it.
- **Gates run locally on the 4 files:**
  - `prettier --check`: clean.
  - `eslint`: clean.
  - `tsc --noEmit` (project-wide): no errors in U-002 files. Of the 5 errors, 4 are stale `.next/**/validator.ts` stubs for the unbuilt `kontak` and `tentang-kami` pages, and 1 is U-005's in-flight test file.
- **Icons:** `tabler-bulb`, `tabler-tools`, `tabler-school`, `tabler-building-community` and `tabler-arrow-right` are all confirmed present in `@iconify/json/json/tabler.json`. That file is bundled in full, so no `build:icons` rerun is needed.

## Hard rules honored

- **DO NOT add new package.json dependencies:** honored. `package.json` and the lockfile are untouched. The code uses only MUI, next, classnames and existing `@core` components.
- **file src/views/company-profile/Beranda/index.test.tsx MUST exist after bolt:** honored. It was created and committed in 67d0b24.
- **ALWAYS keep the Beranda view test inside its view folder:** honored. The test lives at `Beranda/index.test.tsx` next to `Beranda/index.tsx`, per the constitution's rule on co-locating a module with its test. The config has no test, so it stays flat.
- **Framework pack rules:**
  - The page file is named `page.tsx`.
  - `'use client'` is the first non-comment line of the view. The provenance comment block sits above it.
  - No secrets or env vars are used.
  - No data mutation.

## reuse_decisions

```yaml
reuse_decisions:
  - candidate: "reuse-index.yaml (Iron Rule 4b full scan)"
    decision: not_applicable
    reason: "Absent at .mega-sdd/codebase/reuse-index.yaml (recorded in the dispatch PROVENANCE omissions), so the full-index scan could not run. As a substitute I grepped .mega-sdd/codebase/symbol-index.json for Card/Hero/Section/Avatar/Link/profile symbols. Hits: CustomAvatar, HorizontalWithSubtitle, components/Link and the features/profile (user-account) module. None is a content config or a public landing section."
  - candidate: "src/@core/components/mui/Avatar.tsx (CustomAvatar)"
    decision: reused
    reason: "Icon tiles for the hero and the service cards use the house tonal-avatar idiom (skin='light' / 'filled'), with no hand-rolled colour styling."
  - candidate: "src/components/card-statistics/HorizontalWithSubtitle.tsx"
    decision: not_applicable
    reason: "It is a numeric statistics card (formatNumber(stats)) with no description body. Its Card + CustomAvatar + classnames(icon) composition was followed instead."
  - candidate: "src/components/layout/shared/Logo.tsx"
    decision: not_applicable
    reason: "It needs the VerticalNav and Settings contexts (absent from renderWithProviders) and renders themeConfig.templateName ('Starter Kit'), which would conflict with the organisation name."
  - candidate: "src/components/Link.tsx"
    decision: not_applicable
    reason: "The anchor (Register.tsx) uses next/link directly, and the CTA always has an href, so the wrapper's no-href preventDefault branch adds nothing."
  - candidate: "src/configs/themeConfig.ts (typed config + default export pattern)"
    decision: reused
    reason: "companyProfile.ts mirrors its shape: exported type plus a typed const as the default export."
  - candidate: "src/test/utils.tsx:renderWithProviders"
    decision: reused
  - candidate: "MUI Grid size={{ xs, md }} (house responsive pattern, e.g. src/app/(dashboard)/profile/page.tsx)"
    decision: reused
```

## Provenance trailer notes

- The trailer is present in all 4 committed files. It starts with the `Generated by mega-sdd execute-bolts 7.37.0` marker (the version comes from the dispatch Contracts line, "mega-sdd v7.37.0"). It also carries the unit id with the vault sha256, the 2 anchors, and the 3 hard-rule texts verbatim.
- **The `Implements claim:` line is OMITTED** because the Provenance values block says `claims: (none cited)`. I did not derive a claim id myself.
- No `C-*`/`F-*`/`OQ-*` id appears in any code comment.

## Self-assessment

```yaml
bolt_self_report:
  model_used: "Opus 5"
  confidence: 0.85
  certain_decisions:
    - "Content lives in src/configs/companyProfile.ts. 'Exactly three services' and '2–3 paragraphs' are enforced by tuple types, not by convention."
    - "U-003's content (profile paragraphs and a photo-less team) ships in this bolt, because U-003 is forbidden to modify the config."
    - "Heading outline: h1 org name, h2 'Layanan Kami', h3 per service. The CTA is a real link to /kontak with a text label."
    - "The view uses no Settings or VerticalNav context, so it renders under the minimal test harness and the blank layout alike."
  uncertain_decisions:
    - decision: "The config field for the profile paragraphs is named `profileParagraphs`."
      rationale: "The spec says 'dua–tiga paragraf profil' but names no field, and a bare `profile` would read like a nested object. U-003 will consume whatever name ships here and cannot rename it."
      fallback_if_wrong: "Rename it in a follow-up unit that owns companyProfile.ts. U-003 is the only other consumer."
    - decision: "The icon and accent colour for each service are presentational, held in the view and indexed by the 3-tuple position rather than stored in the config."
      rationale: "The spec fixes the service shape to { title, description }. Adding an icon key would widen the content contract beyond the spec."
      fallback_if_wrong: "Add an optional `icon` field to CompanyService and read it in the view."
    - decision: "Placeholder copy is realistic Indonesian ('Unit Kerja Nusantara', four named team members) rather than literal 'Lorem' or 'Nama Organisasi' text."
      rationale: "The PRD says the content is a placeholder that the team replaces. Realistic copy lets reviewers judge the layout, and the file header states the values are placeholders."
      fallback_if_wrong: "Swap in obviously generic strings. Only the config file changes."
    - decision: "The service list is a Grid rendered as ul/li with an explicit role='list' and aria-labelledby pointing to the section h2."
      rationale: "It gives list semantics and an accessible name (and the test asserts the count through them). The explicit role keeps Safari/VoiceOver from dropping list semantics when list-style is removed."
      fallback_if_wrong: "Render the Grid as div and assert the count via the h3 headings instead."
  acceptance_test_concern: "The unit's test asserts content presence and the /kontak href only. My test adds a check for exactly 3 list items and for heading levels, but it cannot see responsiveness: the one-column-at-375px vs. side-by-side-on-desktop layout is CSS (Grid size breakpoints), and jsdom does no layout. That part rests on the manual acceptance entry. Proposed extra assertions: (1) a snapshot-free check that each service Grid item carries the md-4 / xs-12 Grid classes; (2) a Playwright viewport check at 375px asserting scrollWidth <= clientWidth. Confidence for responsive behaviour is MEDIUM."
  retry_history:
    - attempt: 1
      failure: "Failed to resolve import \"./index\" from \"src/views/company-profile/Beranda/index.test.tsx\". Does the file exist? (intended TDD red)"
      fix: "Implemented companyProfile.ts, Beranda/index.tsx and the page; the re-run gave 4/4 passed"
```

## Concerns

1. **No design system in the vault (open question to raise).** vault.json carries no `design_system`, so I invented no palette or type pairing. The page uses only the Vuexy MUI theme tokens (`--mui-palette-primary-*`, `text.secondary`, the theme typography variants, CustomAvatar skins) and the repo's logical-property Tailwind classes. A design-system decision should be raised as an OQ at chain end.
2. **The manual acceptance entry was not executed here.** It asks for /beranda to be checked at 375px and on desktop with no horizontal scroll, and for the Kontak button to lead to /kontak. There is no browser in this session. Responsive behaviour comes from the Grid breakpoints (`xs: 12, md: 4`), the fluid padding and `break-words` on the h1, but it is unverified visually. `/kontak` itself is built by U-005, so until it lands the CTA leads to a 404.
3. **The full suite is red only because of a sibling.** `src/features/contact/components/ContactForm/index.test.tsx` (U-005, in flight) fails to load because its component doesn't exist yet. It is not U-002 code, and it should clear when U-005 commits its component.
4. **Anti-context `DO NOT WRITE` is not applicable.** All six items are database-schema patterns, and this unit writes no DDL or persistence.
5. **The blank layout has no site navigation.** /beranda has no header or footer nav linking to /tentang-kami. The PRD asks only for the Kontak button on Beranda (Tentang Kami links back to Beranda itself), so I added no nav. A shared public header could come in a later unit.

## Rollback hints

```yaml
- step_id: step-1-test
  step_type: file_created
  evidence: "created src/views/company-profile/Beranda/index.test.tsx (51 lines)"
  compensating_action: "git rm -f src/views/company-profile/Beranda/index.test.tsx"
  idempotent: true
- step_id: step-2-config
  step_type: file_created
  evidence: "created src/configs/companyProfile.ts (67 lines)"
  compensating_action: "git rm -f src/configs/companyProfile.ts"
  idempotent: true
- step_id: step-3-view
  step_type: file_created
  evidence: "created src/views/company-profile/Beranda/index.tsx (117 lines)"
  compensating_action: "git rm -f src/views/company-profile/Beranda/index.tsx"
  idempotent: true
- step_id: step-4-page
  step_type: file_created
  evidence: "created src/app/(blank-layout-pages)/beranda/page.tsx (27 lines)"
  compensating_action: "git rm -f 'src/app/(blank-layout-pages)/beranda/page.tsx'"
  idempotent: true
- step_id: step-5-tests
  step_type: test_command_run
  evidence: "pnpm test:run src/views/company-profile/Beranda → 4 passed; pnpm test:run → 53/53 tests (1 sibling U-005 file failed to load)"
  compensating_action: "(none — read-only)"
  idempotent: true
- step_id: step-6-commit
  step_type: git_commit
  evidence: "67d0b2430f7401d9d37c3b7e7ee0eb2e25ad702f feat(U-002): Buat konfigurasi konten profil dan Halaman Beranda"
  compensating_action: "git revert --no-edit 67d0b2430f7401d9d37c3b7e7ee0eb2e25ad702f"
  idempotent: false
- step_id: step-7-report-commit
  step_type: git_commit
  evidence: "follow-up commit 'docs(U-002): bolt report' adding only this file (U-004 precedent; --amend is denied by the wave rail)"
  compensating_action: "git rm -f .mega-sdd/vaults/company-profile/bolts/U-002/bolt-report.md && git commit -m 'revert U-002 bolt report'"
  idempotent: false
```
