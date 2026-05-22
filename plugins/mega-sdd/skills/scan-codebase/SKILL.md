---
name: scan-codebase
version: 2.4.1
description: Heuristic codebase scanner for brownfield SDD projects. Produces `codebase-map.md` cataloging entities, modules, conventions, public interfaces, naming patterns, and test conventions. Consumed by `bind-codebase` as ground truth for vault validation. Triggers — "scan codebase", "map this repo", "siapkan context codebase", "init mega-sdd", or paraphrases.
---

# Scan-Codebase

Builds a structured map of an existing repository for use by the SDD binding gate.

**Announce at start:** "I'm using the scan-codebase skill to map the repository."

## When to use

- User runs `/mega-sdd:scan-codebase`
- `orchestrate-flow` detects brownfield project + missing `codebase-map.md`
- User asks "siapkan context buat AI dev di repo ini" or paraphrases
- After significant code changes to refresh stale map

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
   
   Extract version where regex available (e.g., `"laravel/framework": "^11.0"` → `version: "11.x"`). Output to codebase-map.md as:
   ```yaml
   framework:
     name: laravel
     version: "11.x"  # or "unknown" if regex fails
     confidence: high  # high (explicit dep), medium (transitive), low (heuristic)
     pack_path: plugins/mega-sdd/references/framework-conventions/laravel.md
   ```
   If no match → `framework: { name: "_universal", confidence: "fallback" }`.

9. **Detect pattern signatures.** Heuristic grep for indicators:
   - Auth: search for `middleware`, `jwt`, `session`, `@Auth` decorators
   - State management: imports of `redux`, `zustand`, `mobx`, `react context`
   - Error handling: ratio of `try/catch` vs `Result<T>` patterns

10. **Write `codebase-map.md`** per `references/codebase-map-schema.md`. Include all sections; mark genuinely empty sections as "None detected" not omitted. Frontmatter stamps `engine: tree-sitter | regex` + `precision_tier: ast | regex` so downstream `bind-codebase` knows the confidence level.

11. **Suggest next step:** `/mega-sdd:bind-codebase <vault-path>` to validate a vault against this map.

## Anti-hallucination rails

- If a section has no detection: write "None detected" — do NOT invent.
- Limit symbol extraction to **first 200 per category** in v1 (prevents giant maps). Note "truncated at 200, see file scan log for full list."
- Cite line numbers for routes/models (`src/foo.ts:42`) so binding can verify.

## Halt conditions

- Repo > 100k files: confirm with user (`--force-large` flag required to proceed).
- Detection produces 0 public interfaces: warn user — likely scan misconfiguration; offer to re-run with different `--include`.
- (v2.0+) `--engine=tree-sitter` set AND tree-sitter not on PATH → halt `dep_missing` with install commands (per `references/tree-sitter-integration.md` §Installation guidance).

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

## Hand-off

On completion, announce: "Codebase map written to `<path>`. Run `/mega-sdd:bind-codebase <vault>` to validate your vault against it."

## Handoff emission (v1.1+, Iter 4)

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML record at the end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: scan-codebase
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  artifacts:
    - <absolute path to codebase-map.md>
  next_action:
    suggested_skill: mega-sdd:bind-codebase
    suggested_args: ["<absolute vault path>", "--auto"]
    rationale: "Codebase mapped; validate vault claims against it."
  blockers: []
```

Status `halted` only when repo > 100k files without `--force-large` (per existing halt-condition). Required ONLY under `--auto`.

## Memory layer (v1.2+, Iter 5)

When memory enabled (default; opt-out via `--memory-off`), participates in mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`.

### Writes

| When | File | Content |
|---|---|---|
| After scan completes | `<project>/.mega-sdd-memory/conventions.md` | Append detected conventions: test framework, naming case, file suffix, error format. Each entry includes detection count + `status: detected` (first time) or `status: established` (per MEMORY-OQ-4 threshold) |

### Reads

| What | Source | How used |
|---|---|---|
| Past convention detections | `<project>/.mega-sdd-memory/conventions.md` | SKIP re-detection for conventions marked `status: established` (per learning-rules.md §2.5); just confirm signal still present |

### Anti-halu rails

- Memory write happens AFTER `codebase-map.md` is written (memory is derivative)
- Conventions marked `established` STILL get re-verified each scan; status only affects whether the verbose detection is re-emitted
- `--memory-off` disables both reads and writes
- Skipped conventions are logged in scan output for transparency
