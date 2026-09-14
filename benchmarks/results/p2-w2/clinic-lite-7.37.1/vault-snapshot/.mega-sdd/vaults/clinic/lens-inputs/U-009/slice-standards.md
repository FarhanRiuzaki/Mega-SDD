---
id: U-009
title: Add the appointments repository and TanStack Query hooks
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:145, PRD/prd-clinic.md:165, PRD/prd-clinic.md:175]
task_type: create
grounding_confidence: LOW
risk: medium
module: M-clinic-core
depends_on: [U-001]
target_files:
  - path: src/features/appointments/repositories/appointment.repository.ts
    operation: create
  - path: src/features/appointments/hooks/useAppointments/index.ts
    operation: create
  - path: src/features/appointments/hooks/useAppointments/index.test.tsx
    operation: create
existing_interfaces:
  - file: src/libs/query-keys/index.ts
    symbol: createQueryKeys
    note: "reuse unchanged"
  - file: src/libs/api/crud-hooks.ts
    symbol: makeCreateMutation
    note: "reuse unchanged"
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "loads doctors and services from the clinic proxy routes"
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "requests availability only when doctor and date are chosen"
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "posts a booking to the appointments proxy route"
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "cancels through the token cancel route outside the v1 prefix"
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "reassigns an appointment and refreshes the schedule"
binding_refs: [OQ-CN-1, OQ-AR-1]
---

# Unit U-009 — Add the appointments repository and TanStack Query hooks

## Anchors


- src/features/users/repositories/user.repository.ts:1-19 — repository functions over `apiClient` with `/v1/...` paths
- src/features/users/hooks/useUsers.ts:1-51 — query keys + `useQuery` + mutation factories
- src/libs/api/crud-hooks.ts:21-61 — `makeCreateMutation` / `makeUpdateMutation` contracts (snackbar + invalidate)
- src/libs/api/client.ts:10-18 — `apiClient` base `/api`, throws on non-OK
- src/test/utils.tsx:36 — `renderWithProviders`; tests override MSW handlers per case with `server.use`

## Claims


- C-U009-01 "createQueryKeys is the query-key factory" — expect: src/libs/query-keys/index.ts:createQueryKeys
- C-U009-02 "makeCreateMutation wires snackbar and invalidation" — expect: src/libs/api/crud-hooks.ts:makeCreateMutation
- C-U009-03 "renderWithProviders is the component test helper" — expect: src/test/utils.tsx:renderWithProviders
- C-U009-04 "apiClient is the browser fetcher" — expect: src/libs/api/client.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/test/handlers.ts
  Source: src/test/handlers.ts:14-21 (tests override default handlers per case with server.use)
- file src/features/appointments/repositories/appointment.repository.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep repositories free of enqueueSnackbar and return the raw envelope (constitution C-003)
  Source: constitution.md §C C-003
- MUST build query keys with createQueryKeys and CRUD mutations with the crud-hooks factories where they fit (constitution C-003)
  Source: constitution.md §C C-003
- MUST call only apiClient from this client-side layer (constitution C-001)
  Source: constitution.md §C C-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-AR-1 — upstream response shapes follow the recommended contract; the envelope `data` is typed with the U-001 types.



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
