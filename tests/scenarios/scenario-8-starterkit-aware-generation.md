# Scenario 8 — Starterkit-Aware Generation (full pipeline)

**Time**: ~30 min
**When to use**: Validate that the pipeline correctly captures a Laravel starterkit's patterns and propagates them through generate-units (Anchors + Hard Rules) and execute-bolts (T2 slice injection) to produce code that matches the starterkit by default.

> Integration scenario covering scan-codebase deep-scan → generate-units consumption → execute-bolts T2 injection. The deep-scan is a scan-codebase feature, so this scenario runs the **classic spine** (`--classic`); on the express default, pack matching happens via the GROUND matcher without a scan phase.

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
- mega-sdd plugin v6+ installed

## Scenario steps

### Step 1: Invoke the front door on the classic spine

```
/mega-sdd --classic
```

The front door detects PRD + starterkit + no vault → classic starterkit-first chain (Phase 1: scan-codebase).

### Step 2: Verify scan-codebase deep-scan produced starterkit-context.yaml

```bash
test -f .mega-sdd/codebase/starterkit-context.yaml && cat .mega-sdd/codebase/starterkit-context.yaml | head -50
```

**Assertions:**
- File exists
- `starterkit_context.framework` == `laravel`
- `starterkit_context.auth.lib` == `sanctum`
- `starterkit_context.authz.lib` == `spatie/permission`
- `starterkit_context.ui_ux.notification_lib` == `sweetalert2`
- `starterkit_context.libs[]` includes ≥3 entries (laravel/sanctum, spatie/laravel-permission, sweetalert2)
- `cache_key.composer_lock_sha256` is a 64-char hex string
- `_source:` arrays present for each block (anti-halu citation rail)

Deep-scan is triggered automatically by scan-codebase Step 10.5 when framework confidence ≥ MEDIUM.

### Step 3: Verify generate-units consumed starterkit-context

```bash
ls .mega-sdd/vaults/*/units/
grep -l "starterkit_context_consumed: true" .mega-sdd/vaults/*/units/U-*.md | head -3
```

**Assertions:**
- ≥1 unit file exists in `units/` directory
- ≥1 unit has `starterkit_context_consumed: true` in frontmatter (added by generate-units Step 7.7)
- That unit's body has `## Hard Rules` section with ≥1 rule citing `starterkit-context.yaml §<path>`
- That unit's anchors[] includes `resources/views/layouts/app.blade.php` (if it's a UI-touching unit)

### Step 4: Verify execute-bolts injected T2.3 slices

```bash
ls .mega-sdd/vaults/*/bolts/
grep -l "Starterkit context (relevant to this unit)" .mega-sdd/vaults/*/bolts/U-*/dispatch-prompt.md | head -3
```

**Assertions:**
- ≥1 bolt-report exists in `bolts/` directory
- ≥1 bolt's dispatch-prompt contains the T2.3 "Starterkit context (relevant to this unit)" section (injected by execute-bolts Step 4.5.b-starterkit)
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
# say "scan codebase ini" (phrase-routes to scan-codebase; typed skill commands were removed at 6.0.0)
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
- Generated code missing SweetAlert2 despite starterkit having it → BUG in T2.3 slice injection (execute-bolts Step 4.5.b-starterkit)
- Generated unit Hard Rule missing Citation → `starterkit_rule_citation_missing` halt expected (generate-units Step 7.7)

## Field test (real starterkit verification)

Run this scenario against the user's actual starterkit (spec §6.4 acceptance criterion #10):

```bash
cd /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/base-laravel-26
# in Claude Code: say "scan codebase ini"
cat .mega-sdd/codebase/starterkit-context.yaml
```

Expected outcomes for `base-laravel-26`:
- `auth.lib` correctly identifies auth lib in use
- `authz.lib` == `spatie/permission` (if Spatie is installed)
- `ui_ux.notification_lib` == `sweetalert2` (per standing user pref)
- `ui_ux.idioms` includes `"use document.addEventListener('DOMContentLoaded', ...) over $(document).ready"`
- `ui_ux.idioms` includes `"responsive mobile-first (sm/md/lg breakpoints)"`
- Subsequent `generate-units` on a real feature PRD produces units that USE those libs by default
- Subsequent `execute-bolts` produces code matching starterkit patterns (layout, notification lib, auth guard)

This field test validates the spec against real-world data — confirms the design works on the actual project, not just theoretical Laravel.

## Related artifacts

- `docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md` (design source)
- `docs/superpowers/plans/2026-05-24-iter-32-starterkit-aware-deep-scan.md` (this plan)
- `plugins/mega-sdd/references/starterkit-context-schema.md` (canonical schema)
- `plugins/mega-sdd/references/lib-patterns/laravel/*.md` (detection catalogs)
