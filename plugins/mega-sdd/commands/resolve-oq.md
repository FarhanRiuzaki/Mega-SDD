---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: "[path/to/vault] [optional OQ tag like OQ-FLOWS-3]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:resolve-oq` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Invoke the `mega-sdd:resolve-oq` skill via the Skill tool to walk through unresolved Open Questions in a generated vault.

User arguments (vault path, specific OQ tag, priority filter): $ARGUMENTS

Follow the skill exactly:
- Read `00-index.md` OQ roll-up + `vault.json` to enumerate unresolved OQs.
- For each OQ, ask the user the question with concise context; capture the answer verbatim.
- Land the answer in the correct doc(s) — single landing for scoped OQs, cross-cutting landing pattern for OQs spanning multiple docs.
- Update `vault.json` resolved/unresolved counts and last_updated timestamps.
- Refuse to overwrite a LOCKED vault unless user explicitly confirms unlock.
