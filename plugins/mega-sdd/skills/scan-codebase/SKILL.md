---
name: scan-codebase
version: 2.6.1
description: Heuristic codebase scanner for brownfield SDD projects. Produces `codebase-map.md` cataloging entities, modules, conventions, public interfaces, naming patterns, and test conventions. Consumed by `bind-codebase` as ground truth for vault validation. Triggers — "scan codebase", "map this repo", "siapkan context codebase", "init mega-sdd", or paraphrases.
---

# Scan-Codebase

Builds a structured map of an existing repository for use by the SDD binding gate.

**Announce at start:** "I'm using the scan-codebase skill to map the repository."

## When to use

- User runs `/mega-sdd:scan-codebase`
- `orchestrate-flow` detects brownfield project + missing `codebase-map.md`
- **`orchestrate-flow` Mode A/B (v2.4+ Iter 27) — starterkit detected: scan runs FIRST in the pipeline (before generate-intent) so vault generation is pack-aware from the start**
- User asks "siapkan context buat AI dev di repo ini" or paraphrases
- After significant code changes to refresh stale map

## v2.5+ (Iter 27) — scan-first usage

When invoked as the FIRST phase in starterkit-first mode (`orchestrate-flow` decision matrix Mode A/B):
- Scaffold-only repos are OK — codebase-map.md will have minimal symbols but POPULATED §7 Framework section (the critical output for downstream generate-intent)
- Empty `app/` directory does NOT halt the scan; framework detection comes from package manifests, not file content
- Output is consumed by `generate-intent --scan=<codebase-map>` to inform vault sections with starterkit conventions (dual-citation format per `generate-intent/references/vault-contract.md`)

## Inputs

- Repo path (positional, default `./`)
- `--depth=N` (default 8)
- `--include=<glob>` (repeatable; default infers from package manager)
- `--exclude=<glob>` (repeatable; default excludes `node_modules`, `vendor`, `dist`, `build`, `.git`)

## Output

`codebase-map.md` written to repo root (or CWD if outside repo). Idempotent — overwrites prior map.

## Procedure

0. **Engine detection (v2.0+, Iter 6; v2.1+ Iter 9 Bug 8 fix — multi-binary probe).**
   - Probe for tree-sitter via TWO binary names (different package managers ship under different names):
     ```bash
     command -v tree-sitter || command -v tree-sitter-cli
     ```
     - `tree-sitter` — typically when installed via `brew install tree-sitter` or `cargo install tree-sitter-cli` (binary name is just `tree-sitter`)
     - `tree-sitter-cli` — typically when installed via `npm install -g tree-sitter-cli` (binary may keep the package name)
   - Found (either) → `engine: tree-sitter` (AST-precise extraction per `references/tree-sitter-integration.md`); stash the actual binary name found for subsequent invocations
   - Not found AND `--engine=tree-sitter` flag set → halt `dep_missing` with install commands
   - Not found AND no flag → fall back to `engine: regex` (v1 behavior); emit chat warning: "⚠️ tree-sitter not found (probed: tree-sitter, tree-sitter-cli); using regex engine (lower precision). Install: brew install tree-sitter / cargo install tree-sitter-cli / npm install -g tree-sitter-cli"
   - Override via `--engine=tree-sitter|regex` flag

1. **Detect repo root.** Walk up from CWD until `.git` directory found. If none, treat CWD as root and warn user.

2. **Detect package manager / language.** Probe in order:
   - `package.json` → npm/node
   - `composer.json` → php/composer
   - `Cargo.toml` → rust
   - `go.mod` → go
   - `requirements.txt` / `pyproject.toml` → python
   - `pom.xml` / `build.gradle` → java
   - Multiple → multi-language project; record all

3. **Detect test framework.** Grep for known imports/configs:
   - `jest.config.*`, `vitest.config.*`, `playwright.config.*`
   - `phpunit.xml`, `pest.php`
   - `pytest.ini`, `tox.ini`
   - `Cargo.toml [dev-dependencies]`

4. **Build tree (depth-limited).** Walk dirs up to `--depth`, respect `--exclude`. Output as markdown tree.

5. **Extract public interfaces.**

   **If `engine: tree-sitter` (v2.0+, default when available):**
   - For each detected language, locate `queries/tags-<lang>.scm` in plugin dir
   - Invoke: `tree-sitter query queries/tags-<lang>.scm <file> --captures` per source file
   - Parse capture output (line + col + capture name + symbol text) into interface table
   - Capture names map: `name.definition.<kind>` → §2 (public interfaces); `name.reference.<kind>` → symbol graph (used by generate-units PageRank per Iter 6 Swap #3)
   - Languages without `.scm` file → fall back to regex (graceful per-language degradation)

   **If `engine: regex` (v1 fallback; v2.3+ uses ripgrep when available for structured JSON output, falls back to GNU grep):**

   ```bash
   # Prefer ripgrep --json when installed for structured matches (v2.3+, Iter 14)
   if command -v rg >/dev/null; then
     RG_OPTS="--json --type-add 'php:*.php' --type-add 'ts:*.ts'"
     # Per-language patterns:
     #   TS/JS: rg --type ts $RG_OPTS '^export (default |async )?(function|class|const|interface|type)' <paths>
     #   PHP:   rg --type php $RG_OPTS '^(class|interface|trait|function) |public function ' <paths>
     #   Python: rg --type py $RG_OPTS '^(class|def) ' <paths>
     #   Go:    rg --type go $RG_OPTS '^func [A-Z]' <paths>
     #   Rust:  rg --type rust $RG_OPTS '^pub (fn|struct|enum|trait)' <paths>
   else
     # Fallback to GNU grep when ripgrep absent
     # ... per-language patterns above without --json structure
   fi
   ```

   Per-language patterns (engine: regex):
   - **TypeScript/JS:** `^export (default |async )?(function|class|const|interface|type)` in `--include` files
   - **PHP:** `^(class|interface|trait|function) ` and `public function `
   - **Python:** `^(class|def) ` (exclude `_private`)
   - **Go:** `^func [A-Z]` (exported)
   - **Rust:** `^pub (fn|struct|enum|trait)`

   Ripgrep `--json` output structured: emit `begin`/`match`/`end`/`summary` records; skill parses these into interface table (faster + more reliable than text grep).

   See `plugins/mega-sdd/references/tooling-install.md` for ripgrep install (`brew install ripgrep` etc.); install is OPTIONAL — GNU grep fallback always works.

6. **Extract routes.** Per known framework signatures:
   - **Express:** `app.(get|post|put|delete|patch)\(`
   - **Laravel:** `Route::(get|post|...)` or controller method routing
   - **Next.js:** files under `pages/api/` or `app/**/route.{ts,js}`
   - **FastAPI:** `@app.(get|post|...)` decorators
   - **Spring:** `@(Get|Post|Put|Delete)Mapping`

7. **Extract data models.** Per known patterns:
   - **TypeORM / Prisma:** `@Entity()`, `model X {` in schema.prisma
   - **Eloquent:** `class * extends Model`
   - **Sequelize:** `sequelize.define(`
   - **Pydantic:** `class X(BaseModel):`

8. **Detect naming conventions.** Sample 20+ files per language:
   - File case: kebab vs camel vs snake (majority wins)
   - Symbol case: camel vs snake vs Pascal
   - Test file suffix: `.test.ts`, `.spec.ts`, `Test.php`

8.5. **Detect framework (v2.4+, Iter 23).** Parse package manifest for framework dependency fingerprints; write to `codebase-map.md` §Framework section. Detection rules (first match wins per language):
   | Manifest | Grep pattern | Framework |
   |---|---|---|
   | `composer.json` | `"pixinvent/vuexy-laravel-bootstrap-jetstream"` | laravel-base-26 (starterkit variant; takes precedence over plain laravel) |
   | `composer.json` | `"laravel/framework"` | laravel |
   | `composer.json` | `"symfony/framework-bundle"` | symfony |
   | `composer.json` | `"slim/slim"` | slim |
   | `package.json` | `"next"` (dependencies) | next |
   | `package.json` | `"nuxt"` (dependencies) | nuxt |
   | `package.json` | `"@nestjs/core"` | nestjs |
   | `package.json` | `"express"` | express |
   | `package.json` | `"fastify"` | fastify |
   | `package.json` | `"@remix-run/"` | remix |
   | `package.json` | `"@sveltejs/kit"` | sveltekit |
   | `Gemfile` | `gem ['"]rails['"]` | rails |
   | `Gemfile` | `gem ['"]sinatra['"]` | sinatra |
   | `pyproject.toml`/`requirements.txt` | `django` | django |
   | `pyproject.toml`/`requirements.txt` | `fastapi` | fastapi |
   | `pyproject.toml`/`requirements.txt` | `flask` | flask |
   | `go.mod` | `github.com/gin-gonic/gin` | gin |
   | `go.mod` | `github.com/labstack/echo` | echo |
   | `go.mod` | `github.com/gofiber/fiber` | fiber |
   | `Cargo.toml` | `actix-web` | actix |
   | `Cargo.toml` | `axum` | axum |
   | `Cargo.toml` | `rocket` | rocket |
   
   Extract version where regex available (e.g., `"laravel/framework": "^11.0"` → `version: "11.x"`). Output to codebase-map.md.

   **First-match-wins ordering**: more specific starterkit packs take precedence over generic framework packs. Examples:

   YAML for plain Laravel detection:
   ```yaml
   framework:
     name: laravel
     version: "11.x"
     confidence: high          # high (explicit dep), medium (transitive), low (heuristic)
     pack_path: plugins/mega-sdd/references/framework-conventions/laravel.md
     detection_source: "composer.json — laravel/framework"
   ```

   YAML for base-laravel-26 starterkit detection (Vuexy fingerprint detected, takes precedence over plain laravel):
   ```yaml
   framework:
     name: laravel-base-26
     version: "12.x"
     confidence: high
     pack_path: plugins/mega-sdd/references/framework-conventions/laravel-base-26.md
     detection_source: "composer.json — pixinvent/vuexy-laravel-bootstrap-jetstream + joelbutcher/socialstream"
     extends: laravel           # pack inheritance (recursive load resolves base laravel.md + _universal.md)
   ```

   If no match → `framework: { name: "_universal", confidence: "fallback", pack_path: "plugins/mega-sdd/references/framework-conventions/_universal.md" }`.

9. **Detect pattern signatures.** Heuristic grep for indicators:
   - Auth: search for `middleware`, `jwt`, `session`, `@Auth` decorators
   - State management: imports of `redux`, `zustand`, `mobx`, `react context`
   - Error handling: ratio of `try/catch` vs `Result<T>` patterns

10. **Write `codebase-map.md`** per `references/codebase-map-schema.md`. Include all sections; mark genuinely empty sections as "None detected" not omitted. Frontmatter stamps `engine: tree-sitter | regex` + `precision_tier: ast | regex` so downstream `bind-codebase` knows the confidence level.

## Step 10.5 — Deep-scan stage (v2.6.0+, Iter 32, DEFAULT-ON when framework detected)

After Step 10 writes `codebase-map.md` (so §7 Framework block is fully populated), run this stage automatically. No user flag required. Opt-out: `--shallow-scan`.

### Step 10.5.0 — Trigger check

```
IF framework.confidence == HIGH or MEDIUM (≥ 0.5):
  → proceed to Step 10.5.1 (cache check)
ELSE:
  → log "framework confidence LOW (X.XX); deep-scan skipped — install ambiguous, run /mega-sdd:scan-codebase --force-deep to override"
  → skip Step 10.5 entirely; proceed to Step 11
```

### Step 10.5.1 — Cache check

Mirrors Iter 30 shared-snapshot reuse pattern (see `plugins/mega-sdd/references/shared-snapshot-schema.md`).

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
        → CACHE HIT: skip Steps 10.5.2 + 10.5.3; reuse existing starterkit-context.yaml
        → set handoff_reused_flag = true; proceed to Step 11
     c. ELSE → CACHE MISS / INVALID: proceed to Step 10.5.2
4. ELSE (file not present) → CACHE MISS: proceed to Step 10.5.2
```

Force re-scan: `--no-cache` (existing flag; extends to deep-scan cache too).

### Step 10.5.2 — Dispatch 4 subagents in PARALLEL

Dispatch all 4 subagents IN A SINGLE MESSAGE with 4 Agent tool calls (parallel-safe per `superpowers:subagent-driven-development` convention — reuses extract-intelligence wave-dispatch pattern).

Use prompt templates from `references/deep-scan-prompts.md`, substituting:
- `<FRAMEWORK>` → from §7 Framework.name (e.g., `laravel`)
- `<PROJECT_ROOT>` → absolute path to project root
- `<CATALOG_PATH>` → for each subagent, the matching catalog under `plugins/mega-sdd/references/lib-patterns/<FRAMEWORK>/<domain>-libs.md`

Subagents:
1. **auth-extractor** — model: per `references/model-tiers.md §auth-extractor` (default sonnet); catalog: `lib-patterns/<framework>/auth-libs.md`
2. **rbac-extractor** — model: per `references/model-tiers.md §rbac-extractor` (default sonnet); catalog: `lib-patterns/<framework>/rbac-libs.md`
3. **ui-ux-extractor** — model: per `references/model-tiers.md §ui-ux-extractor` (default sonnet); catalog: `lib-patterns/<framework>/ui-libs.md`
4. **libs-extractor** — model: per `references/model-tiers.md §libs-extractor` (default sonnet); catalog: `lib-patterns/<framework>/generic-libs.md`

> If invoked via orchestrate-flow chain, model tier may be overridden via handoff metadata.model_tiers per role (CLI flag / project config / user preference). Standalone invocation uses catalog default unconditionally.

**Fallback:** if `lib-patterns/<FRAMEWORK>/` directory does not exist:
- Log "no lib-pattern pack for <framework>; using generic extraction"
- Subagents proceed using framework-conventions/_universal.md fallback patterns + manifest-only detection
- No halt; graceful degradation

**Timeout handling:** if a subagent exceeds 10 min wall-clock OR returns malformed YAML:
- Emit halt `deep_scan_subagent_failed` (soft); auto-retry ONCE with same model
- If second attempt also fails: mark that slice as failed; consolidator (Step 10.5.3) sets `partial: true` and adds the domain to `partial_slices: [...]`
- Pipeline continues (warn-only, NOT chain-stopping)

**All-fail handling:** if ALL 4 subagents fail (likely API outage):
- Emit halt `deep_scan_subagent_all_failed` (ALWAYS STOP)
- DO NOT write starterkit-context.yaml (preserve any existing prior version untouched)
- Chain halts; user re-runs scan-codebase later

### Step 10.5.3 — Consolidate + write starterkit-context.yaml

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
         composer_lock_sha256: <from Step 10.5.1>
         package_lock_sha256: <from Step 10.5.1>
4. Write atomically to <project>/.mega-sdd/codebase/starterkit-context.yaml
   (Use temp file + rename pattern: write to .starterkit-context.yaml.tmp, then mv)
5. Validate the written file is parseable:
   - If parse fails: emit halt deep_scan_cache_corrupt (soft); delete file; retry write once
   - If second write also corrupts: drop deep-scan entirely; log warning; proceed to Step 11 without handoff starterkit_context: block
```

### Step 10.5.4 — Concurrency guard

Use existing memory file-lock pattern (per `mega-sdd:memory` SKILL.md §file-lock: backoff + retry 3x; fail with `memory_in_use` blocker if all retries fail) on `.mega-sdd/codebase/starterkit-context.yaml`:
- Acquire exclusive lock before write
- If lock held by concurrent scan-codebase invocation → fail fast with `memory_in_use` halt (existing halt type)
- Release lock after write

---

11. **Suggest next step:** `/mega-sdd:bind-codebase <vault-path>` to validate a vault against this map.

## Anti-hallucination rails

- If a section has no detection: write "None detected" — do NOT invent.
- Limit symbol extraction to **first 200 per category** in v1 (prevents giant maps). Note "truncated at 200, see file scan log for full list."
- Cite line numbers for routes/models (`src/foo.ts:42`) so binding can verify.
- (v2.6.0+, Iter 32) Deep-scan no-fabrication: each subagent MUST emit `lib: not_detected` when no fingerprint matches, NEVER guess. Schema-validation drops slices that violate.
- (v2.6.0+, Iter 32) Deep-scan citation rail: every starterkit-context.yaml field MUST be backed by `_source: [<file>, ...]` companion field. Schema-validation drops slices without _source.
- (v2.6.0+, Iter 32) Deep-scan read-only: subagents have NO Edit/Write/mutating-Bash tool access. Read-only enforced at dispatch.

## Halt conditions

- Repo > 100k files: confirm with user (`--force-large` flag required to proceed).
- Detection produces 0 public interfaces: warn user — likely scan misconfiguration; offer to re-run with different `--include`.
- (v2.0+) `--engine=tree-sitter` set AND tree-sitter not on PATH → halt `dep_missing` with install commands (per `references/tree-sitter-integration.md` §Installation guidance).

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

## Flags

- `--depth=N`: tree depth (default 8)
- `--include=<glob>`: scan only matching files (repeatable)
- `--exclude=<glob>`: skip matching files (repeatable)
- `--out=<path>`: override output location
  - **v2.2+ default (Iter 10)**: `<project-root>/.mega-sdd/codebase/codebase-map.md` per `plugins/mega-sdd/references/paths.md`
  - **Legacy default (≤v2.1)**: `<project-root>/codebase-map.md` (preserved when `.mega-sdd/` dir absent OR `layout: legacy` in config)
  - User explicit `--out=<path>` always respected
- `--auto`: skip confirmation prompts
- `--force-large`: proceed on >100k file repos
- `--engine=tree-sitter|regex` (v2.0+): force engine; default auto-detect via `command -v tree-sitter`
- `--shallow-scan` (v2.6.0+, Iter 32): skip Step 10.5 deep-scan stage; emit only surface codebase-map.md (opt-out for deep-scan)
- `--force-deep` (v2.6.0+, Iter 32): force deep-scan even when framework confidence is LOW (override Step 10.5.0 trigger check)
- `--no-cache` (v2.6.0+, Iter 32): invalidate deep-scan cache; re-run all 4 subagents even if lock files unchanged

## Hand-off

On completion, announce: "Codebase map written to `<path>`. Run `/mega-sdd:bind-codebase <vault>` to validate your vault against it."

## Handoff emission (v1.1+, Iter 4)

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML record at the end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: scan-codebase
  emitted_at: <ISO8601 timestamp>
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
  scope:                                  # v3.20+ (Iter 28) — when vault has scope_metadata
    id: <scope id, e.g., "BE">
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from vault.json>
```

> The `starterkit_context:` block + the `starterkit-context.yaml` artifact entry are CONDITIONAL — emitted only when deep-scan ran successfully (framework detected at MEDIUM+ confidence). Skip both when deep-scan was skipped or failed entirely.

Status `halted` on: `dep_missing` | `deep_scan_subagent_all_failed` | `memory_in_use`. Required ONLY under `--auto`.

## Memory layer (v1.2+, Iter 5)

When memory enabled (default; opt-out via `--memory-off`), participates in mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`.

### Writes

| When | File | Content |
|---|---|---|
| After scan completes | `<project>/.mega-sdd/memory/conventions.md` | Append detected conventions: test framework, naming case, file suffix, error format. Each entry includes detection count + `status: detected` (first time) or `status: established` (per MEMORY-OQ-4 threshold) |

### Reads

| What | Source | How used |
|---|---|---|
| Past convention detections | `<project>/.mega-sdd/memory/conventions.md` | SKIP re-detection for conventions marked `status: established` (per learning-rules.md §2.5); just confirm signal still present |

### Anti-halu rails

- Memory write happens AFTER `codebase-map.md` is written (memory is derivative)
- Conventions marked `established` STILL get re-verified each scan; status only affects whether the verbose detection is re-emitted
- `--memory-off` disables both reads and writes
- Skipped conventions are logged in scan output for transparency
