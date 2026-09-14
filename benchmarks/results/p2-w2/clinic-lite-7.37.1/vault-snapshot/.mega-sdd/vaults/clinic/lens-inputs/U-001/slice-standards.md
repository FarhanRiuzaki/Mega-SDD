---
id: U-001
title: Define appointment domain types and zod payload schemas
context_source: context.md#Data-model
prd_source: [PRD/prd-clinic.md:202, PRD/prd-clinic.md:149, PRD/prd-clinic.md:95]
task_type: create
grounding_confidence: LOW
risk: low
module: M-clinic-core
depends_on: []
target_files:
  - path: src/features/appointments/types/index.ts
    operation: create
  - path: src/features/appointments/schemas/booking/index.ts
    operation: create
  - path: src/features/appointments/schemas/booking/index.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "accepts a complete booking"
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "rejects an invalid email with a readable message"
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "rejects whitespace-only name and reason"
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "covers every booking field in exactly one wizard step"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-DM-1, OQ-CN-3]
---

# Unit U-001 — Define appointment domain types and zod payload schemas

## Anchors


- src/features/users/types/index.ts:1-29 — `I`-prefixed entity interfaces and `T`-prefixed payload types; follow this naming
- src/features/users/schemas/user.schema.ts:1-30 — a schema file exports schema + inferred type + defaults
- src/libs/api/query-params/index.ts — a module that owns a test lives in `<name>/index.ts` + `<name>/index.test.ts`

## Claims


- C-U001-01 "feature types follow the users feature shape" — expect: src/features/users/types/index.ts — must-exist
- C-U001-02 "schema files export schema, inferred type and defaults" — expect: src/features/users/schemas/user.schema.ts — must-exist
- C-U001-03 "the folder-with-test module pattern is established" — expect: src/libs/api/query-params/index.test.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/types/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- file src/features/appointments/schemas/booking/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST export every schema together with its inferred type and its defaults (constitution A-004)
  Source: constitution.md §A A-004
- MUST keep the schema module and its test together in schemas/booking/ (constitution A-002)
  Source: constitution.md §A A-002
- MUST NOT add any payment or price-calculation field beyond the display-only service price (constitution C-005)
  Source: constitution.md §C C-005

## Anti-patterns


- Don't invent entity fields the PRD §Clinic.4 data model does not list; display-only embedded summaries (`patient`, `doctor`, `service`) on an appointment are allowed because staff views must show patient name and reason for visit (context.md#F-S-001).
- Don't encode timezone conversions — the timezone is still open (OQ-CN-3); keep `date` as `YYYY-MM-DD` and times as `HH:mm`.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-3 — date/time strings stay timezone-free until the clinic timezone is decided.
- TBD: OQ-DM-1 — nothing here assumes how long services occupy slots.



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
