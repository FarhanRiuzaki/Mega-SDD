# Spec — token + latency optimization

**Date:** 2026-07-30 · **Research:** `research/2026-07-30-token-audit-end-to-end.md`
**Trigger:** operator asked for an end-to-end token audit (target "up to 90%") and, mid-audit, for
**3–4× faster** wall-clock. Both targets are answered with arithmetic in the research doc; this
spec is the execution plan for the findings that survived adversarial verification.

## Targets

**The goal is REAL end-to-end token consumed by a mega-sdd run** — not the accounting, not the
artifact sizes. Operator reaffirmed **90%** after being shown the arithmetic below. That is the
target being worked to, including the capability-cutting lever, which ships as an explicit
opt-in profile rather than being declined.

| axis | asked | reachable how | why |
|---|---|---|---|
| tokens | **90%** | **60–70% without capability loss** (Phases 2/3/5), then a `--lean` profile for the rest | Eliminating *all* standing-context re-read still leaves 56–64% of cost. The remaining terms ARE the work: subagent seeds, model output, fresh input. Reaching 90% means doing less work — fewer optional phases, fewer review lenses, less generated documentation. That is a legitimate product decision; it is not an "optimization" and must never be smuggled in as one. |
| wall-clock | 3–4× | **2.5–3.2× on the bolt phase**; end-to-end unproven | Amdahl: if bolts are ~54% of wall-clock, 2.7× there ≈ 1.5× overall. 3–4× end-to-end needs P2+P3+P4 stacked, and **there is no measured baseline** to verify against. |

### The path to 90% — what each tranche buys

Cost-weighted, against a real pipeline run's shape (cache_creation + cache_read ≈ 82–88% of cost):

| tranche | lever | saving | capability cost |
|---|---|---|---|
| A | Phase 5a fork `scan-codebase` + `bind-codebase` | 11–16% of main-thread cost | none |
| B | Phase 2b/5b/5d/5e script-derive the output lane | output bills **5×** — the highest per-token weight | none |
| C | Phase 3 collapse human round trips | each turn re-bills the whole resident context at 0.1× | none |
| D | Phase 5c/H6 seed slicing on the remaining full-corpus dispatches | every fresh subagent seed is CREATED (1.25–2.0×), never read | none |
| **A–D total** | | **~60–70%** | **none** |
| E | `--lean` profile: drop optional phases, drop review lenses to `minimal`, skip non-mandated emissions | the remaining ~20–30% | **real** — this is the trade |

**Tranche E is where the last 20–30% lives, and it is a product decision, not an engineering one.**
It must be opt-in, must name exactly what it turns off, and must never weaken a gate or an invariant
(the moat is not a token line item — see Non-goals). Default profile stays at A–D.

## Non-goals

- No weakening of any gate, validator, or halt. Doctrine: *gates > rules > hooks*.
- No sharing of context/verdicts between review lenses (`review-panel.md:53` — anti-rubber-stamp rail).
- No Agent-offload of a gated phase.
- No re-tiering of review-panel lens models (moat: frontmatter-pinned by design,
  `review-panel.md:23` + `model-tiers.md:89-94`). **Killed in audit — do not revisit.**
- `context: fork` is **not** a latency lever (it re-creates its seed). Cost-only, Phase 5.

---

## Phase 0 — fix the instruments (BLOCKING; nothing downstream is trustworthy until this ships)

**STATUS: SHIPPED v5.13.0.** Both are ~0-token. These are why six prior optimization rounds aimed
at the wrong target.

**0a — `scripts/report-token-cost.sh`: price `cache_creation` at its ACTUAL TTL.** The script
hard-coded ×1.25, the 5-minute rate, for everything.

> **Amended during implementation.** The plan was to substitute a per-lane constant (main 2.0 /
> subagent 1.25). Measurement showed that is unnecessary: the transcript states the TTL **per
> message** in `usage.cache_creation.ephemeral_{5m,1h}_input_tokens`. This session measured
> **666,802 tokens @1h / 0 @5m** on the main lane — confirming the 1h claim, but as a *measurement*
> rather than an assumption. So the hooks now carry that split into telemetry and the report prices
> cache creation exactly. The lane constants survive **only** as the fallback for telemetry written
> before this ships, and every report states what share was measured vs assumed. This is strictly
> stronger than the planned fix and satisfies its "do not hard-code a single weight" constraint
> without inheriting a new assumption.

**0b — `hooks/stop`: SUM usage across the turn**, deduped by `message.id`, plus the same dedup in
`hooks/subagent-stop`. `hooks/stop` kept only `last_usage`; `hooks/subagent-stop` already summed.

> **Amended during implementation — the planned fix was unsafe as written.** "Sum the transcript"
> is correct for `subagent-stop` (a subagent transcript is read **once**, at the subagent boundary)
> but wrong for `stop`: the main transcript is append-only for the whole session and the hook fires
> **every turn**, so summing the file each time re-emits the cumulative total every turn — O(N²),
> strictly worse than the undercount it replaces. `stop` therefore windows by a **per-session byte
> cursor** and sums only what was appended since its last firing. The cursor must be per-session:
> one shared cursor would see a path mismatch under two concurrent sessions, reset, and re-sum each
> whole transcript.

**Corrected ratios — the planned numbers were wrong.** 8.03× and 2.898× were derived against
naive sum-of-all-messages. Measured against the shipped window+dedup logic, replayed over **10 real
session transcripts / 547 turns**:

| ratio | planned | measured | spread |
|---|---|---|---|
| main-lane undercount (last-message-only → windowed sum) | 8.03× | **11.65×** | median 9.53×, range 2.8–18.3× |
| dedup overcount (blind sum → deduped) | 2.898× | **2.468×** | median 2.404× |

These are dev-session transcripts; a pipeline run's factor will differ. The *direction* and the
*mechanism* are what generalize, not the constant.

**Expected effect on the report:** main-thread cost jumps ~11×, subagent cost drops ~2.5×. **That is
the correction landing, not a regression.** Said so in the CHANGELOG or it reads as a bug.

**Two defects the implementation surfaced, both now pinned by tests:**
- **Dedup needs a real id.** Keying on a missing `message.id` collapses every id-less message into
  one. Dedup only on a non-empty string id; count the rest individually.
- **Sidechain records must be skipped** in `stop` — subagent turns are billed by `SubagentStop`
  against their own nested transcript, so counting them in the main lane double-counts the bolt
  and review-panel lane.

**Free rider (do not act on it in this phase):** the same read now captures `message.model`, so
**Phase 1b needs no special run** — `by_model` in the cost report answers it from ordinary telemetry.

**Tests:** `plugins/mega-sdd/tests/token-cost/test-stop-turn-usage.sh` (new, 14 assertions —
window, dedup, id-less, sidechain, per-session cursor isolation, truncation-resets-to-EOF,
observe-only) + the TTL-exact / lane-fallback / residual cases added to
`test-token-cost-report.sh`.

---

## Phase 1 — `bolt-implementer` model pin (two SEPARABLE items)

**1a — AMENDED 2026-07-31: the original premise was stale; the real gap is narrower.**
`agents/bolt-implementer.md:5` **does** carry an explicit declaration — `model: inherit`. Verified
across the 8 plugin agents: 3× opus (`code-quality-reviewer`, `phase-advisor`, `security-reviewer`),
4× sonnet (`design-reviewer`, `domain-extractor`, `spec-reviewer`, `standards-reviewer`), 1×
`inherit` (`bolt-implementer`). The earlier "only agent without an explicit `model:` (4× opus, 4×
sonnet elsewhere)" is wrong on both counts.

`inherit` **is** an explicit declaration, and a defensible design here: the implementer tracks the
operator's chosen tier, so a session deliberately running a stronger model gets a stronger
implementer without editing the plugin — which suits the LOCKED "akurasi code WAJIB" mandate better
than a hard pin. It is therefore **not** a defect to fix.

**The remaining real gap: it has NO row in `references/model-tiers.md`** — the catalog is silent on
the one agent whose tier is operator-controlled, so nothing documents that choice or its rationale.
**Ship: the catalog row only** (added 2026-07-31, row 22, tier `inherit`). **Do NOT change the
agent's `model:` value** — swapping `inherit` for a hard tier is a cost/quality behavior change this
spec itself defers to 1b. A catalog↔frontmatter parity test remains optional follow-up; note that
`inherit` is a legitimate frontmatter value it must accept, not a missing pin.

**1b — choose the tier only after the measured run.** Worth **6.3–7.2M cost-units (17–19%)** if
bolts ran Opus-tier; **exactly 0 if Sonnet**. One `usage.model` read from any bolt transcript
settles it — and since Phase 0 shipped, `by_model` in `TOKEN-COST-REPORT.md` reports it directly
from any run that dispatched a bolt, so **no special instrumented run is needed for 1b** (one is
still needed for the latency baseline). **Do not blind-pin to Sonnet:** the LOCKED "akurasi code
WAJIB" mandate creates a feedback loop where a weaker implementer costs *more* via panel rejections
and re-dispatches.

---

## Phase 2 — the both-axes wins (best value; ship together)

**2a — parallelise `execute-bolts` in the orchestrated chain.** `--all` is sequential by default
(`batch-and-fanout.md:16`) and **no routing row ever passes `--parallel`**
(`routing-rules.md:56,86,87,157`; `orchestrate-flow/SKILL.md:70`; `handoff-contract.md:273`) — while
`chain-execution.md:176` already auto-runs `analyze-parallelism` and claims the wave plan is "passed
to execute-bolts". Honour that contract. **Gain: 2.5–2.7× on the bolt phase** (single-squad `--all`;
multi-squad already routes to the parallel procedure).
*Constraint:* preserve `batch-and-fanout.md:18` "on any failure halt the entire `--all` run (no
skip-ahead)" — wave-level parallelism only, never pipelining unit N+1 against unit N's review tail.

> **DESIGN 2026-08-01 (tranche 2a/2c/2d).** The gap, stated precisely: the flag exists
> (`execute-bolts --parallel`), the procedure exists (`batch-and-fanout.md` §`--all` step 3, with
> the overlap rail), the auto-run exists (`chain-execution.md` diagnostics row: analyze-parallelism
> runs before every chained execute-bolts invocation and its row claims the plan is "passed") — and
> **no chain path connects them**: not one routing row, decision-matrix row, handoff row, or
> pipeline example carries `--parallel`. 2a wires the existing pieces; it invents no mechanism.
>
> **The channel is in-context, not a flag.** There is no `--waves=` input and none is added. The
> chain's auto-run invokes `analyze-parallelism.sh --format=json`; its `waves` array IS the
> `depends_on` topological layering, and it is already sitting in the controller's context when the
> next phase dispatches. `execute-bolts --parallel` consumes it as the layering input when present;
> a standalone `--parallel` run (no plan in context) computes its own grouping exactly as today. In
> BOTH cases the **target_files overlap rail is applied by execute-bolts itself, per wave, at
> dispatch time** — the script does not compute it, deliberately: the rail lives with the
> dispatcher, so a stale or hand-edited plan can never bypass it (units in the same wave whose
> whitelists intersect still serialize).
>
> **Failure semantics at the wave boundary** (the constraint above, made operational): when any
> unit in the in-flight wave records a failure (implementer BLOCKED, L0 blocking halt, panel
> `review_critical_unresolved`, post-flight violation), the controller **completes the detect-after
> pipeline for every unit already dispatched in that wave** — their commits have already landed;
> abandoning them would leave landed commits with no verdict trail (and trip B1/B2/B4 at the next
> gate anyway) — and **dispatches no further unit and no further wave**. "No skip-ahead" = never
> START new work past a failure; it never meant discard verdicts on work already committed. The
> next wave dispatches only after the current wave's panels have ALL merged clean — never pipelined
> against a review tail.
>
> **Sites — ROUND-1 CORRECTION 2026-08-01: "all prose/routing, no script change" was WRONG.** The
> blind static reviewer found the gap statement itself had a hole: the routing rows were ported to a
> SCRIPT in the v5 state-engine work, and `routing-rules.md:56` sits in the "Derived-position map
> (script default ↔ matrix row)" table — it DOCUMENTS `scripts/_lib/state_probes.py:773`'s output.
> Editing the doc without the engine left the front door (`/mega-sdd` proposes from
> `derived.proposed_next`) dispatching sequential while every prose surface and fixture claimed
> parallel, with `tests/state/test-derive-state.sh` f6 pinning the divergence CI-green. Fixed in the
> same round: the engine's `units_pending_bolts` chain now emits `--all --parallel`, the f6 fixture
> pins it, and `test-2a2d-chain-parallel.sh` pins the ENGINE (not just its docs). The
> `maintenance_sync` proposal entry stays bare `execute-bolts` deliberately — sync-lane bolt args
> arrive from the generate-units `--reconcile` handoff at dispatch time, which now carries the flag.
> Prose/routing sites as originally listed: `routing-rules.md` :56 `units_pending_bolts` row,
> :86 decision-matrix row, :157 1-phase chain row (each `execute-bolts --all` → `--all --parallel`;
> the `--per-squad` leg is untouched — its procedure is already parallel by construction);
> `orchestrate-flow/SKILL.md` step-6 pipeline example; `handoff-contract.md` generate-units routing
> row + `generate-units/references/auto-and-memory.md` emission (`suggested_args:
> ["--all", "--parallel", "--auto"]`); `chain-execution.md` diagnostics row reworded to name the
> actual channel (JSON in context) instead of asserting an unspecified "passed";
> `batch-and-fanout.md` §`--all` step 3 gains the wave-plan-consumption sentence + the boundary
> semantics above; `execute-bolts/SKILL.md` `--parallel` flag text gains one line (chain runs
> receive the flag from routing; wave plan consumed when in context). Trigger-test fixtures that
> pin the proposed args are updated in the same change. **The flag DEFAULT stays sequential**
> (`batch-and-fanout.md:16` remains true): 2a changes what the chain passes, not what the skill
> defaults to — standalone suggestions outside the chain (generate-units completion line, README)
> deliberately keep plain `--all`.
>
> **Gain basis, honestly labelled:** the 2.5–2.7× figure is the audit's DAG estimate under the
> analyze-parallelism speedup model ("1 bolt = 1 min, unlimited parallel — an estimate, not a
> promise", the script's own label). Real wall-clock depends on each vault's DAG shape and is not
> synthetically measurable here; no measured wall-clock is claimed and none should be quoted as one.
>
> **ROUND-1 rails (same blind round as the sites correction — same-tree wave concurrency was
> activated-by-default with unspecified semantics; all four specified in `batch-and-fanout.md
> §--all` + the agent body, none left as hand-waves):**
> - **In-flight cap, concrete:** wave dispatch is bounded (default 5 concurrent implementers,
>   cap-sized slices; the same bound stated in `squad-subagent.md`, which previously said only
>   "a sensible in-flight cap"). Unbounded fan-out was the I2 finding — each bolt later fans out
>   panel lenses, and the platform's concurrent-task comfort zone is finite.
> - **Per-unit gate ranges:** wave commits interleave, so `wave-base..wave-head` is no unit's
>   range. The atomic-commit contract + the canonical commit identity give each unit's L0 run its
>   OWN commit (`<its-commit>^..<its-commit>`; re-dispatch scans the unit's commit SET, one call
>   per commit, results merged — the S7 "never fix-commit-only" purpose preserved without
>   attributing sibling commits). Under sequential execution this is byte-identical to the shipped
>   `bolt-base..new-head`.
> - **Index contention:** concurrent commits into one branch race on git's index.lock; the
>   `bolt-implementer` contract now names it CONTENTION — bounded retry, never `BLOCKED` — so a
>   benign race cannot manufacture a wave halt (detector-as-chain-killer, blocked).
> - **Shared test state:** acceptance runs inside a wave share project test state; the named valve
>   is `--worktree` (per-bolt isolation) or dropping the flag at the chain's Edit step — disclosed
>   in the procedure, never a silent hazard. Full worktree-coupling as the wave default was
>   EVALUATED and REJECTED this round: the `--worktree` flag's merge-back procedure is one line of
>   prose today — too thin to carry a default; revisit only with a real worktree procedure spec.
> - Also fixed in-round: `commands/analyze-parallelism.md` Step-3 suggested `--per-squad --parallel`
>   unconditionally — a form that HALTS on single-squad vaults by procedure; now squad-count-
>   conditional. Consumed wave plans skip already-completed units explicitly (resume-safe).

**2b — move bolt dispatch-prompt assembly into a script.** ~9KB/bolt of pure copy/filter/sort/cap
logic, currently model-assembled **and materialized twice**. **Gain:**

> **MEASURED 2026-07-31 against the shipped working tree — this replaces the round-3
> `PENDING MEASUREMENT` markers.** Two figures previously stood here (`~4.8K / 37.3×`, then
> `~6.9K / ~26×`), each re-derived from the PREVIOUS round's measurement rather than from shipped
> code, while the code moved under both (stdout slim; `--plugin-root` made mandatory and the
> invocation string longer; the design slice moved off stdout to
> `<vault>/lens-inputs/U-XXX/design-slice.md`). **Both are struck.** Everything below was produced
> by one measurement pass over `plugins/mega-sdd/scripts/build-dispatch-prompt.sh` as it stands in
> the working tree.
>
> **Corpus and method (so it is reproducible, not just asserted).** 35 real `U-*.md` units found in
> this tree, renumbered `U-001…U-035`, run through the exact §Invocation form
> (`--plugin-root` passed, no `--quiet`, no `--explain`) on three fixture projects. Arms are
> discriminated deterministically and asserted, never assumed:
> **A — non-UI, n = 25** (`design_slice_path` key ABSENT from stdout);
> **B — UI on a starterkit repo, n = 10** (slice file does NOT begin with the `## Design system
> (UI-bearing unit` heading, and the prompt carries `### Starterkit context`);
> **C — UI on a greenfield repo, n = 10** (slice file BEGINS with that heading). All 105 runs
> exited 0.
>
> **One corpus modification, disclosed because reproducibility is the point.** Arm B required
> stamping `starterkit_relevance: [ui_ux, libs, auth]` into every unit's frontmatter: only 1 of the
> 35 found units carries the field, and without it the starterkit design-slice branch never runs
> (`sk_ui` stays `None` and the builder falls through to the greenfield branch even on a starterkit
> repo — an arm-B reading that is really arm C). The stamp is schema-legal and is what
> `generate-units` writes on a real starterkit repo. **Arms A and C use the units exactly as found.**
>
> Every byte figure is stated **at a named absolute-path length** — specifically project root 67 B +
> `/.mega-sdd/vaults/demo-bound/bolts/U-XXX/dispatch-prompt.md` (59 B) = a **126-byte
> `prompt_path`** — because path length is what made three prior figures non-reproducible, and the
> vault name sits inside the path that gets carried: the builder's stdout carries the project path
> **2× on a non-UI unit and 3× on a UI unit**, and `inline_core` carries it **1×** — verified
> exactly (a 42-byte path lengthening moved stdout by exactly 84 B / 126 B and `inline_core` by
> exactly 42 B), so normalisation between path lengths is arithmetic, not estimation.
> Divisor: **4 chars/token, the same divisor on both sides of every comparison.**

- **Output tokens: OLD side ~179K per 40-unit run — CONFIRMED and UNAFFECTED.** The pre-change flow
  materialized the ~9KB prompt TWICE as model output (pre-change `context-enrichment.md:182` +
  `superpowers-bridge.md:91`): 179,000 tok × 4 B/tok ÷ 40 ÷ 2 = 8,942 B = 8.74 KB/bolt, matching the
  "~9KB/bolt" premise. This is the one figure on this item that survives round 3; it describes the
  flow that was replaced, not the replacement.
- **Output tokens: NEW side — MEASURED 2026-07-31, `578 B–1,251 B` per bolt ⇒ `~14×–31×`.** The
  residual is the **enumerated set** below; anything not in this list is not counted, so the next
  reader can audit the set rather than the sum.

  | term | bytes | basis |
  |---|---|---|
  | Bash `command` — the shipped three-line §Invocation form | **190 / 298 / 406** | MEASURED verbatim from `SKILL.md:80-83` == `context-enrichment.md:381-383`. 190 = short root (`/Users/me/app`, 13 B) with `${CLAUDE_PLUGIN_ROOT}` left LITERAL; 406 = this repo's own root (67 B) with the plugin root PRE-EXPANDED (`/Users/farhanriuzaki/.claude/plugins/marketplaces/mega-sdd/plugins/mega-sdd`, 75 B); 298 = either middle case. **Which form the controller emits is UNRESOLVED** — the template contains `${CLAUDE_PLUGIN_ROOT}` twice, and expansion swings the string more than path length does. Both are published; neither is assumed. |
  | Bash `description` | **30–60 (ESTIMATED)** | No shipped literal exists to measure. Band taken from the Bash tool's own "keep it brief (5–10 words)" guidance. Labelled estimated wherever it appears. |
  | Agent `prompt` = `inline_core` VERBATIM | **303 (measured floor) … 700 (contract cap)** | MEASURED min 303 B (arm A, short root) / med 437 B / max 587 B at this repo's root, n = 45 (25 non-UI + 20 UI). The **ceiling uses the contractual ≤700 B cap** (`SKILL.md:87`), not the corpus max — the found corpus is thin-bodied (largest real unit body 1,692 B per §AMENDMENT) and a schema-legal 10–12-`target_files` unit approaches the cap. |
  | Agent `subagent_type` = `mega-sdd:bolt-implementer` | **25** | exact |
  | Agent `description` | **30–60 (ESTIMATED)** | as above |
  | **residual / bolt** | **578 (floor, all-measured-except-descriptions) … 1,251 (ceiling)** | floor = 190+30+303+25+30; ceiling = 406+60+700+25+60 |

  **⇒ 145–313 tok/bolt · 5,780–12,510 tok per 40-unit run · `179,000 ÷ that` = `14.3× – 31.0×`.**
  Centre of mass (this repo's root, literal `${CLAUDE_PLUGIN_ROOT}`, measured `inline_core` spread):
  740–1,030 B/bolt = 7,400–10,300 tok/run = **17.4×–24.2×**.
  **The ratio is a LOWER BOUND, deliberately:** the new side counts the Bash and Agent `description`
  params, the confirmed 179K old side counted prompt bytes only. Growth with path length is exact —
  **+3 B/bolt per character of project-root length** (`--cwd` + `--vault` in the command = 2×,
  `inline_core`'s READ-FIRST pointer = 1×).
  **The design-lens hand-off is NOT in this residual** — it is its own line item below, because the
  confirmed 179K old side does not include it either.
- **Output tokens: the design-lens hand-off (round-3 D3) — its OWN line item, MEASURED.** Pre-change
  the controller pasted the whole design slice into the `design-reviewer` prompt as model output
  (`review-panel.md` at HEAD: *"It receives the SAME design slice injected into the implementer's
  prompt"*, and §Blind dispatch: *"Everything else a lens needs is pasted as text"*). It now emits
  one path. Measured per UI bolt: **greenfield 9,635 B → 129 B, saved 9,506 B ≈ 2,377 output tok**;
  **greenfield with the design_slice truncation rung fired 3,420 B → 129 B, saved 3,291 B ≈ 823 tok**;
  **starterkit 495 B → 129 B, saved 366 B ≈ 92 tok** (the starterkit branch only ever carried the
  `### Starterkit context` design lines — D3's saving there is small and must not be quoted as the
  headline). At 10 greenfield UI bolts in a 40-unit run: **≈ 8,200–23,800 output tokens saved**,
  i.e. of the same order as, or larger than, the entire post-change residual — which is what
  justified moving the slice off the paste.
- **Input tokens — a SEPARATE line item, never folded into the ratio. MEASURED 2026-07-31.** The
  builder's stdout is the sole carrier of `inline_core`, so `--quiet` is forbidden and the report
  JSON lands as a tool result every bolt. **Three figures that must never be averaged**, all at this
  repo's own root length (67 B), min / median / max:

  | arm | n | stdout bytes | tok |
  |---|---|---|---|
  | A non-UI | 25 | **731 / 815 / 922** | 183 / 204 / 231 |
  | B UI, starterkit repo | 10 | **985 / 1,043 / 1,343** | 246 / 261 / 336 |
  | C UI, greenfield repo | 10 | **1,199 / 1,256 / 1,343** | 300 / 314 / 336 |

  At a 13-byte project root these fall to 623 / 823 / 1,037 B respectively; at a 144-byte root they
  rise to 885 / 1,216 / 1,430 B. Per 40-unit run: **8,150 input tok** all-non-UI, **9,252 input tok**
  on a 30 non-UI + 10 greenfield-UI mix. The **round-3 `design_slice_text` → `design_slice_path`
  rename removed 9,754–9,808 B/bolt from this channel on a greenfield UI unit** (the retired key's
  exact `json.dumps(indent=2, ensure_ascii=True)` member was **9,911 B** — not the 9,635 B file
  size; newline and quote escaping is the difference), and 369–423 B on a starterkit UI unit.
  The previously published `3.0–3.6 KB/bolt = ~30K–36K/run, 41–63 % of it sections_omitted` is
  struck — that shape no longer ships. **No cost-weighted ratio is claimed in either direction:**
  the OLD flow's input debit was never quantified (the controller had to Read the unit, constitution,
  vault.json, starterkit-context.yaml, reuse-index.yaml, binding.md, upstream bolt-reports and pack
  bodies that the builder now reads in-process), and a one-sided weighting would be a fabricated
  comparison. Residency: this tool result is billed 1.0× once and then `cache_read` 0.1× on every
  subsequent controller turn — the multiplier is real, N is unmeasured, and no N is invented here.
- **Cost-weighted, OUTPUT CHANNEL ONLY** (`scripts/report-token-cost.sh`: input 1.0×, cache_read
  0.1×, output 5.0×). Old side **179,000 × 5.0 = 895,000 cost-units/run**; new side
  **5,780–12,510 × 5.0 = 28,900–62,550 cost-units/run**. Both sides are the same channel at the same
  weight, so the comparison is sound. **Do not add the input leg (8,150–9,252 cost-units/run at
  1.0×) to the new side and divide** — that would imply a total-cost ratio, and the old side's input
  debit is unmeasured. The input leg is an absolute, published above, and stands alone.
- **Wall clock: GROSS 19.9–59.7 min, NET 15–55 min (conditional — one term is assumed).**
  **Gross, recomputed from the CONFIRMED 179K:** 179,000 output tok ÷ 50–150 tok/s = 3,580–1,193 s =
  **59.7–19.9 min** per 40-unit run. **The previously published "gross 25–75 min" is struck: it does
  not reproduce from the confirmed 179K at the 50–150 tok/s band its own sentence states** (that
  arithmetic yields 20.5–61.4 min). Netted against it, per 40-unit run:
  - new-side generation of the residual: **0.6–3.8 min** (5,780–12,510 tok at 150–50 tok/s);
  - builder runtime, **MEASURED**: median **0.186 s/bolt** (n = 140, macOS, warm cache, clean
    `subprocess` timing; min 0.177 · p90 0.198 · max 0.223) → **7.4 s = 0.12 min over 40**;
  - builder spawn tax on the Windows/CrowdStrike target, **DERIVED not measured**: **6 exec'd
    binaries measured** here via a PATH shim (1 `bash`, 3 `dirname`, 2 `python3` — exactly the
    script header's count for the `--plugin-root`-passed form) plus the header's ~3 subshell forks
    ≈ 9 process creations × the operator's documented 220 ms floor = 1.98 s/bolt → **1.3 min over 40**;
  - one new subagent `Read` round-trip per bolt: **UNMEASURED and not measurable from here.**
    Assumed 1.5–4.5 s → **1.0–3.0 min over 40**. The bytes are a near-wash on non-UI units
    (`file_bytes` median 9,272 B vs the 8,942 B/bolt the old premise implies) and unquantified on UI
    units, where the file is larger (median 16,235 B starterkit / 18,688 B greenfield).

    > **These three medians are AS-OF the round-3 builder** (the 105-run pass) and have NOT been
    > re-measured since. Two round-4 changes shift them by measured constants: the corrected tracker
    > enumeration adds **+235 B to every unit**, and the `ui_bearing` gate's new omission line adds
    > a further **+216 B to non-`ui_bearing` units** — so the non-UI median reads **≈9,723 B** and
    > the two UI medians **≈16,470 / ≈18,923 B** when carried forward arithmetically. Carried
    > forward, not re-measured: stated so that re-running the documented method and getting ~9,723
    > reads as *this disclosure*, not as a builder regression or an unreproducible measurement.
    > The wall-clock arithmetic below is unaffected — a 451 B shift on a ~9 KB file does not move
    > the assumed Read term's 1.5–4.5 s band.

  **NET, worked corner by corner:** fast/macOS/low-Read `19.9 − 0.6 − 0.12 − 1.0 = 18.1 min`;
  fast/Windows-EDR/high-Read `19.9 − 0.6 − 1.32 − 3.0 = 14.9 min`; slow/macOS/low-Read
  `59.7 − 3.8 − 0.12 − 1.0 = 54.7 min`; slow/Windows-EDR/high-Read
  `59.7 − 3.8 − 1.32 − 3.0 = 51.6 min`. **⇒ NET ≈ 15–55 min per 40-unit run.** NET is explicitly
  conditional on the ASSUMED Read term; strike that term and the two measured/derived endpoints
  give **19.2–54.6 min**. A NET that hides an assumed term inside a single number is the shape that
  failed three times — the assumption is on the outside here.

The cleanest both-axes lever in the audit.
*Constraint:* the T2 truncation cascade is a moat surface — the script must reproduce it exactly.

**2c — collapse the per-bolt L0 fan-out to ~3 wrapper calls.** 13–16 sequential main-thread Bash
turns per bolt, re-run on every panel re-dispatch. **Gain: macOS ~14–29 min, Windows ~25–40 min per
40-unit run.** The merged-JSON contract is already specified in `code-gates.md`.
*Constraint (hard):* the wrapper **must** preserve the cheap→expensive short-circuit, or it does
strictly more subprocess work than today on a blocking run — a regression on the target platform.

> **DESIGN 2026-08-01 (tranche 2a/2c/2d).** One new script, `scripts/run-code-gates.sh` — the
> single-call L0 executor. It composes the five existing gate scripts **as-is** (subprocess calls,
> zero reimplementation: `detect-toolchain.sh`, `scan-secrets-code.sh`, `run-code-scan.sh`,
> `validate-new-deps.sh`, `check-dep-authorization.sh` — the last with its space-separated arg
> style preserved) plus the detected toolchain commands, in the shipped gate order, and emits ONE
> merged JSON to stdout: the exact payload the controller pastes verbatim as the
> `## Deterministic scan results` block into every lens prompt. The wrapper resolves its siblings
> from its own directory (`dirname $0`), which retires the per-bolt plugin-root resolver block that
> `code-gates.md` used to carry — one fewer Bash turn before any gate even ran.
>
> **Contract.** Args (house `--key=value`): `--cwd=` `--base=` `--head=` required; `--unit=`
> optional (absent → gate 6 recorded as a SKIP with reason, never silently dropped);
> `--no-code-gates` flag = the CLI opt-out; the `.mega-sdd/config.yaml` `code_gates: false` key is
> read by the wrapper itself — both skip gates 1–2, 4, 6 while **gates 3 (secrets) and 5
> (dep-existence) always run**, the un-disableable pair, unchanged. Exit codes: **0** = ran, no
> blocking finding (non-blocking findings ride in the JSON for the panel); **1** = a BLOCKING
> finding — the JSON carries the `halt` object (`secret_in_code` / `sast_critical_finding` /
> `dep_not_found`) and the controller emits that halt exactly as before; **2** = usage/environment
> error (bad args, unresolvable base/head, no python3) — nothing scanned, never reported clean.
> Every toolchain command runs under a per-command timeout (120s, mirroring the Bash-tool bound the
> controller had); a timeout is a visible per-gate failure note, never a hang and never a silent
> pass. Formatter `fix_cmd` auto-fix + re-check behavior is carried INTO the wrapper verbatim from
> the code-gates.md table, and any mutation it makes is disclosed in the JSON
> (`format.fix_applied: true`) so the controller sees the tree changed.
>
> **The short-circuit, made structural (the hard constraint above):** the wrapper runs gates in
> order and STOPS at the first BLOCKING result — later gates are recorded in `not_run[]`, their
> subprocesses never spawned. The test proves this behaviorally, not by trusting the JSON: a PATH
> shim `semgrep` that writes a marker file when invoked is planted, a secret-bearing commit is
> scanned, and the assertion is exit 1 + `secret_in_code` + **marker absent** (SAST never
> executed). Degradation paths are untouched because they live inside the gate scripts themselves
> (gitleaks runtime-failure → regex fallback stays in `scan-secrets-code.sh`); "a SKIP is visible,
> never silent" carries into the merged JSON per gate.
>
> **What the controller does after 2c:** ONE Bash call per bolt attempt (a panel re-dispatch
> re-enters at the same one call, over the same original-base..new-head range); paste stdout into
> the lens prompts. The before-side turn count, from the shipped procedure: 1 resolver block +
> 1 detect-toolchain + 2–4 toolchain check/fix commands + 4 gate scripts = **9–13 main-thread Bash
> turns per attempt** (the audit's "13–16" included base/head resolution and re-runs) → **1**.
> Wall-clock gain stays the audit's estimate (macOS ~14–29 min, Windows ~25–40 min per 40-unit
> run); the wrapper's own runtime is measured at ship time and reported as an absolute, not
> folded into that estimate.
>
> **MEASURED 2026-08-01 (n stated per arm, macOS warm):** wrapper floor — gitleaks/semgrep absent,
> fallback/skip paths — median **0.637 s/bolt** (n = 10, min 0.455 · max 1.415); with both tools
> live median **7.06 s/bolt** (n = 5), dominated by `semgrep --config auto`'s registry pull — a
> per-run TOOL cost identical in the per-turn flow it replaced, never quoted as wrapper overhead.
>
> **ROUND-1 (blind execution review, 2026-08-01) — 1 Critical + 2 Important + 7 Minor, all folded
> before ship:**
> - **Critical — unknown gate exit codes fell through to "pass".** The gate scripts call bare
>   `python3` internally; on the documented WindowsApps alias-stub environment (the v5.4.0 P0
>   history) every gate exits 49 while the wrapper's own resolve-python interpreter works — the
>   reviewer produced a run where a SECRET-bearing diff was certified clean at exit 0. Fixed:
>   per-gate rc sets are now closed — secrets {0,1} and new-dep {0,2-with-JSON} die exit-2 on
>   anything else (nothing certified), SAST degrades to a visible SKIP, and the test reproduces
>   the stub environment deterministically (a `WindowsApps/python3` stub + real `python`) proving
>   exit 2, never 0.
> - **Important — gate-6 vanished from the record on any short-circuit without `--unit`** (the
>   skip was recorded only when execution REACHED gate 6). Fixed structurally: skips for gates
>   decided off are recorded UP FRONT, and the test asserts a gate-accounting invariant — every
>   gate in exactly one of gates-ran/skips/not_run — on every path.
> - **Important — the config read matched a NESTED `code_gates:` key, last match winning** (an
>   off-schema nested block could silently disable SAST project-wide). Fixed: top-level key only,
>   first match wins, quoted values honored.
> - Minor, all folded: failing `fix_cmd` disclosed (`fix_rc`, re-check's output in `output_tail`,
>   die-path stderr warning when a fix already mutated the tree); the formatter-dirt aftermath
>   given an owner (controller commits the fix under the unit identity — pre-flight 3 enforces);
>   unresolvable `--unit` and a requested-but-unparseable `--pack` are visible notes, never silent
>   degradation; `range{}` pins resolved 40-hex SHAs; an internal crash exits 2, never 1 (exit 1
>   is only ever a blocking finding with its JSON present). The reviewer's process-group-kill fix
>   for timed-out command trees (M6) was IMPLEMENTED and then REVERTED: it requires a bare
>   `subprocess.Popen`, which the repo's bounded-subprocess law
>   (`tests/hooks/bounded-subprocess.test.sh` — every `subprocess.*` call carries `timeout=` on
>   the call itself) structurally forbids, and weakening that hook-tier scanner to fit new code is
>   the exact class this round exists to catch. The law wins; the residue — an orphan grandchild
>   of a timed-out toolchain command may briefly survive the direct-child kill — is disclosed in
>   the wrapper header and stands as a known Minor.
> - Carried open (Windows-only, unconfirmed by execution): the CPython `subprocess` reader-thread
>   hang past timeout when orphan grandchildren hold pipes, and native-Windows path-style OSError
>   handling — both land in the Windows validation lane, not this tranche.

**2d — one-line: `extract-intelligence` `--max-parallel` default 3 → 5.** 6 → 4 sequential agent
batches = **1.5×** on the agent-batch portion.

> **DESIGN 2026-08-01 (tranche 2a/2c/2d).** Flip sites: `extract-intelligence/SKILL.md` flag line
> (`default 3` → `default 5`; the soft-warn >5 and hard cap 8 stay), `commands/extract-intelligence.md`
> flag doc, and `orchestrate-flow/references/predictive-checks.md` `subagent_capacity_reasonable`
> `on_fail` text — which still asserts "the empirical optimum is 3 (the default)" and carries a
> garbled ".0+ per audit" fragment; both are replaced. **Supersession, stated:** the "optimum 3"
> claim predates 5d — its basis was per-dispatch coordination overhead in the era when every wave
> dispatch was model-assembled (~large output per in-flight subagent). After 5d moved the invariant
> contract into the `domain-extractor` body and the mechanical injections into
> `.dispatch-static.md`, the per-dispatch output is a compact variable core, so the overhead
> ceiling that justified 3 no longer exists; 5 stays under the platform's ~10-concurrent-task
> comfort zone and under the existing soft-warn line. Gain arithmetic unchanged: `ceil(N/3) →
> ceil(N/5)` batches; at the audit's 18-domain corpus that is 6 → 4 = **1.5×** on the agent-batch
> portion. No new measurement is claimed.

---

## Phase 3 — human stops

**3a — resolve-oq: 3 human round trips per OQ → 1.** Its own sibling reference already specified 1 —
but at FIVE options, over the platform's 4-option `AskUserQuestion` cap, and with Skip dropped; it
was reconciled, not copied. **SHIPPED** (`skills/resolve-oq/references/interactive-walk.md` Step 2b
is canonical; `recommendation-context.md` points at it and does not restate it).
*Constraint:* the mandated **keterangan** contract (question text + source + per-option explanation
in Indonesian) must survive on every prompt — see `references/output-language.md` and the
`oq-interaction-keterangan` rule. Merging the action menu with free-text capture must not degrade
the Defer/OOS/Skip affordance.

Shipped shape: `[1]` recommended answer · `[2]` Skip · `[3]` Defer · `[4]` Out of scope · "Other" =
the free-text answer + the destination override · **Esc = end the walk** (the plugin-wide reading of
Esc — `halt-recovery.md` and `propose-and-confirm-prompt.md` both use it for *cancel the activity*).
The considered alternatives lost their slot and moved into the question text as sourced prose; no
typed `STOP` sentinel exists (it would swallow a legitimate answer). The Defer follow-up is ONE
`AskUserQuestion` **call** carrying TWO questions — the platform's 4-option cap is per QUESTION, and
a call takes 1–4 of them.

**Gain — RE-DERIVED from the shipped procedure. The published "22 → 7–13 stops (`--auto`, N=8);
25–42 interactive" is corrected at the FLOOR only; the delivered work MEETS the published claim.**

Assumptions, on the outside: N = 8 OQs, **all P1** — the `--auto` column requires this, because
`--auto` defaults Step 0.6 to `p1-only`, so a mixed-priority N = 8 would put fewer than 8 OQs in the
queue and the closed form below would not be walking all 8; a clean vault (the conditional LOCKED-unlock prompt is
excluded from both columns); mix **5 Answer / 1 Defer / 1 Out-of-scope / 1 Skip**, one of the 5
Answers cross-cutting. Fixed logistical prompts per run = Step 0 vault + Step 0.6 scope
(+ Step 0.5 resume, which fires only when a prior round exists) = **2 interactive on a first pass,
3 on a resume; 0 under `--auto`** (all three default).

| Path | Prompts BEFORE | Prompts AFTER |
|---|---|---|
| Answer (incl. a bare `→ <file>.md` that accepts the recommendation) | 3 (action menu + answer + destination confirm) `+1` if cross-cutting | **1** |
| Skip | 1 | **1** (slot `[2]` on the same prompt) |
| Defer | 2 (menu + who/when) | **2** — one choice + ONE two-question follow-up call; kept by design (recorded state, invariant #5) |
| Out of scope | 2 (menu + rationale) | **2** — kept by design |

**Closed form, `--auto`:** `stops = N + (#Defer + #OOS)`. Answer and Skip cost 1; Defer and OOS cost
2 because their second value is recorded state that may not be invented.

- Floor = **N = 8** (nothing deferred). This is the one correction to the published band.
- At the stated mix: BEFORE `5×3 + 1 + 2 + 2 + 1 = 21`; AFTER `8 + 1 + 1 = **10**`, a **2.1×**
  reduction — **inside the published 7–13 band. The delivered work MEETS the published claim.**
- Interactive at the same mix: `10 + 2 = **12**` first pass, `10 + 3 = **13**` on a resume, against
  `23` / `24` before (**1.85–1.92×**).

What D4 (the one-call two-question Defer follow-up) bought: without it, a brownfield Defer costs 3
(menu + sub-target + reason) and the same mix lands at **11**, not 10. The arithmetic above assumes
the shipped one-call shape.

Correction to the published figure — one, not three:

1. The `22` baseline reproduces (21 at the stated mix) — that number stands.
2. **`7` is unreachable at N = 8.** The collapsed floor is exactly N: the human must see the prompt
   even to decline it, so 8 OQs cost ≥ 8 stops. A sub-N figure requires
   `--auto-accept-from-memory`, a different flag; plain `--auto` never auto-decides a substance
   prompt. **Published band `7–13` → `8–13`.**
3. **The ceiling is NOT widened.** An earlier draft proposed `13 → 16` on the grounds that an
   all-Defer/OOS round costs `8 + 8 = 16`. That is a target adjusted to the implementation and is
   retracted: the delivered work at the stated mix is 10, inside the published band. Readers who
   need a different mix have the closed form above; the acceptance band stays `8–13` at the stated
   mix.

The `25–42 interactive` pair is published without its N and does not reproduce at N = 8 in either
direction (42 needs N ≈ 13 with every OQ answered and cross-cutting). Superseded by the interactive
row above. This supersedes `research/2026-07-30-token-audit-end-to-end.md` §6.1 / §6.2 row 4 for
this lever; the audit's other rows are untouched.

Pinned by `tests/interaction-keterangan/test-oq-single-prompt.sh`; behavior fixture
`tests/skill-triggering/resolve-oq.test.md`.

**3b — batch the bind CONFLICT walk** using the `suggested_action` bind already computes.
**Gain: 2–4 stops** (not 6 — `KEEP_CODE` rows cannot batch; they patch the vault inline).

---

## Phase 4 — spawn tax (Windows-dominant, zero-token)

Exec counts below are **measured floors** (PATH shim, macOS, minimal fixture); 220 ms/spawn is the
operator's Windows/CrowdStrike floor applied uniformly.

- **4a (L3-4, highest value)** — memoize the framework-pack resolver (**measured 9 spawns per gate
  firing** → 36→4 execs) and stop re-walking bolt-artifacts (40→8). Most precisely verified finding.
- **4b (L3-1)** — substitute the 9 plumbing execs (`cat`/`sed`/`head`/`dirname`/`uname`/`grep`) on
  the **blocking** `PreToolUse` path.
- **4c (L3-2)** — gate the `Stop` hook's five bolt-artifact scans on "did this turn produce a commit
  or evidence artifact". Today the only guard is `[ -d .mega-sdd ]`. Measured 40 execs (20 `git`) of
  an 87-exec Stop total → **~24.9 min** per 400-tool-call run at an assumed 15% commit-bearing turns.
- **4d (L3-6) — pre-flight scripts ONLY** (`run-preflight-scan.sh`, `check-anchor-freshness.sh`).
  **Do NOT batch postflight/acceptance** — defers the `execute-bolts/SKILL.md:88` in-run STOP past
  N commits with no compensating gate.
- **4e (L3-3) — ONLY a per-turn debounce of the 4 unconditional project-wide scanners.**
  **Do NOT add PostToolUse glob filters:** only 7 validators are unconditional (not 13) and the
  filters **already exist** at `post-tool-use:788,799`. The finding's mechanism section is refuted
  and must be rewritten before implementation.
- **4f (L3-5)** — memoize B1 recompute inside the blocking hook. Magnitude deliberately
  unquantified pending a run with real bolt commits.

> **DESIGN 2026-08-01 (tranche 4, first release: 4a+4b+4c only).** Phase 4 ships in TWO releases,
> deliberately: 4a/4b/4c are the two HIGHs + the largest MED and live on the hook side; 4d/4e/4f
> are deferred to the follow-up — 4f touches the B1 recompute (the single riskiest moat surface in
> the set; it gets its own round), 4e's debounce is safe ONLY because of the gate-time re-derive
> architecture and deserves an unhurried proof, 4d is LOW. Splitting keeps each release's blast
> radius reviewable — the lesson of every prior tranche on this spec.
>
> **4a-i — the pack resolver gets a derived cache with a ZERO-EXEC hit path.**
> `_lib/resolve-framework-pack.sh` is the chokepoint 4 gate-firing validators call (ui-quality,
> cross-cutting, sibling-consistency, flow-coverage) — each call pays ~3 subshells + a python spawn
> for input that changes only when two project files or the pack files change. New: a derived cache
> under `<root>/.mega-sdd/.cache/pack-resolver/` (one file per `--section`/chain request, storing
> the exact stdout + the resolved chain + input-file existence fingerprint). **Hit-path validity is
> decided with bash BUILTINS only** — `[ -f ]` existence parity for `starterkit-context.yaml` /
> `codebase-map.md` and `[ cache -nt input ]` for BOTH project inputs, EVERY pack file in the
> cached chain, and the pack ROOT dir (a newly-added more-specific pack changes the dir mtime) —
> zero execs, no python, stdout byte-identical to a cold run. Any doubt (missing helper, mismatch,
> unreadable cache) falls through to the current cold path, which then rewrites the cache. The
> resolver's "writes NO state file" contract is amended honestly: the cache is DERIVED and
> DISCARDABLE (deleting it costs one cold resolve), never state. `-nt`'s "true when file2 is
> missing" hazard is neutralized by the recorded existence fingerprint.
>
> **4a-ii — the five `validate-bolt-artifacts.sh` gate/Stop calls become ONE composable call.**
> The scan flags are already independent if-blocks; the change makes them COMPOSABLE in a single
> invocation (`--orphan-scan --batch-suite-gate --postflight-scan --recompute --whitelist-scan
> --acceptance-scan`) sharing one bash spawn + one project-root resolve, and both call sites
> (pre-tool-use execute-bolts gate block, Stop hook) collapse 5 spawn-chains → 1. Each mode's
> python heredoc + its state file + its verdict semantics are byte-unchanged — this is call-site
> consolidation, NOT a scan merge; the deeper one-python merge from the research's 40→8 ceiling is
> explicitly out of scope until measured need.
>
> **4b — plumbing execs on the 8 hook entry tops become builtins.** The always-paid per-firing
> plumbing (`sed|head` cwd extraction, `$(dirname)` subshells, `date -u` where a timestamp is
> non-essential, config `grep`) is replaced with bash builtins: `[[ =~ ]]`/`BASH_REMATCH` for the
> stdin cwd extraction (same regex semantics as the shipped sed — first match wins), `${0%/*}` for
> script-dir derivation, builtin `read`-loop config probing. The extraction MUST stay byte-
> equivalent on the paths the shipped sed accepted — pinned by comparing both extractors over a
> corpus of stdin shapes (incl. Windows `\\`-escaped paths, the documented hazard class).
>
> **4c — the Stop hook's five artifact scans run only on turns that could change their verdict.**
> Guard today: `[ -d .mega-sdd ]` — 5 validator spawn-chains (~40 execs) on EVERY turn end. New
> guard, checked first with ~3 execs (git rev-parse + find + the stamp read): a stamp file `.mega-sdd/.stop-scan-stamp` records the HEAD
> sha at the last scan; the scans re-run when (a) `git rev-parse HEAD` differs from the stamp,
> (b) anything under `.mega-sdd/` (or legacy `docs/mega-sdd/`) is newer than the stamp
> (`find -newer` with memory/, .cache/, and the four auto-analyze report outputs pruned —
> broader than the bolts/ tree, in the safe direction; SUBDIRECTORY deletions caught via dir-mtime — under `-mindepth 1` a direct root-child deletion is invisible, and the stale side there is a recorded FAIL: over-blocking, never open), (c) the stamp is absent, or (d) HEAD is
> unresolvable (fail toward scanning). All five scans key on commits + evidence artifacts, so the
> two probes cover every input; a skipped turn leaves the state files exactly as the last scan
> wrote them — still-true verdicts, and the PreToolUse gate re-derives all of them anyway (the
> S6 EB-GATE-1 block), so a stale skip can never open a gate. The stamp is written ONLY after the
> five scans complete (a crash re-scans next turn — fail toward scanning).
>
> **ROUND-1 (blind static trace, 2026-08-01) — 0 Critical (the gate re-derive holds), 7 Important,
> all folded:** the turn-gate NEVER skipped in telemetry-active projects (the hook's own auto-analyze
> tail rewrites four report files after the stamp — now pruned, plus `-mindepth 1` because the
> `.mega-sdd` ROOT dir's mtime bumps on every direct-child write; a telemetry-fixture test arm now
> proves the skip where the saving was claimed); a failed `find` probe read as "no change" (fail-away
> — now rc-checked: doubt scans); Windows-native python wrote the cache CRLF so it NEVER validated on
> the target platform (writer pins `newline="\n"`, reader strips a trailing CR); the resolver header
> still claimed "writes NO state file" (amended at the contract itself); a resolver-CODE change did
> not bust the cache (`$0` is now an input); the cache writer could MINT `.mega-sdd/` in non-adopted
> projects (EB-GATE-6 — now gated on the dir existing); the two new hook-consumed files were outside
> the anti-self-bypass guard (`.stop-scan-stamp` + `.cache/pack-resolver/` added to both deny
> surfaces). Minor folded: "zero-exec hit" overclaim reworded (zero PYTHONS is the proven property;
> the prologue keeps two dirname subshells), the "each turn end" prose sites turn-gated, spec probe
> wording tightened to what shipped, `.gitignore` + `paths.md` cover the two new derived artifacts.
> Carried open (PLAUSIBLE, disclosed): the sub-second read-then-write race on ns-precision bash
> (parallel-sessions lane; safe direction preserved).

> **DESIGN 2026-08-01 (tranche 4, second release: 4d+4e only — 4f stays deferred to its OWN
> release and its own adversarial round; it touches the B1 recompute, the single riskiest moat
> surface in the set, and ships nothing here).**
>
> **4d — the two pre-flight scripts take a unit LIST; the controller pays one spawn-chain and one
> tool round-trip per batch, not per unit.** Both scripts gain `--units=U-001,U-002,…`
> (comma-separated; `--unit=` stays byte-compatible for a single unit — every existing call site
> and fixture is untouched). The per-unit halt semantics are NOT relaxed; what changes is only
> where the loop lives:
>
> - `check-anchor-freshness.sh --units=…` — read-only probe, so the batch processes EVERY unit
>   and reports every stale one in a single output (strictly more informative than N stops).
>   Fixed costs amortized once per batch: `rev-parse --show-prefix`, `git ls-files`, and
>   `walk_unit_commits` (which already computes ALL units' commits in one log walk — the batch
>   finally uses that). Exit: `2` fail-fast if any unit cannot run (unit not found — a controller
>   bug, not a verdict), else `1` if ≥1 not-yet-bolted unit has a stale anchor (halt
>   `anchor_missing`, every offending unit listed), else `0`. Advisory WARNs for already-bolted
>   units print per unit, exactly as today.
> - `run-preflight-scan.sh --units=…` — the baseline WRITER, so the batch is sequential and
>   fail-fast on every FATAL code: the first unit hitting `3/4/5/6/8` (or `2`) stops the batch and
>   the script exits with THAT code, the offending unit named on stderr and the unprocessed
>   remainder listed — the run was halting anyway, and a half-processed batch must be visible, not
>   silent. Exit `7` (post-hoc refusal) keeps its NON-FATAL contract: it is collected per unit,
>   the batch continues, and the final exit is `7` iff ≥1 refusal (stderr names each refused unit
>   so the controller can log each in its bolt-report). Successful units' artifacts are written
>   exactly as the single-unit path writes them — same schema, same immutable-keep, same
>   tamper-refusals; a fatal mid-batch leaves earlier units' already-written baselines in place
>   (they are valid artifacts; the re-run's immutable-keep/no-Hard-rules paths make re-batching
>   the same list idempotent).
> - `execute-bolts` SKILL.md pre-flight checks 3.7 + 4 now instruct ONE batched invocation over
>   all target units instead of a per-unit loop — the exit-code → halt map is unchanged (any fatal
>   code halts the run; the stderr names which unit fired it; **exit 2 is a PRE-LOOP abort — no
>   verdict/baseline exists for ANY unit, and both checks now carry an explicit "any other
>   non-zero → STOP" clause** so a controller can never read a rc-2 as "proceed"). Scripts
>   self-skip units with no `## Anchors` / no Hard rules, so the controller passes the full target
>   list without filtering. **Procedure step 1 KEEPS the per-unit re-capture** (round-1 static
>   finding 4): the old step 1 ran the writer at dispatch time, and a pre-commit re-run OVERWRITES
>   the batch baseline with the file state at THAT moment — folding it into the T0 batch would
>   have let a sibling bolt's legitimate commit to a later unit's `DO NOT modify` path read as a
>   false `hard_rule_violated` at post-flight. The 4d saving on this script is the check-4
>   validation loop (N→1); the step-1 dispatch-time capture is semantics, not spawn tax.
> - **The L3-6 boundary is untouched:** postflight/acceptance writers stay strictly single-unit —
>   batching them would defer the `execute-bolts/SKILL.md:88` in-run STOP past N commits.
>
> **4e — the 4 unconditional project-wide PostToolUse scanners get an input-keyed debounce**
> (bolt-artifacts, ui-deferral, vault-binding-coverage, vault-flow-staging — the Write|Edit arm's
> project-wide set; the three file-scoped unconditional validators unit-spec/vault-oqs/fsd-slots
> keep firing unchanged). Today all four re-scan the project on EVERY Write|Edit, including a
> 50-file source-code bolt run where none of their inputs moved. New guard, same architecture as
> the shipped 4c turn-gate: a stamp `.mega-sdd/.ptu-scan-stamp` records HEAD at the last scan; the
> four scanners are SKIPPED only when the stamp exists, HEAD resolves and equals the stamp,
> the written FILE_PATH is not itself under a mega-sdd tree (zero-exec case guard —
> `.mega-sdd`/`docs/mega-sdd`/`*-bound`), and a `find -mindepth 1 -newer <stamp>` probe over
> `.mega-sdd` + `docs/mega-sdd` + root-level `*-bound`/`*/*-bound` (glob-expanded, present dirs
> only) returns empty with rc 0. Fail TOWARD scanning on every doubt (stamp absent, HEAD
> unresolvable, find rc≠0); the stamp is written only AFTER all four scans complete.
> "Per-turn" (the research's lever direction) is subsumed: the guard is input-keyed, so it also
> skips across consecutive quiet turns AND re-scans twice in one turn when inputs actually change
> — strictly the safer refinement in both directions.
>
> - **Why a skip can never lie to a gate:** none of the four states is read by PreToolUse at all —
>   ui-deferral and vault-flow-staging are on the demoted-advisory list, and
>   `.bolt-artifacts-state.json` / `.vault-binding-coverage-state.json` appear at ZERO of the gate
>   aggregator's `L()` sites (verified against all 11, 2026-08-01). Every state the gate DOES read
>   is re-derived at the gate itself (S4/S5/S6 + §4a-ii). The only consumer of the four is
>   `/mega-sdd:analyze`, which re-runs the validators fresh. The residual staleness is therefore a
>   state file whose mtime is old — never a verdict anyone reads stale.
> - **Probe prunes (the F1 lesson, applied at design time):** derived outputs are never scan
>   inputs, so the probe prunes `memory/`, `.cache/`, the four auto-analyze report outputs, every
>   `.*-state.json`, `.validation-blockers.json`, `.ui-quality-blockers.json`, BOTH stamps,
>   `.dirty-paths.jsonl` — the living-vault journal this same hook APPENDS on every source write
>   in a mapped repo; without that prune the debounce would be vacuous exactly in the mapped-repo
>   case it exists for — plus (round-1 static finding 8) `state.json`, `graph.json`,
>   `.locked-files-index.json`, and `.compaction-snapshot.json`. The list is explicitly
>   NON-exhaustive: an unlisted derived file costs an over-scan on the turn it changes, never an
>   under-scan.
> - **The mirror is closed BOTH ways (fix-opens-its-mirror, pre-empted):** the 4c Stop probe gains
>   the same prunes (`.ptu-scan-stamp`, `.*-state.json`, `.validation-blockers.json`,
>   `.ui-quality-blockers.json`, `.dirty-paths.jsonl`) — otherwise the new stamp and the
>   PostToolUse validators' state rewrites would re-trigger the Stop scans every turn and silently
>   undo 4c; conversely the PTU probe prunes `.stop-scan-stamp`. The five Stop scans key on
>   commits + evidence artifacts only, and none of the pruned files is either — the widened Stop
>   prune also extends 4c's skip to write-bearing turns whose writes touched no scan input, same
>   safety argument, disclosed here as deliberate 4e scope.
> - **New derived artifact, full registration:** `.ptu-scan-stamp` joins `.stop-scan-stamp` on
>   every surface — the Write/Edit deny list (the deny MESSAGE now names both stamps), both Bash
>   anti-self-bypass PROTECTED regexes, `.gitignore`, and `references/paths.md`. Carried open,
>   same as 4c (PLAUSIBLE/CONFIRMED-inherent, disclosed): the sub-second read-then-write race on
>   ns-precision bash (parallel-sessions lane); a DEPTH-1 deletion directly under a probe root
>   (only the root's mtime moves, which `-mindepth 1` excludes — commented at the guard); and a
>   backdated-mtime shell edit evading `find -newer`. All three share the same stale side: an
>   un-refreshed ADVISORY state file — never a gate verdict — and analyze re-runs fresh.
>
> **ROUND-1 (dual blind, 2026-08-01) — 0 Critical shipped, all folded pre-ship.** The EXECUTION
> reviewer (7 attack lanes, all fixtures) returned SHIP with 3 inherent Minors (above); every
> constructed attack on batch isolation (PATH-strip mid-batch, dedupe/whitespace arg abuse,
> legacy `*-bound` + monorepo-PREFIX fixtures, exit-8 protected-path bleed both orderings,
> deny-surface live-fire incl. `tee`/`sed -i`/`rm+touch`, Stop-lane evidence-class preservation)
> held. The STATIC reviewer returned FIX-FIRST; findings folded: (1+2) the exit-2 lane had NO
> controller mapping and the batch turned one bad unit id into a whole-gate skip — both checks
> now carry the explicit STOP clause and the "remainder listed" prose no longer claims rc-2
> discloses a remainder (it is a pre-loop abort); (3) the `build-dispatch-prompt.sh` "can never
> disagree" anchor-regex pin pointed at rotted line numbers and was enforced by nothing — now
> line-number-free AND pinned byte-identical by the 4de test; (4) **the near-Critical**: the
> first cut moved baseline capture from dispatch time to T0 undisclosed — step-1 re-capture
> restored (see the 4d bullet); (5) the mutual-prune direction-1 test arm was vacuous (the PTU
> firing it observed was itself a skip) — the arm now forces a genuine scan and proves the state
> rewrite happened; (6) `snapshot_at`/`head_sha` were batch-wide — now stamped per unit at write
> time; (7) the deny message did not name the stamps it blocks; (8) four unlisted derived files
> made the debounce silently not pay after a session start / graph derive / compaction — pruned,
> list declared non-exhaustive; (9) the legacy `docs/mega-sdd` + root `*-bound` probe arms were
> untested — both now have fixtures.

> **DESIGN 2026-08-01 (tranche 4f — the L3-5 lever is AMENDED: the memo is REJECTED on
> measurement + trust analysis; what ships is BATCHING inside the recompute, at zero trust-model
> change).** L3-5 said "memoize B1 recompute inside the blocking hook; magnitude deliberately
> unquantified pending a run with real bolt commits." The run now exists (PATH-shim, macOS,
> N = 0/5/10 committed Hard-rule bolts, honest artifacts via the real writers):
>
> - **Common v1 mix** (DO_NOT_MODIFY with a preflight snapshot — in-process sha256; DEPS rule
>   whose manifest no bolt commit touched): recompute marginal cost = **1 exec** (the HEAD
>   rev-parse). There is nothing for a memo to save.
> - **Worst v1 mix** (per unit: 1 SIGNATURE rule + a manifest-touching DEPS commit): **41 git at
>   N = 10** — 10 `git grep` (one per SIGNATURE name) + 10 parent `rev-parse --verify` + 20
>   before/after `git show` pairs + 1 HEAD ≈ **~9 s per gate firing on the Windows floor**.
> - **v2 (ast-grep) rules** — the only place minutes live — **cannot be memoized soundly at
>   all**: the scan covers UNTRACKED files, whose content changes are invisible to HEAD, to
>   `git status --porcelain` (same `??` line), and to any enumerable-input hash.
> - **Trust analysis (the reason the memo dies even where it is computable):** any memo hit
>   path trusts (memo + artifact) disk consistency. A co-forgery via an exotic write path —
>   exactly the attacker the verb-enumeration deny is documented NOT to stop — would then
>   survive to the gate read. B1 recompute-at-gate exists BECAUSE "the write-guard is a
>   best-effort deny, not a cryptographic guarantee — recompute is the durable hardening"
>   (CLAUDE.md). A memo reintroduces trust in the best-effort layer at the single most
>   load-bearing moat gate: fix-opens-its-mirror at moat scale. REJECTED.
>
> **What ships instead — same computation, fewer processes, re-derived from ground truth on
> EVERY firing (the 4a-ii doctrine, applied inside the scan):**
>
> - **4f-i — SIGNATURE decl lookup batches to ≤4 greps per firing** (one per declaration
>   pattern, all unresolved names as an ERE alternation), replacing one `git grep` per name.
>   Per-name semantics byte-identical: names resolve at the FIRST pattern (in the existing
>   priority order) yielding a usable line, matches are re-attributed per name python-side with
>   the same regex translated to line-context, and the `.md`/vault self-match filter is
>   unchanged.
> - **4f-ii — blob reads batch through ONE single-shot `git cat-file --batch`** run
>   (`subprocess.run` with the full request list as stdin and the standard 60 s bound — no
>   interactive pipe management, Windows-safe, honoring the bounded-subprocess law): the
>   per-unit `unit_text` at-commit reads (paid in BOTH modes — the N-scaling term of every gate
>   AND Stop firing), the DEPS before/after manifest pairs, and the parent-existence probes.
>   Requests are fully known up front (two phases: unit texts first, then the rule-derived
>   pairs). The rare non-JSON `git diff` fallback lane stays per-commit (bounded, unchanged).
> - The single-unit writer path (`run-postflight-scan.sh`) is byte-unchanged — `scan_unit`
>   takes optional prefetch callbacks, defaulting to the current per-call subprocesses.
> - Expected: worst-v1 recompute delta 41 → ≤6 execs, and the shared unit_text term drops
>   N → 1 in both modes; v2 keeps its per-rule `ast-grep` + 120 s bound untouched.
> - **The moat pin:** the `recompute_unit` call is unconditional WITHIN the obligation branch —
>   a forged `postflight.json` is still overwritten from ground truth on every firing,
>   test-pinned (including under a cat-file kill-switch: batch failure degrades to solo,
>   never opens). The obligation predicate (`has_hard_rules`) now reads the BATCHED unit
>   blob — which is why the stream-integrity guards below are load-bearing, not hygiene.
>
> **ROUND-1 (dual blind, 2026-08-01) — both reviewers FIX-FIRST, all folded pre-ship.**
> Static (3 High / 3 Medium / 2 Low): the `batch_cat` parser consumed replies positionally
> with NO stream validation — a truncated/desynced stream (rc≠0 with partial stdout, or a
> crafted newline-bearing dir name adding an input line) could erase a unit's B1 obligation
> or hand DEPS a wrong blob (CLOSED: newline-bearing requests dropped to solo, rc≠0 → `{}`,
> truncated-slice + total-consumption checks); strict-UTF-8 `.encode()` raised an uncaught
> `UnicodeEncodeError` on surrogate-escaped paths and the gate crash direction is a stale
> PASS (CLOSED: surrogateescape + `except Exception → {}`); the unresolved-decl `(None,
> None)` was returned as a RESULT so the solo fallback was dead code and the byte-identical
> claim false (CLOSED: unresolved names are OMITTED = MISS → solo second opinion); one bad
> SIGNATURE name could take down the whole alternation round (CLOSED: rc≥2 = no-information
> + ≤100-name chunking, which also caps the O(lines×names) re-attribution); the DEPS
> diff-fallback funnel widened by a `./`-prefixed manifest in the explicit request (CLOSED:
> normalized; the diff lane's own rc-blindness stays pre-existing, disclosed); batch
> timeout lowered 60→20 s so a wedged git costs one short ceiling, not an additive full
> one. Execution (9 hostile parity fixtures, truncation/kill-switch shims): lone-`\r`
> (classic-Mac) unit text collapsed to one line under the batch decode and ERASED the
> obligation where solo universal-newlines caught it — a measured fail-open (CLOSED:
> `\r`→`\n` at both decode sites); truncated-stream wrong-verdicts (CLOSED by the same
> stream guards); Windows `os.sep` in rev-path requests normalized (pre-existing, fixed in
> passing — run-postflight-scan.sh precedent). Test arms added: pattern rounds 2/4, prefix
> pair, ghost name (solo-second-opinion), cat-file kill-switch. Everything else held:
> substring/metachar names, CRLF fixtures, EMPTY_TREE + non-JSON lanes, untracked/deleted
> vaults, poison paths, forgery on every firing; measured delta 3 git (≤5), Stop lane 14→5.

---

## Phase 5 — cost-only levers (accept the latency penalty; decide by the payback rule)

Payback rule (§2 of the research doc):
`0.1 × (resident_old − resident_new) × turns_remaining > 2.0 × seed` (1h TTL, main lane).

- **5a — fork `scan-codebase` + `bind-codebase`.** **~2.0M cost-units (floor 1.7M) = 11–16% of
  main-thread cost.** Costs latency. **Audited 2026-07-30 — see the amendment below.**

### 5a amendment — findings of the fork-safety audit

Full report + evidence: [`research/2026-07-30-fork-safety-audit-scan-bind.md`](../../../research/2026-07-30-fork-safety-audit-scan-bind.md)
(13 agents, 6 dimensions each adversarially refuted). **Three things in the line above were wrong.**

**Wrong #1 — the scoping.** "One missing `--auto-policy` paragraph another skill already ships
verbatim" understates it. Verbatim reuse is also *incorrect* here: `generate-units` can take
`--skip-pagerank` as its safe default because PageRank is advisory and `execute-bolts` ignores it;
scan's extraction **is** the deliverable. Real scan work = 4 prompt sites + 1 behaviour table +
1 warnings channel + 1 unconditional handoff. Real bind work = a deterministic Step 0 + one stale
reattribution + one declaration.

**Wrong #2 — the named risk was the wrong risk.** "A fork could change where
`.validation-blockers.json` lands and break the CONFLICT gate" is **REFUTED** on three independent
mechanisms: bind **never writes that file** (sole writer is `scripts/validate-handoff-binding-units.sh:85`,
invoked by hooks with a hook-computed `--cwd`); the state is **recomputed at the gate before it is
read** (`hooks/pre-tool-use:421-422` then `:474-494`, fail-closed); and direct writes are hard-denied
(`:774/:804/:924/:951`). **The moat is fork-immune here, and it is immune by recompute-at-gate — not
by anything the skill body says.** The June "producer-timing race" is stale for the moat.

**Wrong #3 — the real blocker is elsewhere, and it is not fixable by editing prose.**
`bind-codebase` dispatches `phase-advisor` **by default** (`SKILL.md:58`). Whether a `context: fork`
body can dispatch an `Agent` at depth 2 is **doc-cited but never exercised** — and the `detect-drift`
pilot cannot settle it, because detect-drift dispatches no subagent at all.

**Verdicts:**

| | verdict |
|---|---|
| **scan-codebase** | **GO** after a bounded edit set — no unresolvable risk remains |
| **bind-codebase** | **NO-GO until the depth-2 probe returns** |
| **both** | gated by **Precondition 0** below, which pre-dates this audit |

**Precondition 0 (the project's own contract, `plugins/mega-sdd/CLAUDE.md:69`):** fork may be
extended to scan/bind *only after* the live token before/after on `detect-drift` confirms the win.
It has never produced a verdict — the only attempt failed because `context: fork` silently no-ops
under `claude -p` (`research/2026-07-20-fork-ab-headless-attempt.md`). **Two interactive runs are
required, and RUN 1 does not clear RUN 2's question:**
- **RUN 1 (pilot):** one `/mega-sdd:sync` on a Mode-D brownfield repo, invoked **from a
  sub-directory**. Measures (a) the token win per the scaffolded procedure, (b) whether a forked
  skill's handoff reaches the orchestrator's capture point, (c) CWD inheritance — do artifacts land
  at the canonical root?
- **RUN 2 (depth-2 probe):** a `context: fork` skill whose body attempts exactly one `Agent`
  dispatch. Gates bind, and also decides whether scan's default-on deep-scan stage survives a fork.

**Decisions taken (they cannot be inferred from any existing rail):**
- **Spawn-cost gate → a THREE-LANE split** (**AMENDED 2026-07-30**, see below). Lane 1: an explicit
  `--engine=`/`--include=` IS the caller's decision → proceed, log the estimate. Lane 2, **undecided
  STANDALONE** (a direct user invocation): the named `scan_spawn_budget_exceeded` blocker carrying
  the re-run command. Lane 3, **UNATTENDED** — `--auto`, a forked body, or an
  orchestrator-dispatched phase (how the Mode-D `--changed-only` hop arrives), ambiguity resolved HERE: **downgrade to `--engine=regex`
  and RECORD it loudly** — `precision_tier: regex` + a new `precision_downgrade_reason` in the map frontmatter, one
  chat line, and the AST-recovery re-run command in the handoff `next_action.rationale`;
  `status: completed`, no `blockers[]` entry.

  > **What this amendment corrects.** The first cut took the blocker UNCONDITIONALLY. That was a
  > **live regression, not a future one**: the pre-existing `--auto` behaviour *proceeded*, and
  > **zero** orchestrate-flow routing rows carry `--engine`/`--include`/`--force-large`, so a chain
  > cannot pre-resolve the gate the way `handoff-contract.md` pre-resolves `bind-codebase <vault>`.
  > `scan-codebase` is phase 1 of nearly every brownfield row, and on Windows (~0.22 s/spawn) the
  > gate trips at only **~272 files** — so an unconditional blocker hard-stopped nearly every
  > brownfield chain at phase 1, on the common case. Restoring a bare "proceed" was equally wrong:
  > that re-opens the unattended multi-hour stall the gate exists to close (100k files ≈ 6.1 h).
  >
  > **Lane 3 is NOT keyed on the `--auto` literal**, and this is load-bearing: **zero** routing rows
  > render `--auto` on the *scan* hop either — `routing-rules.md` writes phase 1 as bare
  > `scan-codebase` / `scan-codebase --changed-only`, and only the DOWNSTREAM hops carry the flag,
  > because scan is phase 1 and nothing hands IT a handoff. A flag-literal lane 3 would have put
  > every chain-dispatched scan back in the blocker lane — the regression, re-created inside its own
  > fix. The condition is unattended-ness (`--auto` / `--changed-only` / forked / orchestrator-
  > dispatched), and ties resolve to lane 3 because the failure modes are asymmetric: a wrong lane 3
  > is a recoverable, loudly stamped regex map; a wrong lane 2 is a chain that produced nothing.
  >
  > **Why lane 3 is legitimate, written down in `scan-procedure.md §Spawn-cost gate` rather than
  > assumed.** (a) The house rule is that `--auto` takes the SAFEST option
  > (`generate-units/references/pagerank-targeting.md` §`--auto` policy), and unattended, "safest" is
  > neither a multi-hour stall nor a phase-1 chain halt — it is finishing in seconds at a precision
  > the map states honestly. (b) It does NOT violate `scan-procedure.md`'s *"Do NOT silently downgrade
  > the engine"* rail, because **that rail protects the RECORD, not the action** — the governing
  > sentence is pagerank's own *"The `--auto` skip is not a SILENT skip — 'silently' is about the
  > record, not the action"*, and the record here (durable map frontmatter + chat + handoff) is
  > STRONGER than the one that sentence blesses. (c) It does not port back to pagerank's rail either:
  > `generate-units` is a **CONSUMER** mutating already-written upstream state; `scan-codebase` is the
  > **PRODUCER** stamping its own output in the same write. Lane 2 keeps the rail's original force
  > exactly where it has a human to hand the choice back to.
- **Monorepo rail → deterministic precedence** (explicit `--include` > root manifest > single
  app-root manifest), blocker only on residual ambiguity. A bare blocker is not acceptable on its
  own: **zero** orchestrate-flow routing rows carry `--include`/`--engine`/`--force-large`, and scan
  is phase 1 of nearly every brownfield chain — an unthreaded blocker converts a one-time question
  into a phase-1 chain halt for every monorepo user.
- **Warnings channel → the secret-scan warning must be routed to disk.** scan's handoff schema
  carries `blockers[]` only. The map stores `[REDACTED-SECRET]`; the live credential's `file:line`
  exists **only in chat** (`scan-procedure.md:451`) and a fork would swallow it.

**Closed after the adversarial re-review (2026-07-30, same day):** besides the spawn-gate lane split
above — bind's handoff is now **unconditional** at both sites (`bind-codebase/SKILL.md` §Hand-off +
`references/auto-memory-handoff.md`), which was scan's B8 defect with no C-item counterpart: a direct
`/mega-sdd:bind-codebase` run never injects `--auto`, so an `--auto`-gated handoff emitted nothing at
all on the standalone lane — the one lane with no chain to fall back on, and the one where
`bind_conflict` / `bind_inputs_missing` most need a route out. Also closed: the C2 glob-root
constraint now binds at **direct-child** level (`vaults/<slug>/`) rather than the looser "under
`.mega-sdd/vaults/`", matching the four non-recursive globs at
`scripts/validate-handoff-binding-units.sh:123-128`; the deep-scan scrub sites
(`deep-scan-dispatch.md` Step 10.5.3 steps 3+6) now implement the SECRET-FINDINGS.md routing that
`halts-flags-handoff.md` claims for EVERY scrub site.

**Fixable today, independent of 5a — do not wait for the runs:** three surfaces already describe
`bind-codebase` as forked while its frontmatter carries no `context:` key, and two of three render
the sync-lane handoff as bare `bind-codebase --auto` with **no vault signal** on the one lane where
both downstream phases are forked (`routing-rules.md:92` + `scan-procedure.md:49` vs
`halts-flags-handoff.md:110`).
- **5b — `codebase-map.md` deriver (`scripts/derive-codebase-map.sh`). SHIPPED v5.19.0
  (2026-08-01).** Measured pre-change baseline **37.6K cost-units per write**, ≥188K lifetime;
  the map was re-typed **in full** on every write — worst on
  the `--changed-only` sync lane, whose merge semantics DEMAND byte-identical carry-forward that
  the model delivers by retyping every unchanged row at the 5.0× output weight.

  **Division of labour.** The model stays what it must be — the extraction-output parser (its
  tool-result reads of tree-sitter/rg output) and the author of the judgment sections (§5 naming /
  §6 patterns / §7 framework). Everything else moves to the deriver: the model writes a small
  **delta** (`$SCAN_TMP/delta/`: `frontmatter.json` + `s2.rows`+`s2.files` + `s3.rows` +
  `s4.rows`+`s4.files` + `s5.md`/`s6.md`/`s7.md`, rows in the map's own format but WITHOUT the
  sha256 column) and the script assembles the map: §1 tree rendered from Step 4's `files.z`
  (box-drawing, depth-limited — the model never types the tree), `Last_Scanned_Sha256` joined
  from Step 5's `hashes.txt` (which exists only on the `--shallow-scan` lane) or hashed
  in-process via hashlib — either way the model never types 64-hex again — replace-set merge
  per section (canonical-header-gated: a touched §2/§4 whose prior column order is
  non-canonical is exit 3, never a positional guess), atomic temp+rename with the validator
  gating the TEMP before the rename (a rejected assembly never overwrites a good prior map). `--mode=full` (all
  sections from the delta) and `--mode=merge` (absent delta section = carry the prior's,
  byte-identical; §2/§4 replace by `s*.files`, §3 whole-section-or-carry).

  **The 4 prose-trusted anti-hallucination rails, made structural:**
  1. *Carry-forward byte-identity + original `Last_Scanned_Sha256`* (scan-procedure §Anti-halu
     rail) — carried rows are byte-COPIES of the prior map; only delta rows get fresh hashes.
  2. *"A merge that cannot prove a row's provenance (prior map corrupt) → fall back to full
     scan"* — an unparseable/section-missing prior in merge mode is **exit 3 `fallback_full`**,
     nothing written; the caller re-runs a full scan.
  3. *"DROP rows whose file vanished"* — prior §2/§4 rows whose `File` no longer exists on disk
     are dropped by the script (in-process existence check, zero spawns) and counted in the
     stdout JSON; §3 deletions ride the model's whole-section replace (its `Handler` column has
     no reliable path key).
  4. *Schema shape* — all 7 sections always present ("None detected", never omitted);
     `generated_at`/`generated_by`/`repo_root` script-stamped; `last_scanned_commit` from the
     script's own `git rev-parse --verify 'HEAD^{commit}'`, OMITTED on failure or a literal
     `HEAD` (the zero-commit poisoning rule enforced where the stamp is minted).

  **Chained, so the write-path gates are structural too:** the deriver runs
  `secret-scan.sh --redact` on the assembled temp (Step 10a — findings JSON passed through on
  stdout for the model's `SECRET-FINDINGS.md` routing), renames atomically, then refreshes
  `validate-codebase-map.sh --quiet` (the post-write state-freshness step). Constant spawn
  count per write, no per-item fan-out.

  **Deliberately NOT in scope, named:** parsing tree-sitter capture output inside the script —
  the dev box ships no compiled grammars, so that parse cannot be verified here, the exact
  reason scan-procedure §Step 5 refuses to change the per-file invocation; shipping an
  unverifiable parser would be fabrication-by-code. The model remains the extraction parser.

  **Measured (2026-08-01, synthetic 200-file fixture — method scripted, reproducible; 4 B/tok):**
  FULL scan — map 37,885 B, model-typed delta 17,365 B ⇒ **54% of the map's bytes no longer
  typed** (2.18×; ≈5.1K output tok ≈ 25.6K cost-units per full write at the 5.0× weight).
  MERGE with 5/200 files changed — the model types **537 B** against the old full retype of
  37,930 B ⇒ **70.6× on the sync lane** (≈9.3K output tok ≈ 46.7K cost-units per sync write) —
  the lane the ≥188K lifetime floor lived on. The 37.6K/write research figure stands as the
  pre-change baseline (and the synthetic map's 37.9 KB size lands on the same scale, which is
  consistency, not proof). Pinned by `tests/token-efficiency/test-derive-codebase-map.sh` —
  rails 1–4 proven behaviorally (incl. the mutate-on-disk no-rehash proof for rail 1).
- **5c — intent-leg phase-advisor seed dispatch. SHIPPED v5.20.0 (2026-08-01).** The P7
  slice-first fix was wired to the **bind leg only**; the intent leg's Step 3.7 still pasted the
  drafted 7 vault files + the whole source into the fresh `phase-advisor` subagent —
  **15–50K tok per dispatch, central ~30K (research §6.2 row 11's measurement; not re-measured
  here — no live vault run exists in this repo to measure against, and the pasted-corpus size IS
  the vault+source size, project-dependent by construction).** Unlike bind, the intent leg needs
  **no bundle builder**: after Step 3 every claim, OQ text, and classification bracket the
  advisor hunts (fabrication / missed_oq / misclassification / coverage_gap) is already ON DISK
  — the five JSON-only recommend fields (`scan_query`/`recommendation`/`rationale`/
  `scan_citations`/`fallback_if_wrong`) are NOT (they ride the Step-3.8 authored patch) and are
  out of this pass's scope. The dispatch carries the vault DIR path + the source file PATHS +
  the scope id / phase N-of-total on filtered runs + the OQ roll-up counts — a seed of a few
  hundred bytes — with a **fail-closed pre-dispatch path check** (an unresolvable source is
  `advisor: unavailable`, never clean) and two carve-outs (sibling-scope/out-of-phase source
  sections are not `coverage_gap`s; MCP-loaded Figma has no path and never grounds a
  `fabrication`). **The trade, stated, §5d-style:** the removed side is the pasted corpus as
  main-thread OUTPUT at the 5.0× weight (research's 15–50K/dispatch — GROSS, project-dependent);
  the advisor now re-reads much of the same corpus as fresh subagent INPUT at 1.0× — so the net
  is the 5×→1× weight differential plus whatever the advisor's selective reads skip, and **no
  net constant is quoted** because the corpus size is the project's. The seed-not-horizon
  invariant ships as contract prose in BOTH homes; `coverage_gap` explicitly REQUIRES the
  whole-on-disk-source sweep (inside the carve-outs), mirroring bind's `missed_match`
  whole-map grep. Pinned by `tests/token-efficiency/test-5c-intent-advisor-seed.sh` —
  **prose-contract pins** (both legs' expansion contracts, the no-paste dispatch shape,
  bind parity, agent tools); the BEHAVIORAL seed-not-boundary fixture lives on the bind leg
  (`tests/phase-advisor/test-advisor-bundle.sh`, which plants evidence outside the bundle and
  proves it reachable), and the intent leg's rails are prose-tier by design — same tier as the
  dispatch they guard.
- **5d — extract-intelligence dispatch: invariant into the agent body, injections into a script.
  SHIPPED v5.18.0 (2026-08-01).** The research row's premise held (no template; the invariant was
  model-typed per dispatch) but its **~150K/run (~129K output) figure did NOT reproduce and is
  superseded by the measurements below** — same rule as Phase 0: the measured number replaces the
  estimate, whichever direction it moves.

  **What shipped.** (1) The invariant contract — DISCIPLINE deltas, EXTRACTION DEPTH, DEEP
  DISCIPLINES P1–P4+P6, REPORT BACK + both self-check rails, glossary-index usage, tech-agnostic
  output scoping — moved wholesale into `agents/domain-extractor.md`, the subagent's SYSTEM prompt:
  it loads on every `domain-extractor` dispatch by construction — extract-intelligence is its sole
  dispatcher, and that agent choice remains prose-stated, not validator-enforced — so a hurried
  controller can no longer truncate the contract the way a typed block could be (the delivery moved
  UP the gates>rules ladder); it is byte-identical across all ~15 dispatches (the strongest cache
  position), and the model types none of it. (2) The two mechanical injections —
  the `<STACK_IDIOM_ROWS>` slice and the `<GLOSSARY_INDEX>` — are derived by
  `scripts/build-extract-static.sh` into `<kb>/.dispatch-static.md` (run at Wave 0, re-run after
  the Wave 1 gate; atomic; fail-closed exit 2; the MASTER idiom table is PARSED out of
  `wave-dispatch-templates.md` at run time so the single-copy rule is structural; the glossary
  `short_def` is a verbatim word-boundary prefix — the model-paraphrase surface is gone). Every B1
  slicing rule is preserved and now script-enforced. (3) The typed dispatch is the variable core
  only: ROLE/CONTEXT/SEED/READ-FIRST/FILES/OUTPUT/TEMPLATE + the wave SCOPE blocks (wave depth
  deltas deliberately stay model-typed prose — the script owns mechanical derivations only).

  **Measured (2026-08-01, against the shipped tree; 4 B/tok both sides):**
  - Skeleton fence, old → new: **9,836 B → 772 B = 9,064 B/dispatch** of invariant the controller
    no longer types. This is a FLOOR for the typed reduction: the old flow additionally typed the
    idiom slice (**820 B** measured at 2 detected stacks / **920 B** full-table fallback, per
    dispatch × ~15) and the glossary index (project-dependent, ×12 — format overhead measured at
    ~95–112 B/term; an 80-term glossary ⇒ ~8 KB × 12) ON TOP of the fence.
  - Per 15-dispatch run, fence term alone: 9,064 × 15 = 135,960 B ≈ **34.0K output tok ≈ 170K
    cost-units at the 5.0× output weight**. With the slice term: +12.3–13.8 KB/run ≈ +3.1–3.4K tok.
    The glossary-index term is published as a formula (`index_bytes × 12 ÷ 4`), not a constant —
    no field glossary exists in this repo to measure one honestly.
  - Also removed from the MAIN thread: the 80–120 KB glossary read (the script reads it now, in a
    subprocess — the bytes never enter any model context).
  - **The trade, stated:** the agent body grew 3,589 → 13,920 B (**+10,331 B ≈ 2.6K tok**) of
    subagent INPUT. Worst corner (all 15 dispatches cache-miss at 1.25×): ~48K cost-units — still
    ~3.5× cheaper than the 170K output-side floor it replaces. Realistic corner (1× creation +
    14× cache_read 0.1×): ~6.8K cost-units, ~25×. The `.dispatch-static.md` Read per subagent is
    a near-wash — the same bytes previously arrived as prompt input.
  - Wall-clock: ~136 KB/run of serial main-thread generation removed ≈ **34K tok ÷ 50–150 tok/s =
    3.8–11.3 min per extract run**; builder runtime is one python spawn ~2×/run (constant, no
    per-item fan-out).

  **Pinned by:** `tests/token-efficiency/test-extract-dispatch-static.sh` (script: parse/slice/
  gloss/atomicity/leak-scan-exclusion), the rewritten `test-b1-wave-dispatch-diet.sh` (relocation
  1:1 — every moved block present verbatim in the agent body; the fence carries the variable core
  only), and `tests/fixtures/iter80-extract-deepening/verify.sh` (disciplines reach every subagent
  — now by construction). Amended into the tech-agnostic spec (2026-08-01 note under the B1
  amendment).
- **5e — FSD + PRD builder scripts** (SIT/UAT already have them). Highest effort; do last.

**Explicitly deprioritised (measured ceilings, not worth the effort):** the always-on surface
(**0.16–0.31%** of a long run) and the output lane as a whole (**~3%** of a single-pass run — its
leverage is write *multiplicity*, not artifact size).

---

## Phase E — the `--lean` profile (the last 20–30%, and the only tranche that costs capability)

Operator reaffirmed the 90% target after seeing the arithmetic. A–D reach ~60–70% with nothing
given up; the remainder can only come from **doing less work**. So it ships as a named, opt-in
profile that states exactly what it turns off — never as a silent default and never as an
"optimization".

**What `--lean` may turn off (each one is a real capability, listed so the operator chooses):**
- **`phase-advisor` adversarial second opinion skipped** on the intent and bind legs.
- **Optional emissions skipped** unless explicitly requested (`emit <prd|fsd|sit|uat>`).
- **`extract-intelligence` wave depth reduced** — fewer domain slices, shallower KB.
- Non-blocking advisory surfaces (`/mega-sdd:analyze` aggregate) not auto-run.

**What `--lean` must NEVER touch — these are not token line items:**
the CONFLICT gate and its blocking behaviour, binding verdicts, citation discipline, the halt
taxonomy, the no-fabrication rule, the B1–B4 artifact gates, anti-self-bypass, review-lens
blindness, **and the review-panel risk tiering**. A lean run must still be a *correct* run; it is
allowed to be a less thorough one.

> **Review-panel tiering is explicitly out of scope for `--lean`, and this is deliberate.** Forcing
> the panel to `minimal` is the most tempting remaining lever and it was already evaluated: Batch-4
> measured the risk tiering and **kept** it because cutting it dulls the moat, and the plugin
> contract states the tiering is by design. Re-framing it as "the operator's choice" is exactly how
> a gate erodes — the token target does not get to buy its last points out of the moat. If A–D plus
> the rest of E do not reach 90%, the honest answer is that 90% was not reachable, not that the
> panel should shrink.

**Contract:** `--lean` announces its own reductions in the run header, records them in the
handoff, and stamps the profile into `TOKEN-COST-REPORT.md` so a lean run is never compared
against a full run as if they were the same workload.

---

## Measurement plan

There is **no measured pipeline wall-clock or per-phase cost baseline today**, and §5.3 of the
research doc explains why this repo's telemetry cannot supply one (dev-session idle dominates:
p99 gap 22.8 h, max 3.7 days).

1. Phase 0 produces the **cost** baseline. ✅ shipped v5.13.0.
2. **One instrumented real run** is required for the latency baseline and the unmeasured halt
   firing rate behind L3-5/4f. (Phase 1b no longer needs it — Phase 0's `by_model` answers that
   from ordinary telemetry.)
3. Re-run `report-token-cost.sh` after each phase; compare cost-weighted, never raw.
4. **Read the TTL provenance line before quoting any total.** `cache_creation_ttl.pct_measured`
   < 100 means part of the number is a lane assumption carried over from pre-v5.13.0 telemetry.
   The existing `.mega-sdd/memory/telemetry.jsonl` in this repo is **0% measured** — the first
   genuinely measured baseline is the first run after v5.13.0, not a re-report of old data.

## Ship order

`0 ✅ → 5a(readiness ✅ v5.15.0; FLIP blocked on RUN 1+2) → 2b ✅ v5.16.0 → 3a ✅ v5.17.0 → 5d ✅ v5.18.0 → 5b ✅ v5.19.0 → 5c ✅ v5.20.0 → 2a/2c/2d ✅ v5.21.0 → 4-first (4a/4b/4c) ✅ v5.22.0 → 4-second (4d/4e) ✅ v5.23.0 → 4f (memo REJECTED; batching) ✅ v5.24.0 → 5e → E(--lean)`

**Re-ordered after operator feedback (2026-07-30):** the original order front-loaded latency and
left the biggest *token* levers last. The goal is real e2e token consumed, so the order is now
**by cost-weighted token saved**, with the both-axes levers (2b) kept high because they are free
wall-clock too. Phase 1a is now a docs-only catalog row (see its amendment — the "unpinned agent"
premise was stale; `model: inherit` is already declared), ship it whenever. Phase 1b needs no run
anymore (Phase 0's `by_model` answers it). Phase 4 is spawn-tax — pure wall-clock, ~0 tokens —
so it drops below the token work despite being cheap.

Phase 0 shipped and gates the *measurement* of everything downstream: re-run
`report-token-cost.sh` after each tranche and compare cost-weighted, never raw, and check
`cache_creation_ttl.pct_measured` before quoting any total.
