---
type: prose
doc_id: 04-flows
vault_version: "1.0"
---

# 04 — Flows (demo-phase)

## User Flows

### F-U-001 — Widget Approval (4-stage Maker->Checker->Confirmer->Dispatcher)

**Actors**: Maker, Checker, Confirmer, Dispatcher

**Steps**:

1. **Maker intake** (`POST /widget/initiate`):
   - Creates a `widgets` row, workflow_state=`DRAFT` then `SUBMITTED`.

2. **Checker review** (`POST /widget/{id}/approve`):
   - Dual-key re-entry of `amount`. workflow_state -> `APPROVED`.

3. **Confirmer confirm** (`POST /widget/{id}/confirm`):
   - Final confirmation. workflow_state -> `CONFIRMED`.

4. **Dispatcher dispatch** (`POST /widget/{id}/dispatch`):
   - Dispatch the confirmed widget. workflow_state -> `DISPATCHED`.

**Post-conditions**:
- 1 widgets row with workflow_state=`DISPATCHED`.
