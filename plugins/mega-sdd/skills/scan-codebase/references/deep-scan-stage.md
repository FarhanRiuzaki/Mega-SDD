# scan-codebase — deep-scan stage (Steps 10.5.x + 10.6)

## Contents
- Step 10.5.0 — Trigger check
- Step 10.5.1 — Cache check (per-slice signature)
- Step 10.5.1.5 — Manifest pre-parse
- Step 10.5.2 — Dispatch subagents in parallel (selective dispatch)
- Step 10.5.2.5 — Deep-read code patterns (pack-driven, framework-agnostic)
- Step 10.5.3 — Consolidate + write starterkit-context.yaml (full schema)
- Step 10.5.4 — Concurrency guard
- Step 10.6 — Emit codebase-map shared snapshot

Loaded by `scan-codebase` after Step 10 writes `codebase-map.md`. DEFAULT-ON when a framework is detected at MEDIUM+ confidence. No user flag required; opt-out via `--shallow-scan`. The four subagent prompt templates are a separate reference the SKILL.md router links to. The output schema lives in `plugins/mega-sdd/references/starterkit-context-schema.md`. This stage runs because §7 Framework is fully populated by Step 10.

## Step 10.5.0 — Trigger check

```
IF framework.confidence == HIGH or MEDIUM (≥ 0.5):
  → proceed to Step 10.5.1 (cache check)
ELSE:
  → log "framework confidence LOW (X.XX); deep-scan skipped — install ambiguous, run /mega-sdd:scan-codebase --force-deep to override"
  → skip Step 10.5 entirely; proceed to Step 11
```

**Pack-coverage advisory (after trigger passes):** when the trigger proceeds, read `framework-conventions/_registry.md` (if absent, skip silently — never halt). If the detected framework's registry status is `thin` or `none`, emit one advisory note in the scan output:

> `pack coverage: <status> for <framework> — generic _universal fallback in use; see framework-conventions/_registry.md`

This is informational only — it surfaces that the deep-scan will use generic extraction rather than a full framework-specific pack. It never blocks the pipeline.

## Step 10.5.1 — Cache check (per-slice signature)

Mirrors the shared-snapshot reuse pattern (see `plugins/mega-sdd/references/shared-snapshot-schema.md`). Cache invalidation is per-slice: when only some inputs change (e.g., a frontend dep added in package.json), unchanged slices (auth, authz) reuse cached output; only invalidated slices (ui_ux, libs) re-dispatch.

```
1.+2. Compute per-ecosystem lock digests + digest groups — RUN the deterministic script
   (do not hand-compute hashes):

     # Resolve $PLUGIN_ROOT to the LATEST cached version (defeats stale-version anchoring;
     # see plugins/mega-sdd/references/plugin-root-resolution.md). DERIVED = this reference
     # file's own absolute path truncated before /skills/.
     DERIVED="<this reference file's absolute path, truncated before /skills/>"
     RESOLVER="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
     PLUGIN_ROOT="$([ -n "$RESOLVER" ] && bash "$RESOLVER" "$DERIVED" || echo "$DERIVED")"
     [ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED"
     bash "$PLUGIN_ROOT/scripts/compute-lock-digests.sh" \
       --project=<project-root> --app-ecosystem=<ecosystem of §7 Framework>

   It probes EVERY supported ecosystem's lock (php composer.lock; js package-lock/yarn/pnpm/bun;
   rust Cargo.lock; go go.sum; ruby Gemfile.lock; python poetry/uv/Pipfile/requirements;
   jvm gradle.lockfile/pom/gradle) and prints JSON:
   - locks_sha256: {<ecosystem>: <hex>}   (only ecosystems present; + lock_files provenance)
   - app_locks_digest      — locks of the APP ecosystem (ruby for Rails, go for Gin, js for Next.js)
   - frontend_locks_digest — js lock when APP ecosystem ≠ js AND a js lock exists
                             (asset/SPA layer of a non-JS app, e.g., Rails+esbuild, Laravel+Vite);
                             else = app_locks_digest
   - all_locks_digest      — every detected ecosystem folded together
3. Compute per-slice signatures:
   - auth_sig_input = app_locks_digest + framework_pack §auth section content + sha256(lib-patterns/<fw>/auth-libs.md)
   - authz_sig_input = app_locks_digest + framework_pack §authz section content + sha256(lib-patterns/<fw>/rbac-libs.md)
   - ui_ux_sig_input = frontend_locks_digest + framework_pack §ui section content + sha256(lib-patterns/<fw>/ui-libs.md)
   - libs_sig_input = all_locks_digest + framework_pack §libs section + sha256(lib-patterns/<fw>/generic-libs.md)
   - reuse_sig_input = sha256(listing+mtimes of the hinted first-party source dirs) + framework_pack §Reuse discovery section content
     (NOT lock files — reuse tracks first-party source, not deps; output written to reuse-index.yaml, separate from starterkit-context.yaml)
   - auth_signature = sha256(auth_sig_input); similarly for authz/ui_ux/libs/reuse
4. IF <project>/.mega-sdd/codebase/starterkit-context.yaml exists:
     a. Read its `cache_signatures:` block (v2.0 schema) OR `cache_key:` block (v1.0 schema, backward-compat).
     b. IF v1.0 schema detected → treat as "all slices stale" (full re-dispatch); migrate to v2.0 on next write.
     - IF a cached starterkit-context.yaml has schema_version < 3.1 (pre-authz `rbac:` shape) → treat the authz slice as STALE and regenerate it in the neutral shape (the rbac->authz reshape is not cache-compatible).
     c. IF v2.0 schema → per-slice diff:
        - stale_slices = []
        - For each slice in [auth, authz, ui_ux, libs, reuse]:
            IF prior.cache_signatures.per_slice[<slice>].signature_sha256 != current_<slice>_signature:
              stale_slices.append(<slice>)
        - IF stale_slices is empty → FULL CACHE HIT: skip Steps 10.5.1.5 + 10.5.2 + 10.5.3; reuse existing starterkit-context.yaml AND existing reuse-index.yaml; set handoff_reused_flag = true; proceed to Step 11.
        - IF stale_slices is non-empty → PARTIAL CACHE HIT: proceed to Step 10.5.1.5; dispatch only stale_slices subagents in Step 10.5.2; consolidator merges fresh slices with cached slices in Step 10.5.3.
5. ELSE (file not present) → FULL CACHE MISS: stale_slices = [auth, authz, ui_ux, libs, reuse]; proceed to Step 10.5.1.5.
```

Force full re-scan: `--no-cache` (existing flag; sets `stale_slices = [all]` regardless of signatures).

## Step 10.5.1.5 — Manifest pre-parse

**Runs only when `stale_slices` non-empty (not on full cache hit).** Eliminates redundant manifest re-reads by the manifest-consuming subagents (auth/authz/ui_ux/libs). The reuse-extractor reads first-party source dirs directly and does NOT consume manifest_facts.

Main thread reads + parses manifest files ONCE, builds `manifest_facts` struct, passes to each subagent prompt as `<MANIFEST_FACTS>` placeholder:

```
1. For EVERY manifest detected in Step 2 of the surface scan (TECH-AGNOSTIC — parse all that exist,
   not just composer/package):
     - composer.json  → require / require-dev / scripts / autoload PSR-4 map
     - package.json   → dependencies / devDependencies / peerDependencies / scripts / type
     - Cargo.toml     → [dependencies] / [dev-dependencies] / workspace members
     - go.mod         → module path + require list (direct deps; mark // indirect)
     - Gemfile        → gem entries (name + version constraint + group)
     - pyproject.toml → [project.dependencies] / [project.optional-dependencies]
                        (else requirements.txt lines; else Pipfile [packages])
     - pom.xml / build.gradle(.kts) → dependency coordinates (groupId:artifactId:version)
2. Build manifest_facts YAML struct — one block PER detected ecosystem; omit absent ones:

     manifest_facts:
       composer:                     # php
         dependencies: {<name>: <version>, ...}
         dev_dependencies: {<name>: <version>, ...}
         scripts: {<name>: <command>, ...}
         autoload_psr4: {<namespace>: <path>, ...}
       package:                      # js/ts
         dependencies: {<name>: <version>, ...}
         dev_dependencies: {<name>: <version>, ...}
         peer_dependencies: {<name>: <version>, ...}
         scripts: {<name>: <command>, ...}
         type: module | commonjs
       cargo:                        # rust
         dependencies: {<name>: <version>, ...}
         dev_dependencies: {<name>: <version>, ...}
       go:                           # go
         module: <module path>
         dependencies: {<name>: <version>, ...}   # direct only; indirect flagged
       gem:                          # ruby
         dependencies: {<name>: <constraint-or-empty>, ...}
         groups: {<name>: <group>, ...}            # e.g., rspec-rails: test
       python:                       # python
         dependencies: {<name>: <constraint>, ...}
         optional_dependencies: {<extra>: [<names>], ...}
         source: pyproject | requirements | pipfile
       jvm:                          # java/kotlin
         dependencies: {"<groupId>:<artifactId>": <version>, ...}
         build_tool: maven | gradle

3. Embed manifest_facts struct into the <MANIFEST_FACTS> placeholder of each subagent prompt (templates in the deep-scan subagent prompts reference).
4. Subagent prompts INSTRUCT: "manifest_facts is authoritative; do NOT re-read ANY manifest or lock file (composer.json / package.json / Cargo.toml / go.mod / Gemfile / pyproject.toml / pom.xml / their locks). Spend your context budget on framework-specific source files per the pack's file hints — see INPUTS TO READ for the per-domain list."
```

**Net savings:** ~9-24KB per scan (4 manifest-consuming subagents × ~2-6KB saved per subagent; reuse-extractor reads first-party source dirs directly, not manifests).

## Step 10.5.2 — Dispatch subagents in PARALLEL (selective dispatch)

Dispatch only the subagents whose slice is in `stale_slices` (from Step 10.5.1). If all 5 slices stale → dispatch 5 in parallel. If only 1-4 slices stale → dispatch only those (selective re-dispatch).

Dispatch stale-slice subagents IN A SINGLE MESSAGE with N Agent tool calls (parallel-safe per `superpowers:subagent-driven-development` convention — reuses the extract-intelligence wave-dispatch pattern). N = len(stale_slices).

Use the deep-scan subagent prompt templates (a separate reference linked from the SKILL.md router), substituting:
- `<FRAMEWORK>` → from §7 Framework.name (e.g., `laravel`)
- `<PROJECT_ROOT>` → absolute path to project root
- `<CATALOG_PATH>` → for each subagent, the matching catalog under `plugins/mega-sdd/references/lib-patterns/<FRAMEWORK>/<domain>-libs.md`

Subagents:
1. **auth-extractor** — model: per `plugins/mega-sdd/references/model-tiers.md §auth-extractor` (default sonnet); catalog: `lib-patterns/<framework>/auth-libs.md`
2. **authz-extractor** — model: per `plugins/mega-sdd/references/model-tiers.md §authz-extractor` (default sonnet); catalog: `lib-patterns/<framework>/rbac-libs.md`
3. **ui-ux-extractor** — model: per `plugins/mega-sdd/references/model-tiers.md §ui-ux-extractor` (default sonnet); catalog: `lib-patterns/<framework>/ui-libs.md`
4. **libs-extractor** — model: per `plugins/mega-sdd/references/model-tiers.md §libs-extractor` (default sonnet); catalog: `lib-patterns/<framework>/generic-libs.md`
5. **reuse-extractor** — model: per `plugins/mega-sdd/references/model-tiers.md §reuse-extractor` (default sonnet); hints: framework pack `## Reuse discovery` section (or `_universal` generic); output: `.mega-sdd/codebase/reuse-index.yaml` (SEPARATE sibling artifact, NOT merged into starterkit-context.yaml).

> If invoked via orchestrate-flow chain, model tier may be overridden via handoff metadata.model_tiers per role (CLI flag / project config / user preference). Standalone invocation uses catalog default unconditionally.

**Fallback:** if `lib-patterns/<FRAMEWORK>/` directory does not exist:
- Log "no lib-pattern pack for <framework>; using generic extraction".
- Subagents proceed using `framework-conventions/_universal.md` fallback patterns + manifest-only detection.
- No halt; graceful degradation.

**Timeout handling:** if a subagent exceeds 10 min wall-clock OR returns malformed YAML:
- Emit halt `deep_scan_subagent_failed` (soft); auto-retry ONCE with same model.
- If second attempt also fails: mark that slice as failed; consolidator (Step 10.5.3) sets `partial: true` and adds the domain to `partial_slices: [...]`.
- Pipeline continues (warn-only, NOT chain-stopping).

**All-fail handling:** if ALL 5 subagents fail (likely API outage):
- Emit halt `deep_scan_subagent_all_failed` (ALWAYS STOP).
- DO NOT write starterkit-context.yaml (preserve any existing prior version untouched).
- Chain halts; user re-runs scan-codebase later.

## Step 10.5.2.5 — Deep-read code patterns (pack-driven, framework-agnostic)

Runs in main thread (no extra subagent — reuses just-written `codebase-map.md` from Step 10 + the framework pack identified at §7 Framework). Populates the `patterns:` block of starterkit-context.yaml so `validate-starterkit-conformance.sh` can check unit `target_files` against actual codebase conventions.

**Inputs to this step:**
- `codebase-map.md §1 Top-level structure` (the directory layout discovered in Step 10)
- `codebase-map.md §7 Framework.pack_path` (the framework pack file — e.g., `framework-conventions/laravel-base-26.md`, `framework-conventions/django.md`, `framework-conventions/_universal.md`)
- The just-resolved framework pack — read its §patterns hints block (each pack tells deep-scan WHERE each generic category typically lives for that framework).

**Generic categories (universal semantic roles; same for every framework):**

| Category | Universal meaning | Pack provides | Skill body must NOT hardcode |
|---|---|---|---|
| `controller` | endpoint / request handler | Where handlers live in this framework | Laravel `app/Http/Controllers/` |
| `data_model` | persistence-layer entity | Where models live | Laravel `app/Models/` |
| `request_validator` | input validation layer (optional) | Where validators live; null if framework convention absent | Laravel `app/Http/Requests/` |
| `business_logic` | service/usecase layer (optional) | Where services live; null if framework convention absent | Laravel `app/Services/` |
| `test` | test suite | Where tests live | Laravel `tests/Feature/` |
| `schema_migration` | DDL/migration files | Where migrations live | Laravel `database/migrations/` |
| `route` | URL routing definition | Centralized file vs decorator-based vs file-based-routing | Laravel `routes/api.php` |
| `view` | renderable view/page (presentation) | Where views live (pack `## UI quality signatures` view_glob narrows it); null when API-only | Laravel `resources/views/` |
| `component` | reusable presentation component (optional) | Where components live; null when stack has no component layer | Laravel `resources/views/components/` |

**Algorithm per category:**

```
1. Read framework pack §patterns hints to discover the conventional location for this category.
   - Laravel pack → "controllers typically live at app/Http/Controllers/"
   - Django pack → "controllers (views) live at <app>/views.py or <app>/views/"
   - Express pack → "handlers live at src/controllers/ or src/handlers/"
   - _universal pack → best-effort heuristic (grep for *Controller, *.handler.*, *View*)
2. Confirm against codebase-map.md §1 Top-level — does that dir exist in the actual repo?
   - YES → location = <pack-suggested dir>
   - NO → category may be absent. Look for nearest analog under §1. Still absent → emit category with location: null and _source: [].
3. Pick 2-3 representative source files in that dir (NOT generated, NOT vendor, NOT test fixtures).
4. Read first ~30 lines of each to derive:
   - naming pattern (e.g., {Model}Controller<ext>) — read several samples + abstract
   - extension (the actual file extension observed)
   - framework-specific quirks → emit into `extras: {}` per pack's hints (Laravel pack tells you to extract base_class + methods; Django pack tells you to extract as_view + mixins)
5. Cite each derived field with `_source: ["<path>:<line-range>"]` — anti-halu rail (per starterkit-context-schema.md §Anti-halu rails).
6. NEVER fabricate. NEVER guess across frameworks (Laravel idioms in a Django repo = halt).
   - If you cannot find a sample file for a category, that category MUST emit `location: null` and `_source: []`.
   - `extras: {}` is ALWAYS present (may be empty object).
7. Exemplar ordering for `view`/`component` (`exemplar_selection: linter-clean`): for the
   presentation categories, the chosen sample becomes a FEW-SHOT the bolt subagent mirrors, so a raw-scaffold
   view would anchor the bolt to exactly the tells slice E flags. When picking the 2-3 representative samples,
   ORDER `_source` BEST-FIRST: put the cleanest / most-idiomatic view first (passes the pack `## UI quality
   signatures` scaffold_tells — humanized labels, FK resolved via relation, formatted money, app layout +
   responsive grid, project notification idiom). execute-bolts' code-slice then picks the first linter-clean
   entry, NOT `_source[0]` blindly. Emit `exemplar_selection: linter-clean` on the `view`/`component` category.
   (controller/data_model/etc. keep their existing unordered `_source` — selection ordering is a presentation-
   category concern only.)
```

**Pack-driven, NOT skill-hardcoded:** the skill body does NOT contain framework-specific paths. The framework pack (`framework-conventions/<pack>.md`) is the source of "where to look". A new framework pack (e.g., Rails, FastAPI, NestJS) makes this step work for that framework without skill body edits — pack-add is the extension point.

**Universal fallback:** when no framework pack matches (greenfield, unknown stack), use `framework-conventions/_universal.md` heuristics: grep the codebase for `*Controller*`, `*model*`, `*service*`, `*test*`, `migrations/` directories — derive best-effort locations. Emit `extras: {}` empty (no pack quirks to capture).

**Concurrency note:** Step 10.5.2.5 runs AFTER Step 10.5.2 subagents return (sequential — uses their slice citations as hints for which files are representative) and BEFORE Step 10.5.3 consolidator (which merges patterns block into the YAML).

**Failure mode:** if codebase-map.md §1 has no recognizable structure for a category, emit that category as `{ location: null, naming: null, extension: null, _source: [], extras: {} }` — do NOT emit halt. Downstream `validate-starterkit-conformance.sh` treats null-location categories as opt-out and skips checks for them.

**Multi-framework examples:** see `plugins/mega-sdd/references/starterkit-context-schema.md §patterns block — multi-framework examples` — same container schema filled with Laravel, Django, and Express values to prove genericness.

## Step 10.5.3 — Consolidate + write starterkit-context.yaml

```
1. Collect responses from dispatched subagents (= len(stale_slices))
2. Read prior starterkit-context.yaml (if exists) to harvest cached slices for non-stale domains.
3. For each successful subagent response: validate YAML against starterkit-context-schema.md §<domain> slice
   - If validation fails: drop slice; add domain to partial_slices: []
   - If validation passes: include slice in merged output
   - EXCEPTION — reuse slice: do NOT merge into starterkit-context.yaml. Write it atomically to
     <project>/.mega-sdd/codebase/reuse-index.yaml per `plugins/mega-sdd/references/reuse-index-schema.md` (same
     temp-file+rename pattern as starterkit-context write). The handoff carries:
     `reuse_index: { path: .mega-sdd/codebase/reuse-index.yaml, counts: {helpers, model_api, services, commands}, truncated }`.
4. Merge fresh slices (from dispatched subagents) with cached slices (from prior YAML).
   NOTE: only auth/authz/ui_ux/libs slices are merged into starterkit-context.yaml; the reuse slice is consolidated separately (see step 3 EXCEPTION above).
   - Conflict resolution: fresh always wins over cached for same domain (cached is the fallback for non-stale domains).
5. Build merged YAML structure (cache_signatures v2.0 schema):

     starterkit_context:
       schema_version: 3.1                          # v3.1 = neutral authz reshape (rbac block replaced by authz; entrypoints replaces routes; mechanism replaces guard); v3.0 added patterns:; v2.0 added per-slice cache; v1.0 was initial
       generated_by: scan-codebase@<skill version from SKILL.md frontmatter>
       generated_at: <ISO8601 of MOST RECENT slice write>
       framework: <from §7 Framework.name>
       framework_version: <from §7 Framework.version>
       framework_pack: <from §7 Framework.pack_path basename>
       partial: true                                # if ≥1 slice failed in this run
       partial_slices: [<list>]                     # only when partial: true
       reused_slices: [<list of cached domains>]    # provenance of cache reuse
       auth: {...}                                  # fresh OR cached
       authz: {...}                                 # fresh OR cached
       ui_ux: {...}                                 # fresh OR cached
       libs: [...]                                  # fresh OR cached
       patterns:                                    # generic schema, pack-driven values (see Step 10.5.2.5)
         controller:                                # endpoint/request handler (universal semantic role)
           location: <dir path | null>              # pack tells WHERE; deep-scan confirms in real codebase
           naming: <pattern>                        # e.g., "{Model}Controller<ext>" | "{model}_views.py" | "{Model}.handler.ts"
           extension: <file ext>                    # ".php" | ".py" | ".ts" | ".rb" | …
           _source: [<sample file:lines>]
           extras: {}                               # framework-specific (Laravel: {methods, base_class}; Django: {as_view, mixins}; …)
         data_model:                                # persistence-layer entity (universal)
           location: <dir path | null>
           naming: <pattern>                        # e.g., "{Model}<ext>"
           extension: <file ext>
           _source: [<sample file:lines>]
           extras: {}                               # Laravel: {traits, cast_style}; Django: {meta, managers}; Prisma: {schema_file}; …
         request_validator:                         # input validation layer (optional per framework)
           location: <dir | null>                   # null when framework has no validation layer
           naming: <pattern | null>
           extension: <file ext | null>
           _source: [<sample> or empty]
           extras: {}                               # Laravel: {validation_style}; Django: {form_or_serializer}; Express: {schema_lib}
         business_logic:                            # service/usecase layer (optional)
           location: <dir | null>
           naming: <pattern | null>
           extension: <file ext | null>
           _source: [<sample> or empty]
           extras: {}                               # NestJS: {injectable}; Laravel: {action_class_style}; …
         test:
           location: <dir path>
           naming: <pattern>                        # "{Model}Test.php" | "{model}.test.ts" | "test_{model}.py"
           extension: <file ext>
           framework: <test framework>              # phpunit | pest | jest | vitest | pytest | rspec | go-test | …
           _source: [<sample file:lines>]
           extras: {}
         schema_migration:                          # DDL / migration files (universal)
           location: <dir path>
           naming: <pattern>                        # framework-specific format
           extension: <file ext>
           _source: [<sample file:lines>]
           extras: {}                               # Laravel: {timestamp_format}; Django: {numbered_seq}; Rails: {timestamped}; Prisma: {single_schema_file}
         route:
           location: <dir or single-file path>
           style: <generic descriptor>              # "centralized-routes" | "decorator-based" | "file-based-routing" | "manual"
           api_prefix: <string | null>
           web_file: <path | null>
           api_file: <path | null>
           _source: [<sample file:lines>]
           extras: {}                               # Laravel: {resource_style}; FastAPI: {router_count}; NestJS: {controller_decorators}
         view:                                      # renderable view/page (presentation layer; null when stack is API-only)
           location: <dir path | null>              # pack tells WHERE (pack `## UI quality signatures` view_glob narrows it); null when API-only
           naming: <pattern | null>                 # e.g., "{model}.blade.php" | "{Model}Page.tsx" | "{model}.html"
           extension: <file ext | null>             # ".blade.php" | ".vue" | ".tsx" | ".html" | …
           exemplar_selection: linter-clean         # REQUIRED selection rule; see Step 10.5.2.5 note
           _source: [<sample file:lines>, …]        # ORDERED best-first (cleanest/most-idiomatic view FIRST — execute-bolts code-slice picks the first linter-clean, NOT [0] blindly)
           extras: {}                               # Laravel: {layout_extends, component_dir}; Vue: {sfc}; React: {jsx_runtime}; …
         component:                                 # reusable presentation component (optional; null when stack has no component layer)
           location: <dir path | null>
           naming: <pattern | null>                 # e.g., "{name}.blade.php" | "{Name}.vue" | "{Name}.tsx"
           extension: <file ext | null>
           exemplar_selection: linter-clean
           _source: [<sample file:lines>, …]        # ORDERED best-first
           extras: {}
       cache_signatures:                            # v2.1 schema (per-ecosystem locks; replaces v2.0 php/js-only + v1.0 cache_key:)
         locks_sha256:                              # one entry per detected ecosystem (Step 10.5.1.1)
           <ecosystem>: <hex>                       # php | js | rust | go | ruby | python | jvm
         app_ecosystem: <ecosystem of §7 Framework> # which ecosystem drove app_locks_digest
         framework_pack: <pack basename>
         per_slice:
           auth: { signature_sha256: <hex>, generated_at: <ISO8601> }
           authz: { signature_sha256: <hex>, generated_at: <ISO8601> }
           ui_ux: { signature_sha256: <hex>, generated_at: <ISO8601> }
           libs: { signature_sha256: <hex>, generated_at: <ISO8601> }
           reuse: { signature_sha256: <hex>, generated_at: <ISO8601> }
       # NOTE: cached slices keep their original generated_at; fresh slices get current ISO8601.
       # NOTE (v2.0 → v2.1): signature INPUTS changed (per-ecosystem digests), so v2.0-era cached
       #   signatures mismatch on the first v2.1 scan → all slices re-dispatch once, then the new
       #   schema is written. Self-healing; no special migration branch needed.
       # NOTE (reuse slice): the reuse cache signature is stored here for bookkeeping, but the
       #   reuse slice output is written to its OWN file: .mega-sdd/codebase/reuse-index.yaml
       #   (per plugins/mega-sdd/references/reuse-index-schema.md), NOT merged into starterkit-context.yaml.
       #   reuse_sig_input = sha256(listing+mtimes of the hinted first-party source dirs) +
       #     framework_pack ## Reuse discovery section content (NOT lock files — reuse tracks
       #     first-party source, not deps).
6. Write atomically to <project>/.mega-sdd/codebase/starterkit-context.yaml
   (Use temp file + rename pattern: write to .starterkit-context.yaml.tmp, then mv)
7. Validate the written file is parseable:
   - If parse fails: emit halt deep_scan_cache_corrupt (soft); delete file; retry write once
   - If second write also corrupts: drop deep-scan entirely; log warning; proceed to Step 11 without handoff starterkit_context: block
```

**Backward compatibility:** if existing starterkit-context.yaml has `cache_key:` (v1.0), step 2 treats prior as fully-stale (no cached slices reused); Step 10.5.2 dispatches all 5 subagents; Step 10.5.3 writes the new v2.0 `cache_signatures:` schema. One-time migration cost per project; no user action required.

## Step 10.5.4 — Concurrency guard

Use the existing memory file-lock pattern (per `mega-sdd:memory` SKILL.md §file-lock: backoff + retry 3x; fail with `memory_in_use` blocker if all retries fail) on `.mega-sdd/codebase/starterkit-context.yaml`:
- Acquire exclusive lock before write.
- If lock held by concurrent scan-codebase invocation → fail fast with `memory_in_use` halt (existing halt type).
- Release lock after write.

## Step 10.6 — Emit codebase-map shared snapshot

After Step 10 codebase-map.md write completes, additionally write a shared-snapshot file per `plugins/mega-sdd/references/shared-snapshot-schema.md §scan-codebase (codebase-map snapshot)`. Enables downstream `bind-codebase` to skip per-source-file re-tokenization when codebase-map.md is fresh.

```
1. Compute codebase_map_sha256 = sha256(<just-written codebase-map.md>)
2. Build source_files_sha256_map from the files enumerated during Step 10 symbol extraction:
   {
     "<repo-relative-path>": "<sha256-hex>",
     ...
   }
3. Write atomically to <project>/.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json:
   {
     "snapshot_schema_version": "1.1",
     "snapshot_type": "codebase-map",
     "generated_by": "scan-codebase@<skill version from SKILL.md frontmatter>",
     "generated_at": "<ISO8601>",
     "scope": null,
     "files": [],
     "codebase_map_sha256": "<from step 1>",
     "source_files_sha256_map": { ... }
   }
4. Use temp-file + rename for atomicity (same pattern as Step 10.5.3 starterkit-context write).
```

If write fails (disk full / permissions): log warning + continue (snapshot is optimization, not correctness — bind-codebase falls back gracefully per shared-snapshot-schema.md §bind-codebase consumer).
