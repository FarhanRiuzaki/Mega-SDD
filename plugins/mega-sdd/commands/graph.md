---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: "--impact <id|file[:line]> [--upstream|--downstream]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:graph` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Invoke the `mega-sdd:graph` skill via the Skill tool to query the project graph.

User arguments: $ARGUMENTS

Follow the skill exactly:
- The graph (`.mega-sdd/graph.json`) is derived and rebuilt lazily when stale — never authored.
- Run `scripts/query-graph.sh --root <project> --impact <target> [--upstream|--downstream]` and surface the output verbatim.
- Always surface the staleness banner if present and recommend `/mega-sdd:sync` when a binding is older than HEAD.
- Every reported edge cites its source artifact + field; never invent relationships.
