# De-Laravelize the deep-scan core — neutral authz ontology + pack-driven extraction

**Status:** Design approved 2026-06-09 (advisor-hardened)
**Plugin target:** v4.x (sequencing vs starterkit-reuse-awareness + phase-advisor decided at planning)
**Type:** Refactor + extensibility (scan producer + schema + two downstream consumers, in-iter) + one thin proof-pack
**Decomposition:** This is **Spec 3a** of the multi-stack effort. Deferred: **3b** pack-authoring kit (`_lint.md` linter, pack-readiness registry, scaffold), **3c** full per-stack packs (Node/Next/Python/Go/Rust/Rails/Spring).

---

## Background and motivation

Mega-SDD claims to be tech-stack-agnostic and *detects* 22 frameworks, but only Laravel has a convention pack. Worse than the content gap: the supposedly-generic deep-scan machinery still bakes Laravel in at **three layers**, so even adding a pack would not make a non-Laravel stack work.

Verified against the codebase:

1. **Paths** — `deep-scan-prompts.md` hard-codes Laravel file paths in the auth/rbac/ui-ux extractor prompts (`app/Http/Middleware/`, `app/Http/Kernel.php`, `app/Providers/AuthServiceProvider.php`, `resources/views/**/*.blade.php` — lines 78-82, 146-158, 203-220).
2. **Constructs / extraction instructions** — the same prompts instruct the extractor in Laravel's *conceptual model*: "parse `$policies` array", "find `Gate::define` calls → populate `gates[]`", "`$routeMiddleware`", "`@extends('layouts.'`". Substituting a path to `settings.py` still leaves the prompt hunting for `Gate::define` — which does not exist in Django.
3. **Output ontology** — the slice shape itself is Laravel ontology: `rbac: {middleware, gates, policies, default_roles}`. A Django RBAC slice (groups + permission strings + decorators) has nothing to put in `gates`/`policies`.

And the ontology is consumed **structurally** downstream, so it is not a cosmetic leak:

- `generate-units/references/starterkit-derivation.md:133` — `IF starterkit_context.rbac.lib == "spatie/permission"` (hard branch on a Laravel enum value).
- `starterkit-derivation.md:119` — emits Hard Rule `"MUST use auth guard '<auth.guard>'"` ("guard" is a Laravel-only concept).
- `starterkit-derivation.md:74` — `IF starterkit_context.rbac.middleware contains entries`.
- `execute-bolts/references/bolt-dispatch-prompt.md:201` + `context-enrichment.md:252` — inject `rbac.lib / role_model / middleware` into the bolt prompt.

So a path-only parameterization (`<RBAC_FILE_HINTS>`) is a **paper unlock**: it would look done but ship a still-Laravel-shaped prompt, schema, and consumer chain. The honest fix reaches the **ontology**.

Scope decision: adopt a **neutral authz ontology** that each pack maps its constructs onto (option X — chosen over Y "each pack emits its own shape", because the downstream consumers need a *uniform* slice regardless of stack). Validate the abstraction with **one thin Django proof-pack** in-iter — `_universal` hints alone can only prove the *negative* (doesn't look in `app/Http`), never the *positive* (correctly extracts a second paradigm's RBAC).

---

## §1 Architecture overview

The deep-scan extractor prompts become thin, ontology-typed shells. Each framework pack supplies, in a new `## Deep-scan file hints` + `## Authz mapping` section, both **where** to look (file hints) and **how that stack's constructs map onto the neutral ontology**. The consolidated slice is emitted in the neutral shape. The two downstream consumers (`generate-units` starterkit-derivation; `execute-bolts` dispatch/context-enrichment) read the neutral shape, so they work identically for any stack whose pack provides the mapping. `_universal.md` supplies cross-stack generic hints so an unknown stack degrades sensibly instead of looking for Laravel files. A thin Django pack proves the abstraction against a maximally-different paradigm.

Laravel behavior is preserved exactly: the Laravel paths/constructs move *out of the prompt* and *into `laravel.md`*; the assembled Laravel prompt string is asserted byte-equal to the current hard-coded one (deterministic regression — not LLM output).

### File version bumps

- `scan-codebase` — minor bump (prompt parameterization + neutral-shape emission)
- `generate-units` — minor bump (starterkit-derivation reads neutral ontology)
- `execute-bolts` — minor bump (dispatch/context-enrichment read neutral ontology)
- `starterkit-context-schema.md` — schema_version bump (rbac → authz; open auth/rbac libs)
- `framework-conventions/_template.md` + `laravel.md` + `_universal.md` — new hints + authz-mapping sections
- New: `framework-conventions/django.md` (thin proof-pack) + `lib-patterns/django/` (minimal)
- Plugin — minor bump (`plugin.json` + `marketplace.json` in sync)

---

## §2 The neutral authz ontology

### 2.1 Shape (replaces Laravel-shaped `auth` + `rbac` blocks)

```yaml
auth:                                  # authentication
  lib: "<open string>"                 # e.g. sanctum | django-allauth | passport | not_detected (NOT a closed enum)
  lib_source: "<file:line proving the lib>"
  mechanism: session | token | jwt | oauth | builtin | unknown
  user_model: "<FQCN or path or null>"
  entrypoints:                         # login / register / logout handlers
    - { name: "<handler>", _source: "file:line" }
  _source: "file:line"

authz:                                 # authorization (replaces `rbac`)
  lib: "<open string>"                 # e.g. spatie/permission | django.contrib.auth | casl | not_detected
  lib_source: "<file:line>"
  mechanism: middleware | decorator | guard | policy | mixin | builtin | unknown
  role_source: model | config | db | enum | unknown      # where roles/groups are defined
  declarations:                        # the access-control rules, stack-neutral
    - name: "<role | permission | gate | policy name>"
      kind: role | permission | gate | policy | group
      applies_to: "<route/controller/view it guards, or null>"
      _source: "file:line"
  _source: "file:line"
```

**Why this shape.** Every stack expresses authorization as *some mechanism* applying *some named declarations* over *some targets*, with roles defined *somewhere*. That is the invariant; `middleware/gates/policies` was just Laravel's spelling of it.

### 2.2 Mapping examples (pack-supplied)

| | Laravel | Django |
|---|---|---|
| `authz.mechanism` | `middleware` (+ `policy`) | `decorator` (+ `mixin`, `builtin`) |
| `authz.role_source` | `model` (spatie roles table) | `db` (auth `Group`) |
| `authz.declarations` | `Gate::define` → kind=gate; `$policies` → kind=policy; spatie roles → kind=role | `@permission_required('app.x')` / `PermissionRequiredMixin` → kind=permission; `Group` → kind=group |
| `auth.mechanism` | `session`/`token` (guard) | `session` (Django auth) |

Each pack's `## Authz mapping` section tells the extractor: which constructs of this stack become which `declarations.kind`, what `mechanism`/`role_source` to record, and the file hints to read.

### 2.3 Open libs (was: closed enums)

`auth.lib` / `authz.lib` accept **any string** (with `lib_source` evidence). `not_detected` remains the sentinel. A pack MAY ship a known-libs list for normalization, but the field is never a closed enum. This kills the "Django auth → not_detected" trap.

---

## §3 Extractor prompt parameterization

`deep-scan-prompts.md` auth/rbac(→authz)/ui-ux extractor prompts replace baked-in Laravel paths AND constructs with pack-injected placeholders:

- `<AUTH_FILE_HINTS>` / `<AUTHZ_FILE_HINTS>` / `<UI_FILE_HINTS>` — where to look (from pack `## Deep-scan file hints`).
- `<AUTH_CONSTRUCT_MAP>` / `<AUTHZ_CONSTRUCT_MAP>` / `<UI_CONSTRUCT_MAP>` — what constructs to find and how to map them (from pack `## Authz mapping` for auth/authz; `## UI detection` for ui-ux).
- The authz prompt becomes ontology-typed and stack-neutral: "Read `<AUTHZ_FILE_HINTS>`. Using `<AUTHZ_CONSTRUCT_MAP>`, extract each access-control declaration as `{name, kind, applies_to, _source}` and record `mechanism` + `role_source`." No `Gate::define` / `$policies` / `guard` in the generic prompt.
- The ui-ux prompt is parameterized the same way: the **construct-level** Laravel instructions (`@extends('layouts.'` for dominant-layout detection, `@heroicons`/blade-component probes for icon/component detection) move into the pack's `## UI detection` block, surfaced as `<UI_CONSTRUCT_MAP>` ("how this stack declares a layout/template-inheritance, a component, a notification call"). The generic ui-ux prompt names no Laravel construct. The `ui_ux` *output* fields (js_framework / css_framework / notification_lib / layout_extends) are already framework-neutral and are retained as-is — only the *detection instructions* are de-Laravelized.

When no pack (or pack lacks a section), the prompt falls back to `_universal.md`'s generic hints + a generic construct heuristic (search common authz markers across stacks). Generic hints are explicitly NOT Laravel-shaped (e.g., `**/middleware/**`, `**/permissions*`, `**/decorators*`, `**/templates/**`, `**/views/**`).

---

## §4 Pack contract extension

`_template.md` gains three required-when-applicable sections (documented as the contract for every future pack):

- `## Deep-scan file hints` — `auth_hints`, `authz_hints`, `ui_hints` (glob/path lists).
- `## Authz mapping` — `auth.mechanism`, `authz.mechanism`, `authz.role_source`, and the construct→`declarations.kind` table for this stack.
- `## UI detection` — how this stack declares template inheritance / dominant layout, a component, and a notification call (feeds `<UI_CONSTRUCT_MAP>`).

`laravel.md` is populated with the paths/constructs **moved out of the prompt** (so Laravel output is unchanged, sourced from the pack). `_universal.md` gains the generic cross-stack hints + a generic authz heuristic.

---

## §5 Downstream consumer migration (the ripple)

The neutral ontology must be read by everything that consumed the old `rbac`/`auth` shape, or the unlock stops at the schema. **Grepped repo-wide** (`rbac\.`, `starterkit_context.rbac`, `\.gates`, `\.policies`, `default_roles`, `auth\.guard`, `rbac.role_model`); the complete consumer set is: the producer (`deep-scan-prompts.md`, §3) + the schema (`starterkit-context-schema.md`, §2) + the three below. No other skill/hook reads the shape.

### 5.1 generate-units / starterkit-derivation.md
- `IF rbac.lib == "spatie/permission"` → **ontology-driven**: `IF authz.declarations has kind in [role, permission]` (no branch on a Laravel lib value).
- Hard Rule `"MUST use auth guard '<auth.guard>'"` → `"MUST apply authorization via <authz.mechanism> using the existing declarations (<names>)"`. Laravel still renders middleware/guard wording via its mapping; Django renders decorator wording. The rule is generated from the ontology, not from the word "guard".
- `IF rbac.middleware contains entries` → `IF authz.declarations non-empty`.

### 5.2 execute-bolts / bolt-dispatch-prompt.md + context-enrichment.md
- `RBAC: lib=<rbac.lib>, role_model=<rbac.role_model>, middleware=<rbac.middleware…>` → `Authz: lib=<authz.lib>, mechanism=<authz.mechanism>, declarations=<authz.declarations names…>`.

### 5.3 orchestrate-flow / handoff-contract.md
The handoff contract carries the starterkit slice forward between phases and references the old `rbac`/`auth` shape — update its documented shape to the neutral `auth`/`authz` ontology so the chain's handoff schema matches what scan now emits.

(`auto-and-memory.md` / `halts-and-handoff.md` carry `auth_lib`/`rbac_lib` only as illustrative memory examples — update labels to `authz_lib` for consistency; no structural branch there.)

---

## §6 Django proof-pack (thin, in-iter)

Just enough to prove the ontology holds against a non-MVC-Laravel paradigm — NOT a production-complete pack (that is 3c):

- `framework-conventions/django.md`: frontmatter detection signature; `## File location standards` (models.py, views.py, urls.py, templates/, migrations/); `## Deep-scan file hints` (authz: settings.py `AUTH_*`, app `permissions.py`/decorators, `Group`; ui: `templates/`, `static/`); `## Authz mapping` (decorators/mixins/groups → declarations); minimal naming + idioms.
- `lib-patterns/django/` minimal catalogs (auth: django built-in / allauth / DRF; authz: django.contrib.auth perms / django-guardian).
- Detection fingerprint already present in `scan-procedure.md §8.5` (line 156: `pyproject.toml`/`requirements.txt` → `django`) — no detection-table change needed.

---

## §6.5 Committed fixture migration (in-iter, mandatory)

A repo-wide grep found **~25 committed `starterkit-context.yaml` fixtures** carrying the old `rbac:`/`auth.guard` shape — under `tests/fixtures/code-delivery/*/{good,bad}/`, `tests/fixtures/sample-project/`, `tests/fixtures/iter76-patterns-injection/`, plus references in `tests/skill-triggering/scan-codebase.test.md` and `tests/scenarios/scenario-8-starterkit-aware-generation.md`. The `rbac:`→`authz:` rename + restructure breaks these on load, so migrating them is **part of 3a, not optional**:

- Mechanically migrate each fixture's `rbac:` block to the neutral `authz:` shape (and `auth.guard` → `auth.mechanism`), preserving the scenario each fixture exercises.
- Re-run the code-delivery validators (sibling-consistency, dispatch-prompt, cross-cutting, ui-quality, etc.) against the migrated fixtures; they must pass unchanged (the validators key off presence/structure, not the Laravel field names — confirm during execution).
- Bonus: `tests/fixtures/code-delivery/regressions/tae2e-nonlaravel-fk/` is an existing **non-Laravel** fixture — reuse/extend it for §8.2 path-unbinding rather than authoring a new one.

This is the largest mechanical slice of 3a and the planner must budget for it explicitly.

## §7 Halt protocol + error handling

No new blocking halt.

| Condition | Behavior |
|---|---|
| Pack lacks `## Deep-scan file hints` / `## Authz mapping` | fall back to `_universal` generic hints + heuristic; record `authz.mechanism: unknown` rather than fabricate |
| Stack has no authorization | `authz.declarations: []`, `mechanism: unknown` — valid, not an error |
| Construct found but unmappable | record as `declarations[].kind` best-effort + `_source`; never drop the `_source` |
| Old-shape `rbac:` slice encountered at runtime (stale user cache) | schema_version mismatch → scan regenerates in neutral shape (a user's runtime starterkit-context.yaml is a regenerable cache) |

### Anti-halu rails (new)
1. No `declarations[]` entry without `_source`.
2. `auth.lib`/`authz.lib` require `lib_source`; absent → `not_detected`, never a guessed lib.
3. The generic prompt contains **zero** framework-specific construct names — those live only in pack `## Authz mapping`.
4. Unmappable construct → `mechanism: unknown`, never silently coerced into a Laravel `kind`.

---

## §8 Testing

### 8.1 Regression (deterministic — architecture-honest)
Prompt assembly is **model-driven** (the `scan-codebase` skill composes each dispatch prompt by substituting placeholders into the template + pack hints, then calls the Agent tool — there is no assembler script, so there is no runtime "assembled string" artifact to diff). The deterministic regression is therefore at the **artifact level**, two checks:

1. **Clean-template check** (the negative): grep the generic prompt templates in `deep-scan-prompts.md` for Laravel tokens (`app/Http`, `Gate::define`, `$policies`, `$routeMiddleware`, `@extends`, `@heroicons`, `guard`, `blade`) → must be **zero**.
2. **Relocation-coverage check** (the preservation guarantee): snapshot, before the refactor, the exact set of Laravel paths + construct tokens the current auth/authz/ui-ux prompts contain (a golden token set). After the refactor, assert every token in that golden set now appears in `laravel.md` (moved, not lost). This proves "Laravel knowledge preserved + relocated to the pack" without asserting a runtime composition the model-driven architecture doesn't deterministically produce.

(Optional future hardening, OUT OF SCOPE for 3a: introduce a deterministic prompt-assembler script so a literal byte-equal assembled-string diff becomes possible. Not taken here — it changes the dispatch architecture.)

### 8.2 Path-unbinding (the negative — what `_universal` can prove)
On a non-Laravel fixture with no pack, assert the assembled prompt contains **no** Laravel paths/constructs (`app/Http`, `Gate::define`, `@extends`, etc.) and uses `_universal` generic hints.

### 8.3 Ontology positive (the proof-pack — what `_universal` cannot prove)
On a Django fixture WITH `django.md`: assert the extractor reads Django hint paths, maps `@permission_required` / `Group` into `authz.declarations` with correct `kind`, records `mechanism: decorator`/`builtin`, and `authz.lib` is the real Django auth lib (not `not_detected`).

### 8.4 Consumer migration
- starterkit-derivation: a Django `authz` slice produces ontology-driven Hard Rules (no "guard" wording); a Laravel `authz` slice still produces the equivalent Laravel-flavored rule.
- bolt-dispatch: the injected `Authz:` line renders from the neutral shape for both stacks.

### 8.5 Field test
The user's Laravel starterkit: full pipeline, confirm output unchanged (regression). The Django fixture: confirm RBAC is extracted into the neutral shape and flows to a unit Hard Rule.

---

## Acceptance criteria

1. `deep-scan-prompts.md` generic prompts (auth/authz **and ui-ux**) contain **zero** Laravel paths AND zero Laravel construct names (`Gate::define`, `$policies`, `$routeMiddleware`, `@extends`, `@heroicons`, `guard`); all live in `laravel.md`.
2. Slice schema emits the neutral `auth` + `authz` shape; `auth.lib`/`authz.lib` are open strings with `lib_source`.
3. All three downstream consumers (starterkit-derivation; bolt-dispatch/context-enrichment; orchestrate-flow handoff-contract) read the neutral ontology; the `IF rbac.lib == "spatie/permission"` branch and the "guard" Hard Rule are ontology-driven, not Laravel-value-driven.
4. Laravel regression (artifact-level, deterministic): generic templates contain zero Laravel tokens AND every Laravel token in the pre-refactor golden set now appears in `laravel.md` (relocation-coverage). (Assembly is model-driven; no runtime-string diff — §8.1.)
5. `_universal.md` generic hints are not Laravel-shaped; an unknown stack degrades to them without looking for `app/Http`.
6. `_template.md` documents the `## Deep-scan file hints` + `## Authz mapping` + `## UI detection` contract.
7. Django proof-pack extracts Django RBAC into the neutral ontology (positive validation against a second paradigm), proving option X holds.
8. All ~25 committed `starterkit-context.yaml` fixtures are migrated to the neutral shape and the code-delivery validator suite passes.
9. No new blocking hook.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Path-only "paper unlock" (the original trap) | ontology + construct-map are first-class in the design; acceptance #1/#3 forbid construct leak, not just path leak |
| Neutral ontology too lossy for some stack's RBAC | `declarations[].kind` open-ish + `extras`-style escape via `_source`; proof-pack stress-tests against Django before committing the shape |
| Consumer migration misses a structural read | §5 enumerates every grepped consumer; acceptance #3 gates it |
| Stale old-shape cache | schema_version bump + regenerable-cache semantics |
| "Byte-identical assembled prompt" untestable (assembly is model-driven, no assembler script) | regression is artifact-level: clean-template grep + golden relocation-coverage of Laravel tokens into `laravel.md` (§8.1) |
| Scope creep into full packs | only a *thin* Django proof-pack in 3a; full packs are 3c |

---

## Out of scope (deferred)

- **3b**: pack-authoring kit — `_lint.md` linter (currently TBD in README), pack-readiness registry, scaffold generator.
- **3c**: production-complete packs for Node (Express/NestJS), Next/Nuxt/SvelteKit, Python (Django full/FastAPI), Go, Rust, Rails, Spring — one spec per stack.
- A neutral *output* ontology for ui-ux (the `ui_ux` fields are already framework-neutral; only ui-ux *detection constructs* are de-Laravelized here via `<UI_CONSTRUCT_MAP>`).
- Re-mapping the `patterns:` block / other non-authz slices beyond their existing pack-driven design.

---

## Spec self-review checklist

- [x] No placeholders / TBDs remain.
- [x] Addresses all THREE leak layers (path §3, construct §3, ontology §2) **for authz AND ui-ux** — no paper-unlock left in the ui dimension; §3/§4/acceptance #1/out-of-scope agree.
- [x] Neutral ontology (§2) is consumed by every **repo-wide-grepped** downstream surface (§5: starterkit-derivation + bolt-dispatch/context-enrichment + orchestrate-flow handoff) — no structural read left on the old shape.
- [x] Enum-opening (§2.3) paired with consumer migration of the `== "spatie/permission"` branch (§5.1).
- [x] Regression assertion is deterministic AND architecture-honest: assembly is model-driven (no assembler script), so regression is artifact-level (clean-template grep + golden relocation-coverage), not a fictional runtime-string diff (§8.1).
- [x] Validation honesty: `_universal` proves the negative (§8.2); Django proof-pack proves the positive (§8.3).
- [x] Committed-fixture migration (~25 files) is in-scope and budgeted (§6.5), not assumed away — codebase claim verified by grep.
- [x] Django fingerprint verified present (scan-procedure.md:156); no detection-table change.
- [x] Scope bounded to 3a; 3b/3c explicitly deferred.
