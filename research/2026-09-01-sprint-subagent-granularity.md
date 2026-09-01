# Research — sprint-level subagent granularity (masukan tim, 2026-09-01)

**Ask tim:** "subagent jangan jalan per unit — satu sprint isi 5 unit yang relate, jadikan 1 subagent."
**Konteks:** tim di v7.6.x, belum pernah merasakan wave default (7.7.0). Ask ini datang SETELAH
penjelasan bahwa sprint scheduling sudah default; yang mereka maksud memang granularity subagent.

## Verdict singkat

| Opsi | Verdict | Alasan satu baris |
|---|---|---|
| A. 1 subagent per sprint (ask tim) | **REJECT on the record** | Depth-1 runtime limit — sprint-subagent tidak bisa dispatch panel; preseden squad-subagent.md |
| B. Knob coarsening di generate-units | **PROPOSE — gated pada contoh tim** | Lever yang benar ada di hulu (ukuran unit), bukan hilir (ukuran subagent) |
| C. Cohesion advisory di lint-units | **PROPOSE — pasangan B** | Deteksi cluster unit kekecilan → saran merge, human decides; read-only, moat utuh |
| D. Sprint context primer | **DEFER** | Nilai belum terbukti; symbol_slice + pointer dispatch sudah menutup sebagian besar re-priming |

## Evidence

### E1 — Runtime physics: subagent tidak bisa spawn subagent (KILLER untuk opsi A)

`skills/execute-bolts/references/squad-subagent.md:13-20` — kasus IDENTIK sudah dievaluasi
untuk `--per-squad` dan ditolak:

> "Subagents cannot spawn subagents (hard depth-1 limit enforced by the runtime; a dispatched
> plugin agent has no `Agent`/`Task` tool). … If a squad subagent were the per-unit controller,
> it would have to dispatch those agents = depth-2 = forbidden; in practice it would silently
> degrade to inline implementation, **losing the review panel** (the moat's quality enforcement)."

Substitusi "squad" → "sprint": argumennya byte-identical. Satu sprint-subagent yang memegang 5 unit
TIDAK BISA memanggil `bolt-implementer` maupun 4 lensa review panel — dia bakal implement inline
tanpa panel, tanpa blind review, tanpa per-unit gate attribution. Itu bukan trade-off, itu
kehilangan moat #2 dan #5 (CONFLICT gate + no-fabrication enforcement jalan lewat per-unit
artifacts yang hook-guarded).

### E2 — Context decay terukur

- Implementer ≈ **80 turn per unit** (`execute-bolts/SKILL.md:25` — dasar `parallel_max: 4`,
  "CC's 20-subagent default × an ~80-turn implementer is a token/fleet hazard").
- 5 unit dalam satu context = 400+ turn. Attempt-loop = context burner sudah pernah diukur
  (research bolt-loop efficiency → v6.1.0 justru memecah, bukan menggabung: findings-only
  returns, pointer dispatch, ledger).

### E3 — Per-unit overhead sudah tipis (saving opsi A ≈ nol)

Biaya per-unit yang tersisa setelah v6.1.0/v7.7–7.8:

- Dispatch = pointer ke file (bukan paste konteks), return = findings-only.
- Preflight/anchor-freshness/symbol-index = **satu call batched per RUN**, bukan per unit
  (`SKILL.md:62-65` — "never loop per unit" tiga kali).
- L0 gates = satu `run-code-gates.sh` call per bolt (2c, terukur 0.637s floor).
- Yang TIDAK bisa hilang di opsi A: review panel + acceptance + pre/postflight tetap per unit
  (hook-guarded artifacts). Jadi yang dihemat cuma 4 spawn implementer — sementara kerugiannya
  E1 + E2.

### E4 — "Relate" sudah punya rumah di data model

- **Modules layer** (`decomposition-rails.md:60`): "Semantic grouping layer ABOVE atomic units
  (units stay atomic; **modules ≠ bigger units**)". Filter `--module=<id>` ada di execute-bolts.
- Unit yang relate via dependency → beda wave (Kahn layering), jalan berurutan by construction.
- Unit satu wave = independen by construction (tanpa edge `depends_on`, target_files disjoint
  via overlap rail).

### E5 — Granularity hulu: threshold ada, knob coarsening TIDAK ada

- `unit-schema.md:276`: "One unit = one PR-sized commit. If the body steps would produce
  **>300 lines** of code change, SPLIT … The >300 LOC / ≤5 files threshold is an **authoring
  judgment (advisory — no validator measures it)**."
- `generate-units/SKILL.md:24`: `--max-complexity=small|medium` — hanya bisa **memperhalus**
  (split anything bigger). Tidak ada arah sebaliknya.
- Konsekuensi: kalau tim merasa 5 unit = satu kesatuan, kemungkinan decomposer memecah terlalu
  halus di bawah 300 LOC — dan tidak ada knob maupun advisory yang menangkapnya. INI gap
  yang nyata.

## Desain usulan (B + C, satu rilis kecil)

### B — knob coarsening

- `generate-units --max-complexity=large` (atau config `unit_granularity: coarse`):
  menaikkan authoring threshold Step 3 (mis. 300→600 LOC, 5→8 files; angka final di-spec
  setelah lihat contoh tim). Unit tetap atomic + PR-sized-contract — cuma "PR"-nya boleh
  lebih gemuk untuk tim yang review-nya per story.
- Bukan default. Default tetap 300 LOC — blast radius review per bolt adalah alasan
  threshold itu ada.

### C — cohesion advisory di lint-units

- Tambah satu cross-unit check (Step 3 lint-units, read-only): cluster `depends_on`-chain
  dalam module yang sama, di mana tiap unit diestimasi kecil (heuristik: body steps sedikit +
  target_files ⊆ 2 file + tanpa Hard rules/PBT) → advisory
  `merge_candidate: U-00X..U-00Z (est. gabungan masih ≤ threshold)`.
- Advisory, never blocking; human yang memutuskan merge (edit units atau re-run
  generate-units dengan knob B). Konsisten dengan doktrin: gates > rules; advisory
  belongs in analyze/lint, not hooks.

### Yang sengaja TIDAK diusulkan

- Mengubah granularity **eksekusi** (opsi A) — E1/E2/E3.
- Auto-merge tanpa konfirmasi — melanggar propose-first (preseden delta lane + moat takeout).

## Gate & next steps

1. Balas tim: sprint scheduling sudah default di 7.7.0 (mereka di 7.6 → update dulu), dan
   minta **contoh nyata 5 unit** yang mereka rasa harusnya satu.
2. Contoh masuk → kalibrasi angka threshold B + heuristik C → spec
   `docs/superpowers/specs/` → gas per cadence.
3. Tanpa contoh, B+C tetap bisa di-spec dengan angka konservatif — tapi measure-first
   lebih sehat (preseden №A size-weighted yang masih di gate).
