---
id: U-007
title: Add the role-scoped staff schedule and reassign BFF routes
context_source: context.md#F-S-001
prd_source: [PRD/prd-clinic.md:209, PRD/prd-clinic.md:171, PRD/prd-clinic.md:176, PRD/prd-clinic.md:177, PRD/prd-clinic.md:193, PRD/prd-clinic.md:194]
task_type: create
grounding_confidence: LOW
risk: high
module: M-clinic-bff
depends_on: [U-001]
target_files:
  - path: src/app/api/v1/appointments/schedule/route.ts
    operation: create
  - path: src/app/api/v1/appointments/schedule/route.test.ts
    operation: create
  - path: src/app/api/v1/appointments/[id]/reassign/route.ts
    operation: create
  - path: src/app/api/v1/appointments/[id]/reassign/route.test.ts
    operation: create
existing_interfaces:
  - file: src/libs/jwt-permission/index.ts
    symbol: JWTPermissionChecker
    note: "reuse unchanged for doctor / receptionist role checks"
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "forces the doctor id to the signed-in doctor"
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "passes the receptionist query through for all doctors"
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "rejects a schedule request from a user without a staff role with 403"
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "rejects an unauthenticated schedule request with 401"
  - type: test
    command: "pnpm test:run reassign/route --reporter=verbose"
    expects: "rejects a reassign request from a non-receptionist with 403"
  - type: test
    command: "pnpm test:run reassign/route --reporter=verbose"
    expects: "forwards a valid reassign to upstream"
  - type: test
    command: "pnpm test:run reassign/route --reporter=verbose"
    expects: "rejects an invalid reassign payload with 400 without calling upstream"
  - type: test
    command: "pnpm test:run reassign/route --reporter=verbose"
    expects: "rejects an unauthenticated reassign request with 401"
  - type: test
    command: "pnpm test:run appointments/schedule/route --reporter=verbose"
    expects: "treats a user with both doctor and receptionist roles as a receptionist"
binding_refs: [OQ-CN-1, OQ-AR-1]
---

# Unit U-007 — Add the role-scoped staff schedule and reassign BFF routes

## Anchors


- src/libs/api/route-handler.ts:19-41 — `respond()` mapping and the query-forwarding approach of `proxyGet`
- src/libs/api/server.ts:9-27 — `apiServer.get(path, { params })`
- src/libs/auth.ts:134-152 — session carries `user.id`, `user.roles`, `user.permissions`
- src/libs/jwt-permission/index.ts:29 — `JWTPermissionChecker.hasRole`

## Claims


- C-U007-01 "JWTPermissionChecker implements role checks" — expect: src/libs/jwt-permission/index.ts:JWTPermissionChecker
- C-U007-02 "the session exposes user id and roles" — expect: src/types/next-auth.d.ts — must-exist
- C-U007-03 "apiServer is the server-side fetcher" — expect: src/libs/api/server.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/auth.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file src/app/api/v1/appointments/schedule/route.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST answer 401 without a session and 403 for a session with neither the doctor nor the receptionist role (constitution B-005)
  Source: constitution.md §B B-005
- MUST overwrite any doctorId query parameter with session.user.id when the caller is a doctor without the receptionist role (constitution B-005)
  Source: constitution.md §B B-005
- MUST allow reassign only for the receptionist role and parse the body with reassignPayloadSchema before calling upstream (constitution B-001)
  Source: constitution.md §B B-001
- MUST call apiServer, never apiClient, inside these Route Handlers (constitution C-001)
  Source: constitution.md §C C-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `rejects an invalid reassign payload with 400 without calling upstream`: a body failing reassignPayloadSchema answers 400 and apiServer.post is not called.
- Adversarial addition — `rejects an unauthenticated reassign request with 401`: with getServerSession resolving null the reassign route answers 401 (not 403 or 500) and upstream is not called.
- Adversarial addition — `treats a user with both doctor and receptionist roles as a receptionist`: a session with roles doctor and receptionist forwards an explicit doctorId query unchanged.
- TBD: OQ-AR-1 — the upstream also enforces data scope with the bearer token; this route is the defense-in-depth layer.



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
