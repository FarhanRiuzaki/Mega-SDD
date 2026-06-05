---
description: Inspect CWD and orchestrate a chain of mega-sdd sub-skills with single confirmation. Halt-pauses on blockers. `--deep` chains to pipeline-end; `--resume` continues a paused chain from CWD state.

> Iter 63 differentiation note (cross-ref below frontmatter): `/mega-sdd:orchestrate-flow` is the power-user front-door (assumes user knows what to chain); `/mega-sdd:auto` is the user-facing entry with input-shape detection. See cross-ref block in body.
argument-hint: [vault-path] [--from=<phase>] [--to=<phase>] [--dry-run] [--deep] [--resume] [--auto] [--memory-off] [--greenfield|--brownfield] [--converge|--no-converge] [--max-cycles=N] [--strict-quality] [--no-lint] [--no-analyze] [--no-modules-summary] [--no-agents-md] [--with-fsd] [--no-fsd] [--no-drift-check] [--no-enrich-staging]
---

> **`/mega-sdd:orchestrate-flow` vs `/mega-sdd:auto`** (Iter 63 clarification): both invoke the same orchestrate-flow skill. The difference:
> - **`/mega-sdd:orchestrate-flow`** (this command) — power-user lower-level chain executor. Skips input-shape detection. Use when you know exactly what skills to chain (custom composition, partial pipeline re-run, debugging).
> - **`/mega-sdd:auto`** — user-facing entry-point with input-shape detection + chain proposal + single confirm. **Typical users should start there.**
>
> Both accept same flags. Both invoke the same skill.

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
  - `--with-fsd` (v3.42.0+, Iter 63) — OPT-IN auto FSD generation at chain end (default: off since Iter 63; expensive pandoc/LaTeX). Legacy `--no-fsd` still accepted as no-op back-compat.
  - `--no-telemetry` (v3.44.0+, Iter 64) — suppress telemetry.jsonl writes for this chain. Persistent opt-out via `defaults.telemetry: false` in `<project>/.mega-sdd/config.yaml`.
  - `--plan` / `--act` / `--plan-then-act` (v3.46.0+, Iter 67) — Plan/Act mode override per CLAUDE.md §Plan/Act Mode. Default behavior is classifier-gated (PATCH=act / MINOR=act / MAJOR=plan-first).

Follow `skills/orchestrate-flow/SKILL.md` procedure. Default behavior: 3-sub-skill chain with single upfront confirmation. `--deep` lifts the cap and chains to pipeline-end; `--resume` continues from current CWD state.

Hard rails:
- No content generation by orchestrator itself
- No persisted state file (re-invoke OR `--resume` to continue; CWD probes rebuild cursor)
- No parallel sub-skills
- Substance prompts (real blockers) surface to human even under `--auto`; conventional prompts (CWD detection, defaults) suppressed
- Blocker artifacts pause chain; handoff YAML records halt reason + `next_action`
