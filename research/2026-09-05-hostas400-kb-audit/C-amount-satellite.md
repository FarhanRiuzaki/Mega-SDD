# Lane C — Audit PRD: amount-currency-engine & satellite-programs

Auditor lane C · 2026-09-05 · sumber dibaca penuh: 16 copy member QCPYSRC + qrpgsrc.tltran (range tercite) + DD0215, CD0215, JHDATI, JHDATO, DM91028, DM91033 + DDS pendukung (DDHISTLA, GLGREF, DDFREF, CDFREF, CDMAST, DDPAR2, DDMAST).

Semua nomor baris di bawah = baris file fisik di `TLTRAN/`, sudah dicek langsung.

---

## MODULE 1 — amount-currency-engine.prd.md

### Verdict ringkas

PRD ini kuat di struktur & citation discipline — mayoritas rule bisa dilacak persis ke baris kode, dan temuan paling penting (asumsi (19,2) "temporary", suspense 9999999999, float silent-skip, FNDCUR mati) memang benar ada di kode. Tapi ada **2 rule yang salah arah secara substansi** (BR-FLT-3 kondisi negasi float kebalik; BR-CUR-3 mekanisme '***' tidak terjadi), dan **satu wilayah besar tidak terdokumentasi sama sekali**: logika region/branch-type yang menentukan KAPAN dan BERAPA kaki IBT dibuat (WRTGL:184-255), plus override amount IBT dari buffer (WRTGL:186-189). Untuk PRD yang mau jadi source of truth revamp, gap IBT itu material — double-entry clearing bisa sampai 4× PUTIBT (8 record jurnal), bukan "satu IBT kalau cabang beda".

Skor kasar: **akurasi baris-per-baris bagus (10/12 citation ≥ SUPPORTS), tapi 2 rule WRONG + 2 gap HIGH → belum siap dipakai sebagai kontrak 1:1 untuk bagian float-direction dan IBT.**

### Citation spot-check (12)

| # | Claim | Citation | Grade | Catatan |
|---|---|---|---|---|
| 1 | BR-AMT-1 buffer → 4 array 20-slot | #MFTO2:7-90 | **EXACT** | TLF←TLBF01-20 (7-26), ABR←TLBB (28-47), DC←TLBDC1-9/T1BDC0-9/T2BDC0 (49-68), CU←TLBC (71-90). [VERIFIED] |
| 2 | BR-AMT-3 formula 8-char NO1/OP1/NO2/OP2/NO3 | #DS3:26-30; #AMTSR:29-147 | **SUPPORTS-BUT-IMPRECISE** | Struktur benar, tapi USDS di DS3 itu baris 26-**32** (NO3 di baris 32); range yang dicite kepotong. [VERIFIED] |
| 3 | BR-AMT-4 operand 01-20=TLF, 21-24=TEAMT, "di luar itu operand = 0" | #AMTSR:29-49, 57-77, 103-124 | **SUPPORTS-BUT-IMPRECISE** | Baris benar. Tapi "operand = 0" cuma berlaku untuk **NO1** (ELSE→SELEC→OTHER→`Z-ADD0 ADDF`, baris 46-48). Untuk NO2/NO3, guard-nya `IFGE '01' ANDLE'24'` (57-59, 103-105): nilai di luar range → **seluruh stage di-skip** (OP pun tidak dieksekusi), bukan operand 0. Hasil beda: `05+xx` dengan xx invalid = nilai slot 5, bukan 5+0 lewat jalur operator. [VERIFIED] |
| 4 | BR-AMT-6 asumsi (19,2), hitung di 25,9, half-adjust akhir | #AMTSR:21-23, 54-55, 79-80, 126-127, 153-155 | **EXACT** | Komentar REDI verbatim (21-23); `MOVE ADDF XMAMT1 192` + `Z-ADDXMAMT1 TMAMT1 259` (54-55, 79-80, 126-127); `Z-ADDTMAMT1 XAMOUN 192H` (154). [VERIFIED] |
| 5 | BR-AMT-8 TAMU≠0 → direct, else formula TAMT/TBMT/TCMT + TLOE/TLOF | #GETAM2:44-91 | **EXACT** | Persis: 44-60 direct (termasuk 21-24 team), 62-91 formula 3 tahap + CALLE. [VERIFIED] |
| 6 | BR-CUR-1 load kurs sekali, 8 rate/currency, urutan buy/sell/middle/avg/other/6/7/8 | #LODEXC:9-39; tltran:117-135, 401 | **EXACT** | JFXBRT/SRT/MRT/ART/ORT/RT6/RT7/RT8 (21-36); CCT 60, CER 480 (tltran E-spec ±117-133); `EXSR LODEXC` tltran:401. [VERIFIED] |
| 7 | BR-CUR-3 currency tak ketemu → CRU='***', hanya desimal default | #FNDCUR:14, 31-33, 102-111 | **WRONG** | `MOVE '***' CRU` (14) memang men-set semua slot invalid, TAPI baris 21/24/27 **selalu menimpa CRU,X dengan kode currency** sebelum LOKUP — '***' tidak pernah survive sebagai penanda gagal. Dan branch not-found (102-111) bukan cuma pakai desimal default: dia juga men-set `CRE,X = CER,C2` dengan C2 = rate number mentah **tanpa offset currency** → mengambil rate dari grup currency PERTAMA di tabel. Fail-soft-nya benar, mekanismenya salah dua-duanya. |
| 8 | BR-CUR-5 indeks = (pos−1)×8 + rate# | #FNDCUR:35-45; #LODEXC:18-36 | **EXACT** | `C SUB 1 C2; MULT 8 C2` lalu ADD rate#. [VERIFIED] |
| 9 | BR-FLT-3 koreksi + debit → ×(−1) | #CRTFLT:28-35 | **WRONG** | Kondisi sebenarnya: `DC,X='D' AND TLBCOR≠'Y'` **OR** `DC,X='C' AND TLBCOR='Y'` → negasi. Artinya yang dibalik itu **debit NORMAL** dan **kredit KOREKSI** — kebalikan dari klaim PRD ("koreksi dengan arah debit"). Ini rule arah uang; salah baca di sini = float terbalik tanda di sistem baru. |
| 10 | BR-GL-1 lookup GL 2 tingkat + suspense 9999999999/999/999 | #WRTGL:50-72 | **EXACT** | Kunci KEYGRF = TLBRN# + REF# + CURRCY (diverifikasi tltran:325-328, REF#=ACCTNO 19 digit di WRTGL:49); fallback cabang 0 (59-60); suspense 67-69. [VERIFIED] |
| 11 | BR-GL-5 matriks arah IBT (DC × koreksi × kaki) | #PUTIBT:55-107 | **EXACT** | Kaki 1: (D&¬kor)|(C&kor) → *CTL=TLIBDR else TLIBCR; kaki 2 mirror. [VERIFIED] |
| 12 | BR-GL-8 RPVMOD='Y' matikan override branch | #WRTGL:31, 131, 164-178 | **EXACT** | YS05: guard `RPVMOD ANDNE'Y'` di blok OSB (131) dan `RPVMOD IFNE 'Y'` membungkus blok USB (164-178). [VERIFIED] |

Skor: 8 EXACT · 2 SUPPORTS-BUT-IMPRECISE · 2 WRONG.

### Marker honesty (sampel 8 klaim ber-confidence implisit "verified")

Catatan metodologi: PRD ini hampir tidak memakai marker inline — kolom Confidence kosong di 36/37 rule (satu-satunya isi: BR-CUR-6 [INFERRED]). Kosong = implicit verified per grammar extract-intelligence. Sampel:

1. BR-AMT-6 kutipan komentar REDI — **HONEST**, verbatim di #AMTSR:21-23. (Tapi klaim "sejak 2006" di Edge Case 1 = [INFERRED] dari header MODIFS 26/04/2006, disajikan sebagai fakta — minor.)
2. BR-GL-4 dua record per panggilan PUTIBT — **HONEST** (WRITE RGLTELS di PUTIBT:78 dan 111).
3. BR-FLT-4 float silent-skip bila kalender tak ada — **HONEST** (CHAIN TLFLTC by FLOTBR+TLDAY, *IN10='1' → tidak ada WRITE, tidak ada log; BRNDAY klist diverifikasi tltran:305-308).
4. BR-MSC-3 BOP transaksi-dulu-line-menang, hanya >0 — **HONEST** (#FNDBOP:4-15).
5. BR-AMT-9 GETAM3 pra-hitung TEAMT1-4 — **HONEST** (#GETAM3:22-49; tltran:449 `EXSR GETAM3`).
6. BR-CUR-6 [INFERRED] FNDCUR mati di jalur utama — **HONEST & AKURAT**: tltran:482 = `AL03 C* EXSR FNDCUR` (comment), pengganti selector TLLU,X di tltran:573-580. Inferensi dilabeli benar; malah bisa naik jadi VERIFIED.
7. BR-FLT-3 — **DISHONEST-BY-ERROR**: disajikan verified padahal kondisinya terbalik (lihat spot-check #9).
8. BR-CUR-3 — **DISHONEST-BY-ERROR** untuk detail '***' dan rate not-found (spot-check #7).

Frontmatter vs body: `inferred_count: 9` tapi body cuma 1 [INFERRED]; `artifact_count: 3` tapi body cuma 1 [ARTIFACT] (BR-CUR-6). Angka frontmatter tidak bisa direkonsiliasi dari dokumen — [NEEDS_VALIDATION] ke pipeline extract (mungkin menghitung klaim non-BR, tapi itu tidak auditable).

### Undocumented behavior (severity-tagged)

- **[HIGH] Kondisi generate IBT (WRTGL:184-255) tidak terdokumentasi.** PRD/flow mereduksi jadi "cabang transaksi ≠ cabang rekening → PUTIBT". Kode aslinya: lookup region code RGN1/RGN2 dari TLBRN1 saat `TLMSBR='Y'` (191-203), lalu **empat** blok generate: servicing leg (206-217, syarat TLMSBR≠'Y' OR beda region OR sama region tapi TLITYP≠'M'), HO-of-servicing bila tipe 'S' + beda region (221-229), account leg (232-242, guard `SAVTY1≠'M'` — patch MEDAN, baris 238), HO-of-account bila SAVTY1='S' (246-253). Plus **exclusion hard-coded `TLSVBR ≠ 888`** (YS01, baris 212 & 224). Satu transaksi bisa memicu s.d. 4× PUTIBT = 8 record jurnal. Blok serupa juga di-copy inline di tltran (874-909, 1181-1217) untuk lane deposit. Ini justru bagian bisnis paling rawan salah saat rebuild. [VERIFIED]
- **[HIGH] Override amount IBT dari buffer (WRTGL:186-189).** `TLMMCA≠0 AND TLF,TLMMCA≠0 → MOVE TLF,TLMMCA AMOUNT` — nominal IBT bisa BEDA dari nominal jurnal GL yang baru ditulis (kaki kliring pakai slot buffer lain). Tidak disinggung sedikit pun. [VERIFIED]
- **[MEDIUM] PUTIBT memutasi DC,X permanen (PUTIBT:47-53).** Override GLPAR3 ditulis balik ke `DC,X` (array kerja), bukan variabel lokal — pemroses berikutnya atas line yang sama melihat arah yang sudah diganti. BR-GL-6 mendokumentasikan override-nya tapi tidak side-effect-nya. [VERIFIED]
- **[MEDIUM] FNDCUR not-found branch tetap mengisi rate (FNDCUR:104-111)** dari `CER,C2` dengan C2 tanpa offset currency → rate milik currency pertama di tabel. (Dampak runtime kecil karena FNDCUR mati di jalur ini, tapi PRD menyimpannya sebagai rule hidup BR-CUR-3.) [VERIFIED]
- **[MEDIUM] LODEXC tanpa bound check (LODEXC:11-39).** Loop READ sampai EOF menaikkan C tanpa cek ≤60; file kurs >60 record = index error / job crash. [VERIFIED]
- **[MEDIUM] CRTFLT memproses amount negatif.** Guard lama `IFGT *ZEROS` diganti `IFNE *ZEROS` (baris 39/40, 97/98, 154/155 — versi lama tinggal komentar). Kombinasi dengan matriks negasi (28-35) berarti float minus adalah jalur hidup. PRD tidak menyebut. [VERIFIED]
- **[LOW] Accrual float juga silent-skip** bila kalender (cabang, hari-tersisa) tidak ada (CRTFLT:75-76, 132-133, 189-190) — PRD Edge Case 4 hanya menyebut availability float. [VERIFIED]
- **[LOW] WRTGL plumbing tak terdokumentasi:** TRSRC default 'Z' bila TLTXSR blank (94-98); TRBR fallback TLBRN# bila lookup memberi 0 (78-80); TRREFN diisi check# dari slot DCK,X (106-112); remark RMK,X 'R'/'D' → TRDESC (118-125). [VERIFIED]
- **[LOW] PUTIBT sengaja TIDAK mengosongkan TRDESC** (baris 17 di-comment, tag I0064) — deskripsi jurnal GL terbawa ke record IBT; TRSTAT='I' selama IBT lalu reset (11, 116). [VERIFIED]
- **[LOW] LBRUSE:4-6 LOGSW toggle** '0'→'1' tanpa efek lain di member ini — state flag yang konsumennya di luar copy member, tidak dijelaskan. [UNKNOWN konsumen]

### Contradictions

1. **BR-FLT-3 vs #CRTFLT:28-35** — arah negasi float terbalik (lihat spot-check #9). Paling serius.
2. **BR-CUR-3 vs #FNDCUR:21-27** — mekanisme '***' tidak pernah kejadian di elemen yang diproses.
3. **Flow mermaid vs BR-CUR-6** — diagram §3 menaruh "LODEXC + FNDCUR — pilih mata uang & rate" sebagai node hidup di jalur runtime, padahal BR-CUR-6 + Edge Case 6 bilang FNDCUR mati ([ARTIFACT]). Dokumen menyangkal dirinya sendiri; pembaca flow-only akan mem-port FNDCUR.
4. **Flow mermaid vs call-site FNDBOP** — diagram menempatkan FNDBOP sebelum cabang kurs; faktanya FNDBOP di-EXSR dari dalam WRTGL (147) DAN dari dispatcher per-application (tltran:663, 1076, 1346). Urutan di diagram bukan urutan kode.
5. **Frontmatter counts vs body markers** (inferred 9≠1, artifact 3≠1) — lihat Marker honesty.

### Ambiguous rules (8 BR paling load-bearing)

| BR | Masalah testability |
|---|---|
| BR-AMT-4 | "di luar itu operand = 0" tidak memisahkan perilaku NO1 (operand 0) vs NO2/NO3 (stage skipped). Test `21*xx` vs `xx*21` memberi hasil beda — PRD tidak bisa memprediksinya. |
| BR-AMT-6 | Tidak menyebut bahwa `MOVE` (bukan Z-ADD) berarti buffer TLF (17,0) di-reinterpretasi dengan 2 digit terakhir sebagai desimal — kunci porting yang hilang; "(19,2)" saja tidak cukup untuk reproduksi bit-exact. |
| BR-AMT-7 | "urutan operasi mempengaruhi pembulatan" benar tapi tak teruji: tidak ada contoh, tidak disebut bahwa intermediate (25,9) TIDAK di-round antar tahap (Z-ADD tanpa H di 55/80/127), hanya hasil akhir H. |
| BR-CUR-4 | "rate dari buffer (TLFXL0/1/2)" ambigu: TLFXLn menunjuk slot buffer yang berisi **nilai rate itu sendiri** (`MOVE TLF,TLFXL1 CRE,X`, FNDCUR:48), bukan rate number. Dua interpretasi memberi kurs beda total. |
| BR-FLT-5 | Pemetaan bucket→param tidak dieja: local→TLXFT2, foreign→TLXFT3, on-us→TLXFT1 (urutan 2/3/1, bukan 1/2/3) — tanpa ini tester salah pasang kategori. |
| BR-GL-4 | "setiap panggilan IBT" benar per-call, tapi tanpa dokumentasi kondisi pemanggilan (region/tipe cabang/888) total kaki tidak bisa diprediksi. |
| BR-GL-6 | Tidak menyebut mutasi DC,X permanen; juga fail path GLPAR3 not-found (arah lama dipertahankan) tidak dinyatakan. |
| BR-MSC-4 | "bila ketemu, cabang transaksi diganti cabang rekening" — ACCTBR yang dipakai adalah field hasil chain TLBRN2 atau nilai kerja yang sudah ada? (KYBRN2 = TLBRN#+ACCTBR, jadi ACCTBR justru bagian kunci; yang di-MOVE balik adalah ACCTBR yang sama). Kalimatnya menyembunyikan bahwa mapping-nya cuma existence-check. |

### Scorecard

| Dimensi | Nilai | Alasan |
|---|---|---|
| Completeness | **PARTIAL** | 16 member tercakup, tapi wilayah IBT-generation (WRTGL:184-255) + amount override absen — itu inti modul. |
| Accuracy | **PARTIAL** | 8/12 citation EXACT, namun 2 rule arah-uang salah (BR-FLT-3, BR-CUR-3). |
| Consistency | **PARTIAL** | Flow diagram kontradiksi dengan BR-CUR-6 & call-site FNDBOP; frontmatter counts tak cocok body. |
| Unambiguity | **PARTIAL** | Mayoritas rule tajam; 8 item di atas butuh pengetatan (terutama NO1-vs-NO2/3 dan TLXFLn). |
| Testability | **PARTIAL** | Formula & fallback bisa dites; tapi tanpa spesifikasi MOVE-semantics (19,2) dan matriks IBT, golden test tak bisa ditulis lengkap. |
| Traceability | **PASS** | Setiap rule bercite file:line dan hampir semua menunjuk baris yang benar; dead-code diberi tag. |
| Dependency clarity | **PASS** | depends_on + daftar tabel input + program eksternal (DM91028) dieja; KEYGRF/BRNDAY komposisinya di tltran, wajar untuk copy member. |
| Edge-case coverage | **PARTIAL** | 9 gotcha bagus (silent no-op, suspense, float skip), tapi miss: float negatif, LODEXC overflow, DC,X mutation, IBT amount override. |
| AI-readability | **PASS** | Tabel rule + ID stabil + mutability tier + flow; agent bisa mengonsumsi. |
| Implementation readiness | **FAIL** | Dengan BR-FLT-3 terbalik dan matriks IBT hilang, implementasi 1:1 dari PRD ini menghasilkan tanda float salah dan kliring antar-cabang tidak lengkap. Dua item itu blocker. |

### Missing-info list

1. Semantik lengkap blok IBT WRTGL:184-255 (region, tipe cabang M/S, TLSVBR=888, patch MEDAN SAVTY1) — perlu ditulis sebagai rule set sendiri.
2. Override amount IBT via TLMMCA (WRTGL:186-189) — arti bisnis slot itu apa? [UNKNOWN]
3. Definisi field `AMT` (induk *LIKE untuk AMOUNT/ADDF/OPRAND) — presisinya tidak ditemukan di source set; menentukan overflow behavior formula. [UNKNOWN]
4. Konsumen LOGSW (LBRUSE:4-6). [UNKNOWN]
5. Duplikasi blok IBT inline di tltran (874-909, 1181-1217 dst.) — identik dengan WRTGL atau divergen? Perlu diff per lane. [NEEDS_VALIDATION]
6. Rekonsiliasi angka frontmatter (verified/inferred/artifact) dengan marker body. [NEEDS_VALIDATION]

---

## MODULE 2 — satellite-programs.prd.md

### Verdict ringkas

Citation quality-nya paling tinggi dari yang saya audit — 11/12 spot-check EXACT, formula bunga & basis 360/365 dikutip persis, dan PRD jujur soal JHDATC yang hilang ([OPEN]) dan CD0215 tanpa error code. Tapi PRD **melewatkan kelas bug paling berbahaya di file ini: state basi antar panggilan**. CD0215 tidak pernah set *INLR dan mengevaluasi CDRTT2/RATE/METHOD/YRBASE **sebelum** chain CDMAST (chain-nya cuma ada di branch ELSE) — jadi keputusan tier-bypass dan rate-nya memakai record milik PANGGILAN SEBELUMNYA; DD0215 tidak me-reset SAVDT/SAVRAT per call sehingga adjustment bisa di-skip diam-diam untuk rekening berikutnya. BR-SAT-10 versi CD0215 sebagaimana ditulis PRD tidak menggambarkan yang benar-benar dieksekusi. Untuk rumus [LOCKED] "harus 1:1", ini temuan yang wajib masuk dokumen sebelum ada yang berani port.

### Citation spot-check (12)

| # | Claim | Citation | Grade | Catatan |
|---|---|---|---|---|
| 1 | BR-SAT-1 rumus simple & compound harian | DD0215:243-267; CD0215:161-191 | **EXACT** | Simple: `ACCBAL×TRATE×CTR÷(360|365)` (261-267); compound: loop `COMINT=ACCBAL×TRATE÷basis; ACCBAL+=COMINT` (247-257). CD identik (161-189). [VERIFIED] |
| 2 | BR-SAT-2 kode tahun 2→360, else 365 | DD0215:249-253, 263-267; CD0215:169-173, 185-189 | **EXACT** | YEARCD (DDPAR2) / YRBASE (CDMAST). [VERIFIED] |
| 3 | BR-SAT-3 hari ≤0 → nol | DD0215:236-238; CD0215:157 | **EXACT** | [VERIFIED] |
| 4 | BR-SAT-4 eff ≥ posting → '4' | DD0215:109-113 | **EXACT** | `EFFD IFGE POSTD7`. [VERIFIED] |
| 5 | BR-SAT-5 peta error '1'-'4' | DD0215:104, 111, 124, 140 | **EXACT** | Keempat assignment persis di baris itu. [VERIFIED] |
| 6 | BR-SAT-7 rate master lalu ditimpa histori ≤ eff | DD0215:131-133, 156-170 | **EXACT** | JHKEY=PRIRT#+DP2CUR → JRCRAT; loop DDHISTLA timpa TRATE/SAVRAT bila TRDATE≤EFFD. [VERIFIED] |
| 7 | BR-SAT-10 tier bypass | DD0215:148-154, 217-218; CD0215:63-70, 140 | **SUPPORTS-BUT-IMPRECISE** | Baris benar & klaim DD0215 benar (TRATE sudah = RATE di 147). Tapi untuk CD0215 klaim "akrual sekali dengan rate master" TIDAK terjadi: `EXSR ACCRUE` (67) jalan **sebelum** `Z-ADDRATE TRATE` (68), dan CDRTT2/RATE/METHOD/YRBASE saat itu masih isi record panggilan sebelumnya (chain CDMAST baru ada di ELSE, baris 72). Lihat Undocumented #1. |
| 8 | BR-SAT-11 fallback rate CD 3 tingkat | CD0215:83-108 | **EXACT** | BRATE=CHNRAT (≤eff, last wins), ARATE=CHORAT (pertama >eff), lalu master. [VERIFIED] |
| 9 | BR-SAT-12 siklus open/*CLOSE + LR | DD0215:77-98; tltran:2358-2359 | **EXACT** | FIRST flag (77-88), '*CLOSE'→GOTO SETLR (90-98, SETLR 225-226); dispatcher `MOVE '*CLOSE '` + CALL (2358-2359). [VERIFIED] |
| 10 | BR-SAT-13 pindah ke LF filter 151 (2021, HD156063) | DD0215:30, 38, 158, 169, 179, 215; DDHISTLA:14-24 | **EXACT** | Semua baris ADE1 cocok; DDHISTLA `S TRANCD COMP(EQ 151)` di baris 35. [VERIFIED] |
| 11 | BR-DATE-2 pivot abad dari UM9005 key 'JHDATI', fallback 50 | JHDATI:98-107, 15-16, 27-29 | **EXACT** | `N99 Z-ADDUMNUM NUM` / `99 Z-ADD50 NUM`; baris lama `YER IFLT 50` tinggal komentar (102). [VERIFIED] |
| 12 | BR-DM-1 DM91028 interface 23/'D' vs 30/'C' by huruf pertama deskripsi | DM91028:53-66 | **EXACT** | `%SUBST(UMDESC:1:1)='D'` → 23/D else 30/C; kunci GLINT1 6 field. [VERIFIED] |

Skor: 11 EXACT · 1 SUPPORTS-BUT-IMPRECISE · 0 WRONG.

### Marker honesty (sampel 8)

1. BR-SAT-1 [LOCKED] — formula **HONEST** dan layak LOCKED. Tapi kata "pembulatan" per hari kurang presisi: `DIV` tanpa H = **truncation**, pada presisi COMINT = *LIKE ACCRUE (15,5) di DD0215 (DDFREF:214) dan *LIKE ACCINT (17,5) di CD0215 (CDFREF:53). Jadi kuantisasi harian = potong di 5 desimal, bukan rounding. Untuk mandat "harus 1:1", beda round-vs-truncate itu material.
2. BR-SAT-2 [LOCKED] — **HONEST**, persis.
3. BR-SAT-6 fallback DDTNEW — **HONEST** (DD0215:119-126; DM91028:53-54; DM91033:34-35 semua cocok).
4. BR-SAT-9 kode 151 — **HONEST**; bonus yang terlewat: header DDS DDHISTLA baris 21 berkomentar "SELECT TRANCD = **169**" padahal select sebenarnya 151 — jebakan dokumentasi di source yang layak dicatat.
5. BR-DATE-3 [INFERRED] MOD-4-only — **HONEST**, dan sebetulnya bisa dinaikkan VERIFIED (JHDATI:81-87 `DIV 4` + `MVR`, tidak ada tes 100/400; JHDATO:31-32 sama). Catatan tambahan: leap dites pada **tahun 2 digit** sebelum pivot abad — jadi '00' selalu dianggap kabisat terlepas jadi 1900 atau 2000.
6. BR-DM-5 MR Mei 2026 — **HONEST** (DM91033:14-16, V 2.16.T MR 26/5).
7. §4 [OPEN] JHDATC tidak ada di source set — **HONEST**, call site DD0215:138, 204 & CD0215:57, 128 terverifikasi.
8. BR-SAT-10 (CD0215) — **DISHONEST-BY-ERROR**: disajikan verified padahal path yang dieksekusi berbeda (stale state, urutan accrue-sebelum-set-rate).

Frontmatter: `locked_count: 1` tapi body punya **dua** [LOCKED] (BR-SAT-1 dan BR-SAT-2) — kontradiksi angka. `inferred_count: 6` vs 1 [INFERRED] visible + [OPEN] 1 vs `open_count: 5` (OQ ada 5, konsisten kalau open=OQ; tapi [OPEN] §4 tidak jelas terhitung di mana). [NEEDS_VALIDATION]

### Undocumented behavior (severity-tagged)

- **[HIGH] CD0215 hidup lintas panggilan dan branch tier memakai data basi.** CD0215 tidak pernah SETON LR (RETRN saja, baris 144) → program tetap aktif, semua variabel & record buffer CDMAST bertahan. Cek tier `CDRTT2 IFNE *ZEROS` (66) dieksekusi **sebelum** chain CDMAST apa pun (chain hanya di ELSE, baris 72) → keputusan tier untuk transaksi N memakai record transaksi N−1. Di path tier: `EXSR ACCRUE` (67) memakai TRATE, METHOD, YRBASE basi, baru setelahnya `Z-ADDRATE TRATE` (68). Panggilan pertama dalam job aman (semua nol → ELSE), sesudah itu perilakunya history-dependent. PRD gotcha 5 hanya menandai DD0215 sebagai "bukan fungsi murni". [VERIFIED]
- **[HIGH] DD0215: SAVDT & SAVRAT tidak di-reset per panggilan.** Hanya `*LIKE DEFN` (73-74); SAVDT di-set pertama kali di loop kedua (200). Panggilan berikutnya: guard `TRDATE IFGT SAVDT` (197) membandingkan dengan tanggal adjustment REKENING SEBELUMNYA → perubahan rate yang lebih tua bisa di-skip tanpa jejak. SAVRAT juga basi bila rekening tidak punya record 151 ≤ eff-date (loop pertama tidak menyentuhnya) → selisih rate di loop kedua dihitung terhadap rate rekening lain. [VERIFIED — jalur kode; frekuensi kejadian produksi = NEEDS_VALIDATION]
- **[MEDIUM] Parameter CD0215 mismatch panjang:** dispatcher mendeklarasikan `ADJST2 112` (11,2 — tltran:295) sedangkan CD0215 mendeklarasikan `ADJ 152` (15,2). CALL by-reference dengan definisi beda panjang = kelas decimal-data-error/korupsi klasik AS/400. AMOUNT (caller) vs `AMT 152` juga belum terverifikasi cocok (definisi AMT tidak ada di source set). [NEEDS_VALIDATION di mesin]
- **[MEDIUM] Parameter "tanggal posting" CD0215 sebenarnya diberi NEXTDT.** Dispatcher (tltran:289-295) mengirim NEXTDT (next processing date) ke parm POST6; DD0215 memakai POSTDT untuk periode utama tapi NEXTD7/NEXTDT untuk adjustment (136-137 vs 202-203). Tabel §4 PRD menulis "tanggal posting" untuk CD0215 — basis hari yang berbeda satu hari mengubah bunga. [VERIFIED]
- **[MEDIUM] DD0215: seluruh validasi tanggal di-gate `TREFF6 IFNE *ZERO` (100).** Eff-date 0 → tanpa error '3'/'4', EFFD memakai nilai basi/nol, proses lanjut ke chain rekening. [VERIFIED]
- **[MEDIUM] DD0215 loop kedua punya guard "bad date" (186-189):** record 151 dengan TRDATE > NEXTD7 atau = 0 dilewati; loop PERTAMA tidak punya guard itu → record 151 bertanggal 0 justru bisa menimpa rate awal (163: 0 ≤ EFFD selalu true). Asimetri tak terdokumentasi. [VERIFIED]
- **[MEDIUM] JHDATO tidak menolkan output saat error dan tidak set LR** — pada error '1' TODS tetap berisi hasil konversi panggilan sebelumnya; caller yang lupa cek DTOERR menerima tanggal valid-tapi-salah. JHDATI menolkan hanya pada error '1', tidak pada error format '0'. PRD BR-DATE-4/5 menyiratkan simetri yang tidak ada. [VERIFIED]
- **[LOW] JHDATI chain UM90005I setiap panggilan** (98-99) — pivot dibaca ulang per konversi, file dibuka permanen (RETRN tanpa LR); relevan untuk kinerja EOD & untuk caching di rebuild. [VERIFIED]
- **[LOW] DDHISTLA DDS: komentar "SELECT TRANCD = 169" (baris 21) vs select sebenarnya 151 (baris 35)** — perangkap bagi pembaca dokumen/DDS. [VERIFIED]
- **[LOW] DM91033: bila rekening tak ketemu, OACST/OACCF dibiarkan apa adanya tanpa indikator error** (36-39); kontrak "diam bila gagal" hanya didokumentasikan untuk DM91028 (BR-DM-3), padahal berlaku juga di sini, dan lookup DDPAR3 jalan terus meski rekening tidak ada (41-44). [VERIFIED]
- **[LOW] DM91028 chain DDMAST hanya dengan nomor rekening** (partial key, 53) — tipe rekening tidak ikut kunci; kalau satu nomor punya >1 tipe, record pertama yang menang. [VERIFIED — dampak: NEEDS_VALIDATION]

### Contradictions

1. **BR-SAT-10 (CD0215) vs urutan eksekusi nyata** — lihat Undocumented #1. PRD menulis intent penulis (komentar SSB), bukan behavior.
2. **`locked_count: 1` vs dua rule [LOCKED]** di body.
3. **§4 CD0215 "tanggal posting" vs NEXTDT** yang benar-benar dikirim dispatcher.
4. **Flow §3 menggabungkan DD0215/CD0215 ke satu node error '2'/'3'/'4'** — CD0215 tidak punya parameter error sama sekali (PRD sendiri bilang begitu di gotcha 4); diagram menyesatkan untuk CD-lane.
5. **Gotcha 3 & OQ-SAT-2 menyebut "pembulatan tiap hari"** — kodenya truncation (DIV tanpa half-adjust) pada 5 desimal; "pembulatan" vs "pemotongan" menghasilkan angka regresi beda.

### Ambiguous rules (8 load-bearing)

| BR | Masalah testability |
|---|---|
| BR-SAT-1 | Unit rate tidak dispesifikasi: `saldo×rate÷basis` tanpa ÷100 → rate tersimpan sebagai apa (persen? fraksi?) menentukan hasil 100×. JRCRAT = REFFLD(RATE), definisi RATE tidak di source set. [UNKNOWN] |
| BR-SAT-1 | Presisi kuantisasi harian tidak disebut ((15,5)/(17,5), truncate) — tanpa ini "replicate loop persis" tidak bisa diverifikasi. |
| BR-SAT-4/5 | Tidak dinyatakan bahwa validasi ini **DD0215-only**; CD0215 menerima eff-date masa depan tanpa protes (hasil 0 via CTR≤0, tak terbedakan dari sukses). |
| BR-SAT-7 | "perubahan rate historis yang berlaku pada/sebelum tanggal efektif" — yang menang record TERAKHIR dalam urutan kunci (TRACCT/TRATYP/TRDATE), loop timpa terus; kalau ada 2 perubahan di tanggal sama, urutan fisik menentukan. Tidak diterakan. |
| BR-SAT-8 | Periode adjustment = tanggal perubahan → **NEXTDT**, periode utama = eff → **POSTDT**; PRD bilang "periode tersisa" tanpa menyebut dua anchor tanggal beda — potensi off-by-one-day sistemik saat port. |
| BR-SAT-11 | "yang pertama ditemui" untuk ARATE benar, tapi BRATE justru last-wins; asimetri first-vs-last tidak dieja. |
| BR-DATE-2 | Ambang dibandingkan `IFLT` (strictly less) — tahun == ambang jatuh ke 1900-an; "≥ ambang → 1900-an" di PRD benar, tapi nilai tepi (misal ambang 50, tahun '50' → 1950) layak dicontohkan untuk test. |
| BR-DM-1 | "huruf pertama deskripsi" — deskripsi yang mana (parm UMDESC datang dari mana di caller UM9005 record)? Case-sensitivity ('d' kecil → jalur Credit!) tidak dinyatakan. |

### Scorecard

| Dimensi | Nilai | Alasan |
|---|---|---|
| Completeness | **PARTIAL** | 6 program tercakup rapi, tapi kelas state-antar-panggilan (CD0215 keseluruhan, DD0215 SAVDT/SAVRAT) absen — dan itu perilaku finansial, bukan trivia. |
| Accuracy | **PASS** | 11/12 EXACT; satu-satunya miss (BR-SAT-10 CD) adalah baca-intent-bukan-eksekusi, sisanya presisi tinggi. |
| Consistency | **PARTIAL** | locked_count vs body; flow error-node CD; "posting" vs NEXTDT. |
| Unambiguity | **PARTIAL** | Rumus jelas, tapi unit rate, presisi truncation, dan dua anchor tanggal tidak dieja. |
| Testability | **PARTIAL** | Error map DD0215 & pivot abad langsung bisa jadi test; rumus bunga belum — butuh unit rate + presisi + JHDATC. |
| Traceability | **PASS** | Citation terbaik di batch ini; dead code (KTW, referensi DDHIST lama) ditandai per baris. |
| Dependency clarity | **PASS** | Tabel §4 per program + [OPEN] JHDATC eksplisit; file dibaca cocok dengan F-spec semua program. |
| Edge-case coverage | **PARTIAL** | Gotcha bagus (kabisat, pivot 50, CD tanpa error, DM huruf pertama), tapi state-basi — kelas bug termahal — lolos. |
| AI-readability | **PASS** | Struktur konsisten dengan PRD lain, ID stabil, mutability jelas. |
| Implementation readiness | **PARTIAL** | Boleh mulai port JHDATI/JHDATO/DM9102x dari PRD ini; DD0215/CD0215 JANGAN sebelum: (a) JHDATC didapat, (b) semantik state-basi diputuskan (replikasi bug atau fix sadar), (c) unit & presisi rate dikunci. |

### Missing-info list

1. **Source JHDATC** — sudah OQ-SAT-1 [P1]; menggantung semua angka bunga. [OPEN]
2. Definisi field `RATE` (REFFLD induk JRCRAT/CHNRAT/CHORAT) → unit & skala rate. [UNKNOWN]
3. Keputusan bisnis atas dua bug state-basi (CD0215 tier stale, DD0215 SAVDT carry-over): direplikasi 1:1 atau diperbaiki dengan disclosure? Perlu jadi OQ P1 baru. 
4. Verifikasi mismatch panjang parm ADJST2(11,2)↔ADJ(15,2) dan AMOUNT↔AMTI/AMT(15,2) di mesin nyata. [NEEDS_VALIDATION]
5. Asal & nilai sah UMDESC yang dikirim ke DM91028 (tabel UM9005 'BYMHD.TC' — daftar deskripsinya). [UNKNOWN — nyambung OQ-SAT-5]
6. DDPAR1 POSTDT/NEXTDT semantics (kontrol harian) — dipakai sebagai anchor dua periode beda; definisi bisnis kedua tanggal itu tidak ada di PRD mana pun yang saya audit. [NEEDS_VALIDATION lintas-modul]
