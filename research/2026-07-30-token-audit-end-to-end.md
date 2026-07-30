# End-to-end token audit — mega-sdd pipeline

**Date:** 2026-07-30 · **Trigger:** "audit secara end to end terkait token use … current pipeline
sangat makan token banget dan beberapa kali bolak balik terus … klo bisa save token hingga 90%."
**Method:** measure first from ground truth (16,259 telemetry records + the MSmile field-audit
transcript decomposition), verify pricing against the live `claude-api` reference rather than
memory, then fan out 7 investigators on orthogonal cost axes with adversarial verification of
every finding.

---

## 0. Headline

**The honest answer to "90%": no — not without giving up capability. ~60–70% is the real
engineering target, ~70–85% is the ceiling if every lever lands aggressively.**

The arithmetic (§2) is not close: even **completely eliminating** standing-context re-read — the
largest single lever anyone has proposed — leaves 56–64% of the bill standing, because the rest
is subagent seeds, model output, and fresh input, i.e. the work itself. Reaching 90% means doing
less work: fewer phases, fewer gates, fewer review lenses. That is a product decision, and it
should be offered as an explicit opt-in profile, never smuggled in as an "optimization".

Two framing corrections come before any lever, because both make the pipeline look more wasteful
than it is:

1. **Raw token counts overstate real cost 4.5–4.8×.** `cache_read` dominates raw volume but bills
   at 0.1×. A run that reads as "176M tokens" costs like ~37M.
2. **~⅓ of the remembered pain has already been refunded by a price cut.** The field audit's
   `$317/run` was correct at the then-current **$15/MTok** Opus input price. At today's Opus 5
   **$5/MTok** the identical run costs **~$184** (~$105 for the intent→unit phase).

---

## 1. Verified pricing and weights

Taken from the live `claude-api` reference, not from memory.

Opus 5: **$5.00 / 1M input**, **$25.00 / 1M output**.

| token type | $/1M | weight vs 1 uncached input token |
|---|---|---|
| `input_tokens` | $5.00 | **1.00** |
| `cache_creation_input_tokens` (5-min TTL) | $6.25 | **1.25** |
| `cache_creation_input_tokens` (**1-hour TTL**) | $10.00 | **2.00** |
| `cache_read_input_tokens` | $0.50 | **0.10** |
| `output_tokens` | $25.00 | **5.00** |

### Finding 0 — the plugin's own ruler under-weights the largest line item · CONFIRMED

`plugins/mega-sdd/scripts/report-token-cost.sh` hardcodes `cache_creation × 1.25` — correct only
for the **5-minute** cache TTL. The independent H5 investigation established that **Claude Code
writes 1-hour-TTL cache exclusively**, so the true weight is **2.00** and this is not a
conditional: the report **understates `cache_creation` by 60%**, and `cache_creation` is the
largest single term in a real pipeline run (§2). Every other weight is correct.

Re-pricing the measured run with the corrected weight: **23.4M → 26.5M cost-units**.

**Fix:** set `cache_creation = 2.0` (or make it TTL-aware). Cheap, and it matters because this
instrument is the yardstick every future optimization will be judged against.

### Finding 0b — the two telemetry hooks disagree, and it inverted the lever ranking · CONFIRMED

`hooks/stop:266–279` keeps only `last_usage` — the **final** assistant message of the turn —
whereas `hooks/subagent-stop` deliberately **sums usage across every turn** in the subagent
transcript (its own comment: last-message-only runs "~7x under the real cumulative cost").

A main-thread turn contains many assistant messages when it makes many tool calls. Recording only
the last one captures that turn's peak `cache_read` (so resident-context figures stand) but
**drops the output and cache_creation of every intermediate message**. Because output bills at
5.0×, the main-thread cost — and specifically its output share — is systematically understated,
while subagents are measured correctly. The H1 investigation measured the undercount at **9.16×**.

**Consequences, applied throughout this document:**
- The `turn_end_marker` shape in §2 (output 11.2%) is **instrument-distorted and understates
  output and cache_creation**. The MSmile field-audit shape — taken from transcript ground truth,
  not from this hook — is the trustworthy one and is what the recommendation is built on.
- This is why six prior token rounds all aimed at *dispatch payloads*: the instrument made the
  main thread look cheap. Fixing the hook is a prerequisite for trusting any future measurement.
- My own earlier main-thread-vs-subagent split in this audit inherited the same distortion; the
  resident-context and turn-count figures survive, the cost-share split does not.

---

## 2. The cost model — where the money actually goes

### Measured shape, two independent datasets

| dataset | input | cache_creation | cache_read | output |
|---|---|---|---|---|
| this repo, main-thread `turn_end_marker` (n=620) | 0.3% | 16.0% | **72.5%** | 11.2% |
| MSmile field-audit real pipeline, 5m TTL | 5.7% | **38.3%** | **44.0%** | 12.0% |
| MSmile field-audit real pipeline, **1h TTL** | 4.7% | **49.8%** | 35.8% | 9.7% |

The two cache terms are **82–88% of cost** in every view. Which one dominates is
workload-dependent, and that decides the lever ranking:

- **Main-thread-heavy work** → `cache_read` rules (72.5%) → residency and turn-count levers.
- **Real pipeline runs** → `cache_creation` is co-dominant, and under 1h TTL it is the **single
  largest term (49.8%)**. Every fresh subagent seed is CREATED, never read — the most expensive
  input token in the system. **Seed economics matters at least as much as `context: fork`.**

A report that names only one of these is wrong. This is the main correction to the prior
framing, which treated standing-context growth as the sole driver.

### Standing-context growth — corroborated on a second dataset

This repo's `turn_end_marker` data (14 sessions ≥5 turns); per-turn `cache_read` is the resident
context size. Growth is **monotonic in 89–98% of turn-to-turn transitions**.

| metric | this repo | MSmile field audit |
|---|---|---|
| median resident context | 279,518 tok | 209,000 tok |
| peak observed | 747,918 tok | 325,000 tok |
| pure standing cost / turn | 27,952 cost-units | 20,900 cost-units |

At 279K resident, **every turn pays ~28K cost-units before doing any work.** A 180-turn session
pays ~5.0M cost-units in pure standing re-read. This is why turn count is a linear cost
multiplier and why the user's "bolak balik terus" is a genuine cost complaint even though the
individual round trips feel cheap.

### The payback rule for context reset

Forking a phase trades `cache_read` down for `cache_creation` up. Per phase it wins when:

```
0.1 × (resident_old − resident_new) × turns_remaining  >  1.25 × seed     (5m TTL)
0.1 × (resident_old − resident_new) × turns_remaining  >  2.00 × seed     (1h TTL)
```

Worked: a 30K seed costs 37.5K (5m) / 60K (1h) cost-units up front. At a 200K resident delta you
save ~20K/turn → **payback in ~2–3 turns**. So fork is strongly positive for long phases and
negative for short ones. It is a threshold rule, not a blanket policy — and the known blocker
stands: `AskUserQuestion` no-ops under `context: fork`, so only non-interactive phases qualify.

### Ceiling scenarios

Factors are divisors per cost term; scenario C is the defensible target, D pushes every lever hard.

| scenario | 5m TTL | 1h TTL |
|---|---|---|
| C. residency 3× + turns 1.5× + output 2× + seed/cc 2× | **59.3% saving (2.46×)** | **57.6% saving (2.36×)** |
| D. residency 6× + turns 2× + output 3× + cc 2.5× | 73.2% saving (3.73×) | 70.7% saving (3.42×) |

### Why 90% is arithmetically out of reach

Eliminating `cache_read` **entirely** still leaves **56.0%** (5m) / **64.2%** (1h) of cost. To
reach 90% overall you must additionally cut every non-`cache_read` term by **5.6×–6.4×**.

| saving achieved | cost per full run | saved per run |
|---|---|---|
| 30% | $130 | $56 |
| 50% | $92 | $92 |
| **65% (target)** | **$65** | **$120** |
| 75% | $46 | $139 |
| 90% | $18 | $166 |

---

## 3. Red herrings — ruled out, with evidence

Recording these so they are not re-investigated. Two of them cost this audit a false claim each
before being caught.

| claim | verdict | evidence |
|---|---|---|
| "3,892 self-resolved halts are burning tokens" | **~0 tokens** | Every one carries `logged_at_chat: false` and `fix="detection-only at hook layer"`. They are PostToolUse re-detections that inject nothing. 982 re-detections of the *same* condition in one session is a real **integrity** defect — not a cost lever. |
| "38.2M tokens of redundant reference re-reads" | **not pipeline cost** | Split by origin: 40.5M from the **repo** path (plugin-development file reads) vs **107K** from the real plugin cache (`~/.claude/plugins/marketplaces/`). This is plugin-development churn, measured in the plugin's own dev repo. |
| "the plugin's telemetry is blind to pipeline subagents" | **already fixed** | `hooks/subagent-stop` takes `agent_type` from harness stdin and sums usage across the subagent's own transcript. It would capture `mega-sdd:bolt-implementer` et al. The absence in this repo is because this repo never ran bolts. |
| "subagents are 95.9% of the bill" (from this repo's data) | **not transferable** | All 963 `subagent_end_marker` records are `workflow-subagent` / `general-purpose` — the operator's own ultracode dev agents, not pipeline agents. Their profile describes the dev harness. (Subagent seeds *are* co-dominant in real runs — but that conclusion comes from the field audit, not from this data.) |
| "the field audit's $317 figure was miscalculated" | **audit was correct** | It reconciles exactly at the then-current $15/MTok Opus price (21.04M cost-equiv × $15 = $316; 100.7M raw × $15 = $1,510; ratio 4.76× ✓). Only the price has changed since. |
| TOON / compressed token formats | **rejected on research** | `research/2026-07-19-token-format-research-okf.md`. Do not re-propose. |

### Artifact consumption signal

Normalising every `.mega-sdd/` read in the telemetry to its artifact role:

- `units/U-NNN.md` — **461 reads**, by far the hottest artifact. Consistent with the implementer
  plus every review lens each re-receiving the unit body.
- `graph.json` — **2 reads** across 16,259 events. The graph layer is generated and gated but
  barely consumed via the Read path. Worth confirming whether script-side consumption makes up
  for it before treating it as waste.
- `.scan-meta`, `TOKEN-COST-REPORT.md` — 0 reads (expected; both are script-consumed).

*(Caveat: these counts come from sessions that mix plugin development with pipeline work, so read
them as consumption **shape**, not as pipeline volume.)*

---

## 4. Prior art — already shipped, do not re-propose

The bytes-in-files axis has been mined hard. Re-proposing any of these is a failed finding.

1. **Batch-4 audit (v4.43.0)** — lean anchor injection (7839→3330 chars/injection, ~57%);
   deny-message diet (~26%). Explicitly **kept after measurement**: review-panel risk-tiering,
   blind per-lens context, SKILL.md bodies (all ≤500 lines), skill descriptions, hook telemetry,
   gated dynamic SessionStart blocks.
2. **Token-efficiency god-review, 18 findings, v4.71.0→v4.77.0 (~72K tok/run)** — reference
   monolith splitting (~14K), execute-bolts dispatch diet (~24.5K chars), extract-intelligence
   wave-dispatch diet (~14K), quiet gates (~12K), per-lens payload trim + source-aware anchor
   (~6.9K), memory pointers not content (~2K).
3. **W-batch script-derive** — `make-bound.sh` (bound/ derived, ~10–30K output tok/bind),
   `derive-binding-json.sh`, `build-citation-map.sh` (~4–10K/emit-fsd).
4. **P7 slice-first** — `build-advisor-bundle.sh` (advisor gets a sha-stamped seed, not the
   corpus), `seeding_budget.py` + `measure-seeds.sh` (the ruler), `report-token-cost.sh`.
5. **P2 diets** — static `_meta/ai-consumer-guide.md`, post-write binding boilerplate stamping,
   dispatch contracts moved into the `bolt-implementer` system prompt.
6. Review panel is **already** risk-tiered (`minimal`=1 lens / `standard`=2 / `full`=4, +design
   additive for UI only) **and** per-lens trimmed.

### Moat constraints any lever must respect

- **Review-lens blindness is an invariant.** `review-panel.md:53`: *"Blind review is the
  anti-rubber-stamp rail — do not 'save tokens' by sharing context between lenses."* Blindness
  forbids sharing **verdicts**, not paying one seed — but no lever may give a lens another lens's
  output or the implementer's self-report.
- No weakening of any gate, validator, or halt. Doctrine is *gates > rules > hooks*.
- No Agent-offload of a gated phase — that bypasses the gates (`moat-token-tradeoff`).

---

## 5. Wall-clock latency — the second axis

Added mid-audit: runs take hours ("berjam2"); target **3–4× faster**. Latency is a *different*
axis from cost, and conflating them produces wrong advice.

### 5.1 The critical tension — the top token lever HURTS speed

| lever | token effect | wall-clock effect |
|---|---|---|
| Reduce turn count | ✓✓ | ✓✓ |
| Reduce **output** tokens (script-derive) | ✓✓ (billed 5.0×) | ✓✓ (output is generated **serially** — the biggest machine-time sink) |
| Slice dispatch seeds smaller | ✓✓ | ✓✓ (less prefill to process) |
| Collapse redundant multi-pass dispatches | ✓✓ | ✓✓ |
| **Parallelism** | ~neutral | **✓✓✓ biggest free win** |
| Reduce subprocess spawns | ~0 | ✓✓ (large on Windows) |
| Collapse human halts | ~0 | ✓✓✓ (unbounded) |
| **`context: fork` / residency reset** | **✓✓** | **✗ HURTS** |

The fork penalty is mechanical: a fork re-**creates** its seed, and `cache_creation` means actually
processing those tokens (~2–5k tok/s) where `cache_read` is a near-free lookup. So the single
biggest *cost* lever carries a *latency* penalty. **`context: fork` must not be sold as a speed
lever.** The levers that win on both axes are turn reduction, output reduction, seed slicing, and
multi-pass collapse.

### 5.2 Machine-time sinks (derived, assumptions stated)

- Main-thread output: **609,666 tokens over 621 turns (~982/turn)**. At Opus streaming throughput
  40–80 tok/s that is **2.1–4.2 h of pure generation** for that corpus. Output generation is
  serial, so this is irreducible except by emitting less.
- `cache_creation` prefill at ~2–5k tok/s is real processing time; `cache_read` is a fast lookup.

### 5.3 Wall-clock is NOT decomposable from this repo's telemetry — stated, not guessed

Inter-turn gaps here are **human-idle dominated**: p50 530s, p90 5,789s, p99 82,215s (22.8 h),
max 323,828s (3.7 days); one session spans 378 h. These are the plugin's own dev sessions — the
gaps are the operator being away. Any per-phase wall-clock figure must come from structure plus a
stated throughput assumption, or be labelled unmeasured. **No measured pipeline latency number
exists yet; producing one requires an instrumented real run.**

### 5.4 The human-blocking surface (structural, counted)

- `references/halt-protocol.md` defines **~146 distinct halt types**, many marked **ALWAYS STOP**.
  Each ALWAYS STOP is *unbounded* wall-clock when the operator is not watching.
- Confirmation/`AskUserQuestion` mentions per skill (grep — mentions, not yet verified as distinct
  runtime stops): execute-bolts 37, orchestrate-flow 31, resolve-oq 28, generate-intent 25,
  memory 15, diff-vault 9, install-deps 7, detect-drift 7, extract-intelligence 6.
- `--auto` does **not** remove them all: `diff_conflict`, `prd_path_missing`, and every ALWAYS STOP
  explicitly hold under `--auto`.

**Hypothesis (being verified):** if machine time is ~2–4 h and a run takes far longer, the
difference is human-response latency across many stops — i.e. the "berjam-jam" is largely *waiting
for a human*, not compute. That would make halt batching the highest-leverage speed lever, and it
costs ~0 tokens.

### 5.5 The spawn tax — Windows-dominant, ~0 token cost · CONFIRMED structure

- **91** shell scripts; **55** distinct scripts referenced at **212** sites; **302** python
  invocations inside scripts/hooks; **8** hook handlers.
- `hooks/hooks.json`: **`PreToolUse` is `async: false` — SYNCHRONOUS — with matcher
  `Skill|Bash|Edit|Write`**, and its handler `hooks/pre-tool-use` is **62.5 KB** of bash. So every
  Bash, Edit, Write and Skill call blocks on that handler plus whatever it spawns.
  `PostToolUse` (matcher `Read|Skill|Bash|Write|Edit|Agent`), `Stop`, and `SubagentStop` are
  `async: true`.
- Target machines: Windows office laptops, **Git Bash + cmd only** (PowerShell blocked, WSL blocked
  by the employer), **CrowdStrike EDR ≈220 ms/spawn (~12× macOS)**. Fork count therefore dominates
  wall-clock there. Precedent: the v5.8.0→5.9.0 regression was unbounded exec probes, ~96× slowdown.

The earliest-safe-exit path through `pre-tool-use` is the highest-value fix on this axis: a guard
that exits in one spawn instead of several, multiplied by every tool call in a run.

---

## 6. Findings

Two fan-outs, 11 investigators, every finding adversarially verified against five kill-checks
(real / arithmetic-and-assumptions / already-shipped / moat / buildable). **22 of 28 token
findings survived; 6 were killed. 10 of 11 latency findings survived; 2 killed.** All figures
below are the **verifier's corrected** values, not the finder's claims — corrections ran in both
directions and several finders were overstated ~2–3×.

### 6.1 Corrections to §5.4 of this document — my own claim was wrong

**"~146 halt types, many ALWAYS STOP" is a TYPE CENSUS, not a firing rate.** The L2 investigation
established that the overwhelming majority are **error-conditional and fire zero times on a clean
run**. The real human-blocking surface is far smaller and concentrated:

- An interactive run's stops are dominated by **resolve-oq (3 round trips per OQ)** and the
  **bind CONFLICT walk**, not by the halt registry.
- **`detect-drift` never calls `AskUserQuestion` on any path** — all 5 grep "mentions" are
  *prohibitions*. My grep-based count in §5.4 was misleading and is retracted.
- Verified per-run stop counts: **~22–42 stops interactive, ~7–13 under `--auto`** (post-fix),
  against a pre-fix baseline of 25–42 / 22.

Also retracted from my earlier reasoning: **scan-codebase's 5 deep-scan slices are already
concurrent and already selective**; the **4 emit-\* skills are not chained at all** (opt-in behind
flags), so there is no serial cost to remove there.

### 6.2 Token findings that survived — ranked by corrected value

| # | finding | corrected value | notes |
|---|---|---|---|
| 1 | **`bolt-implementer` is `model: inherit`** — the only unpinned agent in the plugin | **6.3–7.2M cost-units = 17–19% of a 37M run** | **CONDITIONAL:** that value if the bolt session ran Opus-tier; **exactly 0 if Sonnet.** Unverified. One `usage.model` read settles it. |
| 2 | **Fork `scan-codebase` + `bind-codebase`** | **~2.0M (floor 1.7M) = 11–16% of main-thread cost** | Cost win, **latency cost**. Remaining blocker for scan is one missing `--auto-policy` paragraph another skill ships verbatim. Risk: handoff-under-fork is unexercised. |
| 3 | **Per-bolt L0 script fan-out** (13–16 sequential Bash turns/bolt → 3 wrappers) | large; also the top latency lever | Wrapper **must** preserve the cheap→expensive short-circuit or it does strictly more subprocess work on Windows. |
| 4 | `cache_creation` weight is 2.0× not 1.25× | **0 saved; corrects a 2.05M (8.0%) mis-measurement** | Nuance: main lane measured **1h TTL (2.0×)**, subagent lane **5m (1.25×)** — mixed, not uniform. |
| 5 | Telemetry hooks disagree (§Finding 0b) | **0 saved; instrument fix** | Corrected ratios: undercount **8.03×** (not 9.16×), overcount **exactly 2.898×**. |
| 6 | Review-panel per-wave dispatch floor | 160–306K on a 20-unit run | Spends review recall to buy tokens at an unmeasured exchange rate. Treat as last-resort. |
| 7 | No lens-prompt template; invariant authored last | ~150K per extract run (~129K is main-thread output at 5.0×) | Relocation is not pure cut-and-paste — prose back-references the dispatcher slice. |
| 8 | FSD + PRD have no builder script (SIT/UAT do) | ~42K cost-units per FSD emit (±40%; structural projection, no FSD exists in the field project) | Highest effort of the four output items. |
| 9 | `codebase-map.md` re-typed in full every sync | **37.6K per write (measured); ≥188K lifetime floor** | Script needs 4 anti-hallucination rails currently prose-trusted. |
| 10 | resolve-oq prompt fan-out | ~1.5 turns/OQ (not the claimed 3.9) | |
| 11 | intent-leg phase-advisor still pastes whole vault+source | 15–50K/dispatch, central ~30K | Seed-bundle fix was wired to the **bind leg only**. |
| 12 | `/mega-sdd:update-plugin` mid-session reload | ~340K avoidable for the one observed event | Real risk is a **correctness** regression — people reload to get a fix they need *now*. |

**Honest negative results — do not spend effort here:** the entire always-on lane is capped at
**0.16–0.31%** of a long run (H6-B, re-derived upward by the verifier and still negligible); the
whole output-lane ceiling is **~3%** of a single-pass run, so its leverage is write *multiplicity*
(sync/re-emit counts), not artifact size.

**Killed:** prefix-loss attribution (double-counted), the 60-min TTL-cadence lever (mechanism
misread, physically unachievable baseline), forkability-census correction (unbuildable), bolt-report
evidence re-typing (already shipped in effect), resolve-oq pre-prompt probe loop (cost is not paid
per-OQ), **and panel-lens re-tiering (moat violation — lens models are frontmatter-pinned by
design, `review-panel.md:23` + `model-tiers.md:89-94`)**.

### 6.3 Latency findings that survived — ranked

| # | finding | corrected saving | token effect |
|---|---|---|---|
| 1 | **`execute-bolts` runs SEQUENTIALLY in every orchestrated chain** — the chain computes its own available parallel speedup and then discards it | **2.5–2.7× on the bolt phase**; **3.0–3.2×** with the script tail hoisted per wave (not the claimed 4.0×). Single-squad `--all` only — multi-squad already routes to the parallel procedure | **neutral** |
| 2 | Bolt dispatch prompt (~9KB/bolt) is model-assembled from pure copy/filter/sort/cap logic **and materialized twice** | **25–75 min** of serial main-thread generation for a 40-unit run | **helps strongly** — ~179K output tokens → ~4.8K. The cleanest both-axes lever in the pipeline |
| 3 | L0 code gates are 7–11 main-thread Bash round trips per bolt per pass, re-run on every panel re-dispatch | **macOS ~14–29 min; Windows-with-EDR ~25–40 min** (40-unit run). Hook cost **measured** at 0.22–0.24 s per benign Bash PreToolUse firing | helps moderately |
| 4 | resolve-oq spends **3 human round trips per OQ**; its own sibling reference already specifies 1 | **22 → 7–13 stops** (`--auto`, N=8); 25–42 interactive. Coverage-independent | helps both axes |
| 5 | bind CONFLICT walk is serial and cold-start-blind despite a computed `suggested_action` | **2–4 stops** (not the claimed 6 — KEEP_CODE rows can't batch) | helps |
| 6 | `extract-intelligence` re-batches waves under a default cap | **6 → 4 batches = 1.5×** on the agent-batch portion (not 6→3=2×). **One-line edit**: `--max-parallel` 3 → 5 | neutral |
| 7 | generate-units per-unit adversarial test review serialized by a note, no data dependency | up to **~21 min** at an assumed 8 high-risk units (ceiling, on the repo's own 3-min budget) | mixed |
| 8 | 3 ALWAYS-STOP halts whose entire remedy is running a script the plugin already ships | 1 stop per firing × **unmeasured** firing rate | mildly helps |
| 9 | `_index.md` Mermaid DAGs + topological order 100% derivable | **1–4 min** over a project's ~3 unit passes | helps |
| 10 | Adversarial acceptance-test review runs main-thread on Opus, serially | **~0 as specified** (a wash) — has an ordering blocker the finding didn't address | helps if reordered |

**Spawn-tax axis (L3) — all 6 survived; verifiers independently MEASURED exec counts via a PATH
shim on macOS rather than trusting the finder.** Exec counts are measured floors (a real vault
grows the per-validator terms); the 220 ms/spawn is the operator's Windows/CrowdStrike floor
applied uniformly (bash and python spawns are strictly worse; subshell forks uncounted).

| # | finding | corrected saving |
|---|---|---|
| L3-4 **HIGH** | execute-bolts gate block — pack resolver re-spawned per call (**measured 9 spawns per gate firing**), bolt-artifacts re-walked | pack resolver **36→4**, bolt-artifacts **40→8**, plus a ~12-exec `dirname` sweep. *"The most precisely verified finding in the set."* |
| L3-1 **HIGH** | 9 of 13 execs on every blocking `PreToolUse` firing are plumbing (`cat`/`sed`/`head`/`dirname`/`uname`/`grep`) with zero policy content | corrected **down ~28%** from the finder; scoped to the 8 hook entry points |
| L3-2 **MED** | `Stop` hook re-runs all five bolt-artifact scans **every turn end** — guard is only `[ -d .mega-sdd ]` | **measured 40 execs (20 `git`) of an 87-exec Stop total**. Standalone: **~24.9 min** of background process creation per 400-tool-call run at an assumed 15% commit-bearing turns (rescale freely — at 50% it halves) |
| L3-5 **MED** | B1 recompute re-executes committed bolts' Hard rules **inside the blocking hook** | deliberately **partly unquantified** — the honest call. Measured: 8 execs / 4 `git` with *zero* bolt commits, i.e. before the loop has anything to iterate |
| L3-3 **MED** | `PostToolUse` validator fan-out | **headline mechanism REFUTED** — only **7** validators are unconditional, not 13, and the glob filters the finding proposes adding **already exist** at `post-tool-use:788,799`. Survives on lever *direction* only: per-turn debounce of the 4 unconditional project-wide scanners. **Must be rewritten before anyone acts on it.** |
| L3-6 **LOW** | Per-unit evidence writers accept only one `--unit=` | **survives only in half** — batch the two *pre-flight* scripts; batching postflight/acceptance would defer the `SKILL.md:88` in-run STOP past N commits with no compensating gate |

All are **zero-token** changes confined to hooks/scripts the model never reads.

Killed on this axis: `context: fork` as a speed lever (mechanism — re-creates its seed);
parallelising PostToolUse validators (already backgrounded with `&`/`wait`); re-reporting
tree-sitter per-file spawning and the `--shallow-scan`/ast-grep bounds (**already shipped**
v5.10.0–v5.12.0).

---

## 7. Recommendation

### 7.1 Answering the two targets honestly

**Tokens — target was 90%.** Not reachable without capability loss (§2). **60–70% is the
engineering target.** The verified survivors do not sum to that on their own; the largest single
item (#1, model pin) is conditional and may be worth zero, and the two instrument findings save
nothing directly. Expect **~35–50% from the ranked list**, reaching 60–70% only with the model pin
resolved favourably plus fork adopted on scan+bind.

**Speed — target was 3–4×.** Reachable **on the bolt phase**, which is where the time is:
lever #1 alone gives 2.5–2.7×, and 3.0–3.2× with the script tail hoisted. End-to-end is bounded by
Amdahl — if the bolt phase is ~54% of wall-clock, a 2.7× speedup there yields ~1.5× overall, so
**3–4× end-to-end requires stacking #1 + #2 + #3 + #4 and the spawn-tax fixes.** That combination
is plausible but **cannot be promised without a measured baseline, which does not exist** (§5.3).

### 7.2 Order of work

**Phase 0 — fix the instruments first (nothing else is trustworthy until this ships).**
Both are ~0-token, low-risk, and they are why six prior rounds aimed at the wrong target:
set `cache_creation = 2.0` for the main lane, and make `hooks/stop` **sum** usage across the turn
the way `hooks/subagent-stop` already does (and dedup `subagent-stop` by `message.id`).
Expect main-thread cost to jump ~8× and subagent cost to fall ~2.9× in the report — that is the
correction landing, not a regression.

**Phase 1 — two separable items; do not conflate them.**

- **1a — pin `bolt-implementer` explicitly, add the `model-tiers.md` catalog row, add the parity
  test. Do this regardless of what any historical run used.** It is the only unpinned agent in the
  plugin (verified: 4× opus, 4× sonnet elsewhere) and has no catalog row — a one-line defect that
  is worth fixing on its own merits. A Sonnet answer in 1b does **not** mean "no action here."
- **1b — decide *which* tier after the measured run.** The 6.3–7.2M / 17–19% figure is contingent
  on the bolt session having run Opus-tier and is **exactly 0 if it ran Sonnet**; one `usage.model`
  read settles it. **Do not blind-pin to Sonnet:** the LOCKED "akurasi code WAJIB" mandate creates
  a real feedback loop where a weaker implementer costs *more* through panel rejections and
  re-dispatches. Choose deliberately, then test.

**Phase 2 — the both-axes wins (best value; ship together).**
Parallelise `execute-bolts` (#L1-1), move dispatch-prompt assembly into a script (#L4-1), and
collapse the per-bolt L0 fan-out into ~3 wrappers (#L4-2/#H2-1) preserving the short-circuit.
Add the one-line `--max-parallel` default change (#L1-6).

**Phase 3 — human stops.** resolve-oq 3→1 round trips per OQ (#L2-F1) and the batched bind
CONFLICT walk (#L2-F4), preserving the mandated keterangan on every prompt.

**Phase 4 — spawn tax (Windows-dominant, zero-token).** In value order:

- **L3-4** — memoize the pack resolver (measured 9 spawns/gate firing → 36→4 execs) and stop
  re-walking bolt-artifacts (40→8). Most precisely verified item in the audit.
- **L3-1** — substitute the 9 plumbing execs on the blocking `PreToolUse` path.
- **L3-2** — gate the `Stop`-hook's five bolt-artifact scans on "did this turn produce a commit or
  evidence artifact" (today the only guard is `[ -d .mega-sdd ]`).
- **L3-6 — pre-flight scripts ONLY** (`run-preflight-scan.sh`, `check-anchor-freshness.sh`).
  **Do not batch postflight/acceptance** — that defers the `execute-bolts/SKILL.md:88` in-run STOP
  past N commits with no compensating gate.
- **L3-3 — the surviving lever is ONLY a per-turn debounce of the 4 unconditional project-wide
  scanners.** Do **not** add PostToolUse glob filters: only 7 validators are unconditional (not 13)
  and the filters **already exist** at `post-tool-use:788,799`. This finding's mechanism section
  must be rewritten before it enters a spec.
- **L3-5** — memoize B1 recompute inside the blocking hook; magnitude deliberately unquantified
  pending a run with real bolt commits.

**Phase 5 — cost-only levers, decided by the payback rule (§2).** Fork scan+bind, accepting the
latency penalty; then the output-lane items (`codebase-map.md` deriver first — measured 37.6K/write
and ≥188K lifetime; FSD/PRD builders last, highest effort).

### 7.3 What to measure before and after

There is still **no measured pipeline wall-clock or per-phase cost baseline**. Phase 0 produces the
cost baseline. For latency, one instrumented real run is required — the same run also settles the
`usage.model` question in Phase 1 and the unmeasured halt firing rates behind #L2-F5.
