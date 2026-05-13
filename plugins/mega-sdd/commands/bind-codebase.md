---
description: Validate a vault against the codebase map. Produces bound-vault/ + binding.md. BLOCKS unit generation on conflicts.
argument-hint: <vault-path> [<codebase-map-path>] [--strict] [--auto]
---

Invoke `mega-sdd:bind-codebase` via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: vault directory path (REQUIRED).
- Second positional: codebase-map.md path (default: <repo>/codebase-map.md).
- Flags: --strict (block on OQ too), --auto (skip confirmations).

Follow `skills/bind-codebase/SKILL.md` procedure exactly. Output to `<vault>-bound/` (sibling) + `binding.md` at vault parent dir.

Hard rails:
- BLOCKING on conflict: never auto-resolve.
- Always human-in-the-loop for conflict decisions.
- Halt if codebase-map missing — instruct scan-codebase first.

On clean binding: suggest `/mega-sdd:generate-units`.
On blocked: suggest `/mega-sdd:resolve-oq --binding <binding.md>`.
