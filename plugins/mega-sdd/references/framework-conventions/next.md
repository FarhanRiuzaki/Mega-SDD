---
framework: next
framework_version_range: "14.x — 15.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: package.json
  dependency_marker: "next"
  version_regex: '"next"\s*:\s*"[\^~]?(\d+)\.'
extends: _universal
pack_tier: full
---

# Next.js Convention Pack (14.x — 15.x)

Conventions for Next.js full-stack projects. Extends `_universal.md` — universal defaults apply, Next.js-specific rules override on conflict.

> **Router default**: App Router (`app/`) is the standard as of Next.js 13+. Pages Router (`pages/`) is the legacy alternative — still supported, noted inline below where conventions diverge.

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

## Hard Rules emitted

```
HARD_RULE: Every Client Component file MUST have "use client" as the FIRST non-comment line
  path_glob: components/**/*.tsx
  rule_type: CUSTOM
  rationale: Without the directive, React/Next.js treats the file as a Server Component; browser APIs and useState/useEffect will throw at runtime

HARD_RULE: Server Actions MUST be in files with "use server" directive OR in async functions tagged "use server"
  path_glob: app/**/*.ts
  rule_type: CUSTOM
  rationale: Server Actions without the directive run as Client-side code, exposing server logic or causing runtime errors

HARD_RULE: Route Handler files MUST be named route.ts (not handler.ts, api.ts, etc.)
  path_glob: app/**/route.ts
  rule_type: NAMING_RULE
  pattern: '^route\.(ts|js)$'
  rationale: Next.js file-based routing only recognizes the reserved name route.ts for HTTP handlers

HARD_RULE: Page files MUST be named page.tsx (not index.tsx, component.tsx, etc.) in the App Router
  path_glob: app/**/page.tsx
  rule_type: NAMING_RULE
  pattern: '^page\.(tsx|jsx|ts|js)$'
  rationale: Next.js App Router only renders the reserved filename page.tsx as a route; other filenames are treated as co-located modules, not routes

HARD_RULE: Secrets MUST NOT be used in Client Components or client-side code
  path_glob: components/**/*.tsx
  rule_type: CUSTOM
  forbidden_patterns: ['process.env.DATABASE_URL', 'process.env.SECRET_', 'process.env.PRIVATE_']
  rationale: Anything in a Client Component is bundled into the browser; only NEXT_PUBLIC_ env vars are safe for client consumption

HARD_RULE: Data mutations MUST go through Server Actions or Route Handlers, not direct DB calls from Client Components
  path_glob: app/**/*.tsx
  rule_type: CUSTOM
  rationale: Client Components cannot securely access databases or secrets; mutations must be server-side

HARD_RULE: The root layout MUST be app/layout.tsx and MUST include <html> and <body> tags
  path_glob: app/layout.tsx
  rule_type: LOCATION_RULE
  rationale: Next.js requires a root layout that wraps all routes and supplies the html/body shell
```

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — `zod` parse at the server boundary: inside every Server Action (`formData` → schema) and Route Handler (`await request.json()` → schema); the bypass is trusting the payload shape because "the form only sends these fields" — client-side validation is not validation, both surfaces are directly callable.
- **SQL injection** — Prisma/Drizzle parameterize; `prisma.$queryRawUnsafe` or building SQL with string concatenation inside a tagged template reintroduces SQLi — use the tagged-template bindings (`sql\`… ${v}\``) or stay in the ORM query API.
- **XSS / output escaping** — React auto-escapes JSX output; `dangerouslySetInnerHTML` is the named bypass, valid only for server-sanitized HTML. Also watch user-controlled `href` values rendering `javascript:` URLs.
- **CSRF** — Server Actions have built-in origin checking (POST-only + Origin/Host match); Route Handlers do NOT — a cookie-authenticated handler needs `SameSite` cookies plus an explicit origin check. The bypass is a state-changing Route Handler (or a mutating GET) that trusts cookies with no origin/token check.
- **AuthN/AuthZ enforcement point** — `middleware.ts` for coarse redirects, but real authorization is the session check inside each Route Handler, Server Action, and data-access function; the classic bypass is protecting only the page UI (or only middleware) while the API route and server action underneath stay open to direct requests.
- **Password hashing** — `bcrypt`/`argon2` in server-only code (Server Actions, Route Handlers, `lib/` server modules); never imported into a `"use client"` file.
- **Mass assignment** — the zod schema's parsed output is the field allowlist; the bypass is `Object.fromEntries(formData)` or a raw body passed straight into `prisma.user.update({ data })`, letting an extra `role` field escalate privileges.
- **Secrets / config** — anything prefixed `NEXT_PUBLIC_` is compiled into the client bundle; server secrets stay unprefixed and are read only in server code. The bypass is importing a server-env module from a `"use client"` component, or "temporarily" renaming a secret to `NEXT_PUBLIC_` to make a build pass (pack hard rule).
- **File uploads** — handle uploads server-side only (Route Handler/Server Action) with size caps and a mimetype allowlist, stored outside `public/`; for `next/image` remote sources, constrain `images.remotePatterns` in `next.config` so the optimizer is not an open image proxy.

## Testing conventions

- **Unit / integration runner**: Jest (common default) or Vitest — configured via `jest.config.ts` / `vitest.config.ts`
- **React component testing**: React Testing Library (`@testing-library/react`) + `@testing-library/jest-dom` for DOM matchers
- **End-to-end testing**: Playwright (`@playwright/test`) — config in `playwright.config.ts`; tests in `e2e/` or `tests/e2e/`
- **Test file location**: co-located `ComponentName.test.tsx` next to the component, or aggregated under `__tests__/`
- **Test naming**: describe/it blocks — `describe('UserCard', () => { it('renders user name', ...) })`
- **Server Component testing**: render with React's `renderToString` or wrap with a test `Suspense` boundary; mock `next/navigation` and `next/headers` modules
- **Mocking next modules**: use `jest.mock('next/navigation')` / `jest.mock('next/headers')` to isolate components from Next.js routing/cookie APIs in unit tests
- **MSW (Mock Service Worker)**: common choice for intercepting `fetch` calls in integration tests without a real server
- **Coverage**: `jest --coverage` or `vitest run --coverage`; `lcov` format for CI integration

## Deep-scan file hints

```yaml
auth_hints:
  - middleware.ts                        # auth redirect / session check at edge
  - app/api/auth/[...nextauth]/route.ts  # NextAuth v4 catch-all handler
  - auth.ts                              # Auth.js v5 (NextAuth v5) config file
  - lib/auth.ts                          # common location for auth helpers
  - lib/session.ts                       # session utilities
  - next.config.ts                       # may include auth provider config
authz_hints:
  - middleware.ts                        # matcher-based route protection
  - lib/auth.ts                          # role/permission check helpers
  - app/api/auth/                        # auth route handlers
  - components/providers/               # session/auth context providers
ui_hints:
  - app/layout.tsx                       # root layout (global shell)
  - app/**/layout.tsx                    # nested layouts
  - components/                          # shared component library
  - app/globals.css                      # global CSS entry point
  - tailwind.config.ts                   # Tailwind CSS config
  - tailwind.config.js                   # Tailwind CSS config (JS variant)
```

## Authz mapping

- `mechanism`: `middleware` (middleware.ts matcher-based route guards) + `route-guard` (server-side checks in page/layout/route handler)
- `role_source`: `token` (JWT claims / session token — e.g. NextAuth session role field) or `db` (role fetched from database in server-side check)
- Construct → `declarations[].kind`:
  - `middleware.ts` matcher config protecting a set of routes → `{kind: route-guard, applies_to: <matcher pattern>}`
  - Session-role check in a Server Component or Route Handler (`session.user.role === 'admin'`) → `{kind: role, name}`
  - NextAuth / Auth.js `callbacks.jwt` or `callbacks.session` injecting role into token → `{kind: role, name}`
  - Custom `withAuth` HOC or layout-level auth check → `{kind: route-guard}`

## UI detection

- dominant layout: `app/layout.tsx` (root) provides the global shell; nested `app/**/layout.tsx` for per-segment layouts
- component dir: `components/` — shared reusable React components
- styling: Tailwind CSS (`tailwind.config.ts` / `app/globals.css`) or CSS Modules (`*.module.css` co-located with components)
- notification call: commonly `react-hot-toast`, `sonner`, or Radix UI `Toast` — look for import in `components/providers/` or root layout
- icon lib: `lucide-react` (most common with shadcn/ui), `@heroicons/react`, or `react-icons`
- rendering model: components under `app/` are Server Components by default; interactive leaves that need state, effects, or browser APIs are Client Components (`"use client"` directive at the top of the file)

## Reuse discovery

```yaml
reuse_hints:
  helpers:  [ "lib/**", "utils/**" ]
  model_api: [ "lib/db/**", "lib/models/**", "app/models/**" ]
  services: [ "lib/services/**", "lib/actions/**" ]
  commands: [ "scripts/**" ]
```
- model_api: data-access layer functions and types (Prisma client wrappers, query helpers, typed DB accessors).
- commands: build scripts, migration helpers, seed scripts in `scripts/`.
