# Iter 32 Starterkit-Aware Deep Scan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make mega-sdd automatically capture each starterkit's actual auth/RBAC/UI-UX/library patterns into `.mega-sdd/codebase/starterkit-context.yaml`, then propagate that context through generate-units (Anchors + Hard Rules with citations) and execute-bolts (T2 dispatch-prompt slice injection) so generated code matches the user's starterkit by default — no flags, no user trigger.

**Architecture:** `scan-codebase` v2.6.0 gains a Step 2 deep-scan stage that dispatches 4 parallel `sonnet` subagents (auth, rbac, ui-ux, libs) when framework confidence ≥ MEDIUM. Subagents read manifests + actual code, return structured YAML slices, consolidator writes `starterkit-context.yaml`. Cache via lock-file sha256 → re-scan with unchanged deps is 0sec. Consumers `generate-units` v2.6.0 + `execute-bolts` v2.7.0 ship in-iter (no producer-only debt). 4 new halt types synchronized across 4 surfaces (SKILL.md + vault-contract.md type enum + orchestrate-flow taxonomy + handoff-contract.md per-skill examples) per iter-31 audit lessons.

**Tech Stack:** Markdown-driven plugin (no runtime code). Plugin SKILL.md files describe procedure for AI subagents. YAML for structured context. Bash for verification. Plugin v3.22.0 → v3.23.0.

**Spec source:** `docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md`

---

## File Structure

### New plugin files (7)

| Path | Responsibility |
|---|---|
| `plugins/mega-sdd/references/starterkit-context-schema.md` | Canonical YAML schema for `starterkit-context.yaml` — single source of truth for all consumers |
| `plugins/mega-sdd/references/lib-patterns/README.md` | Index of lib-pattern catalogs + extension protocol for new frameworks |
| `plugins/mega-sdd/references/lib-patterns/laravel/auth-libs.md` | Detection patterns for Sanctum / Breeze / Jetstream / Fortify / Passport |
| `plugins/mega-sdd/references/lib-patterns/laravel/rbac-libs.md` | Detection patterns for Spatie/permission / laravel-permission / custom RBAC |
| `plugins/mega-sdd/references/lib-patterns/laravel/ui-libs.md` | Detection patterns for JS framework / CSS framework / notification / icon / datatable libs |
| `plugins/mega-sdd/references/lib-patterns/laravel/generic-libs.md` | Catalog for queue / cache / log / test / misc libs |
| `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` | 4 subagent prompt templates (auth-extractor, rbac-extractor, ui-ux-extractor, libs-extractor) |

### New test files (1)

| Path | Responsibility |
|---|---|
| `tests/scenarios/scenario-8-starterkit-aware-generation.md` | Full-pipeline integration scenario from Laravel starterkit + PRD to bolt completion |

### Modified plugin files (8)

| Path | Change summary | Version |
|---|---|---|
| `plugins/mega-sdd/skills/scan-codebase/SKILL.md` | + Step 2 deep-scan stage; + Step 3 consolidator; + 3 new halt YAML envelopes; + handoff `starterkit_context:` block | 2.5.0 → 2.6.0 |
| `plugins/mega-sdd/skills/generate-units/SKILL.md` | + Step 4.7 starterkit Anchors/Hard Rules derivation; + Step 12.5 starterkit citation check; + handoff metrics fields | 2.5.4 → 2.6.0 |
| `plugins/mega-sdd/skills/execute-bolts/SKILL.md` | + Step 1.5.f-h starterkit slice injection logic; + T2 budget note | 2.6.0 → 2.7.0 |
| `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` | + T2 "Starterkit context (relevant slice)" section template | — |
| `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` | + 4 halt types in taxonomy (3 soft + 1 always-stop from scan-codebase, 1 always-stop from generate-units) | 2.5.0 → 2.5.1 |
| `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` | + `starterkit_context:` schema field defined once; + per-skill examples updated (scan-codebase, generate-units, execute-bolts) | — |
| `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` | + 4 new halt types to `§halt-protocol type enum` | — |
| `plugins/mega-sdd/references/paths.md` | + row for `.mega-sdd/codebase/starterkit-context.yaml` | — |

### Modified test/manifest files (5)

| Path | Change summary |
|---|---|
| `tests/skill-triggering/scan-codebase.test.md` | + 6 new cases SC-DS1..SC-DS6 |
| `tests/skill-triggering/generate-units.test.md` | + 3 new cases GU-SK1..GU-SK3 |
| `tests/skill-triggering/execute-bolts.test.md` | + 2 new cases EB-SK1..EB-SK2 |
| `tests/skill-triggering/orchestrate-flow.test.md` | + 1 new case OF-SK1 |
| `plugins/mega-sdd/.claude-plugin/plugin.json` | version 3.22.0 → 3.23.0 |
| `CHANGELOG.md` | + full `[3.23.0] - 2026-05-24` entry |
| `plugins/mega-sdd/README.md` | + "What's new in v3.23.0" section |

---

## Task ordering rationale

Tasks are ordered by dependency:
1. **Task 1 — Schema doc**: foundation that everyone references
2. **Task 2 — Lib-pattern files**: independent detection references; subagent prompts (Task 3) cite these
3. **Task 3 — Subagent prompts**: depend on schema + lib-patterns
4. **Task 4 — Cross-surface halt sync**: vault-contract + handoff-contract + paths + orchestrate-flow — must exist BEFORE skill bodies cite them (audit-31 lesson: never declare halts in skill body without registering across all 4 surfaces)
5. **Task 5 — scan-codebase (producer)**: depends on schema + prompts + halt registry
6. **Task 6 — generate-units (consumer 1)**: depends on schema; ships in-iter
7. **Task 7 — execute-bolts (consumer 2)**: depends on schema; ships in-iter
8. **Task 8 — Trigger tests**: covers all 12 new cases across 4 skill test files
9. **Task 9 — Scenario test**: full-pipeline integration scenario
10. **Task 10 — Version bumps + CHANGELOG + README + push**: ship v3.23.0

---

## Task 1: Canonical schema doc (foundation)

**Files:**
- Create: `plugins/mega-sdd/references/starterkit-context-schema.md`

- [ ] **Step 1.1: Write canonical schema doc**

Write the full canonical schema definition to `plugins/mega-sdd/references/starterkit-context-schema.md`:

```markdown
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
```

- [ ] **Step 1.2: Verify file written + readable**

Run:
```bash
test -f plugins/mega-sdd/references/starterkit-context-schema.md && wc -l plugins/mega-sdd/references/starterkit-context-schema.md
```
Expected: line count ≥ 100 (file is substantial canonical doc).

- [ ] **Step 1.3: Commit**

```bash
git add plugins/mega-sdd/references/starterkit-context-schema.md
git commit -m "$(cat <<'EOF'
docs(iter-32): canonical starterkit-context.yaml schema (foundation)

Single source of truth for the starterkit-context.yaml emitted by
scan-codebase v2.6.0+ deep-scan stage. Defines auth/rbac/ui_ux/libs
blocks, cache_key for lock-file hash reuse, partial-output protocol
for subagent failures, and anti-halu rails (no-fabrication, citation
required, schema validation).

Consumers (generate-units Step 4.7, execute-bolts Step 1.5.f-h) will
read this schema in subsequent tasks.
EOF
)"
```

---

## Task 2: Lib-pattern reference files (4 laravel files + README)

**Files:**
- Create: `plugins/mega-sdd/references/lib-patterns/README.md`
- Create: `plugins/mega-sdd/references/lib-patterns/laravel/auth-libs.md`
- Create: `plugins/mega-sdd/references/lib-patterns/laravel/rbac-libs.md`
- Create: `plugins/mega-sdd/references/lib-patterns/laravel/ui-libs.md`
- Create: `plugins/mega-sdd/references/lib-patterns/laravel/generic-libs.md`

- [ ] **Step 2.1: Create lib-patterns/README.md (index + extension protocol)**

Write to `plugins/mega-sdd/references/lib-patterns/README.md`:

```markdown
# Lib-Pattern Detection Catalogs

> Per-framework reference catalogs of library detection patterns used by `scan-codebase` v2.6.0+ deep-scan subagents.

**Introduced:** v3.23.0 (Iter 32)
**Consumed by:** subagent prompts in `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md`

## Directory layout

```
plugins/mega-sdd/references/lib-patterns/
  README.md                  # this file
  laravel/
    auth-libs.md             # Sanctum / Breeze / Jetstream / Fortify / Passport
    rbac-libs.md             # Spatie/permission / laravel-permission / custom
    ui-libs.md               # JS / CSS / notification / icon / datatable
    generic-libs.md          # queue / cache / log / test / misc
```

## Adding a new framework

To add a new framework (e.g., `nextjs/`, `django/`, `rails/`):

1. Create directory `lib-patterns/<framework>/`
2. Add the 4 standard catalog files: `auth-libs.md`, `rbac-libs.md`, `ui-libs.md`, `generic-libs.md`
3. Each file follows the canonical "Detection Examples" structure:
   - **Manifest fingerprint**: which key in package manifest signals this lib
   - **File fingerprint**: where in the codebase the lib's usage appears
   - **Sample output YAML slice**: what the extractor should emit
4. Update `scan-codebase/SKILL.md` framework-pack detection to recognize the new framework
5. No skill code changes needed — subagent prompts auto-load `lib-patterns/<detected-framework>/` based on `codebase-map.md §7 Framework.name`

## Fallback behavior

When `scan-codebase` detects a framework but no matching `lib-patterns/<framework>/` directory exists:
- Subagents proceed using `_universal.md` patterns from `framework-conventions/`
- Detection becomes manifest-only (less precise)
- Log line emitted: `no lib-pattern pack for <framework>; using generic extraction`
- No halt (graceful degradation per Iter 32 design)

## Anti-halu

Pattern files describe what to LOOK FOR; subagents MUST NOT invent libs that match no fingerprint. Absence is marked `lib: not_detected`. Every detection MUST cite the file(s) used (`_source:` array per starterkit-context-schema.md).
```

- [ ] **Step 2.2: Create lib-patterns/laravel/auth-libs.md**

Write to `plugins/mega-sdd/references/lib-patterns/laravel/auth-libs.md`:

```markdown
# Laravel — Auth Libraries Detection Patterns

> Catalog consumed by `auth-extractor` subagent in `scan-codebase` v2.6.0+ deep-scan.

**Output target:** `starterkit-context.yaml §auth` block (see `references/starterkit-context-schema.md`)

## Coverage

5 Laravel auth libs + `not_detected` fallback:
- Sanctum (API tokens + SPA cookie auth)
- Breeze (lightweight starter)
- Jetstream (Livewire/Inertia-powered starter)
- Fortify (headless auth backend)
- Passport (full OAuth2 server)

---

## Sanctum

**Manifest fingerprint** (`composer.json` `require`):
```json
"laravel/sanctum": "^3.0" OR "^4.0"
```

**File fingerprints:**
- `app/Http/Kernel.php` contains `\Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful`
- `config/sanctum.php` exists
- `routes/api.php` typically has `middleware('auth:sanctum')` groups

**Routes typical:** API-first; web auth absent unless paired with Breeze/Jetstream.

**Sample output YAML slice:**
```yaml
auth:
  lib: sanctum
  lib_version: "4.0"
  guard: sanctum
  user_model: "App\\Models\\User"  # read from config/auth.php providers.users.model
  routes:
    login: "/login"               # only if web routes also present
    register: ""
    logout: "/logout"
    password_reset: ""
  features: []                    # 2fa/social_login only if paired with Fortify/Socialite
  _source: ["composer.json:<line>", "config/sanctum.php", "app/Http/Kernel.php:<line>"]
```

---

## Breeze

**Manifest fingerprint:**
```json
"laravel/breeze": "^2.0"  # dev-time only; check require-dev too
```

**File fingerprints:**
- `routes/auth.php` exists with `Route::middleware('guest')->group(...)` blocks for login/register
- `app/Http/Controllers/Auth/AuthenticatedSessionController.php` exists
- `resources/views/auth/login.blade.php` exists (Blade flavor) OR `resources/js/Pages/Auth/Login.vue|.jsx` (Inertia flavor)

**Routes typical:** `/login`, `/register`, `/logout`, `/forgot-password`, `/reset-password`, `/verify-email`

**Features detection:**
- email_verification: `app/Http/Middleware/EnsureEmailIsVerified.php` exists OR `routes/auth.php` has `verified` middleware
- 2fa: NOT default (use Fortify or Jetstream)
- social_login: NOT default (Breeze adds password auth only)

**Sample output YAML slice:**
```yaml
auth:
  lib: breeze
  lib_version: "2.0"
  guard: web
  user_model: "App\\Models\\User"
  routes:
    login: "/login"
    register: "/register"
    logout: "/logout"
    password_reset: "/forgot-password"
  features: [email_verification]
  _source: ["composer.json:<line>", "routes/auth.php", "app/Http/Controllers/Auth/AuthenticatedSessionController.php"]
```

---

## Jetstream

**Manifest fingerprint:**
```json
"laravel/jetstream": "^5.0"
```

**File fingerprints:**
- `config/jetstream.php` exists
- `app/Actions/Jetstream/` directory exists (Teams actions if teams enabled)
- `resources/views/api/api-token-manager.blade.php` exists (Livewire stack) OR `resources/js/Pages/API/Index.vue` (Inertia stack)

**Features detection (from config/jetstream.php `features` array):**
- `Features::accountDeletion()` → features array includes `account_deletion`
- `Features::api()` → features includes `api_tokens`
- `Features::teams()` → features includes `teams`
- `Features::profilePhotos()` → features includes `profile_photos`

**Sample output YAML slice:**
```yaml
auth:
  lib: jetstream
  lib_version: "5.0"
  guard: web
  user_model: "App\\Models\\User"
  routes:
    login: "/login"
    register: "/register"
    logout: "/logout"
    password_reset: "/forgot-password"
  features: [email_verification, 2fa, api_tokens, teams]
  _source: ["composer.json:<line>", "config/jetstream.php"]
```

---

## Fortify

**Manifest fingerprint:**
```json
"laravel/fortify": "^1.0"
```

**File fingerprints:**
- `config/fortify.php` exists
- `app/Actions/Fortify/` directory exists (CreateNewUser, UpdateUserProfileInformation, etc.)
- `app/Providers/FortifyServiceProvider.php` exists

**Features detection (from config/fortify.php `features` array):**
- `Features::twoFactorAuthentication()` → `2fa`
- `Features::emailVerification()` → `email_verification`
- `Features::updatePasswords()`, `Features::resetPasswords()`, `Features::registration()` → standard auth features

**Sample output YAML slice:**
```yaml
auth:
  lib: fortify
  lib_version: "1.0"
  guard: web
  user_model: "App\\Models\\User"
  routes:
    login: "/login"               # Fortify registers these by default
    register: "/register"
    logout: "/logout"
    password_reset: "/forgot-password"
  features: [email_verification, 2fa]
  _source: ["composer.json:<line>", "config/fortify.php", "app/Providers/FortifyServiceProvider.php"]
```

---

## Passport

**Manifest fingerprint:**
```json
"laravel/passport": "^12.0"
```

**File fingerprints:**
- `config/passport.php` exists
- `app/Models/User.php` uses `Laravel\Passport\HasApiTokens` trait
- `app/Providers/AuthServiceProvider.php` calls `Passport::routes()` or registers Passport scopes

**Sample output YAML slice:**
```yaml
auth:
  lib: passport
  lib_version: "12.0"
  guard: api
  user_model: "App\\Models\\User"
  routes:
    login: "/oauth/token"
    register: ""
    logout: "/oauth/tokens"
    password_reset: ""
  features: [oauth2]
  _source: ["composer.json:<line>", "config/passport.php", "app/Models/User.php:<line>"]
```

---

## not_detected fallback

When NONE of the above match:

```yaml
auth:
  lib: not_detected
  lib_version: ""
  guard: ""                       # may still read default from config/auth.php if exists
  user_model: ""                  # may still read from config/auth.php
  routes: { login: "", register: "", logout: "", password_reset: "" }
  features: []
  _source: ["composer.json"]      # cite the absence
```

Anti-halu: NEVER guess. If no fingerprint matched, emit `not_detected`. Downstream consumers degrade gracefully.

## Detection precedence

Multiple libs may coexist (e.g., Sanctum + Breeze). Detection order matters for the `lib:` enum value:

1. **Jetstream** (most opinionated; if present, dominates)
2. **Breeze** (web-flavored, simpler than Jetstream)
3. **Fortify** (headless; present standalone OR under Jetstream)
4. **Passport** (OAuth2; may coexist with Sanctum for hybrid API auth)
5. **Sanctum** (token/SPA auth)
6. `not_detected` (none of the above)

If multiple match, emit the highest-precedence as `lib:`; list others in `libs:` (Task 3 libs-extractor handles that).
```

- [ ] **Step 2.3: Create lib-patterns/laravel/rbac-libs.md**

Write to `plugins/mega-sdd/references/lib-patterns/laravel/rbac-libs.md`:

```markdown
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
```

- [ ] **Step 2.4: Create lib-patterns/laravel/ui-libs.md**

Write to `plugins/mega-sdd/references/lib-patterns/laravel/ui-libs.md`:

```markdown
# Laravel — UI/UX Libraries Detection Patterns

> Catalog consumed by `ui-ux-extractor` subagent in `scan-codebase` v2.6.0+ deep-scan.

**Output target:** `starterkit-context.yaml §ui_ux` block

## Coverage: 5 categories

1. JS framework: Alpine / Livewire / Inertia / Vue / React / none
2. CSS framework: Tailwind / Bootstrap / Bulma / custom / none
3. Notification lib: SweetAlert2 / Toastr / native / not_detected
4. Icon lib: Heroicons / FontAwesome / not_detected
5. DataTable lib: yajra/laravel-datatables / not_detected

---

## JS framework detection

### Alpine

**Manifest fingerprint** (`package.json` dependencies/devDependencies):
```json
"alpinejs": "^3.0"
```

**File fingerprints:**
- `resources/js/app.js` contains `import Alpine from 'alpinejs'` OR `Alpine.start()`
- Blade views use `x-data`, `x-show`, `x-on:` directives

### Livewire

**Manifest fingerprint:**
```json
"livewire/livewire": "^3.0"
```

**File fingerprints:**
- `app/Livewire/` directory exists (v3) OR `app/Http/Livewire/` (v2)
- Blade views use `<livewire:component-name />` syntax OR `@livewire('...')`

### Inertia

**Manifest fingerprint:**
```json
"inertiajs/inertia-laravel": "^1.0"   // composer.json
"@inertiajs/vue3": "..."              // package.json (Vue flavor)
"@inertiajs/react": "..."             // package.json (React flavor)
```

**File fingerprints:**
- `resources/js/Pages/` directory exists
- `app/Http/Middleware/HandleInertiaRequests.php` exists

### Vue (standalone)

**Manifest fingerprint:**
```json
"vue": "^3.0"
```

**File fingerprints:**
- `resources/js/app.js` imports `createApp` from `vue`
- `resources/js/components/*.vue` files exist

### React (standalone)

**Manifest fingerprint:**
```json
"react": "^18.0", "react-dom": "..."
```

**File fingerprints:**
- `resources/js/app.jsx` or `resources/js/app.tsx` exists

### none

If `resources/js/app.js` is empty/missing or only contains Bootstrap import without JS framework: `js_framework: none`.

---

## CSS framework detection

### Tailwind

**Manifest fingerprint:**
```json
"tailwindcss": "^3.0" OR "^4.0"
```

**File fingerprints:**
- `tailwind.config.js` exists
- `resources/css/app.css` has `@tailwind base; @tailwind components; @tailwind utilities;`

**Design tokens** — parse `tailwind.config.js`:
- `theme.extend.colors` → populate `design_tokens.colors` (subset: primary, secondary, accent, danger, success, warning)
- `theme.extend.spacing` → if customized, populate `design_tokens.spacing`; else `default`
- `theme.extend.fontFamily` → populate `design_tokens.fonts`

### Bootstrap

**Manifest fingerprint:**
```json
"bootstrap": "^5.0"
```

**File fingerprints:**
- `resources/sass/app.scss` imports `~bootstrap/scss/bootstrap`
- `resources/js/bootstrap.js` exists (Laravel convention)

### Bulma / custom / none

- Bulma: `bulma` in package.json → `css_framework: bulma`
- Custom: only `app.css` exists with no framework imports → `css_framework: custom`
- None: no CSS framework signals → `css_framework: none`

---

## Notification lib detection

### SweetAlert2

**Manifest fingerprint** (package.json):
```json
"sweetalert2": "^11.0"
```

**File fingerprints:**
- `resources/js/app.js` imports `Swal from 'sweetalert2'` OR `import 'sweetalert2/dist/sweetalert2.min.css'`
- Blade views use `Swal.fire(...)` OR `<x-sweetalert />` component
- Notification component at `resources/views/components/notification.blade.php` or similar

### Toastr

**Manifest fingerprint:**
```json
"toastr": "^2.0"
```

### native (Laravel session flash + Blade)

Detection: `@if(session('success'))` patterns in Blade layouts without third-party notification lib.

### not_detected

When no notification lib is found.

---

## Icon lib detection

### Heroicons

**Manifest fingerprint:**
```json
"@heroicons/vue": "..." OR "@heroicons/react": "..." OR
```
Composer:
```json
"blade-ui-kit/blade-heroicons": "^2.0"
```

### FontAwesome

**Manifest fingerprint:**
```json
"@fortawesome/fontawesome-free": "..."
```

### not_detected

When no icon lib is found.

---

## DataTable lib detection

### yajra/laravel-datatables

**Manifest fingerprint:**
```json
"yajra/laravel-datatables-oracle": "^11.0"
```

**File fingerprints:**
- `app/DataTables/*.php` files extending `Yajra\DataTables\Services\DataTable`
- Base class often `BaseDataTable` at `app/DataTables/BaseDataTable.php` (per laravel-base-26 pack)

### not_detected

When no DataTable lib is found.

---

## Layout file detection

Inspect `resources/views/layouts/`:
- If `app.blade.php` exists → `layout_extends: "layouts.app"`, `layout_file: "resources/views/layouts/app.blade.php"`
- If `master.blade.php` exists → `layout_extends: "layouts.master"`, `layout_file: "resources/views/layouts/master.blade.php"`
- If `main.blade.php` exists → `layout_extends: "layouts.main"`, `layout_file: "resources/views/layouts/main.blade.php"`
- If multiple → pick the one most-extended by views in `resources/views/` (grep for `@extends('layouts.X')` counts)
- If none → `layout_extends: ""`, `layout_file: ""`

## Component dir detection

- `resources/views/components/` (Blade Components convention) → `component_dir: "resources/views/components"`
- `resources/js/Components/` (Inertia convention) → `component_dir: "resources/js/Components"`
- Multiple may coexist; pick the dominant one (more files = dominant)

## Idioms inference

Parse `resources/js/app.js`, `resources/views/layouts/<layout>.blade.php` for recurring patterns:
- `document.addEventListener('DOMContentLoaded', ...)` usage → idiom: "use document.addEventListener('DOMContentLoaded', ...) over $(document).ready"
- Tailwind responsive prefixes (`sm:`, `md:`, `lg:`) used heavily → idiom: "responsive mobile-first (sm/md/lg breakpoints)"
- `$(document).ready(...)` usage → idiom: "uses jQuery ready (legacy pattern)"

Emit only idioms that have ≥3 occurrences in scanned files. No guessing.

---

## Sample full §ui_ux output

```yaml
ui_ux:
  js_framework: alpine
  css_framework: tailwind
  layout_extends: "layouts.app"
  layout_file: "resources/views/layouts/app.blade.php"
  component_dir: "resources/views/components"
  notification_lib: sweetalert2
  icon_lib: heroicons
  datatable_lib: yajra/laravel-datatables
  design_tokens:
    colors: { primary: "#3b82f6", secondary: "#64748b" }
    spacing: default
    fonts: ["Inter"]
  idioms:
    - "use document.addEventListener('DOMContentLoaded', ...) over $(document).ready"
    - "responsive mobile-first (sm/md/lg breakpoints)"
  _source: ["package.json:<line>", "tailwind.config.js", "resources/views/layouts/app.blade.php", "resources/js/app.js"]
```

## Anti-halu

- Idioms array MUST be empirically grounded (≥3 occurrences). Never guess "uses X pattern" without evidence.
- `not_detected` is a valid value for notification_lib, icon_lib, datatable_lib. Never invent.
- design_tokens only populated if `tailwind.config.js` has explicit `extend.colors` / `extend.spacing` / `extend.fontFamily` blocks; else use `default`.
```

- [ ] **Step 2.5: Create lib-patterns/laravel/generic-libs.md**

Write to `plugins/mega-sdd/references/lib-patterns/laravel/generic-libs.md`:

```markdown
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
```

- [ ] **Step 2.6: Verify all 5 lib-pattern files written**

Run:
```bash
ls plugins/mega-sdd/references/lib-patterns/ plugins/mega-sdd/references/lib-patterns/laravel/
for f in README.md laravel/auth-libs.md laravel/rbac-libs.md laravel/ui-libs.md laravel/generic-libs.md; do
  test -f plugins/mega-sdd/references/lib-patterns/$f && echo "$f OK ($(wc -l < plugins/mega-sdd/references/lib-patterns/$f) lines)" || echo "$f MISSING"
done
```
Expected: all 5 OK, each ≥50 lines.

- [ ] **Step 2.7: Commit**

```bash
git add plugins/mega-sdd/references/lib-patterns/
git commit -m "$(cat <<'EOF'
docs(iter-32): lib-pattern reference catalogs for Laravel deep-scan

Adds 4 detection catalogs consumed by scan-codebase v2.6.0+ deep-scan
subagents (auth-extractor, rbac-extractor, ui-ux-extractor, libs-extractor):

- auth-libs.md   : Sanctum, Breeze, Jetstream, Fortify, Passport (5 libs)
- rbac-libs.md   : Spatie/permission, laravel-permission, custom (3 patterns)
- ui-libs.md     : JS/CSS/notification/icon/datatable libs (5 categories)
- generic-libs.md: queue/cache/log/test/http/misc catalog

Each catalog defines: manifest fingerprint, file fingerprint, sample
output YAML slice. Anti-halu rails: not_detected is a valid value;
no guessing without evidence; usage_hint MUST cite actual files.

Framework-agnostic dir layout: lib-patterns/<framework>/. Future iters
add nextjs/, react/, django/ without modifying any skill body.
EOF
)"
```

---

## Task 3: Subagent prompt templates

**Files:**
- Create: `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md`

- [ ] **Step 3.1: Write 4 subagent prompt templates**

Write to `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md`:

```markdown
# Deep-Scan Subagent Prompts

> Prompt templates for the 4 parallel subagents dispatched by `scan-codebase` v2.6.0+ Step 2 deep-scan stage.

**Introduced:** v3.23.0 (Iter 32)
**Consumed by:** `scan-codebase/SKILL.md` Step 2.2 (subagent dispatch)
**Schema:** `references/starterkit-context-schema.md` (target output structure)
**Catalogs:** `references/lib-patterns/<framework>/*.md` (detection patterns)

## Common dispatch contract

All 4 subagents follow this contract:

- **Model:** `sonnet`
- **Tool surface:** Read, Glob, Grep, Bash (read-only)
- **Wall-clock budget:** ≤10 min (auto-retry once on timeout per Iter 32 §5.1)
- **Output format:** structured YAML matching the assigned slice in `starterkit-context-schema.md`
- **Anti-halu rail:** if a lib is not detected in manifests OR not found in code probes, emit `lib: not_detected` — NEVER guess
- **Citation rail:** every output field MUST be backed by `_source: [<file>, ...]` companion field

## Variable substitution

Each prompt template uses placeholders the dispatcher substitutes:
- `<FRAMEWORK>` → framework name from `codebase-map.md §7 Framework.name` (e.g., `laravel`)
- `<PROJECT_ROOT>` → absolute path to project root being scanned
- `<CATALOG_PATH>` → absolute path to `lib-patterns/<FRAMEWORK>/<domain>-libs.md`

---

## auth-extractor prompt

```
ROLE: Auth library + flow detector for a starterkit codebase.

PROJECT ROOT: <PROJECT_ROOT>
FRAMEWORK: <FRAMEWORK>
CATALOG: <CATALOG_PATH>   (auth-libs.md for this framework)

YOUR JOB:
Detect which auth library is in use, identify the default guard, user model,
typical auth routes, and feature flags (2fa, email verification, social login).

INPUTS TO READ:
1. <PROJECT_ROOT>/composer.json (PHP manifests) AND <PROJECT_ROOT>/package.json (JS manifests)
2. <PROJECT_ROOT>/config/auth.php (default guard + user provider)
3. <PROJECT_ROOT>/routes/auth.php (if exists; Breeze/Fortify convention)
4. <PROJECT_ROOT>/routes/web.php (auth route declarations if not in routes/auth.php)
5. <PROJECT_ROOT>/app/Http/Middleware/Authenticate.php (if exists)
6. <PROJECT_ROOT>/app/Providers/AuthServiceProvider.php
7. <PROJECT_ROOT>/config/fortify.php and config/jetstream.php (if these libs detected)
8. THE CATALOG: <CATALOG_PATH> — use as your detection cheat-sheet

DETECTION PROCEDURE:
1. Read the catalog file (<CATALOG_PATH>). Note the manifest fingerprints, file fingerprints, and detection precedence rules.
2. Read manifests; check which auth lib fingerprints match.
3. Apply detection precedence (Jetstream > Breeze > Fortify > Passport > Sanctum > not_detected).
4. For the matched lib, read the specific files cited in its file fingerprint section to confirm.
5. Read config/auth.php to extract default guard + user model class.
6. Detect features (2fa, email_verification, social_login) per catalog feature-detection rules.

OUTPUT:
Emit a single YAML block matching the §auth slice in
plugins/mega-sdd/references/starterkit-context-schema.md. Include the
_source array citing every file you read to derive the answer.

If no auth lib fingerprint matches, emit `lib: not_detected` with empty
fields. NEVER guess.

OUTPUT FORMAT (single YAML block in your final response, no prose preamble):

```yaml
auth:
  lib: <enum>
  lib_version: <string>
  guard: <string>
  user_model: <FQCN string>
  routes:
    login: <path or empty string>
    register: <path or empty string>
    logout: <path or empty string>
    password_reset: <path or empty string>
  features: [<list>]
  _source: [<list of file:line citations>]
```

CONSTRAINTS:
- READ-ONLY: no Edit, no Write, no Bash mutations
- Cap response at ~80 lines of YAML
- Bind every field to a citation in _source[]
- not_detected is a valid lib value
```

---

## rbac-extractor prompt

```
ROLE: RBAC library + pattern detector for a starterkit codebase.

PROJECT ROOT: <PROJECT_ROOT>
FRAMEWORK: <FRAMEWORK>
CATALOG: <CATALOG_PATH>   (rbac-libs.md for this framework)

YOUR JOB:
Detect which RBAC library is in use (Spatie/permission, laravel-permission,
or custom Gate/Policy setup), identify role/permission models, middleware
names, gates, policies, and default roles from seeders.

INPUTS TO READ:
1. <PROJECT_ROOT>/composer.json
2. <PROJECT_ROOT>/config/permission.php (if exists)
3. <PROJECT_ROOT>/app/Models/User.php (check traits used)
4. <PROJECT_ROOT>/app/Http/Middleware/ (list all files, identify role/permission middleware)
5. <PROJECT_ROOT>/app/Http/Kernel.php (route middleware aliases)
6. <PROJECT_ROOT>/app/Providers/AuthServiceProvider.php (Gate::define calls + $policies array)
7. <PROJECT_ROOT>/app/Policies/ (list .php files)
8. <PROJECT_ROOT>/database/seeders/RoleSeeder.php and DatabaseSeeder.php (parse Role::create calls)
9. THE CATALOG: <CATALOG_PATH>

DETECTION PROCEDURE:
1. Read catalog. Apply precedence: Spatie/permission > laravel-permission > custom > not_detected.
2. For matched lib, populate role_model and permission_model.
3. List middleware aliases from app/Http/Kernel.php $routeMiddleware that look RBAC-related (role, permission, role_or_permission, etc.).
4. Parse AuthServiceProvider.php for Gate::define('<name>', ...) → populate gates[].
5. Parse AuthServiceProvider.php $policies array → populate policies[].
6. Parse RoleSeeder for Role::create(['name' => '<role>']) calls → populate default_roles[].

OUTPUT FORMAT (single YAML block):

```yaml
rbac:
  lib: <enum>
  role_model: <FQCN or empty string>
  permission_model: <FQCN or empty string>
  middleware: [<list>]
  gates: [<list>]
  policies: [<list of FQCN strings>]
  default_roles: [<list>]
  _source: [<list of file:line citations>]
```

CONSTRAINTS:
- READ-ONLY
- Cap response at ~80 lines of YAML
- not_detected is valid if no RBAC lib AND no custom Gate/Policy setup
```

---

## ui-ux-extractor prompt

```
ROLE: UI/UX library + design pattern detector for a starterkit codebase.

PROJECT ROOT: <PROJECT_ROOT>
FRAMEWORK: <FRAMEWORK>
CATALOG: <CATALOG_PATH>   (ui-libs.md for this framework)

YOUR JOB:
Detect JS framework, CSS framework, notification lib, icon lib, datatable lib,
identify layout file + component dir, extract design tokens, infer empirically
grounded idioms from actual code patterns.

INPUTS TO READ:
1. <PROJECT_ROOT>/package.json (devDependencies + dependencies)
2. <PROJECT_ROOT>/tailwind.config.js (if exists — parse extend.colors, extend.spacing, extend.fontFamily)
3. <PROJECT_ROOT>/vite.config.js
4. <PROJECT_ROOT>/resources/views/layouts/ (list all .blade.php; pick dominant by @extends count)
5. <PROJECT_ROOT>/resources/views/components/ (list to confirm component_dir)
6. <PROJECT_ROOT>/resources/js/app.js (or app.ts / app.jsx — check for framework imports + notification lib imports)
7. <PROJECT_ROOT>/resources/css/app.css (Tailwind import check)
8. <PROJECT_ROOT>/resources/views/layouts/<dominant-layout>.blade.php (idiom analysis)
9. <PROJECT_ROOT>/resources/views/components/notification.blade.php (if exists — confirm SweetAlert/Toastr usage)
10. THE CATALOG: <CATALOG_PATH>

DETECTION PROCEDURE:
1. Read catalog. Apply per-category detection rules.
2. js_framework: check package.json for alpinejs / livewire / vue / react / inertia; pick highest-confidence match.
3. css_framework: check package.json for tailwindcss / bootstrap; if neither → check app.css for imports.
4. notification_lib: package.json for sweetalert2 / toastr; if neither → check Blade layouts for native session('success') pattern.
5. icon_lib: package.json for @heroicons/* or @fortawesome/* OR composer.json for blade-ui-kit/blade-heroicons.
6. datatable_lib: composer.json for yajra/laravel-datatables-oracle.
7. layout_extends + layout_file: pick most-referenced layout from grep -c '@extends('layouts.' resources/views/.
8. design_tokens: parse tailwind.config.js (if present) for theme.extend.colors|spacing|fontFamily.
9. idioms: grep resources/js/app.js + resources/views/layouts/<layout>.blade.php for:
   - `document.addEventListener('DOMContentLoaded'` (≥3 occurrences across project → add idiom)
   - `$(document).ready(` (≥3 occurrences → add "uses jQuery ready (legacy pattern)")
   - Tailwind responsive prefixes `sm:`/`md:`/`lg:` (≥10 occurrences → add "responsive mobile-first (sm/md/lg breakpoints)")

OUTPUT FORMAT (single YAML block):

```yaml
ui_ux:
  js_framework: <enum>
  css_framework: <enum>
  layout_extends: <string>
  layout_file: <relative path string>
  component_dir: <relative path string>
  notification_lib: <enum>
  icon_lib: <enum>
  datatable_lib: <string>
  design_tokens:
    colors: { <key>: <hex>, ... }
    spacing: <"default" or object>
    fonts: [<list>]
  idioms: [<list of strings>]
  _source: [<list of file citations>]
```

CONSTRAINTS:
- READ-ONLY
- Cap response at ~100 lines of YAML
- idioms array MUST have ≥3 occurrences evidence — never guess
- design_tokens only populated if tailwind.config.js has explicit extend block; else use defaults
```

---

## libs-extractor prompt

```
ROLE: Full library inventory builder for a starterkit codebase.

PROJECT ROOT: <PROJECT_ROOT>
FRAMEWORK: <FRAMEWORK>
CATALOG: <CATALOG_PATH>   (generic-libs.md for this framework)

YOUR JOB:
Build a complete inventory of packages from composer.json + package.json,
categorize each by purpose (auth/rbac/ui/queue/cache/log/test/http/misc),
and annotate with usage_hint citing files where the package is imported/used.

INPUTS TO READ:
1. <PROJECT_ROOT>/composer.json (all require + require-dev entries)
2. <PROJECT_ROOT>/package.json (all dependencies + devDependencies)
3. THE CATALOG: <CATALOG_PATH> (category mapping reference)
4. For each detected lib: grep -r '<lib-namespace>' app/ routes/ config/ database/ resources/ — capture top 3-5 file matches

DETECTION PROCEDURE:
1. List every entry from composer.json `require` and `require-dev`.
2. List every entry from package.json `dependencies` and `devDependencies`.
3. For each lib:
   a. Match against catalog categories. Use the catalog's "Common Laravel libs reference" tables.
   b. If not in catalog → assign category `misc`.
   c. usage_hint: grep for the lib's namespace (e.g., `Spatie\\Permission` for spatie/permission) across app/, routes/, config/, resources/. Capture top 3-5 matching files (relative paths).
   d. If grep returns 0 matches → usage_hint: [] (lib is unused dependency).

OUTPUT FORMAT (single YAML block):

```yaml
libs:
  - name: <string>
    version: <string>
    category: <enum>
    usage_hint: [<list of file paths>]
  # ... one entry per lib in manifests
```

CONSTRAINTS:
- READ-ONLY
- Cap response at ~200 lines of YAML
- Cap total libs entries at 60 (truncate by alphabetical order if more; flag in _meta)
- Every lib MUST originate from composer.json or package.json — never invent
- Empty usage_hint array is valid (suggests unused dep)
```

---

## Subagent dispatch pattern (for reference)

`scan-codebase` Step 2.2 dispatches all 4 subagents IN PARALLEL via a single message with 4 Agent tool calls (per `superpowers:subagent-driven-development` convention for parallel-safe work). Each Agent call uses the appropriate prompt template above with placeholder substitutions, model: sonnet.

Consolidator (Step 2.3) collects 4 YAML responses, validates each against `starterkit-context-schema.md`, drops malformed slices (with `partial_slices:` updated), merges into single `starterkit-context.yaml`, computes `cache_key.composer_lock_sha256` + `package_lock_sha256`, and writes the file atomically.

## Anti-halu rails (cross-cutting)

All 4 prompts include the same 3 rails verbatim:
1. **No-fabrication**: emit `not_detected` / empty arrays when detection fails
2. **Citation**: every output field tied to `_source: [<file>, ...]`
3. **READ-ONLY**: no Edit / Write / mutating Bash operations

Subagents that violate these rails (e.g., emit a lib without citation) cause the consolidator to drop their slice from the merged output. The dropped slice is logged + the affected domain marked in `partial_slices:`.
```

- [ ] **Step 3.2: Verify file written**

Run:
```bash
test -f plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md && wc -l plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md
```
Expected: ≥250 lines (4 substantial prompt templates).

- [ ] **Step 3.3: Commit**

```bash
git add plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md
git commit -m "$(cat <<'EOF'
docs(iter-32): 4 deep-scan subagent prompt templates

References: starterkit-context-schema.md (output target) + lib-patterns/
<framework>/*.md (detection catalogs).

4 subagents dispatched in parallel by scan-codebase v2.6.0+ Step 2.2:
- auth-extractor:   detects auth lib + guard + user model + routes + features
- rbac-extractor:   detects RBAC lib + role/permission models + middleware + gates + policies
- ui-ux-extractor:  detects JS/CSS framework + notification/icon/datatable libs + layout + design tokens + idioms
- libs-extractor:   full lib inventory with category + usage_hint per lib

All 4 prompts include cross-cutting anti-halu rails: no-fabrication
(not_detected valid), citation required (_source per field), read-only.
Model: sonnet (medium for fuzzy pattern recognition).
EOF
)"
```

---

## Task 4: Cross-surface halt sync (4 surfaces, all in one task to enforce sync)

This task addresses the iter-31 audit's recurring pattern: halts declared in skill body but missing from orchestrate-flow taxonomy / vault-contract type enum / handoff-contract per-skill examples. Iter 32 registers all 4 new halts across all 4 surfaces IN ONE COMMIT.

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (halt type enum)
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (halt taxonomy)
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` (schema field + per-skill examples scaffolding)
- Modify: `plugins/mega-sdd/references/paths.md` (new path row)

The 4 new halt types being registered:
1. `deep_scan_subagent_failed` — soft, emitted by scan-codebase
2. `deep_scan_cache_corrupt` — soft, emitted by scan-codebase
3. `deep_scan_subagent_all_failed` — ALWAYS STOP, emitted by scan-codebase
4. `starterkit_rule_citation_missing` — ALWAYS STOP, emitted by generate-units

- [ ] **Step 4.1: Read current vault-contract.md halt enum to locate exact line**

Run:
```bash
grep -n "type: oq_blocker\|cross_squad_interface_draft" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
```
Locate the exact line of the halt-protocol type enum to extend.

- [ ] **Step 4.2: Extend vault-contract.md type enum**

Use Edit tool to extend the enum line. Find the line containing the existing enum (something like `type: oq_blocker | diff_conflict | drift_framework_mismatch | bind_conflict | dep_missing | test_fail | cycle_detected | mode_migrate | cross_squad_dep_invalid | interface_ref_missing | cross_squad_ambiguous | cross_squad_interface_draft`) and append the 4 new types:

```
type: oq_blocker | diff_conflict | drift_framework_mismatch | bind_conflict | dep_missing | test_fail | cycle_detected | mode_migrate | cross_squad_dep_invalid | interface_ref_missing | cross_squad_ambiguous | cross_squad_interface_draft | deep_scan_subagent_failed | deep_scan_cache_corrupt | deep_scan_subagent_all_failed | starterkit_rule_citation_missing
```

- [ ] **Step 4.3: Add halt-type descriptions to vault-contract.md**

Below the type enum, locate the type descriptions section (where existing types have brief descriptions). Append 4 new entries:

```markdown
- `deep_scan_subagent_failed` — scan-codebase v2.6.0+: a deep-scan subagent (auth/rbac/ui-ux/libs) failed once. Soft halt: auto-retried; on second failure emits partial starterkit-context.yaml with `partial: true`. Pipeline continues (warn-only).
- `deep_scan_cache_corrupt` — scan-codebase v2.6.0+: starterkit-context.yaml exists but fails YAML parse. Soft halt: cache auto-invalidated; subagents re-dispatched. Transparent to user.
- `deep_scan_subagent_all_failed` — scan-codebase v2.6.0+: ALL 4 deep-scan subagents failed (likely API outage). ALWAYS STOP: user re-runs scan-codebase later. Existing starterkit-context.yaml (if any) preserved untouched.
- `starterkit_rule_citation_missing` — generate-units v2.6.0+: a starterkit-derived Hard Rule lacks `Citation: starterkit-context.yaml §<path>` field. ALWAYS STOP: user must edit unit to add citation, then re-run Step 12.5 polished-prompt render pass.
```

- [ ] **Step 4.4: Add halt-type entries to orchestrate-flow taxonomy**

Edit `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`. Locate the existing "Halt types that ALWAYS STOP chain" list. Append:

```
- `deep_scan_subagent_all_failed` (v2.5.1+, Iter 32) — scan-codebase: all 4 deep-scan subagents failed. User re-runs later.
- `starterkit_rule_citation_missing` (v2.5.1+, Iter 32) — generate-units: starterkit-derived Hard Rule lacks citation. User edits unit.
```

Locate (or create) the "Soft halt types (warn-only, chain continues)" section. If section doesn't exist, add it below ALWAYS STOP:

```
### Halt types that are SOFT (warn-only, chain continues)

- `deep_scan_subagent_failed` (v2.5.1+, Iter 32) — scan-codebase: single deep-scan subagent failed. Auto-retried; partial output on second failure.
- `deep_scan_cache_corrupt` (v2.5.1+, Iter 32) — scan-codebase: starterkit-context.yaml YAML parse failed. Cache auto-invalidated; subagents re-dispatched. Transparent.
```

- [ ] **Step 4.5: Bump orchestrate-flow version to 2.5.1**

Edit `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` line 3 frontmatter:

```yaml
---
name: orchestrate-flow
version: 2.5.1
description: ...
---
```

(Bump from `2.5.0` to `2.5.1`.)

- [ ] **Step 4.6: Add starterkit_context: schema field to handoff-contract.md**

Edit `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`. Locate the §schema section that defines top-level handoff YAML fields. Append the new field definition:

```markdown
### `starterkit_context:` (v3.23.0+, Iter 32)

Optional block carrying starterkit detection results forward through the chain.

**Producer:** scan-codebase v2.6.0+ Step 2 deep-scan stage emits this block when a framework is detected with confidence ≥ MEDIUM AND `starterkit-context.yaml` was written.

**Propagation:** orchestrate-flow's existing `metadata.starterkit_context` passthrough carries this block to all downstream skills (generate-intent, bind-codebase, generate-units, execute-bolts) without modification.

**Schema:**

```yaml
starterkit_context:
  reused: <bool>                  # true if cache hit (no subagent dispatch); false if fresh scan
  framework: <string>             # e.g., laravel
  auth_lib: <enum>                # mirrors §auth.lib in starterkit-context.yaml
  rbac_lib: <enum>                # mirrors §rbac.lib
  ui_stack: <string>              # short-form summary, e.g., "alpine + tailwind + sweetalert2"
  libs_count: <int>               # total libs detected in §libs
```

**Consumer-side annotations:** generate-units and execute-bolts MAY append their own metrics under this block (see per-skill examples).

**Canonical source of truth for full structure:** `plugins/mega-sdd/references/starterkit-context-schema.md`
```

Locate per-skill examples sections for scan-codebase, generate-units, execute-bolts. Append `starterkit_context:` block examples to each:

**scan-codebase per-skill example** — append to existing handoff YAML:
```yaml
starterkit_context:
  reused: false
  framework: laravel
  auth_lib: sanctum
  rbac_lib: spatie/permission
  ui_stack: "alpine + tailwind + sweetalert2"
  libs_count: 47
```

**generate-units per-skill example** — append to existing handoff YAML:
```yaml
starterkit_context:
  reused: false
  framework: laravel
  auth_lib: sanctum
  rbac_lib: spatie/permission
  ui_stack: "alpine + tailwind + sweetalert2"
  libs_count: 47
  units_with_starterkit_anchors: 12
  units_with_starterkit_rules: 8
```

Also update generate-units `Status halted on:` line to include `starterkit_rule_citation_missing`.

**execute-bolts per-skill example** — append to existing handoff YAML:
```yaml
starterkit_context:
  reused: false
  framework: laravel
  auth_lib: sanctum
  rbac_lib: spatie/permission
  ui_stack: "alpine + tailwind + sweetalert2"
  libs_count: 47
  bolts_used_starterkit_slice: 11
  slice_avg_size_kb: 1.6
```

Also update scan-codebase `Status halted on:` line to include `deep_scan_subagent_failed`, `deep_scan_cache_corrupt`, `deep_scan_subagent_all_failed`.

- [ ] **Step 4.7: Add row to paths.md**

Edit `plugins/mega-sdd/references/paths.md`. Locate the per-skill path mapping table. Add a row:

```markdown
| scan-codebase | starterkit-context | `.mega-sdd/codebase/starterkit-context.yaml` | `docs/codebase/starterkit-context.yaml` (legacy back-compat probe only) |
```

(Match the format of existing rows in the table.)

- [ ] **Step 4.8: Verify 4-surface synchronization**

Run:
```bash
echo "=== vault-contract.md halt enum ==="
grep "starterkit_rule_citation_missing\|deep_scan_subagent" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | head -10

echo "=== orchestrate-flow halt taxonomy ==="
grep "starterkit_rule_citation_missing\|deep_scan_subagent" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | head -10

echo "=== handoff-contract starterkit_context block ==="
grep "starterkit_context" plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md | head -10

echo "=== paths.md new row ==="
grep "starterkit-context" plugins/mega-sdd/references/paths.md

echo "=== orchestrate-flow version ==="
grep "^version:" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
```

Expected:
- 4 halt types present in vault-contract.md enum line + 4 descriptions
- 4 halts present in orchestrate-flow taxonomy (2 always-stop + 2 soft)
- `starterkit_context:` schema field defined in handoff-contract.md + 3 per-skill examples present
- 1 row in paths.md for starterkit-context.yaml
- orchestrate-flow version: 2.5.1

- [ ] **Step 4.9: Commit (4-surface synchronization in single commit)**

```bash
git add plugins/mega-sdd/skills/generate-intent/references/vault-contract.md \
        plugins/mega-sdd/skills/orchestrate-flow/SKILL.md \
        plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md \
        plugins/mega-sdd/references/paths.md
git commit -m "$(cat <<'EOF'
chore(iter-32): register 4 new halt types across all 4 surfaces

Addresses iter-31 audit recurring pattern: halts declared in skill body
but missing from orchestrate-flow taxonomy / vault-contract type enum /
handoff-contract per-skill examples. This task registers across all 4
surfaces IN ONE COMMIT before any skill body cites them.

4 new halt types:
- deep_scan_subagent_failed         (soft, scan-codebase)
- deep_scan_cache_corrupt           (soft, scan-codebase)
- deep_scan_subagent_all_failed     (ALWAYS STOP, scan-codebase)
- starterkit_rule_citation_missing  (ALWAYS STOP, generate-units)

Surface updates:
- vault-contract.md: type enum + 4 descriptions
- orchestrate-flow SKILL.md: ALWAYS STOP list + SOFT halts subsection (new)
- handoff-contract.md: starterkit_context: schema field + 3 per-skill examples
- paths.md: row for .mega-sdd/codebase/starterkit-context.yaml

orchestrate-flow v2.5.0 -> v2.5.1 (taxonomy additions only).
EOF
)"
```

---

## Task 5: scan-codebase deep-scan stage (producer)

**Files:**
- Modify: `plugins/mega-sdd/skills/scan-codebase/SKILL.md` (2.5.0 → 2.6.0)

- [ ] **Step 5.1: Bump scan-codebase version**

Edit `plugins/mega-sdd/skills/scan-codebase/SKILL.md` frontmatter line 3:

```yaml
---
name: scan-codebase
version: 2.6.0
description: ...
---
```

- [ ] **Step 5.2: Add §Step 2 deep-scan stage to scan-codebase SKILL.md**

Edit the procedure section. After existing Step 1 (surface scan + framework detection) and BEFORE existing step that writes codebase-map.md, insert:

```markdown
## Step 2 — Deep-scan stage (v2.6.0+, Iter 32, DEFAULT-ON when framework detected)

After Step 1 surface scan completes and §7 Framework block is populated with `framework.confidence`, run this stage automatically. No user flag required. Opt-out: `--shallow-scan`.

### Step 2.0 — Trigger check

```
IF framework.confidence == HIGH or MEDIUM (≥ 0.5):
  → proceed to Step 2.1 (cache check)
ELSE:
  → log "framework confidence LOW (X.XX); deep-scan skipped — install ambiguous, run /mega-sdd:scan-codebase --force-deep to override"
  → skip Step 2 entirely; proceed to existing codebase-map.md write step
```

### Step 2.1 — Cache check

```
1. Compute composer_lock_sha256 = sha256(<project>/composer.lock) if file exists, else empty string
2. Compute package_lock_sha256 = sha256(<project>/package-lock.json) if exists,
   else sha256(<project>/yarn.lock) if exists,
   else sha256(<project>/pnpm-lock.yaml) if exists,
   else empty string
3. IF <project>/.mega-sdd/codebase/starterkit-context.yaml exists:
     a. Read its cache_key block
     b. IF prior.composer_lock_sha256 == current AND prior.package_lock_sha256 == current
        AND prior.framework_pack == current §7 Framework.pack_path basename:
        → CACHE HIT: skip Step 2.2 + 2.3; reuse existing starterkit-context.yaml
        → set handoff_reused_flag = true; proceed to Step 4
     c. ELSE → CACHE MISS / INVALID: proceed to Step 2.2
4. ELSE (file not present) → CACHE MISS: proceed to Step 2.2
```

Force re-scan: `--no-cache` (existing flag; extends to deep-scan cache too).

### Step 2.2 — Dispatch 4 subagents in PARALLEL

Dispatch all 4 subagents IN A SINGLE MESSAGE with 4 Agent tool calls (parallel-safe per `superpowers:subagent-driven-development` convention).

Use prompt templates from `references/deep-scan-prompts.md`, substituting:
- `<FRAMEWORK>` → from §7 Framework.name (e.g., `laravel`)
- `<PROJECT_ROOT>` → absolute path to project root
- `<CATALOG_PATH>` → for each subagent, the matching catalog under `plugins/mega-sdd/references/lib-patterns/<FRAMEWORK>/<domain>-libs.md`

Subagents:
1. **auth-extractor** — model: sonnet, catalog: `lib-patterns/<framework>/auth-libs.md`
2. **rbac-extractor** — model: sonnet, catalog: `lib-patterns/<framework>/rbac-libs.md`
3. **ui-ux-extractor** — model: sonnet, catalog: `lib-patterns/<framework>/ui-libs.md`
4. **libs-extractor** — model: sonnet, catalog: `lib-patterns/<framework>/generic-libs.md`

**Fallback:** if `lib-patterns/<FRAMEWORK>/` directory does not exist:
- Log "no lib-pattern pack for <framework>; using generic extraction"
- Subagents proceed using framework-conventions/_universal.md fallback patterns + manifest-only detection
- No halt; graceful degradation

**Timeout handling:** if a subagent exceeds 10 min wall-clock OR returns malformed YAML:
- Emit halt `deep_scan_subagent_failed` (soft); auto-retry ONCE with same model
- If second attempt also fails: mark that slice as failed; consolidator (Step 2.3) sets `partial: true` and adds the domain to `partial_slices: [...]`
- Pipeline continues (warn-only, NOT chain-stopping)

**All-fail handling:** if ALL 4 subagents fail (likely API outage):
- Emit halt `deep_scan_subagent_all_failed` (ALWAYS STOP)
- DO NOT write starterkit-context.yaml (preserve any existing prior version untouched)
- Chain halts; user re-runs scan-codebase later

### Step 2.3 — Consolidate + write starterkit-context.yaml

```
1. Collect 4 subagent responses (or fewer if any failed)
2. For each successful response: validate YAML against starterkit-context-schema.md §<domain> slice
   - If validation fails: drop slice; add domain to partial_slices: []
   - If validation passes: include slice in merged output
3. Build merged YAML structure:
     starterkit_context:
       schema_version: 1.0
       generated_by: scan-codebase v2.6.0
       generated_at: <ISO8601>
       framework: <from §7 Framework.name>
       framework_version: <from §7 Framework.version>
       framework_pack: <from §7 Framework.pack_path basename>
       partial: true   # ONLY include this field if ≥1 slice failed
       partial_slices: [<list>]   # ONLY include if partial: true
       auth: {...}   # include if auth-extractor succeeded
       rbac: {...}   # include if rbac-extractor succeeded
       ui_ux: {...}  # include if ui-ux-extractor succeeded
       libs: [...]   # include if libs-extractor succeeded
       cache_key:
         composer_lock_sha256: <from Step 2.1>
         package_lock_sha256: <from Step 2.1>
4. Write atomically to <project>/.mega-sdd/codebase/starterkit-context.yaml
   (Use temp file + rename pattern: write to .starterkit-context.yaml.tmp, then mv)
5. Validate the written file is parseable:
   - If parse fails: emit halt deep_scan_cache_corrupt (soft); delete file; retry write once
   - If second write also corrupts: drop deep-scan entirely; log warning; proceed to Step 4 without handoff starterkit_context: block
```

### Step 2.4 — Concurrency guard

Use existing memory file-lock pattern on `.mega-sdd/codebase/starterkit-context.yaml`:
- Acquire exclusive lock before write
- If lock held by concurrent scan-codebase invocation → fail fast with `memory_in_use` halt (existing halt type)
- Release lock after write

---
```

- [ ] **Step 5.3: Add ## Halt conditions section entries for new halts**

Locate `## Halt conditions` section in scan-codebase SKILL.md. Append:

```markdown
### `deep_scan_subagent_failed` (v2.6.0+, Iter 32) — SOFT

```yaml
type: deep_scan_subagent_failed
source_skill: scan-codebase
details:
  domain: <auth | rbac | ui_ux | libs>
  subagent_index: <1-4>
  failure_reason: <"timeout" | "malformed_yaml" | "api_error: <msg>">
  retry_count: <1 or 2>
next_action:
  type: continue_with_partial
  hint: "Partial starterkit-context.yaml will be emitted with partial: true and partial_slices: [<domain>]. Pipeline continues; downstream consumers degrade gracefully for missing slices."
```

Recovery: auto-retry once. On second failure: emit partial output. Soft halt — chain continues.

### `deep_scan_cache_corrupt` (v2.6.0+, Iter 32) — SOFT

```yaml
type: deep_scan_cache_corrupt
source_skill: scan-codebase
details:
  file_path: "<project>/.mega-sdd/codebase/starterkit-context.yaml"
  parse_error: "<error message from YAML parser>"
next_action:
  type: auto_invalidate_and_rescan
  hint: "Cache file is corrupt; auto-invalidating and re-dispatching subagents. Transparent to user."
```

Recovery: auto-invalidate cache + re-run subagents. Soft halt — chain continues.

### `deep_scan_subagent_all_failed` (v2.6.0+, Iter 32) — ALWAYS STOP

```yaml
type: deep_scan_subagent_all_failed
source_skill: scan-codebase
details:
  failed_domains: [auth, rbac, ui_ux, libs]
  common_failure_reason: <"api_outage" | "rate_limited" | "unknown">
next_action:
  type: user_retry
  hint: "All 4 deep-scan subagents failed (likely API outage). Re-run /mega-sdd:scan-codebase later. Existing starterkit-context.yaml (if any) preserved untouched."
```

Recovery: user re-runs scan-codebase later. Chain halts.
```

- [ ] **Step 5.4: Update handoff YAML example in scan-codebase SKILL.md**

Locate `## Handoff emission` section (or equivalent) in scan-codebase SKILL.md. Update the handoff YAML example to include the new `starterkit_context:` block:

```yaml
emitted_by: scan-codebase
emitted_at: <ISO8601>
status: completed                                 # or paused | halted
artifacts:
  - <absolute path to .mega-sdd/codebase/codebase-map.md>
  - <absolute path to .mega-sdd/codebase/starterkit-context.yaml>  # NEW v2.6.0+ (only when deep-scan ran)
starterkit_context:                                                  # NEW v2.6.0+ block (only when deep-scan ran)
  reused: false                                                       # true if cache hit
  framework: laravel
  auth_lib: sanctum
  rbac_lib: spatie/permission
  ui_stack: "alpine + tailwind + sweetalert2"
  libs_count: 47
next_action:
  type: invoke_skill
  suggested_skill: mega-sdd:generate-intent          # Iter 27 starterkit-first ordering
  suggested_args:
    - "--scan=<absolute path to .mega-sdd/codebase/codebase-map.md>"
    - "--auto"
blockers: []                                          # populated when status: halted
metrics:
  files_scanned: <int>
  symbols_extracted: <int>
  deep_scan_wall_clock_sec: <int>                     # NEW v2.6.0+: 0 on cache hit
```

Add note below the example:
> The `starterkit_context:` block + the `starterkit-context.yaml` artifact entry are CONDITIONAL — emitted only when deep-scan ran successfully (framework detected at MEDIUM+ confidence). Skip both when deep-scan was skipped or failed entirely.

- [ ] **Step 5.5: Add Status halted on: line update**

Find the existing `Status halted on:` line in scan-codebase SKILL.md handoff section. Update to include the 3 new scan-codebase halts:

```
Status `halted` on: dep_missing | deep_scan_subagent_all_failed | memory_in_use
```

(Soft halts `deep_scan_subagent_failed` and `deep_scan_cache_corrupt` are NOT in this list because they don't set status to halted — they're warn-only.)

- [ ] **Step 5.6: Add anti-halu rails entries**

Locate `## Anti-hallucination rails` section in scan-codebase SKILL.md. Append:

```markdown
- (v2.6.0+, Iter 32) Deep-scan no-fabrication: each subagent MUST emit `lib: not_detected` when no fingerprint matches, NEVER guess. Schema-validation drops slices that violate.
- (v2.6.0+, Iter 32) Deep-scan citation rail: every starterkit-context.yaml field MUST be backed by `_source: [<file>, ...]` companion field. Schema-validation drops slices without _source.
- (v2.6.0+, Iter 32) Deep-scan read-only: subagents have NO Edit/Write/mutating-Bash tool access. Read-only enforced at dispatch.
```

- [ ] **Step 5.7: Verify scan-codebase modifications**

Run:
```bash
echo "=== Version ==="
grep "^version:" plugins/mega-sdd/skills/scan-codebase/SKILL.md
echo "=== Step 2 deep-scan present ==="
grep -c "Step 2 — Deep-scan stage\|Step 2.0\|Step 2.1\|Step 2.2\|Step 2.3" plugins/mega-sdd/skills/scan-codebase/SKILL.md
echo "=== 3 new halts in halt conditions ==="
grep -c "deep_scan_subagent_failed\|deep_scan_cache_corrupt\|deep_scan_subagent_all_failed" plugins/mega-sdd/skills/scan-codebase/SKILL.md
echo "=== Handoff has starterkit_context: block ==="
grep -c "starterkit_context:" plugins/mega-sdd/skills/scan-codebase/SKILL.md
echo "=== Anti-halu rails added ==="
grep -c "v2.6.0+, Iter 32" plugins/mega-sdd/skills/scan-codebase/SKILL.md
```

Expected:
- Version: 2.6.0
- Step 2 substeps: ≥5 matches
- 3 new halts: ≥6 matches (each halt mentioned ≥2 times)
- starterkit_context: ≥2 matches (handoff example + Status line context)
- Anti-halu rails: ≥3 matches

- [ ] **Step 5.8: Commit**

```bash
git add plugins/mega-sdd/skills/scan-codebase/SKILL.md
git commit -m "$(cat <<'EOF'
feat(iter-32): scan-codebase v2.6.0 — deep-scan stage (autonomous default-on)

New Step 2 deep-scan stage runs automatically when framework confidence
>= MEDIUM. Dispatches 4 parallel sonnet subagents (auth/rbac/ui-ux/libs)
that read manifests + actual code, return structured YAML slices.
Consolidator validates against starterkit-context-schema.md, merges into
.mega-sdd/codebase/starterkit-context.yaml.

Cache via composer.lock + package.lock sha256 — re-scan with unchanged
deps is 0sec (cache hit). Atomic write via temp-file + rename.
Concurrency guard via existing memory file-lock.

Handoff YAML includes new starterkit_context: block (conditional —
only when deep-scan ran successfully). Status halted on: extended
with 3 scan-codebase halts (1 ALWAYS STOP + 2 soft warn-only).

3 anti-halu rails added (v2.6.0+):
- No-fabrication: not_detected is valid; never guess
- Citation: _source per field; schema-validate drops un-cited slices
- Read-only: subagents have no mutating tool access

scan-codebase v2.5.0 -> v2.6.0
EOF
)"
```

---

## Task 6: generate-units consumer (Step 4.7 + Step 12.5)

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-units/SKILL.md` (2.5.4 → 2.6.0)

- [ ] **Step 6.1: Bump generate-units version**

Edit `plugins/mega-sdd/skills/generate-units/SKILL.md` frontmatter line 3:

```yaml
version: 2.6.0
```

(From `2.5.4` to `2.6.0`.)

- [ ] **Step 6.2: Add Step 4.7 (between existing Step 4 and Step 5)**

Locate existing Step 4 "Load framework convention pack" (around line 200) and Step 5 "Squad partition" in generate-units SKILL.md. Insert Step 4.7 BETWEEN them:

```markdown
## Step 4.7 — Load starterkit-context.yaml + derive starterkit-specific Anchors and Hard Rules per unit (v2.6.0+, Iter 32)

### Step 4.7.a — Resolve starterkit-context.yaml

```
Path: <project>/.mega-sdd/codebase/starterkit-context.yaml

IF file absent:
  → log "starterkit-context unavailable; emit framework-pack-only Anchors"
  → set every unit's frontmatter `starterkit_context_consumed: false`
  → SKIP Steps 4.7.b - 4.7.e
IF file present:
  → parse YAML
  → IF parse fails: log warning; treat as absent; proceed as above
  → IF starterkit_context.partial == true: note which slices are missing (partial_slices: [...])
  → proceed to Step 4.7.b
```

### Step 4.7.b — Compute starterkit relevance per unit

For each unit being generated, inspect `unit.target_files` (already populated from earlier steps) and unit body content. Determine which starterkit slices apply:

```
starterkit_relevance = []

IF any target_file matches:
  resources/views/**, resources/js/**, resources/css/**, public/css/**, public/js/**
THEN starterkit_relevance += ["ui_ux"]
   (skip if starterkit_context.ui_ux missing OR ui_ux in partial_slices)

IF any target_file matches app/Http/Controllers/**
AND unit body mentions any of: "auth", "login", "register", "logout", "password", "session"
THEN starterkit_relevance += ["auth"]
   (skip if auth missing)

IF any target_file matches app/Http/Middleware/** OR app/Policies/**
OR unit body mentions any of: "role", "permission", "gate", "policy", "Spatie\\Permission"
THEN starterkit_relevance += ["rbac"]
   (skip if rbac missing)

IF any target_file path appears in any libs[].usage_hint[]
THEN starterkit_relevance += ["libs"]
   (skip if libs missing)
```

Empty `starterkit_relevance: []` is a valid result for units that don't intersect any starterkit slice. In that case, skip Steps 4.7.c + 4.7.d for that unit.

### Step 4.7.c — Derive starterkit Anchors per unit

For each unit with `starterkit_relevance` non-empty, append starterkit-specific anchors to `unit.anchors[]`:

```
IF "ui_ux" in starterkit_relevance:
  add anchor: <starterkit_context.ui_ux.layout_file>   (e.g., resources/views/layouts/app.blade.php)
  IF starterkit_context.ui_ux.component_dir exists:
    add anchor: <starterkit_context.ui_ux.component_dir>   (e.g., resources/views/components/)

IF "auth" in starterkit_relevance:
  add anchor: <file path of starterkit_context.auth.user_model class>   (e.g., app/Models/User.php)
  IF starterkit_context.auth.routes.login != "":
    add anchor: routes/auth.php (or routes/web.php if auth.php absent)

IF "rbac" in starterkit_relevance:
  IF starterkit_context.rbac.middleware contains entries:
    add anchor: app/Http/Middleware/<middleware-class>.php for each middleware alias
  add anchor: app/Providers/AuthServiceProvider.php

IF "libs" in starterkit_relevance:
  for each lib in starterkit_context.libs whose usage_hint overlaps unit.target_files:
    add the lib's usage_hint[0] file as an anchor (first hint file)
```

Anchors append to `unit.anchors[]` alongside KB/binding anchors from prior steps. Deduplicate paths if a file is anchored multiple times.

### Step 4.7.d — Derive starterkit Hard Rules per unit (with mandatory citation)

For each unit with `starterkit_relevance` non-empty, append starterkit-specific Hard Rules to `unit.hard_rules[]`. EVERY rule MUST include a Citation field.

**Template format for each rule:**

```
- text: "<rule text>"
  citation: "starterkit-context.yaml §<path>"
  source: starterkit-context.yaml
```

**UI/UX-relevant unit examples (when "ui_ux" in starterkit_relevance):**

```
- text: "MUST extend `<starterkit_context.ui_ux.layout_extends>` (e.g., layouts.app) in all Blade views generated by this unit"
  citation: "starterkit-context.yaml §ui_ux.layout_extends"

- IF starterkit_context.ui_ux.notification_lib == "sweetalert2":
    - text: "MUST use SweetAlert2 for confirmations and notifications (NEVER native alert() or window.confirm())"
      citation: "starterkit-context.yaml §ui_ux.notification_lib"

- FOR EACH idiom in starterkit_context.ui_ux.idioms:
    - text: "MUST follow starterkit idiom: <idiom>"
      citation: "starterkit-context.yaml §ui_ux.idioms"

  (Examples — emitted only if idiom is empirically present per ui-ux-extractor):
  - "use document.addEventListener('DOMContentLoaded', ...) over $(document).ready"
  - "responsive mobile-first (sm/md/lg breakpoints)"
```

**Auth-relevant unit examples (when "auth" in starterkit_relevance):**

```
- text: "MUST use auth guard '<starterkit_context.auth.guard>' (e.g., sanctum or web)"
  citation: "starterkit-context.yaml §auth.guard"

- text: "MUST reference User model `<starterkit_context.auth.user_model>` not generic Auth::user()::class"
  citation: "starterkit-context.yaml §auth.user_model"

- IF "2fa" in starterkit_context.auth.features:
    - text: "Two-factor authentication is enabled in this starterkit; auth flows MUST respect 2fa challenge state"
      citation: "starterkit-context.yaml §auth.features"
```

**RBAC-relevant unit examples (when "rbac" in starterkit_relevance):**

```
- IF starterkit_context.rbac.lib == "spatie/permission":
    - text: "MUST use Spatie/permission middleware: route()->middleware('role:<role>') OR middleware('permission:<perm>')"
      citation: "starterkit-context.yaml §rbac.middleware"

    - text: "MUST reference Spatie\\Permission\\Models\\Role for role queries (NOT custom Role models)"
      citation: "starterkit-context.yaml §rbac.role_model"
```

**Libs-relevant unit examples (when "libs" in starterkit_relevance):**

```
FOR EACH lib in starterkit_context.libs whose usage_hint overlaps unit.target_files:
  - text: "MUST use existing starterkit library `<lib.name>` v<lib.version> for <lib.category> functionality, NOT a competing alternative"
    citation: "starterkit-context.yaml §libs (name: <lib.name>)"
```

### Step 4.7.e — Update unit frontmatter

For each unit (even those with empty starterkit_relevance):

```yaml
---
unit_id: U-001
# ... existing frontmatter ...
starterkit_context_consumed: <true | false>     # NEW v2.6.0+, Iter 32
starterkit_relevance: [<list of applicable slices>]   # NEW v2.6.0+, Iter 32; may be empty list
---
```

Also append `starterkit-context.yaml` as a citation source in the unit's §Citations footer section (only if starterkit_context_consumed: true).

---
```

- [ ] **Step 6.3: Add Step 12.5 citation check**

Locate existing Step 12.5 "polished-prompt render pass" in generate-units SKILL.md. Append a new sub-check:

```markdown
### Step 12.5.<n> — Starterkit citation check (v2.6.0+, Iter 32)

IF unit.frontmatter.starterkit_context_consumed == true:
  FOR EACH hard_rule in unit.hard_rules:
    IF hard_rule.source == "starterkit-context.yaml" AND hard_rule.citation field is missing or empty:
      → HALT `starterkit_rule_citation_missing`
      → emit blocker YAML:
          type: starterkit_rule_citation_missing
          source_skill: generate-units
          details:
            unit_id: <U-XXX>
            rule_text: "<text of offending rule>"
            missing_citation: "starterkit-context.yaml §<expected path>"
            rule_index: <index of rule in hard_rules[]>
          next_action:
            type: edit_unit
            suggested_args: ["<U-XXX>"]
            hint: "Append 'Citation: starterkit-context.yaml §<path>' to Hard Rule #<index>"
      → do NOT write the unit; halt is ALWAYS STOP
```

This rail enforces that every starterkit-derived Hard Rule includes its citation — mirrors existing "every Hard Rule needs a Citation" rail extended to starterkit-derived rules.

- [ ] **Step 6.4: Update handoff YAML in generate-units SKILL.md**

Locate `## Handoff emission` section. Update YAML example to include the new starterkit_context: block:

```yaml
emitted_by: generate-units
emitted_at: <ISO8601>
status: completed
artifacts:
  - <abs path to <vault>/units/U-001.md>
  - <abs path to <vault>/units/U-002.md>
  # ... (one path per unit)
starterkit_context:                                       # NEW v2.6.0+, Iter 32 (passthrough + metrics)
  reused: false
  framework: laravel
  auth_lib: sanctum
  rbac_lib: spatie/permission
  ui_stack: "alpine + tailwind + sweetalert2"
  libs_count: 47
  units_with_starterkit_anchors: 12                       # NEW metric (count of units that gained starterkit Anchors)
  units_with_starterkit_rules: 8                          # NEW metric (count of units that gained starterkit Hard Rules)
next_action:
  type: invoke_skill
  suggested_skill: mega-sdd:execute-bolts
  suggested_args: ["--all", "--auto"]
blockers: []
metrics:
  units_generated: <int>
  units_with_starterkit_anchors: <int>                     # NEW (mirrors starterkit_context block)
  units_with_starterkit_rules: <int>                       # NEW
```

Update the `Status halted on:` line to include `starterkit_rule_citation_missing`:

```
Status `halted` on: cycle_detected | cross_squad_dep_invalid | dedup_ambiguous | unit_underspecified | hard_rule_unparseable | interface_ref_missing | cross_squad_ambiguous | starterkit_rule_citation_missing
```

- [ ] **Step 6.5: Add ## Halt conditions entry for new halt**

Locate `## Halt conditions` section in generate-units SKILL.md. Append:

```markdown
### `starterkit_rule_citation_missing` (v2.6.0+, Iter 32) — ALWAYS STOP

Emitted by Step 12.5 polished-prompt render pass when a unit's starterkit-derived Hard Rule lacks the mandatory `Citation: starterkit-context.yaml §<path>` field.

```yaml
type: starterkit_rule_citation_missing
source_skill: generate-units
details:
  unit_id: <U-XXX>
  rule_text: "<text of offending rule>"
  missing_citation: "starterkit-context.yaml §<expected path>"
  rule_index: <int>
next_action:
  type: edit_unit
  suggested_args: ["<U-XXX>"]
  hint: "Append 'Citation: starterkit-context.yaml §<path>' to Hard Rule #<index>"
```

Recovery: user edits unit to add citation; re-runs Step 12.5 polished-prompt render pass.
```

- [ ] **Step 6.6: Verify generate-units modifications**

Run:
```bash
echo "=== Version ==="
grep "^version:" plugins/mega-sdd/skills/generate-units/SKILL.md
echo "=== Step 4.7 present ==="
grep -c "Step 4.7" plugins/mega-sdd/skills/generate-units/SKILL.md
echo "=== Step 12.5 citation check present ==="
grep -c "starterkit_rule_citation_missing" plugins/mega-sdd/skills/generate-units/SKILL.md
echo "=== Handoff has starterkit_context: block ==="
grep -c "starterkit_context:" plugins/mega-sdd/skills/generate-units/SKILL.md
echo "=== Handoff has new metrics ==="
grep -c "units_with_starterkit_anchors\|units_with_starterkit_rules" plugins/mega-sdd/skills/generate-units/SKILL.md
```

Expected:
- Version: 2.6.0
- Step 4.7: ≥5 matches (header + subheaders)
- starterkit_rule_citation_missing: ≥3 matches (Step 12.5 + halt section + Status halted line)
- starterkit_context:: ≥2 matches
- New metrics: ≥4 matches (handoff example + metrics block)

- [ ] **Step 6.7: Commit**

```bash
git add plugins/mega-sdd/skills/generate-units/SKILL.md
git commit -m "$(cat <<'EOF'
feat(iter-32): generate-units v2.6.0 — starterkit-aware Anchors + Hard Rules

New Step 4.7 (between Step 4 framework pack + Step 5 squad partition):
- 4.7.a: resolve .mega-sdd/codebase/starterkit-context.yaml (graceful absence)
- 4.7.b: compute starterkit_relevance per unit (auth/rbac/ui_ux/libs)
- 4.7.c: derive starterkit Anchors (layout file, User model, middleware, lib usage_hint)
- 4.7.d: derive starterkit Hard Rules with mandatory Citation field
- 4.7.e: update unit frontmatter (starterkit_context_consumed, starterkit_relevance)

New Step 12.5 citation check: halts on starterkit_rule_citation_missing
if any starterkit-derived rule lacks Citation field.

User's standing prefs (SweetAlert2, document.addEventListener over jQuery
ready, responsive mobile-first) flow into Hard Rules automatically when
scanned starterkit reports them as idioms — no per-session reminder needed.

Handoff YAML: starterkit_context: block + 2 new metrics
(units_with_starterkit_anchors, units_with_starterkit_rules).

generate-units v2.5.4 -> v2.6.0
EOF
)"
```

---

## Task 7: execute-bolts consumer (T2 slice injection)

**Files:**
- Modify: `plugins/mega-sdd/skills/execute-bolts/SKILL.md` (2.6.0 → 2.7.0)
- Modify: `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md`

- [ ] **Step 7.1: Bump execute-bolts version**

Edit `plugins/mega-sdd/skills/execute-bolts/SKILL.md` frontmatter line 3:

```yaml
version: 2.7.0
```

(From `2.6.0` to `2.7.0`.)

- [ ] **Step 7.2: Add Step 1.5.f, 1.5.g, 1.5.h to execute-bolts SKILL.md**

Locate existing Step 1.5 "tiered context enrichment" section (or whatever the Iter 30 tiered enrichment step is called) in execute-bolts SKILL.md. Append three sub-steps:

```markdown
### Step 1.5.f — Read starterkit-context.yaml (v2.7.0+, Iter 32)

```
Path: <project>/.mega-sdd/codebase/starterkit-context.yaml

IF file absent → skip Steps 1.5.g + 1.5.h; do not inject starterkit slice into T2
IF file present → parse YAML
  IF parse fails → log warning; emit `deep_scan_cache_corrupt` soft halt; skip
  IF starterkit_context.partial == true → note partial_slices for slice availability
Read unit.frontmatter.starterkit_relevance array (from generate-units Step 4.7.e)
IF unit.starterkit_relevance is missing OR empty → skip Steps 1.5.g + 1.5.h
```

### Step 1.5.g — Build T2 slice based on unit.starterkit_relevance

For each relevance flag in `unit.starterkit_relevance`, include ONLY that slice from `starterkit-context.yaml`:

```
slice = {}

IF "auth" in unit.starterkit_relevance AND starterkit_context.auth exists:
  slice.auth = starterkit_context.auth (lib, guard, user_model only — exclude routes, _source)

IF "rbac" in unit.starterkit_relevance AND starterkit_context.rbac exists:
  slice.rbac = starterkit_context.rbac (lib, role_model, permission_model, middleware only — exclude policies array, _source)

IF "ui_ux" in unit.starterkit_relevance AND starterkit_context.ui_ux exists:
  slice.ui_ux = starterkit_context.ui_ux (layout_extends, notification_lib, idioms only — exclude design_tokens, _source)

IF "libs" in unit.starterkit_relevance AND starterkit_context.libs exists:
  slice.libs = filter(starterkit_context.libs, by usage_hint overlap with unit.target_files)
  (NOT the full inventory — only libs whose usage_hint contains any of unit.target_files paths or path prefixes)
```

Truncation order if slice exceeds 2KB budget:
1. Truncate `slice.libs[]` first — keep top 10 by relevance score (overlap count with target_files)
2. If still >2KB → truncate `slice.ui_ux.idioms[]` to top 3
3. If still >2KB → emit halt `dispatch_prompt_too_large` (existing Iter 30 halt; chain stops)

### Step 1.5.h — Inject into dispatch prompt T2 section

The bolt-dispatch-prompt template (see `references/bolt-dispatch-prompt.md`) has a T2 "Starterkit context (relevant slice)" section. Populate it with the slice from Step 1.5.g:

```
### Starterkit context (relevant to this unit)

<IF slice.auth present:>
Auth: lib=<slice.auth.lib>, guard=<slice.auth.guard>, user_model=<slice.auth.user_model>
</IF>

<IF slice.rbac present:>
RBAC: lib=<slice.rbac.lib>, role_model=<slice.rbac.role_model>, middleware=<slice.rbac.middleware joined by ", ">
</IF>

<IF slice.ui_ux present:>
UI/UX: extends=<slice.ui_ux.layout_extends>, notification=<slice.ui_ux.notification_lib>, idioms=[<slice.ui_ux.idioms joined by "; ">]
</IF>

<IF slice.libs present AND non-empty:>
Libs in scope: <for each lib in slice.libs: <lib.name>@<lib.version> (used in: <lib.usage_hint joined by ", ">)>
</IF>
```

Sections for absent relevance flags are OMITTED entirely (not emitted as empty headers).

Wall-clock cost: 0sec when starterkit-context.yaml is absent (Step 1.5.f exits early). When present: ≤500ms (YAML parse + filter + format).

---
```

- [ ] **Step 7.3: Add T2 starterkit section to bolt-dispatch-prompt.md**

Edit `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md`. Locate the T2 tier section (existing Iter 30 structure should have T2 with "Confidence labels", "Historical memory", etc.). Insert a new subsection BETWEEN "Confidence labels" and "Historical memory":

```markdown
### T2.3 — Starterkit context (relevant slice) (v2.7.0+, Iter 32)

This section is populated by execute-bolts Step 1.5.f-h when:
1. `<project>/.mega-sdd/codebase/starterkit-context.yaml` exists (deep-scan was run)
2. `unit.starterkit_relevance` is non-empty (unit intersects ≥1 starterkit domain)

If both conditions met, the dispatcher injects the relevant slice (≤2KB) here. Sections for non-relevant domains are OMITTED entirely.

**Slice template (sections appear only when relevant):**

```
### Starterkit context (relevant to this unit)

Auth: lib=<auth.lib>, guard=<auth.guard>, user_model=<auth.user_model>
RBAC: lib=<rbac.lib>, role_model=<rbac.role_model>, middleware=<rbac.middleware joined by ", ">
UI/UX: extends=<ui_ux.layout_extends>, notification=<ui_ux.notification_lib>, idioms=[<idioms joined by "; ">]
Libs in scope: <lib.name>@<lib.version> (used in: <usage_hint joined by ", ">), ...
```

**Budget:** total slice content ≤2KB. Truncation order: libs[] (keep top 10 by relevance) → idioms[] (keep top 3) → halt `dispatch_prompt_too_large` if still over.

**Anti-halu rail:** when this section is present, the bolt subagent MUST honor the constraints listed. Do NOT invent libs not listed; do NOT use a different layout than `extends:` value; do NOT use a different notification lib.

**Absence is valid:** if this section is absent, no starterkit context is available — the bolt should produce code following framework defaults (per the framework pack T1 section).
```

- [ ] **Step 7.4: Update handoff YAML in execute-bolts SKILL.md**

Locate `## Handoff emission` section. Update YAML example to include the new starterkit_context: block with execute-bolts-specific metrics:

```yaml
emitted_by: execute-bolts
emitted_at: <ISO8601>
status: completed
artifacts:
  - <abs path to <vault>/bolts/U-001/bolt-report.md>
  # ... (one per executed bolt)
starterkit_context:                                       # NEW v2.7.0+, Iter 32 (passthrough + metrics)
  reused: false
  framework: laravel
  auth_lib: sanctum
  rbac_lib: spatie/permission
  ui_stack: "alpine + tailwind + sweetalert2"
  libs_count: 47
  bolts_used_starterkit_slice: 11                          # NEW metric
  slice_avg_size_kb: 1.6                                   # NEW metric (average T2 slice size injected)
next_action:
  type: invoke_skill
  suggested_skill: mega-sdd:detect-drift
  suggested_args: ["--reuse-bolt-snapshots"]
blockers: []
metrics:
  bolts_completed: <int>
  bolts_used_starterkit_slice: <int>                       # NEW
  slice_avg_size_kb: <float>                               # NEW
```

- [ ] **Step 7.5: Add anti-halu rail entries to execute-bolts SKILL.md**

Locate `## Anti-hallucination rails` section in execute-bolts SKILL.md. Append:

```markdown
- (v2.7.0+, Iter 32) Starterkit slice budget: T2 starterkit slice MUST be capped at 2KB. Truncation order: libs[] (top 10 by relevance) → idioms[] (top 3) → halt dispatch_prompt_too_large if still over. Prevents bolt context bloat regression.
- (v2.7.0+, Iter 32) Starterkit slice constraint honoring: when T2.3 starterkit section is present in dispatch prompt, bolt subagent MUST honor: extend the named layout, use the named notification lib, use only the listed libs (no inventing alternatives). Code that violates is rejected at post-flight check (existing rule extension).
```

- [ ] **Step 7.6: Verify execute-bolts modifications**

Run:
```bash
echo "=== execute-bolts version ==="
grep "^version:" plugins/mega-sdd/skills/execute-bolts/SKILL.md
echo "=== Step 1.5.f-h present ==="
grep -c "Step 1.5.f\|Step 1.5.g\|Step 1.5.h" plugins/mega-sdd/skills/execute-bolts/SKILL.md
echo "=== Handoff has starterkit_context + new metrics ==="
grep -c "bolts_used_starterkit_slice\|slice_avg_size_kb" plugins/mega-sdd/skills/execute-bolts/SKILL.md
echo "=== bolt-dispatch-prompt has T2.3 starterkit section ==="
grep -c "Starterkit context\|T2.3" plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md
echo "=== Anti-halu rails added ==="
grep -c "v2.7.0+, Iter 32" plugins/mega-sdd/skills/execute-bolts/SKILL.md
```

Expected:
- Version: 2.7.0
- Step 1.5.f-h: ≥3 matches
- New metrics: ≥4 matches
- bolt-dispatch-prompt T2.3 section: ≥2 matches
- Anti-halu rails: ≥2 matches

- [ ] **Step 7.7: Commit**

```bash
git add plugins/mega-sdd/skills/execute-bolts/SKILL.md \
        plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md
git commit -m "$(cat <<'EOF'
feat(iter-32): execute-bolts v2.7.0 — T2 starterkit slice injection

New Step 1.5.f-h (extends Iter 30 tiered enrichment Step 1.5):
- 1.5.f: read starterkit-context.yaml (graceful absence + partial: true handling)
- 1.5.g: build T2 slice based on unit.starterkit_relevance (per-domain filter)
       + libs[] filter by usage_hint overlap with target_files (NOT full inventory)
       + truncation order: libs (top 10) -> idioms (top 3) -> dispatch_prompt_too_large halt
- 1.5.h: inject relevant slice into bolt-dispatch-prompt T2.3 section
       (sections for non-relevant domains OMITTED entirely)

bolt-dispatch-prompt.md: new T2.3 "Starterkit context (relevant slice)"
section between Confidence labels + Historical memory. Anti-halu rail:
bolt MUST honor listed constraints (named layout, notification lib, libs).

Handoff YAML: starterkit_context: passthrough + 2 new metrics
(bolts_used_starterkit_slice, slice_avg_size_kb).

When bolt subagent receives "MUST use SweetAlert2" + "MUST extend layouts.app"
in T2.3 context, generates code that does exactly that — without per-session
user reminder. Standing user prefs flow through automatically.

execute-bolts v2.6.0 -> v2.7.0
EOF
)"
```

---

## Task 8: Trigger tests (4 .test.md files modified, +12 cases)

**Files:**
- Modify: `tests/skill-triggering/scan-codebase.test.md` (+6 cases SC-DS1..SC-DS6)
- Modify: `tests/skill-triggering/generate-units.test.md` (+3 cases GU-SK1..GU-SK3)
- Modify: `tests/skill-triggering/execute-bolts.test.md` (+2 cases EB-SK1..EB-SK2)
- Modify: `tests/skill-triggering/orchestrate-flow.test.md` (+1 case OF-SK1)

- [ ] **Step 8.1: Add 6 cases to scan-codebase.test.md**

Append to `tests/skill-triggering/scan-codebase.test.md`:

```markdown
---

## Iter 32 — Deep-scan stage cases (v2.6.0+)

### SC-DS1 — Fresh deep-scan: full Laravel starterkit detected

**Setup:**
- Laravel project at `<project_root>`
- `composer.json` `require` includes: `laravel/sanctum`, `spatie/laravel-permission`
- `package.json` `dependencies` includes: `alpinejs`, `tailwindcss`, `sweetalert2`
- No prior `.mega-sdd/codebase/starterkit-context.yaml`

**Trigger:** `/mega-sdd:scan-codebase <project_root>`

**Expected:**
- Step 1 surface scan completes; codebase-map.md §7 Framework.confidence == HIGH (≥ 0.8) for Laravel
- Step 2.0 trigger check passes (confidence ≥ MEDIUM)
- Step 2.1 cache check: no prior file → cache miss
- Step 2.2: 4 subagents (auth/rbac/ui-ux/libs) dispatched in PARALLEL (single message, 4 Agent calls)
- Step 2.3: 4 YAML responses consolidated → `.mega-sdd/codebase/starterkit-context.yaml` written
- File contents include: `auth.lib: sanctum`, `rbac.lib: spatie/permission`, `ui_ux.notification_lib: sweetalert2`, ≥3 libs in libs[]
- Handoff YAML includes `starterkit_context:` block with `reused: false`
- artifacts[] includes both `codebase-map.md` and `starterkit-context.yaml`

### SC-DS2 — Cache reuse on re-scan with unchanged deps

**Setup:** SC-DS1 just ran; `.mega-sdd/codebase/starterkit-context.yaml` exists; `composer.lock` and `package-lock.json` unchanged

**Trigger:** `/mega-sdd:scan-codebase <project_root>` (run again)

**Expected:**
- Step 2.1 cache check: prior file exists; lock hashes match → CACHE HIT
- Step 2.2 + 2.3 SKIPPED (no subagent dispatch)
- `.mega-sdd/codebase/starterkit-context.yaml` unchanged (mtime preserved or near-preserved)
- Handoff YAML includes `starterkit_context: reused: true`
- Wall-clock for Step 2: <2 seconds

### SC-DS3 — Cache invalidation on dep change

**Setup:** SC-DS2 just ran; user then runs `composer require laravel/cashier`; `composer.lock` regenerated with new hash

**Trigger:** `/mega-sdd:scan-codebase <project_root>`

**Expected:**
- Step 2.1: lock hash mismatch → cache invalidated
- Step 2.2: 4 subagents re-dispatched
- Step 2.3: new `.mega-sdd/codebase/starterkit-context.yaml` written
- Contents: libs[] now includes `laravel/cashier`
- Handoff: `starterkit_context: reused: false`

### SC-DS4 — Pure config repo (no framework detected)

**Setup:** Repo at `<project_root>` has only `.gitignore`, `README.md`, `LICENSE`. No `composer.json`, no `package.json`.

**Trigger:** `/mega-sdd:scan-codebase <project_root>`

**Expected:**
- Step 1: §7 Framework.confidence == LOW (< 0.5) or framework absent
- Step 2.0 trigger check FAILS (confidence below threshold) → Step 2 SKIPPED entirely
- Log line emitted: "framework confidence LOW (<value>); deep-scan skipped — install ambiguous, run /mega-sdd:scan-codebase --force-deep to override"
- codebase-map.md WRITTEN normally (without §7 detailed framework block, or with `framework: none`)
- `.mega-sdd/codebase/starterkit-context.yaml` NOT created
- Handoff YAML has NO `starterkit_context:` block
- artifacts[] includes only `codebase-map.md`

### SC-DS5 — Subagent timeout + partial output

**Setup:** Laravel project as SC-DS1; simulate auth-extractor subagent failing twice (e.g., via API timeout simulation or by injecting a malformed prompt fixture)

**Trigger:** `/mega-sdd:scan-codebase <project_root>`

**Expected:**
- Step 2.2: 4 subagents dispatched
- auth-extractor: first attempt fails → auto-retry (single retry per spec §5.1)
- auth-extractor: second attempt also fails → soft halt `deep_scan_subagent_failed` emitted
- Other 3 subagents (rbac, ui-ux, libs) succeed
- Step 2.3: consolidator emits partial output:
  ```yaml
  starterkit_context:
    schema_version: 1.0
    partial: true
    partial_slices: [auth]
    rbac: {...}
    ui_ux: {...}
    libs: [...]
    # auth block ABSENT
  ```
- Pipeline CONTINUES (soft halt is warn-only, NOT chain-stopping)
- Handoff YAML includes `starterkit_context:` block with `partial: true` flag forwarded to consumers

### SC-DS6 — All-fail (API outage simulation)

**Setup:** Laravel project as SC-DS1; simulate ALL 4 subagents failing twice (API outage)

**Trigger:** `/mega-sdd:scan-codebase <project_root>`

**Expected:**
- Step 2.2: all 4 subagents fail (after retry)
- Step 2.3: hard halt `deep_scan_subagent_all_failed` emitted
- `.mega-sdd/codebase/starterkit-context.yaml` NOT written
- Any pre-existing `.mega-sdd/codebase/starterkit-context.yaml` preserved untouched
- Status: halted; chain STOPS (orchestrator does not auto-route to generate-intent)
- Handoff YAML: `status: halted`, `blockers: [{ type: deep_scan_subagent_all_failed, ... }]`
- User-facing message: "All 4 deep-scan subagents failed (likely API outage). Re-run /mega-sdd:scan-codebase later."
```

- [ ] **Step 8.2: Add 3 cases to generate-units.test.md**

Append to `tests/skill-triggering/generate-units.test.md`:

```markdown
---

## Iter 32 — Starterkit-aware unit generation cases (v2.6.0+)

### GU-SK1 — Unit gains starterkit Anchors + Hard Rules with Citations

**Setup:**
- Vault at `.mega-sdd/vaults/my-app/` with bound binding.md
- `.mega-sdd/codebase/starterkit-context.yaml` exists with:
  - `auth.lib: sanctum`, `auth.user_model: "App\\Models\\User"`
  - `ui_ux.layout_extends: "layouts.app"`, `ui_ux.notification_lib: sweetalert2`
  - `ui_ux.idioms: ["use document.addEventListener('DOMContentLoaded', ...) over $(document).ready", "responsive mobile-first (sm/md/lg breakpoints)"]`
- Vault includes a feature "Add user CRUD page" targeting `resources/views/users/index.blade.php`, `app/Http/Controllers/UserController.php`, `routes/web.php`

**Trigger:** `/mega-sdd:generate-units .mega-sdd/vaults/my-app`

**Expected:**
- Step 4 framework pack loaded (laravel-base-26.md)
- Step 4.7.a: starterkit-context.yaml loaded successfully
- Step 4.7.b: For the user-CRUD unit, `starterkit_relevance = [ui_ux, auth, libs]`:
  - ui_ux: target_files include `resources/views/**`
  - auth: target_files include `app/Http/Controllers/**` AND body mentions "user"
  - libs: target_files overlap with usage_hint of sanctum + sweetalert2
- Step 4.7.c: unit.anchors[] gains:
  - `resources/views/layouts/app.blade.php`
  - `app/Models/User.php`
  - `resources/views/components/`
- Step 4.7.d: unit.hard_rules[] gains (at minimum):
  - `{text: "MUST extend layouts.app ...", citation: "starterkit-context.yaml §ui_ux.layout_extends"}`
  - `{text: "MUST use SweetAlert2 for confirmations and notifications ...", citation: "starterkit-context.yaml §ui_ux.notification_lib"}`
  - `{text: "MUST follow starterkit idiom: use document.addEventListener('DOMContentLoaded', ...) over $(document).ready", citation: "starterkit-context.yaml §ui_ux.idioms"}`
  - `{text: "MUST follow starterkit idiom: responsive mobile-first (sm/md/lg breakpoints)", citation: "starterkit-context.yaml §ui_ux.idioms"}`
  - `{text: "MUST use auth guard 'sanctum' ...", citation: "starterkit-context.yaml §auth.guard"}`
- Step 4.7.e: unit.frontmatter gains:
  - `starterkit_context_consumed: true`
  - `starterkit_relevance: [ui_ux, auth, libs]`
- Unit footer §Citations section appends: `starterkit-context.yaml`
- Step 12.5 citation check PASSES (all starterkit-derived rules have citations)

### GU-SK2 — Greenfield vault (no starterkit-context.yaml) degrades gracefully

**Setup:**
- Vault at `.mega-sdd/vaults/greenfield-app/`
- `.mega-sdd/codebase/starterkit-context.yaml` does NOT exist (greenfield project)
- Vault has same feature spec as GU-SK1

**Trigger:** `/mega-sdd:generate-units .mega-sdd/vaults/greenfield-app`

**Expected:**
- Step 4.7.a: file absent → log "starterkit-context unavailable; emit framework-pack-only Anchors"
- Steps 4.7.b - 4.7.d SKIPPED
- Step 4.7.e: every unit's frontmatter gets `starterkit_context_consumed: false`, `starterkit_relevance: []`
- Unit.anchors[] populated from framework pack + binding (NO starterkit-specific anchors)
- Unit.hard_rules[] populated from framework pack only (NO starterkit-derived rules)
- NO halt emitted
- Step 12.5 citation check passes (no starterkit rules to validate)

### GU-SK3 — Missing citation triggers halt

**Setup:**
- Vault as GU-SK1 (starterkit-context.yaml present)
- Generated unit body (after Step 4.7) somehow contains a Hard Rule with `source: starterkit-context.yaml` but no `citation:` field (simulated: inject test fixture that bypasses Step 4.7.d's citation enforcement)

**Trigger:** generate-units Step 12.5 runs polished-prompt render pass

**Expected:**
- Step 12.5 citation check identifies the offending rule
- Halt `starterkit_rule_citation_missing` emitted with full envelope:
  ```yaml
  type: starterkit_rule_citation_missing
  source_skill: generate-units
  details:
    unit_id: U-003
    rule_text: "<text>"
    missing_citation: "starterkit-context.yaml §<path>"
    rule_index: 4
  next_action:
    type: edit_unit
    suggested_args: ["U-003"]
    hint: "Append 'Citation: starterkit-context.yaml §<path>' to Hard Rule #4"
  ```
- Unit U-003 is NOT written; pipeline STOPS (always-stop)
- Other units already-validated may have been written (partial completion is acceptable per existing generate-units halt semantics)
```

- [ ] **Step 8.3: Add 2 cases to execute-bolts.test.md**

Append to `tests/skill-triggering/execute-bolts.test.md`:

```markdown
---

## Iter 32 — Starterkit slice injection cases (v2.7.0+)

### EB-SK1 — T2.3 slice injection: UI-touching unit gets ui_ux + libs slices

**Setup:**
- Unit U-007 has `target_files: ["resources/views/users/index.blade.php", "app/Http/Controllers/UserController.php"]`
- Unit frontmatter: `starterkit_relevance: [ui_ux, libs]`
- `.mega-sdd/codebase/starterkit-context.yaml` exists (per GU-SK1 setup)

**Trigger:** `/mega-sdd:execute-bolts U-007`

**Expected:**
- Step 1.5.f: starterkit-context.yaml loaded
- Step 1.5.g: slice built with:
  - `slice.ui_ux` populated (layout_extends, notification_lib, idioms)
  - `slice.libs` filtered to libs whose usage_hint overlaps target_files
  - `slice.auth` ABSENT (not in starterkit_relevance)
  - `slice.rbac` ABSENT
- Step 1.5.h: bolt-dispatch-prompt T2.3 section populated with:
  - "UI/UX: extends=layouts.app, notification=sweetalert2, idioms=[use document.addEventListener...; responsive mobile-first...]"
  - "Libs in scope: sweetalert2@11.x (used in: resources/js/app.js, ...)"
  - NO "Auth:" line
  - NO "RBAC:" line
- T2.3 slice size ≤2KB (verify via byte count of injected section)
- Bolt subagent dispatched with prompt containing T2.3 section
- Bolt's generated code (verified via post-flight) uses `@extends('layouts.app')` and `Swal.fire(...)` patterns (matches starterkit)

### EB-SK2 — Slice exceeds 2KB budget → truncation order applies → halt if still over

**Setup:**
- Unit U-008 with `starterkit_relevance: [ui_ux, libs]`
- `.mega-sdd/codebase/starterkit-context.yaml` has:
  - ui_ux.idioms: 20 entries (large)
  - libs[]: 100 entries, 60 of which overlap U-008's target_files

**Trigger:** `/mega-sdd:execute-bolts U-008`

**Expected:**
- Step 1.5.g: initial slice exceeds 2KB
- Truncation step 1: libs[] truncated to top 10 by relevance score (overlap count)
- If still >2KB: idioms[] truncated to top 3
- IF still >2KB: halt `dispatch_prompt_too_large` (existing Iter 30 halt) emitted; bolt NOT dispatched; chain stops
- IF ≤2KB after truncation: bolt dispatched with truncated slice; T2.3 section ≤2KB
- Truncation event logged in execute-bolts metrics: `slice_truncated_count: 1`, `slice_truncation_levels: [libs, idioms]`
```

- [ ] **Step 8.4: Add 1 case to orchestrate-flow.test.md**

Append to `tests/skill-triggering/orchestrate-flow.test.md`:

```markdown
---

## Iter 32 — End-to-end starterkit_context propagation case (v2.5.1+)

### OF-SK1 — Full --auto pipeline propagates starterkit_context through all 5 phases

**Setup:**
- Laravel starterkit at `<project_root>` (Sanctum + Spatie/permission + Alpine + Tailwind + SweetAlert2)
- PRD at `<project_root>/prd.md` describing "User management feature"
- No prior vault, no prior codebase-map.md, no prior starterkit-context.yaml

**Trigger:** `/mega-sdd:auto`

**Expected pipeline:**
1. orchestrate-flow detects: PRD + starterkit + no vault → starterkit-first chain
2. Phase 1: `mega-sdd:scan-codebase` invoked
   - Deep-scan stage runs (4 subagents)
   - `.mega-sdd/codebase/starterkit-context.yaml` written
   - Handoff: `starterkit_context: { reused: false, framework: laravel, auth_lib: sanctum, ... }`
3. orchestrate-flow propagates handoff `starterkit_context:` into `metadata.starterkit_context`
4. Phase 2: `mega-sdd:generate-intent --scan=<codebase-map>` invoked
   - Receives `metadata.starterkit_context` in dispatch context
   - Vault generated under `.mega-sdd/vaults/<auto-generated-id>/`
   - Handoff: `starterkit_context:` passthrough (unchanged from scan-codebase)
5. Phase 3: `mega-sdd:bind-codebase` invoked
   - Handoff: `starterkit_context:` passthrough
6. Phase 4: `mega-sdd:generate-units` invoked
   - Step 4.7 fires for all generated units
   - Units that touch UI/auth/RBAC/libs gain starterkit anchors + Hard Rules
   - Handoff: `starterkit_context:` + 2 new metrics (`units_with_starterkit_anchors: <N>`, `units_with_starterkit_rules: <N>`)
7. Phase 5: `mega-sdd:execute-bolts --all --auto` invoked
   - Per-unit T2.3 slice injection for units with non-empty starterkit_relevance
   - Bolts produce code matching starterkit patterns (extends layouts.app, uses SweetAlert2, Spatie middleware)
   - Handoff: `starterkit_context:` + 2 new metrics (`bolts_used_starterkit_slice: <N>`, `slice_avg_size_kb: <X.X>`)

**Verification at each handoff boundary:**
- starterkit_context.framework field is `laravel` in ALL 5 handoffs
- starterkit_context.auth_lib field is `sanctum` in ALL 5 handoffs
- Final execute-bolts handoff metrics show non-zero bolts_used_starterkit_slice
- Final bolt-report.md files (per unit) cite `starterkit-context.yaml` in their context section
```

- [ ] **Step 8.5: Verify all 12 new cases present**

Run:
```bash
echo "=== scan-codebase (expect SC-DS1..SC-DS6) ==="
grep "^### SC-DS" tests/skill-triggering/scan-codebase.test.md
echo "=== generate-units (expect GU-SK1..GU-SK3) ==="
grep "^### GU-SK" tests/skill-triggering/generate-units.test.md
echo "=== execute-bolts (expect EB-SK1..EB-SK2) ==="
grep "^### EB-SK" tests/skill-triggering/execute-bolts.test.md
echo "=== orchestrate-flow (expect OF-SK1) ==="
grep "^### OF-SK" tests/skill-triggering/orchestrate-flow.test.md
```

Expected: 6 SC-DS lines + 3 GU-SK + 2 EB-SK + 1 OF-SK = 12 new cases.

- [ ] **Step 8.6: Commit**

```bash
git add tests/skill-triggering/scan-codebase.test.md \
        tests/skill-triggering/generate-units.test.md \
        tests/skill-triggering/execute-bolts.test.md \
        tests/skill-triggering/orchestrate-flow.test.md
git commit -m "$(cat <<'EOF'
test(iter-32): 12 new trigger test cases for starterkit-aware deep scan

- scan-codebase: SC-DS1 (fresh deep-scan) + SC-DS2 (cache reuse) +
                 SC-DS3 (cache invalidation) + SC-DS4 (no framework skip) +
                 SC-DS5 (subagent timeout + partial output) +
                 SC-DS6 (all-fail hard halt)
- generate-units: GU-SK1 (starterkit Anchors + Rules with citations) +
                  GU-SK2 (greenfield graceful degradation) +
                  GU-SK3 (missing citation triggers halt)
- execute-bolts: EB-SK1 (T2.3 slice injection — only relevant domains) +
                 EB-SK2 (slice >2KB truncation + halt)
- orchestrate-flow: OF-SK1 (end-to-end propagation through 5 pipeline phases)

Closes the iter-31 audit pattern: trigger tests now cover v2.6.0+ features
in-iter, not deferred.
EOF
)"
```

---

## Task 9: Scenario test (full pipeline integration)

**Files:**
- Create: `tests/scenarios/scenario-8-starterkit-aware-generation.md`

- [ ] **Step 9.1: Write scenario-8 file**

Write to `tests/scenarios/scenario-8-starterkit-aware-generation.md`:

```markdown
# Scenario 8 — Starterkit-Aware Generation (full pipeline)

> Integration scenario covering scan-codebase deep-scan → generate-units consumption → execute-bolts T2 injection. Validates Iter 32 v3.23.0 end-to-end.

## Prerequisites

- Laravel starterkit project at `<project_root>` with:
  - `composer.json` includes `laravel/sanctum` (^4.0), `spatie/laravel-permission` (^6.0)
  - `package.json` includes `alpinejs` (^3.0), `tailwindcss` (^3.0), `sweetalert2` (^11.0)
  - `tailwind.config.js` exists with custom `theme.extend.colors.primary`
  - `resources/views/layouts/app.blade.php` exists
  - `resources/js/app.js` imports SweetAlert2 and uses `document.addEventListener('DOMContentLoaded', ...)`
  - `app/Models/User.php` uses `HasRoles` trait (Spatie/permission)
  - `database/seeders/RoleSeeder.php` creates `admin` and `user` roles
- PRD at `<project_root>/prd.md` describing "User management feature with CRUD page"
- mega-sdd plugin v3.23.0 installed (the version this scenario validates)

## Scenario steps

### Step 1: Invoke /mega-sdd:auto

```
/mega-sdd:auto
```

Orchestrate-flow detects PRD + starterkit + no vault → starterkit-first chain (Phase 1: scan-codebase).

### Step 2: Verify scan-codebase deep-scan produced starterkit-context.yaml

```bash
test -f .mega-sdd/codebase/starterkit-context.yaml && cat .mega-sdd/codebase/starterkit-context.yaml | head -50
```

**Assertions:**
- File exists
- `starterkit_context.framework` == `laravel`
- `starterkit_context.auth.lib` == `sanctum`
- `starterkit_context.rbac.lib` == `spatie/permission`
- `starterkit_context.ui_ux.notification_lib` == `sweetalert2`
- `starterkit_context.libs[]` includes ≥3 entries (laravel/sanctum, spatie/laravel-permission, sweetalert2)
- `cache_key.composer_lock_sha256` is a 64-char hex string
- `_source:` arrays present for each block (anti-halu citation rail)

### Step 3: Verify generate-units consumed starterkit-context

```bash
ls .mega-sdd/vaults/*/units/
grep -l "starterkit_context_consumed: true" .mega-sdd/vaults/*/units/U-*.md | head -3
```

**Assertions:**
- ≥1 unit file exists in `units/` directory
- ≥1 unit has `starterkit_context_consumed: true` in frontmatter
- That unit's body has `## Hard Rules` section with ≥1 rule citing `starterkit-context.yaml §<path>`
- That unit's anchors[] includes `resources/views/layouts/app.blade.php` (if it's a UI-touching unit)

### Step 4: Verify execute-bolts injected T2.3 slices

```bash
ls .mega-sdd/vaults/*/bolts/
grep -l "Starterkit context (relevant to this unit)" .mega-sdd/vaults/*/bolts/U-*/dispatch-prompt.md | head -3
```

**Assertions:**
- ≥1 bolt-report exists in `bolts/` directory
- ≥1 bolt's dispatch-prompt contains the T2.3 "Starterkit context (relevant to this unit)" section
- The slice in that section is ≤2KB (verify via byte count)

### Step 5: Verify generated code matches starterkit patterns

For a UI-CRUD bolt (e.g., user-management feature):

```bash
grep "@extends('layouts.app')" resources/views/users/index.blade.php
grep "Swal.fire" resources/js/users.js
grep "middleware('role:" routes/web.php
grep "document.addEventListener('DOMContentLoaded'" resources/js/users.js
```

**Assertions:**
- Generated Blade view uses `@extends('layouts.app')` (matches starterkit layout_extends)
- Generated JS uses `Swal.fire(...)` for confirmations (matches starterkit notification_lib)
- Generated routes use Spatie middleware (e.g., `middleware('role:admin')`)
- Generated JS uses `document.addEventListener('DOMContentLoaded', ...)` (matches starterkit idiom)

### Step 6: Verify cache reuse on re-run

```bash
mtime_before=$(stat -f %m .mega-sdd/codebase/starterkit-context.yaml)
/mega-sdd:scan-codebase <project_root>
mtime_after=$(stat -f %m .mega-sdd/codebase/starterkit-context.yaml)
echo "Before: $mtime_before; After: $mtime_after"
```

**Assertions:**
- mtime_before == mtime_after (cache hit; file not rewritten)
- Handoff YAML from second scan-codebase invocation has `starterkit_context: reused: true`

## Pass criteria

ALL of:
- starterkit-context.yaml exists with ≥3 detected libs
- Generated units cite starterkit-context.yaml in ≥1 Hard Rule
- Executed bolts produce code using layouts.app + SweetAlert2 + Spatie middleware
- Re-scan reuses cache (no subagent re-dispatch; mtime unchanged)

## Failure modes to watch

- Subagent timeout → expect `deep_scan_subagent_failed` soft halt + partial output (verify partial_slices: [...] populated)
- All subagents fail → expect `deep_scan_subagent_all_failed` hard halt + no starterkit-context.yaml written
- Generated code missing SweetAlert2 despite starterkit having it → BUG in T2.3 slice injection
- Generated unit Hard Rule missing Citation → `starterkit_rule_citation_missing` halt expected

## Related artifacts

- `docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md` (design source)
- `docs/superpowers/plans/2026-05-24-iter-32-starterkit-aware-deep-scan.md` (this plan)
- `plugins/mega-sdd/references/starterkit-context-schema.md` (canonical schema)
- `plugins/mega-sdd/references/lib-patterns/laravel/*.md` (detection catalogs)
```

- [ ] **Step 9.2: Verify scenario-8 written**

Run:
```bash
test -f tests/scenarios/scenario-8-starterkit-aware-generation.md && wc -l tests/scenarios/scenario-8-starterkit-aware-generation.md
```
Expected: ≥80 lines.

- [ ] **Step 9.3: Commit**

```bash
git add tests/scenarios/scenario-8-starterkit-aware-generation.md
git commit -m "$(cat <<'EOF'
test(iter-32): scenario-8 — full-pipeline starterkit-aware generation

Integration scenario covering Iter 32 v3.23.0 end-to-end:
1. scan-codebase deep-scan produces starterkit-context.yaml
2. generate-units consumes it (Step 4.7 Anchors + Rules + citations)
3. execute-bolts injects T2.3 slices into bolt-dispatch-prompts
4. Generated code matches starterkit patterns (layouts.app + SweetAlert2 +
   Spatie middleware + DOMContentLoaded idiom)
5. Re-scan reuses cache (mtime unchanged; reused: true in handoff)

Pass criteria + failure modes documented for field test on
user's base-laravel-26 starterkit (spec §6.4 acceptance criterion #10).
EOF
)"
```

---

## Task 10: Version bumps + CHANGELOG + README + final push

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json` (3.22.0 → 3.23.0)
- Modify: `CHANGELOG.md` (+ full Iter 32 entry)
- Modify: `plugins/mega-sdd/README.md` (+ What's new in v3.23.0)

- [ ] **Step 10.1: Bump plugin version**

Edit `plugins/mega-sdd/.claude-plugin/plugin.json`. Find the `"version"` field and change:

```json
"version": "3.23.0",
```

(From `3.22.0` to `3.23.0`.)

- [ ] **Step 10.2: Add CHANGELOG entry**

Edit `CHANGELOG.md`. Add a new entry at the TOP (after the file header, above the existing `[3.22.0]` entry):

```markdown
## [3.23.0] - 2026-05-24

### Iter 32 — Starterkit-Aware Deep Scan (autonomous, default-on)

**Feature iter:** producer + consumer ship in-iter per propagation directive. No follow-up audit closure needed.

**Skills bumped:**
- `scan-codebase` 2.5.0 → 2.6.0 (Step 2 deep-scan stage + 4 parallel subagents + cache + 3 new halts)
- `generate-units` 2.5.4 → 2.6.0 (Step 4.7 starterkit Anchors + Hard Rules + Step 12.5 citation check + 1 new halt)
- `execute-bolts` 2.6.0 → 2.7.0 (Step 1.5.f-h T2 slice injection)
- `orchestrate-flow` 2.5.0 → 2.5.1 (halt taxonomy: 4 new halts registered + SOFT halts subsection added)

**New plugin files (7):**
- `references/starterkit-context-schema.md` — canonical YAML schema for starterkit-context.yaml (~150 LOC)
- `references/lib-patterns/README.md` — lib-pattern catalog index + framework extension protocol
- `references/lib-patterns/laravel/auth-libs.md` — Sanctum / Breeze / Jetstream / Fortify / Passport detection
- `references/lib-patterns/laravel/rbac-libs.md` — Spatie/permission / laravel-permission / custom detection
- `references/lib-patterns/laravel/ui-libs.md` — JS/CSS/notification/icon/datatable libs detection
- `references/lib-patterns/laravel/generic-libs.md` — queue/cache/log/test/http/misc catalog
- `skills/scan-codebase/references/deep-scan-prompts.md` — 4 subagent prompt templates

**New test files (1):**
- `tests/scenarios/scenario-8-starterkit-aware-generation.md`

**Modified reference docs:**
- `skills/generate-intent/references/vault-contract.md` — halt type enum extended (+4 types)
- `skills/orchestrate-flow/references/handoff-contract.md` — `starterkit_context:` schema field defined; per-skill examples updated for scan-codebase, generate-units, execute-bolts
- `skills/execute-bolts/references/bolt-dispatch-prompt.md` — T2.3 "Starterkit context (relevant slice)" section added
- `references/paths.md` — row for `.mega-sdd/codebase/starterkit-context.yaml`

**4 new halt types** (registered across 4 surfaces: SKILL.md + vault-contract enum + orchestrate-flow taxonomy + handoff-contract per-skill examples — synchronized in one commit per iter-31 audit lessons):
- `deep_scan_subagent_failed` (soft, scan-codebase) — single subagent failed; auto-retry; partial output on second failure
- `deep_scan_cache_corrupt` (soft, scan-codebase) — starterkit-context.yaml YAML parse failed; cache auto-invalidated
- `deep_scan_subagent_all_failed` (ALWAYS STOP, scan-codebase) — all 4 subagents failed; user re-runs later
- `starterkit_rule_citation_missing` (ALWAYS STOP, generate-units) — starterkit-derived Hard Rule lacks Citation; user edits unit

**Trigger test coverage (+12 cases):**
- scan-codebase: SC-DS1..SC-DS6 (fresh deep-scan, cache reuse, cache invalidation, no-framework skip, subagent timeout + partial, all-fail hard halt)
- generate-units: GU-SK1..GU-SK3 (starterkit Anchors/Rules with citations, greenfield graceful degradation, missing citation halt)
- execute-bolts: EB-SK1..EB-SK2 (T2.3 slice injection only for relevant domains, slice >2KB truncation)
- orchestrate-flow: OF-SK1 (end-to-end starterkit_context propagation through 5 pipeline phases)

**Architecture summary:**
- `scan-codebase` Step 2 deep-scan stage runs automatically when framework confidence ≥ MEDIUM. Dispatches 4 parallel `sonnet` subagents (auth/rbac/ui-ux/libs). Consolidator writes `.mega-sdd/codebase/starterkit-context.yaml`.
- Cache via lock-file sha256 (composer.lock + package-lock.json | yarn.lock | pnpm-lock.yaml). Re-scan with unchanged deps: 0sec.
- `generate-units` Step 4.7 derives per-unit starterkit Anchors + Hard Rules with mandatory citations.
- `execute-bolts` Step 1.5.f-h injects relevant slice (per `unit.starterkit_relevance`) into bolt-dispatch-prompt T2.3 section. Slice budget ≤2KB. Truncation order: libs[] → idioms[] → halt.
- User's standing prefs (SweetAlert2, `document.addEventListener` over jQuery ready, responsive mobile-first) flow into Hard Rules automatically when detected by ui-ux-extractor.

**Anti-halu rails (new):**
- No-fabrication: `lib: not_detected` is valid; subagents never guess
- Citation: every output field tied to `_source: [<file>, ...]`
- Read-only: subagents have no mutating tool access
- Citation-mandatory: every starterkit-derived Hard Rule MUST cite `starterkit-context.yaml §<path>`
- Slice-budget: T2 starterkit slice ≤2KB; truncation order enforced

**Iter-31 audit findings preemptively addressed:**
- Producer-only ship pattern: consumer skills (generate-units, execute-bolts) ship IN this iter
- Halt taxonomy gap: 4 new halts registered across all 4 surfaces in Task 4 (single synchronized commit)
- Test coverage gap: 12 new trigger test cases + 1 scenario test ship in-iter
- Stale skill name fossils: zero `grand-design-spec` / `vault-diff` / `drift-detect` in new files (canonical names only)

**Plugin:** v3.22.0 → v3.23.0

**Spec:** `docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md`
**Plan:** `docs/superpowers/plans/2026-05-24-iter-32-starterkit-aware-deep-scan.md`
```

- [ ] **Step 10.3: Add "What's new in v3.23.0" to plugins/mega-sdd/README.md**

Edit `plugins/mega-sdd/README.md`. Locate the "What's new" section (typically near the top). Add a new subsection at the top of "What's new":

```markdown
### v3.23.0 (Iter 32) — Starterkit-Aware Deep Scan

mega-sdd now **automatically** captures your starterkit's actual auth/RBAC/UI-UX/library patterns and feeds them through the pipeline — no flags, no config.

**What changed:**
- `scan-codebase` v2.6.0+ runs a deep-scan stage automatically when a framework is detected. 4 parallel subagents read your manifests + actual code to extract: which auth lib (Sanctum/Breeze/Jetstream/Fortify/Passport), which RBAC lib (Spatie/permission/custom), which UI stack (Alpine/Livewire/Inertia + Tailwind/Bootstrap + SweetAlert/Toastr), and your full library inventory with usage hints.
- Output: `.mega-sdd/codebase/starterkit-context.yaml` — canonical structured context, cached via lock-file hashing (re-scan with unchanged deps is 0sec).
- `generate-units` v2.6.0+ reads the context and adds starterkit-specific Anchors and Hard Rules to each unit with mandatory citations. Your unit specs now know about `layouts.app`, `User` model FQCN, your Spatie middleware names, your SweetAlert2 component path.
- `execute-bolts` v2.7.0+ injects a relevant slice (≤2KB, per-unit) into the bolt-dispatch-prompt T2 tier. Bolts generate code that matches your starterkit by default — uses your layout, your notification lib, your auth guard.

**Why this matters:**
- Before: generated units used framework defaults; bolts produced code that didn't always match your starterkit's libs.
- After: your starterkit's choices propagate automatically. Standing prefs like SweetAlert2 + `document.addEventListener` over `$(document).ready` + responsive mobile-first flow into Hard Rules with citations — no per-session reminder needed.

**Autonomous by design:**
- Zero user flags. Zero config. Triggers automatically when `scan-codebase` detects a framework at MEDIUM+ confidence.
- Graceful degradation: subagent timeouts → partial output; all-fail → preserve prior cache + halt for retry; no framework detected → skip silently.

See [docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md](../../docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md) for the full design.
```

- [ ] **Step 10.4: Verify all version + CHANGELOG entries present**

Run:
```bash
echo "=== plugin.json version ==="
grep '"version"' plugins/mega-sdd/.claude-plugin/plugin.json
echo "=== CHANGELOG top entry ==="
head -10 CHANGELOG.md
echo "=== README What's new ==="
grep -A 2 "v3.23.0\|Iter 32" plugins/mega-sdd/README.md | head -10
```

Expected:
- plugin.json: `"version": "3.23.0"`
- CHANGELOG top entry: `## [3.23.0] - 2026-05-24` with Iter 32 header
- README has v3.23.0 (Iter 32) subsection

- [ ] **Step 10.5: Run final cross-reference verification**

Run:
```bash
echo "=== All 4 new halt types appear across 4 surfaces ==="
for halt in deep_scan_subagent_failed deep_scan_cache_corrupt deep_scan_subagent_all_failed starterkit_rule_citation_missing; do
  echo "  $halt:"
  echo -n "    vault-contract.md type enum: "
  grep -c "$halt" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
  echo -n "    orchestrate-flow taxonomy: "
  grep -c "$halt" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
  echo -n "    skill body (emitter): "
  if [ "$halt" = "starterkit_rule_citation_missing" ]; then
    grep -c "$halt" plugins/mega-sdd/skills/generate-units/SKILL.md
  else
    grep -c "$halt" plugins/mega-sdd/skills/scan-codebase/SKILL.md
  fi
done

echo "=== starterkit_context: in handoff-contract ==="
grep -c "starterkit_context:" plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md

echo "=== No stale skill names in new files ==="
grep -rn "grand-design-spec\|vault-diff\|drift-detect" plugins/mega-sdd/references/lib-patterns/ plugins/mega-sdd/references/starterkit-context-schema.md plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md
echo "(no output = no stale names — PASS)"
```

Expected:
- Every halt appears in vault-contract.md ≥1 time
- Every halt appears in orchestrate-flow ≥1 time
- Every halt appears in its emitting skill ≥3 times (halt section + handoff + step body)
- starterkit_context: ≥4 matches in handoff-contract (schema + 3 per-skill examples)
- Grep for stale names: empty output (no matches)

- [ ] **Step 10.6: Commit + push**

```bash
git add plugins/mega-sdd/.claude-plugin/plugin.json CHANGELOG.md plugins/mega-sdd/README.md
git commit -m "$(cat <<'EOF'
release(iter-32): mega-sdd v3.23.0 — starterkit-aware deep scan

scan-codebase v2.6.0 + generate-units v2.6.0 + execute-bolts v2.7.0 +
orchestrate-flow v2.5.1 ship together as Iter 32. Producer + consumer
in-iter; no follow-up audit closure needed.

Headline capability: mega-sdd now automatically captures starterkit's
actual auth/RBAC/UI-UX/library patterns into structured context, then
propagates through the full pipeline. Generated code matches starterkit
by default — no per-session user reminders.

Plugin v3.22.0 -> v3.23.0
EOF
)"

git push origin main
```

- [ ] **Step 10.7: Verify final state**

Run:
```bash
git log --oneline -12
```

Expected: ~10 Iter 32 commits visible (one per task) at top, ending with the v3.23.0 release commit pushed to origin/main.

---

## Self-Review

### 1. Spec coverage

Iterating spec sections vs plan tasks:

| Spec section | Implementing task(s) |
|---|---|
| §1 Architecture overview (skill version bumps, plugin v3.23.0) | Tasks 5/6/7/10 (version bumps) + Task 10 (plugin.json) |
| §2.1 4 deep-scan subagents | Task 3 (prompt templates) + Task 5 Step 5.2 (dispatch in scan-codebase Step 2.2) |
| §2.2 starterkit-context.yaml canonical schema | Task 1 (schema doc) |
| §2.3 Lib-pattern reference files (5 files) | Task 2 (creates all 5) |
| §2.4 New files inventory (7 files) | Tasks 1+2+3 create all 7 |
| §3.1 Trigger logic (auto-detect via framework.confidence) | Task 5 Step 5.2 (Step 2.0 trigger check) |
| §3.2 Cache mechanism (composer.lock + package.lock sha256) | Task 5 Step 5.2 (Step 2.1 cache check) |
| §3.3 Orchestrate-flow integration (handoff field passthrough) | Task 4 (handoff-contract schema) + Task 5 (handoff emission) |
| §3.4 Performance budget | (no implementation task — documented in spec) |
| §4.1 generate-units Step 4.7 (5 sub-steps) | Task 6 Step 6.2 |
| §4.2 execute-bolts T2 slice injection (Step 1.5.f-h) | Task 7 Step 7.2 + 7.3 |
| §4.3 Anti-halu rail (Step 12.5 citation check) | Task 6 Step 6.3 |
| §4.4 Handoff propagation chain (5 phases) | Task 4 + Task 5/6/7 (handoff YAML updates) + Task 8 OF-SK1 (verification test) |
| §4.5 Modified plugin files inventory (8 files) | Tasks 4/5/6/7 cover all 8 |
| §5.1 Canonical halt registry (4 halts × 4 surfaces) | Task 4 (cross-surface sync) + Task 5/6 (emitter-side body) |
| §5.2 Halt YAML envelope (canonical schema) | Task 5 Step 5.3 + Task 6 Step 6.5 (envelopes shown) |
| §5.3 Error handling matrix (7 conditions) | Task 5 Step 5.2 covers all 7 in Step 2 procedure |
| §5.4 Anti-halu rails (3 new) | Task 3 (in prompts) + Task 5 Step 5.6 (scan-codebase rails) + Task 7 Step 7.5 (execute-bolts rails) |
| §5.5 Audit-pattern prevention checklist (6 items) | Built into task acceptance: Task 4 (halts × 4 surfaces) + Task 6 (consumer in-iter) + Task 8 (tests in-iter) + Task 1-3 (canonical names check via grep in Step 10.5) |
| §6.1 Trigger tests (12 cases) | Task 8 (creates all 12) |
| §6.2 Scenario test (scenario-8) | Task 9 |
| §6.3 Lib-pattern detection fixtures (inline) | Task 2 (each lib-pattern file has "Detection examples" section) |
| §6.4 Field test (user's base-laravel-26) | Documented in Task 9 scenario-8 (Pass criteria + Failure modes); user runs manually post-merge |
| §6.5 Test coverage summary | Task 8 + Task 9 produce all artifacts |
| Acceptance criteria 1-12 | All covered (1: Task 10; 2-3: Task 5; 4: Task 6; 5: Task 7; 6: Task 4; 7: Task 4 + Step 10.5 verification; 8: Tasks 1-3; 9: Tasks 8-9; 10: scenario-8 documents field test step; 11: Step 10.5 grep verification; 12: Task 3 prompts + Task 5/6/7 anti-halu rails) |

**Gaps found:** None. All spec sections mapped to plan tasks.

### 2. Placeholder scan

Searched plan for `TBD`, `TODO`, `implement later`, `fill in details`, `appropriate error handling`, `handle edge cases`, `Similar to Task N`:
- Result: zero matches. All steps have concrete content + exact code/text.

### 3. Type consistency

Checked names across tasks:
- `starterkit-context.yaml` (lowercase, dash, .yaml extension) — consistent across Tasks 1, 4, 5, 6, 7, 8, 9, 10
- `starterkit_context:` (snake_case, colon — YAML key) — consistent
- `starterkit_relevance: []` (frontmatter array) — consistent across Tasks 6, 7, 8
- `starterkit_context_consumed: <bool>` (frontmatter) — consistent across Tasks 6, 8
- 4 halt type names — consistent verbatim across Tasks 4, 5, 6, 8 (no typos)
- Subagent names: `auth-extractor`, `rbac-extractor`, `ui-ux-extractor`, `libs-extractor` (hyphenated) — consistent across Tasks 3, 5
- Domain enum values: `auth | rbac | ui_ux | libs` (underscore, not hyphen for relevance flags) — consistent
- Step numbering: Step 4.7.a-e in generate-units; Step 2.0-2.4 + Step 5.2-5.6 in scan-codebase; Step 1.5.f-h in execute-bolts — consistent
- Skill versions: scan-codebase 2.6.0, generate-units 2.6.0, execute-bolts 2.7.0, orchestrate-flow 2.5.1 — consistent everywhere

**Issues found + fixed inline:**
- None. All type references reconciled at write time by following the spec as canonical source.

---

**End of plan.**

Total tasks: 10
Estimated execution time: ~14-18 hours total
- Task 1 (schema doc): ~1 hr
- Task 2 (5 lib-pattern files): ~3 hr
- Task 3 (prompt templates): ~2 hr
- Task 4 (cross-surface halt sync): ~1.5 hr
- Task 5 (scan-codebase): ~3 hr
- Task 6 (generate-units): ~2 hr
- Task 7 (execute-bolts): ~1.5 hr
- Task 8 (trigger tests): ~2 hr
- Task 9 (scenario): ~0.5 hr
- Task 10 (version bumps + release): ~0.5 hr

Risk areas:
- Task 4 (halt sync): if any of 4 surfaces drift, iter-31 pattern recurs — verification step 4.8 catches this
- Task 5 (scan-codebase Step 2): largest single skill modification (~300 lines added); may need split if subagent context tight
- Task 6 + 7 (consumers): in-iter consumer wiring is the standing directive — verification step 8.5 confirms 12 test cases ship in-iter
