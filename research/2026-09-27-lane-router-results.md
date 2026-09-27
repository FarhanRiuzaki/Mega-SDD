# Lane router: routed mega-sdd vs vanilla Claude Code, xs + clinic (MEASURED)

**Date:** 2026-09-27. **Follows:** `research/2026-09-27-vanilla-vs-megasdd-results.md` (the pipeline lost to
vanilla on every cost dimension, with equal or lower quality).

**Data:**
- `benchmarks/results/vanilla-ab/` (arms `routed`, `routed-v1`, `vanilla-day2`; `REPORT.md`, `compare.json`)
- per run: `metrics.json`, `quality.score.json`, `delivery-check.json`

**Model:** opus for every arm and the scorer.
**Plugin:** the working tree of `bench/vanilla-arm` (uncommitted), loaded as `mega-sdd@inline`.

## 1. What changed, and what was measured

- **Router.** The front door now runs `scripts/route-lane.sh` first. From observable signals it
  picks one of three lanes:
  - `direct`: plain Claude Code;
  - `assisted`: direct + one batched ask + one blind review;
  - `guarded`: the existing pipeline.
- **Delivery check.** Every lane ends with `scripts/delivery-check.sh`.
- **How the arm was run.** Arm `routed` = `/mega-sdd:mega-sdd <PRD>` with no flag, so the router
  decides. The router picked:
  - xs → `direct` (no signal);
  - clinic → `assisted` (6 open questions, a security surface, multi-flow).

  **Not measured:** `guarded` (no brownfield fixture yet) and the interactive batched ask (headless).
- **Snapshots.** Two plugin snapshots were used:
  - `routed-v1` (xs 1–3): delivery-check was a step in the procedure. An earlier version of this
    doc said one of the three runs skipped it. The local run streams (`stream.jsonl`, not committed)
    show a `delivery-check.sh` call ending in `VERDICT: PASS` in all three, so that claim is
    withdrawn. Neither version can be checked from the committed raw data.
  - `routed` (xs 4–6, clinic 1–3): "done = delivery-check `VERDICT: PASS`" is stated as the
    definition of done, in the front door and at the top of `direct-lane.md`. All six runs ran
    the check.

## 2. Results (median [min–max], clean runs, n=3 per arm unless noted)

| xs | vanilla (09-26) | routed | lite (old default candidate) | classic (old default) |
|---|---|---|---|---|
| review-ready (min) | 3.2 [3.1–5.7] | **2.7 [2.4–2.7]** | 20.2 [15.1–23.1] | 38.5 [36.7–41.8] |
| cost (USD) | 1.03 [0.91–1.45] | 1.16 [0.98–1.18] | 11.29 | 22.47 |
| tokens total | 1.0 M | 1.3 M | 20.2 M | 54.0 M |
| output tokens | 21.7 k | 18.1 k | 180 k | 281 k |
| tool calls / subagents | 33 / 0 | 28 / 0 | 304 / 19 | 456 / 32 |
| `.mega-sdd/` lines committed | 0 | 0 | 40,335 | 39,712 |
| code + test lines | 741 | 565 | 906 | 1,166 |
| AC | 12/12 | 12/12 (6/6 runs incl. v1) | 11/12 | 11/12 |
| Critical / Important | 0 / 0 | 0 / 0 | 0 / 2 | 0 / 2 |
| blind rubric | 95 [95–96] | 94 [93–94] | 84 | 82 |
| delivery-check | 3/3 PASS | 6/6 PASS | 0/3 | 0/3 |

| clinic | vanilla (09-26/27) | routed (assisted) | lite |
|---|---|---|---|
| review-ready (min) | 30.0 [25.5–35.8] | 26.6 [22.7–29.6] | 70.6 [65.0–93.9] |
| cost (USD) | 7.68 [6.29–7.81] | 9.30 [6.95–9.79] | 67.33 [53.29–73.27] |
| tokens total | 13.1 M | 18.1 M | 146.9 M |
| tool calls / subagents | 98 / 0 | 141 / 1 | 1,777 / 126 |
| `.mega-sdd/` lines committed | 0 | 0 | 123,824 |
| AC | 10/10 | 10/10 | 9–10/10 |
| Critical / Important | 0 / 2 [1–2] | 0 / 0 | 0 / 2 |
| blind rubric | 90 [89–90] | 91 [90–91] | 85 |
| delivery-check | 3/3 PASS | 3/3 PASS | 0/3 (build fails with an empty env) |

Same-day controls (`vanilla-day2`, n=1, scored in the same scoring batch as `routed`: one
`blind-score.sh` call per scenario, in which every label gets its own fresh `claude -p` session. The
batch grouping comes from the local scoring lists; the committed per-run files record only each
label's own `scorer_sid`):

| scenario | review-ready | cost | AC | Critical / Important | rubric |
|---|---|---|---|---|---|
| xs | 3.7 min | $1.09 | 12/12 | 0/0 | 94 |
| clinic | 31.0 min | $8.30 | 10/10 | 0/0 | 91 |

## 3. Verdicts under the locked rules (`vanilla-vs-megasdd.md` §7)

| claim | verdict | honest reading |
|---|---|---|
| routed faster than vanilla on xs | `BETTER` for review-ready, wall, output tokens and code + test lines (565 [529–582] vs 741 [700–1,042]). `routed-v1`: `BETTER` for code + test lines only | **Not claimed.** The routed runs were on a different day from vanilla 1–3. The same-day vanilla (3.7 min) also sits above the routed range, but that is n=1. The gap is ~0.5 min on a 3-minute task, and the prompts differ (vanilla's spells out "tests per criterion, commit"). The honest summary is "on par". |
| routed cheaper than vanilla | `OVERLAP` both scenarios (xs median 1.13×, clinic 1.21×) | not claimed |
| routed quality ≥ vanilla | AC, Critical `OVERLAP`. xs rubric `WORSE` (93–94 vs 95–96). Clinic Important `BETTER` (0 vs 1–2) | the xs rubric gap is 1 point at the median (94 vs 95), across **different scoring batches**. The same-batch vanilla scored 94. Clinic Important 0 vs 1–2 is also cross-batch: the same-batch vanilla = 0 too. Read as "not shown to differ" |
| other clinic verdicts | `WORSE`: subagents (1 vs 0) and distinct files read (9 [3–30] vs 1 [0–2]). `BETTER`: markdown lines added outside `.mega-sdd/` (51 [35–54] vs 78 [57–95]). Everything else `OVERLAP` | none claimed. The one subagent is the assisted lane's blind review |
| routed vs the pipeline it replaces | every cost dimension: non-overlapping ranges vs lite and classic. AC 12/12 and 10/10 vs 11/12 and 9–10/10 | this is the change's measured effect |

**Bottom line:** on these two greenfield scenarios, mega-sdd with the router is **on par with vanilla
Claude Code**. It does not beat vanilla. The old default path's overhead (2.4–12× the time, 8.8–22×
the cost) is gone. It still ships a check vanilla does not run: the delivery-check. The old pipeline
failed it on all 9 clean pipeline runs. The 10th pipeline run, clinic lite-1 (excluded from the
medians for a system sleep), passed D1–D5.

## 4. Artefact footprint (MEASURED on the committed trees of the earlier runs)

Replaying the new `.mega-sdd/.gitignore` + opt-in render against the 10 mega-sdd benchmark repos:

| run | `.mega-sdd/` lines committed | would stay tracked | cut |
|---|---|---|---|
| xs lite 1 / 3 | 48,118 / 40,284 | 5,113 / 4,268 | 89% / 89% |
| xs lite 2 (committed no HTML render) | 3,766 | 3,672 | 2.5% |
| xs classic 1–3 | 39,390–40,191 | 7,003–7,683 | 81–82% |
| clinic lite 2–4 | 123,419–126,305 | 19,348–21,463 | 83–85% |
| clinic lite 1 (excluded run, sleep) | 125,275 | 12,228 | 90% |

Line counts are the files' lines at each final HEAD. Cut ranges are rounded, not truncated (xs
classic 80.9–82.2%, clinic lite 2–4 82.6–84.7%).

- **What goes:**
  - the HTML render: 73.7–87.3% of committed `.mega-sdd/` lines (git numstat) in 9 of the 10
    repos; xs lite-2 committed no HTML at all;
  - per-lens copies of the unit body, prompts and pack slices;
  - gate-state caches;
  - `state.json`.
- **What stays, and why:**
  - the spec (`context.md`/vault, `constitution.md`, units): what was built against;
  - `bolt-report.md`, `binding.json`, `findings.json`, `pre/postflight.json`, `acceptance.json`,
    `attempts.json`, `l0-results.json`: the evidence the gates read and a reviewer audits;
  - `dispatch-prompt.md`: what the implementer was told. The commit trailer points to it, and it
    can't be rebuilt byte-identically later.

  On the guarded lane, clinic still commits ~20k evidence lines against ~10k code lines. Shrinking
  those files further is a guarded-lane question for the brownfield block, not a greenfield one.

## 5. Quality defects: cause and fix

| defect (earlier runs) | cause (from the artefacts) | fix |
|---|---|---|
| xs, 6/6 pipeline runs: no `npm test` | units are atomized per artefact; the `target_files` whitelist gives no unit ownership of `package.json` scripts | delivery-check D1 + one `fix(delivery)` commit at the end of execute-bolts. The direct lane owns the whole repo, so the gap cannot arise there |
| xs, 6/6: no link to Tentang Kami | the same: no unit owns the navigation shell | D5 (advisory) + direct-lane bar "every page reachable" |
| clinic lite, 3/3 (not 2/3 as first reported): `build` fails with an empty env | env validated at module import, so it throws while prerendering `/staff/*` | D4 (fresh checkout, `env -i`) + implementer rule 5b: validate at request time |
| clinic lite-2: 1/220 tests TZ-dependent | test assumed a UTC host | D3 (UTC and UTC+14) + rule 5b |

Routed runs: delivery-check 9/9 PASS (6 xs + 3 clinic), checked afterwards on each final HEAD
(`delivery-check.json` per run). The three v1 runs are included; see §1 for what they did in-session.

## 6. Limits

- **Headless.** The assisted batched ask can't be answered, so the model took conservative
  defaults. The interactive value of the ask is unmeasured.
- **Greenfield only.** `guarded` is untested in this block and so is the moat. The next experiment,
  `benchmarks/runbooks/brownfield-ambiguous-prd.md`, was designed here and run later the same day:
  `research/2026-09-27-brownfield-results.md`.
- **Different day from vanilla 1–3.** One same-day vanilla per scenario is the drift check, not a
  second control arm.
- **Prompt asymmetry.** Vanilla gets a task sentence that spells out the deliverables. Routed gets
  `/mega-sdd:mega-sdd <PRD>`, which is how a user starts the plugin.
- **Scorer drift across scoring batches** (see §3). The xs `scoring-routed-*` labels are independent
  of the earlier rounds.
- **Blind-strip warning on clinic.** `PRD/prd-clinic.md` itself contains the word "mega-sdd". The
  file ships to every arm, vanilla included, so it doesn't reveal the arm.
- **Measured tree vs final tree.** Two changes landed after the runs, found by the full suite. Neither touches a routing decision on these fixtures:
  - the tier-L row in the injected anchor was shortened (the anchor has a byte cap);
  - `route-lane.sh` bounds its `git ls-files` call to 30 s and treats a timeout as `existing_code`.
- **Cost of this block:** runs $42.04 + scorer $5.41 = **$47.45**. The runs are MEASURED from the
  committed `metrics.json`. The scorer figure comes from the local scorer streams (11 sessions), so
  it is not checkable from the committed raw data.

## 7. Simplifications applied after the measurement (UNMEASURED in runs)

| change | evidence | what it is not |
|---|---|---|
| A new PRD on the guarded lane defaults to **lite**. `lane: standard` keeps classic, and existing vaults keep the lane they were built on | xs n=3: lite beats classic on time and cost with no overlap, quality overlaps. Clinic classic historical n=1 ($259.66 / 301.4 min wall, plugin 7.35.0, another fixture; runbook §8c) vs clinic lite $53–73 / 65–94 min | not measured on clinic in this fixture, a deviation from the locked two-scenario rule (runbook §9). Classic is not removed: brownfield may still need it |
| Lens **`standards` only rides with `quality`** (H1) | field yield: 5 dispatches, 0 Critical, 1 unique fix (a key name), ~335k tokens; quality found 22 fixes in 5 dispatches. Source: `research/2026-08-30-lens-yield-field.md` §2–3 (~335k is that report's ESTIMATE, 5 × 67k); not checkable from committed raw data | not A/B-tested; n = one field project |

**Kept, with reasons:**

| component | why it stays |
|---|---|
| `--lean` | on the default express spine, the advisory diagnostics are already skipped. The flag only matters on the classic spine, and removing it would touch the state engine, the Stop hook and a test for vocabulary alone, with no measured saving |
| classic pipeline, binding CONFLICT gate, OQ rails, per-unit review panel | reachable only on the guarded lane, whose value is the open brownfield question. Removing them before that experiment would delete the one hypothesis mega-sdd has left to test |
