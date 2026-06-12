---
framework: sinatra
framework_version_range: "3.x — 4.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: Gemfile
  dependency_marker: "sinatra"
  version_regex: "gem\\s+['\"]sinatra['\"],\\s*['\"][~>]*\\s*(\\d+)"
extends: _universal
pack_tier: full
---

# Sinatra Convention Pack (3.x — 4.x)

Conventions for Sinatra (Ruby micro-framework) backend and lightweight full-stack projects. Extends `_universal.md` — universal defaults apply, Sinatra-specific rules override on conflict.

Sinatra is intentionally minimal: it provides a route DSL and Rack integration, but imposes no directory structure, ORM, or framework module structure. This pack documents the **community-standard layout** used by well-structured Sinatra applications. Projects may deviate — treat this as the default convention, not a framework-enforced constraint.

## File location standards

| Artifact | Path |
|---|---|
| Classic app entry point | `app.rb` (single-file classic style) |
| Modular app class | `app/` — one `Sinatra::Base` subclass per concern (`app/app.rb` or `app/<name>_app.rb`) |
| Rack entry point | `config.ru` (required for deployment; mounts the app via `run` or `map`) |
| ERB view templates | `views/` — files with `.erb` extension (e.g., `views/index.erb`) |
| Layout template | `views/layout.erb` (auto-loaded for every `erb` call unless `:layout` is overridden) |
| Static assets | `public/` (served automatically by Sinatra's built-in static file handler) |
| Models / domain logic | `models/` (ORM models, e.g., Sequel `Sequel::Model` subclasses, or plain Ruby objects) |
| Helpers | `helpers/` (Ruby modules `include`d via `helpers do … end` or `helpers HelperModule`) |
| Gemfile | `Gemfile` + `Gemfile.lock` |
| App configuration | settings in `configure` blocks in `app.rb` / the `Sinatra::Base` subclass |
| Tests | `spec/` (RSpec) or `test/` (Minitest) |

Note: classic style (`require 'sinatra'` at the top level) suits scripts and tiny apps. For anything non-trivial, the modular style (`class MyApp < Sinatra::Base`) is the idiomatic choice because it enables namespacing, multiple apps, and clean testing via `Rack::Test`.

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Classic app file | snake_case | `app.rb` |
| Modular app class | PascalCase, `Sinatra::Base` subclass | `MyApp`, `AdminApp` |
| Modular app filename | snake_case `.rb` | `my_app.rb`, `admin_app.rb` |
| View file | snake_case, `.erb` extension | `index.erb`, `user_show.erb` |
| Partial convention | prefix with `_` (community convention; Sinatra has no built-in partial support) | `_nav.erb`, `_footer.erb` |
| Helper module | PascalCase + `Helpers` suffix | `ApplicationHelpers`, `AuthHelpers` |
| Route block | route verb + path string block | `get '/users' do … end` |
| Route path segments | lowercase, hyphen-separated for multi-word | `/user-profiles`, `/admin/reports` |
| Named route params | colon-prefixed snake_case | `:user_id`, `:slug` |
| Model class | PascalCase singular | `User`, `Order` |
| Model filename | snake_case singular `.rb` | `user.rb`, `order.rb` |
| Column / attribute | snake_case | `created_at`, `user_id` |
| Rake task namespace | snake_case, colon-separated | `db:migrate`, `assets:precompile` |
| Test file (RSpec) | `*_spec.rb` under `spec/` | `app_spec.rb`, `user_spec.rb` |
| Test file (Minitest) | `*_test.rb` under `test/` | `app_test.rb`, `user_test.rb` |

## Idioms (preferred patterns)

- **Route DSL is the entry point** — all HTTP handling is declared with `get`, `post`, `put`, `patch`, `delete`, `head`, `options`, `link`, `unlink` blocks: `get '/path' do … end`. The block's return value (last expression) is the response body.
- **Classic vs modular style** — classic style (`require 'sinatra'`) pollutes the top-level namespace and mixes into `main`; prefer the modular style (`class MyApp < Sinatra::Base`) for all but the simplest scripts. Modular apps require `require 'sinatra/base'`.
- **`config.ru` as Rack entry point** — mount the app with `run MyApp` (single app) or `map '/api' { run ApiApp }` (multiple apps). Always provide a `config.ru` for deployment to any Rack-compatible server (Puma, Unicorn, Falcon).
- **`before` and `after` filters** — use `before do … end` for cross-cutting setup (authentication checks, setting `content_type`, loading current user) and `after do … end` for teardown; filters can be scoped with a pattern: `before '/admin/*' do … end`.
- **Helpers via `helpers do … end`** — define shared view/route helpers inside a `helpers do … end` block or by passing a module: `helpers ApplicationHelpers`. Helpers are available in both routes and ERB templates.
- **ERB templates via `erb :view`** — call `erb :index` to render `views/index.erb`; pass locals with `erb :show, locals: { user: @user }`; or set instance variables in the route block (available in the template automatically in classic style).
- **`halt` for early exit** — terminate a request immediately with a status and body: `halt 403, 'Forbidden'` or `halt erb(:error)`. Never `return` a response from inside a nested method and expect Sinatra to use it.
- **`redirect` for HTTP redirects** — `redirect '/login'` (302) or `redirect '/page', 301` (permanent); always call `redirect` as the last expression (it calls `halt` internally).
- **Settings for configuration** — declare app settings via `set :option, value` in a `configure` block (or in the class body for modular style); access with `settings.option`. Use `configure :development do … end` for environment-specific overrides.
- **Rack middleware via `use`** — add middleware to the stack with `use MiddlewareClass, *args`; authentication layers (e.g., `Warden`, `Rack::Auth::Basic`), session middleware, and logging all belong here.
- **Sessions** — enable with `enable :sessions` (Sinatra's built-in Rack session cookie) or `use Rack::Session::Cookie, secret: ENV['SESSION_SECRET']` for explicit control; access via the `session` hash.
- **Keep route blocks thin** — route handlers should delegate business logic to plain Ruby objects in `models/` or `lib/`; route blocks are the Rack-level boundary, not the place for business rules.
- **Sequel as the preferred ORM** — Sequel integrates cleanly with Sinatra (no framework coupling); use `Sequel::Model` subclasses under `models/`; connect with `DB = Sequel.connect(ENV['DATABASE_URL'])` in `app.rb` or `config.ru`.
- **JSON APIs** — for API-only apps, set `content_type :json` in a `before` filter and use `JSON.generate(object)` (or the `json` helper from `sinatra-contrib`) as the response body; avoid ERB views entirely.

## Hard Rules emitted

```
HARD_RULE: Modular Sinatra apps MUST subclass Sinatra::Base and require 'sinatra/base'
  path_glob: app/**/*.rb
  rule_type: SIGNATURE_RULE
  pattern: 'class\s+\w+\s*<\s*Sinatra::Base'
  rationale: Requiring 'sinatra' (classic style) in a modular app injects route handlers into the top-level namespace and prevents test isolation via Rack::Test

HARD_RULE: config.ru MUST exist and mount the app via `run` or `map`
  path_glob: config.ru
  rule_type: LOCATION_RULE
  rationale: Without config.ru, Rack-compatible servers (Puma, Unicorn, Falcon) cannot discover or mount the application

HARD_RULE: Route blocks MUST be thin — no inline DB queries or complex business logic inside a `get/post/put/patch/delete do … end` block
  path_glob: app.rb
  rule_type: CUSTOM
  rationale: Inline business logic in route blocks cannot be unit-tested in isolation and couples HTTP concerns to domain logic

HARD_RULE: ERB view files MUST use the `.erb` extension and live under `views/`
  path_glob: views/*.erb
  rule_type: NAMING_RULE
  pattern: '^views/[a-z][a-z0-9_]*(/.+)?\.erb$'
  rationale: Sinatra resolves `erb :view_name` by looking for `views/<view_name>.erb`; misnamed or mislocated templates raise Errno::ENOENT at runtime

HARD_RULE: Sessions MUST be enabled with a secret from an environment variable — never a hard-coded string
  path_glob: app.rb
  rule_type: CUSTOM
  rationale: Hard-coded session secrets leak in version control and are shared across all environments; Sinatra's `set :session_secret, ENV['SESSION_SECRET']` is the correct pattern

HARD_RULE: `halt` MUST be used for early response termination inside a route block — not `return`
  path_glob: app.rb
  rule_type: CUSTOM
  rationale: Sinatra processes the return value of the route block, not a `return` inside a helper called from the block; using `return` silently produces incorrect behavior when called from a nested method context
```

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom.

- **Input validation** — Sinatra validates nothing; `params` is raw user input — validate through dry-validation/dry-schema contracts (or explicit guard clauses that `halt 400`) before anything touches the data layer.
- **SQL injection** — depends on the data layer the app chose: Sequel datasets parameterize (`where(name: v)`); interpolated strings (`DB["... #{v}"]`, `db.execute("... #{v}")`) are the bypass — use placeholders (`where("name = ?", v)`) or bound variables.
- **XSS / output escaping** — ERB via Tilt does NOT autoescape by default; the idiom is `set :erb, escape_html: true`, after which `<%== %>` is the explicit unsafe bypass — without that setting, every `<%= %>` of user data is an XSS.
- **CSRF** — supplied by Rack::Protection (ships with the sinatra gem), but `Rack::Protection::AuthenticityToken` is NOT in the default set — enable it explicitly (`use Rack::Protection::AuthenticityToken`, requires sessions) and embed the token in forms.
- **AuthN/AuthZ enforcement point** — no framework auth; the idiom is a `before` filter or shared helper (`authorize!`) that `halt 401/403`, or Warden mounted as Rack middleware — per-route ad-hoc session checks that drift out of sync are the smell.
- **Password hashing** — `BCrypt::Password.create` / `==` from the bcrypt gem; never `Digest::MD5`/`SHA1` or manual salting.
- **Mass assignment** — exposure depends on the ORM: `Model.create(params)` with Sequel-style models writes whatever columns were posted — use field allowlists (`set_fields(params, [:name, :email])`) or build the attribute hash explicitly.
- **Secrets / config** — ENV (dotenv gem in dev), especially `session_secret`, which must be a stable random value of at least 64 bytes from the environment — an unset or committed secret lets attackers forge session cookies.
- **File uploads** — `params[:file][:tempfile]` plus `[:filename]` are fully attacker-controlled; generate your own stored name, enforce size/type allowlists, and keep uploads out of `public/`.
- **Session/cookie posture** — `enable :sessions` is a signed (not encrypted) cookie; set `httponly`/`secure`/`same_site` session options in production and keep nothing sensitive in the cookie itself.

## Testing conventions

- **Test runners**: RSpec (most common; add `rspec` to `Gemfile`'s test group) or Minitest (`minitest`)
- **HTTP integration layer**: `Rack::Test` — include `Rack::Test::Methods` in the test class/context; set `app { MyApp }` (modular) or `app { Sinatra::Application }` (classic); call `get '/path'`, `post '/path', params`, etc.
- **Test file location**: `spec/` (RSpec) or `test/` (Minitest) — mirror the app structure (e.g., `spec/app_spec.rb`, `spec/models/user_spec.rb`)
- **Test naming (RSpec)**: `describe MyApp do … describe 'GET /users' do … it 'returns 200' do … end end end`
- **Test naming (Minitest)**: class inheriting `Minitest::Test`; methods named `test_<description>`: `def test_get_users_returns_200`
- **Fixtures**: FactoryBot (`factory_bot` gem) for model factories, or simple `let` / `setup` blocks creating model instances directly; database state managed per-test with `DatabaseCleaner` or DB transaction rollback
- **Database isolation**: use `database_cleaner-sequel` (or the equivalent adapter gem for your chosen ORM) to truncate or wrap tests in transactions; define strategy in `spec/support/database_cleaner.rb` or `spec/spec_helper.rb`
- **Example Rack::Test + RSpec pattern**:
  ```ruby
  require 'spec_helper'
  require_relative '../app'

  describe MyApp do
    include Rack::Test::Methods

    def app = MyApp

    it 'GET /users returns 200 and JSON' do
      get '/users', {}, { 'HTTP_ACCEPT' => 'application/json' }
      expect(last_response.status).to eq 200
      expect(JSON.parse(last_response.body)).to be_an(Array)
    end
  end
  ```
- **Coverage**: SimpleCov (`simplecov` gem) required in `spec/spec_helper.rb` or `test/test_helper.rb` before any app requires

## Deep-scan file hints

```yaml
auth_hints:
  - app.rb
  - config.ru
  - helpers/
  - lib/
  - before do
  - "enable :sessions"
  - warden
authz_hints:
  - helpers/
  - "before '/admin"
  - lib/
ui_hints:
  - views/
  - "views/layout.erb"
  - public/
```

## Authz mapping

- `auth.mechanism`: `filter` (`before` blocks) or `middleware` (Rack-level, e.g., Warden, `Rack::Auth::Basic`)
- `authz.mechanism`: `filter` (`before` blocks performing role checks) or `middleware` (Rack middleware wrapping the app)
- `authz.role_source`: `db` (role loaded from the database in the `before` filter) or `token` (JWT claim decoded in middleware or `before` filter)
- Construct → `declarations[].kind`:
  - A `before do … end` or `before '/pattern/*' do … end` block that checks authentication or halts on failure → `{kind: filter}`
  - A helper method invoked inside a `before` filter to verify a user's role (e.g., `require_role :admin`) → `{kind: role}`
  - A Rack middleware added via `use` that performs authentication/authorization (e.g., `use Warden::Manager`, `use Rack::Auth::Basic`) → `{kind: middleware}`

## UI detection

- dominant layout: `views/layout.erb` — Sinatra wraps every `erb :view` call in this layout by default (the view's output is injected at `<%= yield %>` in the layout); override per-route with `erb :view, layout: :other_layout` or disable with `layout: false`
- component: no built-in partial system; partials are rendered by calling `erb :'partials/nav', layout: false` inside the template, typically wrapped in a helper method (`def partial(name, locals={}) = erb :"partials/#{name}", layout: false, locals: locals`)
- notification call: flash messages via `sinatra-flash` gem (`flash[:notice]`) or session-based manual flash; rendered in `views/layout.erb`; SweetAlert2 or similar can be wired in layout JavaScript
- many Sinatra apps are **API-only** (JSON responses, no ERB views); when `views/` is absent, treat as API-only and skip UI detection

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "helpers/**", "app/helpers/**" ]
  model_api: [ "models/**", "app/models/**" ]
  services: [ "services/**", "lib/**" ]
  commands: [ "Rakefile", "tasks/**", "lib/tasks/**" ]
```

- `model_api`: public instance/class methods and dataset methods on Sequel `Sequel::Model` subclasses (or equivalent plain Ruby objects); named scopes or dataset modules.
- `services`: plain Ruby service objects in `lib/` or `services/`; check for classes initialized with domain objects and called from route blocks.
- `commands`: Rake tasks in `Rakefile` or `tasks/**/*.rake`; look for `namespace :db` tasks (migrations) and custom `task :name do … end` definitions.
