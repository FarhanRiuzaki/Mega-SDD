---
framework: fastapi
framework_version_range: "0.110+"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: pyproject.toml
  dependency_marker: "fastapi"
  version_regex: 'fastapi\s*[>=!^~]+\s*"?([0-9]+\.[0-9]+)'
extends: _universal
pack_tier: full
---

# FastAPI Convention Pack (0.110+)

Conventions for FastAPI backend projects. Extends `_universal.md` — universal defaults apply, FastAPI-specific rules override on conflict.

## File location standards

| Artifact | Path |
|---|---|
| Main app entrypoint | `app/main.py` |
| Routers | `app/routers/` or `app/api/` |
| Pydantic schemas (request/response) | `app/schemas/` |
| Database models (SQLAlchemy/SQLModel) | `app/models/` |
| Dependency functions | `app/dependencies.py` or `app/deps/` |
| Services / business logic | `app/services/` |
| Core config | `app/core/config.py` |
| Database session setup | `app/core/database.py` or `app/db/session.py` |
| Auth / security helpers | `app/auth/` or `app/core/security.py` |
| Tests | `tests/` (with `tests/conftest.py`) |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Router module filename | snake_case | `items.py`, `users.py` |
| Router instance | lowercase noun `router` | `router = APIRouter()` |
| Path operation function | snake_case verb + noun | `read_item`, `create_user`, `delete_item` |
| Pydantic schema class | PascalCase + intent suffix | `UserCreate`, `UserRead`, `ItemUpdate` |
| Response schema class | PascalCase + `Read` or `Response` suffix | `UserRead`, `TokenResponse` |
| Database model class | PascalCase singular | `User`, `Item`, `Order` |
| Dependency function | `get_` prefix snake_case | `get_db`, `get_current_user` |
| Service class | PascalCase + `Service` suffix | `UserService`, `OrderService` |
| Tag (for OpenAPI grouping) | lowercase or Title Case noun | `"users"`, `"items"`, `"auth"` |
| Router prefix | kebab-case URI segment | `/users`, `/items`, `/auth` |
| Column/field name | snake_case | `created_at`, `user_id` |
| FK field | `{singular_target_model}_id` | `user_id`, `order_id` |

## Idioms (preferred patterns)

- **APIRouter for modular routing** — define routes in dedicated router modules under `app/routers/`; include them in `app/main.py` with `app.include_router(router, prefix="/items", tags=["items"])`
- **Dependency injection via `Depends()`** — inject shared resources (DB session, current user, config) through `Depends()`; never access DB or auth state directly in path operations
- **Pydantic models for all input/output** — declare `BaseModel` subclasses for every request body and response; use `response_model=` on every path operation decorator to enforce the output shape
- **Async path operations by default** — declare endpoint functions with `async def` unless calling sync-only libraries; use `await` for async DB drivers (SQLAlchemy async, Motor, etc.)
- **HTTP status codes explicit** — set `status_code=` on every decorator that returns non-200 (e.g. `status_code=status.HTTP_201_CREATED` for POST, `status_code=status.HTTP_204_NO_CONTENT` for DELETE)
- **OAuth2PasswordBearer + SecurityScopes for auth** — use `OAuth2PasswordBearer(tokenUrl="token")` to declare the bearer scheme; use `Security(get_current_user, scopes=["items:read"])` to gate endpoints by scope
- **Annotated dependencies (FastAPI 0.95+)** — prefer `Annotated[User, Depends(get_current_user)]` over bare `current_user: User = Depends(...)` for cleaner signatures and re-usability
- **Lifespan context for startup/shutdown** — manage app lifecycle (DB pool creation, ML model load) via the `lifespan=` parameter on `FastAPI()`; avoid deprecated `@app.on_event`
- **Pydantic Settings for configuration** — use `pydantic-settings` `BaseSettings` at `app/core/config.py`; load from environment variables + `.env` file; never hard-code credentials in source
- **HTTPException with detail** — raise `HTTPException(status_code=..., detail="...")` for user-facing errors; define custom exception handlers with `@app.exception_handler(ExcType)` for domain exceptions

## Hard Rules emitted

```
HARD_RULE: Path operation functions MUST use Pydantic BaseModel for request body (not dict or Any)
  path_glob: app/routers/**/*.py
  rule_type: CUSTOM
  rationale: Pydantic body models enable validation, serialization, and OpenAPI schema generation; untyped bodies break all three

HARD_RULE: Every path operation decorator MUST specify response_model= when the endpoint returns a structured response
  path_glob: app/routers/**/*.py
  rule_type: CUSTOM
  rationale: response_model enforces output shape and populates OpenAPI response schema; absent response_model allows internal fields to leak

HARD_RULE: Database session MUST be injected via Depends() — never instantiated directly inside a path operation
  path_glob: app/routers/**/*.py
  rule_type: DEP_RULE
  rationale: Depends-managed session ensures the session is properly closed after the request and supports test overrides via app.dependency_overrides

HARD_RULE: Business logic MUST NOT be placed directly in path operation functions — extract to app/services/
  path_glob: app/routers/**/*.py
  rule_type: CUSTOM
  rationale: Thin path operations are testable in isolation; business logic in path operations is untestable without the HTTP stack

HARD_RULE: Auth/authorization dependencies MUST be wired via Depends() or Security() — never via inline token parsing in path operations
  path_glob: app/routers/**/*.py
  rule_type: DEP_RULE
  rationale: Centralised auth dependencies are unit-testable and overrideable; inline token parsing duplicates logic and is not overrideable in tests

HARD_RULE: Router modules MUST be in app/routers/ or app/api/ and declare a module-level APIRouter instance named `router`
  path_glob: app/routers/**/*.py
  rule_type: NAMING_RULE
  pattern: 'router\s*=\s*APIRouter'
  rationale: Consistent instance naming enables include_router() to import `from .routers.items import router` across all modules without structural exceptions
```

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — Pydantic models on body/query/path params validate at the boundary automatically; taking `request: Request` and reading `await request.json()` into a raw dict bypasses all of it.
- **SQL injection** — SQLAlchemy Core/ORM expressions parameterize; `text()` with f-string interpolation is the escape hatch that reintroduces SQLi — use `text("... :v").bindparams(v=v)` or stay in the expression language.
- **XSS / output escaping** — no server templates by default (JSON responses); if `Jinja2Templates` is added, autoescape is on and `|safe` is the bypass — for pure-JSON APIs the adjacent risk is reflecting unsanitized HTML strings that browser clients render.
- **CSRF** — not built in, and not an exposure for pure `Authorization`-header bearer-token APIs; the moment auth moves into cookies (session or cookie-stored JWT) CSRF middleware (e.g. starlette-csrf) becomes mandatory — cookie auth without it is the gap.
- **AuthN/AuthZ enforcement point** — `Depends()` security dependencies (`OAuth2PasswordBearer`, `Security()` with scopes) on the route or `APIRouter(dependencies=[...])`; an `include_router()` that forgets the auth dependency is the silent bypass.
- **Password hashing** — passlib `CryptContext(schemes=["bcrypt"])` (or argon2) for hash/verify next to `OAuth2PasswordBearer` login flows; never plaintext comparison or bare `hashlib`.
- **Mass assignment** — separate Create/Update/Read Pydantic schemas plus `response_model=` on routes; reusing one schema everywhere (or returning ORM objects directly) both leaks columns like `hashed_password` and lets clients set server-owned fields.
- **Secrets / config** — pydantic-settings `BaseSettings` reads env/`.env` into typed config; secrets as module-level constants or committed defaults are the leak.
- **File uploads** — `UploadFile` streams to a spooled temp file; enforce a size limit, validate the real content (magic bytes), and never trust `.filename` or the client `content_type` for storage decisions.
- **CORS / token posture** — `CORSMiddleware` with an explicit `allow_origins` list; `allow_origins=["*"]` combined with `allow_credentials=True` is the misconfiguration that hands credentials to any origin.

## Testing conventions

- Test runner: `pytest` (via `pytest` CLI or `python -m pytest`)
- Test client: `fastapi.testclient.TestClient` (sync, wraps `httpx`) for synchronous test suites; `httpx.AsyncClient` with `transport=ASGITransport(app=app)` for async test suites
- Test file location: `tests/` at project root; mirrors `app/` structure (e.g. `tests/routers/test_items.py`, `tests/services/test_user_service.py`)
- Test naming: `test_<scenario>` functions in `test_<module>.py` files; use descriptive names (`test_create_item_returns_201`, `test_read_item_not_found_returns_404`)
- Fixtures: `tests/conftest.py` declares shared fixtures (test DB session, test client, authenticated user); use pytest `@pytest.fixture` scope `function` for DB isolation
- Dependency overrides: use `app.dependency_overrides[original_dep] = mock_dep` to override DB sessions and auth in tests; reset after each test to avoid cross-test contamination
- DB isolation: use a separate test database URL; wrap each test in a transaction rolled back after the test (or `pytest-anyio` + SQLAlchemy `AsyncSession` rollback fixture)
- Auth in tests: override `get_current_user` dependency to return a fixture user; never embed real secrets or real JWT generation in test code

## Deep-scan file hints

```yaml
auth_hints:
  - "app/core/security.py"
  - "app/auth/"
  - "app/dependencies.py"
  - "app/deps/"
  - "app/routers/auth.py"
  - "app/routers/login.py"
authz_hints:
  - "app/dependencies.py"
  - "app/deps/"
  - "app/auth/"
  - "app/core/security.py"
  - "app/routers/"
ui_hints: []
```

## Authz mapping

- `mechanism`: `dependency` (Security/Depends-based — all authorization is expressed as FastAPI dependency functions)
- `role_source`: `token` (OAuth2 scopes decoded from JWT claims) or `db` (role rows from the database, loaded inside a dependency)
- Construct → `declarations[].kind`:
  - `Security(get_current_user, scopes=["items:read"])` in a path operation parameter → `{kind: scope, name: "items:read"}`
  - `SecurityScopes.scopes` list checked inside `get_current_user` dependency → `{kind: scope, name: <each scope string>}`
  - `Depends(require_role("admin"))` factory pattern → `{kind: role, name: "admin"}`
  - `OAuth2PasswordBearer(tokenUrl=..., scopes={...})` declaration → `{kind: scope, name: <each scope key>}`

FastAPI's `OAuth2PasswordBearer` declares the OAuth2 scheme and the available scopes for OpenAPI UI. `SecurityScopes` is injected into dependency functions to inspect the cumulative scope requirements of the current request — use `security_scopes.scopes` (list) and `security_scopes.scope_str` (space-joined string for `WWW-Authenticate` headers).

## UI detection

_(N/A: API-only / no built-in UI)_

FastAPI is an API framework with no built-in server-side template rendering. If a project opts in to Jinja2 templates, it installs `jinja2` and uses `Jinja2Templates` from `fastapi.templating` with `TemplateResponse` in path operations. When Jinja2 templates are present, scan `app/templates/` for layout patterns.

## Reuse discovery

```yaml
reuse_hints:
  helpers:  [ "app/utils/**", "app/core/**" ]
  model_api: [ "app/models/**", "app/schemas/**" ]
  services: [ "app/services/**" ]
  commands: [ "app/cli/**" ]
```

- `model_api`: public methods, validators (`@field_validator`, `@model_validator`), and computed fields on Pydantic schema classes; also SQLAlchemy/SQLModel model class methods.
- `commands`: CLI entrypoints typically defined with `typer` or plain `click` under `app/cli/`; check for `typer.Typer()` instances or `@app.command()` decorators.
