# Graph-assisted reconcile — the graph becomes a chain input (transitive dependents + triage ordering)

**Date:** 2026-08-12
**Status:** SHIPPED v6.12.0 (2026-08-12, 33dd278, CI green, suite 227/227) — user "gas" on the audit recommendation (#1 + #2); adversarial round executed INLINE (subagent API 529-overloaded ×3 — disclosed, not skipped): multi-vault cross-contamination MAJOR live-proven + folded (vault-scoped resolve), cycle termination + freshness auto-rebuild live-proven
**Source:** USER audit question "penggunaan graph di mega-sdd sudah optimize belum? apakah hanya jadi pajangan? harusnya digunakan untuk membantu Claude" → inline audit verdict: graph engineering sound (lazy hash-checked rebuild, zero inferred edges, behavior tests) but its ONLY decision consumer is the user-invoked `/graph` skill — **no chain decision reads it**. This ship gives it two chain consumers.
**Version:** 6.12.0 (minor).

## Why (no-gimmick)

The reconcile pass (`task-typing.md §Reconcile pass` step 2) marks a unit `stale` ONLY when its OWN `target_hashes` drifted. A unit whose *dependency* changed — its own files untouched — stays `implemented`, its bolt never re-verifies, and an integration break ships silently. The graph already carries the exact edge needed (`depends_on: unit → unit`, reverse-traversed by the downstream query) — the machinery exists, nothing calls it. Cost: one bounded script call per reconcile; graph absence degrades to today's behavior.

## D1 — transitive-dependents expansion (delta lane + sync reconcile)

- NEW `scripts/derive-transitive-impact.sh --vault=<dir> --project=<root> --units=<csv of changed unit ids>`:
  - Freshness: the same hash-checked lazy rebuild `query-graph.sh` uses (rebuild `graph.json` only when the source set moved).
  - Traversal: reverse-`depends_on` closure over UNIT nodes only (deterministic BFS; `honors`/claim edges deliberately out of scope — directly-affected units already come from the binding).
  - Output: JSON `{"graph_available": true|false, "input": [...], "transitive": [...], "reason": "..."}` — `transitive` excludes the input set, sorted. **Exit 0 always** (2 on usage): graph unbuildable/absent → `graph_available: false`, empty `transitive`, stated reason — **fail-open, the lane never blocks on the graph** (a lens, never a gate — the graph skill's own doctrine).
- Consumption (ADVISORY, no state-model change — no new `status:` enum value, no gate edit):
  - `task-typing.md §Reconcile pass` gains **step 2.6**: after status re-computation, run the script with the units whose status changed (stale/superseded/task_type-flipped); units in `transitive` that are currently `implemented` are surfaced as **"verify-recommended (transitive impact)"** — listed in `SYNC-REPORT.md` / the delta handoff, and offered alongside stale/new bolts at the re-execution step (a `verify` re-run is cheap). Human confirms per the propose-first doctrine; declining changes nothing.
  - `routing-rules.md §Delta lane`: one sentence — the reconcile step carries the transitive list into the handoff.
- **The moat is untouched**: staleness stays hash-deterministic; `stale` is never assigned from graph data; CONFLICT/binding gates unchanged.

## D2 — drift triage ordering (advisory)

`commands/sync.md`: the drift triage processes changed paths in **descending blast-radius order** when the graph is available (largest downstream first — the call most likely to need a human lands earliest, not last); graph absent → document order, unchanged. Pure ordering; no outcome changes.

## Proof tests

NEW `tests/graph-impact/test-derive-transitive-impact.sh`: fixture vault (3 units: U-001 ← U-002 ← U-003 via `depends_on`, U-004 isolated) + real `build-graph.sh` sources; arms — (a) `--units=U-001` → transitive `[U-002, U-003]`, input excluded; (b) `--units=U-004` → empty; (c) graph sources absent → `graph_available:false` exit 0 (fail-open); (d) usage → exit 2; (e) determinism (two runs byte-equal); (f) `bash -n`. Doc pins: step 2.6 present + fail-open wording + "verify-recommended" phrasing; delta-lane sentence; sync triage-ordering line; no new `status:` enum value anywhere (negative pin).

## Non-goals

No new status enum; no gate reads the graph; no bolt-dispatch enrichment (deferred — golden-corpus + token cost, audit #3); no graph schema change; `/graph` skill untouched.
