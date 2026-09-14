---
id: U-004
title: Make teal-700 the default primary color
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:115, PRD/prd-clinic.md:116]
task_type: extend
grounding_confidence: LOW
risk: low
module: M-platform
depends_on: []
target_files:
  - path: src/configs/primaryColorConfig.ts
    operation: delete
  - path: src/configs/primaryColorConfig/index.ts
    operation: create
  - path: src/configs/primaryColorConfig/index.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose"
    expects: "uses teal-700 as the default primary color"
  - type: test
    command: "pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose"
    expects: "keeps white-on-primary contrast at or above 4.5 to 1"
  - type: test
    command: "pnpm test:run src/configs/primaryColorConfig/index.test.ts --reporter=verbose"
    expects: "never uses a raw brand hue as a main color"
binding_refs: [OQ-CN-1]
---

# Unit U-004 — Make teal-700 the default primary color

## Anchors


- src/configs/primaryColorConfig.ts:1-42 — current preset list; the third entry (`primary-3`, orange `#FFAB1D`) is the default
- src/@core/contexts/settingsContext.tsx:63 — `primaryColor: primaryColorConfig[2].main` (read-only reference; vendored)
- src/components/theme/index.tsx:68-79 — theme derives light/dark from `settings.primaryColor` (read-only reference; vendored)

## Claims


- C-U004-01 "the primary preset module exists as a flat file today" — expect: src/configs/primaryColorConfig.ts — must-exist
- C-U004-02 "the vendored settings context reads the default from preset index 2" — expect: src/@core/contexts/settingsContext.tsx — must-exist
- C-U004-03 "PrimaryColorConfig is the exported preset type" — expect: src/configs/primaryColorConfig.ts:PrimaryColorConfig

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/@core/contexts/settingsContext.tsx
  Source: CLAUDE.md:41 (template internals are vendored) — constitution.md §C C-004
- DO NOT modify src/components/theme/index.tsx
  Source: CLAUDE.md:41 (template internals are vendored) — constitution.md §C C-004
- file src/configs/primaryColorConfig/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep the `PrimaryColorConfig` type export and the default export array shape so existing imports compile (constitution C-004)
  Source: constitution.md §C C-004
- MUST use teal-700 #0E7490 as the default primary and never raw #0891B2 or #16A34A as a main color (constitution F-003)
  Source: constitution.md §F F-003

## Migration notes


- **REMOVE**: the flat file `src/configs/primaryColorConfig.ts` (its content moves into the folder module) and the orange values of preset `primary-3`.
- **KEEP**: the `PrimaryColorConfig` type, presets `primary-1`, `primary-2`, `primary-4`, `primary-5`, the array order and the default export.
- **ADD**: `src/configs/primaryColorConfig/index.ts` with preset `primary-3` = teal-700, and `index.test.ts`.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- Browsers holding an old settings cookie keep their saved color until the customizer is reset (existing behavior, themeConfig.ts header comment).



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
