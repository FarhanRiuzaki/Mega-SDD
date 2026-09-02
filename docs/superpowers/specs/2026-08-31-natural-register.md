# 7.17.0 — Register natural untuk semua prosa Indonesia hasil generate

**Tanggal:** 2026-08-31 · **Sumber:** feedback tim (№C-3) via owner: "semua yang di-generate mega-sdd bahasa Indonesianya terlalu kaku dan baku — pengen yang natural, flawless, dan mix indo-english di setiap domain/pipeline hasil generate." Memperluas mandat [natural-mixed-language] 2026-08-31 (sebelumnya baru chat + string template renderer) ke SEMUA prosa Indonesia yang plugin hasilkan.

## Diagnosis

Ini masalah **register** (gaya), bukan pilihan bahasa — kontrak bahasa (`references/output-language.md`, 12 skill route ke sana) sudah benar soal KAPAN Indonesia dipakai; yang salah adalah BAGAIMANA Indonesianya ditulis: bahasa dokumen resmi / terjemahan harfiah ("melakukan proses validasi terhadap", "dipergunakan", "adapun"), bukan bahasa kerja engineer.

## Bentuk (satu pintu, blast radius kecil)

1. **`references/output-language.md` +§Register** — rumah kanonik yang semua surface sudah baca:
   - Prosa Indonesia Tier-2/Tier-3 = **Indonesia kerja natural + istilah teknis English apa adanya**; kalimat aktif-langsung; kata upacara dibuang. Tabel ❌→✅ sebagai teacher (contoh > aturan).
   - **Flawless ≠ gaul**: tetap gramatikal + profesional; "lo/gue" = register chat user, bukan artefak tim.
   - **Carve-out regulator**: bagian dokumen yang menghadap regulator (emit-uat berita acara SEOJK, bagian formalnya) TETAP baku — regulator memang mengharapkan baku; di luar itu natural.
   - Tier-1 (enum/verdict/ID/path) tak tersentuh; "vault ikut bahasa input" tak berubah — register berlaku SAAT menulis Indonesia.
2. **Anchor session-start** — baris output-language di anchor ditambah "natural, tidak kaku" supaya register hidup sejak turn pertama (anchor = satu-satunya rule yang selalu ter-load).
3. **Test** — `tests/output-language/test-output-language.sh` +pin: §Register ada, ≥4 pasang ❌→✅, klausul flawless-bukan-gaul, carve-out regulator, baris anchor.

## Ditunda tercatat

Sweep contoh-contoh prosa kaku di template/teacher individual (vault templates, prd-kontrak-template) — dilakukan bertahap saat template tersebut tersentuh; §Register kanonik sudah mengikat outputnya lebih dulu, dan run lapangan revamp acquisition jadi ukuran apakah sweep teacher masih perlu.

## Amendemen 7.21.2 — kalibrasi ronde 2: bookish-halus juga kaku (2026-09-02)

Owner menegur ke-4 kalinya, kali ini di artefak platform map yang copy-nya SUDAH mengikuti
§Register versi awal: "bahasa yang lo kasih terlalu kaku, tidak natural ini gue mention
berkali2". Temuan: §Register ronde 1 nangkep register birokrasi ("melakukan proses validasi
terhadap") tapi TIDAK nangkep kelas bookish-halus — kalimat gramatikal + puitis yang tetap
terasa dokumen: *hanyalah, menyebut, menimbang, meninggalkan, menemui, sepatah kata pun*.

Fix (satu pintu tetap output-language.md):
1. Tabel §Register +3 baris ronde 2 ("setiap klaim menyebut sumbernya" → "tiap klaim ada
   sumbernya"; "hanyalah otomasi…" → "cuma otomasi…"; "memahami tanpa mengarang" → "paham
   dulu, jangan ngarang").
2. Rambu baru **bookish-halus juga kaku** + tes praktis: bacakan ke rekan kerja — kalau lo
   ga akan ngomong begitu, tulis ulang.
3. Rail lama utuh: Flawless ≠ gaul (lo/gue tetap register chat), carve-out regulator tetap,
   Tier-1 tak tersentuh.

Pin: tests/output-language ≥6 pasang + rambu ronde 2. plugin 7.21.1→7.21.2.
