# v7 Fase 1 — Bukti implementasi (trace after + spawn terukur + verifikasi R2)

**Tanggal:** 2026-08-21 · **Spec:** `docs/superpowers/specs/2026-08-21-v7-weighted-routing-design.md` · **Baseline BEFORE:** `research/2026-08-21-v7-diet-audit.md` §4

## 1. Spawn terukur (bukan estimasi) — metode

Fixture project ter-adopsi (`.mega-sdd/{codebase/,config}`, satu file source) + PATH shim yang menghitung setiap eksekusi `python3 date wc git grep sed find ls` sebelum exec binary asli. Setiap hook dijalankan dengan stdin JSON persis bentuk harness. Angka di bawah adalah hasil run live (macOS, 2026-08-21), dikunci sebagai CEILING oleh `tests/weighted-routing/test-tier-s-hooks.sh` (17 assertion — termasuk proteksi arm-switch, map shared-worktree, dan rail subagent — ikut CI kedua tree).

| Skenario | BEFORE (audit §4.2) | AFTER (terukur) |
|---|---|---|
| PreToolUse **Edit path biasa, un-armed** | 3 python + ~4 fork, BLOCKING (Win 1,5–2,5 dtk/call) | **0 fork, 0 python, output kosong** |
| PreToolUse **Bash innocent, un-armed** | 3 python + ~2 fork | **0 fork** |
| PreToolUse **Write file state (forge)** | deny | **deny — tetap, always-on** (3 python) |
| PreToolUse **Bash tamper `rm .validation-blockers.json`** | deny | **deny — tetap, always-on**; termasuk percobaan spoof `"tool_name": "Edit"` di dalam command (S3b) |
| PostToolUse **Write source, un-armed** | 10–18 fork background (3 validator undebounced + glob) | **1 fork (date), 0 python; journal row utuh** (`{"ts","path","tool","session"}`) |
| PostToolUse **Read, un-armed** | ~2–4 fork | **0 fork** |
| UserPromptSubmit **un-armed** | 2 python + transcript scan O(sesi) (Win ~1,3–1,8 dtk/prompt) | **`mega-sdd-trace:turn` saja, 0 fork, 0 scan** |
| Stop **project non-SDD** | 1–2 python TIAP turn | **0 fork** |
| SubagentStop **project non-SDD** | ~2 python per subagent | **0 fork** |
| **ARMED**: Skill dispatch `mega-sdd:*` | — | `chain_engaged` tertulis di `.gateguard-state.json` (session-keyed) |
| **ARMED**: Edit | full path | full path (python parse + FP_GUARD — identik pre-v7) |
| **ARMED**: Write unit file | fan-out validator | **fan-out pulih penuh: 27 python, `.validation-blockers.json` tertulis** (mutation-proof S12) |
| **Subagent context** (sentinel `agent_id`) walau un-armed | — | full path (S13 — bolt edits tetap ter-gate) |

**Proyeksi Windows kantor (CrowdStrike ~220 ms/spawn):** sesi bug-fix 30–60 tool call yang tadinya membayar ±55–90 dtk blocking + 60–120 dtk background CPU kini membayar ~0 (fast path = bash builtin murni, nol fork). Sesi chain: biaya identik pre-v7 by construction.

## 2. Trace "cari bug" AFTER (statis, langkah demi langkah vs audit §4)

Skenario sama: project klien ber-`.mega-sdd/` lengkap, prompt *"ada bug di fungsi hitungDenda, tolong cari dan fix"*, sesi fresh.

| Langkah BEFORE | AFTER |
|---|---|
| 1. SessionStart inject anchor ~930 tok + ~24 spawn | Tetap ada (anchor = tempat tabel S/M/L hidup): core 3.918 B ≈ ~980 tok (naik ~125 tok dari 3.417 B — harga tabel + larangan negatif). Spawn session-start belum dikurus (backlog Fase 2 №2: pindah C1 self-resolve ke ground.sh). CWD non-SDD: injeksi = 1 baris marker governance (dari ~550 B blok MANDATORY). |
| 2. UserPromptSubmit per prompt: 2 python + transcript scan | Tag saja, 0 fork (terukur §1). |
| 3. UserPromptExpansion | Tetap tidak fire (matcher tidak match) — tidak berubah. |
| 4. Routing model-side: `:13(c)` CWD-invoke + Hard rule STOP → front door | **Hilang.** Tabel S/M/L: prompt ini = tier S eksplisit ("bug hunt / fix" adalah contoh baris S; tidak ada keyword M/L; larangan negatif: "do NOT invoke, do NOT open /mega-sdd, do NOT propose sync"). Nol invoke, nol front door. |
| 5. ground.sh → derive-state → symbol-index → status view (±10–14 spawn + 4–5k tok) | **Tidak jalan** (hanya jalan saat user sendiri membuka `/mega-sdd`). |
| 6. Chain proposal + konfirmasi + sync lane ±60,6k tok | **Tidak ada.** Staleness notice = 1 baris informasional; sync ditawarkan hanya di entry M/L. |
| 7. PreToolUse per Edit/Write/Bash: 3 python blocking + GateGuard deny LOCKED (+1–3k tok) | **0 fork** per call (terukur); GateGuard chain-scoped (residual risk diterima gate-1, dicatat di CHANGELOG). Guard anti-forge tetap deny (terukur S2/S3). |
| 8. PostToolUse per Edit: 10–18 fork; dirty journal memanufaktur change_signal → sesi berikutnya propose sync ±60k tok | Journal tetap mencatat (1 fork, shell) — tapi konsumsinya berubah: session-start hanya menampilkan notice; proposal sync hanya muncul saat user masuk M/L. **Ekor sync ±60k tok untuk fix tier-S: hilang.** |

**Total AFTER untuk bug-hunt tier S: ≈ anchor injection (~1k tok) + 0 script mega-sdd + 0 block + 0 sync tail** — vs BEFORE ±30–65k tok / 15–25 mnt (jalur pipeline) atau ±930 tok + 9–14 dtk / 1,5–3 mnt spawn tax + deny + sync tail (jalur "patuh"). Kriteria §7 spec: (a) tier S ✓, (b) nol script selain session-start ✓, (c) jawaban = vanilla CC (tidak ada teks yang menyuruh lain) ✓, (d) nol PreToolUse block ✓ (terukur), (e) nol sync tail ✓.

## 3. Verifikasi R2 (subagent session_id) — hasil

Pertanyaan gate-1: apakah stdin hook untuk tool call subagent membawa `session_id` sesi utama? **Jawaban dari docs resmi (code.claude.com/docs/en/hooks, via claude-code-guide): AMBIGU — docs tidak menspesifikkan semantik `session_id` di konteks subagent.** Tapi docs MENJAMIN field sentinel yang hadir HANYA di konteks subagent: `agent_id`, `agent_type`, `agent_transcript_path`, `parent_tool_use_id` ("Common Subagent Context Fields").

**Resolusi (lebih kuat dari rencana):** rail fail-closed di kedua armed-check (fast path + `v7_chain_armed()`) key ke ketiga sentinel — konteks subagent SELALU diperlakukan armed, sehingga ambiguitas `session_id` jadi tidak relevan: edit bolt-implementer tetap melewati jalur gate penuh apapun semantiknya (dibuktikan test S13). Fallback `.plan-pending` gate-1 juga terpasang. Tidak ada asumsi yang tersisa untuk diverifikasi di lapangan; kalau suatu saat harness menambah konteks subagent tanpa ketiga sentinel, moat-nya fail-closed (full path), bukan fail-open.

## 4. Deviasi dari desain yang disetujui (dilaporkan, tercatat di spec §7)

1. **armed = `chain_engaged(session)` saja** — AND-`factory-ledger.json` dibuang (lubang greenfield first-chain: ledger belum ada sampai handoff fase pertama → seluruh chain pertama akan un-armed). Lebih ketat untuk moat; identik untuk tier S.
2. **No-signal CWD tidak bisu total** — 1 baris `mega-sdd-trace:session` bertahan (kontrak deteksi governance gateway v6.19.2; bisu total = false-flag semua sesi non-SDD di bawah warn→block).
3. **`--full` bukan alias weight** — kolisi dengan profile switch `--lean|--full`; sesuai catatan gate-1, flag weight satu-satunya `--weight=S|M|L`.
4. **`engaged_sessions` map (spec §7.4)** — hasil panel adversarial: arming single-owner me-regresi shared-worktree (dua sesi satu tree = workflow nyata lo); kini per-sesi map di file yang sama, dan `.gateguard-state.json` MASUK daftar protected anti-forge (Write/Edit + Bash tamper deny — arm switch tidak boleh bisa dilucuti agent).
5. **Derivasi handoff gate-time = absent-only untuk Fase 1 (spec §7.5)** — recompute tiap dispatch terbukti memvalidasi teks turn berjalan (FAIL palsu atas narasi ber-`handoff:`) dan menggandakan retry_count (eskalasi C1→C2 prematur). Fase 1 menutup gap fresh-session/clone saja + wajib envelope nyata (`emitted_by:` line-start); recompute penuh + content-hash menyusul Fase 2 bareng penghapusan leg Stop.

## 4b. Ronde adversarial (4 lensa + verifikasi, 14 agent)

Semua temuan CONFIRMED sudah di-fix di working tree sebelum commit B: R-1 arm-switch unprotected (→ masuk _GUARDED + PROTECTED + prot regex), R-2 cross-session un-arm (→ engaged_sessions map, semua 5 situs armed-check), R-3 Branch 1a teks turn berjalan (→ absent-only + envelope wajib), R-4 retry_count dobel (→ tereliminasi oleh absent-only), R-5 regex config tak ter-anchor (→ anchored line-start di semua fast path), R-6 CPU payload besar (→ size cap 256 KB, fallthrough python). Negative evidence panel: union pre-filter tahan spoof/encoding/symlink/relative-path di semua vektor yang dicoba; refutasi tercatat di jurnal workflow. Fixture prompt-eval di-update ke kontrak v7 (using-mega-sdd.test.md T3, scenario-12 Act 2).

## 5. Backlog eksplisit ke Fase 2 (dari gate-1)

- Pindahkan blok C1 self-resolve 9-guard session-start → `ground.sh` (session-start tidak boleh menulis artifact vault); session-start tersisa: install-front-door (debounced) + derive-state notice + inject anchor.
- Kurus Stop: hapus leg handoff-validation DAN naikkan derivasi gate-time dari absent-only ke full-recompute dengan content-hash di state validator (dedup retry_count); short-circuit sudah masuk Fase 1.
- Rotasi `hook-debug.log`; collapse bash staleness fallback session-start ke `derive-state.sh`; debounce install-front-door.
- Hapus rung hook milik validator yang di-DELETE Fase 2 (pandoc ±65L, starterkit ×2, dst. per audit §6).
- **CI diet (APPROVED user 2026-08-21, diskusi pasca-Fase-1):** (a) path filter — push yang hanya menyentuh `docs/`, `research/`, `*.md` root skip loop suite (manifest-validate tetap); (b) cache npm untuk CLI `claude plugin validate`; (c) paralelkan loop suite (`xargs -P`) SETELAH satu pass verifikasi bahwa tidak ada suite yang menulis state repo bersama (mayoritas mktemp — buktikan, jangan asumsikan). Konsolidasi test dari delete/merge Fase 2 menurunkan jumlah suite dengan sendirinya. Baseline: ~4,2 mnt/run hari ini.
