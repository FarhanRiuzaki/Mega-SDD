## Chat (main thread)

Guarded lane, and the input is a PRD file, so the chain is `plan` → `execute-bolts --all --lite --inline`. Next I'll run GROUND.

I'm using the orchestrate-flow skill to inspect CWD and propose the next phases. `mega-sdd-trace:orchestrate-flow`

I'm using the plan skill to turn the source into context.md + units. `mega-sdd-trace:plan`

I've read the existing code. I'm checking the test baseline and the v1 PRD next, then I'll write the vault and units.

The baseline is 73 tests passing. Next I'm reading the vault/unit templates and grammar.

Now I'm checking the remaining UI surfaces and seed data, plus whether any v1 tests cancel inside 24 h.

Planning is done. Next I'm getting the PRD heading slugs from the coverage library so the units can cite them.

CONTRACT: screens=4 entities=4 flows=8 oq=13 modules=4. Writing `context.md` next.

Now the `vault.json` patch and derive:

I'm writing the vault module map and 11 units next.

Only one blocking issue class is left: `expects` is empty on the `type: test` entries. Vitest prints `passed` on success, so I'm pinning that string.

While the two reviewers run, I'm continuing with the vault event and OQ validator.

The validators are all green. I'm waiting on the two adversarial reviewers before finalizing the units.

Waiting for the reviewer results.

While waiting, I'm reading the inline execute-bolts contract.

The inline path is clear. Still waiting on the reviewers.

Both reviewers rated coverage "weak" and proposed 6 test gaps in total. I'm merging them into U-004 and U-007.

The plan phase is complete: all validators PASS and the batched ask was answered by the runner (headless). Committing the plan artifacts:

The tree is dirty only from mega-sdd state/cache files, which churn from the validators. I'm committing them to get a clean tree.

Pre-flight passed: 10 baselines captured, and the symbol index is absent (ast-grep not installed; advisory). Next is the up-front bind.

The 5 CONFLICTs are all `must-exist` claims on files an earlier unit creates (`leave.ts` from U-003, `waitlist.ts` from U-006). The exec plan should classify them as `deferred`. Running it:

Karantina: none. All 11 units are in scope, and 3 units have deferred claims that are re-checked at their own re-bind. Reading the plan:

Now invoking superpowers:executing-plans with the plan.

I'm using the executing-plans skill to run the plan inline, on `main`, as the plan's Global Constraints direct.

U-007 and U-008 are showing as modified, so I'm checking the diff:

The anchor-freshness check clamped two anchor line ranges; committing that along with the preflight baselines. Then Task 1.

The plan file is not tracked, so everything is in order. Task 1 (U-001), step 1 is the re-bind and step 2 the preflight.

Step 3: the failing test for U-001.

RED confirmed (the third test is a regression guard and passes already). Step 4: the schema.

The migration only adds things. I'm putting the provenance header on the SQL and running step 5.

Typecheck is clean. Running the full suite before committing:

Acceptance, postflight and gates all pass for U-001. Checking the commit log and the bolt-report schema:

I'm writing a small helper to generate each bolt report (target hashes come from the commit), then finishing Task 1.

Task 1 is done. Next is Task 2 (U-002, cancellation window).

Step 3: the failing test for U-002.

RED for the right reasons. Step 4: implementing.

The acceptance tests (20/20) and the full suite (83 tests) pass, and tsc is clean. Quick check that the e2e spec doesn't cancel inside 24 h:

Tasks 1–2 are done. Starting Task 3 (U-003, doctor leave recording).

RED: the module is missing. Implementing `leave.ts` and the availability checks:

Task 4 (U-004): first checking the v1 reassign tests so the new "free doctor" rules don't break them.

RED. Implementing the email kind, the reassign extension and the leave helpers:

Now `staff.ts` reassign and the `leave.ts` helpers:

U-004 passes 21/21. Running the full suite, then committing and recording evidence:

Task 5 (U-005, leave page UI). Reading the existing staff UI patterns first:

Writing the U-005 component test first, plus the access case in `lib.test.ts`:

RED. Implementing the access rule, nav, component, page and actions:

The component passes 6/6. Now the page and actions:

tsc, eslint and the suite (108) are all green. Committing U-005 and recording evidence:

Task 6 (U-006, waitlist domain), writing the test first:

Waitlist passes 6/6. Suite, commit, evidence:

The U-007 re-bind reports 1 CONFLICT. Inspecting it:

Quarantine recorded. Skipping Tasks 8, 9 and 11; Task 10 (U-010, reception waitlist panel) is next.

Now wiring the panel into the reception page and actions:

All green (118 tests). Committing U-010 and recording evidence:

Every task that isn't quarantined is done. Close step 1 is the full suite gate:

The suite gate is green. Close step 2 is one blind review of the run's range on the most capable model:

Writing the RED tests for both fixes:

RED confirmed. Applying the two fixes:

GREEN, and the suite is 124/124. Committing the fixes as `fix(U-004)` and `fix(U-003)`, then re-recording their evidence:

Close step 4 is the delivery check:

`VERDICT: PASS`. Close steps 5–7 are the suite re-run (commits landed since step 1), the run-evidence commit and the boundary gate:

The boundary gate passes (whitelist, conflict-bypass, postflight, acceptance, panel). Close step 8 retires the run:

Run 1 is retired: 7 units done, 4 quarantined. `binding_conflict` is cycle-eligible under `--deep` convergence, so the chain goes to `resolve-oq --binding` for C-U007-A11:

I'm starting inline run 2 for the 4 remaining units (U-007, U-008, U-009, U-011), beginning with pre-flight and the up-front bind.

Karantina: none. All 4 units are in scope, run base `aa591f9`. I'm continuing with the executing-plans loop against the new plan, retargeting my helpers first.

Task 1 (U-007, waitlist offers), writing the test first. It includes the adversarial pass-2 cases.

RED for the right reasons. Implementing the tokens, email and offer flow:

Now the offer flow in `waitlist.ts` and the hook in `cancelWithToken`:

U-007 passes 9/9 and tsc is clean. Full suite, commit, evidence:

Task 2 (U-008, offer expiry sweep):

U-008 passes 10/10. `vercel.json` gets no provenance header (JSON), under the same ruling as run 1. Suite, commit, evidence:

Task 3 (U-009, public waitlist pages). Reading the wizard's Time step and the booking-wizard test first:

Writing the U-009 component test first:

GREEN (12/12). Now the pages and actions:

All green (144 tests). Committing U-009 and recording evidence:

Task 4 is U-011, a verify unit: no code, only the acceptance run and the report.

`close.sh` exited early because U-011 had no evidence yet (the acceptance writer hadn't run). Running step 5 first:

All 4 tasks of run 2 are done. Closing run 2 with the suite gate and then one blind review of `aa591f9..HEAD`:

RED reproduces the finding exactly. Fixing: roll back on any error.

GREEN, suite 145/145. Committing `fix(U-007)`, re-recording its evidence, then the delivery check:

`VERDICT: PASS`. The rest of the close is the suite re-run, the run-evidence commit, the boundary gate and retiring the run:

All 11 units are executed (11 bolts), and every boundary gate passes. `derive-state` proposes the default-on `detect-drift` gate after execute-bolts:

The final `delivery-check` ran before the last evidence-only commits, so I'm re-running it on the actual final commit:

The whole v2 PRD is built, tested and committed on `main`, and `delivery-check.sh` passes on the final commit (`ab6ce83`):

```
VERDICT: PASS
```

That covers: a real `npm test`, green tests under UTC and UTC+14, `build` green with an empty environment, and all 7 page routes linked. The suite went from 73 to 145 tests.

Some things are left open on purpose, below.

## What was built

| AC | Status | Covering test |
|---|---|---|
| AC-201 join the waitlist when a day is full, same validation as booking | ✅ | `integration/waitlist.test.ts`, `component/waitlist-pages.test.tsx` |
| AC-202 cancelling sends an offer to the first on the waitlist; accepting books online; link works once | ✅ | `integration/waitlist-offers.test.ts`, `integration/waitlist-offers-rollback.test.ts`, `component/waitlist-pages.test.tsx` |
| §4.1 an unaccepted offer passes to the next patient after 30 minutes | ✅ | `integration/waitlist-expiry.test.ts` |
| §4.1 receptionist sees each doctor's waitlist per date and can remove an entry | ✅ | `integration/waitlist.test.ts`, `component/waitlist-panel.test.tsx` |
| AC-203 record doctor leave; that doctor's slots in the range can't be booked | ✅ | `integration/doctor-leave.test.ts`, `unit/lib.test.ts` |
| AC-204 reassign or cancel affected appointments, one at a time or in bulk; patient emailed | ✅ | `integration/doctor-leave-resolve.test.ts`, `component/leave-manager.test.tsx` |
| AC-205 no double booking, even with a simultaneous online booking | ✅ | `integration/doctor-leave-resolve.test.ts` (race tests) |
| AC-206 patient links refused inside the window (default 24 h, configurable); staff not restricted | ✅ | `integration/cancellation-window.test.ts`, `unit/email-copy.test.ts` |
| AC-207 v1 behaviour and tests keep passing | ✅ | U-011: full vitest suite, `tsc`, `eslint` |

The concurrency tests for AC-205 run on the same single-connection embedded Postgres (PGlite) the v1 race tests use. Playwright e2e was not run, and the manual UI walkthroughs for the leave and waitlist pages are still pending.

## Decisions I made on your behalf
- [ASSUMED-BY-RUNNER: front-door confirmation -> Run the proposed chain]
- [ASSUMED-BY-RUNNER: install ast-grep -> no; symbol claims bind as OQ instead]
- [ASSUMED-BY-RUNNER: `rescheduling_required` status doesn't exist in code (OQ-DM-1) -> add it, since the doctor-leave feature depends on it]
- [ASSUMED-BY-RUNNER: VIP patients skip the queue (OQ-FL-1) -> deferred; no VIP attribute exists, so the queue is strictly first-come]
- [ASSUMED-BY-RUNNER: PRD says 20-minute slots, code has 15 (OQ-CN-1) -> deferred; code kept at 15]
- [ASSUMED-BY-RUNNER: PRD says 48-hour reminders, code sends at 24 h (OQ-CN-2) -> deferred; code kept at 24 h]
- [ASSUMED-BY-RUNNER: "late cancellations are penalised" with no penalty defined (OQ-FL-2) -> deferred; nothing built]
- [ASSUMED-BY-RUNNER: binding conflict C-U007-A11 -> KEEP_CODE, re-pointing an anchor that U-004's own change had moved]
- [ASSUMED-BY-RUNNER: drift triage -> the 8 findings stay queued for you]

**Behaviour defaults while questions are open:**
- An expired offer puts the patient back in the queue at their original place (OQ-FL-3).
- There is no new general staff cancel/reschedule in the portal (OQ-FL-4).
- A freed slot stays publicly bookable while an offer is pending (OQ-FL-5).

**Technical choices:**
- The window setting is a `CANCELLATION_WINDOW_HOURS` env var, default 24.
- Offer expiry runs from a new `/api/cron/waitlist-offers` route every 5 minutes, so an expired offer can take up to 5 extra minutes to pass on.
- Offer links use the same signed one-time token scheme as the cancel/reschedule links.
- A waitlist entry stores the service the patient chose.
- The schema changes ship as one generated migration, `drizzle/0001_v2_waitlist_leave.sql`.

**Rulings during execution:**
- The new status badge moved into U-001 so typecheck stays green.
- The v1 e2e helper now books the third bookable day, because the new 24 h window refuses cancelling a same-day booking.
- The stricter "free doctor" rule applies only to leave-affected reassigns; v1 reassign of booked appointments is unchanged.
- JSON config files carry no provenance header.
- The booking-wizard sidebar no longer promises "cancel any time".

**Review fixes:** each was reproduced by a failing test first.
- Patient emails claimed you could cancel any time; they now state the window.
- A patient whose appointment was hit by leave was told their link was "invalid"; it now says the doctor is unavailable.
- An unexpected error while accepting an offer could leave it stuck with no appointment; it now voids the offer and returns the patient to the queue.

## What's still open for you
- **Drift report, 8 findings.** They are in `.mega-sdd/vaults/clinic-v2/PENDING-SYNC.md`. The main one is DR-06: waitlist offers don't account for doctor leave, which needs a product decision.
- **Deferred minors:**
  - A malformed offer link returns a 500.
  - The "join the waitlist" link can flash before times load, and also shows on a doctor's leave days (the form then refuses with a clear message).
  - The README doesn't document the new cron route or `CANCELLATION_WINDOW_HOURS`.
  - Unused Next.js demo images remain in `public/`.
- ⏸ 7 OQs deferred or open: OQ-FL-1, OQ-CN-1, OQ-CN-2, OQ-FL-2 (P1) and OQ-FL-3, OQ-FL-4, OQ-FL-5 (P2). Answer them any time with `resolve-oq`.

## How it ran
- **Plan:** 11 units. The validators and the coverage gate passed, and the two high-risk units got an adversarial test review whose gaps were merged in.
- **Run 1:** built U-001–U-006 and U-010. U-007 was quarantined on a binding conflict, which also held back the three units that depend on it (U-008, U-009, U-011).
- **Run 2:** after resolving the conflict, built U-007, U-008, U-009 and U-011.
- Each run ended with the full suite, one blind review, `VERDICT: PASS` and a clean boundary gate (whitelist, conflict-bypass, postflight, acceptance).

The feature commits are 057256c → 20255ee (13 `feat`/`fix` commits); the rest are evidence and state commits. The vault, units, evidence and reports are in `.mega-sdd/vaults/clinic-v2/`, starting with `DRIFT-REPORT.md` and `PENDING-SYNC.md`.

## Questions put to the user

(none)

## Commit messages

chore(sdd): drift gate report — 8 findings queued in PENDING-SYNC.md

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): run aa591f9 retired

chore(sdd): evidence run aa591f9

chore(sdd): evidence U-007 review fix

fix(U-007): never strand an accepted offer — void it and requeue the patient on any failure

Unit: U-007
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-007
SDD-Acceptance: v5

chore(sdd): validator state refresh

chore(sdd): evidence U-011 — Verify v1 regression

chore(U-011): Verify all v1 behaviour and tests still pass with v2 in place

Unit: U-011
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-011
SDD-Acceptance: v5

chore(sdd): re-bind U-011

chore(sdd): validator state refresh

chore(sdd): evidence U-009 — Public waitlist pages

feat(U-009): Public waitlist pages — join from a full date, accept an offer

Unit: U-009
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-009
SDD-Acceptance: v5

chore(sdd): re-bind U-009

chore(sdd): validator state refresh

chore(sdd): evidence U-008 — Offer expiry sweep

feat(U-008): Expire unaccepted offers after 30 minutes and pass the slot to the next patient

Unit: U-008
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-008
SDD-Acceptance: v5

chore(sdd): re-bind U-008

chore(sdd): validator state refresh

chore(sdd): evidence U-007 — Waitlist offers

feat(U-007): Offer a freed slot to the first waitlisted patient and accept it via a one-time link

Unit: U-007
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-007
SDD-Acceptance: v5

chore(sdd): re-bind U-007

chore(sdd): validator state refresh

chore(sdd): resolve C-U007-A11 KEEP_CODE, release U-007 quarantine (runner, headless)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): run 2cbe4ee retired

chore(sdd): evidence run 2cbe4ee

chore(sdd): evidence U-003, U-004 review fixes

fix(U-003): leave-affected patient links explain the doctor is unavailable

Unit: U-003
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-003
SDD-Acceptance: v5

fix(U-004): patient emails state the cancellation window instead of 'cancel any time'

Unit: U-004
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-004
SDD-Acceptance: v5

chore(sdd): validator state refresh

chore(sdd): evidence U-010 — Reception waitlist panel

feat(U-010): Reception waitlist panel — view each doctor's waitlist per date, remove entries

Unit: U-010
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-010
SDD-Acceptance: v5

chore(sdd): re-bind U-010

chore(sdd): quarantine U-007 (binding_conflict C-U007-A11)

chore(sdd): re-bind U-007

chore(sdd): validator state refresh

chore(sdd): evidence U-006 — Waitlist domain

feat(U-006): Waitlist domain — join, list per doctor and date, remove

Unit: U-006
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-006
SDD-Acceptance: v5

chore(sdd): re-bind U-006

chore(sdd): validator state refresh

chore(sdd): evidence U-005 — Doctor leave page

feat(U-005): Doctor leave page — record leave and resolve affected appointments

Unit: U-005
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-005
SDD-Acceptance: v5

chore(sdd): re-bind U-005

chore(sdd): validator state refresh

chore(sdd): evidence U-004 — Resolve leave-affected appointments

feat(U-004): Reassign or cancel leave-affected appointments, individually or in bulk

Unit: U-004
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-004
SDD-Acceptance: v5

chore(sdd): re-bind U-004

chore(sdd): validator state refresh

chore(sdd): evidence U-003 — Doctor leave

feat(U-003): Record doctor leave and hide the doctor's slots during it

Unit: U-003
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-003
SDD-Acceptance: v5

chore(sdd): re-bind U-003

chore(sdd): validator state refresh

chore(sdd): evidence U-002 — Cancellation window

feat(U-002): Refuse patient cancel/reschedule links inside the cancellation window

Unit: U-002
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-002
SDD-Acceptance: v5

chore(sdd): validator state refresh

chore(sdd): evidence U-001 — Add the v2 schema

feat(U-001): Add the v2 schema — rescheduling_required status, waitlist and doctor-leave tables

Unit: U-001
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-001
SDD-Acceptance: v5

plan(clinic-v2): U-001 owns the StatusBadge variant (execute-bolts ruling)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): preflight baselines + anchor refresh

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): refresh validator state

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

plan(clinic-v2): defer OQ-FL-2 (runner, headless)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

plan(clinic-v2): vault context + 11 units from PRD v2

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

## Recorded notes in committed markdown

### .mega-sdd/vaults/clinic-v2/DRIFT-REPORT.md

## Decision violations & decision unwritten (PRIORITY-1)



> These most often correspond to compliance or architectural debt. Review them first. No **decision violation** was found: every AI Technical Decision and every OQ resolution or interim rule is implemented as written (see Confirmed matches).



### DR-02 — Decision unwritten: one active waitlist entry per patient + doctor + date (confidence: high, severity: HIGH)



**Code reference**: `src/server/waitlist.ts` lines 48-59. Inside the join transaction, an existing `waiting|offered` entry for the same patient (matched by email via `findOrCreatePatient`), doctor and date is refused with "You're already on the waitlist for this doctor and date."

**Vault**: F-U-001 (`context.md ## Flows`) and its DoD do not mention duplicates. The DBML `waitlist_entries` has no uniqueness rule. The rule is enforced only at the application level, and there is no DB constraint.

**Suggested action**:

- (A) Promote to a documented rule by adding a DoD line to F-U-001, optionally with a partial unique index.

- (B) Defer by capturing it as `OQ-DC-1`.



### DR-01 — Decision unwritten: a failed offer email leaves the offer pending (confidence: medium, severity: HIGH)



**Code reference**: `src/server/waitlist.ts` lines 190-209 and 214-236. `offerFreedSlot` commits the offer (entry → `offered`, offer `pending`, `expires_at = now + 30 min`) and then sends the email. If the send fails, `sendOfferEmail` logs the error and returns `false`, and the offer stays `pending`.

**Effect**: the patient is never told. The slot is held for that patient until the sweep expires the offer (up to 30 min plus the 5-min sweep interval) before it passes on.

**Vault**: F-S-001 DoD covers only "An email failure never undoes the cancellation". It says nothing about what happens to the offer itself when its email fails.

**Suggested action**:

- (A) Record this as the intended behaviour in the F-S-001 DoD.

- (B) Change the code so that a failed send immediately voids the offer and passes it on.

- (C) Defer as `OQ-DC-2`.



### DR-04 — Decision unwritten: public waitlist join and offer accept are rate-limited (confidence: medium, severity: HIGH)



**Code reference**: `src/app/(public)/waitlist/actions.ts` lines 21-24 and 35-38. Both actions reuse the v1 `bookingRateLimiter`, keyed per client IP.

**Vault**: neither F-U-001 nor F-U-002 mentions rate limiting, and there is no NFR row for it.

**Suggested action**:

- (A) Add an NFR row (Security, "public waitlist endpoints share the booking rate limit").

- (B) Defer.



### DR-05 — Decision unwritten: the expiry sweep processes at most 200 offers per run (confidence: low, severity: HIGH — verify manually)



**Code reference**: `src/server/waitlist.ts` line 336 (`.limit(opts.limit ?? 200)`).

**Vault**: F-S-002 says "Claim pending offers past expires_at" and states no cap. This is a heuristic finding. The cap is probably an operational safeguard rather than a business decision.

**Suggested action**:

- (A) Note the cap in F-S-002.

- (B) No action.



## Notes & caveats



- Detection is heuristic, based on grep and file reads. There was no AST or type-check. Medium- and low-confidence findings can be false positives.

- Decision detection compared code against the AI Technical Decisions table, the OQ resolutions and `constitution.md`, because the vault has no ADR (`D-XXX`) section. Treat decision findings as triggers for review.

- Architecture-prose drift was not evaluated because a plan-born layout-3 vault has no `## Architecture` section.

- **Changelog**: this layout-3 vault has no Changelog prose section, and its changelog lives in the derived `vault.json`. Because no write-back was applied, `vault.json` was left untouched (no hand-writes), and this drift session is recorded in this report only.

- If the framework was mis-detected, re-run with an explicit `--scope=<dirs>`.

### .mega-sdd/vaults/clinic-v2/PENDING-SYNC.md

## Decision unwritten



### .mega-sdd/vaults/clinic-v2/context.md

## Open Questions



- [x] **OQ-DM-1** [P1] [business] [origin: context.md#Data-model]: PRD §4.2 says recording leave sets appointments to `rescheduling_required`, "the existing status", and §1 lists it among today's statuses — but the live enum is only `booked | cancelled | completed` (`src/db/schema.ts:93`). Should v2 add `rescheduling_required` to the appointment status? → **Resolved v1.0** (plan, 2026-09-28): Add `rescheduling_required` as a new appointment status value (additive migration); v1 statuses unchanged. [ASSUMED-BY-RUNNER]

- [ ] **OQ-FL-1** [P1] [business] [origin: context.md#F-S-001]: PRD §4.1 says "VIP patients skip the waitlist queue and are offered freed slots first", but no VIP attribute exists anywhere (patients have no account; `patients` has name/email/phone only, `src/db/schema.ts:98`). Who is a VIP and how is that recorded? **Deferred (plan)**: no VIP source exists; the queue is strictly first-come until a stakeholder defines VIP. [ASSUMED-BY-RUNNER]

- [ ] **OQ-CN-1** [P1] [business] [origin: context.md#Overview]: PRD §1 says v1 books "20-minute slots", but the live app uses 15-minute slots (`SLOT_MINUTES = 15`, `src/lib/clinic-config.ts:6`; all services 15 min, `src/db/seed.ts:7`). Which is authoritative? **Deferred (plan)**: v1 code (15 min) is kept unchanged per AC-207 until a stakeholder decides. [ASSUMED-BY-RUNNER]

- [ ] **OQ-CN-2** [P1] [business] [origin: context.md#Overview]: PRD §1 says the reminder goes out "48 hours" before, but the live app sends it 24 h before (`REMINDER_LEAD_MS`, `src/lib/clinic-config.ts:13`). Which is authoritative? **Deferred (plan)**: v1 code (24 h) is kept unchanged per AC-207 until a stakeholder decides. [ASSUMED-BY-RUNNER]

- [ ] **OQ-FL-2** [P1] [business] [origin: context.md#F-U-006]: PRD §4.3 says "Late cancellations are penalised" but defines no penalty (and payments are out of scope, §6). What is the penalty, and who applies it? **Deferred (plan)**: no penalty is defined and payments are out of scope (PRD §6); nothing is built for it until a stakeholder defines it. [ASSUMED-BY-RUNNER]

- [ ] **OQ-FL-3** [P2] [business] [origin: context.md#F-S-002]: When an offer expires, does the first patient stay in the queue (keeping their place) or leave the waitlist? Interim until answered: the entry returns to `waiting` (non-destructive).

- [ ] **OQ-FL-4** [P2] [business] [origin: context.md#F-U-006]: PRD §4.3 says staff can "still" cancel or reschedule any time from the portal, but the v1 portal has no general staff cancel/reschedule (only reassign and walk-in booking, `src/server/staff.ts:118`). Should v2 add them? Nothing is built for this until answered.

- [ ] **OQ-FL-5** [P2] [business] [origin: context.md#F-S-001]: While an offer is pending, should the freed slot stay publicly bookable? Interim: v1 behaviour (a cancelled slot frees immediately); a taken slot voids the offer at acceptance.

- [x] **OQ-AR-1** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-006]: Where does the cancellation-window setting live? → **Resolved v1.0** (AI decision, 2026-09-28): `CANCELLATION_WINDOW_HOURS` env var read by `src/lib/clinic-config.ts`, default 24 — same pattern as `CLINIC_TIMEZONE`.

- [x] **OQ-AR-2** [P2] [tech / recommend] [conf: high] [origin: context.md#F-S-002]: What triggers the offer-expiry sweep? → **Resolved v1.0** (AI decision, 2026-09-28): a new protected route `/api/cron/waitlist-offers` (same `CRON_SECRET` bearer check), added to `vercel.json` crons every 5 min and to the self-hosted worker; the reminders route keeps its v1 response.

- [x] **OQ-AR-3** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-002]: How is the one-time offer link built? → **Resolved v1.0** (AI decision, 2026-09-28): HMAC-SHA256 signed token carrying offer id + nonce, the `src/lib/tokens.ts` scheme with a distinct payload key; the nonce is rotated on use.

- [x] **OQ-DM-2** [P2] [tech / recommend] [conf: high] [origin: context.md#Data-model]: A waitlist entry must become an appointment, which needs a service (`appointments.service_id` NOT NULL). Where does it come from? → **Resolved v1.0** (AI decision, 2026-09-28): the entry stores the service the patient chose in the booking flow before reaching the empty date.

- [x] **OQ-AR-4** [P3] [tech / recommend] [conf: high] [origin: context.md#Data-model]: How are the schema changes shipped? → **Resolved v1.0** (AI decision, 2026-09-28): one drizzle-kit generated migration `drizzle/0001_*.sql` (+ meta snapshot/journal), as `package.json` `db:generate` already does.



## AI Technical Decisions



5 technical decisions taken by the AI — override any time: `resolve-oq single-oq <OQ-ID>`.



| OQ-ID | Decision | Basis (citation) | If wrong |

|---|---|---|---|

| OQ-AR-1 [P2] | `CANCELLATION_WINDOW_HOURS` env, default 24 | `src/lib/clinic-config.ts:30` (`CLINIC_TIMEZONE` env pattern) | Move to a settings table with a staff UI |

| OQ-AR-2 [P2] | New `/api/cron/waitlist-offers` route, 5-min cron | `src/app/api/cron/reminders/route.ts:5`, `vercel.json:3` | Fold into the reminders sweep and update its response contract |

| OQ-AR-3 [P2] | HMAC one-time offer token | `src/lib/tokens.ts:1` | Random opaque token stored hashed in `waitlist_offers` |

| OQ-DM-2 [P2] | Entry stores the chosen service | `src/db/schema.ts:119`, `src/lib/validation.ts:22` | Book the accepted slot with the cancelled appointment's service |

| OQ-AR-4 [P3] | drizzle-kit generated migration 0001 | `package.json:15`, `drizzle/meta/_journal.json:5` | Hand-written SQL migration |



### .mega-sdd/vaults/clinic-v2/units/U-001.md

## Migration notes



- **REMOVE**: (none)

- **KEEP**: all v1 tables, columns, indexes and enum values; `appointments_doctor_slot_booked_uq` stays `WHERE status = 'booked'`

- **ADD**: enum value `rescheduling_required`; enums `waitlist_status`, `waitlist_offer_status`; tables `waitlist_entries`, `waitlist_offers`, `doctor_leaves`; migration 0001



### .mega-sdd/vaults/clinic-v2/units/U-002.md

## Migration notes



- **REMOVE**: the "OQ-CLINIC-003 unresolved → most permissive rule" comment

- **KEEP**: v1 refusal once the appointment has started; `INVALID_TOKEN` behaviour; one-time nonce rotation

- **ADD**: window check + config function + clearer `TOO_LATE` copy



### .mega-sdd/vaults/clinic-v2/units/U-003.md

## Migration notes



- **REMOVE**: (none)

- **KEEP**: v1 slot rules, the staff override path, error codes

- **ADD**: leave lookup in three availability checks; the new `leave.ts` module



### .mega-sdd/vaults/clinic-v2/units/U-004.md

## Migration notes



- **REMOVE**: the `status !== "booked"` refusal in `reassignAppointment` (replaced by booked-or-rescheduling_required)

- **KEEP**: v1 reassign of booked appointments, its messages and the `reassigned` email; clash check + unique-index mapping

- **ADD**: availability checks on the target, status flip to `booked`, the `cancelled` email kind, list/free/bulk helpers



### .mega-sdd/vaults/clinic-v2/units/U-005.md

## Migration notes



- **REMOVE**: (none)

- **KEEP**: all existing nav links, route rules and badge variants

- **ADD**: `/staff/leave` route rule + nav link, badge variant, leave page, actions and client component



### .mega-sdd/vaults/clinic-v2/units/U-006.md

## Migration notes



- **REMOVE**: (none)

- **KEEP**: `findOrCreatePatient` behaviour and every other line of `appointments.ts`

- **ADD**: `export` on `findOrCreatePatient`; the new waitlist module + schema



### .mega-sdd/vaults/clinic-v2/units/U-007.md

## Migration notes



- **REMOVE**: (none)

- **KEEP**: appointment token format, `cancelWithToken` return value and errors, all existing email kinds

- **ADD**: offer token pair, `waitlist_offer` email, `offerFreedSlot` hook after cancel, `getOfferByToken` / `acceptOffer`



### .mega-sdd/vaults/clinic-v2/units/U-008.md

## Migration notes



- **REMOVE**: (none)

- **KEEP**: the reminders route, its response and the worker's reminders call

- **ADD**: `sweepExpiredOffers`, the new route, the cron entry, the worker call



### .mega-sdd/vaults/clinic-v2/units/U-009.md

## Migration notes



- **REMOVE**: (none)

- **KEEP**: every existing wizard step, prop and message

- **ADD**: waitlist link in the empty Time step; two pages, actions, forms



### .mega-sdd/vaults/clinic-v2/units/U-010.md

## Migration notes



- **REMOVE**: (none)

- **KEEP**: the existing reception sections and actions

- **ADD**: the waitlist section, remove action and panel component



## CONFLICT verdicts in committed bindings

.mega-sdd/vaults/clinic-v2/bolts/U-001/binding.json: "CONFLICT": 0,

.mega-sdd/vaults/clinic-v2/bolts/U-002/binding.json: "CONFLICT": 0,

.mega-sdd/vaults/clinic-v2/bolts/U-003/binding.json: "CONFLICT": 0,

.mega-sdd/vaults/clinic-v2/bolts/U-004/binding.json: "CONFLICT": 0,

.mega-sdd/vaults/clinic-v2/bolts/U-005/binding.json: "CONFLICT": 0,

.mega-sdd/vaults/clinic-v2/bolts/U-006/binding.json: "CONFLICT": 0,

.mega-sdd/vaults/clinic-v2/bolts/U-007/binding.json: "CONFLICT": 0,

.mega-sdd/vaults/clinic-v2/bolts/U-008/binding.json: "CONFLICT": 0,

.mega-sdd/vaults/clinic-v2/bolts/U-009/binding.json: "CONFLICT": 0,

.mega-sdd/vaults/clinic-v2/bolts/U-010/binding.json: "CONFLICT": 0,

.mega-sdd/vaults/clinic-v2/bolts/U-011/binding.json: "CONFLICT": 0,