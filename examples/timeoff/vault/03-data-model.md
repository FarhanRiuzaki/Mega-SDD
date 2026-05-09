# 03 — Data Model

> **TL;DR**: DBML schema with inline notes per field — entities, relations, constraints derived from PRD AC · audience: BE Dev, DBA, Architect · read when designing schema or migrations.

## Entities (DBML)

```dbml
// === Multi-tenancy root ===
Table tenant {
  id bigint [pk, increment]
  name varchar [note: 'company name']
  fiscal_year_start_month int [default: 1, note: 'configurable; default Jan — PRD §H Multi-fiscal-year']
  weekend_days varchar [default: 'sat,sun', note: 'configurable per tenant — PRD §H Working-day calculation']
  default_timezone varchar [note: 'IANA TZ name, e.g. Asia/Jakarta']
  stripe_subscription_id varchar [null, note: 'Stripe ref; null in trial']
  status varchar [note: '"active" | "trial" | "suspended" — exact enum TBD: OQ-DM-7']
  created_at timestamp
  updated_at timestamp
}

Table user {
  id bigint [pk, increment]
  tenant_id bigint [ref: > tenant.id]
  email varchar [unique]
  full_name varchar
  role varchar [note: '"employee" | "manager" | "hr_admin" | "super_admin" — PRD §H Role-based access']
  manager_id bigint [ref: > user.id, null, note: 'employee → direct manager']
  timezone varchar [note: 'IANA TZ; per-user override of tenant default — PRD §H Time zone']
  sso_provider varchar [null, note: '"google" | "oidc" | null (password fallback)']
  password_hash varchar [null, note: 'set only when sso_provider is null — see OQ-DM-1']
  status varchar [note: '"active" | "deactivated" — see OQ-DM-2']
  created_at timestamp
  deactivated_at timestamp [null, note: 'soft-delete; required for compliant data deletion — PRD §I Compliance']
}

// === Leave policy & entitlement ===
Table leave_type {
  id bigint [pk, increment]
  tenant_id bigint [ref: > tenant.id]
  name varchar [note: 'e.g. "Annual Leave", "Sick Leave"']
  default_annual_entitlement_days decimal [note: 'working days; supports half-day if Q1 resolved as yes']
  accrual_rule varchar [note: 'TBD per PRD §L Q2 — annual lump sum vs monthly accrual']
  created_at timestamp
}

Table public_holiday {
  id bigint [pk, increment]
  tenant_id bigint [ref: > tenant.id]
  date date
  name varchar
  Indexes {
    (tenant_id, date) [unique]
  }
}

Table leave_balance {
  id bigint [pk, increment]
  tenant_id bigint [ref: > tenant.id]
  user_id bigint [ref: > user.id]
  leave_type_id bigint [ref: > leave_type.id]
  fiscal_year int [note: 'e.g. 2026']
  total_entitlement_days decimal [note: 'effective entitlement for this period; may be prorated']
  used_days decimal [default: 0, note: 'sum of approved leave days']
  pending_days decimal [default: 0, note: 'sum of pending leave days']
  Indexes {
    (user_id, leave_type_id, fiscal_year) [unique]
  }
}

Table balance_audit_log {
  id bigint [pk, increment]
  tenant_id bigint [ref: > tenant.id]
  leave_balance_id bigint [ref: > leave_balance.id]
  performed_by_user_id bigint [ref: > user.id, note: 'HR admin who triggered override']
  before_value decimal
  after_value decimal
  reason varchar [note: 'mandatory per PRD AC4-4']
  created_at timestamp
}

// === Leave request lifecycle ===
Table leave_request {
  id bigint [pk, increment]
  tenant_id bigint [ref: > tenant.id]
  requester_user_id bigint [ref: > user.id]
  leave_type_id bigint [ref: > leave_type.id]
  start_date date
  end_date date
  working_days decimal [note: 'computed at submission; weekends + public holidays excluded']
  reason_note varchar [null, note: 'max 500 chars per AC1-1']
  status varchar [note: '"pending" | "approved" | "rejected" | "cancelled" — PRD §G US-1, US-2, US-5']
  approver_user_id bigint [ref: > user.id, null, note: 'manager or active delegate']
  decision_at timestamp [null]
  decision_reason varchar [null, note: 'rejection reason; max 500 chars per AC2-3']
  created_at timestamp
  updated_at timestamp
}

// === Manager delegation ===
Table delegation_assignment {
  id bigint [pk, increment]
  tenant_id bigint [ref: > tenant.id]
  manager_user_id bigint [ref: > user.id, note: 'the manager who set the delegate']
  delegate_user_id bigint [ref: > user.id, note: 'must be another manager in same tenant per AC6-1']
  active boolean [default: true]
  created_at timestamp
  Indexes {
    (manager_user_id, active)
  }
}

// === Notification log ===
Table notification {
  id bigint [pk, increment]
  tenant_id bigint [ref: > tenant.id]
  recipient_user_id bigint [ref: > user.id]
  related_leave_request_id bigint [ref: > leave_request.id, null]
  event_type varchar [note: 'enum below — PRD §G AC7-1']
  channel varchar [note: '"email" | "slack" — Slack only if tenant connected']
  delivery_status varchar [note: '"queued" | "sent" | "failed" — see OQ-DM-3']
  sent_at timestamp [null]
  created_at timestamp
}
// event_type enum (5 events per AC7-1):
//   "request_submitted"  — to manager (or delegate)
//   "request_approved"   — to employee
//   "request_rejected"   — to employee (with reason)
//   "request_cancelled"  — to manager
//   "balance_overridden" — to affected employee

// === iCal personal feed ===
Table ical_feed_token {
  id bigint [pk, increment]
  user_id bigint [ref: > user.id, unique]
  token varchar [unique, note: 'opaque; rotatable — see OQ-AR-10']
  created_at timestamp
  rotated_at timestamp [null]
}

// === SSO config per tenant ===
Table sso_config {
  id bigint [pk, increment]
  tenant_id bigint [ref: > tenant.id, unique]
  provider varchar [note: '"google" | "oidc"']
  oidc_issuer_url varchar [null]
  oidc_client_id varchar [null]
  oidc_client_secret_encrypted varchar [null]
  google_workspace_domain varchar [null, note: 'restrict to this domain — see OQ-AR-7']
  created_at timestamp
}

// === Slack integration (optional) ===
Table slack_integration {
  id bigint [pk, increment]
  tenant_id bigint [ref: > tenant.id, unique]
  workspace_id varchar
  channel_id varchar [note: 'configured target channel for events']
  oauth_token_encrypted varchar
  enabled_event_types varchar [note: 'CSV of event_type values; subset of the 5 in notification.event_type — see OQ-AR-9']
  created_at timestamp
}

// === Export audit ===
Table export_log {
  id bigint [pk, increment]
  tenant_id bigint [ref: > tenant.id]
  performed_by_user_id bigint [ref: > user.id]
  date_range_start date
  date_range_end date
  row_count int
  created_at timestamp
}
```

## Entity purpose (1-line each)

- **`tenant`** — root multi-tenancy entity; every other table scopes by `tenant_id`.
- **`user`** — employees, managers, HR admins, super admins. Self-referential `manager_id` for hierarchy.
- **`leave_type`** — per-tenant leave types (annual, sick, etc.) with entitlement + accrual rules.
- **`public_holiday`** — per-tenant calendar; excluded from working-day calculation.
- **`leave_balance`** — per-user-per-type balance for a fiscal year; updated on approval/cancel.
- **`balance_audit_log`** — append-only record of HR admin balance overrides per AC4-4.
- **`leave_request`** — central request lifecycle entity (`pending → approved | rejected | cancelled`).
- **`delegation_assignment`** — manager → delegate mapping; effective only when manager is on approved leave (PRD AC6-1).
- **`notification`** — log of dispatched notifications across email + Slack channels.
- **`ical_feed_token`** — opaque personal token for iCal subscription URL.
- **`sso_config`** — per-tenant SSO provider settings.
- **`slack_integration`** — optional per-tenant Slack workspace + channel.
- **`export_log`** — audit trail of HR admin CSV exports.

## Constraints

- **Multi-tenant isolation**: every non-root table includes `tenant_id`. Enforcement strategy (RLS / app-layer / schema-per-tenant) → OQ-AR-3.
- **Uniqueness**: `(user_id, leave_type_id, fiscal_year)` on `leave_balance`; `(tenant_id, date)` on `public_holiday`; `email` global unique on `user` (assumes one email per identity across tenants — see OQ-DM-2).
- **Soft-delete**: `user.deactivated_at` for compliance; hard-deletion via "delete my data" endpoint required (PRD §I Compliance) — exact retention semantics → OQ-DM-4.
- **Audit fields**: `created_at`, `updated_at` on most tables; `balance_audit_log` and `export_log` are dedicated audit tables.
- **Indexes** (recommended for query patterns):
  - `leave_request(tenant_id, requester_user_id, status)` for "my leaves" view (US-3)
  - `leave_request(tenant_id, approver_user_id, status)` for manager pending queue (US-2)
  - `leave_request(tenant_id, start_date, end_date)` for overlap detection (AC1-4) and coverage warnings (AC2-5)
  - `notification(tenant_id, recipient_user_id, created_at desc)` for inbox-style listing if added later

## Field-level validation (from AC)

| Field | Rule | Source |
|-------|------|--------|
| `leave_request.reason_note` | nullable; max 500 chars | AC1-1 |
| `leave_request.decision_reason` | mandatory when `status='rejected'`; max 500 chars | AC2-3 |
| `leave_request.start_date` | must be ≥ today on submission | AC1-5 |
| `leave_request.end_date` | must be ≥ `start_date` | implicit in AC1 |
| `leave_request` overlap | rejected if requester has overlapping `pending` or `approved` request | AC1-4 |
| `leave_request.working_days` | computed; excludes weekends + public holidays | PRD §H |
| `leave_balance` deduction | atomic on approval; restored on cancel before start | AC2-2, AC5-1 |
| `delegation_assignment.delegate_user_id` | must be another manager in same tenant | AC6-1 |

---

## Sources

- PRD `PRD-Examples.pdf` v1.0 — §G (User Stories AC), §H (Functional Requirements), §I (NFR — retention, compliance), §M (Dependencies — Stripe, iCal)

## Out of Scope

- Schema for native mobile-specific entities (no mobile in v1 per §K)
- Schema for payroll, time-tracking, performance review (out of scope per §K)
- Multi-currency entities

## Open Questions

- [ ] **OQ-DM-1** [P1]: PRD §H states "self-managed username/password is also supported as fallback" but no specifics on password complexity, hashing algorithm, recovery flow, or whether all tenants get this fallback or only those without SSO. Resolve: Mike Patel + security.
- [ ] **OQ-DM-2** [P1]: `user.email` uniqueness — globally unique (one identity across all tenants) or unique per tenant (same email could belong to multiple tenants)? Has implications for SSO domain matching. Resolve: Mike Patel.
- [ ] **OQ-DM-3** [P2]: `notification.delivery_status` — only "queued/sent/failed", or finer states (delivered, bounced, opened)? Provider-dependent. Resolve: Mike Patel after OQ-AR-8.
- [ ] **OQ-DM-4** [P1]: Compliance "delete my data" mechanism for departing employees (PRD §I) — soft-delete + retention purge cron, or immediate hard-delete with cascade? GDPR right to erasure has specific requirements. Resolve: legal review (per §O risk: legal review not started) + Mike Patel.
- [ ] **OQ-DM-5** [P2]: PRD §L Q1 (half-day support) determines whether `working_days` and `entitlement` are `decimal` (current model assumes yes) or `int`. Schema currently flexible; locks should be confirmed. Resolve: Sarah Chen + Maya (target 2026-05-15).
- [ ] **OQ-DM-6** [P2]: PRD §L Q2 (accrual model) determines whether `leave_type.accrual_rule` is `enum('annual_lump_sum','monthly_accrual')` or supports custom strategies. Resolve: Sarah Chen + Lisa (target 2026-05-20).
- [ ] **OQ-DM-7** [P3]: `tenant.status` enum — exact states. "trial" / "active" / "suspended" assumed; PRD doesn't enumerate. Resolve: Mike Patel.
- [ ] **OQ-DM-8** [P2]: `manager_id` foreign key — what happens on deactivation of a manager who has active reports? Cascade reassign? Block deactivation? Resolve: Mike Patel + Lisa.
- [ ] **OQ-DM-9** [P2]: PRD §L Q3 (mid-year entitlement change proration) — affects `leave_balance` recompute logic. Schema currently records `total_entitlement_days` per fiscal year; proration logic TBD. Resolve: Sarah Chen + Lisa (target 2026-05-20).
- [ ] **OQ-DM-10** [P3]: Carryover policy across fiscal years — does unused entitlement roll forward? Cap? Forfeit? Not in PRD. Resolve: Sarah Chen + Lisa.
- [ ] **OQ-DM-11** [P3]: Audit log retention — `balance_audit_log` and `export_log` retained 7 years per PRD §I, or different policy? Resolve: legal review.
