---
name: detect-drift
version: 2.7.0
description: Detects drift between a `mode=existing` vault (the "should be" state) and the live codebase (the "as is" state). Heuristic scan of entities, flows, decisions, and API surface; produces a structured DRIFT-REPORT.md with confidence-rated findings and offers interactive resolution. Use when the user says "drift detect", "vault vs code", "check codebase against vault", "cek code vs vault", "is the code in sync?", or paraphrases.
---

# Drift Detect — vault vs live codebase reconciliation

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

**Step 0 — Inputs (MANDATORY).** Vault path (auto-detect 7 standard files; verify `00-index.md` Vault Lock Status `Implementation mode: existing` — if `new`, STOP per the hard rule below). Codebase path (root of the live repo; `AskUserQuestion` between CWD / subdirectory / other). Optional scope hints (backend, migrations, routes, jobs, frontend dirs). When invoked from the sync lane (`orchestrate-flow --sync`), the changed-paths set (dirty journal ∪ git delta) arrives as the scope hint — scan only those paths against the vault model. Log the scope explicitly at start — `Scope hint received: <scope.id|changed-paths(N)>` or `Full scan (no scope hint)` — so a chain that dropped the scope at a seam is visible in one line. Persist `VAULT_DIR`, `CODE_DIR`, `SCOPE_DIRS`. Run `git status` — note uncommitted changes in the report (findings reflect the working tree).

**Step 0.5 — Drift scope (MANDATORY).** `full` (default) | `schema-only` (entities + constraints) | `flows-only` (flows + endpoints + jobs) | `decisions-only` (ADRs vs code) | `single-doc`. Persist `DRIFT_SCOPE`.

**Step 1 — Read vault** (by scope): `schema-only`→`03-data-model.md`; `flows-only`→`04-flows.md`+`02-architecture.md`; `decisions-only`→`05-decisions.md`; `full`→all 6 numbered docs. Build an internal model: entities (with field signatures), flow IDs (with steps), endpoints, ADRs (with constraints).

**Step 1.5 — Framework detection.** REUSE FIRST: when `.mega-sdd/codebase/codebase-map.md` exists with a §7 Framework block at confidence ≥ medium AND its `last_scanned_commit` matches git HEAD, adopt that framework verbatim (log `Framework from codebase-map §7: <name> (<confidence>)`) — don't re-parse manifests the scan already parsed. Map absent/stale/low-confidence → detect from manifest: `composer.json`→PHP (Laravel/Symfony), `package.json`→Node (Next/Nest/Express), `Gemfile`→Ruby, `go.mod`→Go, `requirements.txt`/`pyproject.toml`→Python, `pom.xml`/`build.gradle`→Java/Spring, `Cargo.toml`→Rust, `pubspec.yaml`→Flutter. Propose default scope dirs; user confirms. Ambiguous (monorepo / multi-framework) → ask which subproject, or emit the `drift_framework_mismatch` blocker (see `references/auto-and-chain.md`).

**Step 2 — Scan codebase** with `Bash`/`Glob`/`Read`: entities (migrations, models/ORM defs → name + fields + types); flows/endpoints (routes, jobs/cron, controllers); decisions (parse each `D-XXX` constraint, keyword-probe the code — lowest confidence axis); OQ references (`OQ-{CODE}-{N}` in code/commits cross-referenced against still-open vault OQs).

**Step 3 — Compute drift.** Per axis, compare vault model vs code model. Each finding: category, vault reference (doc + section + identifier), code reference (path + line range), confidence, severity, suggested action (informational only).

**Step 4 — Write `DRIFT-REPORT.md`** to `<VAULT_DIR>/` (overwrite). Full report structure, section ordering (Decision findings PRIORITY-1 at top), and per-finding format are in **`references/report-format.md`**.

**Step 5 — Interactive walkthrough (optional; SKIPPED under `--auto`).** Under `--auto` (sync lane): NO mid-chain questions — decision deferral instead. Every finding that needs a human direction call is queued to `<vault>/PENDING-SYNC.md` (prioritized digest; appended by category) and the chain continues. **Memory pre-fill (suggestion only):** when `<vault>/.memory/drift-history.md` shows ≥3 same-direction resolutions on the finding's fingerprint class, attach that direction as a pre-filled suggestion (`source: drift-history, n=N`) — to the AskUserQuestion in interactive mode, or onto the PENDING-SYNC.md entry under `--auto`. A memory suggestion NEVER auto-resolves a finding and never widens the `--auto-apply=safe` class. With `--auto-apply=safe` (opt-in): the narrow safe class (confidence HIGH + category ∈ name-drift/type-drift/missing-in-vault + claim NOT `[LOCKED]` + code side committed) goes straight to the Step 5.5 write-back WITHOUT a question — everything else still queues. Interactive mode: `AskUserQuestion`: walk now / save report only / cancel. If walking: present findings in priority order, capture the chosen action per finding into `DRIFT-ACTIONS.md`. Code-side actions (`FIX_CODE`) are NEVER executed by this skill. Vault-side actions (`UPDATE_VAULT`) proceed to the Step 5.5 write-back protocol. Template in `references/report-format.md`.

**Step 5.5 — Vault write-back (only for `UPDATE_VAULT` actions; living-vault S5).** For each accepted vault-side action, DRAFT the exact vault patch with git provenance (`git log -1 --format='%h %s — %an, %ad' -- <code anchor file>` cited inline), present ALL drafts as one batch diff, apply ONLY on explicit user ACCEPT. Full protocol (per-category patch shapes, provenance line, the batch-confirm UX, and the rails) → `references/report-format.md §Vault write-back protocol`.

**Step 6 — Update vault metadata.** Walkthrough captured actions but NO write-back applied → append a Changelog entry to `00-index.md` recording the drift *session* only (version unchanged, `vault.json` untouched). Write-back APPLIED (Step 5.5 ACCEPT) → append the Changelog entry listing each patched section + provenance, bump the vault version (minor), and regenerate `vault.json` under the `vault.json.lock` advisory lock. Boundary rules → `references/report-format.md §Vault write-back protocol`.

**Step 6.5 — Memory layer (skipped under `--memory-off`).** Append to `<vault>/.memory/drift-history.md` via Bash `>>` heredoc (orchestrated chains: emit via handoff `metadata.memory_writes` instead): one run-summary block (findings by category × confidence, scope, source_run) and, per finding the user resolved, one `## Direction calls` row — fingerprint (`<category>:<vault-section>:<normalized-name>`), direction (`code_right | vault_stale | deferred`), provenance. Schema: `memory/references/memory-schema.md §drift-history`. Memory writes happen AFTER the report/actions artifacts are written — memory is derivative, never the source.

**Step 7 — Self-check:** `mode=existing` confirmed; framework detected / overridden and scope dirs documented; every finding has category + vault ref + code ref + confidence; no silent "confirmed match"; decision findings at top; walkthrough findings each ended in an action or explicit defer; no code changes executed; report (and actions file, if any) written.

**Step 8 — Present summary:** total findings + breakdown by category/confidence; top 3 PRIORITY-1 findings (one line each); path to the report; suggested next step. No "I have completed the scan…" preamble.

## Hard rules (the rails)

- **`mode=new` → STOP.** Surface `mode_migrate_after` if present; tell the user to flip to `existing` (or run `diff-vault` for PRD-vs-PRD). This rule holds even under `--auto`.
- **No code execution.** The skill writes report files only — it never modifies code, opens PRs, runs migrations, or edits vault content directly. Actions are captured in `DRIFT-ACTIONS.md` for human follow-up. If asked to apply fixes, refuse politely and offer the action list.
- **Direction-neutral framing.** Always present vault state and code state side-by-side; never declare one "wrong".
- **Confidence labels mandatory.** Low-confidence findings carry an explicit "verify manually" caveat.
- **No silent dismissal.** Confirmed matches are listed so reviewers know they were evaluated, not skipped.
- **Idempotency.** Re-running with no vault/code change regenerates an identical report.

## When to push back

**Always:** `mode=new` (STOP, as above); codebase path missing or has no recognizable code (STOP, verify path); user asks the skill to apply fixes (refuse, offer the action list); major framework mismatch — vault implies one stack, manifest says another (confirm before scanning — the vault may target a different repo).

**Conditional:** scope too large (>10k files) → recommend narrowing or per-subdirectory runs (warn that accuracy degrades, don't refuse); many low-confidence decision findings (>10) → recommend `decisions-only` with a narrower code scope; many unresolved OQs (>20 P1 open) → recommend `resolve-oq` first (drift against an unresolved vault is noisier).

## Limitations (be honest)

Heuristic detection, not static analysis — it greps and reads, no AST or type-checking, so false positives and negatives both happen. Semantic equivalence is hard (same concept, different name → flagged as Name drift for the user to confirm). Decision compliance is the lowest-confidence axis — treat violations as triggers for human review, not verdicts. Large monorepos degrade in time and accuracy — narrow scope. Not a replacement for code review or tests; it catches doc-vs-code divergence that neither typically checks.

## Specialist references (load on demand)

- **`references/report-format.md`** — full `DRIFT-REPORT.md` + `DRIFT-ACTIONS.md` templates, section ordering, per-finding examples, and the `vault.json` reconciliation boundary.
- **`references/constitution-drift.md`** — when `<vault>/constitution.md` exists, validate code against constitution clauses (§A–§F), the `constitution_drift_detected` halt, and the report's `## Constitution Findings` section.
- **`references/auto-and-chain.md`** — `--auto` behavior table, `drift_framework_mismatch` blocker YAML, handoff YAML emission, snapshot reuse, per-bolt incremental mode, suggested-next-actions block, and scope-aware scanning.

## Related skills

Vault must have `Implementation mode: existing`. OQ conventions + `vault.json` field rules: `generate-intent/references/vault-contract.md` (detect-drift reads `vault.json` but never writes it). Vault evolution from a new PRD: `diff-vault`. OQ resolution when drift produces new OQs: `resolve-oq`.
