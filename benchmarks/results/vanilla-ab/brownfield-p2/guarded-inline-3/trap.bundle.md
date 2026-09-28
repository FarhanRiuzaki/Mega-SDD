## Chat (main thread)

I'm using the orchestrate-flow skill to inspect CWD and propose the next phases. `mega-sdd-trace:orchestrate-flow`

I'm using the plan skill to turn the source into context.md + units. `mega-sdd-trace:plan`

Now the existing codebase.

Still in the plan phase: I've mapped the v1 codebase and am checking whether the existing tests conflict with the new 24h cancellation window before I write the spec.

Rencana sudah jelas; sekarang menulis `context.md` (8 flows, 2 tabel baru, 9 business OQ + 7 AI tech decisions).

Fixing a few off-by-N citations.

Menulis 9 unit sekarang; cek dulu konvensi render-test dari framework pack `next`.

Pack `next` tidak punya `detail_view_glob`, jadi render check di-skip. Menulis unit U-001…U-005.

Menulis U-006…U-009.

Now `_index.md`, then the Step 5 validators.

Validators: hanya advisory trace Hard rule yang tersisa; menambahkan `Source:` per rule.

Semua validator PASS (coverage 8/8, OQ strict-tech PASS). Tersisa advisory DAG depth 5 (inline run tetap serial). Sekarang adversarial review untuk unit `risk: high` (U-004, U-006).

Kedua reviewer menemukan 3 gap masing-masing; merge ke step test + provenance.

✓ Phase 1 of 2: plan → status: completed, units: 9, blocked: 0. Predictive preflight for bolts: 6 ok, 0 fatal.

▶ Phase 2 of 2: invoking execute-bolts (--all --lite --inline --auto)

I'm using the execute-bolts skill to implement units via the mega-sdd bolt agents (parallel review panel). `mega-sdd-trace:execute-bolts`

The hook blocks untracking protected state files, so I won't work around it. I'll commit them as they are, together with the managed `.gitignore`.

Pre-flight OK (anchors fresh, 9 baselines, no hooks; index absent → symbol claims will bind as OQ). Now (b) up-front bind.

The one CONFLICT is U-006 modifying `src/server/waitlist.ts`, which U-005 creates earlier in the run. That's the expected `deferred` case. Running step 3.

Karantina: none. U-006 is deferred (C-U006-A01, the file U-005 creates). Reading the plan.

The Skill tool lists `superpowers:executing-plans`, so I'm invoking it with the plan.

Ledger siap. Baseline full suite dulu (untuk tahu kondisi v1).

Baseline: 73/73 green. **Task 1 (U-001)**.

RED confirmed (4 failed). Now implementing the schema.

`tsc` errors are pre-existing: the `PageProps`/`LayoutProps` globals come from Next's typegen. Generating them (gitignored `.next/`).

Both green. Committing U-001 and recording evidence.

I'll write a small helper in the workspace to generate bolt reports (target hashes computed from the commit).

Task 1 complete. **Task 2 (U-002 emails)**.

RED as expected (the v1 guard passes). Implementing the templates.

The signature change breaks both a caller and my own Hard rule. Reverting to `kind: EmailKind`.

GREEN. I'll wrap the commit + evidence sequence in a workspace script for the remaining units.

A re-bind script refreshed a stale anchor line in `U-002.md` (because U-001 added header lines). Committing it as `fix(U-002)`, then re-running postflight.

**Task 3 (U-003 cancellation window)**.

Correct RED. Implementing.

GREEN (23/23, incl. v1 token/route tests). Now the E2E helper change (OQ-FL-6, setup only).

Also running the full vitest suite before committing.

**Task 4 (U-004 doctor leave domain)**.

RED (module missing). Writing `src/server/leave.ts` and the appointments.ts leave checks.

14/14 GREEN. Tidying: the header line landed in the wrong place, and `inArray` with a single id should be `eq`.

**Task 5 (U-005 waitlist join/list/remove)**.

RED. Implementing validation + `waitlist.ts`.

**Task 6 (U-006 offers)**: re-bind first (the deferred claim should now hold).

Writing the U-006 test (step 5 plus the 3 adversarial additions).

RED (10 failed). Implementing tokens, offer logic, the cancel hook and the cron sweep.

Now the waitlist offer functions.

11/11 GREEN. Cleaning up an awkward leftover in one test, then full suite, typecheck and lint.

**Task 7 (U-007 leave page)**. Reading the existing UI patterns first.

RED test for `LeaveManager` first.

RED. Writing the `LeaveManager` component.

Two issues: a duplicate landmark name (section + region), and the button names. Debugging the names.

JSX drops the leading space. Switching those buttons to explicit `aria-label`s (label-in-name kept) and giving the scroll region a distinct name.

The test's own assumption is wrong: after a successful bulk action the component clears the selection, which is right since those rows leave the list. Fixing the test step to select Omar explicitly.

GREEN. Now actions, page and the nav links.

**Task 8 (U-008 staff waitlist page)**.

GREEN. Page and action.

**Task 9 (U-009 patient waitlist UI)**. Reading the wizard and its tests first.

Writing the U-009 test: wizard join mode, offer page, and accept action.

RED. Writing the offer page and accept action.

Offer page green. Now the wizard's join mode.

GREEN (wizard v1 tests still pass). Wiring the server action and the page prop.

All 9 tasks are done. **After the last task**, step 1: the full suite.

Suite green. Step 2: the ONE blind review, run on the most capable model in the foreground since the fix pass depends on it.

Suite 150/150 green. Committing the fixes attributed per unit, then re-recording each unit's evidence.

Updating the bolt reports of the 4 fixed units (fix commit + target hashes at HEAD), then committing the evidence.

Step 4: the delivery check.

`VERDICT: PASS`. Step 5: commits landed since the first suite run, so I'm re-running it. Then the run-evidence commit and the run-boundary gate.

All 9 units of Harbor Clinic v2 are built and committed on `main`. The final delivery check on HEAD `659a554` printed `VERDICT: PASS` (npm test green under UTC and UTC+14, build passes with no `.env`, every page reachable from navigation). Six things (the VIP queue, late-cancellation penalties, two v1 value mismatches in the PRD, and a general staff cancel/reschedule) were not built because the PRD leaves them undefined and no one could answer. The Playwright E2E tests were not run.

## Acceptance criteria

| AC | Status | Covered by |
|---|---|---|
| AC-201 Join the waitlist when a day is full; bad input rejected with the booking rules | ✅ | `tests/integration/waitlist-join.test.ts`, `tests/component/waitlist-ui.test.tsx` |
| AC-202 Cancelling offers the slot to the first waiting patient; accepting books it online; link works once | ✅ | `tests/integration/waitlist-offer.test.ts`, `tests/component/waitlist-ui.test.tsx` |
| AC-203 Receptionist records leave; the doctor's slots in the range can't be booked | ✅ | `tests/integration/doctor-leave.test.ts` |
| AC-204 Affected appointments listed; reassign (same time) or cancel, one by one or in bulk; patient emailed | ✅ | `tests/integration/doctor-leave.test.ts`, `tests/component/leave-manager.test.tsx` |
| AC-205 Reassignment never double-books, even against a concurrent online booking | ✅ | `doctor-leave.test.ts` concurrency tests (the database's unique index decides) |
| AC-206 Patient cancel/reschedule link refused inside the window (default 24 h, configurable); staff unrestricted | ✅ | `tests/integration/cancellation-window.test.ts` |
| AC-207 All v1 behaviour and tests keep passing | ✅ vitest (all 73 v1 tests still pass; 150/150 total) · ⚠️ E2E not run | Only the E2E booking helper changed, so two E2E scenarios book outside the 24 h window; no assertion changed |

## What ran
- **Plan:** 8 flows, 3 tables touched (1 new status + 2 new tables), 16 open questions, 9 units. All planning validators passed.
- **Build:** 9/9 units done, 0 failed, 0 skipped, none quarantined. Every unit was written test-first and has its acceptance, hard-rule and code-gate evidence recorded. The end-of-run gate passed all seven of its scans.
- **Review:** one independent review of the whole change found 0 Critical, 3 Important, 8 Minor.
  - The 3 Important were fixed, each with a failing test first:
    - Recording leave now takes that day's waiting patients off the waitlist instead of stranding them.
    - The booking page no longer offers a waitlist join on a leave day, where it would always fail.
    - The leave page looks up free doctors in 3 queries instead of hundreds.
  - The Minors are deferred.
- **Drift check:** the code matches the vault on 33 checks. Ten items are queued in `PENDING-SYNC.md` for a human, mostly behaviour added by the review fixes that the vault doesn't describe yet. The top three to decide are listed at the end.
- Profile: `full`, but the optional lint/analyze diagnostics were not run.

## Assumptions and decisions
- **Answered by me in place of the owner:**
  - `rescheduling_required` didn't exist in v1 → added as a new status.
  - v1 had no cancellation email → added one, sent only when staff cancel a leave-affected appointment.
  - A patient whose offer expires leaves the waitlist and can join again.
  - The E2E helper books two days out for the cancel/reschedule scenarios.
- **Open questions I left open, so nothing was built for them:**
  - The PRD says 20-minute slots and 48 h reminders, but v1 uses 15 minutes and 24 h. The code is unchanged.
  - VIP patients skipping the queue.
  - Late-cancellation penalties.
  - A general staff cancel/reschedule feature.
  - Answer any time with `resolve-oq`.
- **Technical choices I made:**
  - The cancellation window is the `CANCELLATION_WINDOW_HOURS` env var, default 24; an invalid value falls back to 24.
  - Offer links reuse v1's one-time signed-link scheme.
  - Expired offers are swept by the existing 5-minute reminder cron.
  - The waitlist entry remembers the service chosen in the wizard.
  - I did not install ast-grep, so code claims were recorded as unverified rather than confirmed.
- **Other calls during the build:**
  - `npm run typecheck` needs `npx next typegen` to run first. That was already true in v1.
  - The two drizzle metadata files carry no provenance header (JSON has no comments).
  - Reassigning or cancelling rotates the patient's link, so old email links stop working.
  - Accepting an offer uses up the link before booking, so a double-click can't book twice.
  - Free doctors for the leave page are computed on the server.
  - I corrected two of my own test expectations. After a bulk action the selection clears. The earlier leave-day sweep test now asserts the stronger behaviour.
  - The offer page shows its result through a redirect query string.
  - Leave recorded for past dates is allowed.
- **Deferred minors:**
  - A narrow race between recording leave and an online booking at the same moment.
  - The v1 reception-board reassign can still pick a doctor on leave.
  - Leave-affected rows on the reception board don't link to the leave page.
  - The per-row cancel on the leave page has no confirm step.
  - After a partially failed bulk action, the selection keeps rows that already succeeded.
  - An invalid window setting falls back to 24 h without a warning.
  - `README` and `.env.example` don't mention the window setting.
  - The schedule grid has no border style for the new status.

## Commits (from `3a61cce`)
- `2d705c3` feat(U-001)
- `717614c` feat(U-002)
- `7ee95b0` fix(U-002)
- `0c3a1c2` feat(U-003)
- `836e3e7` feat(U-004)
- `476e0b4` feat(U-005)
- `bdca70c` feat(U-006)
- `e821951` feat(U-007)
- `770b0ba` feat(U-008)
- `d05b38d` feat(U-009)
- Review fixes: `f70c74d` U-004, `07c405e` U-006, `74c98ad` U-007, `6454619` U-009
- Evidence and drift-report commits, ending at `659a554`

Earlier commits: `c400b67` (plan vault) and two chore commits for mega-sdd state.

**Decide first in `PENDING-SYNC.md`:**
- Leave silently removes waitlisted patients, with no email.
- An offer whose slot becomes unbookable is closed for good.
- On a leave day the booking page says the doctor isn't available instead of offering the waitlist.

Run `/mega-sdd:sync` to go through them.

## Questions put to the user

(none)

## Commit messages

chore(sdd): post-bolt drift report + pending-sync queue (clinic-v2)

chore(sdd): evidence run 3a61cce — boundary-gate postflight recompute

chore(sdd): evidence run 3a61cce

chore(sdd): evidence review fixes U-004 U-006 U-007 U-009

fix(U-009): report a doctor's leave day instead of offering a doomed waitlist join (review Important 2)

Unit: U-009
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-009
SDD-Acceptance: v5

fix(U-007): use the batched free-doctor lookup on the leave page (review Important 3)

Unit: U-007
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-007
SDD-Acceptance: v5

fix(U-006): close an offer whose slot became unbookable instead of re-promising it (review Important 1)

Unit: U-006
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-006
SDD-Acceptance: v5

fix(U-004): close waitlist entries on leave days; batch free-doctor lookup (review Important 1, 3)

Unit: U-004
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-004
SDD-Acceptance: v5

chore(sdd): evidence U-009 — Patient waitlist UI — join from the booking wizard, accept an offer page

feat(U-009): Patient waitlist UI — join from the booking wizard, accept an offer page

Unit: U-009
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-009
SDD-Acceptance: v5

chore(sdd): evidence U-008 — Staff "Waitlist" page — each doctor's waitlist per date, remove entry

feat(U-008): Staff "Waitlist" page — each doctor's waitlist per date, remove entry

Unit: U-008
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-008
SDD-Acceptance: v5

chore(sdd): evidence U-007 — Staff "Doctor leave" page — record leave and resolve affected appointments

feat(U-007): Staff "Doctor leave" page — record leave and resolve affected appointments

Unit: U-007
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-007
SDD-Acceptance: v5

chore(sdd): evidence U-006 — Waitlist offers — offer freed slot on cancel, one-time accept, 30-minute expiry sweep

feat(U-006): Waitlist offers — offer freed slot on cancel, one-time accept, 30-minute expiry sweep

Unit: U-006
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-006
SDD-Acceptance: v5

chore(sdd): evidence U-005 — Waitlist domain — join, list per doctor and date, remove

feat(U-005): Waitlist domain — join, list per doctor and date, remove

Unit: U-005
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-005
SDD-Acceptance: v5

chore(sdd): evidence U-004 — Doctor leave domain — record leave, block slots, reassign or cancel affected appointments

feat(U-004): Doctor leave domain — record leave, block slots, reassign or cancel affected appointments

Unit: U-004
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-004
SDD-Acceptance: v5

chore(sdd): evidence U-003 — Refuse patient cancel/reschedule links inside the configurable cancellation window

feat(U-003): Refuse patient cancel/reschedule links inside the configurable cancellation window

Unit: U-003
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-003
SDD-Acceptance: v5

chore(sdd): evidence U-002 — Add the cancellation and waitlist-offer email templates

fix(U-002): refresh appUrl anchor line after U-001 header

Unit: U-002
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-002

feat(U-002): Add the cancellation and waitlist-offer email templates

Unit: U-002
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-002
SDD-Acceptance: v5

chore(sdd): evidence U-001 — Add rescheduling_required status, waitlist_entries and doctor_leave tables with migration

feat(U-001): Add rescheduling_required status, waitlist_entries and doctor_leave tables with migration

Unit: U-001
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-001
SDD-Acceptance: v5

chore(sdd): mega-sdd managed gitignore + validator state

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

plan: clinic-v2 vault (context.md, constitution, 9 units)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

## Recorded notes in committed markdown

### .mega-sdd/vaults/clinic-v2/DRIFT-REPORT.md

## Decision violations & decision unwritten (PRIORITY-1)



**Decision violations: none found.** Code implements all 7 AI technical decisions and all 4 resolved P1 OQs as written (see Confirmed matches).



### Missing in vault: `doctor_leave.note` limited to 500 characters (confidence: high, severity: HIGH)



**Vault** (`context.md` DBML `doctor_leave`): `note text` has no length rule.

**Code** (`src/server/leave.ts:32`): `note: z.string().trim().max(500, …)`. The DB column is still `text` (`drizzle/0001_v2_waitlist_leave.sql:10`).

**Suggested action**: (A) add a DBML note `max 500 chars (app validation)`; (B) remove the limit from the code.



### Behavior drift: `offer_nonce` rotation is broader than the DBML note (confidence: high, severity: HIGH)



**Vault** (DBML `waitlist_entries.offer_nonce`): "rotated on every offer/accept/expiry".

**Code**: the nonce is also rotated on receptionist removal (`src/server/waitlist.ts:143`), on leave closure (`src/server/leave.ts:96`), on the slot-taken reset (`src/server/waitlist.ts:311`), and on the unbookable-slot close (`src/server/waitlist.ts:320`). `src/db/schema.ts:186` documents "offer / accept / expiry / removal".

**Suggested action**: (A) widen the DBML note to "every state change"; (B) no code action is expected, because this is a strictly safer superset.



## Vault-internal note (not code drift)



- `units/_index.md` still lists all 9 units as `pending`, but every `bolts/U-00*/postflight.json` is `pass`. The status column is stale.

- Layout-3 context.md has no Changelog section, and detect-drift never writes `vault.json`. This drift session is therefore recorded only in this report and in `PENDING-SYNC.md`. The vault version is unchanged (v1.0) because nothing was written back (`--auto-apply=safe` was not set).



## Notes & caveats



- Detection is heuristic: files were grepped and read, with no AST or type-check. Low-confidence findings may be false positives.

- Scanned: `src/`, `drizzle/`, `tests/` (the diff only), `scripts/reminder-worker.ts`, `vercel.json`, `package.json`.

- Excluded: `node_modules/`, `public/`, `.mega-sdd/` (except as vault input), `docs/`, `PRD/`.

- Tests were not executed by this scan. The bolt postflights report `pass`.

### .mega-sdd/vaults/clinic-v2/PENDING-SYNC.md

### Decision unwritten



- [ ] **DU-1** [HIGH · conf high] **Recording leave removes `waiting`/`offered` waitlist entries on leave days without notifying the patient.**

  - Vault: `context.md#F-U-004` (silent on this).

  - Code: `src/server/leave.ts:92-104`.

  - Options: UPDATE_VAULT (add the step and DoD to F-U-004, and optionally an OQ about notifying those patients), FIX_CODE, or DEFER as OQ-DC-1.

  - proposed_patch: in the F-U-004 Mermaid diagram, add `L --> WL[("waiting/offered waitlist entries for that doctor in the range become removed, nonce rotated")]`. Add the DoD line "- [ ] Waitlist entries of the doctor inside the range leave the queue; open offer links die." Provenance: `(synced from code: f70c74d "fix(U-004): close waitlist entries on leave days; batch free-doctor lookup (review Important 1, 3)" — Farhan, 2026-09-28)`.

- [ ] **DU-2** [HIGH · conf high] **Accepting an offer whose slot became unbookable closes the entry as `expired`.**

  - Vault: `context.md#F-U-002`.

  - Code: `src/server/waitlist.ts:315-323`.

  - Options: UPDATE_VAULT (add the branch) or FIX_CODE (return the entry to `waiting` instead).

  - proposed_patch: in the F-U-002 diagram, add `B -- "no longer bookable (e.g. leave)" --> U(["'Can no longer be booked' message; entry expired, nonce rotated"])`. Provenance: `(synced from code: 07c405e "fix(U-006): close an offer whose slot became unbookable instead of re-promising it (review Important 1)" — Farhan, 2026-09-28)`.

- [ ] **DU-3** [HIGH · conf medium] **Leave reassign/cancel rotates `appointments.token_nonce`, which invalidates the patient's old links.**

  - Code: `src/server/leave.ts:281`, `:300`.

  - Vault: `context.md#F-U-005` (silent on this).

  - Options: UPDATE_VAULT or DEFER.

- [ ] **DU-4** [HIGH · conf medium] **Waitlist join is rate-limited with `bookingRateLimiter`.**

  - Code: `src/app/(public)/book/actions.ts:52-55`.

  - Vault: `context.md#F-U-001` (silent on this).

  - Options: UPDATE_VAULT or treat it as covered (no action).

- [ ] **DU-5** [HIGH · conf low · verify manually] **A patient reschedule frees a slot but no waitlist offer is made.**

  - Code: only `cancelWithToken` calls `offerFreedSlot` (`src/server/appointments.ts:321-322`). `rescheduleWithToken` (`:334`) does not.

  - Vault: the F-S-001 trigger says cancellation only.

  - Options: UPDATE_VAULT (state that reschedule is out of scope) or FIX_CODE.



### .mega-sdd/vaults/clinic-v2/context.md

## Open Questions



- [x] **OQ-DM-1** [P1] [business] [origin: context.md#Data-model]: PRD §1 and §4.2 call `rescheduling_required` "the existing status", but the v1 enum is only `booked | cancelled | completed` (`src/db/schema.ts:94`). Add it as a new status, or use something else for leave-affected appointments? → **Resolved v1.0** (plan, 2026-09-28): add `rescheduling_required` as a new, additive enum value; nothing else in v1 changes. [ASSUMED-BY-RUNNER — headless benchmark, most conservative option]

- [x] **OQ-FL-1** [P1] [business] [origin: context.md#F-U-005]: PRD §4.2 says the patient "receives the cancellation email with a link to book again", but v1 sends no cancellation email at all (`EmailKind` = confirmation | reminder | rescheduled | reassigned, `src/server/email/mailer.ts:4`). Create a new cancellation email — and for which cancellations? → **Resolved v1.0** (plan, 2026-09-28): new `cancelled` email, sent only when staff cancel a leave-affected appointment; v1 patient self-cancel stays without email. [ASSUMED-BY-RUNNER — headless benchmark, most conservative option]

- [x] **OQ-FL-5** [P1] [business] [origin: context.md#F-S-002]: PRD §4.1 footnote: "an unaccepted offer passes to the next patient in the queue". Does the patient whose offer expired stay on the waitlist, or leave it? → **Resolved v1.0** (plan, 2026-09-28): the entry becomes `expired` and leaves the queue; the patient may join again. [ASSUMED-BY-RUNNER — headless benchmark, most conservative option]

- [x] **OQ-FL-6** [P1] [business] [origin: context.md#F-U-006]: the v1 E2E tests "AC-001 + AC-003" and "AC-006" (`tests/e2e/clinic.spec.ts:89`, `:109`) book the earliest free slot (often within 24 h) and then cancel/reschedule it through the link. The 24 h window (AC-206) would refuse that, so AC-207 ("v1 tests keep passing") conflicts with AC-206. Which wins, and how? → **Resolved v1.0** (plan, 2026-09-28): AC-206 changes that v1 behaviour on purpose; only the E2E booking helper changes so those two scenarios book a day beyond the window — no assertion changes. [ASSUMED-BY-RUNNER — headless benchmark, most conservative option]

- [ ] **OQ-CN-1** [P2] [business]: PRD §1 says v1 books "20-minute slots", but the code uses 15 minutes (`SLOT_MINUTES = 15`, `src/lib/clinic-config.ts:6`; booking page copy `src/app/(public)/book/page.tsx:21`). Which is authoritative? v2 builds nothing on slot length.

- [ ] **OQ-CN-2** [P2] [business]: PRD §1 says reminders go out "48 hours" before, but the code sends them 24 h ahead (`REMINDER_LEAD_MS`, `src/lib/clinic-config.ts:13`; README "Reminder sweep"). Which is authoritative? v2 builds nothing on reminder lead time.

- [ ] **OQ-FL-2** [P2] [business] [origin: context.md#F-S-001]: PRD §4.1 "VIP patients skip the waitlist queue" — there is no VIP concept anywhere (patients have no account, PRD §3; `patients` table has no such field, `src/db/schema.ts:97`). Who is VIP, and who marks it?

- [ ] **OQ-FL-3** [P2] [business] [origin: context.md#F-U-006]: PRD §4.3 "Late cancellations are penalised" — no penalty is defined (what, how much, applied by whom); payments are out of scope (PRD §6).

- [ ] **OQ-FL-4** [P2] [business] [origin: context.md#F-U-006]: PRD §4.3 "Staff can still cancel or reschedule at any time from the portal" — the v1 portal has no general staff cancel/reschedule (reception actions are reassign + walk-in only, `src/app/staff/(app)/reception/actions.ts:24`). Build one, or does "staff actions" mean the existing ones plus the leave list?

- [x] **OQ-AR-1** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-006]: Where does the "clinic setting" for the window length live? → **Resolved v1.0** (AI decision, 2026-09-28): env var `CANCELLATION_WINDOW_HOURS` (default 24) read in `src/lib/clinic-config.ts`, the same way `CLINIC_TIMEZONE` is (`src/lib/clinic-config.ts:30`); no settings UI.

- [x] **OQ-DM-2** [P2] [tech / recommend] [conf: high] [origin: context.md#Data-model]: How is the waitlist stored? → **Resolved v1.0** (AI decision, 2026-09-28): new Drizzle table `waitlist_entries` (one row per patient per doctor+date, offer columns on the row) + a drizzle-kit migration, following `src/db/schema.ts` and `drizzle/0000_init.sql`.

- [x] **OQ-DM-3** [P2] [tech / recommend] [conf: high] [origin: context.md#Data-model]: How is doctor leave stored? → **Resolved v1.0** (AI decision, 2026-09-28): new table `doctor_leave` with inclusive `date` start/end, in the same migration as `waitlist_entries`.

- [x] **OQ-AR-2** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-002]: How is the offer link made one-time? → **Resolved v1.0** (AI decision, 2026-09-28): HMAC-signed token over `{entryId, nonce}` using the v1 signer in `src/lib/tokens.ts:21`; the entry's `offer_nonce` is rotated on accept/expiry, exactly like `appointments.token_nonce`.

- [x] **OQ-AR-3** [P2] [tech / recommend] [conf: high] [origin: context.md#F-S-002]: How do offers expire? → **Resolved v1.0** (AI decision, 2026-09-28): lazily on accept (expired → refused) plus a sweep called from the existing cron route `src/app/api/cron/reminders/route.ts:18` (5-minute cadence, `vercel.json`); no new scheduler.

- [x] **OQ-AR-4** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-005]: How is AC-205 guaranteed under concurrency? → **Resolved v1.0** (AI decision, 2026-09-28): reassignment flips `doctor_id` + `status = booked` in one UPDATE inside a transaction, so the existing partial unique index `appointments_doctor_slot_booked_uq` (`src/db/schema.ts:144`) rejects the loser (mapped to `SLOT_TAKEN` like `src/server/staff.ts:137`).

- [x] **OQ-FL-7** [P2] [tech / recommend] [conf: medium] [origin: context.md#F-U-001]: An appointment needs a service (`appointments.service_id` not null, `src/db/schema.ts:127`) but PRD §4.1 lists only name/email/phone/reason for the waitlist. Which service does an accepted offer book? → **Resolved v1.0** (AI decision, 2026-09-28): the entry records the service already chosen in wizard step 1 (`src/components/booking/booking-wizard.tsx:27`); the accepted offer books that service.



## AI Technical Decisions



> 7 keputusan teknis diambil AI — override kapan saja: `resolve-oq single-oq <OQ-ID>`.



| OQ-ID | Decision | Basis (citation) | If wrong |

|---|---|---|---|

| OQ-AR-1 [P2] | `CANCELLATION_WINDOW_HOURS` env, default 24 | `src/lib/clinic-config.ts:30` | Move to a DB settings row + staff settings page |

| OQ-DM-2 [P2] | `waitlist_entries` table with offer columns | `src/db/schema.ts:117`, `drizzle/0000_init.sql` | Split offers into their own table |

| OQ-DM-3 [P2] | `doctor_leave` table, inclusive dates | `src/db/schema.ts:117` | Store per-day rows instead of a range |

| OQ-AR-2 [P2] | Reuse the HMAC token + nonce rotation | `src/lib/tokens.ts:21` | Random opaque token stored hashed |

| OQ-AR-3 [P2] | Lazy check + sweep in the existing cron route | `src/app/api/cron/reminders/route.ts:18` | Dedicated cron route |

| OQ-AR-4 [P2] | One UPDATE in a tx; the partial unique index decides | `src/db/schema.ts:144` | Row lock (`SELECT … FOR UPDATE`) on the target slot |

| OQ-FL-7 [P2] | Entry stores the wizard's chosen service | `src/components/booking/booking-wizard.tsx:27` | Ask for the service on the join form |



### .mega-sdd/vaults/clinic-v2/units/U-001.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: every v1 table, column, enum value and index; `drizzle/0000_init.sql` byte-identical.

- **ADD**: enum value `rescheduling_required`; enum `waitlist_status`; tables `waitlist_entries`, `doctor_leave`; `APPOINTMENT_STATUSES` value; StatusBadge entry.



### .mega-sdd/vaults/clinic-v2/units/U-002.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: v1 kinds, subjects, copy and footer.

- **ADD**: kinds `cancelled`, `waitlist_offer`; `waitlistOfferEmail()`.



### .mega-sdd/vaults/clinic-v2/units/U-003.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: the TOO_LATE rule, token/nonce checks, every v1 message and status code.

- **ADD**: `cancellationWindowMs()`, error code `WINDOW_CLOSED`, the window check, the cancel-page message, the E2E day-skip option.



### .mega-sdd/vaults/clinic-v2/units/U-004.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: v1 slot rules, override semantics, `reassignAppointment`, all v1 errors.

- **ADD**: `src/server/leave.ts`; leave checks in three functions of `src/server/appointments.ts`.



### .mega-sdd/vaults/clinic-v2/units/U-005.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: `patientDetailsSchema`, `bookingSchema`, `staffBookingSchema` unchanged.

- **ADD**: `waitlistJoinSchema`; `src/server/waitlist.ts`.



### .mega-sdd/vaults/clinic-v2/units/U-006.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: `cancelWithToken` return value and errors; appointment tokens; cron auth and response body; worker schedule.

- **ADD**: offer tokens; `offerFreedSlot`, `getOffer`, `acceptOffer`, `sweepExpiredOffers`; the post-cancel hook; the sweep calls.



### .mega-sdd/vaults/clinic-v2/units/U-007.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: doctor nav and the existing receptionist link.

- **ADD**: leave page, actions, `LeaveManager`, two receptionist nav links (Doctor leave, Waitlist).



### .mega-sdd/vaults/clinic-v2/units/U-008.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: staff layout and access rules.

- **ADD**: waitlist page, action, `WaitlistTable`.



### .mega-sdd/vaults/clinic-v2/units/U-009.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: all v1 wizard steps, copy and props.

- **ADD**: optional `joinWaitlist` prop + join mode; `joinWaitlistAction`; offer page + action.



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