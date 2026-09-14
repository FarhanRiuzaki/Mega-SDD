---
id: U-005
title: Add the public booking BFF routes (doctors, services, availability, create appointment)
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:190, PRD/prd-clinic.md:150, PRD/prd-clinic.md:205, PRD/prd-clinic.md:178]
task_type: create
grounding_confidence: LOW
risk: high
module: M-clinic-bff
depends_on: [U-001]
target_files:
  - path: src/app/api/v1/doctors/route.ts
    operation: create
  - path: src/app/api/v1/services/route.ts
    operation: create
  - path: src/app/api/v1/appointments/availability/route.ts
    operation: create
  - path: src/app/api/v1/appointments/availability/route.test.ts
    operation: create
  - path: src/app/api/v1/appointments/route.ts
    operation: create
  - path: src/app/api/v1/appointments/route.test.ts
    operation: create
existing_interfaces:
  - file: src/libs/api/route-handler.ts
    symbol: proxyGet
    note: "reuse unchanged for the GET proxies"
  - file: src/libs/jwt-permission/index.ts
    symbol: JWTPermissionChecker
    note: "reuse unchanged for the receptionist role check"
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+4 gaps merged)
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "rejects an invalid booking payload with 400 before calling upstream"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "forwards a valid online booking to the upstream appointments endpoint"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "rejects a staff-channel or override booking without the receptionist role"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "allows a receptionist to create a staff-channel override booking"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/availability/route.test.ts --reporter=verbose"
    expects: "forwards doctorId and date to the upstream availability endpoint"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "returns 400 when the request body is not valid JSON"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "rejects a staff-channel booking from a completely unauthenticated caller with 403 not 500"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "rejects an online booking with override true from a non-receptionist"
  - type: test
    command: "pnpm test:run src/app/api/v1/appointments/route.test.ts --reporter=verbose"
    expects: "strips unknown fields from the payload before forwarding to upstream"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CN-4, OQ-CLINIC-001]
---

# Unit U-005 — Add the public booking BFF routes (doctors, services, availability, create appointment)

## Anchors


- src/libs/api/route-handler.ts:31-50 — `proxyGet` / `proxyPost` factories and the `respond()` envelope→status mapping at line 19 to mirror
- src/app/api/v1/users/route.ts:1-4 — one-line proxy route shape
- src/libs/api/server.ts:9-27 — `apiServer` returns a `{ success: false }` envelope instead of throwing
- src/libs/auth.ts:39 — `authOptions` for `getServerSession`
- src/libs/jwt-permission/index.ts:29 — `JWTPermissionChecker.hasRole` (case-insensitive)

## Claims


- C-U005-01 "proxyGet exists in the route-handler factory" — expect: src/libs/api/route-handler.ts:proxyGet
- C-U005-02 "JWTPermissionChecker implements hasRole" — expect: src/libs/jwt-permission/index.ts:JWTPermissionChecker
- C-U005-03 "apiServer is the server-side fetcher" — expect: src/libs/api/server.ts — must-exist
- C-U005-04 "next-auth options live in libs/auth.ts" — expect: src/libs/auth.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/api/route-handler.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file:src/app/api/v1/**/route.ts MUST follow kebab-case naming
  Source: framework pack next.md §Naming standards (route segment folders are kebab-case)
- MUST parse the POST body with createAppointmentPayloadSchema before any upstream call and answer 400 on failure (constitution B-001)
  Source: constitution.md §B B-001
- MUST reject bookingChannel staff or override true unless the session holds the receptionist role (constitution C-006)
  Source: constitution.md §C C-006
- MUST call apiServer, never apiClient, inside these Route Handlers (constitution C-001)
  Source: constitution.md §C C-001
- MUST NOT log request bodies or patient data (constitution F-004)
  Source: constitution.md §F F-004

## Anti-patterns


- Don't forward `Object.fromEntries`-style raw bodies — forward only the zod-parsed data (mass-assignment rail of the Next.js pack).
- Don't implement an in-memory rate limiter — the limit value and its owner are open (OQ-CN-4).

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `returns 400 when the request body is not valid JSON`: an unparsable body answers 400 (no thrown 500) and apiServer.post is never called.
- Adversarial addition — `rejects a staff-channel booking from a completely unauthenticated caller with 403 not 500`: with getServerSession resolving null, a staff-channel payload answers 403 without throwing and upstream is not called.
- Adversarial addition — `rejects an online booking with override true from a non-receptionist`: bookingChannel online plus override true without the receptionist role answers 403 — the override branch is gated on its own.
- Adversarial addition — `strips unknown fields from the payload before forwarding to upstream`: an extra client field (for example status) is absent from the body apiServer.post receives — only the zod-parsed shape is forwarded.
- TBD: OQ-CN-4 — rate limiting of the public booking surface is not implemented until its limit and owner are decided.
- TBD: OQ-AR-1 — upstream paths follow the recommended `/v1/...` mirror.
- OQ-CLINIC-001 (P1, open): regulation-specific handling of the patient data in the payload is not invented here; the handler only validates and forwards.



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
