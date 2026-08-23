# v7 Fase 7 Bagian 1 — Spawn audit (READ-ONLY, berhenti di gate)

**Status: AUDIT SELESAI — menunggu keputusan gate user. Tidak ada satu file plugin pun yang diubah.**
Baseline terukur: **v7.4.0** (`6fc9b2a`). Program: gabungan `research/2026-08-23-v7-fase7-spawn-budget.md` + `research/2026-08-23-v7-auto-gate-design.md` (keduanya menyentuh PostToolUse + matcher).

## §0 Metode (terukur, bukan estimasi)

Harness = perluasan PATH-shim counter milik `tests/weighted-routing/test-tier-s-hooks.sh`, dua beda penting:

1. **Diukur LEWAT `run-hook.sh`** (test yang dipin memanggil body hook langsung — pajak dispatcher tidak pernah terukur sebelumnya).
2. **Shim diperluas**: `bash dirname uname base64 cat head mktemp cp rm mv sort cut stat` ikut dihitung, bukan hanya `python3 date wc git grep sed find ls awk`.

Yang dihitung = **exec eksternal via PATH**. Tidak terhitung: builtin, subshell `$( )` tanpa exec, exec via path absolut. Di Git Bash + Falcon, fork subshell juga kena pajak proses → **semua proyeksi Windows di bawah adalah LOWER BOUND**. Skrip harness: scratchpad sesi (bisa di-rerun; deterministik); versi standing = `tests/weighted-routing/test-spawn-ceilings.sh` (Fase 7 commit 1, dispatch diturunkan dari hooks.json).

**PELAJARAN STANDING (user-mandated, gate Fase 7):** *pin harus mengukur JALUR PRODUKSI, bukan fungsi yang dipanggil langsung.* Kontrak "tier S 0 fork" dipin di test yang memanggil body hook langsung — jalur produksi (`bash run-hook.sh → dirname → uname → bash body`) membayar 4 proses per event yang tidak pernah terlihat pin mana pun: 0,88 s/event di Falcon untuk no-op. Kelas yang sama: S11 lama nge-exercise hook yang filenya sudah dihapus → pass hampa. Setiap pin performa/keamanan baru wajib lewat titik masuk yang sama dengan yang dieksekusi harness aslinya (hooks.json, command surface, dispatcher script), dan wajib gagal kalau titik masuknya hilang.

## §1 Tabel terukur: event × jalur × spawn (v7.4.0)

Proyeksi Windows = spawn × 220 ms (angka Falcon dari audit fleet).

### Tier S (proyek SDD, sesi TIDAK armed)

| Jalur | Spawn | Breakdown | Windows | Blocking? |
|---|---|---|---|---|
| UserPromptSubmit (tag gateway) | **4** | bash=2 dirname=1 uname=1 | 0,88 s | **YA — tiap prompt** |
| PreToolUse Edit/Bash/Write | **4** | bash=2 dirname=1 uname=1 | 0,88 s | YA |
| PostToolUse Write (journal) | **5** | +date=1 | 1,1 s | tidak (async) |
| PostToolUse Bash/Skill | **4** | bash=2 dirname=1 uname=1 | 0,88 s | tidak |
| Stop (SDD, turn-gated) | **13** | git=1 grep=4 find=1 python3=1 date=1 + disp | 2,9 s | tidak |
| Stop (SDD, first-fire / HEAD berubah) | **35** | git=17 python3=6 grep=4 | 7,7 s | tidak |
| Stop / Pre / Post (non-SDD cwd) | **4** | dispatcher saja | 0,88 s | per event |
| SessionStart SDD | **16** | awk=1 cat=2 find=1 git=1 grep=2 python3=2 + disp | 3,5 s | YA (sekali) |
| SessionStart non-SDD | 6 | | 1,3 s | sekali |
| UserPromptExpansion (match) | 7 | python3=1 | 1,5 s | jarang |

### Chain armed

| Jalur | Spawn | Breakdown | Windows | Blocking? |
|---|---|---|---|---|
| PreToolUse Edit (steady, index ada) | **8** | **python3=3** (parse+FP_GUARD+GateGuard) | 1,8 s | YA |
| PreToolUse Edit (first, index rebuild) | 12 | python3=5 | 2,6 s | YA |
| PreToolUse Bash innocent | **7** | python3=3 (parse+decode+GUARD_SKIP) | 1,5 s | YA |
| PreToolUse Skill dispatch mid-chain (bind) | **17** | python3=8 bash=4 | 3,7 s | YA |
| PreToolUse Skill **execute-bolts** (gate aggregator) | **110** | **dirname=43 python3=26 bash=20 git=19** | **~24 s** | **YA** |
| PostToolUse Write **unit** (fan-out) | **80** | dirname=41 bash=23 python3=12 git=3 | ~17,6 s | async (CPU background) |
| PostToolUse Write source | **30** | dirname=12 bash=9 python3=4 | 6,6 s | async |
| PostToolUse Bash / Skill (generate-units) | 7 / 11 | | 1,5–2,4 s | async |

**Model sesi chain 45 tool call** (10 Edit, 15 Bash, 15 Write, 3 dispatch mid, 2 execute-bolts, 20 turn, 10 prompt): blocking ≈ **576 exec ≈ 2,1 menit**, background ≈ 1.170 exec ≈ 4,3 menit CPU. Cocok dengan keluhan lapangan "1–3 menit pajak + laptop berat".

## §2 Temuan #1 — dispatcher `run-hook.sh` sekarang MENDOMINASI tier S

Rantai per event yang match: `bash run-hook.sh` → `dirname` → `uname` → `bash <body>` = **4 proses sebelum body jalan**. Body tier-S sendiri 0 fork (kontrak v7 terbukti) — tapi "0 fork" itu tetap membayar 0,88 s/event di Falcon. Satu Edit tier S = Pre+Post = 9 proses ≈ 2,0 s untuk NO-OP.

**Lever: dispatch langsung** — hooks.json memanggil `bash "${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool-use"` tanpa perantara. Bukti aman:
- **Nol file `.ps1` di seluruh plugin** (`find -name '*.ps1'` = 0) — cabang deteksi platform di run-hook.sh dead weight sejak selamanya.
- Normalisasi backslash `$0` (alasan historis run-hook.sh, v4.37.0) pindah jadi 1 baris builtin di kepala tiap body (`self="${0//\\//}"`) — body sudah pakai `${0%/*}` parameter expansion, hanya butuh guard itu di Windows.
- Efek: 4 → **1 proses per event**. UPS 4→1, Pre tier-S 4→1, Post 5→2. Pajak tier-S turun ~75%.

## §3 Verifikasi target per jalur (dibuktikan tercapai / tidak)

| Target Fase 7 | Terukur sekarang | Verdict | Mekanisme |
|---|---|---|---|
| PostToolUse matcher `Write\|Edit` saja | matcher `Skill\|Bash\|Write\|Edit` | **TERCAPAI** — dengan 2 syarat (§4) | leg Bash & Skill terbukti droppable |
| Edit armed = 1 python | 3 python (parse, FP_GUARD, GateGuard) | **TERCAPAI** | `hooks/_gate.py`: stdin sekali, ketiganya in-process. Opsi B (§8): **0 python** untuk file non-LOCKED via probe builtin `.locked-files-index.json` — mekanisme yang SAMA dengan notice auto-aware Bagian 2 |
| Write unit/binding = 1 python (fan-out mati) | 12 python / 80 exec | **TERLAMPAUI** — bisa **0 python** | fan-out dihapus (§5); journal sudah pure-shell; leg Post Write armed jatuh ke jalur tier-S yang sudah ada |
| Skill dispatch = 1 python | eb gate: 26 python, 110 exec | **TERCAPAI untuk python; total ~23 exec** | driver python tunggal import `_lib`; **git tersisa = kerja nyata** (B1 recompute wajib baca git ground truth — moat, tidak dipangkas). 110 → ~23 (bash 2, python 1, git ~20; sebagian git bisa di-share dalam satu proses driver → realistis 12–18) |
| Session-start ≤ 3 fork | 16 | **TERCAPAI** | anchor statis saat release (`$(<file)` builtin, awk mati); probe superpowers `find+grep` → glob builtin; staleness = baca `.git/HEAD` vs stamp (builtin), derive-state penuh sudah jadi urusan front door. Sisa: ≤2 + 1 dispatcher |
| Stop | 13/turn | ikut turun ke ~5 | parse python → ekstraksi builtin (pola pre/post sudah ada); grep config ×4 → satu read builtin |

## §4 Matcher yang bisa menyempit — bukti konsumen

**PreToolUse `Skill|Bash|Edit|Write`: TIDAK BISA menyempit.** Semua empat = moat (anti-self-bypass Bash, FP_GUARD Write/Edit, gate Skill). Bukan target.

**PostToolUse `Skill|Bash|Write|Edit` → `Write|Edit`: BISA**, bukti per leg:

- **Leg Bash** (`post-tool-use:350-396`): satu-satunya isi = validator dispatch-prompt saat `build-dispatch-prompt.sh` jalan. State-nya `.dispatch-prompt-state.json` = ADVISORY (komentar hook sendiri: "nothing in PreToolUse reads this"), dibaca hanya oleh tabel laporan run-analyze (`run-analyze.sh:669`, mode STATE_FILE — tidak pernah di-re-run). Syarat drop: masukkan `validate-dispatch-prompt.sh` ke daftar re-run FULL run-analyze (§5).
- **Leg Skill** (`post-tool-use:322-347`): satu-satunya isi = `validate-starterkit-metrics.sh`. **EVIDENCE-FLIP terhadap №15 Fase 5**: audit №15 keep validator ini dengan alasan "backs a chain-stopping halt" — census lebih dalam membuktikan `.starterkit-metrics-state.json` punya **NOL pembaca absolut** (run-analyze meng-EXCLUDE-nya eksplisit di `:380`; grep pre-tool-use = 0; tidak ada test yang assert file itu). Halt `starterkit_metrics_inconsistent` yang benar-benar fire diproduksi oleh **rekomputasi prose in-skill** (`orchestrate-flow/references/handoff-consumption.md:61`, `generate-units/references/auto-and-memory.md:72`) — independen dari validator. Validator menulis file yang tidak dibaca siapa pun; komentar hook "analyze surfaces a FAIL" salah/basi. Bisakah pindah ke PreToolUse (transcript_path tersedia di `pre-tool-use:178`)? Secara input ya, tapi verdict-equivalent **hanya** saat dispatch persis menyusul handoff generate-units — di luar itu fail-open. **Rekomendasi: hapus validator + leg-nya** (status quo enforcement-nya memang sudah prose-only); alternatif "wire beneran" = keputusan gate.

**SessionStart / UserPromptSubmit / Stop / UserPromptExpansion: matcher sudah minimal** (UPS+Stop butuh global untuk tag gateway + deteksi bolt; UPE sudah sempit).

## §5 Fan-out PostToolUse: yang boleh mati karena gate-time recompute (per gate)

Fakta penentu (census run-analyze + pre-tool-use):

**(a) SEMUA state yang dibaca gate di-recompute di gate itu sendiri** — `pre-tool-use:651-681`, per state: `.validation-blockers.json` ← validate-handoff-binding-units `:651` (gate **binding→units**, invariant #2); `.unit-spec-state.json` `:659` (gate **render-test + verify-grounding**); `.flow-coverage-state.json` `:660`; `.sibling-consistency-state.json` `:661`; `.bolt-orphans/.batch-suite-gate/.bolt-postflight/.bolt-whitelist/.bolt-acceptance` ← validate-bolt-artifacts 5-scan `:678` (gate **B1–B4**, B1 `--recompute`); `.ui-quality-blockers.json` `:679`; `.cross-cutting-state.json` `:680`; `.factory-ledger-state.json` `:681`. → **Menghapus fan-out tidak membuka satu gate pun. Moat utuh by construction.**

**(b) run-analyze FULL me-re-run 16 dispatch validator** (handoff-binding-units, unit-spec, bolt-artifacts ×2, vault-oqs, fsd-slots, kb ×4, starterkit-conformance, constitution ×2, codebase-map, reuse-duplication — `run-analyze.sh:383-493`) → lane advisory untuk semua itu juga selamat tanpa fan-out.

**(c) Sisa yang benar-benar kehilangan writer bila fan-out mati** — 4 advisory yang run-analyze hanya baca dari state (`:662-672`, kelas STATE_FILE): `fanout-parity`, `ui-deferral`, `vault-flow-staging`, `dispatch-prompt`. **Penutup murah:** tambahkan 4 dispatch itu ke daftar re-run FULL run-analyze (pola `run_validator()` yang sudah ada; semua self-SKIP tanpa pack) → **fan-out mati dengan kehilangan NOL coverage**. (`.constitution-propagation` & `.kb-citations` & `.vault-flows` sudah tercakup butir (b).)

**Timing yang berubah, jujur:** early-warning per-write hilang — verdict segar baru muncul di (1) gate dispatch berikutnya, (2) analyze. Itu persis doktrin gate-0 v7 ("fan-out = early-warning, bukan moat").

## §6 Rantai bash→python yang jadi satu `exec` — bukti struktural

Census 20 validator: **semuanya thin bash wrapper atas python heredoc** (median ~78% baris = python; bash = arg-parse + source resolver + path assembly). 8 di antaranya SUDAH `sys.path.insert` + import `_lib` (vault_layouts, binding_md, state_probes, vault_md, mermaid_syntax…) — pola driver terkonsolidasi sudah jadi preseden internal, bukan mekanisme baru. Konsolidasi per jalur:

1. **`hooks/_gate.py`** (Edit/Write/Bash armed): parse + FP_GUARD + GateGuard + (Bash) decode+GUARD_SKIP dalam satu interpreter; bash tinggal short-circuit builtin → `exec python`. Baterai ~14 `grep -qE` anti-self-bypass ikut masuk (python `re` in-process). 3 python + greps → **1 python**.
2. **Gate aggregator execute-bolts**: 9 `bash validate-*.sh` + GATE_REASON → satu driver python import modul-modul heredoc (perlu ekstraksi heredoc → file `_lib/*.py`; ladder ekstraksi ini sudah OPEN ter-gate harness parity dari v6.7.1 — prasyaratnya sudah ada). `dirname=43` lenyap seluruhnya. Git tetap (kerja nyata B1/B3/B4); driver bisa men-share `rev-parse`/`log` antar scan → 110 → **12–23 exec**.
3. **Stop**: parse python → builtin; 4 grep config → 1 read builtin. 13 → ~5.
4. **Dispatcher** (§2): −3 exec di SEMUA event.

Rambu yang mengikat implementasi: **state file byte-identical** (parity-proof kelas merge Fase 2 — golden corpus + diff byte); moat test S12/S2/S3/S13 hijau per commit; **tidak ada mekanisme baru** selain `_gate.py`; binary Go TIDAK dibangun (tercatat sebagai opsi bila angka fleet belum diterima — §8).

## §7 Proyeksi wall-time Windows — kriteria ≤20 detik, hitungan jujur

Sesudah semua lever §2–§6 (dispatch langsung, `_gate.py`, fan-out mati, matcher `Write|Edit`, Stop+SS diet), model sesi yang sama:

| Ukuran sesi | Blocking sekarang | Blocking sesudah | ≤20 s? |
|---|---|---|---|
| 30 tool call | ~85 s | **~15 s** | ✅ |
| 45 tool call | ~127 s | ~22–24 s | ⚠️ marginal |
| 60 tool call | ~170 s | ~30 s | ❌ |

(Background/async: ~4,3 menit CPU → ~1 menit.) Floor-nya aritmetik: PreToolUse tidak bisa berhenti match (moat), jadi lantai = 2 exec/event (1 bash + 1 python) × jumlah event. **Dua lever untuk menutup 45–60:**

- **Opsi B "0-python armed"**: perluas fast-path pre-tool-use — armed + tanpa fragmen protected + path TIDAK ada di `.locked-files-index.json` (substring builtin, fail-closed ke python pada keraguan apa pun) → exit 0 tanpa python. Ini mekanisme yang **sama persis** dengan notice pasca-edit Bagian 2, dipakai dua arah. Lantai jadi 1 exec/event → 60 call ≈ 18–20 s ✅. Perlu keputusan gate: GateGuard deny-once tetap butuh python HANYA saat file ADA di index — konsisten.
- **Binary tunggal (Go/Rust)**: tetap TIDAK direkomendasikan sekarang; jadi eskalasi hanya kalau angka lapangan pasca-7.5.0 masih ditolak fleet.

## §8 Titik singgung Bagian 2 (auto-aware tier S) — dicatat untuk implementasi yang sama

- Notice pasca-edit 0-fork membaca `.locked-files-index.json` dengan builtin — **infrastruktur yang sama** dengan Opsi B §7; satu implementasi, dua konsumen. Pin: tier S tetap 0 python.
- Census kalimat "selesai" (`udah/commit/push/PR/merge`) → tawaran sync satu baris; `auto_verify_on_edit: false` default. Keduanya masuk fase implementasi, bukan audit ini.

## §9 Temuan sampingan (dicatat, read-only)

1. **Phantom Fase 5 №1**: `session-start:153` masih menulis "Bolts phase will use vendored fallback" — vendored tree sudah dihapus v7.4.0. Reword saat implementasi (probe superpowers-nya sendiri tetap sah).
2. **S11 pass hampa**: `test-tier-s-hooks.sh:113` meng-exercise `hooks/subagent-stop` yang filenya sudah tidak ada (run_hook error senyap → 0 fork → "pass"). Retire/repin.
3. **Prose basi** di `tests/hooks/bounded-subprocess.test.sh:49` ("post-tool-use has 14 invocations…", "registered twice PostToolUse + PostToolUseFailure") — komentar, bukan assertion; rapikan saat lewat.
4. `run_validator_and_emit` membawa 2 argumen mati (`state_file`, `script_label` — "kept for call-site compatibility") — hilang sekalian bersama fan-out.

## §10 Inventaris repin test (bila gate menyetujui)

- **Fan-out mati**: `tests/weighted-routing/test-tier-s-hooks.sh` S12 (pin terkeras — `python3 ≥ 5` + `.validation-blockers.json`; premis "arming restores fan-out" berubah jadi "arming restores gate-time recompute" → repin ke dispatch gate), `tests/efficiency/test-efficiency-pins.sh:20-21` (grep literal blok paralel), `tests/hooks/test-mermaid-flow-hook-fire.sh`, `tests/god-review-s4/test-4a`, `tests/god-review-s5/test-5a`, `tests/token-efficiency/test-4de`, `tests/verify-grounding/test-verify-grounding-wired.sh`, `plugins/mega-sdd/tests/graph/test-vault-layout2.sh:260`, `tests/god-review-s3/test-3a:192`, `tests/derived-artifacts/test-p3:191`, `tests/surface/test-p4b:39`. Selamat tanpa repin: `dirty-journal.test.sh`, `post-tool-use-windows-paths.test.sh` (journal always-on).
- **Matcher drop Bash/Skill**: `tests/platform/test-platform-pins.sh:35` (tetangga edit hooks.json), `hook-stdin-quoting.test.sh`, tier-S S7/S8. Drop Skill = mematikan satu-satunya call site validate-starterkit-metrics — **tidak ada test yang gagal** (census).
- **Dispatcher langsung**: test yang memanggil `run-hook.sh` by name + `tests/platform/test-line-endings.sh` survive (existence only); grep menyeluruh saat implementasi.

## §11 Urutan implementasi yang diusulkan (satu jalur per commit, bump 7.5.0)

1. `ci-guard` repin dulu: harness spawn diperluas (dispatcher-inclusive) masuk `tests/weighted-routing/` dengan ceiling BARU dipin SETELAH tiap commit menurunkannya (measure-last, pelajaran adversarial rounds).
2. **№A dispatch langsung** (hooks.json + guard `${0//\\//}` per body; run-hook.sh dihapus) — menyentuh semua event, win terbesar per byte.
3. **№B Stop + session-start diet** (builtin parse; anchor statis saat release; probe superpowers builtin; fix phantom vendored §9.1).
4. **№C matcher `Write|Edit`** + hapus leg Bash/Skill + starterkit-metrics decision + 4 advisory masuk daftar re-run FULL run-analyze.
5. **№D fan-out mati** (repin S12 dkk; parity: gate-read states tetap ditulis identik oleh gate).
6. **№E `_gate.py`** (parse+FP_GUARD+GateGuard+Bash-guard satu interpreter; parity byte state file).
7. **№F aggregator driver python** (ekstraksi heredoc → `_lib`, ter-gate harness parity v6.7.1).
8. **№G Bagian 2 auto-aware** (notice locked-index + census "selesai" + `auto_verify_on_edit`) — sekalian Opsi B 0-python bila di-ACC.
9. Tutup: tracer + spawn harness re-run, tabel before/after, verifikasi SEKALI di satu laptop kantor (kriteria ≤20 s), baru Fase 6.

## Pertanyaan gate (keputusan user)

1. **starterkit-metrics**: hapus validator+leg (halt tetap prose — status quo), atau wire beneran (analyze re-run / PreToolUse dengan fail-open disclosed)? *Rekomendasi: hapus; catat evidence-flip №15.*
2. **Opsi B 0-python armed** (fast-path builtin locked-index untuk Edit/Write/Bash armed non-protected): ambil sekarang (satu-satunya jalan ≤20 s di 60 call tanpa binary) atau tahan di 1-python floor?
3. **Matcher PostToolUse**: `Write|Edit` penuh (rekomendasi, syarat №C) — konfirmasi.
4. Urutan §11 + bump 7.5.0 — konfirmasi.
