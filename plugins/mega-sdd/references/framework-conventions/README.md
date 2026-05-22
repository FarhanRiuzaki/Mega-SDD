# Framework Convention Packs (v1.0, Iter 23)

Pluggable convention packs for common backend/frontend frameworks. Each pack declares file-location standards, naming standards, idioms, and Hard Rules that `bind-codebase` pulls into Suggested Unit Hard Rules when the matching framework is detected by `scan-codebase`.

## Pluggable, not opinionated-by-default

mega-sdd stays framework-agnostic. Convention packs are **OPT-IN BY DETECTION**:

1. `scan-codebase` step 8.5 detects framework via package manifest fingerprints (`composer.json`, `package.json`, `Gemfile`, `pyproject.toml`, `go.mod`, `Cargo.toml`)
2. `bind-codebase` step 2.8 loads matching pack from this folder
3. Pack's Hard Rules merged INTO `Suggested Unit Hard Rules` in `binding.md`
4. `execute-bolts` enforces via ast-grep (existing rail)

Fallback when no framework match → `_universal.md` (universal good practices that apply to any codebase).

## Files

| File | Purpose |
|---|---|
| `_template.md` | Schema for authoring new packs |
| `_universal.md` | Universal fallback — snake_case columns, FK convention, 3NF, etc. |
| `laravel.md` | Laravel 10.x — 11.x pack |
| `<other>.md` | Add more packs incrementally — Django, Rails, Express, NestJS, FastAPI, Go (Gin/Echo), Rust (Actix/Axum), etc. |

## Opt-out

- `bind-codebase --no-framework-pack` — skip pack loading entirely
- `bind-codebase --framework-pack=<custom-path>` — use a project-specific pack instead of built-in

## Adding a new pack

1. Copy `_template.md` → `<framework>.md`
2. Fill in frontmatter (detection signature) + body sections
3. Test detection by running `scan-codebase` against a known project of that framework
4. Submit PR — packs must pass `references/framework-conventions/_lint.md` checklist (TBD: pack linter)

## Versioning + maintenance

- Each pack has `framework_version_range:` frontmatter (e.g., `"10.x — 11.x"`)
- `last_verified_against:` date tracks freshness
- When framework releases major version with breaking convention changes, fork to `<framework>-v<N>.md` (e.g., `laravel-v11.md`) or update existing pack with revised `framework_version_range`
- Stale packs (>1 year `last_verified_against`) emit advisory in `scan-codebase` output
