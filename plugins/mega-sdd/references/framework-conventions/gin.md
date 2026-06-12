---
framework: gin
framework_version_range: "1.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: go.mod
  dependency_marker: "github.com/gin-gonic/gin"
  version_regex: 'github\.com/gin-gonic/gin\s+v(\d+)\.'
extends: _universal
pack_tier: full
---

# Gin Convention Pack (1.x)

Conventions for Gin (Go) web/API projects. Extends `_universal.md` — universal defaults apply, Gin-specific rules override on conflict.

Gin is a thin HTTP framework; Go itself is largely unopinionated on project layout. This pack documents the **widely-adopted community project layout** (`cmd/`, `internal/`, `pkg/`) as established by the golang-standards/project-layout community convention, combined with idiomatic Gin patterns for routing, middleware, and request handling.

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

- **`gin.New()` or `gin.Default()` as the engine** — `gin.Default()` includes the Logger and Recovery middleware; `gin.New()` for explicit middleware control; attach all routes and middleware to the returned `*gin.Engine`
- **Router groups for API versioning and resource grouping** — `v1 := r.Group("/api/v1")`, then `v1.GET("/users", handlers.ListUsers)`; groups share middleware and prefix, reducing repetition
- **Handler functions take `*gin.Context`** — every route handler has the signature `func(c *gin.Context)`; the context carries request, response writer, params, and bound data
- **Middleware as `gin.HandlerFunc` attached via `r.Use()` or inline** — global middleware: `r.Use(middleware.RequireAuth())`; group middleware: `admin := r.Group("/admin", middleware.RequireRole("admin"))`; inline: `r.GET("/profile", middleware.RequireAuth(), handlers.GetProfile)`
- **Struct binding + validation tags for input** — define request structs with `binding:"required"` and `validate:"..."` tags; use `c.ShouldBindJSON(&req)` (returns error on decode failure without aborting) or `c.BindJSON(&req)` (calls `c.AbortWithError` on failure); prefer `ShouldBind*` for explicit error handling
- **JSON responses via `c.JSON()`** — `c.JSON(http.StatusOK, gin.H{"data": result})` or `c.JSON(http.StatusOK, responseStruct)`; use typed response structs for consistency over ad-hoc `gin.H` maps
- **Abort on error via `c.AbortWithStatusJSON()`** — in middleware and handlers, halt the chain and return an error: `c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})`; do not call `c.Next()` after aborting
- **Context propagation via `c.Set()` / `c.Get()`** — middleware passes values to downstream handlers (e.g. authenticated user) via `c.Set("user", user)` and `c.MustGet("user").(*User)` — prefer typed wrappers over raw string keys
- **Services injected via struct receivers** — handlers are methods on a handler struct that holds service dependencies; wire dependencies in `main.go` or a dedicated `internal/wire/` package (Wire codegen optional)
- **Thin handlers, fat services** — handlers parse the request and call a service method; all business logic lives in `internal/service/`; handlers stay under ~20 lines per method

## Hard Rules emitted

```
HARD_RULE: Handler functions MUST have the signature func(c *gin.Context)
  path_glob: internal/handlers/**/*.go
  rule_type: SIGNATURE_RULE
  pattern: 'func\s+(\([^)]*\)\s+)?\w+\(c\s+\*gin\.Context\)'
  rationale: Gin route handlers must match gin.HandlerFunc; non-conformant signatures cause compile errors

HARD_RULE: Business logic MUST NOT appear inline in handler functions — delegate to service layer
  path_glob: internal/handlers/**/*.go
  rule_type: CUSTOM
  rationale: Handlers thin + services fat; inline business logic breaks testability and separation of concerns

HARD_RULE: Input from HTTP requests MUST be bound via c.ShouldBind* or c.Bind* with a struct carrying validation tags
  path_glob: internal/handlers/**/*.go
  rule_type: CUSTOM
  rationale: Raw c.Query()/c.PostForm() calls bypass input validation; struct binding enables consistent validation

HARD_RULE: Middleware MUST be of type gin.HandlerFunc and attached via r.Use() or group/route-level registration
  path_glob: internal/middleware/**/*.go
  rule_type: CUSTOM
  rationale: Middleware registered outside the gin chain is never executed; direct injection bypasses the middleware stack

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

- **Input validation** — `c.ShouldBindJSON(&req)` into a request struct carrying `binding:"required"` / validator tags is the enforcement point; raw `c.Query()`/`c.PostForm()` reads skip every tag and hand unvalidated strings to the service layer — if it wasn't bound through a tagged struct, it was never validated.
- **SQL injection** — `database/sql` placeholders (`db.QueryContext(ctx, "... WHERE id = ?", id)`) and GORM's method chains parameterize automatically; `fmt.Sprintf("... WHERE id = %s", id)` fed into `db.Query` or `gorm.Raw` is the classic Go SQLi escape hatch — bind params or stay in the builder.
- **XSS / output escaping** — `html/template` (what `c.HTML` uses via `LoadHTMLGlob`) contextually auto-escapes; switching to `text/template` for HTML output, or casting user input to `template.HTML(...)`, disables escaping entirely — that cast is the XSS bypass; reserve it for sanitized, trusted fragments only.
- **CSRF** — no built-in protection; cookie/session-authenticated apps need a CSRF middleware (gin-csrf or a double-submit token check) on every state-changing route; pure bearer-token APIs are CSRF-immune by design, but the moment an auth cookie appears, `SameSite` plus a token check are mandatory — a cookie-auth POST route without the middleware is the hole.
- **AuthN/AuthZ enforcement point** — auth is middleware on router groups (`admin := r.Group("/admin", middleware.RequireAuth(), middleware.RequireRole("admin"))`); the bypass is a handler registered directly on `r` beside the protected group instead of inside it — group membership IS the protection, so audit every route registration site.
- **Password hashing** — `golang.org/x/crypto/bcrypt` (`bcrypt.GenerateFromPassword`) or argon2id (`golang.org/x/crypto/argon2`); a fast hash (`crypto/sha256`, md5) over a password is the bypass — brute-forceable by design — and a hand-rolled `==` compare leaks timing where `bcrypt.CompareHashAndPassword` does not.
- **Mass assignment** — binding straight into the persistence/GORM model makes every struct field client-settable (`role`, `isAdmin`, `id`); use a dedicated request struct with only the intended fields, then map explicitly to the model — `c.ShouldBindJSON(&user)` on the DB model is the over-posting bypass.
- **Secrets / config** — `os.Getenv` or viper-loaded config in `internal/config/`; the bypass is a hardcoded JWT secret or DSN literal in source, or a committed `.env` — keep `.env` gitignored and fail fast at startup when a required secret is empty.
- **File uploads** — cap size via `r.MaxMultipartMemory` plus `http.MaxBytesReader`, allowlist both extension AND sniffed content type (`http.DetectContentType`), and store under a server-generated name outside any statically served directory; trusting the client filename or saving into the `r.Static`-mounted `static/` dir makes the upload path-traversable or directly retrievable — that is the bypass.

## Testing conventions

- **Test runner**: standard `go test ./...` — no test framework required; run from the module root
- **Test file location**: `*_test.go` files co-located with the package under test (e.g. `internal/handlers/user_handler_test.go`)
- **HTTP handler testing**: `net/http/httptest` — create a `httptest.NewRecorder()` and call the handler directly, or use `httptest.NewServer()` for integration tests
- **Table-driven tests**: idiomatic Go pattern — define a slice of `struct{ name, input, expected }` test cases and range over them in a single `t.Run(tc.name, ...)` call
- **Test naming**: `TestFunctionName` (unit) and `TestFunctionName_Scenario` (subtests via `t.Run`); test functions MUST start with `Test`
- **Assertions**: standard `testing` package (`t.Errorf`, `t.Fatalf`); `testify/assert` and `testify/require` are widely used for cleaner assertion syntax (optional dependency)
- **Mocking**: interfaces + hand-rolled mocks or `github.com/stretchr/testify/mock`; define service interfaces so handlers can be tested with mock services
- **Gin test setup**: `gin.SetMode(gin.TestMode)` in `TestMain` or individual tests to suppress output; create a fresh `gin.Engine` per test case for isolation
- **Example handler test pattern**:
  ```go
  func TestGetUser(t *testing.T) {
      gin.SetMode(gin.TestMode)
      w := httptest.NewRecorder()
      c, r := gin.CreateTestContext(w)
      r.GET("/users/:id", handlers.GetUser)
      c.Request, _ = http.NewRequest(http.MethodGet, "/users/1", nil)
      r.ServeHTTP(w, c.Request)
      assert.Equal(t, http.StatusOK, w.Code)
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

- `mechanism`: `middleware` (role/permission checks applied as `gin.HandlerFunc` middleware on route groups or individual routes)
- `role_source`: `token` (JWT claims decoded in middleware) or `db` (role fetched from DB per request)
- Construct → `declarations[].kind`:
  - An auth middleware (`RequireAuth()`) applied via `r.Use()` or inline on a route/group → `{kind: middleware}`
  - A role-check middleware (`RequireRole("admin")`) applied to a group or route → `{kind: role}`
  - A casbin enforcer middleware (`casbinMiddleware.NewAuthorizer(enforcer)`) applied via `r.Use()` → `{kind: policy}`
- Common patterns:
  - `golang-jwt/jwt`: token verified in middleware; claims attached to context via `c.Set("claims", claims)`; downstream handlers retrieve via `c.MustGet("claims").(*Claims)`
  - Role-based: role stored in JWT claims or loaded from DB; `RequireRole` factory returns a `gin.HandlerFunc` that checks `c.MustGet("user").(*User).Role`
  - Casbin: `internal/middleware/rbac*.go` wires a casbin `Enforcer` with a gin adapter; policy loaded from DB or `policy.csv`

## UI detection

_(N/A: API-only; html/template optional)_

If server-rendered HTML is used, detection signals are:

- **Template loading**: `r.LoadHTMLGlob("templates/**/*.html")` or `r.LoadHTMLFiles(...)` in router setup; templates live under `templates/`
- **Template rendering**: `c.HTML(http.StatusOK, "index.html", gin.H{...})` in handlers
- **Static files**: `r.Static("/static", "./static")` or `r.StaticFS("/static", http.Dir("static"))`

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
