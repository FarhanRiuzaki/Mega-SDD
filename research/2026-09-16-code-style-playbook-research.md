# Playbook code style per tech stack — research (masukan tim dari run BE Java)

**Status:** RESEARCH — belum ada perubahan kode. Ditulis terhadap HEAD `41e0e61` (8.0.3, 2026-09-16).
**Sumber:** `research/2026-09-16-team-feedback-java-code-style.md` (dokumen tim, verbatim). Permintaan owner: *"jadikan playbook karena ini hasil masukan dari run be java.. dan jadikan standar yg sama untuk playbook tech stack lain polanya, research dlu."*
**Metode:** klausul-per-klausul dokumen tim dipetakan ke permukaan plugin yang ada (file:line), lalu sensus grep siapa yang MEMBACA tiap section pack — karena playbook yang tidak dibaca mesin = teks mati (pelajaran `elysia.md`: 36/36 dispatch jatuh ke `_universal` karena tidak ada yang membacanya, README pack §Project-local packs).
**Angka:** semua berlabel MEASURED (grep / run terdahulu) atau EST. Tidak ada run baru di sesi ini; biaya sesi = 0 run.

---

## 0. Ringkas

1. **Dokumen tim = aturan yang sama dengan Iron Rule 6 (8.0.1–8.0.3), ditulis dari sisi Java.** Dari 12 klausul: 6 sudah tertutup generik, 4 PARTIAL (kosakata visibility, allow-list "public API", `@throws`, checklist), 2 GAP nyata: **heuristik penamaan semantik** (boolean sebagai pertanyaan, method berawalan verb, hindari nama kabur, koleksi plural) dan **bahasa komentar** (contoh BAD tim = Javadoc berbahasa Indonesia; tidak ada aturan di mana pun).
2. **Temuan struktural (MEASURED grep):** section `## Comment conventions` di `_universal.md:107` (8.0.1) **tidak dibaca mekanis oleh apa pun** — builder dispatch hanya menarik `## Hard Rules emitted` (T2 P7, glob-filtered) dan `## Forbidden patterns` (T1 `DO NOT WRITE`); lens standards dapat naming/location/idiom lewat controller (prosa `review-panel.md:89`); sisanya pointer T3. Aturan komentar sampai ke implementer HANYA lewat Iron Rule 6 di file agent. Konsekuensi: **playbook per stack butuh kanal ke implementer**, bukan cukup ditulis di pack.
3. **Nilai tajam playbook per stack = daftar toolchain yang MEMBACA doc-comment di stack itu.** Aturan generik "docblock hanya bila ada toolchain yang membacanya" (Rule 6) tidak menyebut toolchain mana — di Go (`revive exported`), Ruby (RuboCop `Style/Documentation`, aktif default), C# (`CS1591` + Swashbuckle), FastAPI (docstring → OpenAPI) doc-comment justru **diwajibkan/dikonsumsi**, jadi implementer yang terlalu patuh pada "jangan komentar" bisa merahkan gate lint L0 → fix round. Playbook per stack mencegah kolisi itu; itu alasan non-gimmick-nya.
4. **Rekomendasi: 2 rilis + 1 pengukuran lapangan.** R1 (8.1.0): klausul generik masuk Rule 6 + `_universal` + lens quality + self-review; skeleton standar `## Code style (self-documenting)` di `_template.md`; `spring.md` jadi pack pertama yang diisi (playbook Java dari dokumen tim); kanal T2 `code_style_slice` di builder (spec-first). R2 (8.2.0): 24 pack sisanya + `_universal` default, `_lint.md` Check 2 jadi wajib, registry regen. Ukur: run Java tim berikutnya di ≥8.1.0 dengan `p3-comment-ratio.py` per kelas.
5. **Lima `[OPEN]` untuk owner** di §7 — yang terpenting: (i) lisensi docblock diperluas ke "public API yang melintasi batas modul/tim" (dokumen tim minta; aturan kita sekarang lebih ketat: toolchain-only), (ii) bahasa komentar kode.

---

## 1. Fakta run tim yang belum terverifikasi

| Fakta | Status | Cara verifikasi |
|---|---|---|
| Versi plugin saat run BE Java | `[OPEN]` | tanya tim (`claude plugin list`); memori 2026-09-01: tim di 7.6.x. Iron Rule 6 baru ada di 8.0.1 (2026-09-15) → hampir pasti run tim **sebelum** aturan komentar ada |
| Pack `spring.md` ter-load di run itu | `[OPEN]` | deteksi §8.5 `pom.xml`/`build.gradle` + marker `spring-boot-starter` (`scan-procedure.md:123,545`); cek `codebase-map.md` frontmatter `framework:` di vault tim |
| Contoh BAD di dokumen tim = output nyata | EST (bentuknya khas: Javadoc Indonesia di method private dengan `@param/@return/@throws` pengulang) | minta 3 file bolt dari run tim → jalankan `benchmarks/scripts/p3-comment-ratio.py` |
| Bahasa komentar diminta tim = Indonesia atau Inggris | `[OPEN]` | dokumen tim menulis contoh GOOD dalam Inggris, BAD dalam Indonesia — tidak eksplisit |

Kalau run tim memang pra-8.0.1, sebagian besar keluhan sudah tertutup oleh 8.0.1–8.0.3 (MEASURED di Laravel/TS: komentar ex-provenance −54 %, kelas docblock 19,4 % → 0 %, CHANGELOG 8.0.1 Notes). Itu bukan alasan berhenti: §2 menunjukkan sisa yang belum tertutup, dan §3 menunjukkan pack per stack belum punya kanal.

---

## 2. Peta klausul dokumen tim → permukaan plugin (MEASURED, file:line)

| # | Klausul dokumen tim | Permukaan sekarang | Status |
|---|---|---|---|
| 1 | Core principle: *code explains WHAT, comments WHY* | `agents/bolt-implementer.md:41` Iron Rule 6 kalimat 1; `_universal.md:109` | COVERED (8.0.1) |
| 2 | Alasan token (komentar dibayar tiap file masuk konteks) | Rule 6 "the next unit pays to re-read them"; angka di CHANGELOG 8.0.1/8.0.2 | COVERED |
| 3 | Avoid: ulang nama / narasi control flow / terjemahkan kode / **jelaskan perilaku standar Java** | Rule 6 larangan konkret + **tes hapus** (8.0.3): "pembaca yang paham bahasanya … kehilangan informasi?" — perilaku standar bahasa = gagal tes hapus | COVERED (8.0.3) |
| 4 | Write when: why / workaround / business rule / **side effect atau gotcha yang tidak terlihat dari signature** / `TODO`/`FIXME` | Rule 6 allow-list: business rule + sumber, workaround + alasan, regulasi, asumsi tak terlihat, `TODO`→OQ/unit | PARTIAL — tambah eksplisit: side effect, thread-safety, exception yang tidak tersirat dari nama, `FIXME` |
| 5 | Skip Javadoc: **private/package-private** self-explanatory, getter/setter, constructor sederhana, **override yang kontraknya sudah di interface** | Rule 6: getter/setter/constructor | PARTIAL — visibility + override belum disebut (generik: "anggota non-publik", "override yang kontraknya ada di interface/base") |
| 6 | Write Javadoc: **public API yang dikonsumsi modul/tim/caller eksternal**; perilaku non-obvious; class-level entry point | Rule 6 minimality: "a full docblock only when a **toolchain** reads it (typed generics, IDE contract, API/OpenAPI generator, type-checker stub)" | **GAP (arah terbalik)** — aturan kita LEBIH KETAT dari tim: konsumen manusia (tim lain) bukan lisensi. `[OPEN-1]` §7 |
| 7 | Skip `@param/@return/@throws` yang tidak menambah info | Rule 6 "never add tags that restate the signature (`@param` / `@return`)" | COVERED — tambah `@throws` di contoh (checked exception sudah ada di klausa `throws`) |
| 8 | **Naming**: spesifik > generik; boolean sebagai pertanyaan (`isValid/hasPermission/canRetry`); method berawalan verb; hindari `data/temp/obj/handle/process/manager`; koleksi plural | Tidak ada di Rule 6. Pack `## Naming standards` = case + suffix saja (`spring.md:40-59`); `_universal.md:22-37` = kolom DB (ada `is_/has_` untuk KOLOM). Self-review implementer hanya "accurate names" (`:152`) | **GAP** — stack-agnostic; rumah: implementer (`## Code organization` :142 atau Rule 6 klausul "nama yang mengerjakan penjelasan") + slot `naming` di pack |
| 9 | Quick checklist (5 item) | `bolt-implementer.md:150-152` self-review: Completeness/Quality/Discipline/Testing | PARTIAL — tambah satu kalimat: "tiap komentar lolos tes hapus; doc-comment hanya di public API / yang dibaca toolchain; nama tidak butuh komentar" |
| 10 | Prompt template ("Generate kode Java … ikuti aturan …") | = dispatch prompt + system prompt agent (Rule 6 ikut di SETIAP dispatch tanpa diketik) | COVERED oleh arsitektur — no action |
| 11 | Notes: simpan sebagai `CLAUDE.md` / project rules | Untuk run mega-sdd: otomatis (Rule 6). Untuk sesi Claude Code biasa di repo yang sama: `emit-agents-md` §Section 4 *Code style + conventions* hanya menyalin `conventions.md` (`agents-md-schema.md` §Section 4) — aturan komentar tidak ikut | OPTION R3 — tambah baris "Comment rule" + baris code style pack di §4 |
| 12 | (implisit) contoh BAD = Javadoc **berbahasa Indonesia** | `references/output-language.md`: tidak ada aturan bahasa untuk komentar kode (grep `code comment|source code|komentar` = 0); register natural-mix = narasi + dok, bukan kode | **GAP** `[OPEN-2]` §7 |

**Panel (penegas, bukan penghitung) sudah selaras:** `code-quality-reviewer.md:22` komentar-APA = Minor `comment-what:`, "missing docblock" bukan temuan; `standards-reviewer.md:31` melarang temuan missing docblock. Butuh satu tambahan kecil: `@param/@return/@throws` pengulang dan doc-comment di anggota non-publik masuk daftar bentuk `comment-what:` supaya lens bisa menamai kasus Java-nya.

---

## 3. Sensus kanal: siapa yang MEMBACA section pack (MEASURED grep, HEAD `41e0e61`)

| Section pack | Konsumen mekanis | Sampai ke | Bukti |
|---|---|---|---|
| `## Hard Rules emitted` | `build-dispatch-prompt.sh:1932` → T2 prioritas 7 `framework_pack_rules`, **glob-filtered vs `target_files`**, ladder top 5→3→1 | implementer | `context-enrichment.md:101` |
| `## Forbidden patterns` | `build-dispatch-prompt.sh:1679` → T1 anti-context `DO NOT WRITE:` (bullet `- ` saja, seluruh chain, tidak dipotong) | implementer | dibawa 8/27 file: `_template`, `_universal`, `aspnetcore`, `dotnet`, `laravel`, `laravel-base-26`, `spring`, `symfony` |
| `## Security idioms` | controller → prompt lens security | reviewer | `review-panel.md:89` |
| `## Naming standards` / `## File location standards` / `## Idioms` | controller → prompt lens standards (prosa; tidak ada `--section=` di refs execute-bolts) | reviewer | `review-panel.md:89`, `standards-reviewer.md:10,15` |
| `## Comment conventions` (`_universal.md:107`, 8.0.1) | **tidak ada** — 0 hit di `scripts/ hooks/ skills/` | pembaca manusia + pointer T3 | grep `Comment conventions` di scripts/hooks/skills = 0 |
| `laravel-base-26.md:149` aturan komentar (di bawah `## Idioms (project-specific overrides)` :135) | lens standards saja | reviewer | lens dilarang melaporkan missing docblock, jadi efek praktisnya nol untuk implementer |
| Path pack utuh | T3 pointer `build-dispatch-prompt.sh:3365` | implementer (opsional; Rule 0 membaca dispatch file, bukan pack) | lemah |
| `UI quality signatures`, `Cross-cutting concerns`, `Test patterns`, dst. | validator gate (`resolve-framework-pack.sh --section=`) | gate | bukan kanal style |

**Kesimpulan kanal:** yang sampai ke implementer dari pack hanya (a) Hard Rules (= gate, ast-grep — DILARANG untuk aturan komentar oleh F.5 "style rule, bukan gate", dan owner sudah setuju), (b) `Forbidden patterns` bullet (T1, tidak dipotong, semantik = anti-pattern yang tidak boleh digenerate), (c) pointer T3. Aturan komentar generik sampai lewat Rule 6 (system prompt agent, 0 byte per dispatch). **Delta per stack belum punya kanal.**

**Pilihan kanal untuk delta per stack:**

| Kanal | Perubahan | Biaya per dispatch (EST) | Catatan |
|---|---|---|---|
| A. Section baru `## Code style` → T2 section baru `code_style_slice` (P7b, ladder: penuh → *tool+skip* saja → drop) | builder + `context-enrichment.md` tabel prioritas + `bolt-dispatch-prompt.md` template + golden regen (5 file) + pin dispatch-parity | 400–800 B di T2 (cap 10 240; target total 9 216) | **Drop aman**: aturan generik tetap ada di Rule 6, jadi ladder boleh sampai nol. Ini yang direkomendasikan |
| B. Numpang `## Forbidden patterns` (bullet skip-list) | 0 kode; edit 25 pack | +2–3 baris T1 (~300 B), T1 tidak pernah dipotong | Hanya LARANGAN yang muat; pengecualian toolchain (`read by`) tidak punya tempat → kolisi lint Go/Ruby/C# tidak tercegah. Kalau A ditolak, B = fallback minimum |
| C. `## Idioms` | 0 kode | 0 (reviewer saja) | tidak sampai implementer — bukan solusi |
| D. Iron Rule 6 (file agent) | edit 1 file | 0 | untuk klausul **generik** (§2 #4,5,7,8,9,12) — WAJIB apa pun kanal per stack-nya |
| E. `emit-agents-md` §4 | edit skema | 0 | interop untuk sesi non-mega-sdd (permintaan "Notes" tim) — R3 opsional |

Rekomendasi: **D + A** (generik di agent, delta di pack lewat T2), B ditolak karena tidak bisa membawa pengecualian toolchain, C bukan kanal, E opsional.

---

## 4. Kenapa per stack, bukan cukup generik — daftar toolchain pembaca doc-comment (EST dari pengetahuan; **WAJIB web-verify saat authoring**, pelajaran install-deps: fakta registry upstream membusuk)

Bagian ini adalah isi sebenarnya dari "playbook per stack": aturan generiknya satu, yang berbeda per stack hanya (1) nama alat doc-comment, (2) **siapa yang membacanya** (= satu-satunya lisensi blok penuh), (3) kosakata visibility, (4) contoh penamaan idiomatik.

| Bahasa (pack) | Doc-comment | Dibaca oleh (lisensi blok penuh) | Deteksi lokal (`detect-toolchain.sh`) | Catatan kolisi gate |
|---|---|---|---|---|
| Java — `spring` | Javadoc | Checkstyle `MissingJavadocMethod`/`JavadocMethod` **bila dikonfigurasi** (scope default public); `springdoc-openapi-javadoc` (therapi) bila di classpath → deskripsi OpenAPI; Javadoc jar untuk library yang dipublikasikan. Lombok `@Getter/@Setter` → accessor generated, tanpa Javadoc | belum dideteksi (tidak ada checkstyle/spotless di `:48-94`) → `[OPEN]` tambah deteksi `checkstyle.xml` | rendah kecuali Checkstyle aktif |
| PHP — `laravel`, `laravel-base-26`, `symfony`, `slim` | PHPDoc | PHPStan/Larastan (generics `@param array<int,User>`, `@property` model, `@mixin`), Psalm; `php-cs-fixer` hanya menormalkan | `phpstan.neon*` (`:87-88`), `.php-cs-fixer*` (`:85-86`), `pint.json` (`:83`) | rendah; sudah ada precedent `laravel-base-26.md:149` |
| Python — `django`, `fastapi`, `flask` | docstring (PEP 257) | **FastAPI: docstring path-operation → `description` OpenAPI** (konsumen nyata); ruff `D*` (pydocstyle) bila diaktifkan (default OFF); Sphinx autodoc. Django: `help_text`, bukan docstring | `ruff.toml` (`:59`), `mypy.ini` (`:65`) | sedang (FastAPI) — docstring endpoint = fitur, bukan noise |
| JS/TS — `express`, `fastify`, `nestjs`, `next`, `nuxt`, `remix`, `sveltekit` | JSDoc / TSDoc | **JS polos + `checkJs`: JSDoc = sistem tipe** (express/fastify JS); `eslint-plugin-jsdoc` bila dikonfigurasi; TypeDoc untuk library. NestJS swagger membaca decorator, **bukan** JSDoc | `eslint*` (`:53-54`), `tsconfig.json` (`:55-56`), `biome*` (`:51-52`) | rendah di TS; di JS polos JSDoc tipe = WHY yang sah |
| Ruby — `rails`, `sinatra` | YARD / RDoc | **RuboCop `Style/Documentation` — AKTIF DEFAULT**: class/module top-level wajib punya komentar dokumentasi | `.rubocop.yml` (`:93-94`) | **TINGGI** — implementer yang menghapus komentar class = lint L0 merah → fix round |
| Go — `gin`, `echo`, `fiber` | doc comment `// Name …` | **`revive` rule `exported`** (default on di revive; via golangci-lint bila diaktifkan), stylecheck ST1020–ST1022 (bentuk komentar exported); konvensi Go: identifier exported punya satu kalimat doc | `golangci.y*ml` (`:73-74`), gofmt (`:71`) | **TINGGI** bila golangci-lint aktif |
| Rust — `actix`, `axum`, `rocket` | rustdoc `///` | `#![warn(missing_docs)]`/`deny` bila diset di crate root (default OFF); clippy `missing_docs_in_private_items` (pedantic, OFF); `cargo doc`. Binary crate (web service): biasanya tidak ada pembaca | clippy (`:80`), rustfmt (`:79`) | rendah kecuali `missing_docs` diset |
| C# — `aspnetcore`, `dotnet` | XML doc `///` | compiler **`CS1591`** bila `<GenerateDocumentationFile>true</GenerateDocumentationFile>` (warning; error dengan `TreatWarningsAsErrors`); **Swashbuckle `IncludeXmlComments`** → deskripsi OpenAPI; StyleCop `SA1600` bila dikonfigurasi | belum dideteksi → `[OPEN]` `dotnet format`/`.editorconfig` | **TINGGI** bila `GenerateDocumentationFile` on |

Tiga stack (Ruby, Go, C#) punya linter yang **mewajibkan** doc-comment pada surface tertentu. Di sana aturan generik "jangan tulis" tanpa pengecualian bernama = risiko fix round; ini bukti bahwa playbook per stack bukan gimmick.

---

## 5. Standar playbook: skeleton `## Code style (self-documenting)` untuk SEMUA pack (proposal)

Prinsip: **aturan generik ditulis SEKALI** (Rule 6 + `_universal.md`); pack hanya membawa **delta stack**. Tidak ada prosa generik di pack (doktrin template: "This template MUST NOT restate them"). Style rule, **bukan gate** (F.5 tetap: tidak ada validator penghitung komentar; `HARD_RULE` tidak dipakai untuk komentar).

```markdown
## Code style (self-documenting)   <!-- REQUIRED (R2) — delta stack atas Iron Rule 6 / _universal; JANGAN mengulang aturan generik -->

> Consumed by `build-dispatch-prompt.sh` (T2 `code_style_slice`, bullets only — droppable, the
> generic rule is agent-carried) and by the controller as part of the standards-lens slice.
> Style rule, never a gate (F.5). ≤ 6 bullets, ≤ 900 bytes, at most ONE bad/good pair.

- **Doc-comment tool**: <Javadoc | PHPDoc | JSDoc/TSDoc | docstring | YARD | Go doc comment | rustdoc `///` | XML doc `///`> — **read by**: <konsumen toolchain KONKRET di stack ini, atau `none by default`>. A full block is written ONLY where one of these reads it, or on public API that crosses a module/team boundary [OPEN-1].
- **Skip**: <kosakata stack untuk anggota yang TIDAK pernah dapat doc block — visibility keywords, accessor generated, constructor trivial, override yang kontraknya di interface/base, tag yang mengulang signature>.
- **Write**: <kontrak non-obvious dalam istilah stack — side effect, thread-safety, exception yang tidak tersirat dari nama, unit/nullability yang tidak dibawa tipe>.
- **Names carry the meaning**: <2–3 contoh idiomatik stack: bentuk predikat boolean, method verb-first, koleksi plural, nama kabur yang dihindari>.
- **Comment language**: <ikuti bahasa komentar kode di sekitarnya; file baru di codebase tanpa komentar → [OPEN-2]>.
```

**Contoh isi untuk `spring.md` (Java — dari dokumen tim, dipadatkan):**

```markdown
- **Doc-comment tool**: Javadoc — **read by**: Checkstyle `MissingJavadocMethod`/`JavadocMethod` when `checkstyle.xml` is present (scope default: public), `springdoc-openapi-javadoc` when on the classpath, the Javadoc jar of a published library. Otherwise nothing reads it: a full block only on public API consumed outside this module or a non-obvious contract.
- **Skip**: `private`/package-private methods with a self-explanatory name; getters/setters and Lombok-generated accessors; records; trivial constructors; `@Override` methods whose contract is on the interface; `@param`/`@return`/`@throws` that restate the signature (a checked exception is already in the `throws` clause).
- **Write**: a public method whose behaviour the name hides — retention windows, side effects, thread-safety, an unchecked exception a caller must expect (`reserveInventory` holds stock 15 min — that sentence is the Javadoc).
- **Names carry the meaning**: booleans read as a question (`isValid`, `hasPermission`, `canRetry`); methods start with the verb (`calculateTotal`, `fetchOrders`, `validateEmail`); collections are plural (`activeOrders`); never `data`, `temp`, `obj`, `handle`, `process`, `Manager` unless it is the pattern's real name.
```

**Lint (R2):** `_lint.md` Check 2 + `validate-pack.sh:146-158` menambah `## Code style` ke required-always; `_known_headers` (`:179`) ditambah `Code style`; Check baru: keempat label tebal ada + `read by` tidak kosong (boleh `none by default`) + tanpa kebocoran token lintas-framework (Check 5 sudah menjaga). Registry regen `--registry` + `--check-registry` (24 pack `full` akan `partial` sampai diisi → R2 satu commit untuk semua pack, bukan bertahap).

**Kanal (R1, spec-first):** `context-enrichment.md:88-104` tabel prioritas dapat baris **7b `code_style_slice`** — level 0 seluruh bullet, level 1 dua bullet pertama (tool+read by, skip), drop floor = section dihilangkan (aman: Rule 6 agent-carried). `bolt-dispatch-prompt.md` dapat blok `## Code style (from <pack> §Code style)` di antara *Framework pack rules* dan *Constitution clauses*. Builder: `pack_section("Code style")` chain most-specific-first, first pack wins (delta per stack tidak digabung dengan `_universal` — `_universal` hanya fallback bila tidak ada pack). Golden dispatch-parity di-regen (`GOLDEN_REGEN=1 bash tests/dispatch-parity/test-dispatch-prompt-golden.sh`) dengan alasan tercatat di CHANGELOG.

---

## 6. Rencana rilis (proposal — untuk spec sesi berikutnya)

**R1 — 8.1.0 "playbook code style: generik + Java + kanal"** (satu commit per item, suite dua tree + CI + moat hijau tiap commit):
1. `agents/bolt-implementer.md` Iron Rule 6: tambah kosakata visibility ("anggota non-publik", "override yang kontraknya di interface/base"), allow-list eksplisit (side effect, thread-safety, exception tak tersirat, `FIXME`), `@throws` di contoh tag, klausul **"nama yang mengerjakan penjelasan"** (predikat boolean, verb-first, plural, nama kabur) — atau paragraf baru di `## Code organization` :142 kalau owner tidak mau Rule 6 tambah panjang; self-review :152 dapat satu kalimat checklist. `_universal.md:107` mirror. `code-quality-reviewer.md:22` daftar bentuk `comment-what:` ditambah dua kasus Java. Pin: `tests/comment-diet/test-comment-why-rule.sh` n–r.
2. `_template.md` + `README.md` §Adding a new pack: skeleton §5 (belum wajib di lint — tier-aware, supaya 24 pack `full` tidak jatuh ke `partial` di R1). `spring.md` diisi (§5 contoh) — **verifikasi fakta Checkstyle/springdoc dulu** (Context7/web). Pin: `tests/per-stack-packs/test-code-style-section.sh` (skeleton 4 label; R1 hanya menuntut pack yang MEMILIKI section-nya valid).
3. Kanal T2 `code_style_slice` (§5 Kanal) — spec dulu (`context-enrichment.md`, `bolt-dispatch-prompt.md`), builder, golden regen, pin dispatch-parity + `tests/moat/test-dispatch-prompt-cascade.sh` tidak melonggar.
4. `[OPEN-1]`/`[OPEN-2]` sesuai keputusan owner (kalau belum diputuskan: teks tetap toolchain-only + bahasa komentar "ikuti kode sekitar", ditandai `[OPEN]` di doc, bukan ditebak).
5. CHANGELOG `[8.1.0]` + bump kedua manifest; push GitHub; SCM PENDING.

**R2 — 8.2.0 "playbook code style: 24 pack + wajib lint"**: isi section di 24 pack + `_universal` default (tabel §4 sebagai bahan, **tiap baris `read by` di-web-verify** saat authoring, versi alat dicatat di `last_verified_against`), `_lint.md` Check 2 + `_known_headers` + Check baru, registry regen, test per-stack meluas ke semua pack `full`. Satu commit per bahasa (Java sudah; PHP, Python, JS/TS, Ruby, Go, Rust, C# = 7 commit) — atau satu commit semua kalau owner mau; masing-masing dengan `validate-pack.sh --all` hijau.

**Pengukuran (bukan gate ship R1, tapi gate untuk klaim "selesai"):** run Java tim berikutnya di ≥8.1.0 (lapangan, owner/tim — perlu `claude plugin update` dulu, pelajaran headless update) → `benchmarks/scripts/p3-comment-ratio.py` per kelas (docblock / provenance / sisa) pada file bolt + hitung merah lint L0 karena doc-comment hilang (target 0) + spot-check 3 file. Dibandingkan dengan file bolt run tim yang lama kalau tim masih menyimpannya (§1). Tanpa run baru di repo ini — skenario xs/klinik kita Laravel/TS, bukan Java.

**R3 (opsional, interop):** `emit-agents-md` §Section 4 tambah baris *Comment rule* + baris *Code style* dari pack aktif (sumber dikutip `<!-- from <pack>.md §Code style -->`), supaya sesi Claude Code non-mega-sdd di repo yang sama ikut aturan (permintaan "Notes" dokumen tim) — dan `CLAUDE.md` stub `@AGENTS.md` sudah ditawarkan skill itu (`SKILL.md:75`).

**Yang sengaja TIDAK diusulkan:** validator/gate penghitung komentar (F.5), `HARD_RULE` `forbidden_pattern` untuk Javadoc di method private (= gate atas style; ast-grep rail akan memblok), aturan panjang per bahasa di Rule 6 (agent file harus tetap ramping — delta ke pack), run pengukuran baru di repo ini (bukan Java).

---

## 7. `[OPEN]` untuk owner

| # | Pertanyaan | Rekomendasi | Konsekuensi kalau salah |
|---|---|---|---|
| OPEN-1 | Lisensi doc block diperluas dari "toolchain membacanya" ke **"atau public API yang melintasi batas modul/tim"** (permintaan eksplisit dokumen tim §Javadoc)? | **Ya**, dengan tes hapus tetap berlaku pada ISI-nya (kontrak, bukan pengulangan signature) | Tidak diperluas → tim melihat aturan kita "menolak" masukan mereka; diperluas tanpa tes hapus → docblock balik lagi |
| OPEN-2 | **Bahasa komentar kode**: ikuti komentar di kode sekitar; file baru di codebase tanpa komentar → Inggris (identifier selalu Inggris)? Atau Indonesia mengikuti register narasi? | Ikuti kode sekitar (konsisten dengan ground-truth order lens standards: kode sekitar menang); default Inggris untuk kode baru | Tanpa aturan: campur Indonesia/Inggris per unit (contoh BAD tim) |
| OPEN-3 | Kanal delta stack: **T2 droppable** (rekomendasi) vs T1 tidak dipotong vs numpang `Forbidden patterns` | T2 — drop aman karena generik agent-carried; T1 menaikkan ukuran tiap dispatch tanpa katup | T1: unit besar melewati ambang pelaporan T1 (max terukur 10 874 B vs 12 288) |
| OPEN-4 | R2 satu rilis semua pack vs bertahap per bahasa | Satu rilis 8.2.0, 7 commit per bahasa, lint wajib dinyalakan di commit terakhir | Bertahap = registry `partial` berbulan-bulan |
| OPEN-5 | Rule 6 tambah panjang (klausul naming) vs paragraf baru `## Code organization` | Paragraf baru "Names do the explaining" di `## Code organization` :142 — Rule 6 = aturan komentar, naming = organisasi kode | Rule 6 jadi terlalu panjang untuk satu aturan |

---

## 7b. Amandemen setelah keputusan owner (spec `docs/superpowers/specs/2026-09-16-code-style-playbook-design.md`, 2026-09-16)

- OPEN-1 **ya**, OPEN-2 **ikuti kode sekitar**, OPEN-3 T2 droppable dengan floor = bullet pertama, OPEN-5 paragraf di `## Code organization` — semua mendarat di 8.1.0.
- **`_universal.md` TIDAK membawa `## Code style`** (koreksi §5/§6 di atas): aturan generik sudah agent-carried (Rule 6); slice universal = kirim ulang Rule 6 di tiap dispatch tanpa pack + menyeret prosa pack ke golden corpus framework-less. R2 = 24 pack saja.
- Skeleton **4 slot**, bukan 5 — "bahasa komentar" generik → Rule 6. Cap bullet **≤ 1 600 B** (MEASURED spring.md 1 554 B; estimasi 400–800 B di §3 terlalu rendah karena bullet `read by` adalah muatannya).
- Kanal terpasang: `code_style_slice` prioritas 7b (`build-dispatch-prompt.sh`), pin `tests/comment-diet/test-code-style-slice.sh`; golden dispatch-parity di-regen (hanya baris omission).

## 8. Ringkasan file yang disentuh riset ini

- `research/2026-09-16-team-feedback-java-code-style.md` — dokumen tim verbatim + header provenance (baru).
- `research/2026-09-16-code-style-playbook-research.md` — file ini (baru).
- Tidak ada perubahan di `plugins/`, `tests/`, CHANGELOG, manifest.

**NEXT SESSION:** tulis spec `docs/superpowers/specs/2026-09-1x-code-style-playbook.md` dari §5–§6 setelah owner menjawab OPEN-1/2/3 (kalau belum, spec memakai rekomendasi dan menandai `[OPEN]`), lalu R1 8.1.0: Rule 6 + `_universal` + lens quality (commit 1), `_template` skeleton + `spring.md` terisi dengan fakta Checkstyle/springdoc ter-web-verify (commit 2), kanal T2 `code_style_slice` spec-first + golden regen (commit 3), CHANGELOG + bump + push GitHub; minta tim: versi plugin saat run Java + 3 file bolt lama untuk `p3-comment-ratio.py`.
