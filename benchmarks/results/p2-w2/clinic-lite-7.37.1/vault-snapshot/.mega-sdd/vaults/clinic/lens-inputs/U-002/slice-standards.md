---
id: U-002
title: Implement the bookable slot rules library
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:70, PRD/prd-clinic.md:147, PRD/prd-clinic.md:148, PRD/prd-clinic.md:206]
task_type: create
grounding_confidence: LOW
risk: low
module: M-clinic-core
depends_on: []
target_files:
  - path: src/features/appointments/utils/slots/index.ts
    operation: create
  - path: src/features/appointments/utils/slots/index.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "generates 28 fifteen-minute slots from 09:00 to 16:45 without lunch"
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "narrows slots to the doctor working hours within the global bounds"
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "hides booked start times from the available slots"
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "rejects past dates and weekends"
  - type: test
    command: "pnpm test:run src/features/appointments/utils/slots/index.test.ts --reporter=verbose"
    expects: "hides slots earlier than now on the current day"
binding_refs: [OQ-CN-1, OQ-CN-3, OQ-DM-1]
---

# Unit U-002 — Implement the bookable slot rules library

## Anchors


- src/libs/api/query-params/index.ts — pure helper module with a co-located `index.test.ts`; mirror this folder-with-test shape
- src/libs/api/query-params/index.test.ts — Vitest style used for pure helpers

## Claims


- C-U002-01 "pure helpers with tests live in a folder with index.ts and index.test.ts" — expect: src/libs/api/query-params/index.test.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/utils/slots/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep the module free of React, network and date-library imports so it stays a pure function module (constitution A-002)
  Source: constitution.md §A A-002
- MUST treat 09:00–17:00 and the 12:00–13:00 lunch break as hard outer bounds that working hours can only narrow (source: PRD §5 BR-001)
  Source: PRD §5 BR-001

## Anti-patterns


- Don't convert between timezones — the clinic timezone is open (OQ-CN-3); work on `YYYY-MM-DD` dates and `HH:mm` times.
- Don't mark the slots after a longer service as taken — whether a long visit blocks following slots is open (OQ-DM-1); only booked start times are hidden.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-3 — "today" and "now" are passed in by the caller; the timezone that produces them is not decided here.
- TBD: OQ-DM-1 — only booked start times are removed.



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
