---
id: U-010
title: Open the patient pages and staff login in the route proxy
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:53, PRD/prd-clinic.md:190, PRD/prd-clinic.md:192, PRD/prd-clinic.md:195]
task_type: extend
grounding_confidence: LOW
risk: high
module: M-platform
depends_on: []
target_files:
  - path: src/proxy.ts
    operation: modify
  - path: src/proxy.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+4 gaps merged)
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "lets an anonymous visitor open the booking page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "lets an anonymous visitor open a reschedule link"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "lets an anonymous visitor open the staff login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "still redirects an anonymous visitor on a staff page to the login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "bounces a signed-in user from the staff login page to home"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "redirects an anonymous visitor on reschedule without a token or a substring collision to the login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "redirects an anonymous visitor on a book prefixed but unrelated path to the login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "still bounces a signed-in user from the login page to home"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "still clears cookies and redirects to login on a refresh error even for the booking page"
binding_refs: [OQ-CN-1]
---

# Unit U-010 — Open the patient pages and staff login in the route proxy

## Anchors


- src/proxy.ts:7-37 — `proxy(request)` with `publicRoutes`, the RefreshTokenError branch, the auth-page bounce and the matcher config

## Claims


- C-U010-01 "the Next.js 16 proxy guards every page" — expect: src/proxy.ts — must-exist
- C-U010-02 "no proxy test exists yet" — expect: src/proxy.test.ts — must-not-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/auth.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- MUST keep the exported `proxy(request: Request)` function name and the exported `config.matcher` value unchanged (source: CLAUDE.md §Auth & routing)
  Source: CLAUDE.md §Auth & routing
- MUST keep the RefreshTokenError branch clearing both session cookies and redirecting to /login before any other rule
  Source: src/proxy.ts:14-22 — CLAUDE.md §Auth & routing
- MUST match the reschedule route only as the /reschedule/ prefix followed by a token segment, never by substring (constitution B-002)
  Source: constitution.md §B B-002
- MUST NOT make any /staff path other than /staff/login public (constitution B-005)
  Source: constitution.md §B B-005

## Migration notes


- **REMOVE**: the single `publicRoutes` list and its `includes(pathname)` check.
- **KEEP**: the RefreshTokenError cookie-clearing redirect, the `/home` bounce for signed-in users on auth pages, the anonymous → `/login` redirect, the `export const config` matcher.
- **ADD**: `/staff/login` as an auth page; `/book` and `/reschedule/<token>` as always-public patient pages; `src/proxy.test.ts`.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `redirects an anonymous visitor on reschedule without a token or a substring collision to the login page`: anonymous GET /reschedule and GET /rescheduled both redirect to /login.
- Adversarial addition — `redirects an anonymous visitor on a book prefixed but unrelated path to the login page`: anonymous GET /book/admin (a path sharing the /book prefix) still redirects to /login.
- Adversarial addition — `still bounces a signed-in user from the login page to home`: a signed-in user on /login is still redirected to /home after the refactor.
- Adversarial addition — `still clears cookies and redirects to login on a refresh error even for the booking page`: a RefreshTokenError session on /book is redirected to /login with both session cookies deleted.



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
