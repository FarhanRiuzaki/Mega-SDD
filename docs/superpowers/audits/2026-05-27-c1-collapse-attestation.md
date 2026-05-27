# C1 Collapse Attestation — 2026-05-27

## Purpose

Audit gate BEFORE collapsing the wider 22-halt C1 batch (beyond Phase A's 6 already-soft halts). Per reviewer 2026-05-27: surface every C1 candidate with one-line justification + explicit attestation that the collapse doesn't erode the grounding moat or hide failures from the human.

## The attestation (applies to every C1 halt below)

For each halt classified C1, **both** constraints MUST hold:

1. **No ground-truth fabrication.** Resolution uses information the model already has in-context (skill's own output, vault contents, codebase-map, CWD signals, deterministic heuristics from vault-contract). If resolution would require guessing at facts the model lacks → cat3.

2. **No silent failure hiding.** Resolution path emits a structured log entry (telemetry event `halt_self_resolved` with payload `{halt_type, fix_applied, original_emit_site}`); degradation paths (e.g., "drop the rule after 2 fails") are documented and observable in `.mega-sdd/.validation-blockers.json` or skill chat output. If the human would be materially worse off NOT being told → cat2.

If either constraint is in doubt for a specific halt → it stays C2, not C1.

## 28 C1 candidates + 3 C1 quality_gate_failed subtypes

### generate-intent (5)

| # | Halt | One-line justification | Constraints |
|---|---|---|---|
| 1 | `oq_tech_missing_mode` | Skill itself emitted OQ without `mode:` field. Re-classify via heuristic table in `vault-contract.md §"OQ text pattern → category"` (already in skill's context). | ✅ no fabrication (heuristic is deterministic); ✅ logged (auto-classification noted in OQ description field) |
| 2 | `oq_recommend_underspecified` | Recommend OQ missing fields skill should have filled. Re-run recommendation pass against same PRD + KB context. | ✅ no fabrication (same inputs, structured re-run); ✅ logged (re-run attempt logged; if still underspec → downgrade to scan with log) |
| 3 | `oq_scan_missing_query` | Scan OQ missing `scan_target` skill should emit. Default to `codebase-map §<OQ-category>` pattern from category prefix (deterministic). | ✅ no fabrication (mechanical from OQ-ID prefix); ✅ logged (default-applied noted) |
| 4 | `oq_recommend_citation_invalid` | Citation to nonexistent KB section. Re-pick from KB inventory in same context OR drop recommendation (downgrade to scan mode). | ✅ no fabrication (re-pick from existing KB or drop); ✅ logged (citation change noted in OQ entry) |
| 5 | `scope_not_declared_in_prd` | User flag references scope not in PRD frontmatter. Valid scopes list IS in PRD — display + retry in same turn (not actually a halt). | ✅ no fabrication (PRD is ground truth); ✅ logged (user sees retry prompt; deterministic) |

### scan-codebase (3)

| # | Halt | One-line justification | Constraints |
|---|---|---|---|
| 6 | `deep_scan_subagent_failed` | Single subagent failed once. ALREADY soft-halt with auto-retry; just formalizing semantics. Second fail degrades to `partial: true` in output. | ✅ no fabrication (retry uses same inputs); ✅ logged (retry attempt + partial flag both visible in output) |
| 7 | `deep_scan_cache_corrupt` | starterkit-context.yaml fails YAML parse. ALREADY auto-invalidate (rename `.corrupt-<ts>` + re-dispatch). | ✅ no fabrication (re-dispatch from scratch); ✅ logged (rename leaves forensics; re-dispatch visible) |
| 8 | `dep_missing` | Required binary not found. `install-deps` subsystem auto-installs deterministically based on OS detection + pkg-mgr catalog. | ✅ no fabrication (catalog is deterministic mapping); ✅ logged (install command + exit code; on install fail, escalates to `install_failed` which is C2) |

### bind-codebase (3)

| # | Halt | One-line justification | Constraints |
|---|---|---|---|
| 9 | `framework_pack_missing` | **REVIEWER 2026-05-27 ACCEPTED AS C1 WITH WATCH NOTE:** Pack file referenced but absent. Skill knows reference site; deterministic option = remove reference (degrades to framework-only). User can post-facto restore. **DROP IS REVIEW-VISIBLE: binding.md gets a top-of-document `## ⚠️ DEGRADED — Framework Packs Dropped` section listing every dropped pack with reason, NOT just inline log. Human reading binding.md sees the degradation on first scroll.** | ✅ no fabrication (drops reference, doesn't invent pack content); ✅ logged + REVIEW-VISIBLE (degraded section at binding.md top; cannot miss on review) |
| 10 | `framework_pack_cycle` | Inheritance cycle (A extends B extends A). Skill can compute cycle path; deterministic break at most-derived edge. | ✅ no fabrication (graph algorithm); ✅ logged (cycle path + break-point logged in binding.md) |
| 11 | `framework_pack_unparseable` | Pack YAML parse fail. Skip pack + fall back to parent in inheritance chain (existing pattern). | ✅ no fabrication (uses parent, doesn't invent); ✅ logged (skip + fallback noted; parent identity in binding.md) |

### generate-units (3)

| # | Halt | One-line justification | Constraints |
|---|---|---|---|
| 12 | `unit_underspecified` | **REVIEWER 2026-05-27 RECLASSIFIED:** target_files re-derive from vault_source = C1; acceptance_test substitution = C2. Auto-templating "verify exists" risks TDD rigor (unit passes bolt without real validation). C1 path now: re-emit target_files only. acceptance_test path: emit visible HARD-FLAGGED stub `acceptance_test: [{type: stub, status: NEEDS_HUMAN_AUTHORING, _flag: "HARD STUB — DO NOT EXECUTE"}]` AND escalate to C2 for non-trivial units (task_type ∈ {create, extend} with complexity ≠ small). Verify units → C1 with hard flag. | ✅ no fabrication (target_files traced; acceptance_test marked stub not substituted); ✅ logged (hard flag is in-body, not footer-buried; escalation surfaces non-trivial cases) |
| 13 | `hard_rule_unparseable` | **REVIEWER 2026-05-27 RECLASSIFIED:** re-emit attempt = C1; DROP path = C2. Hard Rule is grounding core; silent drop = anti-halu moat erosion. C1: try re-emit ast-grep YAML once. If 2nd attempt still unparseable → ESCALATE to C2 with proposal `"cannot parse Hard Rule X (attempts: 2). Drop with rationale? [Y/n]"`. No silent drop. | ✅ no fabrication (re-emit uses original intent); ✅ no silent-drop hiding (escalation explicit for the failure case) |
| 14 | `starterkit_rule_citation_missing` | Skill emitted starterkit-derived rule without citation. Re-emit using starterkit-context.yaml `§<path>` trace (skill has trace in its working context). | ✅ no fabrication (trace is deterministic); ✅ logged (citation source noted on the rule line) |

### execute-bolts (5)

| # | Halt | One-line justification | Constraints |
|---|---|---|---|
| 15 | `dispatch_prompt_too_large` | Bolt dispatch prompt > 10KB. Re-tier context (drop SPECIALIST refs, keep HOT) + retry. | ✅ no fabrication (drops loaded context, doesn't invent); ✅ logged (tier-down decision in bolt-report.md) |
| 16 | `provenance_missing` | Bolt-modified file lacks provenance trailer skill should have written. Auto-add trailer from bolt context (file path, unit_id, bolt run ID — all in scope). | ✅ no fabrication (context is in scope); ✅ logged (trailer addition noted in bolt-report) |
| 17 | `self_assessment_missing` | Bolt-report missing self-assessment section. Auto-generate from bolt context (acceptance test results + diff summary). | ✅ no fabrication (synthesis from completed bolt artifacts); ✅ logged (auto-generated flag in section header) |
| 18 | `pbt_citation_invalid` | PBT cites nonexistent ADR. Re-pick from `vault/decisions/` directory OR drop property (downgrade). | ✅ no fabrication (re-pick or drop); ✅ logged (citation change noted; drop logged with reason) |
| 19 | `verify_unit_writable` | Verify unit has non-empty target_files (invalid spec — verify units don't write). Clear target_files; log. | ✅ no fabrication (deterministic clear); ✅ logged (correction noted) |

### orchestrate-flow (8)

| # | Halt | One-line justification | Constraints |
|---|---|---|---|
| 20 | `invalid_handoff` | Producer skill handoff fails schema. Re-invoke producer with `--strict-handoff` flag; **escalate to C2 if still invalid after 2 attempts.** | ✅ no fabrication (re-invokes producer); ✅ logged (attempts logged; escalation path explicit — NOT silent abandonment) |
| 21 | `handoff_type_mismatch` | Type drift in handoff. Same pattern as #20: re-invoke + escalate after 2 fails. | Same as #20 |
| 22 | `handoff_missing` | No parseable handoff in producer's chat. Re-invoke producer standalone; **escalate to C2 if still missing after 2 attempts.** | Same as #20 |
| 23 | `artifact_missing` | Handoff lists artifacts but file doesn't exist. Re-invoke producer to write artifact; verify post-write; **escalate to C2 if still missing after retry.** | Same as #20 |
| 24 | `partial_state_corrupt` | partial-state.json parse fail. Rename `.corrupt-<ts>`, restart fresh (existing semantics). | ✅ no fabrication (fresh start); ✅ logged (forensics file preserved; restart noted) |
| 25 | `routing_outcome_corrupt` | routing-outcomes.md parse fail. ALREADY auto-invalidate. | ✅ no fabrication (uses default routing); ✅ logged (invalidation + default-used both visible) |
| 26 | `model_tier_unknown` | Model-tier override references unknown role. ALREADY log + ignore (forward-compat for future roles). | ✅ no fabrication (uses catalog default); ✅ logged (override-ignored noted) |
| 27 | `mode_migrate` | vault.json.mode mismatch CWD signals (e.g., greenfield in mode but .git + composer.json present). Re-detect from CWD signals deterministically; update vault.json.mode. | ✅ no fabrication (CWD signals are ground truth); ✅ logged (mode change + signals visible in vault.json change history) |

### memory (1)

| # | Halt | One-line justification | Constraints |
|---|---|---|---|
| 28 | `memory_in_use` | File lock collision after retries exhausted. Increase retry budget + exponential backoff to 10 attempts; if still fails, **log + skip memory update** (memory writes are advisory; chain proceeds). | ✅ no fabrication (just retry / skip); ✅ logged (skip + reason noted in chat; human sees memory entry isn't persisted) |

### quality_gate_failed subtypes (3 C1, parent is C2)

| # | Halt | One-line justification | Constraints |
|---|---|---|---|
| S1 | `quality_gate_failed:starterkit_metrics_inconsistent` | Internal inconsistency between scan-codebase output + generate-units output. Auto-trigger `/mega-sdd:scan-codebase --force-deep` + regenerate units. | ✅ no fabrication (re-runs deterministic flows); ✅ logged (auto-trigger + outcome visible) |
| S2 | `quality_gate_failed:pdf_render_failed` | Pandoc/LaTeX render fail. Auto-invoke `/mega-sdd:install-deps --tools=tectonic` + retry render. | ✅ no fabrication (install + retry); ✅ logged (install attempt + render retry; if STILL fails, escalates to C2 install_failed) |
| S3 | `quality_gate_failed:template_slot_unfilled` | Skill template emitted `{{slot}}` placeholder — skill bug in its own template. Emit placeholder text `(content pending — slot=<name> — section-mapping bug)` + flag for plugin author + continue. | ✅ no fabrication (placeholder, not invented content); ✅ logged (placeholder is VISIBLE in output; human cannot miss it on review) |

## Cross-cutting safeguards (the moat)

These guarantee the attestation across all 28+3 C1 candidates:

1. **Telemetry event `halt_self_resolved`** — every C1 self-resolve emits ONE event to telemetry.jsonl. Schema:
   ```json
   {
     "event_type": "halt_self_resolved",
     "payload": {
       "halt_type": "oq_scan_missing_query",
       "fix_applied": "default scan_target = codebase-map §AR",
       "original_emit_site": "generate-intent Step 6.2",
       "logged_at_chat": true | false
     }
   }
   ```
   This is the structural anti-hiding mechanism. Iter 68 analysis can audit C1 frequency + verify no class of failure is over-collapsed.

2. **Chat surface** — every C1 self-resolve emits a one-line chat message: `[self-resolved] <halt_type>: <fix_applied>`. NOT a halt envelope (no interruption), but visible to human reviewing chat history.

3. **Escalation paths explicit** — halts #20-23 (invalid_handoff / handoff_type_mismatch / handoff_missing / artifact_missing) self-resolve only on first attempt; **2nd failure escalates to C2** with full retry history in the halt envelope. No infinite-retry hiding.

4. **C2 fallback for ambiguous cases** — if at runtime any C1 logic encounters a case where the resolution would require ground truth (e.g., re-pick from an empty KB inventory), it MUST escalate to C2 with proposal. This is the runtime escape hatch from over-collapse.

## What's NOT in this list (cross-check anti-erosion)

The following halts were explicitly NOT classified C1 — confirm none of them slipped in:

- **`bind_conflict`** → C3 target (prose-enforced today, hook-enforced after slice 2/4 per honesty discipline)
- **`bolt_repeated_partial_failure`** → C2 (per reviewer 2026-05-27 — repeated failure is EXACTLY when human should know)
- **`hard_rule_unanchored`** → C2 main halt; two-tier handling INSIDE the C2 resolution (high-similarity branch with hard-log + auditable; low-similarity escalates to user). The halt overall remains C2. NOT in this C1 list.
- **`predictive_check_failed`** → C2 (per reviewer 2026-05-27 — split is premature optimization)
- **`bolt_introduces_locked_drift`** → C2 (LOCKED entity override needs sign-off)
- **`bind_conflict_constitution_violation`** → C2 (security/legal intent)
- **`constitution_drift_detected`** → C2 (same)
- **`memory_schema_mismatch`** → C2 (migration could lose data)
- **`dedup_ambiguous`** → C2 (canonical-unit choice is business intent)
- **`hard_rule_violated`** → C2 (revert vs amend is user judgment)
- **`oq_business_p1_unresolved`** → C2 (stakeholder intent)
- **`diff_conflict`** → C2 (stakeholder for vault-vs-PRD conflict)
- **`drift_framework_mismatch`** → C2 (framework pivot is business)
- **`cross_squad_*` / `cross_module_dep_invalid` / `interface_ref_missing` / `cycle_detected`** → C2 (coordination intent)
- **`prd_*_low_confidence` / `prd_no_scopes_*` / `prd_path_missing`** → C2 (PRD-scoped business decisions)
- **`no_starterkit_detected` / `deep_scan_subagent_all_failed`** → C2 (terminal environment state)
- **`install_failed` / `pkg_mgr_not_found`** → C2 (env / network — user investigates)
- **`quality_gate_failed:wave_quality_threshold_unmet`** → C2 (parent halt is C2; this default subtype keeps C2)
- **`quality_gate_failed:replan_budget_exceeded` / `:revalidate_budget_exceeded`** → Fork-B-parked (retracted Iter 67.5)

## Walking-skeleton order (after audit gate clears)

**Phase A (APPROVED — already running):** the 6 most-already-soft halts. Real-run proof via TF Import.

**Phase B (CONDITIONAL on Phase A success + this attestation accepted):** the remaining 22 C1 (+ 3 subtypes), batched by skill:
- Phase B.1: generate-intent (5 halts) — re-emission logic in skill body
- Phase B.2: scan-codebase (already-soft + dep_missing wire-up)
- Phase B.3: bind-codebase framework_pack triplet
- Phase B.4: generate-units re-emission + starterkit_rule_citation
- Phase B.5: execute-bolts auto-fix branches
- Phase B.6: orchestrate-flow handoff re-invoke triplet + escalate-after-2 rule
- Phase B.7: memory retry budget bump
- Phase B.8: 3 quality_gate subtypes

Each sub-phase real-run-verified before the next ships. **Walking-skeleton discipline holds across all 8 sub-phases.**

## Reviewer audit outcome (2026-05-27)

**Classification ACCEPTED with 3 reclassifications** applied above (#12 unit_underspecified, #13 hard_rule_unparseable, #9 framework_pack_missing). All three preserved C1 paths but tightened C2 escalation discipline for grounding-adjacent failure modes.

**TWO GATES established before Phase B (the 22 remaining C1 candidates) collapse:**

### Gate A — Anti-hiding net unproven

The attestation's "no silent failure" guarantee depends on `halt_self_resolved` telemetry event + chat one-liner. **Telemetry collection is NOT YET production-proven** (Stop hook unverified in real-run; `turn_end_marker` not yet observed in TF Import telemetry.jsonl from a real Claude Code session). If telemetry fails to emit, every "self-resolve" happens WITHOUT log = exactly the silent-hiding the attestation claims to prevent. **The anti-hiding net is vacuous until telemetry is empirically observed in production.**

Gate A clears only when: `cat <project>/.mega-sdd/memory/telemetry.jsonl | grep halt_self_resolved` returns ≥1 entry from a real Claude Code chain run (not simulated).

### Gate B — Prose-only C1 protocol = 4× audit failure pattern

Iter 67.7 ships the C1 protocol as **prose in `vault-contract.md`**. Classification ≠ working behavior. The same prose-vs-execution gap that caused Iter 64-67 ship retractions could repeat: skill bodies may read the protocol but not execute it. **Phase B should NOT ship reliable until C1 self-resolve is proven to actually happen in production** — which most likely requires hook-layer enforcement (e.g., SessionStart hook detects `mode_migrate` precondition + auto-fixes + emits telemetry, deterministic; PostToolUse intercepts the partial-state.json Read failure + renames + restarts).

Gate B clears only when: at least ONE Phase A halt is observed self-resolving via hook-layer (not prose) execution in a real run.

### Mitigation strategy (per reviewer 2026-05-27)

- Don't waste a cycle testing prose-only C1 (audit-confirmed unreliable).
- Build hook-layer enforcement for Phase A NOW. Pattern = SessionStart / PostToolUse / PreToolUse / Stop hooks deterministically detect + fix C1 conditions + emit telemetry.
- Walking-skeleton: pick ONE Phase A halt → wire hook enforcement → real-run prove → expand.
- Recommended first slice: `mode_migrate` via SessionStart hook extension (CWD signal re-detection is purely deterministic + existing hook surface).

## Final attestation statement

I attest, on the basis of one-line justifications above + cross-cutting safeguards + the explicit NOT-IN-LIST cross-check:

> **Each of the 28 main C1 halts + 3 subtype C1 halts satisfies BOTH constraints:**
> 1. **No ground-truth fabrication** — every resolution uses information the model already has in-context (skill's own emission state, vault contents, codebase-map, CWD signals, or deterministic heuristics from vault-contract).
> 2. **No silent failure hiding** — every resolution emits a `halt_self_resolved` telemetry event + chat-visible one-liner; escalation paths to C2 (after retry exhaustion) are explicit; degradation paths preserve forensics (rename `.corrupt`, `partial: true` flags, etc.).

**No halt requiring grounding/business intent has been over-collapsed into C1.** Reviewer audit confirms.

If reviewer identifies any halt above that violates either constraint → flag it for re-classification before Phase B starts.
