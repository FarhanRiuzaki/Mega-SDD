# 01 — Overview

> **TL;DR**: TimeOff is a multi-tenant SaaS leave management web app for 50–500 employee teams · audience: PM / BO / new joiners · read when you need basic product context.

## Product

TimeOff is a lightweight, multi-tenant SaaS leave management application for growing teams (50–500 employees) who have outgrown spreadsheets but don't yet need a full HRIS like BambooHR or Workday. v1 ships web-only; native mobile is deferred to v2.

## Target users / personas

- **Eli (Employee)** — software engineer at a 120-person studio. Wants quick balance visibility and friction-free request submission. Submits 2–4 times/year.
- **Maria (Manager)** — engineering manager with 8 reports. Needs at-a-glance pending queue, batch approve, coverage warnings. 5–15 requests/month.
- **Hana (HR Admin)** — Head of People at a 250-person company. Configures policies, audits balances, exports for compliance.
- **Tom (Internal IT / Eng Lead, onboarding only)** — wires up SSO, exports for backups, integrates Slack. Light-touch after initial setup.

## Problem

Internal research with 40 prospective customers surfaced consistent pain: 60% of teams under 200 employees track leave in spreadsheets, which lack audit trail, require manual balance math, allow double-booking, and break when an approving manager is themselves on leave. Existing HRIS products ($6–$12/seat) bundle features small teams don't need; free tiers feature-lock to push premature upgrades.

## Why now / motivation

Opportunity identified: a focused leave-management product priced at $2/seat/month with a clean migration path from spreadsheets and self-serve setup. *(Source: PRD §D.)*

## Success criteria

| Metric | Target | How to measure |
|--------|--------|----------------|
| Paid teams (year 1) | 1,000 (avg 75 employees) | Stripe subscription count |
| Monthly churn (after first 3 months) | < 15% | Cohort analysis |
| p95 leave-request approval time | < 24 hours | Application telemetry |
| Sign-up to first leave request submitted | < 10 minutes | Onboarding funnel |
| Customer NPS at month 6 | ≥ 40 | Quarterly survey |

*(Source: PRD §E.)*

---

## Sources

- PRD `PRD-Examples.pdf` v1.0 (2026-05-09) — §C Executive Summary, §D Background, §E Goals & Success Metrics, §F User Personas

## Out of Scope

- Native mobile applications (deferred to v2 per PRD §K)
- Payroll, time-tracking, performance review integrations
- Custom multi-level approval chains
- Hourly leave granularity
- Multi-currency leave-buyout calculations
- Bring-your-own-database / on-prem deployment

## Open Questions

- [ ] **OQ-OV-1** [P3]: PRD specifies success metric targets but doesn't tie them to specific time windows beyond "year 1" / "month 6". Confirm reporting cadence and accountability owner. Resolve: Sarah Chen (PM).
- [ ] **OQ-OV-2** [P3]: PRD §F lists 4 personas; no estimate of relative weight by user count or revenue impact. Useful for prioritization. Resolve: Sarah Chen.
- [ ] **OQ-OV-3** [P3]: NPS ≥40 at month 6 — survey methodology + sample size? Resolve: Sarah Chen + customer success team.
