# Starterkit Context Schema

> Canonical schema for `.mega-sdd/codebase/starterkit-context.yaml` — single source of truth for all mega-sdd consumers.

**Version:** 3.0 (Iter 68) — supersedes 2.0 (Iter 42), 1.0 (Iter 32)
**Introduced:** v3.23.0 (Iter 32); cache schema bumped v3.28.0 (Iter 42); patterns: block added v3.59.0+ (Iter 68)
**Produced by:** `mega-sdd:scan-codebase` v3.0.0+ Step 10.5 deep-scan stage + Step 10.5.2.5 pattern extraction
**Consumed by:** `mega-sdd:generate-units` v2.6.0+ (Step 4.7), `mega-sdd:execute-bolts` v2.7.0+ (Step 1.5.f-h), `mega-sdd:orchestrate-flow` (handoff metadata propagation), `validate-starterkit-conformance.sh` (v3.0 patterns: block consumer)
**Backward compat:** v1.0 readers (Iter 32 era) skip the `cache_signatures:` block. v2.0 readers skip the `patterns:` block (Iter 42 era — pre-v3.0). v3.0+ writers MUST emit `patterns:`. Consumers MAY read v1.0/v2.0/v3.0; producers MUST emit v3.0.

---

## Top-level structure

```yaml
starterkit_context:
  schema_version: 3.0                    # v3.0 bump (Iter 68 — adds patterns:); v2.0 was Iter 42; v1.0 was Iter 32
  generated_by: scan-codebase v3.0.0
  generated_at: <ISO8601 timestamp>      # MOST RECENT slice write time
  framework: laravel                     # from codebase-map.md §7 Framework.name
  framework_version: "12.x"              # from codebase-map.md §7 Framework.version
  framework_pack: laravel-base-26        # from codebase-map.md §7 Framework.pack_path basename

  partial: true                          # OPTIONAL — only when ≥1 slice failed
  partial_slices: [rbac]                 # OPTIONAL — present when partial: true
  reused_slices: [auth, ui_ux]           # v2.0+ — per-slice cache provenance (which slices reused vs freshly-dispatched)

  auth: { ... }                          # fresh OR cached slice content
  rbac: { ... }                          # fresh OR cached
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

  cache_signatures:                      # v2.0 schema (replaces v1.0 cache_key:)
    composer_lock_sha256: <hex>          # retained for reproducibility
    package_lock_sha256: <hex>           # retained for reproducibility
    framework_pack: <pack-name>          # retained
    per_slice:
      auth:   { signature_sha256: <hex>, generated_at: <ISO8601> }
      rbac:   { signature_sha256: <hex>, generated_at: <ISO8601> }
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

## §auth block

```yaml
auth:
  lib: sanctum                     # enum: sanctum | breeze | jetstream | fortify | passport | not_detected
  lib_version: "4.0"               # version string or "" if not_detected
  guard: sanctum                   # default guard name from config/auth.php
  user_model: "App\\Models\\User"  # FQCN of User model
  routes:
    login: "/login"                # or "" if route absent
    register: "/register"
    logout: "/logout"
    password_reset: "/forgot-password"
  features: [email_verification, 2fa, social_login]  # array; subset of recognized features
  _source: ["composer.json:34", "config/auth.php:42"]  # files used to derive this slice (anti-halu citation)
```

## §rbac block

```yaml
rbac:
  lib: spatie/permission           # enum: spatie/permission | laravel-permission | custom | not_detected
  role_model: "Spatie\\Permission\\Models\\Role"
  permission_model: "Spatie\\Permission\\Models\\Permission"
  middleware: [role, permission, role_or_permission]  # array of middleware aliases
  gates: [view-admin]              # array of Gate definitions found in AuthServiceProvider
  policies: ["App\\Policies\\UserPolicy"]  # array of policy class FQCNs
  default_roles: [admin, user]     # array; from RoleSeeder if present
  _source: ["composer.json:42", "database/seeders/RoleSeeder.php"]
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

## §cache_signatures block (v2.0+, Iter 42)

```yaml
cache_signatures:
  composer_lock_sha256: "abc123..."     # retained for reproducibility
  package_lock_sha256: "def456..."      # retained for reproducibility
  framework_pack: "laravel-base-26"     # retained
  per_slice:
    auth:
      signature_sha256: <hex>           # sha256(composer.lock + framework_pack §auth + auth-libs.md)
      generated_at: "2026-05-25T10:00:00Z"
    rbac:
      signature_sha256: <hex>           # sha256(composer.lock + framework_pack §rbac + rbac-libs.md)
      generated_at: "2026-05-25T10:00:00Z"
    ui_ux:
      signature_sha256: <hex>           # sha256(package.lock + framework_pack §ui + ui-libs.md)
      generated_at: "2026-05-25T10:00:00Z"
    libs:
      signature_sha256: <hex>           # sha256(composer.lock + package.lock + framework_pack §libs + generic-libs.md)
      generated_at: "2026-05-25T10:00:00Z"
```

**Cache reuse rule (v2.0+, per-slice):** on re-scan, scan-codebase computes the current signature for each of 4 slices independently. For each slice:
- IF prior.per_slice[<slice>].signature_sha256 == current_<slice>_signature → slice reused (no subagent dispatch for that slice)
- ELSE → that slice's subagent re-dispatched; consolidator merges fresh slice with other cached slices

**Cache invalidation matrix (v2.0+):**

| Input changed | Slices invalidated | Subagent dispatches needed |
|---|---|---|
| composer.lock only | auth, rbac, libs (3/4) | 3 |
| package.lock only | ui_ux, libs (2/4) | 2 |
| Both lockfiles | auth, rbac, ui_ux, libs (4/4) | 4 (worst case) |
| framework_pack §auth section | auth (1/4) | 1 |
| framework_pack §rbac section | rbac (1/4) | 1 |
| framework_pack §ui section | ui_ux (1/4) | 1 |
| framework_pack §libs section | libs (1/4) | 1 |
| lib-patterns/<fw>/auth-libs.md | auth (1/4) | 1 (best case — 75% saving) |

**Typical savings:** PHP dep edit ≈ 25% (3 of 4 dispatched). JS dep edit ≈ 50% (2 of 4). Single lib-pattern edit ≈ 75% (1 of 4). Framework pack rewrite or initial scan ≈ 0% (all 4 dispatched).

### Legacy v1.0 `cache_key:` block (deprecated — backward-compat read)

v1.0 starterkit-context.yaml files (Iter 32 baseline) have a `cache_key:` block in place of `cache_signatures:`. Producers (v2.7.0+ scan-codebase) treat any prior v1.0 file as fully-stale on read (forces all 4 subagent re-dispatches) and write the new v2.0 `cache_signatures:` block. One-time migration cost per project; zero breaking change.

---

## Partial output protocol

When a subagent fails twice (after auto-retry), the consolidator MAY emit a partial starterkit-context.yaml:

```yaml
starterkit_context:
  schema_version: 2.0              # v2.7.0+ writers always emit 2.0
  partial: true                    # NEW field (Iter 32) — present only when partial
  partial_slices: [rbac]           # which slices are missing
  # auth, ui_ux, libs blocks present as normal
  # rbac block ABSENT
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
