---
framework: <kebab-case-name>           # e.g., laravel, django, rails, express, nestjs, fastapi
framework_version_range: "X.x — Y.x"
last_verified_against: YYYY-MM-DD
maintainer: <name-or-mega-sdd>
detection_signature:
  package_manifest: <filename>          # composer.json | package.json | Gemfile | pyproject.toml | go.mod | Cargo.toml
  dependency_marker: <string>           # e.g., "laravel/framework", "django", "rails", "express"
  version_regex: <regex>                # optional — extract major version from manifest
extends: <other-pack-or-null>           # optional — pack inheritance (e.g., nestjs extends typescript-universal)
---

# <Framework Display Name> Convention Pack

<1-sentence pack purpose, e.g., "Conventions for Laravel 10.x — 11.x backend projects.">

## File location standards

| Artifact | Path |
|---|---|
| Models | <e.g., `app/Models/`> |
| Controllers | <e.g., `app/Http/Controllers/`> |
| Migrations | <e.g., `database/migrations/`> |
| Routes | <e.g., `routes/web.php` + `routes/api.php`> |
| Tests | <e.g., `tests/Feature/` + `tests/Unit/`> |
| Config | <e.g., `config/`> |
| Static views | <e.g., `resources/views/`> |
| Static assets | <e.g., `resources/js/`, `resources/css/`> |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Column case | snake_case | `created_at`, `user_id` |
| Table case | <plural snake_case OR singular?> | `users`, `loan_applications` |
| Class case | PascalCase | `LoanApplication` |
| Method case | <camelCase OR snake_case?> | <example> |
| Filename case | <PascalCase OR snake_case OR kebab-case?> | <example> |
| Migration filename | <pattern> | <example> |
| FK column | `{singular_target_table}_id` | `customer_id` on `loans` table |
| Pivot/junction table | <pattern> | <example> |
| Standard timestamps | <enabled by default?> | `created_at` + `updated_at` |
| Soft delete column | <if applicable> | `deleted_at` |

## Idioms (preferred patterns)

- <Idiom 1 — e.g., "Use Eloquent over raw query for CRUD operations">
- <Idiom 2 — e.g., "Use Form Requests for input validation, not inline `request()->validate()`">
- <Idiom 3 — e.g., "Use Policies for authorization, not inline checks in controllers">
- <Idiom 4 — e.g., "Use API Resources for JSON response shaping">

## Hard Rules emitted

These rules merge into `binding.md` §Suggested Unit Hard Rules when this pack is loaded.

```
HARD_RULE: <human-readable rule statement>
  path_glob: <e.g., app/Models/*.php>
  rule_type: NAMING_RULE | LOCATION_RULE | SIGNATURE_RULE | DEP_RULE | CUSTOM
  ast_grep_pattern: <YAML rule reference, or empty if NAMING_RULE>
  rationale: <1-sentence why>
```

Example (Laravel):

```
HARD_RULE: Migration files MUST follow `YYYY_MM_DD_HHMMSS_<descriptive>.php` pattern
  path_glob: database/migrations/*.php
  rule_type: NAMING_RULE
  rationale: Laravel orders migrations by filename timestamp; non-conformant files break schema rollout
```

## Forbidden patterns

What violates this framework's idioms (anti-patterns that bolts must NOT generate):

- <Anti-pattern 1 — e.g., "Raw `DB::table()` queries in Controllers (use Models)">
- <Anti-pattern 2 — e.g., "Business logic in `routes/*.php` (use Controllers or Actions)">
- <Anti-pattern 3 — e.g., "Direct `$_POST` / `$_GET` access (use Request object)">

## ERD additions (when this pack applies)

Extends `references/framework-conventions/_universal.md` §ERD Quality Rails:

- <Framework-specific ERD rule 1 — e.g., "Pivot tables: alphabetical singular_a_singular_b (Eloquent convention)">
- <Framework-specific ERD rule 2 — e.g., "Polymorphic relations: morphable_id + morphable_type columns">

## Testing conventions

- Framework test runner: <e.g., `php artisan test` for Laravel; `pytest` for Django/FastAPI>
- Test file location: <e.g., `tests/Feature/` + `tests/Unit/`>
- Test naming: <e.g., `<Feature>Test.php` with `test_<scenario>` methods>
- Fixtures: <e.g., factories under `database/factories/`>

## Migration / dependency management

- Lock file: <e.g., `composer.lock`, `package-lock.json`, `Gemfile.lock`>
- Update command: <e.g., `composer update`, `npm update`>
- Install command: <e.g., `composer install`, `npm install`>
- Build/compile command: <e.g., `npm run build` for assets, `php artisan optimize`>

## Notes / pack-specific guidance

<Free-form section for framework-specific quirks, common pitfalls, anti-patterns to call out, etc.>
