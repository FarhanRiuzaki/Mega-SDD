# 7.16.0 — render-html: md → satu file HTML shareable, diagram-first

**Tanggal:** 2026-08-31 · **Riset dasar:** `research/2026-08-31-render-html-standard.md` (Diátaxis lensa per jenis dokumen, arc42 kompartemen, C4 via flowchart, budget mermaid berangka, bahasa natural mix §6). **Mandat user:** team dev paham lewat artefak HTML yang standar-rapi-konsisten-sesuai-domain, share-able ke orang tanpa Claude, diagram-first narasi minimal. Mockup desain di-review + di-approve user (artifact 4dc9dffb).

## Prinsip yang tidak bisa ditawar

**md tetap SATU-SATUNYA ground truth.** Renderer = script deterministik 0 token yang MEMBUNGKUS md mentah ke template; HTML me-render dirinya sendiri di browser (marked.js + mermaid.js vendored). HTML tidak pernah ditulis model → tidak bisa drift, tidak bisa fabrikasi (kelas drift dok-paralel yang triage №C tolak). Regenerate kapan saja.

## Komponen

1. **`assets/render-html/`** — `template.html` (anatomi tetap: chrome bar → untuk-siapa → nav diagram-dulu → summary strip → body → footer provenance; token design light+dark; system fonts ONLY — offline berarti tanpa Google Fonts) + vendored pinned:
   - `marked.min.js` **15.0.12** (sha256 `3e7e7d7feb3e5d58…`)
   - `mermaid.min.js` **11.9.0** (sha256 `0b3ed43741173638…`)
   - Review pin di tiap bump versi plugin, kelas yang sama dengan pin `.mcp.json`.
2. **`scripts/render-html.sh`** — file mode (`<parent>/html/<stem>.html`), dir mode + `--index` (bundle + index.html bernav), `--assets-dir` (aset bersama untuk bundle besar — per-file kecil), `--out`, `--cwd`. Python core:
   - **Lensa per jenis** (deteksi path/nama, fail-open ke generic): kb-module / binding / units / drift / adr / vault / index / generic → badge + baris "Untuk siapa" + summary strip (hitungan regex: tier `[LOCKED]`/`[INTENT]`/`[ARTIFACT]`, verdict CONFIRMED/CONFLICT, OQ-id unik, U-id unik, diagram, bagian — gagal hitung = tile hilang, tidak pernah salah angka).
   - **Budget diagram ADVISORY** (riset §4): >20 edge per fence atau >7 participant sequence → teguran natural ("kegedean, mending dipecah") di JSON output + warnbar halaman; exit tetap 0 — md ground truth tidak pernah diblok.
   - **Provenance** (pola F-26): footer bawa relpath sumber + sha256(md)[:12] + `plugin_version` + `written_at` + kalimat "md = ground truth, HTML ini turunan".
   - **Frontmatter di-strip dari tampilan** (metadata mesin, bukan bacaan; sha + hitungan tetap dari file utuh).
   - **Escape breakout**: md dibawa sebagai JSON dengan `</` → `<\/` (md berisi `</script>` tidak bisa menutup tag pembungkus).
3. **Template JS** (client-side, ~100 baris hand-written): marked v15 renderer (fence `mermaid` → `pre.mermaid`; heading ber-id slug; tabel dibungkus `.tw` scroll sendiri), tier token jadi badge (kosmetik, teks tetap), tiap diagram dibungkus kartu berjudul heading terdekat, nav dibangun dari DOM (diagram dulu), mermaid theme ikut dark/light, `securityLevel: strict`.

## Amendemen 7.18.0 — reachability + auto-emission (field-test hari pertama)

Test lapangan pertama ("render html nya project ini" di sesi lain) MISS — frasa tidak ter-route ke script mana pun; sesi itu menjawab tier-S dengan benar berdasarkan yang dia tahu. Kelas reachability yang sama dengan F-09/F-14: fitur diam karena tidak ada yang menunjuk ke sana, "invoke by phrase" ternyata prosa kosong. Fix:

1. **`/mega-sdd:emit html <file|dir>`** — lane kelima di emit (script, bukan skill; description command membawa trigger "render html"/"html-kan"/"bikin html dari"); dir → `--index` default; target ambigu → tanya, jangan tebak. Router side-lane using-mega-sdd menunjuk lane ini.
2. **Auto-emission per fase (permintaan user — "setiap domain ada laporannya"):** empat hand-off menjalankan renderer otomatis — extract-intelligence (`<kb> --index`), generate-intent (`<vault-dir> --index`), generate-units (`units/_index.md`), execute-bolts (`bolts/_summary.md`) — 0 token model, **fail-open** (render gagal = satu baris warning, tidak pernah halt), opt-out `config.yaml render_html: off`. Path html disebut di announce hand-off masing-masing.

## Rail & keputusan

- Zero perubahan gate/hook/command — script dipanggil by phrase ("render html …") atau `--html` menyusul di emit KALAU dipakai (deferred, konsumen dulu).
- **Auto-fold narasi DITUNDA jujur**: melipat konten md arbitrer = renderer menebak struktur — bukan haknya. Diagram-first dicapai via nav + strip + prominensi kartu; md yang menulis `<details>` sendiri ter-render terlipat. Konvensi emitter menyusul kalau lapangan minta.
- Sintaks C4 mermaid TIDAK dipakai (GitHub tidak render — konsistensi md↔HTML).
- Secret-scan tidak diulang (sudah jalan di writer md); footer "DOKUMEN INTERNAL" menandai klasifikasi peredaran.
- Output `html/` = turunan; rekomendasi `.gitignore` diserahkan ke proyek pemakai.

## Verifikasi (dilakukan sebelum ship)

- `tests/render-html/test-render-html.sh` — 22 pin A–G (self-contained + zero external refs, escape breakout, frontmatter strip, 3 lensa, provenance sha, budget advisory dua arah, bundle+index, assets-dir, bahasa natural, usage rc 2). ALL PASS.
- API marked v15 diverifikasi via node (fence/heading/table renderer); global `mermaid` diverifikasi di tail bundle; **render end-to-end diverifikasi di Chrome live** (flowchart + stateDiagram tampil, lensa kb-module benar, console bersih) — screenshot di sesi 2026-08-31.

## Ukuran (jujur)

Self-contained ≈ 2,6 MB/file (mermaid.js dominan) — diterima untuk share; bundle KB pakai `--assets-dir` (satu folder aset, halaman kecil). Repo +2,7 MB vendored assets — harga mandat offline + auditability.
