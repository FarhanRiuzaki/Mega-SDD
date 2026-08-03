---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: "[input] [--deep|--shallow] [--greenfield] [--scope=<id>] [--step-after=<phase>] [--stop-after=<phase>] [--resume] [--manual] [--out=<path>] [--no-lint] [--no-analyze] [--no-modules-summary] [--no-agents-md] [--converge|--no-converge] [--max-cycles=N] [--with-fsd] [--no-telemetry] [--plan|--act|--plan-then-act]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:auto` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan mengikuti aturan render front door (mega-sdd.md §Flag handling): `--step-after`/`--stop-after` dirender ke `--to=`, `--manual` = tanpa `--auto`; sisanya diteruskan verbatim.

This alias IS the front door under its old name. Its brain (input-shape detection Mode A/B, adoption lane via `certify-artifact.sh`, starterkit detection, multi-scope picker, auto-integrated diagnostics, convergence loops, hard rails) moved verbatim to `plugins/mega-sdd/commands/mega-sdd.md` in 5.0.0.

**Read `plugins/mega-sdd/commands/mega-sdd.md` and follow it exactly** with these arguments — same behavior, same halts, same single upfront confirmation:

User arguments: $ARGUMENTS

In short (the contract lives in the front-door file; do not re-derive it here):
- No arg → `Run: scripts/derive-state.sh --cwd=<root>` → status view → propose the next chain → ONE confirmation → invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--deep --auto` (+ flags).
- Artifact arg → input-shape detection (PRD / legacy dir / vault / quoted brief / adoption lane) per the front-door rules, then the same orchestrate-flow dispatch.
- Every gated phase stays Skill-dispatched — never Agent-offloaded.
