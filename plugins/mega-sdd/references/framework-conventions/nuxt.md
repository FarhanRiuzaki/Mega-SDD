---
framework: nuxt
framework_version_range: "3.x — 4.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: package.json
  dependency_marker: "nuxt"
  version_regex: '"nuxt"\s*:\s*"[\^~]?(\d+)\.'
extends: _universal
pack_tier: full
---

# Nuxt Convention Pack (3.x — 4.x)

Conventions for Nuxt full-stack projects. Extends `_universal.md` — universal defaults apply, Nuxt-specific rules override on conflict.

> **srcDir note (Nuxt 4):** Nuxt 4 moves application source under `app/` by default (`app/pages/`, `app/components/`, `app/composables/`, `app/layouts/`, `app/middleware/`, `app/plugins/`, `app/app.vue`). `server/`, `nuxt.config.ts`, and `package.json` remain at the project root. Nuxt 3 keeps all of these at the root (`pages/`, `components/`, etc.). Both layouts are detected; paths below show `app/` as the Nuxt 4 prefix — strip it for Nuxt 3.

## File location standards

| Artifact | Path (Nuxt 4) | Path (Nuxt 3 equivalent) |
|---|---|---|
| App entry | `app/app.vue` | `app.vue` |
| Pages (file-based routing) | `app/pages/` | `pages/` |
| Layouts | `app/layouts/` | `layouts/` |
| Components (auto-imported) | `app/components/` | `components/` |
| Composables (auto-imported) | `app/composables/` | `composables/` |
| Route middleware | `app/middleware/` | `middleware/` |
| Plugins | `app/plugins/` | `plugins/` |
| Pinia stores | `app/stores/` | `stores/` (community convention, requires `@pinia/nuxt`) |
| Static assets | `public/` | `public/` |
| Nuxt config | `nuxt.config.ts` | `nuxt.config.ts` |
| Server API routes (Nitro) | `server/api/` | `server/api/` |
| Server middleware (Nitro) | `server/middleware/` | `server/middleware/` |
| Server utilities | `server/utils/` | `server/utils/` |
| Server routes (non-API) | `server/routes/` | `server/routes/` |
| Server plugins (Nitro) | `server/plugins/` | `server/plugins/` |
| TypeScript config | `tsconfig.json` | `tsconfig.json` |
| Environment / runtime config | `nuxt.config.ts` `runtimeConfig` block | `nuxt.config.ts` `runtimeConfig` block |
| Tests | `tests/` or co-located `*.spec.ts` | `tests/` or co-located `*.spec.ts` |
| End-to-end tests | `tests/e2e/` (Playwright) | `tests/e2e/` (Playwright) |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Page file (route) | kebab-case `.vue` — maps to URL path | `pages/user-profile.vue` → `/user-profile` |
| Dynamic segment | `[param].vue` (single) / `[...slug].vue` (catch-all) | `pages/posts/[id].vue` |
| Optional catch-all | `[[...slug]].vue` | `pages/docs/[[...slug]].vue` |
| Named layout | `layouts/<name>.vue` (referenced in `definePageMeta`) | `layouts/dashboard.vue` |
| Component filename | PascalCase `.vue` | `components/UserCard.vue` |
| Component name (auto-import) | PascalCase; sub-dir path prefix appended | `components/Base/Button.vue` → `<BaseButton />` |
| Component suffix — server-only | `.server.vue` | `components/HeavyChart.server.vue` |
| Component suffix — client-only | `.client.vue` | `components/MapWidget.client.vue` |
| Composable filename | camelCase, `use` prefix | `composables/useAuth.ts` |
| Composable function | camelCase, `use` prefix | `useAuth`, `useCartStore` |
| Pinia store filename | camelCase domain noun | `stores/user.ts` (exports `useUserStore`) |
| Server route (Nitro) | kebab-case `.ts` under `server/api/` or `server/routes/` | `server/api/users.get.ts` |
| Nitro HTTP-method suffix | `.get.ts` / `.post.ts` / `.put.ts` / `.delete.ts` / `.patch.ts` | `server/api/users.post.ts` |
| Route middleware filename | kebab-case; suffix `.global.ts` for auto-applied global middleware | `middleware/auth.ts`, `middleware/log.global.ts` |
| Plugin filename | kebab-case; `.server.ts` or `.client.ts` suffix when restricted | `plugins/sentry.client.ts` |
| Environment variable (public) | via `runtimeConfig.public` in `nuxt.config.ts`; all-caps in `.env` | `NUXT_PUBLIC_API_URL` |
| Environment variable (private) | via `runtimeConfig` in `nuxt.config.ts`; all-caps in `.env` | `NUXT_SECRET_KEY` |

## Idioms (preferred patterns)

- **`<script setup>` SFCs** — use `<script setup lang="ts">` as the standard component authoring format; avoid Options API for new code
- **Auto-imports** — components in `components/`, composables in `composables/`, and Nuxt/Vue built-ins are auto-imported; do not manually import what Nuxt already provides
- **`useFetch` for data fetching** — use `useFetch('/api/endpoint')` (or `useAsyncData` with `$fetch`) for SSR-aware, cache-keyed data fetching; avoid bare `fetch()` or client-side `onMounted`-only fetching
- **`definePageMeta` for route metadata** — use `definePageMeta({ layout: '...', middleware: [...] })` inside `<script setup>` to declare layout, middleware, and page-level options; do not set these imperatively
- **`useState` for SSR-safe shared state** — use `useState<T>(key, init)` for cross-component shared state that survives hydration; do not use plain `ref()` at module scope for state shared between SSR and client
- **Nitro server routes with `defineEventHandler`** — define API endpoints as `server/api/*.ts` files exporting a default `defineEventHandler((event) => ...)` function; use `readBody(event)`, `getQuery(event)`, `getCookie(event)` for input
- **Route middleware with `defineNuxtRouteMiddleware`** — guard routes in `middleware/*.ts` files exporting a default `defineNuxtRouteMiddleware((to, from) => ...)` function; return `navigateTo('/login')` or `abortNavigation()` to redirect/block
- **`definePageMeta({ middleware: 'auth' })` to apply middleware** — reference named middleware by file stem; use `'auth'` for `middleware/auth.ts`
- **Pinia for complex store logic** — use `defineStore` from Pinia (`@pinia/nuxt`) for feature stores; name the file after the domain noun (`stores/user.ts`), and export the store as `useUserStore`; access via `useUserStore()` composable
- **`runtimeConfig` for environment-linked config** — declare server-private config under `runtimeConfig` and public config under `runtimeConfig.public` in `nuxt.config.ts`; read via `useRuntimeConfig()` — never access `process.env` directly in components or composables
- **`.server.vue` / `.client.vue` suffixes for rendering mode** — suffix components with `.server.vue` to render only on the server (no hydration) and `.client.vue` to render only in the browser; use sparingly for performance or browser-API-dependent widgets
- **`<NuxtLayout>` + `<NuxtPage>` in `app.vue`** — `app.vue` is the universal entry; render layouts via `<NuxtLayout>` and current page via `<NuxtPage />`
- **`useHead` / `useSeoMeta` for document head** — manage `<head>` tags declaratively via composables, not raw DOM manipulation

## Hard Rules emitted

```
HARD_RULE: Server-only secrets MUST be declared under runtimeConfig (not runtimeConfig.public) in nuxt.config.ts
  path_glob: nuxt.config.ts
  rule_type: CUSTOM
  rationale: runtimeConfig.public values are embedded into the client bundle; private keys under runtimeConfig are server-only and never sent to the browser

HARD_RULE: Data fetching in components MUST use useFetch or useAsyncData, not bare fetch() or axios inside onMounted
  path_glob: app/pages/**/*.vue
  rule_type: CUSTOM
  rationale: useFetch / useAsyncData are SSR-aware and deduplicated; bare fetch() in onMounted runs only client-side, breaking SSR hydration and causing content flash

HARD_RULE: Route guards MUST use defineNuxtRouteMiddleware in middleware/*.ts files, not navigation guards in components
  path_glob: app/middleware/*.ts
  rule_type: NAMING_RULE
  pattern: 'defineNuxtRouteMiddleware'
  rationale: Navigation guards in components run after render; route middleware runs before navigation and is applied uniformly across SSR and client

HARD_RULE: Server API routes MUST be in server/api/ and export a default defineEventHandler
  path_glob: server/api/**/*.ts
  rule_type: LOCATION_RULE
  rationale: Nitro only discovers and builds server routes from server/api/ (and server/routes/); files outside this directory are not exposed as API endpoints

HARD_RULE: Components MUST NOT import server-only modules (node:fs, node:crypto, drizzle-orm, prisma client) directly
  path_glob: app/components/**/*.vue
  rule_type: CUSTOM
  forbidden_patterns: [ "from 'node:", "require('node:", "from 'drizzle-orm", "from '@prisma/client'" ]
  rationale: Components are bundled for the browser; server-only imports fail at runtime in the client bundle

HARD_RULE: process.env MUST NOT be accessed in components, composables, or pages — use useRuntimeConfig() instead
  path_glob: app/**/*.{vue,ts}
  rule_type: CUSTOM
  forbidden_patterns: [ "process.env." ]
  rationale: process.env is not available in the browser bundle; useRuntimeConfig() is the Nuxt-safe isomorphic accessor
```

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — Nitro server routes validate with `readValidatedBody(event, schema.parse)` / `getValidatedQuery(event, …)` backed by `zod`; the bypass is plain `readBody(event)` with the shape trusted as-is — `server/api/` routes are directly callable regardless of what the UI sends.
- **SQL injection** — Prisma/Drizzle in `server/` parameterize; raw SQL with interpolated request values (`$queryRawUnsafe`, string-built `sql` fragments) reintroduces SQLi — use bindings/tagged templates or stay in the ORM query API.
- **XSS / output escaping** — Vue template interpolation (`{{ }}`) auto-escapes; `v-html` is the bypass and is only valid for content sanitized server-side — never for user input.
- **CSRF** — nothing built into Nitro routes; cookie-session apps need an origin check or token module (e.g. `nuxt-csurf`) plus `SameSite` cookies — bearer-token APIs are not exposed. The bypass is a state-changing `server/api/*.post.ts` route that trusts the session cookie with no origin/token check.
- **AuthN/AuthZ enforcement point** — the session check inside each Nitro handler or in `server/middleware/` (e.g. `requireUserSession` from the session util); `defineNuxtRouteMiddleware` route middleware is UX-only navigation guarding — the bypass is protecting only the page middleware while the `server/api/` route underneath stays open to direct requests.
- **Password hashing** — `bcrypt`/`argon2` in `server/utils/`; never `node:crypto` plain hashes, never imported into components (pack hard rule blocks server-only imports client-side).
- **Mass assignment** — the validated-body schema is the field allowlist; the bypass is spreading the raw `readBody` result straight into an ORM write (`{ ...body }`), letting an extra `role`/`isAdmin` field ride along.
- **Secrets / config** — `runtimeConfig` (server-private) vs `runtimeConfig.public` split: everything under `public` is embedded in the client bundle. The bypass is parking a secret under `public` / `NUXT_PUBLIC_*` to make it reachable in a component (pack hard rule); read config via `useRuntimeConfig()`, never `process.env`.
- **File uploads** — `readMultipartFormData(event)` in a Nitro route with size caps and a mimetype allowlist, stored outside `public/`; never trust the client filename — generate your own.

## Testing conventions

- **Unit / integration runner**: Vitest — configured via `vitest.config.ts`; use `defineVitestConfig` from `@nuxt/test-utils/config` to wire up the Nuxt environment
- **Component testing**: Vue Test Utils (`@vue/test-utils`) + `mountSuspended` / `renderSuspended` from `@nuxt/test-utils` for testing components with auto-imports and Nuxt context
- **Nuxt test utils**: `@nuxt/test-utils` — provides `setup()`, `$fetch()`, `mountSuspended()`, `renderSuspended()`, and Nuxt-aware Vitest environment
- **End-to-end testing**: Playwright via `@nuxt/test-utils/playwright` — extend base `test` from `@nuxt/test-utils/playwright`; use `goto()` helper which wraps Playwright navigation with hydration awareness
- **Test file location**: co-located `ComponentName.spec.ts` next to the component, or aggregated under `tests/`
- **Test naming**: Vitest `describe` / `it` blocks — `describe('UserCard', () => { it('renders the user name', ...) })`
- **Nitro server route testing**: `$fetch('/api/endpoint')` from `@nuxt/test-utils/e2e` within a `setup()` fixture; tests can assert JSON responses against real server behavior
- **Pinia store testing**: use `createPinia()` + `setActivePinia()` in `beforeEach`; import and call the store directly; no global plugin wiring needed in unit tests
- **Coverage**: `vitest run --coverage`; `v8` provider common; `lcov` for CI

## Deep-scan file hints

```yaml
auth_hints:
  - "middleware/auth.ts"
  - "app/middleware/auth.ts"
  - "server/api/auth/"
  - "server/middleware/"
  - "nuxt.config.ts"
  - "@sidebase/nuxt-auth"
  - "nuxt-auth-utils"
authz_hints:
  - "middleware/auth.ts"
  - "app/middleware/auth.ts"
  - "server/api/"
  - "server/middleware/"
  - "composables/useAuth.ts"
  - "app/composables/useAuth.ts"
ui_hints:
  - "app/layouts/"
  - "layouts/"
  - "app/app.vue"
  - "app.vue"
  - "app/components/"
  - "components/"
  - "assets/css/"
  - "assets/scss/"
  - "nuxt.config.ts"
```

## Authz mapping

- `mechanism`: `middleware` (route middleware files in `middleware/`) + `server-guard` (server-side checks inside `defineEventHandler` in `server/api/`)
- `role_source`: `token` (JWT claims read via `useRuntimeConfig()` or session cookie) or `db` (role fetched from DB inside a server route)
- Construct → `declarations[].kind`:
  - `defineNuxtRouteMiddleware` in `middleware/auth.ts` guarding a set of routes → `{kind: route-guard, applies_to: <route pattern>}`
  - `definePageMeta({ middleware: 'auth' })` on a page → `{kind: route-guard, applies_to: <page path>}`
  - Role check inside `defineEventHandler` in `server/api/` (e.g. `if (user.role !== 'admin') throw createError({ statusCode: 403 })`) → `{kind: role, name}`
  - `@sidebase/nuxt-auth` or `nuxt-auth-utils` session check in middleware → `{kind: route-guard}`

## UI detection

- dominant layout: most-referenced `definePageMeta({ layout: '<name>' })` across `pages/`; default layout is `layouts/default.vue`; `<NuxtLayout>` in `app.vue` activates the layout system
- component dir: `components/` (Nuxt 3) / `app/components/` (Nuxt 4) — auto-imported; sub-directories create PascalCase-prefixed component names
- styling: UnoCSS (`@unocss/nuxt`), Tailwind CSS (`@nuxtjs/tailwindcss`), or Nuxt UI (`@nuxt/ui`) — look for module entry in `nuxt.config.ts` `modules` array
- notification call: Nuxt UI `useToast()` composable, `vue-toastification`, or custom composable in `composables/useToast.ts`
- icon lib: `@nuxt/icon`, `nuxt-icon`, or `@iconify` — look for module in `nuxt.config.ts`

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "composables/**", "utils/**", "app/composables/**", "app/utils/**" ]
  model_api: [ "server/**/models/**", "server/**/repositories/**" ]
  services: [ "server/utils/**", "server/**/services/**", "services/**" ]
  commands: [ "scripts/**" ]
```
- model_api: server-side model definitions, ORM query wrappers, and repository helpers; absent in projects using direct `$fetch` without a service layer.
- commands: Node.js scripts for migration, seeding, or build steps (e.g., `scripts/seed.ts` run with `npx tsx`).
