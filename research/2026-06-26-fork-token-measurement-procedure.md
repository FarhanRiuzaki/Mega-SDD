# Fork token measurement — detect-drift live before/after (the scan/bind precondition)

**Status:** scaffold ready · awaiting one live run on a real machine
**Gates:** `plugins/mega-sdd/CLAUDE.md` (Capability-adoption: *"Re-evaluate fork for scan-codebase / bind-codebase only after the live token before/after on detect-drift confirms the win"*) and the `moat-token-tradeoff` memory.
**Comparator:** `plugins/mega-sdd/scripts/measure-fork-tokens.sh` · contract test `tests/fork-measurement/test-measure-fork-tokens.sh`
**Design context:** `research/2026-06-26-context-reset-fork-feasibility.md`

## Why this exists

`detect-drift` shipped with `context: fork` (v3.0.0). The structural claim — a forked skill runs in a fresh context that inherits **none** of the main pipeline's accumulated history — is proven on paper (standalone footprint ≈605K cost-weighted across 45 turns). What is **not** yet measured is the *live* delta: forked detect-drift vs the same skill **without** the fork, on the same input, end-to-end through the real harness. That number is the gate before paying to convert `scan-codebase` and `bind-codebase` (the other two non-interactive, fork-eligible skills).

The harness's own `subagent_tokens` reports only the **last** turn's usage — an 8.2× (cost) / 32.8× (raw) undercount. So the measurement must come from `report-token-cost.sh`, which sums `message.usage` across every subagent turn and cost-weights it (cache-read billed ~0.1×). The comparator reads that script's `.token-cost-state.json` output; it does **not** re-instrument.

## What you measure

| | A — baseline | B — fork |
|---|---|---|
| `detect-drift` frontmatter | `context: fork` **removed** | `context: fork` present (main) |
| run | identical drift scenario | identical drift scenario |
| capture | `.token-cost-state.json` → `baseline.json` | `.token-cost-state.json` → `fork.json` |

Same input, same vault, same drift. The **only** variable is the fork frontmatter.

## Procedure (run on a real machine — fork needs live agent dispatch)

Use any vault with a known drift: your own project vault, or the neutral `tests/fixtures/sample-project` seeded with an edit that diverges from its binding. Keep telemetry on (`.mega-sdd/memory/telemetry.jsonl` must exist before the run — see the SubagentStop gate).

**1 — Baseline (no fork).** On a throwaway branch, delete the `context: fork` line from `plugins/mega-sdd/skills/detect-drift/SKILL.md` frontmatter. In the target project:

```bash
rm -f .mega-sdd/memory/telemetry.jsonl && : > .mega-sdd/memory/telemetry.jsonl   # fresh capture
# … run /mega-sdd:detect-drift to completion on the drift scenario …
plugins/mega-sdd/scripts/report-token-cost.sh --cwd="$PWD" --json
cp .mega-sdd/.token-cost-state.json /tmp/baseline.json
```

**2 — Fork (main).** Check out `main` (fork present). Reset the scenario to the identical pre-run state, then:

```bash
rm -f .mega-sdd/memory/telemetry.jsonl && : > .mega-sdd/memory/telemetry.jsonl
# … run /mega-sdd:detect-drift to completion on the SAME drift scenario …
plugins/mega-sdd/scripts/report-token-cost.sh --cwd="$PWD" --json
cp .mega-sdd/.token-cost-state.json /tmp/fork.json
```

**3 — Compare.**

```bash
plugins/mega-sdd/scripts/measure-fork-tokens.sh \
  --baseline=/tmp/baseline.json --fork=/tmp/fork.json \
  --skill=detect-drift --margin=0.10
# exit 0 = WIN (fork ≥10% below baseline) · exit 1 = NO-WIN · exit 2 = bad input
```

Compare both the `detect-drift` bucket (`--skill=detect-drift`) and the run total (omit `--skill`). The bucket isolates the skill; the total catches any fork overhead pushed onto the parent.

## Decision gate

- **WIN** (fork meaningfully below baseline, suggested `--margin=0.10`) → the mechanism pays off live. Proceed to convert `scan-codebase` and `bind-codebase` to `context: fork` (both already non-interactive; preserve the PreToolUse gates — they fire before the body forks). Re-run this procedure on each after conversion.
- **NO-WIN / marginal** → do **not** extend. Record the number, keep fork on detect-drift only (the contract is still correct, just not a token win at this scale), and revisit if the dispatch cost model changes.

A single run is suggestive, not conclusive — repeat 2–3× and use the median; agent token usage is noisy.

## Results log (fill in from a live run)

| date | scenario | metric | baseline (cost-wt) | fork (cost-wt) | delta | % | verdict |
|---|---|---|---|---|---|---|---|
| _pending_ | | detect-drift bucket | | | | | |
| _pending_ | | run total | | | | | |

> Until this table has real numbers, the scan/bind fork extension stays in the backlog (task #18), not in flight.
