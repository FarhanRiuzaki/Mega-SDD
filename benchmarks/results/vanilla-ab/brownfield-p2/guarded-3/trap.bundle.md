## Chat (main thread)

I'm using the orchestrate-flow skill to inspect CWD and propose the next phases. `mega-sdd-trace:orchestrate-flow`

I'm using the plan skill to turn the source into context.md + units. `mega-sdd-trace:plan`

Now let me understand the existing codebase.

Status: finishing the plan-authoring rules (there's no symbol index, so units that touch existing files become `extend` through the collision policy). Then I'll write the vault.

Writing the vault files now: `context.md` first, then the constitution.

Fixing the line numbers I got wrong.

Now the constitution and consumer guide.

Next, the units. First a quick look at the slot-picker empty state so I can brief the waitlist-UI unit accurately.

Writing the units in two batches: data, waitlist server and offer engine first.

Second batch of units (U-007 to U-012).

Dispatching adversarial reviewers for the two high-risk units (U-004, U-012) in parallel, and writing `_index.md` while they run.

While the reviewers run, running the Step 5 validators.

Fixing the findings: `expects` literals, Migration notes on U-008/U-011, hard-rule traces, and the U-005 xs diet.

Unit spec passes (remaining advisories: U-001 is the schema foundation hub, and the split candidates exceed 4 target files only because the test files are listed). Next validators:

Coverage PASS. Now the `units_generated` event and the strict OQ validator.

The existing app already has a sourced design system: v1 PRD §8.2–§8.4 (referenced from v2 PRD §1) and `globals.css`. I'm recording that source rather than emitting a Design-Source OQ.

All Step 5 validators pass. Re-running coverage and the constitution check after the context edit:

Preflight is clean (6 ok, 0 fatal). Committing the plan artifacts so the bolts start from a clean tree.

✓ Phase 1 of 2: plan → status: completed, items: 12 units, blocked: 0 (6 P1 OQs deferred)

▶ Phase 2 of 2: invoking execute-bolts (--all --lite --auto)

I'm using the execute-bolts skill to implement the units with the mega-sdd bolt agents, each reviewed by a parallel review panel. `mega-sdd-trace:execute-bolts`

Running the pre-flight batch: git hooks, anchor freshness, L0 probe, symbol index, parallelism plan.

Wave 1 bind passes: 0 CONFLICT, and `text_claims=0` so the bind cost zero model tokens. The 5 symbol claims are OQ because there's no symbol index. Now the Hard-rule pre-flight scan:

All 12 baselines captured. Now tier routing and dispatch prompts for wave 1:

Dispatching both wave-1 implementers in parallel (their target files don't overlap).

While the implementers work, reading the bolt-report schema I'll need after they return.

Both implementers are still running. I'll wait with a blocking monitor rather than end the turn.

Waiting for the wave-1 implementers (U-001, U-002). I'll run each unit's detect-after gates as soon as it returns.

Both bolt commits have landed. Running L0 gates, postflight and acceptance for U-001 and U-002:

Readiness keys on a canonical `bolt-report.md` with `target_hashes`, and the implementer reports have no frontmatter. Adding the controller-owned frontmatter:

U-003, U-004 and U-005 are ready. Binding them and building their prompts:

Wave 2 bind passes (0 CONFLICT, zero-token). U-005 is `unit_tier: xs`, so the lite W2 cell routes it to sonnet. Building the lens slices for the U-001/U-002 panels:

Dispatching 3 wave-2 implementers plus the blind panels for U-001 (standard tier) and U-002 (full tier + design) in one message:

Eleven agents are running. Setting a blocking fallback wait on the wave-2 commits:

Saved the U-001 quality return (2 Minor). Waiting for the other lenses and implementers.

Saved. Still waiting on the other lenses and the wave-2 implementers.

Saved. Remaining: spec lenses for U-001/U-002, the U-002 design lens, and three implementers.

U-002's spec lens passes. Waiting for the U-002 design lens, the U-001 spec lens, and the implementers.

U-002's panel is complete. Merging it:

The U-001 spec lens reports it deleted `tests/integration/waitlist.test.ts` from the working tree. Checking whether that file is committed (U-003's test) so I can restore it:

It's committed in U-003's commit, so restoring it from HEAD is lossless:

U-005 has landed (`f4465cd`). Running its detect-after pipeline, then readiness:

Plan: `dispatch_now` = U-006, U-009, U-007 (target files don't overlap, and none overlap U-004 in flight). Prepping them:

U-004 has landed too, which frees the fourth slot for U-010. Prepping U-010 and running U-004's detect-after:

Eleven agents are running (4 implementers, 7 reviewers). I'll handle each return as it arrives.

U-005 spec passes (minimal tier). Merging and completing it:

U-005 is complete (`a2f602b`). Still waiting on the rest.

Saved U-004 security (1 Minor race). Waiting.

Saved. Waiting for the U-004 spec and design lenses, the U-003 spec lens, and the four implementers.

U-003 is complete (`6fd4c13`). Waiting.

Saved. Waiting for the U-004 spec lens and the implementers.

U-006 has landed (`30c2f68`). Running its detect-after:

U-009 has landed (`97bea1b`) without a bolt-report, so I'm writing its body from the self-report and running its detect-after:

The step was inserted above step 4. Fixing the ordering:

Checking readiness:

U-008, U-011 and U-012 are ready (target files disjoint). Prepping them and refreshing U-010's lens slices for the amended spec:

Committing the writer's anchor repairs for U-011/U-012 and rebuilding their prompts:

Dispatching 3 sprint-4 implementers plus the round-1 panels for U-006, U-007, U-009 and U-010 (U-010 judged against the amended spec):

The three implementer dispatches were denied by the gate: U-010's acceptance evidence went stale when its unit file was amended. First, saving the lens returns and checking what moved HEAD:

HEAD moved only through my own commits. Refreshing U-010's acceptance evidence against the amended unit, then re-dispatching the three implementers:

Saving the returns, merging and completing U-009 (minimal tier), then retrying the three implementer dispatches:

U-007's panel is complete. Merging and completing it:

U-006 and U-007 are complete (gates clear). Retrying the sprint-4 implementer dispatches:

As expected, U-010's spec lens fails on the amended step 5. Saving it; once the standards lens returns I'll merge and run the fix round.

Waiting for U-010's standards lens and the three sprint-4 implementers.

Gate says `re-dispatch`: 3 open Criticals (the route-map entry and its tests). Re-binding U-010, since its unit changed after the bind (3.9b), and rebuilding its prompt for the fix round:

Dispatching the U-010 fix round by pointer:

The gate caught U-008's just-landed commit, which has no evidence yet. Running U-008's detect-after first:

Still running: U-011, U-012, the U-010 fix round, and the U-008 panel.

Saved (1 Minor). Waiting.

U-008 is complete. The tree is clean: one worktree, main only. Waiting on U-011, U-012 and the U-010 fix.

U-011 has landed. It surfaced another planning gap: `book/page.tsx` must pass the live window hours, but it wasn't in U-011's whitelist, so the wizard shows the default 24 hours whenever the setting is overridden. Running detect-after, then amending U-011 the same way as U-010:

Three returns: the U-010 fix (`d4a8aa8`), U-012 (`b9fca37`), and U-011 (done above). Running the gates on the U-010 fix commit plus U-012's detect-after, and amending U-011:

Refreshing the report frontmatter for U-012 (its implementer wrote the report after my pass) and for U-010 (now two commits). Then amending U-011:

Dispatching the U-010 resolution-verifier, U-012's full panel with design, and U-011's spec lens (against the amended spec):

Seven reviewers are running (U-010 verifier, U-011 spec, U-012 panel). Waiting for their returns.

The verifier confirms all three U-010 Criticals are resolved with evidence. Merging round 2:

U-010 is complete (2 rounds, gate clear). Saved U-012 security (1 Minor). Waiting on the rest.

Saved. Waiting on the U-012 spec and design lenses and the U-011 spec lens.

As expected, U-011's spec lens fails on the amended step 4. Merging round 1, re-binding, and dispatching its fix round (xs: sonnet, fix budget 1):

U-011's fix round is dispatched, and U-012's spec lens passed. Waiting on U-012's design lens and the U-011 fix.

U-012 is complete (gate clear, 6 advisory). While U-011's fix runs, re-certifying the units whose files U-012 legitimately changed afterwards (`appointments.ts`: U-002, U-009):

The U-011 fix has landed (`b0e3f1f`). Running gates on it and dispatching the resolution-verifier:

Meanwhile, re-certifying U-006 (U-011 changed its wizard and page files) and committing the re-certification evidence:

All units except U-011 are now `implemented` with fresh evidence. Waiting for the U-011 verifier.

All 12 units are complete. The postflight files were rewritten by the gate's recompute. Committing that evidence, then running the batch-completion full-suite gate (B2):

Full suite is green (24 files, 163 tests; baseline was 73) with no bypass commits, and `delivery-check.sh` prints **VERDICT: PASS**. Writing the batch `_summary.md`:

Four reports show no confidence, meaning the `bolt_self_report` block is missing. Checking which reports lack it:

U-004, U-006 and U-011 returned their self-report YAML in chat, so I'll append those verbatim. U-005 returned none, so I'll ask that implementer for its own instead of fabricating one.

Waiting for U-005's implementer to return its self-report.

Every bolt-report now carries a self-assessment. Running the artifact gates (whitelist B3, batch-suite B2) before the post-bolts drift gate:

Both pass. ✓ Phase 2 of 2: execute-bolts → status: completed, 12/12 units, blocked: 0. Now the chain's default-on post-bolts drift gate:

The chain is complete on the final HEAD `8960e8e`: plan coverage PASS and `delivery-check.sh` → **VERDICT: PASS**.

# Harbor Clinic v2: 10 of 12 units built, 2 blocked by a question for the business

`plan` → `execute-bolts --all --lite`: all 12 planned units were built, reviewed and committed. But two of the PRD's acceptance criteria, AC-204 and AC-205, have no code. They depend on the PRD's claim that a `rescheduling_required` appointment status already exists, and the code doesn't have one. I deferred that and five other questions only the business can answer (runner rule: conservative choice). The waitlist, doctor leave recording and the cancellation window are done. All 73 v1 tests still pass inside the 163-test suite.

## Acceptance criteria

| Criterion | Status | Covering tests |
|---|---|---|
| AC-201 join the waitlist, same validation as booking | ✅ PASS | `tests/integration/waitlist.test.ts`, `tests/component/waitlist-join.test.tsx` |
| AC-202 offer email to the first patient, accept books online, link works once | ✅ PASS | `waitlist-offers.test.ts`, `cancel-offer.test.ts`, `offer-accept.test.tsx`, `offer-sweep-route.test.ts` |
| AC-203 record leave, slots in the range not bookable | ✅ PASS | `leave.test.ts`, `leave-booking.test.ts`, `leave-form.test.tsx`, `tests/unit/lib.test.ts` |
| AC-204 list of affected appointments, reassign or cancel | ⛔ not built | waits on OQ-DM-1 (`rescheduling_required` doesn't exist in the code) |
| AC-205 no double booking during reassignment | ⛔ not built | waits on OQ-DM-1; the v1 double-booking guard is unchanged |
| AC-206 patient link refused inside the window (24 h default, configurable) | ✅ PASS | `cancellation-window.test.ts` plus the updated copy (U-011) |
| AC-207 all v1 behaviour and tests keep passing | ✅ PASS | full suite green (24 files, 163 tests) |

The delivery check passed all five checks: test script present, tests pass at UTC and UTC+14, build passes on a fresh checkout with an empty environment, and every page is linked.

## Decisions and assumptions
- **Runner choices (headless, conservative):**
  - I ran the chain the engine proposed.
  - I didn't install ast-grep, so symbol claims were recorded as open rather than confirmed.
  - I deferred all six top-priority business questions.
  - I left the 12 drift findings queued instead of applying them.
- **Deferred questions and what they hold back:**
  - **OQ-OV-1:** the PRD says 20-minute slots; the code uses 15. Slot length is unchanged.
  - **OQ-OV-2:** the PRD says reminders go 48 h ahead; the code sends them 24 h ahead. Reminder timing is unchanged.
  - **OQ-DM-1:** `rescheduling_required` doesn't exist. This blocks AC-204 and AC-205.
  - **OQ-FL-1:** VIP priority isn't defined anywhere. Offers go strictly in join order.
  - **OQ-FL-2:** "late cancellations are penalised" has no defined penalty. None was built.
  - **OQ-FL-5:** the v1 staff portal has no staff cancel or reschedule. None was added.
- **Technical choices I made (5):** see `context.md#AI-Technical-Decisions`. In short:
  - Offer expiry runs on the existing 5-minute reminder sweep.
  - The offer link uses its own signed token type.
  - The cancellation window is an environment setting, `CLINIC_CANCELLATION_WINDOW_HOURS` (default 24).
  - The waitlist sits on the reception board; doctor leave has its own `/staff/leave` page.
  - The waitlist entry stores the service chosen in the booking wizard.
- **Two gaps in my own plan, fixed during the run:**
  - U-010 was missing the staff route map (`src/lib/access.ts`), so the leave page couldn't be opened.
  - U-011 was missing `book/page.tsx`, so the wizard always showed 24 h whatever the setting.
  - For both I amended the unit, then a fix round was verified by a separate reviewer.
- **Re-checked units:** U-002, U-006 and U-009 were re-run after later units legitimately edited their files. Their acceptance tests passed again.
- **Incident:** one reviewer deleted a committed test file from the working tree. I restored it from git with nothing lost.

## Worth fixing next (review notes, none blocking)
- **Concurrency:** two cancellations at the same moment can give one patient two pending offers. A partial unique index on pending offers per waitlist entry would close it.
- **Offer history is lost:** accepting an offer deletes the waitlist entry, and the database cascade deletes the offer row with it. The accepted status and appointment id don't survive.
- **Waitlist on leave dates:** patients can join the waitlist for a day the doctor is on leave, and that entry can never be served.
- **Duplication and missing tests:**
  - The offer email copies the appointment email's layout.
  - The waitlist join form copies the booking form's patient fields.
  - The accept action has no direct test.
- **Drift report:** `DRIFT-REPORT.md` / `PENDING-SYNC.md` list 12 vault-vs-code differences (0 critical). Each needs a human to choose whether the code or the vault changes; then run `/mega-sdd:sync`.

⏸ 6 questions deferred (OQ-OV-1, OQ-OV-2, OQ-DM-1, OQ-FL-1, OQ-FL-2, OQ-FL-5). Answer them any time with `resolve-oq`; answering OQ-DM-1 followed by `plan --regenerate` unlocks AC-204 and AC-205.

## Commits
- **Plan:** `a8b8a6d`
- **Feature commits:**
  - `bd37c48` U-001
  - `54203b2` U-002
  - `5581cfe` U-003
  - `1824470` U-004
  - `f4465cd` U-005
  - `30c2f68` U-006
  - `c69d329` U-007
  - `e5dfe5a` U-008
  - `97bea1b` U-009
  - `e4c3599` + fix `d4a8aa8` U-010
  - `1e4b6b7` + fix `b0e3f1f` U-011
  - `b9fca37` U-012
- **Records:** spec amendments, evidence, the batch summary and the drift report are in `chore(sdd)` / `fix(U-0xx): spec amendment` commits, ending at `8960e8e`.

Batch summary: `.mega-sdd/vaults/clinic-v2/bolts/_summary.md`. All background agents have finished and the working tree is clean.

## Questions put to the user

(none)

## Commit messages

chore(sdd): post-bolt drift report (12 HIGH queued for human direction) + index status

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): self-assessment blocks for U-004, U-005, U-006, U-011; summary regenerated

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): batch summary + full-suite evidence (green at f7c9dff)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): gate-recomputed postflight evidence + wave claims

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-011 — bolt report, gates, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): re-certify U-002, U-006, U-009 after sanctioned overlaps (U-009/U-012, U-011)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

fix(U-011): wire cancellationWindowHours into BookingWizard from book/page.tsx

Spec amendment step 4: BookPage now passes windowHours={cancellationWindowHours()}
to BookingWizard so a non-default CLINIC_CANCELLATION_WINDOW_HOURS reaches the
wizard's confirmation copy instead of silently falling back to the 24h default.

Unit: U-011
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-011
SDD-Acceptance: v5

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

chore(sdd): evidence U-012 — bolt report, gates, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-010 — bolt report, gates, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

fix(U-011): spec amendment — add book/page.tsx so the live window hours reach the wizard

Found by the U-011 implementer: BookingWizard's only caller was not whitelisted, so the wizard fell back to the 24h default.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-012): Offer the freed slot on cancellation and add the offer-accept page

After cancelWithToken commits, offer the freed slot to the waitlist; a
waitlist failure is logged and never fails the cancellation. Adds the
read-only /waitlist/offer/[token] page with an accept Server Action.

Unit: U-012
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-012
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

fix(U-010): Add the receptionist "Doctor leave" page to record and list leave

Register /staff/leave in ROUTE_ROLES (receptionist only) so the proxy no
longer redirects receptionists away from the page; add staffAccess cases.

Unit: U-010
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-010
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-011): update patient-facing copy that promises changes any time before the visit

Replace the "any time before your visit / before the appointment"
wording on the home page and in the booking wizard confirmation note
with the actual cancellation window from cancellationWindowHours(),
so patients aren't misled after U-002 closed links inside that window.

Unit: U-011
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-011
SDD-Acceptance: v5

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

chore(sdd): evidence U-008 — bolt report, gates, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-008): Run the offer-expiry sweep from the existing cron endpoint

Unit: U-008
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-008
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): anchor repair (R1-shift) for U-010 by rebind-units.sh

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-006 — bolt report, gates, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-007 — bolt report, gates, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-009 — bolt report, gates, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): anchor repair (R1-shift) for U-011, U-012 by write-unit-binding.sh

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

fix(U-010): spec amendment — step order

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

fix(U-010): spec amendment — add /staff/leave to the proxy route map (access.ts) and its unit test to U-010

Found by the U-010 implementer: staffAccess redirects unlisted /staff/* paths, so the leave page was unreachable for a receptionist with a fresh role cookie.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-007): Show each doctor's waitlist on the reception board and let reception remove entries

Unit: U-007
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-007
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-010): Add the receptionist "Doctor leave" page to record and list leave

Unit: U-010
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-010
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-009): Hide a doctor's slots and refuse patient bookings on leave dates

Unit: U-009
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-009
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-004 — bolt report, gates, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-006): Let patients join the waitlist from the booking wizard when a day has no free slot

Unit: U-006
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-006
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-003 — bolt report, gates, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-005 — bolt report, gates, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): anchor repair (R1-shift) for U-009 by write-unit-binding.sh

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-004): Waitlist offer engine — offer a freed slot, accept by one-time link, expire and pass on

Unit: U-004
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-004
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-001 — bolt report, gates, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): anchor repair (R1-shift) for U-003, U-004 by write-unit-binding.sh

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-005): Doctor-leave server module — record, list, and check leave

Unit: U-005
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-005
SDD-Acceptance: v5

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

chore(sdd): evidence U-002 — bolt report, gates, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-003): Waitlist server module — join, list per doctor and date, remove

Unit: U-003
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-003
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-002): Refuse patient cancel and reschedule links inside the configurable cancellation window

Unit: U-002
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-002
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-001): Add waitlist, waitlist-offer and doctor-leave tables plus their input schemas

Adds the waitlist_offer_status enum and the waitlist_entries, waitlist_offers
and doctor_leave tables (relations + row types), the drizzle-kit generated
migration 0001_v2_waitlist_leave, and the waitlistJoinSchema / leaveSchema
Zod input schemas. v1 appointments and its status enum are unchanged.

Unit: U-001
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-001
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

plan(clinic-v2): vault context, constitution and 12 units for PRD v2.1

Waitlist, doctor leave (AC-203 only) and cancellation window. Six P1
business OQs deferred (slot length, reminder lead, rescheduling_required,
VIP, late-cancel penalty, staff cancel UI); their scope has no unit.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

## Recorded notes in committed markdown

### .mega-sdd/vaults/clinic-v2/DRIFT-REPORT.md

## Decision violations & decision unwritten (PRIORITY-1)



> No decision violations were found: every AI Technical Decision and every OQ interim rule checked is honoured by the code (see Confirmed matches). The four items below are behaviours the code embodies that no vault claim captures.



## Notes & caveats



- Detection is heuristic (grep + read, no AST — ast-grep is not installed); low-confidence findings can be false positives.

- The decision axis had no ADRs; it was checked against AI Technical Decisions and OQ interim rules only.

- Vault housekeeping (not a code drift): `units/_index.md` still shows every unit `pending` and "0/12 complete", while `bolts/_summary.md` and `vault.json changelog` record 12/12 done.

- Vault Changelog: on this layout-3 vault the changelog lives only in `vault.json` (written by `derive-vault-json.sh --event`). detect-drift's diagnostic lane never writes `vault.json`, so this drift session is recorded in this report and `PENDING-SYNC.md` only; vault version stays `1.0`.

- Re-run with an explicit `--scope=<dirs>` if the framework was mis-detected.

### .mega-sdd/vaults/clinic-v2/PENDING-SYNC.md

# Pending sync decisions

**Last sync run**: 2026-09-28T00:50:46Z (detect-drift, post-execute-bolts hybrid gate, full scan @ `594137e`) · **Open items**: 12



## 1. CONFLICTs (BLOCKING — gate closed for affected units)

_None queued by this run._



### .mega-sdd/vaults/clinic-v2/bolts/U-001/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: every v1 table, enum, index and relation in `src/db/schema.ts`; `patientDetailsSchema`, `bookingSchema`, `staffBookingSchema`, `loginSchema` in `src/lib/validation.ts` byte-for-byte.

- **ADD**: `waitlistOfferStatus` enum, `waitlistEntries`, `waitlistOffers`, `doctorLeave` tables with relations and types; `waitlistJoinSchema`, `leaveSchema`; migration `0001_v2_waitlist_leave`.



### .mega-sdd/vaults/clinic-v2/bolts/U-002/bolt-report.md

## Notes

- Truncated dispatch sections (design slice, pack rules) were not relied on.

- Boundary: exactly at the window edge (startTime - now == window) online changes are still allowed ("less than the window" per spec step 2).



```yaml

bolt_self_report:

  model_used: "Opus 5.5"

  confidence: 0.9

  certain_decisions:

    - "Window check lives only in loadTokenAppointment, so view/cancel/reschedule are all covered and staff paths are untouched"

    - "Empty/whitespace, non-numeric, negative and non-finite env values fall back to 24"

  uncertain_decisions:

    - decision: "Cancel page shows title 'Online changes are closed' and drops the generic reception suffix for TOO_LATE"

      rationale: "The domain message already asks the patient to call the clinic; the 'Link not valid' title would be misleading"

      fallback_if_wrong: "Keep the original title/suffix and only render err.message"

  retry_history: []

```



### .mega-sdd/vaults/clinic-v2/bolts/U-002/dispatch-prompt.md

## Migration notes



- **REMOVE**: the v1 "has already started" rule in `loadTokenAppointment` (it is replaced by the stricter window rule, which also covers started appointments).

- **KEEP**: token verification, nonce and `booked`-status checks in `loadTokenAppointment`; all other exports of `clinic-config.ts`; the rest of the cancel page.

- **ADD**: `DEFAULT_CANCELLATION_WINDOW_HOURS`, `cancellationWindowHours()`; the window check; window copy on the cancel page.



### .mega-sdd/vaults/clinic-v2/bolts/U-006/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: the five wizard steps, `bookAction`, `fetchSlotsAction`, the rate limiter, and all existing wizard props and copy.

- **ADD**: `joinWaitlistAction`; optional `joinWaitlist` prop; `WaitlistJoinForm`.



### .mega-sdd/vaults/clinic-v2/bolts/U-007/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: the schedule grid, appointments board, walk-in form and date navigation on the reception page; `reassignAction`, `createWalkInAction`, `run()`.

- **ADD**: `removeWaitlistEntryAction`; `WaitlistPanel`; the "Waitlist" section.



### .mega-sdd/vaults/clinic-v2/bolts/U-008/bolt-report.md

## Notes

- L0 tsc finding at detect time came from U-012's uncommitted in-progress files in the shared tree (offer-accept-form import), not from this commit.



```yaml

bolt_self_report:

  model_used: "Opus 5.5"

  confidence: 0.92

  certain_decisions:

    - "Offer sweep runs after sweepReminders on the same ctx; response body unchanged"

    - "Offer-sweep errors are caught and logged, never propagated"

  uncertain_decisions:

    - decision: "Log offer counts only when non-zero, via console.info"

      rationale: "Avoid log noise every 5 minutes; matches the existing console-based logging"

      fallback_if_wrong: "Log on every tick unconditionally"

  retry_history: []

```



### .mega-sdd/vaults/clinic-v2/bolts/U-008/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: the bearer-token check, `sweepReminders` call and the exact `{ due, sent, failed }` response body.

- **ADD**: a guarded `sweepExpiredOffers(ctx)` call after the reminder sweep.



### .mega-sdd/vaults/clinic-v2/bolts/U-009/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: all v1 slot, past-time, regular-slot and double-booking checks; U-002's cancellation-window check in `loadTokenAppointment`; the staff channel.

- **ADD**: the leave check in `getAvailableSlots`, the online branch of `createAppointment`, and `rescheduleWithToken`.



### .mega-sdd/vaults/clinic-v2/bolts/U-011/dispatch-prompt.md

## Migration notes



- **REMOVE**: the "any time before your visit" / "any time before the appointment" wording.

- **KEEP**: every other string, layout and prop of both files.

- **ADD**: the window-hours sentence from `cancellationWindowHours()` (passed to the wizard as a prop).



### .mega-sdd/vaults/clinic-v2/bolts/U-012/bolt-report.md

## Notes / concerns

- `appointments.ts` now imports `waitlist-offers.ts`, which already imports `appointments.ts`, so the two modules import each other. That is safe here because neither module uses the other's bindings at load time, and the full suite, tsc, and the vi.mock partial mock all work with it.

- The page types its props as `{ params: Promise<{ token: string }> }` instead of `PageProps<"/waitlist/offer/[token]">`, because the generated `.next/types/routes.d.ts` does not list the new route until the next typegen/build.

- Truncated T2 sections (pack rules, code style, design slice) were not relied on for correctness.



```yaml

claims: []

bolt_self_report:

  model_used: "Opus 5.5"

  confidence: 0.88

  certain_decisions:

    - "Offer call placed after the successful UPDATE; errors logged and swallowed; return shape unchanged"

    - "Page GET only calls getOfferByToken (no mutation); accept happens in the Server Action"

  uncertain_decisions:

    - decision: "Static import of offerFreedSlot into appointments.ts (circular module import)"

      rationale: "No top-level use of cross bindings; simplest wiring; verified by full suite + tsc"

      fallback_if_wrong: "Use `const { offerFreedSlot } = await import('./waitlist-offers')` inside cancelWithToken"

    - decision: "SLOT_TAKEN / INVALID_TOKEN hide the accept button and link to /book"

      rationale: "Both are final for this offer; a retry cannot succeed"

      fallback_if_wrong: "Keep the button visible for all errors"

  retry_history: []

reuse_decisions:

  - {candidate: "offerFreedSlot / getOfferByToken / acceptOffer (src/server/waitlist-offers.ts)", decision: reused}

  - {candidate: "Alert, Button (src/components/ui)", decision: reused}

  - {candidate: "formatDateTime, serviceLabel, clinicTimeZone", decision: reused}

  - {candidate: "BookingResult type (components/booking/types.ts)", decision: not_applicable, reason: "shape differs (doctorName, no id/emailSent) and types.ts is outside target_files; OfferAcceptResult exported from the form"}

  - {candidate: "reuse-index.yaml", decision: not_applicable, reason: "absent per dispatch PROVENANCE"}

```



### .mega-sdd/vaults/clinic-v2/bolts/U-012/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: token, nonce, status and window checks in the cancel path; its return shape; U-009's leave checks.

- **ADD**: the post-cancel `offerFreedSlot` call; the offer page, action and form.



### .mega-sdd/vaults/clinic-v2/bolts/_summary.md

## Self-assessment summary (uncertain decisions across batch)

- U-001: "ON DELETE restrict for doctor/service FKs, set null for appointment_id" — fallback: switch to no action / cascade and regenerate a migration

- U-001: "status as pgEnum waitlist_offer_status, no default" — fallback: add .default('pending') in a follow-up migration

- U-002: "Cancel page shows title 'Online changes are closed' and drops the generic reception suffix for TOO_LATE" — fallback: Keep the original title/suffix and only render err.message

- U-003: "listWaitlist returns only doctors with entries, grouped as {doctorId, doctorName, entries[]}, ordered by doctor name" — fallback: include every doctor with an empty entries array

- U-003: "createdAt set from ctx.now() rather than DB defaultNow()" — fallback: drop the explicit createdAt and rely on defaultNow()

- U-003: "Messages for past date ('Choose today or a later date.') and non-working day ('<doctor> does not see patients on that day.')" — fallback: adjust strings; tests assert only the code

- U-004: "Stored appointment_id, then deleted the entry, which also deletes the offer row" — fallback: Change the offer's entry link to set null in a later schema unit, or keep the entry

- U-004: "Void the offer on any booking failure, not only a taken slot" — fallback: Void only on SLOT_TAKEN and put other failures back to pending

- U-004: "The sweep checks the slot is free and in the future using getAvailableSlots" — fallback: Query for overlapping bookings directly plus a start > now check

- U-005: "listLeave returns { id, doctorId, doctorName, startDate, endDate, note } (unit did not fix the list shape)" — fallback: Adjust LeaveRecord fields without changing recordLeave/isDoctorOnLeave signatures

- U-005: "Treated reuse-index.yaml as not applicable (absent)" — fallback: Re-scan if an index appears

- U-006: "Moved bookAction's IP and rate-limit logic into a shared private helper" — fallback: Restore bookAction's original body and repeat the logic inline in joinWaitlistAction

- U-006: "Join attempts count against the same per-IP key as booking" — fallback: Use the key waitlist:${ip} on the same limiter

- U-007: "removeWaitlistEntryAction takes (entryId, name)" — fallback: have removeWaitlistEntry return the entry name (U-003 follow-up) and drop the name arg

- U-007: "Joined time rendered with formatDateTime (full date + time)" — fallback: switch to a compact date/time format

- U-008: "Log offer counts only when non-zero, via console.info" — fallback: Log on every tick unconditionally

- U-009: "Online leave check sits inside the !opts.override block, as the anchor says" — fallback: Move the online check outside the override guard

- U-010: "Left src/lib/access.ts unchanged (outside target_files), so the proxy still redirects /staff/leave for cached-role sessions" — fallback: Add { prefix: '/staff/leave', roles: ['receptionist'] } to ROUTE_ROLES in a follow-up

- U-010: "Labels 'First day of leave' / 'Last day of leave' instead of 'Start date' / 'End date'" — fallback: Rename the labels and update the test

- U-011: "Made windowHours an optional prop on BookingWizard defaulting to DEFAULT_CANCELLATION_WINDOW_HOURS (24)" — fallback: Make the prop required once every caller passes it

- U-012: "Static import of offerFreedSlot into appointments.ts (circular module import)" — fallback: Use `const { offerFreedSlot } = await import('./waitlist-offers')` inside cancelWithToken

- U-012: "SLOT_TAKEN / INVALID_TOKEN hide the accept button and link to /book" — fallback: Keep the button visible for all errors



## Deferred open questions (6)

- OQ-OV-1 [P1] — deferred (plan, headless run)

- OQ-OV-2 [P1] — deferred (plan, headless run)

- OQ-DM-1 [P1] — deferred (plan, headless run)

- OQ-FL-1 [P1] — deferred (plan, headless run)

- OQ-FL-2 [P1] — deferred (plan, headless run)

- OQ-FL-5 [P1] — deferred (plan, headless run)



Open business OQs not asked (P2/P3, 4): OQ-FL-3, OQ-FL-4, OQ-FL-6, OQ-FL-7 — answer any time: `resolve-oq`.



### .mega-sdd/vaults/clinic-v2/context.md

## Open Questions



- [ ] **OQ-OV-1** [P1] [business] [conf: high] [covers: PRD/prd-clinic-v2.md#1-context]: PRD §1 says v1 books "20-minute slots", but the code books 15-minute slots (`SLOT_MINUTES = 15`, `src/lib/clinic-config.ts:6`; v1 PRD F-U-001 step 4 "15-min"; `/book` copy "Appointments are 15 minutes"). Which is authoritative — keep 15 minutes, or change v1 to 20 minutes? Until answered no unit changes slot length. **Deferred (plan)**: no stakeholder reachable in this headless run (runner chose Defer); the interim rule above stands, and the question resurfaces via `resolve-oq`.

- [ ] **OQ-OV-2** [P1] [business] [conf: high] [origin: context.md#Overview]: PRD §1 says patients get their reminder "48 hours" before the appointment, but the code sends it 24 hours before (`REMINDER_LEAD_MS = 24h`, `src/lib/clinic-config.ts:13`; v1 AC-004 "24h ± 5 min"; reminder copy "in 24 hours"). Which is authoritative? Until answered no unit changes reminder timing. **Deferred (plan)**: no stakeholder reachable in this headless run (runner chose Defer); the interim rule above stands, and the question resurfaces via `resolve-oq`.

- [ ] **OQ-DM-1** [P1] [business] [conf: high] [origin: context.md#F-U-005]: PRD §1 and §4.2 call `rescheduling_required` "the existing status used for appointments that must move", but the code has only `booked | cancelled | completed` (`src/db/schema.ts:94`, `src/lib/clinic-config.ts:20`) and v1 has no such flow. Should v2 add `rescheduling_required` as a new appointment status (with what effect on slots, reminders and the doctor's schedule), or map "must move" to something else? Until answered: recorded leave hides slots (AC-203) but leaves existing bookings untouched; the affected-appointments list, bulk reassign and leave-cancel (PRD §4.2 bullets 3–5, AC-204, AC-205) have no unit. **Deferred (plan)**: no stakeholder reachable in this headless run (runner chose Defer); the interim rule above stands, and the question resurfaces via `resolve-oq`.

- [ ] **OQ-FL-1** [P1] [business] [conf: high] [origin: context.md#F-S-001]: PRD §4.1 says "VIP patients skip the waitlist queue and are offered freed slots first", but the rule table says the offer goes to the "first patient in the queue", patients have no account (PRD §3), and nothing in v1 or v2 marks a patient as VIP. Who is a VIP, who marks them, and how do they rank? Until answered offers go strictly in join order. **Deferred (plan)**: no stakeholder reachable in this headless run (runner chose Defer); the interim rule above stands, and the question resurfaces via `resolve-oq`.

- [ ] **OQ-FL-2** [P1] [business] [conf: high] [origin: context.md#F-U-006]: PRD §4.3 says "Late cancellations are penalised" with no penalty defined, and payments are out of scope (PRD §6). What is the penalty, and how is it applied without payments? Until answered a refused late change has no other consequence. **Deferred (plan)**: no stakeholder reachable in this headless run (runner chose Defer); the interim rule above stands, and the question resurfaces via `resolve-oq`.

- [ ] **OQ-FL-5** [P1] [business] [conf: high] [origin: context.md#F-U-006]: PRD §4.3 says "Staff can still cancel or reschedule at any time from the portal", but the v1 portal has no staff cancel or staff reschedule action (only reassign and walk-in: `src/app/staff/(app)/reception/actions.ts:24`, `:44`). Should v2 build staff cancel/reschedule in the portal? Until answered no staff cancel/reschedule UI is added; the window only applies to the patient email links, so staff actions stay unrestricted (AC-206). **Deferred (plan)**: no stakeholder reachable in this headless run (runner chose Defer); the interim rule above stands, and the question resurfaces via `resolve-oq`.

- [ ] **OQ-FL-3** [P2] [business] [conf: high] [origin: context.md#F-U-002]: Is a freed slot held for the offered patient while the 30-minute offer is open, or can anyone book it online meanwhile? The PRD is silent; v1 frees a cancelled slot immediately (v1 F-U-002 step 3). Until answered the slot stays publicly bookable; an acceptance on a slot already taken gets the existing "slot was just taken" message and the patient stays on the waitlist.

- [ ] **OQ-FL-4** [P2] [business] [conf: high] [origin: context.md#F-S-002]: When an offer expires and "passes to the next patient", does the first patient keep their place for later freed slots? And when two slots free up, may one patient hold two pending offers? Until answered the patient stays on the waitlist in place; a patient with a pending offer is skipped for another slot's offer; each slot's chain walks the queue once in join order.

- [ ] **OQ-FL-6** [P3] [business] [conf: medium] [origin: context.md#F-U-001]: May the same email join the same doctor + date waitlist more than once? PRD is silent. Until answered duplicate joins are accepted.

- [ ] **OQ-FL-7** [P3] [business] [conf: medium] [origin: context.md#F-U-004]: May staff still book a walk-in for a doctor on leave? PRD §4.2 only says "patients cannot book". Until answered the leave check applies to patient paths only (online booking, reschedule via link, offer acceptance); staff walk-ins are unchanged.

- [x] **OQ-AR-1** [P2] [tech / recommend] [conf: high] [origin: context.md#F-S-002]: How do expired offers pass to the next patient? → **Resolved v1.0** (AI decision, 2026-09-28): extend the existing cron sweep endpoint `/api/cron/reminders` (every 5 minutes via `vercel.json` / `scripts/reminder-worker.ts`) to also expire offers and send the next offer; the accept path checks `expires_at` itself, so an expired link is refused at the exact 30-minute mark.

- [x] **OQ-AR-2** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-002]: How is the one-time offer link built? → **Resolved v1.0** (AI decision, 2026-09-28): an HMAC-signed token in `src/lib/tokens.ts` with its own payload kind (never interchangeable with appointment tokens), checked against `waitlist_offers.token_nonce`, which is rotated when the offer is used.

- [x] **OQ-AR-3** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-006]: Where does the cancellation-window setting live? → **Resolved v1.0** (AI decision, 2026-09-28): `cancellationWindowHours()` in `src/lib/clinic-config.ts`, read from env `CLINIC_CANCELLATION_WINDOW_HOURS` with default 24 — the same pattern as `clinicTimeZone()`; no settings UI.

- [x] **OQ-AR-4** [P3] [tech / recommend] [conf: high] [origin: context.md#F-U-003]: Where do the new staff screens live? → **Resolved v1.0** (AI decision, 2026-09-28): the waitlist is a section of the existing per-date reception board (`/staff/reception`); doctor leave is a new receptionist page `/staff/leave` linked from the staff sidebar.

- [x] **OQ-DM-2** [P2] [tech / recommend] [conf: medium] [origin: context.md#Data-model]: Which service does the booking made from an accepted offer carry? → **Resolved v1.0** (AI decision, 2026-09-28): the service the patient picked in the booking wizard before choosing the date, stored as `waitlist_entries.service_id`; all seeded services last 15 minutes, so every service fits a freed slot.



## AI Technical Decisions



> 5 technical decisions taken by the AI — override any time: `resolve-oq single-oq <OQ-ID>`.



| OQ-ID | Decision | Basis (citation) | If wrong |

|---|---|---|---|

| OQ-AR-1 [P2] | Reuse the 5-minute cron sweep for offer expiry; accept path checks `expires_at` | codebase — `src/app/api/cron/reminders/route.ts:18`, `vercel.json`, `scripts/reminder-worker.ts:21` | Add a dedicated `/api/cron/waitlist` route on its own schedule |

| OQ-AR-2 [P2] | HMAC offer token with its own kind + nonce on `waitlist_offers` | codebase — `src/lib/tokens.ts:4` | Store a random opaque token hash on the offer row instead |

| OQ-AR-3 [P2] | `CLINIC_CANCELLATION_WINDOW_HOURS` env, default 24, via `clinic-config.ts` | codebase — `src/lib/clinic-config.ts:28` | Move the value to a DB-backed settings table with a staff UI |

| OQ-DM-2 [P2] | Store the wizard-chosen service on the waitlist entry | codebase — `src/db/schema.ts:127`, `src/db/seed.ts:7` | Use the cancelled appointment's service for the offered booking |

| OQ-AR-4 [P3] | Waitlist on the reception board; leave on `/staff/leave` | codebase — `src/app/staff/(app)/reception/page.tsx:15`, `src/app/staff/(app)/layout.tsx:14` | Move both to dedicated pages under `/staff` |



### .mega-sdd/vaults/clinic-v2/units/U-001.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: every v1 table, enum, index and relation in `src/db/schema.ts`; `patientDetailsSchema`, `bookingSchema`, `staffBookingSchema`, `loginSchema` in `src/lib/validation.ts` byte-for-byte.

- **ADD**: `waitlistOfferStatus` enum, `waitlistEntries`, `waitlistOffers`, `doctorLeave` tables with relations and types; `waitlistJoinSchema`, `leaveSchema`; migration `0001_v2_waitlist_leave`.



### .mega-sdd/vaults/clinic-v2/units/U-002.md

## Migration notes



- **REMOVE**: the v1 "has already started" rule in `loadTokenAppointment` (it is replaced by the stricter window rule, which also covers started appointments).

- **KEEP**: token verification, nonce and `booked`-status checks in `loadTokenAppointment`; all other exports of `clinic-config.ts`; the rest of the cancel page.

- **ADD**: `DEFAULT_CANCELLATION_WINDOW_HOURS`, `cancellationWindowHours()`; the window check; window copy on the cancel page.



### .mega-sdd/vaults/clinic-v2/units/U-006.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: the five wizard steps, `bookAction`, `fetchSlotsAction`, the rate limiter, and all existing wizard props and copy.

- **ADD**: `joinWaitlistAction`; optional `joinWaitlist` prop; `WaitlistJoinForm`.



### .mega-sdd/vaults/clinic-v2/units/U-007.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: the schedule grid, appointments board, walk-in form and date navigation on the reception page; `reassignAction`, `createWalkInAction`, `run()`.

- **ADD**: `removeWaitlistEntryAction`; `WaitlistPanel`; the "Waitlist" section.



### .mega-sdd/vaults/clinic-v2/units/U-008.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: the bearer-token check, `sweepReminders` call and the exact `{ due, sent, failed }` response body.

- **ADD**: a guarded `sweepExpiredOffers(ctx)` call after the reminder sweep.



### .mega-sdd/vaults/clinic-v2/units/U-009.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: all v1 slot, past-time, regular-slot and double-booking checks; U-002's cancellation-window check in `loadTokenAppointment`; the staff channel.

- **ADD**: the leave check in `getAvailableSlots`, the online branch of `createAppointment`, and `rescheduleWithToken`.



### .mega-sdd/vaults/clinic-v2/units/U-011.md

## Migration notes



- **REMOVE**: the "any time before your visit" / "any time before the appointment" wording.

- **KEEP**: every other string, layout and prop of both files.

- **ADD**: the window-hours sentence from `cancellationWindowHours()` (passed to the wizard as a prop).



### .mega-sdd/vaults/clinic-v2/units/U-012.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: token, nonce, status and window checks in the cancel path; its return shape; U-009's leave checks.

- **ADD**: the post-cancel `offerFreedSlot` call; the offer page, action and form.



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

.mega-sdd/vaults/clinic-v2/bolts/U-012/binding.json: "CONFLICT": 0,