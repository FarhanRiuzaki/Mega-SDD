---
description: Execute unit(s) to produce code commits via superpowers. TDD discipline, halt protocol, target-files whitelist enforced.
argument-hint: <unit-id | --all> [--parallel] [--worktree] [--max-retries=N] [--dry-run] [--force]
---

Invoke `mega-sdd:execute-bolts` via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: unit ID (U-XXX), unit file path, or `--all`.
- Flags per skill spec.

Follow `skills/execute-bolts/SKILL.md` procedure. Pre-flight checks MUST pass before any execution.

Hard rails:
- Superpowers detection per superpowers-bridge.md (real install > vendored > halt).
- target_files whitelist enforced — no out-of-bounds writes.
- No --no-verify on commits.
- Halt + blocker YAML on test failure after max retries.

On completion: suggest `/mega-sdd:detect-drift`.
