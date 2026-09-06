# Size-weighted spec — desain (APPROVED 2026-09-05, implementasi berjalan)

**Keputusan gate 2026-09-05 (owner): APPROVE, A1 = opsi (i) proxy deterministik.** Review pra-gate: nol defect konkret; semua touchpoint terverifikasi masih valid di head 7.27.0 (`unit_tier`/`project_scale`/`--unit-tier`/`.pack-skip-list.json` belum ada di tree; slice P3b/P4/P6/P7/P8/T2 masih hidup di builder; harness dispatch-parity v6.7.1 tersedia untuk target ≤5:1). Urutan implementasi mengikuti §Urutan di bawah.

**Amendemen A1 saat implementasi (Step 1, 2026-09-05):** grammar unit kanonik (unit-schema.md §Required body sections) TIDAK punya `## Requirements` — padanan struktural "butir kerja"-nya adalah `## Implementation steps` (bernomor). Proxy diimplement sebagai: `acceptance_test` entries 1..2 DAN butir kerja 1..3 — dihitung dari `## Implementation steps` (kanonik) ATAU bullet `## Requirements` (unit legacy); bila keduanya ada, keduanya wajib di bawah ceiling. Section absen/kosong/unparsed = bukan bukti kecil → bukan xs (doktrin unknown-never-lowers). Temuan sampingan Step 1: regex blok frontmatter resolver memakai `(?ms)` (DOTALL) sehingga scalar-list `target_files` menelan key berikutnya — unit 2-file terukur `target_files:5` dan `file_count` false-fire (arah fail-up, moat aman, tapi persis kelas inflasi muatan yang spec ini serang); diperbaiki + di-pin di `tests/size-weighted/test-unit-tier-router.sh`.

**Amendemen Step 2 (2026-09-05, saat implementasi §1b):**
- **P8 di unit ui_bearing: STEP-KE-FLOOR, bukan drop.** Tabel §1b menulis ✗ untuk P8a/8b/8c, tapi design-reviewer lens menilai berdasar slice yang SAMA dengan yang dibaca implementer (lens membaca `s.text()` pasca-cascade). Drop untuk implementer saja = kontrak asimetris → temuan palsu. Solusi simetris: `design_slice`/`starterkit_slice`/`framework_pack_rules` ditahan di rung floor ladder-nya sendiri — implementer DAN lens memegang satu kontrak floor yang byte-identik; unit non-UI tetap drop starterkit/map.
- **Baris "Step narrative ✗" + "tracker/provenance ringkas"** diimplement sebagai kompresi xs-only: NOTE acceptance-provenance → 3 baris (fakta + instruksi confidence), preamble Provenance-values dihapus, tracker tanpa prosa explainer + tanpa instruksi truncation yang vacuous saat `(none)`, appendix provenance = daftar key (alasan penuh tetap di stdout `sections_omitted`). Invariant #5 utuh — semua absence tetap TERCATAT.
- **Hasil terukur (f4-xs, replay kelas U-005, implementasi 22 baris):** 18.174 → 6.342 byte (**−65%**), 273 → 125 baris (**12,4:1 → 5,7:1**). **Target ≤5:1 MISS 0,7** — dilaporkan jujur (preseden P5 <10-min): sisa 15 baris di atas target adalah blok kontrak/proteksi (anti-context DO-NOT-WRITE, T3 pointer, banner identitas) — memangkasnya = memotong bukti/proteksi, DITOLAK. Catatan kalibrasi: rasio est-token full build ≈19–21:1 ≈ angka 17,9:1 tim → fixture representatif. Pin: golden `f4-xs` + arm relasi ≤60% di `tests/dispatch-parity/`.
- §3 (pack-skip-list): **VOID BY PRIOR CHANGE — census 2026-09-05 menghasilkan himpunan kandidat kosong** (basis terukurnya = fan-out PostToolUse yang sudah dihapus №D v7.5.0; tabel census + kondisi revive di §3). §2 (project_scale) = satu-satunya bagian yang masih open.

**Status: SPEC COMPLETE — §1 SHIPPED 7.28.0 · §3 CLOSED-VOID (census kosong) · §2 SHIPPED 7.29.0. Semua bagian tertutup; desain asli di bawah utuh.** Sumber: feedback tim (Igoo0/feedback-mega-sdd, diukur 6.12.0 — rasio instruksi:kode 17.9:1 pada unit 22 baris; 5.8:1 spec:kode; 28 OQ untuk 3 screen) + triage `research/2026-08-23-team-feedback-triage.md` №A. Gap yang dikonfirmasi: routing v7.1 menskalakan **panel review + model** per unit, tapi TIDAK menskalakan **payload dispatch prompt** dan **kedalaman vault**. Ini kelanjutan alami S/M/L (v7.0.0 anchor, v7.1.0 panel/model) turun ke level UNIT dan PROJECT.

**Rambu tetap (tidak bisa dinego):** tidak ada gate anti-halu yang dilonggarkan. XS memangkas *muatan* (byte yang dimuat), bukan *bukti* (acceptance test tetap wajib dieksekusi; binding refs tetap disitir; citation discipline utuh). Doktrin "unknown never lowers a tier" (P3/A5) berlaku di semua field baru.

**Objective owner (2026-08-26, mengikat desain ini): tidak overkill, tidak overengineer.** Field evidence kedua: run brownfield di project MTConvert kantor (1 file kode hidup, 1.225 file log, tumpukan backup manual) — pipeline penuh jalan dengan fixed cost yang sama seperti project 200-unit, lambat di mesin CrowdStrike dan menghasilkan emisi yang tidak dibutuhkan. Konsekuensi desain: §2 dipangkas ke dua nilai skala saja, dan dapat lengan brownfield.

## 1. `unit_tier: xs` — router + konsekuensi mekanis di dispatch prompt

### 1a. Derivasi (di `resolve-review-tier.sh`, field output baru)

Field `unit_tier` diturunkan dari sinyal yang SUDAH dievaluasi router (nol input baru ke jalur risiko):

```
xs  = tier verdict "minimal" (yaitu: 1≤target_files≤2 AND nol dari 6 sinyal risiko,
      atau task_type verify)  AND  size-proxy kecil (lihat keputusan A1)
s/m/l = mapping dari verdict existing (minimal→s, standard→m, full→l) — hanya label,
      tidak mengubah panel/model routing yang sudah jalan
```

**Keputusan A1 — sumber "estimasi baris kecil" (butuh keputusan owner):**

| Opsi | Mekanisme | Trade-off |
|---|---|---|
| **(i) proxy deterministik dari body unit — REKOMENDASI** | hitung bullet `## Requirements` ≤3 DAN langkah acceptance_test ≤2 (regex atas struktur yang sudah diparse router) | Nol field baru, nol judgment model; proxy kasar tapi false-negative aman (unit jatuh ke `s`, bukan salah kecil) |
| (ii) frontmatter `size_hint:` ditulis generate-units | model menulis hint saat dekomposisi (kelas yang sama dengan `risk:` yang sudah ada); router membaca sebagai input, absent → bukan xs | Lebih akurat, tapi menambah field writer-side + surface schema; `risk:` presedennya memang ada |

Dua-duanya mempertahankan doktrin: hint/proxy hanya bisa MENURUNKAN muatan pada unit yang sudah lolos nol-sinyal; tidak pernah menaikkan ambang risiko. `parse_note` apa pun → bukan xs.

### 1b. Konsekuensi mekanis (di `build-dispatch-prompt.sh`, flag `--unit-tier=` dari caller)

Caller (execute-bolts Step 2) sudah memegang verdict JSON router — diteruskan sebagai flag; builder TIDAK memanggil router sendiri (satu sumber verdict). Tabel emisi per prioritas (baseline = struktur builder sekarang):

| Slice (prioritas builder) | Standard/full | **XS** | Alasan |
|---|---|---|---|
| Core unit: frontmatter, requirements, hard rules (union DO-NOT-MODIFY berlabel), anchors/binding_refs, acceptance test | ✓ | **✓** | Ini kontrak + bukti — tidak pernah dipangkas |
| P9 constitution clauses (cited) | ✓ | **✓** | Rail; murah di unit xs (sitiran sedikit by construction — §B clause = sinyal risiko = bukan xs) |
| T1 reuse line (unconditional) + acceptance-provenance note | ✓ | **✓** | Satu-dua baris; anti-duplikasi tetap berlaku di unit kecil |
| Provenance appendix (audit trail omission) + T2 budget tracker | ✓ | **✓ (ringkas)** | Jejak audit tetap ada; tracker menyusut sendiri karena seksi sedikit |
| P1 validation hints | ✓ | **✗** | Muatan antisipatif; validator tetap jalan di gate — bukti tidak berkurang |
| P4 KB anti-patterns | ✓ | **✗** | Payload konteks, bukan bukti |
| P5 confidence labels per claim | ✓ | **✗** | Label per-claim; binding refs + verdict tetap disitir penuh |
| P6 depends_on chain | ✓ | **✗ jika kosong/1 hop, ✓ selebihnya** | Unit xs dengan dependency nyata tetap butuh kontraknya |
| P7 framework pack rules | ✓ | **top-1 HARD_RULE saja** | Floor existing "keep top 1" dipakai sebagai ceiling xs |
| P8a/8b/8c starterkit/map/design slice | ✓ | **✗** | Slice scaffolding; unit 22-baris tidak butuh starterkit |
| P3/3b reuse & symbol slice | ✓ | **hanya simbol yang match target_files** | Claim-scoped, bukan sweep (aturan proportional-verification yang sudah standing) |
| Step narrative / naratif prosedur | ✓ | **✗** | Sumber utama rasio 17.9:1 |

**Target terukur (kriteria terima implementasi):** replay fixture kelas U-005 (rekonstruksi unit 22-baris serupa; idealnya minta file spec asli tim) → rasio token-prompt : baris-kode-implementasi turun dari 17.9:1 ke **≤5:1**, dibuktikan di harness dispatch-parity (v6.7.1) yang dapat arm XS baru (golden per tier — kelas counter length-sensitive sudah ada pin-nya).

## 2. `project_scale: xs|standard` — skala project (greenfield + brownfield)

> **SHIPPED 7.29.0 (2026-09-06), dengan amendemen tera:**
> - **Counter** = `scripts/derive-project-scale.sh` (deterministik: heading per-screen + item section Surfaces/Screens + baris tabel ber-header screen/surface; entities = DBML `Table` + heading/section data-model; flows = census id `F-X-NNN`). **Amendemen kalibrasi terhadap korpus** (pinned di `tests/size-weighted/test-project-scale.sh`): (a) **guard flows ≤3** ditambah ke ambang — clinic PRD (produk penuh) membawa 6 flow dan wajib standard bahkan bila section layarnya tak terparse; (b) **"view(s)" DIBUANG dari kata screen** — "Doctor views schedule" (verba) false-fire di korpus; (c) zero screen evidence → standard (unknown mendapat perlakuan PENUH, bukan diet). Sapuan 12 file korpus: nol false-xs.
> - **Bagian-opsional yang di-omit di xs = `vault.md ## Glossary` SAJA** — satu-satunya section template-opsional dengan nol konsumen keras (parser menandainya optional). `## Changelog` KEEP (resolve-oq/diff-vault menulis ke sana), `## Phase context` KEEP (2 pembaca: chain-execution + halts-and-handoff); sisanya sudah terlayani by construction (conditional sections source-gated + compact mode).
> - **OQ tech medium → born-deferred** via mesin defer yang SUDAH ada (`**Deferred**:` + `defer_to` di patch — `binding` di brownfield, `stakeholder` di greenfield [amendemen 7.29.1: kontrak `resolve-oq §Defer targets` hanya mengizinkan `binding` saat `implementation_mode: existing` + sinyal repo; nilai greenfield yang sah = `stakeholder`, mesin yang sama dengan auto-defer express]; `deferred_at` script-stamped oleh deriver) — rule 4b di generation-guide §Step 3.5; OQ count tak berubah (honesty), seremoni interaktifnya yang menyusut.
> - **Scalar** `project_scale` = frontmatter layout-2 murni (`_FM_LOCK_KEYS`; peta bullet legacy TIDAK disentuh — vault lama memang tak pernah membawanya; absen = standard, tidak pernah dikarang).

**Dipangkas dari `xs|s|m|l` ke DUA nilai** (amendemen 2026-08-26, objective tidak-overkill): hanya `xs` yang punya konsekuensi mekanis — tiga label sisanya beban schema tanpa fungsi. Ekspansi tier nanti hanya kalau ada bukti kebutuhan.

- **Sinyal ukuran — greenfield (generate-intent)**: jumlah screen/flow/entity yang diparse dari PRD (hitungan deterministik atas struktur dokumen — heading/tabel — bukan judgment; ambang: xs ≤3 screen & ≤2 entity; angka final ditera saat implementasi terhadap korpus PRD yang ada).
- ~~Sinyal ukuran brownfield + advisory XS~~ — **Superseded 2026-08-26** oleh `2026-08-26-extract-revamp-contract-design.md`: jalur brownfield didesain ulang jadi extraction proporsional (census → PRD kontrak), sehingga advisory "minimal/penuh/batal" moot — extraction yang proporsional tidak perlu ditanya mau diet atau tidak. §2 di dok ini kini hanya mencakup greenfield.
- **Penyimpanan**: scalar `project_scale` di frontmatter vault (kelas lock-scalar per keputusan Fase 3 — frontmatter = skalar saja, section tetap md) + mirror di `vault.json` untuk konsumen script.
- **Konsekuensi XS**:
  - Bagian vault OPSIONAL **tidak diemisi** (bukan diisi placeholder — konsisten doktrin "omit, never fabricate"); inventaris bagian-opsional diambil dari template layout-2 saat implementasi.
  - **OQ tech**: ambang auto-resolve naik — di XS, tech/scan OQ yang hari ini `medium` confidence masuk **defer-by-default** (tercatat di Auto-Classification Review, TIDAK ditanyakan interaktif), bukan auto-resolve tanpa bukti: auto-resolve tetap mensyaratkan citation probe nyata seperti sekarang (`high` + single unambiguous match). Yang berubah = ASK vs DEFER, bukan standar bukti.
  - **OQ business**: tidak berubah — tetap human-decided (rail anti-halu; keterangan Indonesia per standing rule).
- Target: skenario kelas "3 screen statis" tidak lagi menghasilkan 28 pertanyaan interaktif; angka tim jadi baseline pembanding. Brownfield: kelas MTConvert (1–2 file kode) selesai lewat jalur minimal atau batal-jujur, bukan pipeline penuh.

**Yang sengaja TIDAK didesain (ditolak sebagai overkill/gimmick):** heuristik deteksi file backup (`*.bak`, `index - Copy.php`, dsb.) — rapuh dan menambah surface; jalur XS yang menyusutkan seluruh muatan sudah menyelesaikan gejalanya. Tier skala >2 nilai — tanpa konsumen. Ramp kecepatan khusus CrowdStrike — fixed cost turun sendiri saat muatan XS menyusut (lebih sedikit fase = lebih sedikit spawn).

## 3. Validator SKIP-by-construction di pack universal → tidak di-dispatch

> **VERDICT 2026-09-05: VOID BY PRIOR CHANGE (№D v7.5.0) — TIDAK DIBANGUN.** Census per-konsumen (mandat §3 sendiri: "uji pisau per-konsumen") di head 7.28.0 menghasilkan himpunan kandidat KOSONG:
>
> | Invokasi validator | Dispatcher hari ini | Wholly pack-gated? | Kandidat skip-list? |
> |---|---|---|---|
> | ui-quality (main), flow-coverage, sibling --cross-cutting, sibling (main, render leg) | **HANYA gate PreToolUse execute-bolts** (9 re-derive paralel) | ya (section absen → SKIP utuh) | **TIDAK — gate = moat**; spec ini sendiri menulis "kelas fail-closed hanya untuk gate; ini optimisasi dispatch, bukan gate", dan mandat standing: recompute-at-gate JANGAN dioptimasi |
> | unit-spec | analyze FULL + gate | tidak (hanya render leg §Test patterns) | tidak |
> | dispatch-prompt (V16) | analyze FULL | tidak (hanya sub-check exemplar §UI quality signatures) | tidak |
> | sibling --fanout-parity (V13), ui-quality --deferral (V14) | analyze FULL | tidak (branch mode mandiri, pack-free — resolver tidak di-spawn di mode itu) | tidak |
> | flow_coverage / sibling_consistency / cross_cutting / ui_quality di analyze | dibaca STATE_FILE (nol spawn) | n/a | tidak ada dispatch untuk di-skip |
>
> Akar sebabnya: basis terukur §3 (12/26 boundary SKIP = dispatch waste, diukur 6.12.0) menunjuk ke **fan-out validator PostToolUse Write|Edit** — dan permukaan itu DIHAPUS UTUH oleh №D v7.5.0 (setiap gate-read state re-derive di gate-nya sendiri). Yang tersisa di analyze FULL hanya validator pack-parsial (sub-check-nya sudah self-SKIP setelah satu probe resolver murah) atau pack-free. Membangun `.pack-skip-list.json` sekarang = file derived state baru + logika rebuild mtime + perluasan test aggregate-parity untuk menjaga himpunan kosong — biaya maintenance murni, nol spawn terhemat. Preseden kelas: C1 void by no-observability (kb-verify, v7.3.0).
>
> **Kondisi revive:** (a) muncul lagi permukaan dispatch non-gate untuk validator wholly-pack-gated, ATAU (b) bukti lapangan wall-clock analyze FULL di mesin CrowdStrike menunjukkan spawn probe resolver per-validator signifikan. Desain di bawah dipertahankan utuh sebagai referensi.

- Basis terukur (2026-08-23): roster 6.12.0 = 26 boundary (angka tim tereproduksi persis), 7.5.0 = 23. Validator yang berkonsultasi ke pack: `dispatch-prompt`, `flow-coverage`, `sibling-consistency`, `ui-quality`, `unit-spec` (+`preflight` warn, `pack` lint).
- Mekanisme: `run-analyze.sh` menurunkan **sekali** `.pack-skip-list.json` dari pack chain ter-resolve (rebuild saat mtime pack berubah): check yang pack-nya tidak mendeklarasikan konvensi terkait (mis. `_universal` tanpa yaml fence Test patterns → render check pasti SKIP) ditandai skip-by-construction dan **tidak di-dispatch**; state file tetap ditulis `SKIP` (semantik FULL/aggregate parity dipertahankan — test aggregate-parity diperluas).
- **Fail-open**: probe gagal/daftar tak terbaca → dispatch normal seperti sekarang (kelas fail-closed hanya untuk gate; ini optimisasi dispatch, bukan gate).
- Daftar persis validator×section dihitung saat implementasi dengan census per-konsumen (pelajaran standing: uji pisau per-konsumen, bukan per-direktori).

## Yang TIDAK berubah

Panel review + implementer_model routing (v7.1), 6 sinyal risiko, semua 7 gate bolt-stage + re-derivasi at-gate, B1 recompute, citation discipline, halt taxonomy, OQ business human-decided. `unit_tier`/`project_scale` murni menskalakan muatan.

## Urutan implementasi yang diusulkan (setelah approval)

1. Router field `unit_tier` + test (fixture xs/s + doktrin unknown→bukan-xs).
2. `--unit-tier=` di builder + tabel emisi §1b + arm XS di harness dispatch-parity + replay fixture U-005-class → ukur rasio (angka masuk balasan tim sebagai follow-up).
3. `.pack-skip-list.json` (§3) + perluasan aggregate-parity test.
4. `project_scale` (§2) — paling akhir karena menyentuh generate-intent + intake (surface terbesar); spec emisi vault-nya diamandemen di vault-core.md dulu. Catatan prioritas: lengan brownfield (advisory XS) adalah yang paling langsung menjawab keluhan lapangan MTConvert — owner boleh menariknya maju bila mau.

Tiap langkah: satu commit, suite dua tree, CI hijau, moat tidak disentuh.
