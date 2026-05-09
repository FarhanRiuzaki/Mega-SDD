# 04 — Flows

> **TL;DR**: User flows (web), backend / system flows, cross-cutting flows + per-flow Definition of Done · audience: FE Dev, BE Dev, QA, UI/UX · read when building/testing or reviewing end-to-end behavior.

---

## User flows (web)

### F-U-001: Submit leave request

**Actor / Trigger**: employee opens dashboard, clicks "Request leave".

**Steps** (from PRD §G US-1):
1. Employee clicks "Request leave" → form opens with fields: leave type (dropdown), start date, end date, optional reason note (max 500 chars), Submit button.
2. Employee fills form and clicks "Submit".
3. System validates (in order): all required fields present → balance sufficient (AC1-3) → no overlap with existing pending/approved (AC1-4) → start date not in past (AC1-5).
4. If any validation fails, show error inline, do not create record.
5. If valid, create `leave_request` with status `pending`, `working_days` computed (weekends + public holidays excluded).
6. Increment `leave_balance.pending_days` for requester.
7. Trigger notification dispatcher: `request_submitted` to manager (or active delegate, see F-S-002).
8. Show success confirmation to user with request ID.

**Definition of Done**:
- [ ] Form opens with all 4 fields visible.
- [ ] Insufficient balance → error message exact text "Insufficient balance: N working days remaining for {LeaveType}".
- [ ] Overlap with existing → error message exact text "You already have a leave request during these dates (request #N)".
- [ ] Past start date → error "Start date cannot be in the past".
- [ ] Successful submit creates exactly one `leave_request` row.
- [ ] Manager receives email within 1 minute of submission.
- [ ] If submitter's manager is currently on active leave with a delegate, request routes to delegate (see F-S-002).

**Source**: PRD §G AC1-1, AC1-2, AC1-3, AC1-4, AC1-5; §H Working-day calculation.

---

### F-U-002: Approve / reject leave request (manager)

**Actor / Trigger**: manager opens "Pending approvals".

**Steps** (PRD §G US-2):
1. Manager navigates to "Pending approvals" → list shows all `pending` requests from direct reports (or where manager is active delegate). Sort: request date ascending (oldest first). Each row: requester name, leave type, date range, working days, requester's remaining balance, optional note.
2. For requests overlapping other approved leaves on the same team, show coverage-warning banner "N other team member(s) on leave during this period: [list of names]". Banner does NOT block approval (AC2-5).
3. Manager actions:
   - **Approve single** (AC2-2): click "Approve" → request status becomes `approved`. Decrement requester `leave_balance.pending_days`, increment `used_days`. Send `request_approved` email.
   - **Reject** (AC2-3): click "Reject" → reason input (max 500 chars, required) → request status becomes `rejected`. Reverse `pending_days` (no `used_days` change). Send `request_rejected` email including reason.
   - **Batch approve** (AC2-4): select 2+ checkboxes → "Approve selected" → all-or-none atomic. If any fails (e.g., balance went negative due to mid-flight change), reject the whole batch and surface each failure.

**Definition of Done**:
- [ ] Pending list shows correct columns per AC2-1.
- [ ] Coverage warning visible when ≥1 other team member on overlapping approved leave.
- [ ] Coverage warning does NOT prevent approval.
- [ ] Single approve transitions status `pending → approved` and updates balance atomically.
- [ ] Rejection requires non-empty reason.
- [ ] Batch approve is atomic (all-or-none); error message lists which requests would have failed.

**Source**: PRD §G AC2-1, AC2-2, AC2-3, AC2-4, AC2-5.

---

### F-U-003: View leave balance & history

**Actor / Trigger**: employee navigates to "My leaves".

**Steps** (PRD §G US-3):
1. Display, per leave type configured at the tenant: total entitlement, used, pending, remaining (AC3-1).
2. Below balance summary, show history section: all past `leave_request` rows for current and previous fiscal year. Sort: start date desc. Columns: leave type, date range, working days, status, decision date, manager comment (rejection reason or note) if any.

**Definition of Done**:
- [ ] One row per leave type in current fiscal year, with 4 numbers (entitlement / used / pending / remaining).
- [ ] History shows current + previous fiscal year only (older years not shown by default).
- [ ] Sort order: start date desc.

**Source**: PRD §G AC3-1, AC3-2.

---

### F-U-004: Configure leave policies (HR admin)

**Actor / Trigger**: HR admin opens policy console.

**Steps** (PRD §G US-4):
1. **Create leave type** (AC4-1): input name + default annual entitlement (working days) + accrual rule → save → leave type available to all employees from next entitlement period.
2. **Edit annual entitlement** (AC4-2): change `default_annual_entitlement_days` → applies from next fiscal year. Existing balances NOT retroactively recalculated.
3. **Public holidays** (AC4-3): add date + name → working-day calculation now excludes that date for all subsequent leave-day computations.
4. **Override individual balance** (AC4-4): select user + leave type → set new value with reason → balance updated, `balance_audit_log` row written (admin name, timestamp, before/after, reason).

**Definition of Done**:
- [ ] New leave type effective only from next entitlement period; current balances unaffected.
- [ ] Edited entitlement effective only from next fiscal year.
- [ ] Adding public holiday immediately affects working-day calc for new leave requests; existing approved requests are NOT recalculated retroactively.
- [ ] Balance override creates `balance_audit_log` row with all 5 fields populated.
- [ ] Affected employee receives `balance_overridden` email (per AC7-1).

**Source**: PRD §G AC4-1, AC4-2, AC4-3, AC4-4; AC7-1.

---

### F-U-005: Cancel approved leave (before start)

**Actor / Trigger**: employee viewing an approved future leave request.

**Steps** (PRD §G US-5):
1. AC5-1: if `start_date >= tomorrow`, "Cancel" button enabled. Click → status becomes `cancelled` → `leave_balance.used_days` decremented by `working_days` of cancelled request → `request_cancelled` email to manager.
2. AC5-2: if `start_date <= today`, "Cancel" button disabled with tooltip "Cannot cancel a leave that has already started — contact your HR admin".

**Definition of Done**:
- [ ] Future leave: cancel succeeds, balance restored, status `cancelled`.
- [ ] Past or current leave: cancel disabled at UI; if attempted via API, returns error.
- [ ] Manager email notification fires within 1 minute.

**Source**: PRD §G AC5-1, AC5-2.

---

### F-U-006: Manager configures delegate

**Actor / Trigger**: manager configures a delegate from settings.

**Steps** (PRD §G US-6):
1. Manager selects another manager (same tenant) as delegate (AC6-1) → `delegation_assignment` row created with `active=true`.
2. Delegate effective ONLY during the manager's own approved leave periods (AC6-1). System checks at request-routing time whether the manager has an active leave NOW (see F-S-002).

**Definition of Done**:
- [ ] Manager can set / change / unset delegate at any time.
- [ ] Delegate must be another user with role `manager` in same tenant.
- [ ] Delegate is NOT auto-effective the moment delegation is configured — only effective during the configuring manager's actual approved leave window.

**Source**: PRD §G AC6-1, AC6-2.

---

### F-U-007: Export to CSV (HR admin)

**Actor / Trigger**: HR admin opens export tool.

**Steps** (PRD §G US-8):
1. Select date range (start, end).
2. Click "Export to CSV" → backend produces CSV. Columns: request ID, requester name, requester employee ID, leave type, start date, end date, working days, status, manager name, decision timestamp, rejection reason.
3. Includes both completed (approved/rejected/cancelled) AND pending requests within range.
4. Write `export_log` row.

**Definition of Done**:
- [ ] CSV downloadable in browser (or async-link if large — file-size threshold TBD, see OQ-FL-3).
- [ ] All 11 columns present with exact names per AC8-1.
- [ ] Pending requests included.
- [ ] `export_log` row created with date range + row count.

**Source**: PRD §G AC8-1.

---

### F-U-008: Tenant onboarding (Tom — IT / Eng Lead)

**Actor / Trigger**: super admin / IT lead during initial company setup.

**Steps** (inferred from PRD §F Persona 4 + §H):
1. Create tenant + super admin user (signup flow — exact step sequence not in PRD; see OQ-FL-4).
2. Configure SSO: choose provider (Google Workspace OAuth or generic OIDC), enter credentials, validate test login.
3. Optionally connect Slack workspace + select target channel (PRD §H Slack integration).
4. Bulk-import or manually add employees + assign managers (mechanism TBD — see OQ-FL-5).
5. Configure tenant-level policies: fiscal year start, weekend days, default time zone.
6. Hand off to HR admin for leave-type + public-holiday config (F-U-004).

**Definition of Done**:
- [ ] Tenant active in DB.
- [ ] At least 1 super admin can log in via configured SSO.
- [ ] SSO test login succeeds before tenant goes "active".
- [ ] If Slack connected: a test message posts to configured channel.

**Source**: PRD §F Persona 4 (Tom); §H SSO + Slack; §M Stripe (subscription provisioning).

> **Note**: this flow is partially derived from persona description rather than explicit user story. Multiple unspecified details surface as OQ-FL-4 and OQ-FL-5.

---

## Backend / system flows

### F-S-001: Notification dispatcher

**Trigger**: invoked from F-U-001/002/004/005 on each of the 5 events listed in AC7-1.

**Steps**:
1. Resolve recipient (employee or manager) per event type.
2. Construct deep-link URL to the related resource (request detail, balance page).
3. Dispatch to email channel via configured provider (SendGrid working assumption).
4. If tenant has Slack integration enabled AND this event_type is in `slack_integration.enabled_event_types`, also dispatch to Slack channel.
5. Write `notification` row per channel sent.
6. Email content includes request ID + deep link that auto-logs user in via SSO if applicable (AC7-1).

**Outputs**: 1 row in `notification` per recipient per channel.

**Definition of Done**:
- [ ] Email dispatched within 1 minute of event (per AC7-1).
- [ ] Deep link in email opens app, completes SSO if needed, displays request.
- [ ] Slack post (if enabled) lands within 1 minute.
- [ ] Failed delivery (provider error) recorded in `notification.delivery_status`.

**Source**: PRD §G AC7-1; §H Slack integration.

---

### F-S-002: Delegation routing

**Trigger**: invoked synchronously during F-U-001 step 7 (when determining notification recipient and `approver_user_id` on a new `leave_request`).

**Steps** (PRD §G AC6-2):
1. Load requester's `manager_id`.
2. Check if that manager currently has an `approved` leave whose `start_date <= today <= end_date`.
3. If yes, look up `delegation_assignment` for that manager with `active=true`.
4. If a delegate exists, set `leave_request.approver_user_id = delegate_id` and route notification + pending-queue visibility to the delegate.
5. If no delegate (or manager not currently on leave), route to the manager directly.

**Definition of Done**:
- [ ] Routing decision made at request-creation time (not retroactively reassigned).
- [ ] Delegate sees the request in their pending queue with a flag "Delegated from: {manager name}" (AC6-2).
- [ ] If routing decision is made and the manager returns from leave before approval, decision routing remains with delegate (no auto-rerouting on manager return — confirm with OQ-FL-1).

**Source**: PRD §G AC6-1, AC6-2.

---

### F-S-003: Working-day calculator

**Trigger**: invoked during request submission (F-U-001 step 5) and balance re-computation.

**Steps** (PRD §H Working-day calculation):
1. Iterate over date range from `start_date` to `end_date` inclusive.
2. For each date, exclude if day-of-week is in `tenant.weekend_days` (default Sat/Sun).
3. For each remaining date, exclude if it matches any `public_holiday` row for the tenant.
4. Return count of remaining days as `working_days` (decimal — supports half-day if Q1 resolved as yes; otherwise int).

**Definition of Done**:
- [ ] Calculation respects per-tenant `weekend_days` configuration.
- [ ] Public holidays correctly excluded.
- [ ] Half-day requests (if supported per Q1 resolution) handled correctly.
- [ ] Time zone: working-day calculation uses tenant or user TZ — TBD (OQ-FL-2).

**Source**: PRD §H Working-day calculation.

---

### F-S-004: Stripe webhook handler

**Trigger**: Stripe sends webhook on subscription lifecycle event.

**Steps** (PRD §M):
1. Verify HMAC signature.
2. Match event type: `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_failed`, etc.
3. Update `tenant.stripe_subscription_id` and `tenant.status` accordingly.
4. On payment failed → tenant status TBD (suspended? grace period?) — see OQ-FL-6.

**Definition of Done**:
- [ ] HMAC verification rejects forged webhooks.
- [ ] Tenant status correctly updated within 5 seconds of webhook receipt.
- [ ] Failed payment grace period defined (currently TBD).

**Source**: PRD §M Stripe.

---

### F-S-005: iCal feed serving

**Trigger**: calendar app GET to `/ical/{token}`.

**Steps** (PRD §H iCal):
1. Look up `ical_feed_token.user_id` by token. If not found → 404.
2. Query `leave_request` where requester=user AND status=`approved` AND end_date >= today - 30 days (window TBD, see OQ-FL-7).
3. Render RFC 5545 .ics file with one VEVENT per approved leave.
4. Return with appropriate headers for calendar subscription.

**Definition of Done**:
- [ ] Valid token returns RFC 5545 file.
- [ ] Invalid/revoked token returns 404.
- [ ] Calendar app (Apple Calendar, Google Calendar, Outlook) successfully subscribes and refreshes.

**Source**: PRD §H iCal.

---

### F-S-006: Annual entitlement reset (cron)

**Trigger**: scheduled at the start of each tenant's fiscal year.

**Steps**:
1. For each tenant whose fiscal year start equals today's date:
   - For each active user × leave type: create new `leave_balance` row for the new fiscal year with `total_entitlement_days = leave_type.default_annual_entitlement_days` (or accrual-rule-derived amount).
   - Carryover from previous year: TBD (see OQ-DM-10).
2. Idempotent — re-runs on same day produce no duplicates.

**Definition of Done**:
- [ ] Each active user has exactly one `leave_balance` row per leave type per fiscal year after run.
- [ ] Re-running same day produces no duplicates.
- [ ] Carryover handled per resolved policy (OQ-DM-10).

**Source**: PRD §H Multi-fiscal-year; PRD §G AC4-2 (entitlement changes from next fiscal year only).

---

## Cross-cutting flows

### F-C-001: SSO login end-to-end

**Actor**: any user (employee, manager, HR admin, super admin).
**Layers involved**: Web Frontend · Backend · External SSO (Google or OIDC).

**Steps with handoff points**:
1. **[Frontend]** User opens app → frontend redirects to `/auth/login`.
2. **[Frontend → Backend]** GET `/auth/login` → backend resolves tenant SSO config from email domain (or selection UI).
3. **[Backend → External SSO]** Backend redirects browser to provider's authorize URL.
4. **[External SSO → Backend]** User completes SSO → provider redirects back with code.
5. **[Backend]** Exchange code for ID token; validate; lookup or provision user; issue session.
6. **[Backend → Frontend]** Redirect to dashboard with session cookie / token.

**Definition of Done**:
- [ ] SSO domain match works (OR explicit tenant selection — see OQ-AR-7).
- [ ] First-time login provisions user (if SSO domain matches tenant config); existing user is recognized.
- [ ] Session lifetime + refresh behavior per resolved OQ-AR-7.

**Source**: PRD §H SSO.

---

### F-C-002: End-to-end leave lifecycle (submit → approve → balance)

**Actor**: employee + manager.
**Layers involved**: Web Frontend (employee + manager views) · Backend (request, balance, notification, delegation services) · Email provider · optional Slack.

**Steps with handoff points**:
1. **[Frontend]** Employee submits via F-U-001.
2. **[Frontend → Backend]** `POST /leave-requests`. Backend runs validations (AC1-3/4/5).
3. **[Backend]** Determines approver via F-S-002 (manager or delegate). Persists `leave_request`. Increments `pending_days`.
4. **[Backend → Notification]** Async dispatch via F-S-001: `request_submitted` to approver.
5. **[Manager Frontend]** Manager opens pending queue. Sees request with coverage warning if applicable. Clicks Approve.
6. **[Frontend → Backend]** `POST /leave-requests/{id}/approve`.
7. **[Backend]** Updates status to `approved`. Decrements `pending_days`, increments `used_days` atomically.
8. **[Backend → Notification]** Dispatch `request_approved` to employee.
9. **[Frontend]** Employee receives email; balance view reflects updated state.

**Failure handling per handoff**:
- Step 2 validation fail → frontend shows error, no DB write.
- Step 3 race (e.g., balance went negative due to concurrent change) → return 409 conflict; user retries.
- Step 4 / step 8 notification failure → does not block lifecycle progression; logged in `notification.delivery_status`.

**Definition of Done**:
- [ ] Happy path: 1 `leave_request` row, balance state correct, 2 `notification` rows (submit + approve).
- [ ] Concurrent submit-vs-edit race: balance never goes negative.
- [ ] Notification failure isolated; lifecycle still completes.

**Source**: PRD §G US-1 + US-2 + AC7-1.

---

## Sources

- PRD `PRD-Examples.pdf` v1.0 — §G (User Stories US-1…US-8 + all AC), §H (Functional Requirements), §M (Dependencies)

## Out of Scope

- Mobile-specific flows (no native mobile in v1 per §K).
- Multi-level approval flows (PRD §K explicitly OOS).
- Hourly-leave flows (PRD §K explicitly OOS).
- Payroll, time-tracking, performance review flows.

## Open Questions

- [ ] **OQ-FL-1** [P2]: Delegation routing — when a request was routed to delegate (manager on leave) and the manager returns before the delegate decides, does the request stay with delegate or revert to manager? PRD AC6-2 doesn't specify. Resolve: Sarah Chen + Lisa Wong.
- [ ] **OQ-FL-2** [P2]: Working-day calculation time zone — tenant TZ or user TZ when requester and tenant differ? Affects "is today in the past?" check and date-range edge cases. Resolve: Mike Patel.
- [ ] **OQ-FL-3** [P3]: CSV export size threshold — at what size do we switch from sync download to async link? Default behavior? Resolve: Mike Patel.
- [ ] **OQ-FL-4** [P1]: Tenant onboarding flow — exact signup steps, who creates the first super admin (self-serve via marketing site? sales-led? in-app), Stripe trial provisioning. Sprint-0 blocker. Resolve: Sarah Chen + Mike Patel + leadership.
- [ ] **OQ-FL-5** [P1]: Initial employee bulk-import — CSV upload, SSO directory sync, manual entry only? Manager assignment mechanism (manager email reference? manual map?). Sprint-0 blocker. Resolve: Sarah Chen + Mike Patel.
- [ ] **OQ-FL-6** [P2]: Stripe payment-failed grace period — how many days before tenant suspended? Read-only mode during grace? Resolve: Sarah Chen + leadership.
- [ ] **OQ-FL-7** [P3]: iCal feed window — default is "approved leaves end_date >= today - 30 days". Configurable? Past leaves visible at all? Resolve: Sarah Chen + Maya.
- [ ] **OQ-FL-8** [P2]: Notification template content (subject lines, body copy) not in PRD. Need design + copywriting before launch. Resolve: Maya Rodriguez + Sarah Chen.
- [ ] **OQ-FL-9** [P3]: Coverage-warning threshold — show warning if ≥1 other team member on leave (per AC2-5) is the rule. "Same team" definition: same direct manager? Same department? PRD doesn't define team boundaries beyond manager hierarchy. Resolve: Sarah Chen + Lisa.
- [ ] **OQ-FL-10** [P2]: Approver = requester edge case — what if a manager submits a request for themselves? Self-approval path or auto-route to their own manager? PRD doesn't address. Resolve: Sarah Chen + Lisa.
