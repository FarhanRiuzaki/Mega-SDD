# Starterkit Context Schema

> Canonical schema for `.mega-sdd/codebase/starterkit-context.yaml` — single source of truth for all mega-sdd consumers.

**Version:** 1.0
**Introduced:** v3.23.0 (Iter 32)
**Produced by:** `mega-sdd:scan-codebase` v2.6.0+ Step 2 deep-scan stage
**Consumed by:** `mega-sdd:generate-units` v2.6.0+ (Step 4.7), `mega-sdd:execute-bolts` v2.7.0+ (Step 1.5.f-h), `mega-sdd:orchestrate-flow` (handoff metadata propagation)

---

## Top-level structure

```yaml
starterkit_context:
  schema_version: 1.0
  generated_by: scan-codebase v2.6.0
  generated_at: <ISO8601 timestamp>
  framework: laravel               # from codebase-map.md §7 Framework.name
  framework_version: "12.x"        # from codebase-map.md §7 Framework.version
  framework_pack: laravel-base-26  # from codebase-map.md §7 Framework.pack_path basename

  auth: { ... }
  rbac: { ... }
  ui_ux: { ... }
  libs: [ ... ]

  cache_key:
    composer_lock_sha256: <hex>    # sha256 of composer.lock, or "" if absent
    package_lock_sha256: <hex>     # sha256 of package-lock.json | yarn.lock | pnpm-lock.yaml, or "" if absent
```

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

## §cache_key block

```yaml
cache_key:
  composer_lock_sha256: "abc123..."   # sha256 of composer.lock at scan time
  package_lock_sha256: "def456..."    # sha256 of package-lock.json (or yarn.lock or pnpm-lock.yaml)
```

**Cache reuse rule:** on re-scan, if both `composer_lock_sha256` AND `package_lock_sha256` match current file hashes → reuse existing starterkit-context.yaml; skip subagent dispatch.

**Cache invalidation:** any mismatch → full re-scan (all 4 subagents re-dispatched). Also invalidated when `framework_pack` changes (different starterkit detected).

---

## Partial output protocol

When a subagent fails twice (after auto-retry), the consolidator MAY emit a partial starterkit-context.yaml:

```yaml
starterkit_context:
  schema_version: 1.0
  partial: true                    # NEW field — present only when partial
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
