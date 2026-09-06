# Morning proposals — keputusan yang butuh call lo (2026-08-11)

**Status:** DECISION DOC — sebagian sudah terselesaikan lewat spec lain (stempel per item di bawah, dicatat 7.29.1); sisanya masih menunggu call lo. Companion dari spec `2026-08-11-audit-phase4-platform-hygiene.md` (yang HANYA ship item hygiene otonom: honest labeling, AUDIT.md archive, parity harness p12).
**Sumber:** audit `docs/superpowers/audits/2026-08-10-skills-audit.md` (rekomendasi #9, P3/P4) + amendemen moat-takeout lo 2026-08-10 ("klo moat tidak efisien bisa di takeout") + record 2b §S7 (zero cuts — semua kandidat gagal evidence bar-nya sendiri, T2 di-eskalasi ke doc ini).
**Cara baca:** tiap item = Problem / Options / Numbers / Recommendation / What-I-did-NOT-do-and-why. Semua angka estimasi ~4 bytes/token kecuali ditandai measured.

---

## (a) `build-dispatch-prompt.sh` 194KB → ekstraksi `_lib/` python

**Problem.** Satu file bash 194KB / 3,713 baris (12.5% dari seluruh payload scripts) dengan Python heredocs — unlintable, unimportable, untestable per-fungsi. Token cost = NOL (script dieksekusi, never read) — ini murni maintenance risk terbesar di plugin (audit §9), bukan context problem.

**Options.**
1. **Ekstraksi ke `scripts/_lib/dispatch_*.py`** — bash tinggal thin CLI wrapper; logika pindah ke modul python yang bisa di-import + di-unit-test. Precedent SUDAH ADA dan terbukti: `_lib/postflight_rules.py` (B1 recompute v4.62.0 — shared engine, writer dan gate byte-identical by construction).
2. **Opportunistic-only** (guidance audit, P3/P4): jangan big-bang; ekstrak modul HANYA saat sebuah bagian memang mau diedit, dengan parity test per ekstraksi.
3. Biarkan as-is.

**Numbers.** 194,000 bytes ≈ 3,713 baris; 0 tok/run (tidak pernah masuk context); risk event nyata di kelas ini: 6.1.1 (template stamped the poison — defect lolos karena surface tidak ter-CI). Proof harness yang dibutuhkan: golden-output parity test (input dispatch sama → byte-identical prompt sebelum vs sesudah ekstraksi) — pola yang sama dengan emission-parity + p12.

**Recommendation.** Option 2 (opportunistic, spec-first per house policy) dengan parity harness dibangun DULU sebelum ekstraksi pertama. Jangan big-bang rewrite — file ini di jalur moat (bolt dispatch), dan zero-token berarti tidak ada upside context sama sekali; upside-nya murni maintainability.

**What I did NOT do & why.** Tidak menyentuh file, tidak bikin harness-nya. Behavior-adjacent + moat-adjacent → wajib spec + adversarial round sendiri; bukan kelas "autonomous-safe overnight".

---

## (b) Free-text delta lane (`generate-intent --amend` / diff-vault chat input)

**RESOLVED — SHIPPED 6.7.0** (delta lane: chat ticket → `diff-vault --from-prompt` → claim-scoped re-bind → reconcile; CHANGELOG 6.7.0, spec 2026-08-12 delta-lane).

**Problem.** Requirement bentuk tiket ("tambah kolom X di form Y") — persis user base plugin ini (tim bank) — tidak punya jalur murah: lane free-text sekarang re-pay full vault generation + full bind. Sim S4 (audit §13): **~230k tok** untuk delta 3 field. Padahal SEMUA machinery downstream sudah ada: diff-vault structured diff, scoped patch, `--paths` claim-scoped re-bind, sync-intersect. Yang hilang HANYA entry adapter-nya (chat-level requirement → scoped diff input).

**Options.**
1. `generate-intent --amend "<teks>"` — free-text kecil diperlakukan sebagai PRD-delta terhadap vault existing → diff-vault lane → scoped patch → `--paths` bind.
2. diff-vault menerima chat input langsung (tanpa lewat generate-intent).
3. Tidak dibangun (status quo): tiket kecil tetap bayar full lane, ATAU tim menyiasati di luar pipeline (adaptasi terburuk — audit §14.2).

**Numbers.** ~230k → **~60–80k tok** per ticket-shaped change (audit S4, est.); frekuensi use case = tinggi (ini workflow harian tim); machinery baru yang harus ditulis = kecil (adapter + OQ-scoped Q&A cap sized-to-delta).

**Recommendation.** Bangun — tapi lewat gerbang **no-gimmick** yang lo mandatkan: spec sendiri yang menjustifikasi kenapa ini reuse (bukan surface baru — dia menyambungkan dua lane yang sudah ada), plus guard supaya delta besar tetap dipaksa ke full lane (anti-abuse: "amend" 40-requirement bukan delta). Ini item dengan ROI velocity terbesar di seluruh backlog audit.

**What I did NOT do & why.** Zero implementasi — audit #9 sendiri menandai "needs its own spec + no-gimmick justification"; entry surface baru = keputusan produk lo, bukan hygiene.

---

## (c) Moat-takeout candidates — dengan angka (per amendemen 2026-08-10 + record 2b §S7 zero-cut)

Konteks: di 2b, tiga kandidat takeout GAGAL evidence bar-nya sendiri (T1/T3 dropped, T2 naik ke sini). Prinsip yang kepegang: gate dengan defect-catch record = proposal-first, never cut overnight.

### c1 — T2: parallel-batch re-scan (`batch-and-fanout.md:77`)
- **Problem.** Di bawah `--parallel`/`--per-squad`, controller re-invoke validator quality project-wide setelah TIAP batch. Ref-nya sendiri mengaku "defense-in-depth, not a fix for an invisible write" (PostToolUse sudah fire di subagent writes — AUDIT L1).
- **Numbers.** Hemat jika dicut: ~6–7 validator spawns × N batch per run (flow-coverage, sibling-consistency, unit-spec, ui-quality, cross-cutting, dst.) — material di fleet Windows/CrowdStrike (~220ms/spawn, measured), kecil di macOS. Token: 0 (script plane).
- **Rasional penahan:** "the explicit re-scan makes the gate state deterministic regardless of concurrent write ordering" — plausibly load-bearing untuk keputusan halt ANTAR-batch di bawah async PostToolUse interleaving.
- **RESOLVED 2026-08-17 — KEEP** (`research/2026-08-17-c1-batch-rescan-trace.md`): trace done. Cut condition technically met (EB-GATE-1 re-derives at the next gate fire) TAPI angka aslinya salah dua arah — spawn cost cuma 2–3/batch (bukan 6–7), dan menghapus early mid-run halt mempertaruhkan wave sia-sia (10⁴–10⁵ tok) demi ~0.7s/batch. Trade terbalik ~3 orde. Jangan buka lagi tanpa telemetry lapangan.

### c2 — Advisor default-on (opus) per bind
- **Problem.** Step 2.12 bind menjalankan `phase-advisor` (model: **opus**, read-only, default-on; `--no-advisor` opt-out) di TIAP bind — pass adversarial paling mahal per-run di pipeline.
- **Numbers.** Cost per bind: 1 dispatch opus atas advisor-bundle + anchor reads + Grep full codebase-map — est. belasan–puluhan k input tok opus per bind (bundle sengaja seed-kecil; horizon-nya on-disk). Catch record: kelasnya = false-CONFIRMED / missed_match → jadi CONFLICT fail-safe (menutup gate); advisor sengaja DIPERTAHANKAN di v6 P3 (lean-default diagnostics — advisor KEPT) karena ini satu-satunya lapisan yang menangkap "binding yang terlihat benar".
- **Recommendation.** Keep default-on. Opsi hemat yang layak diukur dulu: (1) telemetry findings-per-bind — kalau berbulan-bulan 0 findings HIGH, turunkan ke default-on hanya untuk lane KB/legacy + binding ber-CONFLICT; (2) model tier turun ke sonnet — TAPI kualitas deteksi false-CONFIRMED adalah alasan hidupnya, jadi butuh A/B, bukan asumsi.

### c3 — B1 recompute cadence (recompute-at-gate)
- **Problem (framing efisiensi).** Gate execute-bolts me-RECOMPUTE postflight B1 dari git/fs ground truth tiap fire (via `_lib/postflight_rules.py`), bukan percaya artifact.
- **Numbers.** Cost: ~1 python spawn + git/fs reads per gate fire, scaling dengan jumlah bolt ber-Hard-rule yang sudah commit; token 0. Record: desain ini persis lahir karena **forged artifact** bisa londerin pelanggaran DO_NOT_MODIFY/SIGNATURE lewat B1 — recompute menimpanya (v4.62.0).
- **Recommendation.** **KEEP — bukan kandidat.** Lo sendiri sudah pin "recompute-at-gate = moat, JANGAN dioptimasi". Ditampilkan di sini hanya supaya amendemen "with numbers" lengkap dan on the record; angka-nya pun kecil (satu spawn, bukan suite).

---

## (d) Halt-protocol family split

**RESOLVED — SHIPPED 6.14.0** (registry split by family AFTER the measurement gate this item required; CHANGELOG 6.14.0, spec 2026-08-17-halt-registry-family-split.md).

**Problem.** Sebuah halt memuat registry 43.6KB (~11k tok) untuk mengambil SATU envelope YAML (audit §14.5).

**Numbers.** ~11k tok per halt-yang-memuat-registry; tapi ini exceptional path — amortized cost per run TIDAK diketahui (berapa halt per run yang benar-benar buka file itu? `ref_loaded` telemetry ada tapi honest under-count).

**Recommendation.** Jangan split dulu. Prasyaratnya persis yang audit tulis: **halt-path telemetry dulu** (hitung berapa kali registry ke-load per N run nyata). Split 44KB → per-family files itu operasi berisiko-pointer tinggi (35+ pointer citations) demi saving yang belum terukur frekuensinya. Instrument → ukur → baru potong.

**What I did NOT do & why.** No file split, no instrumentation baru — instrumentation halt-path sendiri adalah perubahan hook surface (bukan autonomous-safe).

---

## (e) Roster item deferred yang masih hidup (biar tidak hilang dari radar)

| Item | Status + prasyarat buka |
|---|---|
| vault-contract physical reorder | Deferred (P3): cross-skill SSOT blast radius; §-named reads (6.3.0) sudah mengambil sebagian besar win — reorder fisik hanya kalau ada bukti §-reads gagal di lapangan |
| Wave-5 synthesis diet (extract) | Machinery sudah shipped (frontmatter counts + §summaries + glossary spot-reads); butuh SATU extraction run nyata untuk verifikasi sebelum jadi default. **→ VOID 7.6.0**: waves/KB-tree pensiun (extract revamp = census → PRD-kontrak per modul) |
| os-detection / install-deps demoted-block deletion | Banner keep-in-sync shipped 6.4.0 (additive demotion); hapus blok prose hanya setelah satu field run membuktikan jalur script bertahan |
| scan/bind `context: fork` flip | Fork-READY sejak v5.15.0, TIDAK di-flip; prasyarat tetap 2 run interaktif: RUN 1 (sync dari subdir) + RUN 2 (depth-2 Agent probe — advisor Step 2.12 bergantung ini); ingat: headless `claude -p` fork NO-OPS, A/B harus interaktif |

**Recommendation.** Tidak ada yang urgent; semuanya menunggu bukti lapangan yang spesifik, bukan effort. Yang paling dekat unlock: os-detection deletion (cukup satu field run sehat).

---

*Constraint yang dihormati: zero implementasi di doc ini; setiap rekomendasi memisahkan angka (measured vs est.) dari klaim; kandidat ber-defect-catch-record tidak pernah diusulkan dipotong tanpa trace/telemetry — sesuai amendemen lo + record 2b §S7.*
