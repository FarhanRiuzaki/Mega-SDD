# Per-unit model routing + cascade — desain (GATE, belum implement)

**Status:** PROPOSED — berhenti di gate, nol perubahan kode.
**Sumber:** `research/2026-08-22-smart-routing-research.md` (§4 rekomendasi, §6 prompt) + tambahan gate: verifikasi empiris param model, perluas `resolve-review-tier.sh` (bukan script baru), rail A5 tetap, nol persona/agent baru/perubahan gate.

## 0. Verifikasi empiris (dilakukan 2026-08-22, bukan asumsi docs)

Satu dispatch dummy `Agent(subagent_type: general-purpose, model: "haiku")` di build Claude Code sesi ini: **diterima tanpa error skema, dan agent yang lahir melapor system prompt-nya sendiri: "Haiku 4.5, `claude-haiku-4-5-20251001`"** — parameter `model` saat spawn EKSIS dan benar-benar mengganti model. Catatan batas: (a) terbukti untuk build INI (macOS, CC terbaru); build kantor (floor plugin v5.9.0, versi CC tak diketahui) belum diprobe — probe 1-baris yang sama masuk runbook rollout; (b) `subagent_type: fork` mengabaikan override (didokumentasikan harness) — tidak relevan, bolt dispatch bukan fork; (c) presedens frontmatter `model:` agent vs param runtime BELUM terdokumentasi — arm A/B memverifikasi live via `model_used` (lihat §3).

**Konsekuensi desain:** jalur utama = param runtime. **Varian agent file (lite/heavy) TIDAK dibangun sekarang** — itu fallback terdokumentasi yang baru dibuat KALAU sebuah build lapangan terbukti tanpa param (no-gimmick: jangan bikin surface mati duluan).

## 1. Router — perluas `resolve-review-tier.sh` (field tambahan, script yang sama)

Output sekarang `{tier, signals_fired, signals_evaluated, target_files, task_type}`. Tambah dua field TURUNAN dari sinyal yang SAMA (rail A5 utuh — nol input baru, nol penilaian model):

```
implementer_model:
  "opus"   ← tier == full  (>=1 sinyal risiko: auth_globs/manifest/file_count/
             vocabulary/constitution_b/risk_field)
  "haiku"  ← tier == minimal DAN task_type == "verify"
             (rubrik haiku katalog: unit tulis-kode hampir tidak pernah cocok)
  "sonnet" ← selain itu (minimal non-verify, standard, parse_note apapun —
             unknown tidak pernah turun tier, doktrin yang sama dengan panel)
effort:
  "low"    ← implementer_model haiku
  "high"   ← selain itu   (xhigh dicadangkan; TIDAK ada mekanisme per-dispatch
             effort di Agent tool build ini — field ini DICATAT untuk telemetry
             + masa depan, tidak dikonsumsi runtime sekarang; jujur di output)
```

Kunci JSON **aditif** — konsumen existing (`tests/express-default/test-p3-oq-defer-risk-router.sh`, execute-bolts caller) membaca kunci bernama, tapi pin exact-JSON di test harus dicek saat implementasi. Override chain TIDAK berubah dan tetap di CALLER: `--model-tier=<haiku|sonnet|opus>` (flag baru execute-bolts, diplumbing front door — pelajaran standing) > `config.yaml model_tiers.bolt_implementer:` > auto.

**Amendemen tercatat:** `references/model-tiers.md` row 22 hari ini MEMBELA `inherit` ("operator-tiered, hard pin salah dua arah"). Desain ini menggantinya dengan pin per-unit **berbasis bukti sinyal** — bukan hard pin satu arah yang dikritik row itu; rasional row 22 di-amend, bukan dilanggar diam-diam. `inherit` tetap tersedia via `--model-tier=inherit` (arm A A/B memakainya).

## 2. Cascade eskalasi — sinyal = gate yang sudah ada

Aturan mekanis (bukan penilaian model): **kalau unit gagal 2× berturut di tier N pada sinyal kualitas yang SUDAH dipercaya** — acceptance red (B4), L0 gate merah, atau fix-round panel dengan P1 finding — **attempt berikutnya dinaikkan satu tier** (haiku→sonnet→opus), maksimal SATU eskalasi per unit, `--no-escalate` mematikan. Hitungan attempt dibaca dari ledger attempt-loop yang sudah ada (v6.1.0 verifier rounds + findings ledger) — controller execute-bolts membaca angka, tidak menilai. Dicatat di bolt-report: `model_used` (disalin VERBATIM dari baris "You are powered by..." system prompt implementer — bukti deterministik, bukan self-assessment), `signals_fired`, `escalated_from` (kalau ada). Turun-tier otomatis TIDAK ada (asimetri disengaja: eskalasi dibayar bukti gagal; de-eskalasi tanpa bukti = judi kualitas).

## 3. Rencana A/B — `sample-prd-clinic.md`, gate ship

End-to-end intent→bind→units→bolts di project seed klinik (playground disposable), sesi interaktif (caveat headless standing):
- **Arm A (baseline):** `bolt-implementer` `inherit` — perilaku hari ini.
- **Arm B:** router §1 + cascade §2, config default.
- **Metrik** (telemetry yang sudah ada — `report-token-cost.sh` + marker per-subagent): token total per arm, jumlah attempt per unit, P1 findings panel, wall time; plus `model_used` per bolt (verifikasi presedens param-vs-frontmatter, §0c).
- **Kriteria SHIP (keputusan user di gate berikut):** hemat token **≥25%** DAN kualitas panel setara (P1 findings arm B ≤ arm A; acceptance pass rate sama). Gagal salah satu → tidak ship, hasil tetap dipublikasikan.

## 4. File yang disentuh (saat implementasi, nanti)

| File | Perubahan |
|---|---|
| `scripts/resolve-review-tier.sh` | +`implementer_model` +`effort` (turunan; ~20 baris) |
| `skills/execute-bolts/SKILL.md` + `references/review-panel.md` + refs dispatch | baca 2 field router, pass `model:` di Agent call, aturan cascade, flag `--model-tier=`/`--no-escalate` |
| `commands/mega-sdd.md` (front door) | plumbing 2 flag baru (pelajaran standing v6.18) |
| `references/model-tiers.md` | amend row 22 + tabel routing implementer + override chain |
| `agents/bolt-implementer.md` | frontmatter `model: inherit` TETAP (param runtime yang menang saat dipass; fallback natural saat tidak) + instruksi salin `model_used` ke bolt-report |
| `skills/execute-bolts/references/bolt-report schema` | +`model_used`/`escalated_from` |
| `.mega-sdd/config.yaml` contract | +`model_tiers.bolt_implementer:` +`parallel_max:` (default 4 — cap `--parallel`; default CC 20 subagent × bolt 80-turn = ledakan token di fleet Windows) |
| Tests | test router fields (extend suite p3/rvt), pin bolt-report fields, pin front-door plumbing; TANPA test varian agent (tidak dibangun) |

## 5. Risiko

1. **Presedens param vs frontmatter tak terdokumentasi** — mitigasi: `model_used` verbatim di bolt-report + arm A/B memverifikasi; kalau frontmatter menang, fallback varian file diaktifkan (template tunggal, parity-pinned) — keputusan kecil terpisah.
2. **Build kantor tanpa param `model`** — probe 1-baris di runbook rollout; sebelum terbukti, kantor tetap `inherit` (nol regresi).
3. **Haiku menulis kode buruk** → rubrik membatasinya ke `verify` saja; cascade menaikkan dengan bukti; A/B mengukur.
4. **Gateway kantor (mega-code)** — alias model harus resolve di gateway; kalau tidak, `model_tiers:` config per-project menetralkan.
5. **Kunci JSON aditif mematahkan pin exact** — dicek saat implementasi (pin di-update ke kontrak baru, bukan dilonggarkan).
6. **Escalation menambah attempt mahal** — dibatasi 1×/unit + `--no-escalate`; A/B menghitung attempt.

**Tidak dilakukan (per gate):** persona prompt; agent baru selain (kelak, kalau perlu) varian implementer; perubahan gate anti-halu apa pun; router di hook; classifier ML; swarm role-based.
