# "Tanpa ketik /mega-sdd, gate-nya tetap jalan otomatis" — desain, bukan kembali ke auto-invoke

Jawaban singkat: **sebagian sudah begitu, sebagian bisa, dan satu bagian sengaja tidak** — karena itulah yang bikin bug-hunt 20 menit.

## Yang SUDAH otomatis tanpa `/mega-sdd` (v7.0+)

1. **Tier M/L auto-route dari kalimat.** "tambah field NIK di form pendaftaran", "ubah flow approval", "ini PRD baru", "kode berubah, sync" → anchor mengenali keyword → front door → ownership check mekanis → delta lane / chain penuh, satu konfirmasi. Dev tidak pernah perlu mengetik `/mega-sdd`. Kalau di kantor ini tidak terjadi, itu bug keyword census (laporkan kalimat yang gagal, tambah ke census) — bukan perlu fitur baru.
2. **Anti-forge always-on.** Siapa pun/apa pun yang menulis file state/evidence mega-sdd kena deny, di tier apa pun, 0 fork untuk path biasa.
3. **Gate chain saat chain aktif.** Begitu satu skill `mega-sdd:*` jalan (karena auto-route di atas), semua gate arm sendiri (`chain_engaged`) — CONFLICT gate, whitelist, hard rules, panel.

## Yang BISA ditambah murah: tier S "sadar vault", bukan "masuk pipeline"

Masalahnya: dev fix bug inline di file yang terikat claim LOCKED/binding, lalu kontraknya geser tanpa ada yang tahu sampai sync berikutnya. Solusi yang tidak mengembalikan pajak 20 menit:

- **Notice pasca-edit, 0 fork, tidak memblokir.** PostToolUse pada `Write|Edit` di tier S: cek path terhadap `.locked-files-index.json` pakai bash builtin (substring match di file yang sudah ada — tanpa python, tanpa jq). Match → satu baris ke model: `mega-sdd: <file> terikat ke claim <id> (<verdict>). Kalau kontrak/skema berubah → /mega-sdd:sync; kalau hanya bug fix internal → lanjut.` Tidak match → hening. Model tetap bebas; dev tetap cepat; tapi drift tidak diam-diam.
- **Acceptance test milik unit ikut jalan kalau file-nya disentuh** (opsional, config `auto_verify_on_edit: true`): kalau file yang di-edit ada di `target_files` sebuah unit yang punya `acceptance_test`, tawarkan satu baris "jalankan acceptance U-012? (ya/tidak)". Ini gate paling berharga (bukti eksekusi) dengan biaya satu pertanyaan, bukan satu chain.
- **Sync ditawarkan saat dev bilang selesai** ("udah", "commit", "push", "PR") di project dengan change_signal → satu baris tawaran, bukan auto-run. Kalimat-kalimat itu masuk census sebagai *trigger tawaran*, bukan trigger invoke.

## Yang SENGAJA TIDAK dilakukan

Auto-invoke pipeline dari keberadaan `.mega-sdd/` atau dari setiap prompt — itu persis klausa :13(c) yang dihapus di Fase 1, dengan bukti 20 menit per bug hunt. "Otomatis" yang benar = router mengenali *niat* (M/L) dan gate menjaga *artefak* (anti-forge, chain armed); bukan memaksa semua prompt lewat chain.

## Eksekusi (kecil, setelah Fase 5; bisa digabung ke Fase 7 karena menyentuh PostToolUse)

Satu commit: notice pasca-edit pure-shell (pin 0 fork di tier S) + census kalimat "selesai" sebagai tawaran + opsi `auto_verify_on_edit`. Test: edit file LOCKED di tier S → satu baris notice, nol deny, nol python; edit file biasa → hening. Dokumentasi satu paragraf di README "apa yang otomatis, apa yang tidak".
