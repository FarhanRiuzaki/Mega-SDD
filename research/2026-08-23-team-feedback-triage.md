# Triage feedback tim (Igoo0/feedback-mega-sdd + percobaan Figma slicing) → kerja berikutnya

Konteks penting: feedback diukur di **6.12.0** (cache drift, empat instalasi dormant — dicatat di dokumennya sendiri). Program v7 (7.0.0→7.5.0) sudah menjawab sebagian. Tugas pertama lo: **verifikasi klaim "sudah kejawab" dengan bukti di 7.5.0**, tulis balasan untuk tim, lalu kerjakan yang tersisa. Jangan defensif — dokumen mereka berkualitas (rasio 17.9:1 per unit itu pengukuran yang bagus), dan nuansa mereka sendiri jujur: masalahnya time-to-first-code + fixed overhead, bukan total biaya.

## Peta keluhan → status (verifikasi masing-masing, jangan asumsi)

| Keluhan mereka (6.12.0) | Status dugaan di 7.5.0 | Verifikasi |
|---|---|---|
| 7j45m brief→kode pertama; intent 14,4 mnt/turn | Sebagian kejawab: express spine default, anchor S/M/L, spawn diet 7.5.0, vault 4-file | Ulangi skenario mereka (3 screen statis) di 7.5.0, ukur wall-clock brief→kode pertama. Ini angka yang dibawa ke balasan |
| **Bobot spec tidak menyesuaikan ukuran (17.9:1 di unit 22 baris; 5.8:1 spec:kode; 28 OQ utk 3 screen)** | **BELUM kejawab** — routing v7.1 menskalakan panel+model, TIDAK menskalakan dispatch prompt & kedalaman vault | Kerja baru №A di bawah |
| 12/26 validator SKIP karena pack `_universal` | Sebagian (Fase 5 hapus starterkit-metrics dll.) | Hitung ulang berapa validator SKIP di project universal pack sekarang; yang selalu SKIP di universal → jangan dispatch |
| Surface command tidak reliabel; `/mega-sdd` "NEVER registered"; wrapper resolve ke instalasi 6.6.0 (index [0]) | Sebagian: surface kini 3 verb + 3 one-timer; wrapper installer sudah punya test | **Cek bug index [0] secara spesifik** di `install-front-door.sh`: harus pilih `scope: "user"` dengan versi TERTINGGI, bukan `installed_plugins.json[0]`. Kalau masih ada → fix + test. Ini rekomendasi №2 mereka, murah |
| TOKEN-COST-REPORT kosong; atribusi cost nyasar | Kejawab dengan cara berbeda: **dihapus by design 7.3.0** — cost = AI gateway | Di balasan, jelaskan keputusan ini + tunjuk `docs/gateway-contract.md` |
| Turn 14 menit tanpa artefak antara → terasa freeze | Sebagian (spawn diet) | Cek: apakah tiap phase mencetak progress line/artefak antara? Kalau intent masih satu turn raksasa, pecah jadi step yang masing-masing menulis artefak |

## Kerja baru №A — "spec berbobot ukuran" (temuan terkuat mereka; prioritas 1 mereka = XS/S/M/L profile)

Ini kelanjutan alami S/M/L kita, turun ke level UNIT dan PROJECT. Desain dulu (gate), lalu implement:

1. **Tier unit XS** di `resolve-review-tier.sh` (field baru dari sinyal yang sudah ada: ≤2 target files + estimasi baris kecil + nol sinyal risiko → `unit_tier: xs`). Konsekuensi mekanis di `build-dispatch-prompt.sh`: XS memuat HANYA frontmatter + requirements + hard rules + anchors + acceptance test — tanpa step narrative, tanpa slice yang tidak relevan. Target terukur: rasio instruksi:kode untuk unit kelas U-005 turun dari 17.9:1 ke ≤5:1, dibuktikan dengan replay fixture mereka (minta file spec mereka atau rekonstruksi unit 22-baris serupa).
2. **Skala project di generate-intent**: sinyal ukuran (jumlah screen/flow/entity dari PRD) → `project_scale: xs|s|m|l` di frontmatter vault; XS memangkas ceremony vault (bagian opsional tidak diemisi, bukan diisi placeholder) dan menaikkan ambang auto-resolve OQ tech (28 OQ untuk 3 screen = decision debt; business OQ tetap human-decided — rail anti-halu tidak berubah).
3. **Validator yang selalu SKIP di pack universal tidak di-dispatch** (daftar SKIP-by-construction per pack, dihitung sekali).
Rambu: tidak ada gate anti-halu yang dilonggarkan; XS mengurangi *muatan*, bukan *bukti* (acceptance test tetap wajib dieksekusi).

## Kerja baru №B — balasan untuk tim (satu dokumen, bahasa manusia)

`docs/mega-sdd/feedback-response-<tanggal>.md`: tabel keluhan → status (fixed di vX dengan bukti / planned dengan target / keputusan sadar dengan alasan), ajakan re-test di 7.5.0 dengan skenario yang sama, dan cara update yang benar (sekaligus membereskan drift versi yang mereka alami). Nada: terima kasih + angka, bukan pembelaan.

## Item 2 tim (Figma slicing) — keputusan gue

Kolega lo adalah **pemakai nyata** workflow design→code — persis kondisi yang gue syaratkan saat menghapus slice-design ("extras nanti kalau ada pemakai nyata"). Maka: **buat `mega-sdd-extras` berisi slice-design** di marketplace yang sama, revive dari commit sebelum d4f82c7, per-page (bukan batch 4 page — itu sumber berat/lamanya), dengan catatan pakai koneksi Figma MCP langsung (bukan PNG) begitu akunnya jalan — PNG kehilangan token desain, makanya detailnya melenceng. Plugin extras tidak menyentuh mega-sdd core dan tidak membebani yang tidak memakainya.

## Urutan

№B (balasan, cepat) → verifikasi wrapper bug (fix kecil) → №A desain [GATE] → extras slice-design → baru Fase 6 script-ification (yang kebetulan menyerang akar yang sama dengan keluhan waktu mereka). Semua per aturan main standing: ukur, satu commit per langkah, moat utuh.
