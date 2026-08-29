# Spec — execute-bolts: efisiensi, relevansi, dan urutan sprint

**Tanggal**: 2026-08-29
**Riset pendukung**: `research/2026-08-29-panel-cost-field-measurement.md` (pengukuran lapangan, HOST-AS400 / dd9000-gate, 30 unit)
**Mandat user**: "buat skills execute bolt beserta pipeline atau turunannya se efisien mungkin, bisa atur mana yg perlu dan ga perlu, mana yang penting dan tidak. dan yg terpenting urutan units nya bisa sesuai dengan tahap dev seperti sprint"

## 0. Baseline terukur (bukan estimasi)

Per bolt: implementer r1 ~70k/10mnt + panel 4 lensa ~267k/4–6mnt + implementer r2 ~70k/10mnt = **~400k token, ~25 mnt**.
30 unit sekuensial: **~150 dispatch, ~12M token, ~12,5 jam wall-clock.**

Tiga fakta yang menentukan desain:

1. **Tier router runtuh ke `full` 100%** — `if fired: tier="full"` adalah OR atas 6 predikat yang mengukur hal berbeda. `file_count>=4` (fakta ukuran, bukan risiko) menyala 22/30. Diukur: `full` 30/30, `minimal` **0/30** — padahal header skrip mengklaim P3 membuat `minimal` reachable.
2. **`--parallel` sudah mengimplementasikan sprint** — topological layering + overlap rail + in-flight cap sudah ada di `batch-and-fanout.md §--all`. **Tapi default-nya OFF.** DAG dd9000-gate = 10 tingkat, lebar paralel maks 7. Sekuensial membakar 12,5 jam untuk kedalaman kritis yang cuma 10 gelombang.
3. **Severity→status mapping tidak ditegakkan** — panel U-001 selesai dengan 2 `critical` + 7 `important` + 4 `minor`, dan **ketiga-tiganya distempel `open`**. `review-panel.md §Attempt rounds` mewajibkan Important/Minor masuk `advisory` (never gating). 11 dari 13 temuan menyandera ronde fix tanpa dasar kontrak.

## 1. Fase 1 — Disiplin ronde (TERUKUR: 11 dari 13 temuan over-gated)

**Masalah, terverifikasi di panel U-001 yang sudah SELESAI** (4 lensa masuk, `spec_verdict: pass`):

| | Kontrak `review-panel.md §Attempt rounds` | Ledger nyata |
|---|---|---|
| `critical` ×2 | `open` | `open` ✓ |
| `important` ×7 | **`advisory` — never gating** | `open` ✗ |
| `minor` ×4 | **`advisory` — never gating** | `open` ✗ |

**11 dari 13 temuan (85%) distempel `open` padahal kontrak melarang.** Ini bukan placeholder pra-merge — panel sudah lengkap. Severity→status mapping adalah prosa di `review-panel.md` yang diterapkan model pengemudi controller; prosa tidak menegakkan apa pun (*gates > rules > hooks*).

**Biayanya bukan "ronde 2 yang tak perlu".** Ronde 2 di U-001 SAH — ada 2 Critical asli. Biayanya adalah **skala ronde itu**: dispatch fix membawa 13 open finding, dan `resolution-verifier` harus memverifikasi 13 alih-alih 2 — lingkup implementer dan verifier sama-sama ×6,5. Temuan `minor` seperti F-011 (nit) ikut menyandera penutupan ronde.

**Perubahan**:

- Skrip baru `scripts/merge-panel-findings.sh --unit=U-XXX --vault=<path> --lens-report=<file>...` — satu-satunya penulis `findings.json`. Ia yang menerapkan: `critical` ∪ spec-❌ → `open`; `important`/`minor` → `advisory`; evidence-or-drop (`file:line` wajib); dedup; consensus. Deterministik, bukan penilaian model.
- Skema ledger di-**pin** ke bentuk terdokumentasi (`schema`, `unit`, `attempt`, `findings[]`). Field karangan (`unit_id`, `head_sha`, `round`, `lenses_reported`, `spec_verdict`) direkonsiliasi: yang berguna masuk kontrak resmi, sisanya dibuang.
- **Gate ronde** membaca `status`, bukan severity mentah: re-dispatch hanya untuk `status: open`.

**Delta terukur**: pada U-001, ronde fix menyusut dari 13 → 2 temuan yang harus ditutup (−85% lingkup ronde). Penghematan token per unit **bergantung isi temuan** dan TIDAK diklaim sebagai angka tetap.

## 2. Fase 2 — Rencana sprint (lever wall-clock terbesar)

**Masalah**: urutan eksekusi tidak pernah terlihat sebagai tahapan; `--parallel` off by default; tidak ada batas checkpoint yang manusiawi.

**TIDAK ada skrip baru — surface-nya sudah ada.** `scripts/analyze-parallelism.sh --format=json` sudah mengeluarkan persis rencana sprint itu, terverifikasi atas vault dd9000-gate hidup: `depth:10`, `max_width:7`, `waves[]` identik dengan hitungan independen, plus `critical_path`, `forks`, `joins`, `bottlenecks`, `parallelism_speedup:3.0`, dan `--format=mermaid`. Membuat `derive-sprint-plan.sh` akan menduplikasi surface — dilarang (reuse over new surface).

**Perubahan**:

- **Angkat `analyze-parallelism.sh` jadi produser rencana sprint resmi.** `execute-bolts --all` menjalankannya (satu spawn, deterministik) dan mengkonsumsi `waves[]` — jalur konsumsi wave-plan ini sudah tertulis di `batch-and-fanout.md §--all`; yang hilang hanyalah menjalankannya sendiri alih-alih menunggu chain menaruhnya di context.
- **Satu field baru** di JSON-nya: `blocks` per unit = tutupan transitif reverse-`depends_on` (U-001 = 29). `forks[].dependents` yang ada hanya menghitung dependent **langsung** (U-012 = 5) — Fase 3 butuh angka transitif untuk membenarkan panel ketat di unit fondasi. Reuse penutupan yang sudah dipakai `derive-transitive-impact.sh`; jangan tulis traversal ketiga.
- **Render Mermaid**: `--format=mermaid` sudah ada — dipakai apa adanya untuk menampilkan tahapan sprint (aturan keras proyek: setiap flow = Mermaid, tidak pernah ASCII/prosa). Yang ditambah hanya label sprint + lebar gelombang.
- `execute-bolts --all` **default = wave execution** (bukan sekuensial). `--sequential` jadi opt-out eksplisit. **`parallel_max` tetap 4.** Diukur atas lebar gelombang nyata `[1,2,3,4,7,3,3,2,4,1]`: cap 4 → 11 slice, cap 6 → 11 slice — identik. Menaikkannya tidak membeli apa pun di DAG ini dan membuka kembali hazard yang v7.1 tutup sengaja (fan-out × implementer ~80 giliran). Outlier ditangani `config.yaml`, bukan default baru.

- **Batas sprint = checkpoint.** Setelah tiap sprint: ringkasan satu blok (unit selesai, temuan advisory, gate, waktu) lalu lanjut. `--sprint-checkpoint` (opt-in) menahan di batas untuk review manusia — inilah "tahap dev seperti sprint" yang diminta.

- `--sprint=<n>` — jalankan satu sprint saja. Prasyarat: semua sprint sebelumnya selesai; kalau tidak → halt `sprint_blocked_by` (bentuk sama seperti `module_blocked_by` yang sudah ada).

**Delta terukur-harapan**: dd9000-gate 30 unit sekuensial ~12,5 jam → 10 gelombang dengan cap 4 ≈ **~4 jam** (~−68% wall-clock; `parallelism_speedup: 3.0` dari skrip, dihitung deterministik atas DAG yang sama). Token tidak berubah karena ini — paralelisme memindahkan waktu, bukan biaya.

## 3. Fase 3 — Relevansi panel ("mana perlu, mana tidak")

**Masalah**: satu sinyal apa pun membeli keempat lensa. Yang dibutuhkan: tiap sinyal membeli lensa yang *dibenarkannya*.

**Perubahan pada `resolve-review-tier.sh`** — keluarkan `lenses[]`, bukan `tier` tunggal (field `tier` tetap ada untuk kompatibilitas flag/config):

| Lensa | Menyala bila |
|---|---|
| `spec` | selalu — moat, tidak pernah dilewati |
| `standards` | selalu kecuali `minimal` (sonnet, murah) |
| `quality` | `file_count ≥3` ∪ `risk: high\|critical` |
| `security` | `auth_globs` ∪ `manifest` ∪ `constitution_b` ∪ `vocabulary`* ∪ `risk: critical` |
| `design` | `ui_bearing` (tidak berubah) |

\* **`vocabulary` di-scope ke seksi kontrak** (`## Hard rules`, `## Acceptance criteria`, `## Requirements`, `## UI contract`) — bukan `## Goal` / `## Context` / `## Implementation steps`. Diukur: 18/30 → 13/30. Kosakata di narasi orientasi adalah false positive; di Hard rules ia klaim yang mengikat.

**`minimal` dibuat terjangkau kembali**: `file_count` berhenti menjadi sinyal *tier* (ia hanya memberi `quality`/`standards`), sehingga unit kecil tanpa sinyal keamanan benar-benar mendarat di `spec`+`standards`.

**Eskalasi `blocks` — DIUKUR, lalu DITOLAK.** Rancangan awal: `blocks ≥ 10` menaikkan unit ke set lensa penuh. Diukur atas 30 unit: 9/30 unit punya `blocks ≥ 10`, tapi **7 di antaranya sudah mendapat set penuh dari sinyal asli** — eskalasi hanya menambah lensa pada **2 unit**, dengan biaya −14% → −12%. Dan bentuknya adalah **term OR ketujuh yang memaksa `full`** — persis mekanisme yang fase ini perbaiki. Ditolak (YAGNI + tidak mengulang defect yang sedang ditutup). `blocks` tetap **dilaporkan** (berguna untuk urutan triase + ringkasan sprint), tidak pernah menjadi term router.

**Delta terukur**: 8.670k → 7.470k token panel untuk 30 unit (**−14%**). Kecil sendirian — itu sebabnya ia Fase 3, bukan Fase 1.

## 4. Fase 4 — kontrak implementer yang tidak lengkap (PREMIS AWAL SALAH, dikoreksi)

**Rancangan awal menyalahkan produser. Itu keliru, dan pengukuran yang membantahnya ada di kode sendiri.**

Klaim awal: `generate-units` mengeluarkan U-001 yang tidak dapat diselesaikan cabang manapun, karena `acceptance_test[1]` menyebut `apps/api/test/contract/openapi-coverage.test.ts` yang tidak ada di `target_files` — commit → `whitelist_violation`, skip → acceptance gagal.

**Cabang "commit" itu tidak melanggar apa pun.** Observer B3 (`scripts/validate-bolt-artifacts.sh` §whitelist scan) membandingkan path yang di-commit terhadap `target_files` **∪ sanctioned extras**, dan sanctioned extras **memuat file tes secara eksplisit**, dengan alasan yang tertulis di kodenya sendiri: *"the implementer writes the acceptance test, which units often do not list"*. Predikatnya:

```
(?:^|/)(?:tests?|spec|specs|__tests__)/|_test\.go$|Test\.php$|(?:^|/)test_[^/]+\.py$|\.(?:spec|test)\.[jt]sx?$
```

`apps/api/test/contract/openapi-coverage.test.ts` cocok dua kali (`/test/` dan `.test.ts`). Commit-nya aman.

**Defect sebenarnya: `agents/bolt-implementer.md` tidak pernah memberi tahu implementer soal sanctioned extras.** Kontraknya berbunyi "B3 mem-diff path yang di-commit terhadap `target_files`" — titik. Implementer bernalar dengan benar dari premis yang salah, menolak ketiga cabang, memarkir tes di scratchpad, dan halt `scope_creep_detected`. ~70k token + 10 menit terbakar untuk aturan yang tidak ada.

**Perubahan**:

1. **`agents/bolt-implementer.md`** — kontraknya kini menyatakan `target_files` **∪ sanctioned extras**, mendaftar bentuk path tes, dan memerintahkan: **commit acceptance test walau unit tidak mencantumkannya**; jangan pernah memarkir tes tertulis di luar repo (itu membuat bukti acceptance yang hanya benar di working tree — cabang C yang implementer itu sendiri tolak, dengan benar). Ini fix untuk kasus lapangannya.
2. **`acceptance_path_unowned`** tetap ada tapi **dipersempit ke sisa yang tidak ambigu**: path yang bukan sanctioned extra, tidak dimiliki unit manapun, dan tidak ada di disk — perintah acceptance yang mustahil lulus. `SANCTIONED_RX` di `validate-unit-spec.sh` **byte-identical** dengan predikat B3, dan `tests/acceptance-path/` §A3 adalah tripwire drift-nya: gate yang lebih ketat dari observer yang ia rujuk akan memblokir konvensi normal di setiap unit.
3. **Kaki gate `acceptance-path` di `hooks/pre-tool-use`** — aggregator memblokir per-`halt_type` eksplisit, jadi halt tanpa kaki gate hanya tercatat lalu diabaikan.

**Pelajaran yang layak dicatat**: gate baru yang menduplikasi penilaian gate lama harus membaca predikat gate itu, bukan menebaknya. Versi pertama check ini memflag fixture `sample-project` U-002 — konvensi normal — dan itulah yang memaksa pembacaan B3 yang membatalkan premisnya.

## 5. Yang TIDAK disentuh (moat)

- **Blind dispatch ronde 1** — rail anti-rubber-stamp. Lensa tetap tidak pernah menerima laporan implementer atau verdict lensa lain.
- **`risk: critical` → lensa penuh.** 3/30, jarang, penilaian konsekuensi eksplisit.
- **Gate L0 deterministik + post-flight Hard-rule scan + acceptance test** — jaring regresi, ~0 token, jalan di setiap tier. Panel adalah judgment; ia tidak pernah menjadi jaring regresi.
- **Pembacaan ulang artefak per-lensa** (kandidat leverage terbesar, ~67k/lensa) — menyentuh rail blind review. Dicatat sebagai open, proposal-first, TIDAK dipotong di spec ini.

## 6. Ringkasan dampak

**STATUS: SEMUA FASE SELESAI.** Ship 2 → 4 (v7.7.0, commit 707f343) lalu 1 → 3 (v7.8.0). Suite 222/222.

**Urutan ship: 2 → 4 → 1 → 3.** Fase 2 adalah prioritas yang user nyatakan, mekanismenya sudah ada dan terverifikasi atas vault hidup. Fase 4 risiko nol dan menutup defect yang membakar dispatch nyata. Fase 1 butuh skrip merge baru. Fase 3 menyentuh router — terakhir.

| Fase | Token | Wall-clock | Risiko |
|---|---|---|---|
| 2 sprint plan | ~0 | **−68%** (12,5 jam → ~4 jam, speedup 3,0× terukur) | rendah — mekanisme ada, default dibalik |
| 4 kontrak implementer + gate sempit | −70k + 10 mnt per kejadian (kasus lapangan) | nol — kontrak diperbaiki, gate baru dipersempit ke sisa |
| 1 disiplin ronde | lingkup ronde fix −85% (13→2 di U-001) | tergantung isi temuan | nol — menegakkan kontrak yang sudah ada |
| 3 relevansi panel | −14% | ~0 | sedang — sentuh router; `critical` tetap penuh |

**Yang TIDAK diklaim**: angka "12M → 8M" adalah proyeksi yang mengandaikan ronde 2 dihindari di hampir setiap unit. U-001 sendiri membantahnya — 2 Critical asli, ronde 2 sah. Wall-clock −68% adalah satu-satunya angka gabungan yang berdiri di atas pengukuran (speedup DAG deterministik). Sisanya diukur setelah ship, bukan sebelum.

## 6b. Yang panel BUKTIKAN pantas dibayar

Panel U-001 menemukan 2 Critical asli pada dokumen fondasi yang menahan 29 unit:

- **F-001** (security) — B-004: penolakan otorisasi host (CKAUT / tax amnesty / RDN) tidak punya bentuk respons di kontrak
- **F-002** (quality) — Hard rule C-001 dan C-005 nol pemeriksaan otomatis, padahal berkas ini gerbang semantik satu-satunya

Keduanya cacat kontrak yang akan menyebar ke 29 unit hilir kalau lolos. **Panel bukan pemborosannya.** Yang boros adalah: eksekusi sekuensial atas DAG sedalam 10 (Fase 2), 11 temuan non-gating yang menyandera ronde fix (Fase 1), dan router yang membeli 4 lensa untuk fakta ukuran (Fase 3).

## 7. Kewajiban tes

- `resolve-review-tier.sh`: fixture per baris peta lensa; regresi "OR-collapse" (unit dengan `file_count=6` tanpa sinyal keamanan TIDAK boleh memanggil `security`).
- `analyze-parallelism.sh`: field `blocks` transitif (fixture rantai U-001→…→U-030 harus `blocks:29` di kepala, `0` di daun); regresi bahwa `waves[]`/`depth`/`max_width` yang sudah ada tidak bergeser satu byte pun (field aditif).
- `merge-panel-findings.sh`: Important tidak pernah `open`; temuan tanpa `file:line` di-drop dan dihitung; id stabil lintas ronde.
- `validate-unit-spec.sh`: fixture U-001 (path acceptance tak dimiliki) harus halt.
- Suite penuh dua pohon (top-level + tests/), CI hijau, sebelum klaim apa pun.
