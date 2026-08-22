# Halt guidance — bind family

Per-type guidance for halts emitted by: bind-codebase (packs, constitution, OQ-verdict discipline).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### bind_conflict_constitution_violation

- `bind_conflict_constitution_violation` — bind-codebase: claim conflicts with constitution.md security clause. ALWAYS STOP. Resolution: review constitution clauses + reject/accept conflict.

### framework_pack_missing

- `framework_pack_missing` — bind-codebase: framework convention pack referenced but file absent. ALWAYS STOP. Resolution: create pack or remove reference.

### framework_pack_cycle

- `framework_pack_cycle` — bind-codebase: pack inheritance has cycle (A extends B extends A). ALWAYS STOP.

### framework_pack_unparseable

- `framework_pack_unparseable` — bind-codebase: pack file fails YAML/markdown parse. ALWAYS STOP.

### oq_recommend_underspecified

- `oq_recommend_underspecified` — generate-intent / bind-codebase: an OQ marked `resolution_mode: recommend` lacks one or more required fields (`recommendation`, `rationale`, `scan_citations` ≥1, `fallback_if_wrong`). ALWAYS STOP. Details `{oq_id, missing_fields}`. Resolution: user fills missing fields in OQ entry per `vault-core.md §Tech-OQ Recommendations schema`. Source skill: `generate-intent` (Mode B Q&A) or `bind-codebase` (Tech-OQ auto-resolution).
