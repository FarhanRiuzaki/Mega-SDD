# Per-Stack Packs (3c) — Design

**Status:** approved (scope chosen via decision matrix 2026-06-10)
**Depends on:** 3b pack-authoring kit (v4.7.0) — `_template.md` contract, `_lint.md`, `validate-pack.sh`, `scaffold-pack.sh`, `_registry.md`.

## 1. Goal

Make mega-sdd genuinely multi-stack at the *pack* layer by authoring **five full, lint-clean framework convention packs**. Today only Laravel is `pack_tier: full`; everything else falls back to the generic `_universal` pack, so deep-scan extraction (auth/authz/UI/reuse) is generic rather than framework-accurate for non-Laravel stacks.

## 2. Scope (exactly these five)

| Framework | File | Action | Type |
|---|---|---|---|
| FastAPI | `fastapi.md` | new | full |
| Next.js | `next.md` | new | full |
| Express | `express.md` | new | full |
| NestJS | `nestjs.md` | new | full |
| Django | `django.md` | **promote** thin → full | full |

File names MUST match the §8.5 framework-detection names (`fastapi`, `next`, `express`, `nestjs`, `django`) so `_registry.md` links them.

**Non-goals:** the other ~17 detected frameworks (symfony, rails, spring, flask, go/rust frameworks, etc.) — a later pass, now cheap. Matching `laravel.md`'s *full* richness (its extra sections — Flow-artifact derivation, Entity globs, Cross-cutting concerns, etc.) is OPTIONAL; the bar here is the 9 contract sections authored with real, doc-grounded content.

### Amendment — Wave 2 (2026-06-10, v4.9.0)

Scope extended beyond the original five. Wave 2 added seven more full packs: `flask`, `symfony`, `rails`, `spring`, `nuxt`, `sveltekit`, `gin` (12 full-pack frameworks total). Same contract + acceptance as §3/§6 applied per pack. Two supporting changes were required: (a) a §8.5 detection row for Spring (`pom.xml`/`build.gradle` → `spring-boot-starter`) — the first JVM entry, without which Spring was undetectable and `spring.md` unreachable; (b) further leak-map precision (dropped generic `composer.json` and Jinja2 `{%extends`/`{%block` — shared across PHP/Python frameworks, not distinctive). A wave-proof gate (`test-all-full-ready.sh`) now enforces "every `pack_tier: full` pack lints clean AND registers `ready`" so future waves need no per-framework test edits.

### Amendment — Wave 3 (2026-06-10, v4.10.0) — long tail complete

The remaining nine were authored: `slim` (PHP), `fastify`, `remix` (JS), `sinatra` (Ruby), `echo`, `fiber` (Go), `actix`, `axum`, `rocket` (Rust). **All 22 detectable §8.5 frameworks now have full `ready` packs.** One supporting change: dropped generic `Gemfile` from rails's leak tokens (generic Ruby, shared by sinatra). Content-only — no skill change (all nine were already in §8.5).

**Only remaining non-`ready` registry row:** `laravel-base-26` (`unknown`) — a project-specific starterkit pack, NOT a coverage gap. Whether it belongs in `framework-conventions/` vs a fork is an open governance decision (tracked separately), unrelated to 3c.

## 3. Per-pack contract (what "full lint-clean" means)

Each pack MUST satisfy `validate-pack.sh <pack>` with **zero violations** AND carry `pack_tier: full`, i.e.:

**Frontmatter:** `framework:`, `framework_version_range:`, `detection_signature:` (`package_manifest:`, `dependency_marker:`, recommended `version_regex:`), `extends: _universal`, `pack_tier: full`, plus `last_verified_against:` + `maintainer: mega-sdd`.

**Sections (all 9):**
1. `## File location standards` — table: artifact kind → path glob.
2. `## Naming standards` — table: class/function/file/route conventions.
3. `## Idioms` — the framework's preferred patterns (bullets).
4. `## Hard Rules emitted` — fenced `HARD_RULE:` entries that merge into `binding.md`.
5. `## Testing conventions` — runner, test file location/naming, fixtures.
6. `## Deep-scan file hints` — ```yaml with `auth_hints:`/`authz_hints:`/`ui_hints:` glob lists (valid YAML).
7. `## Authz mapping` — the **neutral 3a ontology**: `mechanism`, `role_source`, and Construct → `declarations[].kind` mappings. Use `_(N/A: ...)_` ONLY if the framework truly has no built-in authz.
8. `## UI detection` — dominant layout / component dir / notification / icon+datatable libs. For API-only stacks (Express/NestJS/FastAPI when used as pure APIs) use `_(N/A: API-only / no UI)_` OR document the common templating choice — author's judgment, grounded in the stack's real norms.
9. `## Reuse discovery` — ```yaml `reuse_hints:` (helpers/model_api/services/commands globs; valid YAML — `key: [` with the space).

## 4. Sourcing discipline (no fabrication)

Conventions MUST be grounded in the framework's official docs (use context7 / official documentation), not invented. This mirrors the user's standing rule "ikutin docs sebagai acuan code." Where a stack has multiple common conventions (e.g. Next.js App Router vs Pages Router), document the **current default** (App Router) and note the alternative briefly.

## 5. Leak-map refinement

`pyproject.toml` removed from django's cross-framework token list in `_lint.md` (it is a generic Python marker used by FastAPI/Flask/Poetry, not django-distinctive). Django's distinctive tokens (`settings.py`, `INSTALLED_APPS`, `models.Model`, `urls.py`, `manage.py`, `{%…%}` tags) remain. Adding the four new frameworks to the token map is an OPTIONAL future hardening (deferred — low risk this batch since each pack is authored fresh).

## 6. Acceptance

1. All five files exist with `pack_tier: full`; `validate-pack.sh <each>` exits 0.
2. `validate-pack.sh --registry` regenerated; `_registry.md` shows fastapi/next/express/nestjs/django all = `ready`.
3. `validate-pack.sh --all` exits 0; `validate-pack.sh --check-registry` exits 0.
4. New gate suite `tests/per-stack-packs/` green; existing suites (pack-kit, de-laravelize, reuse-awareness, phase-advisor) stay green.
5. Plugin version 4.7.0 → 4.8.0 (plugin.json + marketplace.json), CHANGELOG entry. No skill version change (content-only — new reference packs).

## 7. Out of scope / risks

- `laravel-base-26.md` governance question is unrelated to 3c (tracked separately).
- These packs are authored from docs + general framework knowledge, not from scanning a real repo of each stack; `last_verified_against` records the authoring date. Real-world refinement happens when each is first used against an actual project.
