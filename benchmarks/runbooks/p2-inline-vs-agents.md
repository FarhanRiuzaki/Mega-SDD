# Runbook: P2 inline execution vs per-unit agents (brownfield, LOCKED 2026-09-27)

**Status:** locked before any run. Design: `docs/superpowers/specs/2026-09-27-v9-simplification-design.md`
§8. Results go in §7 below, and the decision in §8.

## 1. Question

The measured pipeline defects come from splitting the work across units:

| defect | guarded runs | single-context runs |
|---|---|---|
| no `npm test` | 7/7 | 0/11 |
| page unreachable | 7/7 | 0/11 |
| scaffold leftovers | 6/7 | 0/11 |
| clinic build fails with an empty env | 3/3 | 0/7 |

In the brownfield block, the per-dispatch CONFLICT gate fired 3 times, all false positives, and
caught none of the seeded contradictions.

**Question:** does running the units inline in one context (`execute-bolts --inline`) keep the
guarded lane's result quality while cutting its cost?

The gates stay deterministic scripts, but the CONFLICT block is no longer a hook at each dispatch
(an owner-approved, opt-in exception to invariant #2 — plugin `CLAUDE.md`):
- the CONFLICT block moves to run start (a script the controller runs) plus a re-bind per task;
- a commit past a CONFLICT can land inside the run: `conflict_bypassed` (detect-after, judged
  against the CONFLICT state each commit landed under), B1–B4, the whitelist and the orphan check
  catch it at the run boundary and block the next entry;
- there is one blind review at the end.

## 2. Hypotheses (pre-registered)

- **P2-Q (quality, non-inferiority):** against `guarded`, `guarded-inline` is **not WORSE** on:
  - AC;
  - Critical;
  - Important;
  - traps surfaced (T1–T5);
  - v1 regressions.
- **P2-C (cost):** `guarded-inline` is cheaper and faster than `guarded`. The ratio is reported,
  and it is never traded against a quality loss.
- **P2-M (moat):** no inline run commits a unit past an open CONFLICT, i.e. `conflict_bypassed` = 0
  at HEAD.

## 3. Fixture and arms

- **Fixture:** `fixture-brown` @ `015ecf3` (Harbor Clinic v1 + `PRD/prd-clinic-v2.md`, seeded
  traps T1–T7; see `brownfield-ambiguous-prd.md` §2).
- **Plugin:** ONE `git archive` snapshot of the P2 commit, used by both guarded arms.
  - Both guarded arms run the same P2 snapshot. Its default path adds the `conflict_bypassed`
    leg (at the Skill entry and each dispatch) and the commented-`depends_on` parse fix, so
    `guarded` measures 9.0 plus those, not 9.0 as shipped.
  - `P0_PLUGIN_DIR` pins the snapshot; `run.meta` records its version.

| arm | batch arm | launch | n |
|---|---|---|---|
| `guarded` | `guarded` | front door, `--guarded` (plan → execute-bolts per-unit agents + panel → delivery-check) | 3 |
| `guarded-inline` | `guarded-inline` | front door, `--guarded --inline` | 3 |
| `vanilla` | `vanilla` | plugin disabled, plain task prompt | 1 same-day drift check, plus the 3 clean runs of 2026-09-27 (`vanilla-2..4`) |

- **Order:** seed `20260927`:
  ```
  python3 -c "import random; a=['guarded']*3+['guarded-inline']*3+['vanilla']; random.seed(20260927); random.shuffle(a); print(a)"
  ```
  → `vanilla, guarded-inline, guarded-inline, guarded, guarded, guarded-inline, guarded`.
- **Machine:** runs are sequential, under `caffeinate` on AC power.
- **Clean-run rule:** as in `vanilla-vs-megasdd.md` §4. A run with an outage (sleep, crash,
  purity FAIL) is excluded and replaced with the next id, and the exclusion is recorded.

**Confound, held equal across arms:** superpowers 6.4.1 is loaded in every arm, vanilla included
(`plugins=` in `run.meta`). `guarded-inline` therefore exercises the superpowers `executing-plans`
path, not the built-in fallback. The fallback gets a smoke run only.

## 4. Metrics (same tools as the brownfield block)

- **Quality:**
  - AC (13 items, `ac-checklist-brownfield.md`);
  - Critical / Important and the blind rubric (`blind-score.sh`);
  - traps surfaced (`trap-judge.py`, verbatim quotes checked mechanically);
  - v1 suite at HEAD (73 tests);
  - `delivery-check.sh` at HEAD.
- **Moat:** `validate-bolt-artifacts.sh --conflict-bypass-scan` at HEAD (must be PASS), the
  number of CONFLICT fires and their true/false-positive classification, and the quarantined units.
- **Cost:** review-ready minutes, cost, tokens, subagents, tool calls, committed `.mega-sdd/`
  lines, code + test lines.
- **Verdict per metric:** `compare-arms.py` (BETTER / WORSE only when the clean ranges do not
  overlap; OVERLAP otherwise).

## 5. Decision rule (locked)

| outcome | action |
|---|---|
| all five P2-Q metrics are OVERLAP or BETTER, and P2-M holds | `--inline` becomes the guarded default; the P3 deletion (per-unit panel, resolution-verifier, merge-panel-findings, attempt cap, per-dispatch hook legs) is proposed with this evidence |
| any P2-Q metric is WORSE | `--inline` stays opt-in; P3 does not run; the losing metric is analysed before any redesign |
| P2-M fails (a bypass reached HEAD) | P2 is a defect: fix it first, re-run the affected arm; no default change |

**Limit:** "not WORSE" at n=3 with a range-overlap test has low power. It can only catch a large
loss. The claim is scoped to this fixture, and it is never phrased as "equal quality".

## 6. Cost estimate (EST, from the measured brownfield block)

- `guarded`: about $39 per run → 3 × $39 ≈ **$117**. The 2026-09-27 routed runs cost $37.6–39.3.
- `guarded-inline`: unmeasured. Assuming one context plus one review, roughly $10–20 per run →
  **$30–60**.
- `vanilla`: 1 × about $6.5.
- Scoring (blind scorer + trap judge): about **$8**.
- **Block total: ≈ $160–190.** The owner-approved option said "~$130". The difference comes from
  re-running `guarded` on 9.0 instead of reusing the pre-9.0 routed runs, which is needed for a
  same-version comparison.

## 7. Results

Run 2026-09-27/28, all 7 runs clean. Full analysis: `research/2026-09-28-p2-inline-results.md`.

| | guarded (agents) | guarded-inline | verdict |
|---|---|---|---|
| AC | 13 [12–13] | 13 [13–13] | OVERLAP |
| Critical / Important | 0 / 0 [0–1] | 0 / 0 | OVERLAP |
| traps surfaced | 5/5 ×3 | 5/5 ×3 | OVERLAP |
| v1 suite at HEAD | 73/73 ×3 | 73/73 ×3 | OVERLAP |
| `conflict_bypassed` | PASS ×3 | PASS ×3 | — |
| rubric | 92 [82–93] | 91 [90–93] | OVERLAP |
| cost (USD) | 42.45 [33.96–43.60] | 25.08 [20.88–25.38] | inline BETTER |
| review-ready (min) | 55.4 [46.7–67.5] | 50.9 [44.2–51.1] | OVERLAP |
| subagents | 70 [61–75] | 3 [3–4] | inline BETTER |

## 8. Decision

All five P2-Q metrics are OVERLAP, and P2-M holds (0 bypasses). By the locked rule in §5,
**`--inline` becomes the guarded default**, and the P3 deletion is proposed with this evidence.
Both guarded arms stay WORSE than vanilla on time, cost and tokens, so the lane router default is
unchanged and guarded stays opt-in.
