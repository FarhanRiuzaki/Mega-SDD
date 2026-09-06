# Halt guidance — units family

Per-type guidance for halts emitted by: generate-units (dedup, hard-rules, squads, interfaces).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### starterkit_rule_citation_missing

- `starterkit_rule_citation_missing` — generate-units: a starterkit-derived Hard Rule lacks `Citation: starterkit-context.yaml §<path>` field. ALWAYS STOP: user must edit unit to add citation, then re-run Step 12.5 polished-prompt render pass.

### dedup_ambiguous

- `dedup_ambiguous` — generate-units: dedupe step finds multiple existing units that could match a new claim (target_files overlap >threshold). ALWAYS STOP. Resolution: user picks the canonical unit OR confirms creating a new one.

### hard_rule_unparseable

- `hard_rule_unparseable` — generate-units: a unit's `## Hard Rules` block contains ast-grep YAML that fails parse OR an ANCHOR reference that cannot be resolved. ALWAYS STOP. Resolution: user fixes the unit's Hard Rules block syntax.

### unit_underspecified

- `unit_underspecified` — generate-units: a generated unit lacks one or more required spec fields (`target_files`, `acceptance_test`, `depends_on` graph) preventing bolt dispatch. ALWAYS STOP. Details `{unit_id, missing_fields}`. Resolution: user fills missing fields OR re-runs generate-units with `--strict` for stricter generation. Source skill: `generate-units`.

### cycle_detected

- `cycle_detected` — generate-units: the unit dependency DAG has a cycle. ALWAYS STOP. Details `{cycle_path: [U-001, U-002, U-001]}` (registry §Type-specific schemas). Resolution: user breaks the cycle by editing the offending units' `depends_on`, then re-runs generate-units.

### cross_squad_dep_invalid

- `cross_squad_dep_invalid` — generate-units (multi-squad mode): a unit's `depends_on` references a unit in a different squad. ALWAYS STOP. Details `{unit_id, unit_squad, dependency_id, dependency_squad}` (registry §Type-specific schemas). Resolution: user re-partitions the squads in `_meta/squads.yaml` or replaces the cross-squad dependency with an interface.

### cross_squad_ambiguous

- `cross_squad_ambiguous` — generate-units (multi-squad mode): two or more squads in `_meta/squads.yaml` claim ownership of the same artifact at the same precedence level. ALWAYS STOP. Details `{artifact, artifact_kind, claimed_by_squads, matched_via}` (registry §Type-specific schemas). Resolution: user disambiguates ownership in `_meta/squads.yaml`, then re-runs generate-units.

### interface_ref_missing

- `interface_ref_missing` — generate-units: a unit's `produces_interfaces` or `consumes_interfaces` references an interface ID with no corresponding file in `<vault>/interfaces/`. ALWAYS STOP. Details `{unit_id, missing_interface_id, referenced_in}` (registry §Type-specific schemas). Resolution: user creates the interface note (or fixes the ID), then re-runs generate-units.

### cross_squad_interface_draft

- `cross_squad_interface_draft` — generate-units / execute-bolts: a consumed cross-squad interface is still `status: draft` — the consumer squad is waiting for the producer to lock it. ALWAYS STOP for the consuming unit. Details `{unit_id, interface_id, producer_squad, consumer_squad}` (registry §Type-specific schemas). Resolution: the producer squad locks the interface (`status: locked` in `<vault>/interfaces/`), then the consumer re-runs; predictive preflight surfaces this before dispatch when possible.

### cross_module_dep_invalid

- `cross_module_dep_invalid` — generate-units Step 4.5: a cross-module `depends_on` edge requires an explicit `blocked_by` declaration in the dependent module's `_meta/modules.yaml` entry; missing → this halt. ALWAYS STOP. Resolution: declare `blocked_by` (or drop the edge), re-run generate-units. Schema: `generate-units/references/halt-protocol.md`. (Registered 7.29.1.)

### module_cycle_detected

- `module_cycle_detected` — generate-units Step 4.5: the module-level DAG has a cycle (validated the same way as the unit DAG). ALWAYS STOP. Resolution: break the cycle in `_meta/modules.yaml`, re-run. Schema: `generate-units/references/halt-protocol.md`. (Registered 7.29.1.)

### unit_oq_trace_missing

- `unit_oq_trace_missing` — generate-units Step 12.5 g (MOAT-CRITICAL — the binding→units handoff): an implementation-relevant OQ-ID from the vault/binding is absent from the unit's `binding_refs:`, so a bolt could implement past an open question. ALWAYS STOP. Resolution: add the OQ-ID to `binding_refs:` (or resolve the OQ), re-run Step 12.5. Schema: `generate-units/references/halt-protocol.md §unit_oq_trace_missing`. (Registered 7.29.1.)
