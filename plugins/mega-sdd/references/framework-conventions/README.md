# Framework Convention Packs

Pluggable convention packs for common backend/frontend frameworks. Each pack declares file-location standards, naming standards, idioms, and Hard Rules. The matching framework is detected by the GROUND matcher (`scripts/ground.sh` → `state_probes.probe_framework_pack` → `state.json` `derived.framework_pack`). The pack-driven validators read their sections through `scripts/_lib/resolve-framework-pack.sh`, `scripts/run-code-gates.sh` runs a project pack's `## Toolchain` commands as L0 gates 1–2, and plan's AI technical decisions may cite the pack (`references/vault-core.md §AI technical decisions`); no pack section is injected into the inline run's context.

## Pluggable, not opinionated-by-default

mega-sdd stays framework-agnostic. Convention packs are **OPT-IN BY DETECTION**:

1. GROUND (`scripts/ground.sh` → `state_probes.probe_framework_pack`) matches each pack's `detection_signature` against the root + one-level workspace manifests (`composer.json`, `package.json`, `Gemfile`, `pyproject.toml`/`requirements.txt`, `go.mod`, `Cargo.toml`, `pom.xml`/`build.gradle`, `*.csproj`); the winner goes to `state.json` `derived.framework_pack`
2. The resolver (`scripts/_lib/resolve-framework-pack.sh`) reads it and loads the matching pack chain from this folder (project pack root first) for the pack-driven validators (flow-coverage, sibling-consistency, ui-quality, unit-spec)
3. `execute-bolts`: no pack section reaches the inline run; a pack-derived rule a unit already carries in `## Hard rules` (a migrated vault) is enforced like any Hard rule — v1 mechanical forms deterministically, v2 fenced ast-grep rules via `ast-grep scan`

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
| `<framework>.md` | One pack per framework. All 24 `pack_tier: full` packs lint clean — laravel, django, fastapi, next, express, nestjs, flask, symfony, rails, spring, nuxt, sveltekit, gin, slim, fastify, remix, sinatra, echo, fiber, actix, axum, rocket, aspnetcore, dotnet — plus the untiered project overlay `laravel-base-26` (25 packs). See [`_registry.md`](_registry.md) for the authoritative readiness table (do not hand-edit). |

## Scripts

| Script | Purpose |
|---|---|
| `../../scripts/validate-pack.sh` | Pack linter — validates one pack or all packs against the `_lint.md` contract |

## Project-local packs (`<root>/.mega-sdd/packs/`)

A stack the plugin does not ship a pack for (or a house variant of one it does) gets its pack **inside the project**: `<root>/.mega-sdd/packs/<framework>.md`, authored from `_template.md` with a real `detection_signature:` and `extends: _universal` (or any plugin pack). Since 7.12.0 (F-14, audit-driven-hardening spec §6, commit 9db83686) that root is read by every consumer — the resolver (`resolve-framework-pack.sh`: project pack first, then the plugin pack of the same name), the GROUND matcher (`state_probes.probe_framework_pack`, which also reads one-level workspace manifests such as `apps/api/package.json`), and `ground.sh`'s pack-chain checks — and its files are cache inputs. Lint it like a plugin pack: `scripts/validate-pack.sh <root>/.mega-sdd/packs/<framework>.md`. Field origin: a run that authored `elysia.md` there and had 36/36 dispatches fall to `_universal` because nothing read it.

## Override

Author `<root>/.mega-sdd/packs/<framework>.md`. The resolver and the GROUND matcher read it before the plugin pack; `extends: _universal` neutralizes a plugin pack.

## Adding a new pack

1. Copy the template by hand: `cp _template.md <framework>.md` (the scaffold script was demoted in v7 Fase 2), then fill the frontmatter stub — set `framework:`, `framework_version_range:`, a real `detection_signature:` (manifest + dependency marker), and rewrite the `extends:` placeholder (usually `_universal`). NOTE: the template's illustrative examples use Laravel tokens — rewrite EVERY example row/path for your framework; the step-4 linter's cross-framework leak check blocks any leftovers (this is the safety net the old scaffold's auto-neutralizer used to provide).
2. Fill in frontmatter (detection signature) + body sections, following the `<!-- REQUIRED -->` markers the template carries. Fill `## Code style (self-documenting)` with the stack's DELTA only (doc-comment tool + who reads it, skip/write vocabulary, naming examples) — every `read by` fact web-verified at authoring; REQUIRED since 8.2.0 (`_lint.md` Check 2 header + Check 6 shape; bullet count/byte cap pinned by `tests/per-stack-packs/test-code-style-section.sh`).
3. Test detection by running `scripts/ground.sh --cwd <known project>` (pre-init: `scripts/derive-state.sh --cwd=<project> --json-only`) and checking `state.json` `derived.framework_pack`.
4. Lint the pack: run `scripts/validate-pack.sh <framework>.md` (checklist in `references/framework-conventions/_lint.md`). Fix all reported violations. The CI gate is `validate-pack.sh --all && validate-pack.sh --check-registry` — `--all` is tier-aware: `pack_tier: full` packs must lint completely clean; `thin` proof-packs and untiered packs block only on structural errors (invalid YAML or cross-framework token leak), so missing-section gaps are reported but non-blocking for in-progress thin packs.
5. Regenerate the readiness registry: `scripts/validate-pack.sh --registry`.
6. Submit PR — both `validate-pack.sh --all` and `--check-registry` must exit 0.

## Versioning + maintenance

- Each pack has `framework_version_range:` frontmatter (e.g., `"10.x — 11.x"`)
- `last_verified_against:` date tracks freshness
- When framework releases major version with breaking convention changes, fork to `<framework>-v<N>.md` (e.g., `laravel-v11.md`) or update existing pack with revised `framework_version_range`
