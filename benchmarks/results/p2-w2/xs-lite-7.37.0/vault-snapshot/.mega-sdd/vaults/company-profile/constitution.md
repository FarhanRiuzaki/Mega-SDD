# Project Constitution

**Status**: Active
**Version**: 1.0
**Last reviewed**: 2026-09-14
**Sign-off**: [Pending]

---

## §A. Coding standards (Non-negotiable)

- A-001: Kode domain baru mengikuti layout feature `src/features/<feature>/{components,hooks,repositories,schemas,types}` (source: CLAUDE.md §Feature-based layout)
- A-002: Modul yang punya test hidup di folder bersama test-nya (`foo/index.ts` + `foo/index.test.ts`); file tanpa test tetap flat; nama file reserved Next.js (`page.tsx`, `route.ts`, `proxy.ts`) tetap di tempatnya (source: CLAUDE.md §Stack & Commands)
- A-003: Test memakai Vitest + React Testing Library + MSW dari harness `src/test/`; `pnpm test:run` harus lulus (source: CLAUDE.md §Stack & Commands)
- A-004: Semua field form berlabel dan navigasi keyboard berfungsi (source: PRD §Non-functional — Aksesibilitas)

## §B. Security baselines

- B-001: Input pengunjung di-escape saat ditampilkan; tidak ada HTML mentah dari pengunjung — `dangerouslySetInnerHTML` tidak dipakai untuk data pengunjung (source: PRD §Non-functional — Keamanan)
- B-002: Field form kontak (nama, email, pesan) divalidasi di sisi server sebelum disimpan (source: PRD §Halaman Kontak)
- B-003: URL upstream dan bearer token tetap server-side; browser hanya memanggil proxy same-origin `/api/v1/*` (source: CLAUDE.md §Next.js API routes are thin proxies)

## §C. Architecture invariants

- C-001: Alur data page → hook → repository → `apiClient` → proxy `/api/v1` → `apiServer` → upstream; `apiServer` hanya dari route handler / RSC, `apiClient` hanya dari komponen `'use client'` (source: CLAUDE.md §Data flow, CLAUDE.md §Conventions worth following)
- C-002: Rilis ini tidak menambah autentikasi, panel admin, notifikasi email, multi-bahasa, atau CMS (source: PRD §Ruang lingkup)

## §D. Anti-patterns (from legacy / past projects)

_Tidak ada klausul — tidak ada sumber yang menyatakan anti-pattern untuk proyek ini._

## §E. Performance constraints

- E-001: Halaman statis termuat < 2 detik di koneksi 3G (source: PRD §Non-functional — Performa)

## §F. Compliance

_Tidak ada klausul — PRD tidak menyatakan kewajiban regulasi._
