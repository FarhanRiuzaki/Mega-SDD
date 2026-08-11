# Raw context-trace report — baseline arm

Produced by a blind read-only tracer agent against the 91a944a worktree. UNCERTAIN entries were
adjudicated per ../../tasks/ADJUDICATION.md and cross-arm harmonized per
../../tasks/HARMONIZATION.md; the files.<arm>.txt lists are the harmonized product.

=== T01 ===
INCLUDED:
plugins/mega-sdd/commands/mega-sdd.md | commands/mega-sdd.md:25 | "invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--deep --auto`"
plugins/mega-sdd/skills/using-mega-sdd/SKILL.md | using-mega-sdd/SKILL.md:25 | "STOP, invoke the skill via the `Skill` tool ... announce which skill"
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | commands/mega-sdd.md:8 | "THINLY WRAPS the orchestrate-flow machinery — it detects the input shape"
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md | orchestrate-flow/SKILL.md:25 | "apply the decision table per `references/routing-rules.md §CWD inspection`"
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | orchestrate-flow/SKILL.md:51 | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/references/model-tiers.md | orchestrate-flow/references/chain-execution.md:78 | "cli → project → user → catalog default (read from ... model-tiers.md §Catalog)"
plugins/mega-sdd/skills/memory/references/routing-outcomes.md | orchestrate-flow/references/chain-execution.md:58 | "Per `memory/references/routing-outcomes.md` (mega-sdd:memory skill) schema"
plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md | orchestrate-flow/SKILL.md:63 | "Predictive preflight per `references/predictive-checks.md` catalog — runs BEFORE invoking"
plugins/mega-sdd/references/output-language.md | orchestrate-flow/SKILL.md:80 | "Per the keterangan contract (`...output-language.md §Prompt surfaces`) each option carries its description" [SECTION:Prompt surfaces]
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | orchestrate-flow/SKILL.md:86 | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`"
plugins/mega-sdd/skills/orchestrate-flow/references/memory-layer.md | orchestrate-flow/SKILL.md:96 | "Protocol: `references/memory-layer.md §Chain end`"
plugins/mega-sdd/skills/orchestrate-flow/references/factory-routing.md | orchestrate-flow/SKILL.md:127 | "`--factory` — enable state-driven factory routing ... Implied by `--deep`"
plugins/mega-sdd/skills/orchestrate-flow/references/factory-ledger-contract.md | orchestrate-flow/SKILL.md:166 | "the derived checkpoint ledger schema each phase appends to"
plugins/mega-sdd/skills/generate-intent/SKILL.md | orchestrate-flow/references/routing-rules.md:154 | "`generate-intent <prd>` → `generate-units` → `execute-bolts` (3 phases"
plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | generate-intent/SKILL.md:50 | "All three modes share the SAME vault contract (`references/vault-contract.md`)"
plugins/mega-sdd/skills/generate-intent/references/setup-flow.md | generate-intent/SKILL.md:127 | "Full procedures, runtime ordering note ... → `references/setup-flow.md`"
plugins/mega-sdd/skills/generate-intent/references/detection-and-shapes.md | generate-intent/SKILL.md:129 | "confirm `PROJECT_SHAPE` with the user (Project Shape Registry → `references/detection-and-shapes.md`)"
plugins/mega-sdd/skills/generate-intent/references/generation-guide.md | generate-intent/SKILL.md:130 | "**Step 3 — Generate the 7 files** into `<OUTPUT_DIR>`, per `references/generation-guide.md`"
plugins/mega-sdd/skills/generate-intent/references/advisor-checklist.md | generate-intent/SKILL.md:133 | "Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (intent focus)"
plugins/mega-sdd/references/advisor-findings-schema.md | generate-intent/SKILL.md:138 | "Focus + materialization → `references/advisor-checklist.md` + `...advisor-findings-schema.md`"
plugins/mega-sdd/skills/generate-intent/references/self-check.md | generate-intent/SKILL.md:140 | "Full anti-halu + readability + output-mode + `vault.json` integrity checklist → `references/self-check.md`"
plugins/mega-sdd/skills/generate-intent/references/auto-and-handoff.md | generate-intent/SKILL.md:79 | "`--auto` | Skip logistical prompts (set by orchestrate-flow) ... `references/auto-and-handoff.md`"
plugins/mega-sdd/skills/generate-intent/references/templates/00-index.md | generate-intent/SKILL.md:182 | "`references/templates/` — scaffolds ... Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-intent/references/templates/01-overview.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-intent/references/templates/02-architecture.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-intent/references/templates/03-data-model.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-intent/references/templates/04-flows.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-intent/references/templates/05-decisions.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-intent/references/templates/06-constraints.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-units/SKILL.md | orchestrate-flow/references/routing-rules.md:154 | "`generate-intent <prd>` → `generate-units` → `execute-bolts` (3 phases"
plugins/mega-sdd/skills/generate-units/references/defensive-generation.md | generate-units/SKILL.md:45 | "act per the decision matrix in `references/defensive-generation.md §Step 0.5`"
plugins/mega-sdd/skills/generate-units/references/decomposition-rails.md | generate-units/SKILL.md:53 | "full rule + the tradefinance-proven failure modes in `references/decomposition-rails.md §Flow-step`"
plugins/mega-sdd/skills/generate-units/references/task-typing.md | generate-units/SKILL.md:85 | "Detail: `references/task-typing.md §Step 7.6` (single owner)"
plugins/mega-sdd/skills/generate-units/references/modules-schema.md | generate-units/SKILL.md:75 | "Detail: `references/decomposition-rails.md §Module assignment` + `references/modules-schema.md`"
plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md | generate-units/SKILL.md:95 | "run the adversarial review (`references/adversarial-test-prompt.md`)"
plugins/mega-sdd/skills/generate-units/references/templates/unit.md | generate-units/SKILL.md:97 | "Write each unit file using `references/templates/unit.md` as the body template"
plugins/mega-sdd/skills/generate-units/references/auto-and-memory.md | generate-units/SKILL.md:97 | "Detail: `references/auto-and-memory.md §Scope propagation`"
plugins/mega-sdd/skills/generate-units/references/validation-passes.md | generate-units/SKILL.md:101 | "Full procedures + anti-halu rails: `references/validation-passes.md`"
plugins/mega-sdd/skills/generate-units/references/unit-schema.md | generate-units/SKILL.md:105 | "Validate the prompt-shape contract per `references/unit-schema.md`"
plugins/mega-sdd/skills/execute-bolts/SKILL.md | orchestrate-flow/references/routing-rules.md:161 | "Units exist, some not in bolts | `execute-bolts --all --parallel` (1 phase)"
plugins/mega-sdd/skills/execute-bolts/references/superpowers-bridge.md | execute-bolts/SKILL.md:53 | "**Superpowers bridge.** Detect per `references/superpowers-bridge.md`"
plugins/mega-sdd/skills/execute-bolts/references/batch-and-fanout.md | execute-bolts/SKILL.md:134 | "`--all` (topo-sort by `depends_on` ... → `references/batch-and-fanout.md`"
EXCLUDED:
plugins/mega-sdd/skills/scan-codebase/** (whole skill + all references) | condition: "under express the scan hop and any `--scan=` argument are dropped" (routing-rules.md:64) | false because: express spine default, no --classic
plugins/mega-sdd/skills/bind-codebase/** | condition: "greenfield (empty repo) | `generate-intent <prd>` → `generate-units` → `execute-bolts` (3 phases — no scan needed)" (routing-rules.md:154) | false because: scenario chain omits bind; starterkit absent/greenfield row
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "the ADVISORY diagnostics in this loop ... are SKIPPED on express-spine chains" (orchestrate-flow/SKILL.md:92) | false because: express spine, no --full
plugins/mega-sdd/skills/orchestrate-flow/references/convergence-loops.md | condition: "cycle-eligible halts auto-resolve via memory-pre-filled recommendations and re-run" (orchestrate-flow/SKILL.md:153) | false because: zero halts
plugins/mega-sdd/skills/orchestrate-flow/references/halt-taxonomy.md | condition: "The full classification of every halt type is in `references/halt-taxonomy.md`" (orchestrate-flow/SKILL.md:158) | false because: zero halts
plugins/mega-sdd/skills/orchestrate-flow/references/sync-digest.md | condition: "Mode D autonomous deferral contracts" (orchestrate-flow/SKILL.md:178) | false because: not the sync lane
plugins/mega-sdd/references/halt-protocol.md | condition: "All halts emit the unified `blocker` envelope" (generate-intent/SKILL.md:158) | false because: zero halts, zero CONFLICT
plugins/mega-sdd/skills/generate-intent/references/kb-submode.md | condition: "`--kb=<path>` | Mode B KB sub-mode" (generate-intent/SKILL.md:74) | false because: PRD.md Mode A, no KB
plugins/mega-sdd/skills/generate-intent/references/from-prompt-mode.md | condition: "`--from-prompt \"<brief>\"` | Force Mode B (free-text)" (generate-intent/SKILL.md:73) | false because: PRD.md present → Mode A
plugins/mega-sdd/skills/generate-intent/references/multi-scope.md | condition: "load when the PRD declares a `scopes:` block or `--scope=<id>` is passed" (generate-intent/SKILL.md:171) | false because: single scope
plugins/mega-sdd/skills/generate-intent/references/scope-picker.md | condition: "scope filter logic + memory write rules (used by Step 0.9)" (generate-intent/SKILL.md:179) | false because: single scope, picker does not fire
plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md | condition: "the AI subagent prompt for the legacy-PRD scope retrofit bridge" (generate-intent/SKILL.md:180) | false because: single scope, no retrofit
plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md | condition: "if `<project>/.mega-sdd/codebase/starterkit-context.yaml` exists" (generate-units/SKILL.md:87) | false because: no starterkit, no scan ran
plugins/mega-sdd/skills/generate-units/references/pbt-integration.md | condition: "emitted only when a PBT framework is detected" (generate-units/SKILL.md:158) | false because: fresh Laravel 11, no PBT framework
plugins/mega-sdd/skills/generate-units/references/halt-protocol.md | condition: "Full blocker YAML for every type → `references/halt-protocol.md`" (generate-units/SKILL.md:132) | false because: zero halts
plugins/mega-sdd/skills/execute-bolts/references/halt-recovery.md | condition: "load it ONLY when a halt actually fires (or a `properties:` unit is in the batch)" (execute-bolts/SKILL.md:151) | false because: zero halts, no properties units
plugins/mega-sdd/skills/execute-bolts/references/starterkit-enrichment.md | condition: "used ONLY when `.mega-sdd/codebase/starterkit-context.yaml` exists" (execute-bolts/SKILL.md:107) | false because: no starterkit
plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md | condition: "Read it to review or amend builder behavior — the controller no longer executes it" (execute-bolts/SKILL.md:177) | false because: builder is script-run (rule 3)
plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md | condition: "the T1/T2/T3 sections + marker lines the builder populates" (execute-bolts/SKILL.md:179) | false because: script-assembled by build-dispatch-prompt.sh
plugins/mega-sdd/skills/execute-bolts/references/code-gates.md | condition: "Run the wrapper against the landed commit" (execute-bolts/SKILL.md:72) | false because: trace stops before implementer runs/commits
plugins/mega-sdd/skills/execute-bolts/references/review-panel.md | condition: "ROUND 1: the risk-tiered read-only lenses ... dispatched in parallel and blind" (execute-bolts/SKILL.md:81) | false because: post-commit, not reached
plugins/mega-sdd/skills/execute-bolts/references/hard-rule-grammar-v2.md | condition: "the v2 (ast-grep YAML) Hard-rule grammar" (execute-bolts/SKILL.md:176) | false because: grammar auto-detect, no v2 units asserted
plugins/mega-sdd/skills/execute-bolts/references/partial-state-and-saga.md | condition: "A crashed bolt writes `<vault>/bolts/U-XXX/partial-state.json`" (execute-bolts/SKILL.md:147) | false because: no crash, first dispatch
plugins/mega-sdd/skills/execute-bolts/references/squad-subagent.md | condition: "`--per-squad` — fan out across all squads in `_meta/squads.yaml`" (execute-bolts/SKILL.md:31) | false because: single squad
UNCERTAIN:
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md | "Auto-continue between phases via the handoff YAML protocol (consumed per `references/handoff-consumption.md`; producer schema in `references/handoff-contract.md`)" (orchestrate-flow/SKILL.md:60)
plugins/mega-sdd/skills/orchestrate-flow/references/checkpoint-protocol.md | "Checkpoint protocol auto-emits per-step JSONL files at `<vault>/.internal/checkpoints/` (per `references/checkpoint-protocol.md`)" (orchestrate-flow/SKILL.md:131)
plugins/mega-sdd/skills/generate-intent/references/squad-partition.md | "squad partition (single vs ≥2)" (generate-intent/SKILL.md:127) — SKILL never states whether the validation ref loads on the single-squad branch
plugins/mega-sdd/skills/execute-bolts/references/hard-rule-scan.md | "Grammar table, snapshot JSON, and halt YAMLs → `references/hard-rule-scan.md`" (execute-bolts/SKILL.md:59) — pre-flight 4 is script-run; ref carries the exit-code semantics partially restated inline
plugins/mega-sdd/skills/execute-bolts/references/bolt-contract.md | "commits the bolt ... carrying the `Unit:` + `SDD-PROVENANCE:` trailers per `references/bolt-contract.md`" (execute-bolts/SKILL.md:69)
CHAIN-END: Stops at execute-bolts Step 4.5 — `build-dispatch-prompt.sh` has written `<vault>/bolts/U-001/dispatch-prompt.md` and returned `inline_core`; the `mega-sdd:bolt-implementer` Agent call is NOT made. Router overhead (commands/mega-sdd.md + using-mega-sdd/SKILL.md + orchestrate-flow/SKILL.md) counted once per spec rule 6; note using-mega-sdd:35 marks everything below ANCHOR-CORE as session-start-injected rather than step-commanded.

=== T02 ===
INCLUDED:
plugins/mega-sdd/skills/using-mega-sdd/SKILL.md | using-mega-sdd/SKILL.md:13 | "the CWD shows SDD signals: `.mega-sdd/`, `.mega-sdd/vaults/`"
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | using-mega-sdd/SKILL.md:25 | "default route when unsure: `orchestrate-flow`"
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md | orchestrate-flow/SKILL.md:25 | "apply the decision table per `references/routing-rules.md §CWD inspection`"
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | orchestrate-flow/SKILL.md:51 | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/references/model-tiers.md | orchestrate-flow/references/chain-execution.md:78 | "catalog default (read from `plugins/mega-sdd/references/model-tiers.md §Catalog`)"
plugins/mega-sdd/skills/memory/references/routing-outcomes.md | orchestrate-flow/references/chain-execution.md:58 | "Per `memory/references/routing-outcomes.md` (mega-sdd:memory skill) schema"
plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md | orchestrate-flow/SKILL.md:63 | "Predictive preflight per `references/predictive-checks.md` catalog"
plugins/mega-sdd/references/output-language.md | orchestrate-flow/SKILL.md:80 | "Per the keterangan contract (`...output-language.md §Prompt surfaces`)" [SECTION:Prompt surfaces]
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | orchestrate-flow/SKILL.md:86 | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`"
plugins/mega-sdd/skills/orchestrate-flow/references/memory-layer.md | orchestrate-flow/SKILL.md:96 | "Protocol: `references/memory-layer.md §Chain end`"
plugins/mega-sdd/skills/bind-codebase/SKILL.md | orchestrate-flow/references/routing-rules.md:86 | "Vault exists, mode=existing, no codebase-map | express (default): `bind-codebase --express`"
plugins/mega-sdd/references/paths.md | bind-codebase/SKILL.md:36 | "MUST be a **DIRECT CHILD** of `<project-root>/.mega-sdd/vaults/` ... (`plugins/mega-sdd/references/paths.md`)"
plugins/mega-sdd/skills/bind-codebase/references/express-bind.md | bind-codebase/SKILL.md:47 | "`--express` set → this step and Step 2's retrieval are replaced by `references/express-bind.md`"
plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md | bind-codebase/SKILL.md:49 | "**2. Per claim, produce a verdict** (per `references/binding-contract.md`)"
plugins/mega-sdd/skills/bind-codebase/references/implementation-state.md | bind-codebase/SKILL.md:66 | "2.5 Implementation-state classification → ... → `references/implementation-state.md`"
plugins/mega-sdd/skills/bind-codebase/references/oq-resolution.md | bind-codebase/SKILL.md:67 | "2.6 Tech-OQ auto-resolution (scan) + 2.7 recommendation surfacing → ... `references/oq-resolution.md`"
plugins/mega-sdd/skills/bind-codebase/references/hard-rules-and-packs.md | bind-codebase/SKILL.md:68 | "2.8 Framework-convention pack load + 2.9 Suggested Unit Hard Rules → ... `references/hard-rules-and-packs.md`"
plugins/mega-sdd/references/framework-conventions/ (resolved pack file) | bind-codebase/SKILL.md:68 | "packs from `plugins/mega-sdd/references/framework-conventions/`"
plugins/mega-sdd/skills/bind-codebase/references/constitution-and-oq.md | bind-codebase/SKILL.md:69 | "2.10 Constitution-aware CONFLICT surfacing → ... `references/constitution-and-oq.md`"
plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md | bind-codebase/SKILL.md:72 | "Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (binding focus)"
plugins/mega-sdd/references/advisor-findings-schema.md | bind-codebase/SKILL.md:76 | "Full focus + materialization → `references/advisor-checklist.md` + `...advisor-findings-schema.md`"
plugins/mega-sdd/skills/bind-codebase/references/binding-md-template.md | bind-codebase/SKILL.md:80 | "**4. Write `binding.md`** using the template in `references/binding-md-template.md`"
plugins/mega-sdd/skills/bind-codebase/references/binding-json-schema.md | bind-codebase/SKILL.md:82 | "derive `binding.json` (structured State Map sidecar; schema → `references/binding-json-schema.md`)"
plugins/mega-sdd/skills/bind-codebase/references/auto-memory-handoff.md | bind-codebase/SKILL.md:124 | "the script appends the `bind` event ... → `references/auto-memory-handoff.md`"
EXCLUDED:
plugins/mega-sdd/skills/scan-codebase/** | condition: "the map never exists on this spine — a scan demand here would trap every brownfield vault forever" (routing-rules.md:54) | false because: express spine default, vault_no_map row
plugins/mega-sdd/skills/bind-codebase/references/conflict-resolution.md | condition: "Per-conflict recovery (KEEP_VAULT / KEEP_CODE / DEFER / SPLIT) ... → `references/conflict-resolution.md`" (bind-codebase/SKILL.md:104) | false because: zero CONFLICT results
plugins/mega-sdd/skills/resolve-oq/** | condition: "If `conflict > 0` ... route to `resolve-oq`" (bind-codebase/SKILL.md:104) | false because: zero CONFLICT, no resolve-oq hop
plugins/mega-sdd/skills/bind-codebase/references/handoff-validation.md | condition: "the manual binding→units handoff-integrity surface" (bind-codebase/SKILL.md:157) | false because: no manual validate-handoff invocation in this chain
plugins/mega-sdd/references/halt-protocol.md | condition: "This YAML is the canonical halt artifact (for orchestrate-flow consumption)" (bind-codebase/SKILL.md:122) | false because: zero CONFLICT, no halt
plugins/mega-sdd/skills/orchestrate-flow/references/convergence-loops.md | condition: "cycle-eligible halts auto-resolve ... and re-run" (orchestrate-flow/SKILL.md:153) | false because: zero CONFLICT → no cycle-eligible halt
plugins/mega-sdd/skills/orchestrate-flow/references/halt-taxonomy.md | condition: "The full classification of every halt type" (orchestrate-flow/SKILL.md:158) | false because: no halt fires
plugins/mega-sdd/skills/orchestrate-flow/references/sync-digest.md | condition: "Mode D autonomous deferral contracts" (orchestrate-flow/SKILL.md:178) | false because: not the sync lane
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "SKIPPED on express-spine chains" (orchestrate-flow/SKILL.md:92) | false because: express spine
UNCERTAIN:
plugins/mega-sdd/references/multi-prd-lifecycle.md | "read `.mega-sdd/constitution.md` (project-scope locked rules inherited by every vault, per `plugins/mega-sdd/references/multi-prd-lifecycle.md`) if present" (bind-codebase/SKILL.md:51) — scenario does not state whether a project constitution exists
plugins/mega-sdd/skills/generate-units/SKILL.md | "Clean binding → `generate-units <vault>/`" (bind-codebase/SKILL.md:144) — routing-rules:86 renders bind → units as one chain, but the scenario bounds T02 at "binding.md + binding.json written"
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md | "The chain always pre-resolves this on the main thread (`orchestrate-flow/references/handoff-contract.md` renders `mega-sdd:bind-codebase <vault> --auto`)" (bind-codebase/SKILL.md:32)
CHAIN-END: Stops when bind-codebase Step 4.5 has run `stamp-binding-boilerplate.sh` + `derive-binding-json.sh` and Step 5's clean gate produced `<vault>/bound/`; no resolve-oq hop because conflict == 0. Express lane taken (spine default at 91a944a) so the whole scan-codebase skill and the codebase-map load are off-path.

=== T03 ===
INCLUDED:
plugins/mega-sdd/commands/sync.md | commands/sync.md:6 | "Invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--sync`"
plugins/mega-sdd/skills/using-mega-sdd/SKILL.md | using-mega-sdd/SKILL.md:59 | "`/mega-sdd:sync` (→ `orchestrate-flow --sync`) reconciles: incremental re-scan → drift triage → re-bind"
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | commands/sync.md:6 | "Invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--sync`"
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md | orchestrate-flow/SKILL.md:126 | "`--sync`: force the Mode D maintenance chain ... per `references/routing-rules.md` §Mode D"
plugins/mega-sdd/skills/orchestrate-flow/references/sync-digest.md | orchestrate-flow/SKILL.md:178 | "Mode D autonomous deferral contracts: `PENDING-SYNC.md` ... + `SYNC-REPORT.md`"
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | orchestrate-flow/SKILL.md:51 | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/references/model-tiers.md | orchestrate-flow/references/chain-execution.md:78 | "catalog default (read from `plugins/mega-sdd/references/model-tiers.md §Catalog`)"
plugins/mega-sdd/skills/memory/references/routing-outcomes.md | orchestrate-flow/references/chain-execution.md:58 | "Per `memory/references/routing-outcomes.md` (mega-sdd:memory skill) schema"
plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md | orchestrate-flow/SKILL.md:63 | "Predictive preflight per `references/predictive-checks.md` catalog"
plugins/mega-sdd/references/output-language.md | orchestrate-flow/SKILL.md:80 | "Per the keterangan contract (`...output-language.md §Prompt surfaces`)" [SECTION:Prompt surfaces]
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | orchestrate-flow/SKILL.md:86 | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`"
plugins/mega-sdd/skills/orchestrate-flow/references/memory-layer.md | orchestrate-flow/SKILL.md:96 | "Mode D additionally appends the `kind: sync` outcomes row. Protocol: `references/memory-layer.md`"
plugins/mega-sdd/skills/scan-codebase/SKILL.md | orchestrate-flow/references/routing-rules.md:96 | "`scan-codebase --changed-only` (writes `<vault>/.sync-changed-paths.txt`"
plugins/mega-sdd/skills/scan-codebase/references/scan-procedure.md | scan-codebase/SKILL.md:39 | "Incremental mode (`--changed-only` ...) is specified at the top of `references/scan-procedure.md`"
plugins/mega-sdd/skills/scan-codebase/references/exclusions.md | scan-codebase/SKILL.md:39 | "The full default exclusion list, the override flags ... live in `references/exclusions.md`"
plugins/mega-sdd/skills/scan-codebase/references/halts-flags-handoff.md | scan-codebase/SKILL.md:39 | "The complete flag catalog is in `references/halts-flags-handoff.md`"
plugins/mega-sdd/skills/scan-codebase/references/codebase-map-schema.md | scan-codebase/SKILL.md:43 | "Section schema ... is defined in `references/codebase-map-schema.md`"
plugins/mega-sdd/skills/scan-codebase/references/tree-sitter-integration.md | scan-codebase/SKILL.md:47 | "Tree-sitter query usage, precision tiers, and graceful regex fallback are in `references/tree-sitter-integration.md`"
plugins/mega-sdd/skills/scan-codebase/references/deep-scan-gate.md | scan-codebase/SKILL.md:64 | "`references/deep-scan-gate.md` (always load first — trigger check, per-slice cache check"
plugins/mega-sdd/skills/memory/references/memory-schema.md | scan-codebase/SKILL.md:89 | "participates in the mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`"
plugins/mega-sdd/skills/detect-drift/SKILL.md | orchestrate-flow/references/routing-rules.md:96 | "`detect-drift --scope=@<vault>/.sync-changed-paths.txt` (scoped to those changed paths"
plugins/mega-sdd/skills/detect-drift/references/report-format.md | detect-drift/SKILL.md:64 | "Full report structure, section ordering ... are in `references/report-format.md`"
plugins/mega-sdd/skills/detect-drift/references/auto-and-chain.md | detect-drift/SKILL.md:52 | "The `drift_inputs_missing` blocker shape is in `references/auto-and-chain.md`"
plugins/mega-sdd/skills/bind-codebase/SKILL.md | orchestrate-flow/references/routing-rules.md:96 | "`bind-codebase --paths=@<vault>/.sync-changed-paths.txt`"
plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md | bind-codebase/SKILL.md:28 | "everything else carried forward per `references/binding-contract.md §Claim-scoped re-bind`"
plugins/mega-sdd/skills/bind-codebase/references/express-bind.md | orchestrate-flow/SKILL.md:128 | "appends `--express` to every `bind-codebase` hop"
plugins/mega-sdd/skills/bind-codebase/references/implementation-state.md | bind-codebase/SKILL.md:66 | "2.5 Implementation-state classification → ... `references/implementation-state.md`"
plugins/mega-sdd/skills/bind-codebase/references/oq-resolution.md | bind-codebase/SKILL.md:67 | "2.6 Tech-OQ auto-resolution (scan) + 2.7 recommendation surfacing → ... `references/oq-resolution.md`"
plugins/mega-sdd/skills/bind-codebase/references/hard-rules-and-packs.md | bind-codebase/SKILL.md:68 | "2.8 Framework-convention pack load + 2.9 Suggested Unit Hard Rules → ..."
plugins/mega-sdd/skills/bind-codebase/references/constitution-and-oq.md | bind-codebase/SKILL.md:69 | "2.10 Constitution-aware CONFLICT surfacing → ... `references/constitution-and-oq.md`"
plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md | bind-codebase/SKILL.md:72 | "Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (binding focus)"
plugins/mega-sdd/skills/bind-codebase/references/binding-md-template.md | bind-codebase/SKILL.md:80 | "**4. Write `binding.md`** using the template in `references/binding-md-template.md`"
plugins/mega-sdd/skills/bind-codebase/references/binding-json-schema.md | bind-codebase/SKILL.md:82 | "derive `binding.json` ...; schema → `references/binding-json-schema.md`"
plugins/mega-sdd/skills/bind-codebase/references/auto-memory-handoff.md | bind-codebase/SKILL.md:124 | "→ `references/auto-memory-handoff.md`"
plugins/mega-sdd/references/paths.md | bind-codebase/SKILL.md:36 | "DIRECT CHILD of `<project-root>/.mega-sdd/vaults/` ... (`plugins/mega-sdd/references/paths.md`)"
EXCLUDED:
plugins/mega-sdd/skills/scan-codebase/references/deep-scan-dispatch.md | condition: "load ONLY when the gate's cache check yields non-empty `stale_slices`" (scan-codebase/SKILL.md:64) | false because: 2 changed files intersect no binding anchor / no starterkit slice → cache full hit
plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md | condition: "the five deep-scan subagent prompt templates" (scan-codebase/SKILL.md:96) | false because: no stale slices → no dispatch
plugins/mega-sdd/skills/resolve-oq/** | condition: "`resolve-oq` ONLY if the drift walkthrough CREATED an `OQ-DC-N` stub" (routing-rules.md:96) | false because: no intersection → no drift finding → no OQ-DC stub
plugins/mega-sdd/skills/detect-drift/references/constitution-drift.md | condition: "when `<vault>/constitution.md` exists" (detect-drift/SKILL.md:101) | false because: constitution-bearing path not signalled by the scenario state
plugins/mega-sdd/skills/bind-codebase/references/conflict-resolution.md | condition: "Per-conflict recovery ... → `references/conflict-resolution.md`" (bind-codebase/SKILL.md:104) | false because: no intersecting claim → no CONFLICT
plugins/mega-sdd/skills/orchestrate-flow/references/convergence-loops.md | condition: "cycle-eligible halts auto-resolve" (orchestrate-flow/SKILL.md:153) | false because: no halt
plugins/mega-sdd/skills/orchestrate-flow/references/halt-taxonomy.md | condition: "full classification of every halt type" (orchestrate-flow/SKILL.md:158) | false because: no halt
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "SKIPPED on express-spine chains" (orchestrate-flow/SKILL.md:92) | false because: express spine
UNCERTAIN:
plugins/mega-sdd/skills/generate-units/SKILL.md (+ its --reconcile refs) | "`bind-codebase --paths=@...` → `generate-units --reconcile` → `execute-bolts` (stale/new units only)" (routing-rules.md:96) — the 6.1.1 Mode D row continues past re-bind; the spec bounds the comparable T04 chain at re-bind
plugins/mega-sdd/skills/scan-codebase/references/deep-scan-gate.md | "always load first" vs "Trigger: framework confidence high/medium → run" (scan-codebase/SKILL.md:64,66) — load is unconditional only once Step 10.5 is entered
CHAIN-END: NO short-circuit exists at 91a944a — commands/sync.md:34 only stops on "No change signal detected", and 2 changed files ARE a change signal, so the full Mode D hop chain (scan --changed-only → detect-drift --scope → bind --paths) runs even with zero intersection. Trace bounded at re-bind complete for parity with T04. detect-drift carries `context: fork` (SKILL.md:4), so its SKILL+refs land in a forked window; counted here because the scenario names the segment.

=== T04 ===
INCLUDED:
plugins/mega-sdd/commands/sync.md | commands/sync.md:6 | "Invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--sync`"
plugins/mega-sdd/skills/using-mega-sdd/SKILL.md | using-mega-sdd/SKILL.md:59 | "`/mega-sdd:sync` (→ `orchestrate-flow --sync`) reconciles: incremental re-scan → drift triage → re-bind"
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | commands/sync.md:6 | "Invoke the `mega-sdd:orchestrate-flow` skill ... with `--sync`"
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md | orchestrate-flow/SKILL.md:126 | "`--sync`: force the Mode D maintenance chain ... per `references/routing-rules.md` §Mode D"
plugins/mega-sdd/skills/orchestrate-flow/references/sync-digest.md | orchestrate-flow/SKILL.md:178 | "Mode D autonomous deferral contracts: `PENDING-SYNC.md` ... + `SYNC-REPORT.md`"
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | orchestrate-flow/SKILL.md:51 | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/references/model-tiers.md | orchestrate-flow/references/chain-execution.md:78 | "catalog default (read from `plugins/mega-sdd/references/model-tiers.md §Catalog`)"
plugins/mega-sdd/skills/memory/references/routing-outcomes.md | orchestrate-flow/references/chain-execution.md:58 | "Per `memory/references/routing-outcomes.md` (mega-sdd:memory skill) schema"
plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md | orchestrate-flow/SKILL.md:63 | "Predictive preflight per `references/predictive-checks.md` catalog"
plugins/mega-sdd/references/output-language.md | orchestrate-flow/SKILL.md:80 | "Per the keterangan contract (`...output-language.md §Prompt surfaces`)" [SECTION:Prompt surfaces]
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | orchestrate-flow/SKILL.md:86 | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`"
plugins/mega-sdd/skills/orchestrate-flow/references/memory-layer.md | orchestrate-flow/SKILL.md:96 | "Mode D additionally appends the `kind: sync` outcomes row. Protocol: `references/memory-layer.md`"
plugins/mega-sdd/skills/scan-codebase/SKILL.md | orchestrate-flow/references/routing-rules.md:96 | "`scan-codebase --changed-only` (writes `<vault>/.sync-changed-paths.txt`"
plugins/mega-sdd/skills/scan-codebase/references/scan-procedure.md | scan-codebase/SKILL.md:39 | "Incremental mode (`--changed-only` ...) is specified at the top of `references/scan-procedure.md`"
plugins/mega-sdd/skills/scan-codebase/references/exclusions.md | scan-codebase/SKILL.md:39 | "The full default exclusion list, the override flags ... live in `references/exclusions.md`"
plugins/mega-sdd/skills/scan-codebase/references/halts-flags-handoff.md | scan-codebase/SKILL.md:39 | "The complete flag catalog is in `references/halts-flags-handoff.md`"
plugins/mega-sdd/skills/scan-codebase/references/codebase-map-schema.md | scan-codebase/SKILL.md:43 | "Section schema ... is defined in `references/codebase-map-schema.md`"
plugins/mega-sdd/skills/scan-codebase/references/tree-sitter-integration.md | scan-codebase/SKILL.md:47 | "Tree-sitter query usage, precision tiers, and graceful regex fallback are in ..."
plugins/mega-sdd/skills/scan-codebase/references/deep-scan-gate.md | scan-codebase/SKILL.md:64 | "`references/deep-scan-gate.md` (always load first — trigger check, per-slice cache check"
plugins/mega-sdd/skills/memory/references/memory-schema.md | scan-codebase/SKILL.md:89 | "participates in the mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`"
plugins/mega-sdd/skills/detect-drift/SKILL.md | orchestrate-flow/references/routing-rules.md:96 | "`detect-drift --scope=@<vault>/.sync-changed-paths.txt` (scoped to those changed paths"
plugins/mega-sdd/skills/detect-drift/references/report-format.md | detect-drift/SKILL.md:64 | "Full report structure, section ordering ... are in `references/report-format.md`"
plugins/mega-sdd/skills/detect-drift/references/auto-and-chain.md | detect-drift/SKILL.md:52 | "The `drift_inputs_missing` blocker shape is in `references/auto-and-chain.md`"
plugins/mega-sdd/skills/memory/references/memory-schema.md [SECTION:drift-history] | detect-drift/SKILL.md:72 | "Schema: `memory/references/memory-schema.md §drift-history`"
plugins/mega-sdd/skills/bind-codebase/SKILL.md | orchestrate-flow/references/routing-rules.md:96 | "`bind-codebase --paths=@<vault>/.sync-changed-paths.txt`"
plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md | bind-codebase/SKILL.md:28 | "everything else carried forward per `references/binding-contract.md §Claim-scoped re-bind`"
plugins/mega-sdd/skills/bind-codebase/references/express-bind.md | bind-codebase/SKILL.md:28 | "`--paths` composition ... `--express` selects HOW the affected set retrieves evidence"
plugins/mega-sdd/skills/bind-codebase/references/implementation-state.md | bind-codebase/SKILL.md:66 | "2.5 Implementation-state classification → ... `references/implementation-state.md`"
plugins/mega-sdd/skills/bind-codebase/references/oq-resolution.md | bind-codebase/SKILL.md:67 | "2.6 Tech-OQ auto-resolution (scan) + 2.7 recommendation surfacing → ..."
plugins/mega-sdd/skills/bind-codebase/references/hard-rules-and-packs.md | bind-codebase/SKILL.md:68 | "2.8 Framework-convention pack load + 2.9 Suggested Unit Hard Rules → ..."
plugins/mega-sdd/skills/bind-codebase/references/constitution-and-oq.md | bind-codebase/SKILL.md:69 | "2.10 Constitution-aware CONFLICT surfacing → ... `references/constitution-and-oq.md`"
plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md | bind-codebase/SKILL.md:72 | "Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (binding focus)"
plugins/mega-sdd/references/advisor-findings-schema.md | bind-codebase/SKILL.md:76 | "Full focus + materialization → ... + `plugins/mega-sdd/references/advisor-findings-schema.md`"
plugins/mega-sdd/skills/bind-codebase/references/binding-md-template.md | bind-codebase/SKILL.md:80 | "**4. Write `binding.md`** using the template in `references/binding-md-template.md`"
plugins/mega-sdd/skills/bind-codebase/references/binding-json-schema.md | bind-codebase/SKILL.md:82 | "derive `binding.json` ...; schema → `references/binding-json-schema.md`"
plugins/mega-sdd/skills/bind-codebase/references/auto-memory-handoff.md | bind-codebase/SKILL.md:124 | "→ `references/auto-memory-handoff.md`"
plugins/mega-sdd/references/paths.md | bind-codebase/SKILL.md:36 | "DIRECT CHILD of `<project-root>/.mega-sdd/vaults/` ... (`plugins/mega-sdd/references/paths.md`)"
EXCLUDED:
plugins/mega-sdd/skills/resolve-oq/** | condition: "`resolve-oq` ONLY if the drift walkthrough CREATED an `OQ-DC-N` stub" (routing-rules.md:96) | false because: zero CONFLICT results, no OQ-DC stub stated
plugins/mega-sdd/skills/bind-codebase/references/conflict-resolution.md | condition: "Per-conflict recovery (KEEP_VAULT / KEEP_CODE / DEFER / SPLIT)" (bind-codebase/SKILL.md:104) | false because: zero CONFLICT results
plugins/mega-sdd/references/halt-protocol.md | condition: "emit the `bind_conflict` halt YAML (below), route to `resolve-oq`" (bind-codebase/SKILL.md:104) | false because: conflict == 0
plugins/mega-sdd/skills/orchestrate-flow/references/convergence-loops.md | condition: "cycle-eligible halts auto-resolve ... and re-run" (orchestrate-flow/SKILL.md:153) | false because: no halt
plugins/mega-sdd/skills/orchestrate-flow/references/halt-taxonomy.md | condition: "full classification of every halt type" (orchestrate-flow/SKILL.md:158) | false because: no halt
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "SKIPPED on express-spine chains" (orchestrate-flow/SKILL.md:92) | false because: express spine
plugins/mega-sdd/skills/detect-drift/references/constitution-drift.md | condition: "when `<vault>/constitution.md` exists" (detect-drift/SKILL.md:101) | false because: scenario does not place a vault constitution on the path
UNCERTAIN:
plugins/mega-sdd/skills/scan-codebase/references/deep-scan-dispatch.md | "load ONLY when the gate's cache check yields non-empty `stale_slices`" (scan-codebase/SKILL.md:64) — 1 changed file matches a binding anchor; whether it also dirties an auth/ui_ux/libs slice is unstated
plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md | "Subagent prompt templates are in `references/deep-scan-prompts.md`" (scan-codebase/SKILL.md:64) — same condition as deep-scan-dispatch.md
plugins/mega-sdd/skills/generate-units/SKILL.md | "`bind-codebase --paths=@...` → `generate-units --reconcile` → `execute-bolts`" (routing-rules.md:96) — Mode D row continues past re-bind; spec bounds T04 at "re-bind complete"
CHAIN-END: Stops when the claim-scoped `bind-codebase --paths --express` re-bind writes binding.md + binding.json with zero CONFLICT. Same hop set as T03 in this arm (no intersect short-circuit exists at 91a944a); the only structural delta vs T03 is the deep-scan-dispatch/prompts UNCERTAIN pair and the drift-history memory write reached by an actual finding.

=== T05 ===
INCLUDED:
plugins/mega-sdd/skills/using-mega-sdd/SKILL.md | using-mega-sdd/SKILL.md:55 | "Side lanes (as needed): `resolve-oq` (OQ walk)"
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | using-mega-sdd/SKILL.md:25 | "invoke the skill via the `Skill` tool (default route when unsure: `orchestrate-flow`)"
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md | orchestrate-flow/SKILL.md:25 | "apply the decision table per `references/routing-rules.md §CWD inspection`"
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | orchestrate-flow/SKILL.md:51 | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/references/model-tiers.md | orchestrate-flow/references/chain-execution.md:78 | "catalog default (read from `plugins/mega-sdd/references/model-tiers.md §Catalog`)"
plugins/mega-sdd/skills/memory/references/routing-outcomes.md | orchestrate-flow/references/chain-execution.md:58 | "Per `memory/references/routing-outcomes.md` (mega-sdd:memory skill) schema"
plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md | orchestrate-flow/SKILL.md:63 | "Predictive preflight per `references/predictive-checks.md` catalog"
plugins/mega-sdd/references/output-language.md | orchestrate-flow/SKILL.md:80 | "Per the keterangan contract (`...output-language.md §Prompt surfaces`)" [SECTION:Prompt surfaces]
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | orchestrate-flow/SKILL.md:86 | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`"
plugins/mega-sdd/skills/orchestrate-flow/references/memory-layer.md | orchestrate-flow/SKILL.md:96 | "Protocol: `references/memory-layer.md §Chain end`"
plugins/mega-sdd/skills/resolve-oq/SKILL.md | orchestrate-flow/references/routing-rules.md:50 | "`oq_gate` | unresolved blocking-tier OQs ... | `resolve-oq`"
plugins/mega-sdd/skills/resolve-oq/references/interactive-walk.md | resolve-oq/SKILL.md:45 | "Full per-step procedure, display formats, templates ... load it before running the walk"
plugins/mega-sdd/skills/resolve-oq/references/recommendation-context.md | resolve-oq/SKILL.md:87 | "context-aware `(recommended)` answers per OQ: source priority ... citation probe"
plugins/mega-sdd/skills/resolve-oq/references/auto-memory-handoff.md | resolve-oq/SKILL.md:88 | "the `--auto` interactive-vs-auto step table, the memory layer reads/writes ... handoff YAML"
plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | resolve-oq/SKILL.md:92 | "OQ conventions, status-marker semantics, the `defer_to` field, and `vault.json` field + concurrency rules"
plugins/mega-sdd/skills/memory/references/memory-schema.md | resolve-oq/SKILL.md:92 | "Memory schema + scope architecture: `../memory/references/memory-schema.md`"
plugins/mega-sdd/skills/memory/references/learning-rules.md | resolve-oq/SKILL.md:92 | "Self-learning thresholds + rollback path: `../memory/references/learning-rules.md`"
EXCLUDED:
plugins/mega-sdd/skills/resolve-oq/references/binding-mode.md | condition: "the `--binding <binding.md>` flow: CONFLICT detail-block walk" (resolve-oq/SKILL.md:86) | false because: intent mode, not --binding
plugins/mega-sdd/skills/bind-codebase/** | condition: "If any OQs deferred to binding → suggest `scan-codebase && bind-codebase`" (resolve-oq/SKILL.md:61) | false because: full walk of 3 OQs, no halts, no deferrals stated
plugins/mega-sdd/skills/orchestrate-flow/references/convergence-loops.md | condition: "cycle-eligible halts auto-resolve" (orchestrate-flow/SKILL.md:153) | false because: no halts
plugins/mega-sdd/skills/orchestrate-flow/references/halt-taxonomy.md | condition: "full classification of every halt type" (orchestrate-flow/SKILL.md:158) | false because: no halts
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "SKIPPED on express-spine chains" (orchestrate-flow/SKILL.md:92) | false because: express spine default
plugins/mega-sdd/skills/orchestrate-flow/references/sync-digest.md | condition: "Mode D autonomous deferral contracts" (orchestrate-flow/SKILL.md:178) | false because: not the sync lane
UNCERTAIN:
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md | "Propagate validated handoff metadata to the next skill" (orchestrate-flow/SKILL.md:87) — producer schema pointer, not named as a step-time read on this one-hop chain
plugins/mega-sdd/skills/resolve-oq/references/interactive-walk.md [SECTION:Step 2b] | "All four are collected in ONE `AskUserQuestion` per OQ (shape + slots: `references/interactive-walk.md` Step 2b, which is canonical)" (resolve-oq/SKILL.md:27) — whole-file already INCLUDED via SKILL.md:45; noted so a section-only reading is not double-counted
CHAIN-END: Stops after resolve-oq Step 5 presents the round summary (3 OQs walked, version bumped, Changelog appended, `derive-vault-json.sh` run per OQ). Scenario states "no halts", so no re-entry into bind or the convergence loop. Note resolve-oq Step 0.6's express `--auto` batched branch (SKILL.md:51) is NOT taken here because the scenario dictates a "full walk of 3 OQs".

=== T06 ===
INCLUDED:
plugins/mega-sdd/skills/using-mega-sdd/SKILL.md | using-mega-sdd/SKILL.md:57 | "`emit-fsd`/`emit-prd`/`emit-sit`/`emit-uat` ... each carry their own trigger census"
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | using-mega-sdd/SKILL.md:25 | "invoke the skill via the `Skill` tool (default route when unsure: `orchestrate-flow`)"
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md | orchestrate-flow/SKILL.md:25 | "apply the decision table per `references/routing-rules.md §CWD inspection`"
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | orchestrate-flow/SKILL.md:51 | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/references/model-tiers.md | orchestrate-flow/references/chain-execution.md:78 | "catalog default (read from `plugins/mega-sdd/references/model-tiers.md §Catalog`)"
plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md | emit-fsd/SKILL.md:50 | "Full preflight catalog: `mega-sdd:orchestrate-flow/references/predictive-checks.md` §emit-fsd preflight checks" [SECTION:emit-fsd preflight checks]
plugins/mega-sdd/references/output-language.md | orchestrate-flow/SKILL.md:80 | "Per the keterangan contract (`...output-language.md §Prompt surfaces`)" [SECTION:Prompt surfaces]
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | orchestrate-flow/SKILL.md:86 | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`"
plugins/mega-sdd/skills/orchestrate-flow/references/memory-layer.md | orchestrate-flow/SKILL.md:96 | "Protocol: `references/memory-layer.md §Chain end`"
plugins/mega-sdd/skills/emit-fsd/SKILL.md | using-mega-sdd/SKILL.md:57 | "`emit-fsd` ... via `/mega-sdd:emit`"
plugins/mega-sdd/references/paths.md | emit-fsd/SKILL.md:24 | "defaults to first vault detected via `plugins/mega-sdd/references/paths.md` priority order"
plugins/mega-sdd/references/output-language.md | emit-fsd/SKILL.md:11 | "Tier-1 structural tokens stay English. Full rules → `plugins/mega-sdd/references/output-language.md`"
EXCLUDED:
plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md | condition: "the deterministic builder that executes `references/section-mapping.md` §1–§10 end-to-end" (emit-fsd/SKILL.md:56) | false because: consumed by `build-fsd-core.sh`, not the model (spec rule 3)
plugins/mega-sdd/skills/emit-fsd/references/fsd-template.md | condition: "the fenced skeletons are parsed from `references/fsd-template.md` at run time" (emit-fsd/SKILL.md:56) | false because: script-parsed, not a model context load (spec rule 3)
plugins/mega-sdd/skills/emit-fsd/references/styling-config.yaml | condition: "`FSD.styling.yaml` seeded from `references/styling-config.yaml` when absent" (emit-fsd/SKILL.md:56) | false because: seeded by the builder script
plugins/mega-sdd/references/halt-protocol.md | condition: "If ANY match found → emit halt `quality_gate_failed`" (emit-fsd/SKILL.md:72) | false because: PDF renders OK, no unfilled slots, no halt
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "SKIPPED on express-spine chains" (orchestrate-flow/SKILL.md:92) | false because: express spine default
plugins/mega-sdd/skills/orchestrate-flow/references/convergence-loops.md | condition: "cycle-eligible halts auto-resolve" (orchestrate-flow/SKILL.md:153) | false because: no halt
plugins/mega-sdd/skills/orchestrate-flow/references/halt-taxonomy.md | condition: "full classification of every halt type" (orchestrate-flow/SKILL.md:158) | false because: no halt
plugins/mega-sdd/skills/memory/references/memory-schema.md | condition: "emit-fsd does NOT participate in mega-sdd memory layer (no reads, no writes)" (emit-fsd/SKILL.md:190) | false because: skill is memory-exempt by contract
UNCERTAIN:
plugins/mega-sdd/references/emission-engine.md | "`plugins/mega-sdd/references/emission-engine.md` owns the doc-agnostic spine ... The Steps below remain the OPERATIVE wording for the FSD lane" (emit-fsd/SKILL.md:13)
plugins/mega-sdd/references/mermaid-emission-rules.md | "mermaid blocks render as code, not diagrams — a quality drop, since mermaid-flows is a hard rule" (emit-fsd/SKILL.md:48) — rule named but no file pointer on the executed path
CHAIN-END: Stops after emit-fsd Step 8 emits the chat summary (FSD.md + FSD.pdf + .citation-map.json + FSD.styling.yaml written). Confirms the honesty check: the FSD lane at 6.1.1 is already script-dominated (`build-fsd-core.sh`, `build-citation-map.sh`, `md2pdf.sh`, `refresh-doc-stamps.sh`), so almost nothing beyond SKILL.md + router overhead is a model-side load — ≈0 delta expected against the optimized arm.

=== T07 ===
INCLUDED:
plugins/mega-sdd/skills/using-mega-sdd/SKILL.md | using-mega-sdd/SKILL.md:21 | "**Any SDD lane phrase → the `/mega-sdd` front door**"
plugins/mega-sdd/commands/mega-sdd.md | using-mega-sdd/SKILL.md:21 | "the `/mega-sdd` front door — status view + next-chain proposal + one confirmation"
plugins/mega-sdd/references/multi-prd-lifecycle.md | using-mega-sdd/SKILL.md:61 | "route a NEW doc by what changed, never guess (full contract → `...multi-prd-lifecycle.md`)"
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | commands/mega-sdd.md:25 | "invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--deep --auto`"
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md | orchestrate-flow/SKILL.md:25 | "apply the decision table per `references/routing-rules.md §CWD inspection`"
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | orchestrate-flow/SKILL.md:51 | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/references/model-tiers.md | orchestrate-flow/references/chain-execution.md:78 | "catalog default (read from `plugins/mega-sdd/references/model-tiers.md §Catalog`)"
plugins/mega-sdd/skills/memory/references/routing-outcomes.md | orchestrate-flow/references/chain-execution.md:58 | "Per `memory/references/routing-outcomes.md` (mega-sdd:memory skill) schema"
plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md | orchestrate-flow/SKILL.md:63 | "Predictive preflight per `references/predictive-checks.md` catalog"
plugins/mega-sdd/references/output-language.md | orchestrate-flow/SKILL.md:80 | "Per the keterangan contract (`...output-language.md §Prompt surfaces`)" [SECTION:Prompt surfaces]
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | orchestrate-flow/SKILL.md:86 | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`"
plugins/mega-sdd/skills/orchestrate-flow/references/memory-layer.md | orchestrate-flow/SKILL.md:96 | "Protocol: `references/memory-layer.md §Chain end`"
plugins/mega-sdd/skills/generate-intent/SKILL.md | using-mega-sdd/SKILL.md:63 | "**New epic** on top of shipped work → **new vault** via `generate-intent`"
plugins/mega-sdd/skills/generate-intent/references/from-prompt-mode.md | generate-intent/SKILL.md:47 | "**Mode B — free-text brief** ... Procedure → `references/from-prompt-mode.md`"
plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | generate-intent/SKILL.md:50 | "All three modes share the SAME vault contract (`references/vault-contract.md`)"
plugins/mega-sdd/skills/generate-intent/references/setup-flow.md | generate-intent/SKILL.md:127 | "Full procedures, runtime ordering note ... → `references/setup-flow.md`"
plugins/mega-sdd/skills/generate-intent/references/detection-and-shapes.md | generate-intent/SKILL.md:67 | "Edge cases (quoted single word, looks-like-path-but-missing, bare single word ...) → `references/detection-and-shapes.md`"
plugins/mega-sdd/skills/generate-intent/references/generation-guide.md | generate-intent/SKILL.md:130 | "**Step 3 — Generate the 7 files** into `<OUTPUT_DIR>`, per `references/generation-guide.md`"
plugins/mega-sdd/skills/generate-intent/references/advisor-checklist.md | generate-intent/SKILL.md:133 | "Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (intent focus)"
plugins/mega-sdd/references/advisor-findings-schema.md | generate-intent/SKILL.md:138 | "Focus + materialization → `references/advisor-checklist.md` + `...advisor-findings-schema.md`"
plugins/mega-sdd/skills/generate-intent/references/self-check.md | generate-intent/SKILL.md:140 | "Full anti-halu + readability + output-mode + `vault.json` integrity checklist → `references/self-check.md`"
plugins/mega-sdd/skills/generate-intent/references/auto-and-handoff.md | generate-intent/SKILL.md:79 | "`--auto` | Skip logistical prompts (set by orchestrate-flow) ... `references/auto-and-handoff.md`"
plugins/mega-sdd/skills/generate-intent/references/templates/00-index.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-intent/references/templates/01-overview.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-intent/references/templates/02-architecture.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-intent/references/templates/03-data-model.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-intent/references/templates/04-flows.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-intent/references/templates/05-decisions.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/generate-intent/references/templates/06-constraints.md | generate-intent/SKILL.md:182 | "Read the relevant template before drafting"
plugins/mega-sdd/skills/bind-codebase/SKILL.md | using-mega-sdd/SKILL.md:63 | "then `bind-codebase` **brownfield** against the codebase that now contains PRD 1"
plugins/mega-sdd/skills/bind-codebase/references/express-bind.md | orchestrate-flow/SKILL.md:128 | "appends `--express` to every `bind-codebase` hop"
plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md | bind-codebase/SKILL.md:49 | "**2. Per claim, produce a verdict** (per `references/binding-contract.md`)"
plugins/mega-sdd/skills/bind-codebase/references/implementation-state.md | bind-codebase/SKILL.md:66 | "2.5 Implementation-state classification → ... `references/implementation-state.md`"
plugins/mega-sdd/skills/bind-codebase/references/oq-resolution.md | bind-codebase/SKILL.md:67 | "2.6 Tech-OQ auto-resolution (scan) + 2.7 recommendation surfacing → ..."
plugins/mega-sdd/skills/bind-codebase/references/hard-rules-and-packs.md | bind-codebase/SKILL.md:68 | "2.8 Framework-convention pack load + 2.9 Suggested Unit Hard Rules → ..."
plugins/mega-sdd/skills/bind-codebase/references/constitution-and-oq.md | bind-codebase/SKILL.md:69 | "2.10 Constitution-aware CONFLICT surfacing → ..."
plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md | bind-codebase/SKILL.md:72 | "Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (binding focus)"
plugins/mega-sdd/skills/bind-codebase/references/binding-md-template.md | bind-codebase/SKILL.md:80 | "**4. Write `binding.md`** using the template in `references/binding-md-template.md`"
plugins/mega-sdd/skills/bind-codebase/references/binding-json-schema.md | bind-codebase/SKILL.md:82 | "derive `binding.json` ...; schema → `references/binding-json-schema.md`"
plugins/mega-sdd/skills/bind-codebase/references/auto-memory-handoff.md | bind-codebase/SKILL.md:124 | "→ `references/auto-memory-handoff.md`"
plugins/mega-sdd/references/paths.md | bind-codebase/SKILL.md:36 | "DIRECT CHILD of `<project-root>/.mega-sdd/vaults/` ... (`plugins/mega-sdd/references/paths.md`)"
EXCLUDED:
plugins/mega-sdd/skills/diff-vault/** | condition: "Same source **revised** (PRD v1 → v1.1) → `diff-vault` (one vault evolves)" (using-mega-sdd/SKILL.md:62) | false because: free-text chat delta, no revised PRD/BRD/Figma FILE exists to diff against
plugins/mega-sdd/skills/generate-intent/references/kb-submode.md | condition: "`--kb=<path>` | Mode B KB sub-mode" (generate-intent/SKILL.md:74) | false because: no KB
plugins/mega-sdd/skills/generate-intent/references/multi-scope.md | condition: "load when the PRD declares a `scopes:` block or `--scope=<id>` is passed" (generate-intent/SKILL.md:171) | false because: free-text brief, no scopes block
plugins/mega-sdd/skills/generate-intent/references/scope-picker.md | condition: "used by Step 0.9" (generate-intent/SKILL.md:179) | false because: no multi-scope PRD
plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md | condition: "the AI subagent prompt for the legacy-PRD scope retrofit bridge" (generate-intent/SKILL.md:180) | false because: no legacy PRD retrofit
plugins/mega-sdd/skills/scan-codebase/** | condition: "under express the scan hop and any `--scan=` argument are dropped" (routing-rules.md:64) | false because: express spine default
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "SKIPPED on express-spine chains" (orchestrate-flow/SKILL.md:92) | false because: express spine
UNCERTAIN:
ROUTING FORK (generate-intent Mode B vs diff-vault) | "A NEW PRD/BRD/Figma/brief → multi-PRD routing (revise vs new epic); **when unsure, ASK**" (using-mega-sdd/SKILL.md:21) — a bare chat sentence matches neither the `prd_revision` probe (routing-rules.md:51, needs a PRD FILE newer than the vault) nor a clean `new epic` doc; 6.1.1 has no chat-delta row, so the branch is genuinely ambiguous
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md | "producer schema in `references/handoff-contract.md`" (orchestrate-flow/SKILL.md:60)
plugins/mega-sdd/skills/generate-units/SKILL.md + refs | "then `bind-codebase` **brownfield** ... the binding gate catches contradictions with shipped reality" (using-mega-sdd/SKILL.md:63) — the full re-vault chain continues to units/bolts; the scenario bounds the trace at "re-vault → diff-vault or bind"
plugins/mega-sdd/skills/generate-intent/references/squad-partition.md | "squad partition (single vs ≥2)" (generate-intent/SKILL.md:127)
CHAIN-END: Traced as the full re-vault path the spec dictates: front door → orchestrate-flow → generate-intent (Mode B `--from-prompt`, Rule 4 of the detection table at generate-intent/SKILL.md:62 — the sentence contains whitespace and no path separator) → bind-codebase `--express`. NEGATIVE CONTROL CONFIRMED: 91a944a has no cheap chat-delta lane — a one-field request re-enters the entire 7-file vault contract plus a full claim re-bind. ≈0 delta expected because nothing on this path was a P1–P4 target.

=== T08 ===
INCLUDED:
plugins/mega-sdd/skills/detect-drift/SKILL.md | orchestrate-flow/SKILL.md:92 | "the DEFAULT-ON hybrid `detect-drift` gate after `execute-bolts`"
plugins/mega-sdd/skills/detect-drift/references/report-format.md | detect-drift/SKILL.md:64 | "Full report structure, section ordering ... are in **`references/report-format.md`**"
plugins/mega-sdd/skills/detect-drift/references/auto-and-chain.md | detect-drift/SKILL.md:52 | "The `drift_inputs_missing` blocker shape is in `references/auto-and-chain.md`"
plugins/mega-sdd/skills/detect-drift/references/report-format.md [SECTION:Vault write-back protocol] | detect-drift/SKILL.md:70 | "Boundary rules → `references/report-format.md §Vault write-back protocol`"
plugins/mega-sdd/skills/memory/references/memory-schema.md [SECTION:drift-history] | detect-drift/SKILL.md:72 | "Schema: `memory/references/memory-schema.md §drift-history`"
plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | detect-drift/SKILL.md:106 | "OQ conventions + `vault.json` field rules: `generate-intent/references/vault-contract.md`"
EXCLUDED:
plugins/mega-sdd/skills/detect-drift/references/constitution-drift.md | condition: "when `<vault>/constitution.md` exists, validate code against constitution clauses (§A–§F)" (detect-drift/SKILL.md:101) | false because: T01-class runs in this benchmark set state "constitution absent"; see UNCERTAIN for the unstated-state caveat
plugins/mega-sdd/skills/orchestrate-flow/** | condition: "Count only the detect-drift segment (execute-bolts context already counted in T01-class runs)" (bench-scenarios.md:30) | false because: scenario scopes the trace to the detect-drift segment only — no router overhead per spec rule 6
plugins/mega-sdd/skills/scan-codebase/** | condition: "REUSE FIRST: when `.mega-sdd/codebase/codebase-map.md` exists with a §7 Framework block" (detect-drift/SKILL.md:58) | false because: standalone post-bolt gate, no scan hop; framework falls to manifest detect
plugins/mega-sdd/skills/resolve-oq/** | condition: "A human resolves the queue later via `resolve-oq` / `sync`" (detect-drift/SKILL.md:66) | false because: zero drift found → nothing queued to PENDING-SYNC.md
plugins/mega-sdd/references/halt-protocol.md | condition: "emit the `drift_framework_mismatch` blocker" (detect-drift/SKILL.md:58) | false because: zero drift, next_action null, no blocker
UNCERTAIN:
plugins/mega-sdd/skills/detect-drift/references/constitution-drift.md | "when `<vault>/constitution.md` exists, validate code against constitution clauses (§A–§F), the `constitution_drift_detected` halt" (detect-drift/SKILL.md:101) — T08's own state line does not say whether a vault constitution exists; excluded above on the T01-class default, flagged here per rule 7
plugins/mega-sdd/references/shared-snapshot-schema.md | "The auto-gate path uses snapshot reuse per `plugins/mega-sdd/references/shared-snapshot-schema.md`" (orchestrate-flow/references/chain-execution.md:233) — named on the orchestrator side of the gate, which T08 scopes out, but it governs this segment's snapshot input
CHAIN-END: Stops at detect-drift Step 8 (summary presented: 0 findings, DRIFT-REPORT.md written, PENDING-SYNC.md untouched, `next_action: null`). Drift-axis `--scope` here is the Step 0.5 DRIFT_SCOPE selector, NOT the sync lane's `--scope=@<vault>/.sync-changed-paths.txt` (detect-drift/SKILL.md:50), so no sync-lane path-list read occurs. IMPORTANT: detect-drift declares `context: fork` (detect-drift/SKILL.md:4), so under spec rule 4 this entire segment lands in a FORKED subagent window, not the main session — counted here only because the scenario names the segment explicitly.
