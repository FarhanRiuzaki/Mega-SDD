# GATE Fase 0 — keputusan

Approve audit dengan keputusan di bawah. Commit Fase 0 (`research/2026-08-21-v7-diet-audit.md`) dulu, lalu lanjut ke **desain** Fase 1 (gate lagi sebelum implementasi). Urutan tetap: Fase 1 routing dulu, baru Fase 2 diet — karena audit lo sendiri bilang penghematan terbesar untuk dev ada di routing + hook scoping, bukan jumlah file.

## 1. §6.2–6.4 — APPROVED

- **DELETE 16 script + `seeding_budget.py`**: approve semua. Ikuti sweep per item di §6.2, KEDUA test tree + `.github/workflows`, zero-phantom grep sesudahnya.
- **DEMOTE 3**: approve. Relocate-then-delete.
- **MERGE 10 grup**: approve, dengan 2 syarat keras: (a) nama state-file yang dibaca aggregator PreToolUse dan `run_family` run-analyze tidak berubah, atau diupdate dalam commit yang sama; (b) merge satu grup per commit, test hijau per commit — jangan gabung 10 grup dalam satu commit.
- **Python 10/12 KEEP**: gue terima bukti lo. Sikap default "hapus" dicabut untuk `_lib`. Jangan merge modul kecil.
- **`build-dispatch-prompt.sh`**: tidak di-demote. Lakukan yang lo usulkan: ±350–500L prose statis keluar jadi file template markdown yang dibaca script. Ekstraksi parser bersama (`_lib/unit_parse.py` dari 4 kopi yaml_lite) boleh, ter-gate dispatch parity harness.

## 2. Tier B — keputusan

| Item | Keputusan |
|---|---|
| Telemetry token-cost | **KEEP kurus**: satu report (`report-token-cost.sh` via analyze), hapus marker hook yang tidak dibaca report itu. |
| `validate-vault-flow-staging.sh` | **KEEP**, fix header rot "Branch 14". |
| Memory side lane | **DEFER** — jangan hapus dan jangan sentuh di v7 kecuali ada rung hook yang jalan tiap turn; kalau ada, rung-nya yang dikurus. Penghapusan lane utuh diputuskan setelah v7 stabil. |
| `analyze-parallelism.sh` | **KEEP** (dikonsumsi `execute-bolts --all --parallel`). |
| Producer starterkit (`deep-scan-dispatch.md` + `starterkit-context-schema.md`) | **HAPUS** bersama 2 validator-nya. Koordinasi scan-codebase dalam commit yang sama. |
| Handoff-validation via Stop | **Pindahkan derivasi ke gate-time** (pola S4/S5/S6) di Fase 1. Setelah itu Stop boleh dikurus di Fase 2. Tidak boleh di-demote ke advisory. |

## 3. Hooks — approve split §3.2/§6.5 + tambahan

Approve "safe split": guard anti-forge Write/Edit path-scoped + Bash-tamper untuk path state mega-sdd tetap always-on; **GateGuard LOCKED-check, fan-out validator PostToolUse, dan Bash-tamper greps non-state-path di-scope ke chain aktif**. Marker: `factory-ledger.json` presence AND `.turn-usage-cursor-<sid>` (sesi ini memang pakai mega-sdd) — dua-duanya sudah ada, tidak ada mekanisme baru. Kalau salah satu tidak ada → tier S, gate lewat.

Tambahan wajib Fase 1/2 (semuanya dari temuan lo sendiri): short-circuit non-mega-sdd di Stop dan SubagentStop; transcript scan di UserPromptSubmit di-cut (atau debounce ke tiap N prompt); rotasi `hook-debug.log`; collapse bash staleness fallback session-start ke `derive-state.sh`; rung hook milik validator yang dihapus ikut hilang.

## 4. Arahan desain Fase 1 (bawa ke gate berikutnya)

Tier gate harus **mekanisme**, bukan kalimat — setuju. Konkretnya yang gue mau lihat di desain:

1. **Anchor `using-mega-sdd`**: hapus klausa :13(c) "CWD shows SDD signals" sebagai *trigger invoke*. Keberadaan `.mega-sdd/` hanya boleh jadi sinyal **status** (satu baris notice), bukan alasan untuk STOP dan invoke skill. Tulis ulang :25 Hard rule agar hanya berlaku untuk tier M/L. Hapus/lunakkan :59 ("after ANY out-of-pipeline change → sync") jadi: sync *ditawarkan* di entry M/L berikutnya, bukan diwajibkan setelah hotfix. Hapus kalimat "MANDATORY development workflow" di session-start :119-125 dan tabel red-flags :86-89 yang mempermalukan kerja inline. Description frontmatter :4 tidak boleh lagi berakhir "…or the CWD shows .mega-sdd/ signals".
2. **Tabel keputusan S/M/L** di anchor: S = default; M hanya kalau prompt menyebut entity/flow vault **dan** meminta perubahan spec/fitur; L hanya artifact arg / `/mega-sdd` eksplisit / epic baru. Override: `--weight=S|M|L`.
3. **Dirty journal**: boleh tetap mencatat (murah, jujur), tapi `change_signal` tidak boleh memicu proposal sync otomatis di session-start untuk tier S; cukup satu baris notice, dan sync baru diusulkan ketika user masuk lane M/L.
4. **Bukti**: ulangi trace §4 secara statis untuk desain baru — tunjukkan langkah mana yang hilang dan angka token/spawn after vs before (§4.3). Target: tier S = ±anchor saja (<1k tok), nol script selain session-start, nol PreToolUse block pada Edit/Write/Bash.

## 5. Vault (catatan untuk gate Fase 3, jangan dikerjakan sekarang)

Gue terima Amendemen 2 (residu 00-index pindah ke head `vault.md`, 6 lock values jadi YAML frontmatter). Amendemen 1: gue condong **4 file** (`vault.md` / `model.md` / `flows.md` / `constraints.md`) karena alasan hot-path lo masuk akal — tapi putuskan final di gate Fase 3 dengan contoh dari `sample-prd-clinic.md`. Migrasi via `migrate-paths` + full re-bind wajib, dual-layout read satu minor cycle.

Lanjut: commit Fase 0, lalu desain Fase 1.
