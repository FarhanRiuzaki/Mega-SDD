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
are validated server-side (dual-key separation of duties on the Checker stage).

## Component surface

This vault enumerates the CRUD scaffold for the Widget entity:

```
resources/views/widget/{index,create,edit,show}.blade.php
app/Http/Controllers/WidgetController.php
app/Models/Widget.php
```

`WidgetController` exposes the standard resource actions (index, create, store,
show, edit, update, destroy). Validation rules live in `WidgetRequest`.
