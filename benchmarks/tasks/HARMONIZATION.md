# Cross-arm harmonization decisions

The two blind tracers occasionally treated IDENTICAL pointer text differently.
Rule: **same text in both arms → same treatment; asymmetric treatment is allowed
ONLY for a real contract difference between 91a944a and a09e430** (cited below).
Raw un-harmonized tracer reports: `results/<arm>/context-trace-raw.md`.

## Symmetric calls (applied to BOTH arms)

| Item | Call | Reason |
|---|---|---|
| Router entry block (using-mega-sdd SKILL, orchestrate-flow SKILL, chain-execution, model-tiers §Catalog, routing-outcomes, output-language §Prompt surfaces, handoff-consumption, handoff-contract) | INCLUDE in T01–T07 | commanded at chain entry / per-hop in both arms (P-1/P-2); command file (mega-sdd.md / sync.md) added where the scenario enters via slash |
| memory-layer §Chain end | INCLUDE where the chain COMPLETES (T02–T07); EXCLUDE T01 (trace stops mid-chain, §Chain end never reached — baseline tracer's T01 inclusion harmonized OUT) | scenario-state call, not an arm difference |
| factory-routing + factory-ledger-contract | INCLUDE both arms T01 only | `--factory` "Implied by `--deep`" — the implication exists in BOTH trees (tracers quoted it from each) |
| checkpoint-protocol | INCLUDE both arms T01 only | deep-chain per-step checkpoints emit in both arms |
| advisor-checklist + advisor-findings-schema | EXCLUDE both arms | checklist is bundled by `build-advisor-bundle.sh` + read in the SUBAGENT window (P-5); findings-schema fires only on findings>0 — all scenarios are clean |
| binding-json-schema | EXCLUDE both arms | `derive-binding-json.sh` exists in BOTH trees; the schema pointer is generator documentation (P-4) |
| constitution-and-oq (bind 2.10) | EXCLUDE both arms | identical step text both arms; fires on CONFLICT rows — all bind scenarios state zero CONFLICT (P-3) |
| paths.md | EXCLUDE both arms | parenthetical pointer; the operative rule ("DIRECT CHILD of `.mega-sdd/vaults/`") is inline in both arms (P-4) |
| resolve-oq Related block (memory-schema, learning-rules, vault-contract) | EXCLUDE both arms | identical Related-pointers block; operative walk grammar is in interactive-walk.md (P-4) |
| resolve-oq auto-memory-handoff | INCLUDE both arms | the walk writes memory rows + emits the handoff in both arms (P-6) |
| oq-resolution (bind 2.6/2.7) | INCLUDE both arms | mandatory numbered steps, both arms (P-6) |
| T08 detect-drift segment | reduced to SKILL + report-format + auto-and-chain in BOTH arms | vault-contract = Related pointer (P-4); memory-schema §drift-history fires only when a drift row is WRITTEN — T08 finds zero drift; report-format §write-back duplicate de-duplicated (whole file counted once) |
| squad-partition, hard-rule-scan, bolt-contract (T01) | EXCLUDE both arms | single squad; script-run scan; commit step not reached |
| memory-schema §drift-history (T04) | INCLUDE both arms | T04 has a real finding → the drift-history row IS written in both arms |

## Real contract deltas (asymmetry PRESERVED — these ARE the optimization)

| Surface | Baseline 91a944a | Optimized a09e430 | Shipped in |
|---|---|---|---|
| routing-rules.md | unconditional read at chain entry (SKILL "apply the decision table per §CWD inspection") | overlay-only (`derived.proposed_next` authoritative; opens for `--sync` T03/T04 + the T07 multi-PRD route only) | 6.3.0 (2a) |
| predictive-checks.md | model-run catalog, read before every chain | `scripts/predictive-preflight.sh` runs it; ref opens only for `on_fail` hints | 6.4.0 (2b) |
| scan sync-hop | whole scan-procedure + exclusions + halts-flags + codebase-map-schema + tree-sitter + deep-scan-gate + memory-schema | `§Incremental + named steps` section read only | 6.3.0/6.5.0 |
| T03 chain length | full Mode D reconcile (scan→drift→bind) even with ZERO intersection ("no change signal" is the only stop) | `sync-intersect.sh` exit 0 → stamp + one-line SYNC-REPORT + chain ENDS | 6.4.0 (2b) |
| resolve-oq walk | interactive-walk + recommendation-context read up front | recommendation-context opened per-OQ at slot-[1] build time (whole file still counted here — P-8 upper bound) | 6.3.0 |
| generate-units refs (task-typing, validation-passes, defensive-generation, setup-flow) | unconditional | WHEN-conditioned; closed on the clean path | 6.3.0 |
| emit-fsd preflight | predictive-checks §emit-fsd section read | 4 checks inline in SKILL | 6.3.0 |
| generate-intent §-reads (vault-contract, generation-guide) | whole files | §-named core (whole file counted anyway — P-8) | 6.3.0 |
| sync-digest (T03 only) | read on the sync lane | short-circuit path states the one-line report inline; T04 reconcile still reads it | 6.4.0 |
