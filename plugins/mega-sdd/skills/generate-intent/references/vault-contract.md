# Vault Contract — conditional overlays

Shared definitions referenced by `mega-sdd` skills — the CONDITIONAL half of the vault contract (v7 Fase 4 R2): §Starterkit-binding loads only under `--scan` (starterkit-first mode), §Multi-scope only for scoped vaults. **The default-lane drafting contract — §schema, §OQ-conventions, Auto-Classification Review, §constitution, §boilerplate, §id-stability — lives in `references/vault-core.md`; this file deliberately carries NO copy.** Single source of truth per section; edits here are breaking changes for sibling skills (bump versions + CHANGELOG).

## Contents

- §Starterkit-binding — Dual-citation format
- §Multi-scope vault — conditional pointer (full schema relocated to `references/multi-scope.md`)
- everything else — relocated to `references/vault-core.md` (drafting core) and `plugins/mega-sdd/references/halt-protocol.md` (halt machinery; tombstone at end of file)

## §Starterkit-binding — Dual-citation format

When `generate-intent` runs with `--scan=<codebase-map-path>` (orchestrate-flow Mode A/B starterkit-first), vault sections that touch implementation conventions use a DUAL-CITATION format: **Intent** (what the design intends) + **Starterkit binding** (how this scaffold realizes that intent). Greenfield mode skips Starterkit binding entirely.

### Sections affected

| Vault file | When dual-citation applies | What "Intent" describes | What "Starterkit binding" describes |
|---|---|---|---|
| `vault.md ## Architecture` | Always when `--scan` set | Conceptual architecture (auth strategy, layering, integration points) | Concrete scaffold-mapped choices (base classes, framework helpers, package selection) |
| `model.md` | When framework pack defines DB conventions | Conceptual ERD (entities, relationships, business rules) | Schema realization (PK type, FK convention, timestamps, soft-delete strategy) |
| `constraints.md` | Always when `--scan` set | Tech-agnostic constraints (style, naming, idioms inferred from PRD/brief) | Pack-specific Hard Rules + forbidden patterns inherited from framework conventions |

### Format

Within each affected section, every architectural decision gets TWO sub-fields:

```markdown
### <Concern> (e.g., Authentication strategy)

**Intent**: <tech-agnostic statement of what the design needs>
**Starterkit binding** (`<pack-name>`):
  - <concrete realization #1>
  - <concrete realization #2>
  - …
  - Citations: `framework-conventions/<pack>.md §<section>`, `codebase-map.md §<n>`
```

### Example

```markdown
### Authentication strategy

**Intent**: Token-based API auth. Refresh-token rotation. Session-based UI auth for admin pages.

**Starterkit binding** (`laravel-base-26`):
  - API auth via Laravel Sanctum (`composer.json` lists `laravel/sanctum: ^4.0`)
  - Routes inside `auth:sanctum + whitelist.host + verified` group (per starterkit convention; see `routes/web.php` pattern)
  - Tokens stored in `personal_access_tokens` table (Sanctum default schema)
  - Session UI auth via Jetstream (already wired via `pixinvent/vuexy-laravel-bootstrap-jetstream`)
  - Citations: `framework-conventions/laravel-base-26.md §Idioms`, `codebase-map.md §7 Framework`
```

### Anti-halu rails

- **Intent** statements MUST be derivable from PRD / brief / KB. Not invented from framework defaults.
- **Starterkit binding** statements MUST cite pack file:section OR codebase-map.md line. No silent invention.
- If a pack doesn't speak to a concern → Starterkit binding sub-field shows `_None (universal defaults apply — see `_universal.md` §<section>)_` or is omitted entirely (per "omit when source content absent" rule).
- When `--greenfield` set → ONLY Intent fields generated; Starterkit binding fields absent (vault stays stack-agnostic).
- When `--scan` set BUT no pack matches (universal fallback) → Starterkit binding fields cite `_universal.md` defaults only.

### Backward compatibility

- Vaults without Starterkit binding fields → consumed unchanged by bind-codebase + generate-units; conventions resolved from binding step instead.
- Mixed vaults (some sections have Starterkit binding, others don't) → permitted; downstream skills handle absence gracefully.
- `bind-codebase` reading a vault with Starterkit binding fields: they supplement Hard Rule emission (clauses cited inline as `source: vault §02-architecture > Starterkit binding > Authentication strategy`).

## §Multi-scope vault — Scope tagging schema

PRD declares a `scopes:` block (or `--scope=<id>` passed)? Read `references/multi-scope.md` (this directory) before scaffolding — it carries the full scope-tagging schema (vault.json extension, field rules, vault.md header structure, validation rules, backward compatibility), relocated verbatim from this section. Single-scope PRDs without a `scopes:` block use the current single-vault schema (no scope tagging).

> §halt-protocol + §halt-escalation-discipline → relocated verbatim to `plugins/mega-sdd/references/halt-protocol.md` — the plugin-root shared ref; from this file the relative path is `../../../references/halt-protocol.md` (`${CLAUDE_PLUGIN_ROOT}` is NOT substituted in reference files, so cite the plugin-root or relative form). Canonical cross-skill halt registry — envelope schema, halt-type enum, C1/C2/C3 categories, and the `quality_gate_failed` subtype enum live there; per-type guidance bodies live in `plugins/mega-sdd/references/halt-families/<family>.md`, routed by the registry index (6.14.0 family split).
