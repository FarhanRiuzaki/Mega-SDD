---
description: Emit one of the four team documents — /mega-sdd:emit <prd|fsd|sit|uat> dispatches the matching doc-pack skill (flags pass through) — or render any mega-sdd md into one shareable offline HTML via /mega-sdd:emit html <file|dir> (triggers "render html", "html-kan", "bikin html dari", "share ke tim tanpa Claude") — or author a cited executive summary via /mega-sdd:emit summary (triggers "emit summary", "rangkuman eksekutif", "ringkasan project", "bahan presentasi"). No arg → list the four docs with current maturity from their doc-control stamps.
argument-hint: "<prd|fsd|sit|uat|html|summary> [vault-path|md-path] [--no-pdf] [--auto] [doc-specific flags]"
---

The single emission verb of the 5.0.0 surface. **Dispatch is via the Skill tool — never the Agent tool** (the doc-pack gates key on Skill calls).

User arguments: $ARGUMENTS

## Dispatch table

| First positional | Dispatch (Skill tool) | Doc | Output |
|---|---|---|---|
| `prd` | `mega-sdd:emit-prd` | Product Requirements Document (forward from vault / REVERSE from KB) | `<vault>/prd/PRD.md` |
| `fsd` | `mega-sdd:emit-fsd` | Hybrid Confluence FSD | `<vault>/fsd/FSD.md` (+ PDF/HTML) |
| `sit` | `mega-sdd:emit-sit` | Bank-style SIT with script-derived evidence | `<vault>/sit/SIT.md` |
| `uat` | `mega-sdd:emit-uat` | UAT test script untuk tim bisnis (skenario 1:1 F-*, berita acara, xlsx) + Playwright e2e skeletons & offered run (6.10.0) | `<vault>/uat/UAT.md` (+ PDF/xlsx/e2e) |
| `html` | **script, bukan skill** — `bash "${CLAUDE_PLUGIN_ROOT}/scripts/render-html.sh" <md-path-or-dir> [--index] [--assets-dir] [--out=…]` | md apa pun (vault/KB/binding/report) → satu file HTML self-contained, offline, diagram-first — buat di-share ke orang tanpa Claude (7.16.0, spec 2026-08-31-render-html.md) | `<parent>/html/<stem>.html` (dir → `<dir>/html/` + index + cross-bundle search, 7.19.0) |
| `summary` | **authored di command ini** (prosedur §Lane summary di bawah; promote ke skill kalau lapangan minta) | ringkasan eksekutif ber-SITASI gaya DD9000 — angka dulu, flow Mermaid, status jujur — ditulis SEKALI ke md lalu di-render (spec 2026-08-31-render-nav-search-summary.md §4) | `<target>/summary/SUMMARY.md` + html-nya |

Strip the first positional (`prd|fsd|sit|uat`) and pass EVERY remaining argument through to the dispatched skill unchanged — each doc-pack skill owns its own flag parsing, rails, and halt taxonomy (this command adds none).

**The `html` lane** runs the script directly (0 model tokens — md stays the only ground truth; the HTML renders itself client-side). Rules: a directory argument gets `--index` by default; no argument after `html` → ask which file/dir (keterangan: sebut kandidat yang ada — vault docs, KB, binding, laporan). Relay the script's JSON honestly — `rendered` paths + any `budget_warnings` ("kegedean, mending dipecah" is advisory, never an error) — and close with the open hint: `open <path>`. Kalau user minta "render html project ini" tanpa file jelas → tanyakan targetnya, jangan menebak (project berjalan ≠ dokumen mega-sdd).

**Lane `summary` — ringkasan eksekutif ber-sitasi (7.19.0, AI di lapisan MD, BUKAN di render).** Target = vault atau KB dir (argumen kedua; absen → pakai vault/KB satu-satunya, lebih dari satu → tanya dengan keterangan). Prosedur:

1. **Baca sumber angka yang NYATA**: `census.json` (file/baris/module), `vault.json` (claims, OQ, changelog), `binding.md` (CONFIRMED/CONFLICT), `units/_index.md`, `bolts/_summary.md` + `_batch-suite.json`, KB README. Yang tidak ada → bagian itu tulis jujur "belum ada datanya (fase belum jalan)" — angka TIDAK PERNAH dikarang, setiap angka dan klaim menyebut artefak sumbernya.
2. **Tulis `<target>/summary/SUMMARY.md`** pola DD9000 (referensi selera di research/2026-08-31-render-html-standard.md §7): §00 strip angka utama → §flow pipeline (Mermaid, label edge dua sisi: atas aksi, bawah bukti) → §peta modul → §temuan → §status JUJUR (baris "menunggu"/"butuh keputusan bisnis" ikut tampil). Tiap section ditutup SATU kalimat takeaway tebal. Bahasa = §Register natural; Tier-1 verbatim; doc-control stamp seperti emisi lain.
3. **Render**: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/render-html.sh" <target>/summary/SUMMARY.md` — sebut path html-nya di penutup.

An unknown first positional (not `prd|fsd|sit|uat|html|summary` and not empty) → do not guess; show the dispatch table and ask which document was meant (keterangan in Indonesian).

## No argument — the doc-maturity listing

When `$ARGUMENTS` is empty, do NOT emit anything. For each vault (canonical `.mega-sdd/vaults/*/` first, legacy `docs/mega-sdd/vaults/*/`), probe the four doc paths and read each doc-control stamp (the `<!-- mega-sdd:doc-control` … `-->` block written by `scripts/refresh-doc-stamps.sh` — fields `maturity` / `position` / `generated_at`):

```
Dokumen tim (vault: <name>)
- PRD  <vault>/prd/PRD.md  — maturity: <draft-from-legacy|reviewed|final>   (generated_at: …)
- FSD  <vault>/fsd/FSD.md  — maturity: <pre-development|post-development>   (generated_at: …)
- SIT  <vault>/sit/SIT.md  — maturity: <planned|partial|executed>           (generated_at: …)
- UAT  <vault>/uat/UAT.md  — maturity: <draft|ready-for-uat|signed-off>     (generated_at: …)
```

A doc that does not exist → `belum pernah di-emit — jalankan /mega-sdd:emit <doc>`. A doc without a doc-control block → `maturity: unset (stamp belum ada)`. Never invent a maturity value; the stamp (or its absence) is the only source.

Close the listing with the one-line hint: `Pakai /mega-sdd:emit <prd|fsd|sit|uat> [flags] untuk emit/regenerate.`
