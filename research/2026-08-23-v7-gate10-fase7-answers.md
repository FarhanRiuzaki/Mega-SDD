# Jawaban 4 pertanyaan gate Fase 7 → GO implementasi (7.5.0)

Audit diterima. Temuan dispatcher itu kelas terbaik dari program ini: "tier S 0 fork" ternyata mengukur body, bukan jalur produksi — 4 proses per event × Falcon = 0,88 s untuk no-op. Ini juga pelajaran standing: **pin harus mengukur jalur produksi, bukan fungsi yang dipanggil langsung** — tulis itu di research note.

## Jawaban

1. **starterkit-metrics → HAPUS** validator + leg. State file tanpa pembaca absolut = uji pisau gagal; halt-nya sudah hidup dari rekomputasi in-skill. Evidence-flip №15 dicatat sebagai koreksi Fase 5.
2. **Opsi B 0-python armed → AMBIL**, dengan dua syarat: (a) **fail-closed** — builtin tidak bisa membaca/parse `.locked-files-index.json` → jatuh ke jalur python penuh, jangan pernah lolos diam-diam; (b) mutation-proof S12 diperluas: file LOCKED di-edit saat armed → tetap DENY lewat fast-path builtin, dibuktikan dengan spawn counter 0 python. Dan benar: ini infrastruktur yang sama dengan notice pasca-edit Bagian 2 — satu implementasi dua konsumen, bangun sekali.
3. **Matcher PostToolUse → `Write|Edit` → KONFIRMASI.**
4. **Urutan §11 + bump 7.5.0 → KONFIRMASI**, dispatch langsung duluan. **Satu rambu untuk langkah ini:** `run-hook.sh` dulu lahir sebagai "Windows cmd.exe-safe dispatch" (v4.37.0, normalisasi backslash `$0`). Dispatch langsung dari `hooks.json` harus membawa normalisasi itu inline (atau membuktikan tidak lagi perlu di Claude Code sekarang), dan **diverifikasi sekali di satu laptop kantor Windows/Git Bash sebelum di-tag** — jangan sampai win 4→1 proses menukar bug path Windows yang dulu sudah dibayar mahal. Kalau verifikasi Windows belum bisa hari ini, ship di belakang satu commit terpisah yang gampang di-revert.

## Ikut di seri yang sama

- Fix phantom `session-start:153` ("vendored fallback") dan test S11 hampa (subagent-stop yang sudah tidak ada) — dua-duanya temuan bonus audit.
- Fan-out Write → **0 python** (bukan 1) sesuai bukti census: 12 state gate-read di-recompute di gate, 4 advisory tanpa pembaca ditutup dengan memasukkan dispatch-nya ke re-run FULL analyze.
- Bagian 2 auto-aware ikut serial ini (notice LOCKED 0-fork, census kalimat "selesai" sebagai tawaran, `auto_verify_on_edit` opt-in default false, verifikasi 10 kalimat kantor).

## Penutup Fase 7

Laporan: tabel spawn before/after per event (terukur), proyeksi wall-time Windows, hasil verifikasi satu laptop kantor (dispatch langsung + sesi chain nyata — target ≤20 s di 30–40 call, ~30 s di 60 call diterima sebagai lantai sampai ada keputusan binary), moat test hijau, bump 7.5.0. Lalu berhenti — Fase 6 script-ification gate berikutnya.
