---
id: U-014
title: Build the token reschedule page
context_source: context.md#F-U-004
prd_source: [PRD/prd-clinic.md:165, PRD/prd-clinic.md:166, PRD/prd-clinic.md:167, PRD/prd-clinic.md:192, PRD/prd-clinic.md:210]
task_type: create
grounding_confidence: LOW
risk: high
module: M-patient-self-service
depends_on: [U-003, U-009, U-012]
target_files:
  - path: src/features/appointments/components/RescheduleForm/index.tsx
    operation: create
  - path: src/features/appointments/components/RescheduleForm/index.test.tsx
    operation: create
  - path: src/app/(patient)/reschedule/[token]/page.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "shows the current appointment for the token"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "reschedules to the chosen free slot"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "shows an error when the token is invalid"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "announces the rescheduled confirmation in a status region"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "sends only startTime in the reschedule request body"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "hides the slot picker for a cancelled appointment"
  - type: test
    command: "pnpm test:run src/features/appointments/components/RescheduleForm/index.test.tsx --reporter=verbose"
    expects: "never renders the token value anywhere on the page"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-001, OQ-CLINIC-003, OQ-FL-1]
---

# Unit U-014 — Build the token reschedule page

## Anchors


- src/features/users/components/UserDetailDialog.tsx — loading / error / detail rendering of a single record via a query hook
- src/app/(dashboard)/users/[id]/page.tsx — dynamic-segment page reading its param

## Claims


- C-U014-01 "detail rendering with a query hook exists in the users feature" — expect: src/features/users/components/UserDetailDialog.tsx — must-exist
- C-U014-02 "the slot picker exists" — expect: src/features/appointments/components/SlotPicker/index.tsx — must-exist
- C-U014-03 "the status chip exists" — expect: src/features/appointments/components/AppointmentStatusChip/index.tsx — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/app/(patient)/reschedule/[token]/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST authorize only through the token from the URL and never ask the patient to log in (constitution B-002)
  Source: constitution.md §B B-002
- MUST offer only free slots of the same doctor through SlotPicker and the availability hook (source: PRD §Clinic.1 F-U-004 step 2)
  Source: PRD §Clinic.1 F-U-004 step 2
- MUST announce the rescheduled confirmation in a role status aria-live region (constitution F-001)
  Source: constitution.md §F F-001
- MUST NOT render the token itself anywhere on the page (constitution B-002)
  Source: constitution.md §B B-002

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `sends only startTime in the reschedule request body`: the captured PUT body is exactly { startTime } with no token, doctorId or id.
- Adversarial addition — `hides the slot picker for a cancelled appointment`: for a cancelled appointment the slot picker and confirm button are absent and a not-changeable message is shown.
- Adversarial addition — `never renders the token value anywhere on the page`: on both the valid-token and the invalid-token path the raw token string never appears in the document.
- TBD: OQ-CLINIC-003 — no reschedule window is enforced client-side.
- TBD: OQ-FL-1 — this page offers no cancel action until the cancel confirmation screen is decided.
- OQ-CLINIC-001 (P1, open): no regulation-specific behavior is invented.



---
# Lens context — framework pack `next` conventions
## File location standards

| Artifact | Path |
|---|---|
| App root layout | `app/layout.tsx` |
| Pages (App Router) | `app/**/page.tsx` |
| Layouts (App Router) | `app/**/layout.tsx` |
| Route Handlers (App Router) | `app/**/route.ts` |
| Loading UI | `app/**/loading.tsx` |
| Error UI | `app/**/error.tsx` |
| Not-found UI | `app/**/not-found.tsx` |
| Pages (Pages Router) | `pages/**/*.tsx` (legacy alternative to App Router) |
| API Routes (Pages Router) | `pages/api/**/*.ts` (legacy alternative to `app/**/route.ts`) |
| Shared components | `components/` |
| Utility / helper modules | `lib/` |
| Static assets | `public/` |
| Global middleware | `middleware.ts` (project root) |
| TypeScript config | `tsconfig.json` |
| Next.js config | `next.config.ts` / `next.config.mjs` |
| Environment variables | `.env.local`, `.env.production`, `.env` |
| Tests | `__tests__/` or co-located `*.test.tsx` / `*.spec.tsx` |
| End-to-end tests | `e2e/` or `tests/e2e/` (Playwright) |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Page file (App Router) | reserved name `page.tsx` | `app/dashboard/page.tsx` |
| Layout file (App Router) | reserved name `layout.tsx` | `app/(marketing)/layout.tsx` |
| Route Handler file | reserved name `route.ts` | `app/api/users/route.ts` |
| Special files | lowercase reserved names | `loading.tsx`, `error.tsx`, `not-found.tsx`, `template.tsx` |
| Route segment (folder) | kebab-case | `app/user-profile/page.tsx` |
| Route group (non-routing folder) | `(group-name)` — lowercase kebab in parens | `app/(auth)/login/page.tsx` |
| Dynamic segment | `[param]` or `[...slug]` (catch-all) | `app/posts/[id]/page.tsx` |
| Private folder (excluded from routing) | `_folder` prefix | `app/_components/` |
| Component filename | PascalCase `.tsx` | `components/UserCard.tsx` |
| Component name | PascalCase | `UserCard`, `NavBar` |
| Server Component | PascalCase, no directive (default) | `app/dashboard/page.tsx` |
| Client Component | PascalCase + `"use client"` directive at top | `components/Counter.tsx` |
| Hook | camelCase, `use` prefix | `useAuthSession`, `useCart` |
| Utility / helper | camelCase or kebab-case file | `lib/formatDate.ts`, `lib/auth-helpers.ts` |
| Type / interface | PascalCase | `UserProfile`, `ApiResponse<T>` |
| Environment variable | `NEXT_PUBLIC_` prefix for client-exposed; all-caps snake | `NEXT_PUBLIC_API_URL`, `DATABASE_URL` |

## Idioms (preferred patterns)

- **Server Components by default** — every component in `app/` is a React Server Component unless `"use client"` is declared; fetch data directly in RSC with `async/await` without client-side state
- **`"use client"` directive at the top of interactive components** — only mark components that need browser APIs, event listeners, or React state/effects as Client Components
- **`"use server"` for Server Actions** — co-locate or extract data-mutation logic in `async` functions marked `"use server"`; call them from forms or Client Components for server-side mutations without a separate API layer
- **Data fetching in Server Components** — prefer `fetch()` with Next.js extended caching options (`cache: 'force-cache'`, `next: { revalidate: N }`) over client-side `useEffect` fetching
- **Route Handlers for API endpoints** — define `GET`, `POST`, `PUT`, `DELETE`, `PATCH` named exports in `app/**/route.ts` for explicit HTTP API routes
- **Metadata API for SEO** — export a `metadata` object or `generateMetadata()` function from `page.tsx` / `layout.tsx` rather than using `<Head>` tags
- **Nested layouts for shared UI** — use nested `layout.tsx` files to share persistent UI across route segments without re-rendering
- **`next/image` for images** — always use the `<Image>` component from `next/image` for automatic optimization, lazy loading, and responsive sizes
- **`next/link` for navigation** — use `<Link>` from `next/link` for client-side navigation; avoid raw `<a>` for internal routes
- **`next/font` for fonts** — use the built-in font optimization module instead of manual `@font-face` or CDN font links
- **Parallel and Intercepting Routes** — use `@slot` and `(.)route` conventions for advanced routing patterns like modals and parallel dashboards
- **Server Actions for form mutations** — prefer `action={serverAction}` on `<form>` elements over manual POST fetch calls
- **Middleware for edge-level logic** — use `middleware.ts` for auth redirects, locale detection, header injection; keep it lightweight (runs at the Edge)

# Lens context — project conventions (CLAUDE.md is authoritative; read it at the repo root)
