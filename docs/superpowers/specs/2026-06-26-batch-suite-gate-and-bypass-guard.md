# Batch full-suite gate + out-of-band bypass guard — design

**Status:** accepted · **Date:** 2026-06-26 · **Skills:** `execute-bolts`, `orchestrate-flow` (sync lane) · **Enforcement:** `scripts/validate-bolt-artifacts.sh` + Stop-hook aggregator

## Problem

Every bolt's acceptance command is **scoped** to that unit (`<runner> <unit-target>`, never the whole project suite), and `execute-bolts` has **no final full-suite run**. Two failure modes ship a RED suite with nothing to catch it:

1. **Within-batch cross-bolt regression.** Bolt N (later) changes shared behavior that breaks bolt M's (earlier) contract. M's scoped acceptance test already passed at M's commit and never re-runs; N's scoped test doesn't cover M. The batch is declared `completed` while the project suite is RED.
2. **Out-of-band post-batch edit.** A commit touches a unit's `target_files` *without going through a bolt* (no pre/post-flight, no review panel, no `SDD-PROVENANCE` trailer) and breaks an earlier bolt's contract. The within-batch gate has already finished, so only the **sync lane** can catch it — and today the sync lane re-verdicts binding but never re-runs the suite.

"Prose that says run the full suite enforces nothing" — the obligation must be a deterministic artifact wired to a hook.

## Design

### A. Final full-suite gate (`execute-bolts`)

After the **last committed code-bearing bolt** of an invocation (single OR batch — a lone bolt can break a sibling just as a batch can; the suite runs in the shell, costing wall-clock not model tokens, so there is no cost reason to narrow it to multi-unit), run the project's **full** test suite — the runner detected at pre-flight check 3.5, **with no per-unit scope filter** — exactly once. Write `<vault>/bolts/_batch-suite.json`:

```json
{ "command": "<full-suite command>", "status": "green|red",
  "passed": N, "failed": N, "todo": N,
  "head_sha": "<sha at run>", "ran_at": "<iso>",
  "units": ["U-001", "..."], "bypass_commits": [] }
```

- `status: red` → **halt `batch_suite_red`**: the batch is NOT complete; emit the blocker with the failing test names; do not emit a `status: completed` handoff; leave the tree for human review (do not auto-revert).
- Runs once per invocation, after the last bolt — affordable. Skipped only for: `--dry-run`, a run that committed zero code (verify-only / all-skipped), or `--no-full-suite` (DISCOURAGED escape hatch, logged in `_summary.md` + handoff `notes.full_suite_skipped: true`, never silent).

### B. Out-of-band bypass guard (`execute-bolts`, at the gate)

Before the gate verdict, scan commits in the **batch window only** — from the invocation's base SHA (recorded at batch start) to HEAD, **excluding** this run's own bolt commits — for any commit that touched a unit's `target_files` yet carries no `SDD-PROVENANCE` trailer. Record them in `_batch-suite.json.bypass_commits[]`. A non-empty list does not by itself halt (the full-suite run is the real gate), but it is surfaced in `_summary.md` and forces the suite to run even on an otherwise-skippable invocation. Bounding to the batch window is mandatory — an unscoped `git log` would flag every pre-SDD commit in history.

### C. Sync-lane full-suite re-run (`orchestrate-flow --sync`)

After the sync lane reconciles any out-of-band edit (re-scan → drift triage → re-bind → unit reconcile), it **re-runs the full suite** and writes `_batch-suite.json` (same shape, `units: []`, `source: sync`). RED → surface in the sync output and `SYNC-REPORT.md`. This is the catch for failure mode 2. **Ownership:** the full-suite re-run is owned by B2 (here); C2 (SYNC-REPORT terminal verification) owns the `SYNC-REPORT.md` emission + staleness re-check and *consumes* this artifact rather than re-running the suite — they compose, they do not duplicate.

### Enforcement (gate, not prose)

`scripts/validate-bolt-artifacts.sh --batch-suite-gate` adds a check, mirroring the existing `bolt_artifacts_missing` next-run aggregator (the hook **verifies the artifact; it never runs the suite** — running 200s+ suites inside a PreToolUse hook is exactly the inflation to avoid). It is **commit-keyed, not handoff-keyed** — it never reads a handoff:

- It walks `git log` for two anchors: the newest **`(bolt): U-XXX` commit** that touched a code file (outside `.mega-sdd/`) — which *activates* the gate (no code-bearing bolt yet ⇒ nothing to gate) — and the newest commit touching a code file **regardless of subject** (`newest_code`), which is the *freshness* anchor.
- "Code file" = outside `.mega-sdd/` AND not a pure-docs file (`.md`/`.markdown`/`.rst`/`.adoc`) — a docs commit cannot break a test suite, so it must not force a re-run.
- A green `_batch-suite.json` **covers** the tree iff `newest_code` is an ancestor of (or equal to) the gate's `head_sha` (`git merge-base --is-ancestor`). Anchoring freshness on `newest_code` (not the newest bolt) is what closes the **out-of-band half** of the incident: a hotfix / manual edit / `git pull` that touches source after a green suite is no longer "covered" → **halt `batch_suite_gate_missing`** (with `out_of_band: true` when the uncovered change carried no bolt provenance).
- No covering green gate → **`batch_suite_gate_missing`** (missing or stale). An existing `_batch-suite.json` with `status: red` → **`batch_suite_red`** (blocked until green, mirroring the Factory-Line FAIL aggregator).

The validator keys on a code commit existing for the run, decided deliberately (not "multi-unit only"): a single bolt can break a sibling, and the artifact check is free. (The within-batch gate + this freshness anchor are defense-in-depth; the sync lane (§C) remains the reconciliation path for out-of-band edits.)

## Tests (behavioral — exercise the validator, never grep prose)

`tests/batch-suite-gate/` — fixtures of a `.mega-sdd` tree with a completed `execute-bolts` handoff:
1. code-committed bolt + no `_batch-suite.json` → validator exits non-zero, emits `batch_suite_gate_missing`.
2. code-committed bolt + `_batch-suite.json status: red` → emits `batch_suite_red`.
3. code-committed bolt + `_batch-suite.json status: green` at HEAD → exit 0.
4. verify-only handoff (no code commit) + no `_batch-suite.json` → exit 0 (gate not required).
Plus a wiring assertion that the Stop-hook aggregator invokes the new check.

## §B1 — Post-flight evidence gate (companion fix, same validator + doctrine)

The same field audit found the post-flight Hard-rule scan was **prose-only**: one `extend` bolt with non-empty `## Hard rules` committed with no `postflight.json`, and nothing caught it — the Stop-hook checked bolt-report presence but never the post-flight evidence. Textbook "prose that says HALT enforces nothing."

**Rule.** A committed `create`/`extend`/`modify` bolt whose unit has a **non-empty `## Hard rules`** section MUST carry `<vault>/bolts/U-XXX/postflight.json` with `status: pass` and every `rules[].verdict: pass`. Verify units skip post-flight (no changes to validate) and are exempt.

**Enforcement.** `validate-bolt-artifacts.sh --postflight-scan` (new mode) walks bolt commits, reads each unit's `task_type` + `## Hard rules` body, and flags any Hard-rule non-verify bolt with a missing or non-passing `postflight.json` → **`postflight_evidence_missing`**, written to `.bolt-postflight-state.json`. The Stop hook runs it each turn end; the PreToolUse execute-bolts aggregator blocks the next run on FAIL — exactly the orphan-scan / batch-suite pattern. The `postflight.json` schema is formalized in `execute-bolts/references/hard-rule-scan.md`.

**Test:** `tests/postflight-evidence/test-postflight-scan.sh` (behavioral) + `test-postflight-wired.sh` (wiring).

## Out of scope / deferred

- Choosing the full-suite command for exotic monorepos with multiple runners (the gate uses the single runner from pre-flight 3.5; multi-runner projects get a follow-up).
- The provenance trailer *format* is unchanged (defined in `execute-bolts/references/halts-and-handoff.md`).

---

## Amendment — S6 god-review hardening (2026-07-03, v4.59.0)

The stage-6 god-review found the B1/B2 gates dormant-or-forgeable in practice. This amendment is the new contract:

1. **Commit identity (EB-GATE-2).** A bolt commit is recognized by ANY of: the canonical conventional-commit scope `<type>(U-XXX):` (bolt-contract §Commit message format), the legacy `(bolt): U-XXX` subject, or the `Unit: U-XXX` git trailer. All validator modes (orphan / B2 / B1 / B3) share this identity. Producers additionally emit the `SDD-PROVENANCE:` trailer (the bypass-guard key).
2. **Evidence artifacts are writer-only (EB-GATE-4).** `postflight.json` and `_batch-suite.json` are Write/Edit-denied and Bash-tamper-guarded; they are produced ONLY by `scripts/run-postflight-scan.sh` (executes the unit's Hard rules: v1 productions deterministically, v2 via ast-grep, directives via explicit `--attest-directives`) and `scripts/run-full-suite.sh` (runs the detected full suite, pins `head_sha` via `git rev-parse HEAD`). No remediation text may instruct hand-writing either artifact.
3. **`head_sha` must be 40-hex (EB-VAL-1).** `covers()` rejects symbolic revs; a green artifact with `head_sha: "HEAD"` never covers anything.
4. **Gate-time re-derivation (EB-GATE-1/5).** The execute-bolts PreToolUse gate re-runs all six bolt-stage/quality validators (orphans, B2, B1, B3 whitelist, ui-quality, cross-cutting, factory-ledger) before the aggregator reads their states — a forged, stale, or absent state is overwritten with current truth.
5. **Obligation stickiness (EB-GATE-8).** B1 reads the unit's `task_type`/`## Hard rules` from the BOLT COMMIT (`git show`), falling back to the working tree only for untracked vaults.
6. **B3 whitelist observer (EB-GATE-11).** `--whitelist-scan` diffs each bolted unit's committed paths against `target_files` ∪ sanctioned extras (vault/bolt artifacts, `.mega-sdd/`, `docs/mega-sdd/`, `*-bound/`, test-file shapes); escapes block the next run with `whitelist_violation` (state `.bolt-whitelist-state.json`, guarded like its siblings).
7. **Layout + monorepo coverage (EB-VAL-2/5).** Unit/report/postflight/_batch-suite lookups go through `scripts/_lib/vault_layouts.py` (mirrors validate-unit-spec discover_units; pinned by test); git walks are pathspec-scoped to `git rev-parse --show-prefix` and the code-file filter excludes the legacy vault trees.
8. **Root resolution (EB-GATE-6).** `resolve_project_root` returns the nearest SUBSTANTIVE `.mega-sdd/` ancestor (vaults/ | knowledge-base/ | codebase/ | config.yaml); pure state-litter roots never shadow the true root; read-side validators SKIP (never mkdir) when no `.mega-sdd/` exists at the resolved root.
9. **Commit topology (EB-GATE-3).** One truth, everywhere: the implementer commits after tests pass; L0 gates / panel / post-flight are detect-after. All halt texts (incl. `secret_in_code`) describe committed-state remediation.
