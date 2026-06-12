# Compaction advisor + PreCompact snapshot — ECC-adoption Batch 2

**Date:** 2026-06-12 · **Research:** ECC review (skills/strategic-compact, hooks/memory-persistence)
**Scope:** (A) phase-aware compaction advisor — suggest `/compact` from TRUE context size at pipeline phase boundaries; (B) PreCompact snapshot — capture pipeline state before the harness compacts.

## Why

mega-sdd chains are long (the clinic sync ran 26 min). Two failure modes:
- **Compaction mid-bolt is destructive** — the controller loses the unit's target-files whitelist / dispatch context mid-implementation. The right moment to compact is a phase boundary (after bind before units; after a bolt before the next), never mid-step.
- **Auto-compaction loses pipeline state** — the harness compacts on its own schedule; if it fires mid-chain, the next window has no idea which phase/unit was in flight.

ECC's contributions: read the REAL context size from the transcript `usage` (not a tool-count proxy), suggest compaction at window-scaled thresholds; and a PreCompact hook that snapshots first.

## A. Phase-aware compaction advisor (Stop hook, advisory)

The Stop hook already extracts transcript `usage`. Extend it: sum `input_tokens + cache_read_input_tokens + cache_creation_input_tokens` = true context size. Window scale detected from the model marker (`[1m]` → 1M window, else 200k). Threshold = 80% of window (160k / 800k). When over AND a mega-sdd chain is active (a recent `turn_end_marker`/handoff in telemetry, or a vault with in-flight units), append ONE advisory line to the Stop output:

> `mega-sdd: context ~Nk of ~Wk (M%). A phase boundary is the safe place to /compact — pipeline state is snapshotted on compaction.`

Re-reminds every +40k. Pure advisory (Stop can't block); never fires for non-mega-sdd projects or below threshold. Opt-out `compaction_notice: false`.

## B. PreCompact snapshot (new hook)

New `hooks/pre-compact` on the PreCompact event (matcher `manual|auto`). Writes `.mega-sdd/.compaction-snapshot.json`: timestamp, trigger (manual/auto), git HEAD, the in-flight phase guess (newest vault + its unit/bolt counts: units total, bolts done, last bolt-report unit), and any open PENDING-SYNC count. Cheap, pure reads, exit 0 always (a snapshot must never block compaction). SessionStart (already injects staleness) gains one line when a fresh snapshot exists and HEAD moved since: "mega-sdd: resumed after a compaction at <phase> — N units, M bolts done; re-orient from .compaction-snapshot.json." Opt-out shares `telemetry: false`.

## Doctrine

Both are advisory context, not gates (compaction is the user's call; state capture is insurance). No PreToolUse surface added. PreCompact is a NEW event wiring — additive, isolated, never blocks. Reuses the existing transcript-usage extractor (no new parsing surface).

## Files

Create: `hooks/pre-compact`, `tests/compaction/*`.
Edit: `hooks/hooks.json` (PreCompact event), `hooks/stop` (advisor line), `hooks/session-start` (resumed-after-compaction line), `project-config.md` (`compaction_notice:`), `references/telemetry-schema.md` (snapshot + advisor event), CHANGELOG + 4.27.0.

## Acceptance

- Advisor: over-threshold + active chain → one line; under → silent; non-mega-sdd → silent; opt-out honored.
- PreCompact: fixture vault → snapshot JSON with phase guess + HEAD; exit 0 even on malformed vault.
- All hooks `bash -n`; `claude plugin validate`; full pin regression green.
