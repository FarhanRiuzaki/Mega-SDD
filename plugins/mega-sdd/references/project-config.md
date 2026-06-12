# Per-project configuration — `.mega-sdd/config.yaml`

One config surface per project (NOT `.claude/*.local.md` — mega-sdd predates that pattern and keeps a single file). Plain YAML at `<project-root>/.mega-sdd/config.yaml`. The file is OPTIONAL — every key has a default; hooks use the quick-exit pattern (absent file = all defaults).

```yaml
# All keys optional. Shown with defaults.
telemetry: true            # false → the PostToolUse hook exits entirely for this project
                           #   (no telemetry.jsonl, AND no validators/journal from that hook)
dirty_journal: true        # false → living-vault dirty-paths journaling off (git channel still works;
                           #   /mega-sdd:sync falls back to the last_scanned_commit diff alone)
staleness_notice: true     # false → suppress the session-start "codebase moved" line
layout: new                # new = canonical .mega-sdd/ layout (what /mega-sdd:migrate-paths writes);
                           #   legacy → outputs at pre-migration scattered paths (see plugins/mega-sdd/references/paths.md)
output_root: .mega-sdd/    # where all outputs live, relative to project root (or absolute)
```

Related-but-separate config surfaces (different scopes, documented where they live):

| Scope | File | Keys |
|---|---|---|
| USER (cross-project) | `~/.mega-sdd/memory/config.yaml` | `halt_auto_propose` block, model-tier overrides (`memory/references/memory-schema.md`) |
| PROJECT | `.mega-sdd/config.yaml` | this file |
| VAULT | `<vault>/vault.json` + `_meta/` | per-vault state, squads, modules |

## Headless / CI

- Always pass `--auto` (or use `/mega-sdd:auto` / `orchestrate-flow --auto`) — interactive steps otherwise emit `AskUserQuestion` and a headless run hangs. Every pipeline phase has an `--auto` path; decisions queue (PENDING-SYNC.md / OQ roll-up) instead of prompting.
- `claude -p --bare` SKIPS hooks entirely — the hook-enforced gates are invisible there. The deterministic gates also exist as `scripts/` (run `scripts/validate-handoff-binding-units.sh --cwd=. --quiet`; exit code gates your CI job) — scripts survive every runtime, per the plugin doctrine.
- Set `telemetry: false` here to silence diagnostics in CI checkouts.
- Full recipes (PR drift gate, sync-on-merge, pure-script gates): `plugins/mega-sdd/references/ci-recipe.md`.

## Rules

- **Defaults when absent** — a missing file or missing key NEVER errors; behavior is the documented default.
- **Validation** — unknown keys are ignored (forward-compat); a malformed YAML file is treated as absent (hooks fail-open to defaults, one debug-log line).
- **Restart required for hook-read keys** — `telemetry` / `dirty_journal` / `staleness_notice` are read by hooks at event time, so edits apply on the next tool event / session start (no full restart needed); skill-read keys apply on next skill invocation.
- **Git:** the file is safe to commit (team-shared posture) OR gitignore it for per-developer preferences — your call; it contains no secrets by design. Do NOT put credentials here.
