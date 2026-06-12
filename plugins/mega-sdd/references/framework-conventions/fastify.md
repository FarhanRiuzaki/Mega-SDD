---
framework: fastify
framework_version_range: "4.x — 5.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: package.json
  dependency_marker: "fastify"
  version_regex: '"fastify"\s*:\s*"[\^~]?(\d+)\.'
extends: _universal
pack_tier: full
---

# Fastify Convention Pack (4.x — 5.x)

Conventions for Fastify (Node.js) backend projects. Extends `_universal.md` — universal defaults apply, Fastify-specific rules override on conflict.

Fastify is an opinionated, plugin-based framework: every feature extension — routes, decorators, hooks, services — is registered as an encapsulated plugin via `fastify.register()`. Encapsulation is the load-bearing primitive; scope isolation is enforced automatically within registered plugin contexts.

## File location standards

| Artifact | Path |
|---|---|
| App factory | `src/app.js` (exports a `buildApp()` function; no direct listen call) |
| Server entry point | `src/server.js` (imports app factory; calls `fastify.listen()`) |
| Route plugins | `src/routes/` (one plugin file per resource, autoloaded via `@fastify/autoload`) |
| Application plugins | `src/plugins/` (decorators, database connections, auth, third-party integrations) |
| Service / business logic | `src/services/` |
| JSON Schema definitions | `src/schemas/` |
| Config | `src/config/` |
| Utilities / helpers | `src/utils/` or `src/helpers/` |
| Tests | `test/` (or `__tests__/`) with `*.test.js` files; node:test or tap is typical |

Note: Fastify does not enforce a directory layout. Projects generated with `fastify-cli` (`fastify generate`) emit the `src/plugins/` + `src/routes/` split with `@fastify/autoload`; this table documents that convention as the community default. Detect the actual layout from the codebase.

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Route plugin file | kebab-case + `.js` (or `.ts`) | `users.js`, `auth.js`, `user-profiles.js` |
| Application plugin file | kebab-case + `.js` describing the capability | `jwt.js`, `db.js`, `sensible.js` |
| Schema file | kebab-case + `.schema.js` or inline `const schema = {}` | `user.schema.js` |
| Decorator name | camelCase on `fastify` instance | `fastify.authenticate`, `fastify.dbClient` |
| Request decorator | camelCase on `request` | `request.user`, `request.session` |
| Reply decorator | camelCase on `reply` | `reply.sendError` |
| Route handler function | camelCase verb + noun | `getUser`, `createUser`, `listOrders` |
| Route URL | kebab-case, noun-plural for collections | `/users`, `/user-profiles`, `/auth/login` |
| Schema id | camelCase or PascalCase string | `UserBody`, `CreateUserResponse` |
| Test file | `*.test.js` or `*.spec.js` | `users.test.js`, `auth.test.js` |
| Environment config | SCREAMING_SNAKE_CASE in `.env` | `PORT`, `DATABASE_URL`, `JWT_SECRET` |

## Idioms (preferred patterns)

- **`fastify()` instance as the root context** — create the Fastify instance once (typically in `buildApp()` in `src/app.js`); never call `fastify.listen()` inside the app factory; separate startup from construction so the instance is injectable into tests
- **`fastify.register()` for everything** — all extension points (route groups, decorators, hooks, database clients) are registered as plugins; `fastify.register(plugin, { prefix: '/api/v1' })` to prefix a route group
- **Plugin encapsulation for scope isolation** — a plugin registered with `fastify.register()` creates a new child scope; decorators and hooks added inside that scope are invisible to the parent and sibling scopes; use `fastify-plugin` (`fp()`) to escape encapsulation and share a decorator with the whole application
- **Route definitions with JSON Schema validation** — declare `schema: { body, querystring, params, headers, response }` on every route; Fastify compiles schemas with `ajv` at startup and rejects non-conforming requests before the handler runs; response schemas also accelerate JSON serialization
- **Async handlers with `return`** — prefer `async (request, reply) => { return payload; }` over calling `reply.send()`; returned values are automatically serialized; `async` handlers catch thrown errors and forward them to the error handler
- **Lifecycle hooks for cross-cutting concerns** — use `fastify.addHook('onRequest', handler)` for authentication (runs before body parsing), `fastify.addHook('preHandler', handler)` for authorization or request decoration (runs after parsing, before the route handler), `fastify.addHook('onSend', handler)` for response manipulation
- **`fastify.decorate()` for application-wide services** — attach a database client, auth utility, or configuration object to the Fastify instance with `fastify.decorate('dbClient', client)`; accessible in any route handler as `fastify.dbClient`; use `fastify.decorateRequest()` / `fastify.decorateReply()` for per-request/reply fields
- **`@fastify/autoload` for filesystem-based loading** — register all plugins in `src/plugins/` and all routes in `src/routes/` in one call per directory; file names map to URL prefixes automatically; avoids manual import chains
- **`@fastify/sensible` for sane defaults** — adds HTTP error helpers (`reply.notFound()`, `reply.badRequest()`), `reply.vary()`, and `assert`; effectively a recommended utility layer
- **`@fastify/jwt` + `onRequest` hook for authentication** — register `@fastify/jwt` as an application plugin; add `fastify.decorate('authenticate', async (request, reply) => { await request.jwtVerify() })` and attach it via `onRequest` on protected routes
- **Separate `src/plugins/` from `src/routes/`** — plugins in `src/plugins/` are loaded first (decorators, DB, auth); routes in `src/routes/` depend on those decorators being available; `@fastify/autoload` respects this loading order when both directories are registered in order in the app factory
- **Never add business logic directly to route handlers** — route handlers call `src/services/` functions; handlers stay to ~5–15 lines; services are plain functions or classes, not Fastify-aware

## Hard Rules emitted

```
HARD_RULE: Route handlers MUST declare a JSON Schema on the route's schema property (body, querystring, params, or response as applicable)
  path_glob: src/routes/**/*.js
  rule_type: CUSTOM
  rationale: Fastify compiles schemas with ajv at startup; routes without schemas bypass input validation and lose the serialization performance benefit

HARD_RULE: Application plugins that must be accessible outside their registration scope MUST be wrapped with fastify-plugin (fp())
  path_glob: src/plugins/**/*.js
  rule_type: CUSTOM
  rationale: Without fastify-plugin, a decorator added inside fastify.register() is encapsulated to that scope and invisible to route plugins registered at the root level

HARD_RULE: Route handlers MUST be async functions returning a value — reply.send() is forbidden in async handlers
  path_glob: src/routes/**/*.js
  rule_type: SIGNATURE_RULE
  pattern: 'async\s*\(request,\s*reply\)'
  rationale: Mixing async return with reply.send() causes double-send errors; returned values are serialized automatically

HARD_RULE: Cross-cutting concerns (authentication, authorization, logging) MUST use lifecycle hooks (onRequest, preHandler) — not inline logic in route handlers
  path_glob: src/routes/**/*.js
  rule_type: CUSTOM
  rationale: Inline auth/authz in handlers cannot be reused across routes and couples transport concerns to domain logic

HARD_RULE: Route plugins MUST NOT directly access a database — service functions in src/services/ MUST be called instead
  path_glob: src/routes/**/*.js
  rule_type: CUSTOM
  forbidden_calls: ['mongoose.model', 'db.query', 'knex(', 'prisma.']
  rationale: Database calls in route handlers are untestable in isolation and bypass the service layer

HARD_RULE: process.env MUST NOT be accessed outside src/config/ or the app entry point
  path_glob: src/**/*.js
  rule_type: CUSTOM
  rationale: Direct process.env access in services or route handlers makes config untestable and breaks 12-factor isolation
```

## Testing conventions

- **Test runner**: `node:test` (preferred for Fastify 5.x projects; zero extra deps) or `tap` (classic Fastify community choice); Jest is used in some projects
- **HTTP injection**: `fastify.inject()` — sends a simulated HTTP request directly against the Fastify instance without opening a real socket; returns a response object; no `supertest` or live server needed
- **App factory pattern**: export a `buildApp()` function from `src/app.js` that accepts options and returns a configured Fastify instance; tests call `buildApp()` directly
- **Test file location**: `test/` directory mirroring `src/routes/` structure, or co-located `*.test.js` files; both patterns are common
- **Test naming**: `describe('<resource>', () => { it('GET /users returns 200', ...) })` (Jest/tap) or `test('GET /users returns 200', ...)` (node:test)
- **Lifecycle**: always call `await fastify.close()` in `after()` / teardown to release plugin connections and avoid open-handle warnings
- **Example node:test + inject pattern**:
  ```js
  const { test } = require('node:test')
  const buildApp = require('../src/app')

  test('GET /users returns list', async (t) => {
    const fastify = buildApp()
    t.after(() => fastify.close())
    const res = await fastify.inject({ method: 'GET', url: '/users', headers: { authorization: 'Bearer <token>' } })
    t.assert.strictEqual(res.statusCode, 200)
    t.assert.deepStrictEqual(JSON.parse(res.body).data, [])
  })
  ```
- **Mocking services**: replace service modules with stubs before calling `buildApp()`; use `fastify.decorate` overrides or dependency injection via plugin options to inject mock clients

## Deep-scan file hints

```yaml
auth_hints:
  - "src/plugins/jwt.js"
  - "src/plugins/auth.js"
  - "src/plugins/authenticate.js"
  - "src/hooks/authenticate.js"
authz_hints:
  - "src/plugins/rbac.js"
  - "src/hooks/authorize.js"
  - "src/routes/admin.js"
ui_hints: []
```

## Authz mapping

- `mechanism`: `hook` (authentication via `onRequest` hook) + `decorator` (`fastify.decorate('authenticate', ...)` registered as a reusable hook)
- `role_source`: `token` (JWT claims decoded by `@fastify/jwt`) or `db` (role fetched from DB inside a `preHandler` hook)
- Construct → `declarations[].kind`:
  - An `onRequest` hook that calls `request.jwtVerify()` (e.g. `fastify.authenticate`) → `{kind: hook, sub: auth}`
  - A `preHandler` hook that checks `request.user.role` or performs RBAC lookup → `{kind: role}`
  - `fastify.decorate('authenticate', async (request, reply) => { await request.jwtVerify() })` → `{kind: hook, sub: auth}`
  - A `preHandler` factory returning a role-check hook (e.g. `requireRole('admin')`) → `{kind: role}`

## UI detection

_(N/A: API-only; `@fastify/view` templating optional)_

Fastify is an API-first framework with no built-in template rendering. `@fastify/view` (supporting Handlebars, EJS, Pug, Nunjucks) is available but uncommon; when present, detect template directories from the `@fastify/view` options (`root` option, defaults to `./views`).

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "src/utils/**", "src/helpers/**" ]
  model_api: [ "src/services/**", "src/schemas/**" ]
  services: [ "src/services/**" ]
  commands: [ "src/scripts/**", "bin/**" ]
```

- `model_api`: service modules in `src/services/` expose the domain API; schema definitions in `src/schemas/` define the data shapes (used both for validation and documentation).
- `services`: exported service functions or classes; each file exposes the domain operations (e.g. `userService.findById`, `userService.create`).
- `commands`: standalone scripts under `src/scripts/` and CLI entry points under `bin/`; check for a `scripts` field in `package.json`.
