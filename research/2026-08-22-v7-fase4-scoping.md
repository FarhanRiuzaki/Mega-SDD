# Fase 4 scoping — markdown diet (metrik: token commanded per lane)

**Status: SCOPING READ-ONLY — berhenti di gate; nol perubahan kode/md.**
**Premis (terverifikasi):** pasca Fase 1–3, yang dibayar LLM per run bukan script (dieksekusi, 0 token) tapi **md yang di-command**: `skills/` 2.272 KB + `references/` 1.036 KB + `agents/` 80 KB + `commands/` 56 KB ≈ **3,4 MB instruction plane** (~860k est tok; chars÷4).

## 1. Baseline T02/T03 — masih berlaku (diverifikasi rerun tracer hari ini)

Tracer statis benchmark (`measure-context.sh`, daftar file arm `optimized` v6.6.0) di-rerun pada tree HEAD:

| Task | v6.6.0 est tok | HEAD est tok | Δ | Catatan |
|---|---:|---:|---:|---|
| T02 brownfield-bind | 66.146 | 67.199 | +1% | **baseline valid** |
| T03 sync-no-intersection | 60.641 | 61.594 | +1% | **baseline valid** |
| T04 sync-with-intersection | 110.609 | 112.742 | +1% | valid |
| T05 resolve-oq-walk | 57.117 | 57.318 | 0% | valid |
| T06 emit-fsd | 36.763 | 36.677 | −1% | valid |
| T01 greenfield-chain | 118.564 | 110.565 | −7% | trace ROT: 7 path template lama hilang (Fase 3) — daftar file T01/T07 perlu re-derivasi (4 template baru belum masuk); angka = bawah |
| T07 chat-delta | 119.820 | 113.941 | −5% | idem T01 |
| T08 post-bolt drift gate | 9.165 | 9.199 | 0% | valid |

**Kesimpulan:** Fase 1–3 memang tidak menyentuh context md (by design); Fase 4 adalah fase yang menyentuhnya. Deliverable awal Fase 4 wajib: **re-derivasi daftar trace T01+T07** ke kontrak loading v7.

## 2. Peta beban per lane

Metode: COMMANDED = imperatif di jalur default (express spine); [COND] = di balik gate eksplisit; **file yang DIEKSEKUSI script TIDAK dihitung** (lever kebenaran terbesar: `context-enrichment.md` 76 KB + `bolt-dispatch-prompt.md` 24,7 KB + `section-mapping.md`/`fsd-template.md`/`emission-engine.md` ~38 KB + templates cp ~27 KB — semuanya 0 token saat run). Token = bytes÷4.

| Lane | Core | Realistic default | Est tok | Catatan |
|---|---:|---:|---:|---|
| intent | 132,5 KB | 147,3 KB | **36,8k** | vault-contract 41,6 KB + generation-guide 26,5 KB dominan |
| bind express | 92,2 KB | ~147,9 KB | **37,0k** | +auto-memory-handoff 16,6 KB + pack 14–33 KB + advisor |
| units | 94,0 KB | 111,2 KB | **27,8k** | unit-schema 27 KB + task-typing 16 KB |
| bolts (1 unit) | 126,8 KB | 166,5 KB | **41,6k** | controller main-thread 128,7 KB (SKILL 45 KB!) + 37,8 KB md subagent panel |
| sync | 103,4 KB | 140,6 KB | **35,2k** | exit-0 short-circuit hanya 103 KB; cabang drift +37 KB |
| emit fsd | 16,3 KB | 16,3 KB | **4,1k** | **lane terbersih — bukti pola script-ification bekerja** |
| **Pipeline penuh (1 unit)** | | **~730 KB** | **~182k** | |

## 3. Duplikasi

- **Exact-line** (script `measure-duplication.py`, rerun HEAD): 148 varian baris, 31.306 chars = **1,13% plane** — didominasi parity pin framework-packs 24× (DISENGAJA, jangan dipangkas). Exact-line BUKAN masalahnya.
- **Prosa semantik** (aturan sama, kalimat beda) — temuan audit agent:

Audit paraphrase keluarga orchestrate-flow (SKILL 25 KB + 15 refs ≈ 205 KB): **~19,6 KB duplikat semantik (~9,5% keluarga)** — 10 aturan terbesar terpetakan dengan OWNER tunggal per aturan. Actionable tanpa keputusan desain: **~17 KB** (satu item, mirror `derived-position` di routing-rules, DINYATAKAN intentional di file-nya — butuh keputusan, bukan edit). Top: skema field handoff dinyatakan 2–3× di handoff-contract sendiri (~3,2 KB); profil `--lean` di 3 tempat (~2,1 KB); mekanik `--resume` di **4 lokasi** (~1,6 KB); starterkit-first di 2 file tanpa disclaimer (~1,3 KB); rails diagnostik di-restate per-diagnostik (~1,3 KB); greenfield/brownfield 2× DALAM SATU file (~0,9 KB). Peringkat shrink: `routing-rules.md` −8 KB (25%), `orchestrate-flow/SKILL.md` −5,7 KB (23% — nilai tertinggi: resident tiap invokasi), `handoff-contract.md` −3,6 KB. Presedens phrasing sudah ada di repo ("This index deliberately carries NO copy — consult the owner", M-04).

## 4. Kandidat tabel keputusan + kebocoran progressive disclosure

**Kebocoran progressive disclosure (top 5):**
1. `vault-contract.md` 41,6 KB — SKILL SENDIRI menyebut 4 dari 7 section top-level tidak dibutuhkan Step 3, tapi routingnya whole-file Read → split `vault-core.md` (§schema+§OQ+§id-stability); leak ~45–55% file.
2. `review-panel.md` 28,8 KB per unit-batch — controller cuma butuh tabel tier + blind-dispatch + §Attempt rounds; konten authoring lens milik `agents/*.md`.
3. `chain-execution.md` 25,4 KB — separuh diagnostik DEAD di express spine (SKILL Step 7: "SKIPPED on express") tapi ikut termuat + design note PARKED EP1/EP2.
4. `generation-guide.md` 26,5 KB — routing named-section jatuh ke whole-file; satu kolom output-mode selalu mati.
5. `binding-contract.md` 18,6 KB di lane express — separuh retrieval (map evidence-search) tidak pernah dipakai express ("zero map load").
Runner-up: **`execute-bolts/SKILL.md` 45,2 KB adalah leak itu sendiri** — SKILL terbesar, resident tiap unit termasuk unit `verify` yang tak menyentuh code-gate/parallel/squad.

**Kandidat tabel keputusan (top 5, ~17,4 KB prose → tabel kondisi→aksi):**
1. orchestrate SKILL Step 7 blob lean/spine/advisor (~2,7 KB) — `(spine × profile × flag) → (diagnostik, advisor, Stop-aggregate)`; nilai tertinggi (default-path SKILL tertinggi trafiknya).
2. execute-bolts §Flags (~5,1 KB, 14 flag) — `flag → efek | halt | ref`.
3. bind SKILL Step 0 vault resolution (~4,1 KB) — `channel × hits → resolve | halt`.
4. routing-rules §Mode D exit-codes (~3,3 KB) — lookup murni exit `sync-intersect.sh` 0/2/3/4 → aksi (load-bearing untuk batas COND lane sync — kandidat tabel yang DIBACA script, bukan prose ringkas).
5. generate-intent §Mode detection (~2,2 KB) — `sinyal → Mode A/B/B-KB/tanya`.

## 5. Top offender per byte (fakta ukuran, HEAD)

| Skill | Total md | Catatan awal |
|---|---:|---|
| execute-bolts | 321 KB | SKILL 45 KB; `context-enrichment.md` **76 KB** — kontraknya sudah DIEKSEKUSI `build-dispatch-prompt.sh` (0 token saat jalan); porsi yang masih perlu di-LOAD LLM per bolt patut diaudit — kandidat terbesar satu file |
| generate-intent | 212 KB | SKILL 26 KB + 20 refs; template baru 18 KB (−42% vs lama, sudah didiet Fase 3) |
| orchestrate-flow | 197 KB | SKILL 25 KB + routing-rules + chain-execution + handoff-* — tersangka utama duplikasi prosa (temuan §3) |
| scan-codebase | 184 KB | deep-scan-dispatch + schema starterkit/reuse (KEEP per keputusan gate-2; ukurannya boleh diaudit, kontraknya tidak) |
| generate-units | 162 KB | decomposition-rails + validation-passes + templates |
| bind-codebase | 122 KB | SKILL 29 KB + binding-contract + express-bind |

## 6. Rekomendasi scoping (untuk gate Fase 4 — belum keputusan)

| # | Aksi | Perkiraan efek per-run | Kelas |
|---|---|---|---|
| R1 | Dedup keluarga orchestrate ke single-owner + pointer (17 KB actionable; mirror derived-position = keputusan gate) | sync/chain −4–6k tok | edit rendah-risiko, presedens M-04 |
| R2 | Split 5 file bocor (vault-core.md; review-panel dispatcher-core; chain-execution diagnostics keluar dari spine; generation-guide sectioning; binding-contract express-half) | intent −8–10k, bolts −5–7k, bind −4–5k tok | restrukturisasi ref (router SKILL tetap satu-satunya) |
| R3 | 5 blob prose → tabel keputusan (Mode D exit-codes → tabel yang dibaca script) | −3–4k tok + readability | JANGAN jadi prose lebih pendek — kelas carve-out |
| R4 | Pecah `execute-bolts/SKILL.md` 45 KB: inti dispatch + per-mode refs (verify-unit tidak memuat squad/parallel/code-gate) | bolts −5–8k tok/unit | terbesar per-unit karena dikali jumlah unit |
| R5 | Re-derivasi daftar trace T01/T07 (rot template Fase 3) + tambah lane trace bolts-per-unit ke harness benchmark | pengukuran jujur | prasyarat angka |

**Target token per lane (gate menetapkan angka final):** bolts/unit 41,6k → **≤28k**; intent 36,8k → **≤26k**; bind express 37,0k → **≤27k**; sync 35,2k → **≤25k**; units 27,8k → **≤23k**; emit-fsd 4,1k (sudah bersih — jadi model). Agregat pipeline ~182k → **target ≤135k (−25%)**, diukur dengan tracer yang sama sebelum/sesudah, quality gate = suite penuh + trace tier-S + arms benchmark quality PASS.

## 7. Rail yang TIDAK BOLEH dipangkas (anti-halu — daftar lindung)

1. **Grammar verdict binding** (CONFIRMED/CONFLICT/OQ + Implementation State Map 6 kolom) — `binding-contract.md`; konsumennya validator + gate.
2. **Halt taxonomy + registry** (C1/C2/C3, tipe blocker, envelope YAML `emitted_by:`) — dipangkas v6.14 sudah −36%; sisa adalah kontrak.
3. **Hard-rule grammar** (`hard-rule-scan.md`, `hard-rule-grammar-v2.md`) — dieksekusi B1 recompute; md = sumber grammar yang sama dengan engine (two-surfaces-one-grammar).
4. **Mandat Mermaid** + aturan emisi node-quote — gate hidup (baru saja menangkap fixture sendiri).
5. **Kontrak hard-header layout-2 + OQ terpusat + [origin:]** — baru dishipping Fase 3, jangan didiet sebelum satu minor telemetry.
6. **Parity pin framework packs** (24× baris identik) — itu kontrak lint, bukan lemak.
7. **Aturan yang HARUS mekanis jangan jadi prose lebih pendek** — kelas "carve-out prose" (pelajaran Fase 0): kalau bisa deterministik → tabel yang dibaca script, atau script; prose ringkas ≠ rail.
