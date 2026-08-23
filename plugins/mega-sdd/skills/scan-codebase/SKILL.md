---
name: scan-codebase
version: 2.31.0
description: Heuristic codebase scanner for brownfield SDD — produces codebase-map.md; runs ON-DEMAND or on the classic spine (the only codebase-map producer — emissions and the classic bind lane consume the map), not as a default-chain phase. Triggers — "scan codebase", "map this repo", "siapkan context codebase", "init mega-sdd", or paraphrases.
---

# Scan-Codebase

> **Non-interactive on every path (fork-ready).** This skill **NEVER calls `AskUserQuestion`** and never prompts — every input resolves deterministically from `$ARGUMENTS` or the CWD, and every former human-stop site now has a named deterministic outcome. **`--auto` is NOT semantically empty: it selects the CHAIN LANE.** It is one signal of an UNATTENDED invocation — alongside a forked body and an orchestrator-dispatched phase (`orchestrate-flow` / `/mega-sdd` / `/mega-sdd:sync`), which is how the chain actually arrives, since no routing row renders `--auto` on the *scan* hop. Unattended, nobody is watching, so the one gate with a cheaper-but-lossier path — Step 5's spawn budget — takes it and RECORDS it loudly instead of stopping. On a DIRECT user invocation carrying none of those signals the run is STANDALONE, a human is on the other end, and that gate hands the decision back as a named blocker. Every other outcome is lane-independent: an input that cannot be resolved emits a **named blocker** carrying its exact re-run command and stops — `scan_spawn_budget_exceeded`, `scan_repo_too_large`, `scan_primary_app_ambiguous`, `deep_scan_subagent_all_failed`, `codebase_map_derive_failed`, `codebase_map_invalid` (YAML in `references/halts-flags-handoff.md`) and `dep_missing` (YAML in `references/halts-flags-handoff.md`); the deriver's exit 3 is a recorded RECOVERY (re-run as FULL), not a halt. Never a prompt, never an UNRECORDED downgrade, never a wait. The handoff YAML is emitted on **every** invocation — chain and standalone alike — so the caller always receives `next_action` / `artifacts[]` / `blockers[]`. This contract is stated here in the body, not inherited: under `context: fork` the body IS the subagent prompt and the fork inherits the **user project's** `CLAUDE.md`, not the plugin's.

Builds a structured map of an existing repository for use by the SDD binding gate.

**Announce at start:** "I'm using the scan-codebase skill to map the repository. `mega-sdd-trace:scan-codebase`"

> **Instruction language:** this skill reasons in English. Detected symbols, paths, and line numbers are recorded verbatim from the codebase. Narrate (the announce, progress, summary) in **Indonesian + English technical terms by default**; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`). *(This skill is greenfield-reachable — direct invocation on a raw brownfield repo runs before any `.mega-sdd/` signal exists, so it carries the policy itself rather than relying on the anchor.)*

## When to use

- User runs `scan-codebase`
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

The full default exclusion list, the override flags, and the anti-bias rationale for excluding SDD outputs live in **`references/exclusions.md`**. The complete flag catalog is in **`references/halts-flags-handoff.md`**. Incremental mode (`--changed-only` — re-extract only changed paths from the dirty journal ∪ git delta, merge into the prior map, consume the journal via rotate-and-delete, never truncate-in-place) is specified at the top of **`references/scan-procedure.md`** — **on the sync hop, read §Incremental mode plus ONLY the full-scan steps it names for the changed slice (Step 0's engine probe, Steps 5–7 extraction logic, Step 8.5 on manifest change, Step 10's deriver delta contract); the rest of the full-scan procedure does not apply to the hop.**

## Output

`codebase-map.md` written to `.mega-sdd/codebase/codebase-map.md` (canonical per `plugins/mega-sdd/references/paths.md`). Override via `--out=<path>`. Idempotent — overwrites prior map. Section schema (frontmatter + §1 structure, §2 public interfaces, §3 routes, §4 data models, §5 naming conventions, §6 pattern signatures, §7 framework) is defined in **`references/codebase-map-schema.md`**, and is the contract `bind-codebase` consumes.

## Procedure (compact skeleton)

Detailed per-step logic — including the probe-scan-engine.sh engine digest, the per-file invalidation gate, the regex/ripgrep extraction code blocks, the framework-detection table + pack-resolution YAML, and the routes/models/naming/pattern heuristics — is in **`references/scan-procedure.md`**. (The tree-sitter opt-in lane + its integration reference were removed in v7.4.0 — the ladder is `ast-grep → regex`.)

0. **Engine detection.** Run `scripts/probe-scan-engine.sh` — ONE spawn resolves the D2 ladder (`ast-grep → regex`; the tree-sitter opt-in lane was removed in v7.4.0 — no grammar compile step exists, so the clang OOM class is structurally unreachable) and prints a JSON digest; consume the digest, never re-probe. ast-grep route → `precision_tier: ast`; regex → loud warning. A forced `--engine=` whose binary is absent → halt `dep_missing`. Details + digest schema: `references/scan-procedure.md` Step 0.
1. **Detect repo root.** Walk up to `.git`; else treat CWD as root and warn.
2. **Detect package manager / language.** Probe `package.json` / `composer.json` / `Gemfile` / `Cargo.toml` / `go.mod` / `requirements.txt`|`pyproject.toml` / `pom.xml`|`build.gradle` (full per-ecosystem table: `references/scan-procedure.md §Step 2`). Multiple → record all.
3. **Detect test framework.** Grep `jest|vitest|playwright.config.*`, `phpunit.xml`/`pest.php`, `pytest.ini`/`tox.ini`, `Cargo.toml [dev-dependencies]`.
4. **Build tree (depth-limited) + persist the enumeration.** Walk dirs up to `--depth`, respecting `--exclude` (defaults in `references/exclusions.md`). This is the ONLY full-tree pass: persist that same walk NUL-delimited to `.mega-sdd/codebase/.scan/files.z` (a deterministic path, NOT a `mktemp -d` — step invocations do not share shell state) so Step 5 reads it instead of re-walking (`references/scan-procedure.md §Step 4`).
5. **Extract public interfaces.** Fixed order — enumerate → invalidation gate → **spawn-cost gate** → extract (`references/scan-procedure.md §Order of operations`). The per-file invalidation gate (REUSE unchanged files under `--shallow-scan`) decides per FILE but hashes the whole enumeration in **ONE batched invocation** (`xargs -0` + one hasher process reading Step 4's persisted `.scan/files.z`, ~1 spawn) — a hasher spawn per file costs the same ~220 ms as any other spawn under Windows endpoint security, which makes an unbatched `--shallow-scan` net-negative. Then the spawn-cost gate: estimate `(N_hash + N_extract) x per_spawn` — the TOTAL bill, hashing included — before extracting; above 60 s the gate resolves **by lane, first match wins**, and the lane semantics — **(1) decided** (explicit `--engine=`/`--include=` = the caller's call) / **(2) undecided STANDALONE** → `scan_spawn_budget_exceeded` blocker + STOP / **(3) UNATTENDED** → downgrade to the highest OOM-safe tier and RECORD it loudly (`precision_downgrade_reason` stamp; `--auto` alone is never the discriminator — the test is unattended-ness; never ASK, never downgrade without the record) — are OWNED in full by `references/scan-procedure.md §Spawn-cost gate` (per-lane details, re-run commands, stamp fields): follow them THERE, never improvise from this summary. Then the ast-grep lane for every packed language (the primary; ONE spawn total), regex/ripgrep per-language patterns for the rest.
6. **Extract routes.** Per-framework signatures covering EVERY framework in the Step 8.5 detection table (Express/Laravel/Rails/Django/Gin/Axum/Spring/…) — full table in `references/scan-procedure.md` Step 6.
7. **Extract data models.** Per-ORM signatures across all ecosystems (Prisma/Eloquent/ActiveRecord/Django ORM/GORM/Diesel/JPA/…) — full table in `references/scan-procedure.md` Step 7.
8. **Detect naming conventions.** Sample 20+ files/language: file case, symbol case, test-file suffix.
8.5. **Detect framework.** Parse manifest fingerprints (first-match-wins; specific starterkit packs precede generic packs); record `name/version/confidence/pack_path/detection_source` to §7. No match → `_universal` fallback pack.
9. **Detect pattern signatures.** Heuristic grep for auth (`middleware|jwt|session`), state management, error handling.
10. **Write `codebase-map.md` via the deriver — never type the map.** Assemble the DELTA under `.mega-sdd/codebase/.scan/delta/` (`frontmatter.json` + `s2.rows`/`s2.files` + `s3.rows` + `s4.rows`/`s4.files` + `s5.md`/`s6.md`/`s7.md`; §2 rows WITHOUT the sha column — the script joins it), then **Run** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/derive-codebase-map.sh" --cwd=<root> --mode=full --delta=.mega-sdd/codebase/.scan/delta --plugin-root="${CLAUDE_PLUGIN_ROOT}"` (the incremental lane passes `--mode=merge` — delta carries ONLY what was re-extracted; carry-forward, vanished-row drops, and the schema shape are script-owned). The script renders §1 from `files.z`, stamps `generated_at`/`last_scanned_commit` itself (a failed or literal-`HEAD` stamp is omitted, never poisoned), **chains the Step-10a secret-scan gate** on the assembled temp + the post-write `validate-codebase-map.sh` refresh, and reports `secret_findings` on stdout — route any to `.mega-sdd/codebase/SECRET-FINDINGS.md` (durable rotation worklist — never the matched value) plus one chat warning (per `references/scan-procedure.md` Step 10a). Model-supplied frontmatter: languages/managers/tests/engine/precision fields incl. `precision_downgrade_reason` when the Step-5 `--auto` lane downgraded (the durable half of that record). Exit 3 = prior map unusable, re-run as FULL (on the sync lane this re-run takes the step-2 full-scan-fallback branch); exit 4 = the validator REJECTED the assembly — NOTHING renamed, prior map intact, rejected copy at `<out>.rejected`; route any `secret_findings` first, then halt and surface. Named blockers: `codebase_map_derive_failed` (exit 2) / `codebase_map_invalid` (exit 4) — YAML in `references/halts-flags-handoff.md`.

### Step 10.5 — Deep-scan stage (DEFAULT-ON when framework detected)

After Step 10 populates §7 Framework, run the deep-scan stage automatically (opt-out: `--shallow-scan`). It produces `.mega-sdd/codebase/starterkit-context.yaml` (auth / authz / ui_ux / libs slices + a pack-driven `patterns:` block; plus a separate `reuse-index.yaml`). The stage is split hot/cold: **`references/deep-scan-gate.md`** (always load first — trigger check, per-slice cache check, concurrency guard, shared snapshot) and **`references/deep-scan-dispatch.md`** (load ONLY when the gate's cache check yields non-empty `stale_slices` — manifest pre-parse, parallel selective subagent dispatch, framework-agnostic deep-read, consolidation + the complete `starterkit-context.yaml` schema). Subagent prompt templates are in **`references/deep-scan-prompts.md`**.

- **Trigger:** framework confidence `high`/`medium` (the §7 string enum) → run; `low`/`fallback` → skip (override with `--force-deep`).
- **Cache:** per-slice signature diff; full hit short-circuits; `--no-cache` forces full re-dispatch.
- **Dispatch:** only stale slices, in a single parallel message (read-only subagents). Missing `lib-patterns/<framework>/` → generic extraction, no halt.
- **Failure:** one slice fails → `partial: true` + `partial_slices`; all fail → halt `deep_scan_subagent_all_failed` (preserve prior YAML).
- **Step 10.6 — Shared snapshot:** also write `.mega-sdd/codebase/.shared-snapshots/codebase-map.snapshot.json` so `bind-codebase` can cheaply attest map freshness — one sha compare, a freshness attestation NOT a parsing shortcut (per `references/deep-scan-gate.md`).

11. **Suggest next step (CWD-conditional, mirrors the handoff `next_action`):** a vault exists → `bind-codebase <vault-path>`; no vault yet (starterkit-first) → `generate-intent --scan=<map>`; sync lane (`--changed-only`, incremental merge ran) → `detect-drift --scope=@<vault>/.sync-changed-paths.txt` (the durable changed set — the forked detect-drift can't re-resolve it once the journal is consumed); sync lane on the step-2 full-scan fallback OR the deriver's exit-3 `fallback_full` re-run (no changed set to scope — same branch) → SKIP detect-drift, `bind-codebase <vault-path> --auto` (a FULL re-bind — a scope-less detect-drift self-classifies STANDALONE and null-terminates the Mode D chain before the re-bind; §3.8(b)(1)).

## Mandatory rails

- **Anti-hallucination.** No detection → write "None detected"; never invent. Cap symbol extraction at the first 200 per category (note truncation). Cite line numbers (`src/foo.ts:42`) so binding can verify. Deep-scan subagents are READ-ONLY, must emit `not_detected` rather than guess, and every field carries a `_source` citation — schema-validation drops slices that violate. Full rail list in `references/halts-flags-handoff.md`.
- **Exclude SDD outputs from the bulk walk.** `.mega-sdd/**` and legacy output paths are excluded by default — reading vault during scan creates confirmation bias. This is an anti-hallucination rail, not just noise-reduction. Reconciliation is `bind-codebase`'s job. Rationale + the two by-name targeted reads (`conventions.md`, `starterkit-context.yaml`) are in `references/exclusions.md`.
- **Halts (all deterministic — a blocker, never a question).** `>100k files` without `--force-large` → emit `scan_repo_too_large` carrying the exact re-run command (`--force-large` to proceed, or `--include=<glob>` to narrow) and STOP. Estimated spawn bill > 60 s on an **undecided STANDALONE** invocation → `scan_spawn_budget_exceeded` (Step 5 gate); on any **UNATTENDED** invocation (`--auto`, forked, or orchestrator-dispatched) that same condition takes the RECORDED regex downgrade instead of halting — scan is phase 1 of nearly every brownfield chain and zero routing rows pre-resolve `--engine`/`--include` (or even render `--auto` on the scan hop), so a blocker there would halt the chain before anything is produced. A forced `--engine=ast-grep` with ast-grep absent → `dep_missing` with install commands. App-root manifests in multiple top-level dirs that the Step-2 precedence rule cannot resolve → `scan_primary_app_ambiguous`. **`0 public interfaces` is NOT a halt** — it is a completed scan of a repo that exposes nothing (or a misconfigured `--include`): record the suggested re-run command (`--include=<glob>`) in the scan summary **and** in the handoff, then complete; never wait for a reply. Deep-scan soft halts (`deep_scan_subagent_failed`, `deep_scan_cache_corrupt`) auto-recover; `deep_scan_subagent_all_failed` always stops. Full YAML for each in `references/halts-flags-handoff.md`.
- **Idempotency.** Re-running overwrites the prior map; `--shallow-scan` reuses unchanged per-file §2 entries via sha256 — computed in ONE batched hash pass over the enumeration, never one process per file.

## Hand-off

On completion, announce: "Codebase map written to `<path>`." + the CWD-conditional next step (vault exists → `bind-codebase <vault>`; none yet → `generate-intent --scan=<map>`).

Emit a handoff YAML record per your local template on **every** invocation — chain (`--auto`, typically from `orchestrate-flow --deep` or `/mega-sdd`) *and* standalone. It is NOT `--auto`-gated: a direct `scan-codebase` run never injects `--auto`, and the caller of a non-interactive skill has no other channel for `next_action` / `artifacts[]` / `blockers[]`. The record, the conditional `starterkit_context:` block, metrics, and the `halted` status conditions are in **`references/halts-flags-handoff.md`** (operative; `orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index).

## Specialist references (load on demand)

- **`references/scan-procedure.md`** — full surface scan (Steps 0–10): probe-scan-engine.sh engine digest, per-file invalidation gate, ast-grep + regex/ripgrep extraction code, routes/models/naming/pattern heuristics, framework-detection table + pack-resolution YAML.
- **`references/deep-scan-gate.md`** — deep-scan hot side (Steps 10.5.0, 10.5.1, 10.5.4, 10.6): trigger check, per-slice cache check, concurrency guard, shared snapshot. Always loaded when Step 10.5 runs.
- **`references/deep-scan-dispatch.md`** — deep-scan cold side (Steps 10.5.1.5 → 10.5.3): manifest pre-parse, parallel selective subagent dispatch, pack-driven deep-read of code patterns, consolidation + the complete `starterkit-context.yaml` schema. Load ONLY on non-empty `stale_slices`.
- **`references/deep-scan-prompts.md`** — the five deep-scan subagent prompt templates (auth / authz / ui-ux / libs / reuse), variable substitution, `<MANIFEST_FACTS>` injection, and cross-cutting anti-halu rails.
- **`references/codebase-map-schema.md`** — the full `codebase-map.md` output schema (frontmatter + §1–§7), how `bind-codebase` consumes it, and detection-precision caveats.
- **`references/exclusions.md`** — the default exclusion list (grouped by ecosystem), override flags, the by-name targeted reads, and the anti-bias rationale.
- **`references/halts-flags-handoff.md`** — anti-hallucination rails, all halt conditions + YAML, the full flag catalog, and the `--auto` handoff YAML.
- **`queries/`** — `astgrep/<lang>.yml` rule packs (20 languages — the tier-1 glossary Step 5 consumes; one pack per ast-grep language, `jsx` aliases to the javascript lane); registry + tested versions in `queries/VERSIONS.md`. (The tree-sitter `tags-*.scm` files died with the opt-in lane, v7.4.0.)

## Related skills

Output `codebase-map.md` is consumed by `bind-codebase` (vault validation) and `generate-intent --scan=` (pack-aware vault generation in starterkit-first mode). Dual-citation convention: `../generate-intent/references/vault-contract.md §Starterkit-binding`; `vault.json` field rules: `../generate-intent/references/vault-core.md §schema`.
