---
framework: actix
framework_version_range: "4.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: Cargo.toml
  dependency_marker: "actix-web"
  version_regex: 'actix-web\s*=\s*(?:\{[^}]*version\s*=\s*)?["''](\d+)'
extends: _universal
pack_tier: full
---

# Actix Web Convention Pack (4.x)

Conventions for Actix Web (Rust) projects. Extends `_universal.md` — universal defaults apply, Actix-specific rules override on conflict.

Actix Web 4.x is a high-performance, actor-model-inspired HTTP framework for Rust. This pack covers idiomatic Actix Web patterns for request handling via extractors, middleware via `wrap()`, and shared state via `web::Data<T>`. The legacy `actix` actor crate is a separate concern and is out of scope; modern Actix Web handlers are plain `async fn` — no actors required.

## File location standards

| Artifact | Path |
|---|---|
| Application entry point | `src/main.rs` |
| Library root (module gateway) | `src/lib.rs` |
| Handlers (request/response) | `src/handlers/` or `src/routes/` |
| Middleware | `src/middleware/` |
| Models / domain structs | `src/models/` |
| Service / business logic | `src/services/` |
| Config structs + loader | `src/config.rs` or `src/config/` |
| Repository / data access | `src/repository/` (optional layer) |
| Public reusable utilities | `src/utils/` |
| Binary entry points (multi-bin) | `src/bin/<name>.rs` |
| Dependency manifest | `Cargo.toml` + `Cargo.lock` |
| Tests (unit) | `#[cfg(test)] mod tests` block at the bottom of the source file under test |
| Tests (integration) | `tests/` directory at the crate root |

**Common module layout for mid-size projects:**

```
src/
  main.rs          ← HttpServer bootstrap + App::new() wiring
  lib.rs           ← re-exports + module declarations
  handlers/        ← one file per resource (users.rs, orders.rs …)
  services/        ← business logic, injected via web::Data
  models/          ← request/response structs, DB models, serde derives
  middleware/       ← custom middleware implementing Transform/Service
  config.rs        ← Config struct loaded from env / file
Cargo.toml
```

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Module name | snake_case | `handlers`, `user_service`, `auth_middleware` |
| Function name (handler, service) | snake_case | `get_user`, `create_order`, `list_items` |
| Struct / Enum / Trait name | PascalCase | `UserResponse`, `AppState`, `AuthError` |
| File name | snake_case | `user_handler.rs`, `auth_middleware.rs` |
| Route path | kebab-case, noun-plural for collections | `/users`, `/user-profiles`, `/api/v1/orders` |
| Environment / config key | SCREAMING_SNAKE_CASE | `PORT`, `DATABASE_URL`, `JWT_SECRET` |
| Struct field (JSON) | snake_case via `serde(rename_all = "camelCase")` or explicit `rename` | `first_name` → serialized as `firstName` |
| Test module | `mod tests` under `#[cfg(test)]` | inline at bottom of source file |
| Integration test file | snake_case | `user_integration_test.rs` |

## Idioms (preferred patterns)

- **`HttpServer::new(|| App::new()...)` as the bootstrap** — the application factory closure is passed to `HttpServer::new`; call `.bind(addr)` and `.run()` on the result; all route/service registration and middleware wrapping happens inside the closure so each worker thread gets its own `App` instance

- **Route registration via `.service()` with proc-macro attributes or via `.route()`** — preferred: annotate handler functions with `#[get("/path")]`, `#[post("/path")]`, `#[put]`, `#[delete]` etc. and register them with `App::new().service(get_user).service(create_user)`; alternative: `App::new().route("/users/{id}", web::get().to(get_user))`; prefer the macro form for readability

- **Extractors for input** — declare handler parameters as typed extractors; Actix automatically deserializes and validates them:
  - `web::Json<T>` — JSON request body (requires `T: serde::Deserialize`)
  - `web::Path<(Type,)>` or `web::Path<Struct>` — URL path parameters
  - `web::Query<T>` — query string parameters
  - `web::Data<T>` — shared application state (see below)
  - `web::Form<T>` — URL-encoded form data
  - Multiple extractors are declared as additional function parameters: `async fn handler(path: web::Path<u32>, body: web::Json<Payload>, data: web::Data<AppState>) -> impl Responder`

- **`web::Data<T>` for shared state and dependency injection** — wrap shared state (DB pool, config, service impls) in `web::Data::new(...)` and register with `.app_data(web::Data::new(state))`; handlers receive it via `data: web::Data<AppState>`; state must be `Send + Sync`; `Arc<T>` is the idiomatic inner type for mutable shared state

- **Return `impl Responder` or `Result<HttpResponse, Error>`** — simple handlers return `impl Responder` (e.g. `HttpResponse::Ok().json(resp)` or a typed struct implementing `Responder`); error-returning handlers use `Result<HttpResponse, Error>` (Actix custom error type) or `Result<HttpResponse, actix_web::Error>`; define domain error enums and implement `ResponseError` for structured error responses

- **Middleware via `.wrap()`** — attach middleware to the whole app with `App::new().wrap(middleware)` or to a scope with `web::scope("/api").wrap(auth_mw)`; common built-ins: `actix_web::middleware::Logger`, `actix_web::middleware::Compress`, `actix_web::middleware::NormalizePath`; JWT auth via `actix-web-httpauth` crate with `HttpAuthentication::bearer(validator_fn)`

- **`web::scope()` for route grouping** — group related routes and apply shared middleware: `App::new().service(web::scope("/api/v1").wrap(Logger::default()).service(users_scope))`; nesting scopes gives clean URL prefixing without repetition

- **`serde` for (de)serialization** — all request and response structs derive `serde::Deserialize` and/or `serde::Serialize`; use `#[serde(rename_all = "camelCase")]` at the struct level for consistent JSON casing; validation via `validator` crate (`#[validate(...)]`) or manual checks in the handler before delegating to the service layer

- **Thin handlers, fat services** — handlers extract inputs from the request, call a service method, and return a response; all business logic lives in `src/services/`; a handler body is typically 5–15 lines; services hold no HTTP concerns and are unit-testable without an HTTP stack

- **`app_data` for request-level configuration** — pass per-type configuration (e.g. `web::JsonConfig::default().error_handler(...)`) via `.app_data(...)` to customize extractor error handling globally

## Hard Rules emitted

```
HARD_RULE: Handler functions MUST be async and return impl Responder or Result<HttpResponse, E>
  path_glob: src/handlers/**/*.rs
  rule_type: SIGNATURE_RULE
  rationale: Actix Web 4.x requires async handlers; synchronous handlers cause compile errors; return type must implement Responder or be a Result whose Ok-variant implements Responder

HARD_RULE: Business logic MUST NOT appear inline in handler functions — delegate to service layer
  path_glob: src/handlers/**/*.rs
  rule_type: CUSTOM
  rationale: Handlers thin + services fat; inline business logic breaks testability and separation of concerns

HARD_RULE: HTTP request inputs MUST be extracted via typed Actix extractors (web::Json, web::Path, web::Query, web::Form) — not via manual request parsing
  path_glob: src/handlers/**/*.rs
  rule_type: CUSTOM
  rationale: Manual request parsing bypasses Actix extractor validation and deserialization; extractors provide consistent, composable input handling

HARD_RULE: Shared application state MUST be injected via web::Data<T> registered in app_data — not via global statics or thread-locals
  path_glob: src/**/*.rs
  rule_type: CUSTOM
  rationale: web::Data<T> is the Actix-idiomatic DI mechanism; global statics bypass the framework's lifetime and concurrency model

HARD_RULE: Middleware MUST be registered via App::wrap() or web::scope().wrap() — not invoked manually inside handler bodies
  path_glob: src/middleware/**/*.rs
  rule_type: CUSTOM
  rationale: Middleware registered outside the Actix middleware chain is never executed for all requests; manual invocation inside handlers breaks the separation of cross-cutting concerns

HARD_RULE: Domain error types MUST implement actix_web::ResponseError to produce structured HTTP error responses
  path_glob: src/**/*.rs
  rule_type: CUSTOM
  rationale: Implementing ResponseError centralizes error-to-response mapping; returning raw unwrap/panic in handlers causes 500 responses with no client-visible detail
```

## Testing conventions

- **Test runner**: `cargo test` — standard Rust test runner; run `cargo test` from the crate root to execute all unit and integration tests
- **Test attribute**: `#[actix_web::test]` — use this attribute (not the plain `#[tokio::test]`) for async handler tests; it sets up the Actix runtime correctly
- **Unit tests**: `#[cfg(test)] mod tests` block at the bottom of the file under test; handlers are tested by constructing an `App` via `test::init_service`
- **Integration tests**: files under `tests/` at the crate root; import from `src/lib.rs`
- **HTTP handler testing with `test::init_service` + `test::TestRequest`**:
  ```rust
  #[actix_web::test]
  async fn test_get_user() {
      let app = test::init_service(
          App::new()
              .app_data(web::Data::new(mock_state()))
              .service(get_user),
      )
      .await;
      let req = test::TestRequest::get().uri("/users/1").to_request();
      let resp = test::call_service(&app, req).await;
      assert_eq!(resp.status(), StatusCode::OK);
  }
  ```
- **Test assertions**: use `assert_eq!` / `assert!` from the standard library; `test::read_body_json` reads and deserializes the response body in tests; `serde_json::json!` macro constructs request bodies
- **Mocking**: define service traits and inject mock implementations via `web::Data` in tests; crates `mockall` or `mockito` are commonly used for async mock generation
- **Table-driven tests**: Rust's `#[test]` supports helper loops; define a `Vec<(input, expected)>` slice and iterate with `for (input, expected) in cases`

## Deep-scan file hints

```yaml
auth_hints:
  - "src/middleware/auth.rs"
  - "src/middleware/auth_middleware.rs"
  - "src/middleware/jwt.rs"
  - "src/middleware/"
  - "src/config.rs"
authz_hints:
  - "src/middleware/rbac.rs"
  - "src/middleware/auth*.rs"
  - "src/middleware/role*.rs"
  - "src/middleware/require_role.rs"
ui_hints:
  - "templates/"
  - "static/"
```

## Authz mapping

- `mechanism`: `middleware` (role/permission checks applied as Actix middleware via `.wrap()` on app or scope, or as extractor-guards via custom `FromRequest` implementations)
- `role_source`: `token` (JWT claims decoded in middleware or extractor) or `db` (role fetched from DB per request via `web::Data` pool)
- Construct → `declarations[].kind`:
  - An auth middleware (`HttpAuthentication::bearer(validator)` from `actix-web-httpauth`) applied via `.wrap()` on the app or a scope → `{kind: middleware}`
  - A custom `FromRequest` extractor that enforces a role (e.g. `AdminUser` struct whose `from_request` checks JWT claims) → `{kind: guard}`
  - A role check inside a middleware or extractor (e.g. checking `claims.role == "admin"`) → `{kind: role}`
- Common patterns:
  - `jsonwebtoken` crate: decode and verify JWTs in a middleware validator function; attach claims to request extensions via `req.extensions_mut().insert(claims)`; downstream handlers retrieve via `req.extensions().get::<Claims>()`
  - `actix-web-httpauth`: `HttpAuthentication::bearer(validator_fn)` where `validator_fn` is `async fn(req, credentials) -> Result<req, (Error, req)>`; register with `.wrap(HttpAuthentication::bearer(validator))`
  - `casbin-rs`: wire a casbin `Enforcer` in a custom middleware; store enforcer in `web::Data`; check `enforcer.enforce((subject, object, action))` per request

## UI detection

_(N/A: API-only; askama/tera templating optional)_

If server-rendered HTML is used, detection signals are:

- **Askama templates**: `askama` crate; templates stored under `templates/` matching configured `dirs`; structs derive `askama::Template` and implement `Responder` via the `askama_actix` integration; handlers return a template struct directly
- **Tera templates**: `tera` crate; `Tera::new("templates/**/*")` initialised in startup; passed in `web::Data`; handlers call `tera.render("page.html", &context)` and return the rendered string as `HttpResponse::Ok().content_type("text/html").body(html)`
- **Static files**: `actix-files` crate; `Files::new("/static", "./static").show_files_listing()` registered as a service on the `App`

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "src/utils/**" ]
  model_api: [ "src/models/**" ]
  services: [ "src/services/**" ]
  commands: [ "src/bin/**" ]
```

- `model_api`: exported structs, enums, and their method implementations in each model file; includes request/response DTOs, DB model structs, and domain types.
- `services`: exported service structs and their `impl` blocks; each service file exposes the domain API (e.g. `UserService::find_by_id`, `OrderService::create`).
- `commands`: binary entry points under `src/bin/`; each `<name>.rs` wires dependencies and starts the server or runs a CLI subcommand; also check `src/main.rs` for single-binary projects.
