---
id: U-018
title: Build the walk-in appointment dialog with emergency override
context_source: context.md#F-S-002
prd_source: [PRD/prd-clinic.md:178, PRD/prd-clinic.md:179]
task_type: create
grounding_confidence: LOW
risk: high
module: M-staff
depends_on: [U-001, U-009, U-012]
target_files:
  - path: src/features/appointments/components/WalkInDialog/index.tsx
    operation: create
  - path: src/features/appointments/components/WalkInDialog/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "creates a walk-in appointment with the staff channel"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "allows a time outside the slot grid only with the emergency override"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "validates patient details before submitting"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "keeps the dialog open and shows an error message when appointment creation fails"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "does not call the create appointment endpoint when patient details are invalid"
  - type: test
    command: "pnpm test:run src/features/appointments/components/WalkInDialog/index.test.tsx --reporter=verbose"
    expects: "resets the selected time when the emergency override switch is turned off"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-001]
---

# Unit U-018 — Build the walk-in appointment dialog with emergency override

## Anchors


- src/features/users/components/UserFormDialog.tsx — MUI dialog + react-hook-form + zodResolver pattern
- src/@core/components/mui/TextField.tsx — `CustomTextField` for labelled inputs

## Claims


- C-U018-01 "the project wires dialog forms with react-hook-form" — expect: src/features/users/components/UserFormDialog.tsx — must-exist
- C-U018-02 "the slot picker exists" — expect: src/features/appointments/components/SlotPicker/index.tsx — must-exist
- C-U018-03 "the booking schema module exists" — expect: src/features/appointments/schemas/booking/index.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/components/WalkInDialog/index.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST send bookingChannel staff for every appointment created from this dialog (constitution C-006)
  Source: constitution.md §C C-006
- MUST offer a free time outside the slot grid only while the emergency override switch is on (source: PRD §Clinic.1 F-S-002 step 4)
  Source: PRD §Clinic.1 F-S-002 step 4
- MUST validate patient details with walkInSchema before submitting and show errors as text (constitution B-001)
  Source: constitution.md §B B-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `keeps the dialog open and shows an error message when appointment creation fails`: with a failing POST /api/v1/appointments, onClose is not called and the error text is rendered in the dialog.
- Adversarial addition — `does not call the create appointment endpoint when patient details are invalid`: submitting with a blank or invalid name, email or reason sends no request to the appointments route.
- Adversarial addition — `resets the selected time when the emergency override switch is turned off`: after entering an off-grid time with override on, switching it off clears the time so it cannot be submitted with override false.
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
