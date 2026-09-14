---
id: U-008
title: Add the CRON_SECRET-guarded reminder sweep trigger route
context_source: context.md#F-U-003
prd_source: [PRD/prd-clinic.md:196, PRD/prd-clinic.md:160, PRD/prd-clinic.md:208, PRD/prd-clinic.md:94]
task_type: extend
grounding_confidence: LOW
risk: high
module: M-clinic-bff
depends_on: []
target_files:
  - path: src/app/api/cron/reminders/route.ts
    operation: create
  - path: src/app/api/cron/reminders/route.test.ts
    operation: create
  - path: .env.example
    operation: modify
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+3 gaps merged)
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "rejects a request without the cron secret with 401"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "rejects every request when CRON_SECRET is not configured"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "triggers the upstream reminder sweep when the secret matches"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "rejects a request with an incorrect secret value with 401"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "rejects a request whose bearer token has a different length than the secret with 401"
  - type: test
    command: "pnpm test:run src/app/api/cron/reminders/route.test.ts --reporter=verbose"
    expects: "triggers the upstream reminder sweep via GET when the secret matches"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-CLINIC-005, OQ-CN-2]
---

# Unit U-008 — Add the CRON_SECRET-guarded reminder sweep trigger route

## Anchors


- src/libs/api/route-handler.ts:19-21 — `respond()` envelope→status mapping to mirror
- src/libs/api/server.ts:9-27 — `apiServer.post` returns an envelope
- .env.example:1-28 — env documentation style (section banners, comments, empty secret values)

## Claims


- C-U008-01 ".env.example documents environment variables" — expect: .env.example — must-exist
- C-U008-02 "no cron route exists yet" — expect: src/app/api/cron — must-not-exist
- C-U008-03 "apiServer is the server-side fetcher" — expect: src/libs/api/server.ts — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/app/api/cron/reminders/route.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST reject every request with 401 when CRON_SECRET is unset or the Authorization header does not equal Bearer followed by CRON_SECRET (constitution B-004)
  Source: constitution.md §B B-004
- MUST compare the secret with a constant-time comparison from node:crypto (constitution B-003)
  Source: constitution.md §B B-003
- NEVER schedule reminders with timers inside this app — the route only triggers the upstream sweep (constitution D-001)
  Source: constitution.md §D D-001
- MUST add CRON_SECRET to .env.example with an empty value and never commit a real secret (constitution B-003)
  Source: constitution.md §B B-003

## Migration notes


- **REMOVE**: nothing.
- **KEEP**: every existing variable, comment and banner in `.env.example`.
- **ADD**: a reminder-cron section with `CRON_SECRET=` in `.env.example`; the new route and its test.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `rejects a request with an incorrect secret value with 401`: a well-formed Bearer header with the wrong value answers 401 and the sweep is not triggered.
- Adversarial addition — `rejects a request whose bearer token has a different length than the secret with 401`: a token of a different length than CRON_SECRET answers 401 without throwing from timingSafeEqual.
- Adversarial addition — `triggers the upstream reminder sweep via GET when the secret matches`: the GET export with the correct secret calls apiServer.post('/v1/reminders/sweep', {}) exactly like POST.
- TBD: OQ-AR-1 — the 24h ± 5 min window, `reminder_sent` idempotency and the email are upstream responsibilities.
- TBD: OQ-CLINIC-005 — which scheduler calls this route is a deployment decision; the route is the same for both options.
- TBD: OQ-CN-2 — delivery within 5 minutes (NFR-003) is not measurable in this tier.



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
