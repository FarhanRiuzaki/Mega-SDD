# Halt guidance — extract family

Per-type guidance for halts emitted by: extract-intelligence (wave quality gates).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### quality_gate_failed

- `quality_gate_failed` — extract-intelligence: a wave's quality-gate threshold (citation density / hallucination floor / canonicalization completeness) is not met. ALWAYS STOP. Resolution: user reviews wave output and either accepts (with QA notes recorded) OR re-runs wave with adjusted prompt.

As a `quality_gate_failed` subtype (the wave default — registry §`quality_gate_failed` subtypes):

- *(omitted OR `wave_quality_threshold_unmet`)* — extract-intelligence: wave-based KB extraction quality threshold (citation density / hallucination floor / canonicalization completeness) not met. Resolution: user reviews wave output + accepts (with QA notes) OR re-runs wave with adjusted prompt.
