---
description: Inspect CWD and orchestrate a chain of mega-sdd sub-skills with single confirmation. Halt-pauses on blockers. `--deep` chains to pipeline-end; `--resume` continues a paused chain from CWD state.
argument-hint: [vault-path] [--from=<phase>] [--to=<phase>] [--dry-run] [--deep] [--resume] [--auto] [--memory-off] [--converge|--no-converge] [--max-cycles=N] [--strict-quality] [--no-lint] [--no-analyze] [--no-modules-summary] [--no-agents-md]
---

Invoke `mega-sdd:orchestrate-flow` via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional (if not a flag): vault path or PRD path; otherwise auto-detect from CWD.
- Flags:
  - `--from`, `--to` — pin chain entry/exit (override CWD-driven detection)
  - `--dry-run` — print proposed chain without executing
  - `--deep` (v2.3+, Iter 4) — lift the 3-sub-skill chain cap; chain auto-continues to pipeline-end via handoff YAML
  - `--resume` (v2.3+, Iter 4) — resume a paused/halted chain from CWD state (no persisted state file; CWD probes rebuild cursor)
  - `--auto` — non-interactive substance-prompt suppression; single upfront confirmation only
  - `--memory-off` (v1.4+) — disable memory layer entirely (no read, no write, no suggestion)
  - `--converge` / `--no-converge` (v2.3+, Iter 19) — opt in/out of auto-recovery loop on cycle-eligible halts (default: `--converge` under `--deep --auto`)
  - `--max-cycles=N` (v2.3+, Iter 19) — convergence loop iteration cap (default N=3)
  - `--strict-quality` — promote lint-units / analyze-parallelism warnings to halts
  - `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md` (v2.2+) — opt out of individual auto-invoked diagnostics

Follow `skills/orchestrate-flow/SKILL.md` procedure. Default behavior: 3-sub-skill chain with single upfront confirmation. `--deep` lifts the cap and chains to pipeline-end; `--resume` continues from current CWD state.

Hard rails:
- No content generation by orchestrator itself
- No persisted state file (re-invoke OR `--resume` to continue; CWD probes rebuild cursor)
- No parallel sub-skills
- Substance prompts (real blockers) surface to human even under `--auto`; conventional prompts (CWD detection, defaults) suppressed
- Blocker artifacts pause chain; handoff YAML records halt reason + `next_action`
