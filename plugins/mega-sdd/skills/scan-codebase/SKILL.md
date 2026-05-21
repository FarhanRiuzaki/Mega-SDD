---
name: scan-codebase
version: 2.0.0
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

0. **Engine detection (v2.0+, Iter 6).**
   - Probe for tree-sitter: `command -v tree-sitter`
   - Found → `engine: tree-sitter` (AST-precise extraction per `references/tree-sitter-integration.md`)
   - Not found AND `--engine=tree-sitter` flag set → halt `dep_missing` with install commands
   - Not found AND no flag → fall back to `engine: regex` (v1 behavior); emit chat warning: "⚠️ tree-sitter not found; using regex engine (lower precision). Install: brew install tree-sitter / cargo install tree-sitter-cli"
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

   **If `engine: regex` (v1 fallback):**
   - **TypeScript/JS:** grep `^export (default |async )?(function|class|const|interface|type)` in `--include` files
   - **PHP:** grep `^(class|interface|trait|function) ` and `public function `
   - **Python:** grep `^(class|def) ` (exclude `_private`)
   - **Go:** grep `^func [A-Z]` (exported)
   - **Rust:** grep `^pub (fn|struct|enum|trait)`

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
- `--out=<path>`: override output location (default `./codebase-map.md`)
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
