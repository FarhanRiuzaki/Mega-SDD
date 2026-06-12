---
framework: echo
framework_version_range: "4.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: go.mod
  dependency_marker: "github.com/labstack/echo"
  version_regex: 'github\.com/labstack/echo/v(\d+)'
extends: _universal
pack_tier: full
---

# Echo Convention Pack (4.x)

Conventions for Echo (Go) web/API projects. Extends `_universal.md` — universal defaults apply, Echo-specific rules override on conflict.

Echo is a thin, high-performance HTTP framework; Go itself is largely unopinionated on project layout. This pack documents the **widely-adopted community project layout** (`cmd/`, `internal/`, `pkg/`) as established by the golang-standards/project-layout community convention, combined with idiomatic Echo v4 patterns for routing, middleware, and request handling.

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

- **`echo.New()` as the engine** — `e := echo.New()` creates the Echo instance; attach all routes and middleware to the returned `*echo.Echo`; optionally assign `e.HideBanner = true` and `e.HidePort = true` for production
- **Router groups for API versioning and resource grouping** — `v1 := e.Group("/api/v1")`, then `v1.GET("/users", handlers.ListUsers)`; groups share middleware and prefix, reducing repetition; nest groups freely: `admin := v1.Group("/admin")`
- **Handler functions take `echo.Context` (interface, by value) and return `error`** — every route handler has the signature `func(c echo.Context) error`; the context carries request, response writer, path params, query params, and bound data; this is a key distinction from Gin's `func(c *gin.Context)` (no pointer, no return value)
- **Middleware as `echo.MiddlewareFunc` attached via `e.Use()` or group/route-level registration** — global middleware: `e.Use(middleware.Logger())`, `e.Use(middleware.Recover())`; group middleware: `admin := e.Group("/admin", middleware.JWT(secret))`; route-level: `e.GET("/profile", handlers.GetProfile, middleware.JWT(secret))`
- **`echo.MiddlewareFunc` wraps the next handler** — a middleware is `func(next echo.HandlerFunc) echo.HandlerFunc`; inside, `return next(c)` continues the chain; return an error to abort without calling next
- **`c.Bind(&req)` + `c.Validate(&req)` for input** — define request structs with `validate:"..."` tags (using `go-playground/validator`); register a custom validator via `e.Validator`; `c.Bind` decodes JSON/form/query into the struct; `c.Validate` runs the validator; both return an error on failure
- **JSON responses via `c.JSON()`** — `c.JSON(http.StatusOK, result)` or `c.JSON(http.StatusCreated, responseStruct)`; use typed response structs for consistency over ad-hoc maps
- **Return errors to the centralized HTTPErrorHandler** — handlers return errors (`return echo.NewHTTPError(http.StatusUnauthorized, "unauthorized")`) instead of writing the response directly; `e.HTTPErrorHandler = customHandler` where the v4 signature is `func(err error, c echo.Context)` receives all unhandled errors centrally
- **Context propagation via `c.Set()` / `c.Get()`** — middleware passes values to downstream handlers (e.g. authenticated user) via `c.Set("user", user)` and `c.Get("user").(*User)` — prefer typed wrappers over raw string keys
- **Services injected via struct receivers** — handlers are methods on a handler struct that holds service dependencies; wire dependencies in `main.go` or a dedicated `internal/wire/` package (Wire codegen optional)
- **Thin handlers, fat services** — handlers parse the request and call a service method; all business logic lives in `internal/service/`; handlers stay under ~20 lines per method

## Hard Rules emitted

```
HARD_RULE: Handler functions MUST have the signature func(c echo.Context) error
  path_glob: internal/handlers/**/*.go
  rule_type: SIGNATURE_RULE
  pattern: 'func\s+(\([^)]*\)\s+)?\w+\(c\s+echo\.Context\)\s+error'
  rationale: Echo v4 route handlers must match echo.HandlerFunc (interface by value, returns error); non-conformant signatures cause compile errors and are the primary distinction from Gin

HARD_RULE: Business logic MUST NOT appear inline in handler functions — delegate to service layer
  path_glob: internal/handlers/**/*.go
  rule_type: CUSTOM
  rationale: Handlers thin + services fat; inline business logic breaks testability and separation of concerns

HARD_RULE: Input from HTTP requests MUST be bound via c.Bind with a struct and validated via c.Validate or an explicit validator call
  path_glob: internal/handlers/**/*.go
  rule_type: CUSTOM
  rationale: Raw c.QueryParam()/c.FormValue() calls bypass input validation; struct binding + validate enables consistent, centralized validation

HARD_RULE: Middleware MUST be of type echo.MiddlewareFunc and attached via e.Use(), group-level, or route-level registration
  path_glob: internal/middleware/**/*.go
  rule_type: CUSTOM
  rationale: Middleware registered outside the echo chain is never executed; direct injection bypasses the middleware stack

HARD_RULE: Private application packages MUST reside under internal/ — not exposed at the repo root
  path_glob: internal/**/*.go
  rule_type: LOCATION_RULE
  rationale: Go enforces internal/ import restriction; placing private packages at the root allows unintended external imports

HARD_RULE: Public reusable library code MUST reside under pkg/ — not mixed into internal/
  path_glob: pkg/**/*.go
  rule_type: LOCATION_RULE
  rationale: Mixing public library code in internal/ makes reuse impossible; pkg/ signals intentional external API
```

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — `c.Bind(&req)` then `c.Validate(&req)` against `validate:"..."` tags via the registered `e.Validator`; the bypass is calling `Bind` without `Validate` — Echo does NOT auto-validate on bind — or reading raw `c.QueryParam()`/`c.FormValue()` strings that no tag ever sees.
- **SQL injection** — `database/sql` placeholders (`db.QueryContext(ctx, "... WHERE id = ?", id)`), sqlx, or GORM method chains parameterize automatically; `fmt.Sprintf`-interpolated SQL passed to `db.Query` or `gorm.Raw` is the classic Go SQLi escape hatch — bind params or stay in the builder.
- **XSS / output escaping** — a `TemplateRenderer` backed by `html/template` contextually auto-escapes in `c.Render`; using `text/template` for HTML, casting user input to `template.HTML(...)`, or writing user input through `c.HTML(code, rawString)`/`c.HTMLBlob` emits it unescaped — those are the XSS bypasses.
- **CSRF** — Echo ships `middleware.CSRF()` (labstack token middleware); apply it to cookie/session-authenticated route groups — a state-changing cookie-auth route registered outside the CSRF-wrapped group is the hole; pure bearer-token APIs are CSRF-immune but still want `SameSite` on any auth cookie that creeps in.
- **AuthN/AuthZ enforcement point** — auth is `echo.MiddlewareFunc` on groups (`admin := e.Group("/admin", echojwt.WithConfig(cfg), middleware.RequireRole("admin"))`); the bypass is a route registered on `e` beside the protected group instead of inside it — group membership IS the protection, so audit every registration site.
- **Password hashing** — `golang.org/x/crypto/bcrypt` (`bcrypt.GenerateFromPassword`) or argon2id; a fast hash (`crypto/sha256`, md5) over a password is the brute-forceable bypass, and hand-rolled `==` comparison leaks timing where `bcrypt.CompareHashAndPassword` does not.
- **Mass assignment** — `c.Bind` into the persistence/GORM model makes every field client-settable (`role`, `isAdmin`, `id`); bind a dedicated request struct with only the intended fields and map explicitly to the model — binding the DB model is the over-posting bypass.
- **Secrets / config** — `os.Getenv` or viper-loaded config in `internal/config/`; the bypass is a hardcoded JWT secret or DSN literal in source, or a committed `.env` — keep `.env` gitignored and fail fast at startup when a required secret is empty.
- **File uploads** — cap request size with Echo's `middleware.BodyLimit("2M")`, allowlist both extension AND sniffed content type (`http.DetectContentType`) on the `c.FormFile` result, and store under a server-generated name outside any `e.Static`-served directory; trusting the client-supplied filename invites path traversal, and saving into `static/` makes the upload directly retrievable — those are the bypasses.

## Testing conventions

- **Test runner**: standard `go test ./...` — no test framework required; run from the module root
- **Test file location**: `*_test.go` files co-located with the package under test (e.g. `internal/handlers/user_handler_test.go`)
- **HTTP handler testing**: `net/http/httptest` — create a `httptest.NewRecorder()`, build a context via `e.NewContext(req, rec)`, and call the handler directly; or spin up `httptest.NewServer(e)` for integration tests
- **Table-driven tests**: idiomatic Go pattern — define a slice of `struct{ name, input, expected }` test cases and range over them in a single `t.Run(tc.name, ...)` call
- **Test naming**: `TestFunctionName` (unit) and `TestFunctionName_Scenario` (subtests via `t.Run`); test functions MUST start with `Test`
- **Assertions**: standard `testing` package (`t.Errorf`, `t.Fatalf`); `testify/assert` and `testify/require` are widely used for cleaner assertion syntax (optional dependency)
- **Mocking**: interfaces + hand-rolled mocks or `github.com/stretchr/testify/mock`; define service interfaces so handlers can be tested with mock services
- **Example handler test pattern**:
  ```go
  func TestGetUser(t *testing.T) {
      e := echo.New()
      req := httptest.NewRequest(http.MethodGet, "/users/1", nil)
      rec := httptest.NewRecorder()
      c := e.NewContext(req, rec)
      c.SetParamNames("id")
      c.SetParamValues("1")
      h := &UserHandler{svc: &mockUserService{}}
      if assert.NoError(t, h.GetUser(c)) {
          assert.Equal(t, http.StatusOK, rec.Code)
      }
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

- `mechanism`: `middleware` (role/permission checks applied as `echo.MiddlewareFunc` on route groups or individual routes)
- `role_source`: `token` (JWT claims decoded in middleware) or `db` (role fetched from DB per request)
- Construct → `declarations[].kind`:
  - An auth middleware (`RequireAuth()`) applied via `e.Use()` or inline on a route/group → `{kind: middleware}`
  - A role-check middleware (`RequireRole("admin")`) applied to a group or route → `{kind: role}`
  - A casbin enforcer middleware applied via `e.Use()` → `{kind: policy}`
- Common patterns:
  - `echo-jwt` / `golang-jwt/jwt`: token verified in middleware; claims attached to context via `c.Set("claims", claims)`; downstream handlers retrieve via `c.Get("claims").(*Claims)`
  - Role-based: role stored in JWT claims or loaded from DB; `RequireRole` factory returns an `echo.MiddlewareFunc` that checks `c.Get("user").(*User).Role`
  - Casbin: `internal/middleware/rbac*.go` wires a casbin `Enforcer` with an echo adapter; policy loaded from DB or `policy.csv`

## UI detection

_(N/A: API-only; html/template optional)_

If server-rendered HTML is used, detection signals are:

- **Renderer registration**: `e.Renderer = &TemplateRenderer{templates: template.Must(...)}` where `TemplateRenderer` implements `echo.Renderer`; templates live under `templates/`
- **Template rendering**: `c.Render(http.StatusOK, "index.html", data)` in handlers
- **Static files**: `e.Static("/static", "static")` or `e.File("/favicon.ico", "static/favicon.ico")`

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
