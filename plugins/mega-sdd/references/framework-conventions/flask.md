---
framework: flask
framework_version_range: "3.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: pyproject.toml
  dependency_marker: "flask"
  version_regex: 'flask\s*[>=!^~]+\s*"?([0-9]+\.[0-9]+)'
extends: _universal
pack_tier: full
---

# Flask Convention Pack (3.x)

Conventions for Flask backend projects. Extends `_universal.md` — universal defaults apply, Flask-specific rules override on conflict.

## File location standards

| Artifact | Path |
|---|---|
| Application factory | `app/__init__.py` (defines `create_app()`) |
| Blueprint package | `app/blueprints/<name>/` (with `__init__.py`) |
| Blueprint routes | `app/blueprints/<name>/routes.py` or `app/blueprints/<name>/views.py` |
| SQLAlchemy models (flat) | `app/models.py` |
| SQLAlchemy models (split) | `app/models/<entity>.py` |
| Extension singletons | `app/extensions.py` (db, login_manager, mail, etc.) |
| Marshmallow / Pydantic schemas | `app/schemas/` |
| Services / business logic | `app/services/` |
| Forms (Flask-WTF) | `app/forms/` or `app/blueprints/<name>/forms.py` |
| Jinja2 templates | `templates/` or `app/templates/` |
| Static assets | `static/` or `app/static/` |
| Config | `app/config.py` or `config.py` |
| Auth helpers | `app/auth/` or `app/blueprints/auth/` |
| CLI commands | `app/commands.py` or `app/cli.py` |
| Tests | `tests/` (with `tests/conftest.py`) |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Application factory | snake_case `create_app` | `def create_app(config=None):` |
| Blueprint instance | lowercase noun | `bp = Blueprint('auth', __name__)` |
| Blueprint name | lowercase snake_case | `'auth'`, `'admin'`, `'api'` |
| Route function | snake_case verb + noun | `def index():`, `def create_user():` |
| SQLAlchemy model class | PascalCase singular | `User`, `Order`, `Product` |
| SQLAlchemy model filename | snake_case | `user.py`, `order.py` |
| Schema class (Marshmallow) | PascalCase + `Schema` suffix | `UserSchema`, `OrderSchema` |
| Service class | PascalCase + `Service` suffix | `UserService`, `OrderService` |
| Form class (Flask-WTF) | PascalCase + `Form` suffix | `LoginForm`, `RegisterForm` |
| Column name | snake_case | `created_at`, `user_id` |
| Table name | plural snake_case | `users`, `orders`, `products` |
| FK column | `{singular_target_table}_id` | `user_id`, `order_id` |
| Standard timestamps | `created_at`, `updated_at` (declared on model) | `created_at = db.Column(db.DateTime)` |
| Soft delete column | `deleted_at` (application-managed) | `deleted_at = db.Column(db.DateTime, nullable=True)` |
| Test file | `test_<module>.py` | `test_auth.py`, `test_user_service.py` |
| Test function | `test_<scenario>` | `test_login_success`, `test_register_duplicate_email` |
| Config class | PascalCase + `Config` suffix | `DevelopmentConfig`, `ProductionConfig`, `TestingConfig` |

## Idioms (preferred patterns)

- **App factory pattern** — define `create_app(config=None)` in `app/__init__.py`; instantiate the `Flask` app object, register extensions, register blueprints, and return the app. Never use a module-level `app = Flask(__name__)` for anything beyond the simplest scripts.
- **Blueprints for modular routing** — group related routes under `Blueprint` objects in `app/blueprints/<name>/`; register them in `create_app()` via `app.register_blueprint(bp, url_prefix='/<name>')`.
- **Flask-SQLAlchemy `db.Model`** — define all database models as classes inheriting from `db.Model` (the `db` object is an `SQLAlchemy` extension instance from `app/extensions.py`); never write raw SQL in view functions.
- **Extension singletons in `extensions.py`** — instantiate extensions (`db = SQLAlchemy()`, `login_manager = LoginManager()`, `mail = Mail()`) without the app object; initialize them in `create_app()` via `ext.init_app(app)`. This pattern supports the factory and avoids circular imports.
- **Application context for DB operations** — push an application context (`app.app_context()`) for any operation that accesses the DB outside a request (scripts, CLI commands, fixtures).
- **`@bp.route` over `@app.route`** — route decorators belong on the Blueprint object, not the app object; `@app.route` is reserved for the simplest single-file apps.
- **Marshmallow or Pydantic for serialization** — validate and serialize request/response payloads with Marshmallow `Schema` or Pydantic `BaseModel`; never build dicts manually from `request.get_json()`.
- **Flask-WTF for server-rendered forms** — use `FlaskForm` for HTML forms; validate via `form.validate_on_submit()` and access `.data`; never manually parse `request.form`.
- **`url_for()` for URL generation** — always build URLs with `url_for('blueprint_name.view_function')` in Python code and `{{ url_for('blueprint_name.view_function') }}` in Jinja2 templates.
- **Jinja2 template inheritance** — define a base layout in `templates/base.html` (or `templates/layout.html`) using `{% block content %}{% endblock %}`; child templates `{% extends 'base.html' %}` and fill blocks.
- **Environment-based configuration** — subclass a `Config` base class per environment (`DevelopmentConfig`, `TestingConfig`, `ProductionConfig`); load secret keys and DB URIs from environment variables via `os.environ.get()` or `python-dotenv`.
- **Flask-Login for session-based auth** — decorate protected routes with `@login_required`; access the authenticated user via `current_user`; never manually manipulate session cookies for auth.

## Hard Rules emitted

```
HARD_RULE: Application MUST use the factory pattern — create_app() in app/__init__.py
  path_glob: app/__init__.py
  rule_type: SIGNATURE_RULE
  pattern: 'def create_app\('
  rationale: Factory pattern enables test isolation via app.test_client(); a module-level app object prevents multiple configurations and cannot be overridden in tests

HARD_RULE: SQLAlchemy model classes MUST inherit from db.Model (Flask-SQLAlchemy)
  path_glob: app/models/**/*.py
  rule_type: SIGNATURE_RULE
  pattern: '\bdb\.Model\b'
  rationale: db.Model binds the model to the application's SQLAlchemy session; standalone Base subclasses bypass Flask-SQLAlchemy session management

HARD_RULE: Extensions MUST be instantiated without the app object and initialized via init_app()
  path_glob: app/extensions.py
  rule_type: CUSTOM
  pattern: '\.init_app\('
  rationale: init_app() pattern supports the application factory; extensions passed the app directly at construction time cannot be reused across multiple app instances

HARD_RULE: Route decorators MUST use @bp.route — not @app.route — in blueprint modules
  path_glob: app/blueprints/**/*.py
  rule_type: SIGNATURE_RULE
  pattern: '@bp\.route|@\w+_bp\.route'
  rationale: Blueprint routes registered with @app.route are not scoped to the blueprint and cannot be prefixed, namespaced, or unregistered independently

HARD_RULE: URL generation MUST use url_for() — not hard-coded URL strings
  path_glob: app/blueprints/**/*.py
  rule_type: CUSTOM
  rationale: Hard-coded URLs break when url_prefix changes; url_for() adapts automatically and raises an error on invalid endpoint names at build time

HARD_RULE: DB model files MUST be in app/models.py or app/models/ directory
  path_glob: app/models/**/*.py
  rule_type: LOCATION_RULE
  rationale: Consistent model location enables Flask-SQLAlchemy metadata discovery and import predictability

HARD_RULE: Config MUST load secrets and credentials from environment variables, not hard-coded values
  path_glob: app/config.py
  rule_type: CUSTOM
  rationale: Hard-coded secrets leak in version control; environment variables support 12-factor app deployment and CI override
```

## Testing conventions

- Test runner: `pytest` (via `pytest` CLI or `python -m pytest`)
- Test client: `app.test_client()` — instantiated from a factory-created app configured with `TestingConfig`; yields the Flask Werkzeug test client for HTTP-level assertions
- Test file location: `tests/` at project root; mirrors `app/` structure (e.g. `tests/test_auth.py`, `tests/blueprints/test_user.py`)
- Test naming: `test_<scenario>` functions in `test_<module>.py` files; use descriptive names (`test_login_success_redirects`, `test_register_duplicate_email_returns_400`)
- Fixtures: `tests/conftest.py` declares shared fixtures — at minimum an `app` fixture returning a test-configured Flask app, a `client` fixture returning `app.test_client()`, and a `db` fixture pushing an app context and rolling back after each test
- Example conftest pattern:
  ```python
  @pytest.fixture
  def app():
      flask_app = create_app(config='testing')
      with flask_app.app_context():
          db.create_all()
          yield flask_app
          db.drop_all()

  @pytest.fixture
  def client(app):
      return app.test_client()
  ```
- Auth in tests: push auth state via `client.post('/auth/login', data=...)` or override `login_user()` in a fixture; never inject raw session values directly
- DB isolation: use a separate in-memory SQLite DB (or test-specific URL); wrap each test in a transaction rolled back at teardown, or use `db.drop_all()` / `db.create_all()` per test

## Deep-scan file hints

```yaml
auth_hints:
  - "app/blueprints/auth/"
  - "app/auth/"
  - "app/extensions.py"
  - "app/config.py"
  - "app/blueprints/auth/routes.py"
  - "app/blueprints/auth/views.py"
authz_hints:
  - "app/blueprints/auth/"
  - "app/auth/"
  - "app/decorators.py"
  - "app/blueprints/admin/"
  - "app/extensions.py"
ui_hints:
  - "templates/"
  - "app/templates/"
  - "static/"
  - "app/static/"
  - "templates/base.html"
  - "templates/layout.html"
```

## Authz mapping

- `mechanism`: `decorator` (`@login_required` for authentication gate; custom `@roles_required` or Flask-Principal `Permission.require()` for role-based access)
- `role_source`: `db` (roles stored in database, loaded via `db.Model`; Flask-Principal `Identity` carries role `Need` objects; Flask-Login `current_user.roles` for simpler setups)
- Construct → `declarations[].kind`:
  - `@login_required` on a view function → `{kind: middleware, name: login_required}`
  - `@roles_required('admin')` custom decorator → `{kind: role, name: "admin"}`
  - Flask-Principal `Permission(RoleNeed('editor')).require()` → `{kind: role, name: "editor"}`
  - Flask-Principal `Identity` loaded from `current_user` in `identity_loaded` signal handler → `{kind: role, name: <each role/need>}`

## UI detection

- dominant layout: most-referenced `{% extends '<base>' %}` template across `templates/` (typically `base.html` or `layout.html`)
- component: `{% include '<partial>.html' %}` partials; Jinja2 macros defined in `templates/macros/` or inline `{% macro name() %}` blocks
- notification call: `flash()` / `get_flashed_messages()` pattern, or JavaScript notification library wired in base template (e.g. Toastr, SweetAlert2)
- URL generation: `{{ url_for('blueprint_name.view_function') }}` in templates (never hard-coded paths)
- Jinja2 template inheritance signals: `{% extends %}` + `{% block %}` patterns — this is server-rendered HTML

## Reuse discovery

```yaml
reuse_hints:
  helpers:  [ "app/utils/**", "app/helpers/**", "app/utils.py" ]
  model_api: [ "app/models/**", "app/models.py" ]
  services: [ "app/services/**" ]
  commands: [ "app/commands.py", "app/cli.py" ]
```

- `model_api`: public methods, hybrid properties (`@hybrid_property`), and query classmethods on each `db.Model` subclass.
- `commands`: CLI commands registered with `@app.cli.command()` or a `click.Group`; check for `app.cli.add_command()` calls in `create_app()`.
