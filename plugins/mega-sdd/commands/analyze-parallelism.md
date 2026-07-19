---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: "[vault-path] [--per=squad|module|all] [--format=table|json|mermaid] [--module=<id>] [--squad=<id>] [--depth-only]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:analyze-parallelism` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Analyze the unit dependency graph for parallelism opportunities and bottlenecks. Read-only.

User arguments: $ARGUMENTS

The deterministic DAG math — depth, max width, topological waves, critical path, forks/joins, per-squad + per-module sub-DAGs, cross-module/squad edge counts, and the over-coupling **candidate** basis — is a single script: `plugins/mega-sdd/scripts/analyze-parallelism.sh`. It reads each unit's frontmatter directly (it is NOT the canonical graph — `graph.json` is — it computes a different thing: topological layering, not blast-radius reachability). This command runs the script and turns its FACTS into the over-coupling and hand-off **suggestions** (human judgment the script never makes).

## Procedure

### Step 1 — Run the analysis

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/analyze-parallelism.sh" $ARGUMENTS --cwd="$(pwd)"
```

The script resolves the vault (positional `[vault-path]`, else auto-probe `.mega-sdd/vaults/` then legacy `docs/mega-sdd/vaults/`), parses the DAG, and emits the chosen `--format`:

- `table` (default) — Overall DAG (depth / max width / total waves), the topological waves, critical chain, forks, joins, cross-module/squad edge counts, wall-clock estimate + speedup, per-squad and per-module breakdowns, and the suspected over-coupling candidates.
- `json` — the same as a machine-parseable object (keys: `depth`, `max_width`, `total_waves`, `waves`, `critical_path`, `forks`, `joins`, `cross_module_edges`, `parallelism_speedup`, `per_squad`, `per_module`, `suspected_over_coupling`, `bottlenecks`, …).
- `mermaid` — `graph LR` with per-squad subgraphs to paste into mermaid.live / Obsidian.

Relay the script output to the user. If `--depth-only` was passed, the script emits depth + width only — STOP after relaying.

### Step 2 — Interpret over-coupling candidates (judgment)

The script lists each `depends_on` edge whose endpoints **share zero `target_files`** (and flags those that are also **cross-module**). These are deterministic *candidates*, never auto-removed. For each, add a review suggestion:

- **Zero target-files overlap** → "review: if U-X doesn't actually consume U-Y's output, removing the dep widens this wave by 1." (Optionally eyeball the unit bodies for a symbol reference the script can't see — that heuristic is yours, not the script's.)
- **Cross-module edge** → "this unit-level `depends_on` crosses a module boundary; prefer a module-level `blocked_by` declaration per `modules-schema.md`."

The user always holds control — they remove a dep only if they confirm it's unnecessary.

### Step 3 — Hand-off (judgment, keyed on the script's numbers)

- `parallelism_speedup` ≥ 2 → suggest `/mega-sdd:execute-bolts --per-squad --parallel`.
- `parallelism_speedup` < 1.5 → suggest reviewing the over-coupling candidates above before executing.
- Bottlenecks present (high-fork keystone units on the critical path) → suggest scope-down OR explicitly accept the keystone.
- Always link `/mega-sdd:lint-units` for a quality pass before execution.

## Anti-halu rails

- The DAG math is **DETERMINISTIC** (graph algorithms on parsed frontmatter) — owned entirely by the script; this command does not re-derive any of it.
- Over-coupling is surfaced as **candidates on a deterministic basis only**: zero `target_files` overlap and/or a cross-module edge. The script does **not** scan unit bodies for symbol references — any "no symbol cross-reference" judgment is an optional human review step, never a computed claim.
- Suggestions are SUGGESTIONS — deps are **never** auto-removed; the user decides.
- The speedup estimate uses a simple "1 bolt = 1 min, unlimited parallel" model — an estimate, not a promise (the script labels it as such).

## Halt conditions (the script's exit codes)

- Vault not found / `vault.json` corrupt / DAG has a cycle (should have been caught by generate-units; failed-safe here) → script exits **1**; relay the error and stop.
- Unknown flag / bad `--per` or `--format` value / `--cwd` not a directory → script exits **2** (usage); fix the invocation.

## References

- `plugins/mega-sdd/scripts/analyze-parallelism.sh` — the deterministic DAG core (covered by `tests/parallelism/test-analyze-parallelism.sh`)
- `plugins/mega-sdd/skills/generate-units/references/modules-schema.md` — cross-module `blocked_by`
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — `--per-squad --parallel` execution
