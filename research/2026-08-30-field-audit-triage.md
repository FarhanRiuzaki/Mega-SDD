# Triage audit lapangan — HOST-AS400 / dd9000-gate (36 unit, 117 commit)

**Tanggal**: 2026-08-30
**Sumber**: `HOST-AS400/.mega-sdd/AUDIT-PIPELINE.md` (sesi audit read-only; 17 pembaca paralel, 1.148 fakta beranchor, 33 temuan F + 8 layak-dibayar D). Objek audit = proses mega-sdd, bukan kode aplikasi.
**Versi produsen run**: campuran 7.6.0 (sesi-1, 14 unit) → 7.8.0 (sesi-2, 22 unit); artefak bukti tidak menstempel versi (F-26).
**Goal user**: skills yang on point + objektif, hemat token, cepat, akurat.

## 0. Kesimpulan satu paragraf

Yang mahal di run ini **bukan verifikasi** — yang mahal adalah **tier yang tidak bisa gagal** dan **prosa yang mengaku gate**. Terukur: postflight directive 278 rule → 0 fail; acceptance B4 69 entri → 0 fail sepanjang run, sementara 18 commit fix lahir dari penangkap lain; `DO_NOT_MODIFY` machine tier 6 false positive / 0 true positive. Sebaliknya, panel lensa + halt agen menangkap **setiap** defect nyata kelas tinggi (D-01, D-02: CORS reflect + credentials, kebocoran `error.message`, test yang meng-assert stub, route PII tanpa auth, dual-control commit sebelum approve) — dan suite hijau 579/0 tidak melihat satu pun. Arah: **berhenti membayar yang tidak bisa gagal; jadikan yang menangkap defect tidak bisa dilewati.**

Filter yang dipakai untuk semua temuan: **apakah mekanismenya reachable?** F-09 (gate cuma menyala 1× dalam 117 commit) dan F-14 (pack proyek tidak pernah resolve → seluruh keluarga gate pack-driven SKIP) berarti banyak "diam" di run ini adalah bukti *tidak pernah jalan*, bukan bukti *tidak berguna*. Memangkas berdasarkan diam yang kita sebabkan sendiri = kesalahan pengukuran.

## 1. Verifikasi independen atas anchor kunci (kode plugin @ `ffaf2fc`)

| Temuan | Anchor audit | Diverifikasi di kode | Hasil |
|---|---|---|---|
| F-09 satu pintu gate | `hooks/pre-tool-use` | `:771` `if [ "$SKILL_NAME" = "mega-sdd:execute-bolts" ]`; `hooks.json` matcher `Skill\|Bash\|Edit\|Write` — `Agent` **sengaja dikecualikan** (`CLAUDE.md:38`) | CONFIRMED. Dispatch bolt-implementer via Agent tidak pernah menyentuh aggregator |
| F-06 predikat DO_NOT_MODIFY | `postflight_rules.py:505-520` | snapshot sha diberi **precedence**; touched-set hanya fallback `elif unit_commits` | CONFIRMED |
| F-06 celah guard `mv` | `pre-tool-use:1432` | regex `\b(mv\|cp)\s+[^\|;&]*\s+[^\|;&]*($PROTECTED)` — PROTECTED hanya cocok di argumen **kedua** (destinasi) | CONFIRMED. `mv preflight.json preflight.stale.json` lolos |
| F-18 `expects` vacuous | `run-acceptance-tests.sh:220` | `passed = (rc==0) and ((not expects) or (expects in out))` — string kosong = term benar-vakum; tidak ada writer/gate yang menolak kosong | CONFIRMED — prosa-vs-mekanisme di rilis 6.1.1 sendiri |
| F-30 emisi tak-bersyarat | `build-dispatch-prompt.sh:2218` | menyebut dirinya "the UNCONDITIONAL T1 path"; anti-context `:1653` di-append tanpa syarat | CONFIRMED |
| F-16 nol rel git | `pre-tool-use` Bash branch | tidak ada guard `git add -A` / `commit -a` / `--amend` / `stash` sama sekali | CONFIRMED |

## 2. Verdict per temuan (tiga keluaran saja: SPEC / TOLAK-dengan-angka / BELUM-BISA-DIPUTUS)

### Tranche 1 — akurasi gratis, nol surface baru → **SPEC** (`docs/superpowers/specs/2026-08-30-audit-driven-hardening.md` §1)

| ID | Verdict | Alasan |
|---|---|---|
| F-09 | SPEC | Gate sebagus D-04 (memaksa backfill 11 unit, menangkap scope U-019, orphan U-008) hanya menyala 1×. Dispatch `bolt-implementer` via Agent ikut ke aggregator, dengan semantik in-run (minus B2, minus evidence unit in-flight) agar wave & fix-round tidak false-deny |
| F-06 | SPEC | 6 FP / 0 TP + 15 baseline basi laten = net-negatif. Touched-set jadi primer; snapshot jadi catatan; guard `mv` ditutup di posisi sumber |
| F-16 | SPEC | Fase 2 (7.7.0) membalik default ke wave **tanpa rel** — commit BLOCKER menyapu 1.031 baris sibling, `--amend` 11×. Rel: deny bentuk `add -A/-a/.`, `commit -a/--amend`, `stash`, `reset --hard` selama ada bolt in-flight (derived dari disk) + kontrak pathspec di implementer |

### Tranche 2 — potong token, nol deteksi hilang → **SPEC** (§2)

| ID | Verdict | Alasan |
|---|---|---|
| F-30 | SPEC | Residu enrichment dispatch bukan cuma token: T1 lewat cap → cascade T2 memangkas `symbol_slice`/`design_slice` −66% sampai implementer menandai MEDIUM. Ini token **dan** akurasi |
| F-01(a) | SPEC | Directive `attested` tidak boleh membentuk status gate — 256 rule, 0 fail, counterfactual "advisory" tidak kehilangan satu deteksi pun. Dipisah jadi kolom `attested_by`; status gate = rule mesin saja |
| F-31 | SPEC | Artefak tanpa konsumen (`_index.md` basi, `ai-consumer-guide.md`, `modules.yaml.auto`, `scaffold/`) — audit sendiri menggugurkan dua kandidat; sisanya derive-on-demand |

### Tranche 3 — bikin yang bagus jadi wajib → **SPEC** (§3)

| ID | Verdict | Alasan |
|---|---|---|
| F-07 | SPEC | Panel menangkap semua defect nyata tapi berjejak ≤17/36. Gate `panel-evidence`: unit `standard`/`full` tanpa `findings.json` ber-skema = evidence missing |
| F-08 | SPEC | `merge-panel-findings.sh` "SOLE writer" tidak pernah menulis satu ledger pun; 3 ledger ditulis tangan. `findings.json` masuk daftar guard + gate membaca skema |
| F-18 | SPEC | `expects` kosong = vacuous. Writer menolak kosong untuk `type: test`; gate membaca |
| F-26 | SPEC | Stempel `plugin_version` + `tier`/`lenses` + durasi di semua writer artefak |

### Ditolak dengan alasan tercatat — **jangan diusulkan ulang tanpa data baru**

| ID | Verdict | Angka |
|---|---|---|
| F-01(b) per-rule attestation | TOLAK | Beban controller ×5–11 per unit (audit sendiri: "proyek prose-berat bisa macet — jalur ast-grep v2 harus disiapkan dulu"). Diblokir oleh F-14 |
| Keluarga gate pack-driven (ui-quality, flow-coverage, cross-cutting, sibling, render-test) | BELUM BISA DIPUTUS | 36/36 dispatch `_universal` karena resolver tidak melihat pack proyek (F-14). Tidak ada satu pun bukti kinerja — ukur **setelah** F-14, bukan sebelum |
| F-03 kanonisasi nama field lintas dokumen di generate-intent | TUNDA | Blast radius besar (validator 3 permukaan + edge otomatis konsumen→produsen); satu cacat nyata (S2/S3) — layak, tapi bukan tranche ini |
| F-04/F-05 validator dual-control + marker human-decision | TUNDA | Satu kejadian; D-01 menunjukkan halt agen SUDAH menangkapnya. Marker `human-decision-pending` = spec sendiri |
| F-14 resolver pack proyek | SPEC-terpisah | Akar dari "gate pack-driven hampa"; perbaikan resolver + `state.json` refresh. Prasyarat pengukuran gate pack-driven |
| F-12 ledger concern | TUNDA | Pola concern→unit bekerja 6× via disiplin controller; formalkan `concerns_for:` setelah F-07/F-08 (ledger dulu, baru konsumen) |
| F-19/F-20/F-21/F-22/F-23/F-24/F-25/F-27/F-28/F-29/F-32/F-33 | BACKLOG | Nyata, beranchor, tapi masing-masing r2–r3 dan tidak menyentuh goal "cepat/murah/akurat" secara langsung. Dicatat; diprioritaskan setelah T1–T3 terukur |

## 3. Batas triage ini

- "Panel berjejak ≤17/36" = ketiadaan **jejak**, bukan ketiadaan peristiwa (audit §4 batas 2 — transkrip tidak tersedia). Fix F-07/F-08 tetap benar untuk audit trail; tidak diklaim sebagai "15 unit tidak direview".
- Verifikasi adversarial multi-agent audit tidak berjalan (session limit); anchor kunci diverifikasi ulang di §1 langsung dari kode.
- Angka biaya token/durasi run tidak terekam (F-26) — semua klaim biaya adalah batas bawah.
