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

**2. Fallback to FULL scan (one-line chat note, no halt) when ANY of:** no prior `codebase-map.md`; **in a git repo, the git delta channel is unavailable — regardless of journal state** (prior map lacks `last_scanned_commit`, the stamp is the literal string `HEAD` (zero-commit-era stamp, see Step 10), or `git rev-parse --verify '<stamp>^{commit}'` fails): the journal only sees in-session AI writes, so manual edits/pulls since the prior scan would be invisible AND then laundered permanently by the step-3 restamp; `changed_paths` exceeds 40% of the prior map's file census (a rebase/refactor — merge math costs more than a re-walk).

**Not-a-git-repo exception:** journal-only incremental is allowed (Channel B never existed) ONLY when the journal is non-empty, with an explicit one-line stale-risk warning: "⚠️ no git history — incremental merge covers in-session writes only; edits made outside this session are not detected. Run a full scan periodically." **Not-a-git-repo AND empty journal → full scan** (there is nothing to merge; a vacuous incremental would just refresh `generated_at` and relabel a possibly-stale map as fresh).

**3. Merge semantics (per map section):**
- §2 public interfaces / §3 routes / §4 data models: re-extract entries ONLY for files in `changed_paths` (Steps 5–7 logic, scoped); carry forward all other rows byte-identical; DROP rows whose file vanished.
- §1 structure: re-walk only the directories containing changed paths.
- §5 naming / §6 patterns: recompute only if >10 source files changed (sampling-based sections are cheap to skip).
- §7 framework: re-run Step 8.5 ONLY when a package manifest is in `changed_paths`.
- Frontmatter: refresh `generated_at` + `last_scanned_commit` (current HEAD); `engine`/`precision_tier` re-probed as usual.

**4. Race-safe journal consume (rotate, don't truncate):** BEFORE processing, `mv .dirty-paths.jsonl .dirty-paths.consumed-<ts>` — appends from concurrent sessions land in a fresh journal and survive for the next run. Union any leftover `.dirty-paths.consumed-*` files from a previously crashed sync into `changed_paths` too. AFTER the map write succeeds, delete the consumed file(s); on failure leave them (next run re-unions). The deep-scan stage then runs its own per-slice cache check as normal (lock digests catch dependency changes independently).

**5. Durable changed-set hand-off (sync lane only — the forked downstream can't re-resolve).** When a vault is present (the Mode D sync lane — the same `<vault>` this skill resolves for its handoff `next_action` / Step-11 suggestion), serialize the **already-resolved `changed_paths` from step 1** (post-exclusion, one repo-relative path per line) to `<vault>/.sync-changed-paths.txt` (overwrite). Write the in-memory union — do NOT re-read the journal here: step 4 has already rotated-and-deleted it, and a second read would re-introduce the §3.7 consume race. This file is the SOLE scope channel for the two forked, non-interactive downstream phases that accept a path scope — `detect-drift --scope=@…` and `bind-codebase --paths=@…` (`generate-units --reconcile` takes NO path arg; it reconciles from the refreshed `binding.md`, not this file): by the time they run, step 3 has advanced `last_scanned_commit` to HEAD and step 4 has deleted the journal, so `journal ∪ git diff <stamp>..HEAD` is now empty and a fork cannot reconstruct the set from ground truth. **On the step-2 full-scan fallback** (no incremental merge — no meaningful changed set) do NOT write the file and DELETE any stale one (`rm -f <vault>/.sync-changed-paths.txt`); because there is no changed set to scope, the sync-lane handoff then SKIPS the scoped detect-drift hop and continues the forced Mode D chain straight to a FULL re-bind — `next_action: mega-sdd:bind-codebase --auto` (per spec §3.8(b)(1)). A scope-less `detect-drift --auto` handoff would misfire here: detect-drift infers sync-lane membership ONLY from a `--scope=@file`, so with no scope it self-classifies as STANDALONE and emits `next_action: null`, truncating the chain before the re-bind and leaving `binding.md`/units/bolts stale vs the freshly re-scanned code (exactly the highest-divergence case). This mirrors the cold brownfield path (`scan → bind`), which likewise skips detect-drift on a from-scratch map — the full re-bind IS the reconciliation. No vault present (starterkit-first, not the sync lane) → skip; there is no changed-set consumer.

**Anti-halu rail:** carried-forward rows keep their original `Last_Scanned_Sha256`; ONLY re-extracted rows get new citations. A merge that cannot prove a row's provenance (prior map corrupt) → fall back to full scan.

## Step 0 — Engine detection (multi-binary probe)

Probe for tree-sitter via TWO binary names (different package managers ship under different names):

```bash
command -v tree-sitter || command -v tree-sitter-cli
```

- `tree-sitter` — typically when installed via `brew install tree-sitter-cli` or `cargo install tree-sitter-cli` (binary name is just `tree-sitter`).
- `tree-sitter-cli` — typically when installed via `npm install -g tree-sitter-cli` (binary may keep the package name).

Resolution:
- Found (either) → run the **grammar smoke test** BEFORE claiming the engine (binary presence ≠ working grammars — a default `brew install tree-sitter-cli` ships the CLI with ZERO grammars configured, and every query would fail "No language found"): for each detected language with a `queries/tags-<lang>.scm` AND at least one source file, invoke the Step 5 query once against one real source file. A language with zero source files yet (scaffold-only repo — a first-class scan-first mode) is SKIPPED, not counted as failed. A language whose invocation errors falls back to regex FOR THAT LANGUAGE and is excluded from `grammars_used`. At least one language passes → `engine: tree-sitter` (precision_tier `ast`); `grammars_used` lists exactly the languages that passed. ALL testable languages fail → downgrade to `engine: regex` with the same chat warning as the not-found path plus the grammar-install pointer (`queries/VERSIONS.md §Installation`). NO language was testable (scaffold-only) → keep `engine: tree-sitter` per binary presence with `grammars_used: []` (nothing was extracted either way). Stash the actual binary name found for subsequent invocations.
- Not found AND `--engine=tree-sitter` flag set → halt `dep_missing` with install commands.
- Not found AND no flag → fall back to `engine: regex`; emit chat warning: "⚠️ tree-sitter not found (probed: tree-sitter, tree-sitter-cli); using regex engine (lower precision). Install: brew install tree-sitter-cli / cargo install tree-sitter-cli / npm install -g tree-sitter-cli — or run `/mega-sdd:install-deps` to install automatically".
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

### Spawn-cost gate (MANDATORY before extraction, both engines)

The two engines differ by **three orders of magnitude in process spawns**, and that
difference — not file count — is what decides whether a scan finishes:

| engine | invocations |
|---|---|
| `tree-sitter` | **one per FILE** |
| `regex` (ripgrep) | **one per LANGUAGE** |

On POSIX a spawn costs ~18 ms and the difference is invisible. On a Windows box with
an endpoint-security agent it is **~220 ms** (measured, `windows-team-environment`),
so a perfectly ordinary 2,000-file repo costs ~7.3 minutes of pure spawn tax under
tree-sitter and under a second under regex. This is a real field hang, not a
hypothetical.

Before Step 5 extraction, compute:

```
N        = files that will actually be extracted (after the invalidation gate)
per_spawn = 0.22s on OS=windows-bash, else 0.02s
estimate  = N × per_spawn        # tree-sitter only; regex is ~n_languages × per_spawn
```

- `estimate` ≤ 60 s → proceed silently.
- `estimate` > 60 s → **AskUserQuestion before extracting.** State N, the estimate,
  and the OS. Options, each with its keterangan (→ `plugins/mega-sdd/references/output-language.md §Prompt surfaces`):
  - **Switch to `--engine=regex`** — one call per language instead of per file; finishes in seconds. Lower precision (regex tier, not `ast`), which the map records honestly in `precision_tier`.
  - **Continue with tree-sitter** — full AST precision, takes about the stated time. Reasonable on a fast disk / POSIX, or when precision matters more than latency.
  - **Narrow the scan** — re-run with `--include=<glob>` to cut N.

Do NOT silently downgrade the engine: precision is a property the map reports, so the
choice belongs to the user. Do NOT skip the estimate on Windows because the repo
"looks small" — 200 files is already 44 s there.

The existing `>100k files` halt stays, but note it is a POSIX-era guard: at 220 ms a
100k-file repo is **6.1 hours**, so on Windows this gate fires long before that halt
is ever reached.

### If `engine: tree-sitter` (default when available)

- For each detected language, locate `queries/tags-<lang>.scm` in the plugin dir.
- For each source file: IF the per-file invalidation gate above marked it REUSE → skip; else continue.
- Invoke: `tree-sitter query queries/tags-<lang>.scm <file> --captures` per source file.
  **This is one process per file** — see the spawn-cost gate above. (Batching multiple
  paths into a single `tree-sitter query` call is the structural fix and would collapse
  N spawns to ~1 per language; it is NOT adopted here because the batched capture
  output format could not be verified — the dev machine's tree-sitter ships no compiled
  grammars. Verify on a box with working grammars before changing the invocation.)
- Parse capture output (line + col + capture name + symbol text) into the interface table.
- Capture names map: `name.definition.<kind>` → §2 (public interfaces). `name.reference.<kind>` captures are NOT persisted by scan-codebase (the map has no channel for them) — `generate-units` re-runs the same queries itself to build its file-level symbol graph (pagerank-targeting §Build), cached at `<vault>/.internal/symbol-graph.json`.
- Languages without `.scm` file → fall back to regex (graceful per-language degradation).

### If `engine: regex` (fallback)

Uses ripgrep when available for structured JSON output, falls back to GNU grep:

```bash
# Prefer ripgrep --json when installed for structured matches.
# rg ships built-in file types for ts/php/py/go/rust/ruby/java/csharp/kotlin —
# no custom type definitions needed. Invocation shape (one call per language,
# pattern from the per-language list below):
if command -v rg >/dev/null; then
  rg --type ts --json -e '<TS/JS pattern below>' <paths>
else
  # GNU grep fallback: same patterns via grep -E (no --json structure)
  grep -RnE '<pattern below>' --include='*.ts' <paths>
fi
```

Per-language patterns (engine: regex). Modifier prefixes are REPEATABLE optional
groups — `export default async function`, `final readonly class`, `async def`, Go
receiver methods, `pub async fn`, `override fun`, `record struct` are all in-scope
(the dominant real-world forms). Patterns are **POSIX-ERE-safe** (no `\w` — the
GNU/BSD `grep -E` fallback treats it as a literal; spelled classes work on rg AND grep):
- **TypeScript/JS:** `^export (default )?(async )?(abstract )?(function|class|const|let|var|interface|type|enum)` in `--include` files
- **PHP:** `^[[:space:]]*(final |abstract |readonly )*(class|interface|trait|enum|function) ` and `^[[:space:]]*(public|protected) (static |abstract |final )*function `
- **Python:** `^(class|(async )?def) ` (exclude `_private`)
- **Go:** `^func (\([^)]*\) )?[A-Z]` (exported, incl. receiver methods)
- **Rust:** `^pub(\([A-Za-z0-9_:, ]*\))? (async |unsafe |const )*(fn|struct|enum|trait|type|mod)` (covers `pub(crate)` / `pub(in crate::my_mod)`)
- **Ruby:** `^[[:space:]]*(class|module) [A-Z]` and `^[[:space:]]*def (self\.)?[A-Za-z_]`
- **Java:** `(class|interface|enum|record) [A-Z]` and `^[[:space:]]*(public|protected) [A-Za-z0-9_<>\[\], ]+ [A-Za-z0-9_]+\(`
- **C#:** `^[[:space:]]*(public|internal) (static |sealed |abstract |partial |readonly )*(class|interface|record( struct)?|struct|enum) [A-Z]` and `^[[:space:]]*(public|protected) (static |async |virtual |override |sealed )*[A-Za-z0-9_<>\[\],? ]+ [A-Za-z0-9_]+\(`
- **Kotlin:** `^[[:space:]]*(open |data |sealed |abstract |enum |annotation |inner |value )*(class|interface|object) [A-Z]` and `^[[:space:]]*(override |open |internal |public |protected |suspend |operator |infix |inline |tailrec )*fun (<[^>]+> )?[A-Za-z_]`
- **F#:** `^[[:space:]]*(type|module) [A-Z]` and `^let (rec )?[A-Za-z_]` (top-level `let` only — an indented `let` is a function-local binding, not a public symbol)

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
| .NET | ASP.NET Core (attribute) | `[Http(Get\|Post\|Put\|Delete\|Patch)` + `[Route(` attributes on controller actions |
| .NET | ASP.NET Core (minimal API) | `app.Map(Get\|Post\|Put\|Delete\|Patch)(` / `group.Map(Get\|...)(` |

No framework match (`_universal`) — **or a matched framework with no signature row in this table** (parity rail: Step 8.5 detection MUST NOT outrun extraction) → grep generic markers (`route`, `handler`, HTTP verb + path-literal pairs) best-effort; mark §3 confidence low.

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
| .NET | EF Core | `: DbContext` class + `DbSet<` properties; `[Table(` / `[Key]` attributes on entities |

No ORM signature match for a detected ecosystem (same parity rail as Step 6) → grep generic persistence markers (entity/model class + field blocks near persistence imports) best-effort; mark §4 confidence low.

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
| `package.json` | `"@remix-run/"` | remix |
| `package.json` | `"@sveltejs/kit"` | sveltekit |
| `package.json` | `"express"` | express |
| `package.json` | `"fastify"` | fastify |
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

**First-match-wins ordering:** more specific starterkit packs take precedence over generic framework packs, and **meta-frameworks precede the server substrates they ship with** (a Remix express-adapter app carries both `@remix-run/` and `"express"` — matching express first would grep `app.(get|…)` and miss every file-based route).

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

Write per the codebase-map schema. Include all sections; mark genuinely empty sections as "None detected" not omitted. Frontmatter stamps `engine: tree-sitter | regex` + `precision_tier: ast | regex` so downstream `bind-codebase` knows the confidence level, plus the staleness stamp: `last_scanned_commit: $(git rev-parse --verify 'HEAD^{commit}' 2>/dev/null)` — **omit the field when the command fails** (no `.git` per Step 1, OR a fresh zero-commit repo where bare `git rev-parse HEAD` would emit the literal string "HEAD" and poison the stamp). Consumers treat a stamp equal to the literal `HEAD` as missing.

### Step 10a — Secret-scan gate (BEFORE the write)

The map can be committed or shared; symbol/route extraction can capture a hardcoded credential from a signature line. Before writing `codebase-map.md` (and before Step 10.5.3 writes `starterkit-context.yaml`), **run the deterministic redactor against the assembled artifact** (write to a temp file first, scrub, then rename into place):

```bash
# Resolve $PLUGIN_ROOT to the LATEST cached version (defeats stale-version anchoring;
# see plugins/mega-sdd/references/plugin-root-resolution.md). DERIVED = this reference
# file's own absolute path truncated before /skills/.
DERIVED="<this reference file's absolute path, truncated before /skills/>"
RESOLVER="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
PLUGIN_ROOT="$([ -n "$RESOLVER" ] && bash "$RESOLVER" "$DERIVED" || echo "$DERIVED")"
[ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED"

bash "$PLUGIN_ROOT/scripts/secret-scan.sh" --redact <assembled-artifact-tmp-file>
```

- The script detects AWS keys, private-key blocks, GitHub/Slack/OpenAI-style tokens, JWT-shaped strings, and `password|secret|api_key|token = "…"` assignments; it replaces each matched VALUE with `[REDACTED-SECRET]` in place (the symbol/route row survives) and prints a JSON report of `{pattern, line, excerpt}` findings.
- Findings present → emit one chat warning listing the affected source `file:line` rows from the report so the user can rotate/relocate the credential.
- This gate redacts the ARTIFACT — it never edits repo source files.
- Empty `findings` (the normal case) → write as-is, no chat output.
- **After the rename into place, refresh the map-validator state:** `bash "$PLUGIN_ROOT/scripts/validate-codebase-map.sh" --cwd=<project-root> --quiet`. The temp-file + `mv` write does not fire the PostToolUse `Write|Edit` dispatch, so this keeps `.codebase-map-state.json` fresh for `/mega-sdd:analyze` (the bind-codebase PreToolUse gate also re-validates lazily when the map is newer than its state).
