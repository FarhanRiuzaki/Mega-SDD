# 02 — Architecture

> **TL;DR**: System components per layer (Web Frontend / Backend / Integrations) + API contracts as derivable from PRD AC · audience: Architect, FE Dev, BE Dev · read when reviewing structure or implementing.

## System overview

Multi-tenant SaaS web app. Browser → Web Frontend → Backend → managed services (DB, email, Slack, Stripe, SSO providers). All tenants share infrastructure; tenant isolation enforced at application + DB level (isolation strategy TBD — see OQ-AR-3).

```
  Web Frontend                 Backend                  Integrations
  ────────────                 ────────                 ────────────
  Browser  ──── HTTPS ────►  API Service  ──────►  PostgreSQL (assumed)
                                  │                  ├─► SendGrid (assumed)
                                  ├──────────────────┼─► Slack (optional)
                                  ├──────────────────┼─► Stripe Billing
                                  ├──────────────────┼─► SSO: Google OAuth + OIDC
                                  └──────────────────┴─► iCal feed served at /ical/<token>
```

---

## By component layer

### Web Frontend

| Component | Purpose | Source |
|-----------|---------|--------|
| Login + SSO redirect | Auth entry; supports Google OAuth, generic OIDC, password fallback | PRD §H SSO |
| Employee dashboard | Show balance per leave type, pending requests, history (US-3) | PRD §G AC3-1, AC3-2 |
| Request form | Leave type, start, end, optional reason note (US-1) | PRD §G AC1-1 |
| Manager pending-approvals view | List pending from direct reports, sort, batch-select, coverage warnings (US-2) | PRD §G AC2-1, AC2-4, AC2-5 |
| Cancel request action | Cancel approved leave before start date (US-5) | PRD §G AC5-1, AC5-2 |
| Manager delegate config | Set delegate effective during own leave (US-6) | PRD §G AC6-1 |
| HR admin policy console | Manage leave types, public holidays, balance overrides (US-4) | PRD §G AC4-1…AC4-4 |
| HR admin export | CSV export with date range filter (US-8) | PRD §G AC8-1 |
| Tenant onboarding (Tom) | SSO config, Slack workspace connect, initial admin setup | PRD §F Persona 4, §H |

**Tech stack (Web Frontend)**: not stated → OQ-AR-1.

### Backend

| Component | Purpose | Source |
|-----------|---------|--------|
| Auth service | SSO orchestration (Google OAuth + OIDC) + password fallback | PRD §H |
| Tenant management | Multi-tenant data isolation, RBAC enforcement (Employee / Manager / HR Admin / Super Admin) | PRD §H |
| Leave request service | Lifecycle: pending → approved / rejected / cancelled. Validation: balance, overlap, past-date, working-day calc | PRD §G AC1-2…AC1-5, AC2-2, AC2-3, AC5-1, AC5-2 |
| Leave policy service | Manage leave types, annual entitlement, accrual rules, public holidays | PRD §G AC4-1…AC4-4 |
| Balance service | Track balance per user per leave type; deduct on approval, restore on cancel; balance-override audit log | PRD §G AC2-2, AC4-4, AC5-1 |
| Working-day calculator | Excludes weekends (configurable per tenant) + public holidays | PRD §H Working-day calculation |
| Delegation router | Route incoming requests to delegate when manager is on approved leave | PRD §G AC6-2 |
| Notification dispatcher | Email primary; Slack optional. 5 trigger events | PRD §G AC7-1 |
| iCal feed generator | Personal user feed URL serving RFC 5545 events for approved leave | PRD §H iCal feed |
| Export service | CSV export of leave requests with required columns | PRD §G AC8-1 |
| Audit log service | Track HR balance overrides, sign-off events, sensitive admin actions | PRD §G AC4-4 |
| Billing integration | Stripe subscription mgmt per tenant | PRD §M Stripe |

**Tech stack (Backend)**: not stated → OQ-AR-2. Database working assumption PostgreSQL (PRD §M) but not locked.

### Integrations

| External system | Direction | Protocol | Purpose | Source |
|-----------------|-----------|----------|---------|--------|
| Google Workspace OAuth | sync, BE → Google | OAuth 2.0 | SSO for Google-using tenants | PRD §H |
| Generic OIDC provider | sync, BE → OIDC | OIDC | SSO for tenants on other identity providers | PRD §H |
| SendGrid (assumed) | async, BE → SendGrid | SMTP/REST | Email notifications (5 events) | PRD §M |
| Slack | async, BE → Slack | Webhook / Slack API | Optional; key events to configured channel | PRD §H, §G AC7-1 |
| Stripe Billing | sync, BE ↔ Stripe | REST + webhooks | Subscription lifecycle | PRD §M |
| iCal subscriber clients | pull, client → BE | HTTPS file fetch (RFC 5545) | Calendar app subscribes to user's leave feed | PRD §H |

**Auth & integration patterns**: SSO (OAuth 2.0 / OIDC); password fallback (details TBD — OQ-AR-7); session lifetime + refresh + MFA not specified → OQ-AR-7.

---

## API contracts

> Tabel of endpoints derived from User Story AC. No JSON examples included (compact mode) — payload shape inferable from request fields below. Wire format (REST/GraphQL/RPC) not stated → OQ-AR-4.

### Mobile-facing / web-facing endpoints

| Method · Path | Purpose | Auth | Errors | Source |
|---------------|---------|------|--------|--------|
| `POST /leave-requests` | Submit leave request (type, start, end, note) | Employee | `400 insufficient_balance` (AC1-3); `400 overlap` (AC1-4); `400 past_date` (AC1-5) | PRD §G US-1 |
| `GET /leave-requests/me` | Current user's history + pending | Employee | — | PRD §G US-3 |
| `GET /leave-requests/pending` | Manager's queue from direct reports (or delegate's queue) | Manager | — | PRD §G AC2-1, AC6-2 |
| `POST /leave-requests/:id/approve` | Approve single request | Manager | — | PRD §G AC2-2 |
| `POST /leave-requests/:id/reject` | Reject with reason | Manager | `400 reason_required` | PRD §G AC2-3 |
| `POST /leave-requests/batch-approve` | Approve multiple atomically | Manager | `400 partial_failure` (all-or-none per AC2-4) | PRD §G AC2-4 |
| `POST /leave-requests/:id/cancel` | Cancel approved leave (before start) | Employee | `400 already_started` (AC5-2) | PRD §G AC5-1 |
| `GET /balances/me` | Current user's balance per leave type | Employee | — | PRD §G AC3-1 |
| `POST /balances/override` | HR admin manual adjustment with reason (audit-logged) | HR Admin | — | PRD §G AC4-4 |
| `GET/POST /leave-types` | CRUD leave types per tenant | HR Admin | — | PRD §G AC4-1, AC4-2 |
| `GET/POST /public-holidays` | CRUD tenant calendar | HR Admin | — | PRD §G AC4-3 |
| `POST /delegations` | Set delegate (effective only during own leave) | Manager | — | PRD §G AC6-1 |
| `GET /export/leaves.csv` | CSV export with date range | HR Admin | — | PRD §G AC8-1 |
| `GET /ical/:token` | Personal iCal feed (no auth, token-bound) | Token | — | PRD §H iCal |
| `POST /webhooks/stripe` | Stripe billing webhook | Stripe HMAC | — | PRD §M |

**Coverage warning** (AC2-5): served as part of `GET /leave-requests/pending` response (per-row metadata showing other team members' approved overlapping leaves). Exact field shape TBD → OQ-AR-5.

---

## Sources

- PRD `PRD-Examples.pdf` v1.0 — §C, §G (US-1…US-8 + AC), §H (Functional Requirements), §M (Dependencies)

## Out of Scope

- Native mobile API surface (no separate mobile endpoints; web-only per §K)
- Custom multi-level approval routing endpoints
- Hourly leave endpoints
- BYOD / on-prem deployment endpoints

## Open Questions

- [ ] **OQ-AR-1** [P1]: Web Frontend tech stack (framework: React/Vue/Next/SvelteKit/etc., state mgmt, build tooling) not stated. Sprint-0 blocker. Resolve: Mike Patel (Eng Lead).
- [ ] **OQ-AR-2** [P1]: Backend tech stack (language, framework, runtime) not stated. PostgreSQL is working assumption only. Resolve: Mike Patel.
- [ ] **OQ-AR-3** [P1]: Multi-tenancy isolation strategy — schema-per-tenant, row-level (RLS with `tenant_id`), or DB-per-tenant? Has cost / compliance / scalability implications. Resolve: Mike Patel + CTO.
- [ ] **OQ-AR-4** [P1]: Wire protocol for client ↔ backend — REST / GraphQL / RPC? Affects FE state libs and BE framework choices. Resolve: Mike Patel.
- [ ] **OQ-AR-5** [P2]: Coverage-warning data shape (AC2-5) not explicit — embedded in pending-list response, separate endpoint, or async load? Resolve: Mike Patel + Maya (Design).
- [ ] **OQ-AR-6** [P2]: Hosting cloud provider TBD (AWS / GCP / Azure per §M). Affects observability stack, secret mgmt, IaC. Resolve: Mike Patel + ops.
- [ ] **OQ-AR-7** [P1]: Auth specifics — session lifetime, refresh tokens, MFA support, password complexity rules, recovery flow, SSO domain restriction. Sprint-0 blocker. Resolve: Mike Patel + security.
- [ ] **OQ-AR-8** [P2]: Email provider — SendGrid is "working assumption"; alternatives Postmark / AWS SES under consideration (§M). Lock the choice. Resolve: Mike Patel.
- [ ] **OQ-AR-9** [P2]: Slack integration scope — which exact events post (subset of the 5 in AC7-1?), per-channel routing, message format. PRD §G AC7-1 lists email triggers but Slack is "optional" per §H. Resolve: Sarah Chen + Mike Patel.
- [ ] **OQ-AR-10** [P2]: iCal feed token — generated per-user; rotatable on demand? Token revocation flow? Resolve: Mike Patel.
- [ ] **OQ-AR-11** [P2]: Manager hierarchy — how is "direct manager" set per employee? HR admin manual? Imported from SSO/HRIS? Mid-org-change reassignment? Resolve: Sarah Chen + Lisa Wong (HR Lead).
- [ ] **OQ-AR-12** [P3]: Rate limiting / API quotas not specified. Tipikal SaaS: per-tenant + per-IP. Resolve: Mike Patel + ops.
