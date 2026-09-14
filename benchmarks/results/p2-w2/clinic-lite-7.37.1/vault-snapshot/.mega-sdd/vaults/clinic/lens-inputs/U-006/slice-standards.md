---
id: U-006
title: Add the token-authorized cancel and reschedule BFF routes
context_source: context.md#F-U-002
prd_source: [PRD/prd-clinic.md:191, PRD/prd-clinic.md:192, PRD/prd-clinic.md:155, PRD/prd-clinic.md:167, PRD/prd-clinic.md:207, PRD/prd-clinic.md:210]
task_type: create
grounding_confidence: LOW
risk: high
module: M-clinic-bff
depends_on: [U-001]
target_files:
  - path: src/app/api/appointments/[id]/cancel/route.ts
    operation: create
  - path: src/app/api/appointments/[id]/cancel/route.test.ts
    operation: create
  - path: src/app/api/v1/appointments/token/[token]/route.ts
    operation: create
  - path: src/app/api/v1/appointments/token/[token]/route.test.ts
    operation: create
existing_interfaces:
  - file: src/libs/api/route-handler.ts
    symbol: proxyGet
    note: "reuse unchanged for loading an appointment by token"
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "cancels through upstream when a token is posted"
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "rejects a cancel request without a token with 400"
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "exposes no GET handler so an email link cannot cancel by itself"
  - type: test
    command: "pnpm test:run appointments/token --reporter=verbose"
    expects: "loads the appointment for a token from upstream"
  - type: test
    command: "pnpm test:run appointments/token --reporter=verbose"
    expects: "rejects a reschedule payload without a valid start time with 400"
  - type: test
    command: "pnpm test:run appointments/token --reporter=verbose"
    expects: "reschedules through upstream when a valid start time is provided"
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "never echoes the token back in the response body"
  - type: test
    command: "pnpm test:run src/app/api/appointments --reporter=verbose"
    expects: "does not call upstream when the cancel payload fails validation"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-FL-1, OQ-CLINIC-001, OQ-CLINIC-003]
---

# Unit U-006 — Add the token-authorized cancel and reschedule BFF routes

## Anchors


- src/libs/api/route-handler.ts:19-50 — `respond()` mapping and `proxyGet` with dynamic params (`({ token }) => ...`)
- src/app/api/v1/users/[id]/route.ts:1-5 — dynamic-segment proxy route shape
- src/libs/api/server.ts:9-27 — `apiServer.post` / `apiServer.put` return the envelope

## Claims


- C-U006-01 "proxyGet supports dynamic route params" — expect: src/libs/api/route-handler.ts:proxyGet
- C-U006-02 "dynamic-segment proxy routes already exist" — expect: src/app/api/v1/users/[id]/route.ts — must-exist
- C-U006-03 "no cancel route exists yet" — expect: src/app/api/appointments — must-not-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/api/route-handler.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file src/app/api/appointments/[id]/cancel/route.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST export only POST from the cancel route so that a GET request cannot cancel an appointment (source: PRD §Clinic.1 F-U-002 step 2)
  Source: PRD §Clinic.1 F-U-002 step 2
- MUST parse the cancel body with cancelPayloadSchema and the reschedule body with reschedulePayloadSchema before calling upstream, answering 400 on failure (constitution B-001)
  Source: constitution.md §B B-001
- MUST forward the token only to the upstream API and never echo it in a response or log (constitution B-002)
  Source: constitution.md §B B-002

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `reschedules through upstream when a valid start time is provided`: a valid PUT calls apiServer.put with /v1/appointments/token/{token} and a body of exactly { startTime } and returns the upstream envelope.
- Adversarial addition — `never echoes the token back in the response body`: for both the success and the 400 case the serialized response body does not contain the raw token.
- Adversarial addition — `does not call upstream when the cancel payload fails validation`: apiServer.post is never invoked when the body is missing, empty or fails cancelPayloadSchema.
- TBD: OQ-FL-1 — the page where the patient confirms a cancellation is not built; only the API exists.
- TBD: OQ-CLINIC-003 — no cancellation/reschedule window is enforced here; the upstream decides.
- OQ-CLINIC-001 (P1, open): no regulation-specific handling is invented; nothing is persisted or logged in this tier.



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
