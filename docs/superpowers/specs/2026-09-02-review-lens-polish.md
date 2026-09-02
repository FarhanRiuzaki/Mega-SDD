# Spec — review-lens polish: seam kepemilikan + simetri Knuth (7.21.3)

**Konteks:** owner nanya "standar code + optimize tanpa over-engineer udah ada belum?" →
audit `research/2026-09-02-code-taste-standards-audit.md` verdict SUDAH ADA (3 lapis:
rules → judgment → floor). Owner challenge "3 lapis berlebihan ga?" → keputusan on the
record: **3 lapis DIPERTAHANKAN** — bukan 3 sistem paralel tapi 1 corong termurah-dulu;
bukti terukur: prose-halt di-bulldoze 1/4 run (rules doang bocor), bullet judgment nempel
di lensa yang toh jalan (hemat pemotongan = nol), floor = linter proyek sendiri. Polish
yang disetujui = jahitan, bukan lapisan.

## Perubahan (3 baris efektif, 2 file agent)

1. **Seam kepemilikan — satu defect, satu pemilik.** Spec-reviewer dan code-quality lens
   dua-duanya bisa nangkep "kebanyakan bangun" → risiko dobel-lapor yang harus di-dedupe
   controller. Batasnya ditulis eksplisit di KEDUA sisi:
   - `spec-reviewer.md` (bullet Extra/unneeded work) → pemilik **SCOPE**: fitur/behavior/
     surface UTUH yang spec tidak minta. BENTUK dari pekerjaan yang in-scope (abstraksi,
     dep, dead code) = milik quality lens — jangan dilaporkan di sini.
   - `code-quality-reviewer.md` (bullet Over-engineering) → pemilik **FORM**: CARA
     pekerjaan in-scope dibangun (tag delete/stdlib/native/yagni/shrink). Fitur utuh di
     luar spec unit = milik spec lens — jangan dilaporkan di sini.
   Blindness panel tidak berubah — tiap lensa cuma tahu batas dirinya, bukan verdict lensa
   lain.
2. **Simetri Knuth di bullet performa** (`code-quality-reviewer.md`): sisi lama "no obvious
   N+1s / needless work in hot paths" ditambah kebalikannya — **optimasi spekulatif yang
   tidak diminta dan tidak diukur** (caching, micro-tuning, struktur data eksotis di cold
   path) = finding, tag `yagni:`. Dua arah kutipan Knuth 1974 kepakai: pemborosan nyata
   diperbaiki, tuning spekulatif dihapus.
3. **Keputusan arsitektur tercatat** — amendemen di research doc supaya "3 lapis perlu ga
   sih" tidak di-relitigasi tanpa data baru.

## Yang TIDAK berubah

- Tidak ada lapisan/surface/agent baru (ironi "ngerapiin anti-over-engineering dengan
  sistem baru" dihindari sadar).
- Taxonomy tag, panel blindness, tier routing, merge flow — semua utuh.

## Tests — `tests/review-lens-seam/test-review-lens-seam.sh`

A quality lens: seam FORM + larangan lapor scope; B spec lens: seam SCOPE + larangan lapor
form; C simetri Knuth (speculative optimization → `yagni:`); D research doc mencatat
keputusan keep-3-lapis + bukti prose-halt.

## Versions

Agent files tanpa frontmatter version (kontrak plugin-agent). plugin 7.21.2→7.21.3,
marketplace match.
