# Velocity live A/B runbook — the experiment this benchmark could NOT run autonomously

**Status: NOT MEASURED.** Every velocity number (wall-clock, turns, tool calls,
retries, live token usage) requires this experiment. Nothing in REPORT.md scores
velocity from data; the static context trace is a PROXY for part of it only.

## Why it was not run in-session

Recorded evidence (`research/2026-07-20-fork-ab-headless-attempt.md` + memory):
under headless `claude -p`, `context: fork` silently NO-OPs, Stop hooks do not
fire (telemetry dark), and a prose-halt was bulldozed in 1 of 4 runs — headless
arms are NOT representative of interactive behavior, and interactive arms need a
human at the AskUserQuestion surfaces. Fabricating either arm is prohibited.

## Protocol (adapted from the PROVEN P5/A7 runbook — docs/superpowers/ P5 measurement, which measured express vs classic the same way)

1. **Fixture**: `tests/blackbox/seed-playground.sh` builds the disposable
   playground; same seed for every run.
2. **Arms**: plugin at `91a944a` (baseline) vs `a09e430` (optimized). Install
   each into a separate clean `~/.claude` profile (or worktree-scoped plugin
   dir) so nothing else changes. Same model, same permission mode, same OS.
3. **Tasks**: run T01, T03, T04, T05 from `../tasks/SCENARIOS.md` exactly as
   written (T03/T04 need the 2-file hotfix commit scripted into the fixture).
4. **Runs**: minimum 3 per task per arm (5 preferred), interactive session,
   the human answering ONLY what the scenario state dictates (confirm-Run, OQ
   answers as scripted). Alternate arm order between runs (A-B-B-A-…).
5. **Collect per run** (from the session transcript + `rtk gain`-style export or
   the extractor pattern in the P5 runbook): wall-clock (net of human idle),
   turns, tool calls, files read, cache-write tokens to first bolt / to chain
   end, retries, halts fired.
6. **Reduce**: mean/median/min/max/stddev per task per arm; compare MEDIANS.
7. **Gate**: every run must end QUALITY_PASS (the scenario's own acceptance:
   artifacts written, suites green where applicable) or the run is discarded
   and counted as a failure — a fast failing run is not a velocity win.

## Precedent for expected effort

The P5/A7 baseline arm alone took ~2h net wall-clock for one classic full-chain
run. Budget accordingly: 4 tasks x 2 arms x 3 runs is a multi-day human effort.
