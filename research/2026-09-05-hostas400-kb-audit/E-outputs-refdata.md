# Lane E — Audit: transaction-output-files.prd.md & reference-data.prd.md

Auditor lane E, 2026-09-05. Semua klaim di bawah dicek langsung ke source di `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/Host-AS400-Batch/` (read-only). Label: [VERIFIED] = dicek langsung ke file:line; [INFERRED] = disimpulkan dari bukti tak-langsung; [UNKNOWN] = tidak bisa dipastikan dari source set; [NEEDS_VALIDATION] = butuh konfirmasi manusia/sistem.

---

# MODULE 1 — `transaction-output-files.prd.md`

## 1.1 Verdict ringkas

**Kuat. Citation discipline-nya termasuk yang terbaik yang pernah saya spot-check di KB ini** — 12 sampel: 9 EXACT, 3 SUPPORTS-BUT-IMPRECISE, 0 WRONG. Semua 10 file output yang benar-benar ditulis `qrpgsrc.tltran` ter-cover, tidak ada orphan. Kelemahan nyata: (a) BR-OUT-4 salah setengah — STVALU diisi untuk kode **sell DAN purchase**, bukan "beli/purchase" saja; (b) BR-OUT-10 menyembunyikan dimensi ketiga float (on-us) dan 4 dari 6 write-site CRTFLT; (c) frontmatter `inferred_count: 10` dan `artifact_count: 2` tidak punya satu pun marker [INFERRED]/[ARTIFACT] di body (bookkeeping bohong kecil); (d) OQ-OUT-2 kini SEBAGIAN terjawab oleh `FILE REF/` (lihat §1.5).

## 1.2 Citation spot-check (12 sampel)

| # | Klaim | Sitasi | Grade | Bukti |
|---|---|---|---|---|
| 1 | BR-OUT-1 DDTELT mapping (status 'A', stack '+' closeout, batch increment, source default 'Z', key BATCH+SEQ) | QDDSSRC.DDTELT:4-36; tltran:595-751 | **EXACT** | Blok DD mulai 595 (`TLAP,X WHEQ 'DD'`), TRSTAT 'A' 598, '+' closeout 599-600, `ADD 1 BATCH` 605, source 'Z' 618, `WRITERDDTELT` 751; DDS K BATCH/SEQ :35-36 [VERIFIED] |
| 2 | BR-OUT-2 CDTELT + backdated 250/251 | CDTELT:10-36; tltran:1026-1114, 1225-1253 | **EXACT** | `WRITERCDTELT` 1114 & 1253; CALL CD0215 1228; kode 250/251 1238/1240; DDS fields 10-34, K 35-36 [VERIFIED] |
| 3 | BR-OUT-3 LNTELT + "backdated → LN1200, komentar tltran:1565" | LNTELT:3-33; tltran:1276-1413 | **EXACT** | Komentar `BACKDATED ACCRUAL ADJUSTMENTS ARE HANDLED BY LN1200` persis di baris 1565; `WRITERLNTELT` 1413; LTREV 'Y' 1384 [VERIFIED] |
| 4 | BR-OUT-4 SRTELT "value hanya untuk kode beli/purchase" | SRTELT:4-19; tltran:1587-1642 | **SUPPORTS-BUT-IMPRECISE** | Range benar (`WRITERSRTELT` 1642), TAPI kondisi STVALU = `TXCD IFEQ TLSRSE OREQ TLSRPU` (tltran:1633-1635). TLSRSE = "Share **sel** Txcd", TLSRPU = "Share pur Txcd" (FILE REF/qddssrc.TLFREF:1135,1137). Jadi value diisi untuk **sell ATAU purchase** — PRD hilang setengah kondisi [VERIFIED] |
| 5 | BR-OUT-5 GLTELT + "system code 'TL' (IBT) / blank (cash)" | GLTELT:2-39; tltran:1867-1991; #WRTGL:34-160 | **SUPPORTS-BUT-IMPRECISE** | Range & lookup 2-tingkat + suspense 999 benar (#WRTGL:51-70). Tapi TRSYS='TL' di-set BUKAN hanya jalur IBT: #WRTGL:89 (jalur GL app & RPV) juga 'TL'; PUTIBT:21 'TL'; blank hanya di CS (tltran:1923) dan RC-GL (tltran:2136). Framing "'TL' (IBT)" menyesatkan untuk rebuild [VERIFIED] |
| 6 | BR-OUT-6 GLTELS dipakai bila summarize 'Y' + generator IBT | GLTELS:2-47; tltran:1986-1991; #PUTIBT:78, 111 | **EXACT** | `TLGSUM IFEQ 'Y' → WRITERGLTELS` 1986-1988; `WRITERGLTELS` persis di #PUTIBT:78 dan :111 (dua kaki IBT). Key 8-kolom DDS :40-47 match §4 [VERIFIED] |
| 7 | BR-OUT-7 RCTELL batch 222, 'D' normal/'C' koreksi "DEL LATER", UNIQUE | RCTELL:4-16; tltran:2309-2329 | **EXACT** | `Z-ADD222 RTBCH#` 2313; TLBCOR≠'Y'→'D' / else 'C' + komentar DEL LATER 2320-2323; payee ← TLBPNM 2326; UNIQUE RCTELL:3 [VERIFIED] |
| 8 | BR-OUT-8 DDTELS SEQ3=0 "must be calculated when merged", expire = posting + hari param, rollover 365 | DDTELS:6-30 (komentar baris 6); tltran:917-1002 | **EXACT** | Komentar persis DDTELS:6; `MOVE *ZEROS SEQ3` + "CREATE LATER" 931/974; TLMLDY/TLMNDY + rollover >365 → +1000 di 948-956/991-997; RECID A/D 926-928 [VERIFIED] |
| 9 | BR-OUT-9 CFTPNT ditulis 3 titik (DD/CD/LN) bila RMK='N' | CFTPNT:3-16; tltran:674-684, 1087-1097, 1388-1398 | **SUPPORTS-BUT-IMPRECISE** | Tiga site benar, tapi ada site KE-EMPAT yang tidak dikutip: tltran:1428-1438 (jalur LN non-reversal, `WRITERCFTPNT` 1438). Konsumen yang menghitung volume record dari PRD akan salah [VERIFIED] |
| 10 | BR-OUT-10 DDTFLT "kategori LC/IB, avail vs accrual" | DDTFLT:2-9; #CRTFLT:55-67 | **SUPPORTS-BUT-IMPRECISE** | FORMAT(DDFLOT) benar (DDTFLT:3). Tapi CRTFLT menulis **6** varian record: {local, foreign, **on-us**} × {avail, accrual} — write di #CRTFLT:67, 87, 125, 144, 182, 201. PRD hanya menyebut 2 dimensi & mengutip 1 write-site; dimensi on-us (ONUS, :155-205) hilang total [VERIFIED] |
| 11 | BR-HIST-1 LNHISTL3 DORC DESCEND untuk reversal match | LNHISTL3:4-13; tltran:344-360, 1369-1420 | **EXACT** | `K LHDORC DESCEND` persis :10; KLIST LNHKY1 345-354 (XDORC='C', XAFFT='Q'); CHAIN 1369 + REDPERLNHIST loop 1372-1419 [VERIFIED] |
| 12 | BR-HIST-2 + OQ-OUT-3: DDHISTLA dibuat 2021 (HD156063), komentar lama "TRANCD=169" usang, implementasi filter 151 | DDHISTLA:18-35, :21, :22-24; DD0215:158-169 | **EXACT** | Komentar "SELECT TRANCD = 169" persis DDHISTLA:21; `S TRANCD COMP(EQ 151)` :35; HD156063 :16; DD0215 CHAIN/READE DDHISTLA :158/:169. Detail forensik kelas ini jarang — nilai plus besar [VERIFIED] |

Bonus dicek: BR-HIST-6 DDTNEW:13-257 + DD0215:121-122 (fallback chain) = EXACT; gotcha 2 header tltran:31-37 = EXACT; §4 "SRTELT tanpa K" = EXACT (DDS memang tanpa K).

## 1.3 Marker honesty (8 sampel)

Body PRD ini praktis tidak memakai marker confidence eksplisit di tabel (kolom Confidence kosong = implisit verified). Sampel 8 klaim yang tampil sebagai fakta-terverifikasi:

| Klaim | Honest? |
|---|---|
| BR-OUT-1 s/d BR-OUT-3 (mapping DD/CD/LN) | ✅ semua tervalidasi ke code [VERIFIED] |
| BR-OUT-7 RCTELL UNIQUE + payee | ✅ [VERIFIED] |
| BR-OUT-8 [LOCKED] SEQ3-kontrak | ✅ satu-satunya [LOCKED], dan memang layak — komentar DDS + code dua-duanya menulis 0 [VERIFIED] |
| Gotcha 3 (DESCEND memilih transaksi reversal) | ✅ [VERIFIED] |
| Gotcha 7 [OPEN] DDTFLT format tidak ada di source set | ✅ jujur, dan kini resolvable (lihat §1.5) |
| §4 key table (16 baris) | ✅ dicek semua terhadap DDS K-specs — 16/16 match, termasuk GLTELS 8-kolom [VERIFIED] |

**Defect bookkeeping**: frontmatter `inferred_count: 10`, `artifact_count: 2` — grep body: **0** kemunculan `[INFERRED]` dan `[ARTIFACT]` [VERIFIED]. Angka frontmatter tidak bisa direkonsiliasi dengan body; kalau angka itu dihitung dari granularity lain, tidak ada jejaknya. [NEEDS_VALIDATION — regenerate counts]

## 1.4 Coverage cross-check (F-spec vs PRD)

F-spec `qrpgsrc.tltran:64-96` — file yang DITULIS program (O atau IF+A dengan WRITE):

| File (F-spec) | WRITE site | Di PRD? |
|---|---|---|
| DDTELT (O, :70) | 751, 794, 2299 | ✅ BR-OUT-1 (site RC-funded-DDA 2299 implisit lewat dispatcher PRD) |
| CDTELT (O, :71) | 1114, 1253 | ✅ BR-OUT-2 |
| LNTELT (O, :72) | 1413, 1456 | ✅ BR-OUT-3 |
| GLTELT (IF A, :73) | #WRTGL:158, tltran:1990, 2180 | ✅ BR-OUT-5 |
| GLTELS (IF K A, :74) | #WRTGL:156, #PUTIBT:78/111, tltran:1988, 2178 | ✅ BR-OUT-6 |
| RCTELL (O, :75) | 2329 | ✅ BR-OUT-7 |
| DDTELS (O, :76) | 958, 1002 | ✅ BR-OUT-8 |
| CFTPNT (O, :77) | 684, 1097, 1398, **1438** | ✅ BR-OUT-9 (site ke-4 tidak dikutip) |
| DDTFLT (O, :81) | #CRTFLT ×6 | ✅ BR-OUT-10 (4 site + on-us tidak disebut) |
| SRTELT (O, :89) | 1642 | ✅ BR-OUT-4 |
| TLLOG (UF, :65) | UPDAT 542 | ✅ di dispatcher PRD (boundary benar) |

**Tidak ada file output yang lolos; tidak ada orphan** (semua entri §2A benar-benar target WRITE). [VERIFIED]

Catatan kecil: (a) GLTELT/GLTELS dideklarasi `IF ... A` (input-with-add) plus dummy READ di tltran:2364-2368 — quirk RPG yang membuat WRITE legal; PRD tidak menyebut, tidak fatal tapi berguna untuk pembaca rebuild. (b) CDHIST dinyatakan "dibaca batch" tapi tanpa read-site — read aslinya di CD0215:79/95/117/137 (`READERCDHIST`) [VERIFIED]; sitasi hilang.

## 1.5 FILE REF resolution (folder baru 2026-09-04)

`FILE REF/` berisi 11 FREF. CDFREF/DDFREF/LNFREF **byte-identik** dengan salinan lama di TLTRAN (cmp) — yang benar-benar baru: TLFREF, GLFREF, RCFREF, CFFREF, SRFREF, JHFREF, BIFREF, RMFREF [VERIFIED].

| Gap di PRD ini | Status pasca-FILE REF | Bukti |
|---|---|---|
| OQ-OUT-2 [P2] — DDFLOT + DDFREF/CDFREF/LNFREF/SRFREF/RCFREF/CFFREF | **SEBAGIAN TERJAWAB** — SRFREF/RCFREF/CFFREF kini ada; DD/CD/LNFREF ternyata sudah ada sejak awal (identik); field float (FLCATG 2, FLDDA7 7,0, FLOTAV 15,2) terdefinisi di DDFREF:1813-1821. **Yang MASIH hilang: DDS file DDFLOT itu sendiri** (urutan record layout) — tipe field bisa, susunan record belum. OQ perlu di-update jadi "tinggal DDFLOT" | [VERIFIED] |
| Tipe field SRTELT (16 field R → SRFREF) | **TERJAWAB** — mis. STACCT 19,0; STCTER 20; SXSMX 1 (SRFREF:53,85,87) | [VERIFIED] |
| Tipe field GLTELT/GLTELS (37+37 field R → GLFREF) | **TERJAWAB** — TRSTAT 1, TRACCT 19,0, TRAMT 17,2 (GLFREF:987,995,1003) | [VERIFIED] |
| Tipe field RCTELL (8 field R → RCFREF; +2 → TLFREF) | **TERJAWAB** — RTBCH# 3,0; RTSEQ# 9,0; RTAMT 11,2; RTCODE 1; RTPAYE 40 (RCFREF:5,78,40,84,85) | [VERIFIED] |
| Tipe field CFTPNT (TPNAME dst → CFFREF/TLFREF) | **TERJAWAB** — TPNAME 40 (CFFREF:1239), CFATYP 1 / CFACC# 19,0 (CFFREF:453,457), TLBID 4S,0 (TLFREF:558) | [VERIFIED] |
| DDTELS/RCTELL field TLBID/TLBSEQ REFFLD(... TLFREF) | **TERJAWAB** — TLFREF ada (1476 baris), TLBID/TLBSEQ terdefinisi | [VERIFIED] |
| DDTNEW BIPEMI REFFLD(BIPEMI BIFREF) | **TERJAWAB** — BIPEMI 3,0 'PEMILIK/DEBITUR' (BIFREF:22) | [VERIFIED] |
| OQ-OUT-1 [P1] konsumen downstream (program posting/merge) | **TIDAK terjawab** — FREF bukan program | [VERIFIED absen] |
| OQ-OUT-3 [P2] arti kode 151/169/222/250/251 | **TIDAK terjawab** — DDFREF TRANCD 3,0 tanpa value-list (DDFREF:711); tidak ada FREF yang mengenumerasi kode transaksi | [VERIFIED] |
| OQ-OUT-4 [P3] SRTELT consumer, OQ-OUT-5 [P3] force-balance V002 | **TIDAK terjawab** (butuh program, bukan DDS) | [UNKNOWN] |

Net: **dari 5 OQ modul ini, 1 turun prioritas jauh (OQ-OUT-2 → tinggal DDFLOT saja), 4 tetap terbuka.** Semua gap "referenced field, type unknown" untuk 10 file output = **resolved** oleh FILE REF.

## 1.6 Ambiguous rules (BR paling load-bearing)

1. **BR-OUT-4 (STVALU)** — teks sekarang bisa dibaca "value = amount hanya saat purchase". Faktualnya sell juga (tltran:1633-1635). Tester yang menulis kasus dari PRD akan menandai record sell ber-STVALU sebagai bug padahal benar. **Perlu koreksi teks.**
2. **BR-OUT-5 "system code 'TL' (IBT) / blank (cash)"** — tidak testable sebagaimana ditulis; kondisi sebenarnya: 'TL' untuk jalur GL-app/RPV/IBT (#WRTGL:89, #PUTIBT:21), blank untuk CS (1923) dan RC-GL (2136).
3. **BR-OUT-10** — "kategori LC/IB" ambigu: FLCATG diisi TLXFT1/2/3 per item-class dan dioverride 'IB' bila IBT (#CRTFLT:62-66 dkk); nilai kategori selain LC/IB tidak dienumerasi → tidak testable tanpa TLTX data.
4. **BR-OUT-1 "nomor batch bertambah per record"** — benar (`ADD 1 BATCH` 605) tapi batch di-reset per TLLOG record (486), bukan global — PRD tidak menyebut reset point; konsumen bisa salah kira monoton sepanjang run.

## 1.7 Scorecard

| Dimensi | Nilai | Alasan |
|---|---|---|
| Completeness | **PASS** | 10/10 file output + 6 history ter-cover; hanya site-level gaps (CFTPNT ke-4, CRTFLT on-us) |
| Accuracy | **PARTIAL** | 9/12 EXACT; BR-OUT-4 salah setengah kondisi; BR-OUT-5 framing 'TL' menyesatkan |
| Consistency | **PASS** | §2 ↔ §4 key table ↔ flow konsisten; tidak ada kontradiksi internal ditemukan |
| Unambiguity | **PARTIAL** | 4 titik ambigu di §1.6; sisanya tajam |
| Testability | **PARTIAL** | Mapping per-field testable; kondisi STVALU/TRSYS/FLCATG butuh koreksi dulu |
| Traceability | **PASS** | Sitasi file:line hampir semua presisi baris; termasuk forensik komentar-usang 169-vs-151 |
| Dependency clarity | **PASS** | Peran penulis/pembaca per file jelas; depends_on benar; downstream jujur di-OQ-kan |
| Edge-case coverage | **PASS** | SEQ3-kontrak, RECID hapus-logis, DESCEND, prefix per-produk — semua edge nyata & benar |
| AI-readability | **PASS** | Tabel padat, ID stabil, mutability tiers jelas |
| Implementation readiness | **PARTIAL** | Blocker eksternal (OQ-OUT-1 konsumen) + koreksi §1.6; field types kini lengkap via FILE REF |

## 1.8 Missing-info list

- Program konsumen downstream (merge hold, posting DD/CD/LN/GL, recon) — OQ-OUT-1 masih blocker [UNKNOWN]
- DDS `DDFLOT` (record layout float) — satu-satunya sisa OQ-OUT-2 [UNKNOWN]
- Enumerasi kode transaksi internal (151/169/222/250/251, TLCD/TCCD per produk) [UNKNOWN]
- Site CFTPNT ke-4 (tltran:1428-1438) & 4 write-site CRTFLT lain + dimensi on-us → perlu ditambah ke BR-OUT-9/10 [VERIFIED, tinggal edit]
- Read-site CDHIST (CD0215:79 dst.) untuk BR-HIST-4 [VERIFIED, tinggal edit]
- Rekonsiliasi frontmatter counts (inferred/artifact) [NEEDS_VALIDATION]

---

# MODULE 2 — `reference-data.prd.md`

## 2.1 Verdict ringkas

**Sitasi juga sangat kuat (11 EXACT dari 12), dan klaim negatif "FREF hilang" dibuktikan dengan cross-check nyata — kelas riset yang bagus.** Tapi ada SATU cacat akurasi yang materiil: **BR-REF-13 + gotcha 6 + OQ-REF-5 menyatakan DDMAST/CDMAST "tidak dikonsultasi batch ini" — padahal satelit DD0215 CHAIN RDDMAST (Qrpgsrc.DD0215:33,119) dan CD0215 CHAIN RCDMAST (Qrpgsrc.CD0215:10,72), dua-duanya DIPANGGIL TLTRAN.** Klaim literal-nya di-scope "qrpgsrc.tltran atau copy member" sehingga selamat secara huruf, tapi basis [INFERRED]-nya ("pencarian di seluruh source... nihil") faktual salah, dan kesimpulan bisnisnya ("validasi rekening terjadi di luar batch ini") terbantahkan: DD0215 menolak backdate dengan ERR '2' bila akun tak ada di DDMAST maupun DDTNEW (DD0215:119-126). Satellite-programs PRD juga tidak menyebut DDMAST/CDMAST — jadi fakta ini hilang dari SELURUH KB [VERIFIED]. Kedua: **OQ-REF-1 kini hampir seluruhnya terjawab oleh FILE REF** (7/7 file yang diminta ada semua). Ketiga: OQ-REF-6 separuhnya ternyata sudah answerable dari DDFREF yang SUDAH ada di source set sejak awal (STATUS 0-9 lengkap dengan arti, DDFREF:81-92) — OQ ini overshoot.

## 2.2 Citation spot-check (12 sampel)

| # | Klaim | Sitasi | Grade | Bukti |
|---|---|---|---|---|
| 1 | BR-REF-1 DDPAR1 satu record kontrol tanggal, dibaca sekali | DDPAR1:5-20; tltran:397 | **EXACT** | Field LASTDT…PAYOPT persis :5-20; `READ DDPAR1` persis :397; pemakaian POSTDT/POSTD7 500-502, 682-683 [VERIFIED] |
| 2 | BR-REF-2 DDPAR3 tabel produk deposit, terpisah dari TLTX | DDPAR3:2-28 | **EXACT** | Komentar "MEMBER SYSTC…" :3, UNIQUE :5, K TRANCD :28; dan memang TIDAK ada F-spec DDPAR3 di tltran [VERIFIED] |
| 3 | BR-REF-3 LNPAR3 dua CHAIN (LTTRAN & LHTRAN) | LNPAR3:4-14; tltran:1357-1420 | **EXACT** | `LTTRAN CHAINLNPAR3` persis 1357; `LHTRAN CHAINLNPAR3` persis 1377; L3RTRN→LTTRAN 1379 [VERIFIED] |
| 4 | BR-REF-4 GLPAR3 4 field, override DORC di PUTIBT tag R003 | GLPAR3:3-8; #PUTIBT:47-53 | **EXACT** | DDS persis 4 field; blok R003 persis #PUTIBT:47-53 (`G3DORC → DC,X`) [VERIFIED] |
| 5 | BR-REF-5 GLGREF key BRANCH+REF#+CURRENCY sejak FC | GLGREF:2-16; #WRTGL:52-71 | **EXACT** (dengan catatan) | K GLBRNI/GLGRF#/GLGCUR (FC) :14-16; lookup 2-tingkat + suspense #WRTGL:52-70. Catatan: nama field di code (TLBRN/TLGACT/TLGCTR/TLGPRD/TLGSUM) ≠ nama DDS (GLBRN/GLGACT/…) karena I-spec rename di QCPYSRC.#DS24:21-30 ("RENAME FIELDS IN GLFREF TO MATCH ORIGINAL NAMES IN TLGREF") — jembatan ini tidak dijelaskan di PRD manapun; pembaca yang diff DDS vs code akan bingung [VERIFIED] |
| 6 | BR-REF-6 GLGRPV key DUBN+CURRENCY, dipakai GENRPV | GLGRPV:6-13; tltran:2381-2384 | **EXACT** | `KYDUBN CHAINRGLGRPV` 2383, `Z-ADDGLGRF# ACCTNO` 2384; K GLDUBN/GLCURR :12-13 (PRD memakai nama code-side DUBN/CURRCY — konsisten dengan klist :382-384) [VERIFIED] |
| 7 | BR-REF-7 GLINT1 dormant di batch ini | GLINT1:20-46; [tidak ada CHAIN] | **EXACT** | Field :20-40 (key sampai :47, off-by-one kecil); tidak ada F-spec/CHAIN GLINT1 di tltran, copybook, maupun satelit [VERIFIED] |
| 8 | BR-REF-8 JHDATA fallback currency | JHDATA:45-46, 53-54; tltran:476-479 | **EXACT** | JDCURR/JDDECI persis :45-46; K JDBANK/JDBR persis :53-54; `MOVE JDCURR TLBCUR` 478 [VERIFIED] |
| 9 | BR-REF-9 JHFXRT 8 jenis rate, JFXRT9/RTA-C/MD6/7/BKC tidak dibaca LODEXC | JHFXRT:7-31; #LODEXC:9-39 | **EXACT** | LODEXC baca persis JFXCOD/DEC/BRT/SRT/MRT/ART/ORT/RT6-8 (:15-36); JFXRT9…JFXBKC ada di DDS :25-31 dan memang tak disentuh. "60 baris" berasal dari kapasitas array CCT/CER (tltran:117,132; CER 480=60×8) — sumber array tidak dikutip, minor [VERIFIED] |
| 10 | BR-REF-10 JHRATE dipakai DD0215 bukan TLTRAN | JHRATE:6-8; DD0215:131-133 | **EXACT** | `JHKEY CHAINRJHRATE` 131, `Z-ADDJRCRAT RATE` 133; tak ada F-spec JHRATE di tltran [VERIFIED] |
| 11 | BR-REF-12 UM90005 3 namespace (TLTX.OVB / MEW.BIN / BYMHD.TC) | UM90005PF:19-28; UM90005I:19-23; tltran:726-730; #GETAM2:119-139 | **EXACT** | 'TLTX.OVB' tltran:727; 'MEW.BIN' #GETAM2:123; 'BYMHD.TC' #GETAM2:136; CHAIN 730/126/139 [VERIFIED] |
| 12 | BR-REF-13 "DDMAST/CDMAST tidak di-CHAIN oleh tltran/copy member; SRMAST dikecualikan (1599)" | DDMAST:16-267; CDMAST:20-218; tltran:1599 | **SUPPORTS-BUT-IMPRECISE → menyesatkan** | SRMAST CHAIN persis 1599 ✓; klaim scoped literal benar ✓; TAPI **DD0215:119 `DDKEY CHAINRDDMAST` dan CD0215:72 `HISKEY CHAINRCDMAST`** — kedua satelit bagian dari source set dan dipanggil TLTRAN (1228, 761, 2359). "Why" kolom ("deposit/CD master dikonsultasi program lain") dan gotcha 6 ("validasi rekening terjadi di luar batch ini [OPEN]") salah arah [VERIFIED] |

Bonus dicek: BR-REF-14 CDFREF:13-893 + status values :36-43 = EXACT (0/1/2/3/4/7/9 persis); §4 ACCTNO/ACTYPE identik di 3 FREF = benar (CDFREF:22-23, DDFREF:70, LNFREF ✓); §4 DDPAR2 "key SCCODE" = **IMPRECISE**: key sebenarnya SCCODE **+ DP2CUR** (DDPAR2:254-255), dan SCKEY di DD0215 memang 2 kfld (SCCODE+DDCTYP, DD0215:65-67).

## 2.3 Marker honesty (8 sampel)

| Marker | Honest? |
|---|---|
| §1 [VERIFIED] "TLFREF dkk tidak ada; grep TLTXCD/TLBID/TRSTAT di 3 FREF, hanya TRSTAT ketemu (DDFREF)" | ✅ direplikasi: TLTXCD 0 hit di CD/DD/LNFREF, TRSTAT hanya di DDFREF — persis seperti diklaim [VERIFIED] |
| §4 [VERIFIED] ACCTNO/ACTYPE identik 3 FREF | ✅ ACCTNO 19,0 di ketiganya [VERIFIED] |
| BR-REF-2 [INFERRED] + dasar (field tak overlap) | ✅ jujur & dasarnya benar |
| BR-REF-7 [INFERRED] GLINT1 dormant + dasar "nol hasil pencarian" | ✅ direplikasi, benar |
| BR-REF-9 [INFERRED] field kurs dorman + dasar perbandingan field | ✅ benar |
| BR-REF-12 [INFERRED] tabel serbaguna + dasar pola 3× | ✅ wajar |
| BR-REF-13 [INFERRED] + dasar "pencarian CHAIN/nama file **di seluruh source**, DDMAST/CDMAST **nihil**" | ❌ **DASAR SALAH** — pencarian seluruh source menemukan CHAIN di DD0215:119 & CD0215:72. Klaim utama selamat karena di-scope, tapi justifikasi [INFERRED]-nya menyatakan sweep yang, kalau benar dilakukan, pasti menemukan dua hit itu [VERIFIED] |
| Frontmatter verified 33 / inferred 6 / intent 39 | ⚠️ body hanya punya ~14 BR + 2 [VERIFIED] prose + 5 [INFERRED]; angka tak bisa direkonsiliasi dengan marker yang terlihat [NEEDS_VALIDATION] |

## 2.4 Coverage cross-check (file DIBACA vs PRD)

Semua file input di F-spec tltran + copybook + satelit:

| File | Read site | Modul yang meng-cover |
|---|---|---|
| DDPAR1, GLGREF, GLGRPV, GLPAR3, LNPAR3, JHDATA, JHFXRT, JHYDAT, UM90005I, SRMAST | tltran/copybooks | ✅ reference-data (benar & tersitasi) |
| JHRATE, DDPAR2, DDMAST, DDTNEW, DDHISTLA | DD0215 | ✅ reference-data / outputs (DDMAST **salah dinyatakan tak dikonsultasi** — lihat §2.2 #12) |
| **CDMAST, CDHIST** | **CD0215:72, 79-137** | ❌ **CDMAST read TIDAK ter-cover di modul manapun** (reference-data bilang tak dikonsultasi; satellite-programs PRD tak menyebut DDMAST/CDMAST sama sekali — grep 0 hit) [VERIFIED] |
| TLTX, TLTXRM | tltran:440, 713-716 | ✅ transaction-parameter-table (boundary) |
| TLLOG, TLTEL, TLBRN1, TLBRN2, TLFLTC, TLFLTCL1, TLMAST (data area) | tltran | ✅ transaction-dispatcher (boundary; source_files-nya memang mengklaim file-file ini) |
| **JHAPAR (external data area, `I EUDSJHAPAR` tltran:208)** — sumber JHICUR (base currency, dipakai 578/582/2378/2414/2497/2506) & JHBNKN (key JHDATA, :322) | tltran | ❌ **TIDAK ter-cover di modul manapun** (grep "JHAPAR" di seluruh KB = 0). Ini reference-data tulen: parameter level-bank. Bonus: dispatcher PRD :106 malah salah menyiratkan JHICUR datang dari DDPAR1 [VERIFIED] |
| GLINT1, DDPAR3 (ada di source, tak dibaca) | — | ✅ dijelaskan jujur sebagai dormant/tak-di-CHAIN |

Orphan check: tidak ada file di source_files PRD yang fiktif. CDFREF/DDFREF/LNFREF sah sebagai "sumber definisi field".

## 2.5 FILE REF resolution

| Gap di PRD ini | Status pasca-FILE REF | Bukti |
|---|---|---|
| **OQ-REF-1 [P1]** — minta TLFREF, GLFREF, RCFREF, CFFREF, SRFREF, JHFREF, BIFREF | **TERJAWAB 7/7** — semuanya ada di `FILE REF/`. Spot: TLFREF 1476 baris — TLTXCD 4,0 (:54), TLBID 4S,0 (:558), TLBTCD 4S,0 (:559), TLBSEQ 4,0 (:596), TLCSHA 19,0 (:20), TLISVA 19,0 (:1384), TLBTPN 40 (:582), TLBPNM 20 (:585), TLMHOL (:789), TLXGDD (:1064), TLFUND (:982); GLFREF — G3TRAN 3,0 (:805), GISTAT (:937), TRSTAT/TRACCT/TRAMT (:987/995/1003); JHFREF — JDCURR 4 (:770), JRCRAT 7,6 (:948), JFXBRT 13,7 (:1368), JYBIAC 19,0 (:1849); BIFREF — BIPEMI 3,0 (:22) | [VERIFIED] |
| Edge case 1 ("risiko migrasi terbesar: tanpa TLFREF panjang/tipe SEMUA field TLLOG & TLTX tak diketahui") | **RESOLVED** — TLFREF mendefinisikan domain teller (header "4700 TELLER FIELD REFERENCE FILE"), termasuk blok TLTEL/TLLOG/TLTX. Gotcha ini harus di-downgrade dari "risiko terbesar" jadi "selesai 2026-09-04" | [VERIFIED] |
| OQ-REF-3 [P2] — arti 8 slot rate + JFXRT9/RTA-C | **TIDAK terjawab semantik** — JHFREF hanya memberi tipe + COLHDG generik ("Current Rate 6", "Current Rate 9", "Current Rate 10"; JHFREF:1373-1377). Tipe kini pasti (13,7), kegunaan bisnis tetap [UNKNOWN] | [VERIFIED] |
| OQ-REF-6 [P3] — value-list status DDMAST & SRMAST | **SEPARUH TERJAWAB — dan separuhnya sudah answerable SEBELUM FILE REF**: DDFREF:81-92 (file lama, identik) punya STATUS 0-9 lengkap dengan arti (0=new-in-process … 6=restricted-post-no-debits, 7=frozen, 9=dormant). Ekstraktor melewatkannya. SRFREF (baru) TIDAK punya field status jenis itu → sisi SRMAST tetap [UNKNOWN] | [VERIFIED] |
| OQ-REF-2 (siapa pakai GLINT1), OQ-REF-4 (pemilik UM90005), OQ-REF-5 (validasi rekening) | **TIDAK terjawab oleh FREF** — tapi OQ-REF-5 sebagian terjawab dari source yang sudah ada: DD0215 memvalidasi keberadaan akun (DDMAST→DDTNEW→ERR '2') untuk jalur backdated (DD0215:119-126). OQ perlu ditulis ulang lebih sempit | [VERIFIED] |
| §1 daftar "FREF absen" + klaim cross-check | **STALE** — kalimat pembuka §1 dan gotcha 1 kini salah terhadap keadaan repo (file sudah ada). PRD wajib re-extract/patch: BR-REF-14 harusnya tumbuh mencakup 8 FREF baru (plus RMFREF yang belum pernah disebut siapa pun) | [VERIFIED] |

Net: **OQ paling kritis modul ini (OQ-REF-1, P1) tuntas; 1 OQ separuh; 3 OQ tetap; seluruh §1/gotcha-1 framing "file hilang" kadaluarsa.** RMFREF (57K) datang tanpa ada yang memintanya — domain RM (remittance?) belum dipetakan KB [UNKNOWN].

## 2.6 Ambiguous rules

1. **BR-REF-13** — "TIDAK di-CHAIN langsung oleh qrpgsrc.tltran atau copy member manapun" — scoping-nya legalistik; pembaca wajar menyimpulkan "batch tidak butuh master" padahal jalur backdated butuh (dan fail dengan ERR '2'). Ini rule paling load-bearing untuk keputusan rebuild "perlu tabel master atau tidak" → harus ditulis ulang eksplisit: TLTRAN tidak, DD0215/CD0215 iya.
2. **BR-REF-12** — "3 namespace" akurat hari ini, tapi tidak menyebut bahwa key ke-3 (UMNUM) ikut jadi key file; CHAIN 2-kfld (KU9005) mengandalkan partial-key — perilaku partial-CHAIN atas key 3 kolom tidak dijelaskan; porting naif ke SQL `WHERE ref= AND chr=` bisa ambil row berbeda bila multiple UMNUM.
3. **§4 DDPAR2 "key SCCODE"** — key aslinya SCCODE+DP2CUR; SCKEY DD0215 pakai DDCTYP sebagai kfld kedua. Untuk migrasi skema, single-key vs composite-key itu perbedaan yang testable.
4. **BR-REF-9 "60 baris kurs"** — 60 adalah kapasitas array program, bukan properti file; JHFXRT bisa berisi >60 record dan LODEXC akan overflow C>60 tanpa guard (LODEXC:11-39 tidak ada cek batas) — risiko nyata yang justru tidak diangkat.

## 2.7 Scorecard

| Dimensi | Nilai | Alasan |
|---|---|---|
| Completeness | **PARTIAL** | Inti reference layer lengkap, tapi CDMAST-read (CD0215) & data area JHAPAR/JHICUR tidak ter-cover di modul manapun |
| Accuracy | **PARTIAL** | 11/12 EXACT, tapi cacat BR-REF-13/gotcha-6 materiil untuk keputusan arsitektur; DDPAR2 key kurang satu kolom |
| Consistency | **PASS** | Cross-ref antar-PRD (BR-GL-1, BR-CUR-1, BR-AMT-11, BR-DSPTCH-8) semuanya nyambung; naming code-side vs DDS-side campur tapi konsisten dipakai |
| Unambiguity | **PARTIAL** | Scoping BR-REF-13 menyesatkan; partial-key UM90005 tak dibahas |
| Testability | **PARTIAL** | Key & field claims testable; klaim dormant (GLINT1, slot kurs) testable dan sudah saya replikasi ✓; klaim negatif master gagal uji semangatnya |
| Traceability | **PASS** | Presisi baris tinggi; klaim negatif pun diberi metode verifikasi (grep) — teladan |
| Dependency clarity | **PARTIAL** | Dua-lapis parameter (produk vs teller) dijelaskan bagus; rename bridge #DS24 (GLFREF→TL*) tidak disebut |
| Edge-case coverage | **PARTIAL** | Gotcha bagus (FREF hilang [kini stale], dua-lapis parameter, dormant) tapi miss: LODEXC tanpa guard 60, validasi master via satelit |
| AI-readability | **PASS** | Struktur seragam, marker + dasar inferensi tertulis |
| Implementation readiness | **PARTIAL** | Pasca-FILE REF sebenarnya naik drastis — tapi PRD-nya sendiri belum tahu; §1/gotcha-1/OQ-REF-1 stale sampai re-extract |

## 2.8 Missing-info list

- **Patch wajib**: BR-REF-13 + gotcha 6 + OQ-REF-5 → akui DD0215:119 (DDMAST), CD0215:72 (CDMAST) [VERIFIED]
- **Patch wajib**: §1 + gotcha 1 + OQ-REF-1 → FREF sudah ada di `FILE REF/` per 2026-09-04; BR-REF-14 diperluas ke 8 file baru [VERIFIED]
- OQ-REF-6 sisi DDMAST → jawab langsung dari DDFREF:81-92 [VERIFIED]; sisi SRMAST tetap [UNKNOWN]
- JHAPAR data area (JHICUR/JHBNKN) → butuh rumah modul; kemungkinan definisi di JHFREF perlu dicek lebih dalam [NEEDS_VALIDATION]
- Kegunaan bisnis JFXRT6-8 vs 9/A-C, pemilik UM90005, konsumen GLINT1 [UNKNOWN — tetap butuh manusia/program lain]
- RMFREF: file baru tak diminta siapa pun; domain RM belum dipetakan [UNKNOWN]
- DDPAR2 key → SCCODE+DP2CUR (DDPAR2:254-255) [VERIFIED, tinggal edit]

---

# Ringkasan skor gabungan

| | transaction-output-files | reference-data |
|---|---|---|
| PASS | 6 | 4 |
| PARTIAL | 4 | 6 |
| FAIL | 0 | 0 |
| Spot-check | 9 EXACT / 3 IMPRECISE / 0 WRONG | 11 EXACT / 1 IMPRECISE-menyesatkan / 0 WRONG |
| Temuan terberat | BR-OUT-4 (sell hilang), on-us float hilang | BR-REF-13 basis inferensi salah (DD0215/CD0215 chain master), §1 FREF-hilang stale |
| Efek FILE REF | OQ-OUT-2 tinggal DDFLOT; semua tipe field output resolved | OQ-REF-1 (P1) tuntas 7/7; edge case #1 resolved; PRD stale |
