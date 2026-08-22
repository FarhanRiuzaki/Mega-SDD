---
name: detect-drift
version: 3.1.5
context: fork
description: Non-interactive drift diagnostic — compares a mode=existing vault against the live codebase; writes DRIFT-REPORT.md, queues direction calls to PENDING-SYNC.md (never prompts). Use when the user says "drift detect", "vault vs code", "check codebase against vault", "cek code vs vault", "is the code in sync?", or paraphrases.
---

# Drift Detect — vault vs live codebase reconciliation

> **Forked, non-interactive (token-reset pilot, `context: fork`).** This skill runs as a forked subagent with no conversation history, so it **NEVER calls `AskUserQuestion`** — the former `--auto` behavior is now the *only* behavior. It detects + reports + queues direction calls to `PENDING-SYNC.md`; a human resolves them later via `resolve-oq` / `sync`. Inputs are resolved deterministically from `$ARGUMENTS` (`--vault=…`, `--code=…`, `--scope=…`) or the CWD; if a required input can't be resolved it emits a blocker (it never asks). Standalone interactive resolution was removed — drift resolution lives in `resolve-oq`/`sync`.

For revamp / extension projects (`mode=existing`), the vault is the target spec and the live codebase is current reality. They drift apart silently: a field renamed in code but not the vault, a flow step that violates a vault decision, an endpoint shipped without an ADR. This skill scans the codebase, compares it to the vault, and produces a structured drift report. Findings are heuristic (high recall, decent precision) — the report is a **starting point for review, not a verdict**.

> **Instruction language:** this skill reasons in English. Drift findings (entity names, paths, line numbers) are recorded verbatim from the codebase; rationale prose follows the vault's language.

## When to use

Trigger when the vault is `mode=existing` and the user wants to confirm the code still matches it: "drift detect", "vault vs code", "check codebase against vault", "cek code vs vault", "is the code in sync?". Also useful before locking a milestone, after a long sprint, or when onboarding a dev who needs "what's actually true vs documented".

Do NOT use when: the vault is `mode=new` (no live code to drift against — bail to `diff-vault`); the user wants vault evolution from a new PRD (that's `diff-vault`); or the codebase isn't readable.

## Core principle

> **The vault is one ground truth. The code is another. When they disagree, surface it — don't pick a side.**

Drift means either *code is right, vault is stale* (update vault) or *vault is right, code regressed* (fix code in a PR). The skill never assumes which. Findings are **direction-neutral**: "vault says X, code does Y, here's where each lives" — the user and their team decide the action.

## Drift outcome categories

| Category | Meaning |
|---|---|
| **Missing in code** | Vault references an entity / flow / endpoint / decision with no analog in code. |
| **Missing in vault** | Code has an entity / flow / endpoint not documented in the vault. |
| **Name drift** | Same concept, different identifier (vault `failed_debit_count`, code `failed_attempts`). |
| **Type drift** | Same field name, different type / constraints (`int` vs `varchar`). |
| **Behavior drift** | Same flow ID, but code steps differ from the vault description. |
| **Decision violation** | Code violates a vault ADR (`D-XXX`). |
| **Decision unwritten** | Code embodies a decision not captured as an ADR. |
| **Confirmed match** | Vault says X, code does X. (Summarized, not detailed.) |

Each finding carries a **confidence**: `high` (exact name + type match / unambiguous absence), `medium` (similar names, different signatures), `low` (heuristic keyword guess — always verify manually).

Each finding also carries a **mutability-tier-aware severity**: **CRITICAL** (drift on a `kb_locked` regulatory/contractual claim — a compliance risk), **HIGH** (drift on a CONFIRMED claim, or a `kb_intent` claim whose outcome changed), **MEDIUM** (drift on `kb_intent` where implementation changed but outcome held), **LOW** (drift on `kb_artifact`, already flagged discardable). Vaults without `mutability_source` annotations → treat all drift as HIGH (safe default).

## Workflow

**Step 0 — Inputs (MANDATORY, deterministic — NEVER ask).** Resolve from `$ARGUMENTS` first, then fall back; a fork cannot `AskUserQuestion`, so an unresolvable input emits a blocker, never a prompt:
- **`VAULT_DIR`** ← `--vault=<path>` arg, else auto-detect the CWD directory holding the standard vault files (layout-2: `vault.md` set; legacy: `00-index.md` …). Verify the lock `implementation_mode: existing` (vault.md frontmatter; legacy: 00-index.md Vault Lock Status) — if `new`, STOP per the hard rule below. Unresolvable → emit `drift_inputs_missing` (vault).
- **`CODE_DIR`** ← `--code=<path>` arg, else the CWD **only if it is obviously a repo** (`.git` or a manifest present). Otherwise do NOT guess — emit `drift_inputs_missing` (code). (When the orchestrator forks this skill it resolves and passes `--code`/`--vault` on the main thread, so the never-guess branch is reached only on a misseeded standalone run.)
- **`SCOPE_DIRS`** ← `--scope=<dirs|@file>` arg — the sync lane (`orchestrate-flow --sync`) passes `--scope=@<vault>/.sync-changed-paths.txt` (the already-resolved changed set — written by scan-codebase `--changed-only` on map-bearing projects or `scripts/derive-changed-paths.sh` on express-born ones; one repo-relative path per line). An `@`-prefixed value is READ as a path-list file; a bare value is a dir CSV or a `scope_metadata` id. Else full scan. Do NOT try to re-resolve the changed set from the dirty journal ∪ git delta on the sync lane: by the time this forked skill runs, scan-codebase has already consumed the journal (rotate-and-delete) and advanced `last_scanned_commit` to HEAD, so both channels are empty AND re-reading would race a concurrent journal consume (`2026-06-10-living-vault-continuous-sync-design.md §3.2/§3.7`). The scope file is read ONLY when `--scope=@<path>` explicitly points at it — never auto-discovered from the vault, so a leftover file can't silently scope a standalone run.

Log the scope explicitly — `Scope hint received: <scope.id|changed-paths(N)>` or `Full scan (no scope hint)`. Persist `VAULT_DIR`, `CODE_DIR`, `SCOPE_DIRS`. Run `git status` — note uncommitted changes in the report (findings reflect the working tree). The `drift_inputs_missing` blocker shape is in `references/auto-and-chain.md`.

**Step 0.5 — Drift scope (MANDATORY).** `full` (default) | `schema-only` (entities + constraints) | `flows-only` (flows + endpoints + jobs) | `decisions-only` (ADRs vs code) | `single-doc`. Persist `DRIFT_SCOPE`.

**Step 1 — Read vault** (by scope): `schema-only`→`model.md`; `flows-only`→`flows.md`+`vault.md ## Architecture`; `decisions-only`→`vault.md ## Decisions`; `full`→every vault doc. Build an internal model: entities (with field signatures), flow IDs (with steps), endpoints, ADRs (with constraints).

**Step 1.5 — Framework detection.** REUSE FIRST: when `.mega-sdd/codebase/codebase-map.md` exists with a §7 Framework block at confidence ≥ medium AND its `last_scanned_commit` matches git HEAD, adopt that framework verbatim (log `Framework from codebase-map §7: <name> (<confidence>)`) — don't re-parse manifests the scan already parsed. Map absent/stale/low-confidence → detect from manifest: `composer.json`→PHP (Laravel/Symfony), `package.json`→Node (Next/Nest/Express), `Gemfile`→Ruby, `go.mod`→Go, `requirements.txt`/`pyproject.toml`→Python, `pom.xml`/`build.gradle`→Java/Spring, `Cargo.toml`→Rust, `pubspec.yaml`→Flutter. Use the detected framework's default scope dirs (no confirmation — forked / non-interactive). Ambiguous (monorepo / multi-framework) → emit the `drift_framework_mismatch` blocker (see `references/auto-and-chain.md`) rather than asking which subproject.

**Step 2 — Scan codebase** with `Bash`/`Glob`/`Read`: entities (migrations, models/ORM defs → name + fields + types); flows/endpoints (routes, jobs/cron, controllers); decisions (parse each `D-XXX` constraint, keyword-probe the code — lowest confidence axis); OQ references (`OQ-{CODE}-{N}` in code/commits cross-referenced against still-open vault OQs).

**Step 3 — Compute drift.** Per axis, compare vault model vs code model. Each finding: category, vault reference (doc + section + identifier), code reference (path + line range), confidence, severity, suggested action (informational only).

**Step 4 — Write `DRIFT-REPORT.md`** to `<VAULT_DIR>/` (overwrite). Full report structure, section ordering (Decision findings PRIORITY-1 at top), and per-finding format are in **`references/report-format.md`**.

**Step 5 — Queue direction calls to `PENDING-SYNC.md` (ALWAYS — non-interactive).** Every finding that needs a human direction call is queued to `<vault>/PENDING-SYNC.md` (prioritized digest; appended by category) and the run continues — there is **no walkthrough and no `AskUserQuestion`**. A human resolves the queue later via `resolve-oq` / `sync`. With `--auto-apply=safe` (opt-in, deterministic — no question): the narrow safe class (confidence HIGH + category ∈ name-drift/type-drift/missing-in-vault + claim NOT `[LOCKED]` + code side committed) goes straight to the Step 5.5 write-back — everything else queues. Code-side actions (`FIX_CODE`) are NEVER executed by this skill. Template in `references/report-format.md`.

**Step 5.5 — Vault write-back (`--auto-apply=safe` ONLY; living-vault S5).** Write-back is **non-interactive** — there is no batch-diff ACCEPT prompt (a fork can't confirm). ONLY the narrow `--auto-apply=safe` class from Step 5 is written back: for each, DRAFT the exact vault patch with git provenance (`git log -1 --format='%h %s — %an, %ad' -- <code anchor file>` cited inline) and apply it. Everything outside the safe class stays queued in `PENDING-SYNC.md` for `resolve-oq`/`sync` — never auto-applied. Full protocol (per-category patch shapes, provenance line, the rails) → `references/report-format.md §Vault write-back protocol`.

**Step 6 — Update vault metadata.** No write-back applied → append a Changelog entry to the vault Changelog (vault.md; legacy: 00-index.md) recording the drift *session* only (version unchanged, `vault.json` untouched). Write-back applied (`--auto-apply=safe`, Step 5.5) → append the Changelog entry listing each patched section + provenance, bump the vault version (small bump vX.Y+1 — grammar per diff-vault's `references/diff-procedure.md`), and refresh `vault.json` by running `bash <plugin>/scripts/derive-vault-json.sh --vault <vault-dir>` (script-held lock; exit 4 → `memory_in_use` halt). Boundary rules → `references/report-format.md §Vault write-back protocol`.

**Step 7 — Self-check:** `mode=existing` confirmed; framework detected and scope dirs documented; every finding has category + vault ref + code ref + confidence; no silent "confirmed match"; decision findings at top; **every finding is queued to `PENDING-SYNC.md` (or auto-applied via `--auto-apply=safe`); NO `AskUserQuestion` was used**; no code changes executed; `DRIFT-REPORT.md` + `PENDING-SYNC.md` written.

**Step 8 — Present summary:** total findings + breakdown by category/confidence; top 3 PRIORITY-1 findings (one line each); path to the report; suggested next step. No "I have completed the scan…" preamble.

## Hard rules (the rails)

- **`mode=new` → STOP.** Surface `mode_migrate_after` if present; tell the user to flip to `existing` (or run `diff-vault` for PRD-vs-PRD). This rule holds even under `--auto`.
- **No code execution.** The skill writes report files only — it never modifies code, opens PRs, runs migrations. (Vault-side write-back happens ONLY for the deterministic `--auto-apply=safe` class; everything else is queued, never applied.) If asked to apply code fixes, it does not — the action stays in `PENDING-SYNC.md` for human follow-up.
- **Non-interactive (forked, `context: fork`).** NEVER calls `AskUserQuestion`. Inputs resolve from `$ARGUMENTS`/CWD; an unresolvable required input emits a `drift_inputs_missing` blocker (never a prompt); direction calls queue to `PENDING-SYNC.md` for `resolve-oq`/`sync`. The standalone interactive walkthrough was removed in v3.0.0.
- **Direction-neutral framing.** Always present vault state and code state side-by-side; never declare one "wrong".
- **Confidence labels mandatory.** Low-confidence findings carry an explicit "verify manually" caveat.
- **No silent dismissal.** Confirmed matches are listed so reviewers know they were evaluated, not skipped.
- **Idempotency.** Re-running with no vault/code change regenerates an identical report.

## When to push back

**Always (as blockers / report notes — never prompts):** `mode=new` → STOP (`mode_migrate_after`); codebase path unresolvable → `drift_inputs_missing` (code); user asks the skill to apply code fixes → it doesn't (the action stays queued in `PENDING-SYNC.md`); major framework mismatch — vault implies one stack, manifest says another → emit `drift_framework_mismatch` (don't scan a possibly-wrong repo) rather than confirming.

**Conditional:** scope too large (>10k files) → recommend narrowing or per-subdirectory runs (warn that accuracy degrades, don't refuse); many low-confidence decision findings (>10) → recommend `decisions-only` with a narrower code scope; many unresolved OQs (>20 P1 open) → recommend `resolve-oq` first (drift against an unresolved vault is noisier).

## Limitations (be honest)

Heuristic detection, not static analysis — it greps and reads, no AST or type-checking, so false positives and negatives both happen. Semantic equivalence is hard (same concept, different name → flagged as Name drift for the user to confirm). Decision compliance is the lowest-confidence axis — treat violations as triggers for human review, not verdicts. Large monorepos degrade in time and accuracy — narrow scope. Not a replacement for code review or tests; it catches doc-vs-code divergence that neither typically checks.

## Specialist references (load on demand)

- **`references/report-format.md`** — the full `DRIFT-REPORT.md` template, section ordering, per-finding examples, the non-interactive vault write-back protocol, and the `vault.json` reconciliation boundary.
- **`references/constitution-drift.md`** — when `<vault>/constitution.md` exists, validate code against constitution clauses (§A–§F), the `constitution_drift_detected` halt, and the report's `## Constitution Findings` section.
- **`references/auto-and-chain.md`** — `--auto` behavior table, `drift_framework_mismatch` blocker YAML, handoff YAML emission, snapshot reuse, per-bolt incremental mode, suggested-next-actions block, and scope-aware scanning.

## Related skills

Vault must have `Implementation mode: existing`. OQ conventions + `vault.json` field rules: `generate-intent/references/vault-contract.md` (detect-drift reads `vault.json` but never writes it). Vault evolution from a new PRD: `diff-vault`. OQ resolution when drift produces new OQs: `resolve-oq`.
