---
framework: express
framework_version_range: "4.x — 5.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: package.json
  dependency_marker: "express"
  version_regex: '"express"\s*:\s*"[\^~]?(\d+)\.'
extends: _universal
pack_tier: full
---

# Express Convention Pack (4.x — 5.x)

Conventions for Express (Node.js) backend projects. Extends `_universal.md` — universal defaults apply, Express-specific rules override on conflict.

Express is intentionally unopinionated; this pack documents the **widely-adopted community layered architecture**: routes → controllers → services → models, with middleware at each level. Projects may deviate — treat this as the default convention, not a framework-enforced constraint.

## File location standards

| Artifact | Path |
|---|---|
| App entry point | `src/app.js` (app setup) + `src/index.js` (server listen) |
| Route definitions | `src/routes/` |
| Controllers | `src/controllers/` |
| Service / business logic | `src/services/` |
| Data models / ORM | `src/models/` |
| Middleware | `src/middleware/` |
| Config | `src/config/` |
| Utilities / helpers | `src/utils/` or `src/helpers/` |
| Static views (if any) | `views/` (EJS / Pug / Handlebars templates) |
| Static assets | `public/` |
| Tests | `__tests__/` or `*.test.js` co-located, or `test/` |
| Scripts / CLI | `src/scripts/` or `bin/` |

Note: Express enforces none of these paths. Some projects use a flat `routes/`, `controllers/`, etc. at the repo root instead of under `src/`. Detect the actual convention from the codebase; this table is the community default.

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Route file | kebab-case + `.routes.js` suffix | `user.routes.js`, `auth.routes.js` |
| Controller file | kebab-case + `.controller.js` suffix | `user.controller.js` |
| Service file | kebab-case + `.service.js` suffix | `user.service.js` |
| Middleware file | kebab-case + `.middleware.js` suffix (or descriptive name) | `auth.middleware.js`, `requireAuth.js` |
| Model file | PascalCase (ORM class) or kebab-case + `.model.js` | `User.js` (Mongoose) or `user.model.js` (Sequelize) |
| Controller function | camelCase verb + noun | `getUser`, `createUser`, `updateUser`, `deleteUser` |
| Route path | kebab-case, noun-plural for collections | `/users`, `/user-profiles`, `/auth/login` |
| Middleware function | camelCase | `requireAuth`, `validateBody`, `checkRole` |
| Environment config | SCREAMING_SNAKE_CASE in `.env` | `PORT`, `DATABASE_URL`, `JWT_SECRET` |
| Test file | co-located `*.test.js` or `*.spec.js`; or under `__tests__/` | `user.controller.test.js` |

## Idioms (preferred patterns)

- **`express.Router()` for modular routing** — define routes per domain in a Router instance (`src/routes/user.routes.js`), then mount with `app.use('/users', userRouter)` in `src/app.js`
- **Thin controllers, fat services** — controllers parse the request and call a service; business logic lives in `src/services/`; controllers stay to ~10–20 lines per handler
- **Middleware chains via `app.use()`** — global middleware (JSON parsing, CORS, logging, auth) applied at the app level; route-level middleware applied inline: `router.get('/', requireAuth, getUsers)`
- **4-arg error-handling middleware** — centralized error handler declared last in `src/app.js`: `app.use((err, req, res, next) => { ... })`; must have all 4 parameters for Express to recognize it as an error handler
- **Async handler pattern (Express 4)** — wrap async route handlers with try/catch and call `next(err)` on rejection, or use a wrapper utility (`asyncHandler`/`catchAsync`): `const asyncHandler = fn => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next)`
- **Async handler pattern (Express 5)** — async route handlers automatically forward rejected promises to `next(value)`; no wrapper needed: `app.get('/users', async (req, res) => { const users = await userService.list(); res.json(users); })`
- **Input validation via middleware** — use `express-validator` or `joi`/`zod` in a dedicated validation middleware before the controller; never validate inline inside the controller
- **Environment config via `process.env`** — load with `dotenv` in entry point; export a `src/config/index.js` that reads `process.env`; never call `process.env` directly in business logic
- **Centralized error response shape** — error handler emits a consistent JSON envelope `{ status, message, errors? }`; never let raw error objects leak to the response
- **Separate app setup from server listen** — `src/app.js` exports the configured `app`; `src/index.js` calls `app.listen()`; this makes `app` importable in tests without starting a real server

## Hard Rules emitted

```
HARD_RULE: Route files MUST use express.Router() and be mounted in app.js/index.js
  path_glob: src/routes/*.js
  rule_type: CUSTOM
  rationale: Monolithic route definitions on `app` prevent modular testing and scaling

HARD_RULE: Error-handling middleware MUST have exactly 4 parameters (err, req, res, next)
  path_glob: src/app.js
  rule_type: SIGNATURE_RULE
  pattern: '\(err,\s*req,\s*res,\s*next\)'
  rationale: Express identifies error handlers by arity; a 3-arg handler silently swallows errors

HARD_RULE: Route handlers MUST delegate business logic to controllers or services — no inline DB calls in route files
  path_glob: src/routes/*.js
  rule_type: CUSTOM
  forbidden_calls: ['mongoose.model', 'db.query', 'sequelize.query', 'knex(']
  rationale: Business logic in route files is untestable in isolation

HARD_RULE: Input validation MUST be handled in middleware before the controller — not inline in controller functions
  path_glob: src/controllers/*.js
  rule_type: CUSTOM
  rationale: Inline validation couples validation to handler and prevents reuse across routes

HARD_RULE: Centralized error-handling middleware MUST be the last app.use() call in app.js
  path_glob: src/app.js
  rule_type: LOCATION_RULE
  rationale: Express applies middleware in declaration order; error handler registered before routes is never reached

HARD_RULE: process.env MUST NOT be accessed outside src/config/ or the app entry point
  path_glob: src/**/*.js
  rule_type: CUSTOM
  rationale: Direct process.env access in services/controllers makes config untestable and breaks 12-factor isolation
```

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — `zod`/`joi`/`express-validator` in a validation middleware at the route boundary (before the controller); a handler that reads `req.body.x` / `req.query.x` with no validation layer in the chain is the defect — Express validates nothing by itself.
- **SQL injection** — parameterize through the project's driver/ORM (`db.query('SELECT … WHERE id = $1', [id])`, Sequelize/Knex bindings); template-literal SQL (`` `WHERE id = ${id}` ``) or string-concatenated `sequelize.query()`/`knex.raw()` is the escape hatch that reintroduces SQLi — bind params or stay in the builder.
- **XSS / output escaping** — Express gives no autoescape guarantee; it depends on the view engine (EJS `<%= %>` escapes but `<%- %>` is raw; Pug/Handlebars escape by default, `!{}` / triple-stash bypass). `res.send()` of raw user input on an HTML response is reflected XSS — escape at the template, or return JSON.
- **CSRF** — nothing built in; cookie-session apps need a token (double-submit pattern or a maintained `csurf`-style middleware) plus `SameSite=Lax/Strict` cookies. The bypass is any state-changing route authenticated by cookie with no token check — bearer-token-only APIs are the exception.
- **AuthN/AuthZ enforcement point** — `requireAuth` / role middleware in the chain (`router.get('/', requireAuth, checkRole('admin'), handler)`), with `helmet` and global auth applied in `app.js` before route mounting; the bypass smell is a new route added without the middleware, or an ordering bug where auth is registered after the routes it should protect.
- **Password hashing** — `bcrypt` or `argon2` libraries (`bcrypt.hash`/`bcrypt.compare`); `crypto.createHash('sha256')` or homegrown salting is the bypass — never roll your own.
- **Mass assignment** — build writes from an explicit field allowlist (the validation schema's output); `Object.assign(model, req.body)` / `new Model(req.body)` turns request payloads into column writes. Cap payloads with `express.json({ limit })`.
- **Secrets / config** — `dotenv` loaded in the entry point, read only via `src/config/`; never commit `.env`, never hardcode secrets, never read `process.env` in business logic (pack hard rule).
- **File uploads** — `multer` with storage outside the web root (not `public/`), a mimetype/extension allowlist, and size limits; never trust the client filename — generate your own.
- **Session/cookie posture** — `express-session`/`cookie-session` with `secure: true`, `httpOnly: true`, `sameSite` set in production and the secret from env; regenerate the session ID on login to prevent fixation.

## Testing conventions

- **Test runners**: Jest (most common) or Mocha + Chai; detected from `package.json` `devDependencies`
- **HTTP integration testing**: `supertest` — imports the `app` object directly (no live server needed): `const request = require('supertest'); const app = require('../src/app');`
- **Test file location**: `__tests__/` directory mirroring `src/` structure, or co-located `*.test.js` files; both patterns are common
- **Test naming**: `describe('<module> controller', () => { it('GET /users returns 200', ...) })`
- **Fixtures / mocks**: Jest mocks (`jest.mock('../src/services/user.service')`) or Sinon stubs for service layer; use `beforeEach`/`afterEach` for DB setup/teardown
- **Database isolation**: use an in-memory DB (SQLite, `mongodb-memory-server`) or seed/truncate a test DB; never share the production DB
- **Coverage**: `jest --coverage` or `nyc` for Istanbul-based coverage with Mocha
- **Example supertest pattern**:
  ```js
  const request = require('supertest');
  const app = require('../src/app');
  it('GET /users returns list', async () => {
    const res = await request(app).get('/users').set('Authorization', `Bearer ${token}`);
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('data');
  });
  ```

## Deep-scan file hints

```yaml
auth_hints:
  - src/middleware/auth.js
  - src/middleware/auth.middleware.js
  - src/middleware/requireAuth.js
  - src/config/passport.js
  - src/config/jwt.js
  - src/utils/jwt.js
authz_hints:
  - src/middleware/role.js
  - src/middleware/rbac.js
  - src/middleware/authorize.js
  - src/middleware/checkRole.js
  - src/middleware/permissions.js
ui_hints:
  - views/
  - views/layouts/
  - views/partials/
  - public/js/
  - public/css/
```

## Authz mapping

- `mechanism`: `middleware` (role/permission checks applied as middleware on route definitions)
- `role_source`: `token` (JWT claims) or `db` (role fetched from DB on each request)
- Construct → `declarations[].kind`:
  - A middleware function applied to a router or route (e.g. `requireAuth`, `isAuthenticated` from Passport.js) → `{kind: middleware}`
  - A role-check middleware (e.g. `requireRole('admin')`, `checkPermission('read:users')`) → `{kind: role}`
  - A JWT-verify middleware (`jwt.verify(token, secret)` in middleware) → `{kind: middleware, sub: jwt}`
  - A Passport strategy (`passport.use(new JwtStrategy(...))` / `passport.use(new LocalStrategy(...))`) → `{kind: middleware, sub: passport-strategy}`
- Common patterns:
  - `jsonwebtoken`: `jwt.verify(token, process.env.JWT_SECRET)` in middleware; decoded payload attached to `req.user`
  - `passport` + `passport-jwt`: strategy registered in `src/config/passport.js`; `passport.authenticate('jwt', { session: false })` used as middleware on protected routes
  - RBAC: role stored on `req.user.role` (from JWT claim or DB lookup); a `requireRole` factory function returns middleware that checks `req.user.role`

## UI detection

_(N/A: typically API-only; view engine optional)_

If a view engine is configured (`app.set('view engine', 'ejs')` / `'pug'` / `'hbs'`), detection signals are:

- **Template directory**: `views/` (Express default; overridden via `app.set('views', ...)`)
- **Layout detection**: check `views/layouts/` for layout templates (common with `express-handlebars`); for EJS/Pug layouts look for a `layout.ejs` / `layout.pug` in `views/`
- **View engine declared in**: `src/app.js` — `app.set('view engine', '<engine>')`

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "src/utils/**", "src/helpers/**" ]
  model_api: [ "src/models/**" ]
  services: [ "src/services/**" ]
  commands: [ "src/scripts/**", "bin/**" ]
```

- `model_api`: exported model methods, static finders, instance methods, and middleware hooks on each ORM model.
- `services`: exported service functions/classes; each service file exposes the domain API (e.g. `userService.findById`, `userService.create`).
- `commands`: standalone scripts under `src/scripts/` and CLI entry points under `bin/`; check for a `scripts` field in `package.json`.
