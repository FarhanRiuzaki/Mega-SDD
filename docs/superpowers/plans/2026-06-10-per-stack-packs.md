# Per-Stack Packs (3c) Implementation Plan

> **For agentic workers:** authored via parallel subagent authoring (one pack per agent), controller commits + verifies. Spec: `docs/superpowers/specs/2026-06-10-per-stack-packs-design.md`.

**Goal:** Ship five full, lint-clean framework packs (fastapi, next, express, nestjs, django-promote) so mega-sdd deep-scan is framework-accurate beyond Laravel.

**Architecture:** Each pack authored to the 3b `_template.md` contract, content grounded in official docs (context7). Linter (`validate-pack.sh`) is the objective gate. `_registry.md` regenerated; tier-aware `--all` stays green.

**Tech Stack:** markdown packs, bash gate suite `tests/per-stack-packs/`.

---

## Task 0: Leak-map fix + gate suite scaffold

**Files:** `_lint.md` (done: pyproject.toml removed from django), `tests/per-stack-packs/{run-all.sh,test-five-ready.sh,test-each-lints.sh,test-all-green.sh}`

- [ ] `tests/per-stack-packs/run-all.sh` — copy the pack-kit runner (`cd "$here/../.."`, loop `test-*.sh`). chmod +x.
- [ ] `test-five-ready.sh`: assert `_registry.md` shows each of fastapi/next/express/nestjs/django with status `ready`:
```bash
#!/usr/bin/env bash
set -u
r="plugins/mega-sdd/references/framework-conventions/_registry.md"
for fw in fastapi next express nestjs django; do
  grep -qiE "^\| $fw .*ready" "$r" || { echo "$fw not ready in registry"; exit 1; }
done
exit 0
```
- [ ] `test-each-lints.sh`: each of the five lints clean (single mode, rc 0):
```bash
#!/usr/bin/env bash
set -u
for fw in fastapi next express nestjs django; do
  bash plugins/mega-sdd/scripts/validate-pack.sh "plugins/mega-sdd/references/framework-conventions/$fw.md" >/dev/null 2>&1 \
    || { echo "$fw.md has lint violations"; exit 1; }
done
exit 0
```
- [ ] `test-all-green.sh`: `validate-pack.sh --all` and `--check-registry` both exit 0.
- [ ] All three fail now (packs not authored) → expected RED.

## Tasks 1–5: Author each pack (parallel subagents)

Each subagent authors ONE pack to the §3 contract, content grounded in official docs, then runs `validate-pack.sh <pack>` until zero violations. Writes the file only (controller commits). Exemplar: `laravel.md`. Contract: `_template.md`. Rules: `_lint.md`.

- [ ] T1 `fastapi.md` — Python async API. package_manifest pyproject.toml, marker `fastapi`. Authz: `Depends()`/`Security()` + scopes (OAuth2). UI: `_(N/A: API-only)_` (FastAPI is API-first; note Jinja2 templates only if used). Reuse: routers/dependencies/services.
- [ ] T2 `next.md` — React/TS. package_manifest package.json, marker `next`. App Router default (note Pages Router). Authz: middleware.ts + NextAuth/Auth.js. UI: app/ layouts, components, client/server components.
- [ ] T3 `express.md` — Node minimal. marker `express`. Authz: middleware (passport/jwt). UI: usually `_(N/A: API-only)_` or templating engine (ejs/pug) if used. Reuse: routes/middleware/services/controllers.
- [ ] T4 `nestjs.md` — Node decorator/DI. marker `@nestjs/core`. Authz: Guards (`@UseGuards`, `CanActivate`) + decorators. Modules/providers/controllers. UI: `_(N/A: API-only)_` typical. Reuse: providers/services/modules.
- [ ] T5 `django.md` — PROMOTE existing thin → full. Add the 4 missing required-always sections (Naming, Idioms, Hard Rules, Testing) + framework_version_range + pack_tier:full; keep its existing good sections (File location, Deep-scan hints, Authz mapping, UI detection, Reuse discovery). Fix any remaining lint violations.

## Task 6: Finalize

**Files:** `_registry.md` (regen), `plugin.json`, `marketplace.json`, `CHANGELOG.md`

- [ ] Controller commits each authored pack (separate files, sequential commits).
- [ ] `validate-pack.sh --registry` → regen `_registry.md`.
- [ ] Run `test-each-lints.sh`, `test-five-ready.sh`, `test-all-green.sh` → all 0.
- [ ] Bump plugin.json + marketplace.json 4.7.0 → 4.8.0; CHANGELOG `[4.8.0]` entry.
- [ ] Full gates: `for t in per-stack-packs pack-kit de-laravelize reuse-awareness phase-advisor; do bash tests/$t/run-all.sh >/dev/null 2>&1; echo "$t=$?"; done` → all 0. JSON valid.
- [ ] Commit release.
