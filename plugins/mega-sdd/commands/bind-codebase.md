---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: "<vault-path> [<codebase-map-path>] [--strict] [--auto] [--kb=<path>] [--no-kb] [--no-framework-pack] [--framework-pack=<path>] [--strict-constitution] [--no-advisor] [--memory-off] [--paths=<csv|@file>]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:bind-codebase` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Invoke `mega-sdd:bind-codebase` via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: vault directory path (REQUIRED).
- Second positional: codebase-map.md path (default probe: `.mega-sdd/codebase/codebase-map.md` → `<repo>/codebase-map.md` legacy).
- Flags:
  - `--strict` — block on OQ too, not just CONFLICT
  - `--auto` — skip confirmations
  - `--kb=<path>` — override KB auto-probe with explicit path
  - `--no-kb` — skip KB consultation entirely
  - `--no-framework-pack` — skip framework convention pack loading
  - `--framework-pack=<path>` — override built-in pack with project-specific file
  - `--strict-constitution` — halt on constitution-violating CONFLICTs (default: warn-only)
  - `--no-advisor` — skip the phase-advisor adversarial pass (default-on)
  - `--memory-off` — disable memory-layer reads and writes
  - `--paths=<csv|@file>` — claim-scoped re-bind (sync lane); active CONFLICTs always re-validated, never carried silently

Follow `skills/bind-codebase/SKILL.md` procedure exactly. Output to `<vault>/bound/` (nested, beside `units/` and `bolts/`) + `binding.md` at the vault root.

Hard rails:
- BLOCKING on conflict: never auto-resolve.
- Always human-in-the-loop for conflict decisions.
- Halt if codebase-map missing — instruct scan-codebase first.

On clean binding: suggest `/mega-sdd:generate-units`.
On blocked: suggest `/mega-sdd:resolve-oq --binding <binding.md>`.
