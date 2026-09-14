# Drift Report

**Vault**: v1.0 (last updated 2026-09-14; mode `existing`; layout 3, lane lite) — `.mega-sdd/vaults/company-profile/`
**Codebase**: `/Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-xs-lite` (commit `b291f02`; working tree bersih untuk `src/` — dua file untracked hanya internal SDD: `.mega-sdd/.cache/pack-resolver/_chain.out`, `.mega-sdd/codebase/.dirty-paths.jsonl`)
**Framework detected**: Next.js 16.2.10 (App Router) + React 19.2.3 + MUI 7 + zod ^4.3.6, pnpm@10.34.5 — dari `package.json` (tidak ada `codebase-map.md`, jadi deteksi dari manifest; satu signature, cocok dengan constraint *Stack lock-in* di vault → tidak ada `drift_framework_mismatch`)
**Drift scope**: full
**Scope hint**: Full scan (no scope hint) — invocation `--vault=.mega-sdd/vaults/company-profile --hybrid --auto`, tanpa `--scope` (bukan sync lane)
**Generated**: 2026-09-15 00:17 +0700 (2026-09-14T17:17:18Z)

**Scanned**: `src/proxy.ts`, `src/app/(blank-layout-pages)/{beranda,tentang-kami,kontak}/`, `src/app/api/v1/**`, `src/features/contact/**`, `src/views/company-profile/**`, `src/configs/companyProfile/`, `src/libs/api/{client,base-fetcher,route-handler,server}.ts`, `next.config.ts`, `package.json`, plus `git diff 6f98c10..HEAD` (seed PRD → HEAD) untuk file yang dilindungi (`package.json`, `next.config.ts`, `src/@core`, `src/@layouts`, `src/@menu`, `src/app/(blank-layout-pages)/layout.tsx`, `src/libs/api/route-handler.ts` — semuanya tanpa perubahan).
**Excluded**: `node_modules/`, `.next/`, `.mega-sdd/` (kecuali sebagai sisi vault), template vendored (`src/@core`, `src/@layouts`, `src/@menu`) selain cek diff.

## Summary

| Category | High | Medium | Low | Total |
|----------|-----:|-------:|----:|------:|
| Missing in code | 0 | 0 | 0 | 0 |
| Missing in vault | 3 | 0 | 0 | 3 |
| Name drift | 0 | 0 | 0 | 0 |
| Type drift | 0 | 0 | 0 | 0 |
| Behavior drift | 2 | 0 | 0 | 2 |
| Decision violation | 0 | 0 | 0 | 0 |
| Decision unwritten | 2 | 1 | 0 | 3 |
| **Confirmed match** | — | — | — | **27** |

> **Confidence legend** — High: exact match or unambiguous absence (action recommended). Medium: similar names, differing signatures, or partial pattern match (verify before action). Low: heuristic keyword guess (always verify manually).

**Severity**: kedelapan finding = **HIGH**. Vault ini tidak punya anotasi `mutability_source` / tier `[LOCKED]`/`[INTENT]`/`[ARTIFACT]` dan `adrs: []`, sehingga semua drift memakai default aman HIGH. Tidak ada klaim `[LOCKED]` → tidak ada CRITICAL.

**Hybrid gate (severity → chain action)**: HIGH → sinyal **PAUSE** (tampilkan ke user; chain boleh di-override dengan keputusan yang tercatat). Tidak ada halt (halt hanya untuk CRITICAL pada klaim LOCKED).

**Arah (direction-neutral)**: tidak ada finding yang menunjukkan kode menyimpang dari keputusan vault. Tujuh dari delapan finding adalah "kode lebih rinci / lebih baru daripada vault". Satu (DRIFT-04) adalah cabang flow vault yang tidak terimplementasi penuh. Arah tiap finding diputuskan manusia lewat `PENDING-SYNC.md`.

## Decision violations & decision unwritten (PRIORITY-1)

> Ini yang paling sering berkaitan dengan hutang arsitektur / kepatuhan. Review lebih dulu.

Decision violations: **0**. Vault tidak punya ADR (`vault.json adrs: []`). Klausul constitution §A–§F diperiksa di bagian *Constitution Findings* dan tidak ada yang dilanggar tanpa alasan tertulis.

### DRIFT-01 — Decision unwritten: route `POST /api/v1/contact-messages` ditulis manual, bukan lewat factory proxy (confidence: high · severity: HIGH)

**Vault**: tidak ada `D-XXX`. Satu-satunya jejak ada di resolusi OQ-DM-1 (`context.md:105`): "route handler same-origin `POST /api/v1/contact-messages` yang memvalidasi di server, lalu meneruskan via `apiServer`…". Constitution C-001 hanya mengatur alur data. Aturan rumah (`CLAUDE.md §Next.js API routes are thin proxies`): semua proxy route dibangun dengan `proxyGet/proxyPost/proxyPut/proxyDelete`, dan satu-satunya pengecualian adalah NextAuth.

**Code reference**: `src/app/api/v1/contact-messages/route.ts:22-47` — `POST` ditulis manual: `safeParse` dengan `contactMessageSchema`, mengembalikan 400 `VALIDATION_ERROR`, lalu meniru mapping status `respond()` (`src/libs/api/route-handler.ts:19-21`). Semua route lain di `src/app/api/v1/**` (roles, users, users/me, branches, permission) memakai `proxyGet`/`proxyPost`. Provenance: `b243a5b` "feat(U-005): Add the contact-message schema and the server-validating submit route".

**Drift**: kode menyimpan pengecualian kedua terhadap aturan factory proxy. Alasannya hanya ada di komentar `route.ts:22-24` dan di Context U-005, tidak tercatat sebagai keputusan vault atau klausul constitution. Alur C-001 tetap utuh (page → hook → repository → apiClient → `/api/v1` → apiServer → upstream).

**Suggested action**: (A) promosikan ke ADR / klausul constitution §C baru, misalnya "route submit publik yang butuh validasi server boleh ditulis manual; wajib meniru mapping status `respond()` dan hanya meneruskan field hasil parse"; (B) defer — catat sebagai `OQ-DC-1`.

### DRIFT-02 — Decision unwritten: allowlist halaman publik dicek sebelum sesi, dengan exact-match pathname (confidence: medium · severity: HIGH)

**Vault**: constitution C-004 menyatakan "Beranda, Tentang Kami, dan Kontak dapat diakses tanpa login". `context.md:85` menjelaskan guard existing. Mekanisme pembukaannya belum tercatat.

**Code reference**: `src/proxy.ts:14-23` — `openPublicRoutes = ['/beranda', '/tentang-kami', '/kontak']` dicek paling awal, sebelum `getServerSession` dan sebelum cabang `RefreshTokenError`. Pencocokannya exact (`openPublicRoutes.includes(pathname)`). Provenance: `a707a54` "feat(U-001): Open the three public company-profile routes in the proxy guard".

**Drift**: ada tiga keputusan yang ter-embed di kode tanpa catatan vault: (1) daftar route publik terpisah dari `publicRoutes` auth; (2) daftar itu mengalahkan pembersihan cookie `RefreshTokenError`, jadi sesi basi tidak dibersihkan saat membuka halaman publik; (3) exact match, jadi `/kontak/` (trailing slash) atau sub-path tidak ikut terbuka. Self-assessment U-001 (`bolts/_summary.md:44`) sudah menandai exact match sebagai keputusan yang belum pasti, dengan fallback `startsWith`. Confidence medium karena fakta kodenya pasti, tetapi apakah ini layak menjadi ADR adalah penilaian.

**Suggested action**: (A) catat sebagai ADR / catatan di C-004 (terkait `fallback_if_wrong` OQ-AR-1 yang sudah menyebut "daftar route publik di `src/proxy.ts`"); (B) defer sampai OQ-AR-1 dijawab.

### DRIFT-03 — Decision unwritten: pengecualian constitution A-002 untuk file yang namanya dicadangkan Next.js (confidence: high · severity: HIGH)

**Vault**: constitution A-002 — "Modul yang punya test sendiri berada di folder bersama test-nya (`foo/index.ts` + `foo/index.test.ts`); file tanpa test tetap flat".

**Code reference**: `src/proxy.test.ts` di samping `src/proxy.ts` (`a707a54`). `src/app/api/v1/contact-messages/route.test.ts` di samping `route.ts` (`b243a5b`, `9c81f94`).

**Drift**: kalau dibaca harfiah, ini pelanggaran standar §A. Tetapi kedua modul memakai lokasi/nama yang dicadangkan framework: `src/proxy.ts` adalah middleware Next.js 16, dan `route.ts` adalah filename wajib App Router. Keduanya tidak bisa dipindah ke `folder/index.ts`. U-001 menyatakan alasan ini secara eksplisit (`units/U-001.md:38`), dan U-005 menempatkan `route.test.ts` bersebelahan lewat `target_files`. Modul baru lain sudah mengikuti A-002 (`src/configs/companyProfile/`, `src/views/company-profile/{HomeView,AboutView}/`, `src/features/contact/components/ContactForm/`). Jadi pengecualian ini hidup di units dan kode, tetapi tidak ada di constitution.

**Suggested action**: (A) tambahkan carve-out di A-002: "kecuali file dengan lokasi/nama yang dicadangkan Next.js — `src/proxy.ts`, `**/route.ts`, `**/page.tsx` — test-nya bersebelahan"; (B) defer.

## Flow drift

### DRIFT-04 — Behavior drift: F-U-001 cabang "server tolak → error per field" tidak menampilkan error per field (confidence: high · severity: HIGH)

**Vault**: F-U-001 (`context.md:42-46`): `S3 "Server memvalidasi tiga field"` → `D{"Tiga field valid?"}` -- tidak → `S6 "Tampilkan error per field, isi form tetap terisi"`. DoD `context.md:51`: "Email tidak valid ditolak dengan pesan error di field email".

**Code reference** (rantai):
- `src/app/api/v1/contact-messages/route.ts:30-38` — penolakan server mengembalikan 400 dengan `data.fieldErrors` per field.
- `src/libs/api/client.ts:13-16` — `onError` hanya melempar `new Error(error.message)`, sehingga `data.fieldErrors` dibuang.
- `src/features/contact/components/ContactForm/index.tsx:60` — menampilkan hanya `error.message` sebagai satu `Alert` umum.
- Error per field di UI hanya berasal dari validasi klien `zodResolver(contactMessageSchema)` (`ContactForm/index.tsx:41`, `helperText` di `:74`, `:92`, `:110`).
- Test `ContactForm/index.test.tsx:145-157` hanya memeriksa alert umum untuk respons 400.

**Drift**: kalau server yang menolak (validasi klien terlewati, skema klien/server berbeda versi, atau upstream mengembalikan envelope gagal), pengunjung hanya melihat "Data yang dikirim tidak valid. Periksa kembali isian form." tanpa penanda di field. Nilai form tetap terisi, jadi bagian itu sesuai DoD. **Konteks**: di jalur normal DoD tetap terpenuhi karena klien memakai skema zod yang sama, sehingga penolakan server praktis sulit terjadi. Tetap dilaporkan karena flow vault secara eksplisit menaruh cabang error per field setelah validasi *server*.

**Suggested action**: (A) fix code — petakan `data.fieldErrors` ke `setError` react-hook-form. Ini butuh jalur yang meneruskan payload error, sementara `apiClient` di U-006 ditandai "consume as-is", jadi perlu unit baru; (B) update vault — nyatakan bahwa error per field adalah validasi klien dengan skema bersama, dan penolakan server ditampilkan sebagai pesan umum; (C) defer ke OQ.

### DRIFT-05 — Missing in vault: form dikosongkan setelah sukses; banner lama dihapus saat validasi klien gagal (confidence: high · severity: HIGH)

**Vault**: F-U-001 `S5 "Tampilkan pesan sukses Pesan terkirim di halaman yang sama"`. DoD hanya mengatur "Form tetap terisi setelah gagal validasi" (`context.md:52`). Tidak ada ketentuan tentang isi form setelah sukses.

**Code reference**: `src/features/contact/components/ContactForm/index.tsx:45-51` — `onSuccess: () => resetForm(contactMessageDefaults)` mengosongkan form setelah pesan tersimpan. `:53-55` — `onInvalid = () => resetMutation()` menghapus banner sukses/error dari percobaan sebelumnya ketika percobaan baru gagal validasi klien. Provenance: `37ff5eb` "feat(U-006): Build the public Kontak page with the contact form". Kedua perilaku tercatat sebagai keputusan tidak pasti di self-assessment U-006 (`bolts/_summary.md:54-55`).

**Suggested action**: (A) tambahkan langkah ke diagram F-U-001 (`S5 --> "Kosongkan form"`) dan ke DoD; (B) hapus perilaku dari kode kalau tidak diinginkan (fallback sudah tercatat di `_summary.md`).

## Schema drift

Tidak ada Missing in code, Name drift, atau Type drift. Entity `contact_messages` cocok (lihat *Confirmed matches*).

### DRIFT-06 — Missing in vault: normalisasi input (trim) sebelum validasi pada ketiga field (confidence: high · severity: HIGH)

**Vault**: §Schema constraints (`context.md:75-77`): `name` ≤100, `message` ≤2000, `email` format valid ≤255. DoD `context.md:53`: "nama wajib ≤100 karakter, email wajib format valid, pesan wajib ≤2000 karakter". Trim tidak disebut.

**Code reference**: `src/features/contact/schemas/contact.schema.ts:17-35` — `.trim()` dijalankan pada `name`, `email`, dan `message` sebelum `min`/`max`/format. Akibatnya: batas panjang dihitung setelah trim; nama/pesan yang hanya berisi spasi ditolak sebagai "wajib diisi"; nilai yang diteruskan ke upstream sudah di-trim (`route.ts:42`). Trim pada `email` melampaui spesifikasi U-005, yang hanya menyebut trim untuk `name` dan `message` (`units/U-005.md:72`; self-assessment `bolts/_summary.md:51`). Provenance: `b243a5b`.

**Suggested action**: (A) catat aturan normalisasi di §Schema constraints; (B) hapus `.trim()` pada email kalau tidak diinginkan.

## Endpoint drift

### DRIFT-07 — Missing in vault: kontrak request/response `POST /api/v1/contact-messages` (confidence: high · severity: HIGH)

**Vault**: endpoint hanya disebut di prosa resolusi OQ-DM-1 (`context.md:105`): route same-origin → `apiServer` → `POST /v1/contact-messages` dengan `created_at` dicap server. Tidak ada kontrak respons.

**Code reference**: `src/app/api/v1/contact-messages/route.ts:25-47`:
- body JSON rusak → diperlakukan sebagai input tidak valid → 400 (`:27`);
- gagal validasi → 400 `{ success: false, code: 'VALIDATION_ERROR', message: 'Data yang dikirim tidak valid. Periksa kembali isian form.', data: { fieldErrors } }`, tanpa panggilan upstream (`:30-38`);
- payload upstream hanya `name`, `email`, `message`, `created_at`: key lain dari klien dibuang dan `created_at` dari klien ditimpa (`:41-42`);
- envelope gagal dari upstream → 400, sukses → 200 (`:47`).

Semua perilaku ini dikunci oleh `route.test.ts:61-150`. Provenance: `b243a5b`.

**Suggested action**: (A) tambahkan kontrak endpoint ke `context.md` (subbagian di F-U-001 atau §Constraints › Integration boundary). Ini juga bahan konfirmasi kontrak upstream yang masih tertunda di OQ-DM-1; (B) defer.

## Constraint drift

### DRIFT-08 — Behavior drift: constraint *Auth guard existing* dan anchor-nya menggambarkan guard sebelum U-001 (confidence: high · severity: HIGH)

**Vault**: `context.md:85` — "`src/proxy.ts:11-28` mengarahkan pengunjung tanpa sesi ke `/login` dan memantulkan user bersesi dari `publicRoutes` ke `/home`". `vault.json` → `open_questions[OQ-AR-1].scan_citations` berisi `src/proxy.ts:11` (juga di `.plan-patch.json`).

**Code reference**: `src/proxy.ts:16` (`openPublicRoutes`), `:21-23` (early return `NextResponse.next()`), `:27` (`publicRoutes`), `:30-46` (guard `RefreshTokenError` / bounce / redirect ke `/login`). Baris 11 sekarang kosong. Provenance: `a707a54`.

**Drift**: kalimat constraint masih benar untuk semua path kecuali tiga halaman publik, yang sekarang dikecualikan. Anchor `:11-28` dan `:11` sudah bergeser. Tidak ada tindakan kode yang disarankan.

**Suggested action**: (A) update vault — anchor diganti ke `src/proxy.ts:16-46` dan ditambah "kecuali `openPublicRoutes` (`/beranda`, `/tentang-kami`, `/kontak`)". `vault.json` diperbarui lewat `derive-vault-json.sh` dari markdown dan patch `scan_citations`, bukan diedit tangan; (B) biarkan sampai OQ-AR-1 dijawab (URL bisa berubah lagi).

## Constitution Findings

**Hash check**: sha256(`constitution.md`) = `07ea4a4d993569ebe95204cc47a4f7568a9f5bd8dcea2c479bc19b65b143033f`, sama dengan `vault.json constitution_hash`, jadi constitution tidak berubah sejak generasi. Tidak ada `binding.md`: lane lite memakai binding per unit di `bolts/U-*/binding.json` (schema `unit-binding/1`, tanpa `constitution_hash`). Karena itu pemeriksaan `constitution_drift_detected` **tidak berlaku** (bukan dilewati).

**Precision**: tidak ada `codebase-map.md` (`precision_tier: ast` tidak tersedia), jadi probe klausul memakai text-grep dan presisinya lebih rendah. ast-grep terpasang, tetapi tidak ada rule YAML deterministik untuk klausul vault ini.

### Critical violations (§B Security, §F Compliance)
- Tidak ada.
  - B-001: pass — `route.ts:28-39` menjalankan `safeParse` sebelum `apiServer.post`.
  - B-002: pass — grep `dangerouslySetInnerHTML` di `src/` hanya menemukan komentar header. `ContactForm/index.tsx:60` merender `error.message` sebagai teks (escaping React).
  - B-003: pass — `contact.repository.ts:22-23` memakai `apiClient` ke `/v1/contact-messages`, dan tidak ada base URL upstream di kode klien baru.
  - §F: tidak ada klausul.

### Standard violations (§A Coding, §C Architecture, §E Performance)
- A-002 — `src/proxy.test.ts`, `src/app/api/v1/contact-messages/route.test.ts` flat di samping modulnya → pengecualian untuk file yang dicadangkan framework, ada alasannya di U-001, lihat **DRIFT-03** (advisory, bukan pelanggaran tanpa alasan).
- C-001 — alur tetap. Penyimpangan dari aturan factory proxy di `CLAUDE.md` → **DRIFT-01**.
- E-001 — **manual review needed**: target "< 2 detik di 3G" belum punya cara ukur (OQ-CN-1). Observasi (low confidence, bukan pelanggaran): `HomeView/index.tsx:11` dan `AboutView/index.tsx:10` memakai `'use client'` walaupun isinya statis (self-assessment U-003), sehingga JS klien bertambah.

### Advisory (§D Anti-patterns)
- D-001: pass — tidak ada dependency baru (`package.json` tanpa perubahan sejak `6f98c10`) dan tidak ada auth, panel admin, email, i18n, atau CMS baru.
- D-002: pass — `AboutView/index.tsx:62-70` hanya merender nama + peran, dan tipe `CompanyTeamMember` (`src/configs/companyProfile/index.ts:17-20`) hanya punya `name`/`role`. `CustomAvatar` di `HomeView/index.tsx:75` adalah nomor layanan, bukan foto tim.
- Carried dari `bolts/U-004/findings.json` (bukan drift baru): U-004 F-4 — test "tanpa foto" hanya memeriksa elemen `img`, jadi MUI Avatar akan lolos. Ini celah coverage test.

## OQ cross-reference

- Tidak ada token `OQ-{CODE}-{N}` di `src/`.
- **OQ-DM-1** (resolved, runner-assumed): kode mengikuti resolusi (`route.ts:43` → `POST /v1/contact-messages`). Konfirmasi kontrak upstream oleh tim backend **masih diperlukan**.
- **OQ-AR-1** (deferred): kode memakai rekomendasi `/beranda`, `/tentang-kami`, `/kontak` (`src/proxy.ts:16`; `src/app/(blank-layout-pages)/{beranda,tentang-kami,kontak}/page.tsx`). Redirect `/` → `/home` tidak berubah. Ini sesuai rekomendasi, **bukan drift**.
- **OQ-FL-1** (deferred): copy error sementara ada di `contact.schema.ts:18-35` dan `route.ts:20`.
- **OQ-FL-2** (deferred): terkonfirmasi tidak ada navigasi ke `/tentang-kami` di `src/`. Grep non-test hanya menemukan `src/proxy.ts:16`.
- **OQ-CN-1** (deferred): tidak ada pengukuran performa di kode/test.

## Confirmed matches

> Dicantumkan agar jelas semuanya sudah dievaluasi. Tidak perlu tindakan.

1. Entity `contact_messages` ↔ `ContactMessage` (`src/features/contact/types/index.ts:14-22`): `id` number, `name`, `email`, `message`, `created_at`. `created_at timestamp` dikirim sebagai string ISO-8601 (representasi JSON, bukan type drift).
2. `name` ≤100 ↔ `varchar(100)` — `contact.schema.ts:21`.
3. `email` format valid, ≤255 ↔ `varchar(255)` — `contact.schema.ts:28-30`.
4. `message` ≤2000 (kolom `text`, batas lewat validasi) — `contact.schema.ts:35`.
5. `created_at` dicap server, nilai dari klien ditimpa — `route.ts:41-42`.
6. F-U-001 S1: Halaman Kontak ada — `src/app/(blank-layout-pages)/kontak/page.tsx`.
7. F-U-001 S2: field Nama / Email / Pesan + tombol Kirim — `ContactForm/index.tsx:62-124`.
8. F-U-001 S3: validasi server sebelum simpan — `route.ts:28-39`.
9. F-U-001 S4: simpan lewat `apiServer.post('/v1/contact-messages')` sesuai OQ-DM-1 — `route.ts:43`.
10. F-U-001 S5: "Pesan terkirim" tampil di halaman yang sama — `ContactForm/index.tsx:59`.
11. F-U-001 S6 (jalur klien): error per field + nilai tetap terisi setelah gagal — `ContactForm/index.tsx:41,74,92,110`; tidak ada reset di jalur gagal.
12. DoD "email tidak valid → error di field email" (jalur klien) — `contact.schema.ts:30` + `ContactForm/index.tsx:91-92`.
13. C-001 alur data: page → `useSubmitContactMessage` (`useContact.ts:19`) → `submitContactMessage` (`contact.repository.ts:22-23`) → `apiClient` → `/api/v1/contact-messages` → `apiServer` → upstream.
14. C-002: tidak ada `enqueueSnackbar` di repository (maupun di hook/komponen contact).
15. B-002: tidak ada `dangerouslySetInnerHTML` di `src/`.
16. B-003: browser hanya memanggil proxy same-origin lewat `apiClient`.
17. C-003: tidak ada perubahan di `src/@core`, `src/@layouts`, `src/@menu` (`git diff 6f98c10..HEAD` kosong).
18. C-004: tiga halaman terbuka tanpa login — `src/proxy.ts:16-23`; ketiganya ada di route group `(blank-layout-pages)` dan layout grup tidak diubah.
19. Stack lock-in: `package.json` tidak berubah; Next 16.2.10, React 19.2.3, zod ^4.3.6, pnpm@10.34.5.
20. Integration boundary: tidak ada database/ORM baru; penyimpanan lewat upstream.
21. Root redirect `/` → `/home` (`next.config.ts:5-13`) tidak berubah.
22. Konten statis dari file konfigurasi — `src/configs/companyProfile/index.ts:30-69`: nama, tagline, tepat 3 layanan, 3 paragraf profil (PRD: 2–3), tim nama + peran.
23. D-001: tidak ada auth / admin / email / i18n / CMS baru.
24. D-002: daftar tim tanpa foto — `AboutView/index.tsx:62-70`.
25. Beranda → Kontak (`HomeView/index.tsx:55-63`, `href='/kontak'`); Tentang Kami → Beranda (`AboutView/index.tsx:76`, `href='/beranda'`).
26. NFR Aksesibilitas: semua field berlabel (`label` pada `CustomTextField`), daftar tim semantik (`ul`/`li` + `role='list'`), elemen native untuk keyboard. Confidence medium, belum ada uji keyboard di browser.
27. NFR Responsif Beranda: `Grid size={{ xs: 12, md: 4 }}` (`HomeView/index.tsx:72`). Confidence medium: jsdom tidak punya layout engine, jadi viewport 375px belum diuji di browser.

## Suggested next actions

Semua finding **di-queue ke `PENDING-SYNC.md`** untuk triage manusia. Tidak ada write-back vault (`--auto-apply=safe` tidak diberikan) dan tidak ada perubahan kode.

| Finding | Severity | Entity / area | Source mutability | Resolution path |
|---|---|---|---|---|
| DRIFT-01 | HIGH | `POST /api/v1/contact-messages` (route manual) | inferred (tanpa anotasi) | Triage: ADR / klausul §C baru, atau `OQ-DC-1` |
| DRIFT-02 | HIGH | `src/proxy.ts` `openPublicRoutes` | inferred | Triage: ADR / catatan C-004, atau tunggu OQ-AR-1 |
| DRIFT-03 | HIGH | constitution A-002 | inferred | Triage: carve-out A-002 (update constitution) |
| DRIFT-04 | HIGH | F-U-001 cabang penolakan server | inferred | Triage: fix code (unit baru) atau update flow vault |
| DRIFT-05 | HIGH | F-U-001 reset form setelah sukses | inferred | Triage: update flow vault atau hapus perilaku (eligible `--auto-apply=safe`) |
| DRIFT-06 | HIGH | `contact_messages` normalisasi trim | inferred | Triage: update §Schema constraints (eligible `--auto-apply=safe`) |
| DRIFT-07 | HIGH | kontrak endpoint | inferred | Triage: tambah kontrak ke `context.md` (eligible `--auto-apply=safe`) |
| DRIFT-08 | HIGH | `context.md:85` + `scan_citations` OQ-AR-1 | inferred | Triage: perbarui anchor/kalimat constraint |

Jalur resolusi: (1) triage manual `PENDING-SYNC.md`; (2) jalankan ulang `/mega-sdd:sync`; (3) `--auto-apply=safe` hanya untuk DRIFT-05/06/07 (HIGH + missing-in-vault + tidak `[LOCKED]` + sisi kode sudah di-commit). DRIFT-01/02/03 (decision unwritten), DRIFT-04 dan DRIFT-08 (behavior drift) tidak masuk kelas aman. Tidak ada rute `resolve-oq` untuk finding drift.

## Notes & caveats

- Deteksinya heuristik (grep + baca file, tanpa AST/type-check). Confidence tiap finding dicantumkan.
- Keputusan dideteksi dari kode karena vault tidak punya ADR. Anggap "Decision unwritten" sebagai pemicu review, bukan vonis.
- Probe constitution memakai text-grep (tidak ada `codebase-map.md`), presisinya lebih rendah.
- `--hybrid`: tidak ada `--auto-gate`/`--reuse-bolt-snapshots`, jadi ini full scan baru. Snapshot postflight (`bolts/U-*/postflight.json`, semua `status: pass`) hanya dipakai sebagai konteks, bukan pengganti scan. Pemetaan severity → chain action hybrid gate tetap diterapkan (HIGH → PAUSE).
- Journal dirty (`.mega-sdd/codebase/.dirty-paths.jsonl`, untracked) hanya berisi edit sesi bolt 2026-09-14 yang semuanya sudah di-commit (`a707a54`…`cdbdccb`). Tidak ada perubahan `src/` yang belum di-commit, jadi finding mencerminkan HEAD `b291f02`.
- **Observasi internal vault (bukan drift kode, tidak di-queue)**:
  - `units/_index.md` masih menulis status `pending` untuk keenam unit, padahal `vault.json changelog` mencatat `bolt_completed` U-001…U-006.
  - `vault.json` OQ-FL-2 `text` terpotong ("PRD memberi tombol Beranda"), dan teks OQ lain berakhir dengan "—". Ini artefak derivasi dari tanda `→` di markdown.
  - `context.md:83` dan constitution A-001 mengutip `package.json:5`, padahal `packageManager` ada di `package.json:6` (baris 5 = `"private": true`). `package.json` tidak berubah sejak `6f98c10`, jadi kutipannya sudah meleset satu baris sejak generasi.
  - `.mega-sdd/state.json` (snapshot derive-state 2026-09-14T16:15Z) dibuat sebelum bolt dan belum diperbarui.
- **Metadata vault (Step 6)**: tidak ada write-back, jadi versi vault tetap **v1.0** dan `vault.json` **tidak disentuh**. **Penyimpangan layout-3**: Step 6 menargetkan Changelog di `vault.md` (legacy: `00-index.md`), padahal vault layout-3 tidak punya `vault.md`, dan changelog-nya hanya ada di `vault.json` (ditulis lewat `derive-vault-json.sh --event`). Karena cabang tanpa-write-back mewajibkan `vault.json` tidak disentuh, sesi drift ini dicatat di sini: **drift session 2026-09-14T17:17:18Z — detect-drift full scan @ `b291f02`, 8 finding (8 HIGH), 27 confirmed match, 0 write-back, 8 di-queue ke `PENDING-SYNC.md`.**
- Framework yang terdeteksi bisa salah. Kalau begitu, jalankan ulang dengan `--scope=<dirs>` eksplisit.
