# Status line observability — design spec (proposed)

**Status:** PROPOSED 2026-09-20. Owner call "gas spec statusline" authorizes this spec and **Phase 0 only**. Phase 1 does not start until the Phase 0 gate (§3) passes and the owner answers §5. Source: `research/2026-09-20-statusline-native-feasibility.md`.

**Trigger:** the owner built a personal 2-line status line (context, 5h/7d limit meters with reset countdown, cost, prompt-cache health) and asked whether mega-sdd can ship it so every install gets the same view.

**Evidence-first classification:** NICE today — one user, one day. Token cost 0 (status line output never enters model context). It is promoted to SHOULD by the Phase 0 gate or it is parked; this spec does not pre-decide that.

Rules carried from the contract: no extra runtime dependency; the command surface stays three verbs + the maintenance one-timers; no hook, gate or validator is added, changed or read by this work; a skill behavior change ships with its trigger fixtures.

## 1. Why this is an installer, not a plugin component

A plugin's `settings.json` honors only `agent` and `subagentStatusLine`; `${CLAUDE_PLUGIN_ROOT}` is not available to `statusLine.command`; the plugin cache path changes per version (research §1). The only working shape is the one `scripts/install-front-door.sh` already uses: a marked copy at a version-stable user-level path.

One thing is NOT like the front-door wrapper: that script drops a file nobody else owns, so it may run at session start. A status line edits the settings file every tool shares. **It is therefore opt-in, human-confirmed every time, and never touched from `hooks/session-start`.**

## 2. Design

### 2.1 The script — `scripts/statusline.py`

One file, python3 stdlib only (the owner's node version, `~/.claude/statusline-pro.js`, 254 lines, is the reference; the port is mechanical). Reads the status-line JSON on stdin, prints at most two lines.

| Line | Segment | Source | When absent |
|---|---|---|---|
| 1 | model + effort | `model.display_name`, `effort.level` | model falls back to `Claude` |
| 1 | active task `done/total` | `~/.claude/tasks/<session_id>/*.json` (`status`, `activeForm`) | segment dropped |
| 1 | **pipeline** — position · vault · `C:n` active conflicts · `OQ:n` open blocking OQs · `u/b` units/bolts | `<project>/.mega-sdd/state.json`: `derived.position`, and on the primary vault `name`, `binding.conflicts_active`, `oq.pending_p0_p1`, `units_count`, `bolts_count` | segment dropped (no `.mega-sdd/state.json` = not an SDD project) |
| 1 | dir@branch | `workspace.current_dir`, `.git/HEAD` read directly (worktree pointer files followed) | branch dropped |
| 1 | PR / session name | `pr.number` + `pr.review_state`, `session_name` | dropped |
| 2 | context meter + tokens | `context_window.used_percentage`, `current_usage.*`, `context_window_size` | dropped |
| 2 | limit meters + `↻` countdown | every object under `rate_limits` that has `used_percentage` (`five_hour`, `seven_day`, `spend_limit`, and any window added later) | dropped — expected for gateway sessions without a spend limit |
| 2 | cost · wall time · lines | `cost.*` | dropped |
| 2 | cache hit % + `cold` | `prompt_cache.hit_ratio`, `.warm` | dropped |

Pipeline segment rules: the position is printed as the enum value with `_` → space — no invented labels, the vocabulary stays the one `state_probes.py` owns. The script **reads** `state.json` and never runs `derive-state.sh` (no per-message probe sweep). When `generated_at` is older than 10 minutes the segment renders dim with its age (`· 42m old`): stale is shown, not hidden. The exact key paths are pinned from `scripts/_lib/state_probes.py` at build time and covered by a fixture, so a producer-grammar change there trips a test (the 7.24.0 sweep rule).

Two honesty limits, both inherited from the probe and both stated in the README rather than papered over. `oq.pending_p0_p1` effectively counts open **P1**s — the OQ grammar has no P0 (the probe's own HONESTY NOTE) — so the label is `OQ:n`, never `P0`. And on a layout-3 (lite) vault conflicts are recorded **per unit** at dispatch (`bolts/U-XXX/binding.json`), so the vault-level `binding.conflicts_active` can read 0 while one unit's gate is closed. The segment prints what `state.json` carries and computes nothing: it is a position indicator, **not a gate readout** — the gate stays where the contract puts it, in the PreToolUse hook.

Hard rails, all testable: always exits 0 · 3 s stdin guard · no subprocess, no network, no file written (one exception: the debug dump below) · output fitted to `COLUMNS` by dropping the lowest-priority segment first · malformed or empty payload renders what it can or nothing — never a traceback.

Debug: `touch ~/.claude/mega-sdd-statusline.debug` makes each render dump its raw stdin to `~/.claude/mega-sdd-statusline.last-input.json`. This is how Phase 0 evidence is collected and how a payload change gets diagnosed.

### 2.2 The installer — `scripts/install-statusline.sh [--uninstall] [--force]`

1. Copy `statusline.py` → `~/.claude/mega-sdd-statusline.py`, carrying the marker `mega-sdd-statusline v1`.
2. Resolve the interpreter **once** via `scripts/_lib/resolve-python.sh` and bake its absolute path into the command (no per-render resolution; dodges the WindowsApps stub). If python later moves, the status line goes blank — fail-open — and re-running the installer fixes it.
3. Write `statusLine` (`type`, `command`, `refreshInterval` per §5 D3) into `~/.claude/settings.json`.

Ownership rails (mirroring `install-front-door.sh`, stricter where the file is shared):
- An existing `statusLine` whose command does not point at our marked file is **user-authored → never overwritten.** Print the snippet, explain in Indonesian what would change, stop. `--force` only after an `AskUserQuestion` whose options carry keterangan.
- `settings.json` is rewritten atomically (temp + rename) only after the result parses as JSON; a timestamped backup is taken first; a settings file that does not parse on the way IN aborts with nothing touched.
- Every key other than `statusLine` is byte-preserved in meaning (`jq -S` diff in the test).
- `--uninstall` removes our file and our `statusLine` block, and only ours.
- If the auto-mode classifier denies the settings write (seen on 2026-09-19 for hook removal, not for `statusLine`, but it is the same file): do not retry — print the command for the human to run with `!`.

Refresh on plugin update: `/mega-sdd:update-plugin` re-copies the script when our marker is present and older. Nothing is added to `hooks/session-start` — zero new spawns on the hot path.

### 2.3 The lane — `install-deps`, no new command

`skills/install-deps/SKILL.md` gains one **detect-and-offer** section, the same class as the Playwright browser item: deliberately no `tool-matrix.yaml` row, never auto-run, absence is always fine. Detect = is our marker present / is a foreign `statusLine` present. Offer = one line in the existing batch proposal. Triggers added to the description: "pasang statusline", "status line mega-sdd", "install status line". Body stays within the 500-line rule (currently 179).

## 3. Phase 0 — field evidence (zero plugin change)

Hand the existing node file + a 4-line settings snippet to 1–2 teammates on office laptops. That assumes node is on those machines (expected, for mega-code) — check first; if it is not, Phase 0 starts with a throwaway python3 port instead, which G2 needs measured anyway. Collect:

1. **One payload skeleton per environment.** Debug flag on, one prompt, flag off. Share it scrubbed — the dump carries cwd, transcript path, session id and the repo host: `jq 'del(.cwd, .transcript_path, .scratchpad_dir, .session_id, .session_name, .prompt_id, .workspace)'`.
2. **Render wall time on an office laptop**, node and python3, 20 runs each, median.
3. **A week of notes** — owner included: which segment changed a decision, which was noise, which was wrong.

**Gate — all three must hold:**

| # | Criterion | Fails → |
|---|---|---|
| G1 | ≥ 2 trial users still have it on after 7 days AND can name one decision it changed (stopped before a limit, compacted earlier, caught a cold cache, saw a CONFLICT count) | PARK — it stays the owner's personal file |
| G2 | median python3 render ≤ 300 ms on an office laptop | ship event-driven only (`refreshInterval` unset) and re-measure; still over → PARK |
| G3 | behind the office gateway, line 2 keeps ≥ 2 live segments | ship line 1 (pipeline segment) only, or PARK if G1's evidence was all about limits |

## 4. Phase 1 — build (after the gate)

| Path | Change |
|---|---|
| `plugins/mega-sdd/scripts/statusline.py` | new |
| `plugins/mega-sdd/scripts/install-statusline.sh` | new |
| `plugins/mega-sdd/skills/install-deps/SKILL.md` | + detect-and-offer section, description triggers, skill `version` bump |
| `plugins/mega-sdd/commands/update-plugin.md` | + refresh step |
| `tests/statusline/test-statusline-render.sh` | golden payloads: full · `{}` · non-JSON · gateway-shaped (no `rate_limits`) · `COLUMNS=70` · fresh / stale / missing / corrupt `state.json` · hostile `session_id` (`../`) |
| `tests/statusline/test-install-statusline.sh` | fresh settings · user-authored `statusLine` left alone · malformed settings untouched · idempotent re-run · `--uninstall` leaves foreign keys identical · Windows path forms proven with `ntpath` from macOS |
| `tests/skill-triggering/` | fixtures for the three new phrases |
| `README.md`, `CHANGELOG.md`, `plugin.json` + `marketplace.json` | 8.5.0 — additive, opt-in, minor |

Both local test trees and CI run before "green" is claimed. The office Windows field run is the owner's.

## 5. Owner decisions (needed before Phase 1, not before Phase 0)

- **D1 — home.** Core `install-deps` (**recommended**: reuses the "pasang tools" lane, no new surface) vs `mega-sdd-extras` (keeps core strictly on-mission, but breaks extras' zero-scripts property).
- **D2 — generic segments.** Ship context / limits / cost alongside the pipeline segment (**recommended** — team consistency was the ask), or ship the pipeline segment alone and leave the rest to each user.
- **D3 — `refreshInterval`.** 30 s on macOS; on Windows whatever G2's number supports, possibly unset.

## 6. Out of scope

- `subagentStatusLine` — the one key a plugin CAN ship; nobody has asked for agent-row detail. Parked.
- OpenTelemetry export, usage history, cost reports.
- Installing at session start, or replacing a user's own status line.
- Any change to a hook, gate, validator, or to what `derive-state.sh` computes.

## 7. Verification (Phase 1)

`bash tests/statusline/test-statusline-render.sh` · `bash tests/statusline/test-install-statusline.sh` · the skill-triggering suite · `pack-lint` untouched · one live install on the owner's machine (marker present, `jq .statusLine` points at the marked file, foreign keys identical to the backup) · one live `--uninstall` · office laptop run by the owner.
