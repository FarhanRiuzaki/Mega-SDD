# Vanilla Claude Code vs mega-sdd — xs + klinik, n=3 per arm (MEASURED)

**Tanggal:** 2026-09-26/27 · **Runbook:** `benchmarks/runbooks/vanilla-vs-megasdd.md` (target, seed, dan aturan keputusan dikunci sebelum run) · **Data:** `benchmarks/results/vanilla-ab/` (`metrics.json` + `quality.score.json` per run, `REPORT.md`, `compare.json`) · **Plugin:** mega-sdd 8.8.1 (tree branch `bench/vanilla-arm`, dimuat sebagai `mega-sdd@inline`) · **Model:** opus untuk semua arm dan scorer.

## 1. Jawaban singkat

Pada dua skenario yang diukur, **mega-sdd tidak lebih cepat, tidak lebih hemat, tidak lebih ringan, dan tidak lebih berkualitas daripada Claude Code polos**. Verdict `compare-arms.py` vs vanilla, per metrik:
- **WORSE di setiap arm dan skenario (rentang tidak overlap):** speed (review-ready, wall, API time), token (total, input, output, cache read), biaya, tool call, subagent, distinct files read, dan baris `.mega-sdd/` ter-commit.
  - xs: 6–12× lebih lama, 11–22× lebih mahal.
  - klinik: 2,4× lebih lama, 8,8× lebih mahal.
- **Metrik lightness lain tidak seragam:**
  - baris kode + test: OVERLAP di xs (lite 906 [656–922], classic 1.166 [816–1.183] vs vanilla 741 [700–1.042]), WORSE di klinik lite (10.597 vs 5.886, 1,8×);
  - baris markdown di luar `.mega-sdd/`: OVERLAP di xs; **BETTER** di klinik lite (0 [0–41] vs 78 [57–95]). Dokumen pipeline ditulis ke `.mega-sdd/`, yang dihitung terpisah dan WORSE (123.824 baris);
  - interaction points dan silence > 5 menit: OVERLAP (0 di semua arm).

Kualitas:
- xs: lebih rendah (AC 11/12 vs 12/12, rubric 84/82 vs 95).
- klinik: tidak terbukti berbeda (AC, Critical, dan Important OVERLAP; rubric 85 vs 90).

Critical = 0 di semua 15 run bersih yang dinilai.

Selisihnya menyempit dari xs ke klinik (waktu 6,4× → 2,4×, biaya 11× → 8,8×). Tapi pada skala klinik (20–22 unit per run bersih; dihitung dari work tree lokal, tidak bisa dicek dari data mentah yang ter-commit), arah hasilnya belum berbalik.

## 2. Setup

| | |
|---|---|
| Fixture | `create-next-app@16.3.6` (ts, app, eslint, tailwind, src-dir) + PRD. xs `ff006be`, klinik `2f1c78c`. `npm install` di luar jam ukur. **Deviasi:** fixture historis `training-nextjs @ c6821ad` tidak tersedia (SCM internal tidak ter-resolve), jadi angka ini tidak sebanding dengan §8c runbook |
| Arm | `vanilla` (plugin mega-sdd dimatikan per sesi, wrapper `/mega-sdd` user-level dipindah sementara; purity dicek dari record init) · `lite` (`--lite`) · `classic` (default lane) |
| Roster lain | identik di semua arm: superpowers 6.4.1, agents-md, telemetry |
| Urutan | acak ber-seed (xs `20260926`, klinik `20260927`), berurutan, satu salinan fixture per run |
| Kualitas | checklist tersembunyi (xs X1–X12, klinik C1–C10) + rubrik severity. Scorer `claude -p` baru tanpa plugin mega-sdd, label acak, salinan tanpa `.mega-sdd/`, `bolts/`, dan trailer provenance |
| Bersih | 1 proses, 0 outage/resume, purity PASS, 0 sistem sleep (`sleep-check.py`) |

## 3. Hasil (median [min–max], run bersih, n=3 per arm)

| xs | vanilla | lite | classic |
|---|---|---|---|
| review-ready (menit) | 3,2 [3,1–5,7] | 20,2 [15,1–23,1] | 38,5 [36,7–41,8] |
| biaya (USD) | 1,03 [0,91–1,45] | 11,29 [9,83–11,90] | 22,47 [21,87–22,52] |
| token total | 1,0 M | 20,2 M | 54,0 M |
| tool call / subagent | 33 / 0 | 304 / 19 | 456 / 32 |
| baris `.mega-sdd/` ter-commit | 0 | 40.335 [3.797–48.182] | 39.712 |
| baris kode + test | 741 | 906 | 1.166 |
| AC | 12/12 | 11/12 | 11/12 |
| Critical / Important | 0 / 0 | 0 / 2 | 0 / 2 [0–3] |
| rubric | 95 | 84 [80–89] | 82 [77–87] |

| klinik | vanilla | lite |
|---|---|---|
| review-ready (menit) | 30,0 [25,5–35,8] | 70,6 [65,0–93,9] |
| biaya (USD) | 7,68 [6,29–7,81] | 67,33 [53,29–73,27] |
| token total | 13,1 M | 146,9 M |
| tool call / subagent | 98 / 0 | 1.777 / 126 |
| baris `.mega-sdd/` ter-commit | 0 | 123.824 |
| baris kode + test | 5.886 | 10.597 |
| AC | 10/10 (3 run) | 9/10, 10/10, 9/10 |
| Critical / Important | 0 / 2 [1–2] | 0 / 2 [2–3] |
| rubric | 90 [89–90] | 85 [85–87] |

Interaction points (upaya `AskUserQuestion`) = 0 di semua arm. Ini headless, dan setiap tanya diganti pilihan konservatif `[ASSUMED-BY-RUNNER]`.

## 4. Temuan kualitas — diverifikasi tangan, bukan dipercaya dari scorer

- **xs, 6 run mega-sdd (lite + classic):** tidak ada script `test` di `package.json` (test ada dan lolos via `node --test`, tapi `npm test` gagal) → X12 FAIL. Di **keenam** run juga tidak ada link navigasi ke Tentang Kami (dicek dengan grep `href`). Scorer menandai keenamnya: 5 sebagai Important, classic-3 sebagai Minor ("No site navigation; Beranda does not link to Tentang Kami"). Ketiga vanilla punya nav di `layout.tsx`. PRD tidak mewajibkan link itu secara eksplisit, jadi ini temuan usability yang nyata tapi di luar teks PRD.
- **Klinik lite-2 dan lite-4:** `npm run build` gagal saat prerender (`/staff/login`, `/staff/reception`) kalau env kosong. Dijalankan ulang 2026-09-27: exit 1. Belakangan `delivery-check.sh` (D4: checkout fresh, env kosong) menemukan lite-3 juga gagal, jadi 3/3 run bersih, bukan 2/3 (`clinic/lite-*/delivery-check.json`). vanilla-1 build exit 0 (hanya warning secret default). Lite-2: 1 dari 220 test gagal di TZ lokal (lolos dengan `TZ=UTC`).
- **Klinik, semua arm:** temuan Important yang sama kelasnya muncul di kedua sisi. Contohnya: tidak ada scheduler untuk sweep reminder (vanilla-1, lite-4), `/book` tanpa rate limit (lite-2, lite-3), dan Schedule-X diganti grid custom (vanilla-1, vanilla-3).
- **Reliabilitas scorer:** blok xs lite/vanilla dinilai dua kali dengan label berbeda. Ronde 1 bocor lewat `.gitignore`, ronde 2 strip semua file teks. AC, Critical, dan Important identik di kedua ronde. Rubric bergeser 1–8 poin per run (`quality.score.round1.json` → `quality.score.json`): vanilla-1 93 → 96, vanilla-2 94 → 95, vanilla-3 93 → 95, lite-1 88 → 89, lite-2 87 → 84, lite-3 88 → 80.

## 5. Ke mana biaya mega-sdd pergi (MEASURED dari stream)

- **Subagent:** per unit ada 1 implementer + panel. Contoh xs lite-1: 6 implementer, 6 spec, 3 quality, 3 standards, 3 design = 21 dispatch. Klinik: 115–134 dispatch per run. Vanilla: 0. Total 21 dan rentang klinik ada di `metrics.json`; rincian per jenis dihitung dari `stream.jsonl` lokal, jadi tidak bisa dicek dari data mentah yang ter-commit.
- **Model:** xs lite 77–87% biaya dari opus (controller + implementer), sisanya sonnet (lens). Dihitung dari `modelUsage` di `stream.jsonl` lokal. `metrics.json` tidak memuat biaya per model, jadi tidak bisa dicek dari data mentah yang ter-commit.
- **Artefak proses ter-commit:** 40k (xs) sampai 124k (klinik) baris di `.mega-sdd/`, termasuk HTML render otomatis (±3.505 baris per file). Semua itu masuk repo dan diff review.
- **Rantai tetap per run:** front door, `orchestrate-flow`, `plan`, `execute-bolts`, `detect-drift`, `analyze`, masing-masing sekali.

## 6. Keputusan menurut aturan yang dikunci (runbook §7)

| Keputusan | Hasil |
|---|---|
| Klaim "mega-sdd lebih cepat / hemat / ringan / kuat dari Claude Code" | **TIDAK BOLEH.** Tidak ada metrik speed, token, biaya, atau kualitas yang `BETTER` di skenario mana pun. Satu-satunya `BETTER` di blok ini adalah baris markdown di luar `.mega-sdd/` pada klinik lite (0 [0–41] vs 78 [57–95]). Menurut aturan §7 itu hanya mengizinkan klaim sempit tentang metrik itu sendiri, bukan "lebih ringan": run yang sama meng-commit 123.824 baris `.mega-sdd/` (WORSE) |
| Klaim "kualitas setara" | xs: **tidak**. WORSE untuk AC rate, completion, dan rubric (lite dan classic), plus Important di lite (2 [2–2] vs 0); Important classic dan Critical OVERLAP. Klinik: "tidak terbukti berbeda" untuk AC, completion, Critical, dan Important; rubric WORSE |
| `--lite` jadi default | **Belum bisa diputuskan dengan aturan yang dikunci.** Aturannya butuh kedua skenario, dan klinik classic belum diukur. Di xs saja, lite mengalahkan classic di waktu (15–23 vs 37–42 menit) dan biaya ($10–12 vs $22), rentangnya tidak overlap, sementara kualitasnya OVERLAP. Arahnya jelas, tapi syaratnya belum lengkap |
| H1 (lens standards) / H2 (plan tidak membaca `generate-units/SKILL.md`) | Tidak diuji. Keduanya memangkas paling banyak beberapa persen, sedangkan gap token terhadap vanilla jauh lebih besar: total token 20,1× (xs lite), 53,6× (xs classic), 11,2× (klinik lite); output token 8,3×, 12,9×, 6,6×. Menguji keduanya tidak menjawab pertanyaan utama |

## 7. Implikasi (inferensi dari angka di atas, bukan pengukuran tambahan)

1. Nilai jual "anti-halusinasi / kualitas" belum tampak di skenario greenfield ini. Vanilla sudah mencapai Critical 0 dan AC penuh tanpa pipeline.
2. Selisih yang menyempit dari xs ke klinik membuka kemungkinan ada titik impas di skala lebih besar, brownfield, atau PRD yang ambigu. Moat mega-sdd (binding CONFLICT, OQ) paling relevan di kasus seperti itu, dan kedua skenario ini tidak mengujinya. Itu eksperimen berikutnya, bukan kesimpulan.
3. Beban yang paling bisa dikendalikan tanpa menyentuh moat:
   - jumlah dispatch panel per unit,
   - artefak `.mega-sdd/` (HTML render, laporan) yang ter-commit ke repo,
   - rantai end-of-run (`detect-drift` + `analyze`) yang jalan di setiap run.

   Menurut runbook, ketiganya harus diuji dengan arm vs vanilla, n ≥ 3, sebelum ada yang diubah.

## 8. Batasan

- Headless (tanpa manusia) → tidak mewakili sesi interaktif. Deviasinya sama di semua arm.
- Satu mesin, satu hari, satu akun. Klinik lite-2 mengalami 23 API retry (401 + koneksi putus, ±90 s), tetap dihitung bersih karena 1 proses dan tanpa sleep. Klinik lite-1 kena sistem sleep dan dikeluarkan; lite-4 adalah penggantinya (runbook §4).
- Fixture greenfield saja. Brownfield (tempat binding bekerja) tidak diukur.
- Kebutaan scorer tidak sempurna. xs classic-1 menyisakan file `AGENTS.mega-sdd.md` (nama file); struktur kode bisa membocorkan arm.
- n=3: tidak ada klaim signifikansi. Verdict hanya "rentang tidak overlap" vs "overlap".
- Klinik classic tidak diukur (historis n=1: $259,66, wall 301,4 menit, plugin 7.35.0, fixture lain; runbook §8c).
- Biaya blok ini: vanilla $25,17 (xs $3,39 + klinik $21,78), lite xs $33,02, classic xs $66,86, lite klinik $225,67 (termasuk lite-1 yang tidak bersih), scorer $10,03 (21 sesi `claude -p`), probe roster $0,04 (2 × $0,02) → total ≈ $360,79. Biaya run MEASURED dari `metrics.json` yang ter-commit. Biaya scorer dan probe diambil dari stream lokal (`score.jsonl`, `probe/*.jsonl`), jadi tidak bisa dicek dari data mentah yang ter-commit.
