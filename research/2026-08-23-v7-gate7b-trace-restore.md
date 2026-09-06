# Koreksi v7.3.0: kembalikan `mega-sdd-trace:*` sebagai marker filter gateway

Keputusan pemilik plugin (2026-08-23): tag `mega-sdd-trace:<skill>` / `mega-sdd-trace:turn` **dikembalikan** — tim gateway memakainya untuk memfilter sesi mega-sdd. Ini satu-satunya pengecualian dari "observability dihapus total", dan statusnya **kontrak gateway**, bukan observability plugin.

## Bentuk yang dikembalikan (minimal, nol biaya)

- Echo `mega-sdd-trace:turn` per prompt di project ter-adopsi — di hook yang masih ada (UserPromptSubmit sudah dihapus → pilih cara termurah yang tetap pure-shell, nol python, tidak mengembalikan transcript scan atau advisor apa pun; kalau harus menghidupkan kembali UserPromptSubmit, isinya HANYA echo tag dengan short-circuit non-SDD).
- Announce line tiap skill diakhiri `` `mega-sdd-trace:<skill>` ``; dispatch prompt subagent memuat satu baris `mega-sdd-trace:<skill>` (fresh-context subagent tidak terlihat gateway tanpa ini).
- Goldens dispatch-parity di-regen (delta = baris tag saja, seperti saat dihapus).
- Tidak ada yang lain ikut kembali: tidak ada telemetry.jsonl, marker hook, cost, advisor, governance v6.19.2 (deteksi sesi tetap urusan gateway — tag ini yang mereka pakai).

## Dokumentasi

`docs/gateway-contract.md` (baru, pendek): apa yang gateway harapkan dari plugin — daftar tag, format, di mana muncul — dan kalimat eksplisit "satu-satunya artefak observability yang plugin hasilkan; semua hitungan token/biaya/sesi ada di gateway". CLAUDE.md + README satu baris merujuk ke sana. Test pin: tag ada di announce line + dispatch prompt (assertion positif menggantikan assertion negatif yang dibuat di 7.3.0).

Satu commit, bump 7.3.1, CI hijau. Lalu lanjut Fase 5 sesuai `2026-08-23-v7-gate7-accept-730.md`.
