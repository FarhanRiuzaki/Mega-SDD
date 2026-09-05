# Audit Lane B — transaction-dispatcher.prd.md vs qrpgsrc.tltran

Auditor lane B · 2026-09-05 · PRD: `.mega-sdd/knowledge-base/modules/transaction-dispatcher.prd.md` (201 baris) · Source: `TLTRAN/qrpgsrc.tltran` (2546 baris, dibaca penuh) + 13 copybook + 6 DDS yang PRD kutip (dibaca/diverifikasi semua).

## Verdict ringkas

PRD ini **kuat di traceability dan jujur di marker** — dari 16 sitasi yang di-spot-check, 11 EXACT sampai ke baris. Tapi ada **2 kontradiksi nyata dengan kode** (klaim "RPV di-skip untuk closeout" dan arah mekanisme TLBNXT='X'), **2 key file salah** (IBCKEY kehilangan TLBAFT, SRMKEY salah nama field), dan **4 perilaku HIGH-severity yang tidak terdokumentasi sama sekali** — paling gawat: baris non-NDP dengan tanggal ≠ posting date di-skip diam-diam, IBT fail-silent saat TLBRN1 miss, threshold hold amount (LOCAL−TLMLAV), dan seluruh plumbing kurs (FNDCUR) yang ternyata MATI sehingga TRCDEC/TRCVRT selalu 0 di semua output. Untuk rebuild, PRD ini cukup sebagai peta tapi **belum cukup sebagai kontrak implementasi** — kondisi IBT 4-leg dan state machine NDP masih harus dibaca dari kode.

## Citation spot-check

16 sitasi diambil menyebar (BR tables A–E, verdict hipotesis, §4, gotchas). Grade: 11 EXACT · 3 SUPPORTS-BUT-IMPRECISE · 2 WRONG.

| # | Citation | Claim | Grade | Note |
|---|---|---|---|---|
| 1 | BR-DSPTCH-1 → :494 + :595/1026/1276/1587/1651/1867/2083; TLTX TLAPP1-20 | Loop `DO 20 X` + selector per app code | **EXACT** | Semua 7 WHEQ persis di baris yang dikutip; TLAPP1..T2APP0 REFFLD(TLXAPP) terverifikasi di QDDSSRC.TLTX:148..2352 |
| 2 | BR-DSPTCH-2 → :424-427 | Filter TLTXOK/TLBTRN/TLBDEL/TLBAPM | **EXACT** | Empat kondisi persis, AND-chain sesuai |
| 3 | BR-DSPTCH-4 → :437-440, :338-339 | Chain TLTX by TLTXCD, gagal tak di-guard | **EXACT** | Betul tidak ada cek *IN10 setelah :440; tapi lihat Contradictions #8 soal klausa "baris hanya jalan bila TLAP,x terisi" |
| 4 | BR-DSPTCH-5 → :456 | Bypass bila TLXGTN='Y' | **EXACT** | `TLXGTN IFNE 'Y'` membungkus seluruh proses |
| 5 | BR-DSPTCH-7 → :239-241, 406-414, 417 | Window BRRNIN/ERRNIN, PSPARM≤0 → semua | **EXACT** | PLIST, PSPARM branch, CHAIN by RRN semua match |
| 6 | BR-IBT-1 → :835-912; #PUTIBT:1-118 | Pasangan IBT *CTL/*ACT, double-entry TLISVx + TLIHOx ke GLTELS | **EXACT** | #PUTIBT:42-45 (TLISVA/B/C/P), :83-86 (TLIHOA/B/C/P), dua WRITERGLTELS (:78, :111) |
| 7 | BR-IBT-2 → 10 titik 888 + #WRTGL:212, 224 | IBT dibungkam bila TLSVBR=888 | **EXACT** | Kesepuluh titik di mainline + 2 di #WRTGL semua terverifikasi `TLSVBR IFNE 888` |
| 8 | BR-HARD-2 → :2313 | Batch recon 222 hard-coded | **EXACT** | `Z-ADD222 RTBCH#` persis |
| 9 | BR-HARD-3 → :1887, 1906-1908, 2119-2121; #WRTGL:67-69 | Fallback GL 9999999999/999/999 | **SUPPORTS-BUT-IMPRECISE** | :1906-1908, :2119-2121, #WRTGL:67-69 exact; tapi :1887 itu `Z-ADD9999999999REF#` = fallback teller-cash (domain BR-HARD-4), bukan fallback GL account |
| 10 | BR-HARD-5 → :944-954, 987-997 | Hold expiry POSTDT+TLMLDY/TLMNDY, rollover Julian >365 | **EXACT** | Formula SUB 365 / ADD 1000 persis di kedua blok |
| 11 | BR-HARD-10 → :726-747, :297-303 | OVB same-CIF: chain UM90005 'TLTX.OVB', DM91033, TRANCD←UMNUM | **EXACT** | Termasuk kondisi ODORC='C' AND OACCF=OVBCIF AND OVBCIF≠blank (:742-745) |
| 12 | BR-RPV-1 → :2373-2514; #CALLE:32-41 | RPV BU/DU via GLGRPV + LE via AMTSR/CALLE | **SUPPORTS-BUT-IMPRECISE** | Range dan mekanisme benar; "TLXAA" typo (kode: TLAA, :2416); klaim "TLIBDR/TLIBCR dari TLMAST" tak bisa diverifikasi — layout TLMAST tidak ada di source set (harusnya [INFERRED]) |
| 13 | BR-RPV-3 → :573-579, 2403-2410 | "TALT,x ∈ {1,2} memilih TLCUR1/TLCUR2" | **SUPPORTS-BUT-IMPRECISE** | :573-579 memakai **TLLU,X** (currency usage per line), bukan TALT; TALT hanya di GENRPV (:2404-2407) untuk REVCUR. Dua array berbeda digabung jadi satu rule |
| 14 | Verdict #1 → "READ RTLLOG (:417, 2353)" | Loop baca TLLOG | **SUPPORTS-BUT-IMPRECISE** | :417 itu `CHAIN RTLLOG` (positioning awal), READ hanya di :2353 |
| 15 | §4 TLBRN1 → "chain IBCKEY: PUTIBC+CURRCY" (:853-860) | Key TLBRN1 | **WRONG** | IBCKEY = PUTIBC + **TLBAFT** + CURRCY (:375-379, KFLD TLBAFT ditambah tag ATM24). Key 2-field yang PRD tulis tidak akan match file berkey 3 (TLIBRN+TLIAFT+TLICUR, QDDSSRC.TLBRN1:20-22) |
| 16 | §4 SRMAST → "chain SRMKEY/STACCT+STATYP" (:1599) | Key SRMAST | **WRONG** | SRMKEY = **ACCTNO + CCTYPE** (:370-372); CCTYPE diisi 'O'/'L' di :1594-1598. STACCT/STATYP itu field output SRTELT, bukan key SRMAST |

Bonus minor (tidak dihitung): §4 "DM91028 (:144)" — call sesungguhnya di QCPYSRC.#GETAM2:144, bukan qrpgsrc.tltran:144 (baris itu E-spec `TLAA`); BR-HARD-11 juga menulis "qrpgsrc.tltran:114-148" padahal maksudnya #GETAM2. §4 GLTELT/GLTELS writes juga melewatkan :2178/2180 (leg RC-GL).

## Marker honesty

**Sampel 10 klaim "verified" (kolom Confidence kosong = implicit verified):** BR-DSPTCH-2, DSPTCH-5, HARD-1 (250/251, :776-780 & :1237-1241 ✓), HARD-2, HARD-5, HARD-7 (*CLOSE :2358-2359 ✓), HARD-10, IBT-2, ERR-3 (:763-764, :1229 ✓), ERR-4 — **semuanya memang verifiable murni dari source**. [VERIFIED] discipline solid.

**Sampel [INFERRED]:** BR-ERR-1, ERR-2, ERR-5, ERR-6, §1.4, §2F, gotcha 2 — **semua menyertakan "(dasar: ...)"** dan dasarnya valid. Gotcha 2 malah terbukti benar mekanismenya: TLTX di-overlay DS via QCPYSRC.#DS2 (TLAPP1-20 → array TLAP, #DS2:33-40), jadi chain miss memang meninggalkan data record sebelumnya. Praktik inference-with-evidence di sini bagus.

**Kebocoran honesty (klaim bergaya verified padahal inference):**
1. "A1/C1=call-center" (BR-DSPTCH-3) — hanya C1 yang bertag CC01 (:432, header :38); makna A1 tidak berbukti di source. [NEEDS_VALIDATION]
2. "TLIBDR/TLIBCR (bank-level IBT code **dari TLMAST**)" (BR-RPV-1) — layout data area TLMAST tidak ada di folder; semua field TLM*/TLIB*/TLSR* hanya direferensikan, tak pernah didefinisikan. Ini inference tanpa marker.
3. §4 "TLBSOV→TLSVBR (servicing branch)" — TLBSOV ada di TLLOG:7 tapi **tidak pernah dibaca program ini**; program pakai TLSVBR langsung (:470). Mapping TLBSOV→TLSVBR tidak berbukti.
4. Frontmatter counts (62/12/9/2/79/2) tidak bisa direkonsiliasi dengan body — kolom Confidence di tabel mayoritas kosong, bukan bertanda [VERIFIED] eksplisit. Bookkeeping vs body tidak saling ngunci.

## Undocumented behavior

Hasil jalan sistematis mainline + semua subroutine/copybook. [VERIFIED] semua item di bawah kecuali dinyatakan lain.

1. **CRITICAL/HIGH — Baris non-NDP dengan TLBTDT≠POSTDT di-skip diam-diam.** Leg ketiga kondisi NDPITM (:503-505): `NDP,X ≠'Y' AND ≠'L' AND TLBTDT≠POSTDT → NDPITM='*YES'` → baris tidak diproses (:547-548) dan **tidak pernah** diproses (path TLBNXT='X' di :512-515 hanya untuk NDP Y/L). Record carry-over/backdated tanpa flag NDP = hilang tanpa jejak. PRD BR-HARD-9 hanya membahas NDP='Y'/'L'.
2. **HIGH — IBT fail-silent saat TLBRN1 miss.** #PUTIBT:6-7 chain TLBRN1; miss (*IN10=1) → **kedua leg GLTELS tidak ditulis**, tanpa error — padahal leg produk sudah ditulis → clearing sepihak. PRD BR-IBT-* tidak menyebut miss path ini.
3. **HIGH — Hold record punya threshold amount yang tak terdokumentasi.** :921-923 `LOCAL SUB TLMLAV → CKAMT; CKAMT IFGT 0` (foreign: TLMNAV, :964-966). Hold hanya ditulis bila amount > nilai "available" TLMAST, dan **jumlah hold = selisihnya**, bukan full amount. BR-HARD-5 hanya membahas expiry.
4. **HIGH — Plumbing kurs efektif MATI: TRCDEC/TRCVRT selalu 0.** `EXSR FNDCUR` di-comment (:482, tag AL03). FNDCUR adalah **satu-satunya** penulis array CRU/CRD/CRE (grep seluruh source), jadi :556-558 selalu memindahkan blank/0 → DECPOS=0, EXCRAT=0 → TRCDEC/TRCVRT=0 di semua output GL/CS/RC/IBT (:1878-1879, 2096-2097, #WRTGL:44-45, #PUTIBT:36-37). LODEXC/JHFXRT dimuat tapi CER tak pernah terpakai di program ini. Rebuild yang mem-port plumbing ini secara literal akan salah dua arah. [VERIFIED mekanisme; apakah downstream memang expect 0 = NEEDS_VALIDATION]
5. **MEDIUM — SR whitelist transaction code.** SRTELT hanya ditulis bila TLCD,x ∈ {TLSRPU, TLSRSE, TLSRDP, TLSRWD} atau {TLSRCD, TLSRCW} dengan SXSMX='Y' (:1602-1609); kode SR lain tidak menghasilkan apa pun; STVALU hanya untuk SE/PU (:1633-1638). PRD cuma bilang "SMX account check".
6. **MEDIUM — Guard branch-type 'M' tidak konsisten antar produk.** Leg *ACT: DD/CD memakai SAVTY1 (:896; :1204 fix YP1; #WRTGL:238 fix MEDAN), tapi **CS (:2057) dan RC (:2246) masih memakai TLITYP** — mengetes tipe branch hasil chain terakhir, bukan tipe account branch. Kelas bug yang sudah dikoreksi YP1/MEDAN di jalur lain tapi belum di CS/RC.
7. **MEDIUM — Mekanisme offset TXCD koreksi ada di kode hidup, bukan cuma komentar.** #GETAM2:155-159: `TLBCOR≠'Y' → TXCD=TLCD,x; else TXCD=TCCD,x`. PRD hanya membawanya sebagai BR-ERR-5 [INFERRED] dari komentar header — padahal langsung verifiable dan array TCCD ("BATCH TXCD COR", :100) adalah kuncinya.
8. **MEDIUM — Internals CRTFLT tak terdokumentasi:** flip tanda untuk debit/koreksi (#CRTFLT:28-35), record float ACCRUAL kedua bila TLGACF='Y' (:72-91), rewrite kategori 'LC'→'IB' saat interbranch (:63-66), ladder float-days (TLXFSL/TLFSCH/TLF vs TLMLDY), dan **silent no-write** bila kalender TLFLTC miss (:55-56).
9. **MEDIUM — Lookup GLGREF dua tingkat.** Branch aktual → retry **branch 0** (default mapping) → baru suspense 9999999999 (:1890-1911; #WRTGL:51-71). PRD hanya mendokumentasikan fallback terakhir.
10. **MEDIUM — RPVMOD (YS05):** selama GENRPV, RPVMOD='Y' menonaktifkan override branch OSB/USB di WRTGL (#WRTGL:131, 164) — "RPV pakai servicing branch". BR-IBT-4 mengutip #WRTGL:129-145 tanpa guard ini.
11. **MEDIUM — Ladder LE short-circuit.** IF TLAB/TLAC (dan TLXB/C/D) nested (:2420-2428, :2454-2469): TLAB blank → TLAC tidak pernah dievaluasi. Mempengaruhi hasil kalkulasi LE.
12. **LOW — LBRUSE:** butuh TLMLBR='Y' AND TLXULB='Y' AND ABR,x≠TLBRN#; hit TLBRN2 → TLBRN#←ACCTBR (efek: IBT tersupresi) (#LBRUSE:8-14). PRD cuma satu kalimat "logical branch override".
13. **LOW — Slot magic TAMU 21-24** → TEAMT1-4 hasil GETAM3 (#GETAM2:47-54).
14. **LOW — Baris amount=0 di-skip kecuali SR** (:565-566 `AMOUNT IFNE *ZEROS / TLAP,X OREQ 'SR'`).
15. **LOW — Chain GLGRPV indicator 31 tak pernah dites** (:2383) — kelas unguarded-chain yang sama dengan gotcha 2/6 tapi tidak masuk daftar PRD.
16. **LOW — Artefak:** blok dummy mustahil :2364-2368 (baca format GLTELT/GLTELS), copybook #MOVETR di-include tapi tak pernah di-EXSR, clear remark per record :2347-2351, komentar stale "LHTRAN < 900" (:1417) vs kondisi riil LHAFFT≠'Q' (:1375).

## Contradictions

1. **Gotcha 7: "float & RPV untuk closeout di-skip" — SALAH separuh.** Hanya float yang di-guard `TLXAFT ANDNE'CT'` (:1013, 1263, 1572); **GENRPV dipanggil tanpa syarat** setelah blok DD/CD/LN/GL (:1019, 1268, 1578, 1659). RPV tetap jalan untuk closeout.
2. **BR-HARD-9: arah TLBNXT='X' terbalik.** Kode: bila business-day MATCH → item **diproses run ini juga** DAN di-stamp 'X' (:537-543 lalu lolos filter :548); bila bukan business day → ditahan TANPA update. Klaim PRD "di-update ... agar diproses hari berikutnya" menyesatkan — 'X' distamp justru pada run yang memprosesnya.
3. **§4 key TLBRN1 salah** — IBCKEY = PUTIBC+TLBAFT+CURRCY, bukan PUTIBC+CURRCY (lihat spot-check #15).
4. **§4 key SRMAST salah** — ACCTNO+CCTYPE, bukan STACCT+STATYP (spot-check #16).
5. **Flowchart urutan C↔D terbalik:** kode READ DDPAR1 dulu (:397) baru LODEXC (:401); diagram menggambar sebaliknya.
6. **Flowchart P7 "TLFUNDF"** — nama field sebenarnya TLFUND (:2084). Typo kecil tapi flow dipakai agent.
7. **§4 "TLBSOV→TLSVBR"** — program tidak pernah menyentuh TLBSOV; TLSVBR dibaca langsung dari TLLOG.
8. **BR-DSPTCH-4 klausa efek** — "baris hanya jalan bila TLAP,x terisi" mengesankan chain-miss = no-op; realitasnya TLAP,x **tetap terisi nilai record TLTX sebelumnya** (DS overlay #DS2 tidak di-clear), jadi baris jalan dengan parameter transaksi lain. Gotcha 2 sudah benar; rule-nya sendiri melembek.

## Ambiguous rules

10 rule paling load-bearing, dinilai "bisakah AI agent implement tanpa nanya?":

1. **BR-IBT-1 + BR-IBT-3** — TIDAK. Kondisi emisi 4 leg sesungguhnya: `TLMSBR≠'Y' OR (TLMSBR='Y' AND RGN1≠RGN2) OR (TLMSBR='Y' AND RGN1=RGN2 AND type≠'M')` per leg, ditambah leg TLIHOB bila type='S' AND RGN1≠RGN2 AND TLMSBR='Y' (:865-910). PRD hanya prosa "region berbeda mengubah pasangan leg". → Rewrite: **decision table** kolom TLMSBR/RGN1=RGN2/TLITYP/SAVTY1/TLSVBR=888 → baris leg yang terbit.
2. **BR-HARD-9 (NDP)** — TIDAK. Interaksi NDP-flag × TLBTDT=POSTDT × TLBNXT × business-day menghasilkan 4 outcome berbeda; PRD satu kalimat dan arahnya keliru (Contradictions #2). → Rewrite: state table per kombinasi + kolom "diproses? / TLLOG di-update?".
3. **BR-DSPTCH-4** — TIDAK untuk perilaku miss. → Rewrite: "chain miss ⇒ DS overlay TLTX menahan nilai record sebelumnya; baris dieksekusi dengan parameter stale — rebuild WAJIB reject" (sudah setengahnya di gotcha 2, angkat ke rule).
4. **BR-RPV-1 (LE)** — TIDAK. "hitung local-equivalent via AMTSR+CALLE" tidak operasional; urutan operand, opcode mana (TLOC/TLOD vs TLOA/TLOB/TLOG), dan short-circuit nesting tak dispesifikasikan. → Rewrite: formula eksplisit `ACT = f(LEAMT1 op LEAMT2 op LEAMT3...)` per cabang REVCUR=/≠JHICUR.
5. **BR-DSPTCH-1** — SEBAGIAN. Enum TLAP ('DD','CD','LN','SR','GL','CS','RC') tampil closed tapi PRD tidak menyatakan "nilai lain = no-op"; mekanisme TLTX→array (I-spec #DS2) tak disebut. Acceptance test bisa dibuat kalau ada fixture TLTX (OQ-2 memblok).
6. **BR-DSPTCH-3** — SEBAGIAN. "Hanya MO/CT/A1/C1 diproses" testable, tapi perilaku nilai tak dikenal hanya implisit (skip); makna A1 tak berbukti. → Tambah kalimat else-skip eksplisit + tandai A1 [NEEDS_VALIDATION].
7. **BR-ERR-4** — SEBAGIAN. "membalik arah Dr/Cr **di banyak titik**" tidak enumeratif — agent tak tahu titik mana saja (GETAM2 TXCD, PUTIBT 4-way, CRTFLT sign, RC, RECID hold). → Rewrite: tabel lengkap situs efek TLBCOR.
8. **BR-IBT-4** — TIDAK. Urutan presedensi override branch (AXF → USB → OSB, plus guard RPVMOD, plus perbedaan konteks IBT vs GL-write) tidak dispesifikasikan; kode menerapkannya beda-beda per situs. → Rewrite: precedence list per konteks.
9. **BR-HARD-6** — SEBAGIAN. "muncul di semua file output" — pengecualian RC-funded-DDA yang **selalu** 'Z' tanpa cek TLTXSR (:2292) tidak disebut. Testable setelah pengecualian ditulis.
10. **BR-HARD-8** — SEBAGIAN, dan setengah keliru. 'TL' hanya di-set oleh WRTGL (#WRTGL:89) dan PUTIBT (:21); tulisan langsung CS **dan RC-GL** dua-duanya blank (:1923, :2136) — rule menyebut hanya CS. → Rewrite: "TRSYS='TL' ⇔ record lewat WRTGL/PUTIBT; direct-write CS/RC ⇒ blank".

Umum: hampir tidak ada rule yang membawa acceptance criteria eksplisit (given/when/then atau fixture); testability bergantung pembaca menurunkannya sendiri dari sitasi.

## Scorecard

| Dimensi | Nilai | Alasan 1 baris |
|---|---|---|
| Completeness | **PARTIAL** | Mainline & routing terpetakan bagus, tapi 4 perilaku HIGH (non-NDP date skip, IBT fail-silent, hold threshold, FNDCUR mati) absen |
| Accuracy | **PARTIAL** | 11/16 sitasi EXACT, tapi 2 key salah + 2 klaim terkontradiksi kode (RPV-closeout, arah TLBNXT) |
| Consistency | **PASS** | ID rule konsisten, tidak ada self-contradiction internal; hanya frontmatter counts yang tak bisa direkonsiliasi ke body |
| Unambiguity | **PARTIAL** | IBT 4-leg, NDP state machine, ladder LE, presedensi override semua masih prosa — butuh decision table |
| Testability | **PARTIAL** | Sebagian rule crisp (filter, hard-code 222/250/251), tapi tak ada acceptance criteria; OQ-2 (data TLTX) memblok fixture |
| Traceability | **PASS** | Disiplin file:line hampir di tiap klaim; spot-check 69% EXACT, tak ada sitasi fabricated |
| Dependency clarity | **PASS** | depends_on + peta input/output per file dengan key — meski 2 key keliru, strukturnya lengkap |
| Edge-case coverage | **PARTIAL** | §5 gotchas bernilai tinggi (dead code, indicator reuse, RRN), tapi kelas silent-skip terbesar justru lolos |
| AI-readability | **PASS** | Tabel ber-ID, mermaid, mutability tier, OQ ber-prioritas — format ramah agent |
| Implementation readiness | **PARTIAL** | Cukup untuk orientasi & triage, belum cukup sebagai kontrak rebuild tanpa membaca RPG-nya lagi |

## Missing-info list

- **[P1/HIGH] Layout data area TLMAST** — ±25 field TLM*/TLIB*/TLSR* (TLMLDY, TLMNAV, TLMHOL, TLMFLO, TLMSBR, TLMLBR, TLIBDR/TLIBCR, TLSRPU/SE/DP/WD/CD/CW, TLMDRT, TLMLAV...) dipakai sebagai kontrol utama tapi definisinya tidak ada di source set, dan **PRD tidak mengangkatnya sebagai OQ**. Tanpa ini, semantik hold/float/IBT/SR tak bisa dikunci.
- **[P1/HIGH] Ekspor data TLTX** — sudah tertangkap sebagai OQ-DSPTCH-2 ✓ (valid, memblok enum kode transaksi & semua acceptance fixture).
- **[P1/HIGH] Job stream / CL pemanggil + kontrak restart** — sudah OQ-DSPTCH-1 ✓; tambahkan sub-pertanyaan baru: **rerun window yang sama setelah TLBNXT='X' terstamp akan memproses ulang item NDP** (path :512-516) — double-posting saat restart? [NEEDS_VALIDATION]
- **[P2/HIGH] Apakah TRCDEC/TRCVRT=0 memang diterima downstream** (konsekuensi FNDCUR mati, temuan #4) — perlu konfirmasi tim host sebelum rebuild memutuskan port atau buang plumbing kurs.
- **[P2/MEDIUM] DDS *FREF** — sudah OQ-DSPTCH-3 ✓ (tipe/panjang semua field R tak diketahui; mempengaruhi truncation semantics MOVE/MOVEL yang PRD sendiri warning di gotcha 3).
- **[P2/MEDIUM] Semantik bisnis TLBNXT='X' dan siapa lagi yang menulis/membacanya** — arah yang PRD tulis terbukti keliru; perlu konfirmasi desain sebelum rule ini dikunci.
- **[P2/MEDIUM] Guard 'M' CS/RC pakai TLITYP vs SAVTY1** (temuan #6) — bug atau intended? Menentukan apakah rebuild mereplikasi atau memperbaiki.
- **[P3/LOW] Makna after-code A1** — sebagian tertangkap OQ-DSPTCH-5; tandai gloss "call-center" untuk A1 sebagai belum berbukti.
- **[P3/LOW] UM90005 isi live** (BIN e-wallet, BYMHD, TLTX.OVB) — resolusi akun virtual tak bisa diuji tanpa datanya.
