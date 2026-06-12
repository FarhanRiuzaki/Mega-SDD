---
framework: remix
framework_version_range: "2.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: package.json
  dependency_marker: "@remix-run/"
  version_regex: '"@remix-run/react"\s*:\s*"[\^~]?(\d+)\.'
extends: _universal
pack_tier: full
---

# Remix Convention Pack (2.x)

Conventions for Remix v2 full-stack projects using `@remix-run/*` packages. Extends `_universal.md` — universal defaults apply, Remix-specific rules override on conflict.

> **Routing model**: Remix v2 uses file-based routing under `app/routes/` with a flat, dot-delimited convention — dots in filenames create URL segments (`concerts.$city.tsx` → `/concerts/:city`). Each route file is a self-contained module that can export a `loader` (server data), `action` (server mutation), default component, `ErrorBoundary`, `meta`, and `links`. Nested routes render inside the parent's `<Outlet />`. **React Router 7 direction**: Remix has merged into React Router 7 (packages `react-router` / `@react-router/*`); this pack covers the Remix v2 `@remix-run/*` generation only. React Router 7 projects use a different detection signature.

## File location standards

| Artifact | Path |
|---|---|
| App root layout | `app/root.tsx` |
| Route modules (flat) | `app/routes/*.tsx` (dot-delimited, e.g. `users.$id.tsx`) |
| Route modules (folder) | `app/routes/<segment>/route.tsx` (co-location variant) |
| Index route | `app/routes/_index.tsx` |
| Pathless layout route | `app/routes/_auth.tsx`, `app/routes/_app.tsx` (underscore prefix) |
| Root entry (server) | `app/entry.server.tsx` |
| Root entry (client) | `app/entry.client.tsx` |
| Shared components | `app/components/` |
| Domain models / DB access | `app/models/` |
| Service layer | `app/services/` |
| Utility / helper modules | `app/utils/` |
| Session helpers | `app/session.server.ts` |
| Remix v2 config (Vite) | `vite.config.ts` (with `@remix-run/dev` Vite plugin) |
| Remix v2 config (legacy) | `remix.config.js` (pre-Vite mode) |
| Environment variables | `.env`, `.env.local`, `.env.production` |
| Tests (unit) | `app/**/*.test.tsx` or `app/**/*.spec.tsx` (co-located, Vitest) |
| Tests (e2e) | `tests/` or `e2e/` (Playwright) |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Route file (flat) | dot-delimited segments, kebab segments allowed | `app/routes/concerts.$city.tsx` |
| Route file (folder) | folder named by segment, entry is `route.tsx` | `app/routes/concerts.$city/route.tsx` |
| Index route | `_index.tsx` (underscore-prefixed) | `app/routes/_index.tsx`, `app/routes/concerts._index.tsx` |
| Pathless layout route | leading underscore prefix (no URL segment) | `app/routes/_auth.tsx` (groups `_auth.login.tsx`, `_auth.register.tsx`) |
| Opt-out of parent nesting | trailing underscore on a segment token | `app/routes/concerts_.trending.tsx` |
| Dynamic segment | `$param` prefix | `$city`, `$id` in `concerts.$city.tsx` |
| Splat / catch-all segment | `$` alone | `app/routes/$.tsx` |
| Component filename | PascalCase `.tsx` | `app/components/UserCard.tsx` |
| Component name | PascalCase | `UserCard`, `NavBar` |
| Server-only module | camelCase `.server.ts` suffix | `app/session.server.ts`, `app/utils/auth.server.ts` |
| Hook | camelCase, `use` prefix | `useCurrentUser`, `useCart` |
| Utility / helper | camelCase or kebab-case file | `app/utils/formatDate.ts`, `app/utils/validate.ts` |
| Type / interface | PascalCase | `UserProfile`, `LoaderData` |
| Environment variable | All-caps snake; no client-exposure prefix convention (Remix does not auto-expose env to client) | `DATABASE_URL`, `SESSION_SECRET` |

## Idioms (preferred patterns)

- **Route module as the unit of co-location** — a single route file exports `loader`, `action`, default component, `ErrorBoundary`, `meta`, and `links`; all concerns for that URL live together, not scattered across separate files
- **`loader` for server-side data** — export an `async function loader({ request, params }: LoaderFunctionArgs)` that returns `json(data)` or `redirect(url)`; loaders run server-only on GET and are never bundled to the client
- **`useLoaderData` to consume loader data** — call `useLoaderData<typeof loader>()` in the default component; no client-side fetch needed for initial page data
- **`action` for server-side mutations** — export an `async function action({ request, params }: ActionFunctionArgs)` that reads `request.formData()`, validates, mutates, and returns `json({ errors })` or `redirect(url)`; actions run server-only for non-GET requests
- **`useActionData` for action feedback** — call `useActionData<typeof action>()` to read the action return value in the component; use for validation errors or confirmation messages
- **`<Form>` for progressive-enhancement mutations** — import `Form` from `@remix-run/react` and use it instead of raw `<form>`; it submits to the route's `action` and works without JavaScript, upgrading to SPA behavior when JS is available
- **Nested routes + `<Outlet />`** — parent route renders `<Outlet />` where child route content appears; each layout in the hierarchy owns its own data via its own `loader`; avoid prop-drilling between parent and child routes
- **`json()` and `redirect()` from `@remix-run/node`** — use these helpers in loaders and actions to produce typed HTTP responses; `json(data, { status: 400 })` for errors, `redirect('/path')` for navigation
- **`ErrorBoundary` export for route errors** — export an `ErrorBoundary` component from any route to catch loader/action errors and render a scoped error UI without crashing the whole page
- **`meta` export for page metadata** — export a `meta` function returning an array of `{ title }` / `{ name, content }` / `{ property, content }` descriptors for per-route `<title>` and `<meta>` tags
- **`links` export for route-scoped assets** — export a `links` function returning an array of link descriptors to inject `<link rel="stylesheet">` or other link tags for that route only
- **Session helpers in `app/session.server.ts`** — centralise `createCookieSessionStorage`, `getSession`, `commitSession`, and `requireUserSession` (a loader helper that reads the session and throws `redirect('/login')` if unauthenticated); all loaders/actions import from this module
- **`remix-auth` for OAuth / credential strategies** — use the `remix-auth` library with the `authenticator.authenticate()` pattern in loaders/actions rather than rolling a custom auth pipeline
- **`.server.ts` suffix for server-only modules** — any file with `.server.ts` in its name is excluded from the client bundle by Remix's Vite plugin; use this for DB clients, secret env access, and session utilities

## Hard Rules emitted

```
HARD_RULE: Data loading MUST happen in `loader` exports, not in component useEffect or client-side fetch for initial data
  path_glob: "app/routes/**/*.tsx"
  rule_type: CUSTOM
  rationale: Loaders run server-side and are the Remix data-fetching contract; fetching in useEffect bypasses caching, SSR, and error handling

HARD_RULE: Data mutations MUST happen in `action` exports, not in client-side event handlers calling fetch directly
  path_glob: "app/routes/**/*.tsx"
  rule_type: CUSTOM
  rationale: Actions are the Remix mutation contract; they run server-only, handle revalidation automatically, and support progressive enhancement

HARD_RULE: Server-only code (DB access, secrets, session) MUST live in `*.server.ts` files or inside `loader`/`action` exports
  path_glob: "app/**/*.ts"
  rule_type: CUSTOM
  rationale: Remix's Vite plugin tree-shakes loader/action exports from the client bundle; code outside these boundaries may leak into the browser

HARD_RULE: `<Form>` from `@remix-run/react` MUST be used for mutations, not raw `<form>` submitting to the server
  path_glob: "app/routes/**/*.tsx"
  rule_type: CUSTOM
  rationale: Remix's Form component wires to the route action, enables progressive enhancement, and participates in Remix's navigation/revalidation lifecycle

HARD_RULE: Route modules MUST use dot-delimited filenames or the route.tsx folder convention — no custom file names for route entry points
  path_glob: "app/routes/**"
  rule_type: NAMING_RULE
  pattern: '^[a-z_$][a-z0-9._$-]*\.(tsx|ts|jsx|js)$|^route\.(tsx|ts|jsx|js)$'
  rationale: Remix file-based routing only recognises the flat dot-delimited convention or folder/route.tsx; arbitrary filenames are not wired as routes

HARD_RULE: `app/root.tsx` MUST export a default component rendering `<html>`, `<head>`, `<body>`, and `<Outlet />`
  path_glob: "app/root.tsx"
  rule_type: LOCATION_RULE
  rationale: Remix requires root.tsx as the shell of the entire application; omitting Outlet breaks all child route rendering
```

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — `zod` (or `conform`) parses `request.formData()` and `params` inside every `action`/`loader`; the bypass is reading `formData.get('x')` and trusting it — actions are plain HTTP endpoints anyone can POST to, regardless of what the `<Form>` renders.
- **SQL injection** — Prisma (or the project's ORM) in `app/models/` parameterizes; `$queryRawUnsafe` or string-built SQL with interpolated request values reintroduces SQLi — use tagged-template bindings or stay in the ORM query API.
- **XSS / output escaping** — React auto-escapes JSX output; `dangerouslySetInnerHTML` is the named bypass, valid only for server-sanitized HTML. Also watch user-controlled `href` values rendering `javascript:` URLs.
- **CSRF** — `createCookieSessionStorage` cookies with `secure: true`, `httpOnly: true`, `sameSite: 'lax'` make SameSite the primary defense for `<Form>` POSTs; the bypass is relaxing to `sameSite: 'none'` (or supporting legacy browsers) without adding a token check (e.g. the `remix-utils` CSRF helper) on actions.
- **AuthN/AuthZ enforcement point** — `requireUserSession` / `authenticator.isAuthenticated` called at the top of EVERY `loader` and `action` that needs protection; the bypass is checking in the component — or only in a parent layout loader — child loaders run in parallel and are individually fetchable, so each one must enforce its own check.
- **Password hashing** — `bcrypt`/`argon2` in `*.server.ts` modules (e.g. `app/models/user.server.ts`); never in client-bundled code, never plain `crypto` hashes.
- **Mass assignment** — the zod schema's parsed output is the field allowlist; the bypass is `Object.fromEntries(await request.formData())` passed straight into a DB write, letting an injected `role` field escalate privileges.
- **Secrets / config** — server env lives in `*.server.ts` (excluded from the client bundle); Remix does not auto-expose env to the client, so the leak vector is hand-feeding it: returning a secret from a `loader`'s `json()` payload ships it to the browser — pass only deliberate public values.
- **File uploads** — `unstable_parseMultipartFormData` with a file-upload handler configured with `maxPartSize` and a mimetype allowlist, stored outside `public/`; never trust the client filename.

## Testing conventions

- **Unit / integration runner**: Vitest — configured via `vite.config.ts` or `vitest.config.ts`; run with `npx vitest` or `vitest run`
- **React component testing**: `@testing-library/react` with `@testing-library/jest-dom` matchers; mount components with `render()` from `@testing-library/react`
- **Loader / action unit testing**: call `loader()` or `action()` directly with a mocked `Request` object and `params`; assert the returned `Response` / `json` data without starting a server
- **End-to-end testing**: Playwright (`@playwright/test`) — config in `playwright.config.ts`; tests in `tests/` or `e2e/`
- **Test file location**: co-located `*.test.tsx` / `*.spec.tsx` next to the route or module, or aggregated under `app/__tests__/`
- **Test naming**: describe/it blocks — `describe('loader', () => { it('redirects unauthenticated users', ...) })`
- **Mocking Remix modules**: use `vi.mock('@remix-run/react')` or stub `useLoaderData` return values to isolate components from route data in unit tests
- **Session testing**: create a real or mocked session object via `createCookieSessionStorage` in test helpers; call session utils directly
- **Coverage**: `vitest run --coverage`; `@vitest/coverage-v8` provider

## Deep-scan file hints

```yaml
auth_hints:
  - app/session.server.ts
  - app/utils/auth.server.ts
  - app/utils/session.server.ts
  - app/services/auth.server.ts
  - app/routes/_auth.login.tsx
  - app/routes/login.tsx
authz_hints:
  - app/session.server.ts
  - app/utils/auth.server.ts
  - app/routes/_app.tsx
  - app/routes/_app._index.tsx
ui_hints:
  - app/root.tsx
  - app/components/
  - app/styles/
  - app/tailwind.css
  - tailwind.config.ts
  - tailwind.config.js
```

## Authz mapping

- `mechanism`: `loader-guard` (server-side session checks inside `loader` and `action` exports that throw `redirect` for unauthenticated requests) + `session` (cookie-backed session via `createCookieSessionStorage` from `@remix-run/node`)
- `role_source`: `token` (session data decoded from cookie — e.g. `session.get("userId")`) or `db` (role fetched from database inside loader using the session `userId`)
- Construct → `declarations[].kind`:
  - A `loader` or `action` calling `requireUserSession(request)` or `requireUserId(request)` — throwing `redirect('/login')` if unauthenticated → `{kind: loader-guard, applies_to: <route segment>}`
  - A role check inside a `loader`/`action` (e.g. `requireRole(session, 'admin')`) → `{kind: role, name: <role value>}`
  - `createCookieSessionStorage` export in `app/session.server.ts` → `{kind: session}`

## UI detection

- dominant layout: `app/root.tsx` provides the global shell (renders `<html>`, `<head>`, `<body>`, `<Outlet />`); nested route layouts add per-segment structure via their own default component exporting `<Outlet />`
- component dir: `app/components/` — shared reusable React components imported across routes
- styling: Tailwind CSS (`tailwind.config.ts` / `app/tailwind.css`) or CSS Modules (`*.module.css` co-located with routes) or route-scoped stylesheets via the `links` export
- notification call: commonly `react-hot-toast`, `sonner`, or Radix UI Toast — look for import in `app/root.tsx` or `app/components/`
- icon lib: `lucide-react`, `@heroicons/react`, or `react-icons`
- rendering model: routes are server-rendered by default (SSR); each route's `loader` runs server-side; client hydration adds interactivity; no per-route SSR toggle (unlike SvelteKit) — control rendering via Remix's streaming and `defer`/`Await` for progressive hydration

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "app/utils/**", "app/utils/*.server.ts" ]
  model_api: [ "app/models/**", "app/models/*.server.ts" ]
  services: [ "app/services/**", "app/services/*.server.ts" ]
  commands: [ "scripts/**" ]
```
- model_api: data-access layer functions, DB query helpers, and typed accessors under `app/models/`; may also live in `app/services/` for project structures that skip the models directory.
- commands: build scripts, migration helpers, seed scripts in `scripts/`.
