# Halt guidance — extract family

Per-type guidance for halts emitted by: extract-intelligence (module quality gates).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### quality_gate_failed

- `quality_gate_failed` — extract-intelligence: a module's per-module quality gate (frontmatter contract / 6-section presence / gotcha floor / Mermaid flow / citation discipline) failed twice for the SAME module. ALWAYS STOP; surface the gate output VERBATIM. Resolution: user reviews the module PRD and either accepts (with QA notes recorded), re-scopes the module split, OR re-runs that module's extraction with adjusted prompt.

As a `quality_gate_failed` subtype (the extract default — registry §`quality_gate_failed` subtypes):

- *(omitted OR `module_quality_threshold_unmet`)* — extract-intelligence: per-module PRD-kontrak quality threshold not met twice. Resolution: user reviews the module PRD + accepts (with QA notes), re-scopes, OR re-runs the module with adjusted prompt. The extract default emits with `subtype` ABSENT; `module_quality_threshold_unmet` is a documentation label only, never written into an envelope (pre-v7.6 records may carry the historical label `wave_quality_threshold_unmet` — same semantic).
