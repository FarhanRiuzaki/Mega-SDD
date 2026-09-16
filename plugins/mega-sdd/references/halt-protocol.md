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
| **C1 — Self-resolve** | Skill fixes own output, logs the `[self-resolved]` chat one-liner, NEVER halts. | Skill emitted bad output (missing field, parse error, citation typo) AND can re-derive from in-context info. NO ground-truth fabrication. NO silent failure hiding (every fix logged). |
| **C2 — Business gate** | Halt + PROPOSE recommendation + sign-off. No raw "what should I do?" questions. | Resolution needs domain/stakeholder intent (scope choice, conflict resolution, business rule). Skill emits halt envelope with `recommendation:` field populated. |
| **C3 — Grounding gate** | Halt — enforce via [HOOK-VALIDATE] slice (deterministic validator), not prose. | Continuing would require hallucinating ground truth (vault↔code conflict, traceability ID drop). Enforced by hook + state file, not skill body text. |

### C1 self-resolve protocol

When a skill detects a C1 condition during execution:

1. **Apply the documented fix** (per the halt's `C1 SELF-RESOLVE` description in this file).
2. **Emit chat one-liner:** `[self-resolved] <halt_type>: <fix_applied>` (single line, not a halt envelope).
3. **Continue execution.** Do NOT emit a `blocker:` envelope. Do NOT pause the chain. Do NOT prompt the human.

### Escalation paths from C1 → C2

A C1 halt MUST escalate to C2 (with proposal) when:
- Resolution would require ground truth the model lacks (e.g., re-picking from empty inventory)
- Documented retry budget exhausted (e.g., `invalid_handoff` after 2 producer re-invokes)
- The fix would silently hide a class of failure the human should know about (catch-all safety)

When escalating, emit standard C2 halt envelope WITH the C1 attempt history in `details.retry_attempts: [...]` for forensics.

### C2 propose-and-confirm discipline

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

This discipline is LIVE: the auto-propose flow and its `halt_auto_propose` config live in `execute-bolts/references/halt-recovery.md §Configuration override`, and the prompt template in `execute-bolts/references/propose-and-confirm-prompt.md`.

### C3 enforcement via [HOOK-VALIDATE]

C3 halts are enforced by `plugins/mega-sdd/scripts/validate-handoff-*.sh` validators + `PreToolUse` hooks per `docs/mega-sdd/fork-a-recovery-map.md` (repo docs, maintainer-facing since v7.4.0). Skill bodies declaring C3 halts can mention them as design vocabulary, but the actual enforcement is the hook layer. The binding→units OQ-ID slice is hook-enforced today; CONFLICT-IDs / Hard Rules / vault→binding / units→bolts follow the same pattern.

### Backward compatibility

Halts not yet classified (or in older skill bodies) default to legacy behavior (ALWAYS STOP). The current C1 census is carried inline in the registry — each C1 halt's index row and family entry is marked **C1 SELF-RESOLVE**; a row without that mark is not C1.

## §halt-protocol — Unified `blocker` envelope

When a skill running in `--auto` mode hits something that requires human judgment (unresolved P1 OQ blocking downstream work, diff-vault conflict, framework mismatch), it emits a structured YAML artifact called a **blocker**. The orchestrator (`/mega-sdd`) catches blockers, pauses the chain, and surfaces the artifact in chat for the user to act on.

The envelope is uniform across types so a single consumer can handle all of them.

### Schema

```yaml
blocker:
  type: oq_blocker | diff_conflict | drift_framework_mismatch | bind_conflict | binding_conflict | dep_missing | test_fail | ambiguous_spec | cycle_detected | cross_module_dep_invalid | module_cycle_detected | unit_oq_trace_missing | mode_migrate | cross_squad_dep_invalid | interface_ref_missing | cross_squad_ambiguous | cross_squad_interface_draft | deep_scan_subagent_failed | deep_scan_cache_corrupt | deep_scan_subagent_all_failed | starterkit_rule_citation_missing | bind_conflict_constitution_violation | bind_inputs_missing | framework_pack_missing | framework_pack_cycle | framework_pack_unparseable | constitution_drift_detected | memory_in_use | dispatch_prompt_too_large | bolt_repeated_partial_failure | provenance_missing | bolt_introduces_locked_drift | self_assessment_missing | oq_recommend_citation_invalid | predictive_check_failed | invalid_handoff | handoff_type_mismatch | model_tier_unknown | pbt_citation_invalid | pbt_property_violated | handoff_missing | artifact_missing | partial_state_corrupt | dedup_ambiguous | hard_rule_unparseable | hard_rule_violated | prd_no_scopes_block_user_rejected_retrofit | prd_path_missing | prd_retrofit_low_confidence | quality_gate_failed | scope_not_declared_in_prd | install_failed | pkg_mgr_not_found | oq_tech_missing_mode | oq_recommend_underspecified | oq_scan_missing_query | oq_business_p1_unresolved | no_starterkit_detected | module_blocked_by | sprint_blocked_by | acceptance_path_unowned | hard_rule_unanchored | unit_underspecified | prd_source_unresolvable | plan_coverage_gap | verify_unit_writable | verify_grounding_untrusted | adoption_demote_confirm | delta_too_large | secret_in_code | sast_critical_finding | dep_not_found | review_critical_unresolved | batch_suite_red | batch_suite_gate_missing | postflight_evidence_missing | acceptance_evidence_missing | acceptance_red | build_broken | panel_evidence_missing | l0_evidence_missing | acceptance_expects_missing | anchor_missing | whitelist_violation | commit_rejected_by_hook | scope_creep_detected | bolt_artifacts_missing | hard_rule_mixed_grammar | convergence_max_reached | phase_stuck | anti_spin | drift_inputs_missing | scope_args_missing | vault_json_corrupt | scan_repo_too_large | scan_primary_app_ambiguous | scan_spawn_budget_exceeded | codebase_map_derive_failed | codebase_map_invalid | user_authored_conflict | vault_not_found | vault_corrupt | greenfield_no_bind_context
  tag: <stable identifier — OQ-AR-1, D-007, etc.>
  priority: P1 | P2 | P3 | n/a
  context: "<what's blocked, e.g. 'Implementing F-U-001 backend' or 'Applying diff-vault Step 6'>"
  resolver_owner: "<name or role, e.g. 'Mike Patel (Eng Lead)'>"
  resolver_route: "<where to find them, e.g. 'ask in #timeoff-team'>"
  vault_version: "<current vault version, e.g. '1.1'>"
  source_skill: generate-intent | diff-vault | detect-drift | bind-codebase | scan-codebase | generate-units | execute-bolts | extract-intelligence | resolve-oq | plan | orchestrate-flow | emit-agents-md | emit-fsd | emit-prd | emit-sit | emit-uat | install-deps
  # type-specific fields below
  conflict_old: "<vault state>"            # diff_conflict only
  conflict_new: "<new PRD state>"          # diff_conflict only
  options: ["supersede", "keep_vault", "capture_both"]  # diff_conflict only
  cap_exceeded: "<which cap: entities_flows | changed_rows | new_scope | scope_shift>"  # delta_too_large only
  measured: "<the offending count, e.g. entities+flows=4>"  # delta_too_large only
  # delta_too_large also uses `options:` — as {code, keterangan} pairs per §Field rules:
  # full_lane / split_ticket / cancel (registry entry below carries the keterangan text)
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

# LEGACY (accepted for backward compat):
next_action: "<one-line prose string>"         # plain string form

# OMITTED (NOT accepted):
# next_action: <missing>                        → halt invalid_handoff during validation
```

`type` enum — five values, each with a live emitter or consumer (the seven prose-only values that no skill, script, or fixture ever used were dropped in 8.4.0; the free-text `hint` carries any nuance):

- `re_run_producer` — re-run the producer skill standalone to reproduce *(script-emitted by `validate-handoff-yaml.sh`)*
- `user_review` — user inspects artifact + decides *(script-emitted)*
- `chain_complete` — terminal; no further action *(script-emitted)*
- `invoke_skill` — orchestrator auto-invokes a recovery skill (skill-authored envelopes; the handoff-types fixtures)
- `inspect_subskill_logs` — read chat_tail_excerpt + investigate sub-skill output (skill-authored envelopes)

Consumer dispatch (ANY halt-displaying surface — orchestrate-flow is the chain-path displayer; a skill halting on a STANDALONE run renders the same way):

0. **Keterangan block FIRST (MANDATORY — the keterangan contract, `references/output-language.md §Prompt surfaces`).** BEFORE printing the envelope YAML, render a plain-language block in Tier-2 narration (Indonesian-mix by default):
   - **Apa yang ditanya:** resolve `tag` to the ACTUAL text — quote the OQ question / CONFLICT claim pair / decision at stake verbatim from the source artifact (the vault doc, `binding.md`, the diff report). A bare `OQ-AR-1` is never a question.
   - **Kenapa berhenti:** one line — which phase halted and why this blocks it.
   - **Pilihan lo:** when the envelope carries choices (`options`, `suggested_action`, an action menu), list each as `CODE — keterangan konsekuensi` (Tier-1 code stays English; the description says what choosing it DOES). Mark the recommended default with its one-line reason when one exists.
   - Then print the envelope YAML below the block (the YAML is the machine record; the block is for the human).
1. Read `next_action.type` if present → format hint per type semantics (e.g., wrap commands in code fence)
2. Else read `next_action.hint` if it's a string → display as plain text
3. Else (no next_action) → emit `invalid_handoff` halt at validation gate

**Backward compatibility:** legacy halt emit sites work unchanged. The canonical shape is RECOMMENDED for new halts but not enforced — consumers fall back to legacy string-only form.

### Type-specific guidance — registry index

One row per halt type. The full guidance body lives in the named family file
(`references/halt-families/`) — load ONLY the family of the halt in hand; this
index is the router and the registry-existence surface (grep a type name here).

Rows below are the halt-type index — this index is the registry-existence surface (grep a type name here); the handoff validator checks envelope SHAPE and, since 8.4.0, WARNS (advisory `halt_type_unregistered` in its state, never a FAIL) on a blocker type this index does not carry. Validator DROP codes (`binding_missing`, `conflict_unresolved`, … in `.validation-blockers.json`) are not halt types: the emitting skill maps them to a halt (`conflict_unresolved` ⇒ `binding_conflict`). Rows marked *(subtype of `quality_gate_failed`)* are NOT standalone types: they are emitted as `type: quality_gate_failed` + `details.subtype: <name>` (see §`quality_gate_failed` subtypes below). `skills/orchestrate-flow/references/halt-taxonomy.md` mirrors classification NAMES only; full guidance bodies live in `halt-families/`, these rows are the index.

**intent-and-vault** (`halt-families/intent-and-vault.md`):

- `oq_blocker` — emitted by `generate-intent` (when generation surfaces a P1 that would block downstream…
- `diff_conflict` — emitted by `diff-vault` Step 5 when a Resolved-OQ conflict or Decision conflict require…
- `delta_too_large` — diff-vault (`--from-prompt` cap, Step 3): a chat-brief delta exceeds the ticket-scale c…
- `oq_recommend_citation_invalid` — generate-intent: OQ recommendation cites non-existent KB…
- `prd_no_scopes_block_user_rejected_retrofit` — generate-intent: PRD lacks `scopes:` frontmatter AND user rejected AI retrofit AND chos…
- `prd_path_missing` — diff-vault: `vault.json.prd_path_at_generation` points to non-existent PRD file. ALWAYS…
- `prd_retrofit_low_confidence` — generate-intent: AI retrofit subagent returned `overall_confidence: LOW`. ALWAYS STOP.…
- `scope_not_declared_in_prd` — generate-intent: `--scope=<id>` flag references a scope ID that's not in the PRD's `sco…
- `oq_tech_missing_mode` — generate-intent: PRD declares technical OQ but `resolution_mode` field missing on the O…
- `oq_scan_missing_query` — generate-intent: an OQ marked `resolution_mode: scan` lacks the `scan_query` field that…

**extract** (`halt-families/extract.md`):

- `quality_gate_failed` — extract-intelligence: a module's per-module quality gate failed twice for the same module (frontmatter / sections / gotcha floor / Mermaid flow / citation discipline). ALWAYS STOP; gate output verbatim. → `halt-families/extract.md`
- `claim_verify_failed` *(subtype of `quality_gate_failed`)* — extract-intelligence claim-verify lane: the same module's verify report shows `wrong_load_bearing > 0` twice. ALWAYS STOP; findings verbatim in the halt. → `halt-families/extract.md`

**scan** (`halt-families/scan.md`):

- `deep_scan_subagent_failed` — scan-codebase: a deep-scan slice subagent (auth/authz/ui-ux/libs/reuse) failed once. So… **[Soft halt — auto-retried, warn-only]**
- `deep_scan_cache_corrupt` — scan-codebase: starterkit-context.yaml exists but fails YAML parse. Soft halt: cache au…
- `deep_scan_subagent_all_failed` — scan-codebase: ALL 5 deep-scan slice subagents failed (likely API outage). ALWAYS STOP:…
- `dep_missing` — scan-codebase: a FORCED engine's binary not found (ast-grep under --engine=ast-grep… *(also emitted by execute-bolts — test runner absent (preflight 3.5) or ast-grep absent under v2 grammar — and the emit lane)*
- `scan_repo_too_large` — scan-codebase: repo > 100k files and no `--force-large`. ALWAYS STOP; re-run with `--force-large` or narrow `--include=`. → `halt-families/scan.md`
- `scan_primary_app_ambiguous` — scan-codebase: monorepo with ≥2 app-root manifests, no `--include`, no root manifest. ALWAYS STOP; re-run with `--include=<app dir>`. → `halt-families/scan.md`
- `scan_spawn_budget_exceeded` — scan-codebase (undecided STANDALONE lane only): estimated extraction > 60 s with no explicit `--engine=` / `--include=`. ALWAYS STOP; re-run with an explicit engine or include, or unattended (`--auto`). → `halt-families/scan.md`
- `codebase_map_derive_failed` — scan-codebase Step 10: `derive-codebase-map.sh` exit 2 — a delta gap. ALWAYS STOP; fix the named delta and re-run the same scan. → `halt-families/scan.md`
- `codebase_map_invalid` — scan-codebase Step 10: `derive-codebase-map.sh` exit 4 — the derived map fails its own validation. ALWAYS STOP; read the deriver stderr, re-run. → `halt-families/scan.md`

**bind** (`halt-families/bind.md`):

- `bind_conflict_constitution_violation` — bind-codebase: claim conflicts with constitution.md security clause. ALWAYS STOP. Resol…
- `framework_pack_missing` — bind-codebase: framework convention pack referenced but file absent. ALWAYS STOP. Resol…
- `framework_pack_cycle` — bind-codebase: pack inheritance has cycle (A extends B ex…
- `framework_pack_unparseable` — bind-codebase: pack file fails YAML/markdown parse. ALWAY…
- `oq_recommend_underspecified` — generate-intent / bind-codebase: an OQ marked `resolution_mode: recommend` lacks one or…
- `bind_conflict` — bind-codebase: binding produced ≥1 CONFLICT verdict; downstream generation is hook-blocked until each is resolved. Schema + resolution-code legend: §Type-specific schemas (`bind_conflict`); guidance: `halt-families/bind.md`.
- `binding_conflict` — execute-bolts pre-flight 3.9 (v8 P1): a unit's JIT claim CONFLICTs with the code. ALWAYS STOP for that unit; resolve via `resolve-oq --binding`.
- `bind_inputs_missing` — bind-codebase Step 0: a required input (`vault` | `codebase_map` | `vault_index`) is absent, ambiguous, malformed, or outside the vaults glob root. ALWAYS STOP. Schema: `bind-codebase/references/auto-memory-handoff.md`; guidance: `halt-families/bind.md`.

**units** (`halt-families/units.md`):

- `starterkit_rule_citation_missing` — generate-units: a starterkit-derived Hard Rule lacks `Citation: starterkit-context.yaml…
- `dedup_ambiguous` — generate-units: dedupe step finds multiple existing units that could match a new claim…
- `hard_rule_unparseable` — generate-units: a unit's `## Hard Rules` block contains ast-grep YAML that fails parse…
- `prd_source_unresolvable` — generate-units: `prd_source` unresolvable. ALWAYS STOP.
- `plan_coverage_gap` — generate-units 12.8 (v8 P1): PRD heading with no unit `prd_source` and no OQ. ALWAYS STOP.
- `unit_underspecified` — generate-units: a generated unit lacks one or more required spec fields (`target_files`…
- `cycle_detected` — generate-units: the unit dependency DAG has a cycle. Schema: §Type-specific schemas (`cycle_detected`); guidance: `halt-families/units.md`.
- `cross_module_dep_invalid` — generate-units Step 4.5: a cross-module `depends_on` edge lacks its `blocked_by` in `_meta/modules.yaml`. ALWAYS STOP. Guidance: `halt-families/units.md`.
- `module_cycle_detected` — generate-units Step 4.5: the module-level DAG has a cycle. ALWAYS STOP. Guidance: `halt-families/units.md`.
- `unit_oq_trace_missing` — generate-units Step 12.5 g (MOAT-CRITICAL — the binding→units handoff): an implementation-relevant OQ-ID is absent from a unit's `binding_refs:`. ALWAYS STOP. Schema: `generate-units/references/halt-protocol.md`; guidance: `halt-families/units.md`.
- `cross_squad_dep_invalid` — generate-units (multi-squad): a unit's `depends_on` references a unit in a different squad. Schema: §Type-specific schemas; guidance: `halt-families/units.md`.
- `cross_squad_ambiguous` — generate-units (multi-squad): two or more squads claim the same artifact at the same precedence. Schema: §Type-specific schemas; guidance: `halt-families/units.md`.
- `cross_squad_interface_draft` — execute-bolts (`--per-squad`/`--squad=`): a consumed interface is still `status: draft`. Schema: §Type-specific schemas; guidance: `halt-families/units.md`.
- `interface_ref_missing` — generate-units: `produces_interfaces`/`consumes_interfaces` references an interface ID with no file in `<vault>/interfaces/`. Schema: §Type-specific schemas; guidance: `halt-families/units.md`.

**bolts** (`halt-families/bolts.md`):

- `ambiguous_spec` — execute-bolts (emitted by the `bolt-implementer` subagent): the unit spec admits more than one reading and the implementer will not guess. ALWAYS STOP (pure-pause; human interpretation call). Guidance: `halt-families/bolts.md`.
- `dispatch_prompt_too_large` — execute-bolts: assembled bolt dispatch prompt exceeds 10KB hard cap. ALWAYS STOP. Resol…
- `bolt_repeated_partial_failure` — execute-bolts: bolt failed 3 partial-state recovery cycles. ALWAYS STOP. Resolution: re…
- `provenance_missing` — execute-bolts: bolt modified file lacks provenance traile…
- `bolt_introduces_locked_drift` — execute-bolts: bolt drift hits a LOCKED entity. ALWAYS STOP (override-only; CONFLICT-li…
- `self_assessment_missing` — execute-bolts: bolt-report.md lacks self-assessment secti…
- `pbt_citation_invalid` — execute-bolts: a PBT property block declares `Cites: §Decision-D-NNN` but the cited ADR…
- `pbt_property_violated` — execute-bolts post-flight: an error-severity PBT property failed; counterexample preserved; propose-and-confirm bridge. (Registered 6.14.0 — the type predates the registry row; owners: generate-units pbt-integration.md + convergence-loops.md.)
- `partial_state_corrupt` — execute-bolts: `--resume` mode loaded `<vault>/bolts/U-XXX/partial-state.json` (canonic… **[C1 SELF-RESOLVE — never halts on the primary path]**
- `hard_rule_violated` — execute-bolts: the post-flight scan of the ALREADY-COMMITTED bolt found a Hard Rule vio…
- `module_blocked_by` — execute-bolts: bolt invocation blocked because prerequisite module hasn't completed yet…
- `sprint_blocked_by` — execute-bolts: `--sprint=<n>` invoked while an earlier sprint still has incomplete units…
- `acceptance_path_unowned` — a unit acceptance_test command runs a path no unit declares in target_files and that does not exist…
- `panel_evidence_missing` — execute-bolts gate (7.11.0): bolt keyed by `review-tier.json` lacks a `merge-panel-findings.sh`-written ledger. ALWAYS STOP.
- `l0_evidence_missing` — execute-bolts gate (7.11.0): keyed bolt lacks a `run-code-gates.sh --write` L0 record. ALWAYS STOP.
- `acceptance_expects_missing` — execute-bolts in-run gate (7.11.0): dispatched unit has a `type: test` entry with no `expects`. ALWAYS STOP (that dispatch only).
- `hard_rule_unanchored` — execute-bolts: a unit's `## Hard Rules` block references an ANCHOR (file path / functio…
- `verify_unit_writable` — execute-bolts: a `task_type: verify` unit has non-empty `target_files` with operation ∈… **[C1 SELF-RESOLVE — never halts on the primary path]**
- `secret_in_code` — execute-bolts (L0 gate): a committed secret was detected; user rotates it + purges it f…
- `sast_critical_finding` — execute-bolts (L0 gate): a Critical SAST finding; user fixes before the panel. ALWAYS S…
- `dep_not_found` — execute-bolts (L0 gate): a newly-added dependency does not resolve in its registry; use…
- `review_critical_unresolved` — execute-bolts: the review panel's Critical findings (or a still-❌ spec lens — an unmet…
- `batch_suite_red` — execute-bolts: the batch-completion FULL suite ended RED; user fixes the failing test(s…
- `batch_suite_gate_missing` — execute-bolts: no green `_batch-suite.json` covers the newest code commit (a bolt OR an…
- `postflight_evidence_missing` — execute-bolts: a committed Hard-rule bolt has no passing `postflight.json`; user runs t…
- `acceptance_evidence_missing` — execute-bolts (B4): a **v5-keyed** bolt (its commit carries the `SDD-Acceptance: v5` tr…
- `acceptance_red` — execute-bolts (B4): the recorded `acceptance.json` is RED — an executed `acceptance_tes…
- `build_broken` — execute-bolts (L0 syntax floor, B4 pre-rung): a committed file fails the zero-config sy…
- `anchor_missing` — execute-bolts (pre-flight, `check-anchor-freshness.sh`): a `## Anchors` entry `file:lin…
- `whitelist_violation` — execute-bolts: a bolt commit touched files outside the unit's `target_files` ∪ sanction…
- `commit_rejected_by_hook` — execute-bolts: the repo's own commit hook (pre-commit/husky/lefthook) or required GPG s…
- `scope_creep_detected` — execute-bolts: a bolt exceeded its declared scope; user reviews the deviation. ALWAYS S…
- `bolt_artifacts_missing` — execute-bolts: a `completed` unit emitted no `bolts/U-XXX/bolt-report.md`; structural s…
- `hard_rule_mixed_grammar` — execute-bolts: a unit's `## Hard rules` mixes v1 (bulleted) + v2 (YAML) grammar; user p…
- `test_fail` — execute-bolts: a unit's tests still fail after max retries. Schema: §Type-specific schemas (`test_fail`); guidance: `halt-families/bolts.md`.
- `verify_grounding_untrusted` — execute-bolts (A1 verify-grounding gate): a `verify` unit with HIGH `grounding_confidence` whose acceptance criteria lack a non-test source anchor; blocking at the execute-bolts gate.

**flow** (`halt-families/flow.md`):

- `drift_framework_mismatch` — emitted by `detect-drift` Step 1.5 when the vault implies one framework but the codebas…
- `constitution_drift_detected` — detect-drift: §B Security or §F Compliance constitution clause drift detected in code.…
- `memory_in_use` — advisory file-lock collision (vault.json.lock via `derive-vault-json.sh` exit 4, or the starterkit-context lock): concurrent writer holds the lock. Surface the envelope (wait 5s + retry; check for an orphaned `.lock` older than 30s and remove it manually). The halt NAME is historical (pre-v7.3.0); the lock class it names is pipeline concurrency, not the removed memory lane.
- `mode_migrate` — orchestrate-flow: vault.json `mode` field (greenfield | existing) doesn't match CWD sig… **[C1 SELF-RESOLVE — never halts on the primary path]**
- `predictive_check_failed` — orchestrate-flow: predictive preflight check marked `fatal: yes` failed. ALWAYS STOP. R…
- `invalid_handoff` — orchestrate-flow: handoff YAML from sub-skill fails schema validation (missing REQUIRED… **[C1 SELF-RESOLVE — never halts on the primary path]**
- `handoff_type_mismatch` — orchestrate-flow: handoff YAML field type doesn't match TYPE annotation in handoff-cont…
- `model_tier_unknown` — orchestrate-flow: model-tier override references a role not in `references/model-tiers.md` **[C1 SELF-RESOLVE — never halts on the primary path]**
- `handoff_missing` — orchestrate-flow: sub-skill chat output contains no parseable `handoff:` YAML block (sk…
- `artifact_missing` — orchestrate-flow: handoff YAML lists `artifacts: [paths]` and one or more paths fail ex…
- `install_failed` — install-deps: install command exited non-zero OR `verify_cmd` failed post-install. ALWA…
- `pkg_mgr_not_found` — install-deps: no compatible package manager detected for OS (PKG_MGR=`none` AND no cros…
- `oq_business_p1_unresolved` — orchestrate-flow: a P1 business OQ blocks downstream pipeline; chain pauses until user…
- `no_starterkit_detected` — orchestrate-flow: starterkit-first mode default but no framework manifest detected (no…
- `adoption_demote_confirm` — orchestrate-flow / auto (P2 adoption lane, LOCKED): `scripts/certify-artifact.sh` retur…
- `convergence_max_reached` — orchestrate-flow: convergence loop hit `--max-cycles`. User reviews cycle history (enve…
- `phase_stuck` — factory-line: a phase failed to reach a green checkpoint within the retry cap (default…
- `anti_spin` — factory-line: a phase re-ran with an identical unresolved set (no progress); the loop s…
- `drift_inputs_missing` — detect-drift Step 0 (fork-ready — it cannot ask): the vault or code dir is unresolvable from the args / CWD. ALWAYS STOP; re-invoke with `--code=<repo-root>` and/or `--vault=<vault-dir>`. → `halt-families/flow.md`
- `scope_args_missing` — `validate-handoff-yaml.sh`: an execute-bolts handoff carries a `scope:` block and routes to detect-drift without `--scope=<id>` in `next_action.suggested_args` — the scope would die at the seam. ALWAYS STOP; add the flag. → `halt-families/flow.md`
- `vault_json_corrupt` — `scripts/ground.sh` Guard 1: a `vault.json` fails to parse; the mode guard skips it and prints the file. **[C1 SELF-RESOLVE — never halts on the primary path]** Resolution: `derive-vault-json.sh --vault <dir>`. → `halt-families/flow.md`
- `starterkit_metrics_inconsistent` *(subtype of `quality_gate_failed`)* — orchestrate-flow: generate-units handoff reports `units_with_starterkit_rules > 0` but…

**emit** (`halt-families/emit.md`):

- `pdf_render_failed` *(subtype of `quality_gate_failed`)* — emit-fsd: pandoc exited non-zero during PDF render in §Step 5.3. Details include `pando…
- `template_slot_unfilled` *(subtype of `quality_gate_failed`)* — emit-fsd: an FSD-template slot marker `{{slot_name}}` remained unfilled in `FSD.md` out…
- `citation_unresolvable` *(subtype of `quality_gate_failed`)* — emit-fsd: `scripts/build-citation-map.sh` exited 1, for either (or both) of two causes:…
- `signoff_fabricated` *(subtype of `quality_gate_failed`)* — emit-sit: a §5 Sign-off body row in `SIT.md` carries non-placeholder text in the Nama /…
- `execution_fabricated` *(subtype of `quality_gate_failed`)* — emit-uat: a §2 execution cell / tester footer, §3 RTM status, or §4 berita-acara/sign-o… (ANNEX_FORGED)
- `marker_stripped` *(subtype of `quality_gate_failed`)* — emit-prd: a PRD line citing a knowledge-base claim lost (or upgraded) that claim's `[VE…
- `user_authored_conflict` — emit-agents-md under `--auto`: AGENTS.md exists, user-authored, no mega-sdd marker (an interactive run asks sibling / append / skip). ALWAYS STOP; re-run interactively or pick `sibling`. → `halt-families/emit.md`
- `vault_not_found` — emit-agents-md: no vault resolvable from the args / CWD. ALWAYS STOP; pass the vault path. → `halt-families/emit.md`
- `vault_corrupt` — emit-agents-md: `vault.json` lacks a required field. ALWAYS STOP; re-derive it (`derive-vault-json.sh --vault <dir>`). → `halt-families/emit.md`
- `greenfield_no_bind_context` — emit-agents-md: a greenfield vault with no bind context to render. ALWAYS STOP; run the chain to bolts first (or `--lite`). → `halt-families/emit.md`

#### `quality_gate_failed` subtypes

The `quality_gate_failed` halt carries a `subtype:` discriminator. Canonical subtype enum — these are emitted as `type: quality_gate_failed` + `details.subtype: <name>`, **NOT** as standalone halt types:

*(omitted / `module_quality_threshold_unmet`)* · `starterkit_metrics_inconsistent` · `pdf_render_failed` · `template_slot_unfilled` · `citation_unresolvable` · `signoff_fabricated` · `execution_fabricated` · `marker_stripped` · `claim_verify_failed`

Consumer dispatch logic MUST branch on `details.subtype` field. If `subtype` is absent OR empty, treat as the `module_quality_threshold_unmet` semantic (extract-intelligence; pre-v7.6 records may carry the historical label `wave_quality_threshold_unmet` — same semantic). Full guidance per subtype lives in the family files the index routes to (emit-lane subtypes → `halt-families/emit.md`; starterkit/budget guards → `halt-families/flow.md`; the extract default → `halt-families/extract.md`).

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

Only the unified `blocker:` envelope is accepted — the pre-1.0 bare `oq_blocker:` form is not parsed by `validate-handoff-yaml.sh`.

### Field rules

- `tag` mirrors the markdown identifier (OQ tag, ADR ID, or `n/a`). Never invent.
- `resolver_owner` is best-effort; use `null` if not declared in the OQ entry.
- `vault_version` is the current vault version at emit time, not the target post-resolution version.
- `source_skill` identifies the emitting skill — needed because consumers may dispatch differently per source.
- `context` is human-readable; keep it short (one line). It's not a structured field.
- For `diff_conflict`, `options` MUST list the user choices as `{code, keterangan}` pairs — the code verbatim from the diff report, the keterangan saying what choosing it does (e.g. `supersede` — keputusan baru menggantikan yang di vault; `keep_vault` — tolak perubahan PRD, vault tetap; `capture_both` — catat keduanya sebagai OQ untuk stakeholder). An optional `recommended: <code>` carries a one-line rationale. (Legacy bare-string arrays are read-compatible; the DISPLAYER still renders the legend per step 0.)

### Type-specific schemas

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

# dep_missing — emitted by execute-bolts when the project's test runner is absent
# (preflight 3.5) or ast-grep is absent under v2 Hard-rule grammar (preflight 4)
details:
  missing_tool: <runner-or-binary>
  install_command: <one command>

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

# adoption_demote_confirm — emitted by orchestrate-flow/auto when
# scripts/certify-artifact.sh verdicts DEMOTE (P2 adoption)
details:
  rung: prd | map | vault | kb | units
  artifact_path: <path certify-artifact was run against>
  verdict: DEMOTE
  certify_keterangan: <the certify KETERANGAN block, verbatim — incl. the
                       derive-vault-json exit-2 lines when the rung is vault>
  demote_target: "generate-intent (PRD-rung re-ingest)" | "scan-codebase (re-scan)" | "extract-intelligence (re-extract)"
  options: [{code: RE_INGEST, keterangan: <apa yang terjadi + biaya token>},
            {code: MANUAL_FIX, keterangan: <perbaiki mengikuti template, lalu certify ulang>},
            {code: CANCEL, keterangan: <artefak tidak diadopsi, chain berhenti>}]
```
