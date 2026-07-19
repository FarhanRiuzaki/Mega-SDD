---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: <vault-path> [--refresh] [--max-complexity=small|medium] [--auto]
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:generate-units` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Invoke `mega-sdd:generate-units` via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: vault directory (REQUIRED) — contains `binding.md` + nested `bound/` after binding.
- Flags: --refresh (renumber IDs), --max-complexity, --auto.

Follow `skills/generate-units/SKILL.md` procedure. Output to `<vault>/units/` directory.

Hard rails:
- One unit = one PR-sized bolt (300 LOC max).
- Every unit cites vault source.
- Reject dependency cycles.
- target_files whitelist enforced downstream (prompt rule + review-panel scope check + the deterministic B3 whitelist observer at bolt stage).

On completion: suggest `/mega-sdd:execute-bolts --all`.
