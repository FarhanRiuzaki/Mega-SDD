---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: "[repo-path] [--depth=N] [--include=<glob>] [--exclude=<glob>] [--no-default-excludes] [--out=<path>] [--engine=tree-sitter|ast-grep|regex] [--changed-only] [--shallow-scan] [--force-deep] [--no-cache] [--memory-off] [--auto] [--force-large]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:scan-codebase` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Invoke the `mega-sdd:scan-codebase` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional (if not a flag): repo path. Default `./`.
- Flags: `--depth`, `--include`, `--exclude`, `--no-default-excludes`, `--out`, `--engine`, `--changed-only`, `--shallow-scan`, `--force-deep`, `--no-cache`, `--memory-off`, `--auto`, `--force-large` (full catalog in `skills/scan-codebase/references/halts-flags-handoff.md`).

Follow `skills/scan-codebase/SKILL.md` procedure exactly. Output to `.mega-sdd/codebase/codebase-map.md` by default.

Hard rails:
- No invention — sections without detections are marked "None detected".
- Halt on >100k files unless `--force-large` set.
- Always cite line numbers for routes/models.

On completion, suggest `/mega-sdd:bind-codebase` as next step.
