# Brownfield + ambiguous PRD: guarded pipeline vs vanilla Claude Code (MEASURED)

**Date:** 2026-09-27
**Runbook (hypotheses and decision rules locked before the runs):**
`benchmarks/runbooks/brownfield-ambiguous-prd.md`
**Data:** `benchmarks/results/vanilla-ab/brownfield/`. Per run: `metrics.json`, `quality.score.json`,
`trap.score.json` + `trap.bundle.md`, `delivery-check.json`, `regression.json`. Also `REPORT.md`.
**Model:** opus for both arms, the scorer and the judge.
**Plugin:** `git archive` of commit `d447a6d2`.

## 1. Setup

- **Fixture `015ecf3`.** The clinic app built by vanilla run `clinic-vanilla-2`: 81 source files,
  a green 73-test suite, delivery-check PASS. The v1 PRD was moved to `docs/` with its plugin
  comments stripped. `PRD/prd-clinic-v2.md` asks for a waitlist, doctor leave with bulk
  reassignment, and a cancellation window.
- **Seeded traps, never marked in the PRD:**

  | Trap | Kind | What the PRD says | What the code does |
  |---|---|---|---|
  | T1 | spec-vs-code | "v1 has 20-minute slots" | 15 |
  | T2 | spec-vs-code | "48-hour reminder" | 24 |
  | T3 | spec-vs-code | "the existing status `rescheduling_required`" | no such status |
  | T4 | business ambiguity | "late cancellations are penalised" | no rule defined |
  | T5 | business ambiguity | "VIP patients skip the queue" | VIP not defined |
  | T6 | concurrency | reassignment must never double-book | — |
  | T7 | footnote-only AC | a 30-minute offer expiry | — |
- **Arms:**
  - `vanilla`: plugin disabled; the plain task prompt.
  - `routed`: `/mega-sdd:mega-sdd PRD/prd-clinic-v2.md`. The router sent every run to guarded
    (`existing_code`), and a new PRD runs lite: plan → JIT bind → bolts + panel.
- **Order:** seed `20261001`.
- **Clean-run rule.** `vanilla-1` hit a real idle/maintenance sleep on battery at run start
  (`outage_sleep`), so it was **excluded** and replaced by `vanilla-4` (runbook §4). Every other
  run: 1 process, purity PASS, no sleep.
- **Scoring:**
  - **Code: blind.** `blind-score.sh` with `ac-checklist-brownfield.md` (13 items: B1–B8 AC,
    T1c–T5c code outcomes).
  - **Traps: judged from what a human would read.** `trap-judge.py` reads main-thread chat,
    asks, commits, note sections and CONFLICT verdicts. Every "surfaced" needs a verbatim quote,
    checked mechanically.
  - **Regressions.** The v1 test suite from the base commit, run against each HEAD.

## 2. Results (median [min–max], clean runs, n=3 per arm)

| | vanilla | routed (guarded / lite) | verdict |
|---|---|---|---|
| review-ready (min) | 19.1 [18.9–21.9] | 60.8 [39.8–63.6] | WORSE (3.2×) |
| cost (USD) | 6.46 [5.99–7.28] | 38.93 [37.64–39.32] | WORSE (6.0×) |
| tokens total | 11.2 M | 74.5 M | WORSE (6.6×) |
| subagents | 0 | 78 [77–78] | WORSE |
| `.mega-sdd/` lines committed | 0 | 15,332 [14,886–15,371] | WORSE (already after the artefact diet; the greenfield clinic lite runs committed ~124k) |
| markdown lines added outside `.mega-sdd/` | 51 [45–53] | 0 [0–0] | BETTER (the pipeline's notes go into `.mega-sdd/`, the row above) |
| code + test lines | 3,294 [3,173–3,424] | 4,020 [3,915–4,519] | WORSE (1.2×) |
| **traps surfaced (T1–T5)** | **5/5 in every run** | **5/5 in every run** | **OVERLAP (identical)** |
| AC (13 items incl. T1c–T5c, B6 race, B3 footnote) | 13/13 ×3 | 13/13 ×3 | OVERLAP |
| Critical / Important | 0 / 0 | 0 / 0 [0–2] | OVERLAP |
| blind rubric | 91 [91–93] | 91 [89–91] | OVERLAP |
| v1 suite at HEAD (73 tests) | 73/73 ×3 | 73/73 ×3 | no regressions either arm |
| delivery-check | 3/3 PASS | 3/3 PASS | — |

The excluded `vanilla-1` would not change a verdict: 26.6 min, $6.73, 5/5 traps.

## 3. What the moat actually did

- **CONFLICT gate: 3 fires across 3 routed runs, all false positives.**
  - One was a line range the pipeline itself mistyped.
  - Two were anchors moved by a sibling unit's legitimate commit.
  - Each fire was resolved `KEEP_CODE` and cost a resolve/re-bind cycle.
  - **None of the 3 seeded spec-vs-code contradictions reached the gate.**
- **Where the traps were actually caught.** The `plan` phase caught T1–T5 as P1 business OQs, with
  `file:line` citations. That is a good write-up, but vanilla surfaced the same five in its
  `[ASSUMED-BY-RUNNER]` lines and its notes, from reading the code itself.
- **Both arms defaulted the same way.** Keep v1 behaviour (15 min, 24 h), add the missing status
  through a migration, defer VIP and the penalty. That is why T1c–T5c pass everywhere.

## 4. Decision (locked rule, runbook §5)

- **The rule.** `traps_surfaced` OVERLAP → downgrade `existing_code` to an **assisted** signal;
  guarded becomes opt-in.
- **Applied in `scripts/route-lane.sh`.** Only an existing vault (the user's own pipeline
  artefact) or `--guarded` / `--lite` / `--classic` runs the pipeline.
- **What the assisted lane keeps from the pipeline:** the part that did its job, which is **one
  batched ask for the open business items before coding**, plus one blind review and the
  delivery check.
- **What it drops:** the parts that cost 6× and caught nothing vanilla missed: per-unit
  implementers, the 4-lens panel per unit, JIT bind, and 15k committed evidence lines.

## 5. Limits

- **Headless.** The CONFLICT gate's intended value is making a human decide before code is
  written, which can't happen without a human. Here every halt became `[ASSUMED-BY-RUNNER]`. The
  interactive variant (B1b, a human answering from a fixed answer sheet) is not run. **Still,
  the gate's three fires were all false positives, so an interactive human would have been
  interrupted three times for nothing.**
- **The trap judge is not blind** (pipeline text has a different shape). The mechanical quote
  check guards against a judge that invents evidence, not against a lenient one. Both arms scored
  5/5 anyway, so the direction of any leniency doesn't matter here.
- **"Before the commit" timing (runbook §4) was not scored.** Surfacing anywhere in the run
  counts. Both arms were 5/5, so timing can only separate them if one surfaced late. Not
  measured.
- **One fixture, one PRD, n=3.** The traps are the kind a careful reader finds in the code. A
  subtler contradiction, like behaviour hidden across many files, might favour systematic
  binding. That is not shown here.
- **Cost of the block:** runs $142.35 (7 runs incl. the excluded one) + judge $1.49 + scorer $4.46
  = **$148.30**. The runs are MEASURED from the committed `metrics.json`, the judge from the
  committed `trap.score.json` (`judge_cost_usd`, 7 runs). The scorer figure comes from the local
  scorer streams (6 sessions), so it is not checkable from the committed raw data.
