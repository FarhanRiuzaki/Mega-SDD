# Modules Schema (v2.2+, Iter 11)

Semantic grouping layer ABOVE units. Units stay atomic (1 unit = 1 PR-sized commit per Iter 1 invariant); modules aggregate related units per domain / flow / component for human mental-model fit + progress tracking + filtered execution.

Per user UX request — units felt "too small" cognitively; need module-level grouping to match team mental model (auth phase, leave-mgmt phase, etc.).

## Contents
- Why modules ≠ bigger units
- Vault layout addition
- `_meta/modules.yaml` schema
- Auto-derivation rules (when modules.yaml absent)
- Unit frontmatter extension
- `_index.md` template (grouped by module)
- Module dependency graph
- Module-level DoD validation
- Filtered execution (`execute-bolts --module=<id>`)
- Module-level progress in memory
- Halt protocol additions
- Backward compatibility
- Migration
- References

## Why modules ≠ bigger units

Module = **semantic grouping** (like Jira Epic over Stories). Units = **atomic implementation work** (TDD-discipline + bolt-focus + rollback granularity preserved). The two layer; neither replaces the other.

| Concern | Larger atomic units | Modules over atomic units (THIS DESIGN) |
|---|---|---|
| TDD cycle | One test per huge unit — long cycle | One test per atomic unit — fast cycle |
| Hard Rule scoping | Muddled across surface | Clear per atomic boundary |
| Bolt focus | LLM context diluted | LLM holds one unit at a time |
| Git rollback granularity | Coarse | Per-unit |
| Parallelism (`--per-squad`, `--parallel`) | Lower | Preserved |
| Semantic grouping | "Sort of" via larger size | Explicit via module field |
| Progress tracking | Per-unit (overwhelming) | Per-module (meaningful) + per-unit (detail) |

Modules are the strictly-better answer for the user's stated pain.

## Vault layout addition

```
<vault>/
├── 00-index.md
├── 01-overview.md ... 06-constraints.md
├── vault.json
├── _meta/
│   ├── squads.yaml                  # multi-squad (Iter 1.1; unchanged)
│   └── modules.yaml                 # NEW v2.2+ (Iter 11) — semantic grouping
├── units/
│   ├── U-*.md                       # each unit gains `module: <id>` frontmatter field
│   └── _index.md                    # grouped by module (NEW format)
└── (binding.md, bound/, bolts/, etc.)
```

## `_meta/modules.yaml` schema

```yaml
mega_sdd_schema: 1
modules:
  - id: <kebab-case identifier with M- prefix>     # e.g., M-auth, M-leave-mgmt, M-reporting
    name: <human-readable display name>             # e.g., "Authentication & Authorization"
    description: <1-2 sentences>                    # optional
    vault_sections:                                  # which vault sections this module covers
      - <vault-file>#<anchor>                       # e.g., 04-flows.md#F-U-001-login
      - <vault-file>#<section-name>
    dod:                                             # Definition of Done (module-level)
      - <checklist item>                            # e.g., "All auth flows return RFC 7807 errors"
      - <test command>                              # e.g., "phpunit tests/Feature/Auth*.php passing"
    estimated_units: <range>                         # e.g., "5-8" — optional sizing hint
    priority: P0 | P1 | P2 | P3
    blocks: []                                       # module IDs that depend on this one
    blocked_by: []                                   # module IDs this one depends on
```

## Auto-derivation rules (when modules.yaml absent)

If user does NOT provide `_meta/modules.yaml`, `generate-units` v2.2+ auto-derives a minimal modules.yaml from vault structure:

| Vault structure signal | Auto-derived module |
|---|---|
| Each `## F-U-*` section in `04-flows.md` (user flow) | One module per top-level user flow group |
| Each component in `02-architecture.md` (named component) | One module per architectural component |
| Each `## D-*` ADR group in `05-decisions.md` referencing same domain | Implicit grouping (advisory; doesn't generate module) |

Auto-derivation produces a `_meta/modules.yaml.auto` file (note `.auto` suffix). User can rename to `modules.yaml` to lock in OR edit before re-running generate-units.

## Unit frontmatter extension

```yaml
---
id: U-007
title: Add nama field to login endpoint
module: M-auth                       # NEW v2.2+ (Iter 11) — references _meta/modules.yaml
vault_source: 04-flows.md#F-U-001-login
task_type: extend
grounding_confidence: HIGH
# ... existing fields ...
---
```

### Module assignment algorithm in `generate-units` (v2.2+)

For each unit's `vault_source`, find matching module:

```
for module in modules.yaml.modules:
  for section in module.vault_sections:
    if unit.vault_source matches section (file + anchor or section-name):
      unit.module = module.id
      break
  if unit.module is set: break

if unit.module is still null:
  unit.module = "M-unassigned"   # fallback (no halt; surface warning in chat)
```

`M-unassigned` is special — units not matching any module. Render warning: "N units have no module; consider adding vault section to modules.yaml or creating new module."

## `_index.md` template (v2.2+ grouped by module)

```markdown
# Vault Units Index

**Total units**: N
**Modules**: M (5 modules — see _meta/modules.yaml)

---

## M-auth — Authentication & Authorization
**Status**: in-progress (2/5 complete)
**Priority**: P0
**DoD**:
- [ ] All auth flows return RFC 7807 errors
- [x] Sanctum middleware applied to /api/* routes
- [ ] phpunit tests/Feature/Auth*.php passing

Units (dependency order):
| ID | Title | task_type | depends_on | status |
|---|---|---|---|---|
| U-001 | Create LoginController | create | (none) | ✓ done |
| U-002 | Add LoginRequest validator | create | U-001 | ✓ done |
| U-003 | Add Sanctum auth middleware | create | U-001 | pending |
| U-007 | Add nama field to login | extend | U-001, U-002 | pending |
| U-008 | Add password reset flow | create | U-001 | pending |

---

## M-leave-mgmt — Leave Management
**Status**: not-started (0/3 complete)
**Priority**: P1
**DoD**:
- [ ] End-to-end leave request UAT passes
- [ ] Approval chain matches RBAC config

Units (dependency order):
| ID | Title | task_type | depends_on | status |
|---|---|---|---|---|
| U-010 | Create LeaveRequest model | create | (none) | pending |
| U-011 | Add /api/leave endpoints | create | U-010 | pending |
| U-012 | Add approval workflow | create | U-011 | pending |

---

## M-unassigned (1 unit — no module match)

⚠️ Consider adding this unit's vault section to modules.yaml OR creating a new module.

| ID | Title | vault_source |
|---|---|---|
| U-015 | Add audit log table | 03-data-model.md#AuditLog |
```

## Module dependency graph

Modules can have `blocks` / `blocked_by` for inter-module ordering. Example:

```yaml
- id: M-auth
  blocks: [M-leave-mgmt, M-reporting]  # other modules can't start until M-auth done
  blocked_by: []

- id: M-leave-mgmt
  blocks: []
  blocked_by: [M-auth]                 # waits for M-auth
```

`generate-units` validates: every unit's `depends_on` is consistent with its module's `blocked_by`. Cross-module unit dependencies require explicit module-level `blocked_by` declaration.

## Module-level DoD validation

`/mega-sdd:list-modules` command (or `execute-bolts --module=<id>` completion check) probes each DoD item:

- Checklist items (Markdown `- [ ] / [x]`) → toggleable; user marks done
- Test commands → can be auto-run: detect command string; invoke via Bash; pass/fail logged to memory
- Module marked `completed` when ALL DoD items pass

## Filtered execution (`execute-bolts --module=<id>`)

```bash
/mega-sdd:execute-bolts --module=M-auth
```

Runs only units where `module: M-auth`. Topologically sorted within module. Respects cross-module `blocked_by` declarations — halts with `module_blocked_by` blocker if dependencies not done.

## Module-level progress in memory

After each unit completes (Iter 5 memory layer integration):

- `<vault>/.memory/bolt-outcomes.json` already tracks per-unit outcomes (existing)
- Module progress derived: `units in module M-X where status=completed / total units in M-X`
- `/mega-sdd:list-modules` reads this for live progress display

## Halt protocol additions (v2.2+)

| Halt type | When |
|---|---|
| `module_unassigned_warn` | ≥10% of units have `module: M-unassigned`. Warning (not blocking); halts only with `--strict-modules` flag |
| `module_blocked_by` | execute-bolts --module=X invoked but X.blocked_by has incomplete module Y |
| `module_dod_unsat` | module declared completed but DoD items still pending (user attempts to mark done prematurely) |
| `cross_module_dep_invalid` | unit's depends_on crosses module boundary AND that module isn't declared in blocked_by |

## Backward compatibility

- v3.4 vaults without `_meta/modules.yaml` → all units get `module: M-default` (single implicit module)
- v3.4 unit files without `module:` field → treated as M-default
- `_index.md` falls back to flat list (no grouping) when only M-default exists
- `execute-bolts --module=<id>` works for M-default-only vaults (just runs all units)
- Existing `vault_source` field is the primary signal for auto-derivation

## Migration

Existing v3.4 vaults can opt into modules by:

1. Adding `_meta/modules.yaml` (manual or via auto-derivation: `/mega-sdd:generate-units --derive-modules`)
2. Running `/mega-sdd:generate-units --refresh-modules` (NEW flag) — re-runs Step 5 module assignment without regenerating units
3. Optional: edit `modules.yaml` to refine grouping; re-run `--refresh-modules`

## References

- The atomic unit definition (the unit-schema reference listed in the skill router) — unchanged by this layer
- `squads.yaml` — the social partition (orthogonal to modules)
- This file — the semantic grouping layer above atomic units
- `commands/list-modules.md` — module progress query command
