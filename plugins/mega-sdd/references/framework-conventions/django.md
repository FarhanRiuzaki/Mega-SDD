---
framework: django
framework_version_range: "4.2 — 5.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
extends: _universal
pack_tier: full
detection_signature:
  package_manifest: pyproject.toml
  dependency_marker: django
---

# Django Convention Pack (4.2 — 5.x)

## File location standards
- models: `**/models.py`
- views: `**/views.py`
- urls: `**/urls.py`
- templates: `**/templates/**`
- migrations: `**/migrations/`

## Deep-scan file hints

```yaml
auth_hints:  [ "**/settings.py", "**/urls.py", "**/views.py" ]
authz_hints: [ "**/settings.py", "**/permissions.py", "**/decorators.py", "**/views.py" ]
ui_hints:    [ "**/templates/**", "**/static/**" ]
```

## Authz mapping

- `auth.mechanism`: `session` (Django auth) — `token`/`jwt` if DRF/SimpleJWT present
- `authz.mechanism`: `decorator` (+ `mixin`, `builtin`)
- `authz.role_source`: `db` (`auth.Group`)
- Construct -> `declarations[].kind`:
  - `@permission_required('app.codename')` / `permission_classes` -> `{kind: permission, name}`
  - `PermissionRequiredMixin.permission_required` -> `{kind: permission}`
  - `Group` objects / `@user_passes_test` role checks -> `{kind: group}`
- `django.contrib.auth` is the baseline authz library for all standard Django projects

## UI detection
- dominant layout: most-`{% extends "<base>" %}` template across `templates/`
- component: `{% include %}` partials / `templatetags`
- notification call: `django.contrib.messages` framework usage

## Reuse discovery

```yaml
reuse_hints:
  helpers:  [ "**/utils.py", "**/helpers.py" ]
  model_api: [ "**/models.py" ]
  services: [ "**/services.py", "**/selectors.py" ]
  commands: [ "**/management/commands/**" ]
```

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| App name | lowercase singular or plural noun (snake_case) | `accounts`, `blog`, `loan_applications` |
| Module files | snake_case `.py` | `views.py`, `url_helpers.py` |
| Model class | PascalCase singular | `User`, `LoanApplication` |
| Model field | snake_case | `created_at`, `email_address`, `is_active` |
| FK field | `{singular_target}_id` | `user_id`, `category_id` |
| Many-to-many through table | PascalCase compound | `UserGroup`, `PostTag` |
| View function | snake_case verb-noun | `loan_list`, `create_application` |
| Class-based view | PascalCase + `View` suffix | `LoanListView`, `ApplicationCreateView` |
| URL name | snake_case or kebab-case, namespace-prefixed | `accounts:login`, `loans:detail` |
| Template filename | snake_case, inside `<app>/templates/<app>/` | `loans/detail.html`, `accounts/login.html` |
| Template tag module | snake_case under `templatetags/` | `loan_tags.py`, `format_helpers.py` |
| Form class | PascalCase + `Form` suffix | `LoanApplicationForm`, `UserRegistrationForm` |
| ModelForm class | PascalCase + `Form` suffix (same) | `LoanApplicationForm` |
| Serializer class (DRF) | PascalCase + `Serializer` suffix | `LoanApplicationSerializer` |
| ViewSet class (DRF) | PascalCase + `ViewSet` suffix | `LoanApplicationViewSet` |
| Manager class | PascalCase + `Manager` suffix | `PublishedManager`, `ActiveLoanManager` |
| Migration file | auto-generated `NNNN_<description>.py` — never renamed by hand | `0001_initial.py`, `0002_add_status_field.py` |
| Management command | snake_case under `management/commands/` | `import_loans.py`, `send_reminders.py` |
| Test class | PascalCase + `Test` or `TestCase` suffix | `LoanApplicationTest`, `AccountsViewTestCase` |
| Test method | snake_case prefixed `test_` | `test_user_can_submit_loan`, `test_invalid_form_returns_400` |

## Idioms (preferred patterns)

- **MTV pattern** — Django follows Model-Template-View (not MVC): models define data + business logic, templates render HTML, views orchestrate request → response. Business logic belongs in models, managers, or service modules — not in views.
- **Class-based views (CBVs) for standard CRUD** — `ListView`, `DetailView`, `CreateView`, `UpdateView`, `DeleteView` cover most CRUD; use `LoginRequiredMixin` + `PermissionRequiredMixin` for auth. Use function-based views (FBVs) for simple endpoints or complex, non-standard logic where CBV mixins become harder to follow.
- **ORM for all database access** — use `QuerySet` methods (`filter`, `select_related`, `prefetch_related`, `annotate`, `aggregate`) rather than raw SQL. Custom logic belongs in model methods or custom `Manager` subclasses; use `get_queryset()` overrides in managers for reusable filtered querysets.
- **`select_related` and `prefetch_related` to avoid N+1** — `select_related` for FK/one-to-one traversals (SQL JOIN); `prefetch_related` for reverse FK and many-to-many (separate queries + Python-side join). Never access related objects in a loop without eager loading.
- **Forms and ModelForms for input validation** — `Form` subclasses for non-model data; `ModelForm` subclasses for model-backed inputs. `form.is_valid()` before any save; `form.save()` inside a transaction for multi-model writes.
- **Migrations workflow** — schema changes are always captured in migration files via `manage.py makemigrations`; never alter the database schema manually outside of migrations. Commit migration files.
- **Django REST Framework (DRF) for APIs** — `ModelSerializer` for model-backed endpoints, `ViewSet` + router for RESTful resource APIs, `Serializer.validate_*` and `validate()` for field-level + object-level validation. Use `APIView` or `GenericAPIView` for non-resource endpoints.
- **Signals sparingly** — `post_save`, `pre_delete`, etc. for genuinely cross-cutting side effects (audit logs, cache invalidation). Prefer explicit calls in service functions or overriding `save()`/`delete()` when the coupling is intentional and local.
- **`get_object_or_404` and shortcut helpers** — use `get_object_or_404(Model, pk=pk)` in views rather than bare `Model.objects.get(pk=pk)` (avoids uncaught `DoesNotExist`).
- **Settings split** — `settings/base.py` + `settings/local.py` + `settings/production.py` for environment-specific configuration; `DJANGO_SETTINGS_MODULE` selects the active file. `SECRET_KEY`, passwords, and API keys always come from environment variables.
- **Static files** — `STATIC_ROOT` / `MEDIA_ROOT` separate from source tree; `collectstatic` before production deploy; `WhiteNoise` or a reverse proxy (nginx) serves static files in production, never `runserver`.
- **Database transactions for multi-step writes** — `transaction.atomic()` (decorator or context manager) wraps writes that must succeed or fail together.

## Hard Rules emitted

```
HARD_RULE: Business logic MUST live in models, managers, or service modules — not in views
  path_glob: **/views.py
  rule_type: CUSTOM
  rationale: Views are thin request-handlers in MTV; fat views become untestable and non-reusable

HARD_RULE: All schema changes MUST be captured in migration files (manage.py makemigrations) and committed
  path_glob: **/migrations/*.py
  rule_type: CUSTOM
  rationale: Django applies migrations in order; manual schema changes not captured in migrations cause drift

HARD_RULE: Input MUST be validated via Form or ModelForm (or DRF Serializer) before use
  path_glob: **/views.py, **/serializers.py
  rule_type: CUSTOM
  rationale: Bypassing form/serializer validation exposes raw user input without field-level or object-level checks

HARD_RULE: Raw SQL MUST use parameterized queries (cursor.execute(sql, params) or ORM .raw(sql, params))
  path_glob: **/*.py
  rule_type: SECURITY
  pattern: 'cursor\.execute\(\s*[^,)]'
  rationale: String-interpolated SQL is vulnerable to injection; parameterized queries prevent it

HARD_RULE: SECRET_KEY and passwords MUST be loaded from environment variables, never hardcoded in settings
  path_glob: **/settings*.py
  rule_type: SECURITY
  rationale: Hardcoded secrets are leaked in version control

HARD_RULE: Model classes MUST be PascalCase singular; migration files MUST NOT be renamed after creation
  path_glob: **/models.py, **/migrations/*.py
  rule_type: NAMING_RULE
  rationale: Django introspects model class names for content types and migration graph; renaming migrations breaks the dependency chain

HARD_RULE: N+1 queries MUST be prevented with select_related / prefetch_related at the queryset level
  path_glob: **/views.py, **/serializers.py
  rule_type: PERFORMANCE
  rationale: Accessing related objects inside a loop without eager loading produces one query per row

HARD_RULE: INSTALLED_APPS MUST list every app whose models, signals, or management commands are used
  path_glob: **/settings*.py
  rule_type: CUSTOM
  rationale: Apps omitted from INSTALLED_APPS have their models invisible to the ORM and their migrations unapplied
```

## Testing conventions

- **Test runner**: `pytest` with `pytest-django` (preferred) or Django's built-in `manage.py test` (uses `unittest`-compatible runner)
- **pytest-django configuration**: `pytest.ini` or `pyproject.toml` section `[tool.pytest.ini_options]` with `DJANGO_SETTINGS_MODULE` set; `django_db` marker (or `@pytest.mark.django_db`) required for database access
- **Base test class (manage.py test)**: `django.test.TestCase` for DB-touching tests (wraps each test in a transaction, rolls back); `django.test.SimpleTestCase` for no-DB logic
- **Test file locations**: `tests.py` at app root (simple projects) or `tests/` package inside each app (`tests/__init__.py` + `tests/test_views.py`, `tests/test_models.py`, etc.)
- **Fixtures / factories**: `factory_boy` (`factory.django.DjangoModelFactory`) preferred over Django fixtures (`.json`/`.yaml` files) for programmatic, maintainable test data; use `@pytest.fixture` with `factory_boy` for composable setup
- **HTTP test client**: `django.test.Client` (sync) or `django.test.AsyncClient` (async views); with pytest-django use the `client` fixture. Authenticate via `client.force_login(user)` or `client.login(username=..., password=...)`
- **DRF API tests**: `rest_framework.test.APIClient` for DRF endpoints; `api_client.force_authenticate(user=user)` for auth
- **Database isolation**: each `TestCase` runs in a transaction rolled back after the test; `TransactionTestCase` for tests that require committed data (e.g., testing signals triggered post-commit)
- **Assertions**: `assertContains`, `assertRedirects`, `assertFormError` from `TestCase`; `response.status_code`, `response.json()` for API responses
- **Test naming**: test modules prefixed `test_` (e.g. `test_views.py`); test functions/methods prefixed `test_`
- **Coverage**: `pytest-cov` (`--cov=<app>`) or `coverage run manage.py test` + `coverage report`
