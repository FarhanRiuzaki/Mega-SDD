# Pending sync decisions
**Last sync run**: 2026-09-14T17:17:18Z (detect-drift, full scan, `--hybrid --auto`, HEAD `b291f02`) · **Open items**: 8

## 1. CONFLICTs (BLOCKING — gate closed for affected units)
- None. Vault lane lite tidak punya `binding.md`. Binding per unit (`bolts/U-*/binding.json`) semuanya 0 CONFLICT, dan C-U006-A06 sudah diselesaikan KEEP_CODE di `1b87a24`.

## 2. Drift direction calls (vault stale vs code regressed — your call)
- [ ] DRIFT-01 [HIGH] decision-unwritten: route `POST /api/v1/contact-messages` ditulis manual (bukan `proxyPost`) dengan validasi server — pengecualian kedua terhadap aturan factory proxy, tidak ada ADR / klausul constitution
      (source: DRIFT-REPORT.md §DRIFT-01; anchor src/app/api/v1/contact-messages/route.ts:22-47; provenance b243a5b "feat(U-005): Add the contact-message schema and the server-validating submit route")
- [ ] DRIFT-02 [HIGH] decision-unwritten (confidence medium): `openPublicRoutes` dicek sebelum sesi/`RefreshTokenError`, exact-match pathname — mekanisme C-004 belum tercatat
      (source: DRIFT-REPORT.md §DRIFT-02; anchor src/proxy.ts:14-23; provenance a707a54 "feat(U-001): Open the three public company-profile routes in the proxy guard"; terkait OQ-AR-1)
- [ ] DRIFT-03 [HIGH] decision-unwritten: carve-out constitution A-002 untuk file yang dicadangkan Next.js (`src/proxy.test.ts`, `route.test.ts` flat di samping modulnya)
      (source: DRIFT-REPORT.md §DRIFT-03; anchors src/proxy.test.ts, src/app/api/v1/contact-messages/route.test.ts; rationale units/U-001.md:38)
- [ ] DRIFT-04 [HIGH] behavior-drift: F-U-001 cabang "server tolak → error per field" — `data.fieldErrors` dari server dibuang oleh `apiClient`, UI hanya menampilkan alert umum (jalur normal tetap memenuhi DoD lewat validasi klien dengan skema bersama)
      (source: DRIFT-REPORT.md §DRIFT-04; anchors src/app/api/v1/contact-messages/route.ts:30-38, src/libs/api/client.ts:13-16, src/features/contact/components/ContactForm/index.tsx:60; vault context.md:42-46, :51)
- [ ] DRIFT-05 [HIGH] missing-in-vault: form dikosongkan setelah sukses dan banner lama dihapus saat validasi klien gagal — tidak ada di flow/DoD F-U-001
      (source: DRIFT-REPORT.md §DRIFT-05; anchor src/features/contact/components/ContactForm/index.tsx:45-55; provenance 37ff5eb "feat(U-006): Build the public Kontak page with the contact form")
- [ ] DRIFT-06 [HIGH] missing-in-vault: `.trim()` pada name/email/message sebelum validasi — tidak ada di §Schema constraints (trim email melebihi spec U-005)
      (source: DRIFT-REPORT.md §DRIFT-06; anchor src/features/contact/schemas/contact.schema.ts:17-35; provenance b243a5b)
- [ ] DRIFT-07 [HIGH] missing-in-vault: kontrak request/response `POST /api/v1/contact-messages` (400 `VALIDATION_ERROR` + `fieldErrors`, JSON rusak → 400, key tambahan dibuang, `created_at` ditimpa, upstream gagal → 400)
      (source: DRIFT-REPORT.md §DRIFT-07; anchor src/app/api/v1/contact-messages/route.ts:25-47; provenance b243a5b)
- [ ] DRIFT-08 [HIGH] behavior-drift: `context.md:85` *Auth guard existing* + `vault.json` OQ-AR-1 `scan_citations` `src/proxy.ts:11` menggambarkan guard sebelum U-001 (anchor bergeser, tiga route publik sekarang dikecualikan)
      (source: DRIFT-REPORT.md §DRIFT-08; anchor src/proxy.ts:16-46; provenance a707a54)

## 3. Write-back drafts awaiting human triage
- None. `--auto-apply=safe` tidak diberikan, jadi tidak ada patch yang di-draft atau diterapkan. DRIFT-05, DRIFT-06, dan DRIFT-07 masuk kelas aman (HIGH + missing-in-vault + tidak `[LOCKED]` + sisi kode sudah di-commit) kalau run berikutnya memakai `--auto-apply=safe`.
