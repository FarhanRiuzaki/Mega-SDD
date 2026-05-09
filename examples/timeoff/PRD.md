# Product Requirements Document: TimeOff

> **Status**: Draft v1.0
> **Last updated**: 2026-05-09

## A. Document Control

| Field | Value |
|-------|-------|
| Product name | TimeOff |
| Document version | 1.0 |
| Status | Draft (pending stakeholder sign-off) |
| Date created | 2026-05-09 |
| Author | Sarah Chen (Product Manager) |
| Reviewers | Mike Patel (Engineering Lead), Lisa Wong (HR Lead), Tom Yamamoto (CTO), Maya Rodriguez (Design Lead) |
| Sign-off required from | PM, Eng Lead, HR Lead, CTO |

## B. Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-05-09 | Initial draft | Sarah Chen |

## C. Executive Summary

TimeOff is a lightweight, multi-tenant SaaS leave management application for growing teams (50–500 employees) who have outgrown spreadsheet-based tracking but don't yet need a full-featured HRIS like BambooHR or Workday. Employees request leave, managers approve via a digest interface, and HR admins configure policies and audit balances. v1 ships as a web-only application; native mobile is deferred.

## D. Background & Problem

Internal research with 40 prospective customers (mix of design agencies, software studios, and B2B SaaS startups) surfaced consistent pain points:

- 60% of teams under 200 employees still track leave in shared spreadsheets.
- Spreadsheet workflow has no audit trail, requires manual balance calculations, and is prone to double-booking when multiple managers don't see each other's approvals.
- When a manager is themselves on leave, requests pile up with no delegation path.
- Existing tools (BambooHR, Workday, Personio) cost $6–$12 per seat per month and bundle features (payroll, performance reviews) that small teams don't need.
- Free tier of larger HRIS products has feature locks that push teams to upgrade prematurely.

The opportunity: a focused leave-management product priced at $2/seat/month with a clean migration path from spreadsheets and a self-serve setup flow.

## E. Goals & Success Metrics

### Goals

1. Replace spreadsheet workflow for leave management at companies of 50–500 employees.
2. Provide manager and HR admin tooling that scales beyond what spreadsheets allow without requiring a full HRIS migration.
3. Establish TimeOff as the default "next step" for teams who outgrow Google Sheets / Notion / Airtable for HR.

### Success metrics

| Metric | Target | How to measure |
|--------|--------|----------------|
| Paid teams (year 1) | 1,000 teams (avg 75 employees) | Stripe subscription count |
| Monthly churn (after first 3 months of customer lifetime) | < 15% | Cohort analysis |
| 95th-percentile leave-request approval time | < 24 hours | Application telemetry |
| Time from sign-up to first leave request submitted | < 10 minutes | Onboarding funnel telemetry |
| Customer NPS at month 6 | ≥ 40 | Quarterly survey |

## F. User Personas

### Persona 1: Eli (Employee)

**Role**: Software engineer at a 120-person product studio.
**Goals**: Quick visibility into remaining leave balance; submit a request without back-and-forth; know when it's been approved.
**Pain points (current state with spreadsheet)**:
- Has to email HR to ask "how many days do I have left?"
- Can't tell whether a teammate is on leave during the same week.
- Approval status is invisible — relies on Slack DM follow-up.

**Behavior**: Submits leave 2–4 times per year. Mostly small requests (1–3 days at a time). Cares about speed and clarity, not feature richness.

### Persona 2: Maria (Manager)

**Role**: Engineering manager with 8 direct reports.
**Goals**: See pending requests at a glance; approve in batches; see upcoming team coverage gaps before approving.
**Pain points**:
- Approval requests come via email, get lost in inbox.
- No way to see "who's out next week?" without asking around.
- When she's herself on leave, requests pile up because there's no auto-delegation.

**Behavior**: Receives 5–15 leave requests per month. Approves the same day if no conflicts; defers if uncertain about coverage.

### Persona 3: Hana (HR Admin)

**Role**: Head of People at a 250-person company.
**Goals**: Define company-wide leave policies (annual entitlement, accrual rules, public holiday calendar); audit individual balances; produce compliance reports.
**Pain points**:
- Spreadsheet has formula bugs that have caused balance errors traced back 6+ months.
- Auditors ask for leave-history exports; she has to manually compile from the master sheet.
- Has to manually enter every public holiday and prorate entitlements for new hires mid-year.

**Behavior**: Configures policy once, then mostly monitors. Heavy export usage at year-end and during audits.

### Persona 4: Tom (Internal IT / Engineering Lead — onboarding only)

**Role**: Sets up TimeOff for the company.
**Goals**: Wire up SSO; export data periodically for backup; integrate with Slack for notifications.
**Pain points**: None specific — this persona is light-touch. Once onboarded, doesn't use the product day-to-day.

## G. User Stories with Acceptance Criteria

### US-1: Submit a leave request

> As an employee, I want to submit a leave request quickly so I can plan my time off without bottlenecking on email.

**AC1-1: Open request form from dashboard**
- Given I am logged in as an employee
- When I click "Request leave" from my dashboard
- Then I see a form containing: leave type (dropdown), start date, end date, optional reason note (max 500 chars), and a "Submit" button

**AC1-2: Submit a valid request**
- Given I have filled all required fields
- And the requested days do not exceed my available balance for the selected leave type
- When I click "Submit"
- Then the system creates a leave request with status `pending`
- And my direct manager receives an email notification within 1 minute
- And I see a success confirmation with the request ID

**AC1-3: Insufficient balance error**
- Given my available balance for "Annual Leave" is 5 working days
- When I submit a request that would consume 7 working days
- Then the system rejects the request with the message "Insufficient balance: 5 working days remaining for Annual Leave"
- And no record is created

**AC1-4: Overlapping request error**
- Given I have an existing leave request (status `pending` or `approved`) for 2026-06-01 to 2026-06-05
- When I submit another request whose date range overlaps any of those dates
- Then the system rejects the request with the message "You already have a leave request during these dates (request #1234)"
- And no record is created

**AC1-5: Past-date rejection**
- Given I attempt to submit a request whose start date is before today
- When I click "Submit"
- Then the system rejects with "Start date cannot be in the past"

### US-2: Approve or reject a leave request (manager)

> As a manager, I want to see and act on pending requests from my reports without digging through email.

**AC2-1: Manager dashboard shows pending requests**
- Given I am logged in as a manager
- When I navigate to "Pending approvals"
- Then I see a list of all `pending` requests from my direct reports, sorted by request date (oldest first), each row showing: requester name, leave type, date range, working days, requester's remaining balance, optional note

**AC2-2: Approve a single request**
- Given I am viewing a pending request
- When I click "Approve"
- Then the request status becomes `approved`
- And the requester's available balance for that leave type decreases by the requested working days
- And the requester receives an email notification

**AC2-3: Reject with reason**
- Given I am viewing a pending request
- When I click "Reject" and provide a rejection reason (max 500 chars, required)
- Then the request status becomes `rejected`
- And the requester's balance is unchanged
- And the requester receives an email notification including the rejection reason

**AC2-4: Batch approve**
- Given I have selected 2 or more pending requests via checkboxes
- When I click "Approve selected"
- Then each selected request follows AC2-2 logic atomically (all-or-none — if any one fails, none are approved and the user sees an error listing the failures)

**AC2-5: Coverage warning before approval**
- Given I am viewing a pending request
- And there is at least one other approved leave from the same team during the requested date range
- Then the system displays a warning banner "N other team member(s) on leave during this period: [list of names]"
- And approval still proceeds at the manager's discretion (the warning does not block)

### US-3: View leave balance

> As an employee, I want to see my current leave balance and history.

**AC3-1: Display current balances**
- Given I am logged in
- When I navigate to "My leaves"
- Then I see, per leave type configured at my company: total entitlement, used (approved), pending, and remaining

**AC3-2: Display leave history**
- Given I am viewing "My leaves"
- When I scroll to the history section
- Then I see all my past leave requests for the current and previous fiscal year, sorted by start date (most recent first), each row showing: leave type, date range, working days, status, decision date, manager comment if any

### US-4: Configure leave policies (HR admin)

> As an HR admin, I want to set the policies that govern leave for my company.

**AC4-1: Create a leave type**
- Given I am logged in as an HR admin
- When I create a new leave type (name, default annual entitlement in working days, accrual rule)
- Then the leave type is available for all employees in my company starting from the next entitlement period

**AC4-2: Edit annual entitlement per leave type**
- Given a leave type exists
- When I update its default annual entitlement
- Then the change applies to all employees from the next fiscal year (existing balances are not retroactively recalculated)

**AC4-3: Configure public holiday calendar**
- Given I am an HR admin
- When I add a public holiday (date, name)
- Then leave requests overlapping that date will not consume that day from the employee's balance (working-day calculation excludes public holidays)

**AC4-4: Override an individual employee's balance**
- Given an employee's balance is incorrect (e.g., unused TOIL carryover, manual adjustment)
- When I set their balance for a specific leave type to a custom value with a reason
- Then the employee's balance reflects the new value
- And an audit log entry records the override (admin name, timestamp, before/after, reason)

### US-5: Cancel an approved leave request

> As an employee, I want to cancel an approved leave if my plans change.

**AC5-1: Cancel before start date**
- Given I have an approved leave request with start date in the future (>= tomorrow)
- When I click "Cancel" on that request
- Then the status becomes `cancelled`
- And my balance for that leave type is restored by the working days that were deducted
- And my manager receives an email notification

**AC5-2: Cannot cancel after start date**
- Given I have an approved leave request that has already started (start date <= today)
- When I view the request
- Then the "Cancel" button is disabled with tooltip "Cannot cancel a leave that has already started — contact your HR admin"

### US-6: Manager delegation when out of office

> As a manager, when I am myself on leave, I want my reports' requests to be auto-delegated.

**AC6-1: Configure a delegate**
- Given I am a manager
- When I configure a delegate (another manager in the same company)
- Then the delegate becomes effective only during my own approved leave periods

**AC6-2: Delegated approval routing**
- Given I have an active delegate (i.e., I am currently on approved leave with a delegate set)
- When one of my direct reports submits a leave request
- Then the request is routed to the delegate (not me)
- And the delegate sees it in their pending approvals queue with a flag "Delegated from: [my name]"

### US-7: Notifications

> As any user, I want to be notified about events that affect me.

**AC7-1: Email notification triggers**
- The system sends an email notification within 1 minute on each of these events:
  1. Employee submits a request → manager (or delegate) is notified
  2. Manager approves a request → employee is notified
  3. Manager rejects a request → employee is notified (with reason)
  4. Employee cancels a request → manager is notified
  5. HR admin overrides a balance → affected employee is notified
- Email content includes the request ID and a deep link to the request detail page (clicking the link opens the app, logs the user in via SSO if applicable, and displays the request)

### US-8: Export to CSV

> As an HR admin, I want to export leave data for compliance and audit purposes.

**AC8-1: Export current and historical data**
- Given I am an HR admin
- When I select a date range and click "Export to CSV"
- Then I receive a CSV file containing one row per leave request in that range, with columns: request ID, requester name, requester employee ID, leave type, start date, end date, working days, status, manager name, decision timestamp, rejection reason (if any)
- And the export includes both completed and pending requests

## H. Functional Requirements (system-level)

- **Multi-tenancy**: each company is isolated; data from one company is never visible to another.
- **Role-based access**: at least four roles — Employee, Manager, HR admin, Super admin (one per company; can manage other admins).
- **SSO integration**: the system supports Google Workspace OAuth and a generic OIDC provider for SSO. Self-managed username/password is also supported as fallback.
- **Slack integration (optional)**: HR admin can connect a Slack workspace; key events (request submitted, approved, rejected) post to a configured Slack channel.
- **iCal feed**: each user has a personal iCal feed URL to subscribe to in their calendar app, showing their approved leave events.
- **Multi-fiscal-year**: configurable fiscal year start month per company (default: January).
- **Working-day calculation**: leave days are calculated as working days only, excluding weekends (Sat/Sun by default — configurable per company) and public holidays from the company's calendar.
- **Time zone**: each user has a time zone setting; emails and dates respect the user's TZ.

## I. Non-Functional Requirements

| Category | Requirement |
|----------|-------------|
| Performance | p95 page-load time < 2 seconds; p95 API response time < 500 ms |
| Availability | 99.5% monthly uptime SLA |
| Scalability | Support 1000 tenants × avg 75 employees = ~75,000 active users in year 1 |
| Security | Data encrypted at rest (AES-256) and in transit (TLS 1.2+); leave records contain personal data subject to applicable privacy law |
| Data retention | Leave records retained for 7 years to satisfy common labor-record obligations; soft-delete with full audit trail |
| Compliance | GDPR for EU users (data residency in EU region); CCPA for California users; an explicit "delete my data" mechanism for departing employees |
| Observability | Structured logs to a central log store; metrics (p50/p95/p99 latency per endpoint, request rate, error rate); alerts on availability dips below SLA |
| Backup | Daily full backups, retained 30 days; ability to restore any tenant's data within 4 hours of request |

## J. UI/UX

Figma link: TBD (design work to begin after PRD sign-off).

Brand voice & visual direction notes (from preliminary brand workshop):

- Tone: friendly, calm, professional. Avoid jargon. Avoid corporate stiffness.
- Visual: clean and minimal; default to system fonts; muted color palette with one accent color (TBD by Design Lead).
- Accessibility: targeted level — TBD (likely WCAG 2.1 AA but not yet ratified; Design Lead and Eng Lead will confirm).

## K. Out of Scope (v1)

The following are explicitly NOT in scope for v1.0:

- Native mobile applications (iOS, Android) — v1 is web-responsive only; mobile is a planned v2 milestone.
- Payroll integration of any kind.
- Time-tracking / attendance / time-clock features.
- Performance review or 360-feedback features.
- Custom multi-level approval chains (e.g., manager → director → VP). v1 supports a single approver (manager) with one optional delegate.
- Hourly leave (e.g., "I need 2 hours off this afternoon"). v1 supports full days and half days only.
- Multi-currency leave-buyout calculations.
- Bring-your-own-database / on-prem deployment. v1 is SaaS-only.

## L. Open Questions (PRD-level — to be resolved before sign-off)

| # | Question | Owner | Target resolution |
|---|----------|-------|-------------------|
| Q1 | Does v1 support half-day leave, or full days only? Half-day expands UI complexity. | Sarah Chen + Maya Rodriguez | 2026-05-15 |
| Q2 | What is the exact accrual model — annual lump sum vs monthly accrual? Customer interviews split 50/50. | Sarah Chen + Lisa Wong | 2026-05-20 |
| Q3 | When an employee's annual entitlement changes mid-year (raise, role change), how is the existing balance prorated? | Sarah Chen + Lisa Wong | 2026-05-20 |
| Q4 | Does Slack integration belong in v1 or v2? Eng estimate is 2 additional weeks. | Sarah Chen + Mike Patel | 2026-05-22 |
| Q5 | Pricing tier structure: flat $2/seat vs per-feature tiers? | Sarah Chen + leadership | 2026-05-30 |

## M. Dependencies & Assumptions

- **Hosting**: cloud provider TBD (AWS, GCP, or Azure — to be decided by Eng Lead based on existing org contracts).
- **Email provider**: SendGrid is the working assumption; alternatives (Postmark, AWS SES) under consideration.
- **Database**: PostgreSQL is the working assumption.
- **SSO**: assume customers can provide their own OIDC provider details; Google Workspace OAuth uses Google's standard flow.
- **Stripe**: payments and subscription management via Stripe Billing. (Stripe contract already in place at the org level.)
- **iCal**: standard RFC 5545 (iCalendar) format; no special server requirements beyond serving the feed file at a personal URL.

## N. Timeline & Milestones (target)

| Milestone | Target date |
|-----------|-------------|
| PRD sign-off | 2026-05-30 |
| Engineering kickoff | 2026-06-02 |
| Internal alpha (dogfood at Sarah's company) | 2026-08-01 |
| Closed beta (5 design partners) | 2026-09-15 |
| Public beta | 2026-10-15 |
| GA (paid plans live) | 2026-11-15 |

## O. Impact / Risk Checklist

| Item | Status |
|------|--------|
| Customer interviews completed | ✅ 40 interviews, summary in `customer-research-2026-Q1.md` |
| Competitive analysis completed | ✅ See `competitive-analysis-2026-Q1.md` |
| Pricing validated with prospects | 🟡 Partial — 3 prospects confirmed willingness at $2/seat; need 5 more |
| Legal review of GDPR/CCPA compliance | 🔴 Not started — flag for Q2 |
| Brand identity finalized | 🟡 In progress — Maya Rodriguez |
| SOC 2 readiness assessment | 🔴 Not yet — track for v2 |

## P. Sign-off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Product Manager | Sarah Chen | | |
| Engineering Lead | Mike Patel | | |
| HR Lead | Lisa Wong | | |
| CTO | Tom Yamamoto | | |
| Design Lead | Maya Rodriguez | | (review-only, not blocking sign-off) |
