# Learning Loop — closing the wasted-output gaps (v4.15)

**Status: SHIPPED** · Builds on the memory layer (`skills/memory/`) and the Living Vault spec (`2026-06-10-living-vault-continuous-sync-design.md`).

## Problem

The pipeline produces outcome data on every run, but several skills discard it: detect-drift and the sync lane write NO memory at all; execute-bolts drops the *why* of failures (only the resolution enum survives) and discards per-bolt `acceptance_test_concerns` after the handoff summary; pattern aggregation is implied by `learning-rules.md` thresholds but no step owns running it. Result: the user re-answers the same drift direction calls, bolts repeat the same failure classes, and suggestion thresholds are never actually evaluated.

Research basis (2026-06-10, see git): Anthropic memory-tool guidance (view-first protocol, secret hygiene, size tracking), Anthropic long-running-harness findings (JSON for model-mutable state; verify-then-record), Reflexion (arXiv:2303.11366 — persisted failure reflections improve later attempts), GSD extract-learnings (capture as an owned pipeline step), Letta (small curated context slices over raw tails), aider (cache entries versioned by extractor logic).

## Doctrine (unchanged — the moat)

**Capture is automatic; behavior change is suggestion-gated.** Observational facts (what happened, with `source_run` citation) append automatically. Anything that changes how mega-sdd acts next time goes through `/mega-sdd:memory review` ACCEPT — never auto-applied. CONFLICTs and drift direction calls are NEVER auto-resolved from memory; memory may only PRE-FILL a suggested answer with provenance. Current evidence always wins over memory.

## Slices

### L1 — detect-drift learns (vault scope: `.memory/drift-history.md`)

- **Write (auto):** per run, one summary row (findings by category × confidence, scope, source_run). Per finding the user resolves: one row with a **fingerprint** (`<category>:<vault-section>:<normalized-name>`), the direction chosen (`code_right | vault_stale | deferred`), and provenance.
- **Read (suggestion only):** at Step 5, if the SAME fingerprint class has ≥3 same-direction resolutions, show that direction as a pre-filled suggestion (`source: drift-history, n=N`) — exactly the §2.2 CONFLICT-pattern mechanic. Under `--auto`, this NEVER upgrades to auto-resolve; it is queued into PENDING-SYNC.md with the suggestion attached.

### L2 — sync runs learn (project scope: `outcomes.md` `kind: sync` rows)

- **Write (auto):** orchestrate-flow Mode D appends one `kind: sync` row per run: channel mix (journal/git), per-phase outcome counts, applied-vs-queued patch tally, `--auto-apply=safe` accept/reject tally, closing staleness.
- **Read (suggestion only):** when the last N≥3 sync runs each queued ≥1 write-back of the same safe class that the user later ACCEPTed unchanged, surface ONE suggestion: "default `--auto-apply=safe`?" — config flip happens only on explicit ACCEPT (it widens the autonomy surface).

### L3 — Reflexion failure memory (vault scope: `bolt-outcomes.json`)

- On every bolt retry or halt, persist `failure_reflection`: a one-line root-cause from the fix-proposer ("mock for X missing because the unit's anchor predates the rename"), alongside the existing resolution enum. JSON, not markdown (model-mutable state).
- Pre-execution read (already exists for outcomes) now also surfaces the reflections of (a) this unit's past attempts and (b) sibling units in the same module — so retry N+1 and neighboring bolts start with the *why*, not just the *what*.

### L4 — acceptance_test_concerns persist (vault scope: `bolt-outcomes.json`)

The per-bolt concerns execute-bolts already harvests into `_summary.md` are ALSO appended to `bolt-outcomes.json` (`concerns: [...]`), so cross-vault recurrence can reach a learning threshold instead of dying with the handoff.

### L5 — extract-learnings is an owned step (orchestrate-flow Step 7.6)

After the Step 7.5 routing-outcomes write, the orchestrator runs the threshold pass from `learning-rules.md §2` over the rows touched this chain and appends any threshold-crossing candidates to the user-scope `patterns.md` under `## Pending suggestions` (status `pending`; `learning-log.md` stays the audit trail of ACCEPT/REJECT decisions). `/mega-sdd:memory review` remains the only path from pending → applied. No thresholds evaluated mid-chain; once, at chain end.

### L6 — `_index.md` per memory scope

Each scope dir gains a script-maintained `_index.md`: per file — row count, last-entry date, one-line "current state" summary, and open pending-suggestion count. Updated by the orchestrator at its batched-write point (single I/O point unchanged). Chain-start reads consult the index first and open only the files the chain needs (just-in-time, not preload).

### L7 — memory hygiene rails

- **Secret scan on write:** every memory append runs `scripts/secret-scan.sh --check` on the content first; findings → the value is redacted (`[REDACTED-SECRET]`) before append. Memory files are git-tracked; this is non-negotiable.
- **Size threshold:** any memory file > 256 KB triggers a prune *suggestion* (never auto-prune) in the next `_index.md` update.
- **Detector versioning:** convention entries record the `scan-codebase` skill version that detected them; a heuristic upgrade invalidates the skip (re-detect), mirroring aider's cache-version bump.

## Non-goals

- No vector stores, no embeddings, no new runtime dependencies.
- No new always-loaded context (slices stay filtered per `memory-layer.md`).
- No change to the binding gate, halt taxonomy, or PENDING-SYNC contracts.
- `--memory-off` continues to disable ALL of the above per scope.

## Test obligations

- Contract pins (grep-based, like `tests/moat/`): drift-history fingerprint format; "never auto-resolve from memory" sentence present in detect-drift Step 5; L5 step exists and is threshold-once-at-chain-end; secret-scan-on-write rule present in memory-layer.
- `tests/skill-triggering/` — trigger descriptions untouched by this change; existing tests remain valid. Contract pins live in `tests/learning-loop/test-contract-pins.sh` (17 pins).
