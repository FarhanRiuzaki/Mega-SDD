# Addendum untuk amandemen observability + Fase 5: "taruh sesuai tempatnya", bukan buang

Koreksi cara kerja: yang memang milik plugin tetap di plugin; yang **bukan** milik plugin tidak otomatis dibuang — **diverifikasi dulu rumahnya**, lalu dipindah ke sana atau, kalau tidak ada rumah, baru dihapus dengan alasan. Setiap item di daftar potong (observability 7.2.0 dan Fase 5) wajib punya kolom **tujuan** sebelum di-commit.

## Peta rumah (tetapkan sekali, pakai untuk semua item)

| Rumah | Isi | Kriteria |
|---|---|---|
| `plugins/mega-sdd/` | runtime pipeline: skills, agents, hooks, scripts, references yang di-Read saat run, packs | lolos uji pisau v2 (langkah pipeline / gate anti-halu / prasyarat langsung) |
| `benchmarks/` (repo, di luar plugin) | tracer ukuran konteks, harness A/B routing, golden dispatch parity, `measure-duplication.py`, price-table calculator kalau masih berguna untuk riset | alat maintainer; tidak pernah jalan saat dev pakai plugin; tidak ter-install |
| `docs/` (repo) | upgrade/migration guide, fork-recovery map, reading-map, superpowers specs, runbook rollout kantor | dibaca manusia, bukan skill |
| `research/` | temuan, audit, keputusan gate | sudah ada |
| **AI gateway** (di luar repo) | telemetry, token/cost, trace/filter sesi, compaction/usage advisor, governance "sesi mega-code harus pakai mega-sdd" | observability & kebijakan — bukan plugin |
| **Plugin terpisah di marketplace yang sama** (mis. `mega-sdd-extras`) | `slice-design` (UI slicing standalone), `memory` learning lane, `_vendored` superpowers — kalau ada yang masih mau pakai | fitur dev yang sah tapi bukan pipeline; opsional, tidak membebani yang tidak memakainya |
| Hapus | duplikat, mati, atau tidak punya rumah di atas | wajib alasan satu baris |

## Yang harus diverifikasi, bukan diasumsikan (per item, jawab dengan grep/bukti)

1. **Trace tag `mega-sdd-trace:*`** — tanya tim gateway: apakah filter Langfuse/gateway masih mengandalkan tag ini? Kalau ya → tag tetap di plugin sebagai **kontrak gateway** (satu baris, nol biaya), dan catat di `docs/gateway-contract.md` apa yang gateway harapkan dari plugin. Kalau tidak → hapus. Jangan putuskan tanpa jawaban mereka. Sama untuk deteksi governance v6.19.2.
2. **`publish-artifacts.sh`** — verifikasi dengan tim gateway endpoint dan payload yang dipakai; payload telemetry dibuang, payload dokumen tetap.
3. **Dirty journal** — grep: kalau `sync`/`derive-changed-paths` masih membaca → plugin; kalau tidak → hapus.
4. **`report-token-cost.sh --price-table`** — pindah ke `benchmarks/` sebagai alat riset routing kalau A/B lapangan masih mau dihitung dari ekspor gateway; kalau gateway sudah punya hitungan berbobot → hapus.
5. **scan-codebase klasik** — grep konsumen express; bagian yang dipakai (reuse-index, symbol index) tetap di plugin; lane klasik → hapus atau extras.
6. **design-intelligence** — bagian yang dibaca `design-reviewer` tetap; sisanya ikut `slice-design` ke extras atau hapus.
7. **install-deps / Windows PATH repair** — lo yang tahu fleet kantor: dipakai → plugin (dipangkas); tidak → `docs/` sebagai instruksi manual.

## Output gate

Satu tabel: item · konsumen nyata (bukti) · rumah tujuan · tindakan (pindah/hapus/tetap) · pertanyaan terbuka (kalau butuh jawaban tim gateway atau gue). Berhenti di situ; eksekusi setelah gue isi kolom pertanyaan terbuka. Untuk yang dipindah ke `benchmarks/`/`docs/`, pastikan tidak ada path plugin yang masih menunjuk ke sana (zero-phantom) dan tidak ter-package saat `plugin validate`.
