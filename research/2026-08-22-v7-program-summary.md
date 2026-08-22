# Program v7 "Diet" — ringkasan satu halaman (Fase 0–3, SHIPPED)

**Mandat:** plugin mega-sdd jadi ringan + berbobot-sesuai-tugas + tetap grounded — **mekanisme anti-halu boleh dipotong, garansinya tidak pernah.** Semua fase CI hijau, suite penuh kedua tree hijau per commit. Rilis: v7.0.0 (rolling MAJOR).

## Before → After

| Dimensi | Before (v6.20) | After (v7 Fase 0–3) |
|---|---|---|
| **Routing** | semua sesi bayar biaya penuh | **weighted S/M/L**: tier S (bug-hunt/edit biasa) = **0 fork hook** di Edit/Bash/Read; gate penuh hanya saat chain mega-sdd aktif (`engaged_sessions` per-sesi); guard anti-forge tetap **always-on** |
| **session-start** | ±22–26 spawn tiap sesi | **0 spawn** (no-signal) / **8 spawn** (SDD+index); battery C1 pindah ke `ground.sh` (session-start tidak menulis artifact vault) |
| **Hook** | 4.029 baris; handoff ditulis Stop tiap turn | 3.773 baris; handoff = **recompute di gate-time** (satu penulis, `content_sha256` dedup, nol jendela tanpa penjaga), leg Stop dihapus |
| **Script** | 118 file / 36.341 baris | **87 file / 33.259 baris** (DELETE 14+1 py, DEMOTE 3 ke instruksi md, MERGE 10 grup — fold verbatim + parity-proof byte-identical sebelum delete; nama state-file & exit code tak berubah) |
| **Vault** | 7 file md + roll-up OQ duplikat (8 permukaan OQ) | **4 file** (`vault.md`+lock frontmatter / `model.md` / `flows.md` / `constraints.md`) — OQ terpusat **8→2 permukaan** dengan token locality `[origin: file#anchor]`; header `## Overview/Architecture/Decisions` = kontrak keras (derive exit 2 kalau hilang) |
| **Template generate** | 31.072 B (~7,8k tok) | **17.829 B (~4,5k tok) = −42%**; vault klinik fixture −11% (lower bound — 00-index fixture sudah ringkas) |
| **CI** | ~4,2 mnt semua push | push docs-only skip loop suite (manifest-validate tetap), npm cache |
| **Suite** | 239 | 233 (mati bareng script yang dihapus; +3 test layout-2 baru; semua hijau) |

**Migrasi vault existing:** opsional — `migrate-paths.sh --vault-layout` (dry-run default), relokasi verbatim, lalu **full re-bind WAJIB** (line-anchor binding tidak pernah di-patch — regenerate). Semua reader **dual-layout satu minor cycle** (floor kantor v5.9.0). Bukti akhir: e2e blackbox klinik layout-2 sampai units — **CONFLICT gate tetap menyala**, mandat Mermaid tetap menangkap, trace tier-S tidak berubah.

## Keputusan yang DIBALIK oleh bukti (bukan selera — semua tercatat di research/)

1. **Starterkit deep-scan: rencana DELETE → KEEP utuh.** Bukti: blast radius 82 file dan konsumennya hidup — file itu satu-satunya producer `reuse-index.yaml` (sumber graph code layer + reuse-first, dua-duanya mandat) + dispatch builder membacanya live (dibuktikan golden fixture).
2. **№3 build-dispatch-prompt (template prose + `_lib/unit_parse.py`): DIBATALKAN.** Bukti: "±350–500 baris prose statis" riilnya ±170 baris tersebar (sisanya diagnostik/konstanta/interpolasi) — netto ~4% dengan menambah loader + fail-mode baru; "4 kopi parser" riilnya 2 kopi + 2 varian toleransi + 1 desain beda. Cost > benefit = gimmick.
3. **Marker armed: `turn-usage-cursor` → `chain_engaged`.** Bukti: cursor ditulis Stop tiap turn di project ter-adopsi **apapun jenis sesinya** — tidak pernah berarti "sesi ini memang pakai mega-sdd"; AND-`factory-ledger` juga dibuang (lubang greenfield: chain pertama akan un-armed). Hasil: map `engaged_sessions` per-sesi, masuk daftar protected anti-forge.
4. **Residu 00-index: YAML frontmatter → SECTION md verbatim** (kecuali 6 lock scalar yang memang ke frontmatter). Bukti: mentranskode markdown authored sembarang ke YAML = risiko korupsi/fabrikasi, dan grammar `### vN.N` yang dibaca resolve-oq/diff-vault tetap utuh.
5. *(kelas sama, minor)* **`xargs -P` CI: SKIP** — verifikasi menemukan tepat satu suite yang menulis state repo bersama (`test-4abc-spawn-tax` men-touch pack file asli untuk bukti invalidasi cache); loop tetap sekuensial, tidak di-fix paksa.

## Prinsip yang terbukti sepanjang program

- **Gates > rules > hooks** — yang dipotong adalah spawn dan duplikasi, bukan satu pun verdict/blocking gate; gate-time re-derivation membuat scoping aman.
- **Parity-proof sebelum delete** (byte-identical, twin-fixture) — 10 merge, nol regresi kontrak.
- **Ukur dulu, angka terakhir** — tiap klaim penghematan diukur (fork count, byte, suite), dan angka yang jelek dilaporkan apa adanya (−11% fixture = lower bound, bukan dibungkus).
- **Rambu berhenti-lapor bekerja dua arah:** dua item berhenti karena bukti membalik premis (starterkit, №3) — keduanya kembali ke keputusan manusia, bukan diputuskan agent.

**Berikutnya (gate terpisah):** Fase 4 markdown diet — konteks LLM sekarang didominasi skills/references (±2,6 MB md), metrik: token commanded per lane.
