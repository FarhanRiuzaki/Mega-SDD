# Fork token measurement — detect-drift live before/after (the scan/bind precondition)

**Status:** scaffold ready + machinery confirmed live (2026-06-29) · awaiting one baseline run in a *representative* (non-measurement) session — see "Why still pending" (now ONE blocker, not two)
**Gates:** `plugins/mega-sdd/CLAUDE.md` (Capability-adoption: *"Re-evaluate fork for scan-codebase / bind-codebase only after the live token before/after on detect-drift confirms the win"*) and the `moat-token-tradeoff` memory.
**Guarded driver (recommended):** `plugins/mega-sdd/scripts/measure-fork-ab.sh` · contract test `tests/fork-measurement/test-measure-fork-ab.sh`
**Raw comparator (underlying / escape hatch):** `plugins/mega-sdd/scripts/measure-fork-tokens.sh` · contract test `tests/fork-measurement/test-measure-fork-tokens.sh`
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

## Precondition 1: SubagentStop must actually fire (verify FIRST — it is a silent footgun)

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

> **✅ CONFIRMED RESOLVED in-environment (2026-06-29).** The 2026-06-27 "SubagentStop never fired" finding was root-caused to the hook matcher (`".*"` → `""`, commit `52c7fb4`, v4.50.0; the event matcher is treated as an exact/alternation token, so `.*` matched nothing and the hook never registered). After `/plugin marketplace update mega-sdd` → 4.52.0 + `/reload-plugins` (a reload re-snapshots the hook config — no full restart needed), a **controlled probe subagent** fired `SubagentStop` end-to-end: `hook-debug.log` recorded the invocation (`hook_source=SubagentStop`, real `agent_id` + `agent_transcript_path`) **and** `telemetry.jsonl` got a `subagent_end_marker` with real summed usage; `report-token-cost.sh` now reports `subagent_turns: 1` (was `0`). The third row ("healthy — fork cost is captured") is now the live state. **This blocker is closed.**

## Precondition 2: the SKILL.md you edit must be the plugin the session LOADS (the second silent footgun)

The baseline arm strips `context: fork` from `plugins/mega-sdd/skills/detect-drift/SKILL.md`. But a fresh Claude Code session loads the plugin instance the harness resolved — for a marketplace install that is the **cache** (`~/.claude/plugins/cache/mega-sdd/mega-sdd/<version>/`), rebuilt from the marketplace clone by `/plugin marketplace update`, **not** your dev checkout. Verified on this machine (2026-07-03): the dev checkout and the marketplace clone were byte-identical, but the cache topped out several versions behind dev HEAD. **Edit the dev file, load the cache, and the "baseline" arm still forks → baseline == fork → a phantom NO-WIN with no error.** This is exactly as silent as the SubagentStop footgun.

You do **not** have to reverse-engineer the loader to be safe, because a fork leaves a mechanical fingerprint: a fork's cost is a `subagent_end_marker` (`subagent_turns > 0`); an inline run has none (`subagent_turns == 0`). So the arm's `subagent_turns` tells you which instance actually ran:

| arm | must observe | if violated |
|---|---|---|
| baseline (fork stripped) | `subagent_turns == 0` (ran inline) | a fork ran → the loaded instance still has `context: fork` → you edited the wrong instance (likely the cache) |
| fork (main) | `subagent_turns > 0` (forked) | no fork ran → SubagentStop didn't fire (Precondition 1) **or** the loaded instance lacks the fork |

`measure-fork-ab.sh capture <arm>` enforces exactly this table and **refuses** (exit 2) on a violation, so you cannot record a phantom. If you strip the dev file but the harness loads the cache, `capture baseline` will refuse with a message naming the cache — the fix is to strip the fork on the instance that is actually loaded (or rebuild the cache from a fork-stripped build).

## Procedure (run on a real machine — fork needs live agent dispatch)

### Guarded fast path (recommended)

`measure-fork-ab.sh` wraps the two mandatory manual harness runs with the Precondition-1 and Precondition-2 guards and records the baseline confound as raw numbers. **"One command" is a mirage** — the two `/mega-sdd:detect-drift` runs are yours to drive by hand; the helper only brackets them so a footgun can't slip a phantom past you.

```bash
DRV=plugins/mega-sdd/scripts/measure-fork-ab.sh
# Baseline arm — on a throwaway branch with `context: fork` stripped from the LOADED instance:
rm -f .mega-sdd/memory/telemetry.jsonl && : > .mega-sdd/memory/telemetry.jsonl
#   … run /mega-sdd:detect-drift to completion on the drift scenario …
bash "$DRV" capture baseline --cwd="$PWD"      # refuses if it detects a fork (wrong instance)
# Fork arm — on main (fork present), same scenario reset to the identical pre-run state:
rm -f .mega-sdd/memory/telemetry.jsonl && : > .mega-sdd/memory/telemetry.jsonl
#   … run /mega-sdd:detect-drift to completion on the SAME drift scenario …
bash "$DRV" capture fork --cwd="$PWD"          # refuses if subagent_turns==0 (no fork captured)
bash "$DRV" compare --cwd="$PWD"               # WIN/NO-WIN + the confound line; writes .mega-sdd/.fork-ab/result.json
# housekeeping: `bash "$DRV" status --cwd="$PWD"` (progress) · `bash "$DRV" reset --cwd="$PWD"` (clean re-run)
```

`compare` always passes `--require-subagent` and prints the baseline confound (the inline arm's `cache_read` proxy) **un-judged** — the tool records the number, you judge whether the baseline was a representative mid-pipeline session (the baseline confound — the one open blocker, see "Why this is still pending"). Drop to the raw comparator (next) only if you deliberately need to bypass the arm-aware baseline guard.

### Raw comparator (what the driver wraps)

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

### Why this is still `_pending_` (ONE blocker remaining, as of 2026-06-29)

A faithful A/B was attempted in-session on 2026-06-27 and was blocked by two reasons. **One is now resolved:**

1. **Baseline confound — STILL OPEN (the gating blocker).** The no-fork arm runs detect-drift *inline*, inheriting the current session's full context. The session this was attempted in is ~1M+ tokens deep and unrepresentative, which would inflate the no-fork baseline by a large multiple and overstate the "win." A faithful baseline must come from a representative mid-pipeline session, not a long measurement/working session. This is a **methodology constraint, not a tooling gap** — it cannot be satisfied from a deep session no matter what; it needs a fresh, representative pipeline session on a real `mode=existing` vault + codebase.
2. ~~**SubagentStop did not fire.**~~ **RESOLVED 2026-06-29** (matcher fix `52c7fb4`, confirmed live — see the ✅ note in the Precondition section). The fork-cost-capture machinery is now proven end-to-end (`subagent_turns: 1`, marker emitted, comparator contract test green). The fork arm is capturable.

What is settled without the number:
- **Correctness gate: satisfied** — detect-drift is non-interactive, gates fire on the Skill call before the body forks, no `memory_context` dependence (`moat-token-tradeoff` memory; `research/2026-06-26-context-reset-fork-feasibility.md`).
- **Token sign: structurally ≥ 0** — saving = the inherited main-session context the inline run re-processes and the fork skips. Non-negative by construction for any non-trivial phase in a non-fresh session.
- **Token magnitude: OPEN and session-dependent** — saving ≈ inherited-context size × fork-turn-count × cache-read weight (0.1×). A large mid-pipeline context over ~45 fork turns can clear 50%+; a light session is marginal. It is **not** a fixed percentage and is unknowable from here — which is exactly why the gate requires a representative-session run. Do not pin a number, and do not pre-decide the gate either way.

> The extend-to-scan/bind decision is therefore **PENDING the live measurement**, per `plugins/mega-sdd/CLAUDE.md` ("re-evaluate … only after the live token before/after confirms the win"). Deciding it now on the structural argument alone would override a written measurement gate with prose — the enforcement-by-prose anti-pattern the doctrine forbids.
