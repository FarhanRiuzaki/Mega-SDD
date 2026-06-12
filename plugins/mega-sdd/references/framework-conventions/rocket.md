---
framework: rocket
framework_version_range: "0.5.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: Cargo.toml
  dependency_marker: "rocket"
  version_regex: 'rocket\s*=\s*["{].*"0\.5\.'
extends: _universal
pack_tier: full
---

# Rocket Convention Pack (0.5.x)

Conventions for Rocket (Rust) web/API projects. Extends `_universal.md` — universal defaults apply, Rocket-specific rules override on conflict.

Rocket is an async, attribute-driven web framework for Rust with a focus on usability and safety. Routing is declared via attribute macros (`#[get]`, `#[post]`, etc.), authentication and validation use typed request guards (`FromRequest`), shared dependencies use managed state (`.manage()` + `&State<T>`), and cross-cutting concerns use fairings — Rocket's lifecycle hooks analogous to middleware.

## File location standards

| Artifact | Path |
|---|---|
| Application entry point | `src/main.rs` (carries the `#[launch]` function) |
| Route handlers | `src/routes/` (one module per resource) or `src/routes.rs` (small apps) |
| Models / domain structs | `src/models/` |
| Service / business logic | `src/services/` |
| Request guards | `src/guards/` |
| Fairings (lifecycle hooks / middleware) | `src/fairings/` |
| Repository / data access | `src/repositories/` or `src/db/` |
| Config structs | `src/config.rs` or `src/config/` |
| Cargo manifest | `Cargo.toml` |
| Rocket configuration | `Rocket.toml` (environment-aware: `[default]`, `[debug]`, `[release]`) |
| Tests | `tests/` (integration) and `#[cfg(test)]` inline modules (unit) |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Module / file name | snake_case | `user_routes.rs`, `auth_guard.rs`, `db_fairing.rs` |
| Function name | snake_case | `get_user`, `create_order`, `from_request` |
| Struct / enum / type name | PascalCase | `AuthenticatedUser`, `AppState`, `UserInput` |
| Route function name | snake_case verb + noun | `get_user`, `list_orders`, `create_order` |
| Request guard struct | PascalCase, noun describing identity | `AuthenticatedUser`, `AdminUser`, `ApiKey` |
| Fairing struct | PascalCase + `Fairing` suffix | `DbFairing`, `CorsFairing`, `LoggingFairing` |
| Managed state struct | PascalCase, descriptive | `DbPool`, `AppConfig`, `HitCount` |
| JSON input struct | PascalCase + `Input` or `Request` suffix | `CreateUserInput`, `LoginRequest` |
| JSON output struct | PascalCase + `Response` or `Dto` suffix | `UserResponse`, `OrderDto` |
| Route path segment | kebab-case, noun-plural for collections | `/users`, `/user-profiles`, `/api/v1/orders` |
| Dynamic path segment | snake_case in angle brackets | `<user_id>`, `<order_id>` |
| Environment config key | SCREAMING_SNAKE_CASE via `Rocket.toml` or env | `ROCKET_PORT`, `ROCKET_DATABASES`, `DATABASE_URL` |

## Idioms (preferred patterns)

- **`#[launch]` function returning `rocket::build()`** — the application entry point is an annotated function (not `fn main()`) returning `_` (inferred as `Rocket<Build>`): `#[launch] fn rocket() -> _ { rocket::build().mount("/", routes![...]) }`; `#[launch]` generates an async `main` that calls this function; do not use the deprecated `rocket::ignite()` API
- **Route attribute macros on handler functions** — declare routes with `#[get("/path")]`, `#[post("/path", data = "<body>")]`, `#[put("/path/<id>", data = "<body>")]`, `#[delete("/path/<id>")]`, etc.; dynamic path segments are captured as typed function parameters by the same name: `#[get("/<id>")] fn get_user(id: i64) -> ...`
- **`.mount("/prefix", routes![handler1, handler2])` for registration** — routes are collected with the `routes![]` macro and registered at a base URI with `.mount()`; this is the only way to wire handlers into the router; never call handler functions directly for routing
- **Request guards via `FromRequest` for auth and validation** — any type implementing `rocket::request::FromRequest` can appear as a function parameter and is resolved before the handler runs; returning `Outcome::Failure` short-circuits the request (e.g. 401 Unauthorized) before the handler body executes; request guards are the idiomatic Rocket pattern for authentication, API key validation, and per-request derived data
- **Managed state with `.manage()` and `&State<T>`** — inject thread-safe shared state (database pool, config, counters) via `rocket.manage(value)` at build time; handlers and other guards receive it as `state: &State<T>`; Rocket panics at launch if a `&State<T>` parameter is requested but the type was never managed — catch mis-wiring at startup, not at runtime
- **Fairings for cross-cutting lifecycle concerns** — fairings implement `rocket::fairing::Fairing` (or use `AdHoc` for one-off closures) and are attached via `.attach(MyFairing)`; fairing callbacks include `on_ignite`, `on_liftoff`, `on_request` (mutable request editing), and `on_response` (mutable response editing); use fairings for CORS headers, request logging, DB connection checks, and config extraction via `AdHoc::config::<T>()`
- **`Json<T>` from `rocket::serde::json` for JSON I/O** — `Json<T>` as a `data` parameter deserializes the request body when `T: serde::Deserialize`; returning `Json<T>` serializes the response when `T: serde::Serialize`; enable the `json` Cargo feature for Rocket (`rocket = { features = ["json"] }`); derive `serde::Serialize` and `serde::Deserialize` on model/DTO structs
- **`Responder` trait for typed response shaping** — implement `rocket::response::Responder` on custom types to control status code, headers, and body; use `rocket::response::status::Custom<T>` for one-off status overrides without a full custom responder; `Json<T>`, `rocket::fs::NamedFile`, `rocket::response::Redirect`, and `String` all implement `Responder` out of the box
- **`Rocket.toml` for environment-aware configuration** — use `[default]`, `[debug]`, and `[release]` sections; override with environment variables prefixed `ROCKET_`; extract custom config blocks into typed structs via `rocket::figment::Figment` or `AdHoc::config::<T>()`; avoid hardcoding port, address, or database URLs in source

## Hard Rules emitted

```
HARD_RULE: Route handlers MUST be thin — delegate all business logic to a service layer
  path_glob: src/routes/**/*.rs
  rule_type: CUSTOM
  rationale: Thin handlers keep routes testable and maintain separation of concerns; business logic in route functions couples the HTTP layer to domain logic

HARD_RULE: Authentication and per-request validation MUST be implemented as request guards (FromRequest), not inline handler logic
  path_glob: src/routes/**/*.rs
  rule_type: CUSTOM
  rationale: Request guards provide composable, reusable auth/validation that short-circuits before the handler body; inline checks are not reusable and can be accidentally omitted

HARD_RULE: Shared dependencies (database pools, config, external clients) MUST be injected via managed state (.manage() + &State<T>), not global statics
  path_glob: src/main.rs
  rule_type: CUSTOM
  rationale: Rocket managed state is lifecycle-safe and testable; global statics bypass Rocket's startup validation and make test isolation impossible

HARD_RULE: Cross-cutting concerns (CORS, logging, DB health, request mutation) MUST be implemented as fairings attached via .attach(), not as logic duplicated across handlers
  path_glob: src/fairings/**/*.rs
  rule_type: CUSTOM
  rationale: Fairings are the canonical Rocket lifecycle hook; duplicating cross-cutting logic across handlers is fragile and inconsistent

HARD_RULE: Routes MUST be registered via .mount() with the routes![] macro — never invoked directly as functions for routing
  path_glob: src/main.rs
  rule_type: CUSTOM
  rationale: Only routes registered through .mount() are part of Rocket's routing tree; direct calls bypass path matching, guard resolution, and fairings

HARD_RULE: JSON request bodies MUST be received as Json<T> where T derives serde::Deserialize — never via raw body readers for structured input
  path_glob: src/routes/**/*.rs
  rule_type: CUSTOM
  rationale: Json<T> provides automatic deserialization and a 422 Unprocessable Entity on malformed input; raw body reads bypass type-safe validation
```

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — `FromForm` structs with `#[field(validate = ...)]` validators run before the handler body, and `Json<T>` rejects malformed bodies with a 422; the bypass is accepting raw `Data`/`String` parameters or `&str` segments that skip typed parsing — keep every input behind a form/guard/`Json` type so failed validation never reaches the handler.
- **SQL injection** — `rocket_db_pools` with sqlx (`query!`/`.bind()` placeholders) or Diesel's typed DSL parameterizes by construction; `format!`-built SQL strings handed to `sqlx::query(&s)` or `diesel::sql_query` reintroduce SQLi — bind parameters or stay in the macro/DSL.
- **XSS / output escaping** — `rocket_dyn_templates` (Tera or Handlebars) auto-escapes HTML output in `Template::render`; Tera's `| safe` filter and Handlebars' triple-brace `{{{...}}}` mark input as raw — those are the bypasses — as is returning `content::RawHtml(format!(...))` built from user input.
- **CSRF** — no built-in token mechanism; bearer-token APIs are CSRF-immune by design, but cookie-session apps (private cookies) need a double-submit or synchronizer-token check in a request guard or fairing on state-changing routes, plus an explicit `SameSite` policy on the session cookie — a cookie-auth POST without a token check is the hole.
- **AuthN/AuthZ enforcement point** — request guards (`FromRequest` types like `AuthenticatedUser`, `AdminUser`) declared as handler parameters short-circuit with 401/403 before the body runs; the bypass is structural: a route that omits the guard parameter compiles and is wide open — guards protect only the signatures that declare them, so audit every mounted route for the expected guard.
- **Password hashing** — the `argon2` crate (argon2id) or `bcrypt` crate via `PasswordHasher`/`verify_password`; hashing a password with `sha2` or comparing digests with `==` is the bypass — fast hashes are brute-forceable and naive comparison leaks timing.
- **Mass assignment** — dedicated `CreateUserInput`/`LoginRequest`-style structs (already the pack's naming standard) carry only client-settable fields; deriving `Deserialize`/`FromForm` on the DB model exposes `role`/`is_admin`/`id` to over-posting — map input structs to models explicitly and add `#[serde(deny_unknown_fields)]` on JSON inputs.
- **Secrets / config** — `Rocket.toml` + `ROCKET_`-prefixed env vars via figment; the `secret_key` encrypts/signs private cookies and MUST come from the environment in release (Rocket refuses ephemeral keys there) — committing `secret_key` or a database URL into `Rocket.toml`/source is the bypass.
- **File uploads** — accept via the `TempFile` form guard with size caps from `Rocket.toml` limits (`limits.file`, per-type `limits."file/jpg"`), allowlist the content type, and `persist_to` a server-generated name outside any `FileServer::from`-mounted directory; trusting `raw_name()` (the client filename) invites traversal, and persisting into `static/` makes uploads directly retrievable — those are the bypasses.

## Testing conventions

- **Test runner**: `cargo test` — standard Rust test runner; run `cargo test` from the project root
- **Test file location**: integration tests under `tests/` (each file is a crate compiled against the library); unit tests as `#[cfg(test)]` modules inline within `src/**/*.rs`
- **Rocket test client**: `rocket::local::blocking::Client` (synchronous) or `rocket::local::asynchronous::Client` (async, `#[rocket::async_test]`) — both are in `rocket::local` and wrap a `Rocket<Build>` instance; instantiate with `Client::tracked(rocket())` for cookie tracking or `Client::untracked(rocket())` for stateless tests
- **Test function annotation**: `#[test]` for blocking tests; `#[rocket::async_test]` for async tests; test functions are snake_case
- **Request dispatch in tests**: use `client.get("/path").dispatch()` to send a request; inspect the `LocalResponse` for status via `.status()` and body via `.into_string()`
- **Managed state in tests**: call `.manage(mock_value)` on the `Rocket<Build>` instance before passing it to `Client::tracked(...)` — this replaces real dependencies with test doubles
- **Example integration test pattern**:
  ```rust
  use rocket::local::blocking::Client;
  use rocket::http::Status;

  #[test]
  fn test_get_user() {
      let client = Client::tracked(rocket()).expect("valid rocket instance");
      let response = client.get("/users/1").dispatch();
      assert_eq!(response.status(), Status::Ok);
  }
  ```

## Deep-scan file hints

```yaml
auth_hints:
  - "src/guards/auth.rs"
  - "src/guards/auth_guard.rs"
  - "src/guards/api_key.rs"
  - "src/fairings/auth.rs"
  - "src/config/jwt.rs"
  - "src/guards/**"
authz_hints:
  - "src/guards/admin.rs"
  - "src/guards/role_guard.rs"
  - "src/guards/**"
  - "src/fairings/**"
ui_hints:
  - "templates/"
  - "static/"
```

## Authz mapping

- `mechanism`: `request-guard` (auth and role enforcement implemented as `FromRequest` request guards) and `fairing` (for request-level cross-cutting auth checks via `on_request`)
- `role_source`: `token` (JWT claims decoded in a guard, e.g. via `jsonwebtoken` crate) or `db` (role loaded from a database pool accessed through managed state inside the guard)
- Construct → `declarations[].kind`:
  - A `FromRequest` implementation that verifies authentication (e.g. `AuthenticatedUser`) and returns `Outcome::Failure((Status::Unauthorized, ...))` when unauthenticated → `{kind: guard}`
  - A role-enforcing `FromRequest` guard (e.g. `AdminUser`) that checks a role claim and returns `Outcome::Failure((Status::Forbidden, ...))` when unauthorized → `{kind: role}`
  - An auth fairing (e.g. `AdHoc::on_request(...)` that sets a request-local auth flag) → `{kind: middleware}`
- Common patterns:
  - `jsonwebtoken`: token verified inside a `FromRequest` impl; decoded claims stored in the guard struct; handler receives the guard as a typed parameter (e.g. `user: AuthenticatedUser`)
  - Role-based: role embedded in JWT claims or fetched via `&State<DbPool>` inside the guard; `AdminUser` guard calls the `AuthenticatedUser` guard and additionally checks the role field
  - Casbin: enforcer held in managed state (`&State<CasbinEnforcer>`); a role guard fetches it via `request.rocket().state::<CasbinEnforcer>()` and calls `enforcer.enforce((sub, obj, act))`

## UI detection

_(N/A: API-first; `rocket_dyn_templates` with Tera or Handlebars is optional)_

If server-rendered HTML is used, detection signals are:

- **Template engine**: `rocket_dyn_templates` crate; attach via `.attach(Template::fairing())` in the launch function; templates live under `templates/` with `.html.tera` or `.html.hbs` extensions
- **Template rendering**: return `Template::render("template_name", context_map)` from a handler (implements `Responder`)
- **Static files**: `.mount("/static", rocket::fs::FileServer::from("static/"))` in the launch function

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "src/utils/**", "src/helpers/**" ]
  model_api: [ "src/models/**" ]
  services: [ "src/services/**" ]
  commands: [ "src/bin/**" ]
```

- `model_api`: domain structs, their `impl` blocks, and trait implementations in `src/models/`; includes ORM model definitions (e.g. Diesel schema types, SeaORM entities) and repository interfaces.
- `services`: service structs and their public method impls in `src/services/`; each service file exposes the domain API (e.g. `UserService::find_by_id`, `OrderService::create`).
- `commands`: additional binary entry points under `src/bin/`; each file is a separate compiled binary (e.g. a migration runner, a background worker).
