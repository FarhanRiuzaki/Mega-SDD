---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: "[path/to/vault] [path/to/codebase]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:detect-drift` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Invoke the `mega-sdd:detect-drift` skill via the Skill tool to reconcile a vault against a live codebase.

User arguments (vault path, codebase root, scope filters): $ARGUMENTS

Follow the skill exactly:
- Read the vault (especially `03-data-model.md`, `02-architecture.md`, `vault.json`).
- Inspect the codebase for entities, fields, endpoints, and flows.
- Categorize drift: vault-only (documented but missing in code), code-only (implemented but undocumented), name/shape mismatches.
- For `IMPLEMENTATION_MODE=existing` vaults past `mode_migrate_after`, surface migration-readiness gaps separately.
- Produce `DRIFT-REPORT.md` with confidence-rated findings; never edit the vault or code automatically.
