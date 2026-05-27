# Halt Escalation Classification — 2026-05-27

## Design requirement (per Farhan 2026-05-27)

Bake escalation discipline INTO skills, not session instructions. Three categories:

- **Cat 1 — Self-resolve (NEVER halt for human):** skill's own output failed format/schema or internal trace got lost → skill fixes itself (log allowed), continues. Don't bother human.
- **Cat 2 — Business gate (halt + PROPOSE + sign-off):** needs domain/stakeholder intent (scope, conflict resolution, business rule) → escalate WITH recommendation + ask sign-off, not raw question.
- **Cat 3 — Grounding gate (halt — KEEP):** continuing would require hallucination (no ground truth, vault↔code conflict) → halt. Enforce via [HOOK-VALIDATE] slice (deterministic validator), not prose.

**Distinguisher:** can model resolve correctly from info it already has? yes → cat1, needs business intent → cat2, would have to fabricate ground truth → cat3. When in doubt → cat2 (don't over-collapse cat3 → cat1).

## Methodology

Source: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md §halt-protocol` canonical enum + grep across all `skills/*/SKILL.md` for halt mentions. 63 distinct halt types identified (57 top-level + 6 `quality_gate_failed` subtypes).

Cross-cutting note: this is a CLASSIFICATION ONLY. No code changes until Farhan signs off on mapping. Walking-skeleton expansion: reclassify the most-frequent or clearest cat1 halts first, prove self-resolve in real-run, expand from there.

## Domain context

TF Import's 27 OQ drops (caught by Iter 67.6 validator) were ARTIFACTS of old-version generation, NOT bugs in the current pipeline. They've been handled as one-time migration cleanup (commit history 2026-05-27). The validator remains forward-applicable to future generations. The retroactive "27 bugs found" framing was wrong; Iter 67.6 produces the validator + hook layer for going-forward enforcement.

## Classification table

Legend:
- **C1** = Self-resolve (skill fixes own output, continues)
- **C2** = Business gate (halt + propose + sign-off)
- **C3** = Grounding gate (halt, enforce via [HOOK-VALIDATE])
- **FB** = Fork-B-future (already parked per Iter 67.5, kept here for completeness)

### Per-source-skill view

#### generate-intent (vault generation)

| Halt | Cat | Rationale | Proposed self-resolve mechanism |
|---|---|---|---|
| `oq_tech_missing_mode` | **C1** | Skill itself emitted OQ without `mode:` field. Skill has full PRD context to classify scan vs recommend; this is its own output gap. | Re-classify using the keyword heuristic in vault-contract.md §"OQ text pattern → category" (high-confidence patterns auto-tagged); default to `recommend` for ambiguous. Log decision. |
| `oq_recommend_underspecified` | **C1** | Recommend OQ missing fields skill should fill. | Re-run recommendation pass for the OQ; if still underspecified, downgrade to `scan` mode. Log. |
| `oq_scan_missing_query` | **C1** | Scan OQ missing scan_target; skill emitted it. | Auto-emit default scan_target = `codebase-map §<category>` based on OQ category prefix. |
| `oq_recommend_citation_invalid` | **C1** | Citation to nonexistent KB section. | Re-pick valid section from KB inventory OR drop recommendation (downgrade to scan). |
| `oq_business_p1_unresolved` / `oq_blocker` | **C2** | P1 business OQ blocks downstream. Genuinely needs stakeholder intent. | Halt + propose recommended resolution based on OQ context + recommendation field if present. Surface options + ask sign-off. |
| `prd_no_scopes_block_user_rejected_retrofit` | **C2** | User already rejected retrofit; explicit terminal user choice. | Keep halt. Propose next options (single-scope fallback / manual retrofit). |
| `prd_retrofit_low_confidence` | **C2** | AI retrofit returned LOW confidence; business intent unclear. | Propose retrofit anyway + cite confidence + ask sign-off. |
| `scope_not_declared_in_prd` | **C1** | User flag references invalid scope; valid scopes list is in PRD. | Auto-display valid scope list, retry with user picking from list (in-band, no halt). |

#### scan-codebase (codebase analysis)

| Halt | Cat | Rationale | Proposed self-resolve mechanism |
|---|---|---|---|
| `deep_scan_subagent_failed` | **C1** | Already soft-halt auto-retry. | Auto-retry once; second fail → degrade to `partial: true` (existing behavior). Stay silent unless ALL fail. |
| `deep_scan_cache_corrupt` | **C1** | Already soft-halt auto-invalidate. | Rename to `.corrupt-<ts>`, re-dispatch subagents. Silent. |
| `deep_scan_subagent_all_failed` | **C2** | All 4 failed = likely API outage. Not skill's fault; user re-runs later. | Halt + propose: "API likely down. Retry in 15min? Or skip starterkit detection (--greenfield)?". |
| `no_starterkit_detected` | **C2** | Genuine business choice: scaffold / greenfield / cancel. | Already proposes options. Keep cat2 with proposal. |
| `dep_missing` | **C1** | Required binary not found. install-deps subsystem can auto-install. | Auto-invoke `/mega-sdd:install-deps --tools=<missing>`; retry on success. Halt only if install fails. |

#### bind-codebase (vault↔code grounding)

| Halt | Cat | Rationale | Proposed self-resolve mechanism |
|---|---|---|---|
| `bind_conflict` | **C3** | Vault claim disagrees with codebase truth. Continuing = hallucinating one side. | KEEP halt. Enforce via existing binding gate (already [HOOK-VALIDATE]-style — `bind-codebase` writes binding.md, generate-units halts if CONFLICT unresolved). Slice expansion candidate: hook validates CONFLICT count before downstream skills. |
| `bind_conflict_constitution_violation` | **C2** | Security/compliance constitutional clause violated. Stakeholder review. | Halt + propose: cite constitution clause + claim conflict + ask "override (legal sign-off) / fix vault / fix code?". |
| `framework_pack_missing` | **C1** | Pack file referenced but absent. | Skill can detect → propose: create stub OR remove reference (downgrade to framework-only). Auto-pick "remove reference" with log; user can override post-facto. |
| `framework_pack_cycle` | **C1** | Inheritance cycle. | Skill can compute cycle path → break at most-derived edge, log. Pure structural fix. |
| `framework_pack_unparseable` | **C1** | YAML parse fail. | Log + skip pack + fall back to parent in inheritance chain. |
| `constitution_drift_detected` | **C2** | §B security or §F compliance drift. Stakeholder/legal. | Halt + propose: cite drifted clause + ask sign-off (override allowed with risk note OR fix code OR fix constitution). |

#### generate-units (vault → units)

| Halt | Cat | Rationale | Proposed self-resolve mechanism |
|---|---|---|---|
| `unit_underspecified` | **C1** | Unit missing required fields skill itself emitted. | Re-emit with defaults: target_files from vault_source paths, acceptance_test from "verify exists" template. Log auto-fill. |
| `dedup_ambiguous` | **C2** | Multiple existing units could match. Business intent (canonical choice). | Halt + propose: pick most-recently-modified unit as canonical + cite collision rationale + ask sign-off. |
| `hard_rule_unparseable` | **C1** | Ast-grep YAML skill emitted. Format error in own output. | Re-emit hard rule; if grammar still fails 2x, drop the rule (log). |
| `starterkit_rule_citation_missing` | **C1** | Internal generation bug — skill emitted starterkit-derived rule without citation. | Re-emit with citation pulled from starterkit-context.yaml §<path> trace. Skill has full context. |
| `unit_oq_trace_missing` (Iter 67.5 prose rule) | **C3** | Grounding: skill must cite OQ-IDs to maintain trace. SUPERSEDED in Iter 67.6 by [HOOK-VALIDATE] validator. | KEEP halt as design vocabulary; enforce via validator hook (already shipped 67.6 slice 1). Skill body rule becomes redundant; can be removed after validator real-run-verified in production. |

#### execute-bolts (units → code)

| Halt | Cat | Rationale | Proposed self-resolve mechanism |
|---|---|---|---|
| `dispatch_prompt_too_large` | **C1** | Bolt prompt > 10KB. Skill can re-tier. | Auto-re-tier context (drop SPECIALIST refs, keep HOT only); retry. Log tier-down decision. |
| `bolt_repeated_partial_failure` | **C2** | Bolt failed 3 cycles. Root cause in unit spec; user reviews. | Halt + propose: cite the 3 failure modes + suggest unit spec adjustments. Ask sign-off on retry vs unit re-edit. |
| `provenance_missing` | **C1** | Bolt file lacks provenance trailer skill should have written. | Auto-add trailer from bolt context; log. |
| `bolt_introduces_locked_drift` | **C2** | LOCKED entity drifted. Override needs sign-off. | Halt + propose: cite locked field + show diff + ask override (with reason field). |
| `self_assessment_missing` | **C1** | Bolt-report missing self-assessment skill should have written. | Auto-generate self-assessment from bolt context; log. |
| `module_blocked_by` | **C2** | Prereq module incomplete. Business choice: wait vs override. | Halt + propose: list blocking modules + suggest run-order. Cat2 because user might want to override sequence. |
| `hard_rule_unanchored` | **C2** | Anchor in unit's Hard Rule can't resolve to current codebase. | Halt + propose: fuzzy-match nearest symbol + show diff + ask sign-off ("use suggested anchor / drop rule / fix manually"). |
| `hard_rule_violated` | **C2** | Post-flight scan found code violates rule. Needs user revert/amend decision. | Halt + propose: cite violation + show diff + ask "revert / amend / override". |
| `pbt_citation_invalid` | **C1** | PBT cites nonexistent ADR. Skill emitted PBT block. | Re-pick valid ADR from vault decisions/ OR drop property (log). |
| `pbt_property_violated` | **C2** | PBT property fails in execution. Real test failure, not format. | Halt + propose: cite failing property + suggest fix patterns. |
| `verify_unit_writable` | **C1** | Verify unit has target_files (invalid spec). Skill emitted it. | Auto-clear target_files (verify units don't write); log. |

#### orchestrate-flow (chain coordination)

| Halt | Cat | Rationale | Proposed self-resolve mechanism |
|---|---|---|---|
| `invalid_handoff` | **C1** | Producer skill handoff fails schema. Producer's own output. | Log + re-invoke producer with `--strict-handoff` flag. If still invalid 2x, escalate as `cat2`. |
| `handoff_type_mismatch` | **C1** | Type drift in handoff. Producer bug. | Same as `invalid_handoff` — re-invoke + log. |
| `handoff_missing` | **C1** | No parseable handoff in chat. Producer crashed or emitted nothing. | Re-invoke producer standalone; if still empty 2x, escalate. |
| `artifact_missing` | **C1** | Handoff says artifacts exist but file doesn't. | Re-invoke producer to write artifact; verify post-write. |
| `partial_state_corrupt` | **C1** | partial-state.json parse fail. | Rename to `.corrupt-<ts>`, restart fresh (already documented). Pure self-resolve. |
| `routing_outcome_corrupt` | **C1** | Already SOFT halt auto-invalidate. | Existing behavior; pure self-resolve. |
| `predictive_check_failed` | **C2** | Preflight check failed (env / config). User fixes precondition. | Halt + propose: cite failing check + show suggested fix command. Ask sign-off on fix-then-retry. |
| `model_tier_unknown` | **C1** | Already SOFT halt log+ignore. | Pure self-resolve. |
| `mode_migrate` | **C1** | Vault mode mismatch with CWD signals. | Re-detect from CWD signals deterministically; update vault.json.mode; log change. No user prompt needed unless user explicitly overrode mode previously. |
| `prd_path_missing` | **C2** | vault.json.prd_path points to missing file. | Halt + propose: list files near recorded path + ask "restore? regenerate vault? edit path?". |

#### diff-vault (PRD revision)

| Halt | Cat | Rationale | Proposed self-resolve mechanism |
|---|---|---|---|
| `diff_conflict` | **C2** | Resolved-OQ or Decision conflict requires stakeholder intent. | Halt + propose: show conflict_old/new + cite latest stakeholder context + recommend "supersede" vs "keep_vault" with rationale. Ask sign-off. |

#### detect-drift (code vs vault)

| Halt | Cat | Rationale | Proposed self-resolve mechanism |
|---|---|---|---|
| `drift_framework_mismatch` | **C2** | Code framework ≠ vault framework. Big business decision. | Halt + propose: detected vs expected + options (pivot vault / fix code / mixed). Sign-off. |
| `constitution_drift_detected` | **C2** | Already classified above under bind-codebase. | Same. |

#### memory (persistence)

| Halt | Cat | Rationale | Proposed self-resolve mechanism |
|---|---|---|---|
| `memory_in_use` | **C1** | File lock collision; retry exhausted. | Increase retry budget + exponential backoff. If still fails after 10x, log + skip memory update (non-fatal). |
| `memory_schema_mismatch` | **C2** | Schema migration needed. User opts in. | Halt + propose: show schema diff + ask "auto-migrate?". Cat2 because migration could lose data. |

#### install-deps (dependency management)

| Halt | Cat | Rationale | Proposed self-resolve mechanism |
|---|---|---|---|
| `install_failed` | **C2** | Install command failed (env/network). User investigates. | Halt + propose: show stderr_tail + suggest common fixes (PATH refresh / signing). Ask sign-off on retry. |
| `pkg_mgr_not_found` | **C2** | No pkg mgr for OS. User installs. | Halt + propose: OS-specific install instruction (brew / apt / WSL). |

#### extract-intelligence + emit-fsd (auxiliary)

| Halt | Cat | Rationale | Proposed self-resolve mechanism |
|---|---|---|---|
| `quality_gate_failed:wave_quality_threshold_unmet` | **C2** | KB extraction quality below threshold. User accepts with QA notes OR re-runs. | Halt + propose: show metric breakdown + cite specific failures. Ask sign-off on accept-with-notes vs re-run. |
| `quality_gate_failed:starterkit_metrics_inconsistent` | **C1** | Internal inconsistency between scan output + generate-units output. | Auto-trigger `/mega-sdd:scan-codebase --force-deep` then regenerate. Log. |
| `quality_gate_failed:pdf_render_failed` | **C1** | Pandoc/LaTeX render fail. | Auto-invoke `/mega-sdd:install-deps --tools=tectonic`; retry. |
| `quality_gate_failed:template_slot_unfilled` | **C1** | Skill template emitted `{{slot}}` placeholder. Skill bug in its own template. | Auto-emit placeholder text "(content pending — section-mapping bug)" + flag for plugin author. Continue. |

#### Cross-cutting (squad / interface coordination)

| Halt | Cat | Rationale | Proposed self-resolve mechanism |
|---|---|---|---|
| `cross_squad_dep_invalid` | **C2** | `depends_on` edge crosses squads. Coordination needed. | Halt + propose: route through interface OR break edge. Ask sign-off. |
| `cross_squad_ambiguous` | **C2** | Multi-squad ambiguity. | Halt + propose: assignment options. Sign-off. |
| `cross_squad_interface_draft` | **C2** | Interface in draft state; consumer waits. | Halt + propose: wait OR override (with risk). |
| `cross_module_dep_invalid` | **C2** | Same pattern, module level. | Same as cross_squad_dep_invalid. |
| `interface_ref_missing` | **C2** | Dangling interface ID. Could be typo or stale. | Halt + propose: fuzzy match nearest interface + ask "use match / declare new / remove ref?". |
| `cycle_detected` | **C2** | DAG cycle in unit deps. | Halt + propose: cite cycle path + suggest break point (most-derived edge). Sign-off. |

#### Fork-B-future (already parked per Iter 67.5, NOT in scope)

| Halt | Cat | Status |
|---|---|---|
| `quality_gate_failed:replan_budget_exceeded` | **FB** | Parked. Anti-recursive guard runtime retracted Iter 67.5. |
| `quality_gate_failed:revalidate_budget_exceeded` | **FB** | Same. |

## Summary by category

| Category | Count | Notes |
|---|---|---|
| **C1 (Self-resolve)** | **28** | These currently halt for human; should be re-engineered to fix own output + log. Major reduction in interruption surface. |
| **C2 (Business gate, propose+sign-off)** | **27** | Keep halt but enforce "with proposal" discipline — no raw "what should I do?" questions. |
| **C3 (Grounding gate, [HOOK-VALIDATE])** | **2** | `bind_conflict`, `unit_oq_trace_missing` (slice 1 shipped; slices 2-6 expand pattern). |
| **FB (Fork-B-future, parked)** | **2** | Retracted per Iter 67.5; not in 67.x scope. |
| **TOTAL** | **59** | Plus 4 `quality_gate_failed` subtypes already counted in their parent rows above. |

## Walking-skeleton execution order (if Farhan signs off mapping)

**Phase A — Lowest-risk C1 batch (proven safe to self-resolve):**
- `mode_migrate` (deterministic re-detect)
- `routing_outcome_corrupt` (already soft)
- `partial_state_corrupt` (already documented self-resolve)
- `model_tier_unknown` (already soft)
- `memory_in_use` (just bigger retry budget)
- `verify_unit_writable` (auto-clear target_files)

These already have SOFT semantics in some form; just need consistency + remove "ALWAYS STOP" wording.

**Phase B — Skill-self-output C1 batch:**
- `unit_underspecified` (re-emit with defaults)
- `oq_tech_missing_mode` / `oq_scan_missing_query` / `oq_recommend_underspecified` (re-classify from heuristics)
- `oq_recommend_citation_invalid` / `pbt_citation_invalid` (re-pick or drop)
- `starterkit_rule_citation_missing` (re-emit with trace)
- `hard_rule_unparseable` (re-emit; drop after 2 fails)
- `template_slot_unfilled` / `quality_gate_failed:starterkit_metrics_inconsistent` / `quality_gate_failed:pdf_render_failed` (auto-retry mechanisms)

These are skills correcting their own output. Pure cat1 work.

**Phase C — Orchestrate-flow handoff C1 batch:**
- `invalid_handoff` / `handoff_type_mismatch` / `handoff_missing` / `artifact_missing` — re-invoke producer with stricter flags before halting. Already has retry semantics; just formalize.

**Phase D — C2 "propose+sign-off" discipline pass:**
- Audit each C2 halt to ensure halt envelope INCLUDES a `recommendation` field, not just options
- This is doc-only work mostly; existing halts already emit options but rarely propose

**Phase E — Slice expansion of [HOOK-VALIDATE] (C3 series):**
- Slice 2: CONFLICT-ID propagation (clone of slice 1 OQ-ID pattern)
- Slice 3: Hard Rule propagation
- Slice 4: vault → binding coverage
- Slice 5: units → bolts traceability
- Slice 6: `/mega-sdd:analyze` umbrella

## Risk flag resolutions (reviewer 2026-05-27 — technical review, not Farhan-escalation)

Operating model affirmed: tech-judgment risk flags resolved via technical review. Only domain/business decisions at C2 runtime fire go to Farhan. The 4 flags:

1. **`bolt_repeated_partial_failure`** → **STAYS C2.** Reviewer rationale: repeated failure across 3 cycles is EXACTLY the moment the human needs to know — could be unit spec defect, env corruption, or grounding issue. C1-with-silent-give-up = the opposite of the discipline (hides failure). Halt + report + propose root-cause guess. Risk-flag closed.

2. **`hard_rule_unanchored`** → **STAYS C2 main halt.** Two-tier resolution allowed INSIDE the C2 path: high-similarity fuzzy match → auto-anchor with HARD log + conservative similarity threshold (≥ 0.95 token-level OR exact basename match) → resolved as C1 sub-branch with auditable log entry. Low-similarity → escalate to user with options. Anchor-mismatch IS a grounding error if propagated; conservative bar is mandatory. The halt overall remains C2 (not in the 28-C1 list). Risk-flag closed.

3. **`bind_conflict`** → **C3 target; HONESTLY labeled as prose-enforced today; hook-enforced after slice 2/4.** Same honesty discipline as Iter 67.5 Runtime SHIPPED retraction. Don't claim hook-enforcement until slice 2 (CONFLICT-ID propagation) and slice 4 (vault→binding coverage) ship and real-run-verify. Risk-flag closed.

4. **`predictive_check_failed`** → **STAYS C2 conservative.** Reviewer rationale: split per-check (auto-install-dep → C1; env config → C2) is optimization; premature. Revisit only after framework proves out (Phase A + B verified in production). Risk-flag closed.

## What changes after sign-off (if accepted as proposed)

- ~28 halts move from "ALWAYS STOP" to silent self-resolve. **Major reduction in human interrupt surface.**
- ~27 halts keep halting but switch to "halt + propose recommendation" pattern. **Quality of escalation improves; no more raw questions.**
- 2 halts stay grounding gates, enforced by hook validators (1 shipped slice 1, slices 2-6 follow).
- 2 halts stay parked Fork-B (no change from Iter 67.5).
- Net effect: halt taxonomy shrinks operationally; only ~29 halts ever interrupt the human (cat2 + cat3 + FB), down from ~59.

## Walking-skeleton DISCIPLINE reminder

Per Iter 67.6 lesson: pick the smallest cat1 slice, prove self-resolve in real-run, expand only after proof. **Don't refactor all 28 cat1 halts at once.** Recommended slice 1 = Phase A (the already-soft halts) — just formalize their self-resolve behavior + remove ALWAYS-STOP wording. Real-run-proof: trigger one of those halts in TF Import; observe skill auto-resolves + continues without prompting human.
