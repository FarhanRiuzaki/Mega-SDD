# Audit Phase 2a — WHEN-triggered reference loading (true progressive disclosure)

**Date:** 2026-08-10
**Status:** DRAFT
**Source:** `docs/superpowers/audits/2026-08-10-skills-audit.md` recommendation #2 (Phase-2 roadmap). Phase 2 is split into two ship trains for round quality: **2a (this spec, 6.3.0)** = the loading contract; **2b (next, own spec)** = script-ification (predictive-preflight, probe-tool, detect-os), the sync claim-intersection short-circuit, and the single-owner sweeps + parity tests.
**Version:** 6.3.0 (minor — loading-contract change only: pointer sentences gain deterministic WHEN conditions; NO reference body changes, NO gate/grammar/halt change, NO file moves).

**The defect (audit-measured):** the architecture's "load on demand" tier is defeated in practice — Procedure steps command their refs unconditionally, so a full deep chain loads ~930 KB ≈ ~230k tokens of instruction before project content. This release makes each pointer carry the deterministic condition under which the file is opened, and declares the inline step skeleton authoritative for the unambiguous path. **Estimated recovery: ~40–60k tokens per full chain** (the audit's ~60–90k figure includes items deferred to 2b/Phase 3), always labeled estimate; the real number is a future P5-style measurement, never asserted.

**Rails (round-amended):** every WHEN condition is state-derived (a flag, a State-Map row class, a `HAS_*` flag, a wave number, a degraded probe) — a small set of judgment-tail escape hatches ("ambiguous", "in question") survives and is acceptable BECAUSE every one is fail-open: ambiguity can only ADD a read, never skip a mandated one (round finding, both reviewers). One reference-body exception was taken: the step-renumber's stale ordinal citation in `chain-execution.md:260` (one phrase — the no-ref-edit rail and the renumber collided; the ordinal was replaced with a section-name anchor). Moat-commanded reads stay UNCONDITIONAL: `unit-schema.md` + `templates/unit.md` at authoring, `express-bind.md` under `--express`, `binding-contract.md` at verdicting, the dispatch-static READ-FIRST, halt YAMLs on halt, `interactive-walk.md` for the walk itself, keterangan/Mermaid contracts. A gate can never be skipped by a WHEN clause — gates are scripts and are untouched.

## D1 — orchestrate-flow (~10k est./chain)

- **Step 4:** `derived.proposed_next` (already computed by the Step-2 engine) IS the default chain. `routing-rules.md` (§Decision matrix / §Deep-chain decision matrix) opens ONLY when an overlay applies: a routing flag (`--greenfield` / `--sync` / `--from` / `--to`), rebuild/adoption intent, multi-squad, or the user edits the proposal. The engine's default needs no table read (the file itself already declares the engine authoritative).
- **Step 5:** `predictive-checks.md` read **section-scoped** — only the §sections of skills actually in the proposed chain (full script-ification is 2b).
- **EP1/EP2 removed from the SKILL body** (audit P2 rec, both blind reviewers' live-vs-PARKED finding class): `chain-execution.md` keeps the PARKED design note; the SKILL stops teaching a dead step.
- **§Specialist references:** per-entry WHEN annotations for the heavy six; `handoff-contract.md` opens ONLY when a handoff fails validation or a producer's expected block is in question (`handoff-consumption.md` owns the per-hop loop and stays per-hop).

## D2 — generate-intent (~10–15k est./run)

- **Mode A / Step 2 core read** names its sections: `vault-contract.md` **§schema + §OQ-conventions** are the drafting core; **§Starterkit-binding ONLY under `--scan`**, **§constitution ONLY at Step 3.4**, **§Multi-scope ONLY when the PRD carries a `scopes:` block**, concurrency detail only on lock contention.
- **Step 3:** `generation-guide.md` — §Step 3 guide + §Mandatory section template + §File-by-file are the core; **design-system content ONLY when a Step-2 `HAS_*` flag is set**; **§Output mode policy detail ONLY when `OUTPUT_MODE=compact`**.
- **Templates:** read ONLY the template for the file currently being drafted, never the set. The `:182` roster drops the phantom `vault.json` scaffold claim (script-derived — never hand-written; audit P1) and §Halt-conditions gains the missing `oq_recommend_citation_invalid` (fired by `validate-vault-oqs.sh`; audit P1).

## D3 — generate-units (~11k est./run)

Line 43 contract flips: *each step names its specialist file WITH the condition under which to open it; the inline skeleton is authoritative for the unambiguous path.* Conditions: `defensive-generation.md` ONLY when a Step-0.5 probe is missing/stale/contradictory; `task-typing.md` ONLY when the State Map carries `PARTIAL_*`/`UNKNOWN`/`CONFLICT` rows or `field_diff` consumption (all-IMPLEMENTED/MISSING follows the inline rules); `validation-passes.md` ONLY when a 12.x check fires or an edge is ambiguous (the inline 12.x list is the authoritative order); `modules-schema.md` ONLY when `_meta/modules.yaml` exists or module assignment is ambiguous; `auto-and-memory.md` ONLY under `--auto`/chain or when a memory write is due. **Stay unconditional:** `unit-schema.md`, `templates/unit.md`, `adversarial-test-prompt.md` (at Step 9.5), `decomposition-rails.md` (deferred — its inline-vs-ref boundary is not yet crisp enough for a deterministic condition; disclosed).

## D4 — resolve-oq (~3–4k est./walk)

`recommendation-context.md` opens **per-OQ, ONLY when building slot [1] for an OQ with `resolution_mode: recommend`** (or when a recommendation probe is otherwise required); business OQs with explicit stakeholder answers never load it. `interactive-walk.md` stays commanded (it IS the walk).

## D5 — scan-codebase sync hop (~12k est./hop)

The dominant post-v6 invocation (`--changed-only` from `/mega-sdd:sync`) reads **ONLY §Incremental mode** (the top-of-file section) of `scan-procedure.md` — the full-scan Steps 0–11 do not apply to the hop. **No file split** (the audit proposed one; a split would relocate ~10 moat-adjacent sync-lane test pins for zero additional token win — the scoped-read contract achieves the same load at zero churn; revisit the split only if a field run shows non-compliance).

## D6 — extract-intelligence (~2k est./run + dilution fix)

`knowledge-base-schema.md` splits by wave in the READ instruction (file unchanged): **before any wave dispatch** read §Directory layout + §Per-domain file frontmatter + §Per-domain 11-section template (incl. §3a) + §Marker conventions + §Anti-hallucination invariants; the **Wave-5-only** sections (§ERD Quality Rails, §`data-mutation-policy.md` template + its sub-sections, §README roll-up structure, §99-rebuild-architecture templates) are read AT Wave 5, not before.

## Round disclosure (dual-blind, 2 reviewers, read-only + mktemp)

Reviewer 1 (spec-fidelity + moat): 0 blocker / 8 majors / 10 minors. Reviewer 2 (breakage; 59/59 referencing tests executed green): 0 blocker / 7 majors / 8 minors. Heavy overlap; ALL folded pre-ship. The moat-class catches (the reason this round earned its cost): the failure-only `handoff-contract` WHEN starved the b.iv conditional-field gate (its CONDITIONAL roster lives only in the schema — WHEN re-widened with b.iv + §Resume carve-outs); chain-scoped `predictive-checks` made §Cold-halt anticipation (2 `fatal: yes` checks) unreachable (carve-out added for execute-bolts chains); the "authoritative" inline 12.x list was MISSING 12.5.h — the PBT no-fabrication rail — which could then never fire (restored inline); the `modules-schema` condition was inverted (auto-derive NEEDS the file exactly when modules.yaml is absent); D4's recommend-mode-only condition was an undisclosed behavior cut (the canonical walk attempts a recommendation for EVERY OQ — re-widened to per-OQ-at-build-time); the generation-guide core orphaned two mandatory sections and barred `OUTPUT_MODE=full` runs from their own column (fixed); the front door still sold the PARKED classifier as live (three flag texts reworded); plus the Step-2 routing-rules self-contradiction, `--resume`/`--brownfield` overlay omissions, phantom "Step-2.4"/"MISSING" names, a leaked stale ordinal, the near-vacuous auto-and-memory condition (dropped — its sections are every-run reads), scan "Steps 0–11" off-by-one folded into the dependency-steps rewrite, twin GI halt rosters, and Plan/Act flags absent from the Flags list. Round lessons: a WHEN condition must be validated against the CONSUMER of the ref (who needs it on the condition-false path?), and "the inline list is authoritative" is itself a claim to verify item-by-item against the ref it summarizes. Disclosed, deferred to 2b/Phase 3: `routing-rules.md:40` "the matrix stays authoritative" wording; engine `derived.notes` gaps for two table-only propose-mentions.

## Proof

`tests/surface/test-p10-when-triggered-refs.sh`: per-skill pins that each targeted pointer line carries its deterministic condition; EP1/EP2 absent from the orchestrate-flow body while chain-execution keeps the PARKED note; the generate-intent roster/halt fixes; negative pins that the moat-commanded reads (unit-schema, templates/unit, express-bind, dispatch-static, interactive-walk) remain unconditional; scan-procedure §Incremental mode still lives at its original location (no move). Existing suites re-run in full (both trees). Pin sweep pre-implementation: none of the edited phrases is test-pinned (verified).

## Non-goals

- Reference BODY changes of any kind (repetition compression, section reordering, archaeology purge) — Phase 3.
- `decomposition-rails.md` conditionality — deferred with rationale (above).
- predictive-checks/probe-ladder/os-detection script-ification, sync claim-intersection short-circuit, single-owner sweeps + parity tests — **Phase 2b (next spec)**.
- vault-contract.md physical section reordering (audit P2) — Phase 3; the §-named reads land the main win without touching the cross-skill SSOT file.
