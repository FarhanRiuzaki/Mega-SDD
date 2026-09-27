## Chat (main thread)

No scopes block, no vault → new PRD defaults to lite. Writing config and running GROUND.

▶ Phase 1 of 2: invoking plan (PRD/prd-clinic-v2.md --lite --mode=existing --auto)

I'm using the plan skill to turn the PRD into context.md + units (lite lane). `mega-sdd-trace:plan`

I've finished reading the v1 code and found several places where the PRD and the repo disagree. Next I'm reading the vault and unit templates so I can write context.md and the units.

Still reading the plan-phase references (flow-step decomposition rules, the `_index.md` shape, the Next.js pack's test patterns) before I write the vault.

Baseline is green (73/73 vitest). Next I'm writing the lite vault: context.md, constitution.md, and vault.json.

Now the vault.json patch and derive.

Vault PASS (3 entities, 8 flows, 19 OQs; constitution PASS). Now the units, starting with U-001 so I can check the grammar.

Grammar passes. Writing the next batch (U-002–U-007: emails, nav/access, waitlist service, leave service, leave-blocks-booking, cancellation window).

Now `_index.md`, then the validators.

Now the adversarial test review for the two `risk: high` units (U-008, U-010): two read-only reviewers running in parallel.

Both reviewers returned `coverage_verdict: weak` with concrete gaps. I'm merging those gaps into U-008 and U-010 as additional required assertions.

Preflight is clean: 6 ok, 0 fatal. Next I'm branching off main and committing the plan artifacts before dispatching bolts.

▶ Phase 2 of 2: invoking execute-bolts (--all --lite --auto)

I'm using the execute-bolts skill to implement units via the mega-sdd bolt agents (parallel review panel). `mega-sdd-trace:execute-bolts`

Wave 1 bound (0 CONFLICT; the symbol claims are OQ because there's no index). Resolving review tiers and building dispatch prompts.

Dispatching wave 1 (4 implementers in parallel; U-011 is xs, so it's routed to sonnet per the lite W2 cell).

While wave 1 runs, I'm reading the handoff/report contract.

Wave 1's four implementers are running. I'm arming a commit watcher so I can process each bolt as it lands.

The U-003 panel is running. I'm saving its self-report, then waiting for the next wave-1 commit.

U-003 panel merged clean. U-001 still shows as in-progress, so its dependents aren't ready yet. Checking how readiness is derived.

Readiness needs the controller-written `bolt-report.md` with `target_hashes`. I'm writing a report generator (panel section filled in once its merge is done).

U-004, U-005 and U-007 are ready. Binding them and building their prompts.

While those run, I'm committing U-003's evidence (its panel merged clean).

Merging the U-002 panel, then running detect-after on U-004.

Wave 1 is fully reviewed and evidence is committed. U-008, U-010 and U-013 are ready (U-014 is next in the queue). Preparing them.

The dispatch gate blocked the three new implementers until U-007's commit has evidence. U-007 has now returned, so I'm running its detect-after pipeline and report, then re-dispatching.

Three implementers are running (U-008, U-010, U-013) plus the U-007 panel. Checking for the remaining open slot.

U-004 is merged clean with 6 advisories. U-014 and U-016 are ready but waiting for a free slot. Waiting on the next commit.

Dispatching U-014, the U-013 panel (4 lenses + design), and the U-011 design lens I missed earlier (U-011 is UI-bearing).

U-010's acceptance run came back red. Checking why.

Progress: 8/16 units reviewed with evidence committed. U-006, U-008, U-010 and U-014 have landed and need panels. The last four (U-009, U-012, U-015, U-016) are ready. Preparing them.

U-015 has a binding CONFLICT on the anchor `reschedule/[token]/actions.ts:26-34`. Checking the evidence before deciding anything.

The anchor range is my authoring error: the file has 30 lines and `rescheduleAction` sits within them. That makes this a `binding_conflict`, a human-wait halt.

Binding gate passes. Dispatching the last four implementers plus panels for U-006, U-008, U-010 and U-014.

The U-010 standards lens hasn't returned yet. Meanwhile I'm running detect-after on U-015 and dispatching the U-015 and U-016 panels.

Dispatching panels for U-009 (full), U-015 and U-016 (standard + design).

All 16 implementers have returned. Recording lens results, then running detect-after and the panel for U-012.

All 16 code commits have landed. While the remaining lenses (U-012 ×5, U-015 ×2, U-016 ×1) run, I'm running the B2 full-suite gate.

Full suite is green at HEAD. Merging U-016 now; U-015 waits on its design lens, U-012 on spec/standards/design.

While the last three lenses finish, I'm running the deterministic delivery check (a fresh checkout, tests under UTC and UTC+14, and a build with an empty env).

Delivery check passed (D1–D5). Merging U-015, then waiting for the last U-012 design lens.

Execute-bolts is complete: 16/16 units, 0 halts, full suite green, delivery check PASS. Next is the chain's default-on `detect-drift` gate.

Harbor Clinic v2 is built: all 16 units are implemented and reviewed on branch `feat/clinic-v2` (36 commits, nothing pushed, working tree clean). The full test suite passes (193 tests) and the delivery check passed on a fresh checkout. That check ran the tests in UTC and UTC+14, built with an empty env, and confirmed every page is linked. There are no open halts.

**What was delivered**
- **Waitlist:** patients can join from the booking page when a day has no free slot. When someone cancels, the first waiting patient gets an email with a one-time link that expires after 30 minutes. Accepting books the slot. Unaccepted offers pass to the next patient on the existing 5-minute cron. Receptionists get a new `/staff/waitlist` page to view and remove entries.
- **Doctor leave:** receptionists record leave on a new `/staff/leave` page. Those days stop showing slots, and that doctor's appointments on those days move to `rescheduling_required`. Each one can then be reassigned (same time, patient emailed) or cancelled (patient emailed a link to book again), one at a time or in bulk. A reassignment can't double-book a doctor, including against a simultaneous online booking.
- **Cancellation window:** patient email links refuse cancel and reschedule within 24 hours of the appointment and show a "please call the clinic" notice. The length is set with `CANCELLATION_WINDOW_HOURS`. Staff actions aren't affected.

**Where the PRD and the existing code disagreed**
- The PRD describes v1 with 20-minute slots and 48-hour reminders, but the code uses 15 minutes and 24 hours. I kept the code, since v2 doesn't ask to change them.
- The PRD calls `rescheduling_required` and "the cancellation email" existing features; neither existed, so I added both.
- "VIP patients skip the queue" can't be built because nothing identifies a VIP, so the queue is strictly first-come.
- "Late cancellations are penalised" has no defined penalty, so nothing was built for it.

These are recorded as open questions for the Product Team: 4 P1 deferred and 8 lower-priority open. Answer them with `resolve-oq`.

**Worth fixing before merge.** These were flagged in review as non-blocking, and the drift check raised the first two again:
- If accepting an offer fails for a reason other than a normal booking error (say the database is down), the waitlist entry is left "accepted" with no appointment and is never offered again (`src/server/waitlist-offers.ts`).
- Removing a waitlist entry that holds an open offer doesn't pass the slot to the next patient.
- On the leave page, cancelling a single affected appointment has no confirmation, and bulk cancel uses the browser's native confirm dialog.
- The waitlist and offer pages don't use the project's typed `PageProps` convention for route params.

The drift check found no code missing or contradicting the vault. It queued 11 items in `.mega-sdd/vaults/clinic-v2/PENDING-SYNC.md`; these are mostly edge-case decisions the vault doesn't document, plus stale line citations.

**Process notes**
- One unit (U-015) was stopped by a binding conflict. The cause was a wrong line range I wrote into its reference to existing code; the file itself was correct.
- I missed the design review for U-011 on the first pass and ran it afterwards; its findings are in the ledger.

Decisions I made because no one was available to ask:

[ASSUMED-BY-RUNNER: front-door confirmation for the plan → execute-bolts chain -> Run: it was the proposed chain and every gate still applied]
[ASSUMED-BY-RUNNER: install ast-grep (missing dependency) -> skip: installing would change the environment; the chain ran without a symbol index]
[ASSUMED-BY-RUNNER: plan's question batch — OQ-OV-1 (VIP), OQ-CN-1 (late-cancel penalty), OQ-CN-2 (20 vs 15-min slots), OQ-CN-3 (48 vs 24-h reminder) -> Defer: easiest to revert, no unit depends on them, and v1 behaviour stays unchanged]
[ASSUMED-BY-RUNNER: U-015 binding conflict on a wrong line range in my reference to existing code -> keep the code: v1 code is unchanged and the range was my typo; recorded as `by=runner` so a human can revisit it]
[ASSUMED-BY-RUNNER: detect-drift automatic vault updates (`--auto-apply=safe`) -> not applied: the vault is unchanged and the items stay queued for a human]

⏸ 4 OQ deferred — OQ-OV-1, OQ-CN-1, OQ-CN-2, OQ-CN-3. Jawab kapan saja: resolve-oq

```yaml
handoff:
  emitted_by: execute-bolts
  emitted_at: 2026-09-27T02:48:00Z
  status: completed
  notes:
    postflight_skipped: false
    full_suite_skipped: false
  artifacts:
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-001/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-002/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-003/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-004/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-005/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-006/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-007/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-008/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-009/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-010/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-011/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-012/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-013/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-014/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-015/
    - /private/tmp/claude-501/mega-sdd-bench/work/brownfield-routed-1/.mega-sdd/vaults/clinic-v2/bolts/U-016/
  next_action:
    suggested_skill: mega-sdd:detect-drift
    suggested_args: []
    rationale: "All bolts executed; recommend a periodic drift check."
    hint: "Phase 1 of 1 complete — all phases finished."
  blockers: []
  metrics:
    items_processed: 16
    items_blocked: 0
    bolts_used_starterkit_slice: 0
    slice_avg_size_kb: 0
    acceptance_test_concerns:
      - {unit: U-003, concern: "Sidebar change covered by typecheck only"}
      - {unit: U-005, concern: "Transaction rollback on partial failure not exercised"}
      - {unit: U-008, concern: "Non-domain errors during accept can leave an entry stuck in accepted (review advisory)"}
      - {unit: U-009, concern: "JSON-client cancel path not asserted to trigger an offer"}
      - {unit: U-012, concern: "Leave page wiring covered by typecheck only"}
      - {unit: U-014, concern: "Server action and Enter-key interception not exercised end-to-end"}
      - {unit: U-015, concern: "Page server-side read and action error mapping not integration-tested"}
```

Files are in `.mega-sdd/vaults/clinic-v2/`:
- context.md
- constitution.md
- units/_index.md
- bolts/_summary.md
- DRIFT-REPORT.md
- PENDING-SYNC.md

## Questions put to the user

(none)

## Commit messages

chore(sdd): detect-drift report + PENDING-SYNC queue (clinic-v2)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): batch evidence — _summary.md, _batch-suite.json, refreshed postflight

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-012 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-015 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-016 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-009 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-014 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-008 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-012): Staff doctor-leave page — record leave and resolve affected appointments

Unit: U-012
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-012
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-010 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-009): Trigger offers on patient cancellation and run the offer-expiry sweep from cron

Unit: U-009
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-009
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-015): Waitlist offer page — review and accept the freed slot

Unit: U-015
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-015
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-006 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-016): Show the call-the-clinic message on the cancel and reschedule pages inside the window

Unit: U-016
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-016
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-011 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-013 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-014): Booking page — join the waitlist when the chosen date has no free slot

Unit: U-014
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-014
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-006): Leave dates are not bookable — hide slots and refuse online booking/reschedule

getAvailableSlots now hides all slots on a doctor's leave days, and the
non-override create/reschedule paths refuse a target on a leave day with
INVALID_SLOT, while staff override walk-ins keep bypassing slot rules.

Unit: U-006
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-006
SDD-Acceptance: v5

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

feat(U-008): Waitlist offer engine — offer freed slot, accept via one-time link, expiry sweep

Unit: U-008
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-008
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-010): Leave resolution service — reassign or cancel affected appointments, individually or in bulk

Unit: U-010
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-010
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-007 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-013): Staff waitlist page — each doctor's waitlist per date with remove

Unit: U-013
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-013
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-004 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-005 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-001 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-007): Cancellation window — refuse patient link cancel/reschedule inside the window

Unit: U-007
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-007
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-011 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-002 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-004): Waitlist service — join, list per doctor/date, remove

Unit: U-004
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-004
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-005): Doctor leave service — record leave, mark affected appointments, on-leave check

Unit: U-005
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-005
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(sdd): evidence U-003 — bolt report, gate evidence, panel ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-011): Affected-appointments list component with per-row and bulk reassign/cancel

Unit: U-011
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-011
SDD-Acceptance: v5

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

feat(U-001): Add rescheduling_required status and the waitlist_entries / doctor_leaves tables

Unit: U-001
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-001
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-002): Add the cancellation and waitlist-offer email kinds

Unit: U-002
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-002
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-003): Route access and staff navigation for /staff/waitlist and /staff/leave

Add receptionist-only proxy rules for /staff/waitlist and /staff/leave and
link both from the receptionist sidebar.

Unit: U-003
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-003
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

plan: clinic-v2 lite vault (context.md, constitution, 16 units)

PRD/prd-clinic-v2.md -> .mega-sdd/vaults/clinic-v2: 8 flows, 3 entities,
19 OQs (7 tech decided by AI, 4 P1 business deferred by headless runner),
16 units; plan-coverage 9/9 PASS.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

## Recorded notes in committed markdown

### .mega-sdd/vaults/clinic-v2/DRIFT-REPORT.md

## Decision violations & decision unwritten (PRIORITY-1)



> These most often correspond to compliance or architectural debt. Review them first.



No **decision violations** were found. Each AI technical decision (OQ-AR-1..5, OQ-DM-2, OQ-DM-3) and each constitution clause has conforming code (see Confirmed matches).



## Notes & caveats



- Detection is heuristic, based on grep plus manual reading, with no AST. Low-confidence findings can be false positives.

- Decision compliance was checked by reading the implementing services end to end, not only by keyword probing. It is still the lowest-confidence axis.

- Findings reflect commit `baf3636`; the working tree has no uncommitted app-code changes.

- There is no vault Changelog surface on this layout-3 vault (no `vault.md`, and `context.md` has no `## Changelog`). No write-back was applied, so `vault.json` and the vault version are untouched per the boundary rule. This session is recorded only in this report and in `PENDING-SYNC.md`.

- If the framework was mis-detected, re-run with an explicit `--scope=<dirs>` override.

### .mega-sdd/vaults/clinic-v2/PENDING-SYNC.md

# Pending sync decisions

**Last sync run**: 2026-09-27T02:47:12Z (detect-drift, standalone full scan @ `baf3636`) · **Open items**: 11



## 1. CONFLICTs (BLOCKING — gate closed for affected units)



_None from this run._



### .mega-sdd/vaults/clinic-v2/bolts/U-001/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: every v1 table, column, enum value, index and the partial unique index; `0000_init.sql` and its snapshot byte-identical.

- **ADD**: enum value `rescheduling_required`; enum `waitlist_status`; tables `waitlist_entries`, `doctor_leaves`; relations + inferred types; migration `0001_clinic_v2`; status-badge entry.



## Acceptance-test provenance NOTE



> NOTE: This unit's `acceptance_test` has weak blind-spot coverage

> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that

> wrote the unit body — the test may inherit the same blind spots as the spec

> and fail to catch behavioral bugs your implementation introduces.

>

> If your implementation passes this test but feels under-validated:

>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`

>     explaining what you suspect the test might miss

>   - Propose 1-2 additional assertions you'd add to strengthen coverage

>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested



### .mega-sdd/vaults/clinic-v2/bolts/U-002/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: v1 `COPY` texts, `AppointmentEmail`, `appointmentEmail` signature and output for the four v1 kinds.

- **ADD**: `EmailKind` members `cancelled`, `waitlist_offer`; builders `cancellationEmail`, `waitlistOfferEmail`.



## Acceptance-test provenance NOTE



> NOTE: This unit's `acceptance_test` has weak blind-spot coverage

> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that

> wrote the unit body — the test may inherit the same blind spots as the spec

> and fail to catch behavioral bugs your implementation introduces.

>

> If your implementation passes this test but feels under-validated:

>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`

>     explaining what you suspect the test might miss

>   - Propose 1-2 additional assertions you'd add to strengthen coverage

>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested



### .mega-sdd/vaults/clinic-v2/bolts/U-003/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: every v1 `ROUTE_ROLES` row and the doctor sidebar.

- **ADD**: two receptionist-only prefixes and two receptionist sidebar links.



## Acceptance-test provenance NOTE



> NOTE: This unit's `acceptance_test` has weak blind-spot coverage

> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that

> wrote the unit body — the test may inherit the same blind spots as the spec

> and fail to catch behavioral bugs your implementation introduces.

>

> If your implementation passes this test but feels under-validated:

>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`

>     explaining what you suspect the test might miss

>   - Propose 1-2 additional assertions you'd add to strengthen coverage

>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested



### .mega-sdd/vaults/clinic-v2/bolts/U-004/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: `patientDetailsSchema`, `bookingSchema`, `staffBookingSchema`, `loginSchema` unchanged.

- **ADD**: `waitlistSchema` + types in validation.ts; the new `src/server/waitlist.ts` module.



## Acceptance-test provenance NOTE



> NOTE: This unit's `acceptance_test` has weak blind-spot coverage

> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that

> wrote the unit body — the test may inherit the same blind spots as the spec

> and fail to catch behavioral bugs your implementation introduces.

>

> If your implementation passes this test but feels under-validated:

>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`

>     explaining what you suspect the test might miss

>   - Propose 1-2 additional assertions you'd add to strengthen coverage

>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested



### .mega-sdd/vaults/clinic-v2/bolts/U-005/dispatch-prompt.md

## Acceptance-test provenance NOTE



> NOTE: This unit's `acceptance_test` has weak blind-spot coverage

> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that

> wrote the unit body — the test may inherit the same blind spots as the spec

> and fail to catch behavioral bugs your implementation introduces.

>

> If your implementation passes this test but feels under-validated:

>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`

>     explaining what you suspect the test might miss

>   - Propose 1-2 additional assertions you'd add to strengthen coverage

>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested



### .mega-sdd/vaults/clinic-v2/bolts/U-006/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: every v1 check and message, the transaction + unique-violation mapping, the override bypass.

- **ADD**: leave checks in `getAvailableSlots`, the non-override branch of `createAppointment`, and `rescheduleWithToken`.



## Acceptance-test provenance NOTE



> NOTE: acceptance_test authored same-pass (_authored_by: absent — legacy unit, treated as same-pass) — it may share

> the spec's blind spots. Mark `confidence` no higher than MEDIUM for behaviors

> not directly tested; record doubts as `acceptance_test_concern` in bolt-report.md.



### .mega-sdd/vaults/clinic-v2/bolts/U-007/dispatch-prompt.md

## Migration notes



- **REMOVE**: the "OQ-CLINIC-003 unresolved → most permissive" placeholder comment.

- **KEEP**: token verification, nonce rotation, INVALID_TOKEN and TOO_LATE codes/messages and their order.

- **ADD**: `cancellationWindowHours()`, `WINDOW_CLOSED`, the window check.



## Acceptance-test provenance NOTE



> NOTE: This unit's `acceptance_test` has weak blind-spot coverage

> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that

> wrote the unit body — the test may inherit the same blind spots as the spec

> and fail to catch behavioral bugs your implementation introduces.

>

> If your implementation passes this test but feels under-validated:

>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`

>     explaining what you suspect the test might miss

>   - Propose 1-2 additional assertions you'd add to strengthen coverage

>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested



### .mega-sdd/vaults/clinic-v2/bolts/U-008/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: `createAppointmentToken`, `verifyAppointmentToken`, `newNonce` and their behaviour.

- **ADD**: `createOfferToken`, `verifyOfferToken`; the new offer-engine module.



### .mega-sdd/vaults/clinic-v2/bolts/U-009/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: every status code, redirect and JSON body of both routes.

- **ADD**: the post-cancel offer call; the expiry sweep + header in cron.



## Acceptance-test provenance NOTE



> NOTE: This unit's `acceptance_test` has weak blind-spot coverage

> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that

> wrote the unit body — the test may inherit the same blind spots as the spec

> and fail to catch behavioral bugs your implementation introduces.

>

> If your implementation passes this test but feels under-validated:

>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`

>     explaining what you suspect the test might miss

>   - Propose 1-2 additional assertions you'd add to strengthen coverage

>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested



### .mega-sdd/vaults/clinic-v2/bolts/U-011/dispatch-prompt.md

## Acceptance-test provenance NOTE



> NOTE: acceptance_test authored same-pass (_authored_by: absent — legacy unit, treated as same-pass) — it may share

> the spec's blind spots. Mark `confidence` no higher than MEDIUM for behaviors

> not directly tested; record doubts as `acceptance_test_concern` in bolt-report.md.



### .mega-sdd/vaults/clinic-v2/bolts/U-012/dispatch-prompt.md

## Acceptance-test provenance NOTE



> NOTE: This unit's `acceptance_test` has weak blind-spot coverage

> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that

> wrote the unit body — the test may inherit the same blind spots as the spec

> and fail to catch behavioral bugs your implementation introduces.

>

> If your implementation passes this test but feels under-validated:

>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`

>     explaining what you suspect the test might miss

>   - Propose 1-2 additional assertions you'd add to strengthen coverage

>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested



### .mega-sdd/vaults/clinic-v2/bolts/U-013/dispatch-prompt.md

## Acceptance-test provenance NOTE



> NOTE: This unit's `acceptance_test` has weak blind-spot coverage

> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that

> wrote the unit body — the test may inherit the same blind spots as the spec

> and fail to catch behavioral bugs your implementation introduces.

>

> If your implementation passes this test but feels under-validated:

>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`

>     explaining what you suspect the test might miss

>   - Propose 1-2 additional assertions you'd add to strengthen coverage

>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested



### .mega-sdd/vaults/clinic-v2/bolts/U-014/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: all v1 wizard steps, validation, booking flow and `bookAction`; the existing booking-wizard tests pass unmodified.

- **ADD**: optional `joinWaitlist` prop, join button in the empty Time step, `WaitlistForm`, `joinWaitlistAction`.



## Acceptance-test provenance NOTE



> NOTE: This unit's `acceptance_test` has weak blind-spot coverage

> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that

> wrote the unit body — the test may inherit the same blind spots as the spec

> and fail to catch behavioral bugs your implementation introduces.

>

> If your implementation passes this test but feels under-validated:

>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`

>     explaining what you suspect the test might miss

>   - Propose 1-2 additional assertions you'd add to strengthen coverage

>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested



### .mega-sdd/vaults/clinic-v2/bolts/U-015/dispatch-prompt.md

## Acceptance-test provenance NOTE



> NOTE: This unit's `acceptance_test` has weak blind-spot coverage

> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that

> wrote the unit body — the test may inherit the same blind spots as the spec

> and fail to catch behavioral bugs your implementation introduces.

>

> If your implementation passes this test but feels under-validated:

>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`

>     explaining what you suspect the test might miss

>   - Propose 1-2 additional assertions you'd add to strengthen coverage

>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested



### .mega-sdd/vaults/clinic-v2/bolts/U-016/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: v1 rendering for INVALID_TOKEN, TOO_LATE and the happy path.

- **ADD**: the WINDOW_CLOSED branch on both pages.



## Acceptance-test provenance NOTE



> NOTE: This unit's `acceptance_test` has weak blind-spot coverage

> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that

> wrote the unit body — the test may inherit the same blind spots as the spec

> and fail to catch behavioral bugs your implementation introduces.

>

> If your implementation passes this test but feels under-validated:

>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`

>     explaining what you suspect the test might miss

>   - Propose 1-2 additional assertions you'd add to strengthen coverage

>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested



### .mega-sdd/vaults/clinic-v2/bolts/_summary.md

## Self-assessment summary (uncertain decisions across batch)

- U-001: "FK delete behaviour: doctor_id cascade, service_id restrict, created_by restrict, appointment_id set null" — fallback: Change to restrict everywhere via a follow-up migration

- U-001: "CHECK end_date >= start_date on doctor_leaves" — fallback: Drop the check constraint

- U-001: "No provenance comment in the two drizzle JSON files" — fallback: n/a

- U-002: "appointmentEmail throws for cancelled/waitlist_offer" — fallback: Add COPY entries for new kinds and drop the guard

- U-002: "tsc acceptance requires `next typegen` first" — fallback: Controller runs `npx next typegen` before the check

- U-003: "Icons ListOrdered (Waitlist) and CalendarOff (Doctor leave)" — fallback: Swap for any other lucide icon

- U-004: "listWaitlist returns only waiting/offered entries; position counts those" — fallback: return all statuses, compute position only over queued

- U-004: "every doctor appears in listWaitlist even with no entries" — fallback: filter out empty groups

- U-005: "Past booked appointments inside the range are also flipped" — fallback: Add gte(startTime, now) to the update filter

- U-005: "nowOf/tzOf/Executor re-implemented locally in leave.ts" — fallback: Export them from appointments.ts in a later unit

- U-007: "Blank CANCELLATION_WINDOW_HOURS falls back to 24 instead of 0" — fallback: Drop the blank-string guard

- U-008: "offerFreedSlot skips a slot no longer free, or one already held by another offer" — fallback: Remove the getAvailableSlots and pending-offer checks

- U-008: "offerFreedSlotForAppointment requires status cancelled" — fallback: Drop the status check

- U-009: "Header omitted (not zeroed) when sweepExpiredOffers throws" — fallback: Set expired=0;offered=0 or an error marker

- U-010: "Bulk failure item carries error:string plus optional code" — fallback: Drop code and match on the message

- U-010: "Any non-rescheduling_required status -> VALIDATION 'Already resolved.' (also in freeDoctorsAt)" — fallback: Separate message for never-affected rows

- U-011: "Only bulk 'Cancel selected' asks window.confirm; per-row Cancel fires immediately" — fallback: Add the same confirm guard to per-row Cancel

- U-011: "Per-row results announced in one shared role=status region as 'patient: outcome'" — fallback: Add inline error text inside each row

- U-012: "Role refusal on bulk actions returned as per-id failures, not thrown" — fallback: Return a single {ok:false,error} and adapt the page

- U-012: "Client-side zod schema duplicates leaveSchema messages" — fallback: Move leaveSchema to src/lib/validation.ts later

- U-013: "Remove confirmation is an inline Confirm/Keep swap instead of window.confirm" — fallback: Radix AlertDialog from the installed radix-ui

- U-013: "searchParams typed by hand instead of PageProps<'/staff/waitlist'>" — fallback: Switch to PageProps after next typegen

- U-014: "WaitlistForm is a grouped block (not a nested <form>) inside the wizard form; Enter is intercepted" — fallback: Render the panel outside the wizard form

- U-014: "JoinWaitlistResult type defined in waitlist-form.tsx" — fallback: Move to src/components/booking/types.ts

- U-015: "Action calls getOfferByToken before acceptOffer to get doctorName" — fallback: Pass doctorName from page props

- U-015: "params typed by hand instead of PageProps" — fallback: Switch to PageProps after typegen

- U-016: "Notice uses the info Alert tone instead of error" — fallback: Switch tone to error



## Deferred open questions (4)

- OQ-OV-1 [P1] business — deferred (headless runner); PRD §4.1 says "VIP patients skip the waitlist queue and are offered freed slots first", but patients have no account (PRD §3) and nothing in

- OQ-CN-1 [P1] business — deferred (headless runner); PRD §4.3 says "Late cancellations are penalised" but defines no penalty (what, how much, who applies it), and payments are out of scope (PRD

- OQ-CN-2 [P1] business — deferred (headless runner); PRD §1 says v1 books **20-minute** slots, but the live code uses 15-minute slots (`SLOT_MINUTES = 15`, src/lib/clinic-config.ts:6; booking p

- OQ-CN-3 [P1] business — deferred (headless runner); PRD §1 says reminders go out **48 hours** before, but the live code sends them 24 hours before (`REMINDER_LEAD_MS`, src/lib/clinic-config.ts

Answer any time: `resolve-oq`.



### .mega-sdd/vaults/clinic-v2/context.md

## Open Questions



- [ ] **OQ-OV-1** [P1] [business] [conf: high] [origin: context.md#F-S-001]: PRD §4.1 says "VIP patients skip the waitlist queue and are offered freed slots first", but patients have no account (PRD §3) and nothing in the PRD or the repo (`patients` table, src/db/schema.ts:98) identifies a VIP; the offer-rule table says "first patient in the queue". How is a VIP identified, and who marks them? — resolve: Product Team. Until answered the queue is strictly first-come (the table rule) and no VIP logic is built. **Deferred (plan)**: headless benchmark run — no stakeholder available; deferred by the runner (conservative), resurfaced in the chain summary.

- [ ] **OQ-CN-1** [P1] [business] [conf: high]: PRD §4.3 says "Late cancellations are penalised" but defines no penalty (what, how much, who applies it), and payments are out of scope (PRD §6). What is the penalty? — resolve: Product Team / clinic management. No unit implements a penalty. **Deferred (plan)**: headless benchmark run — no stakeholder available; deferred by the runner (conservative), resurfaced in the chain summary.

- [ ] **OQ-CN-2** [P1] [business] [conf: high]: PRD §1 says v1 books **20-minute** slots, but the live code uses 15-minute slots (`SLOT_MINUTES = 15`, src/lib/clinic-config.ts:6; booking page copy "Appointments are 15 minutes", src/app/(public)/book/page.tsx:22; seeded services 15 min). Which is authoritative? — resolve: Product Team. v2 does not ask to change slot length, so the plan keeps the code as is (AC-207). **Deferred (plan)**: headless benchmark run — no stakeholder available; deferred by the runner (conservative), resurfaced in the chain summary.

- [ ] **OQ-CN-3** [P1] [business] [conf: high]: PRD §1 says reminders go out **48 hours** before, but the live code sends them 24 hours before (`REMINDER_LEAD_MS`, src/lib/clinic-config.ts:13; reminder email copy "in 24 hours", src/server/email/templates.tsx:28). Which is authoritative? — resolve: Product Team. The plan keeps the code as is (AC-207). **Deferred (plan)**: headless benchmark run — no stakeholder available; deferred by the runner (conservative), resurfaced in the chain summary.

- [ ] **OQ-FL-1** [P2] [business] [conf: high] [origin: context.md#F-U-002]: While an offer is outstanding (≤ 30 min), is the freed slot held for the offered patient, or can anyone book it online? What happens to the entry if they accept after someone else took it? — resolve: Product Team. The plan keeps v1 behaviour: a cancelled slot is free immediately (src/server/appointments.ts:284); an accept on a taken slot is refused with the v1 booking error and nothing changes.

- [ ] **OQ-FL-2** [P2] [business] [conf: high] [origin: context.md#F-S-001]: Should slots freed by a patient **reschedule** (moving away from a slot) also trigger waitlist offers? PRD §4.1 only names cancellation. — resolve: Product Team. The plan offers on cancellation only.

- [ ] **OQ-FL-3** [P2] [business] [conf: high] [origin: context.md#F-U-004]: When leave is recorded, what happens to waitlist entries (and open offers) for that doctor on leave dates? — resolve: Product Team. The plan leaves them untouched; they can get no new offers, and an accept on a leave date is refused by the booking rules.

- [ ] **OQ-FL-4** [P2] [business] [conf: high] [origin: context.md#F-U-005]: For an appointment in `rescheduling_required`: may the patient still use their email cancel/reschedule links, do they still get the reminder, and what happens if reception resolves it only after its start time? — resolve: Product Team. The plan keeps v1 rules: links and reminders apply to `booked` appointments only (src/server/appointments.ts:256, src/server/reminders.ts:20).

- [ ] **OQ-FL-5** [P2] [business] [conf: high] [origin: context.md#F-U-006]: PRD §4.3 says "Staff can still cancel or reschedule at any time from the portal", but the v1 portal has no general staff cancel or reschedule action (only reassign + walk-in, src/app/staff/(app)/reception/actions.ts:24-58). Should v2 add them? — resolve: Product Team. Not built (scope); the window never restricts staff paths.

- [ ] **OQ-FL-6** [P3] [business] [conf: high] [origin: context.md#F-U-004]: Can recorded leave be edited or deleted? What happens to appointments already moved to `rescheduling_required` if it is? — resolve: Product Team. Not built.

- [ ] **OQ-FL-7** [P3] [business] [conf: medium] [origin: context.md#F-U-001]: May the same patient join the same doctor + date waitlist twice? May they join for a day the doctor does not work? — resolve: Product Team. The plan applies the literal rule only (no free slot on a date not in the past).

- [ ] **OQ-CN-4** [P3] [business] [conf: high] [origin: context.md#F-U-006]: The in-window message asks patients to "call the clinic", but neither the PRD nor the code has a clinic phone number. Which number should be shown? — resolve: clinic management. Message shown without a number until answered.

- [x] **OQ-AR-4** [P1] [tech / recommend] [conf: high] [origin: context.md#F-U-005]: How is AC-205 (no double-booking under concurrent online booking) guaranteed for reassignment? → **Resolved v1.0** (AI decision, 2026-09-27): reuse the v1 partial unique index `appointments_doctor_slot_booked_uq` + one transactional UPDATE (`doctor_id`, `status = booked`); a unique violation maps to `SLOT_TAKEN`

- [x] **OQ-AR-1** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-006]: Where does the "cancellation window" clinic setting live? → **Resolved v1.0** (AI decision, 2026-09-27): env var `CANCELLATION_WINDOW_HOURS` read by a `cancellationWindowHours()` helper in src/lib/clinic-config.ts, default 24, following the `clinicTimeZone()` env pattern; no settings screen

- [x] **OQ-AR-2** [P2] [tech / recommend] [conf: high] [origin: context.md#F-S-002]: What runs the 30-minute offer expiry? → **Resolved v1.0** (AI decision, 2026-09-27): the existing 5-minute cron trigger `/api/cron/reminders` + `scripts/reminder-worker.ts` also runs an offer-expiry sweep; accept checks `offer_expires_at` at request time, so the 30 minutes is exact for the patient

- [x] **OQ-AR-3** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-002]: How is the offer's one-time link built? → **Resolved v1.0** (AI decision, 2026-09-27): the HMAC signing of src/lib/tokens.ts with a distinct offer payload (`w` entry id + `n` nonce) checked against `waitlist_entries.offer_nonce`, rotated on use

- [x] **OQ-DM-2** [P2] [tech / recommend] [conf: medium] [origin: context.md#Data-model]: A booking needs a service (`appointments.service_id` NOT NULL), but the waitlist form lists only name, email, phone, reason — which service does an accepted offer book? → **Resolved v1.0** (AI decision, 2026-09-27): store the service the patient already chose in wizard step 1 "Doctor & service" with the entry; no new question is shown

- [x] **OQ-DM-3** [P2] [tech / recommend] [conf: high] [origin: context.md#Data-model]: How is leave stored and applied to slots? → **Resolved v1.0** (AI decision, 2026-09-27): new `doctor_leaves` table with an inclusive clinic-local date range; `getAvailableSlots` returns no slots and the non-override create/reschedule paths refuse a leave date

- [x] **OQ-AR-5** [P3] [tech / scan] [conf: high]: Which test framework? → **Resolved v1.0** (AI decision, 2026-09-27): Vitest + PGlite integration helpers (`package.json` scripts.test, tests/helpers/db.ts:12)



## AI Technical Decisions



> 7 technical decisions taken by the AI — override any time: `resolve-oq single-oq <OQ-ID>`.



| OQ-ID | Decision | Basis (citation) | If wrong |

|---|---|---|---|

| OQ-AR-4 [P1] | DB partial unique index + transactional UPDATE for reassignment | src/db/schema.ts:130; src/server/staff.ts:118 | add `SELECT … FOR UPDATE` row lock on the target doctor's slot |

| OQ-AR-1 [P2] | `CANCELLATION_WINDOW_HOURS` env, default 24 | src/lib/clinic-config.ts:27 | move to a DB-backed settings table with a staff screen |

| OQ-AR-2 [P2] | expiry sweep on the existing 5-min cron + request-time expiry check | src/app/api/cron/reminders/route.ts:19; vercel.json | a dedicated cron route with its own schedule |

| OQ-AR-3 [P2] | HMAC offer token + per-entry nonce | src/lib/tokens.ts:1 | random opaque token stored hashed in the entry |

| OQ-DM-2 [P2] | entry stores the service chosen in wizard step 1 | src/components/booking/booking-wizard.tsx:27 | book the cancelled appointment's service instead |

| OQ-DM-3 [P2] | `doctor_leaves` table, inclusive date range | src/server/appointments.ts:73 | per-slot blocking rows |

| OQ-AR-5 [P3] | Vitest + PGlite | package.json; tests/helpers/db.ts:12 | — |

### .mega-sdd/vaults/clinic-v2/units/U-001.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: every v1 table, column, enum value, index and the partial unique index; `0000_init.sql` and its snapshot byte-identical.

- **ADD**: enum value `rescheduling_required`; enum `waitlist_status`; tables `waitlist_entries`, `doctor_leaves`; relations + inferred types; migration `0001_clinic_v2`; status-badge entry.



### .mega-sdd/vaults/clinic-v2/units/U-002.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: v1 `COPY` texts, `AppointmentEmail`, `appointmentEmail` signature and output for the four v1 kinds.

- **ADD**: `EmailKind` members `cancelled`, `waitlist_offer`; builders `cancellationEmail`, `waitlistOfferEmail`.



### .mega-sdd/vaults/clinic-v2/units/U-003.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: every v1 `ROUTE_ROLES` row and the doctor sidebar.

- **ADD**: two receptionist-only prefixes and two receptionist sidebar links.



### .mega-sdd/vaults/clinic-v2/units/U-004.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: `patientDetailsSchema`, `bookingSchema`, `staffBookingSchema`, `loginSchema` unchanged.

- **ADD**: `waitlistSchema` + types in validation.ts; the new `src/server/waitlist.ts` module.



### .mega-sdd/vaults/clinic-v2/units/U-006.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: every v1 check and message, the transaction + unique-violation mapping, the override bypass.

- **ADD**: leave checks in `getAvailableSlots`, the non-override branch of `createAppointment`, and `rescheduleWithToken`.



### .mega-sdd/vaults/clinic-v2/units/U-007.md

## Migration notes



- **REMOVE**: the "OQ-CLINIC-003 unresolved → most permissive" placeholder comment.

- **KEEP**: token verification, nonce rotation, INVALID_TOKEN and TOO_LATE codes/messages and their order.

- **ADD**: `cancellationWindowHours()`, `WINDOW_CLOSED`, the window check.



### .mega-sdd/vaults/clinic-v2/units/U-008.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: `createAppointmentToken`, `verifyAppointmentToken`, `newNonce` and their behaviour.

- **ADD**: `createOfferToken`, `verifyOfferToken`; the new offer-engine module.



### .mega-sdd/vaults/clinic-v2/units/U-009.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: every status code, redirect and JSON body of both routes.

- **ADD**: the post-cancel offer call; the expiry sweep + header in cron.



### .mega-sdd/vaults/clinic-v2/units/U-014.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: all v1 wizard steps, validation, booking flow and `bookAction`; the existing booking-wizard tests pass unmodified.

- **ADD**: optional `joinWaitlist` prop, join button in the empty Time step, `WaitlistForm`, `joinWaitlistAction`.



### .mega-sdd/vaults/clinic-v2/units/U-016.md

## Migration notes



- **REMOVE**: nothing.

- **KEEP**: v1 rendering for INVALID_TOKEN, TOO_LATE and the happy path.

- **ADD**: the WINDOW_CLOSED branch on both pages.



### .mega-sdd/vaults/clinic-v2/units/_index.md

## Not planned as units (open questions)



- VIP priority (OQ-OV-1), late-cancellation penalty (OQ-CN-1), slot length 20 vs 15 min (OQ-CN-2), reminder 48 vs 24 h (OQ-CN-3) — P1 business, waiting on the Product Team.

- General staff cancel/reschedule from the portal (OQ-FL-5), leave edit/delete (OQ-FL-6) — not built.

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

.mega-sdd/vaults/clinic-v2/bolts/U-013/binding.json: "CONFLICT": 0,

.mega-sdd/vaults/clinic-v2/bolts/U-014/binding.json: "CONFLICT": 0,

.mega-sdd/vaults/clinic-v2/bolts/U-015/binding.json: "CONFLICT": 1,

.mega-sdd/vaults/clinic-v2/bolts/U-015/binding.json: "verdict": "CONFLICT",

.mega-sdd/vaults/clinic-v2/bolts/U-016/binding.json: "CONFLICT": 0,