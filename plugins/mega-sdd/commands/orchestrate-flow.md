---
description: Inspect CWD and orchestrate a chain of mega-sdd sub-skills (max 3 per chain) with single confirmation. Halt-pauses on blockers.
argument-hint: [vault-path] [--from=<phase>] [--to=<phase>] [--dry-run]
---

Invoke `mega-sdd:orchestrate-flow` via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional (if not a flag): vault path or PRD path; otherwise auto-detect from CWD.
- Flags: --from, --to, --dry-run.

Follow `skills/orchestrate-flow/SKILL.md` procedure. Hard cap 3 sub-skills per chain.

Hard rails:
- No content generation by orchestrator itself
- No state file (re-invoke to resume)
- No parallel sub-skills
- All substance prompts surface to human
- Blocker artifacts pause chain
