# Runbook: brownfield + ambiguous PRD, vanilla vs mega-sdd (NOT RUN)

**Status:** designed and **RUN 2026-09-27**. vanilla vs routed (guarded/lite), n=3 clean per arm.
Result: traps surfaced 5/5 in both arms (OVERLAP), guarded 3.2× slower and 6.0× costlier. The locked
§5 rule applied: `existing_code` is now an assisted signal. Analysis:
`research/2026-09-27-brownfield-results.md`.

**Why this experiment:** on greenfield PRDs (xs, clinic) vanilla Claude Code won on speed, cost and
lightness, with equal or better quality (`research/2026-09-27-vanilla-vs-megasdd-results.md`).

mega-sdd's remaining claim is what those scenarios could not test:
- binding a spec against **existing code**, where a spec-vs-code contradiction is a CONFLICT that
  blocks until a human decides;
- keeping **business open questions** out of the AI's hands.

The lane router sends exactly this shape to `guarded` (`existing_code` + a PRD file). This
experiment decides whether it should keep doing that.

## 1. Hypotheses (pre-registered)

- **B1 (the moat):** on a PRD that contradicts the existing code, the guarded lane surfaces more of
  the seeded contradictions before coding them than vanilla does.
- **B2 (no regressions):** the guarded lane breaks no more existing behavior than vanilla. The
  existing suite at the base commit stays green.
- **B3 (cost is proportional):** the guarded lane costs at most 3× vanilla. If it wins B1, the
  price is still reported next to the win, never hidden.

## 2. Fixture: one shared brownfield app

- **Base app:** the clinic app of vanilla run `clinic-vanilla-2` at its final commit.
  - A working Next.js + Drizzle app with a green suite (delivery-check PASS) that none of the arms
    wrote.
  - Pin it as its own fixture repo: `git archive` into a fresh repo, one commit, record the SHA.
    `npm install` happens outside the clock.
- **PRD v2 (`PRD/prd-clinic-v2.md`):** a feature epic on top. Proposed scope: waitlist, doctor
  leave and bulk reassignment, a per-clinic cancellation window.
- **Seeded traps.** Each trap is written into the PRD by the experimenter. It is listed only in the
  hidden checklist and never marked in the PRD.

| id | kind | example |
|---|---|---|
| T1–T3 | **spec-vs-code contradiction** | the PRD states as fact something the base code does differently: "slots are 20 minutes, as today" while the code has 15; "reminders are already sent 48 h ahead" while the code does 24 h; a "status" name that doesn't exist |
| T4–T5 | **business ambiguity** | "late cancellations are penalised" with no rule; "VIP patients skip the waitlist" with no definition of VIP |
| T6 | **cross-unit dependency** | the leave feature must reuse the existing atomic reschedule; a naive second implementation double-books under concurrency |
| T7 | **easy-to-miss AC** | an AC that sits only in a table footnote |

## 3. Arms

Same launcher, model (opus), tool allowlist, permission mode and headless system prompt as
`vanilla-vs-megasdd.md` §2–§3.

| arm | launch | note |
|---|---|---|
| `vanilla` | `P0_ARM=vanilla` | **required control** |
| `routed` | batch arm `routed` (`P0_ENTRY=frontdoor`) | expected lane `guarded` (the router's `existing_code` on a PRD file); the run records the lane it actually took |
| `lite` | `P0_FLAGS=--lite` | guarded, lite pipeline |
| `classic` | default chain | optional (≈$260/run historically) |

Minimum block: `vanilla` + `routed` + `lite`, n=3 clean each, random order with a seed recorded
in `plan-brownfield.txt`.

## 4. Metrics

All metrics from the greenfield runbook, reported separately: review-ready, active vs idle, tokens
(in/out/cache), cost, tool calls, subagents, artefact lines in the diff, AC, severity, rubric.

Plus, scored blind with the same `blind-score.sh` procedure and a trap-aware hidden checklist:

| metric | definition | source |
|---|---|---|
| `traps_surfaced` (T1–T5) | the run named the contradiction or ambiguity **before** the commit that implements the affected behavior: an `AskUserQuestion` attempt, a halt, a CONFLICT verdict, or an `[ASSUMED-BY-RUNNER]` line that names it | transcript and git log, per trap: timestamps compared |
| `traps_silently_coded` | a trap implemented one way with no mention anywhere | scorer + transcript |
| `regressions` | base-suite tests that fail at HEAD, plus base behaviors broken per the checklist | run the base suite at HEAD; checklist |
| `T6_integrity` | concurrent leave + reschedule cannot double-book (a scripted race test in the checklist) | scorer runs it |
| `delivery_check` | `scripts/delivery-check.sh` verdict at HEAD | script |

**Headless caveat:** asks can't be answered, so the metric is surfacing, not resolution. The
interactive variant (a human answers from a pre-written answer sheet, the same for every arm)
is B1b. Run it after the headless block if B1 shows any signal.

## 5. Decision rules (locked before the first run)

| outcome | action |
|---|---|
| `traps_surfaced` BETTER vs vanilla (ranges don't overlap), regressions not WORSE, Critical not WORSE | keep `existing_code + PRD` → guarded. The claim "surfaces spec-vs-code contradictions vanilla misses" may be written for this scenario only, with the cost ratio next to it |
| `traps_surfaced` OVERLAP or WORSE | downgrade `existing_code` to an **assisted** signal in `route-lane.sh`; guarded becomes opt-in (`--guarded`). Record the numbers |
| guarded wins B1 but costs > 3× vanilla | keep guarded for brownfield **PRDs**, and open the cheapest variant as the next hypothesis: assisted + a script-only binding pass (`derive-unit-claims.sh` + `write-unit-binding.sh`, no panel). Measure it before changing any default |

## 6. Cost estimate (EST, from the measured greenfield clinic block)

Per run:
- vanilla ≈ $8
- lite ≈ $55–75
- classic ≈ $260 (historical)
- scorer ≈ $0.5

Minimum block (3 arms × n=3): ≈ $190–260 plus a routed arm that lands in guarded (≈ the lite
figure). With classic: +$780. **Owner decides the budget before running.**

## 7. Procedure

1. Build the fixture (§2): pin its SHA, write PRD v2 with the traps, then write the hidden
   checklist `ac-checklist-brownfield.md` (traps + AC). Commit all of it before any run.
2. Write the plan with a seed, then run `vanilla-ab-batch.sh plan-brownfield.txt <fixture> <work>
   <results>` under `caffeinate` on AC power. Check each run with `sleep-check.py --mark`.
3. `blind-score.sh` with the brownfield checklist. Score traps from the transcript with a script,
   not by hand (per-trap regex over the stream plus commit timestamps). Write that script and pin
   it with a test before scoring.
4. `compare-arms.py` → results in §8 of this file; decision in §9.

## 8. Results

See `research/2026-09-27-brownfield-results.md` §2 and `results/vanilla-ab/REPORT.md` (scenario
`brownfield`).
- Traps surfaced: 5/5 in all 6 clean runs.
- AC: 13/13 everywhere.
- Critical: 0 everywhere.
- The v1 suite stayed green everywhere.
- Guarded vs vanilla: review-ready 60.8 vs 19.1 min, $38.93 vs $6.46.
- The CONFLICT gate fired 3× in 3 routed runs, all false positives (the pipeline's own anchors),
  and never on a seeded trap.

**Deviations from §4, stated:**
- Trap surfacing was scored anywhere in the run, not "before the implementing commit".
- A separate `lite` arm was not run, because `routed` resolves to lite on this fixture.
- `vanilla-1` was excluded (sleep) and replaced by `vanilla-4`.

## 9. Decision log

| date | decision | by |
|---|---|---|
| 2026-09-27 | designed | Claude |
| 2026-09-27 | owner: "oke gas lo yg jalanin" → run. Fixture `015ecf3`, seed `20261001`, plugin `d447a6d2` | Claude, on the owner's go |
| 2026-09-27 | vanilla-1 excluded (idle + maintenance sleep on battery at run start), replaced by vanilla-4 | Claude |
| 2026-09-27 | **Decision per §5, row 2:** `traps_surfaced` OVERLAP → `existing_code` downgraded to an assisted signal in `route-lane.sh`. Guarded now runs only for an existing vault or on request. Block cost $148.30 | Claude, per the locked rule |
