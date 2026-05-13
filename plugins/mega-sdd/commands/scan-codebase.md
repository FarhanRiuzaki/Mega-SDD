---
description: Scan an existing repository and produce a `codebase-map.md` for SDD binding. Brownfield prep for mega-sdd pipeline.
argument-hint: [repo-path] [--depth=N] [--include=<glob>] [--exclude=<glob>] [--auto]
---

Invoke the `mega-sdd:scan-codebase` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional (if not a flag): repo path. Default `./`.
- Flags: `--depth`, `--include`, `--exclude`, `--out`, `--auto`, `--force-large`.

Follow `skills/scan-codebase/SKILL.md` procedure exactly. Output to `<repo-root>/codebase-map.md` by default.

Hard rails:
- No invention — sections without detections are marked "None detected".
- Halt on >100k files unless `--force-large` set.
- Always cite line numbers for routes/models.

On completion, suggest `/mega-sdd:bind-codebase` as next step.
