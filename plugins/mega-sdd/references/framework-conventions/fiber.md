---
framework: fiber
framework_version_range: "2.x — 3.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: go.mod
  dependency_marker: "github.com/gofiber/fiber"
  version_regex: 'github\.com/gofiber/fiber/v(\d+)'
extends: _universal
pack_tier: full
---

# Fiber Convention Pack (2.x — 3.x)

Conventions for Fiber (Go) web/API projects. Extends `_universal.md` — universal defaults apply, Fiber-specific rules override on conflict.

Fiber is an Express-inspired, high-performance HTTP framework built on top of fasthttp (not `net/http`). Go itself is largely unopinionated on project layout. This pack documents the **widely-adopted community project layout** (`cmd/`, `internal/`, `pkg/`) as established by the golang-standards/project-layout community convention, combined with idiomatic Fiber patterns for routing, middleware, and request handling.

**v2 vs v3 note**: v2 (canonical for this pack) uses `*fiber.Ctx` (pointer to struct), `c.BodyParser(&s)`, and imports `github.com/gofiber/fiber/v2/middleware/*`. v3 changes to `fiber.Ctx` (interface, by value), `c.Bind().Body(&s)`, and `github.com/gofiber/fiber/v3/middleware/*`. Handler return-error semantics and the overall API shape are identical across both majors.

## File location standards

| Artifact | Path |
|---|---|
| Application entry point | `cmd/<app>/main.go` |
| Private application packages | `internal/` |
| Handlers (request/response) | `internal/handlers/` or `internal/api/` |
| Middleware | `internal/middleware/` |
| Models / domain structs | `internal/models/` or `internal/domain/` |
| Service / business logic | `internal/service/` |
| Repository / data access | `internal/repository/` |
| Config structs + loader | `internal/config/` |
| Public reusable packages | `pkg/` |
| Router setup | `internal/router/` or inline in `cmd/<app>/main.go` (small apps) |
| Static HTML templates (if any) | `templates/` |
| Static assets | `static/` |
| Module manifest | `go.mod` + `go.sum` |
| Tests | `*_test.go` co-located with the package under test |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Exported identifier | PascalCase | `UserHandler`, `AuthMiddleware`, `UserService` |
| Unexported identifier | camelCase | `fetchUser`, `parseToken`, `dbConn` |
| Package name | lowercase, no underscores | `handlers`, `middleware`, `service` |
| Handler function | PascalCase verb + noun (exported) | `GetUser`, `CreateUser`, `ListOrders` |
| Middleware function | PascalCase, descriptive | `RequireAuth`, `RequireRole`, `RateLimiter` |
| File name | lowercase with underscores or all lowercase | `user_handler.go`, `auth_middleware.go` |
| Test file | same as source + `_test` suffix | `user_handler_test.go` |
| Route path | kebab-case, noun-plural for collections | `/users`, `/user-profiles`, `/api/v1/orders` |
| Environment config key | SCREAMING_SNAKE_CASE in `.env` | `PORT`, `DATABASE_URL`, `JWT_SECRET` |
| Struct field (JSON binding) | camelCase via `json:"..."` tag | `json:"firstName"`, `json:"createdAt"` |

## Idioms (preferred patterns)

- **`fiber.New()` as the engine** — `app := fiber.New()` creates the Fiber instance; pass `fiber.Config{...}` to customize (e.g. `ReadTimeout`, `WriteTimeout`, `ErrorHandler`); `app.Listen(":3000")` starts the fasthttp-backed server; `fiber.New()` is always explicit — there is no "default" convenience constructor like Gin's `gin.Default()`
- **Router groups for API versioning and resource grouping** — `api := app.Group("/api")`, then `v1 := api.Group("/v1")`; `v1.Get("/users", handlers.ListUsers)`; groups share a path prefix and any middleware passed as group-level arguments: `app.Group("/admin", middleware.RequireAuth())`
- **Handler signature `func(c *fiber.Ctx) error`** — every v2 route handler receives a pointer to `fiber.Ctx` and returns `error`; v3 changes the receiver to by-value `fiber.Ctx` (interface), but the `error` return is invariant; returning a non-nil error routes to the centralized `ErrorHandler`
- **Middleware as `fiber.Handler` attached via `app.Use()`** — global middleware: `app.Use(recover.New(), logger.New())`; path-scoped: `app.Use("/api", rateLimiter)`; group-level inline: `app.Group("/admin", requireRole("admin"))` — a Fiber middleware is any `func(c *fiber.Ctx) error` that calls `c.Next()` to continue the chain
- **`c.BodyParser(&struct)` + validator for input** — define request structs with `json:"..."` and `validate:"..."` tags; call `c.BodyParser(&req)` (v2) or `c.Bind().Body(&req)` (v3) to decode the request body into the struct; run an explicit validator (e.g. `go-playground/validator`) or configure `fiber.Config{StructValidator: ...}` for automatic validation on bind; return the error directly on failure
- **`c.JSON()` and `c.Status()` for responses** — `c.JSON(result)` serializes to JSON with `200 OK`; `c.Status(fiber.StatusCreated).JSON(result)` chains status and body; `c.Status(fiber.StatusNoContent).Send(nil)` for empty responses; use typed response structs for consistency over ad-hoc `fiber.Map` maps in non-trivial handlers
- **Centralized `ErrorHandler` in `fiber.Config`** — configure `fiber.Config{ErrorHandler: func(c *fiber.Ctx, err error) error { ... }}` to handle all unhandled errors (including `*fiber.Error` from `fiber.NewError(status, msg)`) in one place; do not scatter error-response logic across handlers
- **fasthttp underpinning** — Fiber sits on fasthttp, not `net/http`; `*fiber.Ctx` is NOT compatible with `http.ResponseWriter`/`*http.Request`; any library that requires `net/http` types must be wrapped or replaced with a Fiber/fasthttp-compatible alternative
- **Built-in middleware via `github.com/gofiber/fiber/v2/middleware/*`** — use the shipped middlewares: `logger`, `recover`, `cors`, `limiter`, `compress`, `cache`, `requestid`; avoid duplicating their functionality; import path changes to `v3` for v3 projects
- **Services injected via struct receivers** — handlers are methods on a handler struct holding service dependencies; wire in `main.go` or a dedicated `internal/wire/` package; `app.Get("/users", h.ListUsers)` registers the bound method as a `fiber.Handler`
- **Thin handlers, fat services** — handlers parse the request and call a service method; all business logic lives in `internal/service/`; handlers stay under ~20 lines per method

## Hard Rules emitted

```
HARD_RULE: Handler functions MUST have the signature func(c *fiber.Ctx) error (v2) or func(c fiber.Ctx) error (v3)
  path_glob: internal/handlers/**/*.go
  rule_type: SIGNATURE_RULE
  pattern: 'func\s+(\([^)]*\)\s+)?\w+\(c\s+\*?fiber\.Ctx\)\s+error'
  rationale: Fiber route handlers must match fiber.Handler; non-conformant signatures cause compile errors and missing returns break the centralized ErrorHandler chain

HARD_RULE: Business logic MUST NOT appear inline in handler functions — delegate to service layer
  path_glob: internal/handlers/**/*.go
  rule_type: CUSTOM
  rationale: Handlers thin + services fat; inline business logic breaks testability and separation of concerns

HARD_RULE: Input from HTTP requests MUST be bound via c.BodyParser (v2) or c.Bind().Body (v3) with a struct carrying validation tags
  path_glob: internal/handlers/**/*.go
  rule_type: CUSTOM
  rationale: Raw c.Query()/c.FormValue() calls bypass struct validation; BodyParser + validator enables consistent, centralized input validation

HARD_RULE: Middleware MUST be of type fiber.Handler and attached via app.Use(), group-level, or route-level registration
  path_glob: internal/middleware/**/*.go
  rule_type: CUSTOM
  rationale: Middleware wired outside the Fiber chain is never executed; direct function calls bypass the middleware stack and the centralized ErrorHandler

HARD_RULE: Private application packages MUST reside under internal/ — not exposed at the repo root
  path_glob: internal/**/*.go
  rule_type: LOCATION_RULE
  rationale: Go enforces internal/ import restriction; placing private packages at the root allows unintended external imports

HARD_RULE: Public reusable library code MUST reside under pkg/ — not mixed into internal/
  path_glob: pkg/**/*.go
  rule_type: LOCATION_RULE
  rationale: Mixing public library code in internal/ makes reuse impossible; pkg/ signals intentional external API
```

## Testing conventions

- **Test runner**: standard `go test ./...` — no test framework required; run from the module root
- **Test file location**: `*_test.go` files co-located with the package under test (e.g. `internal/handlers/user_handler_test.go`)
- **HTTP handler testing via `app.Test(req)`** — Fiber's built-in test helper runs an `*http.Request` directly against the app in-process without opening a TCP socket; create the request with `httptest.NewRequest`, call `app.Test(req)`, and inspect the returned `*http.Response`; this is Fiber's canonical test path (unlike Gin/Echo which use `httptest.NewRecorder`)
- **Table-driven tests**: idiomatic Go pattern — define a slice of `struct{ name, input, expected }` test cases and range over them in a single `t.Run(tc.name, ...)` call
- **Test naming**: `TestFunctionName` (unit) and `TestFunctionName_Scenario` (subtests via `t.Run`); test functions MUST start with `Test`
- **Assertions**: standard `testing` package (`t.Errorf`, `t.Fatalf`); `testify/assert` and `testify/require` are widely used for cleaner assertion syntax (optional dependency)
- **Mocking**: interfaces + hand-rolled mocks or `github.com/stretchr/testify/mock`; define service interfaces so handlers can be tested with mock services
- **Example handler test pattern**:
  ```go
  func TestGetUser(t *testing.T) {
      app := fiber.New()
      h := &UserHandler{svc: &mockUserService{}}
      app.Get("/users/:id", h.GetUser)
      req := httptest.NewRequest(http.MethodGet, "/users/1", nil)
      resp, err := app.Test(req)
      assert.NoError(t, err)
      assert.Equal(t, http.StatusOK, resp.StatusCode)
  }
  ```

## Deep-scan file hints

```yaml
auth_hints:
  - "internal/middleware/auth.go"
  - "internal/middleware/auth_middleware.go"
  - "internal/middleware/jwt.go"
  - "pkg/jwt/**"
  - "internal/config/jwt.go"
authz_hints:
  - "internal/middleware/rbac.go"
  - "internal/middleware/auth*.go"
  - "internal/middleware/role*.go"
  - "internal/middleware/require_role.go"
ui_hints:
  - "templates/"
  - "static/"
```

## Authz mapping

- `mechanism`: `middleware` (role/permission checks applied as `fiber.Handler` middleware on route groups or individual routes)
- `role_source`: `token` (JWT claims decoded in middleware) or `db` (role fetched from DB per request)
- Construct → `declarations[].kind`:
  - An auth middleware (`RequireAuth()`) applied via `app.Use()` or inline on a route/group → `{kind: middleware}`
  - A role-check middleware (`RequireRole("admin")`) applied to a group or route → `{kind: role}`
  - A casbin enforcer middleware applied via `app.Use()` → `{kind: policy}`
- Common patterns:
  - `github.com/gofiber/contrib/jwt` or built-in JWT middleware: token verified in middleware; claims attached to context via `c.Locals("claims", claims)`; downstream handlers retrieve via `c.Locals("claims").(*Claims)` — note `c.Locals` (not `c.Set`/`c.Get`) is the Fiber idiom for passing values between handlers
  - Role-based: role stored in JWT claims or loaded from DB; `RequireRole` factory returns a `fiber.Handler` that checks `c.Locals("user").(*User).Role` and returns `fiber.ErrForbidden` on mismatch
  - Casbin: `internal/middleware/rbac*.go` wires a casbin `Enforcer` with a Fiber-compatible adapter; policy loaded from DB or `policy.csv`

## UI detection

_(N/A: API-only; Views template engine optional)_

If server-rendered HTML is used, detection signals are:

- **Views engine registration**: `fiber.Config{Views: html.New("./templates", ".html")}` (using `github.com/gofiber/template`); templates live under `templates/`
- **Template rendering**: `c.Render("index", fiber.Map{"title": "Home"})` in handlers
- **Static files**: `app.Static("/static", "./static")` mounts a directory; fasthttp serves files directly without `net/http` overhead

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "internal/utils/**", "pkg/**" ]
  model_api: [ "internal/models/**", "internal/domain/**" ]
  services: [ "internal/service/**" ]
  commands: [ "cmd/**" ]
```

- `model_api`: exported structs, methods, and interfaces in each model/domain file; includes ORM model definitions and repository interfaces.
- `services`: exported service interfaces and implementations; each service file exposes the domain API (e.g. `UserService.FindByID`, `OrderService.Create`).
- `commands`: application entry points under `cmd/`; each `main.go` wires dependencies and starts the server or runs a CLI subcommand.
