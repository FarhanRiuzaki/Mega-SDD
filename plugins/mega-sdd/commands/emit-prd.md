---
description: "DEPRECATED — folded into /mega-sdd:emit prd; alias resolves through 5.x"
argument-hint: "[vault-path] [--kb=<path>] [--mode=forward|reverse|auto] [--no-pdf] [--auto]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:emit-prd` sudah dilebur ke `/mega-sdd:emit prd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd:emit prd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Invoke the `mega-sdd:emit-prd` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: vault path (forward mode; default: detect per `plugins/mega-sdd/references/paths.md` priority order)
- `--kb=<path>`: reverse-mode KB root (default `.mega-sdd/knowledge-base` → legacy paths)
- `--mode=forward|reverse|auto`: default `auto` — vault present → forward; KB present + no vault → reverse
- `--no-pdf`: markdown-only output
- `--auto`: skip confirmation prompts + emit handoff YAML in chat

Follow `skills/emit-prd/SKILL.md` Procedure exactly.

Hard rails (anti-halu):
- MARKER PRESERVATION: `[VERIFIED]/[INFERRED]/[OPEN]` markers from KB claims ride VERBATIM into the PRD text; dropping or upgrading one is a deterministic halt (`scripts/check-prd-markers.sh` exit 1 → `quality_gate_failed:marker_stripped`).
- Every section traces to sources via `scripts/build-citation-map.sh --doc=prd`; missing source → `[Pending — X]` placeholder, never fabrication.
- User journeys are Mermaid; source diagrams carried verbatim, never redrawn.
- The PRD is an OUTPUT, never a decision surface — §6 Open Items is read-only; resolution runs via resolve-oq / generate-intent Q&A.
- Maturity: the model stamps only `draft-from-legacy`; `reviewed`/`final` are human-set.

On completion, announce the path to PRD.md (+ PDF/HTML when rendered) + summary: "PRD emitted (<mode>): N citations, V/I/O markers carried, K open items". Reverse lane continues via `/mega-sdd:generate-intent --kb=<kb>`.
