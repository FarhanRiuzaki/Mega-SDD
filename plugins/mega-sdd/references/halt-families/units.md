# Halt guidance — units family

Per-type guidance for halts emitted by: plan (unit writing — dedup, hard-rules, squads, interfaces).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

Relocated from skills/generate-units/references/halt-protocol.md in 9.0 (P1); tuned text kept verbatim — the **Blocker shape** blocks below (the only halt details the registry's §Type-specific schemas do not carry).

## Contents
- `starterkit_rule_citation_missing`
- `dedup_ambiguous` (+ blocker shape, reconcile second trigger)
- `hard_rule_unparseable` (+ blocker shape)
- `unit_underspecified` (+ blocker shapes: `verify` without anchor, missing sections)
- `prd_source_unresolvable`
- `plan_coverage_gap`
- `cycle_detected`
- `cross_squad_dep_invalid`
- `cross_squad_ambiguous`
- `interface_ref_missing`
- `cross_squad_interface_draft`
- `cross_module_dep_invalid` (+ shared blocker shape with `module_cycle_detected`)
- `module_cycle_detected`
- `unit_oq_trace_missing` (+ blocker shape, why the rail exists)

### starterkit_rule_citation_missing

- `starterkit_rule_citation_missing` — `validate-unit-spec.sh` Check 3 (plan Step 5; only a unit carrying `starterkit_context_consumed: true` — the legacy starterkit derivation, never authored by `plan`): a starterkit-derived Hard Rule lacks `Citation: starterkit-context.yaml §<path>` field. ALWAYS STOP: user must edit unit to add citation, then re-run `validate-unit-spec.sh`.

### dedup_ambiguous

- `dedup_ambiguous` — plan: dedupe step finds multiple existing units that could match a new claim (target_files overlap >threshold). ALWAYS STOP. Resolution: user picks the canonical unit OR confirms creating a new one.

**Blocker shape** — 12.6 deduplication check (`plan/references/validation-passes.md`): a `create` unit's `target_files` ALL already exist.

```yaml
blocker:
  type: dedup_ambiguous
  emitted_at: <ISO8601 timestamp>
  emitted_by: plan
  details:
    unit_id: U-XXX
    conflicting_paths: [src/foo.ts, tests/foo.test.ts]
    reason: "Unit task_type=create but all target_files already exist on disk. Step 2.5 symbol-index typing did not classify these claims as verify/extend — possible index gap OR genuine intent to overwrite."
    suggested_resolutions:
      - "If existing files are unrelated (name collision), rename the unit's target_files."
      - "If existing files SHOULD be modified, edit unit frontmatter: task_type=extend + fill Migration notes."
      - "If existing files SHOULD be replaced (rebuild scenario), accept Step 7.6 option 4 (force-create) in the unit body's collision note — the recorded acceptance carries through 12.6; there is no flag route."
  next_action: "Resolve manually then re-run plan."
```

**Second trigger (reconcile lane):** `plan --reconcile`'s claim↔unit matching (`plan/references/task-typing.md §Reconcile pass`) reuses this halt type when a refreshed claim matches MULTIPLE existing units ambiguously (per the entry above). Its details block differs: `candidate_units: [U-XXX, U-YYY]` + `claim: <id>`; resolution = user picks the canonical unit — reconcile never creates one (a requirement that needs a NEW unit goes through `diff-vault` → `plan --regenerate`), so the rename-target_files resolutions above do NOT apply. A SPLIT pair sharing one `context_source` (`vault_source` on migrated layout-2 units) is matched by `binding_refs` first (the primary reconcile match key), `context_source` as fallback — so normal SPLIT output does not false-trigger this.

### hard_rule_unparseable

- `hard_rule_unparseable` — plan: a unit's `## Hard Rules` block contains ast-grep YAML that fails parse OR an ANCHOR reference that cannot be resolved. ALWAYS STOP. Resolution: user fixes the unit's Hard Rules block syntax.

**Blocker shape** — emitted by render pass 12.5 b (`plan/references/validation-passes.md`) when a `## Hard rules` line matches none of the 5 grammar productions (the closed Hard-rule grammar in `plan/references/unit-schema.md`). Same blocker shape (`emitted_by: plan`); `details` carries `unit_id`, the offending line, and which production was attempted; `next_action` instructs the author to rewrite the line into a supported production. NEVER silently skip an unparseable rule.

### unit_underspecified

- `unit_underspecified` — plan: a generated unit lacks one or more required spec fields (`target_files`, `acceptance_test`, `depends_on` graph) preventing bolt dispatch. ALWAYS STOP. Details `{unit_id, missing_fields}`. Resolution: user fills missing fields OR re-runs plan (`--regenerate`). Source skill: `plan`.

**Blocker shape — `verify` without anchor (anchor gap)** (Step 2.5 task_type assignment):

```yaml
blocker:
  type: unit_underspecified
  emitted_at: <ISO8601>
  emitted_by: plan
  details:
    unit_id: U-XXX
    reason: "task_type=verify assigned but no anchor exists — neither a symbol-index anchor nor a Step 2.5 direct-probe result. A verify unit certifies EXISTING code; without an anchor there is nothing to certify against."
    fired_in: "Step 2.5 (task_type assignment)"
  next_action: "Fix the symbol-index anchor (re-run query-symbol-index.sh) OR record the probe anchor in the unit's ## Anchors; a claim with NO anchor from any source types as create, never verify."
```

**Blocker shape — missing sections** (render pass 12.5 a/d, `plan/references/validation-passes.md`: missing mandatory `## Anchors` / `## Migration notes`):

```yaml
blocker:
  type: unit_underspecified
  emitted_at: <ISO8601 timestamp>
  emitted_by: plan
  details:
    unit_id: U-XXX
    missing_sections: [Anchors, Migration notes]
    reason: "task_type=extend requires Anchors AND Migration notes; both missing"
  next_action: "Re-run plan OR manually populate the missing sections."
```

### prd_source_unresolvable

- `prd_source_unresolvable` — plan (spec 2026-09-10 Appendix F1): `prd_source: <prd-file>#<heading-slug>` / `<prd-file>:<line>` must resolve — file exists under the project root AND the slug matches a heading (lowercase, non-alphanumerics → `-`) or the line is within the file. Only checked when the field is PRESENT; absence = legacy unit, never an issue. Emitted by `validate-unit-spec.sh` (issue → status FAIL, plan Step 5 halts; not a hook gate). Details `{unit_id, prd_source, reason}`. Resolution: cite a real heading/line, or remove the field.

### plan_coverage_gap

- `plan_coverage_gap` — plan Step 5 (12.8 plan coverage, the LAST validator; spec 2026-09-10 Appendix F5; `emitted_by: plan` — the units are written first, the gap is the finding): `validate-plan-coverage.sh --cwd --prd --vault` found a PRD requirement heading (H2/H3 outside meta + out-of-scope sections, or an `F-*` id) that NO unit cites via `prd_source` and NO open question quotes — a requirement nothing will ever verify. ALWAYS STOP (validator FAIL; state `.mega-sdd/.plan-coverage-state.json`; analyze row `plan_coverage`). Details `{gaps[{heading, slug, line}]}`. Resolution: add a unit with `prd_source`, raise an OQ quoting the heading, or move the heading under an explicit 'Out of scope' section.

### cycle_detected

- `cycle_detected` — plan unit procedure Step 4 (`plan/references/unit-procedure.md`): the unit dependency DAG has a cycle. ALWAYS STOP. Details `{cycle_path: [U-001, U-002, U-001]}` (registry §Type-specific schemas). Resolution: user breaks the cycle by editing the offending units' `depends_on`, then re-runs plan.

### cross_squad_dep_invalid

- `cross_squad_dep_invalid` — plan unit procedure Step 4 (multi-squad mode — a migrated vault's `_meta/squads.yaml`; `plan` never authors one): a unit's `depends_on` references a unit in a different squad. ALWAYS STOP. Details `{unit_id, unit_squad, dependency_id, dependency_squad}` (registry §Type-specific schemas). Resolution: user re-partitions the squads in `_meta/squads.yaml` or replaces the cross-squad dependency with an interface.

### cross_squad_ambiguous

- `cross_squad_ambiguous` — plan unit procedure Step 5 (multi-squad mode — a migrated vault's `_meta/squads.yaml`; `plan` never authors one): two or more squads in `_meta/squads.yaml` claim ownership of the same artifact at the same precedence level. ALWAYS STOP. Details `{artifact, artifact_kind, claimed_by_squads, matched_via}` (registry §Type-specific schemas). Resolution: user disambiguates ownership in `_meta/squads.yaml`, then re-runs plan.

### interface_ref_missing

- `interface_ref_missing` — plan unit procedure Step 4: a unit's `produces_interfaces` or `consumes_interfaces` references an interface ID with no corresponding file in `<vault>/interfaces/`. ALWAYS STOP. Details `{unit_id, missing_interface_id, referenced_in}` (registry §Type-specific schemas). Resolution: user creates the interface note (or fixes the ID), then re-runs plan.

### cross_squad_interface_draft

- `cross_squad_interface_draft` — plan / execute-bolts: a consumed cross-squad interface is still `status: draft` — the consumer squad is waiting for the producer to lock it. ALWAYS STOP for the consuming unit. Details `{unit_id, interface_id, producer_squad, consumer_squad}` (registry §Type-specific schemas). Resolution: the producer squad locks the interface (`status: locked` in `<vault>/interfaces/`), then the consumer re-runs; predictive preflight surfaces this before dispatch when possible.

### cross_module_dep_invalid

- `cross_module_dep_invalid` — plan unit procedure Step 4.5 (`plan/references/unit-procedure.md`): a cross-module `depends_on` edge requires an explicit `blocked_by` declaration in the dependent module's `_meta/modules.yaml` entry; missing → this halt. ALWAYS STOP. Resolution: declare `blocked_by` (or drop the edge), re-run plan. Schema: the shared blocker shape below. (Registered 7.29.1.)

**Shared blocker shape** (`cross_module_dep_invalid` / `module_cycle_detected`; the `blocked_by` contract is `plugins/mega-sdd/references/modules-schema.md §Module dependency graph`): Cross-module `depends_on` edges require an explicit `blocked_by` declaration in the dependent module's `_meta/modules.yaml` entry. A missing declaration halts `cross_module_dep_invalid`. The module-level DAG is validated for cycles the same way the unit DAG is; a module cycle halts `module_cycle_detected`. Both follow the shared blocker shape (`emitted_by: plan`, `details` naming the offending module IDs, `next_action` instructing the user to declare `blocked_by` or break the module cycle, then re-run).

### module_cycle_detected

- `module_cycle_detected` — plan unit procedure Step 4.5 (`plan/references/unit-procedure.md`): the module-level DAG has a cycle (validated the same way as the unit DAG). ALWAYS STOP. Resolution: break the cycle in `_meta/modules.yaml`, re-run. Schema: the shared blocker shape under `cross_module_dep_invalid` above. (Registered 7.29.1.)

### unit_oq_trace_missing

- `unit_oq_trace_missing` — plan render pass 12.5 g (`plan/references/validation-passes.md`) (MOAT-CRITICAL — the binding→units handoff): an implementation-relevant OQ-ID from the vault (`context.md ## Open Questions`) is absent from the unit's `binding_refs:`, so a bolt could implement past an open question. ALWAYS STOP. Resolution: add the OQ-ID to `binding_refs:` (or resolve the OQ), re-run Step 12.5. Schema: the blocker shape below. (Registered 7.29.1.)

**Blocker shape:**

```yaml
blocker:
  type: unit_oq_trace_missing
  emitted_at: <ISO8601 timestamp>
  emitted_by: plan
  details:
    unit_id: U-XXX
    missing_oqs: [OQ-DM-P2-1, OQ-FE-P2-3]
    oq_source: context.md#Open-Questions
  next_action: "Append the listed OQ-IDs to unit's binding_refs frontmatter so the traceability link is preserved."
```

**Why this rail exists:** a field audit traced OQ-DM-P2-1 from vault → binding-phase-2.md (correctly carried) → units/U-005 + U-014 (resolution semantics carried as `lc_amount + goods_total` fields, but the OQ-ID itself was DROPPED). Future readers reviewing U-005 cannot trace the design decision back to its source OQ. CONFLICTs already propagate via this same mechanism (per phase-1 verification); this rail extends the discipline to OQs.
