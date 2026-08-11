# Raw context-trace report — optimized arm

Produced by a blind read-only tracer agent against the a09e430 tree. UNCERTAIN entries were
adjudicated per ../../tasks/ADJUDICATION.md and cross-arm harmonized per
../../tasks/HARMONIZATION.md; the files.<arm>.txt lists are the harmonized product.

=== T01 ===
INCLUDED:
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | orchestrate-flow/SKILL.md:11 | "The orchestrator inspects the working directory, infers where you are"
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | orchestrate-flow/SKILL.md:85 | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`"
plugins/mega-sdd/skills/generate-intent/SKILL.md | orchestrate-flow/SKILL.md:83 | "Per sub-skill in chain (loop): a. Dispatch with assembled flags"
plugins/mega-sdd/skills/generate-intent/references/vault-contract.md [SECTION:schema + OQ-conventions + id-stability + constitution + Auto-classifier heuristics] | generate-intent/SKILL.md:46 | "Parse + decompose directly per `references/vault-contract.md` §schema + §OQ-conventions + §id-stability"
plugins/mega-sdd/skills/generate-intent/references/generation-guide.md [SECTION:Step 3 + Mandatory section template + File-by-file + Readability + Output mode policy] | generate-intent/SKILL.md:130 | "per `references/generation-guide.md` — read §Step 3 + §Mandatory section template"
plugins/mega-sdd/skills/generate-intent/references/templates/ [SECTION:per-file template of each of the 7 drafted files] | generate-intent/SKILL.md:186 | "Read ONLY the template for the file currently being drafted"
plugins/mega-sdd/skills/generate-units/SKILL.md | orchestrate-flow/SKILL.md:83 | "Per sub-skill in chain (loop): a. Dispatch with assembled flags"
plugins/mega-sdd/skills/generate-units/references/unit-schema.md | generate-units/SKILL.md:43 | "stay unconditional — they are the authoring contract"
plugins/mega-sdd/skills/generate-units/references/templates/unit.md | generate-units/SKILL.md:97 | "Write each unit file using `references/templates/unit.md` as the body template"
plugins/mega-sdd/skills/generate-units/references/modules-schema.md | generate-units/SKILL.md:75 | "open `references/modules-schema.md` at Step 4.5 whenever auto-deriving `.auto`"
plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md | generate-units/SKILL.md:95 | "For each unit, run the adversarial review (`references/adversarial-test-prompt.md`)"
plugins/mega-sdd/skills/generate-units/references/auto-and-memory.md [SECTION:Scope propagation + _index.md] | generate-units/SKILL.md:145 | "its §Scope propagation and §_index.md sections are every-run reads at Steps 10–11"
plugins/mega-sdd/skills/execute-bolts/SKILL.md | orchestrate-flow/SKILL.md:83 | "Per sub-skill in chain (loop): a. Dispatch with assembled flags"
plugins/mega-sdd/skills/execute-bolts/references/superpowers-bridge.md | execute-bolts/SKILL.md:53 | "Superpowers bridge. Detect per `references/superpowers-bridge.md`"
plugins/mega-sdd/skills/execute-bolts/references/batch-and-fanout.md [SECTION:--all] | execute-bolts/SKILL.md:25 | "overlap rail always applied here (`references/batch-and-fanout.md §--all`)"
EXCLUDED:
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md | condition: "Open ... ONLY when an overlay applies: a routing flag (`--greenfield` / `--brownfield` / `--sync` / `--from` / `--to` / `--resume`)" | false because: no routing flag stated; engine `derived.proposed_next` is the default chain
plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md | condition: "open it ONLY to read an `on_fail` hint in full or to author checks" | false because: no fatal/warn needing hint expansion; no --strict-constitution / positional diff source / --max-parallel triggers
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "ADVISORY diagnostics in this loop ... are SKIPPED on express-spine chains" | false because: express spine is the default (no --classic, no --full)
plugins/mega-sdd/references/halt-protocol.md | condition: "Pause on blocker artifacts (any type) per ... halt-protocol.md §halt-protocol" | false because: zero OQ halts, zero CONFLICT, no halts on path
plugins/mega-sdd/skills/orchestrate-flow/references/halt-taxonomy.md | condition: "Every blocker a sub-skill emits is classified" | false because: no blocker emitted
plugins/mega-sdd/skills/orchestrate-flow/references/convergence-loops.md | condition: "cycle-eligible halts auto-resolve ... and re-run" | false because: no halts
plugins/mega-sdd/skills/orchestrate-flow/references/memory-layer.md | condition: "Protocol: `references/memory-layer.md` §Chain end" | false because: trace stops at first bolt dispatch, before Step 8 chain end
plugins/mega-sdd/skills/generate-intent/references/multi-scope.md | condition: "load when the PRD declares a `scopes:` block or `--scope=<id>` is passed" | false because: single scope
plugins/mega-sdd/skills/generate-intent/references/kb-submode.md | condition: "`--kb=<path>` flag present" | false because: Mode A structured PRD, no KB
plugins/mega-sdd/skills/generate-intent/references/from-prompt-mode.md | condition: "`--from-prompt` flag present" | false because: Mode A (PRD.md resolves on disk, Rule 2)
plugins/mega-sdd/skills/generate-intent/references/scope-picker.md | condition: "scope filter logic ... (used by Step 0.9)" | false because: single scope, no picker
plugins/mega-sdd/skills/generate-intent/references/squad-partition.md | condition: "Multi-squad mode (≥2 squads) additionally emits `_meta/squads.yaml`" | false because: single squad
plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md | condition: "the legacy-PRD scope retrofit bridge" | false because: no scopes block, no retrofit
generate-intent §design-system content of generation-guide.md | condition: "the design-system content ONLY when a Step-2 `HAS_*` flag is set" | false because: HAS_UI=false, no design-system source
generate-intent vault-contract.md §Starterkit-binding | condition: "§Starterkit-binding ONLY under `--scan`" | false because: no starterkit, no codebase-map, express spine drops --scan
plugins/mega-sdd/skills/generate-units/references/task-typing.md | condition: "Open ONLY when the State Map carries `PARTIAL_*` / `UNKNOWN` / `CONFLICT` rows" | false because: greenfield, no binding/State Map — all candidates `create`
plugins/mega-sdd/skills/generate-units/references/validation-passes.md | condition: "Open `references/validation-passes.md` ONLY when a pass fires or an edge is ambiguous" | false because: zero halts, no ambiguous edges
plugins/mega-sdd/skills/generate-units/references/halt-protocol.md | condition: "Halt YAML: `references/halt-protocol.md` (on halt only)" | false because: no halt
plugins/mega-sdd/skills/generate-units/references/starterkit-derivation.md | condition: "if `<project>/.mega-sdd/codebase/starterkit-context.yaml` exists" | false because: no starterkit
plugins/mega-sdd/skills/generate-units/references/pbt-integration.md | condition: "emitted only when a PBT framework is detected" | false because: none detected
plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md | condition: "Read it to review or amend builder behavior — the controller no longer executes it" | false because: prompt is script-assembled by build-dispatch-prompt.sh
plugins/mega-sdd/skills/execute-bolts/references/bolt-dispatch-prompt.md | condition: "the T1/T2/T3 sections + marker lines the builder populates" | false because: builder-owned, model never re-types it
plugins/mega-sdd/skills/execute-bolts/references/starterkit-enrichment.md | condition: "used ONLY when `.mega-sdd/codebase/starterkit-context.yaml` exists" | false because: no starterkit
plugins/mega-sdd/skills/execute-bolts/references/halt-recovery.md | condition: "load it ONLY when a halt actually fires (or a `properties:` unit is in the batch)" | false because: no halt, no PBT unit
plugins/mega-sdd/skills/execute-bolts/references/code-gates.md | condition: "Run the wrapper against the landed commit" | false because: trace stops before implementer runs/commits
plugins/mega-sdd/skills/execute-bolts/references/review-panel.md | condition: "ROUND 1: the risk-tiered read-only lenses ... dispatched in parallel" | false because: panel runs after the bolt commit; trace stops before it
plugins/mega-sdd/skills/execute-bolts/references/halts-and-handoff.md | condition: "the full handoff YAML schema, and the memory-layer read/write tables" | false because: chain stops before hop completion/handoff
plugins/mega-sdd/skills/execute-bolts/references/partial-state-and-saga.md | condition: "A crashed bolt writes `partial-state.json`" | false because: no crash/--resume/--rollback
plugins/mega-sdd/skills/execute-bolts/references/squad-subagent.md | condition: "`--per-squad` — fan out across all squads" | false because: single squad
plugins/mega-sdd/skills/execute-bolts/references/propose-and-confirm-prompt.md | condition: "Eligible halts ... may dispatch an AI fix-proposer" | false because: no halt
plugins/mega-sdd/agents/bolt-implementer.md | condition: rule 4 subagent window | false because: fresh-context implementer, not main-session
plugins/mega-sdd/commands/mega-sdd.md | condition: "task scope: entry = the entry skill's SKILL.md under skills/" | false because: command-file injection is out of the counted contract
scripts/ground.sh, scripts/derive-state.sh, scripts/build-symbol-index.sh, scripts/predictive-preflight.sh, scripts/copy-consumer-guide.sh, scripts/derive-vault-json.sh, scripts/validate-vault-oqs.sh, scripts/check-anchor-freshness.sh, scripts/run-preflight-scan.sh, scripts/build-symbol-index.sh, scripts/build-dispatch-prompt.sh | condition: rule 3 "Scripts executed via Bash ... are NOT context loads" | false because: Bash-run, output lines only
UNCERTAIN:
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | "**Resolution preflight** (per `references/chain-execution.md`). Run in order; each is default-on and falls through silently when not applicable."
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md | "`references/handoff-contract.md` opens at the b.iv conditional-field check — its schema owns the CONDITIONAL roster — ... never for the rest of a clean hop"
plugins/mega-sdd/skills/orchestrate-flow/references/factory-routing.md | "`--factory` — enable state-driven factory routing: read the whole checkpoint ledger ... Implied by `--deep`."
plugins/mega-sdd/skills/orchestrate-flow/references/factory-ledger-contract.md | "the derived checkpoint ledger schema each phase appends to"
plugins/mega-sdd/skills/orchestrate-flow/references/checkpoint-protocol.md | "Checkpoint protocol auto-emits per-step JSONL files at `<vault>/.internal/checkpoints/` (per `references/checkpoint-protocol.md`)"
plugins/mega-sdd/references/output-language.md | "Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`)."
plugins/mega-sdd/skills/generate-intent/references/setup-flow.md | "Full procedures, runtime ordering note (0.8 runs before 0.9), the squad-partition Q&A, and the three scope halts → `references/setup-flow.md`."
plugins/mega-sdd/skills/generate-intent/references/self-check.md | "Step 4 — Self-check before delivery. Full anti-halu + readability + output-mode + `vault.json` integrity checklist → `references/self-check.md`."
plugins/mega-sdd/skills/generate-intent/references/auto-and-handoff.md | "(Full `--auto` behavior → `references/auto-and-handoff.md`.)"
plugins/mega-sdd/skills/generate-intent/references/detection-and-shapes.md | "Infer + confirm `PROJECT_SHAPE` with the user (Project Shape Registry → `references/detection-and-shapes.md`)."
plugins/mega-sdd/skills/generate-intent/references/advisor-checklist.md | "Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (intent focus)"
plugins/mega-sdd/references/advisor-findings-schema.md | "Focus + materialization → `references/advisor-checklist.md` + `plugins/mega-sdd/references/advisor-findings-schema.md`."
plugins/mega-sdd/skills/generate-units/references/decomposition-rails.md | "Emission rules + flag behavior: `references/decomposition-rails.md §Dependency-graph`."
plugins/mega-sdd/skills/generate-units/references/defensive-generation.md | "Open the decision matrix in `references/defensive-generation.md §Step 0.5` ONLY when a probe is missing/stale/contradictory"
plugins/mega-sdd/skills/execute-bolts/references/hard-rule-scan.md | "Snapshot formats, grammar detail, and full halt YAMLs → `references/hard-rule-scan.md`."
CHAIN-END: Stops inside execute-bolts Step 4.5 — `build-dispatch-prompt.sh` exit 0 has written `<vault>/bolts/U-001/dispatch-prompt.md`, before the `bolt-implementer` Agent call (rule 4: implementer content is subagent-window).

=== T02 ===
INCLUDED:
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | orchestrate-flow/SKILL.md:11 | "The orchestrator inspects the working directory, infers where you are"
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | orchestrate-flow/SKILL.md:85 | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`"
plugins/mega-sdd/skills/bind-codebase/SKILL.md | orchestrate-flow/SKILL.md:83 | "Per sub-skill in chain (loop): a. Dispatch with assembled flags"
plugins/mega-sdd/skills/bind-codebase/references/express-bind.md | bind-codebase/SKILL.md:49 | "`--express` set → this step and Step 2's retrieval are replaced by `references/express-bind.md`"
plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md | bind-codebase/SKILL.md:57 | "**2. Per claim, produce a verdict** (per `references/binding-contract.md`). **This is the moat:**"
plugins/mega-sdd/skills/bind-codebase/references/implementation-state.md | bind-codebase/SKILL.md:74 | "2.5 Implementation-state classification → ... → `references/implementation-state.md`"
plugins/mega-sdd/skills/bind-codebase/references/hard-rules-and-packs.md | bind-codebase/SKILL.md:76 | "2.8 Framework-convention pack load + 2.9 Suggested Unit Hard Rules → ... `references/hard-rules-and-packs.md`"
plugins/mega-sdd/references/framework-conventions/laravel.md | bind-codebase/SKILL.md:76 | "packs from `plugins/mega-sdd/references/framework-conventions/`"
plugins/mega-sdd/skills/bind-codebase/references/binding-md-template.md | bind-codebase/SKILL.md:88 | "**4. Write `binding.md`** using the template in `references/binding-md-template.md`"
plugins/mega-sdd/skills/bind-codebase/references/auto-memory-handoff.md | bind-codebase/SKILL.md:152 | "Emit the handoff YAML ... on **every** invocation ... Both → `references/auto-memory-handoff.md`"
EXCLUDED:
.mega-sdd/codebase/codebase-map.md (classic-lane primary ground truth) | condition: "`--express` ... zero map load" / express-bind.md:27 "not read at all (zero map load; not required)" | false because: express spine default injects --express on every bind hop (orchestrate-flow/SKILL.md:126)
plugins/mega-sdd/skills/scan-codebase/SKILL.md | condition: "the state engine renders chains WITHOUT a scan phase (GROUND ran as a script)" | false because: express spine; scan-codebase is on-demand/classic only
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md §Decision matrix | condition: "Open ... ONLY when an overlay applies: a routing flag ... rebuild/adoption intent, multi-squad, or the user edits the proposal" | false because: no routing flag; single-squad; engine proposal accepted (adoption is a vault-pull, not foreign-SDD/external-artifact)
plugins/mega-sdd/skills/bind-codebase/references/conflict-resolution.md | condition: "Per-conflict recovery (KEEP_VAULT / KEEP_CODE / DEFER / SPLIT) ... → `references/conflict-resolution.md`" | false because: zero CONFLICT results
plugins/mega-sdd/skills/bind-codebase/references/binding-json-schema.md | condition: "`scripts/derive-binding-json.sh` ... deterministic generator: `binding.json` is derived FROM `binding.md`" | false because: rule 3 — script-owned artifact, schema not model-read
plugins/mega-sdd/skills/bind-codebase/references/handoff-validation.md | condition: "the manual binding→units handoff-integrity surface" | false because: manual/on-demand surface, not on the bind path
plugins/mega-sdd/skills/resolve-oq/SKILL.md | condition: "Blocked → `resolve-oq --binding <binding.md>`" | false because: zero CONFLICT — scenario states no resolve-oq
plugins/mega-sdd/references/halt-protocol.md | condition: "Pause on blocker artifacts (any type)" | false because: no blocker
plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md | condition: "open it ONLY to read an `on_fail` hint in full or to author checks" | false because: preflight clean; no flag-dependent MODEL-RUN check triggered
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "ADVISORY diagnostics in this loop ... SKIPPED on express-spine chains" | false because: express spine
plugins/mega-sdd/commands/mega-sdd.md | condition: "task scope: entry = the entry skill's SKILL.md under skills/" | false because: command-file injection out of counted contract
scripts/derive-state.sh, scripts/build-symbol-index.sh, scripts/predictive-preflight.sh, scripts/build-advisor-bundle.sh, scripts/stamp-binding-boilerplate.sh, scripts/derive-binding-json.sh, scripts/make-bound.sh, scripts/derive-vault-json.sh | condition: rule 3 "Scripts executed via Bash ... are NOT context loads" | false because: Bash-run
UNCERTAIN:
plugins/mega-sdd/skills/bind-codebase/references/oq-resolution.md | "2.6 Tech-OQ auto-resolution (scan) + 2.7 recommendation surfacing → ... → `references/oq-resolution.md`."
plugins/mega-sdd/skills/bind-codebase/references/constitution-and-oq.md | "2.10 Constitution-aware CONFLICT surfacing → cite constitution §A–F clauses on relevant conflicts ... → `references/constitution-and-oq.md`."
plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md | "Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (binding focus)"
plugins/mega-sdd/references/advisor-findings-schema.md | "Full focus + materialization → `references/advisor-checklist.md` + `plugins/mega-sdd/references/advisor-findings-schema.md`."
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md | "opens at the b.iv conditional-field check ... never for the rest of a clean hop"
plugins/mega-sdd/references/output-language.md | "Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`)."
plugins/mega-sdd/references/paths.md | "`<vault>/bound/` (nested in the vault dir ... per `plugins/mega-sdd/references/paths.md`)"
CHAIN-END: Ends after bind-codebase Step 5 clean gate + Step 6 audit log — `binding.md` + `binding.json` + `<vault>/bound/` written, handoff emitted; no resolve-oq hop (conflict == 0).

=== T03 ===
INCLUDED:
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | orchestrate-flow/SKILL.md:124 | "`--sync`: force the Mode D maintenance chain ... regardless of other inference"
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md [SECTION:Decision matrix + Mode D — maintenance/sync detail] | orchestrate-flow/SKILL.md:57 | "Open `references/routing-rules.md §Decision matrix` ONLY when an overlay applies: a routing flag (`--sync`)"
plugins/mega-sdd/skills/scan-codebase/SKILL.md | routing-rules.md:114 | "The chain: `scan-codebase --changed-only` (writes `<vault>/.sync-changed-paths.txt`"
plugins/mega-sdd/skills/scan-codebase/references/scan-procedure.md [SECTION:Incremental mode + Step 0 engine probe + Steps 5–7 + Step 8.5 + Step 10 deriver delta] | scan-codebase/SKILL.md:39 | "on the sync hop, read §Incremental mode plus ONLY the full-scan steps it names"
EXCLUDED:
plugins/mega-sdd/skills/scan-codebase/references/deep-scan-gate.md | condition: "the rest of the full-scan procedure does not apply to the hop" (SKILL.md:39) | false because: Step 10.5 is not in the sync hop's named step set
plugins/mega-sdd/skills/scan-codebase/references/deep-scan-dispatch.md | condition: "Load ONLY on non-empty `stale_slices`" | false because: deep-scan stage not reached on the incremental hop
plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md | condition: "the five deep-scan subagent prompt templates" | false because: no deep-scan dispatch; also rule 4
plugins/mega-sdd/skills/scan-codebase/references/tree-sitter-integration.md | condition: "A forced `--engine=` whose binary is absent → halt `dep_missing`" | false because: AUTO ladder, no forced engine, no halt
plugins/mega-sdd/skills/scan-codebase/references/halts-flags-handoff.md | condition: "Named blockers: `codebase_map_derive_failed` (exit 2) / `codebase_map_invalid` (exit 4)" | false because: no halt on this hop
plugins/mega-sdd/skills/scan-codebase/references/exclusions.md | condition: "The full default exclusion list, the override flags ... live in `references/exclusions.md`" | false because: incremental hop scopes to the changed set, not a bulk walk
plugins/mega-sdd/skills/scan-codebase/references/codebase-map-schema.md | condition: "Section schema ... is defined in `references/codebase-map-schema.md`" | false because: merge delta is script-owned (derive-codebase-map.sh --mode=merge)
plugins/mega-sdd/skills/detect-drift/SKILL.md | condition: "exit 0 (`in_sync` ...) → stamp freshness, one-line SYNC-REPORT.md, chain ENDS" (routing-rules.md:112) | false because: sync-intersect.sh exit 0 — no intersection, chain short-circuits before the drift hop
plugins/mega-sdd/skills/bind-codebase/SKILL.md | condition: routing-rules.md:112 "chain ENDS (nothing to re-verdict — proportional verification)" | false because: short-circuit before `bind-codebase --paths`
plugins/mega-sdd/skills/generate-units/SKILL.md | condition: routing-rules.md:114 "→ `generate-units --reconcile`" | false because: short-circuit ended the chain
plugins/mega-sdd/skills/execute-bolts/SKILL.md | condition: routing-rules.md:114 "→ `execute-bolts` (stale/new units only)" | false because: short-circuit ended the chain
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "SKIPPED on express-spine chains" | false because: express spine, Mode D lane
plugins/mega-sdd/commands/sync.md | condition: "task scope: entry = the entry skill's SKILL.md under skills/" | false because: command-file injection out of counted contract
scripts/sync-intersect.sh, scripts/derive-state.sh, scripts/derive-changed-paths.sh, scripts/probe-scan-engine.sh, scripts/derive-codebase-map.sh, scripts/build-graph.sh, scripts/compute-unit-staleness.sh, scripts/predictive-preflight.sh | condition: rule 3 "Scripts executed via Bash ... are NOT context loads" | false because: Bash-run; sync-intersect.sh emits only an exit code + in_sync line
UNCERTAIN:
plugins/mega-sdd/skills/orchestrate-flow/references/sync-digest.md | "`references/sync-digest.md` — Mode D autonomous deferral contracts: `PENDING-SYNC.md` ... + `SYNC-REPORT.md` (run report with closing staleness verification)."
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/references/output-language.md | "Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`)."
CHAIN-END: Mode D short-circuit — `scripts/sync-intersect.sh` exits 0 (`in_sync`, changed ∩ anchors ∪ target_files = ∅); freshness stamped, one-line `SYNC-REPORT.md` written, chain ENDS before detect-drift (routing-rules.md:112).

=== T04 ===
INCLUDED:
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | orchestrate-flow/SKILL.md:124 | "`--sync`: force the Mode D maintenance chain ... regardless of other inference"
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md [SECTION:Decision matrix + Mode D — maintenance/sync detail] | orchestrate-flow/SKILL.md:57 | "Open `references/routing-rules.md §Decision matrix` ONLY when an overlay applies: a routing flag (`--sync`)"
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | orchestrate-flow/SKILL.md:85 | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`"
plugins/mega-sdd/skills/scan-codebase/SKILL.md | routing-rules.md:114 | "The chain: `scan-codebase --changed-only` (writes `<vault>/.sync-changed-paths.txt`"
plugins/mega-sdd/skills/scan-codebase/references/scan-procedure.md [SECTION:Incremental mode + Step 0 engine probe + Steps 5–7 + Step 8.5 + Step 10 deriver delta] | scan-codebase/SKILL.md:39 | "on the sync hop, read §Incremental mode plus ONLY the full-scan steps it names"
plugins/mega-sdd/skills/detect-drift/SKILL.md | routing-rules.md:114 | "→ `detect-drift --scope=@<vault>/.sync-changed-paths.txt` (scoped to those changed paths)"
plugins/mega-sdd/skills/detect-drift/references/report-format.md | detect-drift/SKILL.md:64 | "Full report structure, section ordering ... are in `references/report-format.md`"
plugins/mega-sdd/skills/bind-codebase/SKILL.md | routing-rules.md:114 | "→ `bind-codebase --paths=@<vault>/.sync-changed-paths.txt`"
plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md [SECTION:Claim-scoped re-bind + verdict types] | bind-codebase/SKILL.md:28 | "everything else carried forward per `references/binding-contract.md §Claim-scoped re-bind`"
plugins/mega-sdd/skills/bind-codebase/references/express-bind.md | bind-codebase/SKILL.md:28 | "Lane default: the chain injects `--express` on every bind hop (express spine default)"
plugins/mega-sdd/skills/bind-codebase/references/implementation-state.md | bind-codebase/SKILL.md:74 | "2.5 Implementation-state classification → ... → `references/implementation-state.md`"
plugins/mega-sdd/skills/bind-codebase/references/hard-rules-and-packs.md | bind-codebase/SKILL.md:76 | "2.8 Framework-convention pack load + 2.9 Suggested Unit Hard Rules → ... `references/hard-rules-and-packs.md`"
plugins/mega-sdd/references/framework-conventions/laravel.md | bind-codebase/SKILL.md:76 | "packs from `plugins/mega-sdd/references/framework-conventions/`"
plugins/mega-sdd/skills/bind-codebase/references/binding-md-template.md | bind-codebase/SKILL.md:88 | "**4. Write `binding.md`** using the template in `references/binding-md-template.md`"
plugins/mega-sdd/skills/bind-codebase/references/auto-memory-handoff.md | bind-codebase/SKILL.md:152 | "Emit the handoff YAML ... on **every** invocation ... Both → `references/auto-memory-handoff.md`"
EXCLUDED:
.mega-sdd/codebase/codebase-map.md (bind primary ground truth) | condition: express-bind.md:27 "not read at all (zero map load; not required)" | false because: `--express` injected on every bind hop
plugins/mega-sdd/skills/scan-codebase/references/deep-scan-gate.md | condition: "the rest of the full-scan procedure does not apply to the hop" (SKILL.md:39) | false because: Step 10.5 not in the sync hop's named step set
plugins/mega-sdd/skills/scan-codebase/references/deep-scan-dispatch.md | condition: "Load ONLY on non-empty `stale_slices`" | false because: deep-scan stage not reached
plugins/mega-sdd/skills/scan-codebase/references/halts-flags-handoff.md | condition: "Named blockers: `codebase_map_derive_failed` / `codebase_map_invalid`" | false because: no halt
plugins/mega-sdd/skills/detect-drift/references/constitution-drift.md | condition: "when `<vault>/constitution.md` exists, validate code against constitution clauses" | false because: constitution presence not asserted by the scenario state
plugins/mega-sdd/skills/bind-codebase/references/conflict-resolution.md | condition: "Per-conflict recovery (KEEP_VAULT / KEEP_CODE / DEFER / SPLIT)" | false because: zero CONFLICT results
plugins/mega-sdd/skills/bind-codebase/references/binding-json-schema.md | condition: "`scripts/derive-binding-json.sh` — deterministic generator" | false because: rule 3 script-owned
plugins/mega-sdd/skills/resolve-oq/SKILL.md | condition: routing-rules.md:114 "[`resolve-oq` ONLY if the drift scan CREATED an `OQ-DC-N` stub]" | false because: no OQ-DC stub created
plugins/mega-sdd/skills/generate-units/SKILL.md | condition: "Chain ends at re-bind complete" (scenario state) | false because: scenario stops the trace at re-bind
plugins/mega-sdd/skills/execute-bolts/SKILL.md | condition: "Chain ends at re-bind complete" (scenario state) | false because: scenario stops the trace at re-bind
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "SKIPPED on express-spine chains" | false because: express spine
plugins/mega-sdd/commands/sync.md | condition: "task scope: entry = the entry skill's SKILL.md under skills/" | false because: command-file injection out of counted contract
scripts/sync-intersect.sh, scripts/derive-state.sh, scripts/derive-changed-paths.sh, scripts/derive-codebase-map.sh, scripts/probe-scan-engine.sh, scripts/stamp-binding-boilerplate.sh, scripts/derive-binding-json.sh, scripts/derive-vault-json.sh, scripts/secret-scan.sh, scripts/predictive-preflight.sh | condition: rule 3 "Scripts executed via Bash ... are NOT context loads" | false because: Bash-run
UNCERTAIN:
plugins/mega-sdd/skills/detect-drift/SKILL.md | "context: fork" (detect-drift/SKILL.md:4) — under fork the body becomes the SUBAGENT prompt (rule 4 tension); INCLUDED here because CLAUDE.md records fork silently NO-OPs headless and the fork is identical in both arms
plugins/mega-sdd/skills/detect-drift/references/auto-and-chain.md | "`references/auto-and-chain.md` — `--auto` behavior table, ... handoff YAML emission, snapshot reuse, per-bolt incremental mode, ... and scope-aware scanning."
plugins/mega-sdd/skills/orchestrate-flow/references/sync-digest.md | "Mode D autonomous deferral contracts: `PENDING-SYNC.md` (deferred-decision queue) + `SYNC-REPORT.md`"
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md | "opens at the b.iv conditional-field check ... never for the rest of a clean hop"
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/skills/bind-codebase/references/oq-resolution.md | "2.6 Tech-OQ auto-resolution (scan) + 2.7 recommendation surfacing → ... `references/oq-resolution.md`."
plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md | "Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (binding focus)"
plugins/mega-sdd/references/advisor-findings-schema.md | "Full focus + materialization → `references/advisor-checklist.md` + `plugins/mega-sdd/references/advisor-findings-schema.md`."
plugins/mega-sdd/references/output-language.md | "Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`)."
CHAIN-END: `sync-intersect.sh` exits 4 (intersection) → scan (incremental) → detect-drift (scoped) → `bind-codebase --paths --express`; trace stops at re-bind complete (zero CONFLICT), before `generate-units --reconcile`.

=== T05 ===
INCLUDED:
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | orchestrate-flow/SKILL.md:11 | "The orchestrator inspects the working directory, infers where you are"
plugins/mega-sdd/skills/resolve-oq/SKILL.md | orchestrate-flow/SKILL.md:81 | "`resolve-oq` is always interactive on per-OQ choices"
plugins/mega-sdd/skills/resolve-oq/references/interactive-walk.md | resolve-oq/SKILL.md:45 | "are in `references/interactive-walk.md` — load it before running the walk"
plugins/mega-sdd/skills/resolve-oq/references/recommendation-context.md | resolve-oq/SKILL.md:100 | "Open per-OQ at slot-`[1]` build time — the walk attempts a recommendation for every OQ"
EXCLUDED:
plugins/mega-sdd/skills/resolve-oq/references/binding-mode.md | condition: "the `--binding <binding.md>` flow: CONFLICT detail-block walk" | false because: intent mode, not --binding (scenario state)
plugins/mega-sdd/skills/memory/references/memory-schema.md | condition: "Memory schema + scope architecture: `../memory/references/memory-schema.md`" | false because: Related-skills pointer, no memory-schema procedure on the walk path
plugins/mega-sdd/skills/memory/references/learning-rules.md | condition: "Self-learning thresholds + rollback path" | false because: chain-end learning pass not in the traced segment
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md | condition: "Open ... ONLY when an overlay applies: a routing flag ... or the user edits the proposal" | false because: no routing flag; engine `derived.proposed_next` returns the OQ-gate row
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "SKIPPED on express-spine chains" | false because: express spine
plugins/mega-sdd/references/halt-protocol.md | condition: "Pause on blocker artifacts (any type)" | false because: no halts (scenario state)
plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md | condition: "open it ONLY to read an `on_fail` hint in full" | false because: preflight clean
plugins/mega-sdd/commands/mega-sdd.md | condition: "task scope: entry = the entry skill's SKILL.md under skills/" | false because: command-file injection out of counted contract
scripts/derive-state.sh, scripts/derive-vault-json.sh, scripts/predictive-preflight.sh | condition: rule 3 "Scripts executed via Bash ... are NOT context loads" | false because: Bash-run (one derive per resolved OQ)
UNCERTAIN:
plugins/mega-sdd/skills/resolve-oq/references/auto-memory-handoff.md | "non-interactive machinery: the `--auto` interactive-vs-auto step table, the memory layer reads/writes ... and the handoff YAML emitted under `--auto`"
plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | "OQ conventions, status-marker semantics, the `defer_to` field, and `vault.json` field + concurrency rules: `../generate-intent/references/vault-contract.md`"
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`" — single-hop chain, per-hop loop reached once
CHAIN-END: Ends at resolve-oq Step 5 (summary) after 3 OQs walked, version bumped + Changelog appended; no `--binding` mode, no halts, no downstream hop proposed.

=== T06 ===
INCLUDED:
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | orchestrate-flow/SKILL.md:11 | "The orchestrator inspects the working directory, infers where you are"
plugins/mega-sdd/skills/emit-fsd/SKILL.md | orchestrate-flow/SKILL.md:83 | "Per sub-skill in chain (loop): a. Dispatch with assembled flags"
EXCLUDED:
plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md | condition: "the deterministic builder that executes `references/section-mapping.md` §1–§10 end-to-end" | false because: rule 3 — read by `build-fsd-core.sh`, not by the model
plugins/mega-sdd/skills/emit-fsd/references/fsd-template.md | condition: "the fenced skeletons are parsed from `references/fsd-template.md` at run time" | false because: rule 3 — script-parsed, single source of truth inside the builder
plugins/mega-sdd/skills/emit-fsd/references/styling-config.yaml | condition: "`FSD.styling.yaml` seeded from `references/styling-config.yaml` when absent" | false because: rule 3 — builder-seeded
plugins/mega-sdd/references/emission-engine.md | condition: "The Steps below remain the OPERATIVE wording for the FSD lane" (SKILL.md:13) | false because: SKILL steps are operative; the engine ref owns only the doc-agnostic spine
plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md | condition: "Full preflight catalog: `orchestrate-flow/references/predictive-checks.md` §emit-fsd preflight checks" | false because: the 4 preflight checks are inline at SKILL.md:45–48 and all pass
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md | condition: "`orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index" | false because: SKILL.md:154 declares the local template "the OPERATIVE spec"
plugins/mega-sdd/references/halt-protocol.md | condition: "emit-fsd emits these halts: `dep_missing` ... `quality_gate_failed`" | false because: vault complete, PDF renders OK — no halt
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md | condition: "Open ... ONLY when an overlay applies: a routing flag ..." | false because: no routing flag
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "SKIPPED on express-spine chains" | false because: express spine
plugins/mega-sdd/commands/emit.md | condition: "task scope: entry = the entry skill's SKILL.md under skills/" | false because: command-file injection out of counted contract
scripts/build-fsd-core.sh, scripts/check-citation-drift.sh, scripts/build-citation-map.sh, scripts/md2pdf.sh, scripts/refresh-doc-stamps.sh, scripts/derive-state.sh | condition: rule 3 "Scripts executed via Bash ... are NOT context loads" | false because: Bash-run; `model_slots=0` — the FSD lane is fully mechanical
UNCERTAIN:
plugins/mega-sdd/references/output-language.md | "Tier-1 structural tokens stay English. Full rules → `plugins/mega-sdd/references/output-language.md`."
plugins/mega-sdd/references/paths.md | "defaults to first vault detected via `plugins/mega-sdd/references/paths.md` priority order"
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`" — single-hop chain
CHAIN-END: Ends at emit-fsd Step 8 (chat summary) after Steps 0–4 builder, Step 4.5 slot scan clean, Step 4.6 citation stamp exit 0, Step 5 md2pdf exit 0, Step 6.5 doc-control stamp. Control task — every heavy artifact on this lane is script-owned.

=== T07 ===
INCLUDED:
plugins/mega-sdd/skills/using-mega-sdd/SKILL.md [SECTION:ANCHOR-CORE] | using-mega-sdd/SKILL.md:21 | "Any SDD lane phrase → the `/mega-sdd` front door ... when unsure, ASK"
plugins/mega-sdd/references/multi-prd-lifecycle.md | using-mega-sdd/SKILL.md:61 | "route a NEW doc by what changed, never guess (full contract → ... multi-prd-lifecycle.md)"
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | using-mega-sdd/SKILL.md:25 | "invoke the skill via the `Skill` tool (default route when unsure: `orchestrate-flow`)"
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md [SECTION:Decision matrix] | orchestrate-flow/SKILL.md:57 | "Open ... ONLY when an overlay applies: ... or the user edits the proposal"
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-consumption.md | orchestrate-flow/SKILL.md:85 | "Full gate ordering + halt envelopes ... in `references/handoff-consumption.md`"
plugins/mega-sdd/skills/generate-intent/SKILL.md | using-mega-sdd/SKILL.md:63 | "New epic on top of shipped work → new vault via `generate-intent`"
plugins/mega-sdd/skills/generate-intent/references/from-prompt-mode.md | generate-intent/SKILL.md:47 | "Runs adaptive Q&A (≤10 questions) ... Procedure → `references/from-prompt-mode.md`"
plugins/mega-sdd/skills/generate-intent/references/vault-contract.md [SECTION:schema + OQ-conventions + id-stability + constitution + Auto-classifier heuristics] | generate-intent/SKILL.md:50 | "All three modes share the SAME vault contract (`references/vault-contract.md`)"
plugins/mega-sdd/skills/generate-intent/references/generation-guide.md [SECTION:Step 3 + Mandatory section template + File-by-file + Readability + Output mode policy] | generate-intent/SKILL.md:130 | "per `references/generation-guide.md` — read §Step 3 + §Mandatory section template"
plugins/mega-sdd/skills/generate-intent/references/templates/ [SECTION:per-file template of each of the 7 drafted files] | generate-intent/SKILL.md:186 | "Read ONLY the template for the file currently being drafted"
plugins/mega-sdd/skills/bind-codebase/SKILL.md | using-mega-sdd/SKILL.md:63 | "then `bind-codebase` **brownfield** against the codebase that now contains PRD 1"
plugins/mega-sdd/skills/bind-codebase/references/express-bind.md | bind-codebase/SKILL.md:28 | "Lane default: the chain injects `--express` on every bind hop (express spine default)"
plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md | bind-codebase/SKILL.md:57 | "**2. Per claim, produce a verdict** (per `references/binding-contract.md`). **This is the moat:**"
plugins/mega-sdd/skills/bind-codebase/references/implementation-state.md | bind-codebase/SKILL.md:74 | "2.5 Implementation-state classification → ... → `references/implementation-state.md`"
plugins/mega-sdd/skills/bind-codebase/references/hard-rules-and-packs.md | bind-codebase/SKILL.md:76 | "2.8 Framework-convention pack load + 2.9 Suggested Unit Hard Rules → ... `references/hard-rules-and-packs.md`"
plugins/mega-sdd/references/framework-conventions/laravel.md | bind-codebase/SKILL.md:76 | "packs from `plugins/mega-sdd/references/framework-conventions/`"
plugins/mega-sdd/skills/bind-codebase/references/binding-md-template.md | bind-codebase/SKILL.md:88 | "**4. Write `binding.md`** using the template in `references/binding-md-template.md`"
plugins/mega-sdd/skills/bind-codebase/references/auto-memory-handoff.md | bind-codebase/SKILL.md:152 | "Emit the handoff YAML ... on **every** invocation ... Both → `references/auto-memory-handoff.md`"
EXCLUDED:
(no cheap delta lane exists) | condition: known gap — no incremental/chat-delta route in the v6.6.0 loading contract | false because: nothing between "chat answer" and a full generate-intent re-vault; this is the negative control
plugins/mega-sdd/skills/generate-intent/references/multi-scope.md | condition: "load when the PRD declares a `scopes:` block or `--scope=<id>` is passed" | false because: free-text brief, no scopes block
plugins/mega-sdd/skills/generate-intent/references/kb-submode.md | condition: "`--kb=<path>` flag present" | false because: no KB
plugins/mega-sdd/skills/generate-intent/references/squad-partition.md | condition: "Multi-squad mode (≥2 squads)" | false because: single squad
plugins/mega-sdd/skills/scan-codebase/SKILL.md | condition: "the state engine renders chains WITHOUT a scan phase" | false because: express spine default
plugins/mega-sdd/skills/bind-codebase/references/conflict-resolution.md | condition: "Per-conflict recovery (KEEP_VAULT / KEEP_CODE / DEFER / SPLIT)" | false because: outcome not asserted by the scenario
plugins/mega-sdd/skills/orchestrate-flow/references/diagnostics-procedures.md | condition: "SKIPPED on express-spine chains" | false because: express spine
plugins/mega-sdd/commands/mega-sdd.md | condition: "task scope: entry = the entry skill's SKILL.md under skills/" | false because: command-file injection out of counted contract
scripts/derive-state.sh, scripts/ground.sh, scripts/build-symbol-index.sh, scripts/derive-vault-json.sh, scripts/copy-consumer-guide.sh, scripts/derive-binding-json.sh, scripts/make-bound.sh | condition: rule 3 "Scripts executed via Bash ... are NOT context loads" | false because: Bash-run
UNCERTAIN:
plugins/mega-sdd/skills/diff-vault/SKILL.md | "Same source **revised** (PRD v1 → v1.1) → `diff-vault` (one vault evolves; history preserved)." — routing may land on diff-vault instead of a new vault; diff-vault Step 0 then STOPs: "no new source provided (STOP, ask for the path)"
plugins/mega-sdd/skills/diff-vault/references/diff-procedure.md | "PRD change detection (`prd_sha256`), per-axis diff computation, apply mechanics (Step 6)"
plugins/mega-sdd/skills/diff-vault/references/report-format.md | "the full `VAULT-DIFF.md` template, per-section examples ... and the Step 5 interactive walkthrough"
plugins/mega-sdd/skills/generate-intent/references/setup-flow.md | "Full procedures, runtime ordering note (0.8 runs before 0.9), the squad-partition Q&A ... → `references/setup-flow.md`."
plugins/mega-sdd/skills/generate-intent/references/self-check.md | "Full anti-halu + readability + output-mode + `vault.json` integrity checklist → `references/self-check.md`."
plugins/mega-sdd/skills/generate-intent/references/detection-and-shapes.md | "Infer + confirm `PROJECT_SHAPE` with the user (Project Shape Registry → `references/detection-and-shapes.md`)."
plugins/mega-sdd/skills/generate-intent/references/auto-and-handoff.md | "(Full `--auto` behavior → `references/auto-and-handoff.md`.)"
plugins/mega-sdd/skills/generate-intent/references/advisor-checklist.md | "Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (intent focus)"
plugins/mega-sdd/skills/bind-codebase/references/advisor-checklist.md | "Dispatch the `mega-sdd:phase-advisor` agent with `references/advisor-checklist.md` (binding focus)"
plugins/mega-sdd/references/advisor-findings-schema.md | "Full focus + materialization → `references/advisor-checklist.md` + `plugins/mega-sdd/references/advisor-findings-schema.md`."
plugins/mega-sdd/skills/orchestrate-flow/references/chain-execution.md | "**Resolution preflight** (per `references/chain-execution.md`). Run in order"
plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md | "opens at the b.iv conditional-field check ... never for the rest of a clean hop"
plugins/mega-sdd/references/output-language.md | "Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`)."
CHAIN-END: A one-column form change routes to the FULL vault lane (new-epic vault via `generate-intent --from-prompt` → `bind-codebase --express`); trace stops at bind complete. No cheap delta lane exists in this arm — expected ≈0 delta vs baseline (negative control).

=== T08 ===
INCLUDED:
plugins/mega-sdd/skills/detect-drift/SKILL.md | detect-drift/SKILL.md:47 | "Step 0 — Inputs (MANDATORY, deterministic — NEVER ask). Resolve from `$ARGUMENTS` first"
plugins/mega-sdd/skills/detect-drift/references/report-format.md | detect-drift/SKILL.md:64 | "Full report structure, section ordering ... are in `references/report-format.md`"
EXCLUDED:
plugins/mega-sdd/skills/execute-bolts/SKILL.md | condition: "execute-bolts context already counted in T01-class runs" (scenario state) | false because: T08 counts only the detect-drift segment
plugins/mega-sdd/skills/execute-bolts/references/batch-and-fanout.md | condition: "a per-bolt lightweight drift check compares each modified `target_file` ... Detail → `references/batch-and-fanout.md`" | false because: execute-bolts segment excluded by the scenario
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | condition: "standalone gate, NOT sync lane" (scenario state) | false because: the gate fires inside the already-counted execute-bolts chain; router overhead counted in T01-class runs
plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md | condition: "Open ... ONLY when an overlay applies: a routing flag (`--sync` ...)" | false because: standalone gate, not the sync lane
plugins/mega-sdd/skills/detect-drift/references/report-format.md §Vault write-back protocol | condition: "Step 5.5 — Vault write-back (`--auto-apply=safe` ONLY; living-vault S5)" | false because: `--auto-apply=safe` not set; zero drift found — nothing to write back
plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | condition: "OQ conventions + `vault.json` field rules ... (detect-drift reads `vault.json` but never writes it)" | false because: Related-skills pointer, no commanded read on the gate path
plugins/mega-sdd/skills/diff-vault/references/diff-procedure.md | condition: "bump the vault version (small bump vX.Y+1 — grammar per diff-vault's `references/diff-procedure.md`)" | false because: no write-back applied → Step 6 takes the Changelog-only branch, version unchanged
plugins/mega-sdd/skills/memory/references/memory-schema.md | condition: "Schema: `memory/references/memory-schema.md` §drift-history" | false because: Step 6.5 states the rule inline ("a fork cannot reach §6/§8.5 ... so it is stated here")
plugins/mega-sdd/references/halt-protocol.md | condition: "an unresolvable required input emits a `drift_inputs_missing` blocker" | false because: inputs resolved by the orchestrator on the main thread; zero drift, next_action null
scripts/secret-scan.sh, scripts/derive-vault-json.sh | condition: rule 3 "Scripts executed via Bash ... are NOT context loads" | false because: Bash-run (derive-vault-json.sh not reached — no write-back)
UNCERTAIN:
plugins/mega-sdd/skills/detect-drift/SKILL.md | "context: fork" (detect-drift/SKILL.md:4) — a forked body becomes the SUBAGENT prompt with no conversation history, which rule 4 would EXCLUDE from the main-session trace; INCLUDED above because CLAUDE.md records that `context: fork` silently NO-OPs headless (skill runs inline) and the frontmatter is identical in both arms, so it cannot be the measured delta. Subtract both detect-drift entries if the harness applies rule 4 strictly.
plugins/mega-sdd/skills/detect-drift/references/auto-and-chain.md | "`references/auto-and-chain.md` — `--auto` behavior table, ... handoff YAML emission, snapshot reuse, per-bolt incremental mode, suggested-next-actions block, and scope-aware scanning."
plugins/mega-sdd/skills/detect-drift/references/constitution-drift.md | "when `<vault>/constitution.md` exists, validate code against constitution clauses (§A–§F)"
CHAIN-END: Ends at detect-drift Step 8 (present summary) — `DRIFT-REPORT.md` written with zero findings, nothing queued to `PENDING-SYNC.md`, Step 6 Changelog-only branch, handoff `next_action: null`; the drift-axis `--scope` gate does not chain onward.
