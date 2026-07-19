---
description: "DEPRECATED — folded into /mega-sdd:emit sit; alias resolves through 5.x"
argument-hint: "[vault-path] [--vaults=<csv>] [--no-pdf] [--auto]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:emit-sit` sudah dilebur ke `/mega-sdd:emit sit` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd:emit sit`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Invoke the `mega-sdd:emit-sit` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: vault path (default: detect in priority order — `.mega-sdd/vaults/*/vault.json` (canonical) → `docs/mega-sdd/vaults/*/vault.json` (legacy back-compat))
- `--vaults=<comma-list>`: multi-scope merge — ONE SIT, per-scope sections, `TS-<SCOPE>-NNN` ids (decision 10)
- `--no-pdf`: markdown-only output (skips pandoc)
- `--auto`: skip confirmation prompts + emit handoff YAML in chat (orchestrator-invoked)

Follow `skills/emit-sit/SKILL.md` Procedure exactly.

Hard rails (anti-halu):
- §4 evidence tables are SCRIPT-DERIVED (`scripts/build-sit-evidence.sh` reading the hook-guarded B4/B1/B2 artifacts) and included VERBATIM — the model never authors an evidence cell; absent evidence = `[Pending — bolt U-XXX belum dieksekusi]`, counts never fabricated.
- TS scenarios carry the vault flow's Mermaid diagram VERBATIM — never redrawn.
- §5 sign-off body rows are placeholder LITERALS; a filled row = fabricated record → deterministic halt via `build-sit-evidence.sh --check-signoff`.
- Citations stamped by `scripts/build-citation-map.sh --doc=sit` from file bytes; the model writes only the literal `(sha256: pending)`.
- Maturity is the script's verdict (planned → partial → executed) — never model-claimed.

On completion, announce the path to `<vault>/sit/SIT.md` (+ PDF/HTML when rendered) + summary: "SIT emitted: N TS, M TC, maturity <verdict>, evidence E/U units". Sign-off dilakukan manusia di dokumen cetak.
