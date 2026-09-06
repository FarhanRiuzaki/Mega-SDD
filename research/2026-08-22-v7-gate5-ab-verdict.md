# Keputusan gate A/B routing (v7.1.0) + lanjut Fase 4 R4

## A. Verdict: default TETAP `inherit`. Tidak ada flip. Kode tetap ship sebagai opt-in.

Hasil A/B gue terima apa adanya — dan ini hasil yang bagus justru karena gagal: kita sekarang tahu bahwa "model lebih murah" ≠ "token lebih sedikit" (model murah butuh lebih banyak iterasi), dan presedens param runtime terjawab untuk ketiga alias. Tiga catatan:

1. **Jangan tarik kesimpulan dari n=3.** Tiga unit, satu per sel, satu seed. Ini pilot metodologi, bukan bukti. Laporkan sebagai itu.
2. **Metrik yang benar memang biaya berbobot harga, bukan raw token** — setuju dengan temuan lo. Gue akan kasih tabel harga gateway kantor (per model, input/output). Begitu ada, hitung ulang arm A/B dalam rupiah/USD dengan angka token yang sama — jangan mengarang harga. Gue ingatkan intuisinya: kalau harga sonnet per token jauh di bawah Fable, +19% token masih bisa jauh lebih murah; tapi opus +36% token dengan 3× wall time hampir pasti rugi dua kali (uang + waktu dev). Kemungkinan besar hasilnya: sel `full→opus` harus dicabut dari router (biarkan `full` = inherit), sel `verify→haiku` dipertahankan, `standard→sonnet` tergantung harga.
3. **Kualitas**: satu edge ke Fable (haiku melewatkan inkonsistensi spec) pada n=1 cukup untuk bilang haiku tidak boleh menyentuh unit non-verify — rubrik lo sudah begitu, pertahankan.

Langkah berikutnya untuk A, tanpa A/B sintetis lagi: **pilot lapangan via telemetry**. `model_used`, attempt count, dan token per bolt sudah tercatat di bolt-report + telemetry. Aktifkan `model_tiers.bolt_implementer: auto` di SATU project kantor yang representatif (gue pilih nanti), kumpulkan n≥10 bolt, lalu hitung biaya berbobot. Keputusan flip/cabut-sel dibuat dari data itu, bukan dari seed klinik. Satu tugas kecil sekarang: tambahkan ke `report-token-cost.sh` kolom `model_used` per bolt dan opsi `--price-table=<yaml>` (input/output per model) supaya hitungan berbobot jadi satu perintah — itu satu-satunya kode baru yang gue izinkan di jalur A, dan hanya kalau muat di script yang ada.

Probe tersisa (interaksi frontmatter custom-agent vs param) masuk backlog; tidak menghalangi apa pun karena `bolt-implementer` tetap `inherit`.

## B. Fase 4 — lanjut R4 sesuai aturan main gate-4

R5 diterima: T01 115,9k / T07 118,8k / T10 50,4k terekam sebagai baseline pre-Fase-4. Keputusan lo menunda R4 karena konteks tinggal 25% itu benar — bedah 45 KB tidak boleh setengah jalan.

Sesi segar, mulai R4:
- Pecah `execute-bolts/SKILL.md` menjadi inti dispatch + refs per mode (`implement`, `verify`, `parallel/squad`, `code-gates`) — unit `verify` tidak boleh memuat squad/parallel/code-gate.
- Ukur T10 before/after per commit; target R4 = bolts-per-unit −5–8k tok. Tidak terukur turun → revert.
- Skill-triggering tests + 7 rail lindung tetap hijau; split tidak boleh menghasilkan dua file yang tetap di-Read bersamaan.
- Lalu R2 → R1 → R3 per urutan gate-4. Berhenti di akhir tiap R dengan angka tracer.

Leg scm: gue push dari VPN kantor.
