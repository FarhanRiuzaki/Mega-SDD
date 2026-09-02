# Research — audit standar code & "optimize tanpa over-engineer" di mega-sdd

**Pertanyaan owner (2026-09-02):** standar code, standar penulisan code, dan gaya yang bikin
kode optimal tanpa over-engineering — udah ada belum di mega-sdd? Harus general lintas stack,
ada rujukannya, POV senior dev.

## Verdict singkat

**SUDAH ADA — tiga lapis, semuanya stack-general, dan bentuknya lebih tajam daripada
style-guide biasa** karena dia operasional (rules di prompt implementer + lensa review +
gate deterministik), bukan dokumen pajangan. Gap yang ketemu tipis; satu polish kecil
opsional. Detail + citation di bawah.

## Lapis 1 — RULES di implementer (stack-agnostic, dibaca setiap bolt)

`agents/bolt-implementer.md`:

- **Build ladder** (step 3, baris 46) — "climb the build ladder — stop at the first rung
  that holds: (1) reuse yang udah ada; (2) standard library over custom code; (3) fitur
  native platform/framework over dependency baru; (4) dependency yang udah terpasang over
  yang baru — never add a dep for what a few lines do; (5) the minimum code that works."
  Plus kalimat kuncinya: **"The ladder shortens the solution, never the reading."**
  → Ini persis "optimize tanpa over-engineer" versi bisa-dieksekusi.
- **Reuse-first protocol** (Iron Rule #4, baris 39) — scan reuse-index penuh, baca
  fungsinya beneran sebelum mutusin, dan nulis ulang TANPA alasan tercatat = bolt ditolak.
- **Self-review** (baris 154) — "Discipline — no overbuilding (YAGNI), only what was
  requested, existing patterns followed."

## Lapis 2 — JUDGMENT di 3 lensa blind (per bolt)

- `code-quality-reviewer.md:20` — **taxonomy over-engineering dengan fix yang ga ambigu**:
  `delete:` (dead/speculative) · `stdlib:` (hand-rolled padahal stdlib punya) · `native:`
  (dep/kode padahal platform udah sedia) · `yagni:` (abstraksi ber-1 caller → inline) ·
  `shrink:` (logika sama, baris lebih dikit). Baris 23: performa wajar buat konteksnya —
  "no obvious N+1s, no needless work in hot paths."
- `spec-reviewer.md:23` — "Extra / unneeded work: did they build things not requested?
  Over-engineer?" — lapisan kedua nangkep gold-plating.
- `standards-reviewer.md` — "reads like it belongs in this codebase": baca 2–3 file
  tetangga dulu, **"the codebase's actual convention beats any abstract rule"**, dan cuma
  menilai yang formatter/linter ga bisa auto-fix.

## Lapis 3 — FLOOR deterministik

- **L0 gates** jalanin formatter/linter/typecheck PROYEK SENDIRI (bukan opini plugin);
  proyek tanpa linter dapat advisory `l0_toolchain_vacuous` (7.13.0) + keputusan manusia.
- **30 framework packs + `_universal.md`** — naming, file location, forbidden patterns,
  testing conventions per stack; `_universal` jadi fallback generic.
- **Reuse symbol index** — biar "reuse dulu" itu ada datanya, bukan himbauan.

## Peta rujukan (canon → tempat dia hidup di mega-sdd)

| Rujukan | Prinsipnya | Di mega-sdd |
|---|---|---|
| Knuth 1974, *Structured Programming with go to* | "Premature optimization is the root of all evil" — TAPI jangan lewatkan the critical 3% | quality lens: N+1/hot-path = finding, micro-opt spekulatif = over-engineering |
| Kent Beck, *4 rules of simple design* + "make it work, make it right" | Lolos test → intensi jelas → no duplication → elemen paling sedikit | build ladder rung 5 + `shrink:` + duplication lens |
| Fowler, *Refactoring* — smell "Speculative Generality" + Rule of Three | Abstraksi nunggu bukti kebutuhan ke-3 | `yagni:` (abstraksi 1-caller → inline) + `delete:` |
| Sandi Metz | "Prefer duplication over the wrong abstraction" | reuse-first BUTUH baca fungsi aslinya dulu, reimplement sah asal alasannya tercatat |
| Go proverbs (Rob Pike) | "A little copying is better than a little dependency" | ladder rung 3–4 (native/installed dep over new dep) |
| Kernighan & Pike, *The Practice of Programming* | Tulis mengikuti gaya kode di sekitarnya | standards-reviewer: surrounding code beats abstract rule |
| Ousterhout, *A Philosophy of Software Design* | Complexity = dependencies + obscurity; modul dalam, interface tipis | single-responsibility lens + `shrink:` |
| McKinley, "Choose Boring Technology" | Inovasi itu budget terbatas | ladder: dep baru = rung TERAKHIR |

Kesimpulan peta: prinsip senior-dev puluhan tahun itu bukan cuma "ada" — dia **di-enforce**
(gate + lensa + rejected-bolt), yang justru lebih kuat dari org yang punya style-guide
panjang tapi ga ada yang baca.

## Gap yang jujur

1. **Premature-optimization tidak eksplisit satu kalimat.** Sisi "jangan biarin N+1" ada;
   sisi kebalikannya (jangan nge-cache / micro-opt tanpa diminta & tanpa ukuran) ketangkep
   TIDAK LANGSUNG via `yagni:` + spec-reviewer "extra work". Polish 1 baris di bullet perf
   quality lens bikin simetris. Kecil, opsional.
2. **Canon tidak ternamai di runtime.** Sengaja DIBIARKAN: nambahin nama Knuth/Fowler di
   body agent = token per dispatch tanpa ngubah perilaku (pajangan). Rumah canon = doc ini.
3. **Tidak ada style-guide umum "ukuran fungsi dst" di `_universal`.** Juga sengaja:
   ground truth-nya kode tetangga + linter proyek — itu sendiri posisi senior-dev
   (konsistensi lokal > aturan global abstrak). Jangan ditambah.

## Usulan

- **Opsi 0 (recommended): tanpa perubahan runtime.** Yang ditanya udah ada dan tajam;
  doc ini jadi record + bahan ngejelasin ke tim/auditor.
- **Opsi 1 (polish 1 baris, kalau mau):** bullet perf `code-quality-reviewer.md:23`
  ditambah kebalikannya — "optimasi spekulatif tanpa pengukuran/permintaan = finding
  `yagni:`" — nutup simetri Knuth (dua arah kutipannya kepakai).

## Amendemen — keputusan "3 lapis" (challenge owner, hari yang sama)

Owner challenge: "3 lapis terlalu berlebihan ga? menurut gue 1–2 cukup." **Keputusan:
DIPERTAHANKAN 3, on the record**, dengan alasan yang bisa diadu ulang kalau ada data baru:

1. Ini 1 corong termurah-dulu, bukan 3 sistem paralel — rules (teks di prompt, biaya ~0)
   → judgment (bullet numpang di lensa yang toh jalan buat duplikasi/test/security —
   hemat pemotongan = NOL subagent) → floor (linter/formatter PROYEK sendiri, 1 script
   call).
2. Bukti terukur bahwa 1 lapis bocor: prose-halt di-bulldoze model di 1/4 run
   (fork-measurement, 2026-07). Rules doang = sistem yang udah kita ukur gagal.
3. Ekonomi hilir: riset bolt-loop ngukur fix-round = context burner termahal; motong hulu
   berarti bayar lebih mahal di panel & gate.

Polish yang di-ship sebagai gantinya (7.21.3, spec 2026-09-02-review-lens-polish.md):
seam kepemilikan scope-vs-form di spec-reviewer ↔ code-quality (satu defect satu pemilik,
anti dobel-lapor) + simetri Knuth di bullet performa (optimasi spekulatif tanpa ukuran =
`yagni:`). Tanpa lapisan/surface baru.
