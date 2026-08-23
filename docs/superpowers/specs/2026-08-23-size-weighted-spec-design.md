# Size-weighted spec — desain (GATE: menunggu approval owner, JANGAN implement dulu)

**Status: DESIGN-ONLY.** Sumber: feedback tim (Igoo0/feedback-mega-sdd, diukur 6.12.0 — rasio instruksi:kode 17.9:1 pada unit 22 baris; 5.8:1 spec:kode; 28 OQ untuk 3 screen) + triage `research/2026-08-23-team-feedback-triage.md` №A. Gap yang dikonfirmasi: routing v7.1 menskalakan **panel review + model** per unit, tapi TIDAK menskalakan **payload dispatch prompt** dan **kedalaman vault**. Ini kelanjutan alami S/M/L (v7.0.0 anchor, v7.1.0 panel/model) turun ke level UNIT dan PROJECT.

**Rambu tetap (tidak bisa dinego):** tidak ada gate anti-halu yang dilonggarkan. XS memangkas *muatan* (byte yang dimuat), bukan *bukti* (acceptance test tetap wajib dieksekusi; binding refs tetap disitir; citation discipline utuh). Doktrin "unknown never lowers a tier" (P3/A5) berlaku di semua field baru.

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

## 2. `project_scale: xs|s|m|l` — skala project di generate-intent

- **Sinyal ukuran**: jumlah screen/flow/entity yang diparse dari PRD (hitungan deterministik atas struktur dokumen — heading/tabel — bukan judgment; ambang: xs ≤3 screen & ≤2 entity, l ≥ ~15 screen; angka final ditera saat implementasi terhadap korpus PRD yang ada).
- **Penyimpanan**: scalar `project_scale` di frontmatter vault (kelas lock-scalar per keputusan Fase 3 — frontmatter = skalar saja, section tetap md) + mirror di `vault.json` untuk konsumen script.
- **Konsekuensi XS**:
  - Bagian vault OPSIONAL **tidak diemisi** (bukan diisi placeholder — konsisten doktrin "omit, never fabricate"); inventaris bagian-opsional diambil dari template layout-2 saat implementasi.
  - **OQ tech**: ambang auto-resolve naik — di XS, tech/scan OQ yang hari ini `medium` confidence masuk **defer-by-default** (tercatat di Auto-Classification Review, TIDAK ditanyakan interaktif), bukan auto-resolve tanpa bukti: auto-resolve tetap mensyaratkan citation probe nyata seperti sekarang (`high` + single unambiguous match). Yang berubah = ASK vs DEFER, bukan standar bukti.
  - **OQ business**: tidak berubah — tetap human-decided (rail anti-halu; keterangan Indonesia per standing rule).
- Target: skenario kelas "3 screen statis" tidak lagi menghasilkan 28 pertanyaan interaktif; angka tim jadi baseline pembanding.

## 3. Validator SKIP-by-construction di pack universal → tidak di-dispatch

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
4. `project_scale` (§2) — paling akhir karena menyentuh generate-intent (surface terbesar); spec emisi vault-nya diamandemen di vault-core.md dulu.

Tiap langkah: satu commit, suite dua tree, CI hijau, moat tidak disentuh.
