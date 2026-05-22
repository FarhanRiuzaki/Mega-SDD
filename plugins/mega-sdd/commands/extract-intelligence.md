---
description: Extract tech-agnostic domain knowledge from a legacy codebase. Produces `.mega-sdd/knowledge-base/` (v3.4+ canonical) — multi-file knowledge base organized by business domain. v1.4+ Iter 22 emits mutability tier markers `[LOCKED]/[INTENT]/[ARTIFACT]` orthogonal to confidence markers. Output consumable by `generate-intent --kb=<path>` and `bind-codebase` as secondary ground truth.
argument-hint: <legacy-codebase-path> [--out=<path>] [--seed=<path>] [--max-parallel=N] [--auto]
---

Invoke the `mega-sdd:extract-intelligence` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: legacy codebase path. Required.
- Flags: `--out` (default `.mega-sdd/knowledge-base/` per `plugins/mega-sdd/references/paths.md`), `--seed` (forensic dump, optional), `--max-parallel` (default 5, hard cap 8), `--auto`.

Follow `skills/extract-intelligence/SKILL.md` procedure exactly. Output to `<out>/knowledge-base/` (default `.mega-sdd/knowledge-base/`); legacy `docs/knowledge-base/` only triggered when prior extraction artifacts already exist there.

Hard rails:
- 5 sequential waves, ≤5 parallel subagents per wave (hard cap 8).
- Every non-trivial claim carries TWO marker axes (Iter 22):
  - Confidence: `[VERIFIED] / [INFERRED] / [OPEN]`
  - Mutability: `[LOCKED] / [INTENT] / [ARTIFACT]` (default `[INTENT]` when uncertain)
- Every non-trivial claim has `file:line` citation in §11.
- Tech-agnostic vocabulary in domain files (language/DB names allowed only in `## 11. Source References` and `50-integrations/`).
- Quality gate grep checks between waves; halt on second gate failure.
- Wave 5 synthesis runs on main thread, not as subagent.
- Wave 5 produces `99-rebuild-architecture/data-mutation-policy.md` (v1.4+ Iter 22).
- README leads with `## Reengineering Opportunities` BEFORE `## Critical Findings` (v1.4+ Iter 22).
- No fabrication — ambiguous confidence → `[OPEN]`. Ambiguous mutability → `[INTENT]` default.

On completion, suggest `/mega-sdd:generate-intent --kb=<out>/knowledge-base/` to bootstrap a vault, OR direct read of `<out>/knowledge-base/README.md` for manual rebuild planning.
