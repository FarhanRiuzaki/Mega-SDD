---
description: Extract tech-agnostic domain knowledge from a legacy codebase. Produces `docs/knowledge-base/` — multi-file knowledge base organized by business domain. Output consumable by `generate-intent --kb=<path>` and `bind-codebase` as secondary ground truth.
argument-hint: <legacy-codebase-path> [--out=<path>] [--seed=<path>] [--max-parallel=N] [--auto]
---

Invoke the `mega-sdd:extract-intelligence` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: legacy codebase path. Required.
- Flags: `--out` (default `docs/knowledge-base/`), `--seed` (forensic dump, optional), `--max-parallel` (default 5, hard cap 8), `--auto`.

Follow `skills/extract-intelligence/SKILL.md` procedure exactly. Output to `<out>/knowledge-base/` (under `<out>/`, default `docs/knowledge-base/`).

Hard rails:
- 5 sequential waves, ≤5 parallel subagents per wave (hard cap 8).
- Every non-trivial claim carries `[VERIFIED] / [INFERRED] / [OPEN]` marker + `file:line` citation.
- Tech-agnostic vocabulary in domain files (language/DB names allowed only in `## 11. Source References` and `50-integrations/`).
- Quality gate grep checks between waves; halt on second gate failure.
- Wave 5 synthesis runs on main thread, not as subagent.
- No fabrication — ambiguous → `[OPEN]`.

On completion, suggest `/mega-sdd:generate-intent --kb=<out>/knowledge-base/` to bootstrap a vault, OR direct read of `<out>/knowledge-base/README.md` for manual rebuild planning.
