# Starterkit Context Schema

> Canonical schema for `.mega-sdd/codebase/starterkit-context.yaml` — single source of truth for all mega-sdd consumers.

**Version:** 3.1 — supersedes 3.0, 2.0, 1.0 (schema lineage: 1.0 initial; 2.0 added per-slice cache; 3.0 added `patterns:`; 3.1 neutral auth/authz reshape — rbac→authz, auth.routes→entrypoints, auth.guard→mechanism)
**Produced by:** `mega-sdd:scan-codebase` Step 10.5 deep-scan stage + Step 10.5.2.5 pattern extraction
**Consumed by:** `mega-sdd:generate-units` (Step 4.7), `mega-sdd:execute-bolts` (Step 1.5.f-h), `mega-sdd:orchestrate-flow` (handoff metadata propagation), `validate-starterkit-conformance.sh` (`patterns:` block consumer)
**Backward compat:** v1.0 readers skip the `cache_signatures:` block. v2.0 readers skip the `patterns:` block. v3.0+ writers MUST emit `patterns:`. v3.1 reshapes auth/authz (breaking format change — see cache migration note in deep-scan-stage.md). Consumers MAY read v1.0/v2.0/v3.0; producers MUST emit v3.1.

---

## Contents

- Top-level structure
- §patterns block — multi-framework examples (v3.0+)
- §auth block (authentication — framework-neutral)
- §authz block (authorization — framework-neutral; replaces the old Laravel-shaped `rbac` block)
- §ui_ux block
- §libs block
- §cache_signatures block (v2.1)
- Partial output protocol
- Anti-halu rails
- See also

## Top-level structure

```yaml
starterkit_context:
  schema_version: 3.1                    # v3.1 = neutral auth/authz reshape (rbac->authz, auth.routes->entrypoints, auth.guard->mechanism); v3.0 added patterns:
  generated_by: scan-codebase v3.0.0
  generated_at: <ISO8601 timestamp>      # MOST RECENT slice write time
  framework: laravel                     # from codebase-map.md §7 Framework.name
  framework_version: "12.x"              # from codebase-map.md §7 Framework.version
  framework_pack: laravel-base-26        # from codebase-map.md §7 Framework.pack_path basename

  partial: true                          # OPTIONAL — only when ≥1 slice failed
  partial_slices: [authz]                # OPTIONAL — present when partial: true
  reused_slices: [auth, ui_ux]           # v2.0+ — per-slice cache provenance (which slices reused vs freshly-dispatched)

  auth: { ... }                          # fresh OR cached slice content
  authz: { ... }                         # fresh OR cached (replaces old rbac: block)
  ui_ux: { ... }                         # fresh OR cached
  libs: [ ... ]                          # fresh OR cached

  patterns:                                    # v3.0+ — generic schema, pack-driven values
    controller:                                # endpoint/request handler (universal semantic role)
      location: <dir-path>                     # where handlers live
      naming: <pattern>                        # template, e.g. "{Model}Controller<ext>" / "{model}_views.py" / "{Model}.handler.ts"
      extension: <file-ext>                    # ".php" | ".py" | ".ts" | ".rb" | ...
      _source: [<sample file:lines>]
      extras: {}                               # framework-specific (Laravel: {methods, base_class}; Django: {as_view, mixins}; …)
    data_model:                                # persistence-layer entity (universal)
      location: <dir-path>
      naming: <pattern>
      extension: <file-ext>
      _source: [<sample file:lines>]
      extras: {}                               # Laravel: {traits, cast_style}; Django: {meta, managers}; Prisma: {schema_file}; …
    request_validator:                         # input validation/parsing layer (optional per framework)
      location: <dir | null>                   # null when framework has no validation layer (e.g., Express w/o zod)
      naming: <pattern | null>
      extension: <file-ext | null>
      _source: [<sample> or empty]
      extras: {}                               # Laravel: {validation_style: array-rules|rule-objects|inline}; Django: {form_or_serializer}; Express: {schema_lib: zod|joi|yup}
    business_logic:                            # service/usecase layer (optional)
      location: <dir | null>                   # null when framework convention has no service layer
      naming: <pattern | null>
      extension: <file-ext | null>
      _source: [<sample> or empty]
      extras: {}                               # NestJS: {injectable, providers}; Laravel: {action_class_style}; …
    test:
      location: <dir-path>
      naming: <pattern>                        # "{Model}Test.php" | "{model}.test.ts" | "test_{model}.py"
      extension: <file-ext>
      framework: <test framework>              # phpunit | pest | jest | vitest | pytest | rspec | go-test | other
      _source: [<sample file:lines>]
      extras: {}
    schema_migration:                          # DDL / migration files (universal)
      location: <dir-path>
      naming: <pattern>                        # framework-specific format
      extension: <file-ext>
      _source: [<sample file:lines>]
      extras: {}                               # Laravel: {timestamp_format}; Django: {numbered_seq}; Rails: {timestamped}; Prisma: {single_schema_file}
    route:
      location: <dir or single-file path>
      style: <generic descriptor>              # "centralized-routes" | "decorator-based" | "file-based-routing" | "manual"
      api_prefix: <string | null>
      web_file: <path | null>
      api_file: <path | null>
      _source: [<sample file:lines>]
      extras: {}                               # Laravel: {resource_style: resource|apiResource}; FastAPI: {router_count}; NestJS: {controller_decorators}

  cache_signatures:                      # v2.1 schema (per-ecosystem locks; replaces v2.0 php/js-only + v1.0 cache_key:)
    locks_sha256:                        # one digest per detected ecosystem (php|js|rust|go|ruby|python|jvm)
      <ecosystem>: <hex>
    app_ecosystem: <ecosystem>           # ecosystem of §7 Framework (drives app_locks_digest)
    framework_pack: <pack-name>          # retained
    per_slice:
      auth:   { signature_sha256: <hex>, generated_at: <ISO8601> }
      authz:  { signature_sha256: <hex>, generated_at: <ISO8601> }
      ui_ux:  { signature_sha256: <hex>, generated_at: <ISO8601> }
      libs:   { signature_sha256: <hex>, generated_at: <ISO8601> }
```

## §patterns block — multi-framework examples (v3.0+)

The schema container is framework-agnostic. Values come from the framework pack (`framework-conventions/<pack>.md`) + deep-scan reading of the real codebase. Same schema, different concrete values per framework:

### Example A — Laravel pack (laravel-base-26)

```yaml
patterns:
  controller:
    location: "app/Http/Controllers/"
    naming: "{Model}Controller.php"
    extension: ".php"
    _source: ["app/Http/Controllers/UserController.php:1-5"]
    extras:
      base_class: "App\\Http\\Controllers\\Controller"
      methods: [index, create, store, show, edit, update, destroy]
  data_model:
    location: "app/Models/"
    naming: "{Model}.php"
    extension: ".php"
    _source: ["app/Models/User.php:1-10"]
    extras:
      traits: [HasFactory, HasUuid, SoftDeletes]
      cast_style: "method"
  request_validator:
    location: "app/Http/Requests/"
    naming: "{Action}{Model}Request.php"
    extension: ".php"
    _source: ["app/Http/Requests/StoreUserRequest.php:1-3"]
    extras:
      validation_style: "array-rules"
  business_logic:
    location: "app/Services/"
    naming: "{Model}Service.php"
    extension: ".php"
    _source: ["app/Services/NotificationService.php:1-5"]
    extras:
      action_class_style: false
  test:
    location: "tests/Feature/"
    naming: "{Model}Test.php"
    extension: ".php"
    framework: "phpunit"
    _source: ["tests/Feature/UserTest.php:1-5"]
    extras: {}
  schema_migration:
    location: "database/migrations/"
    naming: "YYYY_MM_DD_HHMMSS_create_{table}_table.php"
    extension: ".php"
    _source: ["database/migrations/2024_01_01_000000_create_users_table.php"]
    extras:
      timestamp_format: "YYYY_MM_DD_HHMMSS"
  route:
    location: "routes/"
    style: "centralized-routes"
    api_prefix: "api"
    web_file: "routes/web.php"
    api_file: "routes/api.php"
    _source: ["routes/api.php:1-5"]
    extras:
      resource_style: "apiResource"
```

### Example B — Django pack

```yaml
patterns:
  controller:
    location: "<app>/views.py | <app>/views/"
    naming: "{model}_views.py"
    extension: ".py"
    _source: ["users/views.py:1-10"]
    extras:
      class_based: true
      as_view: ["ListView", "DetailView", "CreateView", "UpdateView", "DeleteView"]
      mixins: ["LoginRequiredMixin"]
  data_model:
    location: "<app>/models.py"
    naming: "{Model}.py"                       # class within models.py — pattern is class name, not file name
    extension: ".py"
    _source: ["users/models.py:5-30"]
    extras:
      meta_class: true
      managers: ["objects", "active"]
  request_validator:
    location: "<app>/forms.py | <app>/serializers.py"
    naming: "{Model}Form.py | {Model}Serializer.py"
    extension: ".py"
    _source: ["users/serializers.py:1-5"]
    extras:
      form_or_serializer: "drf-serializer"
  business_logic:
    location: null                              # Django does not enforce a service layer convention
    naming: null
    extension: null
    _source: []
    extras: {}
  test:
    location: "<app>/tests.py | <app>/tests/"
    naming: "test_{module}.py"
    extension: ".py"
    framework: "pytest"
    _source: ["users/tests.py:1-10"]
    extras: {}
  schema_migration:
    location: "<app>/migrations/"
    naming: "{NNNN}_{description}.py"
    extension: ".py"
    _source: ["users/migrations/0001_initial.py"]
    extras:
      numbered_seq: true
  route:
    location: "<app>/urls.py + <project>/urls.py"
    style: "centralized-routes"
    api_prefix: "api/v1"
    web_file: "myproject/urls.py"
    api_file: null
    _source: ["myproject/urls.py:1-10"]
    extras:
      include_pattern: true
```

### Example C — Express + Zod (Node/TypeScript)

```yaml
patterns:
  controller:
    location: "src/controllers/ | src/handlers/"
    naming: "{Model}.handler.ts"
    extension: ".ts"
    _source: ["src/controllers/leave.ts:1-5"]
    extras:
      style: "function-handlers"
      async: true
  data_model:
    location: "src/models/ | src/entities/"
    naming: "{Model}.ts"
    extension: ".ts"
    _source: ["src/models/user.ts:1-10"]
    extras:
      orm: "typeorm"
      decorator_based: true
  request_validator:
    location: "src/validators/ | src/schemas/"
    naming: "{Model}.schema.ts"
    extension: ".ts"
    _source: ["src/validators/leave.ts:1-3"]
    extras:
      schema_lib: "zod"
  business_logic:
    location: "src/services/"
    naming: "{Model}.service.ts"
    extension: ".ts"
    _source: ["src/services/leave.service.ts:1-5"]
    extras: {}
  test:
    location: "tests/ | src/**/*.spec.ts"
    naming: "{model}.test.ts"
    extension: ".ts"
    framework: "jest"
    _source: ["tests/leave.test.ts:1-5"]
    extras: {}
  schema_migration:
    location: "src/migrations/"
    naming: "<timestamp>-{description}.ts"
    extension: ".ts"
    _source: ["src/migrations/1700000000000-initial.ts"]
    extras:
      orm_native: true
  route:
    location: "src/routes/"
    style: "manual"
    api_prefix: "api"
    web_file: null
    api_file: "src/routes/api.ts"
    _source: ["src/app.ts:10-15"]
    extras:
      router_lib: "express-router"
```

### Genericness guarantees

- **Container schema is identical** across packs (7 categories, same field names, `extras: {}` per category).
- **`location` can be `null`** when the framework has no convention for that category (Django has no service layer ⇒ `business_logic: { location: null, ... }`).
- **`naming` template uses `{Model}` / `{model}` placeholders** filled by pack-specific casing rules.
- **`extras: {}` is the escape hatch** for framework quirks — anything not generic goes here. Validators MUST NOT introspect `extras` (it varies per pack).
- **Pack-driven extraction**: `framework-conventions/<pack>.md` tells deep-scan WHERE to look for each category. `_universal.md` fallback covers unknown frameworks with best-effort heuristics.

## §auth block (authentication — framework-neutral)

```yaml
auth:
  lib: "<open string>"             # e.g. sanctum | django-allauth | passport | next-auth | not_detected (NOT a closed enum)
  lib_version: ""                  # version string or "" if not_detected
  lib_source: "<file:line>"        # evidence proving the lib (required unless not_detected)
  mechanism: session               # session | token | jwt | oauth | builtin | unknown
  user_model: "<FQCN or path or null>"
  entrypoints:                     # login / register / logout handlers
    - { name: "login", _source: "<file:line>" }
  features: []                     # subset of recognized features (email_verification, 2fa, social_login, ...)
  _source: ["<file:line>", ...]    # anti-halu citation
```

## §authz block (authorization — framework-neutral; replaces the old Laravel-shaped `rbac` block)

```yaml
authz:
  lib: "<open string>"             # e.g. spatie/permission | django.contrib.auth | casl | not_detected (open, not an enum)
  lib_source: "<file:line>"        # evidence (required unless not_detected)
  mechanism: middleware            # middleware | decorator | guard | policy | mixin | builtin | unknown
  role_source: model               # model | config | db | enum | unknown — where roles/groups are defined
  declarations:                    # the access-control rules, stack-neutral
    - name: "<role|permission|gate|policy name>"
      kind: role                   # role | permission | gate | policy | group
      applies_to: "<route/controller/view it guards, or null>"
      _source: "<file:line>"
  _source: ["<file:line>", ...]
```

## §ui_ux block

```yaml
ui_ux:
  js_framework: alpine             # enum: alpine | livewire | inertia | vue | react | none
  css_framework: tailwind          # enum: tailwind | bootstrap | bulma | custom | none
  layout_extends: "layouts.app"    # Blade extends path used in starterkit views
  layout_file: "resources/views/layouts/app.blade.php"  # actual file path
  component_dir: "resources/views/components"  # Blade components dir
  notification_lib: sweetalert2    # enum: sweetalert2 | toastr | native | not_detected
  icon_lib: heroicons              # enum: heroicons | fontawesome | not_detected
  datatable_lib: yajra/laravel-datatables  # or "not_detected"
  design_tokens:
    colors: { primary: "#3b82f6", secondary: "#64748b" }  # subset from tailwind.config.js extend.colors
    spacing: default               # or custom-spec object
    fonts: ["Inter"]
  idioms:                          # array of recognized starterkit idioms
    - "use document.addEventListener('DOMContentLoaded', ...) over $(document).ready"
    - "responsive mobile-first (sm/md/lg breakpoints)"
  _source: ["package.json:15", "tailwind.config.js", "resources/views/layouts/app.blade.php"]
```

## §libs block

```yaml
libs:
  - name: "laravel/sanctum"
    version: "4.0"
    category: auth                 # enum: auth | rbac | ui | queue | cache | log | test | http | misc
    usage_hint: ["app/Http/Kernel.php", "routes/api.php"]  # files where lib is imported/used
  # ... (repeat per lib in manifests)
```

## §cache_signatures block (v2.1)

```yaml
cache_signatures:
  locks_sha256:                         # TECH-AGNOSTIC — one digest per detected ecosystem
    ruby: "abc123..."                   #   e.g., sha256(Gemfile.lock) for a Rails app
    js: "def456..."                     #   e.g., sha256(yarn.lock) for its asset layer
  app_ecosystem: ruby                   # ecosystem of §7 Framework
  framework_pack: "rails"               # retained
  per_slice:
    auth:
      signature_sha256: <hex>           # sha256(app_locks_digest + framework_pack §auth + auth-libs.md)
      generated_at: "2026-05-25T10:00:00Z"
    authz:
      signature_sha256: <hex>           # sha256(app_locks_digest + framework_pack §authz + authz-libs.md)
      generated_at: "2026-05-25T10:00:00Z"
    ui_ux:
      signature_sha256: <hex>           # sha256(frontend_locks_digest + framework_pack §ui + ui-libs.md)
      generated_at: "2026-05-25T10:00:00Z"
    libs:
      signature_sha256: <hex>           # sha256(all_locks_digest + framework_pack §libs + generic-libs.md)
      generated_at: "2026-05-25T10:00:00Z"
```

**Cache reuse rule (v2.0+, per-slice):** on re-scan, scan-codebase computes the current signature for each of 4 slices independently. For each slice:
- IF prior.per_slice[<slice>].signature_sha256 == current_<slice>_signature → slice reused (no subagent dispatch for that slice)
- ELSE → that slice's subagent re-dispatched; consolidator merges fresh slice with other cached slices

**Cache invalidation matrix (v2.1, ecosystem-relative — examples for a non-JS app with a JS asset layer, e.g., Rails+esbuild or Laravel+Vite):**

| Input changed | Slices invalidated | Subagent dispatches needed |
|---|---|---|
| app-ecosystem lock only (Gemfile.lock / composer.lock / go.sum / Cargo.lock / …) | auth, authz, libs (3/4) | 3 |
| js asset-layer lock only | ui_ux, libs (2/4) | 2 |
| Both | auth, authz, ui_ux, libs (4/4) | 4 (worst case) |
| framework_pack §auth section | auth (1/4) | 1 |
| framework_pack §authz section | authz (1/4) | 1 |
| framework_pack §ui section | ui_ux (1/4) | 1 |
| framework_pack §libs section | libs (1/4) | 1 |
| lib-patterns/<fw>/auth-libs.md | auth (1/4) | 1 (best case — 75% saving) |

For a single-ecosystem app (pure Go API, pure Next.js), `app_locks_digest == frontend_locks_digest == all_locks_digest`, so any lock change re-dispatches all 4 — correctness preserved, granularity simply has nothing to split.

**Typical savings:** app-dep edit ≈ 25% (3 of 4 dispatched). Asset-layer dep edit ≈ 50% (2 of 4). Single lib-pattern edit ≈ 75% (1 of 4). Framework pack rewrite or initial scan ≈ 0% (all 4 dispatched).

### Legacy v1.0 `cache_key:` block (deprecated — backward-compat read)

Oldest starterkit-context.yaml files have a `cache_key:` block in place of `cache_signatures:`. Producers treat any prior v1.0 file as fully-stale on read (forces all 4 subagent re-dispatches) and write the current `cache_signatures:` schema. One-time migration cost per project; zero breaking change. (v2.0 php/js-only signature files self-heal the same way — changed signature inputs mismatch once, then v2.1 is written.)

---

## Partial output protocol

When a subagent fails twice (after auto-retry), the consolidator MAY emit a partial starterkit-context.yaml:

```yaml
starterkit_context:
  schema_version: 3.1              # current writers emit 3.1 (matches the top-level structure)
  partial: true                    # present only when partial
  partial_slices: [authz]          # which slices are missing
  # auth, ui_ux, libs blocks present as normal
  # authz block ABSENT
```

Downstream consumers MUST handle `partial: true` gracefully: if a slice they need is missing, skip starterkit-derived Anchors/Rules for that domain; degrade to framework-pack-only behavior.

---

## Anti-halu rails

1. **No-fabrication rail**: every `lib:` field MAY be `not_detected`. Subagents MUST mark absence rather than guess presence.
2. **Citation rail**: every block MUST include `_source: [<file>, ...]` companion field listing files used to derive it.
3. **Schema validation**: consolidator validates output against this schema before writing; malformed slices are dropped (with `partial_slices:` updated) rather than written.

---

## See also

- `plugins/mega-sdd/skills/scan-codebase/SKILL.md` §Step 2 deep-scan stage (producer)
- `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` (subagent prompts)
- `plugins/mega-sdd/references/lib-patterns/laravel/*.md` (per-lib detection patterns)
- `plugins/mega-sdd/skills/generate-units/SKILL.md` §Step 4.7 (consumer — Anchors + Rules)
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` §Step 1.5.f-h (consumer — T2 slice injection)
