# Halt guidance — bind family

Per-type guidance for halts emitted by: bind-codebase (packs, constitution, OQ-verdict discipline).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### bind_conflict

- `bind_conflict` — bind-codebase: the CONFLICT-gate halt (moat invariant #2). Binding produced ≥1 CONFLICT verdict (`conflict_count > 0`); downstream unit/bolt generation is hook-blocked until each conflict is resolved. Details per the registry §Type-specific schemas (`bind_conflict`): `{vault, conflict_count, conflicts: [{id, vault_claim, codebase_reality, suggested_action, suggested_action_rationale}]}`. Resolution codes (the displayer renders this legend — the enum never surfaces bare): KEEP_VAULT = code harus diubah mengikuti vault; KEEP_CODE = vault di-update mengikuti kenyataan code; DEFER = jadi OQ — gate binding terbuka, unit digenerate membawa OQ-nya, execute-bolts prompt sebelum bolt final; SPLIT = claim dipecah jadi sub-claim.

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

### bind_inputs_missing

- `bind_inputs_missing` — bind-codebase Step 0: a required input cannot be resolved deterministically — `details.missing` ∈ {`vault`, `codebase_map`, `vault_index`}, `details.reason` ∈ {`not_found`, `vault_ambiguous`, `vault_outside_glob_root`, `malformed`}; `details.candidates` is REQUIRED for `vault_ambiguous` (re-invoke with an explicit `--vault=`). ALWAYS STOP. Resolution: run `scan-codebase` (missing map), pass `--vault=`, or fix the vault location / JSON. Full envelope: `bind-codebase/references/auto-memory-handoff.md §Halt YAML — bind_inputs_missing`. (Registered 7.29.1 — emitted since the bind Step-0 contract, never indexed.)
