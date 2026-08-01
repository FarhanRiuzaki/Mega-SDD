# Squad Fan-Out (main-thread loop)

How `execute-bolts --per-squad` executes every declared squad's units while the
controller stays in the **main thread** — preserving the per-unit review panel.

## When this applies

- Flag `--per-squad` is set on `execute-bolts`
- `_meta/squads.yaml` exists with ≥2 squads

## Topology — a main-thread loop, NOT a squad subagent

Subagents cannot spawn subagents (hard depth-1 limit enforced by the runtime; a
dispatched plugin agent has no `Agent`/`Task` tool). The per-unit flow already
dispatches the first-class agents — `bolt-implementer` then the review-panel
lenses (see `superpowers-bridge.md` + `review-panel.md`). If a **squad subagent**
were the per-unit controller, it would have to dispatch those agents = **depth-2 =
forbidden**; in practice it would silently degrade to inline implementation,
**losing the review panel** (the moat's quality enforcement). So the controller
**NEVER forks a squad subagent.**

Instead the **main-thread controller** iterates squads and runs the SAME per-unit
flow directly (depth-1). **Parallelism** is achieved by the controller issuing
multiple `bolt-implementer` Agent calls **concurrently** across squads' independent
units — depth-1 AND parallel, no tradeoff. This is the same mechanism as
`--all --parallel` (see `batch-and-fanout.md`); `--per-squad` only changes the
*filter* (group by `squad:`) and the *consolidation* (per-squad reporting).

## Procedure

1. **Load `_meta/squads.yaml`.** Build the squad list (≥2 squads, else halt per
   SKILL.md Procedure step 1 — see Single-squad fallback below).
2. **Per squad — filter + interface check.** For each declared squad: select
   `units/U-*.md` where frontmatter `squad: <id>`. For each selected unit with
   `consumes_interfaces`, verify each listed interface is `status: locked`; any
   `draft` → HALT `cross_squad_interface_draft` (squad-attributed) and stop.
3. **Build the working set.** Union the squads' filtered units; topo-sort within
   each squad by `depends_on` (cross-squad deps are interfaces, not `depends_on`,
   by validation).
4. **Dispatch the per-unit panel flow from the MAIN THREAD** (the per-unit flow
   in `superpowers-bridge.md`). Parallelize by dispatching **independent units —
   including units from different squads — concurrently** (multiple `bolt-implementer`
   Agent calls in one message), bounded by an in-flight cap (default **5** concurrent
   implementers — the same bound `--all --parallel` uses, `batch-and-fanout.md §--all`;
   a wider set dispatches in cap-sized slices). **Independent =
   no `depends_on` edge AND pairwise-disjoint `target_files`** — cross-squad units
   have no dependency edges by design (step 3), so the whitelist-overlap check is the
   only rail against two squads clobbering a shared file; intersecting units serialize.
   Every unit still goes `bolt-implementer` → the review panel (per `review-panel.md`).
   **Never skip the review on a parallel unit.**
5. **Re-scan after each batch.** Run the project-wide quality validators against
   `$PROJECT_ROOT` (defense-in-depth, per `hard-rule-scan.md` §Parent-thread re-scan)
   so gate state is deterministic regardless of concurrent write ordering.
6. **Consolidate** (below).

## Consolidation

After all units across all squads finish (or halt), the controller:

1. Collects per-squad results.
2. Builds a single summary table:

   ```
   Squad             Units run   Commits   Status
   ─────────────────────────────────────────────
   squad-be            12          12      OK
   squad-fe-web         8           7      HALT (test_fail on U-FE-005)
   squad-integrations   4           4      OK
   ─────────────────────────────────────────────
   Total:              24          23      1 halt
   ```

3. Lists each blocker verbatim (squad-attributed).
4. Surfaces to the user for resolution.

## Failure isolation

Squads' units are independent (cross-squad coupling is via locked interfaces, not
`depends_on`). A unit halt in one squad does NOT invalidate another squad's completed
bolts and does NOT auto-advance past the halt within its own squad (the standard
"any failure halts the batch — no skip-ahead" rule applies per squad). Units already
in flight complete; the controller surfaces all halts together at the end. Each unit
writes its own bolt-report + halt artifacts; the controller aggregates.

## Single-squad fallback

If the user passes `--per-squad` but only one squad is declared: halt early (per
Procedure step 1 in SKILL.md). Don't loop over a single squad for no benefit — use
plain `--all` (optionally `--all --parallel`).
