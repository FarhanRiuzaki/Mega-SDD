# scan-codebase — surface scan procedure (Steps 0–10)

## Contents
- Step 0 — Engine detection (tree-sitter multi-binary probe + regex fallback)
- Step 1 — Detect repo root
- Step 2 — Detect package manager / language
- Step 3 — Detect test framework
- Step 4 — Build tree (depth-limited)
- Step 5 — Extract public interfaces (per-file invalidation gate; tree-sitter; regex/ripgrep)
- Step 6 — Extract routes
- Step 7 — Extract data models
- Step 8 — Detect naming conventions
- Step 8.5 — Detect framework (manifest fingerprints + pack resolution)
- Step 9 — Detect pattern signatures
- Step 10 — Write codebase-map.md

Loaded by `scan-codebase` for the surface scan. These steps produce `codebase-map.md` (whose section schema is the codebase-map schema). The deep-scan stage (Step 10.5.x), the default exclusion list, and the tree-sitter engine/precision detail are separate references the SKILL.md router links to.

## Step 0 — Engine detection (multi-binary probe)

Probe for tree-sitter via TWO binary names (different package managers ship under different names):

```bash
command -v tree-sitter || command -v tree-sitter-cli
```

- `tree-sitter` — typically when installed via `brew install tree-sitter` or `cargo install tree-sitter-cli` (binary name is just `tree-sitter`).
- `tree-sitter-cli` — typically when installed via `npm install -g tree-sitter-cli` (binary may keep the package name).

Resolution:
- Found (either) → `engine: tree-sitter` (AST-precise extraction; full tree-sitter engine detail is a separate reference); stash the actual binary name found for subsequent invocations.
- Not found AND `--engine=tree-sitter` flag set → halt `dep_missing` with install commands.
- Not found AND no flag → fall back to `engine: regex`; emit chat warning: "⚠️ tree-sitter not found (probed: tree-sitter, tree-sitter-cli); using regex engine (lower precision). Install: brew install tree-sitter / cargo install tree-sitter-cli / npm install -g tree-sitter-cli".
- Override via `--engine=tree-sitter|regex` flag.

## Step 1 — Detect repo root

Walk up from CWD until `.git` directory found. If none, treat CWD as root and warn user.

## Step 2 — Detect package manager / language

Probe in order:
- `package.json` → npm/node
- `composer.json` → php/composer
- `Cargo.toml` → rust
- `go.mod` → go
- `requirements.txt` / `pyproject.toml` → python
- `pom.xml` / `build.gradle` → java
- Multiple → multi-language project; record all.

## Step 3 — Detect test framework

Grep for known imports/configs:
- `jest.config.*`, `vitest.config.*`, `playwright.config.*`
- `phpunit.xml`, `pest.php`
- `pytest.ini`, `tox.ini`
- `Cargo.toml [dev-dependencies]`

## Step 4 — Build tree (depth-limited)

Walk dirs up to `--depth`, respect `--exclude` (the default exclusion list is a separate reference). Output as markdown tree.

## Step 5 — Extract public interfaces

### Per-file invalidation gate

This gate runs BEFORE tree-sitter / regex extraction below. When `--shallow-scan` flag is set AND a prior `codebase-map.md` exists in the project, the gate compares each source file's current sha256 to the `Last_Scanned_Sha256` column in prior `codebase-map.md` §2:
- File current sha256 == prior `Last_Scanned_Sha256` → REUSE prior §2 entries for this file; SKIP tree-sitter/regex re-extraction for it.
- File current sha256 != prior → re-extract symbols via tree-sitter/regex (logic below); update `Last_Scanned_Sha256` to current sha256.
- File not in prior map → re-extract symbols + add to §2 with current sha256.
- File in prior map but not in current repo enumeration → drop from §2 (file removed).

For default `--deep-scan` (no flag) OR `--no-cache` → SKIP gate; full re-extract for every file (correctness guarantee preserved for deep scans). The gate runs BEFORE per-file extraction so it actually short-circuits the expensive per-file invocations.

### If `engine: tree-sitter` (default when available)

- For each detected language, locate `queries/tags-<lang>.scm` in the plugin dir.
- For each source file: IF the per-file invalidation gate above marked it REUSE → skip; else continue.
- Invoke: `tree-sitter query queries/tags-<lang>.scm <file> --captures` per source file.
- Parse capture output (line + col + capture name + symbol text) into the interface table.
- Capture names map: `name.definition.<kind>` → §2 (public interfaces); `name.reference.<kind>` → symbol graph (used by generate-units PageRank).
- Languages without `.scm` file → fall back to regex (graceful per-language degradation).

### If `engine: regex` (fallback)

Uses ripgrep when available for structured JSON output, falls back to GNU grep:

```bash
# Prefer ripgrep --json when installed for structured matches
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

Ripgrep `--json` output is structured: emit `begin`/`match`/`end`/`summary` records; skill parses these into the interface table (faster + more reliable than text grep). See `plugins/mega-sdd/references/tooling-install.md` for ripgrep install (`brew install ripgrep` etc.); install is OPTIONAL — GNU grep fallback always works.

## Step 6 — Extract routes

Per known framework signatures:
- **Express:** `app.(get|post|put|delete|patch)\(`
- **Laravel:** `Route::(get|post|...)` or controller method routing
- **Next.js:** files under `pages/api/` or `app/**/route.{ts,js}`
- **FastAPI:** `@app.(get|post|...)` decorators
- **Spring:** `@(Get|Post|Put|Delete)Mapping`

## Step 7 — Extract data models

Per known patterns:
- **TypeORM / Prisma:** `@Entity()`, `model X {` in schema.prisma
- **Eloquent:** `class * extends Model`
- **Sequelize:** `sequelize.define(`
- **Pydantic:** `class X(BaseModel):`

## Step 8 — Detect naming conventions

Sample 20+ files per language:
- File case: kebab vs camel vs snake (majority wins)
- Symbol case: camel vs snake vs Pascal
- Test file suffix: `.test.ts`, `.spec.ts`, `Test.php`

## Step 8.5 — Detect framework

Parse package manifest for framework dependency fingerprints; write to `codebase-map.md` §Framework section. Detection rules (first match wins per language):

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

Extract version where regex available (e.g., `"laravel/framework": "^11.0"` → `version: "11.x"`). Output to `codebase-map.md`.

**First-match-wins ordering:** more specific starterkit packs take precedence over generic framework packs.

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

## Step 9 — Detect pattern signatures

Heuristic grep for indicators:
- Auth: search for `middleware`, `jwt`, `session`, `@Auth` decorators
- State management: imports of `redux`, `zustand`, `mobx`, `react context`
- Error handling: ratio of `try/catch` vs `Result<T>` patterns

## Step 10 — Write codebase-map.md

Write per the codebase-map schema. Include all sections; mark genuinely empty sections as "None detected" not omitted. Frontmatter stamps `engine: tree-sitter | regex` + `precision_tier: ast | regex` so downstream `bind-codebase` knows the confidence level.
