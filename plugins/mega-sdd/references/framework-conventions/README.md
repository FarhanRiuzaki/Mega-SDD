# Framework Convention Packs

Pluggable convention packs for common backend/frontend frameworks. Each pack declares file-location standards, naming standards, idioms, and Hard Rules that `bind-codebase` pulls into Suggested Unit Hard Rules when the matching framework is detected by `scan-codebase`.

## Pluggable, not opinionated-by-default

mega-sdd stays framework-agnostic. Convention packs are **OPT-IN BY DETECTION**:

1. `scan-codebase` step 8.5 detects framework via package manifest fingerprints (`composer.json`, `package.json`, `Gemfile`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`/`build.gradle`)
2. `bind-codebase` step 2.8 loads matching pack from this folder
3. Pack's Hard Rules merged INTO `Suggested Unit Hard Rules` in `binding.md`
4. `execute-bolts` enforces via ast-grep (existing rail)

Fallback when no framework match → `_universal.md` (universal good practices that apply to any codebase).

## Files

| File | Purpose |
|---|---|
| `_template.md` | Schema for authoring new packs |
| `_universal.md` | Universal fallback — snake_case columns, FK convention, 3NF, etc. |
| `_lint.md` | Pack lint checklist + cross-framework token map (data-driven; used by `validate-pack.sh`) |
| `_registry.md` | Auto-generated pack-readiness table — do not hand-edit; regenerate with `validate-pack.sh --registry` |
| `laravel.md` | Laravel 10.x — 12.x pack (default framework conventions) |
| `laravel-base-26.md` | RECON / base-laravel-26 starterkit (Vuexy + Jetstream + Spatie permission + custom helpers/traits + Reverb + notification rule engine) — extends laravel.md; takes precedence when Vuexy fingerprint detected |
| `<framework>.md` | One pack per framework. All 22 detectable §8.5 frameworks now have a full pack — laravel, django, fastapi, next, express, nestjs, flask, symfony, rails, spring, nuxt, sveltekit, gin, slim, fastify, remix, sinatra, echo, fiber, actix, axum, rocket. See [`_registry.md`](_registry.md) for the authoritative readiness table (do not hand-edit). |

## Scripts

| Script | Purpose |
|---|---|
| `../../scripts/validate-pack.sh` | Pack linter — validates one pack or all packs against the `_lint.md` contract |

## Project-local packs (`<root>/.mega-sdd/packs/`)

A stack the plugin does not ship a pack for (or a house variant of one it does) gets its pack **inside the project**: `<root>/.mega-sdd/packs/<framework>.md`, authored from `_template.md` with a real `detection_signature:` and `extends: _universal` (or any plugin pack). Since 7.12.0 (F-14, spec `2026-08-30-audit-driven-hardening.md` §6) that root is read by every consumer — the resolver (`resolve-framework-pack.sh`: project pack first, then the plugin pack of the same name), the GROUND matcher (`state_probes.probe_framework_pack`, which also reads one-level workspace manifests such as `apps/api/package.json`), and `ground.sh`'s pack-chain checks — and its files are cache inputs. Lint it like a plugin pack: `scripts/validate-pack.sh <root>/.mega-sdd/packs/<framework>.md`. Field origin: a run that authored `elysia.md` there and had 36/36 dispatches fall to `_universal` because nothing read it.

## Opt-out

- `bind-codebase --no-framework-pack` — skip pack loading entirely
- `bind-codebase --framework-pack=<custom-path>` — use a project-specific pack instead of built-in

## Adding a new pack

1. Copy the template by hand: `cp _template.md <framework>.md` (the scaffold script was demoted in v7 Fase 2), then fill the frontmatter stub — set `framework:`, `framework_version_range:`, a real `detection_signature:` (manifest + dependency marker), and rewrite the `extends:` placeholder (usually `_universal`). NOTE: the template's illustrative examples use Laravel tokens — rewrite EVERY example row/path for your framework; the step-4 linter's cross-framework leak check blocks any leftovers (this is the safety net the old scaffold's auto-neutralizer used to provide).
2. Fill in frontmatter (detection signature) + body sections, following the `<!-- REQUIRED -->` markers the scaffold leaves in place.
3. Test detection by running `scan-codebase` against a known project of that framework.
4. Lint the pack: run `scripts/validate-pack.sh <framework>.md` (checklist in `references/framework-conventions/_lint.md`). Fix all reported violations. The CI gate is `validate-pack.sh --all && validate-pack.sh --check-registry` — `--all` is tier-aware: `pack_tier: full` packs must lint completely clean; `thin` proof-packs and untiered packs block only on structural errors (invalid YAML or cross-framework token leak), so missing-section gaps are reported but non-blocking for in-progress thin packs.
5. Regenerate the readiness registry: `scripts/validate-pack.sh --registry`.
6. Submit PR — both `validate-pack.sh --all` and `--check-registry` must exit 0.

## Versioning + maintenance

- Each pack has `framework_version_range:` frontmatter (e.g., `"10.x — 11.x"`)
- `last_verified_against:` date tracks freshness
- When framework releases major version with breaking convention changes, fork to `<framework>-v<N>.md` (e.g., `laravel-v11.md`) or update existing pack with revised `framework_version_range`
- Stale packs (>1 year `last_verified_against`) emit advisory in `scan-codebase` output
