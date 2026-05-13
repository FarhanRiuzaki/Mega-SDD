---
name: scan-codebase
version: 1.0.0
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

5. **Extract public interfaces.** Per language:
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

10. **Write `codebase-map.md`** per `references/codebase-map-schema.md`. Include all sections; mark genuinely empty sections as "None detected" not omitted.

11. **Suggest next step:** `/mega-sdd:bind-codebase <vault-path>` to validate a vault against this map.

## Anti-hallucination rails

- If a section has no detection: write "None detected" — do NOT invent.
- Limit symbol extraction to **first 200 per category** in v1 (prevents giant maps). Note "truncated at 200, see file scan log for full list."
- Cite line numbers for routes/models (`src/foo.ts:42`) so binding can verify.

## Halt conditions

- Repo > 100k files: confirm with user (`--force-large` flag required to proceed).
- Detection produces 0 public interfaces: warn user — likely scan misconfiguration; offer to re-run with different `--include`.

## Flags

- `--depth=N`: tree depth (default 8)
- `--include=<glob>`: scan only matching files (repeatable)
- `--exclude=<glob>`: skip matching files (repeatable)
- `--out=<path>`: override output location (default `./codebase-map.md`)
- `--auto`: skip confirmation prompts
- `--force-large`: proceed on >100k file repos

## Hand-off

On completion, announce: "Codebase map written to `<path>`. Run `/mega-sdd:bind-codebase <vault>` to validate your vault against it."
