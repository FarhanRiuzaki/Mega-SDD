## Chat (main thread)

Guarded lane. Running GROUND.

I'm using the plan skill to turn the source into context.md + units. `mega-sdd-trace:plan`

Sedang membaca codebase v1 (schema, service appointment, slot, token) untuk menyusun context.md dan units.

Masih di fase plan: memeriksa bagaimana OQ yang dirujuk unit memblokir dispatch, lalu menulis context.md.

Menulis context.md, constitution.md dan meta vault.

Now constitution + consumer guide + patch, then derive vault.json.

Menulis units — batch 1 (foundation + cancellation window).

Batch 2 — modul waitlist (U-003..U-008).

Batch 3 — modul doctor leave (U-009..U-012).

Dispatching adversarial reviewers for the two high-risk units (U-003, U-011) in parallel.

Meanwhile: `_index.md`.

Merge temuan adversarial (3 gap per unit) ke U-003 dan U-011.

Preflight OK (6 ok, 0 fatal). Commit vault, lalu ▶ Phase 2 of 2: execute-bolts.

✓ Phase 1 of 2: plan → status: completed, items: 12 units, blocked: 0

▶ Phase 2 of 2: invoking execute-bolts (--all --lite --inline --auto)

I'm using the execute-bolts skill to implement units via the mega-sdd bolt agents (parallel review panel). `mega-sdd-trace:execute-bolts`

`--inline` aktif, jadi saya baca `inline-run.md` dulu.

Pre-flight bersih. (b) Up-front bind:

Karantina: tidak ada. 5 klaim `deferred` (file dibuat unit sebelumnya). Membaca plan.

superpowers:executing-plans tersedia → invoke dengan path plan.

Task 1: U-001.

RED karena fitur belum ada (enum invalid). Implementasi schema:

Task 2 (U-002): menulis failing test cancellation window.

RED as expected (3 behaviour tests fail; 3 regression guards pass). Implement:

Task 3 (U-003): offer lifecycle. Lihat helper time/utils dulu.

RED (module missing). Implementasi:

Task 4 (U-004): waitlist service.

Test flaky: `createdAt` memakai clock ctx yang beku, jadi urutan antrean seri. Perbaiki test dengan memajukan clock (systematic cause, bukan kode).

Task 5 (U-005): cancellation trigger + cron sweep.

Task 6 (U-006): join-waitlist UI. Membaca wizard.

Komponen lulus. Sekarang server action + page wiring.

Task 7 (U-007): offer acceptance page.

Task 8 (U-008): staff waitlist page + nav/access.

Task 9 (U-009): leave service.

Task 10 (U-010): leave blocks booking.

RED tanpa implementasi terverifikasi, GREEN dengan implementasi.

Task 11 (U-011): reassign/cancel affected appointments.

Re-bind U-011 melaporkan 1 CONFLICT — periksa dulu sebelum lanjut.

Sisa CONFLICT hanya `own_wip: true` (test file milik task ini) → plan mengizinkan lanjut. Implementasi U-011:

Kesalahan di test (assertion penerima yang ceroboh). Perbaiki assertion-nya:

Task 12 (U-012): staff leave page.

Komponen lulus. Page + actions:

Semua 12 task selesai. After-the-last-task step 1: full suite.

Step 2: ONE blind review of the run range (fresh reviewer, most capable model).

GREEN. Fix #3 (U-009), RED dulu:

Kedua fix GREEN, suite 163/163. Commit per unit + evidence ulang:

Step 4: delivery check.

`VERDICT: PASS`. Step 5–7: full suite ulang, evidence run, run-boundary gate.

U-002 acceptance evidence stale (commit `fix(U-002)` anchor refresh datang setelahnya). Re-run writer-nya:

Gate exit 0. `--recompute` menulis ulang postflight.json → commit, gate sekali lagi, lalu retire run.

execute-bolts selesai. Orchestrator: drift gate auto (DEFAULT-ON) setelah execute-bolts.

Delivery-check ulang di commit terakhir (HEAD sekarang hanya berisi commit evidence):

Waitlist, doctor leave, dan cancellation window sudah terpasang di aplikasi v1 dan di-commit di `main`. Delivery check lulus di commit terakhir (`fc173c1`) — `VERDICT: PASS`: test lulus di TZ=UTC dan UTC+14, `build` lulus tanpa `.env`, dan semua page route punya link. Test suite naik dari 73 ke 163, semua lulus.

Ada satu hal yang menunggu kamu: drift gate setelah build menemukan 8 perbedaan antara vault dan kode (0 CRITICAL, 5 HIGH, 2 MEDIUM, 1 LOW). Semuanya diantrekan di `PENDING-SYNC.md` untuk diputuskan manusia lewat `/mega-sdd:sync`; vault dan kode tidak saya ubah. Tiga yang paling perlu dilihat:
- **DR-01:** input leave sekarang tidak membalik janji yang sudah mulai. Ini perbaikan dari review, tapi vault masih bilang "semua janji di rentang tanggal".
- **DR-02:** join waitlist ditolak untuk tanggal lampau, hari dokter tidak praktik, dan tanggal cuti. Vault belum mencatat aturan ini.
- **DR-04:** walk-in dengan override staff dan reassign v1 tidak mengecek status cuti dokter.

Selain itu, beberapa nomor baris yang dikutip di `context.md` dan `constitution.md` sudah bergeser. Memperbaiki yang di `constitution.md` mengubah hash-nya, jadi `constitution_hash` perlu di-pin ulang.

## Acceptance criteria → test

| AC | Status | Test |
|---|---|---|
| AC-201 join waitlist, validasi sama dengan booking | ✅ | `tests/integration/waitlist.test.ts`, `tests/component/waitlist-join.test.tsx` |
| AC-202 cancel → email offer ke antrean pertama; accept sekali → booked/online, keluar dari waitlist | ✅ | `waitlist-offers.test.ts`, `waitlist-trigger.test.ts`, `tests/component/offer-accept.test.tsx` |
| AC-203 input leave; slot dokter di tanggal itu tidak bisa dibooking | ✅ | `leave.test.ts`, `leave-booking.test.ts`, `tests/component/staff-leave.test.tsx` |
| AC-204 reassign/cancel per janji atau massal, pasien di-email | ✅ | `leave-resolution.test.ts`, `staff-leave.test.tsx` |
| AC-205 tidak ada double-book walau bersamaan dengan booking online | ✅ | `leave-resolution.test.ts` (race 6 putaran, dua urutan) |
| AC-206 cancellation window default 24 jam, bisa diatur; staff tidak dibatasi | ✅ | `cancellation-window.test.ts` |
| AC-207 perilaku dan test v1 tetap lulus | ✅ | full suite 163/163 (73 test v1 tidak diubah) |

Tidak ada unit yang dikarantina. Ke-12 unit selesai.

## Keputusan runner (sesi headless)
- [ASSUMED-BY-RUNNER: konfirmasi chain di awal -> Run]
- [ASSUMED-BY-RUNNER: pasang ast-grep? -> tidak; klaim simbol dinilai OQ]
- [ASSUMED-BY-RUNNER: OQ-FL-1 siapa pasien VIP -> Defer; antrean murni FIFO]
- [ASSUMED-BY-RUNNER: OQ-FL-2 penalti late cancellation -> Defer; tidak ada penalti yang dibangun]
- [ASSUMED-BY-RUNNER: OQ-DM-1 status `rescheduling_required` tidak ada di kode v1 -> tambahkan sebagai status baru]
- [ASSUMED-BY-RUNNER: OQ-OV-1 PRD bilang slot 20 menit/reminder 48 jam, kode 15 menit/24 jam -> Defer; kode v1 tidak diubah]
- [ASSUMED-BY-RUNNER: binding CONFLICT C-U011-A08 -> KEEP_CODE; baris yang di-anchor berubah karena U-003 di run yang sama. Keputusan ini hanya memindahkan anchor, tidak mengubah kode, dan bisa dibalik lewat `resolve-oq --binding`]
- [ASSUMED-BY-RUNNER: drift HIGH -> Resolve first; 8 item tetap antre di PENDING-SYNC.md]

## Keputusan yang saya ambil saat build
- **Respons cron:** JSON `/api/cron/reminders` tetap berbentuk v1 persis. Unit meminta tambahan field `offers`, tapi test v1 mengecek bentuk JSON persis. Offer tetap diproses; jumlah dan kegagalannya ditulis ke log.
- **Setting window:** `CANCELLATION_WINDOW_HOURS` dibaca dari env (default 24). Tidak ada halaman setting.
- **Slot tidak ditahan:** slot yang sedang ditawarkan tetap bisa dibooking orang lain. Kalau keduluan, offer batal dan pasien tetap di antrean.
- **Offer kedaluwarsa:** pasien tetap di waitlist dan tidak ditawari slot yang sama lagi.
- **Email pembatalan:** hanya untuk pembatalan karena cuti dokter.
- **Metadata migrasi:** file JSON meta drizzle tidak punya header provenance (JSON tidak bisa diberi komentar).
- **Typecheck:** `npm run typecheck` perlu `npx next typegen` dulu. Ini kondisi lingkungan yang sudah ada sebelumnya, bukan dari perubahan ini.
- **Anchor dari re-bind:** re-bind mengubah nomor baris anchor di file unit, jadi perubahan itu ikut di-commit.
- **Dua test yang saya perbaiki:** urutan antrean di test waitlist tidak stabil karena clock test beku, dan email di data test leave-booking tidak valid. Keduanya kesalahan di test, bukan di kode.
- **Transaksi leave:** atomisitas `recordLeave` hanya dijamin lewat satu transaksi; kasus update yang gagal di tengah tidak di-test.

## Review akhir (satu reviewer independen)
Hasilnya 0 Critical, 2 Important, 8 Minor.
- **Diperbaiki (Important):** join waitlist di tanggal cuti sekarang ditolak (`fix(U-004)`), karena dari tanggal cuti tidak akan pernah ada offer.
- **Diperbaiki (Minor, saya naikkan ke Important):** leave yang diinput siang hari tidak lagi membalik janji pagi yang sudah lewat (`fix(U-009)`). Tanpa ini, pembatalan massal bisa mengirim email "book again" untuk kunjungan yang sudah terjadi.
- **Tidak diperbaiki (Important):** respons cron tanpa field `offers` — alasannya di atas.
- **Minor yang ditunda:**
  - Offer yang masih pending tidak dibatalkan saat leave diinput, jadi pasien yang menerimanya melihat pesan "keduluan orang lain".
  - Halaman reschedule menampilkan judul "Link not valid" di atas pesan window.
  - README belum diperbarui.
  - Ada SVG starter bekas v1 yang tidak dipakai.
  - Race kecil antara hapus entry dan booking.
  - Nilai env window yang tidak valid diam-diam kembali ke 24.
  - Ada 3 warning lint di test.
  - Entry waitlist yang terlanjur ada di tanggal yang kemudian jadi cuti tetap berstatus waiting.

## Open question yang masih menunggu
- ⏸ 3 OQ deferred — OQ-FL-1, OQ-FL-2, OQ-OV-1. Jawab kapan saja lewat `resolve-oq`.
- 4 OQ P2 bisnis masih terbuka — OQ-FL-3..6.
- 6 keputusan teknis diambil AI — review di `.mega-sdd/vaults/clinic-v2/context.md#AI-Technical-Decisions`; override lewat `resolve-oq single-oq <OQ-ID>`.

## Commit (`main`, dari `d7a0f5a`)
- **Plan:** `d7a0f5a plan: clinic-v2 vault (context, constitution, 12 units)`
- **Kode:**
  - `1cf733d feat(U-001)` schema v2 + migrasi 0001
  - `f5e82e4 feat(U-002)` cancellation window, lalu `6dc7673 fix(U-002)` refresh anchor
  - `5da671f feat(U-003)` siklus offer
  - `3ecc44c feat(U-004)` service waitlist, lalu `19fc5b0 fix(U-004)` test, dan `2cda8d3 fix(U-004)` hasil review
  - `bdacf3f feat(U-005)` pemicu cancel + sweep cron
  - `2dde339 feat(U-006)` join waitlist di halaman booking
  - `0be3b5c feat(U-007)` halaman terima offer
  - `f1f92c2 feat(U-008)` halaman waitlist staff + nav/akses
  - `7a5cab2 feat(U-009)` service leave, lalu `cf8f3cd fix(U-009)` hasil review
  - `6ba577e feat(U-010)` leave memblokir booking
  - `ff2103e feat(U-011)` reassign/cancel
  - `479f149 feat(U-012)` halaman leave staff
- **Evidence dan laporan:** commit `chore(sdd): evidence …` per unit dan per run, plus laporan drift gate.

Semua artefak ada di `.mega-sdd/vaults/clinic-v2/`: `context.md`, `constitution.md`, `vault.json`, `units/`, `bolts/U-001..U-012/` (bolt report, acceptance, postflight, binding), `bolts/_batch-suite.json`, `DRIFT-REPORT.md`, `PENDING-SYNC.md`. Saran berikutnya: putuskan 8 item di `PENDING-SYNC.md`, lalu jalankan `/mega-sdd:sync`.

## Questions put to the user

(none)

## Commit messages

chore(sdd): drift gate report after execute-bolts (8 findings queued in PENDING-SYNC)

chore(sdd): evidence run d7a0f5a — final gate recompute

chore(sdd): evidence run d7a0f5a — gate recompute

chore(sdd): evidence U-002 — acceptance at the fix(U-002) commit

chore(sdd): evidence run d7a0f5a

chore(sdd): evidence U-004, U-009 — final-review fixes

fix(U-009): leave never flips appointments that already started

Unit: U-009
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-009
SDD-Acceptance: v5

fix(U-004): refuse joining the waitlist on a doctor's leave date

Unit: U-004
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-004
SDD-Acceptance: v5

chore(sdd): evidence U-012 — acceptance re-run

chore(sdd): evidence U-012 — Add the receptionist leave page

feat(U-012): Add the receptionist leave page — record leave, then reassign or cancel affected appointments

Unit: U-012
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-012
SDD-Acceptance: v5

chore(sdd): evidence U-011 — acceptance re-run

chore(sdd): evidence U-011 — Reassign or cancel appointments affected by leave

feat(U-011): Reassign or cancel appointments affected by leave, one or many, without double-booking

Unit: U-011
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-011
SDD-Acceptance: v5

chore(sdd): evidence U-010 — acceptance re-run

chore(sdd): evidence U-010 — Hide and refuse a doctor's slots on leave dates

feat(U-010): Hide and refuse a doctor's slots on leave dates for booking, reschedule and waitlist offers

Unit: U-010
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-010
SDD-Acceptance: v5

chore(sdd): evidence U-009 — acceptance re-run

chore(sdd): evidence U-009 — Build the doctor-leave service

feat(U-009): Build the doctor-leave service — record leave, flag affected appointments, find free doctors

Unit: U-009
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-009
SDD-Acceptance: v5

chore(sdd): evidence U-008 — acceptance re-run

chore(sdd): evidence U-008 — Add the receptionist waitlist page

feat(U-008): Add the receptionist waitlist page with remove, and the v2 staff routes (waitlist, leave) in nav and access policy

Unit: U-008
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-008
SDD-Acceptance: v5

chore(sdd): evidence U-007 — acceptance re-run

chore(sdd): evidence U-007 — Add the public waitlist-offer page

feat(U-007): Add the public waitlist-offer page where the patient accepts the freed slot once

Unit: U-007
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-007
SDD-Acceptance: v5

chore(sdd): evidence U-006 — acceptance re-run

chore(sdd): evidence U-006 — Let patients join the waitlist from the booking page

feat(U-006): Let patients join the waitlist from the booking page when a date has no free slot

Unit: U-006
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-006
SDD-Acceptance: v5

chore(sdd): evidence U-005 — acceptance re-run

chore(sdd): evidence U-005 — Offer the freed slot when a patient cancels

feat(U-005): Offer the freed slot when a patient cancels, and sweep expired offers in the existing cron

Unit: U-005
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-005
SDD-Acceptance: v5

chore(sdd): evidence U-004 — acceptance re-run

chore(sdd): evidence U-004 — Build the waitlist service

fix(U-004): order waitlist test joins with the test clock (queue ties were random)

Unit: U-004
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-004
SDD-Acceptance: v5

feat(U-004): Build the waitlist service — join with booking validation, list per doctor and date, remove

Unit: U-004
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-004
SDD-Acceptance: v5

chore(sdd): evidence U-003 — acceptance re-run

chore(sdd): evidence U-003 — Build the waitlist offer lifecycle

feat(U-003): Build the waitlist offer lifecycle — offer a freed slot, accept once, expire and pass on

Unit: U-003
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-003
SDD-Acceptance: v5

chore(sdd): evidence U-002 — postflight after unit refresh

fix(U-002): refresh anchor line written by the task re-bind

Unit: U-002
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-002

chore(sdd): evidence U-002 — acceptance re-run

chore(sdd): evidence U-002 — Refuse patient cancel/reschedule links inside the configurable cancellation window

feat(U-002): Refuse patient cancel/reschedule links inside the configurable cancellation window

Unit: U-002
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-002
SDD-Acceptance: v5

chore(sdd): evidence U-001 — acceptance re-run

chore(sdd): evidence U-001 — Add the v2 schema — rescheduling_required status, waitlist and leave tables, migration 0001

feat(U-001): Add the v2 schema — rescheduling_required status, waitlist and leave tables, migration 0001

Unit: U-001
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-001
SDD-Acceptance: v5

plan: clinic-v2 vault (context, constitution, 12 units)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>

## Recorded notes in committed markdown

### .mega-sdd/vaults/clinic-v2/DRIFT-REPORT.md

## Decision violations & decision unwritten (PRIORITY-1)



> These most often correspond to compliance or architectural debt. Review them first.



No **decision violation** was found. Every constitution clause and every resolved OQ decision probed below holds in the code (see Constitution Findings and Confirmed matches).



### DR-04 — Decision unwritten: staff paths may place appointments on an on-leave doctor (confidence: medium)



**Vault** (`context.md ## Flows` F-U-004 DoD 3): "While on leave the doctor's slots in that range do not appear and cannot be booked online, by reschedule, or by accepting a waitlist offer" (PRD §4.2 bullet 2, AC-203).

**Code**:

- `src/server/appointments.ts:151-156` and `:188-194`: `assertNotOnLeave` runs only when `!opts.override`. The comment reads "staff override is unaffected". A receptionist walk-in with `override: true` can book a doctor on a leave date.

- `src/server/staff.ts:105-141`: v1 `reassignAppointment` (unchanged since `015ecf3`) checks for clashes but has **no `isDoctorOnLeave` check**, so a booked appointment can be reassigned *to* a doctor who is on leave that day. By contrast, the v2 `reassignAffected` (`src/server/leave-resolution.ts:47-55`) does exclude on-leave doctors through `findFreeDoctors`.



**Drift**: the vault's leave rule names only the patient paths (online, reschedule, waitlist offer). The code has an implicit decision: staff paths bypass leave, fully for override walk-ins and silently for v1 reassign. No vault decision or OQ records this.

**Suggested action**:

- (A) Promote to a written decision, for example "staff override and v1 reassign are not leave-blocked", in `context.md` (F-U-004 DoD or AI Technical Decisions).

- (B) Fix the code: add the leave check to `reassignAppointment`, and to override bookings if that is intended.

- (C) Defer as `OQ-DC-1`.



### DR-05 — Decision unwritten: a slot freed by a patient reschedule is not offered to the waitlist (confidence: low, verify manually)



**Vault** (`context.md` F-S-001 Trigger): "a `booked` appointment is cancelled (v1 path: patient email link, `cancelWithToken`)". PRD §4.1 says "cancelled (by anyone)".

**Code**: `src/server/appointments.ts:319-326` is the only caller of `offerFreedSlot` on an appointment change. `rescheduleWithToken` (`:335-383`) frees the old slot without offering it. Leave cancellations (`src/server/leave-resolution.ts:104-121`) free slots on a leave date, where no offer is possible, so they are consistent.

**Drift**: code and vault agree on the cancellation trigger. Whether a reschedule-freed slot should reach the waitlist is decided implicitly ("no") and is not written down.

**Suggested action**:

- (A) Record "reschedule does not trigger an offer" in the F-S-001 trigger text.

- (B) Extend the trigger in code.

- (C) Defer as an OQ for the Product Team.



### DR-06 — Missing in vault: leave note length limit (confidence: low)



**Code**: `src/server/leave.ts:27-32`. `leaveSchema.note` is trimmed and limited to `max(500)` with the message "Keep the note under 500 characters."

**Vault**: F-U-004 D1 "Valid? (doctor exists, start <= end)". DBML `doctor_leaves.note text [null]` has no length rule.

**Suggested action**:

- (A) Add "note ≤ 500 chars" to F-U-004 validation.

- (B) Leave it as an implementation detail.



#### DR-08 — Stale line anchors in constitution / AI decision citations (confidence: high)



The v2 bolts added lines above the cited code, so several `source:` anchors now point at the wrong line. The cited symbols still exist and behave as claimed.



| Vault citation | Cited | Now at |

|---|---|---|

| `constitution.md` A-002 (`Ctx`) | `src/server/appointments.ts:21` | `src/server/appointments.ts:27` |

| `constitution.md` C-001 (`appointments_doctor_slot_booked_uq`) | `src/db/schema.ts:144` | `src/db/schema.ts:154` |

| `constitution.md` C-001 (`isUniqueViolation`) | `src/server/errors.ts:23` | `src/server/errors.ts:26` |

| `constitution.md` C-002 (email failure never undoes) | `src/server/appointments.ts:100` | `src/server/appointments.ts:108-131` |

| `context.md` AI Technical Decisions OQ-AR-1 (`CLINIC_TIMEZONE` pattern) | `src/lib/clinic-config.ts:30` | `src/lib/clinic-config.ts:32` |

| `context.md` Schema constraints (`appointments_doctor_slot_booked_uq`) | `src/db/schema.ts:144` | `src/db/schema.ts:154` |



`context.md` OQ-DM-1 cites `src/db/schema.ts:94` and OQ-OV-1 cites `clinic-config.ts:6/:13`. Those are v1-baseline evidence at plan time, so they are historical and not flagged.



**Suggested action**: (A) refresh the anchors.



> **Caveat**: editing `constitution.md` changes its sha256. That trips `constitution_drift_detected` on the next drift run unless `constitution_hash` is re-pinned. For the constitution rows, consider switching to symbol anchors instead of line numbers.



## Notes & caveats



- Detection is heuristic (grep and read, no AST). Low-confidence findings can be false positives.

- There are no ADRs in this vault. The decision axis used the constitution clauses and the AI Technical Decisions table.

- Vault-internal inconsistency (not code drift): the TL;DR says "3 tables touched", but the Data model DBML lists 4 (`appointments` plus 3 new tables), and the code touches 4.

- The code references `OQ-CLINIC-001` (`src/server/email/templates.tsx:9`) and `OQ-CLINIC-005` (`scripts/reminder-worker.ts:4`). These are v1 OQ codes that do not exist in the clinic-v2 vault and are informational only.

- Changelog: a layout-3 vault keeps its changelog only in `vault.json` (the `derive-vault-json.sh --event` lane). Because no write-back was applied, this drift-only session leaves `vault.json` untouched, as the rule requires. This report is the session record.

- If the framework was mis-detected, re-run with `--scope=<dirs>`.

### .mega-sdd/vaults/clinic-v2/PENDING-SYNC.md

## Decision unwritten



### DR-06 — Leave note ≤ 500 chars (low)

- **Code**: `src/server/leave.ts:27-32`.

- **Options**:

  - UPDATE_VAULT: add it to F-U-004 validation.

  - Or ignore it as an implementation detail.



### .mega-sdd/vaults/clinic-v2/context.md

## Open Questions



- [ ] **OQ-FL-1** [P1] [business] [conf: high] [origin: context.md#F-S-001]: PRD §4.1 says "VIP patients skip the waitlist queue and are offered freed slots first", but patients have no accounts and nothing in v1 or v2 says who is a VIP or how the clinic marks one. Who counts as VIP, and who sets it? Until answered, the queue is strictly first-come, first-offered. **Deferred (plan)**: headless run — deferred by the runner (conservative), queue stays FIFO until the Product Team defines VIP — resolve: Product Team

- [ ] **OQ-FL-2** [P1] [business] [conf: high] [origin: context.md#F-U-006]: PRD §4.3 says "Late cancellations are penalised" but names no penalty, and payments are out of scope (PRD §6). What is the penalty and how is it applied? Until answered, nothing is built beyond refusing the change inside the window. **Deferred (plan)**: headless run — deferred by the runner (conservative), no penalty built until defined — resolve: Product Team

- [x] **OQ-DM-1** [P1] [business] [conf: high] [origin: context.md#Data-model]: PRD §1 and §4.2 call `rescheduling_required` "the existing status", but the v1 code only knows `booked | cancelled | completed` (`src/db/schema.ts:94`, `drizzle/0000_init.sql:1`). Should v2 add `rescheduling_required` as a new status (as the PRD describes it), or is another existing mechanism meant? → **Resolved v1.0** (plan, 2026-09-28): add `rescheduling_required` as a new appointment status, as PRD §4.2 describes it (runner-assumed answer in a headless run — option [1], keep the PRD/vault claim)

- [ ] **OQ-OV-1** [P1] [business] [conf: high] [covers: PRD/prd-clinic-v2.md#1-context]: PRD §1 describes v1 as 20-minute slots and a reminder 48 hours before, but the live code uses 15-minute slots (`src/lib/clinic-config.ts:6`) and a 24-hour reminder (`src/lib/clinic-config.ts:13`). v2 asks for no change here. Which is authoritative — the PRD text or the running system? Until answered, nothing about slots or reminders changes. **Deferred (plan)**: headless run — deferred by the runner (conservative), slot length and reminder lead time stay as the running v1 code — resolve: Product Team

- [ ] **OQ-FL-3** [P2] [business] [conf: high] [origin: context.md#F-U-006]: PRD §4.3 says "Staff can still cancel or reschedule at any time from the portal", but the v1 portal has no general staff cancel/reschedule (only reassign and walk-in booking, `src/server/staff.ts:104`). Should v2 add general staff cancel/reschedule? Until answered, only the leave-resolution actions (F-U-005) exist, and they ignore the window. — resolve: Product Team

- [ ] **OQ-FL-4** [P2] [business] [conf: high] [origin: context.md#F-U-005]: PRD §4.2 refers to "the cancellation email with a link to book again", but v1 sends no email on cancellation (`src/server/email/mailer.ts:4`). v2 adds that email for leave cancellations; should patients who cancel themselves also receive it? Until answered, only leave cancellations send it. — resolve: Product Team

- [ ] **OQ-FL-5** [P2] [business] [conf: high] [origin: context.md#F-U-002]: While an offer is pending, is the freed slot held for the offered patient, or can anyone book it online? The PRD states no hold. Until answered, the slot is not held; if it is booked first, the offer becomes void and the patient stays on the waitlist. — resolve: Product Team

- [ ] **OQ-FL-6** [P2] [business] [conf: high] [origin: context.md#F-S-002]: When an offer expires, does the patient stay on the waitlist for later freed slots, or leave it? PRD §4.1 names only acceptance and receptionist removal as exits. Until answered, the patient stays on the waitlist (not re-offered the same slot). — resolve: Product Team

- [x] **OQ-AR-1** [P2] [tech / recommend] [conf: medium] [origin: context.md#F-U-006]: where does the cancellation-window setting live? → **Resolved v1.0** (AI decision, 2026-09-28): env var `CANCELLATION_WINDOW_HOURS` (default 24) read by a `cancellationWindowHours()` helper in `src/lib/clinic-config.ts`, like `CLINIC_TIMEZONE`

- [x] **OQ-AR-2** [P2] [tech / recommend] [conf: medium] [origin: context.md#F-S-002]: what runs the 30-minute offer expiry? → **Resolved v1.0** (AI decision, 2026-09-28): the existing 5-minute cron sweep (`/api/cron/reminders` + `scripts/reminder-worker.ts`) also runs `sweepExpiredOffers`; acceptance re-checks `expires_at` itself

- [x] **OQ-AR-3** [P2] [tech / recommend] [conf: medium] [origin: context.md#F-U-002]: how are offer links signed? → **Resolved v1.0** (AI decision, 2026-09-28): the v1 HMAC token scheme in `src/lib/tokens.ts` with a distinct payload kind for offers (offer id + nonce), nonce rotated on use

- [x] **OQ-DM-2** [P2] [tech / scan] [conf: high] [origin: context.md#Data-model]: how is the schema change shipped? → **Resolved v1.0** (AI decision, 2026-09-28): a drizzle-kit migration `drizzle/0001_v2_waitlist_leave.sql` generated from `src/db/schema.ts` (`npm run db:generate -- --name=v2_waitlist_leave`), applied by the existing migrator

- [x] **OQ-AR-5** [P3] [tech / recommend] [conf: medium] [origin: context.md#Data-model]: which service does an accepted offer book? → **Resolved v1.0** (AI decision, 2026-09-28): the service the patient already chose in the booking wizard, stored on the waitlist entry

- [x] **OQ-AR-6** [P3] [tech / recommend] [conf: medium] [origin: context.md#Data-model]: how are repeated joins by one patient handled? → **Resolved v1.0** (AI decision, 2026-09-28): one active entry per doctor + date + email (partial unique index); a repeat join returns the existing entry instead of a duplicate



## AI Technical Decisions



> 6 technical decisions taken by the AI — override any time: `resolve-oq single-oq <OQ-ID>`.



| OQ-ID | Decision | Basis (citation) | If wrong |

|---|---|---|---|

| OQ-AR-1 [P2] | `CANCELLATION_WINDOW_HOURS` env, default 24 | codebase — `src/lib/clinic-config.ts:30` (`CLINIC_TIMEZONE` env pattern); PRD §4.3 | move the value to a DB settings row with a staff form |

| OQ-AR-2 [P2] | offer expiry in the existing cron sweep | codebase — `src/app/api/cron/reminders/route.ts:18`, `scripts/reminder-worker.ts:21` | add a dedicated cron route |

| OQ-AR-3 [P2] | reuse the HMAC one-time token scheme | codebase — `src/lib/tokens.ts:3` | separate secret / signed JWT |

| OQ-DM-2 [P2] | drizzle-kit migration 0001 | codebase — `package.json` `db:generate`, `drizzle.config.ts:3` | hand-written SQL migration |

| OQ-AR-5 [P3] | store the wizard's service on the entry | codebase — `src/lib/validation.ts:20` (`bookingSchema.service`); PRD §4.1 | ask the service on the offer page |

| OQ-AR-6 [P3] | one active entry per doctor + date + email | codebase — `src/db/schema.ts:144` (partial unique pattern) | allow duplicates, dedupe in the staff list |



### .mega-sdd/vaults/clinic-v2/units/U-001.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: every v1 table, column, enum value and index; `appointments_doctor_slot_booked_uq` stays `WHERE status = 'booked'`

- **ADD**: enum value `rescheduling_required`; enums `waitlist_status`, `waitlist_offer_status`; tables `waitlist_entries`, `waitlist_offers`, `doctor_leaves`; migration 0001; badge entry



### .mega-sdd/vaults/clinic-v2/units/U-002.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: `TOO_LATE` for started appointments, one-time token checks, all staff paths

- **ADD**: `cancellationWindowHours()`, `CANCELLATION_WINDOW` error code, window check in `loadTokenAppointment`, cancel-page message



### .mega-sdd/vaults/clinic-v2/units/U-003.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: `createAppointmentToken` / `verifyAppointmentToken` behaviour for appointment tokens; the four v1 email kinds and their copy

- **ADD**: `createOfferToken` / `verifyOfferToken`; `waitlist_offer` email kind + `waitlistOfferEmail`; new module `src/server/waitlist-offers.ts`



### .mega-sdd/vaults/clinic-v2/units/U-004.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: `patientDetailsSchema`, `bookingSchema`, `staffBookingSchema`, `loginSchema` unchanged

- **ADD**: `waitlistJoinSchema`; new module `src/server/waitlist.ts`



### .mega-sdd/vaults/clinic-v2/units/U-005.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: cancellation semantics, one-time token, reminder sweep, route auth

- **ADD**: post-commit `offerFreedSlot` call; `sweepExpiredOffers` in the cron handler; `offers` key in its JSON



### .mega-sdd/vaults/clinic-v2/units/U-006.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: every v1 wizard step, validation message and the existing wizard tests

- **ADD**: `joinWaitlist` prop, empty-slots panel, `joinWaitlistAction`, `WaitlistResult`



### .mega-sdd/vaults/clinic-v2/units/U-008.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: existing routes, nav entries and role rules

- **ADD**: `/staff/waitlist` + `/staff/leave` rules and nav links, waitlist page, actions, table



### .mega-sdd/vaults/clinic-v2/units/U-010.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: every v1 rule in these functions, the window check from U-002, the offer hook from U-005

- **ADD**: leave checks in `getAvailableSlots`, `createAppointment` (non-override), `rescheduleWithToken`



### .mega-sdd/vaults/clinic-v2/units/U-011.md

## Migration notes



- **REMOVE**: nothing

- **KEEP**: the v1 email kinds, their copy and `appointmentEmail`

- **ADD**: `cancelled` email kind + `leaveCancellationEmail`; new module `src/server/leave-resolution.ts`



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

.mega-sdd/vaults/clinic-v2/bolts/U-011/binding.json: "CONFLICT": 1,

.mega-sdd/vaults/clinic-v2/bolts/U-011/binding.json: "verdict": "CONFLICT",

.mega-sdd/vaults/clinic-v2/bolts/U-012/binding.json: "CONFLICT": 0,