# Multi-scope Vault — Scope Tagging Schema

> Relocated **verbatim** from `vault-contract.md §Multi-scope vault` (same directory; that file keeps a conditional pointer). Load when the PRD declares a `scopes:` block or `--scope=<id>` is passed.

## §Multi-scope vault — Scope tagging schema

When `generate-intent` runs with `--scope=<id>` flag OR canonical PRD has `scopes:` block, the vault is tagged with scope metadata. Single-scope PRDs without scopes block use current single-vault schema (no scope tagging).

> **W5 patch-lane:** `title` / `scope` / `scope_metadata` / `prd_sha256` / `prd_path_at_generation` are AUTHORED fields — supply them in the `--patch` JSON consumed by `scripts/derive-vault-json.sh` at Step 3.8 (never hand-write vault.json). The deriver carries them forward verbatim on every later derive; `prd_sha256` is the at-generation pin `diff-vault` compares against and is NEVER recomputed by the script.

### vault.json extension

```json
{
  "version": "1.0",
  "title": "Order Management System — BE",
  "implementation_mode": "existing",
  "scope": "BE",
  "scope_metadata": {
    "id": "BE",
    "name": "Backend API",
    "pics": ["BE Architect 1", "BE Architect 2"],
    "priority": 1,
    "prd_sections_used": ["§Backend", "§1", "§2", "§3", "§4", "§5", "§6", "§7", "§9"],
    "sibling_scopes_in_prd": ["MW", "FE"],
    "consumed_locked_contracts": [],
    "published_locked_contracts": ["be-mw-event-bus", "be-fe-orders-api"]
  },
  "prd_sha256": "abc123...",
  "prd_path_at_generation": "./shared-docs/prd.md"
}
```

### Field rules

| Field | Required | Set by | Purpose |
|---|---|---|---|
| `scope` | When `scope_metadata` exists | generate-intent Step 0.9 | Quick lookup; matches `scope_metadata.id` |
| `scope_metadata.id` | Yes | generate-intent | Stable id from PRD frontmatter |
| `scope_metadata.name` | Yes | generate-intent | Display name from PRD frontmatter |
| `scope_metadata.pics` | Yes | generate-intent | Array of architect names (team-shared) |
| `scope_metadata.priority` | No (default 1) | generate-intent | Delivery sequencing hint |
| `scope_metadata.prd_sections_used` | Yes | generate-intent | Computed: universal_sections + scope.sections |
| `scope_metadata.sibling_scopes_in_prd` | Yes | generate-intent | Other scopes from PRD (informational) |
| `scope_metadata.consumed_locked_contracts` | Yes | generate-intent | From PRD scope's `depends_on_locked_contracts` |
| `scope_metadata.published_locked_contracts` | Yes | generate-intent | Computed: contracts where this scope is `from` in `cross_scope_dependencies` |
| `prd_sha256` | Yes | generate-intent | For memory-driven scope default on re-invocation |
| `prd_path_at_generation` | Yes | generate-intent | For PRD change tracking via diff-vault |

### vault.md header structure

When vault has scope metadata, the `vault.md` header MUST include:

```markdown
# Vault: <Project Name> — <Scope ID>

**Scope**: <scope_metadata.name> (`<scope_metadata.id>`)
**PICs**: <comma-separated pics list>
**Priority**: <scope_metadata.priority> (delivery sequencing hint)
**PRD source**: `<prd_path_at_generation>` (sha256: `<prd_sha256>`)
**Universal sections included**: <comma-separated universal_sections>
**Scope-specific section**: <scope_metadata.sections>

## Sibling scopes (managed externally — NOT in this vault)

- **<sibling_id>** — <sibling_name> (PIC: <name>; priority: <N>)
- ...

> Cross-scope coordination handled OUTSIDE mega-sdd. Each scope generates an independent vault.
> Locked contracts cross-referenced below for awareness, NOT enforcement.

## Locked contracts this scope PUBLISHES

- `<contract-id>` → see PRD §Cross-scope contracts > <contract-id>
- ...

## Locked contracts this scope CONSUMES

- `<contract-id>` → see PRD §Cross-scope contracts > <contract-id>
- ...
```

When vault has NO scope metadata (legacy single-scope PRD), 00-index.md header omits scope/sibling/contracts sections entirely.

### Validation rules (enforced by generate-intent when assembling the authored patch)

- If `scope` field present → `scope_metadata` MUST exist with all required fields
- `scope_metadata.id` MUST match PRD frontmatter `scopes.<id>` key
- `sibling_scopes_in_prd` MUST list ALL other scopes from PRD scopes block (not chosen ones)
- `prd_sha256` MUST be sha256 of PRD content at generation time (used by memory recall) — computed once into the initial `--patch`; later derives carry it forward, and only `diff-vault` re-baselines it via its sources-patch
- When chosen scope == `all` (legacy flag) → patch omits the `scope` field (back-compat)

### Backward compatibility

- Vaults without a `scope` field → consumed unchanged by bind-codebase + generate-units
- Mixed vaults (some scoped, some legacy) permitted in same project — orchestrate-flow handles both
- diff-vault reads `prd_sha256` to detect PRD changes; vaults without `prd_sha256` skip this check gracefully
