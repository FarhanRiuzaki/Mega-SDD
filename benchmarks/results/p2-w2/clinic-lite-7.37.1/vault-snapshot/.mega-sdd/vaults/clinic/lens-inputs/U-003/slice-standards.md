---
id: U-003
title: Add appointment status labels and an accessible status chip
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:119, PRD/prd-clinic.md:211]
task_type: extend
grounding_confidence: LOW
risk: low
module: M-clinic-core
depends_on: [U-001]
target_files:
  - path: src/libs/label-maps.ts
    operation: modify
  - path: src/features/appointments/components/AppointmentStatusChip/index.tsx
    operation: create
  - path: src/features/appointments/components/AppointmentStatusChip/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"
    expects: "renders the text label for every status"
  - type: test
    command: "pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"
    expects: "renders a distinct icon for every status"
  - type: test
    command: "pnpm test:run src/features/appointments/components/AppointmentStatusChip/index.test.tsx --reporter=verbose"
    expects: "keeps existing label maps unchanged"
binding_refs: [OQ-CN-1]
---

# Unit U-003 — Add appointment status labels and an accessible status chip

## Anchors


- src/libs/label-maps.ts:1-56 — existing `Record<string, string>` label maps; append the new maps in the same style
- src/features/users/components/table/index.tsx:1-20 — client component import ordering used in features

## Claims


- C-U003-01 "label-maps.ts is the central value→label module" — expect: src/libs/label-maps.ts — must-exist
- C-U003-02 "ACCOUNT_TYPE_LABELS is an existing export that must survive" — expect: src/libs/label-maps.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/components/AppointmentStatusChip/index.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep every existing export of src/libs/label-maps.ts unchanged (constitution A-005)
  Source: constitution.md §A A-005
- MUST NOT convey status by color alone — every status renders its text label and an icon (constitution F-002)
  Source: constitution.md §F F-002
- MUST keep the chip text contrast at or above 4.5:1 against its background (constitution F-001)
  Source: constitution.md §F F-001
- MUST use Iconify tabler classes for the icons (constitution A-006)
  Source: constitution.md §A A-006

## Migration notes


- **REMOVE**: nothing.
- **KEEP**: every existing export in `src/libs/label-maps.ts` (`TUJUAN_LABELS` … `ACCOUNT_TYPE_LABELS`) and the header comment, unchanged.
- **ADD**: `APPOINTMENT_STATUS_LABELS`, `BOOKING_CHANNEL_LABELS` (with the type import from `@/features/appointments/types`), and the new `AppointmentStatusChip` component folder.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).



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
