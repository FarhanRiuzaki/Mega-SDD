Runbook doc-audit v8 (8.0.3)
§1 Tujuan dan dua masalah yang berbeda

Repo sudah pindah dari v7 ke v8 (pipeline fusi, vault layout-3, binding per unit, --lite opt-in, aturan komentar, trailer dua baris). Dokumentasi hampir pasti masih menceritakan plugin yang tidak ada lagi. Ada DUA masalah dengan obat berbeda, jangan dicampur:

Permukaan yang dimuat saat run (skills/, references/, agents/, framework-conventions/). Kalau ini salah, model dibohongi setiap run DAN lo bayar token-nya. Prioritas 1.
Dokumen untuk manusia (README.md root + plugin, CLAUDE.md, tests/scenarios/, docs/). Kalau ini salah, dev baru kantor tersesat. Tidak membebani run. Prioritas 2.

Rekaman sejarah bukan masalah sama sekali, lihat §4.

§2 Permukaan yang diaudit, urut prioritas
#    Permukaan    Perhatian khusus
1    plugins/mega-sdd/skills/**/SKILL.md + references/ di dalamnya    Yang paling mahal. Prosedur yang menyebut fase klasik yang sudah jadi preflight FATAL di lane lite, langkah bind sebagai fase (sekarang JIT per wave), vault 4-file atau 7-file (sekarang layout-3 context.md)
2    plugins/mega-sdd/references/*.md    paths.md (layout-3 + bolts/U-*/binding.json), halt-protocol/halt-families (halt yang sudah tidak ada), reading-map, project-config (parallel_max, key yang masih hidup saja), model-tiers, output-language, upgrade-from-old-version (+ §8.x), gateway-contract.md
3    plugins/mega-sdd/agents/*.md    Iron Rules (6 yang terbaru), trailer DUA baris (bukan 5+), daftar lindung, larangan menebak nilai
4    references/framework-conventions/*.md    §Comment conventions konsisten di semua pack, bukan cuma _universal.md; aturan docblock yang dipersempit ke surface yang dibaca toolchain
5    plugins/mega-sdd/CLAUDE.md + CLAUDE.md root    Kontrak kontributor, ini yang dibaca sesi AI berikutnya, paling berbahaya kalau drift
6    README.md root + plugins/mega-sdd/README.md    Quick start, tabel command (3 verb + 3 one-timer), diagram pipeline (harus pipeline v8), hitungan skill/agent/hook, bagian yang masih menyebut fitur mati
7    tests/scenarios/    Muka untuk dev baru. Per scenario: command masih ada? output yang dijanjikan masih berbentuk itu? Minimal SATU scenario di-replay beneran, bukan cuma dibaca
8    docs/mega-sdd/*, .claude-plugin/plugin.json description, marketplace.json    Pointer masih benar, versi 8.0.3
§3 Metode per file (klaim per klaim, bukan baca-rapikan)
Ekstrak klaim yang bisa diverifikasi: nama command/flag/skill/agent/hook/file/path, angka (jumlah skill, event, file vault, baris trailer), perilaku ("X auto-jalan saat Y"), snippet contoh.
Verifikasi tiap klaim terhadap kode di HEAD (grep/ls/eksekusi kalau murah). Sumber kebenaran = kode, bukan dokumen lain. Dua dokumen yang saling mengutip bisa sama-sama salah.
Perbaiki: klaim salah ditulis ulang sesuai kenyataan; fitur mati dihapus (bukan dicoret); fitur v8 yang belum terdokumentasi diberi rumah di dokumen yang tepat.
Catat per file: jumlah klaim dicek / salah / diperbaiki.

Daftar istilah mati (grep ini di seluruh permukaan runtime, target akhir NOL kecuali di rekaman sejarah dan di dokumen migrasi yang memang menjelaskan jalur lama): vault 7-file, vault 4-file sebagai layout aktif, binding.md / claims-ledger.json sebagai artefak hidup, bind sebagai fase pipeline, telemetry / observability / token-cost / TOKEN-COST-REPORT, memory review, slice-design, advisor, vendored, tree-sitter, run-hook.sh, Hard Rules active: di dalam trailer, trailer 5 baris, seeding_budget, starterkit-metrics.

Catatan: mega-sdd-trace:* bukan istilah mati. Itu kontrak gateway yang sengaja dipertahankan, dokumentasinya di docs/gateway-contract.md.

§4 Gerbang hapus (ini yang menahan pembersihan jadi perusakan)

Sebuah file boleh dihapus hanya kalau LOLOS keempatnya:

Nol konsumen, dibuktikan grep: tidak ada skill/reference/script/test/dokumen yang menunjuknya.
Bukan rekaman sejarah. research/** dan docs/superpowers/specs/** yang bertanggal adalah rekaman, bukan dokumentasi hidup. Tidak dihapus, tidak ditulis ulang. Kalau sebuah spec lama berisiko dibaca sebagai kebenaran sekarang, cukup satu baris stempel di atasnya: > Superseded by 8.0.x, lihat <dok hidup>. CHANGELOG append-only.
Bukan bukti pengukuran. benchmarks/** (termasuk results/**, stream, run.meta, comment-ratio, ship-verdict) adalah basis bukti semua klaim program ini. Tidak dihapus, tidak dirapikan.
Bukan test. Tidak ada test yang dihapus atau dilonggarkan dalam seri ini. Kalau ada test yang menguji fitur mati, itu temuan, laporkan, jangan hapus sendiri.

Yang tidak lolos gerbang tapi memang tidak berada di tempat yang benar: dipindahkan, bukan dihapus, dan pointer-nya diperbaiki. Aturan lama tetap berlaku, taruh sesuai tempatnya.

§5 Ukur, jangan rasakan

Pembersihan tanpa angka tidak bisa dinilai. Jalankan tracer byte-loaded-per-lane sebelum dan sesudah, lane default dan lane lite. Tulis delta-nya di laporan. Kalau sebuah pemangkasan tidak menurunkan byte yang benar-benar dimuat, dia cuma kosmetik, dan itu tidak apa-apa selama jujur disebut kosmetik.

§6 Rambu
Satu commit per permukaan (§2 baris 1 sampai 8), supaya bisa direview terpisah.
Sumber kebenaran = kode di HEAD.
Kalau replay scenario menemukan bug kode (bukan dokumen), berhenti dan lapor. Jangan perbaiki kode di seri dokumen.
Yang tidak bisa diverifikasi ditulis [OPEN], tidak ditebak.
Jangan push leg scm (butuh VPN kantor).
Bump tidak perlu (docs-only), kecuali plugin.json description berubah, itu patch version.
Bahasa laporan: Indonesia + istilah teknis English, angka di mana-mana.
§7 Laporan

research/2026-09-16-doc-audit-v8.md:

Tabel file × klaim dicek × salah × diperbaiki.
Daftar hapus, masing-masing dengan bukti keempat gerbang §4.
Daftar pindah, dari mana ke mana, plus pointer yang ikut diperbaiki.
Hasil grep daftar istilah mati §3, sebelum dan sesudah.
Delta byte per lane §5.
Temuan bug kode (kalau ada) untuk gate berikutnya.
[OPEN].
Satu baris NEXT SESSION.
