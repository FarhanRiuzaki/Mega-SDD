# Factory Ledger — Checkpoint Contract

The factory ledger is a **derived**, project-scope, append-only record of what each pipeline phase did, so the router can route forward OR backward (per `factory-routing.md`). It is NOT a source of truth: it is rebuildable from per-phase handoffs/artifacts.

## File

`.mega-sdd/factory-ledger.json` — a JSON array of checkpoint records, one per phase-attempt. Validated by `scripts/validate-factory-ledger.sh` (which writes the verdict `.mega-sdd/.factory-ledger-state.json`). Git-ignored runtime state.

## Record schema

```yaml
- phase: plan                     # emitting skill (handoff.emitted_by, or the blocker envelope's emitted_by for plan)
  attempt: 1                      # increments per re-run of this phase; basis of the retry cap
  emitted_at: 2026-06-25T10:05:00Z
  status: unresolved              # completed | unresolved | halted
  # confidence: 0.72              # optional — handoff.next_action.confidence (0..1); plan emits no handoff, so its record omits it
  did:                            # concise "what I did" — for a downstream phase to read
    - "Wrote context.md + 18 units; 1 P1 business OQ open"
  unresolved:                     # drives BACKWARD routing; [] when green
    - id: OQ-007                  # MUST be anchored: CONFLICT-N | OQ-N | file:line
      kind: oq                    # conflict | oq | low_confidence | missing_input
      blocks: [execute-bolts]     # downstream phase(s) this item blocks
      note: "refund window absent from KB modules/billing.prd.md §4"
  artifacts: [".mega-sdd/vaults/v1/context.md", ".mega-sdd/vaults/v1/units/_index.md"]   # = handoff.artifacts, or the files plan wrote
  consumed: [extract-intelligence@1]   # the KB a plan --kb=<kb-dir> read (query trail)
```

## Rules

- **Anchored unresolved (hard).** Every `unresolved[].id` MUST match `CONFLICT-N`, `OQ-N`, or `file:line`. An unanchored item is a schema FAIL (mirrors evidence-or-drop / no-fabrication). No "feels incomplete" without evidence.
- **Ownership.** An `unresolved` item is cleared by re-running the OWNING phase (the phase whose checkpoint the item lives in). A human-only underlying OQ/CONFLICT is resolved first, then the owning phase re-runs.
- **Append-only.** A re-run appends a new record with `attempt+1`; never mutate a prior record.
- **Emission.** Each phase appends its record as the final step of its handoff (the same data it already emits in the handoff YAML, plus `did` / `unresolved` / `consumed`). See `handoff-contract.md`.
- **Derived / rebuildable.** If the ledger is missing or unparseable, the router rebuilds it from each phase's handoff + artifacts before routing (see `factory-routing.md` §Rebuild).
