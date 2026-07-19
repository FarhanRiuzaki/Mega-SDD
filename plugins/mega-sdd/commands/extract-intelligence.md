---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: <legacy-codebase-path> [--out=<path>] [--seed=<path>] [--max-parallel=N] [--auto]
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:extract-intelligence` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Invoke the `mega-sdd:extract-intelligence` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: legacy codebase path. Required.
- Flags: `--out` (OUTPUT_ROOT / parent dir; default `.mega-sdd/` per `plugins/mega-sdd/references/paths.md` — the KB lands at `<out>/knowledge-base/`), `--seed` (forensic dump, optional), `--max-parallel` (default 3, soft-warn >5, hard cap 8), `--auto`.

Follow `skills/extract-intelligence/SKILL.md` procedure exactly. Output to `<out>/knowledge-base/` (default `.mega-sdd/knowledge-base/`); legacy `docs/knowledge-base/` only triggered when prior extraction artifacts already exist there.

Hard rails:
- 6 sequential waves (Wave 0–5); parallel subagents per wave (soft warn above 5, hard cap 8).
- Every non-trivial claim carries TWO marker axes:
  - Confidence: `[VERIFIED] / [INFERRED] / [OPEN]`
  - Mutability: `[LOCKED] / [INTENT] / [ARTIFACT]` (default `[INTENT]` when uncertain)
- Every non-trivial claim has `file:line` citation in §11.
- Tech-agnostic vocabulary in domain files (language/DB names allowed only in `## 11. Source References` and `50-integrations/`).
- Quality gate grep checks between waves; halt on second gate failure.
- Wave 5 synthesis runs on main thread, not as subagent.
- Wave 5 produces `99-rebuild-architecture/data-mutation-policy.md`.
- README leads with `## Reengineering Opportunities` BEFORE `## Critical Findings`.
- No fabrication — ambiguous confidence → `[OPEN]`. Ambiguous mutability → `[INTENT]` default.

On completion, suggest `/mega-sdd:generate-intent --kb=<out>/knowledge-base/` to bootstrap a vault, OR direct read of `<out>/knowledge-base/README.md` for manual rebuild planning.
