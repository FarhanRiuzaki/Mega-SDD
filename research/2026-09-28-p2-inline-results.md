# P2 `execute-bolts --inline` vs the per-unit agent path (MEASURED, brownfield)

**Date:** 2026-09-28

**Runbook (locked before the runs):** `benchmarks/runbooks/p2-inline-vs-agents.md`

**Data:** `benchmarks/results/vanilla-ab/brownfield-p2/`. Each run has:
- `metrics.json`
- `quality.score.json`
- `trap.score.json` + `trap.bundle.md`
- `delivery-check.json`
- `regression.json`
- `conflict-bypass*.json`

Tables: `REPORT-p2.md` / `compare-p2.json` (`compare-arms.py` over `manifest-p2.json`).

**Plugin:** one `git archive` of `c659e940` (branch `exp/p2-inline`) for both guarded arms.

**Model:** opus for every arm, the scorer and the judge.

## 1. Setup

- **Fixture:** `fixture-brown` @ `015ecf3` (Harbor Clinic v1 + `PRD/prd-clinic-v2.md`; seeded traps
  T1–T7), the same as the 2026-09-27 brownfield block.
- **Arms:**
  - `guarded`: `--guarded`, the per-unit `bolt-implementer` + review panel path, 9.0 as committed;
  - `guarded-inline`: `--guarded --inline`;
  - `vanilla`: the 2026-09-27 clean runs `vanilla-2..4` plus one same-day drift check, `vanilla-5`.
- **Order:** seed `20260927`.
- **Clean runs:** all 7 are clean (1 process, purity PASS, `sleep-check` no-sleep).
- **Scoring:** exactly as in the brownfield block:
  - blind code score (13-item checklist);
  - trap judge, where every "surfaced" verdict needs a verbatim quote that is checked mechanically;
  - the v1 suite (73 tests) from the base commit run against HEAD;
  - `delivery-check.sh`;
  - plus the P2 moat metric: `--conflict-bypass-scan` at HEAD.
- **Superpowers 6.4.1:** loaded in every arm, so the inline arm ran through
  `superpowers:executing-plans`.

## 2. Results (median [min–max], n=3 per guarded arm)

| | guarded (per-unit agents) | guarded-inline | inline vs agents | vanilla (n=4) |
|---|---|---|---|---|
| **AC (13 items)** | 13 [12–13] | 13 [13–13] | OVERLAP | 13 ×4 |
| **Critical** | 0 [0–0] | 0 [0–0] | OVERLAP | 0 |
| **Important** | 0 [0–1] | 0 [0–0] | OVERLAP | 0 |
| **traps surfaced (T1–T5)** | 5/5 ×3 | 5/5 ×3 | OVERLAP | 5/5 (vanilla-5) |
| **v1 suite at HEAD (73)** | 73/73 ×3 | 73/73 ×3 | OVERLAP | 73/73 |
| blind rubric | 92 [82–93] | 91 [90–93] | OVERLAP | 92 [91–93] |
| delivery-check | PASS ×3 | PASS ×3 | — | PASS |
| `conflict_bypassed` at HEAD | PASS ×3 | PASS ×3 | — | n/a |
| review-ready (min) | 55.4 [46.7–67.5] | 50.9 [44.2–51.1] | OVERLAP | 19.0 [17.5–21.9] |
| cost (USD) | 42.45 [33.96–43.60] | 25.08 [20.88–25.38] | **BETTER** (ranges disjoint) | 6.48 [5.99–7.28] |
| tokens total | 94.5 M [60.0–105.1] | 68.6 M [52.7–69.2] | OVERLAP | 11.5 M |
| tool calls | 1,040 [973–1,088] | 252 [226–271] | **BETTER** | 71.5 |
| subagent dispatches | 70 [61–75] | 3 [3–4] | **BETTER** | 0 |
| distinct files read | 124 [107–154] | 12 [7–16] | **BETTER** | 1.5 |
| `.mega-sdd/` lines committed | 13,562 [13,458–14,370] | 8,260 [7,385–8,907] | **BETTER** | 0 |
| code + test lines | 4,077 [3,446–4,096] | 3,216 [3,054–3,551] | OVERLAP | 3,248 |

Bold rows are the five metrics of the locked decision rule (§8.4 of the spec).

## 3. What the CONFLICT gate did

- **guarded (agents):** 0 CONFLICT verdicts in all 3 runs. The JIT bind runs at dispatch, after the
  dependencies have landed.
- **guarded-inline:** 10 CONFLICT episodes across the 3 runs.
  - 9 of them were `fs_must_exist` on a file that an earlier unit in the same run creates.
    `derive-exec-plan.sh` deferred each one at plan time, and the task's own JIT re-bind closed it
    once the file existed.
  - None became a quarantine or a halt, so no human was interrupted.
  - The 10th is an `own_wip` CONFLICT on U-011's own test file, left open because the run ended
    before any later re-bind. It is harmless by design (`conflict_bypassed` PASS), but it leaves an
    open verdict in the vault. **Follow-up: re-bind every unit whose binding still holds an
    `own_wip` claim at the inline close.**
- **Seeded contradictions:** T1–T3 never reached the CONFLICT gate in either arm. `plan` caught
  them as OQs, as in the 2026-09-27 block. The gate again had **0 true positives**. Unlike that
  block, it also had 0 false blocks.

## 4. Decision (locked rule, runbook §5)

- **The rule:** all five P2-Q metrics (AC, Critical, Important, traps, regressions) must be OVERLAP
  or BETTER, and P2-M (0 bypasses at HEAD) must hold.
- **The outcome:** both hold. **`--inline` becomes the guarded default.** The P3 deletion of the
  per-dispatch machinery can be proposed with this evidence:
  - the per-unit review panel lenses;
  - `resolution-verifier`;
  - `merge-panel-findings.sh`;
  - attempt-cap;
  - the per-dispatch hook legs.
- **What the evidence supports:** the same quality as the per-unit agent path on this fixture, at
  about 60% of the cost, with 3 subagents instead of 70.
- **What it does not support:**
  - any claim against vanilla. Both guarded arms remain WORSE than vanilla on time (2.7–2.9×), cost
    (3.9–6.6×) and tokens, with quality OVERLAP. Guarded stays opt-in; the router default is
    unchanged.
  - that inline is faster than agents. Its time overlaps with the agents arm. Inline runs units one
    after another, while the agents path runs them in parallel waves.

## 5. Limits

- **One fixture, n=3.** A range-overlap test at n=3 only catches a large loss. "Not WORSE" does not
  mean "equal".
- **The trap judge is not blind.** Every arm scored 5/5, so the direction of any leniency doesn't
  matter here.
- **Superpowers in every arm.** The built-in fallback loop (no superpowers) has no measured run.
- **Headless only.** No human answered a question or a halt.
- **Cost of the block:**
  - runs $197.85;
  - trap judge $1.66;
  - blind scorer $5.35 (from the local scorer streams, so not checkable from committed data);
  - total **$204.86**;
  - plus the xs smoke: $8.42 plus its scoring.

  The estimate was $160–190. The agents arm cost more than the 2026-09-27 routed runs.
