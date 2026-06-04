# generate-units — --auto handoff, scope propagation & memory layer

## Contents
- Scope propagation into unit frontmatter (Step 10)
- _index.md contents (Step 11)
- Handoff emission (--auto)
- Memory layer (reads / writes / anti-halu)

Loaded by `generate-units/SKILL.md` for write-out, handoff, and memory steps.

## Scope propagation into unit frontmatter (Step 10)

When vault.json contains a `scope` field (multi-scope vault), every unit's frontmatter MUST include:

```yaml
scope: <vault.scope_metadata.id>           # e.g., "BE", "MW", "FE"
scope_name: <vault.scope_metadata.name>    # e.g., "Backend API"
```

This enables downstream skills (execute-bolts, multi-squad routing) to verify they're operating in the correct scope context. Omit both fields when vault has no scope (legacy single-vault back-compat). `scope:` / `scope_name:` MUST be sourced verbatim from vault.json `scope_metadata` — NEVER inferred or invented.

## _index.md contents (Step 11)

Write `<vault>/units/_index.md` with:
- Total unit count + module count
- **Grouped by module** — per module section: name, status (X/Y complete), priority, DoD checklist, units table (ID, title, task_type, depends_on, status); `M-unassigned` group rendered if non-empty with warning
- Per-module dependency DAG (Mermaid graph) — units within module
- Cross-module dependency graph — high-level
- Suggested execution order (topological within + across modules)
- Backward compat: when only `M-default` exists → fall back to flat unit list

## Handoff emission (--auto)

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML record at the end of skill output per `../orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: generate-units
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  artifacts:                                       # MUST be plain filesystem paths — NO annotations like "(N files)", "(latest)", or comments
    - <absolute path to units/ directory>          # e.g., /Users/.../.mega-sdd/vaults/<vault>-bound/units (or <vault>/units when --no-bind)
    - <absolute path to units/_index.md>           # e.g., /Users/.../.mega-sdd/vaults/<vault>-bound/units/_index.md
    # WRONG: "/Users/.../units/ (18 files)"        ← validator strips trailing " (...)" defensively, but producers SHOULD emit clean paths
    # WRONG: "/Users/.../units/ # latest"          ← inline comments invalid in YAML scalars
    # Each path MUST be a thing validate-handoff-yaml.sh can os.path.exists() against.
  next_action:
    suggested_skill: mega-sdd:execute-bolts
    suggested_args: ["--all", "--auto"]
    rationale: "Units generated; execute via bolts."
  blockers: []   # populated on cycle/cross-squad/dedup/unit_underspecified/hard_rule_unparseable/starterkit_rule_citation_missing
  metrics:
    items_processed: <N units>
    items_blocked: 0
    units_with_starterkit_anchors: <int>       # count of units that gained starterkit Anchors
    units_with_starterkit_rules: <int>         # count of units that gained starterkit Hard Rules
  scope:                                       # omit block when vault has no scope field
    id: <vault.scope_metadata.id>
    name: <vault.scope_metadata.name>
    sibling_scopes: <vault.scope_metadata.sibling_scopes_in_prd>
    prd_sha256: <vault.prd_sha256>
  starterkit_context:                          # passthrough from scan-codebase + generate-units metrics; omit block when starterkit-context.yaml absent
    reused: false
    framework: laravel
    auth_lib: sanctum
    rbac_lib: spatie/permission
    ui_stack: "alpine + tailwind + sweetalert2"
    libs_count: 47
    units_with_starterkit_anchors: 12          # mirrors metrics block above
    units_with_starterkit_rules: 8             # mirrors metrics block above
    # Consumer (wiring closure): orchestrate-flow Step 6.b.ix cross-checks
    # units_with_starterkit_rules > 0 against starterkit-context.yaml `starterkit_context.partial:` flag.
    # If rules > 0 AND partial == true → halt `quality_gate_failed` subtype `starterkit_metrics_inconsistent`
    # (rules pulled from incomplete framework slice — may cite missing conventions).
```

Status `halted` on `cycle_detected` / `cross_squad_dep_invalid` / `interface_ref_missing` / `cross_squad_ambiguous` / `dedup_ambiguous` / `unit_underspecified` / `hard_rule_unparseable` / `starterkit_rule_citation_missing`. Required ONLY under `--auto`.

The `scope:` block is included in handoff YAML when vault.json has `scope` field, per `../orchestrate-flow/references/handoff-contract.md`. Omit the entire `scope:` block when vault is legacy single-scope.

## Memory layer

When memory enabled (default; opt-out via `--memory-off`), participates in mega-sdd memory layer per `../memory/references/memory-schema.md`.

### Reads

| What | Source | How used |
|---|---|---|
| Past Hard Rule violations on similar units | `<vault>/.memory/bolt-outcomes.json` (passed via handoff `metadata.memory_context.vault_outcomes_relevant`) | When generating a unit with Hard Rules pulled from binding suggestions: if rule was violated AND reverted ≥3 times → DOWNGRADE the rule to Anti-pattern (informational) per learning-rules.md §2.3 |
| Project decision history | `<project>/.mega-sdd/memory/decisions.md` | When generating unit's `## Anti-patterns` section: include past CONFLICT KEEP_CODE files as "don't modify" Anti-patterns (informational guidance, NOT machine-validated Hard Rules) |
| Classifier override patterns | `<vault>/.memory/classifier-accuracy.json` | When unit derives from a vault OQ that was overridden by user, surface in unit's `## Context` as note: "this OQ was reclassified manually; original heuristic may not match" |

### Writes

This skill does NOT write to memory directly. Unit generation is read-mostly; bolt-time outcomes (success / Hard Rule violation / acceptance test results) are written by `execute-bolts` to `<vault>/.memory/bolt-outcomes.json`.

### Anti-halu rails

- Memory consultation surfaces in unit body (Anti-patterns section or Context note); never modifies frontmatter without user review
- Downgraded Hard Rules (memory-derived) cite the violation history in Anti-pattern line
- `--memory-off` disables memory reads; units fall back to binding-only suggestions
