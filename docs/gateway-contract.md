# Gateway contract — apa yang gateway kantor harapkan dari plugin mega-sdd

**Status: KONTRAK (v7.3.1, keputusan pemilik plugin 2026-08-23 — `research/2026-08-23-v7-gate7b-trace-restore.md`).** Tim AI gateway memfilter sesi mega-sdd pada keluarga tag `mega-sdd-trace:*`. Tag ini adalah **satu-satunya artefak observability yang plugin hasilkan; semua hitungan token / biaya / sesi ada di gateway.** Tidak ada telemetry.jsonl, marker hook, cost report, advisor, atau deteksi governance di sisi plugin (semuanya dihapus di v7.3.0 dan TIDAK kembali).

## Daftar tag

| Tag | Format (verbatim, satu token per baris) | Muncul di | Emitter |
|---|---|---|---|
| `mega-sdd-trace:turn` | **baris PERTAMA**, verbatim | Satu kali per user prompt, HANYA di project ter-adopsi (ada `.mega-sdd/`); CWD non-SDD = hening total. Sejak v7.5.0 №G hook yang sama BOLEH menambahkan satu baris kedua (tawaran sync dari census kalimat "selesai" — pure shell, nol spawn); filter gateway tetap key pada baris pertama | `hooks/user-prompt-submit` (pure shell, nol spawn) |
| `mega-sdd-trace:<skill>` | akhir announce line skill, dalam backtick | Setiap kali sebuah skill mega-sdd mulai (13 skill ber-announce) | announce line tiap `skills/*/SKILL.md` |
| `mega-sdd-trace:<skill>` / `mega-sdd-trace:execute-bolts:<unit-id>` | baris tunggal di dalam prompt dispatch | Setiap prompt subagent (bolt implementer, lens panel, verifier, deep-scan extractor, wave extractor) — subagent berjalan fresh-context sehingga tanpa baris ini tidak terlihat filter gateway | `scripts/build-dispatch-prompt.sh` (T1 + `inline_core`), controller (lens/verifier), template deep-scan/wave |

## Aturan

- Satu token, verbatim, tanpa varian; filter gateway: `contains "mega-sdd-trace"`, prefix-match untuk breakdown per fase/unit. Baris tambahan NON-tag (mis. tawaran sync №G) tidak pernah memakai prefix `mega-sdd-trace` — namespace tag tetap eksklusif.
- Tag TIDAK punya opt-out config — statusnya kontrak, bukan preferensi.
- `mega-sdd-trace:session` (marker per-sesi lama) dan deteksi governance v6.19.2 ("sesi mega-code wajib mega-sdd") TIDAK dikembalikan — deteksi sesi sepenuhnya urusan gateway memakai tag di atas.
- `publish-artifacts.sh` (Stop hook) tetap mengirim dokumen pipeline ke gateway dengan manifest `plugin_version` — itu output pipeline, bukan observability, dan bukan bagian dari kontrak tag ini.

## Baris kedua census (№G, v7.5.0)

Baris kedua dari `hooks/user-prompt-submit` hanya muncul kalau DUA kondisi terpenuhi sekaligus: (a) `.mega-sdd/codebase/.dirty-paths.jsonl` tidak kosong, DAN (b) prompt user match set keyword census pada word boundary — Udah/Sudah/Selesai/Beres/Kelar/Commit/Push/Merge[d]/Done/PR. Teks baris kedua, verbatim:

```
mega-sdd: user menyiratkan pekerjaan selesai dan ada perubahan kode ter-journal — TAWARKAN /mega-sdd:sync dalam SATU baris (jangan auto-invoke; kalau user menolak, lanjut tanpa mengungkit lagi).
```

Baris ini TIDAK memakai prefix `mega-sdd-trace` (namespace tag eksklusif; filter gateway tetap key pada baris pertama).

## Publisher (Stop hook)

- **Gate publish:** leg publisher di Stop hook jalan hanya kalau `.mega-sdd/vaults/` ada ATAU `.mega-sdd/graph.json` ada — vault sentinel `_codebase` meng-cover project tahap scan (belum ber-vault, sudah ber-graph/codemap).
- **Field manifest** (`manifest.json`, entry root PERTAMA di tar.gz): `{schema: "mega-sdd-publish/1", project_id (git remote ter-normalisasi — kredensial/userinfo dibuang, port ssh dibuang, `.git` dipotong; tanpa remote → `local/<work_dir>`), vault, git_head, generated_at, files (map path→sha256), graph_meta, work_dir (basename saja), plugin_version}`.
- **Perilaku:** fail-open by contract (kegagalan network/kredensial exit 0, tidak pernah blokir pipeline) + sha-self-debounce via `.mega-sdd/.publish-state.json` (hanya file yang sha-nya berubah yang dikirim; manifest selalu FULL, gateway self-heal via respons `{"missing":[...]}`).

Pin test: `tests/surface/test-p9-audit-phase1.sh` (kelengkapan announce + template), `tests/derived-artifacts/test-dispatch-prompt-builder-shape.sh` + `plugins/mega-sdd/tests/moat/test-dispatch-prompt-cascade.sh` (tag di prompt/inline_core), `tests/weighted-routing/test-tier-s-hooks.sh` (echo turn = 0 fork; non-SDD hening).
