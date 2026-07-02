---
description: Execute unit(s) to produce code commits via superpowers. TDD discipline, halt protocol, target-files whitelist honored (prompt-level rule + review-panel scope check).
argument-hint: "<unit-id | --all> [--parallel] [--worktree] [--max-retries=N] [--dry-run] [--force] [--auto] [--per-squad] [--squad=<id>] [--module=<id>] [--hard-rule-grammar=v1|v2] [--no-pbt] [--resume] [--rollback <unit-id>] [--memory-off] [--force-skip-postflight]"
---

Invoke `mega-sdd:execute-bolts` via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: unit ID (U-XXX), unit file path, or `--all`.
- Flags:
  - `--parallel` — execute eligible units concurrently (per dependency graph)
  - `--worktree` — isolate execution in git worktree
  - `--max-retries=N` — retry test-fail before halt (default N=3)
  - `--dry-run` — print plan without committing
  - `--force` — override pre-flight warnings (use sparingly)
  - `--auto` — non-interactive; suppress confirmation prompts (halts still emit blocker YAML)
  - `--per-squad` — execute one squad/module at a time; useful for multi-team coordination
  - `--squad=<id>` — execute only units in the named squad
  - `--module=<id>` — execute only units in the named module

Follow `skills/execute-bolts/SKILL.md` procedure. Pre-flight checks MUST pass before any execution.

Hard rails:
- Superpowers detection per superpowers-bridge.md (real install > vendored > halt).
- target_files whitelist honored — a prompt-level rule (rules tier) + review-panel scope check; no deterministic post-hoc observer yet.
- No --no-verify on commits.
- Halt + blocker YAML on test failure after max retries.

On completion: suggest `/mega-sdd:detect-drift`.
