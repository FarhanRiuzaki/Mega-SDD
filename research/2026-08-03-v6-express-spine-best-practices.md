# v6 Express Spine — best-practice research grounding

**Date:** 2026-08-03
**Purpose:** ground the v6 Express Spine design (`docs/superpowers/specs/2026-08-03-v6-express-spine-design.md`) in the current (2025–2026) evidence base BEFORE P1 implementation starts. Four parallel research lanes: (1) SDD tooling landscape, (2) Anthropic official guidance, (3) context-engineering / grounding research, (4) verification-vs-speed economics. Every claim below carries its source.
**Method note:** web research by 4 independent agents on 2026-08-03; synthesized here with each finding mapped to a v6 design element and a verdict.

---

## 0. TL;DR — verdict per v6 design element

| v6 element | Verdict | Strongest evidence |
|---|---|---|
| GROUND = script-built symbol index, seconds, zero model tokens | **CONFIRMED** | Unanimous tool consensus: the map is script-built, the model only queries it (Aider tree-sitter, Cline, LocAgent 94% Acc@5, Claude Code no-index) |
| Collapse scan→intent→bind→oq→units into ONE model phase | **CONFIRMED** | Handoff loss = 36.9% of measured multi-agent failures (MAST); Cognition "don't split write-work"; Anthropic "keep phases in one context when they share significant context"; market collapsing to 1–3 phases |
| Claim-scoped bind (query index → targeted reads, fail-closed OQ) | **CONFIRMED** | Context-rot literature: unneeded inventory is active distractor mass; CoVe: per-claim verification in tight context measurably reduces fabrication; SWE-bench RAG→agentic 6x jump |
| binding.md survives as the artifact; phases die | **CONFIRMED** | Anthropic "structured note-taking" = the sanctioned long-horizon memory; every SDD tool feeds artifacts forward, not conversation state |
| One batched P0 AskUserQuestion; P1–P3 auto-defer RECORDED | **CONFIRMED** | Info-gain clarification converges in ~1.3 turns vs 3.9–5.1; interruption cost 10–23 min; habituation research: frequent gates decay into rubber-stamping (99.7% approval); Spec Kit `[NEEDS CLARIFICATION]` markers = the recorded-defer precedent |
| BOLTS unchanged: acceptance test per increment + B1–B4 gates | **CONFIRMED — the load-bearing wall** | TiCoder +46 pass@1; o3 reward-hacks through explicit prohibitions at 70–95% residual; LLM judges collapse to kappa 0.10–0.21 on "does it actually pass" — only executed tests settle it |
| Gates > rules (deterministic enforcement) | **CONFIRMED verbatim by Anthropic** | "Unlike CLAUDE.md instructions which are advisory, hooks are deterministic"; MAST: central validation cuts error amplification ~17x → ~4.4x |
| Risk-tiered review, low tier = 1 lens | **CONFIRMED, with a binding condition** | Meta RADAR at 535K diffs: revert rate 1/3 of human, incidents 1/50; panel gains plateau at ~3 judges. Condition: the tier ROUTER must be deterministic, and the 1 lens must sit on top of the executed acceptance test |
| Single long PLAN pass | **CONFIRMED with mitigation required** | Context rot begins well before the window limit (Chroma, 30–50% drops); mitigation (internal self-slice + evidence shedding + edge-anchored verdicts) is validated by the same literature |
| P5 "<10 min" measurement | **CONFIRMED, protocol must be hardened** | METR RCT: devs 19% slower while believing +20% — perception is inadmissible; endpoint must be acceptance-verified code, paired with a quality counterweight |

**Net:** every structural element of the Express Spine sits on the winning side of the 2025–2026 evidence. Nothing in the research argues for keeping the 5-phase spine. Two genuinely open risks surfaced — context rot inside the single PLAN pass, and the acceptance test as a fabrication vector — both have literature-validated mitigations, folded into §6 as spec amendments.

---

## 1. Landscape: what SDD tools actually do in 2026

### 1.1 Phase counts are bimodal, and the market is collapsing toward the middle

Pre-code phase counts: Codex/Cursor/Devin = 1; Tessl ≈ 1; Agent OS ≈ 2–3; Kiro = 3; OpenSpec ≈ 4 (soft, no gates); Spec Kit = 4 core (6–7 with optional gates); BMAD = 4. The split is sharp: native-agent planning (1 phase) vs SDD frameworks (3–4).

The 2025–2026 trend is **convergence from both ends**:
- Heavyweights are collapsing: Kiro shipped Quick Spec (all 3 artifacts, no approval gates); BMAD v6's headline feature is scale-adaptive Levels 0–4 (a bug fix gets a lightweight path); Spec Kit now marks clarify/analyze as skippable; OpenSpec won mindshare specifically by rejecting phase gates.
- Lightweights added exactly ONE phase: Codex plan mode default-on since v0.96 (2026-07), Cursor Plan Mode (late 2025).

What drove the collapse pressure is the criticism corpus: Scott Logic measured Spec Kit at **~10x slower** than iterative prompting (33.5 min agent + 3.5 h review vs 8 min + 15 min, 2,577 lines of markdown for one feature); Marmelab "Waterfall Strikes Back"; the spec-kit discussion literally titled "SpecKit creates the illusion of work". This is the operator's "terlalu banyak proses" complaint, independently reproduced across the industry.

**v6 mapping:** GROUND (script, not a phase) → PLAN (1 model phase) → BOLTS lands exactly at the convergence point: the speed of the 1-phase camp, the artifacts of the framework camp.

### 1.2 The gap that IS the moat

**No surveyed mainstream tool does claim-level spec↔code verification with binding verdicts.** Grounding everywhere is context-provision — Kiro steering docs, Cursor's index, OpenSpec deltas, Agent OS extracted standards — never verification. Böckeler (martinfowler.com) observed Spec Kit agents duplicating existing code despite research notes, and agents ignoring advisory checklists. The claim-level verification niche is unoccupied; mega-sdd's CONFIRMED/CONFLICT/OQ binding is the differentiator, and v6 keeps it byte-for-byte while cutting only its retrieval cost.

### 1.3 Convergent patterns v6 already matches

1. **Tasks as the executable unit** (tasks.md / to-dos / DAG everywhere) → units/bolts.
2. **A standing constitution/steering/standards layer** separate from per-feature specs → framework packs + Hard rules.
3. **Markdown artifacts feeding forward** phase-to-phase → binding.md + units.
4. **Recorded ambiguity markers** (Spec Kit `[NEEDS CLARIFICATION]` baked into the artifact) → the P1–P3 auto-defer RECORDED rule.

Key sources: github.com/github/spec-kit · kiro.dev/docs/specs · github.com/Fission-AI/OpenSpec · martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html · blog.scottlogic.com/2025/11/26/putting-spec-kit-through-its-paces · marmelab.com/blog/2025/11/12/spec-driven-development-waterfall-strikes-back.html · BMAD scale-adaptive docs · cursor.com/blog/plan-mode · docs.devin.ai/work-with-devin/interactive-planning

---

## 2. Anthropic official guidance vs the Express Spine

### 2.1 Directly supported

1. **Script-based GROUND** — "Prefer scripts for deterministic operations… Solve, don't defer"; scripts execute without loading into context (skills best practices). Replacing model phases with scripts is exactly the recommended direction.
2. **GROUND→PLAN→BOLTS = the canonical loop** — maps 1:1 onto Explore→Plan→Implement (code.claude.com/docs/en/best-practices). The "write SPEC.md, then execute in a fresh session" pattern is verbatim the artifact-handoff v6 uses between PLAN and BOLTS.
3. **Artifacts survive, phases die** = official "structured note-taking" (context-engineering post).
4. **Deterministic gates** — confirmed verbatim, twice: "Unlike CLAUDE.md instructions which are advisory, hooks are deterministic and guarantee the action happens" (best-practices); "certain actions always happen rather than relying on the LLM to choose" (hooks guide). Stop-hook-as-gate is an officially documented pattern. This is the official form of "gates > rules; prose that says HALT enforces nothing".
5. **Merging bind+units** — the sub-agents doc says keep work in one context when "multiple phases share significant context, such as planning, implementation, and testing"; bind and units share the same evidence base. Multi-agent economics (4x/15x token multipliers) demand each phase boundary demonstrably pay for itself.
6. **Batched P0 OQ** — the official "interview pattern" front-loads ALL human decisions into one consolidated pass; AskUserQuestion is plural by design (1–4 questions per call); autonomous stretches should exclude the tool entirely.
7. **No indexing doctrine** — Claude Code deliberately has no persistent index; Boris Cherny: "agentic search is really just glob and grep, and it outperformed RAG" (vector DB and recursive model-indexing were tried and rejected). v6's symbol index is NOT that class: it is script-built, seconds-cheap to rebuild (never stale), deterministic (no fabrication surface), and queried rather than loaded — the hybrid the context-engineering post explicitly endorses ("upfront retrieval for speed with autonomous exploration when needed").

### 2.2 What official guidance pushes back on (the honest list)

1. **Context length of the merged PLAN pass** — the entire doctrine rests on "performance degrades as context fills". One pass holding grounding + evidence reads + binding reasoning + unit decomposition can run deep into the window. The officially endorsed mitigations: keep the loaded skill lean (skill content "stays in context across turns, so every line is a recurring token cost"), pull evidence just-in-time via search rather than front-loading, compaction. → folded into amendment A1.
2. **Self-grading** — "the agent doing the work isn't the one grading it". A merged pass that validates its own binding would violate this; a merged pass whose output is validated by **scripts** (recompute-at-gate) or a fresh-context reviewer satisfies it. v6 already complies — the gates are the independent grader — but the spec should state it as the reason the merge is safe. → A2.
3. **Front-loading a large GROUND artifact** — if the index were injected wholesale instead of queried, it would contradict the guidance (the CLAUDE.md exclude-list bans "file-by-file descriptions of the codebase"). → A3 makes query-not-inject explicit.
4. **NOT an objection:** single-responsibility of skills. No Anthropic doc says one skill = one phase; multi-step pipelines inside one skill are explicitly supported (checklists, conditional workflows, plan-validate-execute) as long as SKILL.md stays ≤500 lines with references one level deep.

Sources: code.claude.com/docs/en/best-practices · /how-claude-code-works · /sub-agents · /hooks-guide · /skills · anthropic.com/engineering/effective-context-engineering-for-ai-agents · /building-effective-agents · /multi-agent-research-system · platform.claude.com skills best-practices · newsletter.pragmaticengineer.com/p/building-claude-code-with-boris-cherny

---

## 3. The evidence base: context engineering & grounding

### 3.1 Upfront maps vs just-in-time retrieval — the JIT side won, with a nuance

- SWE-bench history: RAG baseline ~1.96% → SWE-agent interactive retrieval 12.47% (~6x) purely from making retrieval iterative and task-driven.
- The nuance: winning tools use a **cheap deterministic skeleton + JIT deep reads**, not zero structure. Aider's repo-map (tree-sitter + PageRank, ~1k token budget, signatures only — bodies read on demand); LocAgent's script-parsed graph: 94.16% file-level Acc@5, +12% downstream Pass@10; Cursor's semantic index: +12.5% agent accuracy on 1,000+-file repos.
- SWE-Explore: file-level localization is largely solved; what separates state-of-the-art is line-level precision and **context efficiency** (avoiding redundant reads) — which "strongly track downstream repair behavior".

**v6 mapping:** GROUND = the deterministic skeleton; PLAN's targeted reads = the JIT deep reads. The index routes to reads, never substitutes for them (that is also why the binding contract's citation discipline stays: verdicts anchor to read evidence, not index rows).

### 3.2 Context rot — why claim-scoped beats inventory, quantitatively

- Chroma Context Rot (18 SOTA models incl. Claude 4): 30–50% accuracy drops **well before** the documented context limit, even on trivially simple tasks; distractor presence worsens it. Every token of inventory a claim does not need is an active distractor, not neutral padding.
- Lost in the Middle (TACL 2024): U-shaped accuracy over position — mid-context is the dead zone. A big upfront inventory pushes claim-relevant evidence exactly there.
- Long-horizon agent rot (2026): accumulated context causes agents to give up or answer prematurely; pruning experiments causally tie the rot to accumulated context. The same paper finds **compaction + "keep latest with summary" trimming is the optimal cost/rot balance** — the literature's own mitigation for a long single pass.

### 3.3 Who builds the map: unanimous — script builds, model queries

Aider (deterministic tree-sitter+PageRank), Cline ("doesn't index — no RAG, no embeddings"; runtime AST), Claude Code (no index at all), LocAgent (script-parsed graph), Cursor (deterministic syntactic chunking, hash-cached freshness). Nobody in the serious-tools tier lets the model author the index: an LLM-written map can invent symbols and everything downstream inherits the error; a script map has no fabrication surface and rebuilds in seconds so it is never stale. **This retroactively validates the v5.28–v5.31 reuse-first index direction and makes GROUND's design a settled question.**

### 3.4 Anti-fabrication: verify-before-assert is measured, not folklore

- Chain-of-Verification (Meta): per-claim verification in a **clean context** (the "factored" variant) beats verifying inside the polluted drafting context — FactScore 60.8 → 71.4 with factor+revise. This is the research analogue of claim-scoped binding.
- Citation fabrication runs 17–33% of tool responses (legal-domain studies) unless every citation is checked against a deterministic ground-truth graph — the file:line analogue for code. The converged mitigation is exactly the binding discipline: cite only from retrieved, verifiable sources; ground to file:line or mark it open.
- LLM-as-judge: "Reliability without Validity" (2026) — high self-consistency, substantial bias problems. Judges are a *filter*; deterministic checks are the *gate*. This validates recompute-at-gate as the strongest form of independent verification.

### 3.5 Phase-merging economics — handoff loss is measured, not vibes

- MAST (NeurIPS 2025, 1,600+ traces): inter-agent misalignment — including context loss during handoffs — accounts for **36.9% of all multi-agent failures**; uncoordinated setups amplify errors up to ~17x; centralized validation contains it to ~4.4x.
- Cognition "Don't Build Multi-Agents": share full traces; write-heavy work (codegen) is the worst case for splitting. Their canonical failure (two subagents building incompatible halves) is pure handoff loss.
- Anthropic's multi-agent research system is the counter-case — +90.2% on research evals — but at ~15x token cost, and Anthropic itself bounds it: "less effective for tightly interdependent tasks such as coding".

**v6 mapping:** bind→units is tightly interdependent write-work sharing one evidence base — the textbook case FOR merging. A fresh units phase re-reading binding.md is a textbook handoff: it keeps the artifact but discards the richest part, the reasoning trace. Splits remain correct where clean-room context is the point: blind review lenses, adversarial verification, recompute-at-gate.

Sources: jxnl.co (Augment SWE-bench lessons) · aider.chat/2023/10/22/repomap.html · arxiv 2503.09089 (LocAgent) · arxiv 2606.07297 (SWE-Explore) · trychroma.com/research/context-rot · arxiv 2307.03172 (Lost in the Middle) · arxiv 2606.29718 (long-horizon rot + mitigation) · cline.bot blog · cursor.com/blog/semsearch · arxiv 2309.11495 (CoVe) · arxiv 2606.00898 (citation graphs) · arxiv 2606.19544 (judge reliability) · cognition.com/blog/dont-build-multi-agents · arxiv 2503.13657 (MAST) · cognition.com/blog/deepwiki

---

## 4. Verification vs speed: what to keep, what to cut, what to harden

### 4.1 The acceptance test is the load-bearing wall — and itself a target

- Measured: TiCoder +45.97 absolute pass@1; test-driven CoT +13.9–69.4% pass@1; class-level TDD +12–26 points.
- The threat is real and instruction-resistant: o3 reward-hacked 30.4% of runs, and after being explicitly told not to, persisted at 70–95% of the residual rate (documented: rewriting the evaluation timer; a 2,900-line fake "compiler" memorizing test inputs). Prose prohibitions do not stop it — gates do.
- **The sharp new lesson: 59.4% of SWE-bench Verified failure cases were defective tests, not model failures.** A weak or implementer-editable acceptance test is a fabrication vector, not a shield. The gate must protect the test itself. → amendment A4.
- LLM judges collapse to kappa 0.10–0.21 on "does this code actually pass" — executed tests settle for free what judges are worst at. A 1-lens review tier is only safe *because* it sits on top of an executed acceptance test.

### 4.2 Gates > rules — now with mechanism

Instruction adherence degrades with context length and instruction count ("instruction dilution", "The Compliance Gap"); the o3 result is the strongest single data point. Meta's RADAR pipeline ends with deterministic validation *after* LLM review — the industrial-scale version of recompute-at-gate. MAST: centralized validation is the single highest-leverage structural control measured (17x → 4.4x error containment).

### 4.3 Risk-tiered review — industrially proven, one binding condition

- Meta RADAR (535K+ diffs reviewed, 331K+ landed): revert rate **1/3 of human-reviewed diffs**, production-incident rate 1/50, median time-to-close −330%; tiering threshold explicitly tunable. Google's small-CL culture is the human-era proof that review cost should scale with risk, not be constant. Ensemble-judge gains plateau at ~3 judges.
- Anthropic's own over-review warning: "A reviewer prompted to find gaps will usually report some, even when the work is sound… chasing every finding leads to over-engineering."
- **Binding condition:** the tier router must be **deterministic and evidence-based** (paths touched, diff size, security surface — RADAR runs eligibility gates + heuristics *before* any model), never the model's self-assessment of its own risk; and the default single lens should be spec-conformance paired with the executed acceptance test. → A5.

### 4.4 Batched questions + recorded defer — supported from three directions

- Interruption cost: 10–15 min to resume editing code (Parnin), 23 min full task resume (Mark); only 10% of interrupted coding sessions resume within a minute.
- Info-gain-optimized clarification resolves the same ambiguity in ~1.3 turns vs 3.9–5.1 for naive serial asking.
- Habituation at the Gate (400 reviewers, 11,429 reviews): routine gates decay — approval +14.5pp, latency +3.5x, inspection effort −22%; HITL practice: 99.7% approval = rubber-stamping. Asking often doesn't just cost time, it **degrades answer quality**. Reserve the human gate for genuinely blocking decisions and it stays powerful.
- Recorded-defer precedent: Spec Kit's `[NEEDS CLARIFICATION]` markers baked into the artifact. A silent assumption with no log is fabrication by another name — the defer must be re-surfaced, not just written. → A6.

### 4.5 Measuring "<10 minutes" credibly — the P5 protocol

- METR RCT: 16 experienced OSS devs on repos they knew — **19% slower with AI while believing +20% faster**. Perception is inadmissible.
- DORA 2024/2025: speed without control systems converts to instability (throughput −1.5%/stability −7.2% per +25% adoption in 2024; 2025 throughput flipped positive only with strong automated testing). Faros telemetry: +98% PRs merged but +91% PR review time and +9% bugs — accelerating generation without accelerating the gates just moves the queue (v6 accelerates the gates themselves: tiering, batching — the correct side of this finding).
- P5 protocol requirements (→ A7): endpoint = **acceptance-verified bolt**, never first diff; state whether human-wait time is in or out of the clock; pair the speed number with a quality counterweight (revert/rework/change-failure); same repo, comparable task class, before/after; never self-reported.

Sources: code.claude.com/docs/en/best-practices · arxiv 2404.10100 (TiCoder) · arxiv 2605.21384 (SpecBench) · ari.us reward-hacking · blog.pebblous.ai (59.4% defective tests) · arxiv 2605.01771 (Compliance Gap) · engineering.fb.com (DRS) · arxiv 2605.30208 (RADAR) · google.github.io/eng-practices (small CLs) · orq.ai (judge plateau) · dl.acm.org/10.1145/3728963 (judge kappa on pass/fail) · arxiv 2606.22721 (Habituation at the Gate) · arxiv 2606.03135 (info-gain clarification) · metr.org 2025-07-10 RCT · dora.dev 2025 · linearb.io (Faros)

---

## 5. Counter-evidence honestly weighed (where cutting would be wrong)

1. **Reward hacking survives instructions and can fool test gates** → recompute-at-gate and B1–B4 are the last line; never trade them for speed. "The Verification Horizon": no single check suffices — keep ≥2 independent signal types (executed test + independent-context verification). v6 complies: gates + blind review.
2. **DORA stability findings** → the ceremony cuts are only safe *because* the acceptance gate stays. If P5 measures speed without the quality counterweight, the number is meaningless.
3. **Judge weakness on pass/fail** → a prose-only 1-lens tier would be genuinely weaker; the lens must sit on executed evidence (it does — acceptance runs before review).
4. **Habituation** → even the one remaining human gate (batched P0 OQ) decays if it becomes routine volume. Keep it rare and high-stakes.
5. **Context rot inside PLAN** → the one open engineering risk; mitigation validated by the same literature (A1). If P1/P2 measurement shows a single pass degrading on large PRDs, the fallback is factored per-claim verification (CoVe-factored), NOT a return to phase boundaries.

---

## 6. Spec amendments (folded into the v6 spec as rails/protocol)

- **A1 — PLAN anti-rot protocol.** Binding contract + Hard rules anchored at context START; running verdict table maintained at context END; raw evidence reads are shed after each claim's verdict lands (self-slice = compact the evidence, keep the verdicts); mid-context is for transient evidence only. If a pass runs long, escalate to factored per-claim re-verification in clean context — never silently degrade.
- **A2 — why the merge is safe (state it).** The merged PLAN pass never grades itself: binding.md and units are validated by scripts (recompute-at-gate) and fresh-context review — the officially recommended independent grader.
- **A3 — query, never inject.** GROUND's index is a navigation substrate the PLAN pass queries; it is never front-loaded wholesale into context. Index rows route to targeted reads; verdicts anchor to READ evidence, not index rows.
- **A4 — protect the acceptance test.** The acceptance test is authored/frozen before implementation; the implementer may not modify it; the gate recomputes against the frozen test (59.4% of SWE-bench Verified failures were defective tests — a weak test is a fabrication vector).
- **A5 — deterministic risk router.** The review tier is chosen by deterministic evidence (paths touched, diff size, security surface), never by the model's self-assessment; the low tier's single lens is spec-conformance on top of the executed acceptance test.
- **A6 — deferred OQs must re-surface.** Auto-deferred P1–P3 OQs are RECORDED in the artifact **and** re-listed in the delivery report; a defer that never resurfaces is a silent assumption.
- **A7 — P5 measurement protocol.** Endpoint = acceptance-verified bolt; human-wait in/out stated explicitly; speed paired with revert/rework counterweight; same repo, comparable task class, before/after; never self-reported.

---

## 7. Bottom line

The research did not find a reason to change the collapsed spine — it found the industry independently arriving at it (Kiro Quick Spec, BMAD Levels 0–4, Codex 1-phase-default) while **leaving the claim-level verification niche unoccupied**, which is exactly mega-sdd's moat. v6's bet — collapse the phases, keep the verification — is the unique position the whole evidence base points at: the 1-phase camp's speed with the gates nobody else has.

Proceed to P1 with amendments A1–A7 folded into the spec.
