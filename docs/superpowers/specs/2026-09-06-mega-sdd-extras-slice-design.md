# Spec — `mega-sdd-extras`: slice-design per-page (revive di plugin terpisah)

**Status:** **APPROVED P0 — owner 2026-09-06** ("APPROVE P0", AskUserQuestion). P0 dibangun di commit yang sama dengan amandemen status ini; P1 = bukti lapangan (§6).
**Sumber keputusan:** `research/2026-08-23-team-feedback-triage.md` §Item 2 (owner, 2026-08-23) — "buat `mega-sdd-extras` berisi slice-design di marketplace yang sama, revive dari commit sebelum d4f82c7, per-page (bukan batch 4 page), pakai koneksi Figma MCP langsung (bukan PNG)". Urutan di triage: setelah №A (size-weighted) — №A SPEC COMPLETE 7.29.0.
**Rambu:** Evidence-First rule (2026-09-05) — bukti permintaan = kolega tim adalah pemakai nyata workflow design→code (triage §Item 2; balasan tim `docs/mega-sdd/feedback-response-2026-08-23.md` baris "Figma slicing"). `plugins/mega-sdd/CLAUDE.md §Commands`: "`mega-sdd-extras` gets built only if demand appears" — syaratnya terpenuhi, klausulnya diamandemen di P0.
**Bahan:** skill lama `skills/slice-design/` @ `d4f82c7^` (44 + 39 baris + `commands/slice.md`), spec asal `2026-08-12-playwright-embed-design.md` D1, catatan penghapusan CHANGELOG 7.4.0 №2, kontrak tool Figma MCP (`get_metadata` / `get_design_context` / `get_variable_defs` / `get_screenshot`), tata letak cache plugin terpasang.

## 1. Masalah yang dijawab (dari bukti, bukan tebakan)

| Yang tim alami (percobaan Figma slicing, 6.12.0 era) | Akar yang tercatat | Jawaban spec ini |
|---|---|---|
| Slicing berat & lama | batch 4 page sekali jalan | **satu invokasi = satu page/frame** (§3.1); page → section → komponen adalah tangga, bukan sekali telan |
| Detail melenceng dari desain | input PNG — token desain (spacing/warna/tipografi/komponen) hilang saat di-rasterisasi | **Figma MCP langsung** sebagai jalur utama: `get_design_context` (kode referensi + token + screenshot) + `get_variable_defs` (variabel). PNG hanya fallback, dan laporannya wajib bilang "token tidak tersedia" |
| Tidak ada pintu masuk di mega-sdd sejak 7.4.0 | slice-design dihapus (surface cull, "extras nanti kalau ada pemakai nyata") | plugin **terpisah** di marketplace yang sama; core tidak berubah perilaku, yang tidak memasang tidak membayar apa pun |

Yang TIDAK diklaim: angka wall-clock/kualitas — belum ada run per-page yang terukur. Itu isi P1 (§7), bukan asumsi.

## 2. Bentuk plugin

```
plugins/mega-sdd-extras/
├── .claude-plugin/plugin.json        # name: mega-sdd-extras, version 0.1.0
├── README.md                          # apa, syarat (core terpasang), cara pakai, degradasi
├── CHANGELOG.md                       # SENDIRI — CI parity core membaca tag teratas CHANGELOG root
├── commands/slice.md                  # /mega-sdd-extras:slice → Skill mega-sdd-extras:slice-design
└── skills/slice-design/
    ├── SKILL.md                       # ≤ 200 baris, router + rails
    └── references/slice-procedure.md  # tangga per-page + kontrak tool Figma + loop compare
```

**Tanpa** `hooks/`, **tanpa** `scripts/`, **tanpa** `.mcp.json`. Alasan: (a) nol spawn = nol pajak di laptop kantor (CrowdStrike ~220 ms/spawn) dan nol beban bagi yang tidak memakai; (b) Playwright + Context7 sudah dibundel core (`plugins/mega-sdd/.mcp.json`) — server kedua = dua proses `npx` untuk hal yang sama; (c) Figma MCP = milik user (akun mereka), bukan dibundel — sama seperti kontrak core `generate-intent` Step 1.

`marketplace.json` `plugins[]` dapat entri kedua (`name: mega-sdd-extras`, `source: ./plugins/mega-sdd-extras`, versi = plugin.json-nya). Install: `claude plugin install mega-sdd-extras@mega-sdd`.

### 2.1 Ketergantungan ke core — resolusi path, bukan path relatif

Plugin terpasang hidup di `~/.claude/plugins/cache/<marketplace>/<plugin>/<versi>/` (fakta mesin ini: `cache/mega-sdd/mega-sdd/7.23.1/`). Dari root extras, `../mega-sdd/…` TIDAK mengarah ke core. Maka skill extras me-resolve core seperti wrapper v2 (`scripts/install-front-door.sh` :53–58, presedennya): baca `~/.claude/plugins/installed_plugins.json` → `plugins["mega-sdd@mega-sdd"]` → entri `scope: "user"` versi tertinggi → `installPath`. Dari situ skill membaca (READ-only, on demand):

- `references/ui-design-heuristics.md`, `references/design-intelligence/{style-principles,ux-rules}.md` — lantai desain (REUSE, tidak menulis pengetahuan desain baru).
- `references/framework-conventions/<pack>.md` — konvensi file/nama/idiom stack aktif (pack proyek `.mega-sdd/packs/*.md` menang, seperti core 7.12.0).
- `references/output-language.md` — register naratif (skill extras greenfield-reachable, jadi bawa kebijakannya sendiri satu kalimat).

Core absen / tidak terbaca → **degradasi, bukan halt**: kode tetap dibuat dari referensi Figma + konvensi yang terbaca dari repo; laporan menyebut "core corpus tidak dibaca (alasan)". Tidak ada yang gating.

## 3. Kontrak skill (perubahan vs skill lama ditandai ★)

### 3.1 Input — satu page per invokasi ★

`/mega-sdd-extras:slice --figma=<url> [--image=<path>] [--url=<web>] [--rounds=<n≤3>]`

- `--figma=<url>` **wajib mengandung `node-id`** (page atau frame). Tanpa node-id → `get_metadata(fileKey)` (tanpa nodeId = daftar page) → SATU `AskUserQuestion` "page/frame yang mana?" dengan keterangan per opsi (aturan OQ interaction). Lebih dari satu node dalam satu invokasi → **ditolak** dengan kalimat "satu page per jalan — jalankan lagi untuk page berikutnya" (ini akar berat/lamanya, bukan batas teknis semata).
- `--image=<path>` / `--url=<web>` = **fallback** bila Figma MCP absen di sesi (probe: `ToolSearch query:"figma"` → tidak ada tool `mcp__figma__get_design_context`). Laporan wajib memuat baris `tokens: NOT AVAILABLE (image fallback) — values inferred`.
- Tanpa referensi sama sekali → tanya SATU (dengan keterangan), lalu jalan.

### 3.2 Tangga intake Figma — page → section → komponen ★

1. `get_metadata(fileKey, nodeId)` — struktur saja (id, tipe, nama, posisi, ukuran). Murah. Hasil: inventaris section/komponen page itu.
2. Per komponen/section (urut atas-bawah): `get_design_context(fileKey, nodeId)` — kode referensi + aset + screenshot node. Aturan tool-nya sendiri: **muat panduan `figma-design-to-code` dulu** (skill `figma:figma-design-to-code` bila ada; kalau tidak, resource `skill://figma/figma-design-to-code/SKILL.md`). Kalau tool membalas metadata-only karena terlalu besar → turun satu tingkat ke child nodes (jangan pernah set `forceCode`). Ini tangga yang membuat "per-page" nyata: page besar tidak pernah ditelan sekali.
3. `get_variable_defs(fileKey, nodeId)` di node page — token warna/tipografi/spacing → dipetakan ke token proyek (vault `design_system` bila ada; kalau tidak, CSS vars/tema stack aktif). Nilai mentah di-hardcode hanya bila tidak ada rumah token — dan dicatat.
4. `get_screenshot(fileKey, nodeId)` **hanya** untuk referensi compare (§3.4), bentuk URL+curl (bukan base64 — hemat konteks), `maxDimension` default 1024.

Kode referensi dari Figma **diadaptasi**, tidak ditempel: komponen yang sudah ada di repo dipakai ulang (reuse-first — cek `.mega-sdd/codebase/symbol-index.json` core bila ada, lalu direktori komponen stack aktif); token proyek menang atas nilai mentah; konvensi pack menang atas struktur kode Figma.

### 3.3 Aturan implementasi (dibawa utuh dari skill lama)

Ikuti pack aktif persis seperti bolt; lantai desain dari corpus core; vault `design_system` = pengayaan opsional; **tidak pernah menulis vault/binding**; Context7 (bundel core) untuk API framework yang cepat berubah, tidak load-bearing; maksimal 3 pertanyaan klarifikasi (lokasi di repo, route, framework bila ambigu), default masuk akal > pertanyaan.

### 3.4 Render-compare (≤ 3 ronde) — dibawa utuh

Dev server **milik operator** — skill tidak pernah start/install/background server (kelas unbounded-spawn + zombie di Git Bash/EDR). URL dari `.mega-sdd/config.yaml` `preview_url:` atau diberikan operator; tak terjangkau → ronde 0 + kalimat jujur "render NOT verified". Screenshot via Playwright MCP bundel core (tool `mcp__plugin_mega-sdd_playwright__*`; absen → compare SKIP dengan alasan). Bandingkan lawan screenshot node Figma di 1280 + 390: layout, spacing, tipografi, peran warna, state. Tanpa pixel-diff. Ronde 3 lewat → STOP, delta dilaporkan.

### 3.5 Laporan — traceability per node ★

`.mega-sdd/slices/<slug>/slice-report.md` (slug = kebab-case nama page/frame). Tambahan vs lama: tabel **komponen → file → Figma nodeId** (disiplin sitasi: setiap potongan UI bisa ditelusuri ke node-nya; komponen tanpa node = tidak diklaim berasal dari desain). Kolom `tokens:` (`figma variables` | `vault design_system` | `NOT AVAILABLE — inferred`). Artefak plugin, tidak pernah masuk source tree user (`references/paths.md` core dapat baris `slices/` lagi — baris ini hilang saat 7.4.0).

### 3.6 Containment (dibawa dari D1 spec 2026-08-12, tetap berlaku)

Command-invocation only. Deskripsi skill TIDAK memuat kata kunci census ID/EN (tidak ada "pecah", "spec out", "slicing" sebagai trigger bebas) dan menyatakan "never auto-triggers off free text". Core tidak menyebut extras di anchor (pin playwright-embed C1/C2/C3 tetap: anchor 3844 B, tanpa "slice"). Satu-satunya penyebutan di core: README (satu baris "plugin opsional `mega-sdd-extras`") + amandemen klausul CLAUDE.md.

## 4. Yang core sentuh (semua non-perilaku)

| File | Perubahan |
|---|---|
| `.claude-plugin/marketplace.json` | entri plugin kedua |
| `.github/workflows/tests.yml` | `claude plugin validate plugins/mega-sdd-extras` di samping core |
| `plugins/mega-sdd/CLAUDE.md §Commands` (2 situs) | "gets built only if demand appears" → "built 2026-09 as a separate plugin on recorded demand (triage 2026-08-23 §Item 2); core surface unchanged" |
| `plugins/mega-sdd/references/paths.md` | baris `<project>/.mega-sdd/slices/<slug>/slice-report.md` (pemilik: mega-sdd-extras) |
| `README.md` + `plugins/mega-sdd/README.md` | satu baris pointer |
| `CHANGELOG.md` (root) | satu baris di rilis core berikutnya: "marketplace: +mega-sdd-extras 0.1.0 (own changelog)" — tag teratas tetap versi core (parity CI) |

Tidak disentuh: hooks, scripts, skills core, anchor, gate apa pun.

## 5. Tests (root tree `tests/extras/`, CI-discovered)

`test-extras-plugin-contracts.sh` — bash + python3:
1. `plugin.json` extras valid JSON, `name == mega-sdd-extras`; marketplace punya 2 entri dan **setiap** `plugins[i].version == plugin.json` sumbernya (menutup celah parity yang sekarang hanya memeriksa `plugins[0]`).
2. Zero-cost pin: `plugins/mega-sdd-extras/{hooks,scripts,.mcp.json}` TIDAK ada.
3. Containment: deskripsi SKILL.md tanpa kata census (daftar dari `test-p6-front-door.sh`), memuat "never auto-triggers"; `commands/slice.md` ada dan memanggil `mega-sdd-extras:slice-design`.
4. Wording pins (kelas pin skill lama, dipulihkan): "one page per invocation", "never starts", "never writes the vault", "NOT verified", "tokens: NOT AVAILABLE", tangga `get_metadata → get_design_context → get_variable_defs`, larangan `forceCode`.
5. Core tetap: `plugins/mega-sdd/skills/slice-design` + `commands/slice.md` absen (pin B1 playwright-embed tetap hijau); command core tetap 6 (p6); anchor 3844 B (C1).
6. `claude plugin validate plugins/mega-sdd-extras` lolos (CI step).

## 6. Fase

- **P0 — bangun (satu commit, markdown + JSON saja):** §2, §3, §4, §5. Acceptance: suite dua tree hijau + tests baru; `claude plugin validate` dua plugin; satu live run pada satu frame Figma nyata. Versi extras 0.1.0. Core tidak bump (tidak ada perubahan perilaku).
  **Hasil P0 (2026-09-06):** SHIPPED — suite dua tree 247/247 (incl. `tests/extras/`), `claude plugin validate` extras + marketplace lolos, core anchor 3844 B / 6 command tak berubah. **Live run mesin-ini DI-SKIP atas keputusan owner** (AskUserQuestion "Tunda live run ke kantor (P1)") meski Figma MCP terautentikasi di sesi build — jadi P0 terbukti secara STRUKTURAL saja; klaim "detail tidak melenceng" belum punya bukti run sampai P1. Dicatat jujur, bukan diklaim.
- **P1 — bukti lapangan (kantor, menumpang kunjungan field run 7.29.1):** kolega menjalankan SATU page yang dulu dia coba dengan PNG. Ukur: wall-clock per page, ronde compare terpakai, delta tersisa (hitung), token (gateway — tag `mega-sdd-trace:slice-design`). Bandingkan lawan pengalaman PNG-nya (kualitatif, jujur). Prasyarat yang belum pasti: akun Figma MCP tim jalan ("begitu akunnya jalan") dan `npx` Playwright di kantor — kalau belum, P1 = jalur fallback image, dan itu yang dilaporkan.
- **P2 — HANYA kalau P1 memberi bukti:** Code Connect (`get_code_connect_map`) untuk mengikat komponen Figma → komponen repo (reuse-first di level desain); saran token ke `design_system` vault sebagai file usulan (extras tetap tidak menulis vault). Tidak sekarang.

## 7. Non-goals (tercatat supaya tidak merayap)

Tidak ada routing free-text; tidak menulis vault/binding; tidak start server; tidak pixel-diff; tidak PNG-first; tidak server Playwright kedua; tidak multi-page per invokasi; tidak hooks/scripts di extras; tidak menyentuh gate core; tidak membundel Figma MCP.

## 8. Risiko yang di-surface

- **Cache path & versi core:** resolusi via `installed_plugins.json` bergantung entri `mega-sdd@mega-sdd` user-scope — sama persis dengan asumsi wrapper v2 yang sudah live-proven (7.5.2). Instalasi core dari marketplace lain / path lokal → corpus tidak terbaca → degradasi tercatat.
- **`get_design_context` besar:** balasan metadata-only pada node besar — tangga child-node menanganinya; larangan `forceCode` mencegah ledakan konteks.
- **Figma MCP di kantor belum tentu ada:** P0 tetap berguna lewat fallback image, tapi janji "detail tidak melenceng" hanya berlaku di jalur MCP — dinyatakan begitu ke tim.
- **Nama command:** `/mega-sdd-extras:slice` (namespace plugin), bukan `/mega-sdd:slice` — pin negatif core tetap berlaku; typed form lama tidak diregistrasi ulang.

## 9. Gate

Owner memilih: **APPROVE P0** (bangun sesuai §2–§5, satu commit, live run di mesin ini sebagai acceptance) · **REVISE** (sebut §-nya) · **PARK sampai field run 7.29.1** (bukti kantor dulu; spec tetap tersimpan).
