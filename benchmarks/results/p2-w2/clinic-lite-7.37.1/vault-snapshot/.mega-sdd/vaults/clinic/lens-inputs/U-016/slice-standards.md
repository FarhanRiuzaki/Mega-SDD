---
id: U-016
title: Build the doctor schedule page with today and week views
context_source: context.md#F-S-001
prd_source: [PRD/prd-clinic.md:170, PRD/prd-clinic.md:171, PRD/prd-clinic.md:172, PRD/prd-clinic.md:193, PRD/prd-clinic.md:110, PRD/prd-clinic.md:209]
task_type: create
grounding_confidence: LOW
risk: medium
module: M-staff
depends_on: [U-002, U-003, U-009]
target_files:
  - path: src/features/appointments/components/DoctorSchedule/index.tsx
    operation: create
  - path: src/features/appointments/components/DoctorSchedule/index.test.tsx
    operation: create
  - path: src/features/appointments/components/AppointmentDetailDialog/index.tsx
    operation: create
  - path: src/app/(dashboard)/staff/schedule/page.tsx
    operation: create
existing_interfaces:
  - file: src/components/rbac/ProtectedRoute.tsx
    symbol: ProtectedRoute
    note: "reuse unchanged with require.roles"
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/DoctorSchedule/index.test.tsx --reporter=verbose"
    expects: "shows the signed-in doctor appointments for today"
  - type: test
    command: "pnpm test:run src/features/appointments/components/DoctorSchedule/index.test.tsx --reporter=verbose"
    expects: "switches to the week view"
  - type: test
    command: "pnpm test:run src/features/appointments/components/DoctorSchedule/index.test.tsx --reporter=verbose"
    expects: "opens appointment details with patient name and reason for visit"
  - type: test
    command: "pnpm test:run src/features/appointments/components/DoctorSchedule/index.test.tsx --reporter=verbose"
    expects: "shows an empty state when there are no appointments"
  - type: manual
    desc: "Sign in as a doctor, open /staff/schedule: only your own appointments appear in today and week views; sign in as a user without the doctor role: the Access Denied panel is shown."
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-AR-2, OQ-CLINIC-006]
---

# Unit U-016 — Build the doctor schedule page with today and week views

## Anchors


- src/app/(dashboard)/users/page.tsx:1-17 — page wrapping a feature component in `ProtectedRoute require={...}`
- src/components/rbac/ProtectedRoute.tsx:18-60 — `require.roles` support and the Access Denied panel
- src/features/users/components/UserDetailDialog.tsx — MUI dialog pattern for a record's details
- src/components/misc/EmptyState.tsx — empty-state component

## Claims


- C-U016-01 "ProtectedRoute supports role requirements" — expect: src/components/rbac/ProtectedRoute.tsx:ProtectedRoute
- C-U016-02 "an EmptyState component exists" — expect: src/components/misc/EmptyState.tsx — must-exist
- C-U016-03 "the appointments hooks exist" — expect: src/features/appointments/hooks/useAppointments/index.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/components/rbac/ProtectedRoute.tsx
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- DO NOT modify src/data/navigation/verticalMenuData.tsx
  Source: context.md OQ-AR-2 (no menu entry until permission names are decided)
- DO NOT modify src/data/navigation/horizontalMenuData.tsx
  Source: context.md OQ-AR-2 (no menu entry until permission names are decided)
- file src/app/(dashboard)/staff/schedule/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST guard the page with ProtectedRoute requiring the doctor role (constitution B-005)
  Source: constitution.md §B B-005
- MUST render appointment status with AppointmentStatusChip so status is never color-only (constitution F-002)
  Source: constitution.md §F F-002
- MUST keep the grid keyboard-reachable with each appointment cell a focusable button that opens the detail dialog (constitution F-001)
  Source: constitution.md §F F-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-AR-2 — no navigation menu entry until permission names are decided; reach the page by URL.



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
