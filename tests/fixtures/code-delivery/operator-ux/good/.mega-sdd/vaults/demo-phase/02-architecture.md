---
type: prose
doc_id: 02-architecture
vault_version: "1.0"
---

# 02 — Architecture (demo-phase)

## Stack

`web-app`. Server-rendered views + a table-driven workflow state machine.

## Workflow engine

The Widget entity carries an explicit `workflow_state` enum. State transitions
are validated server-side (dual-key separation of duties on the Checker stage),
and every transition appends a row to `workflow_transitions`.

## Operator-facing surface (modeled as first-class requirements)

Grounded in the F-U-001 multi-stage approval flow, the operator surface is
modeled explicitly:

- **Worklist / inbox** — `resources/views/widget/worklist.blade.php`: each
  actor (Checker, Confirmer) sees the items awaiting their decision in the
  current `workflow_state`, filtered by their role.
- **Decision affordance** — the show/review page exposes the approve / reject
  actions the actor can take in the entity's current state
  (`availableActions(Widget, User)` drives the buttons).
- **Human-readable state labels** — `workflow_state` enum values map to a
  human label map (DRAFT -> "Draft", SUBMITTED -> "Awaiting Checker", etc.).
- **Audit timeline** — the show page renders the append-only
  `workflow_transitions` audit history (who acted, when, prior -> next state).

```
resources/views/widget/{index,create,edit,show,worklist,review}.blade.php
app/Http/Controllers/WidgetController.php
app/Models/Widget.php
```
