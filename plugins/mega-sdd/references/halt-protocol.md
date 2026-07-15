# Halt Protocol — Canonical Cross-Skill Halt Registry

> Single source of truth for the halt machinery: **§halt-escalation-discipline** (C1/C2/C3 categories + self-resolve protocol) and **§halt-protocol** (unified `blocker` envelope + canonical halt registry + `quality_gate_failed` subtypes). Relocated **verbatim** from `skills/generate-intent/references/vault-contract.md` (which keeps a tombstone pointer). Cite as `plugins/mega-sdd/references/halt-protocol.md §halt-protocol` / `§halt-escalation-discipline`.

## Contents

- §halt-escalation-discipline (C1/C2/C3 anti-erosion gate)
- §halt-protocol — Unified `blocker` envelope + canonical halt registry + `quality_gate_failed` subtypes

## §halt-escalation-discipline (anti-erosion gate)

Halts are classified into THREE operational categories. Categorization is per-halt and authoritative (lives in this doc + per-halt description below). See `docs/superpowers/audits/2026-05-27-halt-escalation-classification.md` and `docs/superpowers/audits/2026-05-27-c1-collapse-attestation.md` for full classification + per-halt reasoning + reviewer attestation.

### Three categories

| Cat | Behavior | When applicable |
|---|---|---|
| **C1 — Self-resolve** | Skill fixes own output, emits `halt_self_resolved` telemetry + chat one-liner, NEVER halts. | Skill emitted bad output (missing field, parse error, citation typo) AND can re-derive from in-context info. NO ground-truth fabrication. NO silent failure hiding (every fix logged). |
| **C2 — Business gate** | Halt + PROPOSE recommendation + sign-off. No raw "what should I do?" questions. | Resolution needs domain/stakeholder intent (scope choice, conflict resolution, business rule). Skill emits halt envelope with `recommendation:` field populated. |
| **C3 — Grounding gate** | Halt — enforce via [HOOK-VALIDATE] slice (deterministic validator), not prose. | Continuing would require hallucinating ground truth (vault↔code conflict, traceability ID drop). Enforced by hook + state file, not skill body text. |

### C1 self-resolve protocol

When a skill detects a C1 condition during execution:

1. **Apply the documented fix** (per the halt's `C1 SELF-RESOLVE` description in this file).
2. **Emit chat one-liner:** `[self-resolved] <halt_type>: <fix_applied>` (single line, not a halt envelope).
3. **Emit telemetry event:**
   ```json
   {
     "event_type": "halt_self_resolved",
     "payload": {
       "halt_type": "<halt name>",
       "fix_applied": "<short description>",
       "original_emit_site": "<skill_name>:<step_id>",
       "logged_at_chat": true
     }
   }
   ```
4. **Continue execution.** Do NOT emit a `blocker:` envelope. Do NOT pause the chain. Do NOT prompt the human.

### Escalation paths from C1 → C2

A C1 halt MUST escalate to C2 (with proposal) when:
- Resolution would require ground truth the model lacks (e.g., re-picking from empty inventory)
- Documented retry budget exhausted (e.g., `invalid_handoff` after 2 producer re-invokes)
- The fix would silently hide a class of failure the human should know about (catch-all safety)

When escalating, emit standard C2 halt envelope WITH the C1 attempt history in `details.retry_attempts: [...]` for forensics.

### C2 propose-and-confirm discipline (future candidate — not yet active)

Every C2 halt envelope MUST include a `recommendation:` field with the skill's best-effort guess + rationale. The halt should not pose a raw question. Format:

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

Implementation deferred to Phase D after Phase A real-run proof. Current C2 halts emit options but rarely propose; Phase D doc-only pass formalizes this.

### C3 enforcement via [HOOK-VALIDATE]

C3 halts are enforced by `plugins/mega-sdd/scripts/validate-handoff-*.sh` validators + `PreToolUse` hooks per `plugins/mega-sdd/references/fork-a-recovery-map.md`. Skill bodies declaring C3 halts can mention them as design vocabulary, but the actual enforcement is the hook layer. The binding→units OQ-ID slice is hook-enforced today; CONFLICT-IDs / Hard Rules / vault→binding / units→bolts follow the same pattern.

### Backward compatibility

Halts not yet classified (or in older skill bodies) default to legacy behavior (ALWAYS STOP). Phase A formalizes 6 already-soft halts as C1. Phase B (separate iter, contingent on Phase A real-run proof + attestation audit sign-off) expands to remaining 22 C1 candidates.

## §halt-protocol — Unified `blocker` envelope (v0.14, extended v1.1)

When a skill running in `--auto` mode hits something that requires human judgment (unresolved P1 OQ blocking downstream work, diff-vault conflict, framework mismatch), it emits a structured YAML artifact called a **blocker**. The orchestrator (`/mega-sdd:orchestrate-flow`) catches blockers, pauses the chain, and surfaces the artifact in chat for the user to act on.

The envelope is uniform across types so a single consumer can handle all of them.

### Schema

```yaml
blocker:
  type: oq_blocker | diff_conflict | drift_framework_mismatch | bind_conflict | dep_missing | test_fail | cycle_detected | mode_migrate | cross_squad_dep_invalid | interface_ref_missing | cross_squad_ambiguous | cross_squad_interface_draft | deep_scan_subagent_failed | deep_scan_cache_corrupt | deep_scan_subagent_all_failed | starterkit_rule_citation_missing | bind_conflict_constitution_violation | framework_pack_missing | framework_pack_cycle | framework_pack_unparseable | constitution_drift_detected | memory_in_use | dispatch_prompt_too_large | bolt_repeated_partial_failure | provenance_missing | bolt_introduces_locked_drift | self_assessment_missing | oq_recommend_citation_invalid | routing_outcome_corrupt | predictive_check_failed | invalid_handoff | handoff_type_mismatch | model_tier_unknown | pbt_citation_invalid | handoff_missing | artifact_missing | partial_state_corrupt | dedup_ambiguous | hard_rule_unparseable | hard_rule_violated | memory_schema_mismatch | prd_no_scopes_block_user_rejected_retrofit | prd_path_missing | prd_retrofit_low_confidence | quality_gate_failed | scope_not_declared_in_prd | install_failed | pkg_mgr_not_found | oq_tech_missing_mode | oq_recommend_underspecified | oq_scan_missing_query | oq_business_p1_unresolved | no_starterkit_detected | module_blocked_by | hard_rule_unanchored | unit_underspecified | verify_unit_writable
  tag: <stable identifier — OQ-AR-1, D-007, etc.>
  priority: P1 | P2 | P3 | n/a
  context: "<what's blocked, e.g. 'Implementing F-U-001 backend' or 'Applying diff-vault Step 6'>"
  resolver_owner: "<name or role, e.g. 'Mike Patel (Eng Lead)'>"
  resolver_route: "<where to find them, e.g. 'ask in #timeoff-team'>"
  vault_version: "<current vault version, e.g. '1.1'>"
  source_skill: generate-intent | diff-vault | detect-drift | bind-codebase | scan-codebase | generate-units | execute-bolts | extract-intelligence | resolve-oq | orchestrate-flow | emit-agents-md | emit-fsd | install-deps | memory
  # type-specific fields below
  conflict_old: "<vault state>"            # diff_conflict only
  conflict_new: "<new PRD state>"          # diff_conflict only
  options: ["supersede", "keep_vault", "capture_both"]  # diff_conflict only
  detected_framework: "<e.g. 'Java/Spring'>"  # drift_framework_mismatch only
  expected_framework: "<e.g. 'PHP/Laravel'>"  # drift_framework_mismatch only
```

### Canonical `next_action` field shape

The `next_action` field in halt envelope is documented per-producer with varying shapes (object `{type, hint}`, plain string, or omitted). Consumer dispatch must branch on shape. The canonical shape is pinned:

```yaml
# CANONICAL (preferred for new halts):
next_action:
  type: <action_id>                            # enum (see below)
  hint: "<one-line user-facing instruction>"   # required
  commands: ["<bash command>", ...]            # optional; ordered list of recovery commands

# LEGACY (accepted for backward compat, pre-v0.15):
next_action: "<one-line prose string>"         # plain string form

# OMITTED (NOT accepted):
# next_action: <missing>                        → halt invalid_handoff during validation
```

`type` enum (extensible per skill):

- `inspect_subskill_logs` — read chat_tail_excerpt + investigate sub-skill output
- `rename_and_retry` — rename corrupt file to .corrupt-<timestamp> + re-run
- `re_run_producer` — re-run the producer skill standalone to reproduce
- `edit_skill_template` — fix skill body template emission (producer bug)
- `user_install_dep` — user installs missing native binary
- `user_resolve_oq` — user runs `/mega-sdd:resolve-oq` interactively
- `user_review` — user inspects artifact + decides
- `invoke_skill` — orchestrator auto-invokes recovery skill
- `chain_complete` — terminal; no further action
- `file_plugin_bug` — internal bug; user files at scm.bankmegadev.com/ai-rnd/mega-sdd/issues
- `log_and_continue` — soft halt; orchestrator logs + proceeds
- `manual_review` — user reviews state manually (no auto-action)

Consumer dispatch (ANY halt-displaying surface — orchestrate-flow is the chain-path displayer; a skill halting on a STANDALONE run renders the same way):

0. **Keterangan block FIRST (MANDATORY — the keterangan contract, `references/output-language.md §Prompt surfaces`).** BEFORE printing the envelope YAML, render a plain-language block in Tier-2 narration (Indonesian-mix by default):
   - **Apa yang ditanya:** resolve `tag` to the ACTUAL text — quote the OQ question / CONFLICT claim pair / decision at stake verbatim from the source artifact (the vault doc, `binding.md`, the diff report). A bare `OQ-AR-1` is never a question.
   - **Kenapa berhenti:** one line — which phase halted and why this blocks it.
   - **Pilihan lo:** when the envelope carries choices (`options`, `suggested_action`, an action menu), list each as `CODE — keterangan konsekuensi` (Tier-1 code stays English; the description says what choosing it DOES). Mark the recommended default with its one-line reason when one exists.
   - Then print the envelope YAML below the block (the YAML is the machine record; the block is for the human).
1. Read `next_action.type` if present → format hint per type semantics (e.g., wrap commands in code fence)
2. Else read `next_action.hint` if it's a string → display as plain text
3. Else (no next_action) → emit `invalid_handoff` halt at validation gate

**Backward compatibility:** all pre-v0.15 halt emit sites work unchanged. The canonical shape is RECOMMENDED for new halts but not enforced — consumers fall back to legacy string-only form.

### Type-specific guidance

**`oq_blocker`** — emitted by `generate-intent` (when generation surfaces a P1 that would block downstream tasks) or by AI consumers reading the vault non-interactively. The `tag` is the OQ identifier. `priority` is always `P1` (lower priorities don't halt).

**`diff_conflict`** — emitted by `diff-vault` Step 5 when a Resolved-OQ conflict or Decision conflict requires stakeholder input. `tag` is the OQ or ADR ID. `priority` is `n/a` (conflicts aren't priority-tagged). `conflict_old`, `conflict_new`, `options` are required.

**`drift_framework_mismatch`** — emitted by `detect-drift` Step 1.5 when the vault implies one framework but the codebase is another. `tag` is `n/a`. `priority` is `n/a`. `detected_framework` and `expected_framework` are required.

- `deep_scan_subagent_failed` — scan-codebase: a deep-scan slice subagent (auth/authz/ui-ux/libs/reuse) failed once. Soft halt: auto-retried; on second failure emits partial starterkit-context.yaml with `partial: true`. Pipeline continues (warn-only).
- `deep_scan_cache_corrupt` — scan-codebase: starterkit-context.yaml exists but fails YAML parse. Soft halt: cache auto-invalidated; subagents re-dispatched. Transparent to user.
- `deep_scan_subagent_all_failed` — scan-codebase: ALL 5 deep-scan slice subagents failed (likely API outage). ALWAYS STOP: user re-runs scan-codebase later. Existing starterkit-context.yaml (if any) preserved untouched.
- `starterkit_rule_citation_missing` — generate-units: a starterkit-derived Hard Rule lacks `Citation: starterkit-context.yaml §<path>` field. ALWAYS STOP: user must edit unit to add citation, then re-run Step 12.5 polished-prompt render pass.
- `bind_conflict_constitution_violation` — bind-codebase: claim conflicts with constitution.md security clause. ALWAYS STOP. Resolution: review constitution clauses + reject/accept conflict.
- `framework_pack_missing` — bind-codebase: framework convention pack referenced but file absent. ALWAYS STOP. Resolution: create pack or remove reference.
- `framework_pack_cycle` — bind-codebase: pack inheritance has cycle (A extends B extends A). ALWAYS STOP.
- `framework_pack_unparseable` — bind-codebase: pack file fails YAML/markdown parse. ALWAYS STOP.
- `constitution_drift_detected` — detect-drift: §B Security or §F Compliance constitution clause drift detected in code. ALWAYS STOP.
- `drift_framework_mismatch` — detect-drift: scanned code framework differs from vault framework. ALWAYS STOP.
- `diff_conflict` — diff-vault: Resolved-OQ or Decision conflict requires stakeholder input. ALWAYS STOP (user resolves via diff-vault interactive walk). Emitted by `diff-vault`.
- `memory_in_use` — memory: file lock collision; concurrent writer holds lock. **C1 SELF-RESOLVE:** retry budget extended to 10 attempts with exponential backoff (250ms → 500ms → 1s → 2s → 4s → 8s → 8s → 8s → 8s → 8s, total ~40s). If still locked after 10x → log + skip memory update (memory writes are advisory; chain proceeds). Emits `halt_self_resolved` telemetry event with `fix_applied: "retry_exhausted_memory_skipped"`. Human visible via chat one-liner `[self-resolved] memory_in_use: skipped after 10 retries`. NEVER halts the chain.
- `dispatch_prompt_too_large` — execute-bolts: assembled bolt dispatch prompt exceeds 10KB hard cap. ALWAYS STOP. Resolution: re-tier context.
- `bolt_repeated_partial_failure` — execute-bolts: bolt failed 3 partial-state recovery cycles. ALWAYS STOP. Resolution: review unit spec.
- `provenance_missing` — execute-bolts: bolt modified file lacks provenance trailer. ALWAYS STOP.
- `bolt_introduces_locked_drift` — execute-bolts: bolt drift hits a LOCKED entity. ALWAYS STOP (eligible for propose-and-confirm override).
- `self_assessment_missing` — execute-bolts: bolt-report.md lacks self-assessment section. ALWAYS STOP.
- `dep_missing` — scan-codebase: required binary (tree-sitter when --engine=tree-sitter forced) not found. ALWAYS STOP.
- `oq_recommend_citation_invalid` — generate-intent: OQ recommendation cites non-existent KB section. ALWAYS STOP.
- `mode_migrate` — orchestrate-flow: vault.json `mode` field (greenfield | existing) doesn't match CWD signals (.git present, package.json present, etc.). **C1 SELF-RESOLVE:** re-detect from CWD signals deterministically (.git present + composer.json/package.json/etc. → `existing`; absence → `greenfield`); update `vault.json.mode`; log change to chat. Emits `halt_self_resolved` telemetry with `fix_applied: "mode_redetected: <old> → <new>"`. NEVER halts. User can override by passing explicit `--mode=<value>` flag on next chain invocation. CWD signals are ground truth — no fabrication risk.
- `routing_outcome_corrupt` — orchestrate-flow: routing-outcomes.md fails parse. **C1 SELF-RESOLVE (HOOK-LAYER ENFORCED via SessionStart):** at session start, hook checks `<cwd>/.mega-sdd/memory/routing-outcomes.md` for UTF-8 validity + schema header presence (`# Routing Outcomes` marker in first 200 chars). If corrupt → rename to `.corrupt-<ISO8601>`; emit `halt_self_resolved` telemetry with `corruption_reason` (`non-utf8-binary` or `missing_schema_header`); chain proceeds with default routing. NEVER halts.
- `predictive_check_failed` — orchestrate-flow: predictive preflight check marked `fatal: yes` failed. ALWAYS STOP. Resolution: user fixes precondition (install dep / add framework pack / etc.) per `next_action.hint`; re-run chain.
- `invalid_handoff` — orchestrate-flow: handoff YAML from sub-skill fails schema validation (missing REQUIRED field, or CONDITIONAL field missing when condition met, or YAML parse error). **C1 SELF-RESOLVE (HOOK-LAYER ENFORCED via Stop+PreToolUse):** at turn end, Stop hook scans transcript for last assistant message; if it contains `handoff:` block, invokes `plugins/mega-sdd/scripts/validate-handoff-yaml.sh` which parses + validates against this schema and writes `<cwd>/.mega-sdd/.handoff-validation-state.json` (current-truth, overwrite-not-append). PreToolUse Skill matcher `mega-sdd:*` (excluding `mega-sdd:using-mega-sdd` anchor) reads that state — if status=FAIL, blocks the next mega-sdd skill invocation with the validator's reason. Retry counter tracks repeated failures of same skill+halt: 1st failure = self-resolve with "re-invoke producer" recommendation; 2nd failure = escalate to C2 user_review. Producer skill author still fixes handoff template per handoff-contract.md schema for permanent fix; hook is the enforcement layer. NEVER halts the chain on first fail; blocks next-skill consumption deterministically.
- `handoff_type_mismatch` — orchestrate-flow: handoff YAML field type doesn't match TYPE annotation in handoff-contract.md schema. ALWAYS STOP. Resolution: producer skill author fixes type emission per handoff-contract.md TYPE annotation; re-run chain.
- `model_tier_unknown` — orchestrate-flow: model-tier override references a role not in plugins/mega-sdd/references/model-tiers.md catalog. **C1 SELF-RESOLVE (formalizing pre-existing SOFT semantics):** log + ignore override; chain proceeds with catalog default for unknown roles. Emits `halt_self_resolved` telemetry with `fix_applied: "unknown_role_catalog_default_used"`. Forward-compat for future role additions. NEVER halts.
- `pbt_citation_invalid` — execute-bolts: a PBT property block declares `Cites: §Decision-D-NNN` but the cited ADR ID does not exist in the bound vault `decisions/` directory. ALWAYS STOP. Resolution: fix the citation in the unit's PBT block (or remove the property if the underlying decision was rescinded), then re-run the bolt.
- `handoff_missing` — orchestrate-flow: sub-skill chat output contains no parseable `handoff:` YAML block (skills emit handoff inline in chat, not to a file). ALWAYS STOP. Resolution: inspect sub-skill chat output (`response_tail` in the validator state shows the last 300 chars; also fires on multiple `handoff:` blocks with conflicting `emitted_by`) for crash logs / parse errors / OS-level failures; re-run sub-skill standalone to reproduce; report as skill-author bug if reproducible.
- `artifact_missing` — orchestrate-flow: handoff YAML lists `artifacts: [paths]` and one or more paths fail existence check (`test -f` for files, `test -d` for directories). ALWAYS STOP. Resolution: re-run producer skill standalone to confirm artifacts actually written; inspect producer chat for mid-write crash logs.
- `partial_state_corrupt` — execute-bolts: `--resume` mode loaded `<vault>/bolts/U-XXX/partial-state.json` (canonical path per execute-bolts §Partial-state contract) and JSON parse failed. **C1 SELF-RESOLVE (HOOK-LAYER ENFORCED via SessionStart):** at session start, hook scans `<cwd>/.mega-sdd/vaults/*-bound/bolts/U-*/partial-state.json`; any file failing JSON parse is renamed to `partial-state.json.corrupt-<ISO8601>` (forensics preserved); next `--resume` invocation restarts fresh from unit spec. Emits `halt_self_resolved` telemetry with full payload (`unit_id`, `original_path`, `corrupt_path`). NEVER halts.
- `dedup_ambiguous` — generate-units: dedupe step finds multiple existing units that could match a new claim (target_files overlap >threshold). ALWAYS STOP. Resolution: user picks the canonical unit OR confirms creating a new one. Previously emitted but missing from canonical halt registry —
- `hard_rule_unparseable` — generate-units: a unit's `## Hard Rules` block contains ast-grep YAML that fails parse OR an ANCHOR reference that cannot be resolved. ALWAYS STOP. Resolution: user fixes the unit's Hard Rules block syntax.
- `hard_rule_violated` — execute-bolts: the post-flight scan of the ALREADY-COMMITTED bolt found a Hard Rule violation (detect-after — the implementer committed before the scan). ALWAYS STOP (no auto-retry). Resolution: fix forward OR `git revert` the flagged bolt commit, then re-run the post-flight scan; the B1 gate blocks every further execute-bolts until a passing `postflight.json` is recorded.
- `memory_schema_mismatch` — memory subsystem: persisted memory file schema_version differs from current code's expected schema. ALWAYS STOP (presents migration prompt). Resolution: user opts in to migration via `/mega-sdd:memory migrate`.
- `prd_no_scopes_block_user_rejected_retrofit` — generate-intent: PRD lacks `scopes:` frontmatter AND user rejected AI retrofit AND chose cancel. ALWAYS STOP. Resolution: user manually retrofits PRD OR re-runs with single-scope fallback.
- `prd_path_missing` — diff-vault: `vault.json.prd_path_at_generation` points to non-existent PRD file. ALWAYS STOP. Resolution: user restores the PRD at the recorded path OR regenerates the vault with the current PRD.
- `prd_retrofit_low_confidence` — generate-intent: AI retrofit subagent returned `overall_confidence: LOW`. ALWAYS STOP. Resolution: user reviews and accepts anyway / chooses single-scope fallback / cancels.
- `quality_gate_failed` — extract-intelligence: a wave's quality-gate threshold (citation density / hallucination floor / canonicalization completeness) is not met. ALWAYS STOP. Resolution: user reviews wave output and either accepts (with QA notes recorded) OR re-runs wave with adjusted prompt.
- `scope_not_declared_in_prd` — generate-intent: `--scope=<id>` flag references a scope ID that's not in the PRD's `scopes:` frontmatter block. ALWAYS STOP. Resolution: user picks a valid scope from PRD's declared list OR cancels.
- `install_failed` — install-deps: install command exited non-zero OR `verify_cmd` failed post-install. ALWAYS STOP. Details `{tool, install_cmd, verify_cmd, exit_code, stderr_tail (last 500 chars), subtype: install_command_failed | verify_after_install_failed}`. Resolution: inspect stderr_tail, fix root cause (PATH refresh / repo signing / network), re-run `/mega-sdd:install-deps --tools=<failed-tool>` to retry single tool. Source skill: `install-deps`.
- `pkg_mgr_not_found` — install-deps: no compatible package manager detected for OS (PKG_MGR=`none` AND no cross-platform fallbacks like cargo/npm/go on PATH). ALWAYS STOP. Details `{os, distro, attempted_pkg_mgrs, fallbacks_attempted}`. Resolution: install brew (macOS) / verify apt is on PATH (Linux) / install WSL Ubuntu (Windows native) → re-run `/mega-sdd:install-deps`. Source skill: `install-deps`.

#### Additional canonical halts

These halt types are emitted by producers as `→ halt <name>` or `type: <name>` in skill bodies and are part of the canonical enum (orchestrate-flow schema validation rejects undeclared types as `invalid_handoff`).

- `oq_tech_missing_mode` — generate-intent: PRD declares technical OQ but `resolution_mode` field missing on the OQ entry (can't classify as `tech / scan` vs `tech / recommend`). ALWAYS STOP. Resolution: user adds `resolution_mode: scan` or `resolution_mode: recommend` to the OQ entry; re-run generate-intent. Source skill: `generate-intent`. *(Field grammar is the §Updated OQ schema — `resolution_mode`, not the pre-v-fix `mode`.)*

- `oq_recommend_underspecified` — generate-intent / bind-codebase: an OQ marked `resolution_mode: recommend` lacks one or more required fields (`recommendation`, `rationale`, `scan_citations` ≥1, `fallback_if_wrong`). ALWAYS STOP. Details `{oq_id, missing_fields}`. Resolution: user fills missing fields in OQ entry per `vault-contract.md §Tech-OQ Recommendations schema`. Source skill: `generate-intent` (Mode B Q&A) or `bind-codebase` (Tech-OQ auto-resolution).

- `oq_scan_missing_query` — generate-intent: an OQ marked `resolution_mode: scan` lacks the `scan_query` field that tells `bind-codebase` Tech-OQ auto-resolver what to grep for. ALWAYS STOP. Details `{oq_id}`. Resolution: user adds `scan_query: codebase-map §<section>` or `scan_query: <file-pattern>` to the OQ entry. Source skill: `generate-intent`.

- `oq_business_p1_unresolved` — orchestrate-flow: a P1 business OQ blocks downstream pipeline; chain pauses until user resolves via `/mega-sdd:resolve-oq`. ALWAYS STOP. Details `{oq_id, priority: P1, category: business, blocked_units}`. Resolution: user answers OQ interactively; vault.json updated; chain resumes. Source skill: `orchestrate-flow` (re-emits from generate-intent's prose claim). **Deprecation note:** older skill bodies may emit `oq_blocker` (legacy name); both are accepted during transition. New code should use `oq_business_p1_unresolved` as canonical name.

- `no_starterkit_detected` — orchestrate-flow: starterkit-first mode default but no framework manifest detected (no composer.json / package.json / Gemfile / etc.) AND user did NOT pass `--greenfield` flag. ALWAYS STOP. Details `{cwd, detected_manifests, suggestions}`. Resolution: user picks (a) scaffold starterkit, (b) re-run with `--greenfield`, or (c) cancel. Source skill: `orchestrate-flow`.

- `module_blocked_by` — execute-bolts: bolt invocation blocked because prerequisite module hasn't completed yet (module-graph dependency). ALWAYS STOP. Details `{unit_id, blocking_module_id, blocked_status}`. Resolution: user runs prerequisite module first OR adjusts module dependency graph in `vault/_meta/modules.yaml`. Source skill: `execute-bolts`.

- `hard_rule_unanchored` — execute-bolts: a unit's `## Hard Rules` block references an ANCHOR (file path / function signature) that cannot be resolved against the current codebase-map. ALWAYS STOP. Details `{unit_id, rule, missing_anchor}`. Resolution: user fixes anchor reference (rename to current symbol) OR removes obsolete rule. Source skill: `execute-bolts`.

- `unit_underspecified` — generate-units: a generated unit lacks one or more required spec fields (`target_files`, `acceptance_test`, `depends_on` graph) preventing bolt dispatch. ALWAYS STOP. Details `{unit_id, missing_fields}`. Resolution: user fills missing fields OR re-runs generate-units with `--strict` for stricter generation. Source skill: `generate-units`.

- `verify_unit_writable` — execute-bolts: a `task_type: verify` unit has non-empty `target_files` with operation ∈ {create, modify, delete} (verify units should not write code). **C1 SELF-RESOLVE (HOOK-LAYER DETECTION via SessionStart, DISPATCH-LAYER AUTO-CLEAR in execute-bolts):** at session start, hook scans `<cwd>/.mega-sdd/vaults/*-bound/units/U-*.md` AND `<cwd>/.mega-sdd/vaults/*-bound/units/U-*/unit.md` (both layouts). For each `task_type: verify` unit with forbidden ops → emit `halt_self_resolved` telemetry (`unit_id`, `unit_path`, `forbidden_operations`) + chat notice in anchor injection. On-disk unit NOT modified (preserves bad spec for human review). Dispatch-time auto-clear is execute-bolts's responsibility (separate code path). Detection-only at SessionStart means the warning re-fires on every session until human fixes the unit — intentional visibility. NEVER halts. Source skill: `execute-bolts`.

The following one-liners were absorbed (verbatim) from `skills/orchestrate-flow/references/halt-taxonomy.md`, which now carries classification names only:

- `secret_in_code` — execute-bolts (L0 gate): a committed secret was detected; user rotates it + purges it from history. ALWAYS STOP.
- `sast_critical_finding` — execute-bolts (L0 gate): a Critical SAST finding; user fixes before the panel. ALWAYS STOP.
- `dep_not_found` — execute-bolts (L0 gate): a newly-added dependency does not resolve in its registry; user corrects the manifest. ALWAYS STOP.
- `review_critical_unresolved` — execute-bolts: the review panel's Critical findings (or a still-❌ spec lens — an unmet requirement carries no severity grade) survived the retry cap; user resolves them. ALWAYS STOP.
- `batch_suite_red` — execute-bolts: the batch-completion FULL suite ended RED; user fixes the failing test(s) then re-runs the suite. ALWAYS STOP.
- `batch_suite_gate_missing` — execute-bolts: no green `_batch-suite.json` covers the newest code commit (a bolt OR an out-of-band edit); user runs the suite via `run-full-suite.sh`. ALWAYS STOP.
- `postflight_evidence_missing` — execute-bolts: a committed Hard-rule bolt has no passing `postflight.json`; user runs the post-flight scan via `run-postflight-scan.sh`. ALWAYS STOP.
- `whitelist_violation` — execute-bolts: a bolt commit touched files outside the unit's `target_files` ∪ sanctioned extras; user reverts/fixes the scope escape. ALWAYS STOP.
- `commit_rejected_by_hook` — execute-bolts: the repo's own commit hook (pre-commit/husky/lefthook) or required GPG signing rejected the bolt commit; user fixes the hook finding (never `--no-verify`). ALWAYS STOP.
- `scope_creep_detected` — execute-bolts: a bolt exceeded its declared scope; user reviews the deviation. ALWAYS STOP.
- `bolt_artifacts_missing` — execute-bolts: a `completed` unit emitted no `bolts/U-XXX/bolt-report.md`; structural silent-failure closure, user re-runs. ALWAYS STOP.
- `hard_rule_mixed_grammar` — execute-bolts: a unit's `## Hard rules` mixes v1 (bulleted) + v2 (YAML) grammar; user picks one grammar. ALWAYS STOP.
- `convergence_max_reached` — orchestrate-flow: convergence loop hit `--max-cycles`. User reviews cycle history (envelope in the convergence-loops reference). ALWAYS STOP.
- `phase_stuck` — factory-line: a phase failed to reach a green checkpoint within the retry cap (default 3); the loop stops and a human must resolve the underlying blocker before re-running. (Auto-looped while cycle-eligible up to the cap; becomes always-stop at the cap.)
- `anti_spin` — factory-line: a phase re-ran with an identical unresolved set (no progress); the loop stops to avoid spinning, human resolution required. ALWAYS STOP.

#### `quality_gate_failed` subtypes

The `quality_gate_failed` halt carries a `subtype:` discriminator. Canonical subtype enum:

`quality_gate_failed` subtypes:
- *(omitted OR `wave_quality_threshold_unmet`)* — extract-intelligence: wave-based KB extraction quality threshold (citation density / hallucination floor / canonicalization completeness) not met. Resolution: user reviews wave output + accepts (with QA notes) OR re-runs wave with adjusted prompt.
- `starterkit_metrics_inconsistent` — orchestrate-flow: generate-units handoff reports `units_with_starterkit_rules > 0` but `starterkit-context.yaml` flags `partial: true` (rules pulled from incomplete framework slice may cite missing conventions). Resolution: re-run `scan-codebase` (since the failed-slice fix, a plain re-run re-dispatches failed slices — they carry no per_slice cache signature; `--no-cache` is the belt-and-braces option that re-dispatches everything; `--force-deep` is only needed when a LOW-confidence trigger skipped deep-scan entirely) then regenerate units.
- `pdf_render_failed` — emit-fsd: pandoc exited non-zero during PDF render in §Step 5.3. Details include `pandoc_stderr_tail` (last 500 chars). Resolution: inspect stderr, fix LaTeX engine config (typically install tectonic via `/mega-sdd:install-deps`), re-run emit-fsd.
- `template_slot_unfilled` — emit-fsd: an FSD-template slot marker `{{slot_name}}` remained unfilled in `FSD.md` output (internal bug — section-mapping.md missing extraction rule for the slot). Resolution: file plugin bug; meanwhile run emit-fsd with `--sections=<subset>` to skip the affected section.
- `replan_budget_exceeded` — anti-recursive guard: a task's re-plan count exceeded `max_replan_count` cap (default 2; configurable). Details `{task_id, max_replan_count, actual_replan_count, trigger_history: [<closed-enum triggers per RULE 1>]}`. Resolution: user reviews trigger history; if hitting same trigger repeatedly, root-cause the underlying issue (don't just raise the cap); if scope grew beyond original task, restart task with corrected scope.
- `revalidate_budget_exceeded` — anti-recursive guard: a task's re-validate count exceeded `max_revalidate_count` cap (default 3). Details `{task_id, max_revalidate_count, actual_revalidate_count}`. Resolution: validators are LEAF NODES — repeated validation failure means root issue is in validated artifact, not validation logic. Fix artifact; do not validate the validation.

Consumer dispatch logic MUST branch on `details.subtype` field. If `subtype` is absent OR empty, treat as the original `wave_quality_threshold_unmet` semantic (extract-intelligence).

### Multiple blockers in one run

For multiple blockers in a single sub-skill run, emit an array:

```yaml
blockers:
  - type: oq_blocker
    tag: OQ-AR-1
    priority: P1
    context: "Implementing F-U-001 backend"
    resolver_owner: "Mike Patel"
    resolver_route: "ask in #timeoff-team"
    vault_version: "1.0"
    source_skill: generate-intent
  - type: diff_conflict
    tag: OQ-DC-2
    priority: n/a
    context: "Applying diff-vault to PRD-v2.pdf"
    resolver_owner: "Mike Patel"
    resolver_route: "ask in #timeoff-team"
    vault_version: "1.1"
    source_skill: diff-vault
    conflict_old: "Idempotency 24h TTL (D-010)"
    conflict_new: "Idempotency 7d TTL (PRD §X.Y)"
    options: ["supersede", "keep_vault", "capture_both"]
```

### Backward compatibility

Vaults generated under v0.13 still emit the legacy `oq_blocker:` YAML form (without the unified envelope). AI consumers reading vaults should accept both shapes for one release cycle:

```yaml
# Legacy v0.13 form (still valid):
oq_blocker:
  tag: OQ-AR-1
  priority: P1
  ...

# New v0.14 form:
blocker:
  type: oq_blocker
  tag: OQ-AR-1
  priority: P1
  ...
```

Regenerated vaults produce only the new form.

### Field rules

- `tag` mirrors the markdown identifier (OQ tag, ADR ID, or `n/a`). Never invent.
- `resolver_owner` is best-effort; use `null` if not declared in the OQ entry.
- `vault_version` is the current vault version at emit time, not the target post-resolution version.
- `source_skill` identifies the emitting skill — needed because consumers may dispatch differently per source.
- `context` is human-readable; keep it short (one line). It's not a structured field.
- For `diff_conflict`, `options` MUST list the user choices as `{code, keterangan}` pairs — the code verbatim from the diff report, the keterangan saying what choosing it does (e.g. `supersede` — keputusan baru menggantikan yang di vault; `keep_vault` — tolak perubahan PRD, vault tetap; `capture_both` — catat keduanya sebagai OQ untuk stakeholder). An optional `recommended: <code>` carries a one-line rationale. (Legacy bare-string arrays are read-compatible; the DISPLAYER still renders the legend per step 0.)

### Type-specific schemas (v1.1 additions)

```yaml
# bind_conflict — emitted by bind-codebase when CONFLICT count > 0
details:
  vault: <path>
  conflict_count: N
  conflicts:
    - id: C-001
      vault_claim: <text>
      codebase_reality: <text>
      suggested_action: KEEP_VAULT | KEEP_CODE | DEFER | SPLIT
      suggested_action_rationale: <one line — why, citing the evidence>   # keterangan contract: the enum never surfaces bare; the displayer also renders the 4-code legend (KEEP_VAULT = code harus diubah mengikuti vault; KEEP_CODE = vault di-update mengikuti kenyataan code; DEFER = jadi OQ — gate binding terbuka, unit digenerate membawa OQ-nya, execute-bolts prompt sebelum bolt final; SPLIT = claim dipecah jadi sub-claim)

# dep_missing — emitted by execute-bolts when superpowers AND vendored fallback both absent
details:
  required_skills: [executing-plans, subagent-driven-development, test-driven-development, using-git-worktrees]
  missing_real: [...]
  missing_vendored: [...]
  install_command: "/plugin install superpowers"

# test_fail — emitted by execute-bolts after max retries
details:
  unit_id: U-XXX
  retries_attempted: N
  test_command: <cmd>
  last_failure_output: <verbatim test output>
  files_touched: [...]

# cycle_detected — emitted by generate-units when dependency DAG has cycle
details:
  cycle_path: [U-001, U-002, U-001]

# mode_migrate — emitted by orchestrate-flow on vault.mode vs CWD signal mismatch
details:
  vault_mode: greenfield | existing
  cwd_signals: [.git, package.json, ...]
  resolution: "update vault mode" | "re-detect"

# cross_squad_dep_invalid — emitted by generate-units in multi-squad mode
# when a unit's depends_on references a unit in a different squad
details:
  unit_id: U-XXX
  unit_squad: <squad-id>
  dependency_id: U-YYY
  dependency_squad: <squad-id-different>

# interface_ref_missing — emitted by generate-units when a unit's
# produces_interfaces or consumes_interfaces references an interface ID
# that has no corresponding file in <vault>/interfaces/
details:
  unit_id: U-XXX
  missing_interface_id: <kebab-id>
  referenced_in: consumes_interfaces | produces_interfaces

# cross_squad_ambiguous — emitted by generate-units when two or more
# squads in _meta/squads.yaml claim ownership of the same artifact at
# the same precedence level
details:
  artifact: <flow-id or entity-name or component-name>
  artifact_kind: flow | entity | component | adr | oq
  claimed_by_squads: [<id-1>, <id-2>, ...]
  matched_via: owns_layers | owns_components | owns_flow_prefixes | owns_feature_tags

# cross_squad_interface_draft — emitted by execute-bolts (specifically
# --per-squad or --squad=<id> modes) when a unit consumes an interface
# whose status is draft, blocking consumer execution until producer locks
details:
  unit_id: U-XXX
  unit_squad: <consumer-squad-id>
  consumed_interface_id: <kebab-id>
  producer_squad: <producer-squad-id>
  interface_status: draft
```
