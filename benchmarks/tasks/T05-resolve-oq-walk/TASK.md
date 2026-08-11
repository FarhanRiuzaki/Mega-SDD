# T05-resolve-oq-walk — Resolve-OQ interactive walk (3 OQs)

**Scenario (canonical definition):** `../SCENARIOS.md` §T05 — state fixed there; both arms trace the SAME state.
Vault carries 3 open `[ ]` OQs; full interactive walk, recommendations rendered, no halts.

Maps to: requirement-clarification workflow.

## Deterministic expected result

The commanded-load sets `files.baseline.txt` / `files.optimized.txt` in this
directory ARE the expected result: the exact plugin files each arm's loading
contract commands for this scenario, derived by blind tracer agents
(raw: `../../results/<arm>/context-trace-raw.md`), adjudicated per
`../ADJUDICATION.md`, cross-arm harmonized per `../HARMONIZATION.md`.

## Automated validation

```
bash benchmarks/scripts/measure-context.sh <arm-root> <arm> <out.json>
```

fails a path that stopped existing (missing_paths) and recomputes every size —
the lists are re-checkable against any commit. Acceptance: 0 missing paths in
both arms.

## Metrics NOT collected here

Wall-clock, turns, tool calls, retries, live token usage: NOT MEASURED —
requires the interactive A/B runs specified in `../../runbooks/velocity-live-ab.md`.
This task measures the STATIC TRACE (PROXY) of commanded context only.
