# Status line inside mega-sdd — feasibility research

**Date:** 2026-09-20 · **Asked by:** owner, after one day on a personal status line: *"bisa ga dibuat native di mega-sdd? jadi yg install mega-sdd punya config yg sama"*.
**Short answer:** not natively — Claude Code gives a plugin no way to provide the main status line. It can be delivered by an opt-in installer (the `install-front-door.sh` pattern). Whether it SHOULD be is an evidence question this doc cannot close from a desk; §5 lists what is missing.

## 1. What the platform allows

Source: Claude Code *Plugins reference* (code.claude.com/docs/en/plugins-reference), read 2026-09-19; cross-checked against the local CLI changelog for 2.1.278.

| Question | Fact |
|---|---|
| Can a plugin ship a `settings.json`? | Yes — but *"Only the `agent` and `subagentStatusLine` keys are supported"*. A `statusLine` key there is silently ignored. |
| Any other plugin-native route to the main status line? | No. Component types are skills/commands, agents, hooks, MCP, LSP, output styles, monitors, themes, workflows, `bin/`, channels — none of them is the status line. |
| Is `${CLAUDE_PLUGIN_ROOT}` usable in `statusLine.command`? | No. It is substituted in hook / MCP / LSP / monitor configs and skill + agent bodies only. |
| Is the plugin's on-disk path stable? | No — `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`; a new directory per version, old ones removed ~14 days later. |
| Does `bin/` help? | No — it extends the Bash tool's PATH only. |

So the status line has to live at a version-stable user-level path, and `statusLine` has to be written into the user's own `~/.claude/settings.json`. mega-sdd already does the first half of that for the bare `/mega-sdd` verb: `scripts/install-front-door.sh` (marker, idempotent, never overwrites a user-authored file), called from `hooks/session-start`.

The difference that matters: the wrapper drops ONE file nobody else owns. A status line edits a settings file every tool shares — exactly how GSD ended up owning the owner's `statusLine` for three months after he stopped using it (§3).

## 2. The payload (verified live, not only from docs)

Captured from a real session on 2.1.274 with a debug dump, then compared with the docs schema. Every field the reference status line uses was present: `model.display_name`, `effort.level`, `session_name`, `cost.{total_cost_usd,total_duration_ms,total_lines_added,total_lines_removed}`, `context_window.{used_percentage,remaining_percentage,context_window_size,current_usage.*}`, `rate_limits.{five_hour,seven_day}.{used_percentage,resets_at}`, `prompt_cache.{warm,hit_ratio}`, `pr`, `workspace.repo`.

Facts that shape the design:
- `resets_at` is Unix epoch **seconds**; `hit_ratio` is 0–1; PR state is `pr.review_state`.
- `rate_limits` exists **only for Pro/Max subscribers, or behind a Claude apps gateway that sets a spend limit** (`rate_limits.spend_limit`), and only after the first API response. Each window can be absent on its own.
- The status line's output is UI only — it never enters the model's context, so it costs 0 tokens.
- Claude Code passes `COLUMNS` / `LINES`; refresh is event-driven (new assistant message, `/compact`, mode change, a limit window's `resets_at`, cache expiry) plus an optional `refreshInterval`. Debounce 300 ms.

## 3. What one day of use already showed

| Observation | Measured |
|---|---|
| Render cost, macOS, node | ~90–135 ms wall per render (node startup dominates) |
| The previous status line's "current task" segment | dead for an unknown time: it read `~/.claude/todos/`, which no longer exists; tasks live in `~/.claude/tasks/<session>/<n>.json` |
| The previous status line used | none of `rate_limits`, `prompt_cache`, `effort`, `cost` |
| Cost of the tool that owned `statusLine` (GSD 1.42.3, unused: 0 real commands in 80 transcripts / 30 days) | ~0.6 s of hooks per Edit, ~0.12 s per Bash, 67 skills + 33 agents listed in every project |
| Assumptions in the new script that turned out wrong within the day | 2 (PR state field name; a bridge-file contract that only existed for a hook that was then removed) |

Two lessons: a status line silently rots when the platform moves (nobody noticed the dead segment), and whoever writes `statusLine` into user settings owns a footprint long after the user stops caring.

## 4. A segment only mega-sdd can provide

`scripts/derive-state.sh` already writes `<root>/.mega-sdd/state.json` (front door, GROUND, preflight all run it). It carries `derived.position` (15-value enum: `empty` … `units_pending_bolts` … `pipeline_complete`), and per vault `name`, `units_count`, `bolts_count`, `oq.pending_p0_p1` / `oq.deferred_p0_p1` (effectively open vs deferred **P1** — the OQ grammar has no P0, per the probe's own HONESTY NOTE) and `binding.conflicts_active` (vault-level only: on a layout-3 vault conflicts live per unit in `bolts/U-XXX/binding.json`, so this can read 0 while a unit gate is closed). A status line can READ that file — it must never run derive-state itself (a per-message python probe sweep would be the spawn tax the Windows work removed). The cost is one small JSON read; the price is staleness, which `generated_at` makes visible.

Context, limits and cost are generic — any status line can show them. Pipeline position is the part that is actually on-mission.

## 5. What is NOT known (and cannot be known from this machine)

1. **Do office sessions carry `rate_limits` at all?** They run through the office gateway. If it sets no spend limit, line 2 loses its most valuable segment for the whole team.
2. **Render cost under CrowdStrike EDR** (~220 ms per spawn measured for hooks). The status line spawns on every assistant message, plus every `refreshInterval`.
3. **python3 vs node startup on those laptops.** The contract refuses extra runtime dependencies, so the shipped script is python3 (resolved once via `scripts/_lib/resolve-python.sh` to dodge the WindowsApps stub) — its startup there is unmeasured.
4. **Whether the team has the pain.** Evidence today = the owner, one day. No teammate has reported losing track of limits, context, or pipeline position.

## 6. Classification (evidence-first rule, 2026-09-05)

**NICE.** Value medium · complexity low · token cost 0 · maintenance low-to-medium (payload drifts with Claude Code releases; shared settings file) · evidence strength weak (one user, one day). "Observability baru" sits on the standing DO-NOT list unless a field pain backs it. Recommendation: run the zero-plugin-change field trial in the spec's Phase 0, and let its gate — not this document — decide whether anything ships.
