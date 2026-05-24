# Laravel — Generic Library Catalog

> Catalog consumed by `libs-extractor` subagent in `scan-codebase` v2.6.0+ deep-scan.

**Output target:** `starterkit-context.yaml §libs[]` array

## Purpose

`libs-extractor` produces a complete inventory of packages from `composer.json` + `package.json`, categorized by purpose + annotated with usage hints. Auth/RBAC/UI libs are also covered by their domain-specific extractors; libs-extractor adds the remaining categories.

## Categories enum

```
auth | rbac | ui | queue | cache | log | test | http | misc
```

- `auth` / `rbac` / `ui`: covered in detail by auth/rbac/ui-ux extractors but also appear in `libs[]` for completeness
- `queue`: job/queue libs (laravel/horizon, beanstalkd, etc.)
- `cache`: cache backends (predis/predis, ext-redis, etc.)
- `log`: log libs (sentry/sentry-laravel, etc.)
- `test`: testing libs (pestphp/pest, phpunit/phpunit, mockery/mockery, laravel/dusk)
- `http`: HTTP clients (guzzlehttp/guzzle, etc.)
- `misc`: everything else not categorized

## Common Laravel libs reference

### Queue / Job

| Manifest fingerprint | Category | usage_hint typical |
|---|---|---|
| `laravel/horizon` | queue | `config/horizon.php`, `app/Providers/HorizonServiceProvider.php` |
| `beanstalkd/pheanstalk` | queue | `config/queue.php` |
| `aws/aws-sdk-php` (with `sqs` driver) | queue | `config/queue.php` |

### Cache

| Manifest fingerprint | Category | usage_hint typical |
|---|---|---|
| `predis/predis` | cache | `config/database.php`, `config/cache.php` |
| `ext-redis` (PHP ext) | cache | `config/cache.php` |
| `aws/aws-sdk-php` (with `dynamodb`) | cache | `config/cache.php` |

### Log / Monitoring

| Manifest fingerprint | Category | usage_hint typical |
|---|---|---|
| `sentry/sentry-laravel` | log | `config/sentry.php`, `bootstrap/app.php` |
| `spatie/laravel-activitylog` | log | `app/Models/*.php` using `LogsActivity` trait |
| `bugsnag/bugsnag-laravel` | log | `config/bugsnag.php` |

### Test

| Manifest fingerprint | Category | usage_hint typical |
|---|---|---|
| `pestphp/pest` | test | `tests/Pest.php`, `tests/Feature/*.php`, `tests/Unit/*.php` |
| `phpunit/phpunit` | test | `phpunit.xml`, `tests/Feature/*.php`, `tests/Unit/*.php` |
| `mockery/mockery` | test | `tests/Feature/*.php` (when mocks used) |
| `laravel/dusk` | test | `tests/Browser/*.php`, `tests/DuskTestCase.php` |
| `nunomaduro/larastan` | test | `phpstan.neon`, `phpstan.neon.dist` |

### HTTP

| Manifest fingerprint | Category | usage_hint typical |
|---|---|---|
| `guzzlehttp/guzzle` | http | `app/Services/*.php` (HTTP client usage) |
| `laravel/http-client` (built-in Http facade) | http | `app/Services/*.php`, `app/Http/Controllers/*.php` |

### Misc (common examples)

| Manifest fingerprint | Category | usage_hint typical |
|---|---|---|
| `barryvdh/laravel-debugbar` | misc | dev-only debugbar |
| `laravel/telescope` | misc | `config/telescope.php`, `app/Providers/TelescopeServiceProvider.php` |
| `intervention/image` | misc | `app/Services/ImageService.php` patterns |
| `maatwebsite/excel` | misc | `app/Exports/*.php`, `app/Imports/*.php` |
| `spatie/laravel-medialibrary` | misc | `app/Models/*.php` using `HasMedia` trait |

## Usage hint inference

For each lib in `libs[]`, populate `usage_hint` by grepping for the lib's namespace (e.g., `Spatie\\Permission`) across `app/`, `routes/`, `config/`, `database/seeders/`. Report top 3-5 files. If lib has no detected usage but appears in manifest → emit `usage_hint: []` (suggests unused dependency).

## Sample full §libs output (subset)

```yaml
libs:
  - name: "laravel/sanctum"
    version: "4.0"
    category: auth
    usage_hint: ["app/Http/Kernel.php", "routes/api.php", "config/sanctum.php"]
  - name: "spatie/laravel-permission"
    version: "6.x"
    category: rbac
    usage_hint: ["app/Models/User.php", "app/Http/Middleware/RoleMiddleware.php", "database/seeders/RoleSeeder.php"]
  - name: "sweetalert2"
    version: "11.x"
    category: ui
    usage_hint: ["resources/js/app.js", "resources/views/components/notification.blade.php"]
  - name: "yajra/laravel-datatables-oracle"
    version: "11.0"
    category: ui
    usage_hint: ["app/DataTables/BaseDataTable.php", "app/DataTables/UsersDataTable.php"]
  - name: "laravel/horizon"
    version: "5.x"
    category: queue
    usage_hint: ["config/horizon.php", "app/Providers/HorizonServiceProvider.php"]
  - name: "pestphp/pest"
    version: "3.x"
    category: test
    usage_hint: ["tests/Pest.php", "tests/Feature/", "tests/Unit/"]
```

## Anti-halu

- Every lib MUST appear in `composer.json` or `package.json` — do NOT invent libs.
- `usage_hint` MUST cite actual file paths grep'd from the codebase. Empty array is correct if lib is unused.
- Categories MUST be from the enum. Use `misc` for genuinely uncategorizable libs rather than inventing new categories.
