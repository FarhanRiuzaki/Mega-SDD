# Iter 56 Deep Audit — Dimension A: Halt Taxonomy Completeness

**Audited by:** general-purpose subagent
**Date:** 2026-05-26
**Baseline:** Iter 38 (v3.26.2); current state v3.38.0
**Files inspected:**
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` §halt-protocol (lines 559-762)
- `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md`
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`
- `tests/scenarios/scenario-6-recovery-from-halt.md`
- All producer SKILL.md (bind-codebase / detect-drift / diff-vault / execute-bolts / generate-intent / generate-units / orchestrate-flow / scan-codebase / extract-intelligence / resolve-oq / memory / install-deps / emit-fsd / emit-agents-md)

---

## Summary

- **Total halt types in canonical enum** (vault-contract.md:569): **46**
- **Halt types referenced as `→ halt <name>` in skill bodies but NOT in enum** (orphan-in-the-wild): **9** (significant drift)
- **Enum halts with producer evidence**: 38/46 (`oq_blocker` has description-only producer claim; not a hard emit site)
- **Enum halts with full canonical description block** (lines 587-631): 45/46 (`mode_migrate` lacks dedicated description; only type-specific schema at line 722)
- **Enum halts with scenario-6 recovery walkthrough**: ~14 of 46 (still many gaps after Iter 49 added 10)
- **Enum halts with predictive-check `predicts_halt:` coverage**: 9 of 46
- **Iter 53/54/55 NEW halts (5 total) audit status**: scenario-6 = 0/5 covered; predictive-checks = 0/5 covered; vault-contract descriptions = 2/5 fully described (install-deps Iter 55) and 3/5 missing (`quality_gate_failed` subtypes from Iter 53/54)

**Headline risk:** Iter 53/54/55 halts shipped without scenario-6 walkthroughs AND without predictive-check anticipation. `install-deps` has NO `### install-deps preflight checks` section in predictive-checks.md, so chain failures will hit halt-protocol cold (the very pattern Iter 33 predictive-checks was designed to avoid). Per spec §4.2: "Instead of 'scan-codebase halted on dep_missing 8 minutes in', user sees 'before chain starts: tree-sitter not installed'." Iter 55 regressed this UX for the new install-deps skill.

---

## Findings

### P1 HIGH (orphans / drift)

#### A1-001: 9 halt types emitted by producers but missing from canonical enum
- **Severity:** P1 HIGH
- **Source:** `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md:569` (enum) vs emit sites listed below
- **Issue:** The following halt names appear in producer skill bodies as `→ halt <name>` or `type: <name>` instructions, but are NOT in the enum at line 569. Halt envelope consumers (orchestrate-flow, handoff-contract validation) will reject these as `invalid_handoff` because the type isn't whitelisted. Listed with primary emit site:
  - `oq_tech_missing_mode` — `plugins/mega-sdd/skills/generate-intent/SKILL.md:689` + `vault-contract.md:191,285`
  - `oq_recommend_underspecified` — `generate-intent/SKILL.md:690` + `bind-codebase/SKILL.md:542`
  - `oq_scan_missing_query` — `generate-intent/SKILL.md:691`
  - `oq_business_p1_unresolved` — `orchestrate-flow/SKILL.md` taxonomy + `scenario-6-recovery-from-halt.md:20`
  - `no_starterkit_detected` — `orchestrate-flow/SKILL.md:57` (full halt YAML emitted)
  - `module_blocked_by` — `execute-bolts/SKILL.md:519-523` (full halt YAML emitted)
  - `hard_rule_unanchored` — `execute-bolts/SKILL.md:129-133` (full halt YAML emitted) + listed in `handoff-contract.md:390` halted-status list
  - `unit_underspecified` — `handoff-contract.md:360` (listed in halted-status enum)
  - `user_authored_conflict` / `vault_not_found` / `vault_corrupt` / `greenfield_no_bind_context` / `verify_unit_writable` — `handoff-contract.md:446` + `execute-bolts/SKILL.md:965` (referenced but never registered)
- **Fix:** Add these to the canonical enum at `vault-contract.md:569` AND add description blocks per the §halt-protocol type-specific guidance section (lines 585-631). Bump vault-contract version.

#### A1-002: `oq_blocker` listed in enum but has zero hard `type: oq_blocker` emit site
- **Severity:** P1 HIGH
- **Source:** `vault-contract.md:569,587` (enum + description) vs `generate-intent/SKILL.md:238` (only a soft prose claim)
- **Issue:** `oq_blocker` is enum-registered and described as "emitted by `generate-intent` (when generation surfaces a P1 that would block downstream tasks) or by AI consumers reading the vault non-interactively." But generate-intent SKILL.md never explicitly says `→ halt oq_blocker` or `type: oq_blocker`. The prose at line 238 says "additionally emit a `blocker` artifact" without naming the type. Per orchestrate-flow taxonomy comment at line 562, this halt now coexists with `oq_business_p1_unresolved` (the orch-level alias for business P1s) — suggests `oq_blocker` may be dead code OR the rename was never fully propagated to producer.
- **Fix:** Either (a) make generate-intent SKILL.md explicitly emit `type: oq_blocker` with halt YAML template, OR (b) deprecate `oq_blocker` from enum and document the alias `oq_business_p1_unresolved` as canonical. Closes Iter 41 sweep note in `orchestrate-flow/SKILL.md:562`.

#### A1-003: `quality_gate_failed` subtypes `starterkit_metrics_inconsistent` / `pdf_render_failed` / `template_slot_unfilled` not in canonical description block
- **Severity:** P1 HIGH
- **Source:**
  - Emit sites: `orchestrate-flow/SKILL.md:315` (starterkit_metrics_inconsistent); `emit-fsd/SKILL.md:115` (pdf_render_failed); `emit-fsd/SKILL.md:147,195` (template_slot_unfilled); `generate-units/SKILL.md:797` (starterkit_metrics_inconsistent)
  - Canonical description: `vault-contract.md:628` — only mentions the base `quality_gate_failed` type from extract-intelligence Iter 9; says nothing about the 3 Iter 53/54 subtypes
- **Issue:** Iter 53 (starterkit_metrics_inconsistent) and Iter 54 (pdf_render_failed + template_slot_unfilled) extended `quality_gate_failed` with a `subtype:` discriminator field. Consumers must distinguish between extract-intelligence "wave failed quality threshold" vs emit-fsd "pandoc render failed" vs orchestrate-flow "starterkit partial but rules already emitted" — but the description block at line 628 only describes the original extract-intelligence semantic. Consumer dispatch logic will mishandle the subtype.
- **Fix:** Update `vault-contract.md:628` to enumerate subtypes:
  ```
  - `quality_gate_failed` — base type. Subtypes:
    - (no subtype OR omitted): extract-intelligence wave failure (Iter 9 original)
    - `starterkit_metrics_inconsistent` — orchestrate-flow / generate-units Iter 53
    - `pdf_render_failed` — emit-fsd Iter 54
    - `template_slot_unfilled` — emit-fsd Iter 54
  ```

---

### P2 MEDIUM (missing scenario / predictive-check)

#### A2-001: Iter 55 halts `install_failed` and `pkg_mgr_not_found` have no scenario-6 recovery walkthrough
- **Severity:** P2 MEDIUM
- **Source:** `tests/scenarios/scenario-6-recovery-from-halt.md` — grep "install_failed" returns no match; grep "pkg_mgr_not_found" returns no match
- **Issue:** Iter 55 added the install-deps skill with two halt types but did not extend scenario-6. New `--auto` users hitting `pkg_mgr_not_found` on a fresh Linux VM (apt not on PATH) will not find a documented recovery path; they get only the inline `next_action.hint` from the halt envelope.
- **Fix:** Add `## Scenario walkthrough — install_failed / pkg_mgr_not_found (Iter 55)` to scenario-6 — should cover: (a) inspect stderr_tail, (b) retry single tool via `--tools=<failed>`, (c) cross-platform pkg-mgr install path (brew/apt/WSL).

#### A2-002: No `### install-deps preflight checks` section in predictive-checks.md
- **Severity:** P2 MEDIUM
- **Source:** `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` — search "install-deps preflight" returns 0 matches; only references at lines 41/213/220 are *consumer-side* "OR run `/mega-sdd:install-deps` for auto-install (Iter 55+)" hints in scan/emit-fsd checks
- **Issue:** Every other skill has a `### <skill> preflight checks` section in predictive-checks.md (scan-codebase / bind-codebase / execute-bolts / generate-intent / detect-drift / diff-vault / resolve-oq / extract-intelligence / emit-agents-md / emit-fsd / memory). install-deps is the lone exception. This means orchestrate-flow Step 3.5 dispatches install-deps with zero predictive validation — running blind into `pkg_mgr_not_found` on incompatible OS or `install_failed` on missing network. Iter 55 spec §4.2 anti-pattern restored.
- **Fix:** Add `### install-deps preflight checks` section with at minimum:
  - `network_reachable` (curl -fsS https://google.com — fatal: no, predicts_halt: install_failed)
  - `pkg_mgr_detected` (per references/os-detection.md PKG_MGR resolution — fatal: yes, predicts_halt: pkg_mgr_not_found)
  - `tools_param_nonempty` (fatal: yes, no halt; CLI validation)

#### A2-003: Iter 33/40 halts have no `predicts_halt:` coverage (handoff_missing / handoff_type_mismatch / artifact_missing / partial_state_corrupt / predictive_check_failed / model_tier_unknown / routing_outcome_corrupt)
- **Severity:** P2 MEDIUM
- **Source:** `predictive-checks.md` — grep "predicts_halt:" listing at lines 26-245 — none of these 7 halt names appear as values of any check's `predicts_halt:` field
- **Issue:** These halts are infrastructure halts (orchestrate-flow self-emitted on chain envelope failures). They cannot have predictive checks in the strict sense — they emit when consumed handoff/artifact/state state is corrupt. BUT: the audit rubric expects at least one anticipating check. For example, `partial_state_corrupt` could be anticipated by `execute-bolts preflight: test -f partial-state.json && python3 -c "json.load(open('partial-state.json'))"`.
- **Fix:** Add anticipating checks where feasible: `partial_state_loads_cleanly` (execute-bolts only when `--resume`), `routing_outcomes_parseable` (orchestrate-flow self-check). Document `handoff_missing`/`artifact_missing` as "infrastructure halts, not preventable via static preflight; rely on chat_tail_excerpt + re-run-standalone recovery".

#### A2-004: Iter 53/54 quality_gate_failed subtypes have no scenario-6 walkthrough
- **Severity:** P2 MEDIUM
- **Source:** `scenario-6-recovery-from-halt.md` — grep `starterkit_metrics_inconsistent` / `pdf_render_failed` / `template_slot_unfilled` returns 0 matches
- **Issue:** Scenario-6 has the original `quality_gate_failed` walkthrough (extract-intelligence wave, lines 224-273) but does not cover the 3 new subtypes added Iter 53/54. Users hitting `pdf_render_failed` (pandoc/xelatex install issue) get no recovery doc; users hitting `starterkit_metrics_inconsistent` (chain-internal) get no recovery doc.
- **Fix:** Extend scenario-6 §quality_gate_failed walkthrough to fork on `details.subtype` field: (a) wave-based KB (existing), (b) `pdf_render_failed` → install LaTeX engine via install-deps, (c) `template_slot_unfilled` → file bug + retry, (d) `starterkit_metrics_inconsistent` → re-run scan-codebase --force-deep then regenerate units.

#### A2-005: Iter 28 halts have no scenario-6 walkthrough
- **Severity:** P2 MEDIUM
- **Source:** `scenario-6-recovery-from-halt.md` — grep `scope_not_declared_in_prd` / `prd_no_scopes_block_user_rejected_retrofit` / `prd_retrofit_low_confidence` returns 0 matches
- **Issue:** Iter 28 added 3 PRD-scope halts; Iter 41 added them to enum but didn't extend scenario-6. The Iter 49 follow-up sweep added 10 walkthroughs (lines 343+) but skipped these PRD-scope halts.
- **Fix:** Add 1 walkthrough covering all 3 PRD-scope halts (they're related — same scope-resolution flow). Show: scope_not_declared → user picks valid scope from PRD list; prd_no_scopes_block → user retrofits PRD frontmatter; prd_retrofit_low_confidence → user inspects retrofit output + accepts/rejects.

#### A2-006: `drift_framework_mismatch` and `constitution_drift_detected` have no scenario-6 walkthrough
- **Severity:** P2 MEDIUM
- **Source:** `scenario-6-recovery-from-halt.md` — grep returns 0 matches
- **Issue:** Two ALWAYS-STOP halts from detect-drift (Iter 12 and Iter 30) lack recovery walkthroughs. These fire on real production drift scenarios (vault says Laravel, code is now Spring; constitution §B security clause violated by new code).
- **Fix:** Add walkthrough showing: (a) inspect detect-drift report, (b) decide vault-supersede vs code-supersede vs split, (c) re-run binding with corrected vault if needed.

#### A2-007: `dispatch_prompt_too_large` Iter 30/44 walkthrough exists (line 442) but `bolt_repeated_partial_failure`, `bolt_introduces_locked_drift`, `self_assessment_missing` do not
- **Severity:** P2 MEDIUM
- **Source:** `scenario-6-recovery-from-halt.md` — grep returns hits only for dispatch_prompt_too_large + provenance_missing (Iter 49 sweep)
- **Issue:** 3 of execute-bolts Iter 30 halts lack walkthroughs. `bolt_repeated_partial_failure` is high-frequency (3 partial-state cycles); deserves explicit recovery doc.
- **Fix:** Add walkthroughs for these 3 — focus on `bolt_repeated_partial_failure` first (most user-visible).

#### A2-008: Multiple lesser-tier halts have no predictive-check coverage at all
- **Severity:** P2 MEDIUM
- **Source:** `predictive-checks.md` predicts_halt grep — only 9 distinct halt names appear: `dep_missing`, `framework_pack_missing`, `bind_conflict`, `bind_conflict_constitution_violation`, `prd_path_missing`, `invalid_handoff`, `memory_in_use`, `memory_schema_mismatch`, plus "(chain order error)" / "(no halt; ...)" placeholders
- **Issue:** Halt types with NO anticipating check (sample, not exhaustive): `cycle_detected`, `cross_squad_dep_invalid`, `interface_ref_missing`, `cross_squad_ambiguous`, `cross_squad_interface_draft`, `deep_scan_subagent_failed/all_failed/cache_corrupt`, `starterkit_rule_citation_missing`, `framework_pack_cycle`, `framework_pack_unparseable`, `constitution_drift_detected`, `dispatch_prompt_too_large`, `bolt_repeated_partial_failure`, `provenance_missing`, `bolt_introduces_locked_drift`, `self_assessment_missing`, `oq_recommend_citation_invalid`, `routing_outcome_corrupt`, `predictive_check_failed`, `model_tier_unknown`, `pbt_citation_invalid`, `handoff_missing`, `handoff_type_mismatch`, `artifact_missing`, `partial_state_corrupt`, `dedup_ambiguous`, `hard_rule_unparseable`, `hard_rule_violated`, `prd_no_scopes_block_user_rejected_retrofit`, `prd_retrofit_low_confidence`, `quality_gate_failed`, `scope_not_declared_in_prd`, `install_failed`, `pkg_mgr_not_found` — ~33 of 46.
- **Fix:** Many of these are runtime-only (cannot be predicted statically). Acceptable. BUT: triage and add static-feasible checks where possible — e.g., `cycle_detected` could be predicted by quick DAG-cycle scan on existing units/depends_on graph; `cross_squad_interface_draft` could be predicted by quick scan of consumed_interfaces in squad mode.

---

### P3 LOW (wording / format)

#### A3-001: Iter citation inconsistency in description blocks
- **Severity:** P3 LOW
- **Source:** `vault-contract.md` lines 593-631
- **Issue:** Some entries cite version+iter (e.g., line 593 "scan-codebase v2.6.0+"); some cite only iter (line 624 "Iter 41 sweep closure"); some omit version entirely. Inconsistent metadata makes it harder to trace which release introduced which halt.
- **Fix:** Normalize to `<skill> v<X.Y.Z>+, Iter <N>: <one-line description>. Resolution: ...`. Cite plugin version for the iter that added the halt.

#### A3-002: `mode_migrate` lacks dedicated description in §Type-specific guidance
- **Severity:** P3 LOW
- **Source:** `vault-contract.md:569` (enum) + `vault-contract.md:722` (type-specific schema only)
- **Issue:** Most halts have both a description line in lines 587-631 AND a type-specific schema in lines 690+. `mode_migrate` has only the schema; no prose description. Inconsistent with peer halts.
- **Fix:** Add description line: "`mode_migrate` — emitted by `orchestrate-flow` when vault.mode (greenfield/existing) doesn't match CWD signals (.git, package.json). Resolution: update vault.json mode OR re-run with `--detect-mode`."

#### A3-003: `source_skill:` enum includes `install-deps` and `emit-fsd` correctly
- **Severity:** P3 LOW (good — note for completeness)
- **Source:** `vault-contract.md:576` — `source_skill: generate-intent | diff-vault | detect-drift | bind-codebase | scan-codebase | generate-units | execute-bolts | extract-intelligence | resolve-oq | orchestrate-flow | emit-agents-md | emit-fsd | install-deps | memory`
- **Note:** Source-skill enum was correctly extended for Iter 54 (emit-fsd) and Iter 55 (install-deps). No drift here.

#### A3-004: `next_action` field inconsistently formatted across producer emits
- **Severity:** P3 LOW
- **Source:** Compare `orchestrate-flow/SKILL.md:232-259` (uses `next_action: {type: inspect_subskill_logs, hint: "..."}`) vs `install-deps/SKILL.md:132` (uses `details: {tool, install_cmd, ...}` with no `next_action:`) vs `execute-bolts/SKILL.md:473` (uses `next_action: "<prose string>"`)
- **Issue:** Halt envelope `next_action` field appears variously as a structured object `{type, hint}`, a plain string, or omitted entirely. Consumer dispatch (orchestrate-flow halt-displayer) must branch on shape.
- **Fix:** Pin the shape in `vault-contract.md §halt-protocol §Schema`. Recommend: `next_action: {type: <action_id>, hint: "<one-line user-facing>", commands: ["<bash hint>", ...]}` as canonical, with `next_action: "<string>"` as legacy-accepted shorthand.

---

## Coverage matrix

(✓ = present; ✗ = missing; ~ = partial; n/a = not applicable per design)

| Halt type | In enum | Has description | Has scenario-6 | Has predictive-check | Source skill matches | Verdict |
|---|---|---|---|---|---|---|
| oq_blocker | ✓ | ✓ | ✓ (l410) | ✗ | ~ (generate-intent prose-only) | A1-002 |
| diff_conflict | ✓ | ✓ | ✓ (l424) | ✗ | ✓ diff-vault | OK |
| drift_framework_mismatch | ✓ | ✓ | ✗ | ✗ | ✓ detect-drift | A2-006 |
| bind_conflict | ✓ | ✓ (line 693 schema) | ✓ (l159) | ✓ (binding_input_complete) | ✓ bind-codebase | OK |
| dep_missing | ✓ | ✓ | ✗ | ✓ (tree_sitter_present, etc) | ✓ scan-codebase/execute-bolts | OK |
| test_fail | ✓ | ✓ (line 710 schema) | ✗ | ✗ | ✓ execute-bolts | A2 gap |
| cycle_detected | ✓ | ✓ (line 718 schema) | ✗ | ✗ | ✓ generate-units | A2-008 |
| mode_migrate | ✓ | ~ (schema only) | ✗ | ✗ | ✓ orchestrate-flow | A3-002 |
| cross_squad_dep_invalid | ✓ | ✓ (line 728 schema) | ✓ (l489) | ✗ | ✓ generate-units | OK |
| interface_ref_missing | ✓ | ✓ (line 736 schema) | ✗ | ✗ | ✓ generate-units | A2 gap |
| cross_squad_ambiguous | ✓ | ✓ (line 744 schema) | ✗ | ✗ | ✓ generate-units | A2 gap |
| cross_squad_interface_draft | ✓ | ✓ (line 753 schema) | ✗ | ✗ | ✓ execute-bolts | A2 gap |
| deep_scan_subagent_failed | ✓ | ✓ | ✗ | ✗ | ✓ scan-codebase | A2 gap |
| deep_scan_cache_corrupt | ✓ | ✓ | ✗ | ✗ | ✓ scan-codebase | A2 gap |
| deep_scan_subagent_all_failed | ✓ | ✓ | ✗ | ✗ | ✓ scan-codebase | A2 gap |
| starterkit_rule_citation_missing | ✓ | ✓ | ✗ | ✗ | ✓ generate-units | A2 gap |
| bind_conflict_constitution_violation | ✓ | ✓ | ✓ (l468) | ✓ (constitution_file_check) | ✓ bind-codebase | OK |
| framework_pack_missing | ✓ | ✓ | ✗ | ~ (referenced in scan-codebase check at l50) | ✓ bind-codebase | A2 gap |
| framework_pack_cycle | ✓ | ✓ | ✗ | ✗ | ✓ bind-codebase | A2 gap |
| framework_pack_unparseable | ✓ | ✓ | ✗ | ✗ | ✓ bind-codebase | A2 gap |
| constitution_drift_detected | ✓ | ✓ | ✗ | ✗ | ✓ detect-drift | A2-006 |
| memory_in_use | ✓ | ✓ | ✗ | ✓ (concurrent_writer_check) | ✓ memory | A2 gap |
| dispatch_prompt_too_large | ✓ | ✓ | ✓ (l442) | ✗ | ✓ execute-bolts | OK |
| bolt_repeated_partial_failure | ✓ | ✓ | ✗ | ✗ | ✓ execute-bolts | A2-007 |
| provenance_missing | ✓ | ✓ | ✓ (l453) | ✗ | ✓ execute-bolts | OK |
| bolt_introduces_locked_drift | ✓ | ✓ | ✗ | ✗ | ✓ execute-bolts | A2-007 |
| self_assessment_missing | ✓ | ✓ | ✗ | ✗ | ✓ execute-bolts | A2-007 |
| oq_recommend_citation_invalid | ✓ | ✓ | ✗ | ✗ | ✓ bind-codebase | A2 gap |
| routing_outcome_corrupt | ✓ | ✓ | ✗ | ✗ | ✓ orchestrate-flow | A2-003 |
| predictive_check_failed | ✓ | ✓ | ✗ | n/a (self-emit) | ✓ orchestrate-flow | A2-003 |
| invalid_handoff | ✓ | ✓ | ✗ | ✓ (vault_version_parseable) | ✓ orchestrate-flow | A2 gap |
| handoff_type_mismatch | ✓ | ✓ | ✗ | ✗ | ✓ orchestrate-flow | A2-003 |
| model_tier_unknown | ✓ | ✓ | ✗ | ✗ | ✓ orchestrate-flow | A2-003 |
| pbt_citation_invalid | ✓ | ✓ | ✗ | ✗ | ✓ execute-bolts | A2 gap |
| handoff_missing | ✓ | ✓ | ✓ (l347) | ✗ | ✓ orchestrate-flow | OK (after Iter 49) |
| artifact_missing | ✓ | ✓ | ✓ (l369) | ✗ | ✓ orchestrate-flow | OK (after Iter 49) |
| partial_state_corrupt | ✓ | ✓ | ✓ (l390) | ✗ | ✓ execute-bolts | OK (after Iter 49) |
| dedup_ambiguous | ✓ | ✓ | ~ (mentioned in pitfalls, no walkthrough) | ✗ | ✓ generate-units | A2 gap |
| hard_rule_unparseable | ✓ | ✓ | ~ (mentioned at l16) | ✗ | ✓ execute-bolts | A2 gap |
| hard_rule_violated | ✓ | ✓ | ✓ (l36) | ✗ | ✓ execute-bolts | OK |
| memory_schema_mismatch | ✓ | ✓ | ✓ (l508) | ✓ (schema_version_match) | ✓ memory | OK |
| prd_no_scopes_block_user_rejected_retrofit | ✓ | ✓ | ✗ | ✗ | ✓ generate-intent | A2-005 |
| prd_path_missing | ✓ | ✓ | ✗ | ✓ (new_source_resolves_for_diff) | ✓ diff-vault | A2 gap (scenario) |
| prd_retrofit_low_confidence | ✓ | ✓ | ✗ | ✗ | ✓ generate-intent | A2-005 |
| quality_gate_failed (base) | ✓ | ✓ | ✓ (l224) | ✗ | ✓ extract-intelligence | OK |
| quality_gate_failed:starterkit_metrics_inconsistent | ✗ (subtype undocumented) | ✗ | ✗ | ✗ | ✓ orchestrate-flow / generate-units | A1-003 + A2-004 |
| quality_gate_failed:pdf_render_failed | ✗ (subtype undocumented) | ✗ | ✗ | ✗ | ✓ emit-fsd | A1-003 + A2-004 |
| quality_gate_failed:template_slot_unfilled | ✗ (subtype undocumented) | ✗ | ✗ | ✗ | ✓ emit-fsd | A1-003 + A2-004 |
| scope_not_declared_in_prd | ✓ | ✓ | ✗ | ✗ | ✓ generate-intent | A2-005 |
| install_failed | ✓ | ✓ | ✗ | ✗ (no install-deps section) | ✓ install-deps | A2-001 + A2-002 |
| pkg_mgr_not_found | ✓ | ✓ | ✗ | ✗ (no install-deps section) | ✓ install-deps | A2-001 + A2-002 |
| **ORPHAN: oq_tech_missing_mode** | ✗ | ✗ | ✗ | ✗ | generate-intent (emit at SKILL.md:689) | A1-001 |
| **ORPHAN: oq_recommend_underspecified** | ✗ | ✗ | ✗ | ✗ | generate-intent + bind-codebase | A1-001 |
| **ORPHAN: oq_scan_missing_query** | ✗ | ✗ | ✗ | ✗ | generate-intent | A1-001 |
| **ORPHAN: oq_business_p1_unresolved** | ✗ | ✗ | ✓ (l20 table) | ✗ | orchestrate-flow (alias claim) | A1-001 |
| **ORPHAN: no_starterkit_detected** | ✗ | ✗ | ✗ | ✗ | orchestrate-flow (emit at SKILL.md:57) | A1-001 |
| **ORPHAN: module_blocked_by** | ✗ | ✗ | ✓ (l18 table) | ✗ | execute-bolts (emit at SKILL.md:519) | A1-001 |
| **ORPHAN: hard_rule_unanchored** | ✗ | ✗ | ✗ | ✗ | execute-bolts (emit at SKILL.md:133) | A1-001 |
| **ORPHAN: unit_underspecified** | ✗ | ✗ | ✗ | ✗ | generate-units (handoff-contract:360) | A1-001 |
| **ORPHAN: verify_unit_writable** | ✗ | ✗ | ✗ | ✗ | execute-bolts (l965) | A1-001 |

---

## Recommendations (ranked)

1. **Fix A1-001 first** — 9 orphan halt types in the wild. Consumers will reject these as `invalid_handoff` per Iter 33 schema validation. This is the single most-likely-to-cause-silent-failure finding.
2. **Fix A1-003** — quality_gate_failed subtype dispatch is broken without canonical subtype enum.
3. **Fix A2-002** — install-deps has zero predictive-check coverage; restore the Iter 33 UX guarantee before more users hit cold halts.
4. **Fix A1-002** — disambiguate `oq_blocker` vs `oq_business_p1_unresolved` (deprecate one, document the other).
5. **Fix A2-001 + A2-004 + A2-005 + A2-006 + A2-007** — extend scenario-6 (Iter 49 sweep closed only 10 of ~25 gap walkthroughs; another sweep needed).
6. **Fix A3-001 + A3-002 + A3-004** — wording normalization pass on vault-contract halt descriptions.
