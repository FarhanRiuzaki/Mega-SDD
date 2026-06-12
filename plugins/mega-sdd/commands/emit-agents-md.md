---
description: ADVANCED / AUTO-INVOKED — Flatten vault → AGENTS.md. Auto-invoked by `/mega-sdd:auto` at chain end (respects config flag default-on). Run standalone for one-off regeneration OR --mode=sibling when AGENTS.md already exists user-authored. Tool-agnostic interop — Continue.dev, Cursor, Aider, and other AGENTS.md-aware tools can consume mega-sdd's intelligence. Pure write-out; idempotent regeneration.
argument-hint: "[vault-path] [--out=<path>] [--mode=overwrite|append|sibling] [--auto]"
---

Invoke the `mega-sdd:emit-agents-md` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: vault path (default: detect in priority order — `.mega-sdd/vaults/*/vault.json` (canonical) → `docs/mega-sdd/vaults/*/vault.json` (legacy back-compat))
- `--out=<path>`: output file (default `<repo-root>/AGENTS.md`)
- `--mode=overwrite|append|sibling`: behavior when AGENTS.md already exists; default `sibling` (safest)
- `--include-section=<list>`: filter sections; default all
- `--auto`: skip confirmation prompts (e.g., when invoked by orchestrate-flow at chain end)

Follow `skills/emit-agents-md/SKILL.md` Procedure exactly. Per ITER6-OQ-4 resolved: config-flag default-on; users can disable per-project via `<project>/.mega-sdd/config.yaml` `defaults.emit_agents_md: false`.

Hard rails (anti-halu):
- AGENTS.md is a FLATTENED VIEW of vault. NEVER adds info not in vault.
- Generation marker (HTML comment) MANDATORY for safe re-generation detection
- Sections with no source content → OMITTED (not faked with placeholders)
- User-authored AGENTS.md preserved when `--mode=append`; mega-sdd appends below a clear marker
- `--mode=sibling` writes `AGENTS.mega-sdd.md` instead of overwriting (safe default when existing AGENTS.md detected)
- Existing AGENTS.md without mega-sdd marker → halt; ask user choice via AskUserQuestion

On completion, announce path + invites consumption by AGENTS.md-aware tools (Continue.dev, Cursor, Aider, etc.).
