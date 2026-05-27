# C2 Propose-and-Confirm Audit — 2026-05-27

## Purpose

Iter 67.7 ship (v3.50.0) introduced the C2 halt category with a stated discipline:

> Every C2 halt envelope MUST include a `recommendation:` field with the skill's best-effort guess + rationale. The halt should not pose a raw question.

This audit walks all 27 C2 halts and proposes the `recommendation:` field shape per halt. Implementation is per-skill body work — out of scope for hook-layer ship pattern but cataloged here for follow-up.

## Convention recap (from vault-contract.md §halt-escalation-discipline)

```yaml
blocker:
  type: <C2 halt>
  ...
  recommendation:
    proposed_action: "<one-line>"
    rationale: "<why this is the best guess given context>"
    confidence: "high | medium | low"
    alternatives: ["<option A>", "<option B>"]
  user_response_required: true
```

## The 27 C2 halts + proposed recommendations

### Domain/stakeholder intent (8)

| # | Halt | Proposed recommendation shape |
|---|---|---|
| 1 | `oq_business_p1_unresolved` / `oq_blocker` | `proposed_action`: present cached recommendation if OQ has one in vault; otherwise propose "defer to next sync with PO". `rationale`: cite OQ category + dependency chain. `confidence`: high if recommendation cached, low otherwise. `alternatives`: [accept_recommendation, defer, override_with_assumption]. |
| 2 | `diff_conflict` | `proposed_action`: based on `conflict_old` vs `conflict_new` semantics — typically "supersede with newer PRD value unless deletion is destructive". `rationale`: PRD diff timestamp + scope of change. `confidence`: medium. `alternatives`: [supersede, keep_vault, capture_both]. |
| 3 | `drift_framework_mismatch` | `proposed_action`: "pivot vault to detected framework" (code is ground truth). `rationale`: rebuild aligning to code is cheaper than rewriting code. `confidence`: medium. `alternatives`: [pivot_vault, fix_code, hybrid_with_adapter]. |
| 4 | `bind_conflict_constitution_violation` | `proposed_action`: "reject conflict; honor constitution clause". `rationale`: constitution clauses are mutability=LOCKED. `confidence`: high (legal/compliance source). `alternatives`: [reject_conflict, request_constitution_amendment, scope_carve_out]. |
| 5 | `constitution_drift_detected` | `proposed_action`: "fix code to comply" (§B Security / §F Compliance violations have legal weight). `rationale`: cite drifted clause + risk class. `confidence`: high. `alternatives`: [fix_code, amend_constitution_with_legal_review, override_with_signed_risk_acceptance]. |
| 6 | `bolt_introduces_locked_drift` | `proposed_action`: "revert bolt change; locked entity requires escalation". `rationale`: LOCKED tier = explicit human intent. `confidence`: high. `alternatives`: [revert, propose_unlocking_review, override_with_reason]. |
| 7 | `memory_schema_mismatch` | `proposed_action`: "auto-migrate with backup". `rationale`: schema versions designed for forward-only evolution. `confidence`: high if migration path exists, medium otherwise. `alternatives`: [auto_migrate_with_backup, defer_migration_use_legacy_read, manual_review]. |
| 8 | `prd_no_scopes_block_user_rejected_retrofit` | `proposed_action`: "fall back to single-scope vault (legacy behavior)". `rationale`: user already rejected retrofit. `confidence`: high. `alternatives`: [single_scope_fallback, manual_PRD_edit, cancel]. |

### Spec/data integrity (6)

| # | Halt | Proposed recommendation shape |
|---|---|---|
| 9 | `prd_path_missing` | `proposed_action`: "regenerate vault with current PRD" if newer PRD exists. `rationale`: vault.json stores path; PRD relocation common. `alternatives`: [regenerate_with_current_prd, restore_at_recorded_path, edit_vault_json]. |
| 10 | `prd_retrofit_low_confidence` | `proposed_action`: "single-scope fallback" (safer than accepting low-conf retrofit). `rationale`: low confidence = high revision cost downstream. `alternatives`: [single_scope_fallback, accept_retrofit_anyway, cancel]. |
| 11 | `wave_quality_threshold_unmet` | `proposed_action`: "re-run wave with adjusted prompt" if hallucination floor exceeded. `rationale`: cite specific metric breach. `alternatives`: [accept_with_qa_notes, re_run_with_prompt_v2, manual_review]. |
| 12 | `dedup_ambiguous` | `proposed_action`: "pick most-recently-modified existing unit as canonical". `rationale`: recency bias is reasonable default. `alternatives`: [pick_most_recent, create_new_unit, manual_review]. |
| 13 | `hard_rule_violated` | `proposed_action`: "revert bolt commit". `rationale`: rule violations are by-design halt conditions. `alternatives`: [revert, amend_bolt_to_comply, override_with_explicit_approval]. |
| 14 | `unit_underspecified` (acceptance_test C2 path per attestation #12) | `proposed_action`: "emit visible HARD-FLAGGED stub acceptance_test; require human to author real test". `rationale`: prevent unit passing bolt without real validation. `alternatives`: [emit_hard_flag_stub, defer_unit, author_now]. |

### Execution flow (5)

| # | Halt | Proposed recommendation shape |
|---|---|---|
| 15 | `bolt_repeated_partial_failure` | `proposed_action`: "review unit spec; failure pattern suggests unit may be under-specified or environment mismatch". `rationale`: cite failure history. `alternatives`: [edit_unit_spec, env_repair, abort_bolt]. |
| 16 | `module_blocked_by` | `proposed_action`: "run prerequisite module first" per dependency order. `rationale`: cite blocking module + dependency edge. `alternatives`: [run_prereq_first, override_order, edit_modules_yaml]. |
| 17 | `hard_rule_unparseable` (DROP path per reclassification #13) | `proposed_action`: "drop unparseable rule" after re-emit failed. `rationale`: re-emit attempted N times; rule is structurally unrecoverable. `alternatives`: [drop_rule, edit_rule_grammar_v1_or_v2, manual_review]. |
| 18 | `cycle_detected` | `proposed_action`: "break at most-derived edge". `rationale`: minimal structural impact. `alternatives`: [break_most_derived, break_at_specified_edge, restructure_vault]. |
| 19 | `predictive_check_failed` | `proposed_action`: cite suggested fix command from `next_action.hint`. `rationale`: preflight check failure is precondition issue. `alternatives`: [fix_then_retry, skip_check_with_risk, abort]. |

### Cross-squad / coordination (4)

| # | Halt | Proposed recommendation shape |
|---|---|---|
| 20 | `cross_squad_dep_invalid` | `proposed_action`: "route through interface contract instead of direct dep". `rationale`: cross-squad direct deps break modularity. `alternatives`: [route_via_interface, request_interface_promotion, refactor_into_same_squad]. |
| 21 | `cross_squad_ambiguous` | `proposed_action`: "assign to squad owning primary affected entity". `rationale`: entity ownership = de-facto squad. `alternatives`: [pick_owning_squad, joint_assignment, defer_to_lead]. |
| 22 | `cross_squad_interface_draft` | `proposed_action`: "wait for interface promotion to stable status". `rationale`: draft interface = breakage risk. `alternatives`: [wait, override_with_risk_note, request_promotion_now]. |
| 23 | `cross_module_dep_invalid` | Same shape as `cross_squad_dep_invalid` adapted for module level. |
| 24 | `interface_ref_missing` | `proposed_action`: "fuzzy-match nearest existing interface + cite trace". `rationale`: typo is most common cause; high-similarity match likely correct. `alternatives`: [use_fuzzy_match, declare_new_interface, remove_ref]. |

### Environment / install (3)

| # | Halt | Proposed recommendation shape |
|---|---|---|
| 25 | `install_failed` | `proposed_action`: cite specific failure mode from `stderr_tail`; suggest "PATH refresh" or "manual install" based on error class. `rationale`: stderr pattern matching. `alternatives`: [retry_after_path_refresh, manual_install, skip_dep_with_degradation]. |
| 26 | `pkg_mgr_not_found` | `proposed_action`: OS-specific install instruction (`brew install` on macOS, etc.). `rationale`: detected OS class. `alternatives`: [install_brew_or_equivalent, install_via_alternative, skip_dep]. |
| 27 | `no_starterkit_detected` | `proposed_action`: "use `--greenfield` flag" if user intent is greenfield. `rationale`: cite cwd inspection findings. `alternatives`: [scaffold_starterkit_now, use_greenfield, cancel]. |

## Operational impact (post-implementation)

After all 27 halts emit `recommendation:` field consistently:

- **User cognitive load drops:** halt envelopes communicate "here's what I think + why" instead of "what should we do?"
- **Decision latency reduces:** explicit option list + confidence rating accelerates user reply
- **Audit trail improves:** Iter 68 analysis can see *what the skill proposed* vs *what user chose* (override rate as metric)
- **Backward-compat:** old halt envelopes without `recommendation:` remain valid (graceful degradation in display)

## Implementation work (per-skill body — out of this iter's scope)

Each producer skill needs body edits to emit `recommendation:` per the table above. Estimated effort: ~1-2 hours per halt × 27 = 27-54 hours total (small per-halt; bulk).

Suggested batching: by source skill (generate-intent halts together, execute-bolts halts together, etc.). Each batch = one iter; can ship incrementally.

## NOT in this iter

- Code/skill body changes — this is doc-only convention establishment
- Halt envelope schema change — already in vault-contract.md §halt-escalation-discipline
- Production verification — depends on per-skill body implementation

This audit is the canonical reference for follow-up implementation when each C2 halt's emit-site is touched.
