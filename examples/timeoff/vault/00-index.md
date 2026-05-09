# TimeOff — Grand Design

> Multi-tenant SaaS leave management web app for 50–500 employee teams.

## Vault Lock Status

- **Vault version**: v1.0
- **Project shape**: `web-app` (Web Frontend + Backend + Integrations)
- **Implementation mode**: `new` (greenfield project; no existing codebase to reconcile)
- **PRD status**: `draft` (PRD §P shows 0/4 required sign-offs collected; PRD §L lists 5 unresolved PRD-level questions)
- **Output mode**: `compact` (table-first, prose-cut)
- **Locked at**: 2026-05-09 (vault generated)
- **Locked by**: ⚠️ DRAFT — PRD itself is not signed off. Vault cannot be treated as locked until at least PM + Eng Lead + HR Lead + CTO sign per PRD §P.
- **PRD source**: `PRD-Examples.pdf` v1.0, 2026-05-09 — DRAFT
- **Status**: ⚠️ DRAFT (not locked yet — pending PRD sign-off + resolution of 12 P1 Open Questions)

## Changelog

### v1.0 (2026-05-09)

- Initial vault generated from PRD `PRD-Examples.pdf` v1.0 (2026-05-09).
- Mode: `new` (greenfield).
- Project shape: `web-app`.
- Output mode: `compact`.
- 48 Open Questions surfaced (12 P1, 22 P2, 14 P3).

## Executive Summary

TimeOff is a lightweight, multi-tenant SaaS leave management application for growing teams (50–500 employees) priced at $2/seat/month. Employees submit leave requests via a web app; managers approve via a digest interface (with optional batch + coverage warnings); HR admins configure tenant-wide policies (leave types, public holidays, fiscal year). v1 ships web-only with Google OAuth + OIDC SSO + password fallback, optional Slack integration, and Stripe-backed billing. The PRD is currently in **draft** status with 0 of 4 required sign-offs and 5 unresolved PRD-level questions; vault should not be treated as locked. Sprint-0 blockers cluster around **tech stack selection** (no language / framework / cloud chosen) and **legal review of GDPR/CCPA compliance** (not started).

## Project Readiness Status

| Item | Status |
|------|--------|
| PRD | 🟡 Draft — 0/4 required sign-offs (PM, Eng Lead, HR Lead, CTO); 5 PRD-level questions unresolved (§L Q1–Q5) |
| Figma | 🔴 Not consumed — Figma link is TBD per PRD §J |
| Tech stack | 🔴 TBD — frontend, backend, multi-tenancy isolation, hosting, wire protocol all unspecified |
| Sign-off | 🔴 0 / 4 |
| Open Questions | **P1: 12** · P2: 22 · P3: 14 |
| Legal / Compliance review | 🔴 GDPR/CCPA review not started (per PRD §O); SOC 2 not in v1 scope |
| Brand identity | 🟡 In progress (Maya Rodriguez) |
| Customer & competitive research | ✅ Done (`customer-research-2026-Q1.md`, `competitive-analysis-2026-Q1.md`) |

> Snapshot at vault generation. Update on each iteration.

## Reading paths by role

- **IT Architect / Tech Lead**: `02-architecture.md` (full) → `03-data-model.md` → `05-decisions.md` → `06-constraints.md`
- **Frontend Developer**: `02-architecture.md#web-frontend` → `04-flows.md#user-flows-web` → `02-architecture.md#api-contracts`
- **Backend Developer**: `02-architecture.md#backend` → `03-data-model.md` → `04-flows.md#backend--system-flows` + `04-flows.md#cross-cutting-flows`
- **QA**: `04-flows.md` (all sections, focus on Definition of Done per flow)
- **PM (Sarah Chen) / Stakeholders (Tom, Lisa, Mike)**: `00-index.md` → `01-overview.md` → `05-decisions.md` → Open Questions roll-up below
- **UI/UX (Maya Rodriguez)**: `01-overview.md` → `04-flows.md#user-flows-web` → `06-constraints.md#design-system`

## Reading order (full)

1. `01-overview.md` — product, personas, problem, success metrics
2. `02-architecture.md` — components per layer (Web Frontend / Backend / Integrations), API contracts as table
3. `03-data-model.md` — DBML for 13 entities (tenant, user, leave_type, leave_request, leave_balance, etc.)
4. `04-flows.md` — 8 user flows + 6 backend flows + 2 cross-cutting flows + DoD per flow
5. `05-decisions.md` — 13 ADRs with explicit PRD source
6. `06-constraints.md` — tech, business, regulatory, NFR, voice & brand (design system sub-section)

## Anti-hallucination rules for dev / dev AI

This document is the **single source of truth for requirements**. When working from it:

1. If a requirement is NOT written here → STOP, ask Sarah Chen (PM). Do not infer; do not use "best-practice defaults".
2. If two docs appear to conflict → STOP, surface the conflict.
3. If a flow has no Definition of Done → STOP, do not mark it complete.
4. The Open Questions below are blockers. P1 must be answered before related work begins.

## Implementation Notes for AI Consumers (Claude Code, Cursor, etc.)

> This section is for AI dev tools that read the vault as source of truth when writing/modifying code.

**Vault metadata**:
- Project shape: `web-app`
- Implementation mode: `new` (no existing codebase to reconcile against; tech stack still TBD per OQ-AR-1, OQ-AR-2, OQ-AR-3, OQ-AR-4)
- PRD status: `draft` (sign-offs pending; OQ list will grow if stakeholders identify additional gaps)
- Output mode: `compact`
- Vault version: v1.0 (DRAFT)

### MANDATORY before writing/modifying any code

1. **Confirm project shape & mode**:
   - Vault states `web-app` + `new`. If you're working on something else, STOP and surface the mismatch.

2. **For mode `new`** — check Open Questions before picking defaults:
   - Tech stack OQs (P1) are unresolved: AR-1 (FE stack), AR-2 (BE stack), AR-3 (multi-tenancy isolation), AR-4 (wire protocol). If you encounter work that requires picking any of these, STOP and ask Sarah Chen / Mike Patel — do NOT auto-pick.
   - Auth OQs (P1) are unresolved: AR-7 (session lifetime, MFA, password complexity), DM-1 (password fallback specifics). If touching auth, STOP and ask.
   - Onboarding OQs (P1) are unresolved: FL-4 (tenant signup flow), FL-5 (employee bulk-import). If touching onboarding, STOP and ask.
   - Compliance OQs (P1) are unresolved: CN-2 (legal review not started), DM-4 (delete-my-data mechanism). If touching anything that processes personal data, escalate to legal first.

3. **Use the relevant layer section based on what you're implementing**:
   - Working on web client → `02-architecture.md#web-frontend` + `04-flows.md#user-flows-web`.
   - Working on backend → `02-architecture.md#backend` + `04-flows.md#backend--system-flows`.
   - Working on auth/SSO → `02-architecture.md#integrations` + `04-flows.md#cross-cutting-flows` (F-C-001).

### Companion skills for vault evolution

- **Stakeholder OQ resolution round** → `/grand-design-spec:resolve-oq`. Most useful AFTER PRD sign-off arrives and the team has stakeholder answers to capture.
- **PRD revises** → `/grand-design-spec:vault-diff`. Use when PRD goes from v1.0 → v1.1 (e.g., after Q1–Q5 from PRD §L are answered and a new PRD is published).
- **Codebase reconciliation** → NOT applicable here. Vault is `mode=new`; there's no existing codebase yet. Once development starts and code lands, this vault could be re-positioned to `mode=existing` for ongoing drift detection.

### During implementation

- Don't inject requirements not in the vault. New requirements → STOP, append to `## Open Questions` in the relevant doc.
- Don't skip Definition of Done. Every flow you implement, validate DoD before marking complete.
- Cite the vault in commit messages or code comments — e.g., `// Per vault 04-flows.md F-U-001 step 5`.

### When you encounter an inconsistency

- Vault internal conflict → STOP, surface to user with quotes from both sides.
- Vault vs PRD asli → STOP. Vault should reflect PRD; if not, vault is stale.

## Glossary

Cross-doc terms and acronyms:

| Term | Definition |
|------|----------|
| ADR | Architecture Decision Record — record of a technical decision with context, decision, consequences |
| DBML | Database Markup Language — text format for defining database schema |
| DoD | Definition of Done — observable criteria that mark a flow/task complete |
| HRIS | Human Resources Information System — full-suite HR platform (BambooHR, Workday) |
| iCal | RFC 5545 calendar feed format used for subscribing to leave events |
| MFA | Multi-Factor Authentication |
| NPS | Net Promoter Score |
| OIDC | OpenID Connect — identity layer on top of OAuth 2.0 used for SSO |
| OQ | Open Question — ambiguity that needs a stakeholder answer |
| PRD | Product Requirements Document |
| RBAC | Role-Based Access Control |
| RLS | Row-Level Security — database feature for per-row access policies |
| SaaS | Software as a Service |
| SLA | Service Level Agreement |
| SSO | Single Sign-On |
| TOIL | Time Off In Lieu — leave granted in exchange for overtime worked |
| TZ | Time Zone (IANA-formatted) |
| WCAG | Web Content Accessibility Guidelines |

## Open Questions roll-up

> Total: **48 Open Questions** across 6 docs (12 P1, 22 P2, 14 P3). Sorted by category (by topic, not by doc), then P1 → P2 → P3 within each.

### Sign-off & legal (PRIORITY-1)

- [ ] **OQ-CN-1** [P1]: PRD §P shows 0 of 4 required sign-offs as of 2026-05-09. Vault should not be locked, dev should not start, until PM + Eng Lead + HR Lead + CTO sign. `[06-constraints.md]`
- [ ] **OQ-CN-2** [P1]: Legal review of GDPR/CCPA compliance NOT STARTED per PRD §O. Required before any EU or California user onboarding. `[06-constraints.md]`

### Tech stack & architecture (PRIORITY-1)

- [ ] **OQ-AR-1** [P1]: Web Frontend tech stack (framework, state mgmt, build tooling) not stated. `[02-architecture.md]`
- [ ] **OQ-AR-2** [P1]: Backend tech stack (language, framework, runtime) not stated. PostgreSQL is working assumption only. `[02-architecture.md]`
- [ ] **OQ-AR-3** [P1]: Multi-tenancy isolation strategy — schema-per-tenant / row-level / DB-per-tenant. `[02-architecture.md]`
- [ ] **OQ-AR-4** [P1]: Wire protocol — REST / GraphQL / RPC. `[02-architecture.md]`
- [ ] **OQ-AR-7** [P1]: Auth specifics — session lifetime, refresh, MFA, password complexity, recovery, SSO domain restriction. `[02-architecture.md]`

### Multi-tenant data model & compliance (PRIORITY-1)

- [ ] **OQ-DM-1** [P1]: Self-managed username/password specifics — complexity, hashing, recovery, scope (all tenants or only non-SSO). `[03-data-model.md]`
- [ ] **OQ-DM-2** [P1]: `user.email` uniqueness — global vs per-tenant. Affects SSO domain matching. `[03-data-model.md]`
- [ ] **OQ-DM-4** [P1]: GDPR/CCPA "delete my data" mechanism — soft-delete + retention purge or immediate hard-delete with cascade. Tied to legal review (OQ-CN-2). `[03-data-model.md]`

### Onboarding flow (PRIORITY-1)

- [ ] **OQ-FL-4** [P1]: Tenant onboarding flow — signup steps, super admin provisioning, Stripe trial setup. `[04-flows.md]`
- [ ] **OQ-FL-5** [P1]: Initial employee bulk-import — CSV / SSO directory sync / manual; manager assignment mechanism. `[04-flows.md]`

### PRD §L unresolved questions Q1–Q5 (PRIORITY-2)

- [ ] **OQ-DM-5** [P2]: Q1 — half-day support. Affects DBML field types (`decimal` vs `int`) and UI complexity. Target: 2026-05-15. `[03-data-model.md]`
- [ ] **OQ-DM-6** [P2]: Q2 — accrual model (annual lump sum vs monthly accrual). Affects `leave_type.accrual_rule` enum. Target: 2026-05-20. `[03-data-model.md]`
- [ ] **OQ-DM-9** [P2]: Q3 — proration logic for mid-year entitlement change. Target: 2026-05-20. `[03-data-model.md]`
- [ ] **OQ-DC-2** [P2]: Q4 — Slack integration v1 vs v2. If v2, D-003 supersedes to email-only. Target: 2026-05-22. `[05-decisions.md]`
- [ ] **OQ-CN-6** [P2]: Q5 — pricing tier structure. Target: 2026-05-30. `[06-constraints.md]`

### Architecture refinements (PRIORITY-2)

- [ ] **OQ-AR-5** [P2]: Coverage-warning data shape (AC2-5) — embedded in pending-list response or separate endpoint. `[02-architecture.md]`
- [ ] **OQ-AR-6** [P2]: Hosting cloud provider TBD (AWS / GCP / Azure). `[02-architecture.md]`
- [ ] **OQ-AR-8** [P2]: Email provider final lock — SendGrid (working) vs Postmark vs AWS SES. `[02-architecture.md]`
- [ ] **OQ-AR-9** [P2]: Slack integration scope — which exact event subset, channel routing, message format. `[02-architecture.md]`
- [ ] **OQ-AR-10** [P2]: iCal feed token rotation / revocation flow. `[02-architecture.md]`
- [ ] **OQ-AR-11** [P2]: Manager hierarchy — how `manager_id` is set, mid-org-change reassignment. `[02-architecture.md]`

### Flow edge cases (PRIORITY-2)

- [ ] **OQ-FL-1** [P2]: Delegation routing — request stays with delegate or reverts to manager when manager returns mid-cycle? `[04-flows.md]`
- [ ] **OQ-FL-2** [P2]: Working-day calculation time zone — tenant TZ or user TZ. `[04-flows.md]`
- [ ] **OQ-FL-6** [P2]: Stripe payment-failed grace period. `[04-flows.md]`
- [ ] **OQ-FL-8** [P2]: Notification template content — subjects, body copy. `[04-flows.md]`
- [ ] **OQ-FL-10** [P2]: Approver = requester edge case (manager submits for self). `[04-flows.md]`

### Data model refinements (PRIORITY-2)

- [ ] **OQ-DM-3** [P2]: `notification.delivery_status` granularity (provider-dependent). `[03-data-model.md]`
- [ ] **OQ-DM-8** [P2]: `manager_id` deactivation cascade — reassign reports / block. `[03-data-model.md]`

### Decisions / cross-cutting (PRIORITY-2)

- [ ] **OQ-DC-1** [P2]: Idempotency strategy for Stripe webhooks + notification dispatch retries. `[05-decisions.md]`

### Constraints / NFR / brand (PRIORITY-2)

- [ ] **OQ-CN-3** [P2]: User-facing UI locale — English-only assumed; tenant or per-user preference. `[06-constraints.md]`
- [ ] **OQ-CN-4** [P2]: Accessibility level — lock the WCAG target before design phase finishes. `[06-constraints.md]`
- [ ] **OQ-CN-5** [P2]: Accent color (visual identity) TBD. `[06-constraints.md]`

### Refinement / nice-to-have (PRIORITY-3)

- [ ] **OQ-OV-1** [P3]: Success-metric reporting cadence + accountability. `[01-overview.md]`
- [ ] **OQ-OV-2** [P3]: Persona weighting (relative user count or revenue). `[01-overview.md]`
- [ ] **OQ-OV-3** [P3]: NPS survey methodology + sample size. `[01-overview.md]`
- [ ] **OQ-AR-12** [P3]: Rate limiting / API quotas not specified. `[02-architecture.md]`
- [ ] **OQ-DM-7** [P3]: `tenant.status` enum exact states. `[03-data-model.md]`
- [ ] **OQ-DM-10** [P3]: Carryover policy across fiscal years (rollforward, cap, forfeit). `[03-data-model.md]`
- [ ] **OQ-DM-11** [P3]: Audit log retention — same 7-year as leave records or different. `[03-data-model.md]`
- [ ] **OQ-FL-3** [P3]: CSV export size threshold (sync vs async). `[04-flows.md]`
- [ ] **OQ-FL-7** [P3]: iCal feed window — how far back / forward. `[04-flows.md]`
- [ ] **OQ-FL-9** [P3]: "Same team" definition for coverage warning. `[04-flows.md]`
- [ ] **OQ-DC-3** [P3]: Half-day mixed with full-day in same multi-day request — allowed or split? `[05-decisions.md]`
- [ ] **OQ-CN-7** [P3]: DR RTO / RPO targets. `[06-constraints.md]`
- [ ] **OQ-CN-8** [P3]: Pricing validation completion — 2 more prospects needed. `[06-constraints.md]`
- [ ] **OQ-CN-9** [P3]: Audit log retention — same as data retention or separate. `[06-constraints.md]`

## Source documents

- **PRD**: `PRD-Examples.pdf` v1.0, 2026-05-09 — DRAFT
- **BRD**: not provided
- **Figma**: TBD (per PRD §J)
- **Sign-off**: not yet collected (per PRD §P) — 0 of 4 required

## Last updated

2026-05-09
