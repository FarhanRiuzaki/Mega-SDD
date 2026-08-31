# 7.13.0 — L0-vacuous advisory + penutupan ledger doc-audit (№C Kandidat 1 + A3/A4)

**Tanggal:** 2026-08-31 · **Sumber:** triage №C (artifact "Triage №C", memory `team-feedback-triage`), ledger temuan kode OPEN doc-audit 2026-08 (`research/2026-08-23-doc-audit.md` §Temuan), spec 2026-08-30 §3.4 (F-26).
**Keputusan user:** "gas A1-A4 jadi 7.13.0".

Scope release ini: SATU fitur kecil (advisory, bukan gate — human-decision surface), penutupan penuh ledger doc-audit (2 fix kode + 1 fix dok + 3 temuan ditutup-terverifikasi), dan balasan tim. TIDAK ada perubahan gate blocking apa pun.

---

## §1 — A1: advisory `l0_toolchain_vacuous` (run boundary)

**Masalah lapangan (HOST-AS400, audit DD9000 butir 11):** repo hanya punya typecheck — `run-code-gates.sh` mencatat skip *visible* ("no formatter config detected…", "no linter/typechecker config detected…") di setiap l0-results, 36×, dan tidak pernah sekalipun jadi keputusan manusia. Celahnya **eskalasi**, bukan pencatatan.

**Bentuk (advisory, satu kali per run — BUKAN gate):**

1. **`ground.sh`** — blok baru setelah battery C1, sebelum `derive-state.sh`, HANYA saat `.mega-sdd/` sudah ada (doktrin phantom-root: GROUND tidak pernah mint):
   - **Diam** bila `.mega-sdd/l0-toolchain-decision.json` ada (keputusan tercatat = selesai, apa pun isinya).
   - **Diam** bila ada pack proyek `.mega-sdd/packs/*.md` yang memuat `^## Toolchain` (tim sudah menyediakan komando — jalur fix F-14/7.12.0; over-silence lebih aman daripada nag untuk advisory).
   - Jalankan `detect-toolchain.sh --cwd` (detect, never impose; fail-open — deteksi gagal → tidak ada advisory, tidak ada probe palsu).
   - `formatters==[] && linters==[]` → advisory. **Typecheck sendirian tidak menyilenkan** — itu persis kasus lapangan.
   - Tulis `.mega-sdd/.l0-toolchain-probe.json` `{formatters,linters,typecheckers,advisory}` + stempel `plugin_meta` (F-26) — ditulis pada KEDUA hasil (true/false) supaya konsumen selalu baca verdict segar; tidak ditulis sama sekali bila decision file ada.
   - Notice GROUND (relai M/L entry): `[advisory] l0_toolchain_vacuous: …` menyebut ketiga opsi (pasang linter/formatter · `## Toolchain` di pack proyek · catat N/A) — bahasa Indonesia + istilah teknis English.
2. **`execute-bolts` SKILL pre-flight 3.8** — sebelum wave pertama: bila probe `advisory:true` dan decision file absen → `AskUserQuestion` SEKALI (keterangan per opsi, kontrak OQ-keterangan), jawaban ditulis ke `.mega-sdd/l0-toolchain-decision.json` `{"decision":"na|pack-toolchain|linter-planned","by":"user","written_at":…,"plugin_version":…}`. **Tidak pernah memblokir**: user boleh lanjut apa pun jawabannya; run berikutnya diam.

**Rail:** ini human-decision surface (kelas moat — proposal-first), bukan enforcement; enforcement L0 yang sebenarnya tetap di `run-code-gates.sh` dan TIDAK berubah. Advisory tidak menyentuh jalur per-bolt → biaya token per bolt = 0; biaya per run = 1 exec `detect-toolchain.sh` (~1 python spawn).

**Test `tests/audit-hardening/test-l0-vacuous-advisory.sh`:**
- A. repo `.mega-sdd/` + `tsconfig.json` saja → GROUND memuat advisory + probe `advisory:true` ber-stempel `plugin_version` (kasus lapangan persis).
- B. + `biome.json` → advisory hilang, probe `advisory:false`.
- C. + decision file → diam total, probe TIDAK ditulis ulang.
- D. + pack proyek ber-`## Toolchain` (tanpa decision) → diam.
- E. repo tanpa `.mega-sdd/` → tidak ada probe, tidak ada mint (phantom-root).

## §2 — A3: penutupan ledger "temuan kode OPEN" doc-audit 2026-08

Kelima temuan diverifikasi ulang terhadap HEAD hari ini (7.12.0) — tiga sudah tertutup oleh rilis-rilis di antaranya, dua masih hidup:

| # | Temuan | Status hari ini | Aksi 7.13.0 |
|---|---|---|---|
| 1 | `build-prd-core.sh` baca `03-open-questions.md` yang tidak ada di layout mana pun | **TERTUTUP** — ADV-009: fallback `vault.json.open_questions[]` (dua shape) + `vault_md.resolve_doc` dual-layout | catat saja |
| 2 | model-tiers rows 11–14, 18 nol situs dispatch tapi runtime-parsed jadi `catalog_roles` | **SEBAGIAN** — parse-bug fixed 7.6.0; rows mati MASIH di katalog (grep hari ini: nol referensi di seluruh plugin di luar model-tiers.md) | **hapus rows 11–14 + 18** (lihat bawah) |
| 3 | GROUND battery C1 glob `*-bound/` saja — vault kanonik tak ter-scan | **HIDUP** — Guard 2 (`partial_state_corrupt`) & Guard 4 (`verify_unit_writable`) hardcode `.mega-sdd/vaults/*-bound` | **ganti ke `vault_layouts.vault_prefixes()`** |
| 4 | `analyze/SKILL.md` klaim trigger PostToolUse phase-boundary; komentar hook SIX→SEVEN basi | **SEBAGIAN** — komentar hook sudah lenyap di rewrite 7.9.0; kalimat SKILL masih ada dan FALSE (post-tool-use 395 baris: nol trigger phase-boundary/CONSISTENCY) | **hapus kalimat phase-boundary** |
| 5 | `seed-playground.sh` tertangkap filter suite | **TERTUTUP** — discovery CI = `test-*.sh` / `*.test.sh` (kedua tree); `seed-playground.sh` tidak match | catat saja |

**§2b — hapus rows model-tiers 11–14 + 18.** Perubahan perilaku yang disengaja: override `model_tiers:` yang menamai role mati kini memicu notice `model_tier_unknown` (jujur — sebelumnya tervalidasi lalu diam tanpa efek). Ikutan wajib:
- Prosa model-tiers.md yang mencontohkan role mati (baris ±40/49/111/113/122) di-re-key ke role hidup.
- Fixture teaching di-re-key ke role hidup non-panel: `tests/skill-triggering/orchestrate-flow.test.md` (OF-MT2/MT3) dan `tests/scenarios/scenario-11-model-tier-override.md` — pakai `libs-extractor` (sonnet, hidup di deep-scan) dan cerita `implementer` sonnet→opus (row 15 memang menyebut override itu); scope note S7-PANEL-3 (lensa panel frontmatter-pinned) DIPERTAHANKAN.
- `ground.sh` Guard 8 tidak berubah (parse tabel generik).
- Rows 15–17, 19–22 TIDAK disentuh (di luar temuan; 15–17 pola subagent-driven-development, 19–22 panel/routed).

**§2c — Guard 2+4 → `vault_layouts.vault_prefixes()`.** Battery C1 kini melihat kelima layout (kanonik `.mega-sdd/vaults/*`, `docs/mega-sdd/vaults/*`, root/nested `*-bound`) — konsisten dengan validator (S6 EB-VAL-2). Realpath-dedup dipertahankan; heredoc python mendapat `MEGA_SDD_LIB_DIR` (export SEBELUM assignment multi-baris — pelajaran T3). Pin baru: Guard 2 me-rename partial-state korup di vault kanonik TANPA suffix `-bound`.

## §3 — A2: balasan tim №C

`docs/mega-sdd/feedback-response-2026-08-31.md` — pola №B (tabel masukan→verdict, nada terima kasih + angka): 11 artefak (7 tercakup-enforced / 1 N/A / 2 celah nyata dengan jalur fix termurah), scoring engine (peta ke resolve-review-tier + 5 bug desain B1–B5 + 1 ide diambil-untuk-diukur), sintesis derived-not-parallel. Konten = artifact "Triage №C" (URL dicantumkan).

## §4 — A4: stempel provenance sisa = SUDAH DIPUTUS, bukan backlog

Spec 2026-08-30 §3.4 mencatat: file state validator sengaja TIDAK di-stempel ("re-derive tiap gate; bukan blind spot audit"). Entri backlog "state-file provenance stamps" di memory dihapus — tidak ada pekerjaan tersisa. (Probe §1 memakai stempel plugin_meta sesuai pola F-26 untuk artefak baru.)

## Rilis

- Suite penuh dua tree + test baru §1; golden dispatch-parity tidak tersentuh (tidak ada perubahan build-dispatch-prompt).
- `CHANGELOG.md` 7.13.0 · `plugin.json`+`marketplace.json` 7.13.0 · `execute-bolts/SKILL.md` bump minor (pre-flight 3.8) · `analyze/SKILL.md` bump patch.
- Push: user (scm DNS di luar kantor).
