# Halt guidance — units family

Per-type guidance for halts emitted by: generate-units (dedup, hard-rules, squads, interfaces).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### starterkit_rule_citation_missing

- `starterkit_rule_citation_missing` — generate-units: a starterkit-derived Hard Rule lacks `Citation: starterkit-context.yaml §<path>` field. ALWAYS STOP: user must edit unit to add citation, then re-run Step 12.5 polished-prompt render pass.

### dedup_ambiguous

- `dedup_ambiguous` — generate-units: dedupe step finds multiple existing units that could match a new claim (target_files overlap >threshold). ALWAYS STOP. Resolution: user picks the canonical unit OR confirms creating a new one. Previously emitted but missing from canonical halt registry —

### hard_rule_unparseable

- `hard_rule_unparseable` — generate-units: a unit's `## Hard Rules` block contains ast-grep YAML that fails parse OR an ANCHOR reference that cannot be resolved. ALWAYS STOP. Resolution: user fixes the unit's Hard Rules block syntax.

### unit_underspecified

- `unit_underspecified` — generate-units: a generated unit lacks one or more required spec fields (`target_files`, `acceptance_test`, `depends_on` graph) preventing bolt dispatch. ALWAYS STOP. Details `{unit_id, missing_fields}`. Resolution: user fills missing fields OR re-runs generate-units with `--strict` for stricter generation. Source skill: `generate-units`.
