# Semantic-scoped validation — analyze freshness ledger + changed-only lint

**Date:** 2026-08-03
**Status:** IMPLEMENTED, round-folded — shipping as v5.32.0
**Target release:** v5.32.0
**Mandate:** the operator's proportionality directive (2026-08-03): "next nya hal2 kaya gini yg perlu jadi concern di skills mega-sdd — agar efisien jalan, ga sweep semua sekaligus tapi semantic sesuai kebutuhan dan context." Validation surfaces must scope to what actually changed, not sweep the whole project every invocation.

## The honest baseline (what is ALREADY scoped — do not rebuild)

- **Stop-hook + PostToolUse auto-analyze are ALREADY cheap.** Both call `run-analyze.sh --aggregate-only`: zero validator re-runs, state-file reads only. This spec does NOT touch them.
- scan `--changed-only`/`--shallow-scan` + per-file sha REUSE; deep-scan stale-slice-only dispatch; sync lane scoping; PostToolUse debounce; `--lean`; `symbol_slice` capped retrieval; diff-scoped dup sweep — all shipped in prior tranches.
- **The moat is exempt BY DESIGN.** The execute-bolts PreToolUse gate re-derives all seven states and recomputes B1 from ground truth on every invocation. That is deliberate anti-forgery (recompute-at-gate), not waste. Nothing in this spec reads from or writes to any gate input, and no gate reads anything this spec introduces.

## The sweep this spec removes

`run-analyze.sh` FULL mode (manual `/mega-sdd:analyze`, and the analyze verb of `/mega-sdd`) re-runs **every per-file validator over every file** on every invocation: `validate-unit-spec.sh` × every unit, {`validate-kb-output.sh`, `validate-kb-markers.sh`, `validate-kb-flows.sh`} × every KB file, `validate-kb-citations.sh` × every domain file, `validate-vault-oqs.sh` × every vault doc, `validate-fsd-slots.sh` × every FSD, `validate-bolt-artifacts.sh` × every bolt report. Each invocation is a bash+python spawn (~100–300ms on macOS, ~12x worse under Windows EDR per the field measurements). A 40-unit + 20-KB-file project pays ~150 spawns to learn that the one unit edited since the last run is fine.

`lint-units` (manual + the chain's auto-lint leg after `generate-units`) has the same shape at the prose layer: Step 2 spawns `validate-unit-spec.sh` per unit and Steps 3–4 narrate per-unit findings for **all** units, even mid-iteration when one unit changed.

## S1 — analyze freshness ledger (`run-analyze.sh`)

### The ledger

`<cwd>/.mega-sdd/.analyze-freshness.json` — **single writer: `run-analyze.sh` FULL mode.** Nothing else writes it (parallel-session safety: one owner). Shape:

```json
{
  "schema": 1,
  "plugin_version": "5.32.0",
  "code_fingerprint": "<sha256 or \"unreusable\">",
  "kb_fingerprint": "<sha256 of the knowledge-base/ md tree>",
  "written_at": "<ISO8601>",
  "families": {
    "vault_oqs":  { "<relpath>": {"sha": "<sha256>", "rc": 0, "status": "PASS", "sibling_sha": "<vault.json sha256>"} },
    "kb_output":  { "<relpath>": {"sha": "<sha256>", "rc": 0, "status": "WARN"} },
    "kb_markers": {}, "kb_flows": {}, "vault_flows": {}, "fsd_slots": {}
  }
}
```

Entries record `status` (PASS/WARN/FAIL, captured from the family state slot right after each fresh invocation — a zero-spawn bash regex read) alongside `rc`, because rc alone cannot carry WARN.

The ledger also carries a top-level `"unit_baseline": { "<relpath>": "<sha256>" }` — the sha of every unit file at the last FULL analyze. It drives **no reuse** in analyze (unit_spec always re-runs); it exists solely as the changed-set baseline for `lint-units --changed-only` (S2). Recording it is pure hashing, no extra spawns.

### The O(n²) collapse first (bigger than the ledger for units)

`validate-unit-spec.sh` **always validates ALL units project-wide on every invocation** (S5 GU-HOOK-1 — `--file-path` only selects the focal unit for stdout/exit code; the state file always merges every unit). run-analyze's per-unit loop is therefore N invocations × N units each = **O(n²) unit validations per FULL run**. Fix: FULL mode calls it **ONCE with `--cwd` only** (no `--file-path`) — the merged exit code IS the worst-of the loop was reconstructing. `unit_spec` moves to the single-invocation class; it is NOT ledger-reused (it is env-coupled anyway, and O(1) spawns needs no ledger). The env-mutant hazard (deleted anchor source) is thereby always caught — the validator re-runs every FULL invocation.

(`validate-bolt-artifacts.sh --file-path` was checked: true single-file mode — the loop stays, unreused.)

### Validator purity classes (verified by inspection, 2026-08-03)

| Class | Families | Reuse key | Why |
|---|---|---|---|
| **PURE** — verdict is a function of the file's bytes only | `kb_markers`, `kb_flows`, `vault_flows`, `fsd_slots` | file sha256 + `plugin_version` | zero reads outside the target file (inspected: no subprocess/isfile/exists beyond the target) |
| **KB-COUPLED** — verdict also reads sibling KB files | `kb_output` (`depends_on` resolves against sibling KB files' `domain:` frontmatter — round finding CL-SB2) | file sha256 + `plugin_version` + `kb_fingerprint` | deleting/renaming a sibling KB file flips `kb_depends_on_invalid` without the validated file changing |
| **ENV-COUPLED** — verdict also reads the KB inventory, cited paths, and siblings | `vault_oqs` (KB inventory + citation-path existence under `.mega-sdd/knowledge-base/` — round finding CL-SB1 — + reads sibling `vault.json`; `code_fingerprint` kept defensively for citations outside `.mega-sdd/`) | file sha256 + `plugin_version` + `kb_fingerprint` + `code_fingerprint` + sibling `vault.json` sha | a deleted citation target flips the verdict without the doc changing — sha-only reuse laundered a stale PASS (proven live in the round) |
| **NEVER REUSED** | `unit_spec` (single project-wide invocation, see above), `bolt_artifacts` (git-history-dependent), `kb_citations` (legacy-root auto-detect may resolve outside the worktree — unfingerprintable), every project-wide single-invocation validator (V1 handoff, V3B orphans, V6 coverage, V7S starterkit, V8–V12), vault internal consistency (pure-read inline, cheap), reuse-dup advisory, token-cost report | — | correctness over savings; the single-invocation set is O(1) spawns anyway |

### `code_fingerprint`

`sha256( HEAD sha ∥ sorted \`git status --porcelain -z -uall -- . ':!.mega-sdd'\` entries ∥ per-listed-path content sha256 )`.

- Covers the code tree outside `.mega-sdd/`. Vault-editing sessions (the dominant analyze loop) leave it stable → the env-coupled family reuses.
- Content-hash based, never mtime (deterministic under `touch`, testable).
- **`-z`** — NUL-separated, unquoted paths (a porcelain-quoted name would otherwise never content-hash); rename/copy entries carry the origin path as its own NUL field and both sides are hashed.
- **`-uall`** — files INSIDE untracked directories are enumerated (round finding: a bare `?? dir/` line is blind to content churn within the dir).
- **Toplevel-relative resolution** — porcelain paths are repo-root-relative; they resolve against `git rev-parse --show-toplevel`, never against cwd (round finding: a mega-sdd root that is a subdirectory of the git repo resolved every dirty path to a nonexistent file and never hashed content).
- **Bounds:** > 200 dirty/untracked code paths, or `git` unavailable, or not a git repo → fingerprint = `"unreusable"` → the env-coupled family always re-runs (fail-closed toward re-running, never toward reusing).

### `kb_fingerprint`

`sha256( sorted (relpath, content sha256) over every `.md` under `.mega-sdd/knowledge-base/` )` — pure fs walk, no git (untracked KB files count the same as tracked ones). This is the invalidation key for everything the KB-reading validators consult: `kb_output` and `vault_oqs` reuse only while it is unchanged. A KB delete, rename, archival move, or edit re-runs them.

### Behavior

- **Default = scoped.** Per-file loops consult a precomputed decision map: `(family, relpath)` → `REUSE:<rc>` when the reuse key matches the ledger, else `RUN`. Reused entries fold their recorded rc into the family's worst-of; fresh runs execute the validator exactly as today and update the ledger entry.
- **`--fresh`** — ignore the ledger entirely, re-run everything, rewrite the ledger from scratch. (NOT `--full`: that token is already the front door's lean/full **profile** switch; overloading it would make `/mega-sdd --full` ambiguous.)
- **`--aggregate-only` is untouched** — never reads nor writes the ledger (it runs no validators to begin with).
- Ledger written at end of every FULL run: entries for every file actually validated this run or legitimately reused; files no longer present drop out; unknown families never enter. `plugin_version` mismatch or `schema` mismatch or unparseable ledger → treated as absent (full re-run, ledger rewritten).
- Existence/SKIP discovery checks are unchanged (they are `find` calls, not spawns of validators).
- **Decision/results rows use `-` as the explicit empty-cell placeholder.** TAB is IFS-whitespace in bash, so consecutive tabs collapse under `read` and empty middle fields shift later columns left (round finding CL-IMP1: the sibling sha landed in the rc column and vault_oqs reuse silently died in every project with a `vault.json`). No cell is ever the empty string on disk; bash and the ledger writer decode `-` back to empty.

### Honest reporting (no silent staleness)

- `CONSISTENCY-REPORT.md` header gains: `**Scope: per-file validators — N re-run, M reused (unchanged since <written_at>); project-wide validators always re-run. \`--fresh\` forces a full re-run.**` A `--fresh` run says `**Scope: full re-run (\`--fresh\`).**`
- `.analyze-state.json` gains `"scope_mode": "scoped"|"fresh"|"aggregate", "reused_files": M, "rerun_files": N` (rerun counts per-file validator invocations, unit_spec's single project-wide invocation included).
- A family whose state slot is missing but whose per-file worst-of exists reports detail `per-file worst-of (state slot absent — files reused)` — never the misleading `validator ran but no state file written`.

### The last-writer-wins masking fix (FULL mode only — disclosed pre-existing bug)

The per-file families write **single-slot state files** (last invocation overwrites), and Phase 3 today **overrides** the loop's worst-of rc with that slot's status — so a FAIL in any file except the last validated is reported PASS at the boundary row. (Same bug class S5 GU-HOOK-1 fixed for unit-spec.) This tranche fixes the truth pass for **all eight per-file loops**: the six ledgered families get severity-max over per-file statuses (fresh + reused; FAIL > ERROR > WARN > PASS) with the slot supplying detail text only, and the two never-reused per-file loops (`bolt_artifacts`, `kb_citations`) get the same per-invocation severity tracking (round finding DL-I1 — the first spec draft claimed the fix while leaving these two masked). **Aggregate-only mode keeps its slot-read semantics untouched** — it is documented as "what PostToolUse wrote during the session", inherently last-write-shaped; the R3-11 empty-tree parity pin is unaffected. The durable fix (incremental-merge slots like unit-spec's) is out of scope — backlogged, not silently absorbed.

### Safety invariant (stated, tested)

Analyze is REPORT-ONLY. No PreToolUse gate reads `.analyze-state.json`, `CONSISTENCY-REPORT.md`, or `.analyze-freshness.json`; the execute-bolts gate re-derives its seven states from ground truth regardless. Forging the ledger can therefore mislead a report at worst — it can never open a gate. (The anti-self-bypass guard list is NOT extended for the ledger for exactly this reason: it guards gate inputs, and the ledger is not one.)

## S2 — `lint-units --changed-only`

`commands/lint-units.md` gains a scoping flag (alias doc = the procedure's single source; flags pass through the front door unchanged):

- **Scope-set** = units whose current sha256 differs from (or is absent in) the analyze ledger's `unit_baseline`, **∪ transitive reverse-dependents** of scope-set units (BFS over `depends_on` edges — a changed unit can invalidate its dependents' binding/interface assumptions), computed over ALL units' loaded frontmatter.
- **No ledger (or unparseable/version-mismatched)** → full sweep + one honest line: `--changed-only: no freshness ledger — full sweep (run /mega-sdd:analyze to establish one)`.
- **Global cross-unit checks always run over the full frontmatter set** (dangling `depends_on`, module/squad resolution, cross-squad routing): loading frontmatter is cheap reads; only the expensive legs scope — Step 2 validator spawns, Step 3 per-unit checks, Step 4 per-unit narration, Step 5 markdownlint file list.
- **Honesty rail:** the summary reports `N of M units linted (changed ∪ dependents)` and NEVER claims project-wide cleanliness from a scoped run; aggregate metrics are labeled scoped.
- **Lint never writes the ledger** (single-writer rule; `validate-unit-spec.sh` still writes its own state file as today).
- **Default stays full** for manual invocation — lint-units' stated purpose is the comprehensive pre-bolt sweep (proportionality cuts both ways: pre-bolt = the release tier).
- **The chain's auto-lint leg passes `--changed-only`** (`orchestrate-flow/references/chain-execution.md` row): right after `generate-units`, regenerated units differ from the ledger and land in scope naturally — first run ≈ full, iteration runs scope to the delta.

### Integration rosters (round findings DL-I3/DL-I4)

- `.analyze-freshness.json` is added to the derived-output prune lists in `hooks/stop` and `hooks/post-tool-use` — without it, the first Stop/PostToolUse after every FULL analyze would see the ledger as "changed" and re-arm the artifact scans tranche 4 (v5.22.0) eliminated.
- `.gitignore` runtime-state roster gains `**/.mega-sdd/.analyze-freshness.json` — consumer projects must not gain a perpetually-dirty untracked file.

## Non-goals

1. Stop/PostToolUse auto-analyze — already aggregate-only; no change.
2. The moat — recompute-at-gate stays byte-for-byte untouched.
3. CI paths filtering — repo-CI decision for the operator, separate from plugin runtime.
4. D3 scan-as-a-service (claim-scoped bind) — its own spec.
5. `analyze-parallelism`, `list-modules` — single-invocation script surfaces, not sweep-shaped.

## Proof obligations (tests, `tests/analyze-scoped/`)

1. **Reuse is real:** fixture project; FULL run 1 → run 2 with nothing changed: pure-family state-file mtimes DO NOT advance (validator not spawned), report says `reused`, worst-of unchanged.
2. **Change re-runs:** touch one KB file's content → only its family re-runs for that file; verdict updates.
3. **The env mutant (the likeliest regression):** vault doc unchanged, the CODE tree changes (a tracked source file modified/deleted) → `code_fingerprint` changes → `vault_oqs` re-runs while the pure KB families keep reusing on the same run (observable: rerun count rises above the steady-state unit_spec-only baseline). And `unit_spec` runs UNCONDITIONALLY every FULL pass (single invocation) — assert its state mtime always advances.
4. **O(n²) collapse:** FULL mode invokes `validate-unit-spec.sh` exactly once (no `--file-path`), and its merged verdict lands in the boundary row.
5. **Masking mutant:** two KB files, first FAILs, second PASSes → boundary row reports FAIL (severity-max), not the slot's PASS.
6. **Version invalidation:** ledger `plugin_version` mismatch → full re-run.
7. **`--fresh`** forces re-run with a fresh ledger.
8. **`--aggregate-only`** neither creates nor mutates the ledger.
9. **Family whitelist:** ledger `families` keys ⊆ the six reusable families; `unit_spec`/`bolt_artifacts`/`kb_citations` never appear.
10. **FAIL reuse is honest:** a failing unchanged file stays FAIL on reuse (recorded status folds into severity-max).
11. **Doc pins:** lint-units.md carries `--changed-only` + the `changed ∪ dependents` closure rule + the no-ledger fallback line; chain-execution.md AND the front-door mega-sdd.md auto-lint rows carry `--changed-only`; analyze surfaces name `--fresh` and the scoped-default prose.
12. **KB-tree laundering pin (round):** deleting a KB file with no validated doc changed → `kb_output` re-runs (`kb_fingerprint` invalidation, slot mtime advances).
13. **TAB-collapse pin (round):** the fixture vault HAS a `vault.json`; the `vault_oqs` ledger entry's `sibling_sha` is a real 64-hex sha (a collapsed row records `""` and reuse silently dies).
14. **Spawn-count pin (round):** with 2 units, a PATH-shimmed `bash` proves `validate-unit-spec.sh` spawns exactly ONCE per FULL run (the O(n²) collapse is otherwise untestable on a 1-unit fixture).
15. **Verdict-flip pin (round):** the changed-file re-run must recompute the verdict, observed as the ledgered per-file status flipping PASS→FAIL after an edit introduces a violation.

## Round disclosure (dual-blind, 2026-08-03 — written after the round, all findings folded pre-ship)

Two blind general-purpose reviewers (code lane / spec-doc lane), both read-only with mktemp experiment rights. **Every finding below was folded before ship; the fixes are the sections marked "round finding" above.**

**Code lane:**
- **CL-SB1 (ship-blocker, proven live):** `vault_oqs` reads the KB inventory + cited KB paths under `.mega-sdd/knowledge-base/` — which the original reuse key did not cover and `code_fingerprint` explicitly excluded. Deleting a cited KB file laundered a stale PASS in scoped mode. Fix: the `kb_fingerprint` key component.
- **CL-SB2 (ship-blocker, proven live):** `kb_output` is NOT pure — `depends_on` resolves against sibling KB files. Same laundering class; same fix (moved to KB-COUPLED).
- **CL-IMP1 (important, proven on bash 3.2 + 5.x):** IFS TAB-collapse shifted the empty rc/st cells of RUN rows, dropping `sibling_sha` — vault_oqs reuse permanently dead in any project with a `vault.json` (fail-closed, invisible to the original fixture which had none). Fix: `-` placeholder cells + fixture vault.json + the 64-hex pin.
- **CL-IMP2 (important):** untracked-directory porcelain blindness (`?? dir/`). Fix: `-uall`.
- **CL-M1:** fallback rows leaked `sha:"RUN"` into the ledger via the same collapse — placeholders fix; writer decodes `-`.
- **CL-M3:** porcelain-quoted names never content-hashed. Fix: `-z`.
- Refuted after live attack: fail-open decision phase (fallback proven fail-closed), corrupt-ledger handling, worst-of rc traps, WARN/exit-contract regression, unit_spec collapse parity, aggregate parity, forged-ledger gate impact (report-only confirmed — nothing outside run-analyze.sh reads the ledger).

**Spec/doc lane:**
- **DL-SB1 (foreign):** `run-full-suite.sh` shebang corrupted by a stray working-tree keystroke (`ma#!/usr/bin/env bash`) — not part of this tranche; reverted via git checkout.
- **DL-I1 (important):** the masking fix covered 6 of 8 per-file loops while the spec claimed the class fixed — `bolt_artifacts` + `kb_citations` now get the same severity tracking.
- **DL-I2 (important):** two `code_fingerprint` churn classes the spec claimed covered were not (untracked dirs, subdir-of-repo roots) — fixed with `-uall` + toplevel-relative resolution.
- **DL-I3/DL-I4 (important):** the ledger was missing from the Stop/PostToolUse prune lists (would re-arm the tranche-4-eliminated artifact scans every post-analyze turn) and from `.gitignore`. Both rosters extended.
- **DL-I5 (important):** the O(n²)-collapse claim was untestable on the 1-unit fixture — added the 2-unit + PATH-shim spawn-count pin.
- **DL-I6 (important):** front-door `mega-sdd.md` auto-lint row + orchestrate-flow SKILL summary still taught the unscoped leg; `analyze.md` kept a "re-run fresh" heading above the scoped-default paragraph. All three aligned.
- **DL-M1/M2/M3:** analyze SKILL description opening updated (trigger phrases preserved), lint Step 5 markdownlint glob scoped under `--changed-only`, test overclaims tightened (scoped-default grep, verdict-flip observable).
- Refuted: moat-safety prose (grep-verified true), reuse proof spawn-proofness, masking-proof order determinism, `--fresh`/`--full` conflation, broken pinned phrases (8 pinning suites re-run green).

**Recurring-class note:** CL-SB1/CL-SB2 are the fourth consecutive round catching a spec claim the code (here: the purity taxonomy) did not honor — the "verified by inspection" table was inspected too shallowly (grep for subprocess/isfile missed `glob` + inventory builds). The countermeasure that worked: reviewers instructed to check the validators' CODE, not the spec's comments.
