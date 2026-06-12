---
framework: rails
framework_version_range: "7.x — 8.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: Gemfile
  dependency_marker: "rails"
  version_regex: "gem\\s+['\"]rails['\"],\\s*['\"][~>]*\\s*(\\d+)"
extends: _universal
pack_tier: full
---

# Ruby on Rails Convention Pack (7.x — 8.x)

Conventions for Ruby on Rails backend and full-stack projects. Extends `_universal.md` — universal defaults apply, Rails-specific rules override on conflict.

## Rails version notes

- **7.0 — 7.1**: Hotwire (Turbo + Stimulus) as the default JS stack; importmap-rails replaces Webpack by default; encrypted credentials (`config/credentials.yml.enc`); `config/database.yml` per environment.
- **7.2**: `bin/rails generate` scaffolding ships Brakeman + RuboCop out of the box; `db/schema.rb` is the default schema format; `config/application.rb` is the primary boot config.
- **8.0**: Solid Queue (database-backed job queue), Solid Cache, Solid Cable replace Redis defaults in new apps; Propshaft replaces Sprockets as the default asset pipeline; PWA scaffold built in.

Detection: `version_regex` extracts the major version from the `gem 'rails', '~> N.x'` declaration in `Gemfile`.

## File location standards

| Artifact | Path |
|---|---|
| Models | `app/models/` |
| Controllers | `app/controllers/` |
| Views (ERB) | `app/views/` |
| Helpers | `app/helpers/` |
| Jobs | `app/jobs/` |
| Mailers | `app/mailers/` |
| Channels (Action Cable) | `app/channels/` |
| Concerns (model) | `app/models/concerns/` |
| Concerns (controller) | `app/controllers/concerns/` |
| Service objects (community) | `app/services/` (convention, not Rails core) |
| JavaScript (importmap/jsbundling) | `app/javascript/` |
| Assets (Propshaft/Sprockets) | `app/assets/` |
| Layouts | `app/views/layouts/` |
| Partials | co-located under `app/views/<resource>/`, prefixed `_` |
| Migrations | `db/migrate/` |
| Schema snapshot | `db/schema.rb` (default) or `db/structure.sql` |
| Seeds | `db/seeds.rb` |
| Routes | `config/routes.rb` |
| Application config | `config/application.rb` |
| Environment configs | `config/environments/<env>.rb` |
| Initializers | `config/initializers/` |
| Locales | `config/locales/` |
| Rake tasks | `lib/tasks/` |
| Tests (Minitest default) | `test/` |
| Specs (RSpec) | `spec/` |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Column case | snake_case | `created_at`, `user_id` |
| Table case | plural snake_case | `users`, `order_items` |
| Model class | PascalCase singular | `User`, `OrderItem` |
| Model filename | snake_case singular `.rb` | `user.rb`, `order_item.rb` |
| Controller class | PascalCase plural + `Controller` suffix | `UsersController`, `OrderItemsController` |
| Controller filename | snake_case plural + `_controller.rb` | `users_controller.rb` |
| Helper module | PascalCase + `Helper` suffix | `UsersHelper` |
| Job class | PascalCase verb-noun + `Job` suffix | `ProcessOrderJob`, `SendWelcomeEmailJob` |
| Mailer class | PascalCase + `Mailer` suffix | `UserMailer`, `OrderMailer` |
| Migration filename | `YYYYMMDDHHMMSS_<snake_case_action>.rb` | `20260610120000_create_users.rb` |
| Migration class | PascalCase action | `CreateUsers`, `AddIndexToOrders` |
| View file (action) | `<action>.html.erb` | `index.html.erb`, `show.html.erb` |
| Partial file | `_<name>.html.erb` | `_form.html.erb`, `_user.html.erb` |
| Layout file | `<name>.html.erb` under `layouts/` | `application.html.erb` |
| FK column | `{singular_target_table}_id` | `user_id`, `order_item_id` |
| Join/pivot table | alphabetical `{singular_a}_{singular_b}` | `roles_users` (or via `has_and_belongs_to_many`) |
| Standard timestamps | `created_at`, `updated_at` via `t.timestamps` in migration | (ActiveRecord default) |
| Soft delete column | `deleted_at` (via `acts_as_paranoid` or Discard gem) | (community convention) |
| Route name | auto-generated from resources, accessible as `<resource>_path` | `users_path`, `edit_user_path` |
| Concern module | PascalCase under `app/*/concerns/` | `Archivable`, `Searchable` |
| Rake task namespace | snake_case, colon-separated | `db:seed`, `assets:precompile` |
| Test class (Minitest) | PascalCase + `Test` suffix | `UserTest`, `UsersControllerTest` |
| Test method (Minitest) | `test_<description>` or `it` (Minitest::Spec) | `test_user_is_valid` |
| Spec file (RSpec) | `<name>_spec.rb` under `spec/<type>/` | `user_spec.rb`, `users_controller_spec.rb` |

## Idioms (preferred patterns)

- **Fat model, skinny controller** — business logic lives in models and service objects; controllers only parse params, call model/service methods, and render responses
- **ActiveRecord for all database operations** — use model methods, associations, and scopes; fall back to `find_by_sql` only for performance-critical queries not expressible in ActiveRecord
- **Strong parameters in controllers** — every form submission goes through `params.require(...).permit(...)` to guard against mass assignment; never pass `params` directly to `ActiveRecord::Base` methods
- **RESTful resourceful routes** — declare resources via `resources :users` in `config/routes.rb`; limit to the 7 REST actions (index, show, new, create, edit, update, destroy); add member/collection routes sparingly
- **Migrations for all schema changes** — use `bin/rails generate migration` to produce timestamped migration files; never alter `db/schema.rb` directly
- **Concerns for shared behavior** — extract reusable model or controller behavior into `app/models/concerns/` or `app/controllers/concerns/` using `ActiveSupport::Concern`
- **Scopes for reusable query fragments** — define named scopes (`scope :active, -> { where(active: true) }`) on models; chain them instead of repeating query conditions
- **Callbacks sparingly** — use `before_save`, `after_create`, etc., only for model-local invariants; prefer service objects for orchestration that touches multiple models
- **Validations at the model layer** — declare with `validates`, `validate`, `validates_associated`; keep form error state in the model, not the controller
- **Partials for view decomposition** — share repeated view fragments as `_partial.html.erb`; pass locals explicitly via `render partial: 'form', locals: { user: @user }`
- **Action Mailer for email** — use mailer classes under `app/mailers/`; enqueue with `UserMailer.welcome(user).deliver_later` so email is async
- **Active Job + queued backends** — background work goes through `ApplicationJob` subclasses; use Solid Queue (Rails 8), Sidekiq, or GoodJob as the backend
- **Hotwire (Turbo + Stimulus) for interactivity** — prefer Turbo Frames and Turbo Streams over full-page SPAs; add Stimulus controllers only for DOM behavior Turbo cannot express
- **`rails generate` scaffolding as a starting point** — run `bin/rails generate scaffold Resource field:type` to get MVC skeleton, then prune what you don't need

## Hard Rules emitted

```
HARD_RULE: Migration files MUST follow `YYYYMMDDHHMMSS_<snake_case_action>.rb` naming
  path_glob: db/migrate/*.rb
  rule_type: NAMING_RULE
  pattern: '^\d{14}_[a-z][a-z0-9_]*\.rb$'
  rationale: Rails loads migrations in timestamp order; non-conformant filenames break rollout sequence

HARD_RULE: Model files MUST be in `app/models/` and use snake_case singular naming
  path_glob: app/models/*.rb
  rule_type: NAMING_RULE
  case_style: snake_case_singular
  pattern: '^[a-z][a-z0-9_]*\.rb$'
  rationale: ActiveRecord constantizes the filename to find the class; non-conformant names require explicit `self.table_name` or constant declaration

HARD_RULE: Controller files MUST be in `app/controllers/` and end with `_controller.rb`
  path_glob: app/controllers/**/*_controller.rb
  rule_type: NAMING_RULE
  pattern: '_controller\.rb$'
  rationale: Rails routing maps resource names to controller filenames via this convention; non-conformant files are not auto-discovered

HARD_RULE: Controllers MUST use strong parameters — `params.require().permit()` — before passing params to model methods
  path_glob: app/controllers/**/*_controller.rb
  rule_type: CUSTOM
  rationale: Without strong params, mass-assignment vulnerabilities allow arbitrary attribute injection (CVE-class); Rails raises ForbiddenAttributesError at runtime if unpermitted params hit ActiveRecord

HARD_RULE: Schema changes MUST be expressed as migration files in `db/migrate/`; `db/schema.rb` MUST NOT be edited directly
  path_glob: db/schema.rb
  rule_type: CUSTOM
  rationale: Direct schema.rb edits are overwritten on next `db:schema:dump`; migrations are the durable, versioned change record

HARD_RULE: RESTful routes MUST be declared via `resources` or `resource` helpers in `config/routes.rb`; custom actions must be member/collection additions, not top-level free-form routes
  path_glob: config/routes.rb
  rule_type: CUSTOM
  rationale: `resources` generates correct path helpers, enforces verb-action mapping, and enables `rails routes` introspection; free-form routes are untestable and skip CSRF protection wiring

HARD_RULE: Foreign key columns MUST follow `{singular_target_table}_id` pattern and be declared in a migration
  path_glob: db/migrate/*.rb
  rule_type: NAMING_RULE
  pattern: '[a-z][a-z0-9_]*_id'
  rationale: ActiveRecord `belongs_to` infers the FK column name from the association name; non-conformant columns require explicit `foreign_key:` args on every association declaration

HARD_RULE: Business logic MUST NOT be placed directly in controller actions; complex orchestration belongs in model methods, concerns, or service objects under `app/services/`
  path_glob: app/controllers/**/*_controller.rb
  rule_type: CUSTOM
  rationale: Fat controllers are untestable in isolation and tightly couple HTTP concerns with domain logic; the fat-model/skinny-controller pattern is core Rails convention
```

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — model validations (`validates`) plus Strong Parameters at the controller boundary; writes via `update_column`/`update_attribute`/`save(validate: false)` skip validations and are the bypass to flag.
- **SQL injection** — ActiveRecord parameterizes hash conditions; `where("name = '#{params[:q]}'")` string interpolation is the classic bypass — use placeholders (`where("name = ?", q)`) or the hash form.
- **XSS / output escaping** — ERB `<%= %>` auto-escapes; `raw()`, `.html_safe`, and `<%== %>` are the bypasses — valid only for content passed through `sanitize`, never raw params.
- **CSRF** — `protect_from_forgery with: :exception` is on by default in `ApplicationController`; `skip_before_action :verify_authenticity_token` is the smell — legitimate only for signature-verified webhooks or token-auth API controllers.
- **AuthN/AuthZ enforcement point** — `before_action :authenticate_user!` (Devise) for authentication; Pundit `authorize record` (or CanCanCan abilities) for authorization — inline `current_user.admin?` checks scattered through actions are the bypass smell.
- **Password hashing** — `has_secure_password` (bcrypt via `password_digest` column); never hand-rolled `Digest::SHA1`/MD5 or home-grown salting.
- **Mass assignment** — Strong Parameters `params.require(:user).permit(:name, :email)` is the whitelist; `permit!` (or passing `params` through unfiltered) reopens the exact hole the old `attr_accessible` era was about.
- **Secrets / config** — `Rails.application.credentials` (encrypted `credentials.yml.enc` + `RAILS_MASTER_KEY` from env); plaintext secrets committed in `config/*.yml` are the leak.
- **File uploads** — ActiveStorage attachments with content-type/size validation; never build filesystem paths from params or serve user uploads out of `public/` under client-chosen names.
- **Session/cookie posture** — the cookie store is signed and encrypted, but production still sets `config.force_ssl = true` (Secure flag + HSTS) and a SameSite policy; keep sensitive data out of the session cookie regardless.

## Testing conventions

- Default test runner: `bin/rails test` (wraps Minitest)
- Test file location: `test/` — subdirs mirror `app/` (`test/models/`, `test/controllers/`, `test/mailers/`, `test/jobs/`, `test/system/`, `test/helpers/`, `test/integration/`)
- Test base class: `ActiveSupport::TestCase` (unit); `ActionDispatch::IntegrationTest` (integration); `ActionDispatch::SystemTestCase` (Capybara system tests)
- Minitest naming: class inherits `ActiveSupport::TestCase`; methods named `test_<description>` or use `it` block syntax with `Minitest::Spec`
- RSpec alternative: if `rspec-rails` in `Gemfile`, prefer `spec/` layout with `*_spec.rb` files; `rails generate rspec:install` wires the generator; spec types: `model`, `controller`, `request`, `feature`, `helper`, `mailer`, `job`
- Fixtures (default): YAML files under `test/fixtures/`; loaded via `fixtures :users` in test class
- FactoryBot alternative: if `factory_bot_rails` in `Gemfile`, define factories in `spec/factories/` or `test/factories/`; create with `FactoryBot.create(:user)` or `create(:user)` with include
- Database state: `ActiveSupport::TestCase` runs each test in a DB transaction that rolls back; system tests run in a separate process and require `DatabaseCleaner` or fixtures strategy
- Request specs: `get users_path`, `post users_path, params: { user: { name: 'Alice' } }`, assert with `assert_response :success` (Minitest) or `expect(response).to have_http_status(:ok)` (RSpec)
- Model assertions: `assert user.valid?`, `assert_equal 'Alice', user.name` (Minitest) / `expect(user).to be_valid` (RSpec)
- Mailer tests: `assert_emails 1 { UserMailer.welcome(@user).deliver_now }` (Minitest) / `have_enqueued_mail` matcher (RSpec)
- Job tests: `assert_enqueued_with(job: ProcessOrderJob)` (Minitest) / `have_enqueued_job` matcher (RSpec)
- System tests: driven by Capybara + Selenium (`test/system/`); run separately with `bin/rails test:system`

## Deep-scan file hints

```yaml
auth_hints:
  - config/initializers/devise.rb
  - app/models/user.rb
  - app/controllers/application_controller.rb
  - config/routes.rb
authz_hints:
  - app/policies/
  - app/models/ability.rb
  - app/controllers/application_controller.rb
  - config/initializers/cancancan.rb
ui_hints:
  - app/views/layouts/
  - app/assets/
  - app/javascript/
  - app/views/components/
```

## Authz mapping

- `mechanism`: `policy` (Pundit) or `ability` (CanCanCan), plus `middleware` for authentication guards (`before_action :authenticate_user!` via Devise)
- `role_source`: `db` (roles stored in the database, typically via a `roles` table or enum column on `users`)
- Construct → `declarations[].kind`:
  - A Pundit policy class in `app/policies/<model>_policy.rb` → `{kind: policy, name}`
  - `authorize @record` call in a controller action (Pundit) → `{kind: policy, name}`
  - `can :manage, Resource` declaration inside `Ability#initialize` in `app/models/ability.rb` (CanCanCan) → `{kind: ability, name}`
  - `before_action :authenticate_user!` (Devise) in `ApplicationController` or specific controllers → `{kind: middleware, name}`

## UI detection

- dominant layout: `app/views/layouts/application.html.erb` (default); project may add `admin.html.erb` or other named layouts — identified by the `layout` declaration in controllers
- partial convention: ERB partials prefixed with `_` (e.g., `_form.html.erb`, `_header.html.erb`); rendered via `render 'form'` or `render partial: 'shared/header'`
- template inheritance: `<%= yield %>` placeholder in the layout; content sections added via `<%= content_for :title, 'Page Title' %>` and yielded with `<%= yield :title %>`
- Hotwire (Turbo + Stimulus): Turbo Frames declared as `<turbo-frame id="...">`, Turbo Streams via `render turbo_stream:`, Stimulus controllers in `app/javascript/controllers/`; `importmap-rails` or `jsbundling-rails` wires JS
- notification call: flash messages via `flash[:notice]` / `flash[:alert]` in controllers; rendered in layout via `<%= flash[:notice] %>`; SweetAlert2 or similar can be wired via a Stimulus controller

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "app/helpers/**" ]
  model_api: [ "app/models/**" ]
  services: [ "app/services/**" ]
  commands: [ "lib/tasks/**" ]
```
- model_api: public instance/class methods, named scopes (`scope :active, ->`), `ActiveSupport::Concern` modules included into models.
- commands: Rake task definitions (`.rake` files under `lib/tasks/`); each task declared with `task :name => :environment do`.
