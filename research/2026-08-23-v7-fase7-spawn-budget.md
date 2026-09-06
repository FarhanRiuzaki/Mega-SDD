# Fase 7 — Spawn budget untuk fleet i5 + CrowdStrike Falcon

**Pertanyaan lo:** bisa nggak dipotong sampai secepat Claude Code tanpa skill? **Jawaban jujur:** untuk tier S — sudah (0 fork terukur). Untuk chain M/L — bisa mendekati, dengan satu batas keras yang harus lo tahu: setiap hook event yang match di `hooks.json` = Claude Code men-spawn minimal **satu proses** (`bash run-hook.sh`), dan di Windows+Falcon satu spawn ≈ 150–250 ms apa pun isinya. Jadi lever-nya dua: (1) **lebih sedikit event yang match**, (2) **satu proses per event, bukan rantai bash→python→python**. Yang tidak mungkin: nol proses saat gate anti-halu memang harus jalan.

## Di mana spawn-nya sekarang (baseline 7.3.1, dari audit/proof)

| Jalur | Hari ini | Catatan |
|---|---|---|
| Tier S: Edit/Bash/Read/prompt | 0 fork di dalam hook | tapi hook process-nya sendiri tetap spawn tiap event yang match (Pre+Post pada Edit = 2 bash spawn ≈ 0,4–0,5 s di Falcon) |
| Session-start project SDD | 8 fork | anchor via awk, derive-state python, install-front-door, git |
| Chain: Edit (armed) | 3 python + ~4 fork, blocking | parse stdin, FP_GUARD, GateGuard = 3 interpreter start terpisah |
| Chain: Write unit/binding (armed) | ~25 python fan-out (PostToolUse) | validator dipanggil satu-satu: bash → python per validator |
| Chain: Skill dispatch | aggregator re-derive semua state (S4/S5/S6) | beberapa python + validator |
| Bolt: L0 gates, preflight/postflight, acceptance | puluhan spawn | memang kerja nyata (ast-grep, test runner) — bukan target |

Angka Windows dari audit: Edit armed ≈ 1,5–2,5 s blocking; sesi chain 30–60 tool call ≈ 1–3 menit pajak hook + background CPU yang bikin laptop i5 "berat".

## Target Fase 7 (diukur harness yang sudah ada: PATH-shim counter, dipin test)

| Jalur | Target | Cara |
|---|---|---|
| Semua event, tier S | **0 fork** (sudah) + **kurangi event yang match** | matcher PostToolUse hanya `Write|Edit` (Bash/Read/Agent sudah tidak perlu sejak telemetry hilang — verifikasi); UserPromptSubmit tetap pure-shell |
| Session-start SDD | **≤ 3 fork** | anchor core di-precompute saat release jadi file statis (`cat`, bukan awk); derive-state pindah sepenuhnya ke front door (notice staleness cukup dari satu `stat`/builtin pada stamp, bukan python); install-front-door debounced via marker versi (builtin `[ -f ]`) |
| Chain: Edit armed | **1 python** | satu entry `hooks/_gate.py` yang menerima stdin sekali dan menjalankan parse + FP_GUARD + GateGuard in-process; bash hanya short-circuit builtin lalu `exec python` |
| Chain: Write unit/binding | **1 python** | fan-out validator dijalankan **in-process** oleh driver python yang meng-import `_lib` (validator-validator itu sudah python-backed); hasil state-file identik byte-for-byte. Dan: karena aggregator PreToolUse me-recompute di gate (temuan Fase 0 #2), fan-out PostToolUse = early-warning → **hapus saja**, biarkan gate-time yang menghitung sekali |
| Chain: Skill dispatch (gate) | **1 python** | aggregator + semua re-derive dalam satu interpreter; validator bash yang hanya membungkus python dipanggil sebagai fungsi, bukan subprocess |
| Bolt gates (L0, pre/postflight, acceptance) | tidak dipangkas | kerja nyata; tapi pastikan tidak dijalankan dua kali (hook + skill body) |

Prinsip: **bash hanya untuk keputusan "perlu lanjut?" (builtin, 0 fork); begitu perlu kerja, satu `exec python` dan semua sisanya in-process.** Tidak ada bash→python→bash→python.

## Yang lebih jauh (keputusan lo, bukan default)

- **Satu binary hook** (Go/Rust statis) menggantikan `bash run-hook.sh` + python: start ±5–10 ms, satu spawn, Falcon scan sekali lalu cache. Ini lever terbesar untuk Windows tapi = rewrite hook layer; hanya layak kalau setelah Fase 7 angka masih tidak diterima fleet. Gue tidak merekomendasikan sekarang.
- **Mematikan GateGuard LOCKED-check di fleet** (`gateguard: off` config sudah ada) — hemat 1 python per Edit di chain; risiko: edit file LOCKED tanpa deny, tapi re-bind gate-time tetap menangkap drift. Keputusan per project.

## Eksekusi (setelah Fase 5, sebelum Fase 6)

Audit read-only dulu: tabel event × jalur × spawn terukur sekarang (bukan estimasi), daftar matcher yang bisa menyempit dengan bukti "tidak ada konsumen", daftar rantai bash→python yang bisa jadi satu `exec`, dan validator PostToolUse yang boleh hilang karena gate-time recompute sudah mencakupnya (sebutkan gate mana yang mencakup masing-masing). Berhenti di gate. Lalu implementasi satu jalur per commit, harness spawn dipin turun, moat test (S12 mutation-proof, anti-forge S2/S3) tetap hijau.

Kriteria selesai: sesi chain 30–60 tool call di Windows/Falcon ≤ 20 detik pajak hook (dari 1–3 menit), diproyeksikan dari spawn count × 220 ms dan diverifikasi satu kali di laptop kantor.
