# End-to-End Intelligence Audit — mega-sdd v3.69.2

**Date:** 2026-06-02
**Trigger:** user — "audit again end to end proses, i want to more intelligent in every step and phase"
**Method:** 4 parallel subagents (orchestrator-baseline / fixture-forensics / upstream-phases / decomposition-delivery), advisor-sharpened framing, fixture-anchored.
**Fixture (ground truth, read-only):** `new-tradefinance-import` (real tradefinance rebuild through Phase 2).
**Detail files:** `01-orchestrator-baseline.md`, `02-fixture-forensics.md`, `03-upstream-phases.md`, `04-decomposition-delivery.md`.

---

## The governing constraint (why most "be smarter" asks fail here)

**Fork A vs Fork B.** Only Claude Code hooks + deterministic validator scripts enforce behavior. SKILL.md *prose* can be silently no-op'd by the model — prose wire-ups failed 4× in this project (Iter 64/65/66a/67). So "make phase X reason harder" is the textbook **un-enforceable** ask.

Every finding below therefore carries an **`enforceable: Y/N`** verdict answering one question: *what OUTPUT SIGNATURE would better reasoning produce, and can a deterministic check detect its absence?* **N** findings are aspirational (0-for-4 track record) — recorded but **not** auto-built. We do not gold-plate an already-heavy 78-iteration system.

---

## Baseline first — what intelligence machinery already exists at v3.69.2

The iter-33 intelligence audit (v3.24.0) proposed Phase-C features F1–F4 and declared them "closure." Verified against current code:

| iter-33 feature | Status @ v3.69.2 | Evidence |
|---|---|---|
| **F1 Memory-driven routing** | **NOT-DONE** | Exists only as `orchestrate-flow` SKILL.md Step 2.7 prose + reference docs. No hook/script fires a routing decision from `outcomes.md`. |
| **F2 Predictive halt detection** | **NOT-DONE** | Step 3.5 prose + `predictive-checks.md` catalog only. `grep predictive hooks/ scripts/` → ∅. Convergence is reactive-only. |
| **F3 Schema validation gate** | **PARTIAL** | `validate-handoff-yaml.sh` is real, wired at `stop:313`, gated at `pre-tool-use:180` — but enforces only 4 required fields + base types. ~50 CONDITIONAL/TYPE/confidence fields ungated. |
| **F4 Type-checked propagation** | **PARTIAL** | Same validator; full TYPE table + confidence still prose. |
| Iter-34 #8 confidence branching / #9 mid-chain memory re-read | **NOT-DONE** | Confidence is untyped everywhere; "≥0.80" is a hardcoded prose string. |

**The Iter-78 code-delivery work (the layer that DID land as real enforcement)** shipped 7 PreToolUse-blocking gates (flow-coverage, sibling-consistency, cross-cutting-registration, ui-quality, dispatch-prompt, render-test, vault-oqs) — all tech-agnostic, pack-declared, fixture-verified. This is the proven template: **detect-and-block-NEXT at PreToolUse, pack-declared signatures, fixture DoD.**

**Headline:** the *delivery* layer is now genuinely enforced; the *orchestration/reasoning* layer is still mostly prose. "More intelligent in every phase" = convert the highest-value reasoning signatures from prose to enforced — using the Iter-78 template — without adding speculative machinery.

---

## Findings — ranked by integrity (real-defect + fixture-anchored + enforceable first)

### Tier 0 — Real defect: a gate that enforces nothing (FIX REGARDLESS)

**X-1 · `validate-conflict-classification.sh` is a vacuous gate.** `enforceable: Y` · phase: bind-codebase
- **Verified:** (a) wired to **no hook** — never runs; (b) greps for ` ```yaml binding_conflict: ``` ` blocks the producer **never emits**; (c) the fixture's real binding.md uses `### CONFLICT-1` prose headings + markdown tables, and its own CONSISTENCY-REPORT.md records `conflict_classification | NOT_RUN`.
- **Impact:** a false guarantee — the binding *grounding gate* looks classified but is unenforced. This is the same vacuous-pass shape already fixed once (ADV-07b dispatch-prompt).
- **Fix:** make the producer emit structured conflict blocks (`conflict_class` / `resolution_complexity`) **and** point the validator at the structure actually produced **and** wire it (PostToolUse detect, or PreToolUse block on binding write). Two-part: producer + validator + wiring.

### Tier 1 — Fixture-anchored reasoning gaps, enforceable, NOT covered by any gate (the user's priority)

**A2 · Fan-out parity ("LC is always the survivor").** `enforceable: Y` (strongest novel) · phase: generate-units
- sibling-consistency checks concern-*mechanism* sameness; flow-coverage sums per-flow *totals* — neither sees one sibling under-served. Repairs 4e0b485/2bdfc1b/abe8d9b all landed on non-LC siblings.
- **Signature:** extend the existing module+scope sibling grouping to a **presence-parity** check — every sibling declares the same KIND of obligation (per-stage artifacts normalized to its own step count, UI contract, render test).

**A1 · Decomposition-altitude trigger.** `enforceable: Y` · phase: generate-units · *the genuine uncovered (c) hole*
- nothing detects a whole N-step flow collapsed into one module-altitude unit (fixture: U-026 owns all 6 steps of F-U-008; `show()` in no unit; 8 Form Requests dropped).
- **Signature:** reuse data flow-coverage already parses — when one unit's tokens match a flow with `n_input_steps ≥ K`, emit `decomposition_altitude_high` and **strip that unit's leniency** (must then satisfy per-stage coverage + parity + UI contract). (LOC-budget is a red herring — U-026 hit budget by deferring UI.)

**B1 · Deferral-bypass (UI coin-flip residue).** `enforceable: Y` · phase: execute-bolts
- the dominant fixture failure — bolt-reports literally say *"scaffold kept; UI polish deferred to a future unit"* and commit anyway (U-027/28/29/30; U-026→U-039). ui-quality (Branch 8) checks tell-*absence* only, never contract-*realization* — a producer-without-consumer gap.
- **Signature:** assert a unit's `## UI contract` `required_states` are realized in the written view + regex deferral-tell over the committed bolt-report.

**N-1 · Shared side-effect parity (Approval-Inbox gap, af49ede).** `enforceable: Y`, no new validator · phase: cross-cutting
- amendment + doc_exam created zero `workflow_assignments` rows → invisible in the cross-module inbox. A shared *runtime side-effect* that must hold uniformly across siblings.
- **Fix:** declare one `inbox-surfacing` cross-cutting concern in the laravel pack → existing slices B+C enforce it. Uncovered today.

### Tier 2 — Upstream "transcription vs reasoning" gaps, enforceable

- **U-EI · extract-intelligence reasoning output unvalidated.** `enforceable: Y` — the 4 KB validators check transcription discipline only; `99-rebuild-architecture/*` + mutation-policy + erd-departures have zero validator. Propose `validate-kb-reengineering.sh` (presence + tier cross-check).
- **U-GI · generate-intent OQ mis-tag blind spot.** `enforceable: Y` — `validate-vault-oqs.sh` only checks OQs *already* tagged `[tech]`; an OQ that should be tech but defaults to `business` is invisible. Re-apply the existing deterministic text-pattern heuristic to ALL OQs; flag tech-text-tagged-business. Pattern-based, no judgment.
- **U-SC · scan-codebase depth signature.** `enforceable: Y` — `validate-codebase-map.sh` checks 7-section presence only; bind's field-diff *requires* `precision_tier: ast` + §2 signatures and silently degrades when absent. Extend validator to assert precision_tier + §2 rows carry signatures.

### Tier 3 — Orchestrator intelligence (real, but speculative / deferred 45 iters — weigh before building)

- **O-1 · Predictive preflight runner → PreToolUse (F2).** `enforceable: Y` — direct clone of the 7 wired code-delivery validators; converts predictive-halt from prose to enforced. Highest *machinery* ROI, but no specific reproduced failure drives it — it's capability, not defect-repair.
- **O-3 · Extend `validate-handoff-yaml.sh` to full contract coverage (F3).** `enforceable: Y` — additive to a live loop; closes ~50 ungated fields. Zero new wiring.
- **O-4 · Type + gate `next_action.confidence` (D5/#8).** `enforceable: Y` — first concrete confidence win; depends on O-3.

### Recorded but NOT to be auto-built (`enforceable: N` — aspirational prose)

- bind-codebase default-tier rationale / deep claim-tracing (true judgment, not a checkable signature).
- B2 self-reported-confidence gating (weak — model self-report is gameable).
- Any "decompose with better business-flow reasoning" framed as SKILL.md guidance without an output signature → 0-for-4; do not.

---

## Cross-cutting insight

Every phase shows the **same shape**: the reasoning *output* is real and producible, but the wired validators police **transcription/structure**, while the one reasoning-enrichment validator (conflict-classification) checks a structure the producer never emits and is wired to nothing. And: **spec-driven gates only fire if decomposition already declared the thing** — the same weakness that produced the defect. The durable wins (A1/A2/N-1) push enforcement to **relationship/parity checks over the vault→unit→bolt mapping**, which assert structure and cannot invent content — so sharper reasoning does **not** raise hallucination risk.

---

## Recommended execution scope (advisor-gated: reproduced-failure + enforceable only)

1. **Tier 0 (X-1)** — fix the vacuous gate. Real defect. Do regardless.
2. **Tier 1 (A2, A1, B1, N-1)** — the user's stated priority (business/arch-flow decomposition + UI delivery), each tied to a reproduced fixture failure, each enforceable, none currently covered.
3. **Tier 2 (U-GI, U-SC, U-EI)** — close the transcription-vs-reasoning validator gaps.
4. **Tier 3 (O-1/O-3/O-4)** — orchestrator machinery; valuable but speculative (deferred 45 iters with no observed harm). Build only on explicit go.

Each fix follows the proven Iter-78 archetype: validator + pack-declared signature (tech-agnostic) + hook wiring + bad/good fixture with verify.sh. No SKILL.md-prose-only fixes.
