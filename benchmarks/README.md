# Mega-SDD optimization benchmark — P1–P4 (v6.2.0 → v6.6.0) vs pre-audit baseline

Proves — with evidence-classified measurements, not claims — whether the
2026-08 skills-audit optimization actually improved the system.

**Commit pair (do not rely on assumptions — these are the exact states):**

| Arm | Commit | State |
|---|---|---|
| BASELINE | `91a944a` | v6.1.1 stamp — the last commit before audit Phase 1 (`43c4b8a`) |
| OPTIMIZED | `a09e430` | v6.6.0 — audit Phase 4 (the last audit train) |

**Verdict + all numbers:** [`results/comparison/REPORT.md`](results/comparison/REPORT.md)
· machine-readable: [`results/comparison/results.json`](results/comparison/results.json)

## Reproduce (any engineer, ~20 min)

```bash
git worktree add --detach /tmp/megasdd-baseline 91a944a
bash benchmarks/scripts/run-benchmark.sh /tmp/megasdd-baseline   # add --skip-quality for a fast pass
python3 benchmarks/scripts/compare-results.py
```

## Layout

- `config/benchmark.config.json` — commit pair, token heuristic (chars/4 = ESTIMATED), plane globs, gate rules.
- `tasks/` — 8 real mega-sdd workflow scenarios (`SCENARIOS.md` = canonical states; per-task `TASK.md` + the traced commanded-load lists `files.<arm>.txt`; derivation policy in `ADJUDICATION.md` + `HARMONIZATION.md`).
- `scripts/` — `measure-static.sh`, `measure-duplication.py`, `measure-context.sh`, `quality-gate.sh`, `run-benchmark.sh`, `compare-results.py`. All take an arm root — nothing hardcodes a checkout.
- `results/{baseline,optimized}/` — raw per-arm JSON + the verbatim tracer reports (`context-trace-raw.md`).
- `results/comparison/` — `REPORT.md` + `results.json`.
- `surveys/dx-survey.md` — the human DX instrument (**PENDING HUMAN VALIDATION** — no fabricated responses).
- `runbooks/velocity-live-ab.md` — the interactive A/B experiment velocity numbers require (**NOT MEASURED** here; headless arms are non-representative per recorded evidence).

## Method in one paragraph

Static footprint and duplication are MEASURED byte-for-byte on both arms with
identical scripts. Per-task context is a STATIC TRACE (labeled PROXY): two
blind read-only agents traced which files each arm's loading contract commands
for the same 8 scenario states; ambiguous entries were adjudicated by one
written policy applied to both arms, and `[SECTION:…]` partial reads are counted
as WHOLE files — an upper bound that biases AGAINST the optimized arm. Quality
is MEASURED by running both arms' full test trees with the same discovery rule.
Velocity and DX are NOT MEASURED — the runbook and survey exist so a human can
close them; no number in the report pretends otherwise.
