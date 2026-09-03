# Spec — render-html template v2 "developer platform" (7.23.0)

**Riset:** `research/2026-09-03-render-html-v2-design.md` (4 ronde owner review + mockup
fungsional `v3-mockup.html`, screenshot light+dark diverifikasi). Owner gas 2026-09-03:
"gas spec + implement render-html v2" — termasuk rekomendasi font vendored + tokenizer mini.

**Pemicu:** owner — output v1 "kuno dan AI slop", kurang interaktif; brief eksplisit:
Mintlify × Stripe × Vercel × Linear, BUKAN Bootstrap/old-enterprise/"AI-generated SaaS".

## Yang TIDAK berubah (moat fitur)

- Offline by construction: zero external request (pin A3/F3 tetap).
- Deterministik zero-model-token: template statis diisi `render-html.sh`; tidak ada
  konten yang di-author model per render; caption/legend/warna = derivable.
- md = ground truth; frontmatter stripped; `</script>` escape; sha256 + provenance footer.
- Kontrak script: lens detection, summary strip, budget advisory, slug replica
  Python↔JS (search deep-link), README index face, `--assets-dir`, exit codes.

## A — Template v2 (assets/render-html/template.html, rewrite)

1. **Tokens semantic** terpusat di `:root` (light) + dark via `@media prefers-dark
   :root:not([data-theme=light])` + `[data-theme=dark]` — pola 3-state; toggle di topbar
   persist `localStorage` (try/catch), re-render mermaid saat ganti (simpan source asli,
   reset `data-processed`).
2. **Tipografi**: Inter (400/600/700) + JetBrains Mono (400) vendored woff2; fallback
   stack system font selalu terpasang. Inline mode: `@font-face` data-URI; `--assets-dir`:
   file di `assets/fonts/`, url relatif.
3. **Layout 3 zona**: kiri nav bundle (bundle mode saja — dibangun client-side dari
   `window.MEGA_SEARCH`, digrup per label lens, active = `MEGA_SELF`, grup collapsible);
   tengah breadcrumb + lens chip + konten + prev/next; kanan "Di halaman ini" sticky +
   scrollspy (h2/h3 + diagram). Single-file: kolom kiri disembunyikan, sisanya tetap.
4. **Komponen**: audience → callout; stat strip di-restyle (angka warn merah saat label
   `open questions`/`conflict` > 0); budget warning → callout warn (class `warnbar` +
   string "Budget diagram" dipertahankan untuk pin D2); baris `[LOCKED]`-list → ledger
   rows; OQ line `- [ ] OQ-… [P1] …` → kartu OQ (chip P-level, status ○ OPEN/● Resolved —
   post-process display, md tidak berubah); code block + copy + tokenizer-mini highlight
   (keyword/string/comment/number, zero dependency); tabel sortable (klik header).
5. **Diagram card**: toolbar (zoom ± / fit / fullscreen), wheel-zoom + drag-pan,
   auto-fit awal, caption derivable ("N node · M edge"), max-height + fullscreen overlay.
6. **Mermaid**: `theme: "base"` + `themeVariables` dari token halaman; `nodeSpacing/
   rankSpacing` rapat; `useMaxWidth:false`; **render setelah `document.fonts.ready`**;
   override CSS `.nodeLabel/.edgeLabel` (SVG inline). **Warna per PERAN deterministik**
   (bukan keyword konten): flowchart start(hijau)/decision(biru)/end(amber)/proses(netral)
   dari topologi source (bracket-strip → in/out-degree); sequence per-participant, warna
   **di-map dari label teks aktor** (urutan DOM mermaid ≠ urutan participant — terukur).
   **Legend** di footer kartu: item hanya peran/participant yang ada.
7. **⌘K / Ctrl-K search modal** di SEMUA halaman: bundle = `MEGA_SEARCH` (halaman +
   heading deep-link, data & slug 7.19.0 tidak berubah); single-file = heading halaman
   ini. Pin lama "search hanya di index" di-REPIN sadar (superseded oleh modal global).
8. Print CSS (nav/toolbar/modal hilang, diagram full); responsive 3→2→1 kolom.

## B — render-html.sh (patch kecil, pipeline tidak berubah)

1. Bundle mode: per halaman inject `<script src="{rel}search-index.js">` +
   `window.MEGA_SELF="{href}"` (placeholder `@@NAVDATA@@`), prev/next dari urutan listing
   (`@@PREVNEXT@@`), breadcrumb rel (`@@CRUMB@@`). Single-file: ketiganya kosong.
2. `SEARCH_JS` blob + searchbox HTML dihapus dari script — UI pindah ke template;
   `search-index.js` (data) tetap ditulis script, shape tidak berubah.
3. Stat strip: class `warn` saat label ∈ {open questions, conflict} dan n > 0.
4. `assets_for` ketambahan lane font (inline data-URI vs copy + url relatif).

## C — Tests (`tests/render-html/`)

Pin lama dipertahankan kecuali K4 (repin dengan alasan: ⌘K global). Pin baru: fonts
offline (tanpa http), token 3-state, mermaid base+themeVariables+fonts.ready, role-color +
label-match + legend fns, ⌘K modal di halaman konten, NAVDATA/PREVNEXT di bundle +
kosong di single-file, tokenizer-mini ada, strip warn class.

## Versions

plugin 7.22.1 → 7.23.0 (marketplace match). Script + assets — tidak ada skill version.
MCP pin review tidak tersentuh (marked/mermaid TIDAK di-bump — hanya template).

## Amendemen (7.23.1) — diagram gede & error handling (temuan owner, hari rilis)

Temuan lapangan: (a) diagram error → "ga muncul" — batch `mermaid.run({nodes: dgs})`
throw pada SATU diagram rusak dan MEMBUNUH semua post-processing (warna/legend/auto-fit
tidak jalan; terverifikasi `transform: none` di semua kartu); (b) diagram gede jadi
"kecil2 sekali" — auto-fit min(lebar, tinggi) tanpa lantai men-scale hingga tak terbaca;
(c) initial view diagram lebar nampilin TENGAH alur (origin 50%), bukan awalnya.

Fix (template-only):
1. **Render per diagram, terisolasi** — loop `mermaid.run({nodes:[p]})` + try/catch;
   gagal → pre disembunyikan (bomb svg mermaid ikut hilang) dan kartu menampilkan
   **panel error jujur** `.dg-err`: pesan parse mermaid + source diagram (details, open)
   + caption "render error — benerin di file md". Diagram lain tetap dirender penuh.
   Sukses tanpa `<svg>` juga dihitung gagal.
2. **Fit floor 0.5** — auto-fit tidak pernah di bawah 0.5 (keterbacaan > muat-utuh);
   sisanya urusan pan/wheel-zoom/fullscreen. Fullscreen toggle kini re-fit ke box besar.
3. **Anchor kiri saat overflow** — masih overflow setelah floor → `justify-content:
   flex-start` + `transform-origin: 0 0`: initial view = AWAL alur.

Tests: `tests/render-html/` §O (5 pin). Versions: plugin 7.23.0 → 7.23.1.

## Amendemen 2 (7.23.2) — field run mcf-fincore: state diagram ciut + 55 label rusak

Temuan owner (KB mcf-fincore, 22 blok mermaid): (a) stateDiagram tampil semut — `useMaxWidth`
default TRUE untuk tipe selain flowchart/sequence memaksa svg muat lebar container, fit-floor
tak pernah kepanggil; (b) 55+ baris transisi state gagal parse.

Ground truth via `mermaid.parse()` (vendored), semua diukur bukan ditebak:
- Label transisi state TIDAK BOLEH mengandung `:` (kedua) atau `;` (terminator statement) —
  **quoting tidak menolong dua-duanya**; `"` sendiri LEGAL di label state (jangan over-flag).
- Node text ber-quote dengan kutip ganda DI DALAM (`J["…GLLink("a,b")…"]`) tetap rusak —
  celah tokenizer lama (dianggap "sudah quoted, aman").

Fix:
1. **Template**: `useMaxWidth:false` untuk SEMUA tipe (state/er/class/journey/gantt/timeline/pie);
   panel error ketambahan hint deterministik saat pola state-label `:`/`;` terdeteksi.
2. **Tokenizer (`_lib/mermaid_syntax.py`)**: Rule 7 baru — label transisi state dengan `:`/`;`
   → `mermaid_syntax_invalid` (additive, Rule 1-3 di body state tidak berubah); Rule 3 varian
   quoted — kutip dalam node text yang sudah ber-quote → flagged.
3. **Kontrak** (`mermaid-emission-rules.md` Rule 7 + PRD-kontrak §3): guard pakai `—`,
   sitasi tanpa colon (`file.cs 112-134`), pemisah klausa `·`, atau pindah ke `note`;
   saran lama "wrap in double-quotes" untuk label state DIKOREKSI (tidak menolong, terukur).
4. **Repin**: `test-kb-flows-syntax-lock` 2→3 issue (fixture bad `(controller:42)` = true
   positive yang dulu lolos); fixture good dikoreksi (dulu meng-encode saran lama yang salah).
5. Field fix: 8 modul KB mcf-fincore (55 baris + quote/semicolon) diperbaiki + re-render —
   22/22 blok parse OK.

Tests: `tests/mermaid-flows/test-state-label-colon.sh` (A1-A3, B1-B3, C, D, E).
Versions: plugin 7.23.1 → 7.23.2.
