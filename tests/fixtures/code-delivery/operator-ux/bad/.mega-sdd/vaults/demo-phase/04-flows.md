---
type: prose
doc_id: 04-flows
vault_version: "1.0"
---

# 04 — Flows (demo-phase)

## User Flows

### F-U-001 — Widget Approval (Maker -> Checker -> Confirmer)

**Actors**: Maker, Checker, Confirmer

**Steps**:

1. **Maker intake** (`POST /widget/initiate`):
   - Creates a `widgets` row, workflow_state=`DRAFT` then `SUBMITTED`.
   - Server recomputes totals.

2. **Checker review** (`POST /widget/{id}/approve`):
   - Server-side dual-key validation: re-entry of `amount`.
   - workflow_state -> `APPROVED`.
   - Reject path: action=`CHECKER_REJECT`, returns to Maker.

3. **Confirmer confirm** (`POST /widget/{id}/confirm`):
   - Final confirmation before dispatch.
   - workflow_state -> `CONFIRMED`.

**Post-conditions**:
- 1 widgets row with workflow_state=`CONFIRMED`.
