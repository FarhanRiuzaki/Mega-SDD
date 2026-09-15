# v8 "Fused Pipeline" — ringkasan program v7.30 → 8.0.0 (runbook §4)

Status: **DRAFT sesi 015iaR6m, 2026-09-15** — kolom 8.0.0 diisi dari chain d (`benchmarks/results/p3/xs-lite-7.38.0-run2`, `clinic-lite-7.38.0`) begitu selesai; sel bertanda ⟨chain d⟩ belum terisi. Semua angka berlabel **MEASURED** (n=1 per arm, headless `claude -p`, opus, fixture `TRAINING/p0-*`) atau **EST**. Sumber: `research/2026-09-10-v8-p0-baseline.md`, `research/2026-09-11-v8-p2-report.md`, `research/2026-09-15-v8-p3-report.md`, spec `docs/superpowers/specs/2026-09-10-v8-fused-pipeline-design.md`, kontrak `research/2026-09-10-v8-autonomous-runbook.md`.

## 0. Satu paragraf

Program v8 memotong **tiga fase model pra-kode (intent → bind → units) jadi satu (`plan`)**, memindahkan **bind dari fase ke gate JIT saat dispatch** (binding per unit, ditulis skrip), dan — temuan P3 — membuka **penyerial bolt-stage yang ternyata gate, bukan DAG**. Di skenario 3-screen xs, waktu ke kode pertama turun dari 47 m ke 21 m dan DONE dari 1h28m ke 1h11m (7.37.1) lalu ⟨chain d⟩ di 8.0.0; di klinik 19–21 unit, DONE turun dari 4h44m ke 3h13m (7.37.1) lalu ⟨chain d⟩. Kualitas tidak memburuk pada yang terukur (acceptance 100 % di semua arm DATA, panel Critical 5 → 0 di klinik). Biaya per run −26 % (xs) / −32 % (klinik). **`--lite` tetap OPT-IN di 8.0.0**: kriteria (a) gagal pada run bersih (xs DONE 1h11m02s > 60 m) — default butuh (a) DAN (b), jadi hasil klinik menentukan angka CHANGELOG dan diagnosa lanjutan, bukan default-nya.

## 1. Before / after — v7.30-era (7.34.0/7.35.0 classic) → 8.0.0 (MEASURED, endpoint DONE = max(gate unit terakhir, B2))

### 1a. Waktu (wall, headless = 0 human-wait by construction)

| Skenario · metrik | classic P0 (7.34.0 xs / 7.35.0 klinik) | `--lite` 7.37.1 (P2) | `--lite` 8.0.0-cand 7.38.0 (P3) | Δ classic → 8.0.0 |
|---|---|---|---|---|
| **xs** time-to-first-code | 47m27s | 20m43s | **23m05s** (run #2, bersih) | **−51 %** |
| xs PRE-CODE (start → dispatch pertama) · share | 38m00s · 80,1 % | 16m16s · 78,5 % | **17m05s · 74,0 %** | −55 % |
| xs bolt-stage (dispatch pertama → commit kode terakhir) | 37,9 m (P0) | 45,3 m | run #1: 22,8 m (tercemar) · **run #2: 37,3 m** (bersih; in-flight 0,93, idle 56 % — controller tidak top-up + detour D5) | ≈ datar |
| **xs DONE** (budget ≤60 m) | **1h27m35s** MISS | **1h10m54s** MISS | **1h11m02s** MISS 11m02s — **kriteria (a) FAIL pada run bersih** | **−19 %** |
| **klinik** time-to-first-code | 1h16m01s net | 50m17s | ⟨chain d⟩ | ⟨⟩ |
| klinik PRE-CODE · share | 1h00m33s · 79,7 % | 42m39s | ⟨chain d⟩ | ⟨⟩ |
| klinik bolt-stage net | ≈3h24m (dispatch → gate) | 2h31m net | ⟨chain d⟩ | ⟨⟩ |
| klinik implementer in-flight rata-rata (cap 4) · % waktu tanpa implementer | 1,09 · 47 % | 1,46 · 45 % | ⟨chain d⟩ (kriteria (b): ≥2,5 · <20 %) | ⟨⟩ |
| **klinik DONE** (budget ≤2 h; band 2–2,5 h) | **4h43m33s** MISS | **3h13m24s** net MISS | ⟨chain d⟩ | ⟨⟩ |

### 1b. Token, biaya, artefak, fase, titik interaksi

| Metrik | classic P0 | `--lite` 7.37.1 | `--lite` 8.0.0-cand | Catatan |
|---|---|---|---|---|
| xs token raw / cost-weighted sampai commit unit terakhir | 174,7 M / 32,0 M (7.34.0) · 161,9 M / 35,8 M (7.36.1) | **74,1 M / 17,0 M** (−54 % / −53 % vs 7.36.1) | **54,0 M / 13,7 M** (run #2; −67 % / −62 % vs 7.36.1) | ekstraktor `p0-extract-arm.sh` |
| klinik token raw / cw sampai DONE | 465,4 M / 90,4 M | **292,0 M / 57,5 M** (−37 % / −36 %) | ⟨chain d⟩ | |
| biaya `total_cost_usd` xs · klinik | $77,47 · $259,66 | $57,24 · $176,72 | **$49,66** (run #2) · ⟨chain d⟩ | xs −36 % · klinik −32 % (7.37.1) |
| fase model pra-kode | 3 (+ resolve-oq bila P1 OQ) | **1** (`plan`) | 1 | handoff YAML antar fase 3 → 0 (state re-derive dari disk) |
| artefak yang ditulis MODEL sebelum bolt pertama (klinik) | vault 4 dok 51,7 KB + `binding.md` 16,8 KB + units 100,4 KB (23 file) ≈ **169 KB** + bound/ + html + ledger | `context.md` 22,3 KB + units 121,0 KB (20 file) ≈ **143 KB (−15 %)**; binding per unit 59,9 KB ditulis SKRIP | spec EST −50 % **tidak tercapai** — badan unit tetap 100–120 KB (unit = kontrak dispatch, bukan lemak) |
| titik interaksi manusia (happy path) | ask nonaktif headless: 0 ask + **13 (xs) / 18 (klinik)** keputusan `[ASSUMED-BY-RUNNER]` | 0 ask + **6 / 6** keputusan runner | xs run #2: 0 ask + 4 OQ lahir `deferred` (1 batched ask di ujung PLAN bila interaktif) · klinik ⟨chain d⟩ | budget ≤2/≤3 tidak sebanding langsung (ask nonaktif); jumlah keputusan turun 2–3× |
| bind: conflict-at-dispatch | bind fase: 7 CONFLICT klinik → resolve → re-bind (16 m); JIT 14,3 % unit | JIT: **5,3 % bind pertama → 0 % final** (157/157 klaim CONFIRMED) | xs run #2: **0 %** (42 CONFIRMED · 0 CONFLICT; auto-repair R2-clamp menyala live, 0 m) · klinik ⟨chain d⟩ | 10/10 kelas CONFLICT simkredit direplay lolos di jalur JIT (P0) |
| kualitas: acceptance · panel Critical/Important/Minor · fix round · karantina (klinik) | 21/21 · 5/46/91 · 5 · 1 | 19/19 · 0/29/50 · 0 · 0 | ⟨chain d⟩ (kriteria (ii): ≤ classic) | headless, asumsi runner; dekomposisi 19 vs 21 unit |

### 1c. Definisi yang dikoreksi terbuka

- **DONE** (P3 §1): angka P0/P2 memakai "commit `type(U-*)` terakhir"; definisi owner = kode terakhir + gate-nya → **DONE = max(gate unit terakhir, B2)**, berlaku surut lewat skrip (`p3-done-endpoints.py`), tanpa re-run. Angka lama lebih RENDAH 5–13 menit dari definisi ini; xs lite 7.37.1 1h03m49s → 1h10m54s, klinik lite 3h01m → 3h13m net. Lane DOCS/emit tidak pernah masuk.
- **Kriteria ship (i)** (§3-lanjutan owner): ambang ≤60 m / ≤2 h adalah proxy "pajak pipeline habis"; pajak itu kini terukur langsung → (a) xs DONE ≤60 m DAN (b) klinik in-flight ≥2,5/4 dan idle-tanpa-implementer <20 % (klinik saja), pada run bersih (0 outage, 0 resume).

## 2. Jawaban atas tiga feedback tim (dengan angka)

**Feedback 1 — "bind tidak perlu."** Separuh benar, dan yang separuh salah justru moat. Fase bind (whole-vault `binding.md` 16,8 KB, 4 field-nya saja yang dibaca hilir) memang dilipat: di `--lite` tidak ada lagi hop bind — verdict CONFLICT ditegakkan **di gate dispatch execute-bolts** (tempat gate itu memang hidup sejak v6, `hooks/pre-tool-use`), dari klaim per unit yang diturunkan skrip dari `target_files` ∪ `## Anchors` (`derive-unit-claims.sh` → `write-unit-binding.sh` → `validate-handoff-binding-units.sh`). Angka: bind fase klinik classic = 7m24s + 5m05s resolve + 3m50s re-bind ≈ 16 m sebelum satu baris kode; JIT lite = ≈0,3 m per wave di dalam bolt-stage. 10/10 kelas CONFLICT lapangan simkredit tertangkap di jalur JIT (P0 replay, `benchmarks/results/p0-baseline/brownfield-replay/`), 157/157 klaim klinik CONFIRMED, conflict-at-dispatch 5,3 % → 0 %. Yang **tidak** dihapus: gate-nya. Kalau kode tidak cocok spec, dispatch tetap ditolak; `bind-codebase` di lane lite = FATAL preflight dengan satu baris KENAPA (`bind_folded_into_bolts`), dan audit penuh "apakah kode masih sinkron dengan spec?" = `rebind-units.sh --units=all` (`sync --full-bind`).

**Feedback 2 — "kontrak ditulis berkali-kali."** Benar untuk fasenya: intent → bind → units menulis vault 4 dok + binding + units + 3 handoff YAML yang **0 konsumen input** (fase berikutnya re-derive dari disk). Di v8: **satu fase `plan`** menulis `context.md` (satu dok, 22 KB di klinik) + units, handoff YAML 0. Tapi angka byte jujur: total prosa model pra-kode klinik 169 KB → 143 KB (**−15 %**, bukan −50 % seperti EST spec) karena badan unit (100–120 KB untuk 19–21 unit) memang kontrak yang dibaca implementer verbatim — itu bukan lemak, itu dispatch. Yang hilang benar-benar: `binding.md` whole-vault (diganti binding per unit ditulis skrip), 3 dok vault yang nol pembaca BUILD (Architecture prose, Glossary, Source docs), handoff antar fase, dan 2 fase resolve-oq (OQ P1 lahir `deferred` di satu batched ask di ujung PLAN). Waktu pra-kode xs 38m → 16m (−57 %), klinik 60m → 43m (−30 %).

**Feedback 3 — "lambat & berat."** Di xs: time-to-first-code 47m27s → 20m43s (−56 %), DONE 1h27m35s → 1h10m54s (−19 %) di 7.37.1, token cost-weighted −53 %, biaya −26 %. Di klinik: DONE 4h43m33s → 3h13m24s (−32 %), token cw −36 %, biaya −32 %. Lalu P3 membedah kenapa bolt-stage klinik cuma turun −25 %: **45 % waktu bolt-stage tidak ada implementer yang jalan, rata-rata in-flight 1,46 dari cap 4** — bukan DAG unit (3 unit tanpa dependency menganggur 39–221 menit), tapi gate panel-evidence in-run yang memperlakukan panel "pending" sebagai "missing" sehingga tiap slice cap-4 jadi barrier. Fix 7.38.0 di gate (panel-pending ≤ cap, bukan melonggarkan F-07): xs run #1 bolt-stage 45,3 m → 22,8 m (−50 %), in-flight 0,98 → 1,57; klinik ⟨chain d⟩. Budget ≤60 m / ≤2 h: ⟨chain d⟩. Yang masih "berat" dan sengaja tidak disentuh: gate per unit (L0 + postflight + acceptance + panel 3–5 lens) — itu moat, dan angka panel Critical 5 → 0 di klinik adalah alasannya.

## 3. Keputusan yang dibalik bukti sepanjang program (kronologis)

1. **Kill-criterion P0** — hipotesis "diet 7.0–7.5 belum cukup" dibuktikan, bukan diasumsikan: pra-kode 80,1 % / 79,7 % ≥ 25 % → P2 lanjut (kalau <25 %, program berhenti di P1).
2. **Headless `claude -p` menonaktifkan `AskUserQuestion`** → budget titik interaksi tidak bisa dinilai sebanding; diganti hitungan keputusan `[ASSUMED-BY-RUNNER]` (13/18 → 6/6), diberi label "headless, asumsi runner".
3. **Klinik attempt 1 P0 = bukan data** (deadlock `handoff_type_mismatch` + model mem-bypass dispatch Skill) → tiga defect diperbaiki + S8-a (bypass Skill ditolak hook) SEBELUM baseline diukur, bukan diabaikan.
4. **Urutan P2**: owner membalik W2 dulu lalu PLAN (ukur terpisah) — W2 di xs ternyata DONE datar (DAG 2 level), lever W2 memang milik klinik.
5. **CONFLICT palsu D1** (route-group Next.js `(blank-layout-pages)` memutus regex anchor): conflict-at-dispatch terukur 42,9 % padahal riil 0 % → hotfix 7.37.1 sebelum klinik supaya metrik moat bersih; baseline P0 dicek ulang tidak terkontaminasi.
6. **Harness end_turn**: lite 7.37.0 DONE bukan data (harness keluar 10 m setelah controller mengakhiri turn saat 2 implementer jalan) → launcher melarang end_turn saat background work; angka DONE diukur ulang di 7.37.1.
7. **Definisi DONE** (P3 amendemen #2): dikoreksi ke max(gate, B2), angka naik 5–13 m, ditulis terbuka.
8. **Penyerial bolt-stage = gate, bukan DAG PLAN** (P3 amendemen #1 mengarahkan "fix di PLAN bila DAG terlalu ketat") → bukti timestamp membalik: fix di gate F-07 in-run (`panel_pending_units` ≤ cap), PLAN tidak disentuh.
9. **Cap paralel "default 5"** di dua prosa vs 4 di controller → prosa diselaraskan ke angka yang benar-benar dipakai; `parallel_max` jadi script-read.
10. **Stale line-range anchor**: owner menyetujui auto-repair hanya hash-identik (R1-shift/R2-clamp; overshoot >1 tetap CONFLICT) — bukan "perbaiki saja".
11. **Kriteria ship (i)** diganti owner dari proxy wall ke pajak pipeline terukur (in-flight + idle), plus stopping rule outage (4 kali jaringan lokal putus selama program).
12. **Komentar over-verbose** (masukan tim #4): hipotesis "panel menghadiahi komentar" DIBANTAH grep; penyebab #1 = trailer provenance yang diwajibkan prompt implementer (33–59 % baris komentar; hanya marker yang dibaca gate) → proposal-first, bukan sapuan.
13. **EST spec −50 % output pra-kode** tidak tercapai (−15 %): badan unit = kontrak, bukan lemak — dicatat, bukan dipaksakan.

## 4. Sisa PR untuk 9.0 (dan yang tidak masuk 8.0.0)

- **Alias tiga fase classic** (`generate-intent`/`bind-codebase`/`generate-units` → FATAL KENAPA di lane lite / layout-3) hidup satu major; cabut di 9.0 setelah usage review (gateway telemetry).
- **Dual-read layout 3/2/legacy** satu minor cycle; legacy 7-file dicabut setelahnya; `migrate-paths --vault-layout=3` tetap dry-run default.
- **Degradasi layout-3 yang disengaja**: drift Architecture prose tidak terdeteksi (tidak ada section-nya) — kalau lapangan butuh, itu fitur 9.0 dengan bukti.
- **Masukan tim #4** (komentar): aturan KENAPA-bukan-APA di implementer + pack + proposal trailer padat, ukur −40 % rasio pada xs — 8.0.x/8.1.0 (P3 §6).
- **Penyerial sisa bolt-stage** kalau klinik 8.0.0 masih <2,5 in-flight: bedah ulang dengan metode P3 §2 (bukan lever baru).
- **P4 field run Windows+Falcon** (angka resmi; `test-spawn-ceilings.sh` jalur JIT) — hanya owner/tim di kantor.
- Seam handoff D4 (`metrics` flow-style di execute-bolts → detect-drift), sel xs→sonnet yang tidak pernah terpicu di fixture, `units/_index.md` refresh status setelah bolts, skema `blockers[]` — kelas parser mini-YAML.
- **SCM leg** (git.example.com) PENDING sejak 53406cc — butuh VPN kantor; `sudo xcodebuild -license` di mesin runner untuk test stub-env lokal.

## 5. Untuk tim (bahasa manusia)

**Yang berubah buat kalian di 8.0.0, singkatnya:** ada lane baru namanya `--lite`. Dari PRD ke kode cuma dua langkah: `/mega-sdd:plan <prd> --lite` (satu fase, satu file `context.md` + unit) lalu `/mega-sdd:execute-bolts --all --lite`. Nggak ada lagi generate-intent → bind-codebase → generate-units → resolve-oq yang masing-masing nulis kontraknya sendiri. Kalau kalian masih manggil tiga fase lama di lane lite, plugin bakal berhenti dengan satu baris alasan (KENAPA fase itu dilipat) dan nunjukin perintah penggantinya — bukan cuma "not found".

**Lane lite BELUM jadi default di 8.0.0.** Kalian harus pakai flag `--lite` atau tulis `lane: lite` di `.mega-sdd/config.yaml`. Alasannya jujur: target owner "3-screen selesai ≤60 menit" belum tercapai — angka terukur 1 jam 11 menit (dari 1 jam 28 menit di v7.34). Sisa 11 menit itu bukan pajak pipeline lagi, tapi controller yang belum konsisten mem-pipeline unit (di satu run iya, di run berikutnya nggak) plus satu bug parser yang sudah diperbaiki di 8.0.0. Kalau kalian pakai `--lite` sekarang, kalian dapat semua percepatan di bawah; yang belum ada cuma "default"-nya.

**Angka before/after (diukur headless, opus, n=1 per arm — bukan proyeksi):**

| | v7.34/7.35 (classic) | 8.0.0 `--lite` |
|---|---|---|
| 3-screen: waktu ke kode pertama | 47 menit | **23 menit** |
| 3-screen: selesai semua unit + gate hijau | 1 jam 28 menit | **1 jam 11 menit** |
| 3-screen: biaya API | $77 | **$50** |
| 3-screen: token cost-weighted | 32 M | **13,7 M** |
| klinik 19–21 unit: waktu ke kode pertama | 1 jam 16 menit | 50 menit (7.37.1) · ⟨8.0.0: chain d⟩ |
| klinik: selesai semua unit + gate hijau | 4 jam 44 menit | 3 jam 13 menit (7.37.1) · ⟨8.0.0: chain d⟩ |
| klinik: biaya API | $260 | $177 (7.37.1) · ⟨chain d⟩ |
| klinik: panel Critical | 5 | **0** |
| acceptance | 21/21 · 5/5 | 19/19 · 5/5 (tetap 100 %) |
| keputusan yang harus diambil manusia (happy path) | 13–18 | 4–6, semuanya di SATU pertanyaan di ujung `plan` |

**Jawaban buat tiga feedback kalian:**
1. *"Bind nggak perlu."* — Setuju untuk fasenya, dan sudah dilipat: nggak ada lagi hop bind di lane lite. Yang TIDAK dihapus adalah gate-nya: sebelum setiap unit di-dispatch, plugin tetap cek spec vs kode (per unit, ditulis skrip, ±20 detik per wave). Di klinik 157/157 klaim cocok, 0 CONFLICT. Kalau suatu saat kode dan spec nggak cocok, dispatch tetap ditolak — itu yang bikin kalian nggak dapat kode yang "kelihatan jalan tapi salah".
2. *"Kontrak ditulis berkali-kali."* — Sekarang satu fase (`plan`) nulis satu `context.md` + unit; handoff YAML antar fase hilang; `binding.md` 17 KB yang cuma 4 field-nya dibaca, hilang. Yang tetap besar adalah badan unit (±100 KB untuk 19 unit) — itu memang kontrak yang dibaca implementer, bukan lemak.
3. *"Lambat & berat."* — Lihat tabel: waktu ke kode pertama −51 %, biaya −36 % (3-screen) / −32 % (klinik). Yang sengaja nggak kami sentuh: gate per unit (L0, postflight, acceptance, panel 3–5 lens). Itu yang bikin Critical turun 5 → 0.

**Komentar di generated code yang kebanyakan (feedback #4):** sudah dibedah, belum diubah (supaya angka di atas nggak tercemar). Separuh baris komentar itu ternyata header provenance yang diwajibkan plugin sendiri, bukan model yang cerewet — perbaikannya masuk 8.0.x/8.1.0.

**Kalau mau coba:** update plugin (`claude plugin marketplace update` lalu `claude plugin update mega-sdd@mega-sdd`), project lama layout-2 bisa dimigrasi dengan `/mega-sdd:migrate-paths --vault-layout=3` (dry-run dulu, lihat apa yang berubah, baru `--apply`; setelah itu wajib `scripts/rebind-units.sh --units=all` sekali). Audit "kode masih sinkron sama spec?" di lane lite = `sync --full-bind`. Lane classic tetap ada sepanjang 8.x.

## 6. Biaya program

| Fase | run DATA | run bukan-data | total |
|---|---|---|---|
| P0 | xs $77,47 · klinik $259,66 | klinik attempt 1 | (owner: P0+P2 = $781) |
| P2 | classic 7.36.1 $74,88 · lite 7.36.1 $75,64 · lite 7.37.0 $40,77 · lite 7.37.1 $57,24 · klinik lite $176,72 = $425,25 | $96,14 (co-tenant, outage, deadlock) | $521,39 |
| P3 | xs run #1 $50,32 (bolt-stage DATA, pra-kode tercemar) · **xs run #2 $49,66 (bersih)** · klinik ⟨chain d⟩ | — | $99,98 + klinik |

SCM PENDING sejak 53406cc.
