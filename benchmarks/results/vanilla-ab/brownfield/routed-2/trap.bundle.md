## Chat (main thread)

Writing `lane: lite` (new-PRD default) and re-deriving.

Front door sudah mengkonfirmasi chain yang sama → skip prompt.

▶ Phase 1 of 2: invoking plan (PRD/prd-clinic-v2.md --lite --mode=existing --auto)

I'm using the plan skill to turn the PRD into context.md + units (lite lane). `mega-sdd-trace:plan`

Sedang membaca codebase v1 untuk grounding plan (staff actions, email, migrasi, tests).

Plan grounding selesai. Menulis `context.md` (flows, DBML, constraints, OQ).

Menulis units batch 1 (foundation + cancellation window).

Batch 2: modul leave.

Batch 3: modul waitlist + regression verify.

unit-spec PASS. Menjalankan flow/sibling/plan-coverage validators.

Fix citation baris PRD di patch, lalu derive + validate OQs.

[ASSUMED-BY-RUNNER: plan batched ask — OQ-FL-1 (definisi VIP) & OQ-CN-1 (penalti late-cancel) -> Defer: paling mudah di-revert; tidak ada unit yang bergantung, fitur VIP/penalti tidak dibangun]

Plan selesai: 15 units, 5 modules, 7 flows, 3 entities, 16 OQ (10 AI-decided, 2 P1 deferred, 4 P2 business open). Kembali ke orchestrator: re-derive state + predictive preflight untuk hop bolts.

✓ Phase 1 of 2: plan → status: completed, items: 15 units, blocked: 0

▶ Phase 2 of 2: invoking execute-bolts (--all --lite --auto)

I'm using the execute-bolts skill to implement units via the mega-sdd bolt agents (parallel review panel). `mega-sdd-trace:execute-bolts`

Pre-flight batch: repo state, hooks, anchor freshness, L0 probe, wave plan.

JIT bind (3.9) untuk U-001, U-003:

Mencari path framework pack untuk router review-tier.

Pack = `plugin-brown/references/framework-conventions/next.md`. Routing tier + build dispatch prompts untuk U-001, U-003.

▶ Bolt 1/15: U-001 · ▶ Bolt 2/15: U-003 (xs → sonnet)

Detect-after untuk U-001 & U-003 (L0 → postflight → acceptance):

L0 pass (tsc advisory: `AppointmentStatus` type di clinic-config belum diperluas — scope U-002). Postflight + acceptance PASS. Menyiapkan panel slices + JIT bind U-002 (sekarang ready).

Controller menulis bolt-report kanonik (frontmatter + `target_hashes`) supaya readiness engine melihat unit `implemented`.

Prep U-002 (JIT bind, tier, prompt), lalu dispatch U-002 + panel U-001 + panel U-003 dalam satu pesan.

Tidak ada Critical; merge ledger U-001 & U-003, lalu detect-after U-002.

U-001 ✓, U-003 ✓. U-002 detect-after PASS → report, readiness, prep U-004/U-007.

Gate menolak dispatch: acceptance.json U-001/U-003 dianggap tidak fresh. Cek state.

Evidence commit saya ber-subject `chore(U-XXX):` → dihitung sebagai bolt commit. Re-run acceptance (writer resmi) dan ganti format subject evidence commit.

Merge ledger U-002 dan finalisasi, lalu dispatch ulang U-004/U-007.

▶ Bolt 4/15: U-004 · ▶ Bolt 5/15: U-007

Detect-after U-004 & U-007:

▶ Bolt 6/15: U-005 + panel U-004 (full + design) + panel U-007 (spec + design)

Semua lens tanpa Critical. Merge U-004/U-007, detect-after U-005.

▶ Bolt 7/15: U-009 · ▶ Bolt 8/15: U-006 + panel U-005 (full)

U-005 panel: no Critical (Important advisory: Zod schema untuk leave note, reuse `getDoctor`). Merge + finish; detect-after U-009 & U-006.

▶ Bolts 9–11/15: U-010, U-008, U-012 + panel U-009, U-006 (standard)

U-014 punya CONFLICT di JIT bind — cek.

U-014: `anchor_content_drift` pada `layout.tsx:14-17` (diubah oleh U-008, dependency-nya) → `binding_conflict` untuk U-014 saja; U-011/U-013 lanjut. Commit anchor repair U-011, lalu dispatch.

▶ Bolts 12–13/15: U-011, U-013 + panel U-010, U-008 (full+design), U-012 (standard+design)

Semua gate clear. Merge U-010/U-008/U-012; detect-after U-011/U-013.

Write reports U-011/U-013. Lalu resolusi CONFLICT U-014 via `resolve-oq --binding`.

Halt `binding_conflict` U-014 (hanya unit ini): klaim anchor `layout.tsx:14-17` berubah oleh U-008 (dependency yang sah). Menjalankan resolver resmi.

Koreksi anchor U-014 ke blok saat ini (`layout.tsx:16-22`, termasuk link U-008), catat changelog, lalu validasi gate.

resolve-oq selesai: 1 CONFLICT resolved (KEEP_CODE), 0 open. Kembali ke execute-bolts: commit unit edit, re-bind U-014 (3.9b), rebuild prompt.

▶ Bolt 14/15: U-014 + panel U-011 (full) + panel U-013 (full+design)

U-011: spec lens ❌ (mengedit `tests/integration/waitlist-offers.test.ts` di luar `target_files`). Merge dan ikuti gate.

▶ U-011 fix round 2 (pointer) + panel U-014 (full+design)

Fix(U-011) commit membuat acceptance.json U-011 stale → jalankan writer, merge U-014, lalu re-dispatch U-011.

Fix round landed (`ccc68c3`). Re-enter L0 pada fix commit, postflight, acceptance, lalu escape-hatch full re-panel (karena round-1 spec ❌).

Re-panel U-011 (escape hatch, blind, range original base..new head pada target files) + U-015 (verify) sekarang ready.

Semua dependency U-015 done. Dispatch U-015 (verify) + U-011 escape-hatch re-panel.

Re-panel U-011: spec ✅, tanpa Critical. Merge round 2 (escape-hatch menutup F-1 bila tidak muncul lagi).

U-015 (verify): acceptance writer, lalu panel (spec + security per router).

U-015 ✅ (spec pass; security: Important advisory B-001 Zod pada staff actions baru + route guard). Merge & finalisasi U-015.

Semua 15 unit selesai. Batch-completion full-suite gate (B2):

Suite green. Delivery check:

Gagal seperti yang diharapkan (2 receptionist cases). Fix:

Delivery PASS di HEAD final. Cek gate artefak (whitelist, batch-suite, postflight evidence):

Semua gate PASS. Tulis `_summary.md` (format dari halts-and-handoff).

▶ Phase 2.5: detect-drift (auto-gate, hybrid)

Chain selesai: kedua fase jalan (lane lite) dan state sekarang `pipeline_complete`. Semua 15 unit ter-bolt dan setiap gate yang mengecek hasilnya lulus di commit `4239e4c`.

**Keputusan yang saya ambil sendiri karena tidak ada stakeholder:**
- [ASSUMED-BY-RUNNER: konfirmasi chain di front-door -> Run: runner instruction, chain lite 2-hop adalah default engine]
- [ASSUMED-BY-RUNNER: batched ask di plan untuk OQ-FL-1 (definisi VIP) dan OQ-CN-1 (penalti late-cancel) -> Defer: paling mudah di-revert; fitur VIP dan penalti tidak dibangun, antrian waitlist murni urutan join]
- [ASSUMED-BY-RUNNER: binding CONFLICT U-014 C-U014-A08 -> KEEP_CODE + koreksi anchor: anchor `layout.tsx:14-17` berubah karena U-008 (dependency sah), tidak ada kode yang di-revert]
- [ASSUMED-BY-RUNNER: pause dari detect-drift (14 temuan, 0 CRITICAL) -> tidak di-apply, dibiarkan di antrian PENDING-SYNC: tidak ada keputusan bisnis yang diambil atas nama stakeholder]

**Fase 1, plan:** vault `.mega-sdd/vaults/clinic-v2` berisi 7 flows, 3 entities, 16 OQ dan 15 units di 5 modules. Dari 16 OQ, 10 adalah keputusan teknis AI yang tercatat di `context.md#AI-Technical-Decisions`, 2 P1 business di-defer, dan 4 P2 business masih open. Semua validator plan PASS.

**Fase 2, execute-bolts:**
- 15/15 unit done, tidak ada unit yang dikarantina, tidak ada halt yang tersisa.
- **U-011** butuh satu fix round. Spec reviewer menolaknya di round 1 karena mengedit test milik U-010 di luar `target_files`. Saya amandemen spec untuk mendeklarasikan file itu, implementer melakukan fix, lalu full re-panel meloloskannya.
- **U-014** sempat kena `binding_conflict` yang saya selesaikan lewat `resolve-oq --binding` (lihat keputusan di atas).
- Full suite: 27 files / 174 tests hijau (baseline v1: 12 / 73). Semua 12 test file v1 tidak berubah, jadi AC-207 terpenuhi.
- `delivery-check`: `VERDICT: PASS` untuk D1–D5, termasuk TZ UTC dan UTC+14 serta build dengan env kosong.

**Satu fix di luar bolt (`fix(delivery)` 4239e4c):** halaman `/staff/leave` dan `/staff/waitlist` sebelumnya tidak bisa dibuka receptionist karena route policy di proxy (`src/lib/access.ts`) belum memuat keduanya. Tiga review panel menemukannya, sementara `delivery-check` tidak. Saya perbaiki dengan test yang terbukti gagal dulu (`tests/unit/access-v2.test.ts`).

**Klaim PRD yang tidak cocok dengan kode v1** (dicatat sebagai P2 OQ, perilaku v1 tetap dipertahankan):
- PRD menyebut slot 20 menit; kode v1 memakai 15 menit.
- PRD menyebut reminder 48 jam; kode v1 memakai 24 jam.
- Status `rescheduling_required` disebut "existing" padahal belum ada di v1. Saya tambahkan karena §4.2 memerlukannya.
- Portal staff v1 tidak punya aksi cancel/reschedule; saya tidak membangun layar baru untuk itu.

**Masih terbuka:**
- **Temuan review "Important" yang tidak memblokir:**
  - Server Action leave/waitlist belum memvalidasi input dengan Zod (constitution B-001).
  - Aksi cancel/remove yang destruktif tidak punya langkah konfirmasi.
  - Sebelum menawarkan slot, kode tidak mengecek ulang apakah slot masih kosong.
  - Test race AC-205 berjalan di PGlite satu koneksi, jadi jalur `SLOT_TAKEN` dari unique index tidak benar-benar teruji.
- **detect-drift:** 11 keputusan arah menunggu di `PENDING-SYNC.md`. Contohnya: waitlist entry pada hari cuti dokter tetap "waiting" selamanya, dan reassign lama di reception board tidak mengecek cuti.
- **Tidak dijalankan:** Playwright E2E, dan ast-grep tidak terpasang sehingga klaim berbasis simbol tercatat sebagai OQ, bukan CONFIRMED.

Semua pekerjaan sudah di-commit di `main` (HEAD `de51856`) dan working tree bersih. Ringkasan per unit ada di `.mega-sdd/vaults/clinic-v2/bolts/_summary.md`, laporan drift di `.mega-sdd/vaults/clinic-v2/DRIFT-REPORT.md`.

⏸ 2 OQ deferred — OQ-FL-1, OQ-CN-1. Jawab kapan saja: resolve-oq

## Questions put to the user

(none)

## Commit messages

chore(drift): post-bolt detect-drift report + PENDING-SYNC queue (clinic-v2)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): batch summary, full-suite gate record, gate-recomputed evidence

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

fix(delivery): register /staff/leave and /staff/waitlist in the proxy route policy

The v2 leave (U-008) and waitlist (U-014) pages were unreachable for
receptionists: staffAccess() redirected every unlisted /staff/* path to the
role home. No unit owned src/lib/access.ts; flagged by the U-008, U-014 and
U-015 review panels. Adds a regression test.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): verify-unit report for U-015 (AC-207 regression gate)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): evidence for U-011 (round 2) + refreshed evidence for U-004/005/006/008/010

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

fix(U-011): Trigger waitlist offers on every cancellation and sweep expired offers from the cron route

Round-1 fixes: isolate the cron offer sweep so a failure is logged and the
reminder result is still returned (F-2, test added); restore U-010's
provenance line in waitlist-offers.test.ts so the edit there is helper-only (F-1).

Unit: U-011
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-011
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): evidence for U-014 (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

fix(U-011): declare waitlist-offers.test.ts helper edit in target_files (spec amendment for panel finding F-1)

Unit: U-011
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): evidence for U-013 (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-014): Staff waitlist page — each doctor's waitlist per date with remove

Unit: U-014
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-014
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(units): U-014 anchor corrected after KEEP_CODE binding resolution

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): evidence for U-012 (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): evidence for U-008 (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): evidence for U-010 (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-011): Trigger waitlist offers on every cancellation and sweep expired offers from the cron route

Unit: U-011
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-011
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-013): Public page to accept a waitlist offer through its one-time link

Unit: U-013
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-013
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(units): JIT-bind anchor repair (R1-shift) for U-011

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): evidence for U-006 (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): evidence for U-009 (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-010): Waitlist offer engine — offer freed slot, accept via one-time link, expire and pass on

Unit: U-010
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-010
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-008): Add the staff Doctor leave page, its server actions and the nav link

Unit: U-008
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-008
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-012): Offer "Join the waitlist" in the booking wizard when a date has no free slot

Unit: U-012
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-012
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): evidence for U-005 (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-006): List, reassign and cancel appointments affected by leave (single + bulk)

Unit: U-006
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-006
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-009): Waitlist core — join, list per doctor/date, remove

Unit: U-009
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-009
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(units): JIT-bind anchor repairs for U-006, U-009 + gate-recomputed postflight evidence

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(units): JIT-bind anchor repair (R1-shift) for U-005

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): evidence for U-007 (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): evidence for U-004 (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-005): Record doctor leave and hide the doctor's slots on leave dates

Unit: U-005
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-005
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-007): Build the leave manager component (record form + affected list with reassign/cancel)

Presentational client component (LeaveManager) records doctor leave and
lists affected appointments with per-row and bulk reassign/cancel,
following the reception-board action-result feedback pattern.

Unit: U-007
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-007
SDD-Acceptance: v5

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

feat(U-004): Enforce the cancellation window on patient cancel/reschedule links

Patient email-link preview, cancel and reschedule now refuse with
WINDOW_CLOSED when the appointment starts within CANCELLATION_WINDOW_HOURS
(default 24 h); TOO_LATE keeps precedence and staff paths are unrestricted.
The cancel page shows a call-the-clinic message.

Unit: U-004
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-004
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): evidence for U-002 (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(bolts): refresh acceptance evidence for U-001, U-003

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(U-003): bolt evidence (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

chore(U-001): bolt evidence (report, ledger, gates)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-002): Plumb the rescheduling_required status, window setting and new error codes

Unit: U-002
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-002
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

feat(U-003): Add the cancellation and waitlist-offer email templates

Adds `cancelled` (book-again link) and `waitlist_offer` (one-time
accept link + 30-minute expiry) email kinds per PRD §4.1/§4.2,
keeping v1 copy, buttons and footer unchanged (constitution D-001)
and never emailing the reason for visit (constitution B-003).

Unit: U-003
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-003
SDD-Acceptance: v5

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>

feat(U-001): Add waitlist, doctor-leave tables and the rescheduling_required status (schema + migration)

Unit: U-001
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-001
SDD-Acceptance: v5

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

plan(clinic-v2): lite-lane vault context + 15 units from PRD v2

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

## Recorded notes in committed markdown

### .mega-sdd/vaults/clinic-v2/DRIFT-REPORT.md

## Decision violations & decision unwritten (PRIORITY-1)



> No `D-XXX` ADR section exists on a layout-3 vault. The decision set compared is `context.md ## AI Technical Decisions` (OQ-AR-1, OQ-FL-3…11), the resolved OQs, and `constitution.md`. **No violations were found.** The items below are code-embodied decisions the vault does not capture.



### DRIFT-01: Decision unwritten. v1 reception reassign ignores doctor leave and working hours (confidence: medium)



**Vault**: `context.md ## AI Technical Decisions` OQ-FL-7 lists what leave blocks: "online slot listing, online booking and patient-link reschedule into a leave date; staff walk-in keeps v1 behaviour". It is silent on the v1 reception **reassign** action.

**Code**: `src/server/staff.ts:105-142` (`reassignAppointment`, v1, called by `src/app/staff/(app)/reception/actions.ts:24`) checks only role, `booked` status and overlap. It does **not** check `isDoctorOnLeave` or `isRegularSlot`. The v2 leave-resolution reassign (`src/server/leave-resolution.ts:67-78`, `assertWorksAt`) checks both.

**Drift**: a receptionist can use the reception board to move a booked appointment onto a doctor who is on leave that day. The same move is refused on the leave page. There are two reassign paths with different guards, and the vault records neither choice.

**Suggested action**: (A) record the decision: extend OQ-FL-7 to state that v1 reception reassign keeps v1 behaviour (like walk-in). (B) Fix the code: add the leave check to `reassignAppointment`, but first confirm AC-207 v1 tests still pass. (C) Defer as a new OQ.



### DRIFT-02: Decision unwritten. Existing waitlist entries are orphaned when leave is recorded afterwards (confidence: medium)



**Vault**: OQ-FL-8 says "no offer for a freed slot … inside leave; joining the waitlist for a leave date is refused". It covers only **new** joins and offers.

**Code**: `src/server/leave.ts:58-76` (`recordLeave`) updates `appointments` only and never touches `waitlist_entries`. Entries already `waiting` for that doctor on a leave date stay `waiting` indefinitely, because `offerFreedSlot` returns null inside leave (`src/server/waitlist-offers.ts:50`). An entry already `offered` for a slot that now falls inside leave fails on accept with `ON_LEAVE` and goes back to `waiting` (`src/server/waitlist-offers.ts:189-194`).

**Drift**: patients on the waitlist for a day that later becomes leave are never told, and their entries never resolve. The vault does not decide whether these entries should be expired, removed or notified.

**Suggested action**: (A) add a decision to the vault, for example "recording leave removes/expires active waitlist entries in range", then implement it. (B) Accept the current behaviour and record it as a decision (receptionist removes entries manually via F-U-006). (C) Defer as a new OQ.



### DRIFT-03: Decision unwritten. The server-side waitlist join accepts dates the doctor does not work (confidence: medium)



**Vault**: F-U-001 D3 "Still no free slot and doctor not on leave?" and DoD "A join for a doctor + date that has a free slot is refused server-side (AC-201)".

**Code**: `src/server/waitlist.ts:35-44` refuses past dates, leave dates and dates with free slots. `getAvailableSlots` returns `[]` for a weekend or non-working weekday (`src/lib/slots.ts:16-21`), so the server **accepts** a join for a day the doctor never works. The UI hides such dates (`src/components/booking/date-slot-picker.tsx:43-45`), but a direct Server Action call (`src/app/(public)/book/actions.ts:44`) creates an entry that can never receive an offer.

**Drift**: "no free slot" and "fully booked working day" are treated as the same thing on the server. This literally matches the vault wording but may not match its intent.

**Suggested action**: (A) tighten the vault: state that the join requires a working day (`worksOn`), then fix the code. (B) Accept the current behaviour and record that the UI is the only guard.



### DRIFT-04: Decision unwritten. Waitlist join is rate-limited per IP (confidence: high)



**Code**: `src/app/(public)/book/actions.ts:44-56`. `joinWaitlistAction` applies `bookingRateLimiter` with key `waitlist:<ip>` and returns `RATE_LIMITED`.

**Vault**: F-U-001 and the constitution make no mention of rate limiting on the join.

**Suggested action**: (A) record it in `context.md` (F-U-001 or Constraints), citing the file. (B) Remove it if it was unintended.



### DRIFT-05: Decision unwritten. Cancellation-window fallback semantics (confidence: high)



**Code**: `src/lib/clinic-config.ts:38-44` (`cancellationWindowMs`). An invalid, non-numeric or negative `CANCELLATION_WINDOW_HOURS` falls back to 24 h. The value `0` is accepted and disables the window.

**Vault**: OQ-AR-1 says only "env var …, default 24".

**Suggested action**: (A) extend OQ-AR-1 with the fallback rule and state whether `0` is a legitimate setting. (B) Change the code, for example to reject `0`.



### DRIFT-06: Decision unwritten. Overlapping leave is allowed, and leave cannot be edited or removed (confidence: high)



**Code**: `src/server/leave.ts:35-77` has no overlap check against existing `doctor_leaves`. There is no update or delete function for leave anywhere under `src/server/` or `src/app/staff/(app)/leave/`. The U-005 self-assessment in `bolts/_summary.md` confirms "overlapping leaves allowed".

**Vault**: F-U-003 does not address overlap, correction or cancellation of recorded leave.

**Suggested action**: (A) record both choices as decisions in F-U-003. (B) Open an OQ if correcting or cancelling leave is a business need. After leave is recorded, affected appointments are already `rescheduling_required` and cannot be reverted.



### DRIFT-07: Decision unwritten. Slots freed by reschedule or reception reassign are not offered to the waitlist (confidence: low, verify manually)



**Code**: `src/server/appointments.ts:333-383` (`rescheduleWithToken`) and `src/server/staff.ts:105-142` (`reassignAppointment`) both free a doctor's slot, and neither calls `offerFreedSlotSafely`. Only cancellations do (`src/server/appointments.ts:315`, `src/server/leave-resolution.ts:187`).

**Vault**: the F-S-001 trigger is "A `booked` appointment is cancelled". This matches the code literally, but PRD Goal 1 is "fill slots freed by cancellations", and a reschedule also frees a slot.

**Suggested action**: (A) confirm that cancellation-only is intended and note it in F-S-001. (B) Extend the trigger to reschedule and reassign.



## Notes & caveats



- Detection is heuristic (grep + read, no AST: ast-grep is absent). Low-confidence findings can be false positives.

- Decision compliance was probed by reading each AI-decision anchor and the related code paths. Treat the findings as review triggers, not verdicts.

- **Vault-internal inconsistency (not code drift)**: `vault.json` `entities[doctor_leaves].fields_count = 6`, but the `context.md` DBML declares 7 fields. `derive-vault-json.sh` should reconcile this on the next vault write.

- **Vault metadata / Changelog**: this plan-born layout-3 vault has no `vault.md` and no Changelog section. No write-back was applied (`--auto-apply` not set), so the vault version stays at 1.0 and `vault.json` is untouched. `context.md` was deliberately **not** edited to add a Changelog, to avoid shifting the `context_source` anchors and hashes that units cite. This drift session is recorded by this report alone.

- Findings reflect commit `7299994` with a clean working tree.

### .mega-sdd/vaults/clinic-v2/PENDING-SYNC.md

# Pending sync decisions

**Last sync run**: 2026-09-27 (detect-drift, full scan @ `7299994`) · **Open items**: 14



## 1. CONFLICTs (BLOCKING — gate closed for affected units)

_None. detect-drift raised no binding CONFLICT. Per-unit `bolts/U-*/binding.json` are untouched._



### .mega-sdd/vaults/clinic-v2/bolts/U-001/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: all v1 tables, columns, indexes, `appointments_doctor_slot_booked_uq`

- **ADD**: enum value `rescheduling_required`; enum `waitlist_status`; tables `waitlist_entries`, `doctor_leaves`; relations + types



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



- **REMOVE**: nothing

- **KEEP**: v1 constants and badge entries

- **ADD**: new status value, window setting, offer TTL constant, three error codes, one badge entry



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



- **REMOVE**: nothing

- **KEEP**: v1 copy, buttons and footer for the four v1 kinds

- **ADD**: two kinds, one builder function



## Acceptance-test provenance NOTE



> NOTE: acceptance_test authored same-pass (_authored_by: absent — legacy unit, treated as same-pass) — it may share

> the spec's blind spots. Mark `confidence` no higher than MEDIUM for behaviors

> not directly tested; record doubts as `acceptance_test_concern` in bolt-report.md.



### .mega-sdd/vaults/clinic-v2/bolts/U-004/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: the v1 TOO_LATE rule and message, token one-time semantics

- **ADD**: WINDOW_CLOSED refusal + page message



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

## Migration notes



- **REMOVE**: nothing

- **KEEP**: v1 slot rules, staff walk-in path, token checks from U-004

- **ADD**: leave module; leave checks in availability, online create and patient reschedule



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



### .mega-sdd/vaults/clinic-v2/bolts/U-007/dispatch-prompt.md

## Acceptance-test provenance NOTE



> NOTE: acceptance_test authored same-pass (_authored_by: absent — legacy unit, treated as same-pass) — it may share

> the spec's blind spots. Mark `confidence` no higher than MEDIUM for behaviors

> not directly tested; record doubts as `acceptance_test_concern` in bolt-report.md.



### .mega-sdd/vaults/clinic-v2/bolts/U-008/bolt-report.md

## Truncation note

The dispatch truncated the framework-pack rules to the top 1 and the code-style slice to its first bullet. Confidence in pack-convention conformance is MEDIUM.



### .mega-sdd/vaults/clinic-v2/bolts/U-008/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: v1 nav links and layout

- **ADD**: one receptionist nav link, one page, one actions file



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



### .mega-sdd/vaults/clinic-v2/bolts/U-009/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: all v1 schemas and messages

- **ADD**: `waitlistJoinSchema`, waitlist module



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



### .mega-sdd/vaults/clinic-v2/bolts/U-010/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: appointment token format and behaviour

- **ADD**: offer token helpers, offer module



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

## Migration notes



- **REMOVE**: nothing

- **KEEP**: v1 cancel semantics, reminder sweep, cron auth

- **ADD**: offer side effect after cancellations; offer sweep in the cron handler



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



### .mega-sdd/vaults/clinic-v2/bolts/U-012/bolt-report.md

## Notes

- The join form is a sibling `<form>` rendered under the wizard's `<form>` (same column, only on the Time step), because HTML does not allow nested forms.

- `booking-wizard.tsx` was re-indented by that extra wrapper `<div>`; `git diff -w` shows the real change is small.

- `formatDate` returns no year ("Tuesday, October 6"), so the confirmation reads "... on Tuesday, October 6. We'll email you if a slot frees up."

- reuse-index.yaml is missing (.mega-sdd/codebase/ does not exist), so the full-index scan could not be done. Reused what the anchors named: waitlistJoinSchema, joinWaitlist, bookingRateLimiter, Alert/Button/Input/Textarea, formatDate.

- Pulled the IP lookup out of bookAction into a private `clientIp()` so both actions share it. bookAction behaves the same.

- The T2 slices were truncated (framework pack rules, code style). The "use client" rule was followed.



acceptance_test_concern: The tests use a mocked `joinWaitlist` action. Nothing tests `joinWaitlistAction` itself (the `waitlist:` rate-limit key and the DomainError mapping). Two tests would cover it: an integration test where the 11th call returns RATE_LIMITED, and one where a DomainError comes back as `{ok:false, code, error}`.



### .mega-sdd/vaults/clinic-v2/bolts/U-012/dispatch-prompt.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: the booking flow and its tests unchanged when slots exist

- **ADD**: optional `joinWaitlist` prop, join form, server action



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



- **REMOVE**: nothing

- **KEEP**: existing nav links

- **ADD**: one receptionist nav link, one page, one actions file, one component



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



### .mega-sdd/vaults/clinic-v2/bolts/_summary.md

## Self-assessment summary (uncertain decisions across batch)

- U-005: listLeaves receptionist-only; overlapping leaves allowed — fallback: allow doctors (own id) / reject overlaps.

- U-007: bulk reassign disabled until every checked row has a target — fallback: send only selected rows.

- U-010: ON_LEAVE on accept returns entry to waiting; expired entries keep nonce — fallback: narrow list / rotate on expiry.

- U-011: cron body adds `offers` only when an offer expired (v1 test pins exact body) — fallback: always include + relax routes.test.ts.

- U-014: queue position counts only waiting/offered entries — fallback: number every row.



## Deferred open questions (2)

- OQ-FL-1 [P1] business — VIP definition (PRD §4.1). Deferred (plan, runner-assumed): VIP priority not built; queue = join order.

- OQ-CN-1 [P1] business — late-cancellation penalty (PRD §4.3). Deferred (plan, runner-assumed): no penalty built.

Open P2 business OQs: OQ-CN-2 (20- vs 15-minute slots), OQ-CN-3 (48 h vs 24 h reminder), OQ-DM-1 (`rescheduling_required` "existing"), OQ-FL-2 (staff cancel/reschedule screens). Answer any time: `resolve-oq`.



### .mega-sdd/vaults/clinic-v2/context.md

## Open Questions



- [ ] **OQ-FL-1** [P1] [business] [origin: context.md#F-S-001]: PRD §4.1 says "VIP patients skip the waitlist queue and are offered freed slots first", but neither the PRD nor v1 defines who is a VIP (no patient accounts — PRD §3/§6; `patients` table has no such flag — src/db/schema.ts:95). How is a VIP identified? Until answered the queue is plain join order. **Deferred (plan)**: no stakeholder available in this headless run (runner-assumed Defer); VIP priority is not built, queue = join order.

- [ ] **OQ-CN-1** [P1] [business] [origin: context.md#F-U-005]: PRD §4.3 says "Late cancellations are penalised" with no definition of the penalty (payments are out of scope — PRD §6). What is the penalty, and what counts as late? **Deferred (plan)**: no stakeholder available in this headless run (runner-assumed Defer); no penalty is built.

- [ ] **OQ-CN-2** [P2] [business] [origin: context.md#Overview]: PRD §1 states v1 books "20-minute slots"; v1 code uses 15-minute slots (src/lib/clinic-config.ts:6, v1 PRD BR-001). v2 does not request a change and AC-207 keeps v1 behaviour, so slots stay 15 minutes — confirm the PRD statement is a typo.

- [ ] **OQ-CN-3** [P2] [business] [origin: context.md#Overview]: PRD §1 states the reminder is sent "48 hours" before; v1 code sends it 24 hours before (src/lib/clinic-config.ts:13, v1 PRD BR-003). Kept at 24 h per AC-207 — confirm.

- [ ] **OQ-DM-1** [P2] [business] [origin: context.md#Data-model]: PRD §1/§4.2 call `rescheduling_required` "the existing status", but the v1 enum has only booked/cancelled/completed (src/db/schema.ts:92). §4.2 requires the status, so v2 adds it — confirm no other v1 behaviour was expected around it.

- [ ] **OQ-FL-2** [P2] [business] [origin: context.md#F-U-005]: PRD §4.3 says "Staff can still cancel or reschedule at any time from the portal", but the v1 portal has no staff cancel/reschedule action (only reassign + walk-in — src/app/staff/(app)/reception/actions.ts:24,44). v2 does not build new staff cancel/reschedule screens beyond the leave flow — confirm whether they are wanted.

- [x] **OQ-AR-1** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-005]: where does the "clinic setting" for the window length live? → **Resolved v1.0** (AI decision, 2026-09-27): `CANCELLATION_WINDOW_HOURS` env var read in `src/lib/clinic-config.ts`, default 24 — the existing clinic settings are constants/env there (`clinicTimeZone()` src/lib/clinic-config.ts:29).

- [x] **OQ-FL-3** [P2] [tech / recommend] [conf: high] [origin: context.md#F-S-001]: is the freed slot held for the offered patient? → **Resolved v1.0** (AI decision, 2026-09-27): not held — v1 frees a cancelled slot immediately and a v1 test rebooks it at once (tests/integration/patient-token.test.ts:36); accepting fails gracefully if the slot was taken.

- [x] **OQ-FL-4** [P2] [tech / recommend] [conf: high] [origin: context.md#F-S-001]: how do offers expire and pass on? → **Resolved v1.0** (AI decision, 2026-09-27): the existing 5-minute cron route also runs an expired-offer sweep (vercel.json:3, src/app/api/cron/reminders/route.ts:18); accept re-checks expiry itself.

- [x] **OQ-FL-5** [P2] [tech / recommend] [conf: medium] [origin: context.md#F-U-002]: which service does an accepted offer book? → **Resolved v1.0** (AI decision, 2026-09-27): the service the patient chose in the booking wizard before joining (wizard picks doctor + service before date — src/components/booking/booking-wizard.tsx:38); stored on the entry.

- [x] **OQ-FL-6** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-004]: status of a reassigned leave appointment? → **Resolved v1.0** (AI decision, 2026-09-27): back to `booked` — AC-205 speaks of "booked appointments" and the v1 unique index guards only `booked` rows (src/db/schema.ts:132).

- [x] **OQ-FL-7** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-003]: which paths does leave block? → **Resolved v1.0** (AI decision, 2026-09-27): online slot listing, online booking and patient-link reschedule into a leave date; staff walk-in keeps v1 behaviour (PRD §4.2 restricts "patients").

- [x] **OQ-FL-8** [P2] [tech / recommend] [conf: high] [origin: context.md#F-S-001]: offers/joins for a doctor on leave? → **Resolved v1.0** (AI decision, 2026-09-27): no offer for a freed slot in the past or inside leave; joining the waitlist for a leave date is refused (the slot can never free up for booking — PRD §4.2 bullet 2).

- [x] **OQ-FL-9** [P2] [tech / recommend] [conf: medium] [origin: context.md#F-U-002]: accept when the slot was already taken? → **Resolved v1.0** (AI decision, 2026-09-27): show "no longer available", the entry returns to `waiting` keeping its queue position; the link is consumed.

- [x] **OQ-FL-10** [P2] [tech / recommend] [conf: high] [origin: context.md#F-U-004]: which "cancellation email"? → **Resolved v1.0** (AI decision, 2026-09-27): new email kind `cancelled` with a book-again link to `/book` — v1 has no cancellation email kind (src/server/email/mailer.ts:4).

- [x] **OQ-FL-11** [P3] [tech / recommend] [conf: medium] [origin: context.md#F-U-001]: duplicate joins? → **Resolved v1.0** (AI decision, 2026-09-27): a second active (`waiting`/`offered`) entry with the same email for the same doctor + date is refused.



## AI Technical Decisions



> 10 keputusan teknis diambil AI — override kapan saja: `resolve-oq single-oq <OQ-ID>`.



| OQ-ID | Keputusan | Dasar (sitasi) | Kalau salah |

|---|---|---|---|

| OQ-AR-1 [P2] | `CANCELLATION_WINDOW_HOURS` env, default 24, in clinic-config | src/lib/clinic-config.ts:29 | move to a settings table + staff UI |

| OQ-FL-3 [P2] | freed slot not held during an offer | tests/integration/patient-token.test.ts:36 | add a hold column + exclude from availability |

| OQ-FL-4 [P2] | expiry sweep in the existing cron route + lazy check on accept | vercel.json:3 | separate cron path |

| OQ-FL-5 [P2] | accepted offer books the service chosen at join | src/components/booking/booking-wizard.tsx:38 | copy the cancelled appointment's service |

| OQ-FL-6 [P2] | reassigned appointment returns to `booked` | src/db/schema.ts:132 | keep a distinct status |

| OQ-FL-7 [P2] | leave blocks online listing/booking/patient reschedule; staff walk-in unchanged | PRD §4.2 | also block staff walk-in |

| OQ-FL-8 [P2] | no offers inside leave/past; join refused on leave dates | PRD §4.2 | allow and let offers skip |

| OQ-FL-9 [P2] | taken slot on accept → entry back to waiting | PRD §4.1 | expire the entry instead |

| OQ-FL-10 [P2] | new `cancelled` email kind with book-again link | src/server/email/mailer.ts:4 | reuse another kind |

| OQ-FL-11 [P3] | refuse duplicate active joins per email/doctor/date | PRD §4.1 | allow duplicates |

### .mega-sdd/vaults/clinic-v2/units/U-001.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: all v1 tables, columns, indexes, `appointments_doctor_slot_booked_uq`

- **ADD**: enum value `rescheduling_required`; enum `waitlist_status`; tables `waitlist_entries`, `doctor_leaves`; relations + types



### .mega-sdd/vaults/clinic-v2/units/U-002.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: v1 constants and badge entries

- **ADD**: new status value, window setting, offer TTL constant, three error codes, one badge entry



### .mega-sdd/vaults/clinic-v2/units/U-003.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: v1 copy, buttons and footer for the four v1 kinds

- **ADD**: two kinds, one builder function



### .mega-sdd/vaults/clinic-v2/units/U-004.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: the v1 TOO_LATE rule and message, token one-time semantics

- **ADD**: WINDOW_CLOSED refusal + page message



### .mega-sdd/vaults/clinic-v2/units/U-005.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: v1 slot rules, staff walk-in path, token checks from U-004

- **ADD**: leave module; leave checks in availability, online create and patient reschedule



### .mega-sdd/vaults/clinic-v2/units/U-008.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: v1 nav links and layout

- **ADD**: one receptionist nav link, one page, one actions file



### .mega-sdd/vaults/clinic-v2/units/U-009.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: all v1 schemas and messages

- **ADD**: `waitlistJoinSchema`, waitlist module



### .mega-sdd/vaults/clinic-v2/units/U-010.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: appointment token format and behaviour

- **ADD**: offer token helpers, offer module



### .mega-sdd/vaults/clinic-v2/units/U-011.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: v1 cancel semantics, reminder sweep, cron auth

- **ADD**: offer side effect after cancellations; offer sweep in the cron handler



### .mega-sdd/vaults/clinic-v2/units/U-012.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: the booking flow and its tests unchanged when slots exist

- **ADD**: optional `joinWaitlist` prop, join form, server action



### .mega-sdd/vaults/clinic-v2/units/U-014.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: existing nav links

- **ADD**: one receptionist nav link, one page, one actions file, one component



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

.mega-sdd/vaults/clinic-v2/bolts/U-015/binding.json: "CONFLICT": 0,