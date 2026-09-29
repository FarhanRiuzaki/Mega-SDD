# Modules Schema

> Relocated from `skills/generate-units/references/modules-schema.md` in 9.0 (P1); tuned text kept verbatim.

Semantic grouping layer ABOVE units. Units stay atomic (1 unit = 1 PR-sized commit invariant); modules aggregate related units per domain / flow / component for human mental-model fit + progress tracking + filtered execution.

## Contents
- `_meta/modules.yaml` schema
- Auto-derivation rules (when modules.yaml absent)
- Unit frontmatter extension
- `_index.md` template (grouped by module)
- Module dependency graph
- Module-level DoD validation
- Filtered execution (`execute-bolts --module=<id>`)
- Halt protocol additions
- Backward compatibility

## `_meta/modules.yaml` schema

```yaml
mega_sdd_schema: 1
modules:
  - id: <kebab-case identifier with M- prefix>     # e.g., M-auth, M-leave-mgmt, M-reporting
    name: <human-readable display name>             # e.g., "Authentication & Authorization"
    description: <1-2 sentences>                    # optional
    vault_sections:                                  # which vault sections this module covers
      - <vault-file>#<anchor>                       # e.g., context.md#F-U-001-login
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

If user does NOT provide `_meta/modules.yaml`, `plan` auto-derives a minimal modules.yaml from vault structure:

| Vault structure signal | Auto-derived module |
|---|---|
| Each `### F-U-*` flow under `context.md ## Flows` (user flow) | One module per top-level user flow group |
| Each component in `context.md ## Architecture` (named component; the H2 exists only in a vault migrated from layout-2 — `plan` never writes it) | One module per architectural component |
| Each `### D-NNN` ADR group in `context.md ## Decisions` referencing same domain | Implicit grouping (advisory; doesn't generate module) |
| `plan --kb`, PRD-kontrak KB: each `<kb>/modules/<domain>.prd.md` (module is the phasing unit) | One module per KB module PRD; its `rebuild_after` (the acyclic build-order field — never `depends_on`, which may cycle) seeds `blocked_by` |
| `plan --kb`, legacy numbered-tree KB: `module-dependency-graph.md` (the `kb_module_graph: <path>` pointer in `context.md` frontmatter) | Its module list + dependency edges seed the derivation — the extraction already computed the grouping; don't re-derive it blind |

KB edges are a SEED for `blocked_by` declarations, not evidence: every cross-module `depends_on` still requires the concrete-coupling evidence rule (`plan/references/decomposition-rails.md §Module assignment`). Absent/unreadable KB module source → fall through to plain auto-derivation silently. KB grammar detection: `plan/references/kb-input.md`.

Auto-derivation produces a `_meta/modules.yaml.auto` file (note `.auto` suffix). User can rename to `modules.yaml` to lock in OR edit before re-running `plan`. Promote after review: `mv _meta/modules.yaml.auto _meta/modules.yaml` (execute-bolts' `--module=` halt accepts only the promoted name).

## Unit frontmatter extension

```yaml
---
id: U-007
title: Add nama field to login endpoint
module: M-auth                       # references _meta/modules.yaml
context_source: context.md#F-U-001-login
task_type: extend
grounding_confidence: HIGH
# ... existing fields ...
---
```

### Module assignment algorithm in `plan`

For each unit's `context_source` (or `vault_source` on the units of a migrated layout-2 vault), find matching module:

```
source = unit.context_source or unit.vault_source
for module in modules.yaml.modules:
  for section in module.vault_sections:
    if source matches section (file + anchor or section-name):
      unit.module = module.id
      break
  if unit.module is set: break

if unit.module is still null:
  unit.module = "M-unassigned"   # fallback (no halt; surface warning in chat)
```

`M-unassigned` is special — units not matching any module. Render warning: "N units have no module; consider adding vault section to modules.yaml or creating new module."

## `_index.md` template (grouped by module)

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

| ID | Title | context_source |
|---|---|---|
| U-015 | Add audit log table | context.md#Data-model |
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

`plan` validates (unit procedure Step 4.5, `plan/references/unit-procedure.md`): every unit's `depends_on` is consistent with its module's `blocked_by`. Cross-module unit dependencies require explicit module-level `blocked_by` declaration.

## Module-level DoD validation

The list-modules diagnostic (`orchestrate-flow/references/diagnostics-procedures.md §list-modules`) probes each DoD item:

- Checklist items (Markdown `- [ ] / [x]`) → toggleable; user marks done
- Test commands → can be auto-run: detect command string; invoke via Bash; the exit code is pass/fail, a pass is marked `[x]` in `modules.yaml`
- Module marked `completed` when ALL DoD items pass

## Filtered execution (`execute-bolts --module=<id>`)

```bash
execute-bolts --module=M-auth
```

Runs only units where `module: M-auth`. Topologically sorted within module. Respects cross-module `blocked_by` declarations — halts with `module_blocked_by` blocker if dependencies not done.

## Halt protocol additions

| Halt type | When |
|---|---|
| (chat warning, no halt) | ≥10% of units have `module: M-unassigned` → warning in the Step 4.5 summary; nothing blocks |
| `module_blocked_by` | execute-bolts --module=X invoked but X.blocked_by has incomplete module Y |
| `cross_module_dep_invalid` | unit's depends_on crosses module boundary AND that module isn't declared in blocked_by |
| `module_cycle_detected` | the module-level DAG (`blocks` / `blocked_by`) has a cycle — validated the same way as the unit DAG |

Guidance: `plugins/mega-sdd/references/halt-families/units.md` (`cross_module_dep_invalid`, `module_cycle_detected`) and `plugins/mega-sdd/references/halt-families/bolts.md` (`module_blocked_by`).

## Backward compatibility

- Vaults without `_meta/modules.yaml` → all units get `module: M-default` (single implicit module)
- Unit files without `module:` field → treated as M-default
- `_index.md` falls back to flat list (no grouping) when only M-default exists
- `execute-bolts --module=<id>` works for M-default-only vaults (just runs all units)
- Existing `context_source` field (`vault_source` on migrated layout-2 units) is the primary signal for auto-derivation
