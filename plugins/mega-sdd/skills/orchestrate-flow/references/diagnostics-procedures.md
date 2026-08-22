# Chain diagnostics — operative procedures

The advisory diagnostics the chain auto-runs (classic spine; skipped lean/express — `chain-execution.md §Auto-integrated diagnostics`) and their on-demand form. Until 5.x these procedures lived in `commands/{lint-units,analyze-parallelism,list-modules,enrich-semantics}.md`; the surface cull relocated them here VERBATIM in contract — the typed `/mega-sdd:<name>` forms no longer resolve. On-demand invocation is by phrase through the front door (`/mega-sdd` → "lint units" / "cek parallelism" / "status module"); the orchestrator runs the matching procedure below.

All are ADVISORY diagnostics: read-only over the pipeline artifacts (the sole exception — `list-modules --mark-dod` mutates `modules.yaml` interactively — is called out in its section). None is a gate; none may block a chain.

## Contents

- [lint-units — pre-bolt static lint](#lint-units)
- [analyze-parallelism — DAG parallelism report](#analyze-parallelism)
- [list-modules — module progress + DoD](#list-modules)
- [enrich-semantics — REMOVED v7](#enrich-semantics)

## lint-units

Static lint of vault units. Read-only; surfaces issues BEFORE bolts run so the user fixes vault/binding/units instead of debugging failed bolts. The unit-spec integrity checks that gate at edit time are owned by a single hook-wired validator: `scripts/validate-unit-spec.sh`. This procedure **re-runs that validator** for a pre-bolt sweep and **adds** the cross-unit checks the validator does not perform — it never re-narrates the validator's checks (that shadow-logic was removed by audit).

Flags: `[vault-path] [--module=<id>] [--squad=<id>] [--changed-only] [--strict] [--format=table|json]`.

### Step 1 — Resolve vault + load context

Probe canonical (`.mega-sdd/vaults/*/`) then legacy (`docs/mega-sdd/vaults/*/`); use the positional arg if given; halt if no vault found. Load, for the cross-unit checks below: `vault.json`, every `units/U-*.md`, `binding.md` (if present), `_meta/modules.yaml`, `_meta/squads.yaml`, the codebase map (probe both new + legacy paths), and `.memory/bolt-outcomes.json` (for context).

### Step 1b — `--changed-only` scope-set (semantic scoping, spec 2026-08-03-semantic-scoped-validation.md)

Default is the FULL sweep — lint-units' stated purpose is the comprehensive pre-bolt pass. `--changed-only` scopes the **expensive legs** (Step 2 validator spawns, Step 3 per-unit checks, Step 4 per-unit narration, Step 5 markdownlint file list) to:

> **scope-set = changed ∪ dependents** — units whose current sha256 differs from (or is absent in) `unit_baseline` of `.mega-sdd/.analyze-freshness.json` (written by the analyze skill, the ledger's single writer — lint only READS it), **plus the transitive reverse-dependents** of those units (BFS over `depends_on` edges across ALL units' frontmatter — a changed unit can invalidate its dependents' interface assumptions).

Compute the current shas in ONE batch invocation (never per-file spawns): `Run: shasum -a 256 <all unit files>` (`sha256sum` where shasum is absent — the ledger records content sha256, NOT git blob shas, so `git hash-object` does not match), then compare against the `unit_baseline` keys (repo-relative paths).

Rails:
- **No ledger, unparseable ledger, or `unit_baseline` absent/empty** → run the FULL sweep and say so in one line: `--changed-only: no freshness ledger — full sweep (run analyze to establish one)`. Never silently lint nothing.
- **The cheap global checks still cover ALL units** — cross-unit dependency resolution, module/squad assignment, and dangling-`depends_on` detection read every unit's frontmatter regardless of scope (loading frontmatter is cheap; only validator spawns + narration scope down).
- **Never claim project-wide cleanliness from a scoped run**: the summary reports `N of M units linted (changed ∪ dependents)` and labels aggregate metrics as scoped.
- Combines with `--module=`/`--squad=` (intersection).

### Step 2 — Per-unit spec integrity (delegated to the validator)

For each unit file, run the hook-wired validator and fold its verdict into the report — do not duplicate its logic:

```bash
bash <plugin-root>/scripts/validate-unit-spec.sh --cwd="$(pwd)" --file-path="<unit-file>"
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

`--module=<id>` / `--squad=<id>` / `--changed-only` scope the sweep (Step 1b); `--strict` promotes SOFT warnings to a halt-equivalent exit (CI mode).

### Step 5 — Optional markdownlint-cli2 prose pass

If `markdownlint-cli2` is available (`command -v markdownlint-cli2`), run a prose pass and fold its findings in as warnings (not halts); skip silently when absent:

```bash
markdownlint-cli2 '<vault>/*.md' '<vault>/units/*.md'
```

Under `--changed-only`, replace the `'<vault>/units/*.md'` glob with the scope-set unit files explicitly (Step 1b) — the vault-doc glob stays.

This relies on markdownlint-cli2's own config discovery (`.markdownlint-cli2.{jsonc,yaml}` / `.markdownlint.{jsonc,json,yaml}` at the repo root). mega-sdd-friendly overrides: MD013 (line-length) off, MD041 (first-line-h1) off, MD033 (inline-HTML) off — vault files lead with frontmatter and use long citations + HTML-comment markers. Install: `plugins/mega-sdd/references/tooling-install.md`.

### Step 6 — Hand-off

- 0 LOW + 0 frontmatter issues → suggest `execute-bolts` or the list-modules diagnostic (below) to start.
- LOW units exist → suggest reviewing those specific units before bolting, OR proceeding while accepting the risk.
- Validator FAILs / frontmatter issues → suggest `generate-units --refresh` to regenerate the problem units.

### lint-units rails + halts

- Lint is READ-ONLY — never modifies vault, units, binding, or memory.
- The unit-spec integrity verdicts come from `validate-unit-spec.sh` (the same validator the PostToolUse hook runs) — lint-units does not reimplement them, so the two can never disagree.
- The cross-unit checks are DETERMINISTIC (field presence, ID resolution, file/line probe) — recommendations cite the specific unit + the specific check that failed, never a vague suggestion.
- Halts: vault not found / `vault.json` corrupt → halt with a helpful error; `--strict` + any validator FAIL or SOFT warning → halt-equivalent exit (CI integration).

## analyze-parallelism

Analyze the unit dependency graph for parallelism opportunities and bottlenecks. Read-only. The deterministic DAG math — depth, max width, topological waves, critical path, forks/joins, per-squad + per-module sub-DAGs, cross-module/squad edge counts, and the over-coupling **candidate** basis — is a single script: `scripts/analyze-parallelism.sh`. It reads each unit's frontmatter directly (it is NOT the canonical graph — `graph.json` is — it computes a different thing: topological layering, not blast-radius reachability). This procedure runs the script and turns its FACTS into the over-coupling and hand-off **suggestions** (human judgment the script never makes).

Flags: `[vault-path] [--per=squad|module|all] [--format=table|json|mermaid] [--module=<id>] [--squad=<id>] [--depth-only]`.

### Step 1 — Run the analysis

```bash
bash <plugin-root>/scripts/analyze-parallelism.sh <flags> --cwd="$(pwd)"
```

The script resolves the vault (positional `[vault-path]`, else auto-probe `.mega-sdd/vaults/` then legacy `docs/mega-sdd/vaults/`), parses the DAG, and emits the chosen `--format`:

- `table` (default) — Overall DAG (depth / max width / total waves), the topological waves, critical chain, forks, joins, cross-module/squad edge counts, wall-clock estimate + speedup, per-squad and per-module breakdowns, and the suspected over-coupling candidates.
- `json` — the same as a machine-parseable object (keys: `depth`, `max_width`, `total_waves`, `waves`, `critical_path`, `forks`, `joins`, `cross_module_edges`, `parallelism_speedup`, `per_squad`, `per_module`, `suspected_over_coupling`, `bottlenecks`, …).
- `mermaid` — `graph LR` with per-squad subgraphs to paste into mermaid.live / Obsidian.

Relay the script output to the user. If `--depth-only` was passed, the script emits depth + width only — STOP after relaying.

### Step 2 — Interpret over-coupling candidates (judgment)

The script lists each `depends_on` edge whose endpoints **share zero `target_files`** (and flags those that are also **cross-module**). These are deterministic *candidates*, never auto-removed. For each, add a review suggestion:

- **Zero target-files overlap** → "review: if U-X doesn't actually consume U-Y's output, removing the dep widens this wave by 1." (Optionally eyeball the unit bodies for a symbol reference the script can't see — that heuristic is yours, not the script's.)
- **Cross-module edge** → "this unit-level `depends_on` crosses a module boundary; prefer a module-level `blocked_by` declaration per `generate-units/references/modules-schema.md`."

The user always holds control — they remove a dep only if they confirm it's unnecessary.

### Step 3 — Hand-off (judgment, keyed on the script's numbers)

- `parallelism_speedup` ≥ 2 → suggest `execute-bolts --per-squad` when the vault declares ≥2 squads, else `execute-bolts --all --parallel` (`--per-squad` HALTS on a single-squad vault by procedure — never suggest the halting form).
- `parallelism_speedup` < 1.5 → suggest reviewing the over-coupling candidates above before executing.
- Bottlenecks present (high-fork keystone units on the critical path) → suggest scope-down OR explicitly accept the keystone.
- Always link the lint-units diagnostic (above) for a quality pass before execution.

### analyze-parallelism rails + halts

- The DAG math is **DETERMINISTIC** (graph algorithms on parsed frontmatter) — owned entirely by the script; this procedure does not re-derive any of it.
- Over-coupling is surfaced as **candidates on a deterministic basis only**: zero `target_files` overlap and/or a cross-module edge. The script does **not** scan unit bodies for symbol references — any "no symbol cross-reference" judgment is an optional human review step, never a computed claim.
- Suggestions are SUGGESTIONS — deps are **never** auto-removed; the user decides.
- The speedup estimate uses a simple "1 bolt = 1 min, unlimited parallel" model — an estimate, not a promise (the script labels it as such).
- Halts (the script's exit codes): vault not found / `vault.json` corrupt / DAG cycle (failed-safe here) → exit **1**, relay and stop; unknown flag / bad `--per` or `--format` / `--cwd` not a directory → exit **2** (usage), fix the invocation.

## list-modules

Display module progress + DoD status for the current vault. The read-only rollup — per-module unit completion (from `bolt-outcomes.json`), DoD marked-count, `blocked_by` resolution, and status label — is a single script: `scripts/list-modules.sh`. This procedure runs it for the display, and owns the **interactive `--mark-dod` flow** (which mutates `modules.yaml` and may re-run DoD test commands — neither belongs in the read-only script).

Flags: `[vault-path] [--module=<id>] [--mark-dod=<module>] [--format=table|json]`.

### Step 1 — Display the rollup

```bash
bash <plugin-root>/scripts/list-modules.sh <flags> --cwd="$(pwd)"
```

The script resolves the vault (positional `[vault-path]`, else auto-probe `.mega-sdd/vaults/` then legacy `docs/mega-sdd/vaults/`), reads `_meta/modules.yaml` (or `modules.yaml.auto`, or falls back to a single implicit `M-default`), and emits per module: ID, name, status (`not-started` / `in-progress` / `units-complete` / `completed`), units `completed/total`, DoD `done/total`, priority, and `blocked_by` resolution — plus an `M-unassigned` warning for units whose `module:` matches no defined module, and the deterministic `Unblocked & actionable:` set. `--format=json` emits the same structured. Relay the output.

> When `modules.yaml` is absent but `modules.yaml.auto` exists, suggest the user rename it to lock the grouping in (`mv _meta/modules.yaml.auto _meta/modules.yaml` — generate-units Step 4.5 auto-derivation produced it).

### Step 2 — `--mark-dod=<module-id>` interactive flow (this procedure's job)

The script's DoD column reflects the **marked** state only (a `dod:` item written as `[x] …` in `modules.yaml`). The fresh, canonical form is a plain string = unchecked. To mark items, run this flow (NOT the script — it mutates state and runs commands):

1. Read the module's `dod:` checklist from `_meta/modules.yaml` (halt with the valid module IDs if the id is unknown).
2. For each **unmarked** item, ask via `AskUserQuestion`: *"DoD item: `<text>` — mark passing?"* — options: (1) Mark passing, (2) Skip, (3) Run associated test command (when the item text looks like a command, e.g. `phpunit …`).
3. On **Run** → invoke the command via Bash; exit code is the verdict (deterministic pass/fail — never "looks done"). On success, mark passing.
4. On **Mark passing** → rewrite that `dod:` item in `modules.yaml` to `[x] <text>`; log the outcome to memory (`outcomes.md`).
5. After review, if **all** DoD items are marked AND all units are complete → the module is `completed`; congratulate and suggest the next module. (Re-run Step 1 to show the updated counts.)

### Step 3 — Hand-off (judgment, keyed on the script output)

- Some module is in the `Unblocked & actionable:` set → suggest a specific `execute-bolts --module=<id>`.
- All remaining modules are blocked → suggest the unblocking path (complete the blocking module / resolve an OQ).
- All modules complete → suggest `detect-drift` for periodic drift verification.

### list-modules rails + halts

- Module status is derived from **objective signals** — unit membership from each unit's `module:` frontmatter, completion from `<vault>/.memory/bolt-outcomes.json` (`status: completed` / `halted_*`), DoD marked-state from `modules.yaml` — **never inferred**.
- **DoD test commands are never auto-marked from the read-only display.** They are only re-run in the `--mark-dod` flow above, via Bash, where the exit code (not an LLM guess) decides pass/fail.
- `blocked_by` is resolved against each blocking module's computed status; a blocker is "ok" only when that module is itself `completed`.
- Halts: vault not found / `vault.json` corrupt → script exits **1**, relay and stop; `--module=<id>` / `--mark-dod=<id>` names an unknown module → halt with the list of valid module IDs (the script exits **2** on an unknown `--module`); a `--mark-dod` test command fails → do **not** auto-mark; the user resolves it manually.

## enrich-semantics

**REMOVED (v7 Fase 2).** The staged-input retrofit helper (`enrich-workflows-staging.sh`) is deleted; the `kb_flow_staging_missing` advisory remains (validate-kb-flows.sh) and the remediation is a scoped re-run of `extract-intelligence` on the affected domain, reviewed as usual. Historical procedure: git.
