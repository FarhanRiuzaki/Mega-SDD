# 7.19.0 — render-html: back-ke-index + cross-bundle search + lane `emit summary`

**Tanggal:** 2026-08-31 · **Keputusan user (diskusi → gas):** "search nya bisa cross lebih baik, summary langsung sekalian emit summary, satu rilis gas." Basis: spec 2026-08-31-render-html.md + riset §7 (referensi selera DD9000).

## 1. Back ke index (renderer, mekanis)

Mode bundle (`--index`): tiap halaman dapat link `← index` di chrome bar (href RELATIF dari halaman ke `index.html` — tetap jalan offline dari folder mana pun). Mode file tunggal: tidak ada link (tidak ada index). Placeholder template baru `@@INDEXLINK@@`, default kosong — halaman lama tak berubah bentuk.

## 2. Cross-bundle search (renderer, mekanis, offline)

- Saat render bundle, script SEKALIAN menulis `search-index.js` di out_dir: `window.MEGA_SEARCH = [{h(ref), t(itle), l(ens), hd([[id,teks]] h2/h3), x(teks polos)}]` — slug id DIREPLIKASI persis dari algoritma nav template (lowercase → non-word jadi `-` → dedup counter), supaya hasil search bisa lompat `halaman#anchor`.
- **Kotak search hidup di index page saja** (keputusan diskusi): substring AND-match multi-term atas judul+heading+teks; hasil = judul halaman + heading yang match (deep link) + snippet ±60 char. Tanpa library — ~60 baris JS hand-written; naik ke minisearch vendored HANYA kalau lapangan bilang kurang.
- Jujur soal bentuk: bundle memang folder multi-file (halaman saling link); `search-index.js` = satu file sibling lagi. Mode file-tunggal tidak berubah (tetap self-contained, tanpa search).

## 3. Index page = muka bermakna (0 token)

`--index` dengan `<dir>/README.md` ada → index-src = README mentah + section `## Semua dokumen` (daftar link + badge lens). README roll-up KB (ringkasan grounded yang SUDAH ditulis emitter) akhirnya tampil sebagai halaman muka, bukan daftar link kering. Tanpa README → daftar seperti sekarang.

## 4. Lane `emit summary` (AI-authored — di lapisan MD, BUKAN di renderer)

Garis prinsip dari diskusi: AI merangkum SEKALI saat emit (konteks sumber ada), hasilnya artefak md bersitasi yang ke-commit + ke-review; renderer tinggal render. TIDAK PERNAH merangkum saat render (offline mati, token per render, drift tak ter-review).

- `/mega-sdd:emit summary [vault|kb-dir]` — lane keenam di emit command (prosedur di command, pola lane html; promote ke skill penuh kalau lapangan minta). Output `<target>/summary/SUMMARY.md`, lalu auto `render-html.sh` hasilnya.
- **Pola DD9000** (riset §7, selera user 0b1b24fd): section 00 angka utama → flow Mermaid dengan label edge dua sisi → peta modul → temuan → status JUJUR (baris "menunggu"/"butuh keputusan" ikut tampil) → penutup satu kalimat. Tiap section ditutup **satu kalimat takeaway tebal**.
- **Rail anti-halu penuh**: setiap ANGKA dan klaim wajib sitasi artefak nyata (census.json, vault.json, binding.md, `_summary.md`, ledger); sumber tidak ada → tulis jujur "belum ada datanya", JANGAN dikarang; bahasa §Register; Tier-1 verbatim. Doc-control stamp seperti emisi lain.

## Test (extend `tests/render-html/test-render-html.sh`)

J: bundle pages bawa link index (relatif), single-file tidak · K: `search-index.js` tertulis (entries + heading anchors yang slug-nya cocok dengan nav) + index.html bawa kotak search + include · L: README jadi muka index + daftar tetap ada · M: emit command bawa lane summary (row dispatch, mandat sitasi, pola DD9000, auto-render, rail jangan-karang).

## Rilis

CHANGELOG 7.19.0 · manifests · suite penuh dua tree.
