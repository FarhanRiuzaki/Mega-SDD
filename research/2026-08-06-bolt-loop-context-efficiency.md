# Bolt-loop context efficiency — research (attempt-loop burn + citation granularity)

**Date:** 2026-08-06
**Status:** RESEARCH COMPLETE — awaiting gas for the spec
**Trigger:** operator field observation on the P5 express arm (simkredit-be, 6.0.1): "satu loop yg bikin context cepet abis" + "sitasi penting ga penting di sisi hasil code" — optimize the bolts process, efficient but still sharp.
**Method:** empirical profile of the operator's own execute-bolts session (deterministic transcript analysis, session `15315fdd`) + 3 parallel web-research lanes (incremental re-review practice / agent-loop context efficiency / citation-traceability granularity). Every lever below is judged against the moat rails: **no gate weakened; speed cuts inventory, never verification.**

## 1. The measured loop (empirical, operator's session)

The dominant context burner is the **attempt cycle**: implement → panel → findings → re-dispatch → FULL re-panel → full gate battery → evidence. Measured over U-000…U-003:

| Burner | Measurement |
|---|---|
| Full re-panel per attempt | 2–3 attempts/unit; 4–6 lens dispatches/unit; U-001 went 2-lens → findings → 4-lens attempt 2 → attempt 3 |
| Findings inlined into re-dispatch prompts | dispatch input grows 800B (attempt 1) → 8,950B (U-003 attempt 2); one attempt-2 dispatch was paid TWICE (10:10 + 11:05, same description — stall + re-dispatch) |
| Lens/implementer reports returned verbatim | 12 task-notifications = 113KB into the orchestrator context (8–15KB each; Anthropic's own recommended subagent return budget is 1–2k tokens — we run 4–8× over) |
| Validator battery re-run per attempt | `validate-unit-spec.sh` ×15, postflight band ×13, 46 gate Bash calls over 4 units — every run's stdout persists in-context |
| Post-compaction re-injection | 4 compaction-like drops; 66KB of skill-body re-injection; loop-critical references are heavy (`context-enrichment.md` 94KB, `bolt-dispatch-prompt.md` 24KB, `review-panel.md` 18KB) |
| Citation churn in the inner loop | one full fix+re-gate round existed only to correct the string `F-C-005` (`docs(U-003)` commit) |

Main-thread tool RESULTS are small (0.43MB total) — the burn is reports-in-notifications, growing dispatch prompts, repeated validator stdout, and re-injection. Profilers: scratchpad `p5-ctx-profile{,2,3}.py` (session-local; method reproducible from this section).

## 2. Lane findings (dense form; full briefs in the session transcript)

**Re-review after a fix (industry 2025–2026).** Consensus = **incremental delta + fix-guided verification of prior findings**, NOT full re-panel: CodeRabbit incremental default + `full review` as escape hatch; Cursor Bugbot "Incremental Review" toggle; Qodo `/review -i` + one persistent updated review comment; CodeGuru incremental on PR updates. GitHub Copilot's stateless full re-scan is the documented failure case (endless fix-push-review loop, new comments on unchanged code, 21/24 noise). Fix-guided verification (check the fix against the specific prior finding) cut FNR ~55–69% → ~16–29% (Springer AutSE 2026). Convergence study (Zylos 2026): re-review scope = fix diff + one hop of dependencies, fresh context; findings converge 7→4→2→1→0; hard cap 1–2 automated rounds; oscillation is the full-re-review failure mode. Resolution state is threaded everywhere mature: stable finding IDs, open/resolved, **"addressed" gated on verification evidence, never implementer-asserted** (Greptile). Universal rail: **deterministic validators/tests always run against the FULL head — only the LLM lens is delta-scoped.**

**Context efficiency (Anthropic + practitioners).** (a) Subagent returns: condensed structured summary 1–2k tokens + **artifact bypass** (full report → file, orchestrator gets verdict + pointer) — both Anthropic-documented. (b) Loop state → JSON ledger files re-read on demand ("model is less likely to inappropriately change or overwrite JSON compared to Markdown" — Anthropic harness post); Manus restorable compression (keep the pointer, drop the body). (c) Stale tool-result clearing is the measured 84%-token-reduction class (context-management eval, 100 turns) — repeated validator stdout is exactly this class. (d) Post-compaction skill re-injection is budget-capped by the platform (~5k tokens/skill, ~25k total, third-party measured) — a 44KB body fights the platform; progressive disclosure is the platform-native fix. Cognition counter-position honored: read-only reviewer lanes compress safely; the implementer re-dispatch needs the findings file to carry **reasons/decisions**, not just verdicts.

**Citation granularity (SDD frameworks + safety-critical RTM + grounding studies).** No mainstream SDD framework (Spec Kit, Kiro, BMAD, Tessl) validates citations mechanically inside the inner implement→fix loop; granularity on the code side is task→requirement-ID everywhere; trace verification concentrates at gates (Spec Kit pre-implement `analyze`, BMAD story-completion, DO-178C SOI milestone audits — even Level A validates at audits, not per-commit). Evidence: maintained trace links pay (+24% speed, +50% correctness — Mäder & Egyed) **but stale links are actively harmful**; forced-citation anti-fabrication wins are all on the **claim side** (Endex 10%→0% source hallucination; code-comprehension citations r=−0.72 vs hallucination, 100% fabricated-location prevention) — **no evidence** citation strings in code-side output improve generated code; deferred validation's drift risk is answered by **recompute/auto-repair links from ground truth at the gate** (Trace Link Evolver; ReqToCode structural trace) — which is mega-sdd's existing recompute-at-gate doctrine.

## 3. Recommended levers (each judged vs the moat)

**R1 — Finding ledger + delta re-review rounds.** Round 1: full tier-routed panel (unchanged). Round 2+: (a) per OPEN finding, a targeted fix-guided verification against the new head; (b) ONE delta-scoped review of the fix diff + 1-hop dependencies, fresh context, suppressing new low-severity findings on untouched code; (c) full re-panel demoted to escape hatch (big fix diff / structural change / suspicion), cap 2 automated rounds then HALT to operator. Findings live in a per-unit JSON ledger (stable IDs, severity, open/resolved, resolution EVIDENCE — resolved is gate-verified, never implementer-asserted). **Moat:** deterministic gates (L0/B1/B3/B4/postflight/acceptance) keep running full-head every attempt — regression catching outside the delta stays script-owned, which is the "gates > rules" doctrine already in force; the panel redistribution follows the measured FNR evidence.

**R2 — Lens artifact bypass.** Lenses write the full report to `<vault>/bolts/U-XXX/panel/<lens>-rN.md` and RETURN a structured verdict ≤ ~1–2k tokens (severity counts + finding IDs + one-line titles). Controller routes on verdicts; nothing verbatim re-enters the orchestrator. **Moat:** blind-dispatch rail unchanged (no lens reads another's path); the full report still exists ON DISK for audit — MORE auditable than a chat transcript.

**R3 — Re-dispatch by pointer.** Attempt N+1 dispatch = unit pointer + finding-ledger pointer + the finding-ID delta to address. Findings file carries bodies + reasons (Cognition requirement). Stop inlining findings into dispatch prompts. **Moat:** none touched — same information, different channel; dispatch-file pattern already exists for the spec side.

**R4 — Validator stdout hygiene + scoped battery.** Gate scripts write full detail to their state files (already true) and print pass/fail + pointer; the attempt loop re-runs only gates whose INPUTS changed (extend the analyze v5.32.0 semantic-scoping/verdict-ledger pattern to the bolt postflight battery — `validate-unit-spec` ×15 on an unchanged spec is pure re-payment). **Moat:** scoping reuses LEDGERED verdicts keyed on content hashes — recompute happens whenever inputs change; unknown/unhashable ⇒ re-run (fail-closed).

**R5 — Citations: claim-side mandatory, code-side task-granular, gate-time validated with auto-repair.** Keep citations REQUIRED where the measured anti-fabrication wins live: vault claims, binding verdicts, bolt reports, emissions (sha256 stamps unchanged). Code-side (unit spec → code) granularity stays at IDs (claim/flow/OQ IDs — already the design). The change: citation-STRING freshness leaves the inner attempt loop — validated once at the unit-completion gate, and that gate **recomputes + auto-repairs** the string from ground truth (with attestation in the state file) instead of HALTing the loop on a mismatch a script can fix; unresolvable citations still HALT. **Moat:** validation gets STRONGER (recompute-from-ground-truth vs string equality) and later, not weaker; fabricated citations still cannot survive the gate.

**R6 — Loop-reference diet.** The references the controller re-reads inside the loop must be split so on-demand reads stay scoped (`context-enrichment.md` 94KB is the outlier); SKILL bodies stay under the ~5k-token re-injection budget. **Moat:** none — packaging only.

**Expected effect (to be measured, not asserted):** the attempt cycle was the dominant express-arm burner; R1–R4 attack its four largest line items directly; R5 removes the observed churn class. Verification P5-style after shipping: same extraction conventions on a post-change run.

## 4. Non-goals (on the record)

- Dropping citations from bolt reports/emissions — the claim side is where fabrication risk measurably lives; untouched.
- Delta-scoping the DETERMINISTIC gates — they are the full-head regression net that makes delta panel rounds safe at all.
- Removing the review panel or tiers — tier routing (P3) already answers "unit kecil"; this research redistributes ROUNDS, not lenses.
- Trusting implementer-asserted resolution — resolved state is evidence-gated (Greptile pattern = existing B1 recompute doctrine).
