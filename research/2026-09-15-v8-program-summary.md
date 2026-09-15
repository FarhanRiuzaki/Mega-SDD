# v8 "Fused Pipeline" — ringkasan program v7.30 → 8.0.0 (runbook §4)

Status: **DRAFT sesi 015iaR6m, 2026-09-15** — kolom 8.0.0 diisi dari chain d (`benchmarks/results/p3/xs-lite-7.38.0-run2`, `clinic-lite-7.38.0`) begitu selesai; sel bertanda ⟨chain d⟩ belum terisi. Semua angka berlabel **MEASURED** (n=1 per arm, headless `claude -p`, opus, fixture `TRAINING/p0-*`) atau **EST**. Sumber: `research/2026-09-10-v8-p0-baseline.md`, `research/2026-09-11-v8-p2-report.md`, `research/2026-09-15-v8-p3-report.md`, spec `docs/superpowers/specs/2026-09-10-v8-fused-pipeline-design.md`, kontrak `research/2026-09-10-v8-autonomous-runbook.md`.

## 0. Satu paragraf

Program v8 memotong **tiga fase model pra-kode (intent → bind → units) jadi satu (`plan`)**, memindahkan **bind dari fase ke gate JIT saat dispatch** (binding per unit, ditulis skrip), dan — temuan P3 — membuka **penyerial bolt-stage yang ternyata gate, bukan DAG**. Di skenario 3-screen xs, waktu ke kode pertama turun dari 47 m ke 21 m dan DONE dari 1h28m ke 1h11m (7.37.1) lalu ⟨chain d⟩ di 8.0.0; di klinik 19–21 unit, DONE turun dari 4h44m ke 3h13m (7.37.1) lalu ⟨chain d⟩. Kualitas tidak memburuk pada yang terukur (acceptance 100 % di semua arm DATA, panel Critical 5 → 0 di klinik). Biaya per run −26 % (xs) / −32 % (klinik). `--lite` ⟨default / opt-in — keputusan §5⟩ di 8.0.0.

## 1. Before / after — v7.30-era (7.34.0/7.35.0 classic) → 8.0.0 (MEASURED, endpoint DONE = max(gate unit terakhir, B2))

### 1a. Waktu (wall, headless = 0 human-wait by construction)

| Skenario · metrik | classic P0 (7.34.0 xs / 7.35.0 klinik) | `--lite` 7.37.1 (P2) | `--lite` 8.0.0-cand 7.38.0 (P3) | Δ classic → 8.0.0 |
|---|---|---|---|---|
| **xs** time-to-first-code | 47m27s | 20m43s | ⟨chain d⟩ | ⟨⟩ |
| xs PRE-CODE (start → dispatch pertama) · share | 38m00s · 80,1 % | 16m16s · 78,5 % | ⟨chain d⟩ | ⟨⟩ |
| xs bolt-stage (dispatch pertama → commit kode terakhir) | 45,3 m (7.37.1 lite) / 37,9 m (P0) | 45,3 m | run #1: **22,8 m** · run #2: ⟨chain d⟩ | ⟨⟩ |
| **xs DONE** (budget ≤60 m) | **1h27m35s** MISS | **1h10m54s** MISS | ⟨chain d⟩ | ⟨⟩ |
| **klinik** time-to-first-code | 1h16m01s net | 50m17s | ⟨chain d⟩ | ⟨⟩ |
| klinik PRE-CODE · share | 1h00m33s · 79,7 % | 42m39s | ⟨chain d⟩ | ⟨⟩ |
| klinik bolt-stage net | ≈3h24m (dispatch → gate) | 2h31m net | ⟨chain d⟩ | ⟨⟩ |
| klinik implementer in-flight rata-rata (cap 4) · % waktu tanpa implementer | 1,09 · 47 % | 1,46 · 45 % | ⟨chain d⟩ (kriteria (b): ≥2,5 · <20 %) | ⟨⟩ |
| **klinik DONE** (budget ≤2 h; band 2–2,5 h) | **4h43m33s** MISS | **3h13m24s** net MISS | ⟨chain d⟩ | ⟨⟩ |

### 1b. Token, biaya, artefak, fase, titik interaksi

| Metrik | classic P0 | `--lite` 7.37.1 | `--lite` 8.0.0-cand | Catatan |
|---|---|---|---|---|
| xs token raw / cost-weighted sampai DONE | 174,7 M / 32,0 M (7.34.0) · 161,9 M / 35,8 M (7.36.1) | **74,1 M / 17,0 M** (−54 % / −53 % vs 7.36.1) | 67,9 M / 15,3 M (run #1) · ⟨chain d⟩ | ekstraktor `p0-extract-arm.sh` |
| klinik token raw / cw sampai DONE | 465,4 M / 90,4 M | **292,0 M / 57,5 M** (−37 % / −36 %) | ⟨chain d⟩ | |
| biaya `total_cost_usd` xs · klinik | $77,47 · $259,66 | $57,24 · $176,72 | $50,32 (run #1) · ⟨chain d⟩ | −26 % / −32 % di 7.37.1 |
| fase model pra-kode | 3 (+ resolve-oq bila P1 OQ) | **1** (`plan`) | 1 | handoff YAML antar fase 3 → 0 (state re-derive dari disk) |
| artefak yang ditulis MODEL sebelum bolt pertama (klinik) | vault 4 dok 51,7 KB + `binding.md` 16,8 KB + units 100,4 KB (23 file) ≈ **169 KB** + bound/ + html + ledger | `context.md` 22,3 KB + units 121,0 KB (20 file) ≈ **143 KB (−15 %)**; binding per unit 59,9 KB ditulis SKRIP | spec EST −50 % **tidak tercapai** — badan unit tetap 100–120 KB (unit = kontrak dispatch, bukan lemak) |
| titik interaksi manusia (happy path) | ask nonaktif headless: 0 ask + **13 (xs) / 18 (klinik)** keputusan `[ASSUMED-BY-RUNNER]` | 0 ask + **6 / 6** keputusan runner | ⟨chain d⟩ | budget ≤2/≤3 tidak sebanding langsung (ask nonaktif); jumlah keputusan turun 2–3× |
| bind: conflict-at-dispatch | bind fase: 7 CONFLICT klinik → resolve → re-bind (16 m); JIT 14,3 % unit | JIT: **5,3 % bind pertama → 0 % final** (157/157 klaim CONFIRMED) | ⟨chain d⟩ | 10/10 kelas CONFLICT simkredit direplay lolos di jalur JIT (P0) |
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

⟨diisi setelah keputusan ship — default vs opt-in — supaya kalimat pertamanya jujur⟩

## 6. Biaya program

| Fase | run DATA | run bukan-data | total |
|---|---|---|---|
| P0 | xs $77,47 · klinik $259,66 | klinik attempt 1 | (owner: P0+P2 = $781) |
| P2 | classic 7.36.1 $74,88 · lite 7.36.1 $75,64 · lite 7.37.0 $40,77 · lite 7.37.1 $57,24 · klinik lite $176,72 = $425,25 | $96,14 (co-tenant, outage, deadlock) | $521,39 |
| P3 | xs run #1 $50,32 (bolt-stage DATA, pra-kode tercemar) · xs run #2 ⟨chain d⟩ · klinik ⟨chain d⟩ | — | ⟨⟩ |

SCM PENDING sejak 53406cc.
