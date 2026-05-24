# Laravel — RBAC Libraries Detection Patterns

> Catalog consumed by `rbac-extractor` subagent in `scan-codebase` v2.6.0+ deep-scan.

**Output target:** `starterkit-context.yaml §rbac` block

## Coverage

3 Laravel RBAC libs + `not_detected` fallback:
- Spatie Permission (`spatie/laravel-permission`)
- `laravel-permission` (legacy alternative)
- Custom (Gate + Policy based, no third-party lib)

---

## Spatie Permission

**Manifest fingerprint:**
```json
"spatie/laravel-permission": "^6.0"
```

**File fingerprints:**
- `config/permission.php` exists
- `app/Models/User.php` uses `Spatie\Permission\Traits\HasRoles` trait
- Migration `*_create_permission_tables.php` published to `database/migrations/`
- `app/Http/Kernel.php` route middleware aliases include `role` / `permission` / `role_or_permission`

**Default models:**
- role_model: `Spatie\Permission\Models\Role`
- permission_model: `Spatie\Permission\Models\Permission`

**Default roles** (from `database/seeders/RoleSeeder.php` or `database/seeders/DatabaseSeeder.php` if present):
- Parse calls like `Role::create(['name' => 'admin'])` to populate `default_roles` array

**Sample output YAML slice:**
```yaml
rbac:
  lib: spatie/permission
  role_model: "Spatie\\Permission\\Models\\Role"
  permission_model: "Spatie\\Permission\\Models\\Permission"
  middleware: [role, permission, role_or_permission]
  gates: []                          # populate from AuthServiceProvider Gate::define calls
  policies: []                       # populate from AuthServiceProvider $policies array
  default_roles: [admin, user]
  _source: ["composer.json:<line>", "config/permission.php", "app/Models/User.php:<line>", "app/Http/Kernel.php:<line>"]
```

---

## laravel-permission (legacy alternative)

**Manifest fingerprint:**
```json
"jeremykenedy/laravel-roles": "^5.0"   # or similar; less common
```

**File fingerprints:** custom; use generic Gate/Policy + role model inference.

**Sample output YAML slice:** similar to Spatie but with appropriate FQCNs.

---

## Custom (Gate + Policy only)

**Manifest fingerprint:** none (no third-party RBAC lib in composer.json)

**File fingerprints (must ALL be present to qualify as "custom RBAC" not "no RBAC"):**
- `app/Providers/AuthServiceProvider.php` defines ≥1 `Gate::define(...)` call OR `$policies` array has ≥1 entry
- `app/Policies/*.php` directory exists with ≥1 policy class
- OR `app/Models/User.php` defines custom `hasRole()` / `hasPermission()` method

**Default models:** typically `App\Models\Role` + `App\Models\Permission` if user-defined; otherwise empty.

**Sample output YAML slice:**
```yaml
rbac:
  lib: custom
  role_model: "App\\Models\\Role"    # or "" if not present
  permission_model: "App\\Models\\Permission"  # or ""
  middleware: []                      # custom middleware names if app/Http/Middleware has role-checking middleware
  gates: [view-admin, edit-posts]    # parsed from Gate::define calls
  policies: ["App\\Policies\\UserPolicy", "App\\Policies\\PostPolicy"]
  default_roles: []                  # from seeders if present
  _source: ["app/Providers/AuthServiceProvider.php:<line>", "app/Policies/"]
```

---

## not_detected fallback

When neither a third-party lib NOR custom Gate/Policy setup is found:

```yaml
rbac:
  lib: not_detected
  role_model: ""
  permission_model: ""
  middleware: []
  gates: []
  policies: []
  default_roles: []
  _source: ["composer.json", "app/Providers/AuthServiceProvider.php"]  # cite the absence
```

## Detection precedence

1. **Spatie Permission** (most common; if present, dominates)
2. **laravel-permission / other third-party** (rare; check composer.json for known alternates)
3. **Custom** (only if Gate::define OR $policies array OR custom role methods exist)
4. **not_detected**

## Anti-halu

If `lib: not_detected`, DO NOT populate `role_model` / `permission_model` with guesses. Empty strings are correct. Downstream generate-units will skip RBAC-related Anchors/Rules for this project.
