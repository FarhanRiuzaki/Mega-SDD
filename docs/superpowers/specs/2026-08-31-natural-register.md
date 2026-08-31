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
