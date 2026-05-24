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
- If multiple auth libs match fingerprints, emit the highest-precedence as auth.lib:. Do NOT list others here — they will be picked up by libs-extractor.
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
- For unrecognized RBAC libs (any third-party lib that has User trait or Role/Permission models but doesn't match Spatie/permission or known alternates), classify as lib: custom — NEVER invent a new enum value. The libs-extractor will catalog the unrecognized lib name in libs[].
- Bind every field to a citation in _source[]
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
2. js_framework: check package.json for alpinejs / livewire / inertia / vue / react; if @inertiajs/* is present, emit js_framework: inertia REGARDLESS of vue/react also being present (Inertia wraps them — Inertia is the dominant framework; vue/react then appears in libs[] as the underlying view layer). Otherwise pick highest-confidence match.
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
- Bind every field to a citation in _source[]
- not_detected is a valid value for notification_lib, icon_lib, datatable_lib — never fabricate
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
- Bind every lib entry to manifest evidence — if a lib is not in composer.json or package.json, do NOT emit it
```

---

## Subagent dispatch pattern (for reference)

`scan-codebase` Step 2.2 dispatches all 4 subagents IN PARALLEL via a single message with 4 Agent tool calls (per `superpowers:subagent-driven-development` convention for parallel-safe work). Each Agent call uses the appropriate prompt template above with placeholder substitutions; model resolved from `plugins/mega-sdd/references/model-tiers.md` §<role-name> (default sonnet for all 4 extractors) OR from handoff metadata.model_tiers if override applied.

Consolidator (Step 2.3) collects 4 YAML responses, validates each against `starterkit-context-schema.md`, drops malformed slices (with `partial_slices:` updated), merges into single `starterkit-context.yaml`, computes `cache_key.composer_lock_sha256` + `package_lock_sha256`, and writes the file atomically.

## Anti-halu rails (cross-cutting)

All 4 prompts include the same 3 rails verbatim:
1. **No-fabrication**: emit `not_detected` / empty arrays when detection fails
2. **Citation**: every output field tied to `_source: [<file>, ...]`
3. **READ-ONLY**: no Edit / Write / mutating Bash operations

Subagents that violate these rails (e.g., emit a lib without citation) cause the consolidator to drop their slice from the merged output. The dropped slice is logged + the affected domain marked in `partial_slices:`.
