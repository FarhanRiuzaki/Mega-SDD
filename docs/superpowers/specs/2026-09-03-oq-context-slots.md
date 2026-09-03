# Spec — OQ context slots + keterangan rekomendasi (7.22.0)

**Lanjutan langsung dari 7.21.1 (human framing).** Owner review lapangan ronde 2:
"sekarang udah oke cuma masih kurang konteksnya" + "rekomendasi answernya kasih konteks
yang jelas juga". Diskusi 2026-09-03, owner gas semua slot.

## A — Step 2a display: dari 2 slot jadi 6 (rumah kanonik tetap interactive-walk.md)

Template framing per OQ (semua mode ikut — vault walk, KB mode, express-batched):

```
Konteks:            situasi bisnis + posisi di alur (flow F-*/step/aktor) bila ada
Yang udah ketahuan: fakta dari kode — meaning-first, citation di kurung
Yang belum:         gap persisnya (kalimat "belum ketahuan dari kode")
Kenapa penting:     P-level dijelasin — apa yang ke-blok / salah kalau ga dijawab
Contoh:             SATU skenario konkret NETRAL (opsional — lihat rail)
Maksudnya:          keputusan / aturan / informasi yang diminta dari user
── detail teknis ── (doc, teks asli verbatim, hint — tidak berubah)
```

Rails (semua mandatory):
1. **Contoh netral** — mengilustrasikan PERTANYAANNYA, tidak boleh menyiratkan jawaban;
   hanya boleh diturunkan dari flow/kode/citation yang ada. Tidak derivable → slot
   di-SKIP jujur, tidak pernah dikarang (no-invention berlaku di framing).
2. **Bounded** — framing ≤ ~7 baris; slot tanpa data di-skip, bukan diisi paksa.
3. Rail 7.21.1 tetap: translate-never-rewrite, no invented facts, meaning-first evidence.

## B — Keterangan rekomendasi (recommendation-context.md)

Deskripsi slot `[1]` (recommended) WAJIB berbentuk 4 bagian, bahasa sehari-hari:

```
<jawaban singkat plain-language> — dasar: <bukti meaning-first (citation)>.
Kalau dipilih: <apa yang berubah / di mana jawaban landing>.
Kalau ternyata salah: <fallback 1 kalimat>.
```

Bukan invariant baru — ini BENTUK dari invariant 1/2/3 yang sudah ada (citation, rationale,
fallback) + disclosure destinasi yang SKILL sudah wajibkan; yang baru cuma: urutannya
dipaku, bahasanya human-first, dan konsekuensi-jika-dipilih eksplisit.

## Yang TIDAK berubah

Prompt tetap SATU AskUserQuestion per OQ (slot & Other & Esc utuh); artifact tidak pernah
di-rewrite dari display; derive contract & vault.json tidak tersentuh.

## Tests — extend `tests/resolve-oq-kb/` §H

H1 6 slot di template Step 2a; H2 rail contoh-netral + skip-jujur; H3 bounded ≤7 baris;
H4 bentuk 4-bagian keterangan rekomendasi; H5 SKILL Step 2 mengarahkan ke shape baru.

## Versions

resolve-oq 2.13.0→2.14.0 · plugin 7.21.3→7.22.0 (marketplace match).
