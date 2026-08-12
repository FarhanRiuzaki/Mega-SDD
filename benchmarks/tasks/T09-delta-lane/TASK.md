# T09-delta-lane — the shipped fix for T07 (ADDENDUM, outside the frozen commit pair)

**Scenario:** identical user need to T07 ("tambah kolom npwp di form nasabah", existing bound Laravel vault) — but routed through the v6.7.0 **delta lane** (`diff-vault --from-prompt` → claim-scoped re-bind), which did not exist at either frozen benchmark commit. Measured at the lane's ship commit (`a6b8c45`/`2774976`), NOT at `a09e430` — that is why this task lives outside the T01–T08 comparison and has NO baseline arm (`files.baseline.txt` deliberately absent).

**Boundary:** re-bind complete — the SAME boundary as T07, so the numbers are directly comparable.

## Result (MEASURED sizes over the same PROXY static-trace method)

| Route | est tokens | Δ vs T07-optimized |
|---|---:|---:|
| T07 baseline 91a944a (full re-vault, v6.1.1) | 130,376 | +8.8% |
| T07 optimized a09e430 (full re-vault, v6.6.0) | 119,820 | — |
| **T09 delta lane (v6.7.0)** | **95,035** | **−20.7%** |

**Honest labeling:** 95,035 is an UPPER BOUND — 4 of the 26 files are `[SECTION:]` partial reads counted whole-file, and two of them (`routing-rules.md`, `binding-contract.md`) are among the largest files in the plugin; T09 commands only their delta-lane/claim-scoped sections. The spec's ~60–80k estimate is therefore *plausible under true section-granularity* but **NOT CONFIRMED** by this method — closing that gap needs runtime telemetry (the P5 extractor pattern), not a better static trace. What IS proven: the generate-intent full-generation segment (14 files) left the path, replaced by the 4-file diff-vault segment + 1 pointer ref.

**Validation:** `bash benchmarks/scripts/measure-context.sh <repo-root-at-v6.7.0+> optimized <out.json>` — 0 missing paths. Trace derivation: blind tracer agent applying `../SCENARIOS.md` rules + `../ADJUDICATION.md`/`../HARMONIZATION.md` policies (raw block preserved in the session transcript; citations per file in the tracer report).
