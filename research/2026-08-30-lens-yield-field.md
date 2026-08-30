# Yield per lensa review — pengukuran lapangan HOST-AS400 / dd9000-gate

**Tanggal**: 2026-08-30
**Sumber**: vault `HOST-AS400/.mega-sdd/vaults/dd9000-gate` @ HEAD `df6f87f` (36 unit, 117 commit), dibaca read-only. Klaim awal per lensa dari satu pembaca, lalu **dua refuter adversarial per lensa** (sudut over-count + sudut under-count) dengan anchor file:line / commit hash. Angka di dokumen ini = hasil koreksi refuter, bukan klaim awal.
**Status**: RESEARCH — tanpa keputusan. Owner yang memutuskan. Setiap angka ber-anchor atau berlabel ESTIMATE / UNVERIFIED.
**Dokumen kakak**: `2026-08-29-panel-cost-field-measurement.md` (biaya ~267k/panel 4 lensa) dan `2026-08-30-field-audit-triage.md` (F-07/F-08/F-26 → jejak panel dan ledger).

`$V` di bawah = `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/HOST-AS400/.mega-sdd/vaults/dd9000-gate`.

## 0. Ringkasan satu paragraf

Klaim awal menghitung **158 baris temuan lensa**; setelah dedup dan atribusi ulang oleh refuter tersisa **64–65 temuan lensa distinct** (9 Critical, 29–30 Important, 26 Minor), **42–43 di antaranya tertutup oleh commit yang bisa ditunjuk**. Inflasi klaim berasal dari tiga cacat metode: baris yang sama dihitung 2–3× (ledger + bolt-report + commit anchor), verdict "bersih/PASS" dihitung sebagai temuan minor, dan temuan lensa lain dikreditkan ke lensa yang salah (paling parah: verifier 13 → 1). Yield nyata terkonsentrasi di **quality** (38 temuan, 5 Critical) dan **security** (14, 3 Critical); **spec** menghasilkan satu Critical yang melahirkan unit baru (U-035) dan sisanya minor; **standards** nol Critical; **verifier** satu Important yang justru regresi lahir dari fix; **design** tidak pernah ter-dispatch (jejak nol). Hanya lensa dengan nol Critical/Important yang boleh jadi kandidat pangkas — satu-satunya yang memenuhi syarat itu (design) tidak bisa diputus karena buktinya ketiadaan jejak, bukan ketiadaan peristiwa.

## 1. Sumber & batas

### 1.1 Yang terbaca

| Sumber | Isi | Catatan |
|---|---|---|
| 3 ledger `findings.json` | `$V/bolts/U-001/findings.json` (13 temuan F-001..F-013 + delta review), `$V/bolts/U-002/findings.json` (E-001..E-008), `$V/bolts/U-019/findings.json` (G-001..G-003) | Satu-satunya ledger di seluruh tree dan seluruh git history (`git log --all --diff-filter=A -- '*findings.json'` → hanya 4d44c16, f6cee44). Ditulis tangan controller, bukan oleh `merge-panel-findings.sh` (triage F-08). Tidak ada field `tier`. |
| Catatan panel sprint 5 | `$V/bolts/_panel/sprint-5-notes.md` (267 baris; U-014, U-015, U-016, U-017) | Header :5 sendiri bilang "BUKAN findings.json". Satu-satunya jejak panel untuk 4 unit itu. Commit bb04ca3, cff47bd, fed9dff. |
| 36 `bolt-report.md` + 36 `postflight.json` | `$V/bolts/U-0xx/` | Attestation `postflight.json:12` ditulis `run-postflight-scan.sh`; teks bebas controller, bukan output lensa. |
| `HANDOFF.md`, `units/`, `lens-inputs/` | Kebijakan panel (`HANDOFF.md:25`: panel penuh hanya risk high/critical, sisanya spec+security), tier agregat sprint 5 (`HANDOFF.md:85`: "2 standard/sonnet + 2 full/opus" tanpa menyebut unit mana), `lens-inputs/U-0xx/design-slice.md` (input, bukan verdict) | |
| 117 commit | `rtk proxy git log` (HEAD == `--all`) | Body commit dipakai sebagai sumber atribusi yang otoritatif saat berbeda dengan dokumen lain (contoh: `AUDIT-PIPELINE.md` D-06 mengkredit 4d44c16 ke U-013/U-021; body commit bilang "Ditemukan spec-reviewer U-001"). |
| `HOST-AS400/.mega-sdd/AUDIT-PIPELINE.md` | Audit sesi lain (untracked) — F-07 (:181-184: jejak panel ≤17/36 unit), F-15 (:285-290: design-reviewer nihil terpakai), :553 (verifier menangkap regresi 4xx→500) | Dipakai sebagai korroborasi, bukan sumber primer. |

### 1.2 Yang TIDAK terbaca — batas keras

- **Transkrip sesi tidak tersedia** (`AUDIT-PIPELINE.md:595`). Semua "lensa X tidak jalan di unit Y" di dokumen ini berarti **tidak ada jejak**, bukan bukti peristiwa tidak terjadi. Sebaliknya "lensa X jalan" hanya diklaim kalau ada output lensa (ledger/notes) atau attestation yang menyebutnya.
- **Tier per dispatch tidak terekam** di artefak manapun (ledger tanpa field tier; sprint 5 hanya agregat). Korelasi tier ↔ yield **tidak bisa dihitung** dari run ini.
- **Token per dispatch tidak terekam** (triage F-26). Semua angka biaya di §3 = ESTIMATE dari satu angka terukur operator.
- **Re-dispatch per ronde tidak terverifikasi**: U-001 `round=2`, U-002 `round=5`, U-019 `round=2`. Apakah lensa dipanggil ulang tiap ronde tidak tercatat; hitungan dispatch di §2 = **batas bawah** (satu dispatch per lensa per unit yang berjejak).
- Sprint 5 mencatat "13 lensa" (`sprint-5-notes.md:4`, fed9dff "12 dari 13 lensa kembali"). Daftar lensa per unit di notes menjumlah 14 (U-014: 4, U-015: 3, U-016: 3, U-017: 4). Satu lensa di daftar itu berarti tidak pernah ter-dispatch; kandidat paling mungkin = **security U-014** (notes:33 "PENDING", tidak ada output file, hanya attestation `U-014/postflight.json:12` "security bersih"). UNVERIFIED — dicatat di tabel sebagai "attestation saja".

### 1.3 Dispatch per unit yang berjejak

| Unit | Lensa berjejak | Tier | Anchor |
|---|---|---|---|
| U-001 | spec, security, quality, standards + resolution-verifier (delta review) | UNVERIFIED (`HANDOFF.md:78` "tier full 30/30" untuk vault — pemetaan ke U-001 tidak eksplisit) | `findings.json:5-10` (lenses_reported), `:158` (verified_by), `postflight.json:12` "4 lensa buta, resolution-verifier, 13/13" |
| U-002 | spec, security + resolution-verifier + controller | UNVERIFIED | `findings.json:5-8`, `:102`; round 5 |
| U-019 | spec, security | UNVERIFIED | `findings.json:5-8`; round 2 |
| U-014 | spec (PASS), standards (PASS), quality, security (attestation saja) | UNVERIFIED (`HANDOFF.md:85` agregat) | `sprint-5-notes.md:17-33`, `U-014/postflight.json:12` |
| U-015 | standards (bersih), quality, spec (**dispatched, kena turn limit, tidak pernah kembali**) | UNVERIFIED | `sprint-5-notes.md:4,143,232,236,255,261`; `U-015/postflight.json:12` tidak menyebut verdict spec |
| U-016 | spec (FAIL), quality, standards; tidak ada security | UNVERIFIED | `sprint-5-notes.md:85,188,221,233,262` |
| U-017 | spec (PASS), security, quality, standards | UNVERIFIED | `sprint-5-notes.md:35-41,70-127,234,263` |
| U-003..U-013, U-020..U-035 (kecuali di atas) | controller review (attestation) + implementer self-report; **tidak ada jejak panel** | none | `postflight.json:12` masing-masing; `AUDIT-PIPELINE.md:184` |
| U-011, U-018, U-034 | halt (bukan lensa) | n/a | bc221b8 (U-018), 84dc6cf (U-034), `U-011/bolt-report.md:288-321` |
| U-019..U-030 (UI) | `lens-inputs/<U>/design-slice.md` ada (input); output design-reviewer **nol** di seluruh tree | none | `AUDIT-PIPELINE.md:285-290` F-15; `U-001/dispatch-prompt.md:241` (non-UI: "no design lens is dispatched") |

Total dispatch lensa berjejak (batas bawah): **spec 7, quality 5, security 4 (+1 attestation-only), standards 5, design 0, verifier 2 = 23–24.**

## 2. Tabel per lensa — klaim vs koreksi

### 2.1 Ikhtisar koreksi

Kedua refuter sepakat pada setiap lensa kecuali satu item standards yang dikontestasi (dijelaskan di §2.5). Kolom "Klaim" = klaim awal (baris mentah); kolom "Koreksi" = hasil refuter.

| Lensa | Klaim total (C/I/m) | Klaim fixed | Koreksi total (C/I/m) | Koreksi fixed | Faktor inflasi | Penyebab utama inflasi |
|---|---|---|---|---|---|---|
| spec | 20 (3/3/14) | 13 | **7 (1/2/4)** | **5** (4 bila new-unit ≠ fixed) | 2,9× | 13 baris duplikat; 3 verdict PASS/"belum kembali" dihitung minor; 1 temuan quality (before:null, 8382210) salah kredit |
| quality | 69 (16/36/17) | 50 | **38 (5/18/15)** | **22** | 1,8× | U-001 ditulis 3×; U-015 before:null 3×; klaim 69 bahkan tidak cocok dengan 60 baris pendukungnya sendiri (9 baris tanpa sumber) |
| security | 42 (9/17/16) | 35 | **14 (3/6/5)** | **12** | 3,0× | 11 entri ledger ditulis 3× (ledger + bolt-report + commit); 2 attestation bersih dihitung minor |
| standards | 14 (2/7/5) | 9 | **4–5 (0/2–3/2)** | **2–3** | ~3× | 2 Critical + 1 Important milik quality (heading `sprint-5-notes.md:188` vs `:221`); F-008 ditulis 3×; 3 verdict bersih dihitung minor |
| design | 0 | 0 | **0** | **0** | — | Tidak ter-dispatch; klaim benar |
| verifier | 13 (2/8/3) | 12 | **1 (0/1/0)** | **1** | 13× | E-006 ditulis 3×; E-003 (security), E-007 (controller), 4 item U-016 (quality), U-033 (self-report+quality), U-022/U-029 (reviewer tak bernama) semua salah kredit; delta review "0 new findings" dihitung minor |
| **Total** | **158** | **119** | **64–65 (9/29–30/26)** | **42–43** | 2,4× | |

Catatan lintas lensa (tidak di-dedup di tabel — tiap lensa dihitung yield-nya sendiri): satu defect bisa muncul di beberapa lensa. Yang teridentifikasi: `deactivate` unreachable U-016 (spec I `:95`, quality I `:206`, standards m `:227` → 1 defect, 3 baris); callerContext duplikat U-017 (quality I `:76`, standards I `:43` kontestasi → 1 defect); harness HTTP duplikat (quality U-014/U-015/U-016/U-017 → satu tema, 4 unit). Jumlah **defect** distinct karena itu < 64.

### 2.2 spec — 7 dispatch, 7 temuan, 5 fixed

| # | Unit | Sev | Temuan | Anchor | Outcome | Commit |
|---|---|---|---|---|---|---|
| 1 | U-016 | **Critical** | Alur level-nasabah hilang (BR-CIF-17 / langkah 7); permukaan tidak ada di openapi.yaml | `sprint-5-notes.md:86-92` | new-unit → U-035 | 9d2d288 (spec: "Lensa spec U-016 menandainya Critical"), 771d1c1 (feat U-035) |
| 2 | U-016 | Important (notes: MAJOR) | Validasi kedua MSG.CODE no-op di produksi (registry permisif default) | `:93-94` | fixed | d022f0b (`-permissiveMessageCodeRegistry`, `+MessageCodeRegistryUnconfiguredError`) |
| 3 | U-016 | Important (MAJOR) | `deactivate` unreachable dari route | `:95` | fixed | d022f0b (+ follow-on 61473a0) |
| 4 | U-016 | Minor | Display-only mode (BR-CIF-26) absen di backend | `:96` | recorded-only | — (`U-016/bolt-report.md:143-152` mendorong ke U-028; tidak ada commit menyebutnya) |
| 5 | U-001 | Minor | F-011 prosa "sepuluh domain" vs enum 11 nilai; vault sendiri tidak konsisten | `U-001/findings.json:124-133` | fixed | c7d2bbd (kontrak) + 4d44c16 (vault; body "Ditemukan spec-reviewer U-001") |
| 6 | U-002 | Minor | E-005 penanda mount route setelah `export const app` | `U-002/findings.json:56-65` status `deferred_to_U-018` | deferred | 5dbc87a hanya menambah catatan di `units/U-018.md` (`@@ -39,8 +39,9`); 13d5bc9 = feature U-018, bukan fix temuan |
| 7 | U-019 | Minor (ledger: low) | G-003 `target_files` tidak memuat `generated/schema.ts` + `bun.lock` | `U-019/findings.json:35-44` | fixed (spec-only) | 5dbc87a (`U-019.md @@ -18,6 +18,10`), 9ce7335 (+schema.ts). Ledger `fix_commit` b8f49f6 tidak menyentuh U-019.md |

Verdict bersih (bukan temuan): U-014 PASS (`:18-20`), U-017 PASS (`:36-38`), U-002 "lulus lensa spec" (`U-002/bolt-report.md:5`), U-019 ronde 1 PASS (`U-019/bolt-report.md:497-498`). Tidak kembali: U-015 (`:255,261`) — tidak ada bukti re-run, UNVERIFIED.

Dibuang dari klaim: baris "U-033 audit before:null, 8382210" — lensa quality (`:236-244` heading "U-015 quality — 1 CRITICAL"; fed9dff subject "U-015 quality"); lensa spec U-015 tidak pernah kembali sehingga tidak mungkin melahirkannya. bb04ca3 `:98-105` hanya mengaitkan **pola lintas-unit** ke lensa spec.

Fix commit spec (koreksi): 771d1c1, d022f0b, c7d2bbd, 4d44c16, 5dbc87a, 9ce7335 (+61473a0 follow-on). **8382210 dihapus.**
False-positive / dismissed: **0**. Deferred 1, recorded-only 1.

### 2.3 quality — 5 dispatch, 38 temuan, 22 fixed

Per unit (angka sumber = heading notes / ledger):

| Unit | Sumber | C/I/m | Fixed (commit) | Deferred | Recorded-only |
|---|---|---|---|---|---|
| U-001 | `findings.json` F-002, F-003, F-004, F-009, F-012, F-013 | 1/3/2 | 6 — c7d2bbd (semua id disebut di body) | 0 | 0 |
| U-014 | `sprint-5-notes.md:22-32` "1 Critical + 2 Important + 3 Minor" | 1/2/3 | 2 — b87e6eb (`:266` stub-assert; `:311`) | 1 — `routes/bi-codes.test.ts:63` harness ke-5 (b87e6eb "TIDAK disentuh — milik U-034"; 3e8783e tidak menyentuh file itu; `interface Handleable` masih ada di HEAD) | 3 |
| U-015 | `:236-253` "1 CRITICAL + 2 Important + 4 Minor" | 1/2/4 | 3 — 8382210 (`:160` before:null, via U-033), 3e8783e (`:39` callerContext; harness ke-4) | 1 — `:150` pagination disuplai stub (8382210 nol hunk `DEFAULT_PAGE_SIZE`; test `:158,:178` masih `?? DEFAULT_PAGE_SIZE`) | 3 |
| U-016 | `:188-219` "2 CRITICAL + 8 Important + 2 Minor" | 2/8/2 | 9 — d022f0b (`:54` registry, `:179` test tautologis, `:72` UTC, `:94` deactivate, `:214`/`:209` test hampa, `:245` deactivation test), 3e8783e (callerContext #6/#7; harness 2 file) | 0 | 3 (accountNotFound ×3 — `cif-contact.service.ts:61`, `cif-message.service.ts:172` masih ada; Static<> alias; 'DELETE' union) |
| U-017 | `:70-79` (3 Important + 4 Minor per konvensi panel) | 0/3/4 | 2 — 3e8783e (callerContext dup — `inquiry.ts` docblock "quality+standards U-017"; harness, PARSIAL 5/8 file) | 1 — `inquiry.service.ts:296` mutant `address?.masked` (8382210 nol baris `masked`; HEAD `:336` tidak berubah) | 4 |
| **Total** | | **5/18/15** | **22** | **3** | **13** |

Distribusi fix: c7d2bbd 6, d022f0b 7, 3e8783e 6, b87e6eb 2, 8382210 1. Follow-on (bukan fix baru): 4f51f0c, 61473a0.
Bacaan alternatif refuter 2: kalau ikut ringkasan gate controller (`:234,:263`: U-017 quality = 1 Important, dua item duplikasi digulung ke seksi lintas-unit U-034 `:43-68`), total 36 (5/16/15), fixed 20. Kedua bacaan mempertahankan 5 Critical.
False-positive / dismissed: **0**.

Sinyal paling penting dari lensa ini: **4 Critical sprint 5 berbentuk sama** — aturan yang hanya berlaku di setup test (stub di-assert, registry permisif, test tautologis, audit before:null) — dan `sprint-5-notes.md:257`: "suite 579/0 caught none".

### 2.4 security — 4 dispatch (+1 attestation), 14 temuan, 12 fixed

| # | Unit | Sev | Temuan | Anchor | Outcome | Commit |
|---|---|---|---|---|---|---|
| 1 | U-001 | **Critical** | F-001 penolakan otorisasi host tanpa bentuk respons (403 hanya BranchNotAuthorized) | `findings.json:13-23` | fixed | c7d2bbd (+AccessDenied, +access_denied_response) |
| 2 | U-002 | **Critical** | E-001 CORS reflect Origin + credentials (default `@elysiajs/cors`) | `U-002/findings.json:11-21` | fixed | d81489f (`cors({origin:[...config.cors.allowedOrigins]})`) |
| 3 | U-002 | **Critical** | E-002 `error.message` mentah bocor ke klien (nama tabel, host, port DSN) | `:22-32` | fixed | d81489f (default branch → 500 badan buram + console.error) |
| 4 | U-001 | Important | F-005 fail-open: `effects` opsional di commit_result | `:57-67` | fixed | c7d2bbd (`minItems: 1`) |
| 5 | U-001 | Important | F-006 customer_address tanpa `masked` | `:68-78` | fixed | c7d2bbd |
| 6 | U-001 | Important | F-007 endpoint PII keyed CIF tanpa 403 | `:79-89` | fixed | c7d2bbd |
| 7 | U-002 | Important | E-003 explorer `/docs` ter-mount tanpa syarat | `:33-43` | fixed | d81489f (`config.docs.enabled`) |
| 8 | U-017 | Important | `routes/inquiry.ts` tanpa `.use(auth)` — saldo, mutasi, audit, PII | `sprint-5-notes.md:108-113` | new-unit → U-034 | 9d2d288 (spec), 3e8783e (`.use(auth)` + `beforeHandle: requireSession`) |
| 9 | U-017 | Important | Oracle enumerasi rekening lintas cabang (not-found vs other-branch beda kode; `error-handler.ts` echo message) | `:114-120` | **deferred — belum ditutup** | Ditugaskan ke U-033 (`U-017/postflight.json:12`, `:137-139`); 8382210 diff `inquiry.service.ts`/`mock.ts` nol perubahan `assertBranchScope`; HEAD `mock.ts:218-222` masih return null sebelum `assertBranchScope`, `inquiry.service.ts:229` throw HostRejectedError, `error-handler.ts:163` echo `error.message` |
| 10 | U-001 | Minor | F-010 deklarasi 403 tidak seragam (lock/heartbeat bocor heldBy) | `:112-122` | fixed | c7d2bbd |
| 11 | U-002 | Minor | E-004 `heldBy` string tanpa batas | `:44-54` | fixed (doc-only sesuai resep temuan) | d81489f; penegakan nilai di U-003 2c86d5a (`U-003/bolt-report.md:63` "Inilah penegakan E-004") |
| 12 | U-019 | Minor | G-001 source map produksi | `U-019/findings.json:12-22` | fixed | b8f49f6 |
| 13 | U-019 | Minor | G-002 `credentials: "include"` melebihi skema auth kontrak | `:23-33` | fixed | b8f49f6 |
| 14 | U-017 | Minor | Cursor di luar rentang → halaman kosong tak bertanda (D-003) | `:121-122` | recorded-only | — (`inquiry.service.ts:108-113` tidak berubah) |

Verdict bersih (bukan temuan): U-014 "security bersih" (attestation controller `U-014/postflight.json:12`; **tidak ada output lensa**, lihat §1.2), U-017 CHECKED-CLEAN (`:123-127`).
Fix commit (koreksi, semua terverifikasi di diff): c7d2bbd (5), d81489f (4), b8f49f6 (2), 3e8783e (1). Tambahan yang tidak ada di klaim: **2c86d5a** (penegakan E-004).
False-positive / dismissed: **0**. Deferred 1 (oracle — masih terbuka di HEAD), recorded-only 1.

### 2.5 standards — 5 dispatch, 4–5 temuan, 2–3 fixed

| # | Unit | Sev | Temuan | Anchor | Outcome | Commit |
|---|---|---|---|---|---|---|
| 1 | U-001 | Important | F-008 kunci skema `nextCursor` camelCase sendirian di antara 36 kunci snake_case | `U-001/findings.json:90-100` (satu-satunya baris `lens: standards` di ledger manapun) | fixed | c7d2bbd (`next_cursor` + 6 `$ref` diganti) |
| 2 | U-016 | Important | `cif-messages.ts:67-70` route factory meneruskan `serviceOptions` — jalur injeksi kedua, pola repo menyuntik instance jadi (`locks.ts:90`) | `sprint-5-notes.md:222-226` | **design retained** (refuter 1: recorded-only; refuter 2: dismissed) | d022f0b hanya menulis ulang docblock (`@@ -60,9 +60,13`) dan **mempertahankan** `serviceOptions`; HEAD `cif-messages.ts:88-90`; 771d1c1 menambah 3 call site lagi; `app.ts:285` mendokumentasikannya sebagai titik wiring U-018 |
| 3 | U-016 | Minor | `deactivate` unreachable (konfirmasi independen atas spec/quality) | `:227` | fixed | d022f0b (defect sama dengan spec #3 / quality U-016) |
| 4 | U-016 | Minor | `format: 'date'` tanpa preseden di repo | `:227-228` | recorded-only | — (`models/cif-contact.ts:139,141` tidak berubah sejak 62d5fc5) |
| 5 (kontestasi) | U-017 | Important | Route split: 5 dari 7 route pakai callerContext lokal byte-identik yang throw plain Error; narrowing U-032 hanya menjangkau 2 route | `:43-56`, `:131` ("quality+standards U-017"); `units/U-034.md:103`; `U-034/dispatch-prompt.md:116` | new-unit → U-034 | 9d2d288 (spec), 3e8783e |

Kontestasi #5: refuter 1 memasukkannya (atribusi gabungan di `:43`/`:131`); refuter 2 mengeluarkannya karena `:83` "U-017 standards — nol temuan", `:61` mengkredit remedi ke lensa quality, `:76` membukukannya sebagai quality Important. Dokumen ini membawa **keduanya**: strict 4 (0/2/2, fixed 2) · inklusif 5 (0/3/2, fixed 3 hanya bila new-unit dihitung fixed). Defect-nya sendiri tertutup lewat lensa quality bagaimanapun atribusinya.

Dibuang dari klaim: CRITICAL 1 (registry no-op), CRITICAL 2 (test tautologis), Important todayIso UTC — ketiganya di bawah heading `## U-016 quality — 2 CRITICAL + 8 Important + 2 Minor` (`:188`, item `:193,:198,:202`); heading standards `:221` "1 Important + 2 Minor" tidak memuat Critical; `U-016/postflight.json:12` "quality 2 Critical + standards 1 Important". cff47bd menamai kedua lensa di judul karena satu commit menambah dua seksi.
Verdict bersih: U-014 PASS (`:21`), U-015 bersih (`:232,:261`), U-017 nol temuan (`:83`, dengan catatan kontestasi di atas).
Fix commit (koreksi): c7d2bbd, d022f0b (+3e8783e bila #5 dihitung). Hitungan 9 → 2–3.
False-positive / dismissed: **0–1** (item #2 tergantung bacaan; tidak ada catatan dismissal eksplisit, tapi desain dipertahankan sadar).

Temuan unik standards yang **tidak** diangkat lensa lain dan berujung fix: **hanya F-008** (penamaan). #2 dipertahankan, #4 tidak diperbaiki, #3 dan #5 duplikat lensa lain.

### 2.6 design — 0 dispatch, 0 temuan

Kedua refuter mengonfirmasi 0. Bukti: tidak ada nilai `lens: design` di 3 ledger maupun di seluruh history-nya (nilai yang muncul: quality ×12, security ×16, spec ×4, standards ×2, controller, resolution-verifier, implementer-self-report); `sprint-5-notes.md` hanya 4 lensa; 0/36 bolt-report menyebut design lens (`AUDIT-PIPELINE.md:288`); 24 dispatch prompt non-UI menyatakan "no design lens is dispatched" (`U-001/dispatch-prompt.md:241`); 10–12 `lens-inputs/U-0xx/design-slice.md` (ef28897) = input, byte-identik, tanpa satu pun output. Satu-satunya fix UI responsif, 7b5703f ("tahan guliran mendatar halaman di 375px"), = commit manual non-bolt (`AUDIT-PIPELINE.md:288`), origin manual, bukan lensa.

Caveat: ketiadaan artefak ≠ bukti lensa tidak pernah dipanggil (transkrip tidak ada). Tapi tidak ada artefak yang bisa menaikkan hitungan di atas 0.

### 2.7 verifier — 2 dispatch, 1 temuan, 1 fixed

| # | Unit | Sev | Temuan | Anchor | Outcome | Commit |
|---|---|---|---|---|---|---|
| 1 | U-002 | Important | E-006 catch-all meratakan error 4xx bertipe Elysia (InvalidCookieSignature 400, InvalidFileType 422) → 500 — **regresi yang lahir dari fix E-002** | `U-002/findings.json:67-76` (`lens: resolution-verifier`) | fixed | bd579eb (`set.status = clientErrorStatus(error) ?? 500`; test +96) |

Verdict bersih (bukan temuan): U-001 delta review `verified_by: resolution-verifier`, `verdict: all_resolved`, `new_findings: 0`, 4 delta check (`U-001/findings.json:157-166`); U-002 ronde 5 `verified_by: resolution-verifier+controller` (`:101-103`). Sapuan under-count: grep `verifier|resolution-verif|verified_by|peninjau|delta review` seluruh vault + 117 body commit → tidak ada temuan verifier lain (`U-014/bolt-report.md:354`, `U-019/bolt-report.md:738` = prosa antisipatif). `AUDIT-PIPELINE.md:31` membatasi dispatch verifier "≥2".

Dibuang dari klaim (12 dari 14 baris): E-003 → security; E-007 → controller; 4 item U-016 → quality; U-033 → self-report U-017 + quality U-015 (8382210 = feat unit baru); U-001 delta review "0 new findings" bukan temuan; U-022 2c5ac18 ("Tinjauan menemukan", reviewer tak bernama, tidak ada ledger) dan U-029 e7f557c (reviewer tak bernama) = origin UNVERIFIED, tidak bisa dikreditkan ke verifier.
Fix commit (koreksi): **bd579eb saja.** d81489f, b2e760c, d022f0b, 8382210, 2c5ac18, e7f557c dihapus.
False-positive / dismissed: **0**.

## 3. Biaya — ESTIMATE dari satu angka terukur

Basis: operator mengukur **~267k token per panel 4 lensa** (`2026-08-29-panel-cost-field-measurement.md` §1) → **~67k per dispatch lensa** (267k/4). Angka ini dari satu unit (U-001, openapi.yaml 2110 baris); biaya panel berskala ukuran artefak × jumlah lensa (§4b dokumen itu), jadi 67k adalah **rata-rata satu titik**, bukan konstanta. Dispatch verifier bukan bagian panel 4 lensa — pemakaian 67k untuknya = ekstrapolasi. Dispatch = batas bawah §1.3 (re-dispatch per ronde tidak terekam). Semua kolom biaya di bawah = **ESTIMATE**.

| Lensa | Dispatch berjejak | ESTIMATE spend | Temuan (C/I/m) | Fixed | ESTIMATE per temuan | ESTIMATE per Critical+Important |
|---|---|---|---|---|---|---|
| spec | 7 | ~469k | 7 (1/2/4) | 5 | ~67k | ~156k |
| quality | 5 | ~335k | 38 (5/18/15) | 22 | ~9k | ~15k |
| security | 4 (+1 UNVERIFIED) | ~268k–335k | 14 (3/6/5) | 12 | ~19k–24k | ~30k–37k |
| standards | 5 | ~335k | 4–5 (0/2–3/2) | 2–3 | ~67k–84k | ~112k–168k |
| design | 0 | 0 | 0 | 0 | — | — |
| verifier | 2 | ~134k (ekstrapolasi) | 1 (0/1/0) | 1 | ~134k | ~134k |
| **Total** | **23–24** | **~1,54M–1,61M** | **64–65** | **42–43** | ~24k | ~40k |

Sprint 5 sendiri (13 lensa, `sprint-5-notes.md:4`): ESTIMATE ~868k (13 × 67k) untuk 5 Critical (4 quality + 1 spec), ~17 Important, ~15 Minor, dari 4 unit yang suite-nya hijau 579/0.

Yang **tidak** bisa dihitung dari run ini: biaya per tier (tier tidak terekam), biaya per ronde (re-dispatch tidak terekam), biaya misdiagnosis yang dihindari (counterfactual tanpa data produksi). Angka "per Critical+Important" untuk spec dan standards sensitif terhadap satu-dua temuan — jangan dibaca sebagai stabil.

## 4. Kandidat pemangkasan / re-tier — dengan counterfactual eksplisit

Aturan yang dipakai: **hanya lensa dengan NOL Critical dan NOL Important di seluruh run yang boleh jadi kandidat pangkas.** Yang punya Important tapi nol Critical dibahas sebagai kandidat **re-tier**, bukan pangkas. Semua counterfactual di bawah dihitung atas unit tempat lensa itu **tidak menemukan apa-apa**, bukan atas seluruh lensa.

| Lensa | C/I di seluruh run | Status per aturan | Unit tanpa temuan (dispatch "sia-sia") | Counterfactual: kalau tidak jalan di unit-unit itu, apa yang hilang? | Verdict |
|---|---|---|---|---|---|
| design | 0/0 | **Satu-satunya kandidat pangkas per aturan** | Tidak pernah ter-dispatch (0/36 jejak) | **Tidak bisa dihitung**: tidak ada dispatch → tidak ada biaya yang dihemat, dan tidak ada yield yang bisa dibandingkan. Satu defect UI (7b5703f, 375px) ditemukan manual di luar pipeline; apakah design lens akan menangkapnya = UNVERIFIED. `design-slice.md` ditulis 10–12× tanpa konsumen = biaya producer nyata tapi kecil dan tidak diukur. | **BELUM BISA DIPUTUS** — buktinya ketiadaan jejak. Yang bisa diputus sekarang hanya: producer slice tanpa konsumer = pemborosan terukur-kecil (triage F-31 kelas yang sama). |
| verifier | 0/1 | Bukan kandidat pangkas (ada Important) | U-001 delta review (0 temuan baru) | ~67k ESTIMATE dihemat. Hilang: attestation independen "13/13 resolved" — klaim tutup U-001 akan bersandar pada laporan implementer saja. Di U-002 lensa ini menangkap **regresi yang lahir dari fix** (4xx→500) — kelas defect yang tidak dicari lensa panel karena mereka membaca versi sebelum fix. | Tidak dipangkas per aturan. Yield-nya per dispatch rendah tapi kelas defect-nya unik (regresi-dari-fix). Owner: pertahankan atau batasi ke unit dengan fix round ≥1 Critical? Data 2 dispatch terlalu tipis. |
| standards | 0/2–3 | Bukan kandidat pangkas (ada Important); **kandidat re-tier** | U-014 PASS, U-015 bersih, U-017 nol temuan (strict) = 3 dari 5 dispatch | ~201k ESTIMATE dihemat. Hilang: **nol** — ketiga unit tidak menghasilkan temuan standards. Di 2 unit lain: F-008 (penamaan, fixed — satu-satunya fix unik lensa ini), serviceOptions (dipertahankan), format:date (tidak diperbaiki), deactivate (sudah ditangkap spec+quality). Kalau lensa ini tidak jalan **sama sekali**: hilang 1 fix penamaan Important + 1 catatan desain yang tidak mengubah kode. | Re-tier BELUM BISA DIPUTUS: tier per unit tidak terekam (`HANDOFF.md:85` hanya agregat), jadi tidak diketahui apakah 3 dispatch kosong itu sudah sonnet. Pemilihan ex-ante unit mana yang akan kosong tidak mungkin dari data ini. Owner memutuskan apakah 1 fix penamaan sepadan ~335k ESTIMATE. |
| spec | 1/2 | Bukan kandidat | U-014 PASS, U-017 PASS, U-002/U-019 hanya minor, U-015 tidak kembali | ~134k ESTIMATE (U-014+U-017) dihemat; hilang nol di dua unit itu. Tapi U-016 melahirkan satu Critical (alur nasabah hilang → U-035) yang tidak ditangkap lensa lain, dan U-015 (tidak kembali) justru unit yang menyimpan Critical before:null — lensa spec tidak sempat melihatnya. Ex-ante U-014/U-017 vs U-016 tidak bisa dibedakan. | Tidak dipangkas. Catatan operasional: turn limit U-015 = satu dispatch terbakar tanpa output (~67k ESTIMATE), tidak di-re-run, tidak dicatat di postflight. |
| security | 3/6 | Bukan kandidat | U-014 (attestation saja — dispatch sendiri UNVERIFIED) | 0–67k ESTIMATE. Hilang nol di U-014. Di U-002 satu dispatch menghasilkan 2 Critical (CORS reflect, bocor error.message) + 1 Important — kelas defect yang suite hijau tidak lihat. | Tidak dipangkas. |
| quality | 5/18 | Bukan kandidat | Tidak ada — 5/5 dispatch menghasilkan temuan, 5 Critical tersebar di U-001, U-014, U-015, U-016 (2) | — | Tidak dipangkas. Yield tertinggi per token (~9k/temuan ESTIMATE). |

Dua hal lintas-lensa untuk owner, tanpa keputusan:

1. **Redundansi lintas lensa terukur kecil tapi nyata**: `deactivate` U-016 dilaporkan 3 lensa, callerContext U-017 oleh 2 lensa. Redundansi ini justru dipakai controller sebagai "konfirmasi independen" (`:227`, fed9dff "konfirmasi independen ketiga"). Apakah itu nilai atau biaya = penilaian owner.
2. **Yang hilang bukan karena lensa, tapi karena dispatch gagal**: U-015 spec tidak kembali (turn limit), U-016 tanpa security, dan 19+ unit tanpa jejak panel sama sekali (kebijakan `HANDOFF.md:25` + F-07). Sebelum memangkas lensa yang berjejak, gap ini lebih besar dari yield lensa manapun yang dipertimbangkan untuk dipangkas.

## 5. Yang akan bisa diukur di run berikutnya (7.11.0)

Per triage `2026-08-30-field-audit-triage.md` tranche 3: `findings.json` ditulis skrip (F-08) dengan `lens` per temuan, gate `panel-evidence` untuk unit standard/full (F-07), dan stempel `plugin_version` + `tier` + `lenses` + durasi di writer artefak (F-26). Kalau itu mendarat, yang berubah dari "tidak bisa" menjadi "bisa dihitung dari disk":

| Pertanyaan yang hari ini UNVERIFIED | Sumber di 7.11.0 | Yang tetap TIDAK terukur |
|---|---|---|
| Lensa mana yang benar-benar ter-dispatch per unit (vs "attestation bersih") | `lenses_reported` / `lenses_pending` per ledger, ditulis skrip; unit tanpa ledger = evidence missing (gate) | Lensa yang dipanggil di luar jalur skrip (Agent langsung) tetap tanpa jejak |
| Atribusi lensa per temuan tanpa membaca heading prosa | field `lens` per temuan — menghilangkan kelas kesalahan §2.1 (standards vs quality, verifier vs semua) | Atribusi gabungan ("quality+standards") harus punya aturan tulis: satu lensa per baris, duplikat lintas lensa = dua baris dengan `duplicate_of` |
| Dedup lintas lensa dan lintas sumber (ledger vs bolt-report vs commit) | satu ledger per unit-ronde sebagai sumber tunggal; bolt-report merujuk id, bukan menulis ulang | Duplikasi defect yang sama di **unit berbeda** (harness ×4) tetap butuh id lintas unit |
| Tier ↔ yield | stempel `tier` per dispatch | Korelasi butuh ≥ puluhan dispatch per tier; satu run 30 unit mungkin masih tipis |
| Biaya per lensa (bukan ESTIMATE 267k/4) | durasi per dispatch terstempel; token per dispatch **hanya** kalau gateway/host mencatatnya (triage: cost = AI gateway) | Token tetap tidak ada di disk kalau gateway tidak mengembalikannya |
| Dispatch gagal (turn limit U-015) | `lenses_pending` yang tidak pernah kosong + gate evidence missing → terlihat, bukan diam | Re-run otomatis = keputusan desain terpisah |
| Verdict bersih vs temuan | ledger dengan `findings: []` + `verdict` eksplisit — tidak lagi dihitung sebagai minor oleh pembaca | — |
| Outcome per temuan (fixed / deferred / dismissed / recorded-only) dan `fix_commit` yang benar | `status` + `fix_commit` per temuan ditulis saat ronde fix, bukan retroaktif (U-002 ledger `fix_commit` 52b8a14 = commit terakhir, bukan fix E-001; U-019 `fix_commit` b8f49f6 tidak menyentuh U-019.md untuk G-003) | Verifikasi "fix_commit benar-benar menutup temuan" tetap butuh pembaca diff atau verifier |
| Defect yang ditemukan panel vs suite | ledger + hasil suite di postflight pada sha yang sama → "suite hijau, panel N Critical" jadi angka per run | — |

Yang **tidak** dijanjikan 7.11.0 dan tetap terbuka untuk dokumen ini: design lens (dispatch-nya sendiri belum ada jejak — sebelum lensa itu dipanggil, tidak ada yang bisa diukur), tier per unit di sprint yang sudah lewat (tidak bisa direkonstruksi), dan token per dispatch tanpa dukungan gateway.

## 6. Batas dokumen ini

- Angka koreksi = hasil dua refuter per lensa dengan anchor; **tidak** diverifikasi ulang oleh penulis dokumen ini terhadap disk (tugas ini menulis, bukan membaca ulang HOST-AS400). Setiap baris membawa anchor-nya agar owner bisa memeriksa.
- Klaim awal bukan dibuang — disimpan di kolom "Klaim" §2.1 sebagai bukti cara hitung yang salah, karena kelas kesalahannya (triple-count, verdict-sebagai-temuan, salah lensa) adalah persis yang F-08 harus buat mustahil.
- Tidak ada satu pun rekomendasi pangkas/re-tier di sini yang cukup bukti untuk dieksekusi hari ini. Yang bisa dieksekusi = instrumentasi (§5), lalu ukur ulang.
