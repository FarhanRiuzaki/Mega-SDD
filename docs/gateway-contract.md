# Gateway contract — apa yang gateway kantor harapkan dari plugin mega-sdd

**Status: KONTRAK (v7.3.1, keputusan pemilik plugin 2026-08-23 — `research/2026-08-23-v7-gate7b-trace-restore.md`).** Tim AI gateway memfilter sesi mega-sdd pada keluarga tag `mega-sdd-trace:*`. Tag ini adalah **satu-satunya artefak observability yang plugin hasilkan; semua hitungan token / biaya / sesi ada di gateway.** Tidak ada telemetry.jsonl, marker hook, cost report, advisor, atau deteksi governance di sisi plugin (semuanya dihapus di v7.3.0 dan TIDAK kembali).

## Daftar tag

| Tag | Format (verbatim, satu token per baris) | Muncul di | Emitter |
|---|---|---|---|
| `mega-sdd-trace:turn` | baris tunggal | Satu kali per user prompt, HANYA di project ter-adopsi (ada `.mega-sdd/`); CWD non-SDD = hening total | `hooks/user-prompt-submit` (pure shell, nol spawn) |
| `mega-sdd-trace:<skill>` | akhir announce line skill, dalam backtick | Setiap kali sebuah skill mega-sdd mulai (13 skill ber-announce) | announce line tiap `skills/*/SKILL.md` |
| `mega-sdd-trace:<skill>` / `mega-sdd-trace:execute-bolts:<unit-id>` | baris tunggal di dalam prompt dispatch | Setiap prompt subagent (bolt implementer, lens panel, verifier, deep-scan extractor, wave extractor) — subagent berjalan fresh-context sehingga tanpa baris ini tidak terlihat filter gateway | `scripts/build-dispatch-prompt.sh` (T1 + `inline_core`), controller (lens/verifier), template deep-scan/wave |

## Aturan

- Satu token, verbatim, tanpa varian; filter gateway: `contains "mega-sdd-trace"`, prefix-match untuk breakdown per fase/unit.
- Tag TIDAK punya opt-out config — statusnya kontrak, bukan preferensi.
- `mega-sdd-trace:session` (marker per-sesi lama) dan deteksi governance v6.19.2 ("sesi mega-code wajib mega-sdd") TIDAK dikembalikan — deteksi sesi sepenuhnya urusan gateway memakai tag di atas.
- `publish-artifacts.sh` (Stop hook) tetap mengirim dokumen pipeline ke gateway dengan manifest `plugin_version` — itu output pipeline, bukan observability, dan bukan bagian dari kontrak tag ini.

Pin test: `tests/surface/test-p9-audit-phase1.sh` (kelengkapan announce + template), `tests/derived-artifacts/test-dispatch-prompt-builder-shape.sh` + `plugins/mega-sdd/tests/moat/test-dispatch-prompt-cascade.sh` (tag di prompt/inline_core), `tests/weighted-routing/test-tier-s-hooks.sh` (echo turn = 0 fork; non-SDD hening).
