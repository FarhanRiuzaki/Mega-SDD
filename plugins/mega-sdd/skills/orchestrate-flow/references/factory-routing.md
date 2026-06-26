# Factory Routing — State-Driven Forward/Backward Loop

Extends the `orchestrate-flow` execution loop so routing reads the WHOLE factory ledger (`factory-ledger-contract.md`), not just the last handoff — enabling backward re-runs. Active under `--deep` (and the explicit `--factory` flag). Reuses `convergence-loops.md` (loop) + `halt-taxonomy.md` (halt classes).

## One iteration

```
1. read .mega-sdd/factory-ledger.json → status map of all phases (latest attempt each)
   (if missing/unparseable → REBUILD, see below)
2. collect all unresolved[] across all latest-attempt records
3. pick ONE next action (priority order):
   a. an unresolved item that `blocks` a downstream phase?
      → target = the OWNING phase (where the item lives); route BACKWARD.
        (human-only underlying OQ/CONFLICT resolved first, then owning phase re-runs)
   b. else, a downstream phase not yet run?
      → target = next downstream phase; route FORWARD.
        Feed its dispatch the relevant upstream checkpoints (the `did`/`artifacts` of phases it `consumed`).
        If a needed upstream checkpoint is ambiguous/missing → bounded LIVE-ESCALATION:
        re-dispatch that one upstream phase, at most 1× per (phase, attempt); still ambiguous → HALT.
   c. else (all phases completed & all unresolved empty) → CONVERGED → done; emit summary.
4. safety checks BEFORE dispatching target. The first two are ENFORCED deterministically by
   the PreToolUse backward-dispatch gate: it recomputes `validate-factory-ledger.sh` on every
   re-dispatch of an upstream phase and BLOCKS the dispatch when THAT phase is already in
   cap-breach / spin-breach — so the loop cannot run hot even if this prose is skipped
   (resetting the rebuildable ledger self-clears the gate; see Rebuild below). The third check
   is prose-only — a human-judgment class the hook cannot adjudicate:
   - [hook-enforced] attempt(target) >= cap (default 3) and not completed → HALT phase_stuck → escalate to human.
   - [hook-enforced] identical unresolved id-set recurred with no progress → HALT anti_spin.
   - [prose-only] item is an always-stop / human-only class (business OQ P1, constitution drift; see halt-taxonomy.md)
     → PAUSE; never force-loop.
5. dispatch target → phase appends a new checkpoint (attempt+1) → goto 1.
```

## Rebuild (derived ledger)

If `factory-ledger.json` is absent or `validate-factory-ledger.sh` reports `ledger_unparseable`: reconstruct it by reading each phase's last handoff (`handoff-contract.md`) + its artifacts, emitting one `completed` record per phase that has artifacts and an empty `unresolved`. Then re-run the validator. The ledger is never a single point of failure.

## Termination (three ways)

- **Converged** — all latest records `completed` + `unresolved: []` → `status: done`.
- **Cap hit** — a phase fails to go green within `cap` attempts → `phase_stuck` halt + a concrete human question. The PreToolUse backward-dispatch gate then BLOCKS re-running that capped phase (so the loop can't spin). **Recovery:** resolve the underlying blocker, then RESET the rebuildable ledger (`rm .mega-sdd/factory-ledger.json` — it rebuilds from phase handoffs, which clears the stale per-phase attempt history) before `--resume`. The reset is what lets the recovered phase re-run; a bare `--resume` against the still-capped ledger is intentionally blocked.
- **Always-pause** — human-only decisions pause; not force-looped.

## Boundaries

- **Vertical only.** This governs phase↔upstream-checkpoint routing. The `execute-bolts` blind reviewer panel is untouched — reviewer independence is its own precision rail.
- **No free-form chat.** All cross-phase information flows through the structured checkpoint records + the bounded live-escalation; never an open conversation between phases.
