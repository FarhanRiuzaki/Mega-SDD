# Runbook — vanilla Claude Code vs mega-sdd (xs + klinik, n ≥ 3 per arm)

**Status:** arm `routed` (lane router) diukur 2026-09-27 (§8d). Blok xs (vanilla / lite / classic, n=3 bersih masing-masing) dan klinik (vanilla / lite, n=3 bersih masing-masing) **SUDAH DIUKUR** 2026-09-26/27 — hasil §8, analisis commit `cf8d3df3`. Klinik classic **belum diukur**.
**Kenapa ada:** setiap benchmark di repo ini (`benchmarks/results/{baseline,comparison,optimized,p0-baseline,p2-w2,p3}`) membandingkan mega-sdd dengan **mega-sdd versi lain**. Belum pernah ada arm Claude Code tanpa plugin. Jadi klaim "mega-sdd lebih cepat/hemat/ringan/kuat" belum punya pembanding. Aturan repo sejak runbook ini: klaim itu **tidak boleh** ditulis sebelum tabel §8 terisi dan verdict-nya `BETTER` (`plugins/mega-sdd/CLAUDE.md §Release evidence`).

## 1. "Seperti Feather", dijadikan angka

Feather dipakai sebagai target pengalaman: sederhana, cepat, ringan. Tidak ada metrik Feather yang diasumsikan di sini. Targetnya didefinisikan **relatif terhadap vanilla pada task yang sama**, karena hanya itu yang bisa diukur di repo ini.

| Dimensi | Metrik (sumber) | Target yang DIUSULKAN (owner mengunci sebelum run pertama) |
|---|---|---|
| Speed | `review_ready_min` = start sesi → commit terakhir (`arm-metrics.py`) | xs: median mega-sdd ≤ 1,5× vanilla · klinik: ≤ 1,25× vanilla |
| Speed | `wall_min`, `api_time_min`, `stream_silence_over_5m_min` (proxy idle) | dilaporkan, tanpa target |
| Token | `tokens.total`, input / output / cache_read / cache_creation, `cost_usd` | cost median ≤ 2× vanilla (xs) dan ≤ 1,5× (klinik) |
| Lightness | `ask_attempts` (titik interaksi wajib) | ≤ vanilla + 1 |
| Lightness | `docs_md_added` (baris markdown yang ikut ke review) per baris kode | dilaporkan; target ditetapkan setelah n=3 vanilla pertama |
| Lightness | tool calls, subagent dispatch, distinct files read, `init_skills` | dilaporkan, tanpa target (lebih sedikit ≠ lebih ringan tanpa bukti) |
| Lightness | overhead hook per call (§6c) | dilaporkan |
| Power | completion, AC pass rate, Critical / Important (skor buta §5) | Critical ≤ vanilla **dan** AC rate ≥ vanilla — syarat mutlak |

Semua angka di kolom target adalah **usulan**. Owner mengubah atau mengesahkannya di baris "Dikunci" §9 **sebelum** run pertama. Setelah ada angka, target tidak boleh digeser.

## 2. Arm

| Arm | Cara launch | Wajib? |
|---|---|---|
| `vanilla` | `P0_ARM=vanilla benchmarks/scripts/p0-headless-run.sh …`. Plugin mega-sdd dimatikan per sesi (`--settings enabledPlugins false`); prompt = task produk polos | **ya** |
| `lite` | `P0_FLAGS=--lite benchmarks/scripts/p0-headless-run.sh …` | ya (kandidat default) |
| `classic` | `benchmarks/scripts/p0-headless-run.sh …` (default lane hari ini) | ya bila keputusan default lane mau dibuat |
| `routed` | batch arm `routed` (`P0_ENTRY=frontdoor`): prompt = `/mega-sdd:mega-sdd <PRD>`, tanpa flag. Lane router (`route-lane.sh`) yang memilih direct / assisted / guarded; lane yang dipilih terlihat di stream | ya, sejak 2026-09-27 (arm produk setelah router) |
| `gate-only` (diagnostik) | vanilla + hanya CONFLICT gate | **belum ada mekanismenya** — belum ada config yang mematikan semua kecuali gate. Arm ini tidak menggantikan vanilla |

**Kemurnian arm dicek mesin.** Launcher membaca record `system/init` stream (`arm-purity.py`). Arm vanilla yang masih memuat permukaan mega-sdd apa pun (plugin, skill, slash command termasuk wrapper user-level `/mega-sdd`, agent) di-KILL, dan `purity=FAIL` ditulis di `run.meta` (bukan data). Daftar plugin lengkap tercatat di `plugins=` untuk kedua arm.

**Confound yang wajib disamakan:** run historis memuat 9 plugin lain (dua versi superpowers, frontend-design, ui-ux-pro-max, figma, context7, code-review, swift-lsp). Set plugin non-mega-sdd harus **identik** di semua arm dalam satu blok. Bandingkan baris `plugins=` antar arm sebelum reduce.

## 3. Kondisi yang disamakan

- **Fixture:** clone baru `training-nextjs` @ `c6821ad` per run (xs → `PRD/prd-company-profile.md` = `research/2026-09-10-p0-baseline/prd-3screen-xs.md`; klinik → `PRD/prd-clinic.md` = `tests/scenarios/sample-prd-clinic.md`). `npm install` di luar jam ukur.
- **Model / tools / permission:** `opus` (argumen ke-4 launcher), allowlist dan `acceptEdits` diambil dari launcher yang sama. Batas task = PRD yang sama.
- **Mesin:** satu mesin untuk semua run dalam satu blok, dijalankan di bawah `caffeinate`. Catat outage jaringan dan limit akun.
- **Versi:** mega-sdd dari cache yang sudah diverifikasi (`claude plugin list` → `plugin=` di `run.meta`). Versi Claude Code dicatat.

## 4. Urutan dan aturan berhenti

1. Per skenario, buat blok acak: `python3 -c "import random; a=['vanilla','lite','classic']*3; random.seed(<seed>); random.shuffle(a); print(a)"`. Catat seed di §9. Blok xs dulu, lalu klinik.
2. Run bersih = 1 proses (tanpa `--resume`), 0 key `resume_*`/`outage_*`, `purity=PASS`. Run yang tidak bersih tetap dicatat di tabel dengan alasannya, tapi tidak masuk median.
3. Maksimal 5 percobaan per arm per skenario untuk mendapat 3 run bersih. Kalau gagal, arm itu dilaporkan `INSUFFICIENT` ("lingkungan ukur tidak layak"), bukan diisi dengan run tercemar.

## 5. Kualitas — skor buta, rubrik sama

**(a) Checklist AC tersembunyi.** Dinilai terhadap aplikasi yang jalan dan test suite milik arm. Checklist tidak pernah diberikan ke arm.

| xs | Kriteria (PRD `prd-3screen-xs.md`) |
|---|---|
| X1 | Beranda: judul, tagline, 3 layanan dari file konfigurasi, tombol ke Kontak |
| X2 | Responsif di 375px dan desktop |
| X3 | Tentang Kami: 2–3 paragraf, daftar tim dari konfigurasi, tautan ke Beranda |
| X4 | Field form: nama wajib ≤100, email wajib dan valid, pesan wajib ≤2000 |
| X5 | Validasi di sisi server (bukan hanya di client) |
| X6 | DoD: pesan valid tersimpan di `contact_messages` dengan `created_at` |
| X7 | Pesan sukses tampil di halaman yang sama |
| X8 | DoD: email tidak valid ditolak dengan error di field email |
| X9 | DoD: form tetap terisi setelah gagal validasi |
| X10 | Semua field berlabel, navigasi keyboard berfungsi |
| X11 | Input di-escape, tidak ada HTML mentah dari pengunjung |
| X12 | Test suite arm hijau di HEAD (script test yang hilang = FAIL) dan `npm run build` sukses |

| Klinik | Kriteria (PRD `sample-prd-clinic.md §Clinic.5`) |
|---|---|
| C1–C7 | AC-001 … AC-007 dari PRD |
| C8 | Aturan slot wizard booking: slot 15 menit 09:00–17:00, istirahat 12:00–13:00 dikecualikan, tanggal lampau/akhir pekan dinonaktifkan; validasi nama/email/telepon/alasan di client + server |
| C9 | Resepsionis bisa memindahkan janji ke dokter lain dan membuat booking staf (`booking_channel = staff`) |
| C10 | Test suite arm hijau di HEAD (script test yang hilang = FAIL) dan `npm run build` sukses |

Teks lengkap yang dipakai scorer ada di `ac-checklist-xs.md` dan `ac-checklist-clinic.md` (`ac_total` = 12 dan 10 di `quality.score.json`). Draf awal runbook ini lebih longgar dari yang dipakai untuk skor: X12 hanya "test suite arm hijau di HEAD" (tanpa syarat script test dan `npm run build`), dan klinik ditulis C1–C8 dengan test suite di C8. Checklist yang di-commit dan dipakai untuk skor adalah X1–X12 dan C1–C10 di atas.

**(b) Review buta.** Siapkan diff tiap arm (`git diff <base>..HEAD`) tanpa `.mega-sdd/`, tanpa `bolts/`, dan tanpa baris trailer `Generated by mega-sdd` / `Unit: U-` (penanda arm). Beri label acak (A/B/C…); pemetaannya disimpan terpisah sampai skor selesai. Scorer = sesi `claude -p` baru dengan **plugin mega-sdd dimatikan** (settings yang sama dengan arm vanilla), supaya reviewer mega-sdd tidak menilai dengan konvensinya sendiri. Model sama, prompt rubrik sama untuk semua arm:

> Anda reviewer senior. Input: PRD dan diff implementasi. Nilai HANYA terhadap PRD. Laporkan temuan dengan severity Critical (data rusak / keamanan / requirement inti tidak jalan), Important (bug yang terlihat user / requirement sebagian), Minor (kualitas). Setiap temuan wajib file:line. Lalu beri skor 0–100: correctness 40, requirement coverage 30, keamanan 15, maintainability 15. Output JSON: {"critical": n, "important": n, "minor": n, "rubric": n, "findings": [...]}.

Batasan yang diakui: kebutaan tidak sempurna, karena gaya kode dan struktur file bisa membocorkan arm.

**Batasan headless (berlaku sama untuk semua arm):** `AskUserQuestion` tidak tersedia di `claude -p`, jadi setiap tanya diganti pilihan paling konservatif `[ASSUMED-BY-RUNNER]`, dan human-wait = 0. Perbandingan antar-arm tetap setara karena deviasinya sama. Tapi angka absolutnya bukan angka sesi interaktif (`runbooks/velocity-live-ab.md`). `ask_attempts` menghitung upaya bertanya, bukan jawaban.

**(c) File skor per run:** `benchmarks/results/vanilla-ab/<scenario>/<arm>-<n>/quality.score.json`
`{"completion": 0..1, "ac_pass": n, "ac_total": n, "critical": n, "important": n, "minor": n, "rubric": 0..100, "scorer_sid": "…", "blind_label": "B"}`
`completion` = 1 bila semua AC lulus dan suite hijau. Selain itu = ac_pass / ac_total.

## 6. Prosedur per run

```bash
# a. launch (satu run)
P0_ARM=vanilla bash benchmarks/scripts/p0-headless-run.sh <clone> PRD/prd-company-profile.md benchmarks/results/vanilla-ab/xs/vanilla-1 opus
#    mega-sdd arm: P0_FLAGS=--lite bash benchmarks/scripts/p0-headless-run.sh <clone> … benchmarks/results/vanilla-ab/xs/lite-1 opus
# b. setelah selesai
git -C <clone> log --format="%h %cI %s" > benchmarks/results/vanilla-ab/xs/vanilla-1/git-log.txt
python3 benchmarks/scripts/arm-metrics.py benchmarks/results/vanilla-ab/xs/vanilla-1 \
  --repo <clone> --base c6821ad --json benchmarks/results/vanilla-ab/xs/vanilla-1/metrics.json
# c. skor kualitas buta (§5) → quality.score.json
# d. reduce (setelah semua run)
python3 benchmarks/scripts/compare-arms.py benchmarks/results/vanilla-ab/manifest.json \
  --md benchmarks/results/vanilla-ab/REPORT.md --json benchmarks/results/vanilla-ab/compare.json
```

`manifest.json`:
```json
{"min_clean_runs": 3,
 "targets": {"xs": {"review_ready_min": 60}, "clinic": {"review_ready_min": 120}},
 "runs": [{"scenario": "xs", "arm": "vanilla", "run": "vanilla-1",
           "metrics": "xs/vanilla-1/metrics.json", "quality": "xs/vanilla-1/quality.score.json"}]}
```

**(6c) Overhead hook.** Per arm mega-sdd, hitung tool call yang kena matcher PreToolUse (`Skill|Bash|Edit|Write`) dari `tool_calls_by_name`. Ukur latency hook di jalur dispatch `execute-bolts` terpisah (jalur ini menjalankan ulang validator gate; belum pernah diukur). Satu-satunya angka yang ada: ±50 ms per call untuk Bash di CWD tanpa state SDD (n=3, 2026-09-26). Angka itu bukan angka jalur dispatch.

## 7. Aturan keputusan (dikunci sebelum ada angka)

`compare-arms.py` memberi verdict per metrik: `INSUFFICIENT` (< 3 run bersih di salah satu arm), `BETTER`/`WORSE` (rentang run bersih tidak overlap), `OVERLAP`. Tidak ada p-value; n=3 tidak cukup untuk klaim signifikansi.

| Keputusan | Syarat |
|---|---|
| Klaim publik "mega-sdd lebih X dari Claude Code" | metrik X = `BETTER` vs vanilla di skenario yang disebut, **dan** Critical bukan `WORSE` |
| Klaim "kualitas setara" | Critical dan AC rate tidak `WORSE` (OVERLAP boleh, dan ditulis sebagai "tidak terbukti berbeda") |
| `--lite` jadi default | lite vs classic: cost dan review-ready tidak `WORSE`, AC rate dan Critical tidak `WORSE`, di **kedua** skenario, n ≥ 3. Target absolut dilaporkan di sampingnya, tidak menggantikan verdict relatif |
| Rilis yang mengklaim perbaikan speed/token | arm rilis vs arm rilis sebelumnya **dan** vs vanilla, n ≥ 3. Kalau memburuk terhadap salah satunya, tulis apa adanya |

**Hipotesis overhead yang diuji dengan harness ini (belum diterapkan di kode):**
- **H1 — lens `standards` hanya ikut bila `quality` ikut. DITERAPKAN 2026-09-27 tanpa A/B** (mandat owner: buang proses tanpa manfaat sepadan). Dasarnya bukti lapangan di bawah; pin `tests/size-weighted/test-standards-lens-h1.sh` (panel lens dan pin ini dihapus di P3, spec v9 §8.6). Efek biaya/kualitas pada run belum diukur. Bukti saat ini: yield lapangan 0 Critical dan 1 fix unik dari 5 dispatch di satu project (commit c6064fef §2). n kecil dan statusnya "owner memutuskan". Uji: arm `lite` vs `lite+H1`, n=3 xs + n=3 klinik. Diterapkan hanya bila Critical/Important tidak `WORSE` dan cost `BETTER`.
- **H2 — `plan` berhenti membaca `generate-units/SKILL.md` (31 KB) lintas-skill.** Diganti digest di `plan-procedure.md`. Statis: −31.184 B dari 470.979 B jejak T01 lite (−6,6 %, `measure-context.sh`). Efek runtime belum diukur.
- **H3 — re-derive gate di PreToolUse di-cache per HEAD + hash evidence.** Belum ada angka latency jalur dispatch (lihat 6c). Ukur dulu, baru diputuskan.

## 8. Hasil

### 8a. vanilla vs mega-sdd — xs (fixture `ff006be`, plugin 8.8.1, opus, 2026-09-26)

| arm | run | status | review-ready (min) | wall (min) | tokens total | cost (USD) | asks | subagents | baris `.mega-sdd/` | baris kode+test | AC | Critical | Important | rubric |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| vanilla | 1 | bersih | 3.2 | 3.4 | 1.0 M | 1.03 | 0 | 0 | 0 | 741 | 12/12 | 0 | 0 | 96 |
| vanilla | 2 | bersih | 5.7 | 6.0 | 1.6 M | 1.45 | 0 | 0 | 0 | 1.042 | 12/12 | 0 | 0 | 95 |
| vanilla | 3 | bersih | 3.1 | 3.4 | 0.8 M | 0.91 | 0 | 0 | 0 | 700 | 12/12 | 0 | 0 | 95 |
| lite | 1 | bersih | 20.2 | 20.6 | 21.3 M | 11.90 | 0 | 21 | 48.182 | 906 | 11/12 | 0 | 2 | 89 |
| lite | 2 | bersih | 15.1 | 18.9 | 17.1 M | 9.83 | 0 | 17 | 3.797 | 656 | 11/12 | 0 | 2 | 84 |
| lite | 3 | bersih | 23.1 | 23.4 | 20.2 M | 11.29 | 0 | 19 | 40.335 | 922 | 11/12 | 0 | 2 | 80 |
| classic | 1 | bersih | 41.8 | 42.1 | 55.4 M | 22.52 | 0 | 30 | 39.455 | 816 | 11/12 | 0 | 2 | 77 |
| classic | 2 | bersih | 36.7 | 37.0 | 54.0 M | 21.87 | 0 | 32 | 39.712 | 1.166 | 11/12 | 0 | 3 | 87 |
| classic | 3 | bersih | 38.5 | 38.9 | 52.2 M | 22.47 | 0 | 36 | 40.267 | 1.183 | 11/12 | 0 | 0 | 82 |

Median run bersih (n=3 per arm; rentang di `benchmarks/results/vanilla-ab/REPORT.md`): review-ready vanilla 3,2 · lite 20,2 · classic 38,5 menit; cost $1,03 · $11,29 · $22,47; token 1,0 M · 20,2 M · 54,0 M; AC 12/12 · 11/12 · 11/12; rubric 95 · 84 · 82. Verdict `compare-arms.py` vs vanilla, lite dan classic sama kecuali disebut: **WORSE** (rentang tidak overlap) untuk review-ready, wall, API time, token (total / input / output / cache read), cost, tool call, subagent, distinct files read, dan baris `.mega-sdd/`; **OVERLAP** untuk baris kode+test, baris markdown di luar `.mega-sdd/`, interaction points, dan silence; Critical OVERLAP (0 semua); completion, AC rate, dan rubric WORSE; Important lite WORSE, classic OVERLAP.

### 8b. vanilla vs mega-sdd — klinik (fixture `2f1c78c`, plugin 8.8.1, opus, 2026-09-26/27)

| arm | run | status | review-ready (min) | wall (min) | tokens total | cost (USD) | asks | subagents | baris `.mega-sdd/` | baris kode+test | AC | Critical | Important | rubric |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| vanilla | 1 | bersih | 30.0 | 30.4 | 13.1 M | 7.68 | 0 | 0 | 0 | 6.561 | 10/10 | 0 | 2 | 89 |
| vanilla | 2 | bersih | 35.8 | 36.0 | 13.7 M | 7.81 | 0 | 0 | 0 | 5.886 | 10/10 | 0 | 1 | 90 |
| vanilla | 3 | bersih | 25.5 | 25.9 | 9.2 M | 6.29 | 0 | 0 | 0 | 5.045 | 10/10 | 0 | 2 | 90 |
| lite | 1 | **TIDAK bersih** — sistem sleep (23 event, mulai sebelum commit terakhir); tidak masuk median | 55.9 | 255.2 | 57.2 M | 31.78 | 0 | 82 | 125.407 | 5.963 | tidak dinilai | — | — | — |
| lite | 2 | bersih (23 API retry, ±90 s) | 93.9 | 94.2 | 190.5 M | 73.27 | 0 | 115 | 126.463 | 10.597 | 9/10 | 0 | 3 | 85 |
| lite | 3 | bersih | 70.6 | 70.9 | 90.4 M | 53.29 | 0 | 126 | 123.824 | 9.147 | 10/10 | 0 | 2 | 85 |
| lite | 4 | bersih (pengganti lite-1) | 65.0 | 65.4 | 146.9 M | 67.33 | 0 | 134 | 123.683 | 12.447 | 9/10 | 0 | 2 | 87 |
| classic | — | belum diukur (ditunda: ±$260/run historis) | belum diukur | belum diukur | belum diukur | belum diukur | — | — | — | — | — | — | — | — |

Median run bersih (n=3 per arm): review-ready vanilla 30,0 · lite 70,6 menit; cost $7,68 · $67,33; token 13,1 M · 146,9 M; AC 10/10 · 9/10 (rentang 9–10); Important 2 · 2; rubric 90 · 85. Verdict lite vs vanilla: **WORSE** untuk review-ready, wall, API time, token (total / input / output / cache read), cost, tool call, subagent, distinct files read, baris `.mega-sdd/`, dan baris kode+test (1,8×); **BETTER** untuk baris markdown di luar `.mega-sdd/` (0 [0–41] vs 78 [57–95]; dokumen pipeline masuk ke `.mega-sdd/`, yang WORSE); interaction points dan silence OVERLAP; completion, AC rate, Critical, Important **OVERLAP**; rubric WORSE.

### 8d. routed (lane router) vs vanilla — xs + klinik (fixture sama, 2026-09-27)

Detail per run, verdict, dan batasan: commit `d447a6d2` + `results/vanilla-ab/REPORT.md` (arm `routed`, `routed-v1`, `vanilla-day2`).
- Median: xs 2,7 menit / $1,16 / AC 12/12 / rubric 94; klinik 26,6 menit / $9,30 / AC 10/10 / rubric 91.
- Verdict vs vanilla OVERLAP, kecuali (semuanya formal, tidak ada yang diklaim; beda hari dan prompt asimetris):
  - xs `BETTER`: review-ready, wall, output token, baris kode+test (`routed-v1`: hanya baris kode+test);
  - xs `WORSE`: rubric (median 94 vs 95, beda batch scoring);
  - klinik `BETTER`: Important (0 vs 2 [1–2]) dan baris markdown di luar `.mega-sdd/` (51 vs 78);
  - klinik `WORSE`: subagent (1 vs 0, review buta lane assisted) dan distinct files read (9 [3–30] vs 1 [0–2]).
- Delivery-check 9/9 PASS.

### 8c. Konteks historis — mega-sdd saja, TIDAK sebanding dengan vanilla

Diukur ulang 2026-09-26 dengan `arm-metrics.py` dari `stream.jsonl` yang sudah di-commit. Run yang tidak bersih ada di file-nya, tidak di sini. Fixture dan PRD sama, tapi versi plugin berbeda-beda. Tabel ini menunjukkan **variansi**, bukan perbandingan.

| run | plugin | wall (min) | cost (USD) | tokens total | tool calls | subagents |
|---|---|---|---|---|---|---|
| p0-baseline/xs-3screen (classic) | 7.34.0 | 110,0 | 77,47 | 75.935.207 | 804 | 24 |
| p2-w2/xs-classic-7.36.1 | 7.36.1 | 112,2 | 74,88 | 56.878.107 | 833 | 28 |
| p3/xs-lite-7.38.0-run2 | 7.38.0 | 89,4 | 49,66 | 33.850.435 | 678 | 26 |
| p3/xs-lite-8.0.1-trailer | 8.0.1 | 78,2 | 50,69 | 35.960.085 | 702 | 29 |
| p3/xs-lite-8.3.0-levers-run3 (API stall ≈56 m) | 8.3.0 | 97,3 | 26,35 | 25.288.506 | 432 | 24 |
| p3/xs-lite-8.3.0-levers-run4 | 8.3.0 | 35,1 | 28,06 | 25.018.604 | 436 | 26 |
| p0-baseline/clinic (classic) | 7.35.0 | 301,4 | 259,66 | 217.457.306 | 3.328 | 131 |
| p3/clinic-lite-8.3.0-levers | 8.3.0 | 102,2 | 106,18 | 102.733.041 | 1.829 | 128 |

Run yang dicatat TERCEMAR di log pengukurannya (mis. `xs-lite-8.3.0-levers-run1`: outage jaringan + restart harness, `docs/superpowers/specs/2026-09-16-clinic-levers-design.md` baris 36) tidak dimasukkan. Dua run xs 8.3.0 yang bersih, dengan versi dan fixture yang sama, punya wall 35 dan 97 menit (yang kedua memuat stall API ±56 menit). Variansi sebesar itu jauh lebih besar dari selisih yang dipakai untuk memutuskan ship 8.0.0 (miss 11 menit, n=1). Run klinik 8.3.0 ($106,18, 102 menit) ada di repo sejak 2026-09-17 tapi belum pernah diekstrak ke CHANGELOG. Kualitas dan gate-nya juga belum dinilai.

## 9. Log keputusan

| Tanggal | Keputusan | Oleh |
|---|---|---|
| 2026-09-26 | Runbook + harness dibuat. Run TIDAK dijalankan (owner: tanpa biaya di sesi ini) | owner |
| 2026-09-26 | Owner: "gas semua, gue terima beres" → blok xs (vanilla + lite) dijalankan, lalu xs classic + klinik (vanilla + lite). Klinik classic ditunda (biaya) | owner |
| 2026-09-26 | Klinik lite-1 kena sistem sleep (lid ditutup, baterai) → TIDAK bersih; pengganti `lite 4` ditambahkan di akhir `plan-clinic.txt` (§4: maks 5 percobaan) | Claude |
| 2026-09-26 | **Dikunci:** target §1 persis seperti tertulis (usulan diterima apa adanya), seed urutan xs `20260926` → `vanilla, lite, vanilla, lite, lite, vanilla` (`results/vanilla-ab/plan-xs.txt`), budget blok xs (6 run). Klinik dan arm classic ditunda sampai hasil xs keluar (§runbook "next") | Claude atas delegasi owner ("gas semua, gue terima beres") |
| 2026-09-26 | **Deviasi fixture:** `training-nextjs @ c6821ad` tidak tersedia di mesin ini (SCM internal tidak ter-resolve). Blok ini memakai fixture baru yang di-pin: `create-next-app@16.3.6` (`--ts --app --eslint --tailwind --src-dir`, npm) + PRD xs, commit `ff006be`, `npm install` di luar jam ukur. Semua arm di blok ini memakai fixture yang SAMA. Angka blok ini tidak sebanding dengan run historis §8c (starter berbeda: tanpa MUI / next-auth) | Claude |
| 2026-09-26 | **Plugin di arm mega-sdd:** salinan `git archive` dari `plugins/mega-sdd` di branch `bench/vanilla-arm` (8.8.1) di path TANPA spasi (`P0_PLUGIN_DIR=/private/tmp/claude-501/mega-sdd-bench/plugin-8.8.1`) dimuat sebagai `mega-sdd@inline`, salinan marketplace 8.7.2 dimatikan per sesi. Roster lain identik di kedua arm (probe: superpowers 6.4.1, agents-md, telemetry) | Claude |
| 2026-09-27 | **Lane router + direct lane** diterapkan (brief owner: "rombak berdasarkan bukti"). Arm baru `routed` diukur pada fixture xs + klinik yang SAMA, n=3, plus satu vanilla per skenario (vanilla-4) sebagai cek drift hari-berbeda terhadap vanilla 1–3. Seed urutan `20260929` (xs) / `20260930` (klinik), plan `results/vanilla-ab/plan-routed-*.txt`. Plugin = snapshot working tree `bench/vanilla-arm` (belum di-commit) di `plugin-routed/` | Claude atas delegasi owner |
| 2026-09-27 | **PRD baru di lane guarded → lite secara default** (vault lama tetap di lane-nya; `lane: standard` = classic). **Deviasi dari aturan §7 yang dikunci:** aturan meminta lite vs classic di KEDUA skenario, sedangkan klinik classic belum pernah diukur di fixture ini. Dasar keputusan: xs n=3 (lite BETTER di waktu dan biaya, AC/rubric/Critical OVERLAP), klinik historis classic $259,66 / wall 301,4 menit (n=1, plugin 7.35.0, fixture lain; §8c) vs lite $53–73 / 65–94 menit, dan mandat owner "pertahankan hanya kompleksitas dengan nilai terukur" (classic menambah tiga fase model tanpa manfaat terukur). Bisa dibalik lewat config. Classic klinik tetap jadi arm opsional di blok brownfield | Claude atas mandat owner |
| 2026-09-27 | Eksperimen brownfield + PRD ambigu dirancang, TIDAK dijalankan: commit `d447a6d2` | Claude |
| 2026-09-27 | Eksperimen brownfield dijalankan kemudian di hari yang sama (vanilla vs routed, n=3 run bersih per arm). Hasil dan keputusan: commit `5d880e8b` + `results/vanilla-ab/REPORT.md` (skenario `brownfield`) | Claude |

**Estimasi biaya (EST, dari run historis §8c):** xs ≈ $25–80 per arm-run (vanilla belum diketahui), klinik ≈ $105–260. 2 arm mega-sdd (lite + classic) × 3 run: xs 6 × $25–80 ≈ $150–480, klinik 6 × $105–260 ≈ $630–1.560. Total ≈ $780–2.040, ditambah arm vanilla (belum diketahui) dan scorer. Keputusan budget ada di owner.
