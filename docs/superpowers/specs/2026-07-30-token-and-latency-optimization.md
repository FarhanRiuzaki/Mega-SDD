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

**1a — pin it, regardless of any historical run.** It is the **only** agent in the plugin without
an explicit `model:` (verified: 4× opus, 4× sonnet elsewhere) and has **no `model-tiers.md` catalog
row**. Ship: explicit `model:` in `agents/bolt-implementer.md` frontmatter + catalog row + a
catalog↔frontmatter parity test (the panel-pin test is the precedent). **A "it ran Sonnet" answer
in 1b does NOT make 1a unnecessary** — unpinned is the defect.

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

**2b — move bolt dispatch-prompt assembly into a script.** ~9KB/bolt of pure copy/filter/sort/cap
logic, currently model-assembled **and materialized twice**. **Gain: 25–75 min serial generation on
a 40-unit run; ~179K output tokens → ~4.8K.** The cleanest both-axes lever in the audit.
*Constraint:* the T2 truncation cascade is a moat surface — the script must reproduce it exactly.

**2c — collapse the per-bolt L0 fan-out to ~3 wrapper calls.** 13–16 sequential main-thread Bash
turns per bolt, re-run on every panel re-dispatch. **Gain: macOS ~14–29 min, Windows ~25–40 min per
40-unit run.** The merged-JSON contract is already specified in `code-gates.md`.
*Constraint (hard):* the wrapper **must** preserve the cheap→expensive short-circuit, or it does
strictly more subprocess work than today on a blocking run — a regression on the target platform.

**2d — one-line: `extract-intelligence` `--max-parallel` default 3 → 5.** 6 → 4 sequential agent
batches = **1.5×** on the agent-batch portion.

---

## Phase 3 — human stops

**3a — resolve-oq: 3 human round trips per OQ → 1.** Its own sibling reference already specifies 1.
**Gain: 22 → 7–13 stops (`--auto`, N=8); 25–42 interactive.** Coverage-independent.
*Constraint:* the mandated **keterangan** contract (question text + source + per-option explanation
in Indonesian) must survive on every prompt — see `references/output-language.md` and the
`oq-interaction-keterangan` rule. Merging the action menu with free-text capture must not degrade
the Defer/OOS/Skip affordance.

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

---

## Phase 5 — cost-only levers (accept the latency penalty; decide by the payback rule)

Payback rule (§2 of the research doc):
`0.1 × (resident_old − resident_new) × turns_remaining > 2.0 × seed` (1h TTL, main lane).

- **5a — fork `scan-codebase` + `bind-codebase`.** **~2.0M cost-units (floor 1.7M) = 11–16% of
  main-thread cost.** Remaining blocker for scan is *one missing `--auto-policy` paragraph* another
  skill already ships verbatim. **Risk: handoff-under-fork is unexercised** — both skills emit
  handoff blocks; prove that path before shipping. Costs latency.
- **5b — `codebase-map.md` deriver.** Measured **37.6K cost-units per write**, ≥188K lifetime;
  currently re-typed **in full** on every incremental sync. Needs 4 anti-hallucination rails that
  are currently prose-trusted.
- **5c — intent-leg phase-advisor seed bundle.** The shipped fix was wired to the **bind leg only**.
  15–50K per dispatch. **Invariant: a slice is a SEED the consumer expands from, never a CAP** —
  ship a seed-not-boundary CONFLICT test.
- **5d — lens-prompt template / invariant-first ordering** (~150K per extract run).
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

`0 ✅ → 5a → 2b → 3a → 5d → 5b → 5c → 2a/2c/2d → 4 → 5e → E(--lean)`

**Re-ordered after operator feedback (2026-07-30):** the original order front-loaded latency and
left the biggest *token* levers last. The goal is real e2e token consumed, so the order is now
**by cost-weighted token saved**, with the both-axes levers (2b) kept high because they are free
wall-clock too. Phase 1a is a one-line correctness fix, ship it whenever. Phase 1b needs no run
anymore (Phase 0's `by_model` answers it). Phase 4 is spawn-tax — pure wall-clock, ~0 tokens —
so it drops below the token work despite being cheap.

Phase 0 shipped and gates the *measurement* of everything downstream: re-run
`report-token-cost.sh` after each tranche and compare cost-weighted, never raw, and check
`cache_creation_ttl.pct_measured` before quoting any total.
