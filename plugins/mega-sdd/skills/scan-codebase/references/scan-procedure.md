# scan-codebase — surface scan procedure (Steps 0–10)

## Contents
- Incremental mode (`--changed-only`)
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

## Incremental mode (`--changed-only`)

For the never-ending-development loop (spec `2026-06-10-living-vault-continuous-sync-design.md`): re-scan ONLY what moved since the last scan, merge into the existing map. This is what `/mega-sdd:sync` invokes.

**1. Resolve `changed_paths` (union of two channels, de-duplicated):**

```bash
# Channel A — ambient journal (in-session AI writes, even uncommitted)
#   .mega-sdd/codebase/.dirty-paths.jsonl — one JSON row per Write/Edit; read the "path" field.
# Channel B — git (manual edits, pulls, other tools)
git diff --name-only <last_scanned_commit>..HEAD   # from the prior map's frontmatter stamp
git status --porcelain                              # uncommitted working-tree changes
```

Apply the default exclusion globs to the union (a journaled `node_modules/` write is still noise). The journal is a HINT — paths that no longer exist are treated as deletions, never errors.

**2. Fallback to FULL scan (one-line chat note, no halt) when ANY of:** no prior `codebase-map.md`; prior map lacks `last_scanned_commit` AND the journal is empty; not a git repo AND the journal is empty; `changed_paths` exceeds 40% of the prior map's file census (a rebase/refactor — merge math costs more than a re-walk).

**3. Merge semantics (per map section):**
- §2 public interfaces / §3 routes / §4 data models: re-extract entries ONLY for files in `changed_paths` (Steps 5–7 logic, scoped); carry forward all other rows byte-identical; DROP rows whose file vanished.
- §1 structure: re-walk only the directories containing changed paths.
- §5 naming / §6 patterns: recompute only if >10 source files changed (sampling-based sections are cheap to skip).
- §7 framework: re-run Step 8.5 ONLY when a package manifest is in `changed_paths`.
- Frontmatter: refresh `generated_at` + `last_scanned_commit` (current HEAD); `engine`/`precision_tier` re-probed as usual.

**4. Race-safe journal consume (rotate, don't truncate):** BEFORE processing, `mv .dirty-paths.jsonl .dirty-paths.consumed-<ts>` — appends from concurrent sessions land in a fresh journal and survive for the next run. Union any leftover `.dirty-paths.consumed-*` files from a previously crashed sync into `changed_paths` too. AFTER the map write succeeds, delete the consumed file(s); on failure leave them (next run re-unions). The deep-scan stage then runs its own per-slice cache check as normal (lock digests catch dependency changes independently).

**Anti-halu rail:** carried-forward rows keep their original `Last_Scanned_Sha256`; ONLY re-extracted rows get new citations. A merge that cannot prove a row's provenance (prior map corrupt) → fall back to full scan.

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

Walk up from CWD until `.git` is found — test `-e` not `-d` (in a linked git worktree `.git` is a FILE pointing at the real gitdir; `git rev-parse --show-toplevel` is the canonical resolver). If none, treat CWD as root and warn user.

## Step 2 — Detect package manager / language

Probe in order (record ALL hits — multi-language projects are normal):

> **Monorepo rail:** when app-root manifests exist in MULTIPLE distinct top-level dirs (e.g. `apps/web/package.json` + `apps/api/composer.json` + root workspace), ask ONCE which app is the PRIMARY scan target (or `--include` it explicitly); a map that conflates several apps' routes/models binds wrongly downstream. Multi-language inside ONE app (php+js) is normal and needs no question.
- `package.json` → js/ts (npm/yarn/pnpm/bun)
- `composer.json` → php/composer
- `Cargo.toml` → rust
- `go.mod` → go
- `requirements.txt` / `pyproject.toml` / `Pipfile` → python
- `Gemfile` → ruby/bundler
- `pom.xml` / `build.gradle` / `build.gradle.kts` → java/kotlin (jvm)
- `*.csproj` / `*.sln` / `*.fsproj` → csharp/fsharp (.NET; nuget) — `Directory.Packages.props` for central package mgmt
- Multiple → multi-language project; record all.

## Step 3 — Detect test framework

Grep for known imports/configs (per detected ecosystem; record all):
- **js/ts:** `jest.config.*`, `vitest.config.*`, `playwright.config.*`, `cypress.config.*`
- **php:** `phpunit.xml`, `pest.php` / `tests/Pest.php`
- **python:** `pytest.ini`, `tox.ini`, `pyproject.toml [tool.pytest.ini_options]`
- **rust:** `Cargo.toml [dev-dependencies]` + `#[cfg(test)]` modules (built-in `cargo test`)
- **go:** `*_test.go` files (built-in `go test`); `testify` in go.mod
- **ruby:** `.rspec` / `spec/spec_helper.rb` (rspec); `test/test_helper.rb` (minitest)
- **jvm:** `junit`/`junit-jupiter` in pom.xml/build.gradle deps; `src/test/java/`
- **.NET:** `xunit` / `nunit` / `MSTest.TestFramework` PackageReference in `*.csproj`; `*Tests.csproj` / `*.Tests/` projects (built-in `dotnet test`)

## Step 4 — Build tree (depth-limited)

Walk dirs up to `--depth`, respect `--exclude` (the default exclusion list is a separate reference). Output as markdown tree.

**Symlink rail:** do NOT follow symlinked directories (loop risk: `./link → ../ → ./link` hangs the walk). Note encountered dir symlinks in one log line; a user who needs them traversed passes explicit `--include` for the TARGET path. Files >10 MB skip tree-sitter (regex fallback or skip; log in the scan summary) — a single minified bundle must not stall extraction.

## Step 5 — Extract public interfaces

### Per-file invalidation gate

This gate runs BEFORE tree-sitter / regex extraction below. When `--shallow-scan` flag is set AND a prior `codebase-map.md` exists in the project, the gate compares each source file's current sha256 to the `Last_Scanned_Sha256` column in prior `codebase-map.md` §2:
- File current sha256 == prior `Last_Scanned_Sha256` → REUSE prior §2 entries for this file; SKIP tree-sitter/regex re-extraction for it.
- File current sha256 != prior → re-extract symbols via tree-sitter/regex (logic below); update `Last_Scanned_Sha256` to current sha256.
- File not in prior map → re-extract symbols + add to §2 with current sha256.
- File in prior map but not in current repo enumeration → drop from §2 (file removed).

For a default scan (no `--shallow-scan`) OR `--no-cache` → SKIP gate; full re-extract for every file (correctness guarantee preserved for full scans). The gate runs BEFORE per-file extraction so it actually short-circuits the expensive per-file invocations.

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
- **Ruby:** `^\s*(class|module) [A-Z]` and `^\s*def (self\.)?\w+`
- **Java:** `(class|interface|enum|record) [A-Z]` and `^\s*(public|protected) [\w<>\[\], ]+ \w+\(`

Ripgrep `--json` output is structured: emit `begin`/`match`/`end`/`summary` records; skill parses these into the interface table (faster + more reliable than text grep). See `plugins/mega-sdd/references/tooling-install.md` for ripgrep install (`brew install ripgrep` etc.); install is OPTIONAL — GNU grep fallback always works.

## Step 6 — Extract routes

Per framework signatures — one row per framework in the Step 8.5 detection table (tech-agnostic: every supported framework has an extraction signature, not just the JS/PHP ones):

| Ecosystem | Framework | Route signature |
|---|---|---|
| js/ts | Express | `app.(get\|post\|put\|delete\|patch)(` / `router.(get\|...)(` |
| js/ts | Fastify | `fastify.(get\|post\|...)(` / `.route({` |
| js/ts | NestJS | `@(Get\|Post\|Put\|Delete\|Patch)(` decorators on controller methods |
| js/ts | Next.js | files under `pages/api/**` or `app/**/route.{ts,js}` (file-based) |
| js/ts | Nuxt | files under `server/api/**` (file-based) |
| js/ts | SvelteKit | `src/routes/**/+server.{ts,js}` + `+page.server.*` (file-based) |
| js/ts | Remix | `app/routes/**` loader/action exports (file-based) |
| php | Laravel | `Route::(get\|post\|...)` in `routes/*.php` |
| php | Symfony | `#[Route(` attributes (or `@Route` annotations) |
| php | Slim | `$app->(get\|post\|...)(` |
| ruby | Rails | `config/routes.rb` — `resources :x`, `get '...'`, `namespace` |
| ruby | Sinatra | top-level `get '/...' do` / `post '...' do` |
| python | Django | `urls.py` — `path(` / `re_path(` / `include(` |
| python | FastAPI | `@app.(get\|post\|...)(` / `@router.(get\|...)(` decorators |
| python | Flask | `@app.route(` / `@bp.route(` decorators |
| go | Gin | `r.GET(` / `router.(GET\|POST\|...)(` / `group.(GET\|...)(` |
| go | Echo | `e.(GET\|POST\|...)(` |
| go | Fiber | `app.(Get\|Post\|...)(` |
| rust | Actix | `#[(get\|post\|...)("` attributes / `.route(` / `web::resource(` |
| rust | Axum | `Router::new()` + `.route("...", (get\|post\|...)(` |
| rust | Rocket | `#[(get\|post\|...)("` attributes + `routes![` |
| jvm | Spring | `@(Get\|Post\|Put\|Delete\|Patch)Mapping` / `@RequestMapping` |

No framework match (`_universal`) → grep generic markers (`route`, `handler`, HTTP verb + path-literal pairs) best-effort; mark §3 confidence low.

## Step 7 — Extract data models

Per ORM/persistence-pattern signatures — covering every ecosystem in the detection table:

| Ecosystem | Pattern | Model signature |
|---|---|---|
| js/ts | Prisma | `model X {` in `schema.prisma` |
| js/ts | TypeORM | `@Entity()` class decorators |
| js/ts | Sequelize | `sequelize.define(` / `extends Model` + `.init(` |
| js/ts | Drizzle | `pgTable(` / `mysqlTable(` / `sqliteTable(` |
| php | Eloquent | `class * extends Model` |
| php | Doctrine | `#[ORM\Entity]` attributes (or `@ORM\Entity` annotations) |
| ruby | ActiveRecord | `class * < ApplicationRecord` / `< ActiveRecord::Base` |
| python | Django ORM | `class X(models.Model):` |
| python | SQLAlchemy | `class X(Base):` / `(DeclarativeBase)` / `(db.Model)` |
| python | Pydantic | `class X(BaseModel):` (DTO/schema layer — record as schema, not persistence, unless no other ORM detected) |
| go | GORM | struct with `gorm.Model` embed or `gorm:"..."` field tags |
| go | sqlc/ent | `ent.Schema` / generated `models` package |
| rust | Diesel | `#[derive(Queryable` / `table! {` macro |
| rust | SeaORM | `#[derive(DeriveEntityModel` |
| jvm | JPA/Hibernate | `@Entity` (jakarta.persistence / javax.persistence) |

Field extraction per entity follows the same per-language tree-sitter/regex ladder as Step 5.

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
| `pom.xml`/`build.gradle` | `spring-boot-starter` | spring |
| `*.csproj` | `Microsoft.AspNetCore.` (or `<Project Sdk="Microsoft.NET.Sdk.Web">`) | aspnetcore |
| `*.csproj` | `Microsoft.EntityFrameworkCore` (no web SDK) | dotnet |

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

Write per the codebase-map schema. Include all sections; mark genuinely empty sections as "None detected" not omitted. Frontmatter stamps `engine: tree-sitter | regex` + `precision_tier: ast | regex` so downstream `bind-codebase` knows the confidence level, plus `last_scanned_commit: $(git rev-parse HEAD)` as the staleness stamp (omit when the repo has no `.git` — Step 1 already detected this).

### Step 10a — Secret-scan gate (BEFORE the write)

The map can be committed or shared; symbol/route extraction can capture a hardcoded credential from a signature line. Before writing `codebase-map.md` (and before Step 10.5.3 writes `starterkit-context.yaml`), **run the deterministic redactor against the assembled artifact** (write to a temp file first, scrub, then rename into place):

```bash
bash "<plugin-root>/scripts/secret-scan.sh" --redact <assembled-artifact-tmp-file>
# (`<plugin-root>` = this reference file's own absolute path truncated before `/skills/` — `${CLAUDE_PLUGIN_ROOT}` is NOT substituted inside reference files and is NOT exported to the Bash tool, so derive the root from the path you just Read)
```

- The script detects AWS keys, private-key blocks, GitHub/Slack/OpenAI-style tokens, JWT-shaped strings, and `password|secret|api_key|token = "…"` assignments; it replaces each matched VALUE with `[REDACTED-SECRET]` in place (the symbol/route row survives) and prints a JSON report of `{pattern, line, excerpt}` findings.
- Findings present → emit one chat warning listing the affected source `file:line` rows from the report so the user can rotate/relocate the credential.
- This gate redacts the ARTIFACT — it never edits repo source files.
- Empty `findings` (the normal case) → write as-is, no chat output.
