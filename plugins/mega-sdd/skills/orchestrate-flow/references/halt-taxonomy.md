# Halt Taxonomy — Orchestrator Halt Classification

Every blocker a sub-skill can emit falls into one of three classes for the orchestrator: **always-stop** (human required), **cycle-eligible** (auto-loop in `--deep`; see the convergence-loops reference indexed in SKILL.md §Specialist references), or **soft** (warn-only, chain continues). This file is names-only — the per-halt one-liners, resolutions, envelope shapes, and C1/C2/C3 categories live in the canonical registry `plugins/mega-sdd/references/halt-protocol.md` (§halt-protocol + §halt-escalation-discipline).

## Cycle-eligible (auto-loop)

Auto-resolved in `--deep` when the safety condition holds; otherwise escalate. Full action + safety table in convergence-loops.md `§Cycle-eligible halt types`:

- `bind_conflict` · `module_blocked_by` · `cross_squad_interface_draft` · `oq_recommend_underspecified`
- Bolt halts bridged via propose-and-confirm (also in convergence-loops.md): `test_fail`, `hard_rule_violated`, `pbt_property_violated`

## Always-stop (human required)

- `hard_rule_violated` — dual-classified: cycle-eligible only via the propose-and-confirm bridge above; always-stop as detect-after (the bolt commit already landed)
- `test_fail` after 3 retries
- `oq_business_p1_unresolved` / `oq_blocker` — coexisting names: `oq_blocker` is the vault-consumer envelope (per `vault-contract.md §oq_blocker`); `oq_business_p1_unresolved` is the orch-level alias for business-classified P1s
- `phase_stuck` — auto-looped while cycle-eligible up to the retry cap; becomes always-stop at the cap
- `anti_spin` — no-progress loop breaker; always-stop once tripped
- `memory_in_use` ⚠ classification conflict — always-stop here vs C1 NEVER-halt (retry+skip) in halt-protocol.md
- `mode_migrate` ⚠ classification conflict — always-stop here vs C1 self-resolve in halt-protocol.md
- `invalid_handoff` ⚠ classification conflict — always-stop here vs C1 hook-enforced self-resolve in halt-protocol.md
- `partial_state_corrupt` ⚠ classification conflict — always-stop here vs C1 hook-enforced self-resolve in halt-protocol.md
- `verify_unit_writable` ⚠ classification conflict — always-stop here vs C1 detection-only NEVER-halt in halt-protocol.md
- `dedup_ambiguous` · `quality_gate_failed` · `hard_rule_unparseable` · `hard_rule_unanchored` · `hard_rule_mixed_grammar` · `cross_squad_dep_invalid` · `memory_schema_mismatch` · `scope_not_declared_in_prd` · `prd_no_scopes_block_user_rejected_retrofit` · `prd_retrofit_low_confidence` · `prd_path_missing` · `deep_scan_subagent_all_failed` · `starterkit_rule_citation_missing` · `bind_conflict_constitution_violation` · `framework_pack_missing` · `framework_pack_cycle` · `framework_pack_unparseable` · `constitution_drift_detected` · `drift_framework_mismatch` · `diff_conflict` · `dispatch_prompt_too_large` · `bolt_repeated_partial_failure` · `provenance_missing` · `bolt_introduces_locked_drift` · `self_assessment_missing` · `dep_missing` · `oq_recommend_citation_invalid` · `predictive_check_failed` · `handoff_type_mismatch` · `handoff_missing` · `artifact_missing` · `cross_squad_ambiguous` · `cycle_detected` · `interface_ref_missing` · `pbt_citation_invalid` · `convergence_max_reached` · `secret_in_code` · `sast_critical_finding` · `dep_not_found` · `review_critical_unresolved` · `batch_suite_red` · `batch_suite_gate_missing` · `postflight_evidence_missing` · `acceptance_evidence_missing` · `acceptance_red` · `build_broken` · `anchor_missing` · `whitelist_violation` · `commit_rejected_by_hook` · `scope_creep_detected` · `bolt_artifacts_missing`

## Soft (warn-only, chain continues)

- `deep_scan_subagent_failed` · `deep_scan_cache_corrupt` · `routing_outcome_corrupt` · `model_tier_unknown`

## See also

SKILL.md §Specialist references indexes the related orchestrate-flow references: convergence-loops (auto-recovery cycling + bolt bridge), handoff-consumption (orchestrator-side halt envelopes), predictive-checks (preflight anticipation).
