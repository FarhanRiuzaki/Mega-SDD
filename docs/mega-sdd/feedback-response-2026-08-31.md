# Balasan untuk masukan tim: standar 11 artefak /docs + Supervisor scoring engine

Terima kasih — dua-duanya masukan yang serius, dan sebagian besar pertanyaannya bisa dijawab dengan bukti dari run lapangan nyata (HOST-AS400: 36 unit, 85 berkas / 23.428 baris legacy AS/400 → gate React + Bun, dieksekusi penuh oleh pipeline ini). Audit butir-per-butir lengkapnya ada di artifact "Audit Artefak DD9000" dan "Triage №C"; dokumen ini peta ringkasnya.

## Bagian 1 — standar 11 artefak `/docs`

Verdict per butir terhadap hasil run nyata: **7 tercakup setara atau lebih kuat** (dalam bentuk yang berbeda — enforced, bukan pasif), **1 N/A** (events-catalog: arsitektur gate sinkron, tanpa broker — N/A yang tercatat, bukan kelalaian), **2 celah nyata**, **1 tersebar**.

| Artefak kalian | Status di proyek nyata | Catatan |
|---|---|---|
| modules-manifest.json | **Lebih kuat**: `units/` 37 spec + DAG + `target_files` DITEGAKKAN | Observer whitelist menangkap 1 insiden nyata (`git add -A` menyapu berkas tetangga). Manifest pasif hanya mendeskripsikan niat — tidak menangkap insiden |
| openapi.yaml | **Lebih kuat**: 3.445 baris + klien DI-GENERATE darinya + `check:api` bikin build merah saat drift | Kontrak berubah tanpa regenerate = build gagal, bukan integrasi patah saat digabung |
| schema.sql / error-matrix / external-mocks / seed-fixtures / env-matrix | **Tercakup** dalam bentuk kode yang ditegakkan | Trigger PostgreSQL append-only, mock stateful (menemukan kelas bug yang mock JSON statis tidak bisa), env fail-closed saat boot |
| events-catalog.json | **N/A** untuk topologi ini | Standar 11 artefak sebaiknya kondisional per topologi, dengan N/A tercatat |
| **code-standards.json** | **Celah nyata** — repo nol linter/formatter → gerbang lint L0 SKIP di 36 unit | Fix termurah + langsung jalan: pasang biome + isi blok `## Toolchain` di pack proyek `.mega-sdd/packs/` (didukung sejak 7.12.0). Sejak **7.13.0** pipeline juga menyurfakan ini SEKALI di awal run sebagai advisory + pertanyaan keputusan — bukan diam 36× |
| **state-machines.json** | **Celah** — peta transisi ada & presisi, tapi rumahnya kode mock + prosa | Bentuk yang benar bila diadopsi: JSON referensi bercap `[LOCKED]` yang DI-GENERATE DARI kode mock — bukan ditulis paralel (salinan kedua = sumber drift), dan dibaca — bukan ditegakkan — oleh gate (host tetap pemilik aturan domain) |
| system-design.md | **Tersebar** — isi ada di vault + constitution + flows | Paling murah: satu halaman indeks yang MENUNJUK, bukan menyalin |

**Sintesis yang kami pegang:** standar kalian dan pipeline ini saling melengkapi. Bentuk gabungannya = artefak `/docs` yang **digenerate dari** sumber yang ditegakkan (kontrak, fixture, transisi, unit) — bukan ditulis sejajar dengannya. Kalau orchestrator kalian (n8n/LangGraph) benar-benar berdiri dan butuh `modules-manifest.json`, itu script kecil yang derive dari `units/` + `_index.md` — kami build saat konsumennya nyata.

Empat hal yang standar 11 artefak belum punya — dan di run lapangan menangkap defect yang suite hijau (579 pass / 0 fail) tidak lihat sama sekali:

1. **Provenance mundur** — trailer `Unit:` + `SDD-PROVENANCE:` per commit: dari baris kode mana pun bisa mundur ke spec, klaim, dan sumber legacy-nya.
2. **Disiplin OQ** — kesenjangan spec jadi pertanyaan bernomor + berprioritas, tidak pernah tebakan; 50 OQ jujur mengalahkan 5 jawaban karangan.
3. **Tier mutabilitas `[LOCKED]/[INTENT]/[ARTIFACT]`** — bagian mana dari perilaku pihak ketiga yang wajib 1:1, mana yang boleh ditulis ulang (termasuk bug legacy yang TIDAK boleh ikut pindah).
4. **Panel review multi-lensa blind** — menemukan 6 Critical yang tes hijau lewatkan, termasuk urutan tulis yang melanggar batas dual-control pada kode yang lolos tes.

## Bagian 2 — Supervisor complexity-scoring engine (n8n)

Arahnya benar — routing deterministik, bukan self-assessment model. Pipeline ini sudah menjalankan kelas engine yang sama (`resolve-review-tier.sh`): 6 sinyal evidence-based → lensa review per sinyal + `implementer_model` opus/sonnet/haiku per unit. Bedanya: versi kami sudah melewati fase kalibrasi yang formula kalian belum masuki — dan di fase itu kami menemukan predicate yang kelihatan masuk akal ternyata salah routing **30/30 unit** saat direplay ke vault nyata (file-count, fakta UKURAN, menyeret semua unit ke tier penuh). Angka dulu, baru percaya.

Lima hal di formula kalian yang layak dibenahi sebelum dipakai produksi:

1. **Security additive, bukan floor.** `isCoreSecurityOrPayment` cuma +2 → task auth 1 file (skor 3) jatuh ke FAST_TIER junior coder, timeout 3 menit, di kode paling berbahaya. Sinyal security harus jadi floor override, bukan penjumlah.
2. **`p.includes('auth')` false positive** — `author.ts`, `oauth-docs/` ikut ke-flag, dan rename path mengalahkan deteksinya. Pakai evidence: globs pack, sitasi klausul security, vocabulary ter-scope.
3. **`strict_typing_required` = sinyal mati** — konstanta repo yang menggeser SEMUA skor sama rata (ekuivalen menggeser threshold), dan strict typing itu MENURUNKAN risiko, bukan menaikkan kompleksitas.
4. **Threshold 4/8 belum dikalibrasi** — replay formula ke riwayat task yang sudah selesai, bandingkan distribusi tier vs outcome aktual, baru kunci angkanya.
5. **Retry +2 terlalu lambat untuk task kecil** — skor 2 butuh 3× gagal (3× timeout 180 detik) sebelum naik tier. Eskalasi pada kegagalan pertama biasanya lebih murah.

Satu ide kalian yang kami AMBIL untuk diukur: **retry escalation** (naikkan model implementer saat percobaan ulang). Itu axis yang engine kami belum punya; masuk antrean pengukuran run lapangan berikutnya — bukan langsung dibangun, karena kegagalan round-2 bisa karena model kurang kuat ATAU spec/anchor kurang, dan dua penyebab itu obatnya beda.

---

*Bagian dari triage №C (`research/…team-feedback` series). Artifact pendukung: "Audit Artefak DD9000" (butir-per-butir + bukti repo) dan "Triage №C" (verdict + kandidat). Pertanyaan/temuan baru: tulis balik di dokumen masukan kalian.*
