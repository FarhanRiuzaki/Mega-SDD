---
framework: symfony
framework_version_range: "6.4 — 7.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: composer.json
  dependency_marker: "symfony/framework-bundle"
  version_regex: '"symfony/framework-bundle"\s*:\s*"[\^~]?(\d+)\.'
extends: _universal
pack_tier: full
---

# Symfony Convention Pack (6.4 — 7.x)

Conventions for Symfony 6.4 LTS and 7.x backend/full-stack projects. Extends `_universal.md` — universal defaults apply, Symfony-specific rules override on conflict.

## File location standards

| Artifact | Path |
|---|---|
| Controllers | `src/Controller/` |
| Entities (Doctrine ORM) | `src/Entity/` |
| Repositories | `src/Repository/` |
| Services | `src/Service/` |
| Forms | `src/Form/` |
| Event subscribers / listeners | `src/EventSubscriber/` or `src/EventListener/` |
| Commands (console) | `src/Command/` |
| Security (authenticators, voters) | `src/Security/` |
| Data fixtures | `src/DataFixtures/` |
| Data Transfer Objects | `src/DTO/` (project convention) |
| Twig templates | `templates/` (`templates/<module>/<action>.html.twig`) |
| Config | `config/` |
| Package configs | `config/packages/` |
| Routes (YAML or PHP) | `config/routes/` or controller attributes |
| Services wiring | `config/services.yaml` |
| Migrations | `migrations/` |
| Console entry point | `bin/console` |
| Tests | `tests/` (`tests/Controller/`, `tests/Service/`, etc.) |
| Public assets | `public/` |
| Asset source files | `assets/` (Webpack Encore) or `assets/` (AssetMapper) |
| Translation files | `translations/` |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Column case | snake_case | `created_at`, `user_id` |
| Table case | snake_case (plural by convention) | `users`, `loan_applications` |
| Entity class | PascalCase singular | `User`, `LoanApplication` |
| Entity filename | PascalCase singular `.php` | `User.php`, `LoanApplication.php` |
| Controller class | PascalCase + `Controller` suffix | `UserController`, `InvoiceController` |
| Controller filename | PascalCase + `Controller.php` | `UserController.php` |
| Repository class | PascalCase + `Repository` suffix | `UserRepository`, `InvoiceRepository` |
| Service class | PascalCase + `Service` suffix | `InvoiceService`, `PaymentService` |
| Form type class | PascalCase + `Type` suffix | `UserType`, `InvoiceType` |
| Command class | PascalCase + `Command` suffix | `SendReminderCommand` |
| Voter class | PascalCase + `Voter` suffix | `InvoiceVoter`, `PostVoter` |
| Route name | snake_case with underscores or dot notation | `app_user_index`, `app_invoice_show` |
| Route URI | kebab-case | `/user-invoices`, `/admin/loan-applications` |
| Twig template | snake_case with `.html.twig` extension | `invoice/show.html.twig` |
| Migration filename | `Version<YYYYMMDDHHmmss>.php` (Doctrine) | `Version20260610120000.php` |
| FK column | `{singular_target_table}_id` | `user_id`, `invoice_id` |
| Standard timestamps | `createdAt`, `updatedAt` via Doctrine `lifecycle callbacks` or `TimestampableInterface` | (Doctrine convention) |
| Soft delete column | `deletedAt` via SoftDeleteable extension (StofDoctrineExtensions) | (extension convention) |
| Test class | PascalCase + `Test` suffix | `InvoiceControllerTest`, `UserServiceTest` |

## Idioms (preferred patterns)

- **PHP 8 attributes for routing** — use `#[Route('/path', name: 'app_route_name', methods: ['GET'])]` on controller action methods; avoid YAML/XML route configs when attributes are available
- **Dependency injection via constructor** — inject services through the constructor; let the DI container autowire via type-hints; avoid `$this->container->get(...)` service locator calls
- **Doctrine ORM for persistence** — define entities in `src/Entity/` with `#[ORM\Entity]` and `#[ORM\Column]` attributes; use repositories for queries; avoid raw SQL for routine CRUD
- **Repository pattern for queries** — keep query logic in `src/Repository/`; custom repositories extend `ServiceEntityRepository`; controllers get a repository injected, not an entity manager directly
- **Twig for server-side templating** — use `templates/` with `.html.twig` files; inherit from a shared base layout; pass variables from the controller via `$this->render(...)`
- **Symfony Flex for package management** — install bundles via `composer require <package>`; Flex recipes auto-configure config files
- **MakerBundle for scaffolding** — use `php bin/console make:controller`, `make:entity`, `make:migration`, `make:voter`, `make:form`, `make:crud` for initial scaffolds; review and customize the generated code
- **Services autowired by type** — services declared in `config/services.yaml` with `autowire: true` (default in Flex projects); prefer constructor injection with PHP type-hints over manual wiring
- **Security via Security component** — use `config/packages/security.yaml` for firewalls and access control; use `#[IsGranted('ROLE_ADMIN')]` or `$this->denyAccessUnlessGranted(...)` for per-action authorization
- **Form component for user input** — define Form types in `src/Form/`; use `$form = $this->createForm(InvoiceType::class, $invoice)` in controllers; use `$form->handleRequest($request)` + `$form->isSubmitted() && $form->isValid()`
- **Symfony Messenger for async** — dispatch messages/commands to queues via `$this->bus->dispatch(new SomeMessage(...))` for non-blocking work; process via workers
- **Environment variables via `.env`** — secrets and env-specific values in `.env` / `.env.local`; access via `$_ENV['KEY']` or `%env(KEY)%` in YAML; never hard-code credentials

## Hard Rules emitted

```
HARD_RULE: Migration files MUST follow Doctrine's `VersionYYYYMMDDHHmmss.php` naming
  path_glob: migrations/Version*.php
  rule_type: NAMING_RULE
  pattern: '^Version\d{14}\.php$'
  rationale: Doctrine orders migrations by the version timestamp embedded in the class name; non-conformant files break migration order

HARD_RULE: Entity classes MUST be in `src/Entity/` and use PascalCase singular naming
  path_glob: src/Entity/*.php
  rule_type: NAMING_RULE
  pattern: '^[A-Z][A-Za-z0-9]*\.php$'
  rationale: Doctrine discovers entities by namespace; non-conformant location or casing requires explicit mapping configuration

HARD_RULE: Controllers MUST end with `Controller` suffix and be in `src/Controller/`
  path_glob: src/Controller/**/*.php
  rule_type: NAMING_RULE
  pattern: 'Controller\.php$'
  rationale: Symfony auto-configures controllers by namespace + suffix; non-conformant naming breaks route discovery and service tagging

HARD_RULE: Repository classes MUST end with `Repository` suffix and extend `ServiceEntityRepository`
  path_glob: src/Repository/*.php
  rule_type: NAMING_RULE
  pattern: 'Repository\.php$'
  rationale: Doctrine links entity to repository via repositoryClass attribute; wrong naming or base class breaks entity manager repository resolution

HARD_RULE: Voter classes MUST end with `Voter` suffix, be in `src/Security/Voter/`, and implement `VoterInterface`
  path_glob: src/Security/Voter/*.php
  rule_type: NAMING_RULE
  pattern: 'Voter\.php$'
  rationale: Symfony Security component auto-tags classes implementing VoterInterface; non-conformant path or missing interface breaks security polling

HARD_RULE: Route names MUST use `app_` prefix + snake_case resource + action (e.g. `app_invoice_index`)
  path_glob: src/Controller/**/*.php
  rule_type: NAMING_RULE
  rationale: Consistent route naming is required for `path()`/`url()` Twig helpers and for reverse routing; controller-level prefix attribute MUST be set when sharing a prefix

HARD_RULE: FK columns MUST follow `{singular_target_table}_id` snake_case pattern
  path_glob: migrations/Version*.php
  rule_type: NAMING_RULE
  pattern: '[a-z][a-z0-9_]*_id$'
  rationale: Doctrine infers join column name from the associated entity; non-conformant names require explicit `#[ORM\JoinColumn(name: ...)]` overrides

HARD_RULE: Templates MUST end with `.html.twig` and live under `templates/`
  path_glob: templates/**/*.html.twig
  rule_type: LOCATION_RULE
  rationale: Twig loader is configured for the `templates/` directory; templates outside it require explicit path configuration

HARD_RULE: Business logic MUST NOT live in controllers; delegate to services in `src/Service/`
  path_glob: src/Controller/**/*.php
  rule_type: CUSTOM
  rationale: Controllers are thin HTTP adapters; testability and reuse require domain logic in injected services
```

## Forbidden patterns

- Service locator calls (`$this->container->get('service.id')`) — use constructor injection
- Direct `$_POST` / `$_GET` / `$_REQUEST` access — use `Request $request` object or Form component
- Database queries in Twig templates — fetch and pass data from the controller
- Raw SQL in entity classes — use repositories and Doctrine Query Builder
- Business logic directly in controllers (parsing excepted) — delegate to `src/Service/`
- `die()` / `var_dump()` in committed code — use Symfony's `dd()` helper for debugging only, remove before commit
- Hard-coded credentials or env values — use `.env` files and `%env(KEY)%` parameters
- Using `@Route(...)` annotation syntax (Doctrine-style docblock) — prefer PHP 8 `#[Route(...)]` attribute syntax in Symfony 6.4+

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — Validator component with `#[Assert\...]` constraints on DTOs, enforced via `#[MapRequestPayload]` or an explicit `$validator->validate()`; reading `$request->request->all()` into entities without constraints is the defect.
- **SQL injection** — Doctrine DQL/QueryBuilder bind values via `setParameter()`; native SQL (`$conn->executeQuery()`) or DQL assembled by string concatenation with user values is the bypass — bind, never interpolate.
- **XSS / output escaping** — Twig autoescapes; `|raw` (and `{% autoescape false %}`) is the bypass — only for server-sanitized markup, never request data.
- **CSRF** — the Form component injects and checks `_token` automatically; hand-built forms use `csrf_token('intent')` + `isCsrfTokenValid()`; a state-changing route with neither is the gap (login/logout are covered by the security config's csrf settings).
- **AuthN/AuthZ enforcement point** — `security.yaml` firewalls + `access_control` for coarse URL rules, `#[IsGranted]`/`denyAccessUnlessGranted()` backed by voters for object-level decisions; inline role-string comparisons in controllers are the bypass smell.
- **Password hashing** — `UserPasswordHasherInterface` with `password_hashers: ... 'auto'` (bcrypt/sodium chosen per platform); hashing inside the entity or with `md5`/`sha1` is the defect.
- **Mass assignment** — hydrate through the Form component or `#[MapRequestPayload]` DTOs with explicit properties; deserializing the raw request body straight onto a Doctrine entity lets the client set any mapped column, including ownership and role fields.
- **Secrets / config** — the secrets vault (`bin/console secrets:set`) plus `%env()%` processors; real values committed to `.env` (instead of `.env.local` or the vault) are the leak.
- **File uploads** — `UploadedFile` constrained by `#[Assert\File]`/`#[Assert\Image]` (mimeTypes, maxSize), stored under a generated name via `move()`; `getClientOriginalName()` is attacker-controlled and never becomes a path.
- **Session/cookie posture** — `framework.session` with `cookie_secure: auto`, `cookie_httponly: true`, `cookie_samesite: lax`; the security component migrates the session on login (fixation protection) — do not disable it.

## ERD additions (Symfony/Doctrine-specific extensions to `_universal.md`)

- **Doctrine association columns**: `#[ORM\ManyToOne(targetEntity: User::class)]` + `#[ORM\JoinColumn(name: 'user_id', referencedColumnName: 'id')]` — FK column is `user_id` in the DB
- **Timestamp columns**: prefer Doctrine `lifecycle callbacks` (`#[ORM\HasLifecycleCallbacks]`) or `TimestampableInterface` from StofDoctrineExtensions for `created_at` / `updated_at`
- **Soft-delete column**: `deleted_at TIMESTAMP NULL` via `SoftDeleteable` filter (StofDoctrineExtensions) — adds `WHERE deleted_at IS NULL` automatically
- **Enum columns**: native PHP 8.1 enums as `#[ORM\Column(type: 'string', enumType: StatusEnum::class)]` in Doctrine 2.13+ / 3.x
- **Inheritance**: Doctrine `InheritanceType::SINGLE_TABLE` or `JOINED` declared on the parent entity class

## Testing conventions

- Test runner: `php bin/phpunit` (PHPUnit via `symfony/test-pack`)
- PHPUnit config: `phpunit.xml.dist` at project root
- Test base classes:
  - `Symfony\Bundle\FrameworkBundle\Test\WebTestCase` — HTTP client tests (controller smoke tests, form submissions, response assertions)
  - `Symfony\Bundle\FrameworkBundle\Test\KernelTestCase` — service/unit tests that need the container but not HTTP
  - `PHPUnit\Framework\TestCase` — pure unit tests with no container
- HTTP test helpers: `$client = static::createClient(); $client->request('GET', '/path');` — then `$this->assertResponseIsSuccessful()`, `$this->assertResponseStatusCodeSame(200)`
- Database: use `doctrine/doctrine-fixtures-bundle` (`src/DataFixtures/`) for test fixtures; wrap tests in transactions via `dama/doctrine-test-bundle` for rollback isolation
- Assertions: `$this->assertSelectorTextContains('h1', 'Expected')`, `$this->assertResponseRedirects('/path')`
- Authentication in tests: `$client->loginUser($user)` (Symfony 5.1+) to bypass login form
- Factory pattern: `zenstruck/foundry` (community preferred) for object factories; or manual `new Entity()` construction in fixtures

## Migration / dependency management

- Lock file: `composer.lock` (committed)
- Install: `composer install --no-dev` (production), `composer install` (dev)
- Update: `composer update` (resolves new versions per composer.json constraints)
- Asset build (Webpack Encore): `npm run build` (production) / `npm run dev` (watch)
- Asset build (AssetMapper — Symfony 6.3+): `php bin/console asset-map:compile` for production; no build step in dev
- Cache clear: `php bin/console cache:clear` (clears compiled container, routes, templates)
- Cache warmup: `php bin/console cache:warmup` (production deploy)
- Migration: `php bin/console doctrine:migrations:migrate` (apply pending) / `php bin/console doctrine:migrations:diff` (generate diff migration)
- Schema: `php bin/console doctrine:schema:validate` (verify entity↔DB consistency)
- Secrets: `php bin/console secrets:set MY_SECRET` (Symfony Secrets Vault for production credentials)

## Flow-artifact derivation

> Concrete Symfony fill of the universal §Flow-artifact derivation principle.
> Consumed by `validate-flow-coverage.sh` (code-delivery slice A).
> In Symfony, an input-accepting state-transition step is handled via a Form Type
> (`src/Form/`) for HTML forms, or via a DTO with manual validation for API endpoints.
> One Form Type per transition action (per the "Form component for user input" idiom).

```yaml
endpoint_kinds:
  - flow_signal: '(?i)\b(submit(?:s|ted|ting)?|resubmit(?:s|ted|ting)?|review(?:s|ed|ing)?|approv(?:e|es|ed|al|ing)|reject(?:s|ed|ing|ion)?|confirm(?:s|ed|ing|ation)?|dispatch(?:es|ed|ing)?|appl(?:y|ies|ied|ying)|finaliz(?:e|es|ed|ing)|enrich(?:es|ed|ing)?)\b'
    required_artifact: form-type
    path_glob: src/Form/**/*.php
    naming: '{Action}{Module}Type'
```

## Conditional scaffold artifacts

> Concrete Symfony fill of the universal §Conditional scaffold artifacts principle.
> Consumed by `validate-flow-coverage.sh` (code-delivery slice A — anti dead-stub).

```yaml
- artifact_glob: 'templates/**/edit.html.twig'
  requires_flow_endpoint: '(?i)\b(update|edit|put|patch)\b'
```

## Entity source globs

> Concrete Symfony fill of the universal §Entity source globs principle.
> Consumed by `validate-flow-coverage.sh` (code-delivery slice A — module matching).

```yaml
entity_sources:
  - pattern: '/(?P<entity>[A-Za-z]+)Controller\.php'
  - pattern: 'templates/(?P<entity>[a-zA-Z0-9_-]+)/'
    exclude: ['_partials', 'components', 'base', 'layout', 'vendor']
  - pattern: 'src/Entity/(?P<entity>[A-Za-z]+)\.php'
```

## Entity matching tokens

> Concrete Symfony fill of the universal §Entity matching tokens principle.

```yaml
stop_tokens: []
compound_aliases: {}
```

## Test patterns

> Concrete Symfony fill of the universal §Test patterns principle.
> Consumed by `validate-unit-spec.sh` (code-delivery slice D — render-test-per-module gate).
> In Symfony a detail view is a `show.html.twig`; the render test uses `WebTestCase` to
> request the show route and assert a real display field appears in the response.

```yaml
detail_view_glob: 'templates/**/show.html.twig'
detail_view_render:
  template: |
    $client = static::createClient();
    $fixture = new {Model}Fixture();
    $manager->persist($fixture->create());
    $manager->flush();
    $client->request('GET', '/path/to/{resource}/show');
    $this->assertResponseIsSuccessful();
    $this->assertSelectorTextContains('[data-field="{display_field}"]', '');
  test_glob: tests/**/*Test.php
```

## UI quality signatures

> Concrete Symfony/Twig fill of the universal §UI quality signatures principle.
> Consumed by `validate-ui-quality.sh` (code-delivery slice E).

```yaml
view_glob: 'templates/**/*.html.twig'
min_view_lines: 20
scaffold_tells:
  - id: title-is-class
    regex: '<title>\s*[A-Z][a-zA-Z]+Controller'
    message: "Page title leaks the Controller class name (raw scaffold). Set a human page title."
  - id: label-is-column-id
    regex: ">[[:space:]]*([A-Za-z]+ )+(Id|ID|Uuid|UUID)[[:space:]]*<"
    message: "Field label is an unstyled column name like 'User Id'. Humanize the label."
  - id: raw-fk-id
    regex: "\{\{[[:space:]]*[a-zA-Z_.]+\.[a-z_]+Id[[:space:]]*\}\}"
    message: "Foreign key rendered as a raw id. Resolve to a human label via the Doctrine relation."
  - id: native-alert
    regex: "\b(alert|confirm|prompt)\s*\("
    message: "Native JS dialog instead of the project notification idiom."
```

## Cross-cutting concerns

> Concrete Symfony fill of the universal §Cross-cutting concerns principle.
> Consumed by `validate-sibling-consistency.sh` (slice B) and
> `validate-sibling-consistency.sh --cross-cutting` (slice C).
> In Symfony, multi-tenant scope is typically enforced via a Doctrine extension
> (query filter) or a base repository method; voter-based access control is the
> idiomatic mechanism for per-resource authorization.

```yaml
cross_cutting_concerns:
  - concern: voter-authorization
    applies_when: 'has_column:owner_id'
    spec_obligation: '\bVoter\b|\bIsGranted\b'
    registration_signature: 'denyAccessUnlessGranted\(|IsGranted\('
    registration_target_glob: 'src/Controller/**/*.php'
    registration_source_glob: 'src/Security/Voter/**/*.php'
```

## Relation derivation

> Concrete Symfony/Doctrine fill of the universal §Relation derivation principle.
> Consumed by `validate-sibling-consistency.sh` (slice B — relation coherence).

In Symfony/Doctrine an FK column `{singular}_id` maps to a **camelCase `ManyToOne` property
named `{singular}`** on the entity — e.g. `user_id` => a `$user` property with
`#[ORM\ManyToOne(targetEntity: User::class)]`, accessed via `$entity->getUser()` /
`$entity->setUser(...)`. A model unit that declares an FK column but omits the relation
property has under-specified the association.

```yaml
relation_derivation:
  fk_to_accessor:
    rule: '{singular}_id => ManyToOne property `{singular}` (camelCase), getter `get{Singular}()`'
    accessor_template: 'get{PascalSingular}()'
    accessor_form: call
```

## Notes / Symfony-specific guidance

- **Autowiring vs explicit wiring**: Symfony autowires services by type by default (`config/services.yaml` with `autowire: true`); explicit wiring in `services.yaml` is needed only when a type maps to multiple implementations (use named arguments or interface bindings).
- **Environment separation**: use `APP_ENV=prod` for production; `APP_ENV=dev` activates the profiler and debug toolbar; `APP_ENV=test` for the test suite.
- **Security firewall hierarchy**: firewalls in `security.yaml` are evaluated top-to-bottom; a `dev` firewall for the profiler must come before the `main` firewall.
- **Doctrine lifecycle callbacks**: prefer `#[ORM\PrePersist]` / `#[ORM\PreUpdate]` on entity methods for automatic timestamp management; require `#[ORM\HasLifecycleCallbacks]` on the entity class.
- **Messenger transport**: configure transports in `config/packages/messenger.yaml`; use `MESSENGER_TRANSPORT_DSN` env variable for the queue URL; run consumers via `php bin/console messenger:consume`.
- **AssetMapper vs Webpack Encore**: Symfony 6.3+ ships AssetMapper (no Node.js build) as the modern default for new projects; Webpack Encore remains fully supported for projects requiring a build pipeline. Check `config/packages/asset_mapper.yaml` (AssetMapper) or `webpack.config.js` (Encore).
- **Profiler & debug toolbar**: enabled in dev via `symfony/profiler-pack`; access at `/_profiler`; includes query inspector, route matcher, and security info.
- **Secrets Vault**: production secrets (`APP_SECRET`, database URLs) managed via `php bin/console secrets:set`; stored encrypted in `config/secrets/`; decrypted at runtime using a deploy key.
- **Doctrine migrations discipline**: always run `doctrine:migrations:diff` to generate migrations from entity changes; never modify a committed migration; use `migrate --allow-no-migration` in CI.

## Deep-scan file hints

```yaml
auth_hints:
  - "config/packages/security.yaml"
  - "src/Security/"
  - "config/packages/lexik_jwt_authentication.yaml"
authz_hints:
  - "config/packages/security.yaml"
  - "src/Security/Voter/"
  - "src/Controller/"
ui_hints:
  - "templates/"
  - "assets/"
  - "webpack.config.js"
  - "config/packages/asset_mapper.yaml"
  - "importmap.php"
```

## Authz mapping

- `auth.mechanism`: `session` (stateful web) or `token` (JWT / API token via `lexik/jwt-authentication-bundle`)
- `authz.mechanism`: `voter` (primary — `VoterInterface` classes polled by Security component) plus `attribute` for `#[IsGranted(...)]` shorthand
- `authz.role_source`: `config` (role_hierarchy in `security.yaml`) or `db` (roles stored in user entity / separate roles table)
- Construct → `declarations[].kind`:
  - `#[IsGranted('ROLE_ADMIN')]` on a controller action → `{kind: role}`
  - A class extending `Symfony\Component\Security\Core\Authorization\Voter\Voter` in `src/Security/Voter/` → `{kind: voter}`
  - `$this->denyAccessUnlessGranted('ROLE_EDITOR')` in a controller → `{kind: role}`
  - `access_control:` rules in `security.yaml` → `{kind: role, applies_to: route_pattern}`
  - `role_hierarchy:` in `security.yaml` → `{kind: group, name: hierarchy_entry}`

## UI detection

- template inheritance / dominant layout: `{% extends 'base.html.twig' %}` at the top of page templates; base layout lives at `templates/base.html.twig`; blocks declared with `{% block <name> %}...{% endblock %}`
- component: Twig Components (`symfony/ux-twig-component`) — `<twig:ComponentName />` syntax; or include via `{{ include('components/_name.html.twig') }}`
- asset bundling: Webpack Encore (`encore_entry_link_tags('app')` / `encore_entry_script_tags('app')`) or AssetMapper (`{{ importmap('app') }}`)
- notification call: Symfony UX Turbo flash messages via `{{ app.flashes('success') }}` in Twig; or SweetAlert2 via custom JS
- live components: Symfony UX Live Component (`symfony/ux-live-component`) for reactive UI without a full JS framework

## Reuse discovery

```yaml
reuse_hints:
  helpers:  [ "src/Helper/**", "src/Util/**" ]
  model_api: [ "src/Entity/**", "src/Repository/**" ]
  services: [ "src/Service/**" ]
  commands: [ "src/Command/**" ]
```
- model_api: entity properties/getters/setters, repository query methods, Doctrine relations.
- commands: each command's `protected static $defaultName` or `#[AsCommand(name: '...')]` attribute.
