# benchmarks/results/p0-baseline — v8 P0 per-phase baseline (MEASURED only)

Home for the two P0 baseline arms mandated by the owner gate 2026-09-10
(runbook: `research/2026-09-10-p0-baseline/README.md`; decision rule locked
there BEFORE any number exists — kill-criterion: pre-code share < 25 % of
time-to-first-code ⇒ v8 stops at P1).

Files land here as `<arm>.json` written by
`python3 research/2026-08-04-p5-extract.py <transcript.jsonl> <first-unit-commit-iso> [<last>] --json benchmarks/results/p0-baseline/<arm>.json`
— deterministic transcript channels only (timestamps, `usage`, tool spans),
never narrated. Expected arms: `xs-3screen.json`, `clinic.json`.

**Status: EMPTY — no run yet.** Both arms are interactive owner runs on plugin
7.31.0 (P5/A7 protocol: never self-reported, never headless). Nothing in this
directory is a number until a JSON file is committed here with its transcript
path + `git log` endpoint recorded in the runbook §Hasil.
