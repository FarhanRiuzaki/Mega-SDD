---
framework: aspnetcore
framework_version_range: "ASP.NET Core 6+ (LTS 8.x baseline)"
last_verified_against: 2026-06-24
maintainer: mega-sdd
detection_signature:
  package_manifest: "*.csproj"
  dependency_marker: "Microsoft.AspNetCore."
  fallback_dependency_marker: '<Project Sdk="Microsoft.NET.Sdk.Web">'
  version_regex: '<TargetFramework>net(\d+\.\d+)'
extends: dotnet
pack_tier: full
---

# ASP.NET Core Convention Pack (web)

Conventions for ASP.NET Core 6+ web projects — Web API (controllers or Minimal APIs), MVC, Razor Pages, and Blazor. Extends `dotnet.md` — all base C# / .NET conventions apply (DI, async, options, logging, EF Core data access); this pack adds the web layer (routing, controllers, middleware, auth/authz, server/client UI).

> **Detection note**: the marker is `Microsoft.AspNetCore.` in a `*.csproj`, or the web SDK `<Project Sdk="Microsoft.NET.Sdk.Web">`. This is the specific pack; it MUST be resolved before the generic `dotnet` pack (web SDK present → `aspnetcore`).

## File location standards

| Artifact | Path |
|---|---|
| Host / pipeline configuration | `src/<Project>/Program.cs` |
| MVC / API controllers | `src/<Project>/Controllers/` |
| Minimal API endpoint groups | `src/<Project>/Endpoints/` |
| Middleware | `src/<Project>/Middleware/` |
| Action / endpoint filters | `src/<Project>/Filters/` |
| Razor views (MVC) | `src/<Project>/Views/{Controller}/` |
| Shared layouts (MVC) | `src/<Project>/Views/Shared/` |
| Razor Pages | `src/<Project>/Pages/` |
| Blazor components | `src/<Project>/Components/` (`*.razor`) |
| Static web assets | `src/<Project>/wwwroot/` |
| Request / response DTOs | `src/<Project>/Dtos/` (inherited from base) |
| App configuration | `src/<Project>/appsettings.json` + `appsettings.{Environment}.json` |
| Integration / functional tests | `tests/<Project>.Tests/` (`WebApplicationFactory`-based) |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Controller class | PascalCase + `Controller` suffix | `UsersController`, `OrdersController` |
| Action method | PascalCase (+ `Async` when awaitable) | `GetByIdAsync`, `Create` |
| Razor Page model | `<Page>Model` | `IndexModel`, `EditUserModel` |
| Blazor component | PascalCase `.razor` | `UserCard.razor`, `OrderList.razor` |
| MVC view file | matches action, PascalCase `.cshtml` | `Index.cshtml`, `Edit.cshtml` |
| Middleware class | PascalCase + `Middleware` suffix | `RequestLoggingMiddleware` |
| Filter class | PascalCase + `Filter`/`Attribute` suffix | `ValidationFilter`, `AuditAttribute` |
| Route template | lowercase kebab-case segments | `/api/order-items/{id}` |
| Authorization policy name | PascalCase string | `"CanEditOrders"` |

> All base .NET naming rules (PascalCase methods, `I`-prefixed interfaces, `Async` suffix, `_camelCase` private fields) are inherited from `dotnet.md`.

## Idioms (preferred patterns)

- **Attribute-routed `[ApiController]` for APIs** — decorate API controllers with `[ApiController]` + `[Route("api/[controller]")]` and per-action `[HttpGet]`/`[HttpPost]`/`[HttpPut]`/`[HttpDelete]`/`[HttpPatch]`; `[ApiController]` enables automatic model-state validation and ProblemDetails error bodies. Minimal APIs (`app.MapGet`/`MapPost` in `Program.cs` or an endpoint extension) are the idiomatic alternative for thin endpoints.
- **DTOs at the HTTP boundary** — accept and return request/response DTOs or `record`s, never EF Core entities; map deliberately in the controller or a mapper. This keeps the API contract decoupled from the persistence schema.
- **`ActionResult<T>` / typed results** — return `ActionResult<T>` (or `IActionResult`) from MVC actions and `Results`/`TypedResults` (`TypedResults.Ok(dto)`, `TypedResults.NotFound()`) from Minimal APIs, so status codes are explicit.
- **Pipeline order is load-bearing** — in `Program.cs` register middleware in the canonical order: `UseRouting` → `UseAuthentication` → `UseAuthorization` → endpoint mapping. `UseAuthentication` MUST come before `UseAuthorization`.
- **Scoped DI lifetimes for request services** — register request-scoped services with `AddScoped`, stateless singletons with `AddSingleton`, and the EF Core context with `AddDbContext` (scoped by default); never inject a scoped service into a singleton.
- **Policy-based authorization** — define named policies via `AddAuthorization(options => options.AddPolicy(...))` and apply with `[Authorize(Policy = "...")]` or endpoint `.RequireAuthorization("...")`; prefer policies over scattering raw role-string checks.
- **Centralized error handling** — handle exceptions with `UseExceptionHandler` + an `IExceptionHandler` (or exception-handling middleware) emitting ProblemDetails, rather than `try/catch` in every action.
- **Strongly-typed configuration** — bind `appsettings.json` sections to options classes and inject `IOptions<T>` (inherited base idiom); register them in `Program.cs`.

## Hard Rules emitted

These rules merge into `binding.md` §Suggested Unit Hard Rules when this pack is loaded.

```
HARD_RULE: Web controllers MUST end with the `Controller` suffix
  path_glob: src/**/Controllers/**/*.cs
  rule_type: NAMING_RULE
  pattern: 'Controller\.cs$'
  rationale: ASP.NET Core controller discovery and the `[controller]` route token both derive the route name by stripping the Controller suffix; non-conformant names break routing

HARD_RULE: API controllers MUST be annotated with `[ApiController]`
  path_glob: src/**/Controllers/**/*.cs
  rule_type: SIGNATURE_RULE
  pattern: '\[ApiController\]'
  rationale: Without [ApiController] the controller loses automatic model validation, binding-source inference, and ProblemDetails responses, so invalid input reaches action bodies unchecked

HARD_RULE: Controller actions MUST NOT return EF Core entity types directly — use a DTO
  path_glob: src/**/Controllers/**/*.cs
  rule_type: CUSTOM
  rationale: Returning entities leaks persistence shape and navigation graphs (over-posting, cyclic serialization, lazy-load surprises) and couples the API contract to the database schema

HARD_RULE: `UseAuthentication` MUST be registered before `UseAuthorization` in the pipeline
  path_glob: src/**/Program.cs
  rule_type: CUSTOM
  rationale: Authorization evaluates the authenticated principal; if authentication runs after (or is absent) every request is treated as anonymous and policies silently fail open

HARD_RULE: Endpoints serving non-public data MUST carry `[Authorize]` (or `.RequireAuthorization`)
  path_glob: src/**/Controllers/**/*.cs
  rule_type: CUSTOM
  rationale: ASP.NET Core endpoints are anonymous by default; an action without an authorization attribute and not deliberately marked `[AllowAnonymous]` is an unguarded surface
```

## Forbidden patterns

- Returning EF Core entities from actions / endpoints (use DTOs)
- `[AllowAnonymous]` on a sensitive endpoint, or a sensitive endpoint with no `[Authorize]` at all
- `Html.Raw(...)` / casting to `MarkupString` on unsanitized user input (XSS)
- `UseAuthorization` before `UseAuthentication`, or omitting `UseAuthentication` on an authenticated app
- CORS configured with `AllowAnyOrigin().AllowCredentials()` (rejected by the framework; an insecure intent)
- Disabling antiforgery validation on cookie-authenticated form POST endpoints
- Building business logic inside `Program.cs` or middleware (delegate to services — inherited base idiom)

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom. Base crypto/secrets/SQL idioms
> are inherited from `dotnet.md`.

- **Input validation** — `[ApiController]` auto-returns 400 ProblemDetails on invalid `ModelState`; combine with DataAnnotations / FluentValidation on DTOs. Omitting `[ApiController]` (or manual binding that skips `ModelState`) is the bypass.
- **XSS / output escaping** — Razor `@expression` and Blazor text bindings HTML-encode by default; `Html.Raw(...)`, `IHtmlContent` from raw strings, and rendering a `MarkupString` are the unsafe bypasses — valid only for content you sanitized.
- **CSRF / antiforgery** — cookie-authenticated form posts require an antiforgery token (`[ValidateAntiForgeryToken]` / `[AutoValidateAntiforgeryToken]`); Razor form helpers emit it automatically. Disabling it for a cookie flow is the smell; pure bearer-token APIs are legitimately exempt.
- **AuthN/AuthZ enforcement point** — authentication scheme registered via `AddAuthentication(...)` + `UseAuthentication`, authorization via `[Authorize]` attributes / named policies / endpoint `.RequireAuthorization()`. Missing `[Authorize]` or a stray `[AllowAnonymous]` on a protected route is the bypass.
- **Password hashing** — ASP.NET Core Identity's `IPasswordHasher<TUser>` (`PasswordHasher<TUser>`) for user credentials; for non-Identity flows fall back to the base PBKDF2 rule. Never plaintext or fast unsalted hashes.
- **CORS** — declare an explicit named policy via `AddCors` listing allowed origins/headers/methods; `AllowAnyOrigin().AllowCredentials()` is invalid and dangerous — name the trusted origins.
- **Transport security** — `UseHttpsRedirection` + `UseHsts` (outside Development) and `Secure`/`HttpOnly`/`SameSite` cookie flags on auth cookies; serving auth cookies over plain HTTP is the leak.
- **File uploads** — bind to `IFormFile`, bound size with `MultipartBodyLengthLimit` / `RequestSizeLimit`, validate content type server-side; the client-supplied `FileName` is attacker-controlled — never use it to build a storage path (inherited base traversal rule).
- **Mass assignment / over-posting** — bind to dedicated request DTOs, never to an EF Core entity exposed as the action parameter (inherited base idiom); `[Bind]` allow-lists are a secondary guard for MVC form binding.

## ERD additions (EF Core)

> Inherited from `dotnet.md` §ERD additions (keys, relationships, value generation, audit
> columns, soft-delete query filters). No web-layer ERD additions.

## Testing conventions

- Test runner: `dotnet test` (inherited base conventions: xUnit default, `Method_Scenario_ExpectedResult` naming, Moq/NSubstitute mocking)
- Integration tests: `WebApplicationFactory<TEntryPoint>` (`Microsoft.AspNetCore.Mvc.Testing`) spins up the app in-memory; issue requests with the factory's `HttpClient`
- Controller unit tests: instantiate the controller with mocked services and assert on the returned `ActionResult<T>` / status code
- Minimal API tests: prefer `WebApplicationFactory` integration tests over unit-testing inline endpoint lambdas
- Auth in tests: a test authentication handler (custom `AuthenticationHandler<>`) or `WebApplicationFactory.WithWebHostBuilder` overriding the auth scheme
- Database: the EF Core in-memory provider for fast tests, or SQLite/Testcontainers for relational fidelity (inherited base note)

## Migration / dependency management

> Inherited from `dotnet.md` (`dotnet restore` / `dotnet add package` / `dotnet build`,
> `packages.lock.json`, `dotnet ef migrations add`). Web build also produces static assets
> under `wwwroot/`; `dotnet publish` bundles the app for deployment.

## Deep-scan file hints

```yaml
auth_hints:
  - "src/**/Program.cs"
  - "src/**/appsettings.json"
  - "src/**/Areas/Identity/**"
  - "src/**/Identity/**"
authz_hints:
  - "src/**/Program.cs"
  - "src/**/Controllers/**/*.cs"
  - "src/**/Authorization/**"
  - "src/**/Policies/**"
ui_hints:
  - "src/**/Views/**"
  - "src/**/Pages/**"
  - "src/**/Components/**/*.razor"
  - "src/**/wwwroot/**"
```

## Authz mapping

- `auth.mechanism`: `cookie` (`AddAuthentication().AddCookie()` / Identity) or `jwt` (`AddJwtBearer`) or `oauth` (`AddOpenIdConnect` / external providers)
- `authz.mechanism`: `attribute` (`[Authorize]` on controllers/actions) + `policy` (named policies via `AddAuthorization`) + `middleware` (endpoint `.RequireAuthorization()`)
- `authz.role_source`: `claims` (principal claims from the token/cookie), `db` (ASP.NET Core Identity roles), or `config` (policy requirements defined in `Program.cs`)
- Construct → `declarations[].kind`:
  - `[Authorize(Roles = "Admin")]` → `{kind: role}`
  - `[Authorize(Policy = "CanEditOrders")]` → `{kind: policy}`
  - `AddAuthorization(o => o.AddPolicy("CanEditOrders", ...))` → policy definition
  - `.RequireAuthorization("CanEditOrders")` on a mapped endpoint → `{kind: policy}`
  - `[AllowAnonymous]` → explicit opt-out marker (review when on a sensitive route)

## UI detection

- template inheritance / dominant layout: MVC views set the `Layout` property (default `_Layout.cshtml`, established in `_ViewStart.cshtml`); Blazor components opt into a layout with the `@layout` directive (`MainLayout.razor`)
- component: an MVC partial (`<partial name="_Card" />` or `Html.PartialAsync`) or a Blazor component (`*.razor`) invoked as a tag (`<UserCard />`)
- notification call: MVC flash via `TempData["StatusMessage"]` surfaced in the layout, or a client-side toast library referenced from `_Layout.cshtml` / `wwwroot`

## Reuse discovery

```yaml
reuse_hints:
  helpers:  [ "src/**/Helpers/**/*.cs", "src/**/Extensions/**/*.cs", "src/**/Filters/**/*.cs" ]
  model_api: [ "src/**/Models/**/*.cs", "src/**/Entities/**/*.cs", "src/**/Dtos/**/*.cs" ]
  services: [ "src/**/Services/**/*.cs" ]
  commands: [ "src/**/Controllers/**/*.cs", "src/**/Endpoints/**/*.cs" ]
```

- model_api: public properties on DTOs/records and public methods on services consumed by controllers.
- commands: controller actions and Minimal API endpoint handlers are the web entry points (the request → response surface other code reuses through services).
