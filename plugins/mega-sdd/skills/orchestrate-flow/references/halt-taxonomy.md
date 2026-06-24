# Halt Taxonomy — Orchestrator Halt Classification

Every blocker a sub-skill can emit falls into one of three classes for the orchestrator: **always-stop** (human required), **cycle-eligible** (auto-loop in `--deep`; see the convergence-loops reference indexed in SKILL.md §Specialist references), or **soft** (warn-only, chain continues). Canonical halt envelope shapes live in `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md §halt-protocol`.

## Contents

- [Cycle-eligible (auto-loop)](#cycle-eligible-auto-loop)
- [Always-stop (human required)](#always-stop-human-required)
- [Soft (warn-only, chain continues)](#soft-warn-only-chain-continues)

## Cycle-eligible (auto-loop)

Auto-resolved in `--deep` mode when the safety condition holds; otherwise escalate. Full action + safety table in the convergence-loops reference (`§Cycle-eligible halt types`, indexed in SKILL.md §Specialist references):

- `bind_conflict`
- `module_blocked_by`
- `cross_squad_interface_draft`
- `oq_recommend_underspecified`

Bolt halts bridged via propose-and-confirm (also in convergence-loops.md): `test_fail`, `hard_rule_violated`, `pbt_property_violated`.

## Always-stop (human required)

These ALWAYS stop the chain; no auto-loop:

- `hard_rule_violated` — code in working tree; user reviews + decides revert vs edit
- `dedup_ambiguous` — multi-path resolution; user picks intent
- `quality_gate_failed` — extract-intelligence; user reviews wave output
- `oq_business_p1_unresolved` — stakeholder decision required
- `test_fail` after 3 retries — manual investigation needed
- `hard_rule_unparseable` / `hard_rule_unanchored` — config error; user fixes
- `cross_squad_dep_invalid` — explicit blocked_by needed; user configures (canonical name per `handoff-contract.md`)
- `memory_schema_mismatch` — migration prompt; user opts in
- `mode_migrate` — vault/code mode contradiction; user decides
- `scope_not_declared_in_prd` — generate-intent: `--scope=<id>` flag mismatches PRD scopes block. ALWAYS STOP (user must pick valid scope from PRD declared list or cancel).
- `prd_no_scopes_block_user_rejected_retrofit` — generate-intent: PRD lacks `scopes:` frontmatter AND user rejected AI retrofit AND chose cancel. ALWAYS STOP (user manually retrofits PRD or chooses single-scope fallback).
- `prd_retrofit_low_confidence` — generate-intent: AI retrofit subagent returned `overall_confidence: LOW`. ALWAYS STOP (user reviews/accepts anyway / single-scope fallback / cancel).
- `prd_path_missing` — diff-vault: vault.json.prd_path_at_generation points to non-existent file. ALWAYS STOP (user must restore PRD or regenerate vault).
- `deep_scan_subagent_all_failed` — scan-codebase: all 4 deep-scan subagents failed. User re-runs later.
- `starterkit_rule_citation_missing` — generate-units: starterkit-derived Hard Rule lacks citation. User edits unit.
- `bind_conflict_constitution_violation` — bind-codebase: claim conflicts with constitution security clause.
- `framework_pack_missing` — bind-codebase: pack referenced but file absent.
- `framework_pack_cycle` — bind-codebase: pack inheritance has cycle.
- `framework_pack_unparseable` — bind-codebase: pack file YAML/markdown parse failed.
- `constitution_drift_detected` — detect-drift: security/compliance clause drift in code.
- `drift_framework_mismatch` — detect-drift: scanned framework differs from vault.
- `diff_conflict` — diff-vault: Resolved-OQ/Decision conflict needs stakeholder.
- `memory_in_use` — memory: concurrent writer holds lock.
- `dispatch_prompt_too_large` — execute-bolts: bolt prompt > 10KB cap.
- `bolt_repeated_partial_failure` — execute-bolts: 3 partial-state cycles failed.
- `provenance_missing` — execute-bolts: modified file lacks provenance trailer.
- `bolt_introduces_locked_drift` — execute-bolts: bolt drift on LOCKED entity.
- `self_assessment_missing` — execute-bolts: bolt-report lacks self-assessment.
- `dep_missing` — scan-codebase: required binary missing.
- `oq_recommend_citation_invalid` — generate-intent: OQ recommendation cites missing KB section.
- `predictive_check_failed` — orchestrate-flow: fatal preflight check failed; chain blocked.
- `invalid_handoff` — orchestrate-flow: handoff schema validation failed; producer-side error.
- `handoff_type_mismatch` — orchestrate-flow: handoff field type mismatch with schema annotation.
- `handoff_missing` — orchestrate-flow: sub-skill exited but no handoff YAML in chat output (silent-failure path closure).
- `artifact_missing` — orchestrate-flow: handoff YAML lists artifact paths that don't exist on disk (silent-failure path closure).
- `partial_state_corrupt` — execute-bolts `--resume`: partial-state.json fails JSON parse (silent-failure path closure).
- `oq_blocker` — generate-intent / AI consumers reading vault non-interactively: P1 OQ blocks downstream work. Canonical envelope per `vault-contract.md §oq_blocker`. (Coexists with `oq_business_p1_unresolved`, the orch-level alias for business-classified P1s.)
- `cross_squad_ambiguous` — generate-units: multi-squad code where the producer squad cannot be determined unambiguously. ALWAYS STOP; user picks the canonical squad.
- `cycle_detected` — generate-units / orchestrator: dependency cycle detected in unit graph (module_depends_on / blocked_by chain). ALWAYS STOP; user resolves cycle by re-tiering.
- `interface_ref_missing` — generate-units / bind-codebase: a unit declares `consumes_interface: <ref>` but the referenced interface is not declared by any other unit. ALWAYS STOP; user fixes ref OR creates producer unit.
- `pbt_citation_invalid` — execute-bolts: PBT property block `Cites: §Decision-D-NNN` points to a non-existent ADR. ALWAYS STOP.
- `convergence_max_reached` — orchestrate-flow: convergence loop hit `--max-cycles`. User reviews cycle history (envelope in the convergence-loops reference).
- `phase_stuck` — factory-line: a phase failed to reach a green checkpoint within the retry cap (default 3); the loop stops and a human must resolve the underlying blocker before re-running. (Auto-looped while cycle-eligible up to the cap; becomes always-stop at the cap.)
- `anti_spin` — factory-line: a phase re-ran with an identical unresolved set (no progress); the loop stops to avoid spinning, human resolution required.

## Soft (warn-only, chain continues)

- `deep_scan_subagent_failed` — scan-codebase: single deep-scan subagent failed. Auto-retried; partial output on second failure.
- `deep_scan_cache_corrupt` — scan-codebase: starterkit-context.yaml YAML parse failed. Cache auto-invalidated; subagents re-dispatched. Transparent.
- `routing_outcome_corrupt` — orchestrate-flow: routing-outcomes.md parse failure. Auto-invalidate + log; chain proceeds.
- `model_tier_unknown` — orchestrate-flow: override source references a role not in model-tiers.md catalog. Auto-ignore + log; chain proceeds with catalog default. Forward-compat.

## See also

SKILL.md §Specialist references indexes the related orchestrate-flow references: convergence-loops (auto-recovery cycling for cycle-eligible halts + bolt bridge), handoff-consumption (orchestrator-side halt envelopes — `handoff_missing`, `artifact_missing`, type/schema mismatches), and predictive-checks (preflight checks that anticipate many of these halts before chain start).
