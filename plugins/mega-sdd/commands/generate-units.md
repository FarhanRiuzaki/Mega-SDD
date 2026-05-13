---
description: Decompose a (bound-)vault into atomic AI-executable unit specs with dependency graph.
argument-hint: <vault-path> [--refresh] [--max-complexity=small|medium] [--auto]
---

Invoke `mega-sdd:generate-units` via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: vault or bound-vault directory (REQUIRED).
- Flags: --refresh (renumber IDs), --max-complexity, --auto.

Follow `skills/generate-units/SKILL.md` procedure. Output to `<vault>/units/` directory.

Hard rails:
- One unit = one PR-sized bolt (300 LOC max).
- Every unit cites vault source.
- Reject dependency cycles.
- target_files whitelist enforced downstream.

On completion: suggest `/mega-sdd:execute-bolts --all`.
