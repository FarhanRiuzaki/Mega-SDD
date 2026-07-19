---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: "[path/to/old-vault] [path/to/new-prd]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:diff-vault` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Invoke the `mega-sdd:diff-vault` skill via the Skill tool to compare an existing vault against a revised PRD/BRD.

User arguments (old vault path, new PRD path, output report path): $ARGUMENTS

Follow the skill exactly:
- Load the existing vault and read the new PRD fully.
- Map differences across all 7 docs: added entities/flows/decisions, changed semantics, removed scope, new/closed Open Questions.
- Produce a `VAULT-DIFF.md` report grouped per doc with cited evidence from the new PRD.
- Never silently mutate the existing vault — diff is read-only by default.
