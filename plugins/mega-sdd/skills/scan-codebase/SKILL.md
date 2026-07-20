---
name: scan-codebase
version: 2.18.2
description: Heuristic codebase scanner for brownfield SDD — produces codebase-map.md consumed by bind-codebase as ground truth. Triggers — "scan codebase", "map this repo", "siapkan context codebase", "init mega-sdd", or paraphrases.
---

# Scan-Codebase

Builds a structured map of an existing repository for use by the SDD binding gate.

**Announce at start:** "I'm using the scan-codebase skill to map the repository."

> **Instruction language:** this skill reasons in English. Detected symbols, paths, and line numbers are recorded verbatim from the codebase. Narrate (the announce, progress, summary) in **Indonesian + English technical terms by default**; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`). *(This skill is greenfield-reachable — direct invocation on a raw brownfield repo runs before any `.mega-sdd/` signal exists, so it carries the policy itself rather than relying on the anchor.)*

## When to use

- User runs `/mega-sdd:scan-codebase`
- `orchestrate-flow` detects a brownfield project + missing `codebase-map.md`
- **`orchestrate-flow` Mode A/B — starterkit detected:** scan runs FIRST in the pipeline (before generate-intent) so vault generation is pack-aware from the start
- User asks "siapkan context buat AI dev di repo ini" or paraphrases
- After significant code changes, to refresh a stale map — use `--changed-only` for an incremental merge-update (journal + git delta; the `/mega-sdd:sync` lane)

### Scan-first usage (FIRST phase in starterkit-first mode)

When invoked as the FIRST phase (`orchestrate-flow` decision matrix Mode A/B):
- Scaffold-only repos are OK — `codebase-map.md` will have minimal symbols but a POPULATED §7 Framework section (the critical output for downstream generate-intent).
- An empty `app/` directory does NOT halt the scan; framework detection comes from package manifests, not file content.
- Output is consumed by `generate-intent --scan=<codebase-map>` to inform vault sections with starterkit conventions (dual-citation format per `generate-intent/references/vault-contract.md`).

## Inputs

- Repo path (positional, default `./`)
- `--depth=N` (default 8)
- `--include=<glob>` (repeatable; default infers from package manager)
- `--exclude=<glob>` (repeatable; defaults cover dependency/build/cache/IDE noise across major ecosystems). User flags are **appended** to defaults (not replacing); use `--no-default-excludes` to opt out entirely.

The full default exclusion list, the override flags, and the anti-bias rationale for excluding SDD outputs live in **`references/exclusions.md`**. The complete flag catalog is in **`references/halts-flags-handoff.md`**. Incremental mode (`--changed-only` — re-extract only changed paths from the dirty journal ∪ git delta, merge into the prior map, consume the journal via rotate-and-delete, never truncate-in-place) is specified at the top of **`references/scan-procedure.md`**.

## Output

`codebase-map.md` written to `.mega-sdd/codebase/codebase-map.md` (canonical per `plugins/mega-sdd/references/paths.md`). Override via `--out=<path>`. Idempotent — overwrites prior map. Section schema (frontmatter + §1 structure, §2 public interfaces, §3 routes, §4 data models, §5 naming conventions, §6 pattern signatures, §7 framework) is defined in **`references/codebase-map-schema.md`**, and is the contract `bind-codebase` consumes.

## Procedure (compact skeleton)

Detailed per-step logic — including the tree-sitter multi-binary probe, the per-file invalidation gate, the regex/ripgrep extraction code blocks, the framework-detection table + pack-resolution YAML, and the routes/models/naming/pattern heuristics — is in **`references/scan-procedure.md`**. Tree-sitter query usage, precision tiers, and graceful regex fallback are in **`references/tree-sitter-integration.md`**.

0. **Engine detection.** Probe tree-sitter via TWO binary names (`command -v tree-sitter || command -v tree-sitter-cli`). Found → run the per-language grammar smoke test (binary presence ≠ working grammars), then `engine: tree-sitter` (precision_tier `ast`) with `grammars_used` = the languages that passed; all fail → downgrade to regex. Not found + `--engine=tree-sitter` → halt `dep_missing`. Not found + no flag → fall back to `engine: regex` (precision_tier `regex`) with a one-line chat warning. Override via `--engine=`.
1. **Detect repo root.** Walk up to `.git`; else treat CWD as root and warn.
2. **Detect package manager / language.** Probe `package.json` / `composer.json` / `Gemfile` / `Cargo.toml` / `go.mod` / `requirements.txt`|`pyproject.toml` / `pom.xml`|`build.gradle` (full per-ecosystem table: `references/scan-procedure.md §Step 2`). Multiple → record all.
3. **Detect test framework.** Grep `jest|vitest|playwright.config.*`, `phpunit.xml`/`pest.php`, `pytest.ini`/`tox.ini`, `Cargo.toml [dev-dependencies]`.
4. **Build tree (depth-limited).** Walk dirs up to `--depth`, respecting `--exclude` (defaults in `references/exclusions.md`).
5. **Extract public interfaces.** Run the per-file invalidation gate first (REUSE unchanged files under `--shallow-scan`). Then tree-sitter (`name.definition.*` → §2; `name.reference.*` not persisted — generate-units builds its own symbol graph from the same queries) when available, else regex/ripgrep per-language patterns. Languages without a `.scm` file fall back to regex (per-language graceful degradation).
6. **Extract routes.** Per-framework signatures covering EVERY framework in the Step 8.5 detection table (Express/Laravel/Rails/Django/Gin/Axum/Spring/…) — full table in `references/scan-procedure.md` Step 6.
7. **Extract data models.** Per-ORM signatures across all ecosystems (Prisma/Eloquent/ActiveRecord/Django ORM/GORM/Diesel/JPA/…) — full table in `references/scan-procedure.md` Step 7.
8. **Detect naming conventions.** Sample 20+ files/language: file case, symbol case, test-file suffix.
8.5. **Detect framework.** Parse manifest fingerprints (first-match-wins; specific starterkit packs precede generic packs); record `name/version/confidence/pack_path/detection_source` to §7. No match → `_universal` fallback pack.
9. **Detect pattern signatures.** Heuristic grep for auth (`middleware|jwt|session`), state management, error handling.
10. **Write `codebase-map.md`** per `references/codebase-map-schema.md`. Include all sections; mark empty ones "None detected" (never omit). Stamp `engine` + `precision_tier` + `last_scanned_commit` (git HEAD; staleness stamp for drift detection) in frontmatter. **Step 10a — secret-scan gate:** scan the assembled map content for credential patterns BEFORE writing; redact matches as `[REDACTED-SECRET]` + warn (per `references/scan-procedure.md` Step 10a).

### Step 10.5 — Deep-scan stage (DEFAULT-ON when framework detected)

After Step 10 populates §7 Framework, run the deep-scan stage automatically (opt-out: `--shallow-scan`). It produces `.mega-sdd/codebase/starterkit-context.yaml` (auth / authz / ui_ux / libs slices + a pack-driven `patterns:` block; plus a separate `reuse-index.yaml`). The stage is split hot/cold: **`references/deep-scan-gate.md`** (always load first — trigger check, per-slice cache check, concurrency guard, shared snapshot) and **`references/deep-scan-dispatch.md`** (load ONLY when the gate's cache check yields non-empty `stale_slices` — manifest pre-parse, parallel selective subagent dispatch, framework-agnostic deep-read, consolidation + the complete `starterkit-context.yaml` schema). Subagent prompt templates are in **`references/deep-scan-prompts.md`**.

- **Trigger:** framework confidence `high`/`medium` (the §7 string enum) → run; `low`/`fallback` → skip (override with `--force-deep`).
- **Cache:** per-slice signature diff; full hit short-circuits; `--no-cache` forces full re-dispatch.
- **Dispatch:** only stale slices, in a single parallel message (read-only subagents). Missing `lib-patterns/<framework>/` → generic extraction, no halt.
- **Failure:** one slice fails → `partial: true` + `partial_slices`; all fail → halt `deep_scan_subagent_all_failed` (preserve prior YAML).
- **Step 10.6 — Shared snapshot:** also write `.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json` so `bind-codebase` can cheaply attest map freshness — one sha compare, a freshness attestation NOT a parsing shortcut (per `references/deep-scan-gate.md`).

11. **Suggest next step (CWD-conditional, mirrors the handoff `next_action`):** a vault exists → `/mega-sdd:bind-codebase <vault-path>`; no vault yet (starterkit-first) → `/mega-sdd:generate-intent --scan=<map>`; sync lane (`--changed-only`, incremental merge ran) → `/mega-sdd:detect-drift --scope=@<vault>/.sync-changed-paths.txt` (the durable changed set — the forked detect-drift can't re-resolve it once the journal is consumed); sync lane on the step-2 full-scan fallback (no changed set to scope) → SKIP detect-drift, `/mega-sdd:bind-codebase <vault-path> --auto` (a FULL re-bind — a scope-less detect-drift self-classifies STANDALONE and null-terminates the Mode D chain before the re-bind; §3.8(b)(1)).

## Mandatory rails

- **Anti-hallucination.** No detection → write "None detected"; never invent. Cap symbol extraction at the first 200 per category (note truncation). Cite line numbers (`src/foo.ts:42`) so binding can verify. Deep-scan subagents are READ-ONLY, must emit `not_detected` rather than guess, and every field carries a `_source` citation — schema-validation drops slices that violate. Full rail list in `references/halts-flags-handoff.md`.
- **Exclude SDD outputs from the bulk walk.** `.mega-sdd/**` and legacy output paths are excluded by default — reading vault during scan creates confirmation bias. This is an anti-hallucination rail, not just noise-reduction. Reconciliation is `bind-codebase`'s job. Rationale + the two by-name targeted reads (`conventions.md`, `starterkit-context.yaml`) are in `references/exclusions.md`.
- **Halts.** `>100k files` → confirm (`--force-large`). `0 public interfaces` → warn (likely misconfig; offer re-run with different `--include`). `--engine=tree-sitter` with tree-sitter absent → halt `dep_missing` with install commands. Deep-scan soft halts (`deep_scan_subagent_failed`, `deep_scan_cache_corrupt`) auto-recover; `deep_scan_subagent_all_failed` always stops. Full YAML for each in `references/halts-flags-handoff.md`.
- **Idempotency.** Re-running overwrites the prior map; `--shallow-scan` reuses unchanged per-file §2 entries via sha256.

## Hand-off

On completion, announce: "Codebase map written to `<path>`." + the CWD-conditional next step (vault exists → `/mega-sdd:bind-codebase <vault>`; none yet → `/mega-sdd:generate-intent --scan=<map>`).

Under `--auto` (typically from `orchestrate-flow --deep` or `/mega-sdd`), emit a handoff YAML record per your local template — the record, the conditional `starterkit_context:` block, metrics, and the `halted` status conditions are in **`references/halts-flags-handoff.md`** (operative; `orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index).

## Memory layer

When memory is enabled (default; opt-out `--memory-off`), participates in the mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`: writes detected conventions to `.mega-sdd/memory/conventions.md` AFTER the map is written, and skips re-detection for conventions marked `status: established` (still re-verified each scan). Read/write tables + anti-halu rails are in **`references/halts-flags-handoff.md`**.

## Specialist references (load on demand)

- **`references/scan-procedure.md`** — full surface scan (Steps 0–10): engine multi-binary probe, per-file invalidation gate, tree-sitter + regex/ripgrep extraction code, routes/models/naming/pattern heuristics, framework-detection table + pack-resolution YAML.
- **`references/deep-scan-gate.md`** — deep-scan hot side (Steps 10.5.0, 10.5.1, 10.5.4, 10.6): trigger check, per-slice cache check, concurrency guard, shared snapshot. Always loaded when Step 10.5 runs.
- **`references/deep-scan-dispatch.md`** — deep-scan cold side (Steps 10.5.1.5 → 10.5.3): manifest pre-parse, parallel selective subagent dispatch, pack-driven deep-read of code patterns, consolidation + the complete `starterkit-context.yaml` schema. Load ONLY on non-empty `stale_slices`.
- **`references/deep-scan-prompts.md`** — the five deep-scan subagent prompt templates (auth / authz / ui-ux / libs / reuse), variable substitution, `<MANIFEST_FACTS>` injection, and cross-cutting anti-halu rails.
- **`references/codebase-map-schema.md`** — the full `codebase-map.md` output schema (frontmatter + §1–§7), how `bind-codebase` consumes it, and detection-precision caveats.
- **`references/tree-sitter-integration.md`** — tree-sitter detection, query-file schema, per-language coverage, precision tiers, `dep_missing` install guidance, and graceful regex fallback.
- **`references/exclusions.md`** — the default exclusion list (grouped by ecosystem), override flags, the by-name targeted reads, and the anti-bias rationale.
- **`references/halts-flags-handoff.md`** — anti-hallucination rails, all halt conditions + YAML, the full flag catalog, the `--auto` handoff YAML, and the memory layer.
- **`queries/`** — tree-sitter `tags-<lang>.scm` capture queries (9 languages: TS/JS/PHP/Python/Go/Rust/Ruby/Java/C#) consumed by Step 5; tested grammar versions in `queries/VERSIONS.md`.

## Related skills

Output `codebase-map.md` is consumed by `bind-codebase` (vault validation) and `generate-intent --scan=` (pack-aware vault generation in starterkit-first mode). Dual-citation convention + `vault.json` field rules: `../generate-intent/references/vault-contract.md`.
