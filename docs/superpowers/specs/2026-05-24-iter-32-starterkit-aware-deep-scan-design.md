# Iter 32 — Starterkit-Aware Deep Scan (autonomous, default-on)

**Status:** Design approved 2026-05-24
**Plugin target:** v3.22.0 → v3.23.0
**Iter type:** Feature iter (producer + consumer in-iter per propagation directive)
**Predecessor context:** Iter 31 v3.22.0 full pipeline audit (`docs/superpowers/audits/2026-05-24-iter-31-v3.22.0-full-pipeline-audit.md`)

---

## Background and motivation

`scan-codebase` v2.5.0 detects which framework a project uses (composer.json, package.json, manifest probes → `codebase-map.md §7 Framework`) but produces only 5 fields: `name`, `version`, `confidence`, `pack_path`, `detection_source`. It does not introspect the starterkit's actual feature stack: which auth library is used (Sanctum vs Breeze vs Jetstream), which RBAC library (Spatie/permission vs custom), which UI/UX stack (Alpine+Tailwind+SweetAlert vs Livewire+Bootstrap vs Inertia+Vue), or which libraries appear in code.

Framework convention packs (`references/framework-conventions/laravel-base-26.md` = 393 LOC) cover **static** conventions deeply — file layout, naming, base classes, traits, ERD rules, forbidden patterns — but include **zero** coverage of runtime feature patterns. Generated units consequently lack starterkit-specific Anchors and Hard Rules, and executed bolts produce code that may not match the starterkit's chosen libs and idioms.

User goal: when mega-sdd encounters a project with an existing starterkit, it should automatically capture that starterkit's auth flow, RBAC pattern, UI/UX templates, and library inventory so that generated units cite those patterns and executed bolts produce code that matches them — without any user-visible flag, config, or trigger. The requirement is framework-agnostic; Laravel is the reference example.

This iter closes the gap. `scan-codebase` gains a deep-scan stage that runs automatically when a framework is detected, dispatches 4 parallel subagents (auth, rbac, ui-ux, libs), and writes a single structured `starterkit-context.yaml`. Consumer skills (`generate-units`, `execute-bolts`) consume that YAML in the same iter — no producer-only ship.

---

## §1 Architecture overview

`scan-codebase` v2.6.0 gains a built-in **deep-scan stage** as a new Step 2 (between existing surface scan and codebase-map.md emission). The stage dispatches 4 parallel subagents — one per domain (auth / rbac / ui-ux / libs) — that read the actual starterkit code via the Read tool, reason about patterns, and return structured YAML slices. A consolidator step merges the 4 slices into a single `.mega-sdd/codebase/starterkit-context.yaml`. The handoff carries a `starterkit_context:` block forward through the chain. `generate-units` v2.6.0 consumes the YAML to add starterkit-specific Anchors and Hard Rules per unit. `execute-bolts` v2.7.0 T2 tier auto-injects the relevant slice per unit (slice budget ≤2KB) into the bolt-dispatch prompt.

No new skill. No user flag. No setting. Just deeper context flowing through the existing pipeline.

```
┌──────────────────────────────────────────────────────────────┐
│ orchestrate-flow Phase 1: scan-codebase (DEFAULT-ON deep)    │
│                                                              │
│  Step 1: surface scan (existing) → codebase-map.md §1-§7     │
│  Step 2: deep-scan stage (NEW, auto when framework detected) │
│     │                                                        │
│     ├──► auth-extractor    subagent (parallel)               │
│     ├──► rbac-extractor    subagent (parallel)               │
│     ├──► ui-ux-extractor   subagent (parallel)               │
│     └──► libs-extractor    subagent (parallel)               │
│     │                                                        │
│     ▼                                                        │
│  Step 3: consolidate → starterkit-context.yaml               │
│  Step 4: emit handoff with starterkit_context: block         │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│ generate-units (consumer)                                    │
│  • Reads starterkit-context.yaml                             │
│  • Adds starterkit Anchors to each unit                      │
│  • Adds starterkit Hard Rules (with citations)               │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│ execute-bolts (consumer)                                     │
│  • T2 tier auto-injects relevant starterkit slice per unit   │
│    (e.g., unit modifies Blade view → inject UI/UX + Libs;    │
│     skip Auth/RBAC unless touched)                           │
└──────────────────────────────────────────────────────────────┘
```

### Skill version bumps

| Skill | From | To | Reason |
|---|---|---|---|
| `scan-codebase` | 2.5.0 | 2.6.0 | Deep-scan stage |
| `generate-units` | 2.5.4 | 2.6.0 | Starterkit Anchors + Hard Rules |
| `execute-bolts` | 2.6.0 | 2.7.0 | T2 starterkit slice injection |
| `orchestrate-flow` | 2.5.0 | 2.5.1 | Handoff propagation (4 new halt types in taxonomy) |

**Plugin:** v3.22.0 → v3.23.0.

### New plugin files (7)

| Path | Purpose | LOC est. |
|---|---|---|
| `plugins/mega-sdd/references/lib-patterns/README.md` | Index + framework-extension protocol | ~80 |
| `plugins/mega-sdd/references/lib-patterns/laravel/auth-libs.md` | 5 auth libs detection patterns (Sanctum, Breeze, Jetstream, Fortify, Passport) | ~200 |
| `plugins/mega-sdd/references/lib-patterns/laravel/rbac-libs.md` | 3 rbac libs detection patterns (Spatie/permission, laravel-permission, custom) | ~120 |
| `plugins/mega-sdd/references/lib-patterns/laravel/ui-libs.md` | JS/CSS/notification/icon/datatable libs | ~250 |
| `plugins/mega-sdd/references/lib-patterns/laravel/generic-libs.md` | Common lib catalog (queue/cache/log/test/...) | ~150 |
| `plugins/mega-sdd/references/starterkit-context-schema.md` | Canonical YAML schema doc (the contract) | ~120 |
| `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` | 4 subagent prompt templates | ~300 |

---

## §2 Components

### 2.1 The 4 deep-scan subagents

Each lives inline in `scan-codebase/SKILL.md` Step 2 (dispatched via Agent tool, like extract-intelligence waves). Each returns a structured YAML slice; consolidator merges into single `starterkit-context.yaml`. Each subagent uses model `sonnet` (medium — pattern recognition requires reasoning; haiku too shallow, opus overkill for bounded-scope per-domain analysis).

| Subagent | Reads | Detects | Outputs |
|---|---|---|---|
| **auth-extractor** | `composer.json` / `package.json`, `config/auth.php`, `routes/auth.php`, `routes/web.php`, `app/Http/Middleware/Authenticate.php`, `app/Providers/AuthServiceProvider.php` | auth lib (Sanctum / Breeze / Jetstream / Fortify / Passport), default guard, user model class, login/register route paths, password reset flow, 2FA presence | `auth: { lib, lib_version, guard, user_model, routes: {login, register, logout, password_reset}, features: [2fa, email_verification, social_login] }` |
| **rbac-extractor** | manifests, `app/Models/*.php` (User model traits), `app/Http/Middleware/*`, `app/Providers/AuthServiceProvider.php` (Gate/Policy defs), seeders for roles | rbac lib (Spatie/permission, laravel-permission, custom), role model, permission model, middleware names, gate/policy classes, role names from seeders | `rbac: { lib, role_model, permission_model, middleware: [role, permission, role_or_permission], gates: [...], policies: [...], default_roles: [...] }` |
| **ui-ux-extractor** | `package.json`, `tailwind.config.js`, `vite.config.js`, `resources/views/layouts/*.blade.php`, `resources/views/components/*`, `resources/js/app.js`, `resources/css/app.css` | JS framework (Alpine / Livewire / Inertia / Vue / React), CSS framework (Tailwind / Bootstrap), default layout file, component dir, notification lib (SweetAlert / Toastr), design tokens (Tailwind extend colors/spacing), icon lib (Heroicons / FontAwesome), DataTable lib | `ui_ux: { js_framework, css_framework, layout_extends, layout_file, component_dir, notification_lib, icon_lib, datatable_lib, design_tokens: {colors, spacing, fonts}, idioms: [...] }` |
| **libs-extractor** | `composer.json`, `package.json`, lockfiles | Full inventory: package name + version + purpose category (auth/rbac/ui/queue/cache/log/test/etc.) + usage hint (files where package is imported/used) | `libs: [{ name, version, category, usage_hint: ["app/Http/Controllers/Auth/*"] }]` |

Wall-clock: ~3-5 min per subagent, parallel = ~5 min total per fresh scan.

### 2.2 starterkit-context.yaml canonical schema

Single output at `.mega-sdd/codebase/starterkit-context.yaml`:

```yaml
starterkit_context:
  schema_version: 1.0
  generated_by: scan-codebase v2.6.0
  generated_at: <ISO8601>
  framework: laravel               # from §7 Framework detection
  framework_version: "12.x"
  framework_pack: laravel-base-26  # from §7 pack_path

  auth:
    lib: sanctum                   # or breeze | jetstream | fortify | passport | not_detected
    lib_version: "4.0"
    guard: sanctum
    user_model: "App\\Models\\User"
    routes:
      login: "/login"
      register: "/register"
      logout: "/logout"
      password_reset: "/forgot-password"
    features: [email_verification]
    _source: ["composer.json:34", "config/auth.php:42"]

  rbac:
    lib: spatie/permission           # or laravel-permission | custom | not_detected
    role_model: "Spatie\\Permission\\Models\\Role"
    permission_model: "Spatie\\Permission\\Models\\Permission"
    middleware: [role, permission, role_or_permission]
    gates: [view-admin]
    policies: ["App\\Policies\\UserPolicy"]
    default_roles: [admin, user]
    _source: ["composer.json:42", "database/seeders/RoleSeeder.php"]

  ui_ux:
    js_framework: alpine             # or livewire | inertia | vue | react | none
    css_framework: tailwind          # or bootstrap | bulma | custom | none
    layout_extends: "layouts.app"
    layout_file: "resources/views/layouts/app.blade.php"
    component_dir: "resources/views/components"
    notification_lib: sweetalert2    # or toastr | native | not_detected
    icon_lib: heroicons              # or fontawesome | not_detected
    datatable_lib: yajra/laravel-datatables  # or not_detected
    design_tokens:
      colors: { primary: "#3b82f6", secondary: "#64748b" }
      spacing: default
      fonts: ["Inter"]
    idioms:
      - "use document.addEventListener('DOMContentLoaded', ...) over $(document).ready"
      - "responsive mobile-first (sm/md/lg breakpoints)"
    _source: ["package.json:15", "tailwind.config.js", "resources/views/layouts/app.blade.php"]

  libs:
    - name: "laravel/sanctum"
      version: "4.0"
      category: auth
      usage_hint: ["app/Http/Kernel.php", "routes/api.php"]
    - name: "spatie/laravel-permission"
      version: "6.x"
      category: rbac
      usage_hint: ["app/Models/User.php", "app/Http/Middleware/RoleMiddleware.php"]
    - name: "sweetalert2"
      version: "11.x"
      category: ui
      usage_hint: ["resources/js/app.js", "resources/views/components/notification.blade.php"]
    # ... (full inventory)

  cache_key:
    composer_lock_sha256: "abc123..."
    package_lock_sha256: "def456..."
```

Schema defined canonically in `plugins/mega-sdd/references/starterkit-context-schema.md`. Single source of truth — no dual-schema risk (audit-31 lesson).

### 2.3 Lib-pattern reference files

Lib-pattern reference docs that subagents consult to know "what to look for per lib":

```
plugins/mega-sdd/references/lib-patterns/
  README.md                    # Index + framework-extension protocol
  laravel/
    auth-libs.md               # Sanctum, Breeze, Jetstream, Fortify, Passport
    rbac-libs.md               # Spatie/permission, laravel-permission, custom
    ui-libs.md                 # Alpine/Livewire/Inertia/Vue + Tailwind/Bootstrap + SweetAlert detection
    generic-libs.md            # Queue/cache/log/test/etc. catalog
```

Each pattern file lists: lib name, manifest fingerprint (composer.json key + version range), file fingerprints (where to look in code), structured-output template. Framework-agnostic directory structure — Iter 33+ can add `react/`, `nextjs/`, `django/`, etc., without modifying any skill.

---

## §3 Data flow + autonomy + caching

### 3.1 Trigger logic (auto-detect, no flags)

`scan-codebase` Step 2 decision tree (no user input ever):

```
After Step 1 (surface scan + §7 Framework detection):

  framework.confidence == HIGH or MEDIUM ?
    │
    ├─ YES → Step 2.1: check cache
    │         │
    │         ├─ cache valid (lock files unchanged) → reuse starterkit-context.yaml; skip subagents
    │         └─ cache miss/invalid → Step 2.2: dispatch 4 subagents in parallel
    │                                  Step 2.3: consolidate → write starterkit-context.yaml
    │
    └─ NO  → skip deep-scan; log "no framework detected with sufficient confidence; deep-scan skipped"
              proceed to Step 3 (write codebase-map.md) without starterkit-context.yaml
```

Confidence thresholds (from existing §7 scoring): HIGH ≥ 0.8, MEDIUM 0.5-0.8, LOW < 0.5. Deep-scan fires at MEDIUM+ because false positives are cheap (subagents detect "actually nothing" gracefully via `lib: not_detected`) but false negatives miss real starterkit awareness.

### 3.2 Cache mechanism

Lock files are the canonical signal for "did the lib set change?":

```
1. Compute composer_lock_sha256 = sha256(composer.lock) if exists
2. Compute package_lock_sha256 = sha256(package-lock.json | yarn.lock | pnpm-lock.yaml) if exists
3. Read existing starterkit-context.yaml (if present)
4. Compare cache_key block:
     prior.composer_lock_sha256 == current AND prior.package_lock_sha256 == current
     │
     ├─ MATCH → reuse; emit handoff with starterkit_context: reused: true; ~0sec extra
     └─ DIFFER → invalidate cache; re-run 4 subagents; rewrite file
```

Mirrors Iter 30 shared-snapshot reuse pattern. First scan: ~5min wall-clock. Re-scan with stable deps: ~0sec extra. Re-scan after `composer install`: ~5min (correctly).

**Force re-scan:** `scan-codebase --no-cache` (existing flag extends to starterkit-context too).

### 3.3 Orchestrate-flow integration (passthrough, no procedure changes)

Iter 27 starterkit-first pipeline already routes scan-codebase as Phase 1 of brownfield/starterkit chains. Deep-scan happens INSIDE that phase (transparent to orchestrate-flow). Iter 32 only adds:

```yaml
# scan-codebase handoff YAML (new starterkit_context: block, conditional emission)
emitted_by: scan-codebase
status: completed
artifacts:
  - <abs path>/.mega-sdd/codebase/codebase-map.md
  - <abs path>/.mega-sdd/codebase/starterkit-context.yaml  # NEW (when deep-scan ran)
starterkit_context:                                         # NEW block
  reused: false
  framework: laravel
  auth_lib: sanctum
  rbac_lib: spatie/permission
  ui_stack: alpine + tailwind + sweetalert2
  libs_count: 47
next_action:
  suggested_skill: mega-sdd:generate-intent  # Iter 27 starterkit-first (existing)
  suggested_args: ["--scan=<abs path>/.mega-sdd/codebase/codebase-map.md", "--auto"]
```

orchestrate-flow's existing handoff metadata propagation (`metadata.starterkit_context`) carries the block forward to all downstream skills. handoff-contract.md schema adds the field definition ONCE; per-skill examples reference it.

### 3.4 Performance budget

| Scenario | Time cost |
|---|---|
| First scan, framework detected | scan-codebase existing time + ~5 min deep-scan (4 parallel subagents) |
| Re-scan, deps unchanged | scan-codebase existing time + <1 sec (cache hit) |
| Re-scan, deps changed | scan-codebase existing time + ~5 min (full re-run) |
| Scan, no framework | scan-codebase existing time + 0 sec (deep-scan skipped) |

Cost roughly equivalent to running detect-drift once. Acceptable given Q3 chose subagent-per-domain for fuzzy pattern detection quality.

---

## §4 Consumer integration (in-iter)

Per standing directive — producer + consumer ship together. No deferral to a follow-up audit closure iter.

### 4.1 generate-units v2.6.0

**New Step 4.7** (between existing Step 4 "Load framework pack" and Step 5 "Squad partition"): **Load starterkit-context.yaml + derive starterkit-specific Anchors and Hard Rules per unit.**

```
4.7.a  Resolve path: <project>/.mega-sdd/codebase/starterkit-context.yaml
       If absent → log "starterkit-context unavailable; emit framework-pack-only Anchors"; skip 4.7.b-e
       If present → parse YAML

4.7.b  For each unit being generated, compute "starterkit relevance" based on unit.target_files:
       - File matches resources/views/** OR resources/js/** OR resources/css/** → relevance.ui_ux = true
       - File matches app/Http/Controllers/** AND unit body mentions auth/login/register → relevance.auth = true
       - File matches app/Http/Middleware/** OR unit body mentions role/permission/gate → relevance.rbac = true
       - File matches anywhere consuming a starterkit_context.libs[].usage_hint → relevance.libs = true

4.7.c  Derive starterkit Anchors per unit:
       - If relevance.ui_ux → add anchor: resources/views/layouts/<ui_ux.layout_extends>.blade.php
       - If relevance.auth → add anchor: <auth.user_model> file
       - If relevance.rbac → add anchor: middleware file from rbac.middleware
       - Anchors appended to unit.anchors[] alongside KB/binding anchors

4.7.d  Derive starterkit Hard Rules per unit (project-specific overrides on top of framework pack):
       Example for UI-emitting unit in Laravel starterkit:
         - "MUST extend `layouts.app` (Citation: starterkit-context.yaml §ui_ux.layout_extends)"
         - "MUST use SweetAlert2 for confirmations + notifications (Citation: starterkit-context.yaml §ui_ux.notification_lib)"
         - "MUST use document.addEventListener('DOMContentLoaded', ...) — never $(document).ready (Citation: starterkit-context.yaml §ui_ux.idioms)"
         - "MUST be responsive: mobile + tablet + desktop (Citation: starterkit-context.yaml §ui_ux.idioms)"
       Auth-touching unit:
         - "MUST use guard '<auth.guard>' (Citation: starterkit-context.yaml §auth.guard)"
         - "MUST reference User model `<auth.user_model>` not Auth::user()::class (Citation: starterkit-context.yaml §auth.user_model)"
       Every starterkit-derived rule MUST include explicit Citation field (anti-halu rail).

4.7.e  Update unit frontmatter:
         starterkit_context_consumed: true
         starterkit_relevance: [ui_ux, libs]      # which slices applied to this unit
       Update unit footer §Citations: append starterkit-context.yaml as new citation source.
```

### 4.2 execute-bolts v2.7.0

bolt-dispatch-prompt.md (Iter 30 T1/T2/T3 template) gains a new **T2 section: "Starterkit context (relevant slice)"** inserted between existing T2 "Confidence labels" and T2 "Historical memory" sections.

Slice computation in execute-bolts **Step 1.5** (renamed Iter 30 tiered-context step):

```
1.5.f  Read .mega-sdd/codebase/starterkit-context.yaml (if exists)
       Read unit.starterkit_relevance array (from generate-units Step 4.7.e)

1.5.g  Build T2 slice based on unit.starterkit_relevance:
       - For each relevance flag (auth | rbac | ui_ux | libs), include ONLY that slice from YAML
       - libs slice: filter to libs whose usage_hint overlaps unit.target_files (NOT full inventory)
       - Cap T2 slice at 2KB (subset of T2's existing 5KB budget); truncate libs[] by usage relevance first

1.5.h  Inject into dispatch prompt T2 section:
       ### Starterkit context (relevant to this unit)
       Auth: lib=<auth.lib>, guard=<auth.guard>, user_model=<auth.user_model>
       UI/UX: extends=<ui_ux.layout_extends>, notification=<ui_ux.notification_lib>, idioms=[...]
       Libs in scope: <filtered libs[] with name + usage_hint>
       (Skip blocks where relevance flag == false)
```

**Why subset, not full**: a rich starterkit can produce 50+KB starterkit-context.yaml. T2 has 5KB total budget per Iter 30. Per-unit slicing keeps bolt context lean.

When bolt subagent receives `MUST use SweetAlert2` + `MUST extend layouts.app` in dispatch context, it produces a Blade view that does exactly that — without manual user reminder per session. The standing user prefs (SweetAlert, responsive, DOMContentLoaded over jQuery ready) flow automatically through the data layer.

### 4.3 Anti-halu rail in generate-units

Step 12.5 "polished-prompt render pass" gains a new check: if `starterkit_context_consumed: true` in frontmatter, every starterkit-derived Hard Rule MUST have a Citation to `starterkit-context.yaml §<path>`. Missing citation → halt `starterkit_rule_citation_missing`. Mirrors existing "every Hard Rule needs a Citation" rail extended to starterkit-derived rules.

### 4.4 Handoff propagation chain (full path)

```
scan-codebase handoff
  starterkit_context: {reused, framework, auth_lib, rbac_lib, ui_stack, libs_count}
        │
        ▼ (via orchestrate-flow handoff metadata propagation)
generate-intent handoff
  starterkit_context: {... passthrough}
        │
        ▼
bind-codebase handoff
  starterkit_context: {... passthrough}
        │
        ▼
generate-units handoff
  starterkit_context: {... + units_with_starterkit_anchors: <N>, units_with_starterkit_rules: <N>}
        │
        ▼
execute-bolts handoff
  starterkit_context: {... + bolts_used_starterkit_slice: <N>, slice_avg_size_kb: <N>}
```

Every consumer's handoff carries the block (passthrough except generate-units + execute-bolts which add metrics). handoff-contract.md schema defines the field ONCE in §schema; per-skill examples reference it.

### 4.5 Modified plugin files inventory

| File | Change |
|---|---|
| `plugins/mega-sdd/skills/scan-codebase/SKILL.md` | + Step 2 deep-scan stage; + handoff `starterkit_context:` block emission |
| `plugins/mega-sdd/skills/generate-units/SKILL.md` | + Step 4.7 starterkit Anchors/Hard Rules derivation; + Step 12.5 starterkit citation check; + handoff metrics |
| `plugins/mega-sdd/skills/execute-bolts/SKILL.md` | + Step 1.5.f-h starterkit slice injection; + T2 budget rebalance note |
| `plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md` | + T2 "Starterkit context (relevant slice)" section template |
| `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` | + `starterkit_context:` schema field (defined once); + per-skill examples updated |
| `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` | + `starterkit_rule_citation_missing` to halt type enum |
| `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` | + 4 new halt types to taxonomy (3 soft + 1 always-stop in this skill; 1 always-stop from generate-units) |
| `plugins/mega-sdd/references/paths.md` | + `.mega-sdd/codebase/starterkit-context.yaml` row |

---

## §5 Halt protocol + error handling

Iter-31 audit surfaced the recurring "halt declared in skill but missing from orchestrate-flow taxonomy + vault-contract type enum" failure pattern (13+ orphaned halt types). Iter 32 builds halt taxonomy synchronization INTO the spec to prevent recurrence.

### 5.1 Canonical halt registry (synchronized 4-surface update)

All new halts ship with synchronized update across all 4 surfaces: SKILL.md body + vault-contract.md type enum + orchestrate-flow taxonomy + handoff-contract.md per-skill `Status halted on:` line. No halt is "complete" until all 4 surfaces show it.

| Halt type | Emitted by | Severity | Routing | Recovery |
|---|---|---|---|---|
| `deep_scan_subagent_failed` | scan-codebase | Soft | Warn-only (chain continues) | Auto-retry once; on second fail → emit partial starterkit-context.yaml with `partial: true`; pipeline continues |
| `deep_scan_cache_corrupt` | scan-codebase | Soft | Warn-only (chain continues) | Auto-invalidate cache + re-run 4 subagents; transparent to user |
| `deep_scan_subagent_all_failed` | scan-codebase | ALWAYS STOP | Chain halted | User re-runs scan-codebase later (likely API outage); cached starterkit-context.yaml (if any) preserved untouched |
| `starterkit_rule_citation_missing` | generate-units | ALWAYS STOP | Chain halted | Edit unit to add `Citation: starterkit-context.yaml §<path>` to the starterkit-derived rule; re-run polished-prompt render pass |

### 5.2 Halt YAML envelope (canonical schema)

All 4 halts MUST emit the vault-contract.md canonical envelope (`source_skill`, `details`, `next_action`) — NOT the legacy `emitted_by`/`emitted_at` shape flagged in iter-31 audit. Example for the most complex case:

```yaml
type: starterkit_rule_citation_missing
source_skill: generate-units
details:
  unit_id: U-003
  rule_text: "MUST extend layouts.app"
  missing_citation: "starterkit-context.yaml §ui_ux.layout_extends"
  rule_index: 4
next_action:
  type: edit_unit
  suggested_args: ["U-003"]
  hint: "Append 'Citation: starterkit-context.yaml §ui_ux.layout_extends' to Hard Rule #4"
```

Closes audit findings F-detect-drift-10 + F-orchestrate-flow-07 anti-pattern preemptively before introducing new halts.

### 5.3 Error handling matrix (non-halt conditions)

| Condition | Behavior | User-visible |
|---|---|---|
| Framework confidence == LOW | Skip deep-scan; emit codebase-map.md without starterkit-context.yaml | Log: "framework confidence LOW (X.XX); deep-scan skipped — run /mega-sdd:scan-codebase --force-deep to override" |
| Framework detected but no matching `references/lib-patterns/<framework>/` dir | Subagents proceed using `_universal.md` fallback patterns + manifest-only detection | Log: "no lib-pattern pack for <framework>; using generic extraction" |
| Lock files missing entirely | Cache key uses mtime of `composer.json` + `package.json` as fallback | Log: "lock files absent; cache key uses manifest mtime (less precise)" |
| One subagent returns malformed YAML | Consolidator skips that slice; partial: true flag set on starterkit-context.yaml | Log: "<domain>-extractor returned malformed YAML; slice omitted" |
| Subagent timeout (>10 min) | Soft-halt `deep_scan_subagent_failed`; retry once | Standard halt UX |
| starterkit-context.yaml exists but framework changed | Invalidate full cache; full re-run regardless of lock hashes | Log: "framework pack changed (<old> → <new>); cache invalidated" |
| Concurrent scan-codebase runs on same vault | File lock on starterkit-context.yaml (existing memory file-lock pattern); second run waits or fails fast with `memory_in_use` halt | Standard halt UX |

### 5.4 Anti-halu rails (new for Iter 32)

Three rails added to `scan-codebase` Anti-hallucination section + propagated to bolt-dispatch-prompt.md:

1. **No-fabrication rail (subagent-level)**: each deep-scan subagent's prompt MUST include: *"If a domain library is not detected in manifests OR not found in code probes, emit `<domain>.lib: not_detected` — never guess. Marking absence is correct; inventing presence is the failure mode."*

2. **Citation-required rail**: every starterkit-context.yaml field MUST cite the file(s) it was extracted from in a `_source:` companion field:
   ```yaml
   auth:
     lib: sanctum
     _source: ["composer.json:34", "config/auth.php:42"]
   ```

3. **Slice-budget rail (T2 injection)**: execute-bolts MUST cap the starterkit slice at 2KB. Truncate libs[] first (by usage_hint relevance score), then idioms[]. If 2KB cap impossible → halt `dispatch_prompt_too_large` (existing Iter 30 halt). Prevents bolt context bloat regression.

### 5.5 Audit-pattern prevention checklist (built into implementation plan acceptance)

These items become acceptance criteria for the implementation plan — addressing iter-31 audit findings preemptively for Iter 32 deliverables:

| Audit pattern | Iter 32 prevention |
|---|---|
| Halt in skill but absent from orchestrate-flow taxonomy | All 4 new halts MUST appear in orchestrate-flow `## Halt types` section before merge |
| Halt in skill but absent from vault-contract type enum | All 4 new halts MUST appear in vault-contract.md `§halt-protocol type enum` before merge |
| Handoff YAML claim in prose but field missing in template | scan-codebase + generate-units + execute-bolts handoff YAML EXAMPLES must literally include `starterkit_context:` block (not just prose claim) |
| Test fixtures zero coverage | Test cases SC-DS1..SC-DS6 + GU-SK1..GU-SK3 + EB-SK1..EB-SK2 + OF-SK1 included as plan tasks, not deferred |
| Producer-only ship (consumer skills don't react) | Consumer steps (generate-units Step 4.7, execute-bolts Step 1.5.f-h) ship IN this iter |
| Stale skill name fossils | All new lib-pattern files use canonical names (mega-sdd, generate-intent, etc.); zero `grand-design-spec` / `vault-diff` / `drift-detect` |

---

## §6 Testing

All tests ship as plan tasks in-iter. Closes the "12/13 skills have zero coverage" pattern flagged in iter-31 audit.

### 6.1 Trigger tests (per-skill `.test.md` cases)

**`tests/skill-triggering/scan-codebase.test.md` — 6 new cases**

| ID | Setup | Expected |
|---|---|---|
| SC-DS1 | Laravel project, composer.json has `sanctum`, `spatie/permission`; package.json has `alpinejs`, `tailwindcss`, `sweetalert2` | 4 subagents fire in parallel; starterkit-context.yaml emitted with auth.lib=sanctum, rbac.lib=spatie/permission, ui_ux.notification_lib=sweetalert2; handoff has starterkit_context: block; reused: false |
| SC-DS2 | Re-run SC-DS1 with unchanged lock files | 4 subagents SKIPPED; starterkit-context.yaml reused; handoff has reused: true; wall-clock <2sec |
| SC-DS3 | Re-run SC-DS1 after `composer require laravel/cashier` | Cache invalidated; 4 subagents re-fire; libs[] now includes cashier; reused: false |
| SC-DS4 | Pure config repo (no composer.json, no package.json) | Deep-scan skipped (no framework detected); codebase-map.md written without starterkit-context.yaml; handoff has NO starterkit_context: block; log line "framework confidence LOW" present |
| SC-DS5 | Laravel project but auth-extractor subagent times out >10min | First failure → auto-retry; second failure → soft halt `deep_scan_subagent_failed`; partial: true in starterkit-context.yaml; auth slice marked `_partial: true`; pipeline continues |
| SC-DS6 | All 4 subagents fail (simulated API outage) | Hard halt `deep_scan_subagent_all_failed`; chain stops; existing starterkit-context.yaml (if any) preserved untouched |

**`tests/skill-triggering/generate-units.test.md` — 3 new cases**

| ID | Setup | Expected |
|---|---|---|
| GU-SK1 | Vault + starterkit-context.yaml (auth=sanctum, ui_ux.notification_lib=sweetalert2). Generate units for "Add user CRUD page" feature | Generated unit has anchors[] including layouts.app.blade.php + User.php; Hard Rules include "MUST extend layouts.app (Citation: starterkit-context.yaml §ui_ux.layout_extends)" + "MUST use SweetAlert2 (Citation: starterkit-context.yaml §ui_ux.notification_lib)"; frontmatter has starterkit_context_consumed: true |
| GU-SK2 | Same vault but starterkit-context.yaml absent (greenfield/non-starterkit) | Generated unit has framework-pack-only anchors; no starterkit-derived rules; frontmatter has starterkit_context_consumed: false; no halt |
| GU-SK3 | Vault + starterkit-context.yaml. Generated unit body contains starterkit rule WITHOUT citation | Halt `starterkit_rule_citation_missing` emitted; unit not written; user prompted to add citation |

**`tests/skill-triggering/execute-bolts.test.md` — 2 new cases**

| ID | Setup | Expected |
|---|---|---|
| EB-SK1 | Unit with starterkit_relevance=[ui_ux, libs] dispatched | bolt-dispatch-prompt T2 section includes "Starterkit context (relevant to this unit)" with UI/UX slice + filtered libs slice (NOT full inventory); slice ≤2KB; auth + rbac slices ABSENT (not relevant) |
| EB-SK2 | Unit with starterkit_relevance=[ui_ux] but full ui_ux slice + libs subset >2KB | Slice truncation fires; libs[] filtered first by usage_hint relevance; if still >2KB → halt `dispatch_prompt_too_large` |

**`tests/skill-triggering/orchestrate-flow.test.md` — 1 new case**

| ID | Setup | Expected |
|---|---|---|
| OF-SK1 | Full --auto pipeline starting from Laravel starterkit with PRD | scan-codebase fires deep-scan → generate-intent receives starterkit_context: in handoff metadata → bind-codebase preserves it → generate-units writes units with starterkit anchors → execute-bolts injects T2 slice. End-to-end propagation verified at each handoff. |

### 6.2 Scenario test (one full-pipeline integration)

**`tests/scenarios/scenario-8-starterkit-aware-generation.md`** — full pipeline from Laravel starterkit + PRD to bolt completion. Asserts:
- scan-codebase produces starterkit-context.yaml with ≥3 libs detected
- Generated units cite starterkit-context.yaml in ≥1 Hard Rule
- Executed bolts produce code that uses `layouts.app` extend + SweetAlert2 + Spatie middleware (verified by grep on bolt output)
- Re-running pipeline with unchanged lock files reuses cache (no subagent re-dispatch)

### 6.3 Lib-pattern detection fixtures

Each of the 4 new `references/lib-patterns/laravel/*.md` files MUST include a "Detection examples" section with: manifest fingerprint match, file fingerprint match, sample output YAML slice. Double as documentation AND as extractor subagent fixtures (subagent prompts can reference them).

Example for `auth-libs.md §Sanctum`:
```markdown
### Sanctum
Manifest: composer.json has `"laravel/sanctum": "^4.0"`
Files: app/Http/Kernel.php contains `\Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful`
Routes: routes/api.php typically has middleware('auth:sanctum') groups
Sample output: { lib: sanctum, lib_version: "4.x", guard: sanctum, ... }
```

### 6.4 Field test (user's actual starterkit)

After plugin v3.23.0 ships: user runs `/mega-sdd:scan-codebase` on `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/base-laravel-26`. Expected:
- starterkit-context.yaml correctly identifies auth lib, rbac lib (if Spatie), notification_lib=sweetalert2 (per standing pref), idioms includes "use document.addEventListener", "responsive mobile-first"
- Subsequent generate-units on a real feature spec produces units that USE those libs by default
- Subsequent execute-bolts produces code matching starterkit patterns

Validates the spec against real-world data — confirms the design works on actual project, not just theoretical Laravel.

### 6.5 Test coverage summary

| Test type | Count | Files |
|---|---|---|
| Trigger tests | 12 new cases | 4 `.test.md` files modified |
| Scenario test | 1 new full-pipeline scenario | 1 new file |
| Lib-pattern fixtures | 4 fixtures within new ref files | inline in lib-patterns/laravel/*.md |
| Field test | 1 manual verification on `base-laravel-26` | post-merge user run |

Total trigger test coverage delta: +12 cases across 4 skills. Closes the "tests have zero Iter coverage" pattern in-iter for Iter 32 features.

---

## Acceptance criteria

1. Plugin version bumped 3.22.0 → 3.23.0 with full CHANGELOG entry
2. scan-codebase v2.6.0 emits starterkit-context.yaml when framework detected with confidence ≥ MEDIUM
3. 4 parallel subagents fire on fresh scan; cache reuse on re-scan with unchanged lock files
4. generate-units v2.6.0 reads starterkit-context.yaml + adds starterkit Anchors and Hard Rules with citations
5. execute-bolts v2.7.0 T2 tier injects relevant starterkit slice ≤2KB per unit
6. handoff-contract.md schema includes starterkit_context: field defined once; per-skill examples updated
7. 4 new halt types added to orchestrate-flow taxonomy + vault-contract type enum (synchronized — not just in skill body)
8. 7 new plugin files created (4 lib-patterns + 2 schema docs + 1 deep-scan-prompts)
9. 12 new trigger test cases + 1 scenario test + 4 lib-pattern fixtures all included as plan tasks (not deferred)
10. Field test verified on `base-laravel-26` actual project post-merge
11. Zero stale skill name references in new files (no `grand-design-spec`, `vault-diff`, `drift-detect`)
12. Anti-halu rails: no-fabrication (`not_detected` allowed), citation-required (`_source:` per field), slice-budget (T2 ≤2KB cap)

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Deep-scan wall-clock 5min annoys users on fast iterations | Cache mechanism: 0sec on re-scan with unchanged lock files. Most edits don't touch composer.json/package.json. |
| 4 parallel subagent dispatches hit API rate limits | Same risk as iter-31 audit dispatch (13 parallel). Sonnet model. If hit → fallback to sequential dispatch documented in scan-codebase SKILL.md halt section. |
| Subagents produce divergent YAML slices that don't compose | Single starterkit-context-schema.md defines canonical structure; consolidator validates against schema before write |
| Iter 32 ships producer-only (consumer regression of standing pattern) | Acceptance criteria #4 + #5 require generate-units + execute-bolts changes in same iter. Plan tasks include consumer-side trigger tests. |
| starterkit-context.yaml becomes large (50KB+) and bloats bolt prompts | T2 slice budget 2KB hard cap per unit; usage_hint relevance filtering; truncation order documented |
| Halt taxonomy gap (iter-31 recurring pattern) | Acceptance criterion #7 requires synchronized 4-surface halt updates verified in plan; audit-prevention checklist (§5.5) is plan task acceptance |
| Field test fails on user's real starterkit | Spec includes §6.4 explicit field test step; if fail → bug filed against deep-scan subagents (lib-pattern detection gap), not against design |

---

## Out of scope (deferred to Iter 33+)

- Non-Laravel framework lib-patterns (`references/lib-patterns/react/`, `nextjs/`, `django/`) — directory structure ready; first non-Laravel pack added later when needed
- API conventions extractor (Resource classes, response shapes) — Q2 chose focused scope, API deferred
- Validation pattern extractor (Form Requests, validation rules) — Q2 deferred
- Notification template extractor beyond notification_lib detection — Q2 deferred
- Queue/job pattern extractor — Q2 deferred
- starterkit-context.yaml versioning + migration (schema_version: 1.0 ships; bump protocol added when schema_version: 2.0 needed)
- Cross-vault starterkit-context sharing (each vault has its own scan output)
- UI mockup generation from starterkit design tokens (out of scope; future UI iter)

---

## Spec self-review checklist

- [x] No `TBD` / `TODO` / `fill in details` markers
- [x] Architecture diagram matches §4 consumer integration (both show 4 subagents → consolidator → generate-units + execute-bolts)
- [x] starterkit-context.yaml schema in §2.2 matches consumer field references in §4.1, §4.2 (auth.lib, ui_ux.layout_extends, etc.)
- [x] 4 new halt types listed identically in §5.1, §5.5 acceptance, and §6.1 trigger tests
- [x] Subagent model (sonnet) consistent across §2.1 and §3.4 performance estimates
- [x] T2 slice budget (2KB) consistent across §4.2 spec text and §5.4 anti-halu rail and §6.1 EB-SK2 test
- [x] Plugin version bump 3.22.0→3.23.0 cited consistently
- [x] Skill version bumps in §1 match §4.5 modified files inventory
- [x] Acceptance criteria (12 items) traceable to spec sections
- [x] Audit-pattern prevention (§5.5) ties iter-31 findings to iter-32 acceptance
- [x] Standing user prefs (SweetAlert, DOMContentLoaded, responsive) used as concrete examples — not as standalone requirements
- [x] Scope clearly bounded: 4 domains (Q2 focused choice); other domains explicitly listed as out-of-scope
