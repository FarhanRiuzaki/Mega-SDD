# Standar output render-html — riset sebelum build (7.16.0)

**Tanggal:** 2026-08-31 · **Mandat user:** "team dev bisa paham dengan mudah lewat artefact html-nya … research dulu agar output-nya standar, rapi, konsisten, sesuai domain" + rule standing "kurangi narasi, banyakin flow diagram yang jelas".
**Kesimpulan satu baris:** standar = **lensa per jenis dokumen** (bentuk halaman ditentukan mode-baca pembacanya, bukan selera render) + **anatomi halaman tetap** + **budget diagram terukur** — semuanya deterministik di template, 0 keputusan gaya per run.

## 1. Landasan (4 standar industri, dipetakan ke kebutuhan kita)

| Standar | Yang diambil | Penerapan di renderer |
|---|---|---|
| **Diátaxis** (diataxis.fr) | Dokumen dibedakan oleh MODE BACA: reference (lookup fakta) ≠ explanation (pahami kenapa) ≠ how-to (kerjakan tugas). AI/dev tidak baca linear — mereka retrieve fragmen → struktur menentukan kualitas pemahaman | Tiap jenis artefak mega-sdd punya lensa layout sendiri (§2) — binding itu *reference* (verdict dulu), ADR itu *explanation* (context→decision), units itu *work order* (DAG dulu) |
| **arc42** (arc42.org) | 12 kompartemen opsional — "lemari bernilai walau ada laci kosong"; bagian kunci buat kita: Context & Scope, Building Block, Runtime, Decisions | Anatomi halaman ADR + halaman vault: kompartemen tetap, yang kosong ditandai kosong (N/A tercatat ≠ terlupa — selaras temuan audit DD9000) |
| **C4 model** | Context + Container CUKUP untuk mayoritas tim; Component hanya bila bernilai; Code di-skip. PENTING: renderer mermaid GitHub TIDAK dukung sintaks `C4Context` | Topologi digambar **flowchart + subgraph gaya C4**, BUKAN sintaks C4 mermaid — supaya md yang sama render identik di GitHub, artifact, dan HTML kita (konsistensi md↔HTML tidak boleh pecah) |
| **Mermaid readability** (mermaid.js.org + praktisi) | >15–20 node → pecah/subgraph; >30–40 → beberapa diagram fokus; sequence >7 participant → pecah; hierarki dalam → `LR`; decision diamond wajib label exit | Jadi **budget diagram** di template + lint advisory di renderer (hitung node per fence, warn saat lewat budget — tidak pernah blok) |
| **Google dev-doc style** | Setiap halaman menyatakan audiens + tujuan di atas; bahasa sederhana konsisten | Baris "Untuk siapa: …" di bawah judul, digenerate dari jenis dokumen (bukan dikarang per run) |

## 2. Lensa per jenis dokumen ("sesuai domain")

Aturan emas: **elemen yang paling sering dicari pembaca = elemen pertama di halaman.**

| Artefak md | Mode baca (Diátaxis) | Yang tampil PERTAMA | Diagram wajib |
|---|---|---|---|
| KB module PRD-kontrak | reference + explanation | Ringkasan angka (claims/tier/OQ) + flow utama | flowchart alur bisnis, stateDiagram siklus entitas, erDiagram entitas |
| vault (model/flows/constraints) | reference | ERD + daftar flow | erDiagram, flowchart per F-xxx (sudah wajib Mermaid) |
| binding.md | reference (lookup verdict) | Strip verdict CONFIRMED/CONFLICT/OQ + tabel per klaim | pie/strip ringkasan; anchor detail terlipat |
| units `_index.md` | how-to / work order | **DAG dependensi** + urutan wave | flowchart DAG (subgraph per wave) |
| DRIFT-REPORT | status | Delta summary + flow yang kena | flowchart flow terdampak, diff ditandai warna token |
| ADR (advisor 7.14.0) | explanation | Context (C4-style) → Decision → Options ditolak | flowchart topologi gaya C4 Context+Container |
| SIT/UAT emissions | reference (matrix) | Matriks skenario × status | stateDiagram alur uji bila ada; PDF tetap kanal formal |

## 3. Anatomi halaman TETAP (identik semua jenis — "standar & konsisten")

```
chrome bar   → nama file · jenis artefak (badge) · versi plugin · tanggal render
"untuk siapa" → 1 baris audiens+tujuan, derived dari jenis dokumen
nav kiri     → index DIAGRAM dulu, baru section
summary strip → 3–5 angka kunci jenis itu (claims/verdict/unit/dsb)
badan        → diagram = muatan utama; narasi DILIPAT ke <details>
footer       → "DOKUMEN INTERNAL — <proyek>" · md sumber + sha256 · plugin_version · written_at (pola F-26)
```

Konsistensi ditegakkan secara mekanis: SATU template, token design tetap, lensa dipilih otomatis dari deteksi jenis file (path/frontmatter) — tidak ada keputusan gaya per run, maka dua render terpisah selalu identik.

## 4. Budget diagram (dari riset mermaid, jadi angka)

- ≤ 20 node per diagram; lebih → subgraph atau pecah jadi diagram fokus (>35 = wajib pecah).
- Sequence ≤ 7 participant.
- Hierarki dalam → arah `LR`.
- Setiap decision diamond berlabel exit (ya/tidak, pass/fail).
- Renderer menghitung dan MENEGUR (advisory di chrome bar: "diagram F1: 31 node — di atas budget, pertimbangkan pecah") — tidak pernah memblok, karena md = ground truth.

## 5. Keputusan teknis yang dikonfirmasi riset

- **Client-side render** (md mentah + marked.js + mermaid.js inline) = pola mapan (Markdown Monster, viewer GitHub-style client-side); kelemahan yang diketahui = ukuran file karena mermaid.js — diterima untuk single-file share; untuk bundle KB multi-file sediakan mode `--assets-dir` (satu folder aset bersama, per-file kecil).
- **Vendored + pinned** (tanpa CDN): lingkungan office tanpa internet + auditability supply-chain.
- Sintaks C4 mermaid TIDAK dipakai (kompatibilitas GitHub) — C4 digambar flowchart+subgraph.
- Secret-scan sudah jalan di md sumber; renderer tidak menambah exposure, footer klasifikasi menandai peredaran.

## Sumber

- https://diataxis.fr/ + https://diataxis.fr/start-here/ (mode-baca 4 tipe; relevansi retrieval AI)
- https://arc42.org/overview/ + https://docs.arc42.org/home/ (12 kompartemen opsional)
- https://mermaidstudio.dev/docs/diagram-types/c4/ + https://github.com/orgs/community/discussions/197898 (C4 levels; GitHub tidak render sintaks C4)
- https://mermaid.js.org/intro/syntax-reference.html + https://www.mermaidcreator.com/blog/mermaid-flowchart-sizing-layout-best-practices + https://www.mermaidcreator.com/blog/mermaid-large-diagram-optimization-performance (budget node, LR, ELK)
- https://developers.google.com/style (audiens+tujuan, bahasa konsisten)
- https://markdownmonster.west-wind.com/docs/Markdown-Rendering-Extensions/Rendering-Mermaid-Charts.html + https://github.com/orgs/mermaid-js/discussions/5977 (pola client-side render + tradeoff ukuran)
