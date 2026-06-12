---
framework: axum
framework_version_range: "0.7 — 0.8"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: Cargo.toml
  dependency_marker: "axum"
  version_regex: 'axum\s*=\s*["{].*?(\d+\.\d+)'
extends: _universal
pack_tier: full
---

# Axum Convention Pack (0.7 — 0.8)

Conventions for Axum (Rust / Tokio / Tower) web/API projects. Extends `_universal.md` — universal defaults apply, Axum-specific rules override on conflict.

Axum is a macro-free, ergonomic web framework built on Tokio, Tower, and Hyper. Routing, extractors, and middleware compose via Tower's `Service` / `Layer` traits. This pack documents the conventional Cargo workspace layout combined with idiomatic Axum patterns for routing, shared state, extractors, and Tower middleware.

## File location standards

| Artifact | Path |
|---|---|
| Application entry point | `src/main.rs` |
| Router setup / route registration | `src/routes/` or `src/handlers/` (small apps: inline in `src/main.rs`) |
| Handler functions | `src/handlers/` or `src/routes/` |
| Shared application state | `src/state.rs` |
| Models / domain structs | `src/models/` |
| Service / business logic | `src/services/` |
| Repository / data access | `src/repository/` |
| Tower middleware (custom) | `src/middleware/` |
| Error types (`AppError`) | `src/errors.rs` or `src/error.rs` |
| Config structs + loader | `src/config.rs` or `src/config/` |
| Dependency manifest | `Cargo.toml` + `Cargo.lock` |
| Tests | inline `#[cfg(test)]` module or `tests/` integration tests co-located with the crate |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Module name | snake_case | `user_handler`, `auth_middleware`, `user_service` |
| Handler function | snake_case async fn | `get_user`, `create_user`, `list_orders` |
| Type / struct / enum | PascalCase | `AppState`, `AppError`, `CreateUserRequest` |
| Trait impl | PascalCase | `impl IntoResponse for AppError` |
| File name | snake_case | `user_handler.rs`, `auth_middleware.rs` |
| Test module | `#[cfg(test)] mod tests` | inline in source file |
| Route path | kebab-case, noun-plural for collections | `/users`, `/user-profiles`, `/api/v1/orders` |
| Environment config key | SCREAMING_SNAKE_CASE | `PORT`, `DATABASE_URL`, `JWT_SECRET` |
| Struct field (JSON) | snake_case via `serde(rename_all)` or field `rename` | `first_name`, `created_at` |
| State type | `AppState` (PascalCase, `#[derive(Clone)]`) | `AppState` |

## Idioms (preferred patterns)

- **`Router::new().route("/path", get(handler))` as the backbone** — build the router by chaining `.route()` calls using method-router functions (`get`, `post`, `put`, `patch`, `delete`) from `axum::routing`; these are free functions, not macros; the router is a value composed at startup
- **Async handler functions returning `impl IntoResponse` or `Result<Json<T>, AppError>`** — every route handler is an `async fn` whose return type implements `IntoResponse`; return `Json<T>` for happy-path responses; return a custom `AppError` type that itself implements `IntoResponse` for structured error responses
- **Extractors for all request input** — use typed extractors as handler arguments: `Json<T>` for request bodies, `Path<T>` for URL path parameters, `Query<T>` for query strings, `State<S>` for shared application state, `TypedHeader` for headers; axum validates and deserializes automatically — never read raw request bytes in handler bodies
- **Shared state via `State<S>` + `.with_state()`** — declare a `#[derive(Clone)] struct AppState { ... }` in `src/state.rs`; register it with the router via `router.with_state(state)`; access it in any handler or middleware via the `State(s): State<AppState>` extractor; state must be `Clone + Send + Sync + 'static`
- **Custom `FromRequestParts` for reusable extraction logic** — implement `FromRequestParts<S>` (for parts-only extractors, e.g. auth guards, role checks) or `FromRequest<S>` (for body-consuming extractors); this is Axum's extension point for custom input validation and auth guard patterns
- **Tower middleware via `.layer()` and tower-http crates** — attach cross-cutting concerns as Tower `Layer`s: `TraceLayer` (from `tower-http`) for structured logging, `CorsLayer` for CORS, `CompressionLayer` for response compression; apply with `router.layer(layer)` (all routes) or `router.route_layer(layer)` (matched routes only); order matters — layers applied last execute first
- **`middleware::from_fn` for lightweight async middleware** — use `axum::middleware::from_fn(my_fn)` to create a Tower layer from an async function; the function receives extractors + `Request` + `Next` and returns `impl IntoResponse`; use `middleware::from_fn_with_state` when the middleware needs `State`
- **Nested routers via `.nest("/prefix", sub_router)`** — decompose large APIs into sub-routers per resource or domain; nest them under a path prefix via `Router::nest()`; sub-routers may carry their own `with_state` calls before nesting
- **`serde` for all serialization** — derive `serde::Serialize` / `serde::Deserialize` on request and response structs; use `#[serde(rename_all = "camelCase")]` or field-level `#[serde(rename = "...")]` to control JSON key casing; never hand-roll JSON strings in handlers
- **Thin handlers, fat services** — handlers extract input, call a service function, and return a response; all business logic lives in `src/services/`; handlers should stay under ~20 lines; services are injected through `AppState`

## Hard Rules emitted

```
HARD_RULE: Handler functions MUST be async and return impl IntoResponse or Result<T, AppError>
  path_glob: src/handlers/**/*.rs
  rule_type: SIGNATURE_RULE
  pattern: 'async\s+fn\s+\w+\s*\([^)]*\)\s*(->\s*(impl\s+IntoResponse|Result<[^>]+>))?'
  rationale: Axum handlers must be async and produce a type implementing IntoResponse; sync handlers cause compile errors and blocking the async runtime

HARD_RULE: Business logic MUST NOT appear inline in handler functions — delegate to the service layer
  path_glob: src/handlers/**/*.rs
  rule_type: CUSTOM
  rationale: Handlers thin + services fat; inline business logic breaks testability and separation of concerns

HARD_RULE: Request input MUST be extracted via Axum extractors (Json<T>, Path<T>, Query<T>, State<S>, custom FromRequest) — never via raw body reads in handler bodies
  path_glob: src/handlers/**/*.rs
  rule_type: CUSTOM
  rationale: Extractors provide typed, validated, deserialized input; bypassing them breaks validation guarantees and couples handlers to wire format

HARD_RULE: Shared application dependencies MUST be passed via State<AppState> — not via global statics or thread-locals
  path_glob: src/handlers/**/*.rs
  rule_type: CUSTOM
  rationale: State<S> is the Axum-idiomatic dependency-injection mechanism; globals bypass the borrow checker and make testing hard

HARD_RULE: Cross-cutting concerns (logging, CORS, auth) MUST be applied as Tower layers via .layer() or .route_layer() — not implemented inside individual handlers
  path_glob: src/middleware/**/*.rs
  rule_type: CUSTOM
  rationale: Tower layers compose cleanly and are applied uniformly; embedding cross-cutting logic in handlers causes duplication and makes auditing impossible

HARD_RULE: A custom error type implementing IntoResponse MUST be defined and used as the Err variant in all fallible handlers
  path_glob: src/**/*.rs
  rule_type: CUSTOM
  rationale: Consistent error responses require a single AppError type; returning heterogeneous errors or unwrapping in handlers produces unstructured 500s
```

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — `Json<T>` / `Query<T>` extractors deserialize via serde, but type-checking is not validation: pair with the `validator` crate (`#[derive(Validate)]` + a `ValidatedJson`-style wrapper extractor that calls `.validate()` in `FromRequest`); the bypass is treating a successful deserialize as "validated", or reading raw request bytes that skip extractors entirely.
- **SQL injection** — sqlx's compile-time-checked `query!`/`query_as!` macros and `.bind()` placeholders parameterize by construction (likewise Diesel's typed DSL); `format!`-built SQL strings handed to `sqlx::query(&s)` reintroduce SQLi — bind parameters or stay in the macro/DSL.
- **XSS / output escaping** — askama (compile-time) and tera (runtime, rendered into `axum::response::Html`) auto-escape template output; tera's `| safe` filter and askama's escape opt-outs mark input as raw — that is the bypass — as is returning `Html(format!(...))` built from user input.
- **CSRF** — no built-in; bearer-token-only APIs are CSRF-immune by design, but apps on `tower-sessions`/`axum-login` cookies need a double-submit or synchronizer-token layer on state-changing routes plus `SameSite` on the session cookie — a cookie-auth POST without a token check is the hole.
- **AuthN/AuthZ enforcement point** — auth is a Tower layer (`route_layer(middleware::from_fn_with_state(state, auth))`) on the protected sub-router, or a `FromRequestParts` guard extractor (`AuthUser`, `RequireRole`) in the handler signature; two bypasses: `.layer()`/`.route_layer()` only cover routes added BEFORE the call — a route added after is unprotected — and a handler that omits the guard parameter compiles clean and ships open.
- **Password hashing** — the `argon2` crate (argon2id) or `bcrypt` crate via `PasswordHasher`/`verify_password`; hashing a password with `sha2` or comparing digests with `==` is the bypass — fast hashes are brute-forceable and naive comparison leaks timing.
- **Mass assignment** — serde fills every named field, so deriving `Deserialize` on the sqlx row / DB model exposes `role`/`is_admin`/`id` to over-posting; use dedicated request structs with only the intended fields and add `#[serde(deny_unknown_fields)]` so unexpected keys are rejected rather than silently ignored.
- **Secrets / config** — `dotenvy` for local `.env` loading plus a typed config layer (`envy`/`config` crate) read into `AppState` at startup; the bypass is a hardcoded JWT secret or database URL literal in `src/`, or a committed `.env` — keep it gitignored and fail at startup on missing secrets.
- **File uploads** — `axum::extract::Multipart` behind the default 2 MB request cap, raised deliberately with `DefaultBodyLimit::max(n)` — calling `DefaultBodyLimit::disable()` without a replacement limit is the bypass; allowlist extension + sniffed content type, and persist under a server-generated name outside any `ServeDir`-mounted directory (client filenames invite traversal; the static mount makes uploads retrievable).

## Testing conventions

- **Test runner**: `cargo test` — standard Cargo test harness; no additional framework required
- **Async test runtime**: `#[tokio::test]` — annotate async test functions with `#[tokio::test]` (from the `tokio` crate with the `macros` feature); Axum handlers require an async runtime
- **HTTP handler testing via `tower::ServiceExt::oneshot`** — build the router under test, then call `.oneshot(request)` from `tower::ServiceExt` to dispatch a single request without binding a port; this is the idiomatic Axum integration test pattern
- **Test file location**: inline `#[cfg(test)] mod tests { ... }` in the source file for unit tests; `tests/` directory for integration tests
- **Request construction**: use `http::Request::builder()` to construct test requests; use `axum::body::Body` for request bodies; use `hyper::body::to_bytes` or `axum::body::to_bytes` to collect response bodies
- **Assertions**: standard `assert_eq!` / `assert!`; `serde_json::from_slice` to deserialize response bodies for JSON assertions
- **Mocking**: define service traits and pass mock implementations through `AppState` in tests; Axum's `with_state` makes swapping test doubles straightforward
- **Example handler test pattern**:
  ```rust
  #[tokio::test]
  async fn test_get_user() {
      let state = AppState { db: mock_db() };
      let app = crate::routes::app().with_state(state);

      let request = Request::builder()
          .method("GET")
          .uri("/users/1")
          .body(Body::empty())
          .unwrap();

      let response = app.oneshot(request).await.unwrap();
      assert_eq!(response.status(), StatusCode::OK);

      let body = axum::body::to_bytes(response.into_body(), usize::MAX).await.unwrap();
      let user: serde_json::Value = serde_json::from_slice(&body).unwrap();
      assert_eq!(user["id"], 1);
  }
  ```

## Deep-scan file hints

```yaml
auth_hints:
  - "src/middleware/auth.rs"
  - "src/middleware/jwt.rs"
  - "src/middleware/auth_middleware.rs"
  - "src/extractors/auth_user.rs"
  - "src/extractors/claims.rs"
authz_hints:
  - "src/middleware/rbac.rs"
  - "src/middleware/require_role.rs"
  - "src/extractors/require_role.rs"
  - "src/extractors/auth*.rs"
ui_hints:
  - "templates/"
  - "static/"
```

## Authz mapping

- `mechanism`: `middleware` (Tower layer via `middleware::from_fn` or `route_layer`) + `extractor` (custom `FromRequestParts` implementing an auth guard)
- `role_source`: `token` (JWT claims decoded in middleware or extractor) or `db` (role fetched from DB per request via `State`)
- Construct → `declarations[].kind`:
  - An auth Tower layer applied via `.layer(middleware::from_fn(auth_fn))` or `.route_layer(middleware::from_fn(auth_fn))` → `{kind: middleware}`
  - A `FromRequestParts` extractor enforcing authentication or role membership (e.g. `AuthUser`, `RequireRole<"admin">`) declared as a handler parameter → `{kind: guard}`
  - A role check inside an extractor or middleware that maps a claim/DB value to a permitted set → `{kind: role}`
- Common patterns:
  - `jsonwebtoken` crate: token verified in a `FromRequestParts` extractor or `from_fn` middleware; decoded claims stored as a request extension (`extensions.insert(claims)`) and retrieved in downstream extractors
  - Role-based: role stored in JWT claims or `db`; `RequireRole` extractor or middleware factory returns `StatusCode::FORBIDDEN` when the caller lacks the required role
  - `axum-login` / `tower-sessions`: session-backed auth; provides `AuthSession` extractor injected by the session layer; role checks performed inside route handlers or dedicated extractors

## UI detection

_(N/A: API-only; askama/tera templating optional)_

If server-rendered HTML is used, detection signals are:

- **Askama**: templates compiled at build time; handler returns `impl IntoResponse` wrapping an Askama `Template` struct annotated with `#[template(path = "...", ext = "html")]`; templates live under `templates/`
- **Tera**: runtime template engine; `Tera::new("templates/**/*.html")` in `AppState`; handlers call `tera.render(...)` and return `Html(rendered)` from `axum::response::Html`
- **Static files**: `tower_http::services::ServeDir` mounted via `Router::nest_service("/static", ServeDir::new("static"))`

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "src/utils/**", "src/lib.rs" ]
  model_api: [ "src/models/**", "src/domain/**" ]
  services: [ "src/services/**" ]
  commands: [ "src/bin/**" ]
```

- `model_api`: exported structs, enums, and their `impl` blocks in each model file; includes ORM model definitions (e.g. `sqlx` row types, `diesel` schema) and repository trait definitions.
- `services`: exported service structs and their `impl` blocks; each service file exposes the domain API (e.g. `UserService::find_by_id`, `OrderService::create`).
- `commands`: additional binary entry points under `src/bin/`; each binary wires up its own Axum router or runs a background task / CLI subcommand.
