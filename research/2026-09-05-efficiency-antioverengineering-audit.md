# Efficiency & Anti-Overengineering Audit — hasil (2026-09-05, head 7.27.0)

> Menjawab prompt `research/2026-09-05-efficiency-audit-prompt.md` (§33–§50). Metode: 3 lane riset paralel — (1) inventory deterministik ukuran/biaya, (2) analisis overlap kapabilitas per skill/validator/agent, (3) rekonstruksi backlog terbuka + bukti pain lapangan vs kekhawatiran hasil audit. Semua angka diambil dari repo hari ini, bukan dari memori.

---

## 0. Verdict satu kalimat

**Mega-SDD hari ini sudah efisien secara arsitektur — merger/diet yang biasanya diusulkan audit semacam ini SUDAH dieksekusi dan terukur; sisa masalah yang nyata bukan masalah engineering, tapi (a) satu keputusan owner yang nunggu di gate (№A size-weighted spec — jawaban untuk keluhan terukur tim), dan (b) gap bukti lapangan: tim masih di 7.6.x sementara head 7.27.0, jadi ~21 rilis kapabilitas belum tervalidasi pemakaian nyata.**

Konsekuensi praktis: langkah bernilai tertinggi berikutnya adalah **berhenti nambah kapabilitas, jalankan field run di versi terkini, dan putuskan №A** — bukan refactor apa pun.

---

## 1. Snapshot inventory (fakta, 2026-09-05)

| Permukaan | Ukuran |
|---|---|
| Skills | 19 skill, SKILL.md total 2.738 baris (semua ≤206, cap 500), references 17.759 baris (progressive-disclosure, load on demand) |
| Agents | 9 file, 644 baris |
| Commands | 6 file (3 verb + 3 one-timer), 412 baris — sesuai kontrak |
| Hooks | 6 event, 2.786 baris; `pre-tool-use` 1.603 baris di matcher terluas, tapi hot path pure-shell 0-fork (doktrin v7.5.0) |
| Scripts | 100 file (87 sh + 13 py), 38.539 baris; terbesar `build-dispatch-prompt.sh` 3.633 |
| Refs plugin-root | 71 file / 12.285 baris (separuhnya framework-conventions packs — data, bukan logic) |
| Tests | plugin-local 71 file + repo-root 614 file (~44.7k baris) |
| SessionStart inject | ~4.0 KB (~1.000 tok) per sesi fresh HANYA di repo ber-sinyal SDD; compact ~1,6 KB; resume 0; non-SDD 0 byte |
| Rilis 7.x | 37 entri sejak 7.0.0 (~2,5 minggu) |

## 2. Bukti bahwa "sudah diaudit" bukan klaim kosong

Empat ronde efficiency sudah CLOSED dengan pengukuran, bukan estetika:

- **Benchmark beku v6.1.1→v6.6.0**: commanded context −21,9% agregat, T03 −53,4%, median task −39% (static trace, bias konservatif); quality PASS dua arm; satu regresi tercatat jujur (executed plane +11,3%).
- **v6 Express Spine**: −34% cache-write ke first bolt, −7% net time (target <10 menit FAILED — dipublikasikan apa adanya).
- **Suite runtime** 2.189s→387s (v4.60.0). **Per-lens panel routing** v7.8: full-panel 30/30 → 17/13/1 setelah diukur.
- Usulan diet yang **DITOLAK berdasarkan trace** dan jangan dibuka lagi tanpa telemetry: c1 batch-rescan (KEEP — cut berisiko 10⁴–10⁵ tok utk hemat ~0,7s), P2b, TOON/kompresi, starterkit surgery (REFUTED — 82 file konsumen hidup).

## 3. Klasifikasi kapabilitas (§34)

**KEEP (dan JANGAN disentuh):** moat 5 invarian + recompute-at-gate; trio "code moved" (detect-drift / sync-lane / diff-vault — tiga sumbu input berbeda, plumbing shared lewat satu writer `derive-vault-json.sh`); `analyze` (129 baris, presenter tipis di atas `run-analyze.sh`); `graph` (53 baris, konsumen mesin nyata: transitive-impact, UAT/SIT builder, dispatch-prompt); keluarga emit (engine `emission-engine.md` shared + parity pin — merger-nya sudah dikerjakan di P3/P5); `resolve-oq` 3 mode (satu permukaan keputusan manusia, memecahnya justru fragmentasi); `scan-codebase` (demosi sudah membankkan winnya; semua bagian punya konsumen); layering front-door ↔ orchestrate-flow (satu engine `derive-state.sh`); review panel 6 lensa (tiering terukur; `resolution-verifier` = pengurang biaya); `using-mega-sdd` (88 baris, anchor-core capped — router S/M/L ini justru mekanisme hemat token, bukan biaya); SessionStart inject (bersyarat, source-aware, sudah di lantai).

**SIMPLIFY (1 item, satu kalimat):** kepemilikan konfirmasi front-door Lane 0 vs orchestrate-flow Step 6 — tidak dinyatakan apakah chain yang sudah dikonfirmasi front door di-re-confirm di Step 6. Fix = satu kalimat di Step 6 ("skip when the dispatching front door already confirmed this chain"). UNKNOWN apakah double-prompt benar terjadi live.

**MERGE:** tidak ada kandidat yang survive. Merger yang masuk akal sudah dieksekusi (emission engine, alias cull 6.0.0, MERGE 10/10 v7 Fase 2, verifier-instead-of-repanel).

**DEPRECATE (remah, next major):** prose PARKED iter classifier di orchestrate-flow (dead design surface nebeng file hidup — pindahkan penuh ke spec doc); flag no-op `generate-units --skip-pagerank` + `install-deps --force-recheck` (shim compat, murah disimpan, lebih murah dibuang di major berikut).

**REPLACE:** tidak ada. Tidak ada kapabilitas yang problem-nya lebih murah dipecahkan ulang daripada dipertahankan.

**UNKNOWN (butuh data lapangan, BUKAN pembacaan repo):**
- **Multi-squad machinery** (squads.yaml, cross_squad halts, `--per-squad`) — permukaan cross-cutting terbesar tanpa bukti demand lapangan.
- **Trio factory-ledger / convergence / checkpoint** — tiga mekanisme resume/retry overlap dengan tabel precedence; kompleksitas-per-pemakaian terpadat di plugin; ukur firing rate backward-routing di field run dulu.
- **`emit-agents-md`** — satu-satunya emisi tanpa verifier deterministik, plausibly once-per-project; kandidat DEPRECATE teratas KALAU cek lapangan menunjukkan nol konsumen non-Claude di kantor.
- **Orphan sweep: nol kapabilitas mati** — semua script ber-referensi rendah resolve ke konsumen nyata (hook/gate/test).

**Validator (§42 risk-based):** roster 24 validator sudah terstratifikasi benar — kelas moat/business-logic tetap hard gate; kelas stylistic (dispatch-prompt, vault-flow-staging, fanout-parity, ui-deferral, operator-UX, reuse-duplication) sudah advisory via analyze. Satu-satunya hard gate berkelas "estetika" adalah `validate-ui-quality` (scaffold-tells) — KEEP (moat by decision), tapi tercatat sebagai kandidat pertama untuk direlitigasi bila diet berikut butuh korban.

## 4. Bagian yang genuinely weak (dengan bukti)

1. **Proporsionalitas bobot spec** — keluhan tim TERUKUR (17,9:1 instruction:code di unit 22 baris; 5,8:1 spec:code; 28 OQ utk 3 layar statis). Ini pain P1 nyata, bukan temuan audit. Jawabannya sudah didesain: **№A size-weighted spec (`docs/superpowers/specs/2026-08-23-size-weighted-spec-design.md`) — masih GATE nunggu approval owner.** Bottleneck-nya keputusan, bukan engineering.
2. **Gap versi lapangan** — tim di 7.6.x, head 7.27.0. Semua akurasi KB-verify (7.24–7.27), coarsening (7.20), OQ human-first (7.21–7.22) belum pernah dipakai orang selain kita. Risiko klasik overengineering bukan "kode jelek", tapi "kapabilitas menumpuk lebih cepat dari validasi".
3. **`build-dispatch-prompt.sh` 3.633 baris** — biaya maintenance murni (0 tok/run, tidak pernah masuk context). Harness parity P0 sudah shipped (v6.7.1); ladder ekstraksi P1+ tetap OPEN, opportunistic-only. Bukan prioritas.
4. **Velocity/DX belum terukur** — runbook + survey siap (`benchmarks/runbooks/velocity-live-ab.md`, `benchmarks/surveys/dx-survey.md`, 0 respons). Telemetry lokal DIHAPUS by design (7.3.0) → beberapa keputusan (C2, multi-squad, factory-trio, emit-agents-md) **secara struktural tak bisa diputuskan dari repo**; datanya harus dari gateway/field. §47: jangan bangun ulang observability lokal — gateway IS the lightweight mechanism.

## 5. PRD problem vs Mega-SDD problem (§49 q4)

- 28 OQ utk 3 layar = sebagian kualitas dokumen input (PRD tipis memaksa OQ), tapi ketiadaan skala-turun spec = masalah Mega-SDD → №A.
- Wrapper/stale-install (index [0] → 6.6.0) = masalah produk, sudah RESOLVED 7.5.1/7.5.2 + prosedur headless update.
- 12/26 validator SKIP di pack `_universal` = masalah Mega-SDD, dijawab SKIP-honesty + migrasi kb_* (7.24.0).
- TOKEN-COST-REPORT kosong = dijawab dengan penghapusan by design (7.3.0), biaya pindah ke gateway.

## 6. Decision matrix (§35, §48)

| Usulan | Value | Complexity | Token | Time | Maint | Klasifikasi §48 | Keputusan |
|---|---|---|---|---|---|---|---|
| Putuskan gate №A size-weighted spec | HIGH (pain tim terukur) | MED (spec sudah ada) | turun | turun | MED | **SHOULD HAVE** | **PUTUSKAN SEKARANG** (keputusan owner, bukan build baru) |
| Field run kantor di versi terkini + data gateway mengalir | HIGH (unlock semua UNKNOWN) | LOW | 0 | 0 | 0 | **SHOULD HAVE** | JALANKAN — prasyarat semua keputusan lain |
| Satu kalimat confirmation-ownership di orchestrate-flow Step 6 | LOW-MED | LOW | ~0 | 0 | LOW | SHOULD HAVE (doc-fix) | Implement kapan pun murah |
| Buang remah DEPRECATE (iter-classifier prose, 2 flag no-op) | LOW | LOW | ~0 | 0 | turun | NICE TO HAVE | Tumpang di major berikut (policy ladder utk flag) |
| Ladder ekstraksi `build-dispatch-prompt.sh` P1+ | MED (maint only) | MED | 0 | 0 | turun | NICE TO HAVE | Opportunistic, ter-gate harness (sudah tertulis di spec) |
| Cut multi-squad / factory-trio / emit-agents-md | ? | — | — | — | turun | **UNKNOWN** | DEFER sampai data lapangan; jangan cut buta |
| Diet byte lanjutan (skill bodies, halt refs, dst) | ~0 | MED | ~0 | 0 | naik (churn) | **NOT NEEDED** | c1/P2b/static-plane sudah membuktikan flat |
| Merge skill emit jadi satu / kurangi lensa panel / gabung drift-sync-diff | negatif | HIGH | naik | naik | naik | **OVERENGINEERING** (arah kebalikan) | REJECT — factoring/tiering sudah optimal |
| Bangun ulang observability/telemetry lokal utk ukur №A dkk | LOW | HIGH | naik | naik | naik | **OVERENGINEERING** | REJECT (§47 eksplisit; 7.3.0 keputusan sadar) |
| Validator baru kelas apa pun tanpa temuan lapangan | LOW | MED | naik | naik | naik | OVERENGINEERING | REJECT by default — audit KB-verify menunjukkan validator lahir dari audit lapangan, pertahankan urutan itu |
| Rewrite / re-arsitektur apa pun | — | — | — | — | — | OVERENGINEERING | REJECT (§46 — tidak ada bukti incremental gagal) |

## 7. Complexity budget (§45)

**NO CHANGE REQUIRED** — budget-nya sudah ada dan ENFORCED, bukan aspirasi:

- Skill body ≤500 baris (aktual max 206); anchor-core byte-capped 3.600 (aktual 3.587); refs one-level-deep dgn lint; command surface dikunci 6 file by contract; dispatch depth ≤2 (depth-1 subagent, sprint-subagent REJECTED on record); panel per-lens risk-tiered (terukur); hook hot path 0-fork by doctrine; duplication terukur flat 1,08%.

Satu guideline tambahan yang layak diadopsi (bukan angka baru, tapi urutan): **evidence-first untuk kapabilitas baru** — sejak sekarang, fitur baru masuk hanya lewat jalur "temuan lapangan → triage → spec → gate" (pola audit HOST-AS400 → KB-verify lane), bukan "audit repo → ide". Repo ini sudah de facto begitu; jadikan eksplisit.

## 8. Jawaban §49, ringkas

1. **Sudah efisien?** Ya, dan terbukti terukur — dengan dua residu non-arsitektural (№A di gate, gap versi lapangan).
2. **Yang bagus & jangan diubah:** semua baris KEEP di §3 — terutama moat, recompute-at-gate, tiering panel, emission engine, router S/M/L.
3. **Yang lemah:** §4 (proporsionalitas spec, gap validasi lapangan, monolit dispatch-prompt [maint-only], velocity/DX unmeasured).
4. **PRD vs Mega-SDD:** §5.
5. **Perubahan terkecil per masalah:** №A = keputusan gate (spec sudah jadi); gap lapangan = update tim + field run (0 kode); confirmation-ownership = 1 kalimat.
6. **Yang tidak perlu:** semua baris NOT NEEDED/OVERENGINEERING di §6.
7. **Yang menaikkan token:** telemetry lokal, validator baru, merge yang menggemukkan body skill.
8. **Yang menaikkan waktu:** validator hard-gate baru, observability, re-panel non-tiered.
9. **Yang menaikkan maintenance:** rewrite, abstraksi baru, diet-churn tanpa hasil.
10. **Implement sekarang:** (a) keputusan №A, (b) field run versi terkini, (c) kalimat Step 6. Tidak ada MUST-HAVE kode — tidak ditemukan celah yang membuat AI behave materially incorrect (kelas itu terakhir ditutup 7.24–7.27 dari audit lapangan).
11. **Eksplisit JANGAN:** rewrite; diet byte lanjutan; merge skill; kurangi lensa; observability lokal; cut buta multi-squad/factory-trio/emit-agents-md.
12. **Defer sampai ada bukti:** semua UNKNOWN §3; fork flip scan/bind (nunggu 2 run interaktif); C2 (data gateway); ladder P1+; extras slice-design (setelah №A); framework+npm (2 spike gate).

## 9. Lesson §50

Sistem ini tidak sedang gagal karena kompleksitas — ia sedang berisiko gagal karena **outrunning its own evidence**. Kecepatan rilis (37 rilis 7.x dalam ~2,5 minggu) melampaui kecepatan validasi lapangan (tim di 7.6.x, DX survey 0 respons). "Building a better Mega-SDD" saat ini berarti mengonsumsi bukti, bukan memproduksi fitur.
