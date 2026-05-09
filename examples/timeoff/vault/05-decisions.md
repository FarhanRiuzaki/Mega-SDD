# 05 — Decisions

> **TL;DR**: Locked technical and business decisions with explicit PRD source · audience: Architect, Tech Lead, PM · read when challenging "why X not Y".

> ADR-lite, compact format. Decisions without explicit source go to Open Questions.

---

### D-001: Multi-tenant SaaS-only deployment (no on-prem)

PRD §K explicitly excludes BYOD / on-prem deployment from v1. **Decision**: ship as cloud-hosted multi-tenant SaaS only; no self-hosted option in v1. **Consequences**: simpler ops + faster iteration; locks out customers with strict data-residency or air-gap requirements. **Source**: PRD §K Out of Scope.

### D-002: Web-only client for v1 (mobile deferred)

PRD §K explicitly defers native mobile to v2; v1 ships web-responsive only. **Decision**: build a single web client; design responsive for mobile browsers but no native iOS/Android apps in v1. **Consequences**: faster path to GA; no mobile-app store pipelines yet; users on the go rely on responsive web. **Source**: PRD §K, §C.

### D-003: Multi-channel notifications — email primary, Slack optional

PRD §G AC7-1 lists 5 trigger events all on email; PRD §H lists Slack as optional integration. **Decision**: email is the always-on notification channel for the 5 events; Slack is opt-in per tenant and dispatches a configurable subset of events. **Consequences**: every tenant gets baseline notifications without integration setup; Slack-using tenants get higher-touch experience; logic for "subset of events" needs config UI. **Source**: PRD §G AC7-1, §H Slack integration.

### D-004: Working-day calculation excludes weekends + public holidays

PRD §H states leave days are calculated as working days only, excluding weekends (Sat/Sun by default — configurable per tenant) and public holidays from tenant calendar. **Decision**: working-day calc subtracts both weekend days (per `tenant.weekend_days` config) and any matching `public_holiday` rows. Half-day support depends on Q1 resolution (PRD §L). **Consequences**: requires per-tenant calendar maintenance; affects balance accuracy; cross-region tenants need separate public-holiday calendars. **Source**: PRD §H Working-day calculation.

### D-005: Notification delivery within 1 minute of triggering event

PRD §G AC7-1 specifies "within 1 minute" for all 5 event types. **Decision**: notification dispatcher SLA is 1 minute end-to-end. **Consequences**: requires async queue with low latency; may rule out batch-style providers; provider failure must not block lifecycle (notif failure isolated per F-C-002). **Source**: PRD §G AC7-1.

### D-006: Email content includes deep link with auto-login via SSO

PRD §G AC7-1 specifies "clicking the link opens the app, logs the user in via SSO if applicable, and displays the request". **Decision**: email body contains a deep link that, when clicked, completes SSO login (if user not already logged in) and lands on the relevant resource page. **Consequences**: deep-link routing must handle unauthenticated state; SSO redirect chain on first click; non-SSO users hit login page first. **Source**: PRD §G AC7-1.

### D-007: Manager delegation effective only during own approved leave

PRD §G AC6-1 states "delegate becomes effective only during my own approved leave periods". **Decision**: delegation is configured persistently but applied dynamically — at request-routing time, system checks whether the configuring manager has an active approved leave NOW. If yes, route to delegate; otherwise, route to manager. **Consequences**: prevents always-on delegation (which could mask manager absenteeism); decision routing is determined at request creation, not retroactively reassigned mid-cycle. **Source**: PRD §G AC6-1, AC6-2.

### D-008: Single-level approval (manager → optional delegate); no multi-level chains

PRD §K explicitly excludes "Custom multi-level approval chains" from v1. **Decision**: each `leave_request` has exactly one approver — the requester's direct manager OR (if manager is on leave with active delegate) the delegate. No director-or-VP escalation. **Consequences**: simpler routing logic; tenants with formal multi-level approval policies (e.g., enterprises) cannot adopt v1 unmodified. **Source**: PRD §K Out of Scope.

### D-009: Leave granularity — full + half day only (no hourly)

PRD §K explicitly excludes hourly leave; v1 supports full and half days only. **Decision**: `working_days` and `total_entitlement_days` use `decimal` type to support 0.5 increments; no sub-day granularity below half. Half-day support itself pending Q1 resolution. **Consequences**: simpler UI than hourly; some teams who track in hours cannot use v1. **Source**: PRD §K, PRD §L Q1.

### D-010: Data retention — 7 years with soft-delete + audit trail

PRD §I states "Leave records retained for 7 years to satisfy common labor-record obligations; soft-delete with full audit trail". **Decision**: deactivated users get `deactivated_at` timestamp (soft-delete); leave records retained 7 years from creation; audit-log tables (`balance_audit_log`, `export_log`) follow same retention. Hard delete via "delete my data" GDPR/CCPA endpoint operates separately and may break the 7-year rule for individual records (legal review pending — see OQ-DM-4). **Consequences**: storage growth; cron job needed to purge after 7-year window; potential conflict with right-to-erasure resolved per legal guidance. **Source**: PRD §I Data retention, §I Compliance.

### D-011: Multi-fiscal-year support with Jan default

PRD §H states "configurable fiscal year start month per company (default: January)". **Decision**: each tenant has a `fiscal_year_start_month` field, default 1 (January). All entitlement calculations and history queries operate within the tenant's fiscal year boundaries. **Consequences**: cross-tenant queries need fiscal-year-aware aggregation; mid-year change (rare) requires migration. **Source**: PRD §H Multi-fiscal-year.

### D-012: SSO via Google OAuth + generic OIDC, password fallback supported

PRD §H states "Google Workspace OAuth and a generic OIDC provider for SSO. Self-managed username/password is also supported as fallback". **Decision**: tenants choose between Google Workspace OAuth, generic OIDC, or password-based auth at onboarding. Password-based is "fallback" per PRD wording — interpreted as available to all tenants but recommended only when SSO is not available. **Consequences**: three auth paths to implement and test; password-auth specifics (complexity, recovery, MFA) still TBD per OQ-DM-1. **Source**: PRD §H SSO integration.

### D-013: Multi-currency leave-buyout calculations excluded from v1

PRD §K excludes multi-currency leave-buyout. **Decision**: no monetary calculations in v1. Leave is tracked in time units (days) only. **Consequences**: tenants who want "buy back unused leave" feature wait for v2; no FX rate handling needed. **Source**: PRD §K Out of Scope.

---

## Sources

- PRD `PRD-Examples.pdf` v1.0 — §C, §G (AC for US-1…US-8), §H (Functional Requirements), §I (NFR), §K (Out of Scope)

## Out of Scope

- Decisions on tech stack — TBD, captured as Open Questions in `02-architecture.md` (OQ-AR-1, OQ-AR-2, OQ-AR-3, OQ-AR-4).
- Pricing tier structure — TBD per PRD §L Q5.
- Payment-failed grace period — TBD per OQ-FL-6.

## Open Questions

- [ ] **OQ-DC-1** [P2]: PRD doesn't specify a decision on idempotency for finance-adjacent operations (Stripe webhooks, notification dispatch retries). Inflight retries must be idempotent. Resolve: Mike Patel.
- [ ] **OQ-DC-2** [P2]: PRD §L Q4 (Slack v1 vs v2) — current vault treats Slack as in-scope per §H "optional"; if Q4 lands as v2, D-003 supersedes to "email-only v1" and Slack-related tables/flows defer. Resolve: Sarah Chen + Mike Patel (target 2026-05-22).
- [ ] **OQ-DC-3** [P3]: PRD doesn't specify whether half-day requests can mix with full-day in the same multi-day request, or must be separate. Resolve: Sarah Chen + Maya.
