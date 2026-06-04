# generate-units — halt protocol (blocker YAML)

## Contents
- When each halt fires (index)
- `cycle_detected`
- `cross_squad_dep_invalid`
- `interface_ref_missing`
- `cross_squad_ambiguous`
- `cross_module_dep_invalid` / `module_cycle_detected`
- `dedup_ambiguous`
- `unit_underspecified`
- `hard_rule_unparseable`
- `unit_oq_trace_missing`
- `starterkit_rule_citation_missing` (ALWAYS STOP)
- Halt-vs-warning summary

Every structured halt conforms to `../generate-intent/references/vault-contract.md §halt-protocol`. The SKILL.md step skeleton names the trigger for each; this file carries the emitted YAML and recovery action. All halts STOP generation unless noted; under `--auto` they set handoff `status: halted`.

## When each halt fires (index)

| Halt type | Fires in | Trigger |
|---|---|---|
| `cycle_detected` | Step 4 | `depends_on` DAG has a back-edge |
| `cross_squad_dep_invalid` | Step 4 (after Step 5 squad assignment) | a `depends_on` edge crosses `squad:` boundaries |
| `interface_ref_missing` | Step 4 | a `consumes_interfaces` / `produces_interfaces` ID has no `interfaces/<id>.md` |
| `cross_squad_ambiguous` | Step 5 | two squads claim one artifact at the same precedence level |
| `cross_module_dep_invalid` | Step 4.5 | cross-module `depends_on` lacks `blocked_by` in modules.yaml |
| `module_cycle_detected` | Step 4.5 | module DAG has a cycle |
| `dedup_ambiguous` | Step 12.6 | a `create` unit's `target_files` ALL already exist |
| `unit_underspecified` | Step 12.5 a/d | missing mandatory `## Anchors` / `## Migration notes` |
| `hard_rule_unparseable` | Step 12.5 b | a `## Hard rules` line fails all 5 grammar productions |
| `unit_oq_trace_missing` | Step 12.5 g | an implementation-relevant OQ-ID absent from `binding_refs:` |
| `starterkit_rule_citation_missing` | Step 12.5 f | a starterkit-derived Hard Rule lacks its `Citation:` |

A `Mix of CONFIRMED + CONFLICT` in the Step 2.5 task_type aggregation also halts ("binding gate should have blocked already; report inconsistency") — but the canonical block is the hard gate in SKILL.md: unresolved CONFLICT entries in binding.md refuse unit generation outright.

## `cycle_detected`

```yaml
blocker:
  type: cycle_detected
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    cycle_path: [U-001, U-002, ..., U-001]  # node sequence forming the cycle
  next_action: "Restructure vault sections so unit dependencies form a DAG (no back-edges)"
```

## `cross_squad_dep_invalid`

```yaml
blocker:
  type: cross_squad_dep_invalid
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    unit_id: U-XXX
    unit_squad: squad-fe-web
    dependency_id: U-YYY
    dependency_squad: squad-be
  next_action: "Cross-squad direct depends_on is not allowed. Route the coupling through an interface note: producer squad declares produces_interfaces, consumer squad declares consumes_interfaces. See interfaces/_index.md."
```

## `interface_ref_missing`

```yaml
blocker:
  type: interface_ref_missing
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    unit_id: U-XXX
    missing_interface_id: api-leave-request-submit
    referenced_in: consumes_interfaces
  next_action: "Create interfaces/api-leave-request-submit.md from interface-note.template.md, fill the contract, and re-run generate-units."
```

## `cross_squad_ambiguous`

```yaml
blocker:
  type: cross_squad_ambiguous
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    artifact: F-U-007
    artifact_kind: flow
    claimed_by_squads: [squad-fe-web, squad-mobile]
    matched_via: owns_layers
  next_action: "Two squads claim ownership at the same precedence level. Refine _meta/squads.yaml so exactly one squad matches this artifact, then re-run generate-units."
```

## `cross_module_dep_invalid` / `module_cycle_detected`

Cross-module `depends_on` edges require an explicit `blocked_by` declaration in the dependent module's `_meta/modules.yaml` entry. A missing declaration halts `cross_module_dep_invalid`. The module-level DAG is validated for cycles the same way the unit DAG is; a module cycle halts `module_cycle_detected`. Both follow the shared blocker shape (`emitted_by: generate-units`, `details` naming the offending module IDs, `next_action` instructing the user to declare `blocked_by` or break the module cycle, then re-run).

## `dedup_ambiguous`

```yaml
blocker:
  type: dedup_ambiguous
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    unit_id: U-XXX
    conflicting_paths: [src/foo.ts, tests/foo.test.ts]
    reason: "Unit task_type=create but all target_files already exist in codebase-map. Implementation State Map did not classify these claims as IMPLEMENTED — possible binding gap OR genuine intent to overwrite."
    suggested_resolutions:
      - "If existing files are unrelated (name collision), rename the unit's target_files."
      - "If existing files SHOULD be modified, edit unit frontmatter: task_type=extend + fill Migration notes."
      - "If existing files SHOULD be replaced (rebuild scenario), confirm intent and re-run with --force-overwrite (NOT YET IMPLEMENTED — pause and consult human)."
  next_action: "Resolve manually then re-run /mega-sdd:generate-units."
```

## `unit_underspecified`

```yaml
blocker:
  type: unit_underspecified
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    unit_id: U-XXX
    missing_sections: [Anchors, Migration notes]
    reason: "task_type=extend requires Anchors AND Migration notes; both missing"
  next_action: "Re-run generate-units OR manually populate the missing sections."
```

## `hard_rule_unparseable`

Emitted by Step 12.5 b when a `## Hard rules` line matches none of the 5 grammar productions (the closed Hard-rule grammar in the unit-schema reference listed in the skill router). Same blocker shape; `details` carries `unit_id`, the offending line, and which production was attempted; `next_action` instructs the author to rewrite the line into a supported production. NEVER silently skip an unparseable rule.

## `unit_oq_trace_missing`

```yaml
blocker:
  type: unit_oq_trace_missing
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    unit_id: U-XXX
    missing_oqs: [OQ-DM-P2-1, OQ-FE-P2-3]
    binding_source: binding-phase-2.md
  next_action: "Append the listed OQ-IDs to unit's binding_refs frontmatter so the traceability link is preserved."
```

**Why this rail exists:** audit 2026-05-27 §F traced OQ-DM-P2-1 from vault → binding-phase-2.md (correctly carried) → units/U-005 + U-014 (resolution semantics carried as `lc_amount + goods_total` fields, but the OQ-ID itself was DROPPED). Future readers reviewing U-005 cannot trace the design decision back to its source OQ. CONFLICTs already propagate via this same mechanism (per phase-1 verification); this rail extends the discipline to OQs.

## `starterkit_rule_citation_missing` — ALWAYS STOP

Emitted by Step 12.5 f when a unit's starterkit-derived Hard Rule lacks the mandatory `Citation: starterkit-context.yaml §<path>` field. Mirrors the "every Hard Rule needs a Citation" rail (Step 12.4.5) extended to starterkit-derived rules.

```yaml
type: starterkit_rule_citation_missing
source_skill: generate-units
details:
  unit_id: <U-XXX>
  rule_text: "<text of offending rule>"
  missing_citation: "starterkit-context.yaml §<expected path>"
  rule_index: <int>
next_action: "Edit unit <U-XXX>: append 'Citation: starterkit-context.yaml §<path>' to Hard Rule #<index>, then re-run /mega-sdd:generate-units."
```

Recovery: user edits unit to add citation; re-runs Step 12.5 polished-prompt render pass. This halt is ALWAYS STOP — never a soft warning. Do NOT write the unit while the citation is missing.

## Halt-vs-warning summary

Hard halts (STOP): `cycle_detected`, `cross_squad_dep_invalid`, `interface_ref_missing`, `cross_squad_ambiguous`, `cross_module_dep_invalid`, `module_cycle_detected`, `dedup_ambiguous`, `unit_underspecified`, `hard_rule_unparseable`, `unit_oq_trace_missing`, `starterkit_rule_citation_missing`. Plus the binding-gate refusal on unresolved CONFLICTs and the `verify`-without-anchor binding-gap halt.

Soft (proceed, surface a WARNING): anchor file missing / line out of bounds (Step 12.3); Implementation-steps bullet-only (Step 12.5 c); module ≥10% unassigned; target_files collision force-create (option 4). The full halt-vs-warning matrix is in the defensive-generation reference listed in the skill router.
