# c1 — parallel-batch re-scan consumer trace: EVALUATED, KEEP (on the record)

**Context:** proposal (c1) of `docs/superpowers/proposals/2026-08-11-morning-proposals.md` gated any cut of the per-batch quality re-scan (`batch-and-fanout.md` blockquote → `hard-rule-scan.md §Parent-thread post-flight re-scan`) on a consumer trace: *who reads the gate state between batches?* Trace executed 2026-08-17.

## What the re-scan actually is

Under `--parallel` / `--per-squad`, after each bolt batch the main-thread controller bash-invokes **three** validators against `$PROJECT_ROOT` with `--quiet`, branching on exit code: `validate-cross-cutting-registration.sh`, `validate-ui-quality.sh`, and (vault edits only) `validate-vault-oqs.sh`. **The proposal's cost estimate of "6–7 validator spawns × N batches" was wrong — it is 2–3 spawns per batch** (~0.7s/batch on the Windows/CrowdStrike fleet at ~220ms/spawn; negligible on macOS). Token cost: 0 (script plane).

## The consumer trace (all readers of `.ui-quality-state.json` / `.cross-cutting-state.json` / vault-oqs state)

| Reader | How it consumes | Depends on batch-end freshness? |
|---|---|---|
| `hooks/pre-tool-use` (the next execute-bolts gate) | **RE-DERIVES both at gate time** (S6 EB-GATE-1 — shipped precisely because "a heredoc-written view keeps a stale PASS") | **No** — recomputes from current truth |
| `hooks/post-tool-use` | Producer path (fires the validators on Write/Edit globs) | n/a |
| `hooks/stop` | Only *excludes* the state files from its debounce change-detection | No — not a content consumer |
| `scripts/run-analyze.sh` | Advisory consistency surface, on-demand, semantic-scoped re-runs for changed files | No — advisory only |
| **The re-scan itself** | Its non-zero exit is the ONLY mid-run halt on a fresh ui-quality/cross-cutting violation between batches | — |

So the proposal's cut condition ("the gate re-derives everything itself at the next fire") **is technically met for correctness**: nothing escapes if the re-scan is removed — the detect-and-block-next contract holds via EB-GATE-1 recompute.

## Why KEEP anyway (the asymmetry the proposal didn't price)

Removing the re-scan removes the **early mid-run halt**. A ui-quality / cross-cutting violation landed by batch N would then go undetected until the NEXT `execute-bolts` gate fire — while the CURRENT run keeps dispatching batches N+1… on top of the violation. Each wasted wave costs an implementer dispatch + L0 + review panel per unit (order 10⁴–10⁵ tokens and minutes of wall-clock), against a saving of **~0.7s and 3 process spawns per batch**. The trade is upside-down by ~3 orders of magnitude; the "defense-in-depth" label in the ref understates it — this is cheap early-abort insurance on the most expensive loop in the plugin.

## Verdict

**KEEP the per-batch re-scan. c1 is closed** — not "blocked on a trace" but evaluated with the trace done: correctness-wise cuttable, economically not worth cutting. Do not re-open without evidence that mid-run violations are (a) vanishingly rare in field telemetry AND (b) the spawn cost became material on some fleet.

*Closes the last runnable item of the 2026-08-17 pemangkasan audit. Remaining levers are user-gated: P3 advisor scoping/tier (measured ~124k tok/bind, opus), scan/bind `context: fork` flip (2 interactive runs).*
