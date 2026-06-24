---
description: Reconcile mega-sdd state with the latest code — the never-ending-development lane. Detects what changed since the last scan (in-session AI edits via the dirty journal + manual/external edits via git), then chains incremental re-scan → drift detect → re-bind → unit reconcile. Use after manual edits, AI-prompted changes outside the pipeline, hotfixes, or a git pull — whenever "the code moved on" and the vault/map/binding/units must catch up.
argument-hint: "[--dry-run] [--auto] [--auto-apply=safe] [--memory-off] [--no-drift-check]"
---

Invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--sync` (plus user flags below).

User arguments: $ARGUMENTS

What this does (per `orchestrate-flow/references/routing-rules.md` §Mode D and spec `docs/superpowers/specs/2026-06-10-living-vault-continuous-sync-design.md`):

1. **Detect change** — union of two channels: `.mega-sdd/codebase/.dirty-paths.jsonl` (in-session Write/Edit journal, even uncommitted) + `git diff --name-only <last_scanned_commit>..HEAD` + uncommitted working-tree changes.
2. **Incremental re-scan** — `scan-codebase --changed-only` merges only the changed paths into the existing map (full scan fallback when preconditions absent).
3. **Drift triage** — `detect-drift` scoped to the changed paths; findings stay direction-neutral (code right vs vault stale).
4. **Re-bind + reconcile** — `bind-codebase --paths=@<changed-paths>` re-verdicts only affected claims (active CONFLICTs always re-validated, never carried silently); `generate-units --reconcile` updates existing unit IDs in place (task_type flips, `status` recomputed via `scripts/compute-unit-staleness.sh`, vanished claims → `superseded`, never duplicates); `execute-bolts` runs only stale/new units (`superseded` skipped).

Flags:
- `--dry-run` — show the change summary + proposed chain without executing
- `--auto` — fully autonomous: ONE upfront confirmation, then NO mid-chain questions (decision deferral — see below)
- `--auto-apply=safe` — opt-in: auto-apply the SAFE write-back class only (confidence HIGH + category ∈ name-drift/type-drift/missing-in-vault + claim NOT `[LOCKED]` + code side committed — definition OWNED by detect-drift Step 5; this line mirrors it); everything else queues
- `--memory-off` / `--no-drift-check` — standard opt-outs (passed through)

Autonomous behavior (`--auto` — decision deferral, per spec §3.7):
- Safe operations run through: scan merge, claim-scoped re-bind, unit reconcile, stale/new bolt execution (every existing bolt gate intact).
- Human-required decisions NEVER pause the chain — they queue into `<vault>/PENDING-SYNC.md` (drift direction calls, write-back drafts, re-bind CONFLICTs). CONFLICTs still close the gate for the affected downstream units (the moat is untouched); the chain completes everything else and reports.
- End of run: `<vault>/SYNC-REPORT.md` — change counts, per-phase outcomes, applied-vs-queued patches (with git provenance), conflicts raised, units reconciled/re-executed, and the closing staleness verification (`scripts/compute-unit-staleness.sh` re-run; stale count MUST be 0 or explained). One chat line summarizes; the report carries the detail; refreshes `.mega-sdd/graph.json` (cache-warm; non-blocking).
- Next session, the staleness notice clears; if PENDING-SYNC.md has open items, the notice points there instead.
- Memory (unless `--memory-off`): one `kind: sync` row appended to project-scope `outcomes.md` (channel mix, applied-vs-queued tally, accept/reject of safe write-backs, closing staleness); drift direction calls land in `<vault>/.memory/drift-history.md`. After ≥3 consistent runs the chain-end learning pass MAY suggest defaulting `--auto-apply=safe` — applied only on explicit ACCEPT via `/mega-sdd:memory review`.

Hard rails:
- Git state first: repo mid-rebase/merge (probe `git rev-parse --git-path rebase-merge` / `--git-path MERGE_HEAD` — worktree-safe; never the literal `.git/...` path) → STOP with "resolve the git state, then re-run sync" (a map scanned mid-conflict is garbage).
- The binding CONFLICT gate applies unchanged — sync never bypasses the moat.
- The dirty journal is a HINT; git is always consulted too. Journal truncated only after a successful map write.
- No change signal detected → report "in sync" and stop (no vacuous re-runs).
