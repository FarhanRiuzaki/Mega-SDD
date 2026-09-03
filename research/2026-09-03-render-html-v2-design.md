# render-html v2 — desain ulang output HTML (research)

**Tanggal:** 2026-09-03 · **Status:** PROPOSED ronde 2 — arah final "developer platform", nunggu gate user
**Pemicu:** feedback user — output render-html sekarang "kuno dan AI slop", kurang interaktif. Minta research desain yang sesuai kebutuhan.
**Scope:** `assets/render-html/template.html` + init mermaid di dalamnya. `render-html.sh` (pipeline deteksi lens, strip, search, index) TIDAK berubah — ini murni layer presentasi.

## 1. Diagnosis — kenapa v1 kebaca "AI slop"

Grounded dari render sample PRD-kontrak (screenshot `v1-current-full.png`, template 7.16.0–7.19.0):

1. **Mermaid theme default** — penyumbang ~70% kesan slop. Kotak lavender/ungu bawaan, spacing default boros (flowchart 9 node makan satu layar penuh), font diagram beda dari font dokumen. Ini persis tampilan yang orang asosiasikan dengan "AI generate diagram".
2. **Tipografi tanpa identitas** — system font untuk semua peran, abu-abu di atas putih, kontras hierarchy lemah. Kebaca kaya markdown render generik.
3. **Card-itis** — semua elemen dibungkus kotak putih + border + shadow tipis (stat strip, diagram, tabel). Pola template dashboard 2023.
4. **Nol interaksi** — diagram statis (ga bisa zoom/pan, diagram gede ga kebaca), tabel ga bisa sort, TOC ga tahu posisi scroll, ga ada theme toggle (cuma ikut OS), ga ada copy button.

## 2. Rujukan

- **Mermaid theming**: satu-satunya theme yang bisa di-custom penuh = `theme: "base"` + `themeVariables` (hex only; `primaryBorderColor` dkk diturunkan otomatis dari `primaryColor`). Spacing: `flowchart.nodeSpacing`/`rankSpacing`, `sequence.actorMargin`. Site-wide via `mermaid.initialize`. ([mermaid.js.org/config/theming](https://mermaid.js.org/config/theming.html))
- **Arah desain dok 2026**: typography-first (layout dibangun dari perilaku teks, bukan sebaliknya), satu keluarga font utama + satu sekunder dipakai dengan intent, content-first — visual mendukung alur baca, bukan bersaing ([Fontfabric 2026](https://www.fontfabric.com/blog/10-design-trends-shaping-the-visual-typographic-landscape-in-2026/), [Fluid Topics](https://www.fluidtopics.com/blog/industry-insights/technical-documentation-trends-2026/)). Benchmark kualitas developer-docs: Mintlify/Stripe-class — tipografi bersih, dark mode serius, komponen interaktif secukupnya.
- **Selera user yang sudah terbukti** (artifact Peta Mega-SDD + presentation reference): Zilla Slab display + Public Sans + JetBrains Mono, palet green-biased, angka-dulu, garis editorial bukan kartu, status jujur.

## 3. Arah desain v2 — "Berkas"

Bahasa visual: **berkas kerja editorial** — kertas hangat, tinta pekat, aksen hijau, tipografi slab untuk judul. Bukan dashboard, bukan kartu-kartuan.

| Elemen | v1 | v2 |
|---|---|---|
| Judul/heading | system sans | **Zilla Slab** (vendored woff2) + nomor bagian mono hijau |
| Body / mono | system | Public Sans / JetBrains Mono (vendored) |
| Mermaid | theme default (ungu) | `theme: base` + `themeVariables` dari token halaman; `nodeSpacing 34 / rankSpacing 38`; font ikut dokumen; **render setelah `document.fonts.ready`** (kalau ngga, label kepotong — kejadian di mockup) |
| Stat strip | tile kartu putih | band editorial bergaris (angka Zilla Slab tabular, label mono caps; angka warning merah kalau CONFLICT/OQ > 0) |
| Tier rows | bullet + badge kecil | baris ledger (badge — isi — sitasi mono kanan) |
| OQ | list item polos | kartu ber-aksen kiri sesuai P-level + chip P1/P2/P3 + status ○ OPEN / ● RESOLVED (derive dari `[ ]`/`[x]`) |
| Diagram | pre polos di kartu | **kartu ber-toolbar**: zoom ±, fit, fullscreen; wheel = zoom, drag = pan; auto-fit awal ke box; caption derivable ("9 node · 8 edge") |
| Kartu diagram gede | tinggi bebas (satu diagram = satu layar) | max-height + auto-fit → halaman padat, detail via zoom/fullscreen |

## 4. Katalog interaktivitas (semua offline, vanilla JS, no lib)

Genuinely useful — bukan gimmick (tiap item lolos "buys vs cost"):

1. **Diagram zoom/pan/fullscreen** — diagram flow gede sekarang ga kebaca sama sekali; ini kebutuhan №1 tim.
2. **Scrollspy TOC** (IntersectionObserver) — dokumen PRD-kontrak panjang, orang perlu tahu posisi.
3. **Theme toggle** light/dark/system, persist `localStorage` — kantor banyak yang light, dev banyak yang dark.
4. **Table sort** (click header) — tabel binding/aturan bisnis puluhan baris.
5. **Copy button** di code block — kontrak data sering di-paste.
6. **Print CSS** — bank tetap nge-print (SEOJK); nav/toolbar hilang, diagram full.
7. Search cross-bundle 7.19.0 — SUDAH ADA, dipertahankan apa adanya.

Ditolak (gimmick untuk konteks ini): kinetic typography/animasi hover, minimap, komentar/anotasi client-side (state ga ke mana-mana), diagram editor.

## 5. Constraint yang TIDAK berubah (moat fitur)

- **Offline by construction** — zero external request. Font vendored woff2 di `assets/render-html/` (Zilla Slab 2 weight + Public Sans 2 + JetBrains Mono 1, subset latin ≈ 100–180KB total — kecil dibanding mermaid.min.js yang sudah ~2.6MB inline). Fallback stack system font tetap dipasang.
- **Deterministik, zero model token** — template statis diisi `render-html.sh`; TIDAK ada konten yang di-author model per render. Caption diagram pun derivable (hitung node/edge), bukan karangan.
- **md = ground truth** — semua fitur v2 murni presentasi; teks tidak ditulis ulang.
- Kontrak `render-html.sh` (lens, strip, warnbar, search-index, slug nav = replika Python↔JS) tidak disentuh — hanya markup/CSS/JS template.

## 6. Bukti visual

- `v1-current-full.png` vs `v2-mockup-full2.png` (scratchpad `render-v2/`) — sample PRD-kontrak yang sama, template beda. Mockup v2 fungsional: zoom/pan/fullscreen, scrollspy, theme toggle, sort, copy jalan semua.
- Pelajaran teknis dari mockup: (a) mermaid **wajib** nunggu `document.fonts.ready` sebelum `run()` — font custom ke-load setelah mermaid ngukur teks → label kepotong; (b) `useMaxWidth:false` + auto-fit scale = diagram padat dan utuh; (c) re-render mermaid saat theme toggle (simpan source asli, reset `data-processed`).

## 7. Ronde 2 — brief user: premium developer platform (ARAH FINAL)

User menilai arah "Berkas" (§3) masih kurang dan memberi brief eksplisit: **Mintlify × Stripe × Vercel × Linear** — enterprise-grade, modern, premium, information-dense tapi tidak overwhelming; BUKAN Bootstrap docs / old-school enterprise portal / "AI-generated SaaS". Arah §3 di-supersede; yang dipertahankan dari ronde 1: mermaid `theme: base` + tokens, zoom/pan/fullscreen, auto-fit, scrollspy, theme toggle, sort, copy, print CSS, dan semua pelajaran teknis §6.

Terjemahan brief ke render-html (mockup fungsional: `v3-mockup.html`, screenshot light + dark):

- **Tipografi**: sans modern (Inter, vendored woff2 saat ship) — BUKAN slab serif display; H1 34px/-.025em, hierarchy dari weight+size, konten tetap fokus visual.
- **Layout 3 zona**: kiri = nav bundle (grup collapsible per lens: Knowledge Base / Binding / Units / Keputusan, active state + badge count OQ/CONFLICT per halaman — data dari `search-index.js` yang SUDAH dibangun render-time); tengah = breadcrumb + lens chip + konten; kanan = "Di halaman ini" sticky + scrollspy. Single-file render (tanpa `--index`): kolom kiri di-omit, TOC kanan tetap.
- **Navigasi**: breadcrumb (path derivable dari struktur bundle), prev/next dari urutan index, **⌘K/Ctrl-K search modal** (re-use `search-index.js` 7.19.0 — UI-nya naik kelas, datanya sama), active state, semua offline.
- **Sistem komponen** (semantic tokens, tidak ada nilai hardcode di komponen): callout (info/warn/danger — audience line & OQ intro jadi callout), stat band restrained, tier rows ledger, tabel sortable, code block first-class (language tab + line number + copy + syntax highlight ringan), OQ card + P-chip + status dot, prev/next card, breadcrumb, TOC.
- **Warna**: netral tinggi kontras + SATU accent (hijau brand #0d7d55 / dark #3fbf8b); shadow nyaris nol; border halus; radius kecil (5–10px). Mermaid ikut netral: node = surface + border netral, accent hanya untuk emphasis — diagram berhenti "keliatan AI".
- **Warna per kotak diagram** (permintaan user ronde 3 — "masing2 kotak warnanya bedain biar enak dibaca"): post-process SVG inline setelah `mermaid.run()`, warna dari **peran yang dihitung deterministik** — flowchart: start (indegree 0) hijau · decision `{…}` biru · end-state (outdegree 0) amber · proses netral (topologi diparse dari source mermaid, bracket di-strip dulu); sequence: tiap participant satu warna (palet 3 soft, cycle by index, baris atas–bawah konsisten). TIDAK PERNAH tebak dari keyword konten (bahasa-dependent + fragile) — peran topologis saja, tetap zero model token. Node id di-match via `flowchart-<id>-<n>`, actor via `rect.actor` (+ fallback selector antar versi mermaid); re-color tiap re-render tema.
- **Legend per diagram** (permintaan user ronde 4): dirender di footer kartu, item HANYA untuk peran/participant yang beneran ada di diagram itu (flowchart: swatch start/keputusan/end-state/proses yang muncul; sequence: nama participant + swatch-nya). **Pelajaran (g): warna aktor sequence WAJIB di-map dari label teks aktor, bukan urutan DOM** — urutan render mermaid ≠ urutan `participant` (kejadian: legend bilang Web UI hijau, kotaknya amber; diverifikasi DOM mermaid me-render aktor terbalik). Label match ke daftar `participant X as <nama>`; fallback index-cycle kalau label tak ketemu.
- **Interaksi**: cepat & restrained — hover nav, active indicator, copy feedback, collapse grup, smooth anchor; TANPA animasi spektakel.
- **Responsive**: 3 kolom → tablet 2 (TOC hilang) → mobile 1 kolom (sidebar jadi drawer — perlu dibangun; mockup baru sampai hide).
- **Syntax highlighting**: keputusan gate — vendor highlight.js core+subset (~90–120KB) vs tokenizer mini sendiri (regex kelas kata kunci, cukup untuk cuplikan kontrak 1–5 baris). Rekomendasi: tokenizer mini dulu (zero dep baru), upgrade kalau kurang.

Pelajaran teknis tambahan ronde 2 (kejadian di mockup, wajib masuk implementasi):
- (d) **re-fit wajib reset transform dulu** — `getBoundingClientRect` ikut transform; tanpa reset, ganti tema bikin diagram makin ciut (compounding).
- (e) dark mode flowchart: set `darkMode` + `textColor`/`mainBkg`/`nodeBorder` di themeVariables DAN pasang override CSS halaman untuk `.nodeLabel`/`.edgeLabel` (SVG inline, CSS halaman tembus) — label htmlLabels diverifikasi `rgb(240,240,238)` di node `rgb(24,26,24)`.
- (f) mermaid re-render saat toggle: simpan source asli, reset `data-processed`, re-`initialize` dengan tokens tema aktif.

## 8. Keputusan yang dibawa ke gate

1. **Go/no-go template v2 arah "developer platform"** (§7; §3 di-supersede).
2. **Font vendored** Inter + JetBrains Mono (~100–150KB, sekali saja di mode `--assets-dir`) vs system-font-only. Rekomendasi: vendored.
3. **Syntax highlight**: tokenizer mini (rekomendasi) vs vendor highlight.js.
4. Cakupan rilis: satu rilis minor — template v2 + mermaid theming + JS interaksi + nav bundle 3-zona; `render-html.sh` hanya nambah data nav/prev-next ke template (lens & search-index sudah ada); test pin `tests/render-html/`.
