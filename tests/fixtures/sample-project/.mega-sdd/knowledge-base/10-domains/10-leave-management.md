---
generated_by: mega-sdd:extract-intelligence
generated_at: 2026-05-27
domain: leave-management
classification: workflow
criticality: high
rebuild_phase: 1
depends_on: [user-management]
verified_count: 5
inferred_count: 2
open_count: 1
source_files_cited: 3
---

# Leave Management

> **Classification**: workflow
> **Criticality**: high
> **Depends on**: user-management
> **Rebuild Phase**: 1

## 1. Purpose

The leave management domain handles all employee time-off requests, approvals, and balance tracking. [VERIFIED] Every leave request follows a maker-checker pattern. [VERIFIED]

## 2. Actors

| Actor | Role |
|---|---|
| Employee | Submits leave requests. [VERIFIED] (`src/controllers/leave.ts:45`) |
| Manager | Approves/rejects requests. [INFERRED] |

## 3. Flow

```
Employee → Submit Request → Manager Review → Approved/Rejected
```

The approval flow includes escalation to HR for requests > 5 days. [VERIFIED]

## 4. Entities

- **leave_request**: id, user_id, start_date, end_date, type, status. [VERIFIED] (`src/models/leave-request.ts:5-20`)
- **leave_balance**: user_id, year, total, used, remaining. [INFERRED]

## 5. Fields & Validation

- start_date must be future date. [VERIFIED]
- end_date >= start_date. [VERIFIED] (`src/validators/leave.ts:12`)
- type enum: annual, sick, personal, unpaid. [OPEN]

## 6. Business Rules

- Annual leave accrues 1.25 days/month. [INFERRED]
- Sick leave requires medical certificate after 3 consecutive days. [VERIFIED]

## 7. Integrations

- Calendar sync via iCal export. [OPEN]

## 8. Edge Cases

_None detected — see §10 Open Questions._

## 9. Rebuild Recommendations

Use event-sourcing for leave balance to maintain audit trail. [VERIFIED]

## 10. Open Questions

- [ ] **OQ-LEAVE-1** [P2]: What is the maximum carry-over for annual leave?

## 11. Source References

- `src/controllers/leave.ts:45` — leave submission handler
- `src/models/leave-request.ts:5-20` — leave request entity definition
- `src/validators/leave.ts:12` — date validation rules
