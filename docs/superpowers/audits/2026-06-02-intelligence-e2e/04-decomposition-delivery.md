# 04 — Decomposition & Delivery Intelligence Audit (generate-units + execute-bolts)

**Date:** 2026-06-02 · **Plugin:** mega-sdd v3.69.2 · **Fork-A scope** (only hooks + deterministic validators enforce; SKILL prose is design vocabulary, no-op-able)
**Fixture:** `new-tradefinance-import` Phase-2 (`.mega-sdd/vaults/tradefinance-rebuild-phase-2/{units,bolts}`)
**User priority (verbatim):** "flow business dan flow arsitek lebih tajam ketika mecah jadi file" — sharper business-flow + arch-flow reasoning at decomposition, grounded in KB/PRD.

**Framing applied:** every gap carries the checkable OUTPUT SIGNATURE good reasoning would produce + `enforceable: Y/N` + which Iter-78 gate already covers it (so this is gap-finding, not gate-re-proposal). "Reason harder" = N (0-for-4 on prose). Anti-hallucination note: all proposed signals are coverage/parity checks over the vault→unit mapping — they assert structure, they cannot invent content (the `## UI contract` `grounded_in:` citation template is the model).

---

## Iter-78 baseline (the 7 gates — READ, not re-proposed)

| Gate | Branch | Validator | Checks |
|---|---|---|---|
| flow-coverage | 5 | validate-flow-coverage | every **input-accepting** (mutation-verb) flow step → ≥1 input-validation artifact; no dead scaffold (edit view w/o update flow) |
| render-test | 6 | validate-unit-spec | view-bearing unit carries `type: render` acceptance_test (halt_type COUNT, not status) |
| sibling-consistency | 7 | validate-sibling-consistency | a cross-cutting concern (`applies_when`) **declared the same way** in every sibling; FK → relation accessor |
| ui-quality | 8 | validate-ui-quality | written view free of scaffold tells (controller-class title, `Customer Id` labels, raw UUID FK, unformatted money, native alert) + has layout/responsive |
| dispatch-prompt | 9 | validate-dispatch-prompt | emitted ui_ux bolt prompt carries injected design tokens + view exemplar |
| operator-UX | 10 | validate-vault-oqs | **vault** models an operator surface for a maker-checker flow OR carries a Design-Source OQ (halt_type COUNT) |
| cross-cutting-reg | 11 | validate-cross-cutting-registration | generated SOURCE that declares a concern (BranchScoped) actually registers it (`addGlobalScope`) |

These close: per-stage Form-Request under-decomposition (slice A), dead edit stubs, scaffold-tell views, divergent concern mechanism, missing render proof. **The gaps below are NOT covered by any of these.**

---

## Phase A — generate-units

**Reasoning verdict: STRONG on per-step input coverage and concern-mechanism uniformity (Iter-78 closed the worst holes), but BLIND on three reasoning axes the fixture forensics flagged: (1) decomposition ALTITUDE — nothing detects a whole multi-step flow collapsed into one module unit; (2) fan-out PARITY — gates check the per-flow TOTAL and per-unit mechanism, never that siblings are served EQUALLY RICHLY; (3) the operator READ/worklist surface — flow-coverage by construction only counts mutation steps.**

### Gap A1 — Decomposition altitude is unchecked (the still-uncovered (c) gap)

| field | value |
|---|---|
| **observed gap** | A single unit may absorb an entire N-step user flow with no signal that it was cut at module altitude instead of step altitude. |
| **fixture-evidence** | `units/U-026.md` = "Import LC Issuance module (6-stage flow Counter→SPV→OPS→CRA→OPS→SWIFT)", `loc_budget: 350`, one unit, `vault_refs:[04-flows.md §F-U-008]`. F-U-008 in `04-flows.md` has 6 input-accepting transition steps. One unit owns all 6. The 8-missing-Form-Request failure was a *symptom* of this altitude error; flow-coverage now catches the symptom (missing artifacts) but not the *cause* (a 6-step flow should not be one bolt). |
| **root-cause** | SKILL Step 2.2 / Step 3 ("if larger → split") are PROSE (no-op-able); the only enforced altitude proxy is `loc_budget` which is self-declared and never reconciled. LOC reconciliation is a **red herring** — U-026 hit budget *by deferring UI* ("scaffold kept"), so an LOC check passes a wrongly-cut unit. |
| **proposed output-signature** | **Concentration trigger** (computable from data `validate-flow-coverage.sh` ALREADY parses — `matched = [units whose tokens ∩ flow tokens]` + `fl["n_input_steps"]`, no new parsing): when `len(matched)==1` AND that flow's `n_input_steps ≥ K` (K≈4), the unit is module-altitude. Do NOT auto-fail "must split" (split-vs-keep is a judgment). Instead make it a **trigger**: such a unit MUST then satisfy per-stage artifact coverage (already A) **+** a `## UI contract` (Step 9.b) **+** a `type: render` test **+** fan-out parity (A2) — i.e. a high-concentration unit forfeits the leniency a small unit gets. Emit `decomposition_altitude_high` (advisory COUNT, like render-test) so a 6-step single unit cannot ride the per-flow-TOTAL leniency. |
| **enforceable** | **Y** — binary signal from existing parsed data; new state key in `.flow-coverage-state.json`; gate via a precise halt_type COUNT (Iter-78.1 EXTENSION-gate pattern, never status==FAIL). |
| **existing-gate-check** | NONE. flow-coverage aggregates artifacts per-flow-TOTAL across all matched units — it is altitude-AGNOSTIC by design (a 6-step flow covered by 6 Form Requests in ONE unit passes identically to 6 units). modules-schema.md is prose. This is the genuine (c) hole. |

### Gap A2 — Fan-out parity: gates check per-flow TOTAL + per-unit mechanism, never sibling SERVED-RICHNESS ("LC is the survivor")

| field | value |
|---|---|
| **observed gap** | Sibling module units in the same flow-analogous group can be served unequally — the survivor (LC issuance) gets full target_files + UI contract; peers (doc_exam, amendment, settlement, counter-balance) get less — with no gate firing. |
| **fixture-evidence** | The fixture units were generated 2026-05-29, BEFORE `## UI contract` (v2.10.0) and `type: render` (Iter-78/v3.69) existed — neither appears in any unit (grep-verified). So the divergence the fixture *observably* proves is **richness asymmetry, not contract/render-test presence**: `_index.md` shows U-026 lists **12** matching target files incl. `resources/js/letter-of-credits/index.js`; siblings U-027/28/30 list **9**, U-029/31 **10**. U-026 body has a rich `## Implementation steps` (7 numbered customizations incl. SweetAlert2/Toastr/responsive grid); U-027 ships the same scaffold with none. Bolt outcome shows the survivor asymmetry propagated: U-026's UI was carved out to a *dedicated* unit (U-039 Wave 6), while siblings U-027/28/29/30 each committed "scaffold kept" INLINE (`bolts/U-027/bolt-report.md:18`, `U-028:17`, `U-029:19`, `U-030:19`). The UI-contract + render-test obligations below are the FORWARD parity signature — the fixture motivates them, it does not yet contain them. |
| **root-cause** | `validate-sibling-consistency.sh` partitions by `module`+`scope` and checks **mechanism uniformity** of a declared cross-cutting concern + FK→relation — it has no notion of *presence-parity of the deliverable richness*. `validate-flow-coverage.sh` sums `n_artifacts` across all matched units per flow (`n_art = sum(...)`), so a per-flow TOTAL passes even when one sibling ships everything and another ships nothing. Survivor bias is invisible to both. |
| **proposed output-signature** | Extend sibling grouping (reuse existing `module`+`scope` partition) to a **presence-parity** check over a flow-analogous sibling group: for each obligation the survivor declares — a `## UI contract` (Step 9.b), a `type: render` test, and per-stage input-validation artifacts **normalized to each sibling's OWN flow-step count** (so F-U-008's 6 steps vs F-U-009's fewer never false-positive) — every sibling MUST declare the same KIND of obligation. A sibling missing what its peers have = `fanout_parity_divergence`. Binary, deterministic, relative-to-peers (no absolute bar → no FP on legitimately simpler siblings). |
| **enforceable** | **Y** — same grouping infra as sibling-consistency; the check is set-presence per group, fully deterministic. This is the strongest novel Y and the direct fix for "LC is always the survivor." |
| **existing-gate-check** | sibling-consistency (Branch 7) checks concern *mechanism* sameness, NOT *deliverable-richness* sameness; flow-coverage (Branch 5) checks per-flow TOTAL, not per-sibling distribution. Neither sees the survivor pattern. |

### Gap A3 — Operator READ/worklist surface is never decomposed into a unit artifact

| field | value |
|---|---|
| **observed gap** | A maker-checker flow's primary operator surface is a **decision worklist** ("items awaiting MY approval"), richer than a scaffolded `show`. Nothing requires that surface to be decomposed into a unit and shipped uniformly across siblings. |
| **fixture-evidence** | `04-flows.md` F-U-008..F-U-013 describe per-stage human review/approve interactions (each stage = an actor deciding on queued items), but no unit enumerates a worklist/decision-queue artifact. flow-coverage's `endpoint_kinds.flow_signal` (laravel.md:234) matches ONLY mutation verbs (submit/review/approve/reject/...); the READ surface that *presents* the item for that decision is by-construction outside its step count. The scaffolded `show.blade.php` IS in U-026/U-027 target_files — but that is a generic single-record view, not the per-actor worklist the flow implies. |
| **root-cause** | flow-coverage is intentionally mutation-only (correct for its slice-A job). No validator maps "this maker-checker flow needs a per-stage operator inbox" down to a *unit artifact + uniform sibling delivery*. |
| **proposed output-signature** | When the concentration trigger (A1) fires on a maker-checker flow, REQUIRE the unit to either (a) list an operator-worklist artifact in target_files (pack-declared `operator_surface_glob`, e.g. an index/datatable view filtered by `workflow_state` + per-row decision affordance) OR (b) carry a `grounded_in`-cited OQ deferring it — folded into the A2 parity set so it's served uniformly. Pack omits `operator_surface_glob` → SKIP (tech-agnostic). |
| **enforceable** | **Y (pack-declared signature)** — new optional pack section; SKIP when absent. |
| **existing-gate-check** | **Distinct from Branch 10.** Branch 10 (validate-vault-oqs) checks the **VAULT** models an operator surface OR carries a Design-Source OQ — it stops at the spec. A3's gap is downstream: nothing checks the operator surface got **decomposed into a unit artifact and shipped uniformly across siblings**. Branch 10 = "did we spec it"; A3 = "did we cut it into a file, for every sibling". |

---

## Phase B — execute-bolts

**Reasoning verdict: the UI coin-flip is now PARTIALLY fenced (Branches 8/9 detect scaffold-tells + un-enriched prompts) but the enforcement is detect-and-block-NEXT — the FIRST scaffold view of a run still commits, and the fixture's dominant failure mode ("scaffold kept; UI polish deferred to a later unit") is a legitimized escape hatch the gates do not close. Hard-rule + render discipline is genuinely strong.**

### Gap B1 — "Scaffold kept; polish deferred to a future unit" is a sanctioned bypass of the UI quality intent

| field | value |
|---|---|
| **observed gap** | A bolt can commit a raw-scaffold view and discharge the UI obligation by pointing at a *future* polish unit. The gates fence tell-bearing views but not the deferral pattern itself. |
| **fixture-evidence** | `bolts/U-027/bolt-report.md:18` "scaffold kept; UI polish deferred"; U-028/29/30 identical "scaffold kept"; `bolts/U-026/bolt-report.md:51` "Mobile + desktop responsive | ... deferred to dedicated UI polish unit" and `:74` "Wave 5 closeout unit can do a comprehensive UI polish pass across all 6 P2 modules at once." `_index.md` then creates U-039 (Wave 6) as that deferred unit. This is the MEMORY anti-pattern `feedback_simplification_flawless` ("no 'deferred to next iter' excuses") manifest in real bolt output. |
| **root-cause** | ui-quality (Branch 8) fires PostToolUse → blocks the NEXT execute-bolts; the in-flight scaffold view already committed. And it scans for *tells* — a scaffold that happens not to trip a tell regex (no `Customer Id`, no raw UUID echo) passes even though it is unfinished, and the bolt's own prose deferral is never checked against the unit's `## UI contract` (A1/9.b). |
| **proposed output-signature** | (1) Tie B to A: a view-bearing unit with a `## UI contract` (Step 9.b) MUST have its `required_states` realized — extend validate-ui-quality to assert the contract's `required_states`/`fk_display` are present in the written view (not just tell-absence). (2) Add a deterministic deferral-tell: a committed bolt-report whose Files-touched marks a view `scaffold kept`/`deferred` while the unit carries a `## UI contract` = `ui_obligation_deferred` (block-next, same Fork-A honesty as Branch 8). Reuses bolt-artifacts/ui-quality plumbing. |
| **enforceable** | **Y** — contract-realization is a structural diff (contract fields vs written view); deferral-tell is a regex over the committed bolt-report. Both deterministic. |
| **existing-gate-check** | ui-quality (Branch 8) checks tell-ABSENCE + required-element presence on the view; it does NOT check the unit's own `## UI contract` was realized, nor flag an explicit "deferred" admission. The contract (A1/9.b) is authored but never verified against the shipped view — a producer-without-consumer gap (MEMORY `feedback_propagation_within_iter`). |

### Gap B2 — Self-reported `confidence` + `uncertain_decisions` in bolt-reports are never gated

| field | value |
|---|---|
| **observed gap** | Bolts emit a `bolt_self_report.confidence` (U-027 = 0.85) and `uncertain_decisions[]` (e.g. "used 5 CALENDAR days as the banking-days approximation" — a real correctness compromise) and commit anyway, with no threshold check. |
| **fixture-evidence** | `bolts/U-027/bolt-report.md` self-report: `confidence: 0.85`, three `uncertain_decisions` incl. a UCP-600 banking-day approximation flagged as possibly-wrong, committed. `bolts/U-034:40` "Wave 5 closure deferred" similarly. |
| **proposed output-signature** | validate-bolt-artifacts asserts: if `confidence < T` (e.g. 0.8) OR any `uncertain_decision` touches a hard-rule / `[LOCKED]` KB constraint, the bolt must carry a linked OQ or follow-up unit ref — else `bolt_low_confidence_uncommitted_risk` (advisory COUNT). |
| **enforceable** | **Y (weak)** — confidence is a self-report (model could game it), so threshold is advisory; the `uncertain_decision ∩ hard_rule` cross-check is the stronger deterministic half. |
| **existing-gate-check** | NONE reads `bolt_self_report`. validate-bolt-artifacts checks artifact presence, not self-reported risk. |

---

## Cross-cutting note — grounding (framing point 4)

All proposed signals are **coverage/parity/structure** checks over the existing vault→unit→bolt mapping. They assert that a relationship holds (every step → an artifact; every sibling → the same obligation kind; every contract field → a rendered element). None asks the model to produce new *content*, so sharper decomposition here cannot increase hallucination — the `## UI contract` `grounded_in: [...]` citation discipline (Step 9.b) is the template every new signal should follow: a signal fires on a MISSING grounded artifact, never invents the artifact's content.
