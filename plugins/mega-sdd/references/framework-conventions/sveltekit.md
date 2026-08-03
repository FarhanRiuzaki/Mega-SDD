---
framework: sveltekit
framework_version_range: "2.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_priority: 50  # P2 matcher: lower wins — starterkit variants/meta-frameworks precede their substrates
detection_signature:
  package_manifest: package.json
  dependency_marker: "@sveltejs/kit"
  version_regex: '"@sveltejs/kit"\s*:\s*"[\^~]?(\d+)\.'
extends: _universal
pack_tier: full
---

# SvelteKit Convention Pack (2.x)

Conventions for SvelteKit full-stack projects. Extends `_universal.md` — universal defaults apply, SvelteKit-specific rules override on conflict.

> **Routing model**: SvelteKit uses file-based routing under `src/routes/`. Special `+`-prefixed files (`+page.svelte`, `+layout.svelte`, `+server.ts`, etc.) are the convention; any other file co-located in a route directory is a module, not a route.

## File location standards

| Artifact | Path |
|---|---|
| Route pages | `src/routes/**/+page.svelte` |
| Universal load (shared SSR+CSR) | `src/routes/**/+page.ts` |
| Server-only load | `src/routes/**/+page.server.ts` |
| Layout component | `src/routes/**/+layout.svelte` |
| Layout server load | `src/routes/**/+layout.server.ts` |
| API endpoints | `src/routes/**/+server.ts` |
| Error boundary | `src/routes/**/+error.svelte` |
| Root error boundary | `src/routes/+error.svelte` |
| Shared library (public) | `src/lib/` (aliased as `$lib`) |
| Server-only library | `src/lib/server/` (aliased as `$lib/server`) |
| Shared components | `src/lib/components/` |
| Utility / helper modules | `src/lib/utils/` or `src/lib/` |
| Server hooks | `src/hooks.server.ts` |
| Client hooks | `src/hooks.client.ts` |
| Universal hooks | `src/hooks.ts` |
| App HTML shell | `src/app.html` |
| Global CSS | `src/app.css` |
| SvelteKit config | `svelte.config.js` |
| Vite config | `vite.config.ts` |
| Environment variables | `.env`, `.env.local`, `.env.production` |
| Static assets | `static/` |
| Tests (unit) | `src/**/*.test.ts` or `src/**/*.spec.ts` (co-located, Vitest) |
| Tests (e2e) | `tests/` or `e2e/` (Playwright) |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Route directory | kebab-case | `src/routes/user-profile/` |
| Dynamic route segment | `[param]` — lowercase | `src/routes/blog/[slug]/+page.svelte` |
| Catch-all segment | `[...rest]` | `src/routes/docs/[...path]/+page.svelte` |
| Optional segment | `[[optional]]` | `src/routes/[[lang]]/+page.svelte` |
| Route group (non-routing) | `(group-name)` — lowercase kebab in parens | `src/routes/(auth)/login/+page.svelte` |
| Private folder (excluded) | `_folder` prefix | `src/routes/_internal/` |
| Special route files | `+` prefix, lowercase with extension | `+page.svelte`, `+page.server.ts`, `+layout.svelte`, `+server.ts`, `+error.svelte` |
| Svelte component filename | PascalCase `.svelte` | `src/lib/components/UserCard.svelte` |
| Svelte component name | PascalCase | `UserCard`, `NavBar` |
| Utility / helper module | camelCase or kebab-case `.ts` file | `src/lib/utils/formatDate.ts` |
| Server utility module | camelCase or kebab-case under `$lib/server/` | `src/lib/server/auth.ts` |
| Type / interface | PascalCase | `UserProfile`, `PageData` |
| Store | camelCase, typically descriptive noun | `userStore`, `cartItems` |
| Environment variable (public) | `PUBLIC_` prefix (Vite convention via `$env/static/public`) | `PUBLIC_API_URL` |
| Environment variable (private) | All-caps snake, no `PUBLIC_` prefix | `DATABASE_URL`, `SECRET_KEY` |
| Generated types | `$types` import from `./$types` — do not handwrite | `PageLoad`, `PageServerLoad`, `Actions` |

## Idioms (preferred patterns)

- **Load functions for data fetching** — use `load` exported from `+page.ts` (universal, runs both server and client) or `+page.server.ts` (server-only) to supply `data` to the page component; never fetch in `onMount` for initial page data
- **`+page.server.ts` for server-side concerns** — DB queries, secret env access, auth checks, and form actions all live in `+page.server.ts`; the `+page.ts` universal load is for data that is safe to re-run on the client (e.g. public API calls)
- **Form actions for mutations** — export `const actions` from `+page.server.ts` to handle `<form method="POST">` submissions server-side; prefer named actions (`actions.create`, `actions.delete`) over the default action for multi-action pages
- **`$lib/server/` for secrets** — any module that imports DB connections, secret tokens, or other server-only resources lives under `src/lib/server/`; SvelteKit's Vite plugin enforces this boundary and errors if client code tries to import from `$lib/server`
- **`handle` hook for auth and request decoration** — implement `handle` in `src/hooks.server.ts` to verify sessions, populate `event.locals.user`, and redirect unauthenticated requests; all downstream `load` functions and form actions read from `event.locals`
- **`+layout.server.ts` as an auth guard** — a `load` function in `+layout.server.ts` throws `redirect(307, '/login')` for unauthenticated access; all child routes inherit this guard without repeating the check
- **Progressive enhancement with `use:enhance`** — import `enhance` from `$app/forms` and apply `use:enhance` to `<form>` elements; forms work without JS and upgrade to SPA-style submission when JS is available
- **`$app/*` modules for framework APIs** — use `$app/navigation` (navigate, goto, invalidate), `$app/stores` (page, navigating, updated), `$app/forms` (enhance, applyAction), `$app/environment` (browser, dev, building)
- **Svelte stores for reactive shared state** — use `writable`, `readable`, `derived` from `svelte/store`; prefer component-local `$state` rune (Svelte 5) over global stores when state is not truly shared
- **Typed load data via `$types`** — import `PageLoad`, `PageServerLoad`, `LayoutServerLoad`, `Actions` from `./$types`; let SvelteKit generate types from the route structure rather than writing manual interfaces
- **`error()` and `redirect()` from `@sveltejs/kit`** — call these helpers inside `load` / actions to produce proper HTTP responses (they throw internally; do not wrap in `throw` in 2.x); never construct a raw `Error` for user-facing HTTP responses
- **`GET`/`POST`/`PUT`/`DELETE`/`PATCH` named exports in `+server.ts`** — each export is a `RequestHandler` matching its HTTP method; this is the SvelteKit API endpoint convention (not pages)

## Hard Rules emitted

```
HARD_RULE: Server-only code (DB, secrets, auth) MUST live in +*.server.ts files or $lib/server/
  path_glob: "src/**/*.ts"
  rule_type: CUSTOM
  rationale: SvelteKit's Vite plugin statically enforces the $lib/server boundary; client bundles that import server modules throw a build error; secrets exposure is a security violation

HARD_RULE: Load functions returning page data MUST be exported from +page.ts or +page.server.ts
  path_glob: "src/routes/**/+page*.ts"
  rule_type: NAMING_RULE
  rationale: SvelteKit only wires the load function to the page component when it is exported from the special +page file; a load in a differently-named file is ignored

HARD_RULE: Form action handlers MUST be exported as `export const actions` from +page.server.ts
  path_glob: "src/routes/**/+page.server.ts"
  rule_type: SIGNATURE_RULE
  pattern: 'export\s+const\s+actions'
  rationale: SvelteKit only recognises form actions from the `actions` export; actions in any other export name or file are silently ignored

HARD_RULE: API endpoint files MUST be named +server.ts (not handler.ts, api.ts, etc.)
  path_glob: "src/routes/**"
  rule_type: NAMING_RULE
  pattern: '^\+server\.(ts|js)$'
  rationale: SvelteKit file-based routing only recognises the reserved name +server.ts for HTTP request handlers in a route segment

HARD_RULE: Route page files MUST be named +page.svelte
  path_glob: "src/routes/**"
  rule_type: NAMING_RULE
  pattern: '^\+page\.svelte$'
  rationale: SvelteKit only renders +page.svelte as a navigable route; other Svelte files in routes/ are co-located modules, not pages

HARD_RULE: Private env vars MUST NOT be imported in +page.svelte or files under src/lib/ (non-server)
  path_glob: "src/routes/**/+page.svelte"
  rule_type: CUSTOM
  forbidden_patterns: ["$env/static/private", "$env/dynamic/private"]
  rationale: Private env imports in client-rendered components expose secrets in the browser bundle; use $lib/server/ or +page.server.ts instead

HARD_RULE: The handle hook MUST be exported from src/hooks.server.ts
  path_glob: "src/hooks.server.ts"
  rule_type: SIGNATURE_RULE
  pattern: 'export\s+(?:async\s+)?function\s+handle|export\s+const\s+handle'
  rationale: SvelteKit only calls the handle hook when exported with the name `handle` from hooks.server.ts; a differently-named export is never invoked
```

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — form actions and `+server.ts` handlers validate `await request.formData()` / `request.json()` with `zod` (or `sveltekit-superforms`); the bypass is reading form fields and trusting them — actions and endpoints are plain HTTP surfaces anyone can POST to directly.
- **SQL injection** — Prisma/Drizzle in `$lib/server/` parameterize; string-built SQL with interpolated request values (`$queryRawUnsafe`, concatenated `sql` strings) reintroduces SQLi — use bindings/tagged templates or stay in the ORM query API.
- **XSS / output escaping** — Svelte auto-escapes template expressions; `{@html}` is the bypass and is only valid for content sanitized server-side — never for user input.
- **CSRF** — SvelteKit blocks cross-origin form POSTs by default (`csrf.checkOrigin`); the bypass is setting `csrf: { checkOrigin: false }` in `svelte.config.js` — if you disable it you own token-based protection yourself; cookie-authenticated JSON endpoints in `+server.ts` should also verify origin.
- **AuthN/AuthZ enforcement point** — the `handle` hook in `src/hooks.server.ts` resolves the session and populates `event.locals.user`; each protected `load` / action then checks `locals` and throws `redirect()`. The bypass is checking in the component, or relying solely on a `+layout.server.ts` guard — child loads can run without re-running the layout load, so per-route checks against `locals` are the contract.
- **Password hashing** — `bcrypt`/`argon2` in `$lib/server/` modules; never in client-bundled code, never plain `crypto` hashes.
- **Mass assignment** — the zod schema's parsed output is the field allowlist; the bypass is `Object.fromEntries(await request.formData())` passed straight into a DB write, letting an injected `role` field escalate privileges.
- **Secrets / config** — `$env/static/private` vs `$env/static/public` (`PUBLIC_` prefix) split; the build fails if private env is imported client-side (pack hard rule mirrors this). The bypasses are renaming a secret to `PUBLIC_*` to silence the error, or returning it from a `load` function — load return values ship to the browser.
- **File uploads** — handle in a form action or `+server.ts` with a size cap and mimetype allowlist, stored outside `static/`; never trust the client filename — generate your own.

## Testing conventions

- **Unit test runner**: Vitest — configured via `vite.config.ts` (or `vitest.config.ts`); run with `npx vitest` or `vitest run`
- **Component testing**: `@testing-library/svelte` with `@testing-library/jest-dom` matchers; mount components with `render()` from `@testing-library/svelte`
- **End-to-end testing**: Playwright (`@playwright/test`) — config in `playwright.config.ts`; tests in `tests/` or `e2e/`
- **Test file location**: co-located `*.test.ts` / `*.spec.ts` next to the module, or aggregated under `src/__tests__/`
- **Test naming**: describe/it blocks — `describe('UserCard', () => { it('renders the user name', ...) })`
- **Mocking SvelteKit modules**: use `vi.mock('$app/navigation')`, `vi.mock('$app/stores')` to isolate components from routing APIs in unit tests
- **Server load testing**: call `load()` directly with a mocked `RequestEvent`; assert the returned data shape
- **Form action testing**: call the action function directly with a mocked `RequestEvent`; check returned `ActionResult`
- **Coverage**: `vitest run --coverage`; `c8` or `istanbul` provider via `@vitest/coverage-v8`

## Deep-scan file hints

```yaml
auth_hints:
  - src/hooks.server.ts
  - src/lib/server/auth.ts
  - src/lib/server/auth/
  - src/routes/(auth)/
  - src/routes/login/+page.server.ts
  - svelte.config.js
authz_hints:
  - src/hooks.server.ts
  - src/lib/server/auth.ts
  - src/routes/**/+layout.server.ts
  - src/routes/**/+page.server.ts
ui_hints:
  - src/routes/+layout.svelte
  - src/lib/components/
  - src/app.css
  - tailwind.config.ts
  - tailwind.config.js
  - uno.config.ts
```

## Authz mapping

- `mechanism`: `hook` (handle in `src/hooks.server.ts` populates `event.locals`) + `load-guard` (`+layout.server.ts` / `+page.server.ts` load throws `redirect`/`error` for unauthorized)
- `role_source`: `token` (JWT claims or session token decoded in `handle`) or `db` (role fetched from database in load / hook)
- Construct → `declarations[].kind`:
  - `handle` export in `src/hooks.server.ts` that checks session and sets `event.locals.user` → `{kind: hook, name: handle}`
  - A `+layout.server.ts` or `+page.server.ts` load function that calls `redirect(307, '/login')` or `error(403)` for unauthorized requests → `{kind: load-guard, applies_to: <route segment>}`
  - Role check in load / hook (e.g. `event.locals.user.role === 'admin'`) → `{kind: role, name: <role value>}`

## UI detection

- dominant layout: root `src/routes/+layout.svelte` provides the global shell; nested `+layout.svelte` files layer per-segment layouts — each passes child content via `<slot />` (Svelte 4) or `{@render children()}` (Svelte 5 runes)
- component dir: `src/lib/components/` — shared reusable Svelte components imported via `$lib/components/`
- styling: Tailwind CSS (`tailwind.config.ts` / `src/app.css`) or UnoCSS (`uno.config.ts`) or plain CSS/SCSS co-located with components
- notification call: commonly `svelte-sonner`, `svelte-french-toast`, or a custom toast store — look for import in root `+layout.svelte` or `src/lib/components/`
- icon lib: `lucide-svelte`, `svelte-heroicons`, or `@iconify/svelte`
- rendering model: pages are server-rendered by default (SSR); individual routes can opt into `export const prerender = true` (static), `export const ssr = false` (CSR-only), or `export const csr = false` (server-only)

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "src/lib/utils/**", "src/lib/**" ]
  model_api: [ "src/lib/server/db/**", "src/lib/server/**" ]
  services: [ "src/lib/server/**", "src/lib/services/**" ]
  commands: [ "scripts/**" ]
```
- model_api: data-access functions, query helpers, and typed DB wrappers (e.g. Drizzle/Prisma client wrappers) under `src/lib/server/`.
- commands: build scripts, migration helpers, seed scripts in `scripts/`.
