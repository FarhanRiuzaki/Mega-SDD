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

## Precondition: SubagentStop must actually fire (verify FIRST — it is a silent footgun)

The fork arm's **entire** cost is a `subagent_end_marker`, emitted only when the harness fires the `SubagentStop` hook at the fork boundary. If `SubagentStop` is not delivered to the plugin hook in your environment, the fork run captures **zero** subagent cost and the A/B silently compares a phantom — a wrong "NO-WIN" (or a wrong "WIN") with no error.

**This is not hypothetical.** In a 2026-06-27 in-environment check, a subagent dispatched via the harness `Agent` tool did **not** fire `SubagentStop` to the plugin hook at all. This was confirmed by isolating the cause (not just inferred from a missing marker): an *unconditional* probe added to the very top of `hooks/subagent-stop`, **before every bail** (the `cwd`/`.mega-sdd`/`telemetry:false` guards), never wrote a line despite a subagent running to completion — so the hook body never ran, i.e. the harness never dispatched it for that path. Corroborating: zero `subagent-stop` diagnostic lines in `.mega-sdd/memory/hook-debug.log`, zero `subagent_end_marker`s all session, `report-token-cost.sh subagent_turns: 0` (while still showing 9.4M cost-weighted of *main-thread* telemetry). The hook code itself is sound (always-on diagnostic, sums usage across all subagent turns, cost-weights it; pinned by `tests/token-cost/test-subagent-stop-telemetry.sh`) — the gap was upstream event delivery for the `Agent`-tool dispatch path. A standard Claude Code `/mega-sdd` pipeline dispatches its subagents via the plugin-agent (Task) path, for which `SubagentStop` is designed to fire — but **you must confirm it in YOUR environment before trusting any number.**

**Verify (10 seconds):** run any pipeline step that dispatches a subagent (e.g. a small `execute-bolts`), then read the two counters *together* — they distinguish three cases (the diagnostic line is written before the capture logic, so it isolates "fired" from "captured"):

```bash
DIAG=$(grep -c '"hook":"subagent-stop"' .mega-sdd/memory/hook-debug.log)   # SubagentStop reached the hook
MARK=$(grep -c subagent_end_marker      .mega-sdd/memory/telemetry.jsonl)  # the hook captured + emitted usage
echo "diagnostic=$DIAG marker=$MARK"
```

| diagnostic | marker | meaning | action |
|---|---|---|---|
| `0` | `0` | SubagentStop never reached the hook (harness didn't emit it for this dispatch path — what the Agent-tool check showed) | fix hook delivery / use a dispatch path that fires SubagentStop; do NOT measure |
| `> 0` | `0` | SubagentStop fired but the hook captured nothing (empty/missing subagent transcript — e.g. the payload lacks `agent_transcript_path`) | a hook-side issue — report it; the A/B still can't capture fork cost |
| `> 0` | `> 0` | healthy — fork cost is captured | proceed |

Only the third row is safe to measure on. The comparator's `--require-subagent` flag (below) enforces this at compare time regardless: it refuses a verdict when the fork snapshot has `subagent_turns == 0`.

## Procedure (run on a real machine — fork needs live agent dispatch)

Use any vault with a known drift: your own project vault, or the neutral `tests/fixtures/sample-project` seeded with an edit that diverges from its binding. (Note: `sample-project` ships with **no codebase** — only a `.mega-sdd/` state tree — so `--code` won't resolve there; point `--code` at a real repo with a `mode=existing` vault.) Keep telemetry on (`.mega-sdd/memory/telemetry.jsonl` must exist before the run — see the SubagentStop gate).

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
  --skill=detect-drift --margin=0.10 --require-subagent
# exit 0 = WIN (fork ≥10% below baseline) · exit 1 = NO-WIN
# exit 2 = bad input OR fork captured 0 subagent telemetry (SubagentStop didn't fire)
```

Always pass `--require-subagent` for a real A/B: it turns the silent SubagentStop footgun into a hard exit-2 with a remediation message, so you can never read a verdict off a fork run whose cost was never captured.

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

### Why this is still `_pending_` (two independent blockers, both → the user's machine)

A faithful A/B was attempted in-session on 2026-06-27 and could **not** be completed from here for two reasons, either of which alone forces a representative-session run on a real project:

1. **Baseline confound.** The no-fork arm runs detect-drift *inline*, inheriting the current session's full context. This session is ~1M tokens deep and unrepresentative, which would inflate the no-fork baseline by a large multiple and overstate the "win." A faithful baseline must come from a representative mid-pipeline session, not a measurement session.
2. **SubagentStop did not fire** (see the Precondition section). The fork arm's cost is entirely a `subagent_end_marker`; in this config none was emitted (`subagent_turns: 0`), so the fork cost is uncapturable here regardless of the baseline.

What is settled without the number:
- **Correctness gate: satisfied** — detect-drift is non-interactive, gates fire on the Skill call before the body forks, no `memory_context` dependence (`moat-token-tradeoff` memory; `research/2026-06-26-context-reset-fork-feasibility.md`).
- **Token sign: structurally ≥ 0** — saving = the inherited main-session context the inline run re-processes and the fork skips. Non-negative by construction for any non-trivial phase in a non-fresh session.
- **Token magnitude: OPEN and session-dependent** — saving ≈ inherited-context size × fork-turn-count × cache-read weight (0.1×). A large mid-pipeline context over ~45 fork turns can clear 50%+; a light session is marginal. It is **not** a fixed percentage and is unknowable from here — which is exactly why the gate requires a representative-session run. Do not pin a number, and do not pre-decide the gate either way.

> The extend-to-scan/bind decision is therefore **PENDING the live measurement**, per `plugins/mega-sdd/CLAUDE.md` ("re-evaluate … only after the live token before/after confirms the win"). Deciding it now on the structural argument alone would override a written measurement gate with prose — the enforcement-by-prose anti-pattern the doctrine forbids.
