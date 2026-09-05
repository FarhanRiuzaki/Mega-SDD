# Lane D — Audit: transaction-parameter-table.prd.md + record-layouts.prd.md

Auditor lane D · 2026-09-05 · sumber dibaca penuh: QDDSSRC.TLTX (2963 baris), QDDSSRC.TLTXRM (34), qrpgsrc.tltran (spot-range ±20 lokasi), 19 member #DS2..#DS29, #DEFN2, #CODES, #GETAM2, #GETAM3, #CRTFLT, #FNDBOP, #LBRUSE, dan `FILE REF/qddssrc.TLFREF` (1476 baris).

---

## MODULE 1 — transaction-parameter-table.prd.md

### Verdict ringkas

PRD ini kuat di struktur: kamus 87-field header, gugus ×20, TLTXRM, dan semantik loc-pointer (BR-TLTX-5) hampir semuanya tembus verifikasi baris-per-baris. TAPI ada satu klaim semantik terbalik yang berbahaya (TLXGTN), satu keluarga field salah nama (TLXBE/TLXCE → harusnya TLXBM/TLXCM), satu gugus batch-read yang HILANG total dari kamus (TLXADn), dan dua gugus yang di-cap dormant padahal dibaca batch (TLXALn, TLXOGn). Ditambah: `FILE REF/` yang masuk 2026-09-04 menjawab OQ-TLTX-3 sepenuhnya dan sebagian besar OQ-TLTX-5 — PRD belum tahu itu. Grade: **BAIK dengan 4 defect faktual yang wajib dipatch.**

### Citation spot-check (12)

| # | Klaim / lokasi | Grade | Bukti |
|---|---|---|---|
| 1 | BR-TLTX-1: UNIQUE + `K TLTXCD` → TLTX:9, 2963 | **EXACT** | [VERIFIED] line 9 `UNIQUE`, line 2963 `K TLTXCD` |
| 2 | BR-TLTX-2: "87 field header" → TLTX:13-97 | **SUPPORTS-BUT-IMPRECISE** | [VERIFIED count] baris 13-97 = **85** field, bukan 87 (dihitung; tak ada baris komentar di range itu) |
| 3 | BR-TLTX-6: field mati TLMPU/TLMPT/TLXEY, "203 baris A*" → TLTX:178-183, 203-205 | **EXACT** | [VERIFIED] grep `A\*` = 203 hit persis; 60 baris field mati (3 gugus × 20 slot penuh, termasuk T1MP*/T2MP*) |
| 4 | BR-TLTX-7: relasi TLTXRM + fallback RTRECN=0 → TLTXRM:23-24,33-34; tltran:711-724 | **EXACT** | [VERIFIED] tltran:711-717 `Z-ADDX RTRECN` → CHAIN → *IN32 on → `Z-ADD0 RTRECN` → re-CHAIN |
| 5 | BR-TLTX-10: KEYTX single-key → tltran:338-339, 439-440 | **EXACT** | [VERIFIED] 338 `KEYTX KLIST`, 339 `KFLD TLTXCD`, 440 `KEYTX CHAINTLTX` |
| 6 | §4.2 TLAPPn routing → TLTX:148-150; tltran:595 | **EXACT** | [VERIFIED] 595 `TLAP,X WHEQ 'DD'` + 596 `TLXGDD ANDNE'N'` |
| 7 | §4.2 TLXRMn mode N/R/D → TLTX:242-244; tltran:676-707 | **EXACT** | [VERIFIED] 676 `RMK,X IFEQ 'N'` (RCFTPNT), 688 `'R'` (TLBTPN→TRREMK), 705-707 `'D'` (TDES,X→TRREMK) |
| 8 | §4.2 TLXAAn/ABn/ACn "REVCUR=base" → tltran:2416-2430 | **WRONG** | [VERIFIED] baris 2416-2427 memakai array `TLAA/TLAB/TLAC` = overlay **TLAMM/TLAMB/TLAMC (gugus TEST)**, bukan TLXAA/TLXAB/TLXAC; keluarga TLXA/TLXB/TLXC dipakai di 2448-2461. Sitasi membuktikan keluarga field yang lain |
| 9 | §4.2 "TLXBEn/TLXCEn (TLXAMT)" → TLTX:2784-2825 | **WRONG (nama)** | [VERIFIED] baris 2784-2825 = `TLXBM1..T2XBM0` + `TLXCM1..T2XCM0`. Nama TLXBE/TLXCE tidak eksis di mana pun (grep repo: satu-satunya hit "TLXBE" adalah TLXBED header). #DS29:418/442 (TBMT/TCMT) mengkonfirmasi nama BM/CM |
| 10 | §4.1 TLXGTN "'N' = bypass generate" → tltran:456 | **WRONG (semantik terbalik)** | [VERIFIED] 456 `TLXGTN IFNE 'Y'` → blok generate jalan. Artinya **'Y' = bypass**. TLFREF:141 menutup debat: COLHDG **'Bypass Tx Generation'** |
| 11 | §4.2 TLMMCA → TLTX:2467-2469; tltran:845-848 | **EXACT** | [VERIFIED] I0017 block `TLF,TLMMCA → AMOUNT` |
| 12 | BR-TLTX-5 loc-pointer → TLTX:163-176; tltran:104-115, 58, 106 | **SUPPORTS-BUT-IMPRECISE** | Klaim inti [VERIFIED] via #GETAM2:104-106 (`MOVE TACU,X TA` → `Z-ADDTLF,TA ACCTNO`) dan tltran:628, 846. Tapi tltran:104-115 = deklarasi E-spec (bukan "pemakaian"), :58 = baris komentar YSF |

Bonus di luar 12 (semua dicek): TLXVPn:1356, TLXPBS:1366-1368, TLXAXn:816-821, TLXUSn+TLFOSB:825-831, TLGSUM:1986-1991, TLXTAN:1300-1304, TLXADL:1330-1332, TLTYPn:1594-1598, TLXSRn:1616-1619, TLXDSn:1957-1959, TLALTn:2404-2407, TLXPVn:2381-2383, TLXLEn:2399, #GETAM2 (44-60 team amount 21-24, 80-89 TLOE/TLOF, 111-112, 114-148 aux Y/W, 155-159 TLBCOR), #GETAM3:27-49, #CODES, #FNDBOP:5-14, #LBRUSE:8-11, #CRTFLT (16-18, 42-53, 62-66, 72-73) — **semua EXACT**. Satu tambahan imprecise: baris TLXAFT mengutip tltran:429-432, padahal filter MO/CT/A1/C1 di situ menguji **TLBAFT** (field buffer TLLOG), bukan TLXAFT; TLXAFT sendiri dipakai di 599 (`IFEQ 'CT'` closeout).

Tally 12 formal: **7 EXACT · 2 IMPRECISE · 3 WRONG.** Extended (±30): mayoritas besar EXACT — presisi baris sitasi PRD ini secara umum sangat tinggi; yang salah adalah segelintir klaim konten, bukan pola sitasi.

### Marker honesty (sample 8 klaim ber-status VERIFIED / tanpa hedge)

1. BR-TLTX-1 → jujur ✓
2. BR-TLTX-6 (203 A*, 20 slot penuh) → jujur ✓
3. BR-TLTX-8 (field TLTXRM) → jujur ✓ (semua tipe cocok TLTXRM:23-32)
4. BR-TLTX-10 → jujur ✓
5. §4.3 tabel tipe TLTXRM (4,0 / 2,0 / 40A / Z dst.) → jujur ✓
6. §4.2 TLAPPn/TLCDn/TLACUn/TLAMUn → jujur ✓
7. §4.2 TLXGTN "'N' = bypass" → **TIDAK jujur** — klaim salah disajikan tanpa hedge apa pun ✗
8. §4.2 baris TLXAA (sitasi 2416-2430) → **meleset tanpa hedge** — baris itu milik keluarga TEST ✗

Catatan positif: klaim yang memang lemah umumnya SUDAH diberi [INFERRED] + dasarnya (BR-TLTX-3, BR-TLTX-5, BR-TLTX-7, BR-TLTX-9, baris dormant). Disiplin marker bagus; 2/8 sample gagal karena isinya keliru, bukan karena over-claim gaya.

### Coverage omissions

Header TLTX (85 field, baris 13-97): **semuanya ke-cover** di §4.1 (tabel identitas + gugus prose). TLTXRM 10 field: **lengkap**. Gugus ×20 dan tail:

- **OMITTED: gugus TLXADn** (`TLXAD1..T2XAD0`, REFFLD TLXAMT, TLTX:2891-2910) — tidak ada di §4.2 sama sekali, padahal **dibaca batch**: array `TLXD` dipakai tltran:2464-2467 (LE amount tahap 4 → LEAMT4). Rangenya malah tertelan diam-diam di baris "TLXALn/TLXOGn ... 2870-2931". Ini omission paling load-bearing.
- **Salah status "tidak dibaca batch"**: TLXALn (array `TLLU`, dipakai tltran:573-575 sebagai currency selector '1'/'2') dan TLXOGn (array `TLOG`, dipakai tltran:2486-2489 sebagai opcode LEAMT4). Keduanya di-cap "[INFERRED dormant kandidat]" — REFUTED.
- **Salah status TEST**: TLAMM/TLAMB/TLAMC dibilang "tidak dibaca batch" — array `TLAA/TLAB/TLAC` justru dibaca di tltran:2416-2427 (cabang REVCUR=JHICUR). OQ-TLTX-6 premisnya gugur.
- Benar-benar declared-only (klaim dormant TAHAN): TLXBMn/TLXCMn (TBMT/TCMT hanya E-spec tltran:152-153, nol referensi), TCY1-12 (DS ada di #DS3:78-91 — tidak dipakai C-spec tltran).
- BR-TLTX-9 mencampur field TLMAST ke daftar "header TLTX" (TLM*/TLXG* bukan field RTLTX — lihat FILE REF table di bawah).
- Minor: baris TLMBLn menunjuk `[OPEN→OQ-TLTX-6]` padahal teks OQ yang memuat TLMBLn adalah OQ-TLTX-5 (salah kait nomor OQ).

### FILE REF resolution table (lever terbesar)

`FILE REF/` (11 DDS, masuk 2026-09-04, SETELAH ekstraksi) — status per unknown:

| Unknown / OQ di PRD | Terjawab? | Bukti |
|---|---|---|
| OQ-TLTX-3 [P1] "minta DDS TLFREF + GLFREF/DDFREF/LNFREF/CDFREF/RCFREF/CFFREF" | **YA — RESOLVED penuh.** Semua 7 file yang diminta ADA, plus BIFREF/SRFREF/JHFREF/RMFREF | `FILE REF/qddssrc.TLFREF` dkk. |
| BR-TLTX-3 [INFERRED] "tipe/panjang di TLFREF yang hilang" | **YA — bisa naik jadi VERIFIED.** Contoh kunci: TLTXCD 4,0 (TLFREF:54), TLTXDS 20 (:55), TLXAFT 2 (:58), TLXAPP 2 (:345), TLXTYP 1 (:362), TLXCD 3,0 (:367), TLXCDC 3,0 (:368), TLXACU 2,0 (:376), TLXACT 19,0 (:380), TLXAUX 1 (:381), TLXAMU 2,0 (:382), TLXAMT 8 (:385), TLXSER 2,0 (:399), TLXRPV 1 (:1470), TLXLEQ 1 (:1471), TLXADT 40 (:1411), TLBC00 1 (:573), TLMMCA 2,0 (:819) — dan semuanya konsisten dengan lebar slot di #DS2-#DS29 (cross-proof dua sumber) | qddssrc.TLFREF |
| OQ-TLTX-5 [P2] field tanpa dokumentasi (TLXBED, TLXSBL, TLXDAY, TLXSEQ, TLXLOG, TLXONF, TLXPBT, TLXPBF, TLMBLn, TLDLM6/7/T, TLUSID) | **SEBAGIAN BESAR YA** — COLHDG-nya ada semua: TLXBED='Bypass Edits' (:148), TLXSBL='Send F5 Response' (:176), TLXDAY='Hold Days Field#' 2,0 (:169), TLXSEQ='Hold Seq# Field#' 2,0 (:172), TLXLOG='Log Transaction' (:108), TLXONF='Teller Type' 1,0 (:122), TLXPBT='Passbook Transaction' (:126), TLXPBF='Passbook Field#' 2,0 (:129), TLDLM6/7='Date last maintenance' (:114-116), TLDLMT='Time last' (:118), TLUSID='Changed by' (:120), TLXMBL 3 + VALUES('Y  '…'YYY') + komentar `POS1=POST AVAILABLE POS2=POST CURRENT POS3=POST COLLECTED` (:390-392) | qddssrc.TLFREF |
| — residu OQ-TLTX-5: "apakah masih dipakai komponen lain?" | TIDAK — butuh program online/maintenance di luar source set | — |
| Semantik TLXGTN | **YA — dan mengekspos error PRD**: 'Bypass Tx Generation' (:141) ⇒ 'Y' = bypass, bukan 'N' | qddssrc.TLFREF:141 |
| Gugus TLXGDD/GCD/GLN/GGL/GRC/GFL + TLM* "definisi fisik [OPEN]" | **YA**: TLXGGL/GDD/GCD/GLN/GRC/GFL 1 char (:1061-1076), TLMHOL/TLMFLO 1 (:789-792), TLMLAV/TLMNAV 15S2 (:799-802), TLMODY/TLMLDY/TLMNDY 2S0 (:804-808), TLMLBR (:1036), TLMLFT (:1163), TLMSBR (:1220), TLGSUM (:547). PLUS koreksi mekanisme [INFERRED]: kontainer runtime-nya bukan record TLTX melainkan **data area TLMAST** via external DS (tltran:234 `ITLMAST E DSTLMAST`; 394-395 `*NAMVAR DEFN TLMAST` + `IN TLMAST`) | TLFREF + tltran |
| Gotcha #1 "95% field tanpa tipe; jangan karang panjang" | **RESOLVED** — semua panjang kini tersedia | TLFREF |
| OQ-TLTX-4 [P2] nilai RTCPTP/RTBCAC | **TIDAK** — tidak ada di FREF mana pun (grep nihil); tetap open | — |
| OQ-TLTX-1 [P1] isi tabel TLTX | **TIDAK** — FREF cuma skema, bukan data | — |
| OQ-TLTX-2 [P1] program pemakai lain | **TIDAK** | — |
| OQ-TLTX-7 [P3] remark paralel | **TIDAK** | — |
| OQ-TLTX-6 [P3] gugus TEST dormant? | Bukan urusan FREF — tapi **REFUTED dari kode**: TLAA/TLAB/TLAC dibaca tltran:2416-2427 | qrpgsrc.tltran |

Net: FILE REF menutup **1 dari 3 OQ P1** (OQ-TLTX-3) dan mayoritas OQ-TLTX-5; sisa P1 (data tabel + konsumen lain) memang butuh manusia/host.

### Ambiguous rules — fokus BR-TLTX-5 (slot-20 indirection)

Bisakah AI agent rebuild mapping tanpa nebak? **Struktur: ya.** Rantainya lengkap dan teruji: loc field (2,0 per TLFREF) → indeks 1-20 → `TLF` buffer array (tltran:111, `E TLF 20 17 0`) → nilai. Pola `MOVE TACU,X TA` / `Z-ADDTLF,TA ACCTNO` (#GETAM2:104-106) plus edge amount-slot 21-24 → team amount TLXCA1-4 (#GETAM2:47-54, #GETAM3:27-49) terdokumentasi dan tembus verifikasi. Yang TIDAK bisa direkonstruksi dari PRD ini: (a) arti bisnis tiap slot buffer per transaction code — itu data TLTX/TLLOG (OQ-TLTX-1, dan memang di-flag jujur); (b) sisi pengisian TLBF01-20 didelegasikan ke PRD dispatcher — acceptable, cross-ref eksplisit. Ambiguitas nyata yang tersisa: nilai sah TLXPVn ("'D'/'U'/'B'") tidak terverifikasi dari kode (nilai cuma jadi kunci CHAIN RGLGRPV, tltran:2382-2383) — harusnya [INFERRED] atau ditautkan ke tabel GLGRPV; dan pembaca bisa salah menganggap urutan LE-amount TLXA→TLXD linear padahal bercabang REVCUR (2414 vs 2447) dengan komentar sumber yang saling bertentangan — PRD tidak menjelaskan cabangnya.

### Scorecard

| Dimensi | Nilai | Alasan |
|---|---|---|
| Completeness | **PARTIAL** | 85 header + TLTXRM lengkap; tapi gugus TLXADn hilang total, dan itu batch-read |
| Accuracy | **PARTIAL** | Mayoritas klaim tembus EXACT, tapi TLXGTN terbalik, TLXBE/TLXCE salah nama, 3 gugus salah status dormant, "87" ≠ 85 |
| Consistency | **PASS** | Cross-ref ke PRD dispatcher/amount-engine rapi; satu salah kait kecil (TLMBLn→OQ-6 vs OQ-5) |
| Unambiguity | **PASS** | Loc-pointer, fallback RTRCNO=0, prefix-shift dijelaskan tegas dengan contoh |
| Testability | **PARTIAL** | Struktur assertable; nilai enum (TLXPV D/U/B, RTCPTP) belum bisa diuji tanpa data |
| Traceability | **PASS** | Hampir tiap sel ada file:line; presisi baris terbukti tinggi di spot-check |
| Dependency clarity | **PASS** | depends_on + delegasi eksplisit ke dispatcher; koreksi kecil: TLM*/TLXG* = data area TLMAST, bukan TLTX |
| Edge-case coverage | **PASS** | §5 bagus: prefix-shift T1/T2, field mati, dormant-by-code vs by-data, fallback remark |
| AI-readability | **PASS** | Tabel padat, marker disiplin, "do-not-replicate" tags berguna |
| Implementation readiness | **PARTIAL** | Sebelum patch 4 defect + serap FILE REF, rebuild akan mewarisi bypass terbalik dan kehilangan LEAMT4 path |

### Missing-info list (untuk stakeholder)

1. Ekspor data TLTX + daftar transaction code aktif (OQ-TLTX-1) — tetap blocker P1.
2. Daftar program lain pembaca/penulis TLTX & TLTXRM (OQ-TLTX-2).
3. Nilai sah + konsumen RTCPTP dan RTBCAC (OQ-TLTX-4) — tidak ada di FREF.
4. DDS/dokumentasi **data area TLMAST** (kontainer runtime TLM*/TLXG*) — file-nya tidak ada di source set; TLFREF hanya memberi tipe field.
5. Konfirmasi nilai TLXPVn terhadap isi GLGRPV.

---

## MODULE 2 — record-layouts.prd.md

### Verdict ringkas

Peta 19 member akurat untuk lebar/base-variable — semua angka yang dicek (TACT 380/19-per-slot, TAMT 160/8, TDES 800/40, STPREM 50, 9 rename #DS24, dst.) cocok sumber, dan kini ter-cross-proof oleh TLFREF. Kelemahannya dua kelas: (1) baris kamus §4 melewatkan gugus di dalam member yang dia sendiri kutip rangenya — EDT/TLXEDn 5000-byte di #DS2 dan TFS/TCY1-12 di #DS3 — plus #DS29 hanya separuh gugusnya disebut nama; (2) gotcha #5 / OQ-LAYOUT-1 tentang "tertukarnya" T/R# vs Check# **terbalik terhadap sumber** — anomali sebenarnya lain sama sekali. Grade: **CUKUP BAIK; butuh patch kamus #DS2/#DS3/#DS29 + tulis ulang gotcha #5.**

### Citation spot-check (12)

| # | Klaim / lokasi | Grade | Bukti |
|---|---|---|---|
| 1 | BR-LAYOUT-1 "pola identik — semua 19 file" | **SUPPORTS-BUT-IMPRECISE** | Pola dominan benar, tapi #DS10 memakai `XLBB01..XLBB20` (suffix 2-digit, TANPA prefix-shift) dan `XLBDC/X1BDC/X2BDC` (prefix X); TCY1-12 & TLX01-12 juga non-pola |
| 2 | BR-LAYOUT-2 penamaan T1/T2 "semua 19 file" | **SUPPORTS-BUT-IMPRECISE** | Sama seperti #1 — #DS10 pengecualian yang tidak disebut |
| 3 | BR-LAYOUT-3 #DS29:20-513 "6+ gugus tambahan" | **EXACT** | [VERIFIED] isi riil 21 gugus DS (LE, PV, TDES, TLXA/B/C, TLAA/AB/AC, TLOA-TLOD, TALT, TLOE/TLOF, TLLU, TBMT, TCMT, TLXD, TLOG, + TLDE mati) — "6+" benar walau sangat undersell |
| 4 | BR-LAYOUT-4 #DS24:21-30 rename GLGREF→TLGxxx, 9 field | **EXACT** | [VERIFIED] `IRGLGREF` + 9 rename persis (GLBRNI→TLBRNI … GLGCUR→TLGCUR) |
| 5 | BR-LAYOUT-5 #DS23 STPREM + tltran:391-392 | **SUPPORTS-BUT-IMPRECISE** | Struktur & literal benar (MOVE 'Teller#-'/'Seq#-' EXACT di 391-392), tapi **TLBID = 4 digit** (pos 30-33), PRD bilang "teller ID (5 digit)" |
| 6 | BR-LAYOUT-6 #DS6:67-113 dua gugus mati `I*` | **EXACT** | [VERIFIED] 67-89 Memo Post Field#, 91-113 Memo Post Usage, semua `I*` |
| 7 | §4 #DS2 "TLAP 40 (2/slot), TLTP 20 (1/slot)" (range 3-77) | **SUPPORTS-BUT-IMPRECISE** | Kedua angka benar; tapi rangenya sendiri memuat gugus ke-3 yang tidak disebut: `EDT` 5000 byte = TLXED1..T2XED0 @250/slot (#DS2:3-24) |
| 8 | §4 #DS3 (range 26-92) | **SUPPORTS-BUT-IMPRECISE** | USDS 8 / USDS1 30 / TLX 36 / TLXU 96 semua benar; gugus `TFS`/TCY1-12 (#DS3:78-91, FP003) tidak disebut |
| 9 | §4 #DS5 TACU/TFAU/TACT 380(19/slot)/TAUX | **EXACT** | [VERIFIED]; TACT 19/slot ↔ TLFREF TLXACT 19,0 cross-proof |
| 10 | §4 #DS7 empat gugus TSER/TTR/DCK/RTN 40 | **EXACT** | [VERIFIED] termasuk catatan jujur "(T/R — no direct TLTX field, internal)" |
| 11 | §4 #DS29 "LE 20, PV 20, TDES 800, TLXA/B/C, TLAA/TLAB/TLAC, TLXOA-OG" | **SUPPORTS-BUT-IMPRECISE** | Angka yang disebut benar; tak menyebut nama TALT, TLLU, TBMT, TCMT, TLXD (padahal TLXD & TLLU dipakai batch) dan TLDE (mati, `I*`, #DS29:513-518) |
| 12 | Gotcha #5: penamaan T/R#/Check# "tertukar" | **WRONG** | Sumber: label "T/R# USAGE" = base `TTR` fields `TLTR1..T2TR0` (#DS7:43-65); label "CHECK# USAGE" = base `DCK` fields `TLXDP1..T2XDP0` (#DS7:67-89). PRD menuliskannya TERBALIK ("field-nya TLXDP1-20 bukan TLTR"; "baris 44-65 = TTR" disebut gugus Check#). Dan pasangan DCK↔TLXDP justru KONSISTEN dengan DDS ('Dep chk# loc') + TLFREF:428 'Deposit Check# Loc'. Anomali riilnya: **TLTRn tidak punya padanan TLTX/TLFREF sama sekali dan tidak pernah dipakai** (satu-satunya ref = E-spec tltran:107) |

Tally: **5 EXACT · 6 IMPRECISE · 1 WRONG.**

### Marker honesty (sample 8)

1. BR-LAYOUT-3 [INFERRED] "file kumpulan sisa" → hedge tepat ✓
2. BR-LAYOUT-4 (tanpa hedge) → jujur ✓
3. BR-LAYOUT-6 (tanpa hedge) → jujur ✓
4. §4 #DS4 TLCD/TCCD 60 (3/slot) → jujur ✓
5. §4 #DS8 TIN/TOUT/TUS/CFT → jujur ✓ (mapping Float1=TLONS/Float2=TLITN/Float3=TLOTN konsisten TLTX:191-199)
6. §4 #DS22 USB/AXF/OSB → jujur ✓
7. BR-LAYOUT-1 "semua 19 file — pola identik" tanpa hedge → **overclaim** (#DS10) ✗
8. Gotcha #5 → memang di-hedge [INFERRED] ✓ secara bentuk, tapi "dasar" yang dikutip salah baca sumber; OQ-LAYOUT-1 lalu dibangun di atas premis keliru — borderline ✗

Skor kejujuran: 6/8 bersih; pola pelanggarannya konsisten dengan Module 1 — bukan fabrication, tapi generalisasi/transkripsi meleset yang lolos tanpa hedge.

### Coverage omissions

- Ke-19 member #DS di direktori (2,3,4,5,6,7,8,10,11,12,13,14,19,22,23,24,25,28,29) **semua ada** di PRD — tidak ada member hilang (nomor 9/15-18/20-21/26-27 memang tidak eksis di folder).
- Dalam-member: **#DS2 gugus EDT/TLXEDn** (5000 byte, 250/slot — gugus terbesar se-file) dan **#DS3 gugus TFS/TCY1-12** tidak disebut; **#DS29** ±9 gugus tidak dinamai (TALT, TLOE, TLOF, TLLU, TBMT, TCMT, TLXD, TLOG eksplisit, TLDE mati).
- **#DS29 TLDE (TLXCA1-4, AL02) di-comment `I*`** — paralel sempurna dengan pola BR-LAYOUT-6 (#DS6 memo mati), tapi tidak dicatat; padahal menarik: TLXCA1-4 dibaca via #GETAM3 langsung dari record, DS-nya yang mati.
- `QCPYSRC.#DEFN2` tidak disebut PRD mana pun di modul ini — isinya 63 baris `*LIKE DEFN` (variabel kerja C-spec, bukan layout record), jadi eksklusinya defensible, tapi PRD tidak menyatakan keputusan scope itu; [NEEDS_VALIDATION] apakah modul lain (dispatcher) meng-cover-nya.
- Kolom "Field TLTX terkait" #DS10 bilang "dari TLBB01-20/TLBDC1-20 buffer" — nama field DS riilnya `XLBB*/XLBDC*`; hubungan ke TLBB/TLBDC masuk akal tapi tak disitasi = [INFERRED] tak berlabel.

### FILE REF resolution table

| Unknown / OQ | Terjawab? | Bukti |
|---|---|---|
| OQ-LAYOUT-1 [P2] (T/R# vs Check# "tertukar") | **SEBAGIAN — dan mengubah pertanyaannya.** TLFREF:425 `TLXRTN 2,0 'Deposit R/T# Loc'` + :428 `TLXDCK 2,0 'Deposit Check# Loc'` mengkonfirmasi pasangan RTN↔TLXRT dan DCK↔TLXDP itu KONSISTEN — tidak ada pertukaran. Pertanyaan yang benar: dari mana `TLTRn` diisi & siapa pemakainya (tidak ada di TLTX, tidak ada di TLFREF, tidak dipakai C-spec tltran) → kandidat dead kuat, tapi konfirmasi butuh program lain, bukan FREF |
| OQ-LAYOUT-2 [P3] (TEST group aman dihapus?) | **TIDAK via FREF — dan premis "dormant di dua sumber" REFUTED via kode**: `TLAA/TLAB/TLAC` dibaca qrpgsrc.tltran:2416-2427. Gugus TEST TIDAK aman dihapus begitu saja |
| Lebar slot per gugus (klaim inti modul) | **Cross-proof baru**: tiap lebar I-spec kini bisa diverifikasi dua arah terhadap TLFREF — TLXEDT 250 (:340) ↔ EDT 250/slot, TLXADT 40 (:1411) ↔ TDES 40/slot, TLXAMT 8 (:385) ↔ TAMT/TLXA 8/slot, TLXACT 19,0 (:380) ↔ TACT 19/slot, TLXMPU 2,0 + RANGE(00 20) (:386-388) ↔ gugus mati #DS6. Banyak baris [INTENT] bisa dinaikkan jadi terverifikasi-ganda |
| #DS23 TLBID/TLBSEQ | TIDAK dari TLFREF ini di-scan (field TLLOG); lebar sudah eksplisit di I-spec (TLBID 4 digit — sekalian koreksi "5 digit") | #DS23:4-10 |

### Ambiguous rules

- BR-LAYOUT-1/2 perlu direparasi jadi "17 dari 19 member berpola slot-20 TL/T1/T2; #DS10 berpola sendiri (XLBBnn 2-digit & X-prefix); #DS23/#DS24 bukan slot-20" — sekarang pembaca yang menulis parser dari BR-1/BR-2 akan salah di #DS10.
- Gotcha #5 + OQ-LAYOUT-1 harus ditulis ulang total (lihat spot-check #12) — dalam bentuk sekarang justru MENANAM kebingungan yang dia klaim peringatkan.
- Flow §3 ("Buffer copied by MOVE ... DS overlay slices") secara mekanik RPG kurang presisi — I-spec DS ini berdiri sendiri; array E-spec (tltran:100-158) menempel ke DS via nama base — tapi cukup untuk pembaca non-RPG. [INFERRED assessment]

### Scorecard

| Dimensi | Nilai | Alasan |
|---|---|---|
| Completeness | **PARTIAL** | 19/19 member ada, tapi gugus dalam #DS2/#DS3/#DS29 bolong |
| Accuracy | **PARTIAL** | Angka lebar/base nyaris sempurna; gotcha #5 terbalik, TLBID "5 digit", "semua 19 file" |
| Consistency | **PASS** | Cross-ref dua arah dengan PRD param-table rapi (BR-TLTX-4/6 ↔ BR-LAYOUT-2/6) |
| Unambiguity | **PARTIAL** | #DS23/24 exception jelas; #DS10 exception tak disebut; gotcha #5 membingungkan |
| Testability | **PASS** | Semua klaim posisi/lebar assertable langsung terhadap file |
| Traceability | **PASS** | Range file:line per baris kamus, terbukti akurat |
| Dependency clarity | **PASS** | Delegasi arti bisnis ke PRD param-table eksplisit dan tepat |
| Edge-case coverage | **PARTIAL** | #DS23/24/mati-#DS6 bagus; miss #DS10, TLDE mati, TLTR-tanpa-sumber |
| AI-readability | **PASS** | Tabel silang member→gugus→field induk sangat berguna untuk rebuild |
| Implementation readiness | **PARTIAL** | ETL yang dibangun dari PRD ini akan kehilangan EDT/TCY dan salah menangani #DS10 |

### Missing-info list

1. Provenance & konsumen `TLTRn` (#DS7 gugus T/R#) — tidak ada padanan TLTX/TLFREF, tidak dipakai tltran; butuh cek program lain sebelum divonis mati.
2. Status pemakaian gugus EDT/TLXEDn (declared di #DS2 + E-spec tltran:128; pemakaian C-spec belum ditemukan di range yang diaudit — [NEEDS_VALIDATION] sapu penuh).
3. Kejelasan scope #DEFN2 (modul mana yang memilikinya).
4. Konfirmasi hubungan XLBB/XLBDC ↔ TLBB01-20/TLBDC1-20 (rutin MOVETH/MOVETR — cek PRD dispatcher).

---

## Cross-module: daftar patch prioritas (gabungan)

1. **[P1] TLXGTN**: balikkan semantik — 'Y' = bypass generation (tltran:456 + TLFREF:141).
2. **[P1] Tambah gugus TLXADn** ke §4.2 param-table (TLTX:2891-2910; dipakai tltran:2464-2467, LEAMT4).
3. **[P1] Serap FILE REF**: tutup OQ-TLTX-3, isi tipe/panjang di kedua PRD, angkat BR-TLTX-3 dari [INFERRED], jawab mayoritas OQ-TLTX-5.
4. **[P2] Koreksi status dormant**: TLXALn (tltran:573-575), TLXOGn (:2486), TLAMM/TLAMB/TLAMC (:2416-2427) = DIBACA batch; perbaiki sitasi baris TLXAA (2448-2461, bukan 2416-2430); tulis ulang OQ-TLTX-6 & OQ-LAYOUT-2.
5. **[P2] Rename TLXBEn/TLXCEn → TLXBMn/TLXCMn** (TLTX:2784-2825; #DS29:418-462).
6. **[P2] Tulis ulang gotcha #5 + OQ-LAYOUT-1** record-layouts (pertanyaan riil = provenance TLTRn).
7. **[P3] Lengkapi kamus #DS2 (EDT), #DS3 (TCY), #DS29 (semua 21 gugus + TLDE mati); catat pengecualian #DS10; "87"→85; TLBID 4 digit; TLM*/TLXG* = data area TLMAST (tltran:234, 394-395).**
