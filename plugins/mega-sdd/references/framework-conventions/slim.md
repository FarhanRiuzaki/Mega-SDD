---
framework: slim
framework_version_range: "4.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: composer.json
  dependency_marker: "slim/slim"
  version_regex: '"slim/slim"\s*:\s*"[\^~]?(\d+)\.'
extends: _universal
pack_tier: full
---

# Slim Convention Pack (4.x)

Conventions for Slim 4 PHP micro-framework projects. Extends `_universal.md` — universal defaults apply, Slim-specific rules override on conflict.

Slim is intentionally minimal: it provides PSR-7 request/response dispatch, PSR-15 middleware, and PSR-11 DI container integration. This pack documents the **widely-adopted community structure**: `src/Action/` single-action invokables + `src/Domain/` services + `config/` wiring, with `public/index.php` as the entry point.

## File location standards

| Artifact | Path |
|---|---|
| App entry point | `public/index.php` |
| App bootstrap / factory | `src/Application/` or `app/` (e.g. `App.php`, `Middleware.php`, `Routes.php`) |
| Action classes (single-action invokables) | `src/Action/` (e.g. `src/Action/User/ListUsersAction.php`) |
| Domain services | `src/Domain/` (e.g. `src/Domain/User/UserRepository.php`, `src/Domain/User/UserService.php`) |
| Middleware | `src/Middleware/` |
| Infrastructure / persistence | `src/Infrastructure/Persistence/` or `src/Infrastructure/` |
| Route definitions | `config/routes.php` |
| DI container definitions | `config/dependencies.php` (or `config/container.php`) |
| Middleware stack | `config/middleware.php` |
| Settings / env | `config/settings.php` or `src/Application/Settings.php` |
| Templates (if Twig/PHP-View) | `templates/` |
| Tests | `tests/` (`tests/Action/`, `tests/Domain/`) |
| Vendor autoload | `vendor/autoload.php` |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Action class | PascalCase + `Action` suffix | `ListUsersAction`, `CreateUserAction` |
| Action filename | PascalCase + `Action.php` | `ListUsersAction.php` |
| Middleware class | PascalCase + `Middleware` suffix | `JwtAuthMiddleware`, `ValidationMiddleware` |
| Middleware filename | PascalCase + `Middleware.php` | `JwtAuthMiddleware.php` |
| Domain service | PascalCase + `Service` suffix | `UserService`, `InvoiceService` |
| Repository interface | PascalCase + `Repository` suffix | `UserRepository` (interface) |
| Repository implementation | PascalCase + `Db` or `InMemory` + `Repository` suffix | `InMemoryUserRepository`, `DbUserRepository` |
| Route path | kebab-case, noun-plural for collections | `/users`, `/user-invoices`, `/auth/token` |
| Method case | camelCase | `findById`, `createUser` |
| Settings key | camelCase array key | `['displayErrorDetails', 'logger']` |
| Test class | PascalCase + `Test` suffix | `ListUsersActionTest`, `UserServiceTest` |

## Idioms (preferred patterns)

- **Single-action invokable classes in `src/Action/`** — each action handles exactly one HTTP endpoint via `__invoke(ServerRequestInterface $request, ResponseInterface $response, array $args): ResponseInterface`; no controller with multiple actions
- **PSR-7 request/response — never modify request/response in-place** — `ResponseInterface` is immutable; always return a new/modified response: `return $response->withJson([...])` or write to the body with `$response->getBody()->write(...)`
- **Route definitions in `config/routes.php`** — load with `(require __DIR__ . '/routes.php')($app)` in `public/index.php`; use `$app->get()`, `$app->post()`, `$app->put()`, `$app->delete()`, `$app->patch()` with class name strings: `$app->get('/users', ListUsersAction::class)`
- **Route groups** — group related routes with `$app->group('/users', function (RouteCollectorProxyInterface $group) { ... })` and attach group-level middleware with `->add(AuthMiddleware::class)`
- **PSR-11 DI container via PHP-DI** — define bindings in `config/dependencies.php`; inject dependencies through action/service constructors; call `AppFactory::setContainer($container)` before `AppFactory::create()`
- **Constructor injection for actions** — actions receive services via constructor; the container auto-wires when PHP-DI autowiring is enabled; avoid service locator `$container->get()` calls inside action bodies
- **PSR-15 middleware for cross-cutting concerns** — middleware implements `MiddlewareInterface` (`process(Request, RequestHandler): Response`) or is an invokable with `__invoke(Request, RequestHandler): Response`; register global middleware via `$app->addMiddleware(...)` / `$app->add(...)`; register route-level middleware via `->add(...)` on route or group
- **`Slim\App` created via `Slim\Factory\AppFactory::create()`** — never instantiate `Slim\App` directly; use the factory so the container and PSR-7 implementation are picked up automatically
- **Settings as a plain PHP array injected via container** — expose app settings (database DSN, log path, display error details) as a `Settings` value object or plain array bound in `config/dependencies.php`; read in constructors, not from globals
- **Domain services decouple HTTP from business logic** — actions parse the PSR-7 request, call a domain service, and write the response; domain services know nothing about HTTP

## Hard Rules emitted

```
HARD_RULE: Action classes MUST implement __invoke(ServerRequestInterface, ResponseInterface, array): ResponseInterface
  path_glob: src/Action/**/*.php
  rule_type: SIGNATURE_RULE
  pattern: 'public function __invoke\s*\(\s*ServerRequestInterface'
  rationale: Slim resolves class-name route callables via __invoke; a missing or mis-typed signature silently breaks dispatch

HARD_RULE: Route callables MUST reference action classes by fully qualified class name string — not inline closures except in bootstrapping
  path_glob: config/routes.php
  rule_type: CUSTOM
  rationale: Closure callables cannot be serialized for route caching and prevent constructor injection of dependencies

HARD_RULE: Action classes MUST NOT contain business logic — delegate to domain services in src/Domain/
  path_glob: src/Action/**/*.php
  rule_type: CUSTOM
  rationale: Actions are thin HTTP adapters; business logic in actions is untestable without a full HTTP stack

HARD_RULE: PSR-7 Response MUST be returned (not echoed) — never use echo/print inside actions
  path_glob: src/Action/**/*.php
  rule_type: CUSTOM
  rationale: Slim relies on the returned Response object for output buffering, middleware wrapping, and testing

HARD_RULE: DI container definitions MUST live in config/dependencies.php (or config/container.php) — not inline in public/index.php beyond bootstrapping
  path_glob: config/dependencies.php
  rule_type: LOCATION_RULE
  rationale: Centralised container definitions make bindings auditable and prevent bootstrap file bloat

HARD_RULE: Middleware MUST be applied via $app->add() or $group->add() / route->add() — not called directly in action bodies
  path_glob: src/Middleware/**/*.php
  rule_type: CUSTOM
  rationale: Direct calls to middleware in action bodies bypass the PSR-15 middleware stack and break orthogonal concerns
```

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — Slim ships none; validate `$request->getParsedBody()` with Respect\Validation (or a validation middleware) inside the Action before it reaches the domain layer — handing the parsed body straight to a service is unvalidated input.
- **SQL injection** — PDO prepared statements / Doctrine DBAL with bound parameters; concatenating request values into `$pdo->query("... $v")` (or DBAL `executeQuery` with interpolated strings) is the bypass — always `prepare` + bind.
- **XSS / output escaping** — with slim/twig-view, Twig autoescapes and `|raw` is the bypass; with plain PHP-View templates there is NO autoescape — every echo of user data must pass through `htmlspecialchars(..., ENT_QUOTES)`.
- **CSRF** — not built in; the idiom is slim/csrf (`Slim\Csrf\Guard`) added as app-level middleware with the token pair rendered in every form — a cookie-session Slim app without it is exposed.
- **AuthN/AuthZ enforcement point** — PSR-15 middleware on routes/groups (`$group->add(AuthMiddleware::class)`, or tuupola/slim-jwt-auth) returning 401/403 before the Action runs; auth checks written inside Action bodies are the bypass smell — skippable and inconsistent.
- **Password hashing** — PHP native `password_hash($pw, PASSWORD_DEFAULT)` / `password_verify()` (bcrypt/argon2id); never `md5()`/`sha1()` or hand-rolled salts.
- **Mass assignment** — stock Slim has no model auto-binding, so the exposure is hand-rolled hydration: spreading the parsed body into an entity constructor or a generic `fill($body)` writes whatever the client posts — hydrate via an explicit field allowlist in the Action/DTO.
- **Secrets / config** — env via vlucas/phpdotenv loaded into container settings; credentials hardcoded in the settings array or a committed `.env` are the leak.
- **File uploads** — PSR-7 `UploadedFileInterface`: check `getError()`, enforce size limits and a server-side MIME sniff, and generate your own filename for `moveTo()` — `getClientFilename()`/`getClientMediaType()` are attacker-controlled.
- **Session/cookie posture** — PHP sessions are app-managed here: `session_set_cookie_params(['httponly' => true, 'secure' => true, 'samesite' => 'Lax'])` plus `session_regenerate_id(true)` on login; the PHP defaults are not production-safe.

## Testing conventions

- **Test runner**: PHPUnit (`phpunit/phpunit`) — run via `./vendor/bin/phpunit`
- **PHPUnit config**: `phpunit.xml` or `phpunit.xml.dist` at project root
- **Test file location**: `tests/` mirroring `src/` structure — `tests/Action/` for action tests, `tests/Domain/` for domain service tests
- **Test naming**: PascalCase + `Test` suffix — `ListUsersActionTest.php`; test methods use `test_<scenario>` or `@test` annotation
- **HTTP integration testing**: build a real PSR-7 `ServerRequest` using `Slim\Psr7\Factory\ServerRequestFactory` (or `nyholm/psr7`) and pass it to `$app->handle($request)`; no live server needed
- **Example action test pattern**:
  ```php
  use Slim\Factory\AppFactory;
  use Slim\Psr7\Factory\ServerRequestFactory;

  $app = AppFactory::create();
  (require __DIR__ . '/../../config/routes.php')($app);

  $request = (new ServerRequestFactory())->createServerRequest('GET', '/users');
  $response = $app->handle($request);

  $this->assertSame(200, $response->getStatusCode());
  ```
- **Domain unit tests**: construct the service with a test double repository (`InMemoryUserRepository`); call service methods directly without booting the full app
- **Test doubles**: use PHPUnit `createMock()` / `createStub()` for repository interfaces; prefer in-memory implementations over mocks for integration scenarios
- **Database isolation**: use an in-memory SQLite or a test-scoped transaction; define fixture data in `tests/fixtures/` or factory helpers

## Deep-scan file hints

```yaml
auth_hints:
  - "src/Middleware/JwtAuthMiddleware.php"
  - "src/Middleware/AuthMiddleware.php"
  - "config/dependencies.php"
  - "config/settings.php"
authz_hints:
  - "src/Middleware/"
  - "config/routes.php"
ui_hints:
  - "templates/"
  - "src/Application/"
```

## Authz mapping

- `auth.mechanism`: `token` (JWT via `tuupola/slim-jwt-auth` or custom `JwtAuthMiddleware`) or `session` (rare in API-first Slim apps)
- `authz.mechanism`: `middleware` (PSR-15 middleware added to routes/groups via `->add()`)
- `authz.role_source`: `token` (JWT claims decoded by auth middleware, attached to request attributes) or `db` (role fetched from database in middleware)
- Construct → `declarations[].kind`:
  - An auth middleware added via `$app->add(JwtAuthMiddleware::class)` or `$group->add(AuthMiddleware::class)` → `{kind: middleware}`
  - A role-check middleware that inspects `$request->getAttribute('role')` and rejects unauthorized roles → `{kind: role}`
  - `tuupola/slim-jwt-auth` `JwtAuthentication` instance added via `$app->add(new JwtAuthentication([...]))` → `{kind: middleware, sub: jwt}`

## UI detection

_(N/A: API-first; Twig/PHP-View templates optional)_

If a view renderer is configured in `config/dependencies.php` (e.g. `Slim\Views\Twig` or `Slim\Views\PhpRenderer`), detection signals are:

- **Template directory**: `templates/` (passed as first argument to `new Twig('templates', [...])`); renderer bound in `config/dependencies.php`
- **Layout detection**: Twig `{% extends 'layout.html.twig' %}` at top of page templates; PHP-View sets layout via `$this->layout = '../templates/layout.php'`
- **Renderer declared in**: `config/dependencies.php` — `$container->set(Twig::class, fn() => Twig::create('templates', [...]))`

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "src/Helper/**", "src/Support/**" ]
  model_api: [ "src/Domain/**", "src/Infrastructure/Persistence/**" ]
  services: [ "src/Domain/**/*Service.php", "src/Application/**/*Service.php" ]
  commands: [ "src/Console/**", "bin/**" ]
```
- `model_api`: domain entity methods, repository interface methods, and persistence implementations.
- `services`: domain service classes encapsulating business rules; injected into actions via constructor.
- `commands`: CLI entry points under `bin/` and console command classes under `src/Console/`.

## Flow-artifact derivation

> Consumed by `validate-flow-coverage.sh` (code-delivery slice A).
> In Slim 4, an input-accepting state-transition step is handled by a dedicated
> Action class that reads the parsed request body; no formal Form/Request object exists,
> but one Action class per endpoint is the required artifact.

```yaml
endpoint_kinds:
  - flow_signal: '(?i)\b(submit(?:s|ted|ting)?|resubmit(?:s|ted|ting)?|review(?:s|ed|ing)?|approv(?:e|es|ed|al|ing)|reject(?:s|ed|ing|ion)?|confirm(?:s|ed|ing|ation)?|dispatch(?:es|ed|ing)?|appl(?:y|ies|ied|ying)|finaliz(?:e|es|ed|ing)|enrich(?:es|ed|ing)?)\b'
    required_artifact: action-class
    path_glob: src/Action/**/*.php
    naming: '{Action}{Module}Action'
```

## Conditional scaffold artifacts

> Consumed by `validate-flow-coverage.sh` (code-delivery slice A — anti dead-stub).

```yaml
- artifact_glob: 'templates/**/edit.html.twig'
  requires_flow_endpoint: '(?i)\b(update|edit|put|patch)\b'
```

## Entity source globs

> Consumed by `validate-flow-coverage.sh` (code-delivery slice A — module matching).

```yaml
entity_sources:
  - pattern: 'src/Action/(?P<entity>[A-Za-z]+)/'
    exclude: ['Base', 'Abstract', 'Shared']
  - pattern: 'src/Domain/(?P<entity>[A-Za-z]+)/'
    exclude: ['Base', 'Shared']
  - pattern: '/(?P<entity>[A-Za-z]+)Action\.php'
```

## Entity matching tokens

```yaml
stop_tokens: []
compound_aliases: {}
```

## Test patterns

> Consumed by `validate-unit-spec.sh` (code-delivery slice D — render-test-per-module gate).
> Slim is typically API-first; no server-rendered detail view convention.
> If Twig is configured, a detail view is a `show.html.twig` under `templates/`.

```yaml
detail_view_glob: 'templates/**/show.html.twig'
detail_view_render:
  template: |
    $app = AppFactory::create();
    (require __DIR__ . '/../../config/routes.php')($app);
    $request = (new ServerRequestFactory())->createServerRequest('GET', '/{resource}/{id}');
    $response = $app->handle($request);
    $this->assertSame(200, $response->getStatusCode());
    $this->assertStringContainsString('{display_field}', (string) $response->getBody());
  test_glob: tests/**/*Test.php
```

## UI quality signatures

> Consumed by `validate-ui-quality.sh` (code-delivery slice E).
> Only applicable when Twig is configured; if no templates/ directory exists, the
> validator writes `status: SKIP` for this pack.

```yaml
view_glob: 'templates/**/*.html.twig'
min_view_lines: 20
scaffold_tells:
  - id: raw-action-class-in-title
    regex: '<title>\s*[A-Z][a-zA-Z]+Action'
    message: "Page title leaks an Action class name. Set a human page title."
  - id: native-alert
    regex: "\b(alert|confirm|prompt)\s*\("
    message: "Native JS dialog instead of the project notification idiom."
required_elements:
  - id: layout-extends
    regex: '\{%[-\s]+extends\s+'
    message: "Template does not extend a base layout. Use {% extends 'layout.html.twig' %}."
```

## Cross-cutting concerns

> Consumed by `validate-sibling-consistency.sh` (slice B) and
> `validate-cross-cutting-registration.sh` (slice C).
> In Slim, auth/authz is enforced via PSR-15 middleware added to routes or groups.

```yaml
cross_cutting_concerns:
  - concern: jwt-auth
    applies_when: 'has_column:owner_id'
    spec_obligation: '\bMiddleware\b|\badd\('
    registration_signature: '->add\(|addMiddleware\('
    registration_target_glob: 'config/routes.php'
    registration_source_glob: 'src/Middleware/**/*.php'
```

## Relation derivation

> Consumed by `validate-sibling-consistency.sh` (slice B — relation coherence).
> Slim has no built-in ORM; relation derivation depends on the persistence layer.
> This entry documents the most common pattern (no ORM, manual FK handling).

```yaml
relation_derivation:
  fk_to_accessor:
    rule: '{singular}_id => accessor method `get{Singular}()` (PascalCase getter) on the domain entity'
    accessor_template: 'get{PascalSingular}()'
    accessor_form: call
```

## Notes / Slim-specific guidance

- **PSR-7 implementation is NOT bundled** — Slim 4 requires a separate PSR-7 implementation; common choices: `slim/psr7` (official), `nyholm/psr7` + `nyholm/psr7-server`, or `guzzlehttp/psr7`. Detect from `composer.json`.
- **`AppFactory` handles PSR-7 auto-detection** — `AppFactory::create()` auto-detects the installed PSR-7 implementation; no manual wiring needed if only one is installed.
- **Routing middleware order matters** — `$app->addRoutingMiddleware()` must be added before `$app->addErrorMiddleware()`; error middleware must be the last added so it wraps the whole stack.
- **Route caching** — enable in production via `$routeCollector->setCacheFile(...)` on the router; requires all callables to be class-name strings (not closures).
- **Request attributes for middleware data passing** — middleware attaches decoded JWT payload or user object via `$request->withAttribute('user', $user)`; actions read with `$request->getAttribute('user')`.
- **`tuupola/slim-jwt-auth`** — the de-facto JWT middleware for Slim 4; configured as `new JwtAuthentication(['secret' => ..., 'path' => '/api', 'ignore' => ['/auth/token']])` added via `$app->add(...)`.
- **Slim Twig-View / PHP-View** — optional renderer packages (`slim/twig-view`, `slim/php-view`); bind the renderer in `config/dependencies.php` and inject into actions that need it; most Slim projects are API-only and have no templates.
- **Lock file**: `composer.lock` (committed); install via `composer install`; update via `composer update`.
