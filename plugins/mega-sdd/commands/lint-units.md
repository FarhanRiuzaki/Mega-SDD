---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: "[vault-path] [--module=<id>] [--squad=<id>] [--strict] [--format=table|json]"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:lint-units` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Static lint of vault units. Read-only diagnostic; surfaces issues BEFORE bolts run so the user can fix vault/binding/units instead of debugging failed bolts.

User arguments: $ARGUMENTS

The unit-spec integrity checks that gate at edit time are owned by a single hook-wired validator: `plugins/mega-sdd/scripts/validate-unit-spec.sh`. This command **re-runs that validator** for a pre-bolt sweep and **adds** the cross-unit checks the validator does not perform (dependency/binding/module/squad resolution, codebase-map anchor verification, prose quality). It does NOT re-narrate the validator's checks — that would be the shadow-logic the audit removed.

## Procedure

### Step 1 — Resolve vault + load context

Probe canonical (`.mega-sdd/vaults/*/`) then legacy (`docs/mega-sdd/vaults/*/`); use the positional arg if given; halt if no vault found. Load, for the cross-unit checks below: `vault.json`, every `units/U-*.md`, `binding.md` (if present), `_meta/modules.yaml`, `_meta/squads.yaml`, the codebase map (probe both new + legacy paths), and `.memory/bolt-outcomes.json` (for context).

### Step 2 — Per-unit spec integrity (delegated to the validator)

For each unit file, run the hook-wired validator and fold its verdict into the report — do not duplicate its logic:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-unit-spec.sh" --cwd="$(pwd)" --file-path="<unit-file>"
```

It returns a JSON report (and writes `.mega-sdd/.unit-spec-state.json`), exit `0`=PASS / `1`=FAIL / `2`=error. It is the **single source of truth** for these checks (so lint-units and the PostToolUse hook never drift):

- required frontmatter (`id`/`unit_id`, `title`, `task_type`, `target_files`, `vault_source`/`vault_anchors`) — `unit_underspecified`;
- `## Anchors` present for `verify`/`extend`; `## Migration notes` present for `extend`;
- per-acceptance-criterion source grounding for `verify` + `grounding_confidence: HIGH` units — `verify_grounding_untrusted` (the A1 gate);
- `## Hard rules` v1-grammar parseability — `hard_rule_unparseable`;
- starterkit-derived rules carry a `Citation: starterkit-context` — `starterkit_rule_citation_missing`.

Surface any FAIL with the validator's evidence string. Under `--strict`, a FAIL is a halt-equivalent exit.

> **Legacy-layout limitation (be honest about it).** The validator only matches canonical `.mega-sdd/vaults/*/units/` and `*-bound/units/` paths — same scope as the PostToolUse hook it shares. On a **legacy** `docs/mega-sdd/vaults/*/units/` vault it no-ops (exit 0), so this Step 2 per-unit integrity sweep is **skipped** there (the Step 3 cross-unit checks below still run, since lint-units performs those itself). If a legacy vault is detected, say so and suggest `/mega-sdd:migrate-paths` to move it to the canonical layout for full per-unit coverage — never report a legacy vault as "0 integrity issues" when the checks did not run.

### Step 3 — Cross-unit + grounding checks (lint-units' own value-add)

These are NOT in the validator — run them here, per unit, from the loaded context. All are deterministic (field presence, ID resolution, file/line probe — never LLM judgment):

- **Dependency resolution** — every `depends_on` resolves to a real unit ID (no dangling); every `binding_refs` resolves to a claim in `binding.md`.
- **Module assignment** — `module:` present and resolves to `_meta/modules.yaml` (or `M-default`); flag `M-unassigned` for review.
- **Squad assignment** (only if `_meta/squads.yaml` declares ≥2 squads) — `squad:` present + resolves; any cross-squad `depends_on` is routed via `consumes_interfaces`.
- **Codebase-map anchor verification** — for each `## Anchors` `<file>:<line>`: file exists in the codebase map OR on disk; line in range. Missing file on `verify`/`extend` → WARNING (likely aspirational); on `create` → OK (greenfield); existing file + out-of-range line → WARNING (drifted).
- **Binding consistency** (when `binding.md` exists) — `task_type` matches the Implementation State Map (`IMPLEMENTED` at `confidence: high` → `verify`, not `create`; IMPLEMENTED at medium/low is treated as UNKNOWN per task-typing — do NOT flag its `create`/probe-derived type; `PARTIAL_FIELDS_* →` Migration notes match the `field_diff` ADD/KEEP/REMOVE).
- **Signature-rule anchoring** — a `SIGNATURE_RULE function <name>` references a symbol present in the codebase map (else `hard_rule_unanchored` warning).
- **Body/prose quality (SOFT)** — `## Goal`, `## Context (read first)` with a `vault_source` citation, `## Implementation steps` with directive prose, `## Anti-patterns`, `## Out of scope` present; `## Migration notes` ABSENT for `create`/`verify`.

### Step 4 — Summary metrics + recommendations

Aggregate: total units; by `task_type`; by `grounding_confidence` (HIGH/MEDIUM/LOW); anchors verified / total; units with ≥1 Hard Rule; module + squad coverage; cross-module `depends_on` edge count; average `target_files`/unit. Emit a per-unit table (`--format=table`, default) or structured JSON (`--format=json`), then **prioritized** recommendations that cite the specific unit + the specific check that failed (LOW grounding, missing anchors, bare Hard Rules, etc.).

`--module=<id>` / `--squad=<id>` scope the sweep; `--strict` promotes SOFT warnings to a halt-equivalent exit (CI mode).

### Step 5 — Optional markdownlint-cli2 prose pass

If `markdownlint-cli2` is available (`command -v markdownlint-cli2`), run a prose pass and fold its findings in as warnings (not halts); skip silently when absent:

```bash
markdownlint-cli2 '<vault>/*.md' '<vault>/units/*.md'
```

This relies on markdownlint-cli2's own config discovery (`.markdownlint-cli2.{jsonc,yaml}` / `.markdownlint.{jsonc,json,yaml}` at the repo root). mega-sdd-friendly overrides to put in that config: MD013 (line-length) off, MD041 (first-line-h1) off, MD033 (inline-HTML) off — vault files lead with frontmatter and use long citations + HTML-comment markers. Install: `plugins/mega-sdd/references/tooling-install.md`.

### Step 6 — Hand-off

- 0 LOW + 0 frontmatter issues → suggest `/mega-sdd:execute-bolts` or `/mega-sdd:list-modules` to start.
- LOW units exist → suggest reviewing those specific units before bolting, OR proceeding while accepting the risk.
- Validator FAILs / frontmatter issues → suggest `/mega-sdd:generate-units --refresh` to regenerate the problem units.

## Anti-halu rails

- Lint is READ-ONLY — never modifies vault, units, binding, or memory.
- The unit-spec integrity verdicts come from `validate-unit-spec.sh` (the same validator the PostToolUse hook runs) — lint-units does not reimplement them, so the two can never disagree.
- The cross-unit checks are DETERMINISTIC (field presence, ID resolution, file/line probe) — recommendations cite the specific unit + the specific check that failed, never a vague suggestion.

## Halt conditions

- Vault not found / `vault.json` corrupt → halt with a helpful error.
- `--strict` + any validator FAIL or SOFT warning → halt-equivalent exit (CI integration).

## References

- `plugins/mega-sdd/scripts/validate-unit-spec.sh` — the hook-wired unit-spec integrity validator (the overlap's single source of truth)
- `plugins/mega-sdd/skills/generate-units/references/unit-schema.md` — unit frontmatter + body schema
- `plugins/mega-sdd/skills/generate-units/references/defensive-generation.md` — grounding_confidence + anchor verification
- `plugins/mega-sdd/skills/generate-units/references/modules-schema.md` — module assignment
- `plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md` — binding state → task_type mapping
