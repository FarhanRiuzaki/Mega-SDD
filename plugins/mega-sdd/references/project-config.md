# Per-project configuration — `.mega-sdd/config.yaml`

One config surface per project (NOT `.claude/*.local.md` — mega-sdd predates that pattern and keeps a single file). Plain YAML at `<project-root>/.mega-sdd/config.yaml`. The file is OPTIONAL — every key has a default; hooks use the quick-exit pattern (absent file = all defaults).

```yaml
# All keys optional. Shown with defaults.
dirty_journal: true        # false → living-vault dirty-paths journaling off (git channel still works;
                           #   /mega-sdd:sync falls back to the last_scanned_commit diff alone)
staleness_notice: true     # false → session-start state block keeps only header + rule line; no "HEAD moved" prompt line
auto_verify_on_edit: false # true → editing a file listed in a unit's target_files (unit with an
                           # acceptance_test) makes the PostToolUse hook OFFER running that unit's
                           # acceptance (one line, never auto-run). Default false = zero extra cost.
layout: new                # new = canonical .mega-sdd/ layout (what /mega-sdd:migrate-paths writes);
                           #   legacy → outputs at pre-migration scattered paths (see plugins/mega-sdd/references/paths.md)
                           #   (reserved — written by migrate-paths' scaffold; no reader today: layout
                           #   selection is dual-layout probing in `_lib/vault_layouts.py`)
output_root: .mega-sdd/    # read by `extract-intelligence` only (extraction output root — census + module PRDs land at `<root>/knowledge-base/`); hooks and scripts
                           #   hard-code `.mega-sdd/`
knowledge_base: ""         # ABSENT = probe the in-project KB paths (.mega-sdd/knowledge-base/ → docs/knowledge-base/ →
                           #   docs/mega-sdd/knowledge-base/ → old-reference/knowledge-base/). Set to a KB DIRECTORY
                           #   (the one holding README.md) when the KB lives outside the tree — a monorepo where FE and BE
                           #   apps share one KB submodule: `../../knowledge/<repo>/.mega-sdd/knowledge-base/`. Relative to
                           #   the project root, absolute allowed, `~` expanded. Read by derive-state (probes.knowledge_base,
                           #   source: config) → routing + generate-intent auto-detect (`--kb=<this dir>`). A configured path
                           #   whose README.md is missing counts as ABSENT (+ a note) — it never falls through to a stale
                           #   local copy. analyze's kb_* validators stay project-local by design.
spine: express      # express (default) | classic; classic restores scan-first chains + the Stop-hook analyze aggregate
lane: standard      # standard (default) | lite. The DURABLE form of the front-door `--lite` flag (derived.lane):
                           #   lite = execute-bolts pre-flight 3.9 JIT bind on EVERY wave + W1 zero-idle + `validate-preflight.sh
                           #   --predictive` refuses the execute-bolts hop while .plan-coverage-state.json is missing/FAIL.
                           #   Set it once per project so `--resume` and every hop know the lane without re-typing the flag.
# profile:          # ABSENT is the default: diagnostics lean-by-default on the express spine (Stop-hook analyze aggregate OFF). Set `full` to re-enable the aggregate; `lean` additionally cuts the advisory chain diagnostics (opt-in)
review_panel: auto         # execute-bolts review-panel tier: auto (risk-based) | minimal | standard | full
                           #   (see execute-bolts references/review-panel.md; CLI --review-panel= overrides this key)
model_tiers:
  bolt_implementer: inherit  # per-unit model routing: inherit (DEFAULT — today's behavior,
                             # session model, no model param passed) | auto (router: the same
                             # resolve-review-tier signals pick haiku/sonnet/opus per unit +
                             # one-step failure cascade) | haiku | sonnet | opus (hard pin)
parallel_max: 4              # execute-bolts in-flight implementer cap (Claude Code's own default is 20
                             # concurrent subagents — one bolt-implementer is ~80 turns; 4 keeps
                             # a fleet Windows laptop responsive). SCRIPT-READ, not
                             # prose-only — `_lib/vault_layouts.parallel_max()` (top-level key, first
                             # match, absent/non-integer → 4) feeds the in-run dispatch gate
                             # (hooks/pre-tool-use): on the lite lane a unit whose postflight +
                             # acceptance passed but whose panel has not merged yet is "panel-pending",
                             # and the gate lets the next dispatch through only while ≤ parallel_max
                             # such units exist (execute-bolts references/batch-and-fanout.md).
max_retries: 3             # execute-bolts re-dispatch budget per unit (an explicit `--max-retries=N` wins;
                           # lane lite + unit_tier xs is always 1). SCRIPT-READ + HOOK-ENFORCED:
                           # `_lib/vault_layouts.retry_budget()` → `review-tier.json` `retry_budget`; the
                           # PreToolUse gate denies the bolt-implementer dispatch past 1 + retry_budget.
code_gates: true           # false → skip the L0 toolchain + SAST gates (execute-bolts references/code-gates.md).
                           #   The secret scan and new-dep existence check ALWAYS run — no key disables them.
gateguard: true            # false → disable the LOCKED-file deny-once investigation gate (PreToolUse
                           #   Edit/Write; inert anyway when no [LOCKED] anchors exist in any vault)
preview_url: ""            # dev-server base URL (e.g. http://localhost:5173) — read by
                           #   `scripts/uat-run.sh` (UAT e2e); the execute-bolts controller passes
                           #   the URL into the capture ladder as an argument — `capture-views.sh`
                           #   never reads config. Empty → design lens is code-only.
# render_html: on          # ABSENT = on: every emit lane (prd/fsd/sit/uat + vault/KB renders) also writes the
                           #   self-contained offline HTML beside the md. `off` skips the render step.
# unit_granularity: fine   # ABSENT = default (medium) unit size in generate-units; `coarse` = story-sized units
                           #   (600 LOC / 8 files — same as `--max-complexity=large`), `fine` = smaller.
                           #   Precedence: flag > config > default.
defaults:
  emit_agents_md: true       # false → the chain's final `emit-agents-md` hop is skipped (written by
                             #   migrate-paths' scaffold; read by the emit-agents-md skill body — prose-read, no script)
```

Related-but-separate config surfaces (different scopes, documented where they live):

| Scope | File | Keys |
|---|---|---|
| USER (cross-project) | `~/.mega-sdd/config.yaml` | `halt_auto_propose` block (see `execute-bolts/references/halt-recovery.md §Configuration override`). Relocated from `~/.mega-sdd/memory/config.yaml` (memory dir removed) — move the file if you had one |
| PROJECT | `.mega-sdd/config.yaml` | this file |
| VAULT | `<vault>/vault.json` + `_meta/` | per-vault state, squads, modules |

## Headless / CI

- Always pass `--auto` (or use `/mega-sdd` / `orchestrate-flow --auto`) — interactive steps otherwise emit `AskUserQuestion` and a headless run hangs. Every pipeline phase has an `--auto` path; decisions queue (PENDING-SYNC.md / OQ roll-up) instead of prompting.
- `claude -p --bare` SKIPS hooks entirely — the hook-enforced gates are invisible there. The deterministic gates also exist as `scripts/` (run `scripts/validate-handoff-binding-units.sh --cwd=. --quiet`; exit code gates your CI job) — scripts survive every runtime, per the plugin doctrine.
- Full recipes (PR drift gate, sync-on-merge, pure-script gates): `plugins/mega-sdd/references/ci-recipe.md`.

## Rules

- **Defaults when absent** — a missing file or missing key NEVER errors; behavior is the documented default.
- **Validation** — unknown keys are ignored (forward-compat); a malformed YAML file is treated as absent (hooks fail-open to defaults, one debug-log line).
- **Restart required for hook-read keys** — the hook-read keys are `dirty_journal` (post-tool-use), `staleness_notice` (session-start), `gateguard` (pre-tool-use), `auto_verify_on_edit` (post-tool-use), and `spine` / `profile` (stop); all are read at event time, so edits apply on the next tool event / session start (no full restart needed); skill-read keys apply on next skill invocation.
- `halt_auto_propose` exists as a USER-scope key in `~/.mega-sdd/config.yaml` — shape and semantics in `execute-bolts/references/halt-recovery.md §Configuration override`.
- REQUIRED interpreter: `python3` — without a usable interpreter the PreToolUse gates fail CLOSED (see tooling-install.md).
- **Git:** the file is safe to commit (team-shared posture) OR gitignore it for per-developer preferences — your call; it contains no secrets by design. Do NOT put credentials here.
