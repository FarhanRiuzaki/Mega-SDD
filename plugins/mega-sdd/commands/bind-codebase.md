---
description: Validate a vault against codebase-map.md (primary) + KB (secondary, v1.1+) + framework convention pack (v1.9+). Produces bound-vault/ + binding.md. BLOCKS unit generation on conflicts.
argument-hint: <vault-path> [<codebase-map-path>] [--strict] [--auto] [--kb=<path>] [--no-kb] [--no-framework-pack] [--framework-pack=<path>] [--strict-constitution]
---

Invoke `mega-sdd:bind-codebase` via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: vault directory path (REQUIRED).
- Second positional: codebase-map.md path (default probe: `.mega-sdd/codebase/codebase-map.md` (v3.4+) → `<repo>/codebase-map.md` legacy).
- Flags:
  - `--strict` — block on OQ too, not just CONFLICT
  - `--auto` — skip confirmations
  - `--kb=<path>` (v1.1+) — override KB auto-probe with explicit path
  - `--no-kb` (v1.1+) — skip KB consultation entirely
  - `--no-framework-pack` (v1.9+, Iter 23) — skip framework convention pack loading
  - `--framework-pack=<path>` (v1.9+, Iter 23) — override built-in pack with project-specific file
  - `--strict-constitution` (v1.8+, Iter 20) — halt on constitution-violating CONFLICTs (default: warn-only)

Follow `skills/bind-codebase/SKILL.md` procedure exactly. Output to `<vault>-bound/` (sibling) + `binding.md` at vault parent dir.

Hard rails:
- BLOCKING on conflict: never auto-resolve.
- Always human-in-the-loop for conflict decisions.
- Halt if codebase-map missing — instruct scan-codebase first.

On clean binding: suggest `/mega-sdd:generate-units`.
On blocked: suggest `/mega-sdd:resolve-oq --binding <binding.md>`.
