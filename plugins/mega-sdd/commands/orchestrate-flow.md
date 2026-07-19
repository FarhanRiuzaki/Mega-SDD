---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: "[vault-path] [--from=<phase>] [--to=<phase>] [--dry-run] [--deep] [--resume] [--sync] [--auto] [--memory-off] [--greenfield|--brownfield] [--converge|--no-converge] [--max-cycles=N] [--strict-quality] [--no-lint] [--no-analyze] [--no-modules-summary] [--no-agents-md] [--with-fsd] [--no-fsd] [--no-drift-check] [--no-enrich-staging]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:orchestrate-flow` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

> **`/mega-sdd:orchestrate-flow` vs `/mega-sdd`** — both invoke the same orchestrate-flow skill. The difference:
> - **`/mega-sdd:orchestrate-flow`** (this alias) — power-user lower-level chain executor. Skips input-shape detection. Use when you know exactly what skills to chain (custom composition, partial pipeline re-run, debugging).
> - **`/mega-sdd`** (the front door) — user-facing entry-point with derive-state status view + input-shape detection + chain proposal + single confirm. **Typical users should start there.**
>
> Both accept same flags. Both invoke the same skill.

Invoke `mega-sdd:orchestrate-flow` via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional (if not a flag): vault path or PRD path; otherwise auto-detect from CWD.
- Flags:
  - `--from`, `--to` — pin chain entry/exit (override CWD-driven detection)
  - `--dry-run` — print proposed chain without executing
  - `--deep` — lift the 3-sub-skill chain cap; chain auto-continues to pipeline-end via handoff YAML
  - `--sync` — force the Mode D maintenance chain: incremental re-scan → drift → re-bind → unit reconcile (the `/mega-sdd:sync` front-door)
  - `--resume` — resume a paused/halted chain from CWD state (no persisted state file; CWD probes rebuild cursor)
  - `--auto` — non-interactive substance-prompt suppression; single upfront confirmation only
  - `--memory-off` — disable memory layer entirely (no read, no write, no suggestion)
  - `--converge` / `--no-converge` — opt in/out of auto-recovery loop on cycle-eligible halts (default: `--converge` under `--deep --auto`)
  - `--max-cycles=N` — convergence loop iteration cap (default N=3)
  - `--strict-quality` — promote lint-units / analyze-parallelism warnings to halts
  - `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md` — opt out of individual auto-invoked diagnostics
  - `--with-fsd` — OPT-IN auto FSD generation at chain end (default: off; expensive pandoc/LaTeX). Legacy `--no-fsd` still accepted as no-op back-compat.
  - `--no-telemetry` — suppress telemetry.jsonl writes for this chain. Persistent opt-out via `defaults.telemetry: false` in `<project>/.mega-sdd/config.yaml`.
  - `--plan` / `--act` / `--plan-then-act` — Plan/Act mode override per CLAUDE.md §Plan/Act Mode. Default behavior is classifier-gated (PATCH=act / MINOR=act / MAJOR=plan-first).

Follow `skills/orchestrate-flow/SKILL.md` procedure. Default behavior: 3-sub-skill chain with single upfront confirmation. `--deep` lifts the cap and chains to pipeline-end; `--resume` continues from current CWD state.

Hard rails:
- No content generation by orchestrator itself
- No persisted state file (re-invoke OR `--resume` to continue; CWD probes rebuild cursor)
- No parallel sub-skills
- Substance prompts (real blockers) surface to human even under `--auto`; conventional prompts (CWD detection, defaults) suppressed
- Blocker artifacts pause chain; handoff YAML records halt reason + `next_action`
