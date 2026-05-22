---
framework: laravel
framework_version_range: "10.x — 12.x"
last_verified_against: 2026-05-22
maintainer: mega-sdd
detection_signature:
  package_manifest: composer.json
  dependency_marker: "laravel/framework"
  version_regex: '"laravel/framework"\s*:\s*"[\^~]?(\d+)\.'
extends: _universal
---

# Laravel Convention Pack (10.x — 12.x)

Conventions for Laravel backend projects. Extends `_universal.md` — universal defaults apply, Laravel-specific rules override on conflict.

> **Project-specific overrides**: when a project ships its own starterkit conventions (custom traits, base classes, helper layout, etc.), see `laravel-<starterkit>.md` pack — extends this base pack with starterkit-specific overrides. Example: `laravel-base-26.md` (RECON starter — Jetstream + Spatie permission + Vuexy + custom helpers/traits stack).

## Laravel version notes

- **10.x**: standard `app/` layout with `app/Console/Kernel.php`, `app/Exceptions/Handler.php`, `app/Http/Kernel.php`, etc.
- **11.x**: slimmer skeleton — Kernels removed, middleware/exceptions in `bootstrap/app.php`, `health` route default, `casts()` method on Models replaces `$casts` property (optional in 11.x, encouraged in 12.x)
- **12.x**: continues 11.x slim skeleton, `casts()` method becomes the convention, factory configuration moved to model `newFactory()`, broader use of typed enums in casts

Detection: `version_regex` extracts major version; framework pack body remains shared across 10.x — 12.x. Version-specific notes flagged inline below with `[v11+]` / `[v12+]` markers.

## File location standards

| Artifact | Path |
|---|---|
| Models | `app/Models/` |
| Controllers (web) | `app/Http/Controllers/` |
| Controllers (API) | `app/Http/Controllers/Api/` |
| Form Requests | `app/Http/Requests/` |
| Resources (API) | `app/Http/Resources/` |
| Middleware | `app/Http/Middleware/` |
| Policies | `app/Policies/` |
| Services | `app/Services/` (community convention, not Laravel core) |
| Actions (Spatie-style) | `app/Actions/` (optional) |
| Jobs | `app/Jobs/` |
| Events | `app/Events/` |
| Listeners | `app/Listeners/` |
| Mail | `app/Mail/` |
| Notifications | `app/Notifications/` |
| Migrations | `database/migrations/` |
| Seeders | `database/seeders/` |
| Factories | `database/factories/` |
| Routes (web) | `routes/web.php` |
| Routes (API) | `routes/api.php` |
| Routes (console) | `routes/console.php` |
| Routes (channels) | `routes/channels.php` |
| Config | `config/` |
| Views (Blade) | `resources/views/` |
| Views (Inertia/Vue) | `resources/js/Pages/` |
| Static JS | `resources/js/` |
| Static CSS | `resources/css/` |
| Tests (Feature) | `tests/Feature/` |
| Tests (Unit) | `tests/Unit/` |
| Lang | `lang/<locale>/` |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Column case | snake_case | `created_at`, `email_verified_at` |
| Table case | plural snake_case | `users`, `loan_applications` |
| Model class | PascalCase singular | `User`, `LoanApplication` |
| Model filename | PascalCase singular `.php` | `User.php`, `LoanApplication.php` |
| Controller class | PascalCase singular + `Controller` suffix | `UserController`, `AuthController` |
| Resource controller | PascalCase plural + `Controller` (or singular per Laravel docs both OK) | `UsersController` or `UserController` |
| Request class | PascalCase + `Request` suffix | `StoreUserRequest`, `UpdateLoanRequest` |
| Resource class | PascalCase singular + `Resource` suffix | `UserResource`, `LoanResource` |
| Policy class | PascalCase singular + `Policy` suffix | `UserPolicy` |
| Middleware class | PascalCase | `EnsureUserIsActive` |
| Service class | PascalCase + `Service` suffix | `LoanApprovalService` |
| Job class | PascalCase verb-noun | `ProcessLoanApplication`, `SendWelcomeEmail` |
| Migration filename | `YYYY_MM_DD_HHMMSS_<snake_case_action>.php` | `2026_05_22_103045_create_users_table.php` |
| Migration action verbs | `create_<table>_table`, `add_<column>_to_<table>_table`, `remove_<column>_from_<table>_table`, `rename_<from>_to_<to>` | (per Laravel convention) |
| Seeder class | PascalCase + `Seeder` suffix | `UsersSeeder`, `LoanApplicationsSeeder` |
| Factory class | PascalCase + `Factory` suffix | `UserFactory` |
| FK column | `{singular_target_table}_id` | `user_id`, `loan_application_id` |
| Pivot/junction table | alphabetical `{singular_a}_{singular_b}` | `role_user` (not `user_role`) |
| Standard timestamps | `created_at`, `updated_at` enabled by default via `$timestamps = true` on Model | (Eloquent default) |
| Soft delete column | `deleted_at` via `use SoftDeletes` trait | (Eloquent convention) |
| Route name | kebab-case dot-separated | `users.index`, `loans.applications.store` |
| Route URI | kebab-case | `/loan-applications`, `/admin/user-roles` |
| Blade view filename | snake_case or kebab-case | `users/index.blade.php`, `loans/show.blade.php` |
| Blade component | PascalCase | `<x-user-card />` (resolved from `app/View/Components/UserCard.php`) |
| Event class | PascalCase past-tense | `LoanSubmitted`, `UserRegistered` |
| Listener class | PascalCase verb | `SendLoanConfirmationEmail` |
| Channel class | PascalCase | `LoanChannel` |
| Test class | PascalCase + `Test` suffix | `LoanApplicationTest` |
| Test method | snake_case starting with `test_` OR `@test` annotation with descriptive method name | `test_user_can_submit_loan_application` |

## Idioms (preferred patterns)

- **Eloquent over raw queries** — use Models + relationships for CRUD; raw `DB::table()` or `DB::statement()` only for performance-critical aggregations or operations not expressible in Eloquent
- **Form Requests for validation** — extract validation into dedicated `app/Http/Requests/` classes; avoid inline `$request->validate([...])` in controllers
- **API Resources for response shaping** — use `app/Http/Resources/` for consistent JSON envelopes; avoid raw `response()->json($model)` for API endpoints
- **Policies for authorization** — define in `app/Policies/`; reference via `$this->authorize()` or `@can` blade directive; avoid inline role checks
- **Service classes for complex business logic** — controllers stay thin (parse request → call service → return response); services in `app/Services/` hold domain logic
- **Queued jobs for non-immediate work** — emails, notifications, reports, file processing → `dispatch(new Job)` rather than synchronous in request lifecycle
- **Eloquent events for side effects** — `boot()` method's `created`, `updated`, `deleting` hooks; or Observer classes for organized side-effect handling
- **Database transactions for multi-table writes** — `DB::transaction(function() { ... })` wraps writes that must succeed or fail atomically
- **Eager loading to prevent N+1** — `Model::with(['relation'])` in controllers; explicit relationship loading in templates
- **Sanctum or Passport for API auth** — token-based auth via Laravel's official packages, not custom JWT
- **Spatie packages preferred for common needs** — laravel-permission (RBAC), laravel-medialibrary (file attachments), laravel-activitylog (audit trail), laravel-data (DTOs)

## Hard Rules emitted

```
HARD_RULE: Migration files MUST follow `YYYY_MM_DD_HHMMSS_<snake_case_action>.php` naming
  path_glob: database/migrations/*.php
  rule_type: NAMING_RULE
  pattern: '^\d{4}_\d{2}_\d{2}_\d{6}_[a-z][a-z0-9_]*\.php$'
  rationale: Laravel orders migrations by filename timestamp; non-conformant files break schema rollout order

HARD_RULE: Eloquent Model files MUST be in `app/Models/` and use PascalCase singular naming
  path_glob: app/Models/*.php
  rule_type: NAMING_RULE
  case_style: PascalCase
  pattern: '^[A-Z][A-Za-z0-9]*\.php$'
  rationale: Laravel auto-discovers models in `app/Models/`; non-conformant location requires manual binding

HARD_RULE: Controllers MUST end with `Controller` suffix and be in `app/Http/Controllers/`
  path_glob: app/Http/Controllers/**/*.php
  rule_type: NAMING_RULE
  pattern: 'Controller\.php$'
  rationale: Laravel resource routing expects `Controller` suffix; routes break without it

HARD_RULE: Form Request classes MUST end with `Request` suffix and be in `app/Http/Requests/`
  path_glob: app/Http/Requests/*.php
  rule_type: NAMING_RULE
  pattern: 'Request\.php$'
  rationale: Type-hint discovery in controller signatures requires consistent naming

HARD_RULE: Column names in `Schema::create()` / `Schema::table()` migration blocks MUST use snake_case
  path_glob: database/migrations/*.php
  rule_type: NAMING_RULE
  case_style: snake_case
  rationale: Eloquent maps snake_case columns to camelCase attributes via accessor; non-conformant columns require explicit `$casts` or accessor

HARD_RULE: Foreign key columns MUST follow `{singular_target_table}_id` pattern
  path_glob: database/migrations/*.php
  rule_type: NAMING_RULE
  pattern: '[a-z][a-z0-9_]*_id$'
  rationale: Eloquent relationship convention — `belongsTo()` infers FK name from related model

HARD_RULE: Pivot tables MUST follow alphabetical `{singular_a}_{singular_b}` naming
  path_glob: database/migrations/*.php
  rule_type: NAMING_RULE
  rationale: Eloquent `belongsToMany()` infers pivot table name alphabetically; non-conformant tables require explicit pivot table arg

HARD_RULE: Soft-deletable models MUST use `use SoftDeletes` trait AND migration MUST include `$table->softDeletes()`
  path_glob: app/Models/*.php + database/migrations/*.php
  rule_type: DEP_RULE
  rationale: SoftDeletes trait expects `deleted_at` column; without it, model behavior breaks

HARD_RULE: Routes file MUST NOT contain business logic
  path_glob: routes/*.php
  rule_type: CUSTOM
  forbidden_calls: ['DB::', 'Model::', 'logic', 'complex closures']
  rationale: Business logic in routes is untestable + un-cacheable
```

## Forbidden patterns

- `DB::table('...')` queries in Controllers (use Eloquent Models)
- `$_POST` / `$_GET` direct access (use `request()` helper or Form Request)
- Business logic in `routes/*.php` (use Controllers or Actions)
- Inline `$request->validate([...])` in Controllers for complex validation (use Form Requests)
- Inline `response()->json(...)` for API endpoints (use API Resources)
- Inline role/permission checks (e.g., `if ($user->role === 'admin')`) — use Policies or `can()` helper
- `dd()` / `dump()` in committed code (use logging instead)
- Eloquent N+1 patterns: looping over collection + accessing relationship without `with()` eager load
- `env()` calls outside `config/*.php` files (cached config breaks env access at runtime)
- Storing files via `move_uploaded_file()` (use `Storage::disk()->putFile()` for testability + cloud-storage abstraction)

## ERD additions (Laravel-specific extensions to `_universal.md`)

- **Polymorphic relations**: `morphable_id BIGINT` + `morphable_type VARCHAR` columns (e.g., `commentable_id` + `commentable_type` on `comments`)
- **Pivot table columns**: alphabetical FK columns + optional `created_at`/`updated_at` if `->withTimestamps()` used
- **Auth `users` table**: standard columns are `id`, `name`, `email`, `email_verified_at`, `password`, `remember_token`, `created_at`, `updated_at` — extend with additional fields, don't rename core ones
- **Personal access tokens** (Sanctum): `personal_access_tokens` table with `tokenable_id` + `tokenable_type` polymorphic FK
- **Failed jobs**: `failed_jobs` table per `php artisan queue:failed-table`
- **Sessions** (database driver): `sessions` table per `php artisan session:table`
- **Cache** (database driver): `cache` + `cache_locks` tables per `php artisan cache:table`

## Testing conventions

- Test runner: `php artisan test` (wrapper over PHPUnit) — preferred since Laravel 8.x
- PHPUnit XML config: `phpunit.xml` at project root
- Test base classes:
  - `Tests\TestCase` (default — extends `Illuminate\Foundation\Testing\TestCase`)
  - `RefreshDatabase` trait for tests that touch DB
  - `WithFaker` trait when factories needed
- HTTP test helpers: `$this->get('/route')`, `->post()`, `->putJson()`, `->actingAs($user)`
- Eloquent assertion: `$this->assertDatabaseHas('users', ['email' => '...'])`
- Job assertion: `Queue::fake()` + `Queue::assertPushed(JobClass::class)`
- Event assertion: `Event::fake()` + `Event::assertDispatched(EventClass::class)`
- Mail assertion: `Mail::fake()` + `Mail::assertSent(MailClass::class)`
- Factories: `User::factory()->create()` — define in `database/factories/UserFactory.php`
- Pest (alternative): if `pestphp/pest` in composer.json, prefer Pest syntax (`it('does X', function() { ... });`)

## Migration / dependency management

- Lock file: `composer.lock` (committed)
- Install: `composer install --no-dev` (production), `composer install` (dev)
- Update: `composer update` (resolves new versions per composer.json constraints)
- Asset build: `npm run build` (Vite) or `npm run dev` (watch mode)
- Cache clear: `php artisan optimize:clear` (clears config, route, view, event caches)
- Cache build: `php artisan optimize` (production deploy)
- Migration: `php artisan migrate` (apply pending) / `php artisan migrate:fresh --seed` (drop + recreate + seed)
- Seeder: `php artisan db:seed --class=UsersSeeder`
- Tinker: `php artisan tinker` (REPL for debugging)

## Notes / Laravel-specific guidance

- **Naming controversy**: Laravel docs flip between singular and plural for Resource Controllers (`UserController` vs `UsersController`). Pick one consistently per project; pack defaults to **singular** because routes auto-pluralize.
- **Mass assignment protection**: every Model needs explicit `$fillable` OR `$guarded` — never leave both unset. Default to `$fillable = []` (whitelist explicit) for safety.
- **Eager loading discipline**: in N+1-sensitive endpoints, declare relations via `with(['rel1', 'rel2.nested'])` at the query level; never inside templates.
- **Casts for non-string columns**: every `json`, `array`, `boolean`, `datetime`, `decimal`, `encrypted`, `enum` column NEEDS `$casts` entry — Laravel doesn't auto-cast.
- **Route caching**: production deploys MUST run `php artisan route:cache`; routes with closures (not controllers) can't be cached → use controllers always for production.
- **Config caching**: production deploys MUST run `php artisan config:cache`; `env()` calls outside config files BREAK after cache (they return null) → only call `config('app.key')`, never `env('APP_KEY')` outside config/.
- **Queue worker**: production needs `php artisan queue:work` as a daemon process (Supervisor or Horizon-managed); without it, jobs queue but never execute.
- **Horizon** (Redis queue UI): if Redis queue, use Horizon for observability + retry management.
- **Octane** (high-performance): if request latency matters, use Octane (Swoole or RoadRunner) — but be careful with shared state (static vars, container singletons can leak).
- **Sanctum vs Passport**: Sanctum for SPA + simple API tokens (most common); Passport for full OAuth2 server use cases.
- **Database transactions**: `DB::transaction(fn() => ...)` rolls back automatically on exception — don't manually commit/rollback unless using nested savepoints.
