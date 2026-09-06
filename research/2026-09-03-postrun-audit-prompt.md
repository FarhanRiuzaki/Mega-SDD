# Post-run audit — review hasil pipeline mega-sdd di project ini (read-only)

> Paste ke sesi Claude Code **di project tempat pipeline barusan jalan** (bukan di repo mega-sdd). Output-nya jadi masukan pengembangan mega-sdd berikutnya, sekelas feedback Igoo0 tapi lebih dalam karena lo punya akses ke seluruh artefak.

Lo baru menyelesaikan (atau menemani) satu run penuh mega-sdd di project ini: PRD → vault → binding → units → bolts → dokumen. Tugas lo sekarang BERBEDA: jadi **auditor hasil run itu**, bukan developer. Read-only total — jangan perbaiki kode, jangan sentuh vault/binding/units, jangan jalankan skill mega-sdd apa pun. Satu deliverable: `mega-sdd-postrun-audit.md` di root project.

## Cara berpikir (ikuti urutan ini, jangan lompat ke opini)

**1. Rekonstruksi dulu, nilai belakangan.** Sebelum menilai apa pun, bangun peta faktual run ini: daftar semua artefak yang mega-sdd hasilkan (`.mega-sdd/` — vault docs, vault.json, binding, units/U-*.md, bolts/*, dokumen emit, state files) dengan ukuran masing-masing; jumlah unit, bolt, attempt, OQ (open/resolved, business/tech), CONFLICT; baris kode produksi yang benar-benar ditulis vs total baris artefak spec. Tabel ini adalah fondasi — setiap temuan nanti harus menunjuk balik ke sini.

**2. Pisahkan tiga jenis kesalahan — jangan dicampur:**
- **Ketidaksesuaian (grounding failure)**: artefak mega-sdd mengklaim sesuatu yang tidak benar terhadap kode/PRD. Contoh kelas: binding CONFIRMED tapi implementasi berbeda; unit `target_files` menyebut file yang tidak pernah disentuh bolt-nya; DoD flow yang tidak ada acceptance test-nya; sitasi `[src:]` yang menunjuk section PRD yang tidak mengatakan itu; dokumen FSD/SIT yang menyebut perilaku yang tidak ada di kode. **Ini kelas terberat** — mega-sdd ada justru untuk mencegah ini, jadi setiap temuan di sini adalah bug moat, bukan sekadar polish.
- **Over-engineering (proportionality failure)**: artefak benar tapi tidak sebanding. Ukur, jangan rasakan: rasio baris spec : baris kode per unit; artefak yang TIDAK PERNAH dibaca apa pun setelah dibuat (grep konsumennya — file yang nol pembaca = ceremony); OQ yang jawabannya sudah jelas dari PRD (harusnya tidak jadi OQ); unit yang dipecah terlalu kecil/besar; section vault yang diisi padahal project ini tidak punya domainnya; review panel full untuk unit yang nol sinyal risiko.
- **Kesalahan input (bukan salah mega-sdd)**: PRD ambigu, jawaban OQ manusia yang salah, keputusan user saat halt. Tetap catat, tapi di bagian terpisah — supaya feedback ke mega-sdd bersih dari noise.

**3. Setiap temuan wajib berbentuk bukti, bukan kesan.** Format per temuan: (a) klaim satu kalimat; (b) bukti `file:baris` atau angka terukur dari langkah 1; (c) **permukaan mega-sdd mana yang menyebabkannya** — skill/reference/template/validator mana (sebut nama file-nya di plugin kalau tahu, atau deskripsikan perilakunya supaya bisa dilacak); (d) usulan kelas perbaikan: template diperketat / validator baru / validator dilonggarkan / instruksi skill diubah / tidak perlu diperbaiki (one-off). Temuan tanpa (b) dan (c) tidak masuk laporan.

**4. Uji sampel, bukan sensus, untuk yang mahal.** Grounding check penuh untuk SEMUA claim binding itu mahal — ambil sampel terstruktur: semua claim CONFLICT-yang-diresolve + 5 CONFIRMED acak + semua unit yang bolt-nya butuh >1 attempt + 3 unit sekali-lolos. Sebutkan metode sampling di laporan supaya pembaca tahu batas klaimnya.

**5. Hitung juga apa yang BENAR.** Audit yang hanya berisi masalah tidak bisa dipakai kalibrasi. Satu section pendek: gate mana yang terbukti bekerja di run ini (CONFLICT yang tertangkap, acceptance test yang menggagalkan bolt lalu diperbaiki, OQ business yang memang butuh manusia) — dengan bukti yang sama ketatnya. Rasio tangkapan-nyata vs ceremony adalah angka paling berharga untuk keputusan diet berikutnya.

## Struktur laporan

1. **Metadata run** — versi plugin, ukuran project (screen/entity/flow), durasi kasar per fase kalau terlihat dari timestamp artefak.
2. **Peta faktual** (langkah 1) — tabel artefak + angka kunci (spec:kode ratio total dan per-unit terburuk/terbaik).
3. **Temuan ketidaksesuaian** — tabel, severity P1 (moat bolong) / P2 (menyesatkan) / P3 (kosmetik).
4. **Temuan over-engineering** — tabel, tiap baris dengan angka + konsumen-nol atau rasio.
5. **Yang bekerja** — bukti gate yang menangkap masalah nyata.
6. **Bukan salah mega-sdd** — daftar pendek.
7. **Rekomendasi ter-ranking** untuk repo mega-sdd — maksimal 7, masing-masing satu baris + permukaan yang disentuh + effort kasar (S/M/L). Jangan menulis solusi detail — itu kerjanya gate di repo mega-sdd.

## Rambu

- Read-only mutlak. Kalau nemu bug KODE project (bukan artefak), catat di bagian terpisah "bug project, di luar scope" — jangan perbaiki di sesi ini.
- Jangan percaya artefak menilai artefak (bolt-report bilang PASS bukan bukti — cek kodenya). Sumber kebenaran: kode + PRD + git history.
- Kalau ada yang tidak bisa diverifikasi (mis. butuh menjalankan app), tulis UNVERIFIED, jangan ditebak.
- Bahasa laporan: Indonesia + istilah teknis English, angka di mana-mana.

Setelah laporan jadi, berhenti. Pemilik akan membawa laporan ini ke repo mega-sdd sebagai gate masukan.
