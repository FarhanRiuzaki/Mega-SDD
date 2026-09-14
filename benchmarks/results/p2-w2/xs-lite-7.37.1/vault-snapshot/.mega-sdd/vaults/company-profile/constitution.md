# Project Constitution — Company Profile Mini

**Status**: Active
**Version**: 1.0
**Last reviewed**: 2026-09-14
**Sign-off**: [Pending]

---

## §A. Coding standards (Non-negotiable)

- A-001: Package manager adalah pnpm; test dijalankan dengan `pnpm test:run` (Vitest + React Testing Library + MSW) (source: CLAUDE.md §Stack & Commands; package.json:5)
- A-002: Modul yang punya test sendiri berada di folder bersama test-nya (`foo/index.ts` + `foo/index.test.ts`); file tanpa test tetap flat (source: CLAUDE.md §Stack & Commands)
- A-003: Kode domain berada di `src/features/<feature>/` dengan subfolder `components/`, `hooks/`, `repositories/`, `schemas/`, `types/` (source: CLAUDE.md §Feature-based layout)
- A-004: Form memakai react-hook-form + zod; file schema mengekspor schema + tipe inferensi + defaults (source: CLAUDE.md §Forms)

## §B. Security baselines

- B-001: Input form kontak divalidasi di sisi server sebelum disimpan (source: PRD §Halaman Kontak; PRD §Alur › F-U-001 langkah 3)
- B-002: Input pengunjung hanya ditampilkan lewat escaping bawaan React; NEVER render HTML mentah dari pengunjung (tanpa `dangerouslySetInnerHTML`) (source: PRD §Non-functional — Keamanan)
- B-003: Base URL upstream dan bearer token tetap di sisi server; browser hanya memanggil proxy same-origin `/api/v1` lewat `apiClient` (source: CLAUDE.md §Data flow; CLAUDE.md §Next.js API routes are thin proxies)

## §C. Architecture invariants

- C-001: Alur data page → hook → repository → apiClient → proxy `/api/v1` → apiServer → upstream (source: CLAUDE.md §Data flow)
- C-002: Repository mengembalikan response mentah; tidak ada `enqueueSnackbar` di repository (source: CLAUDE.md §Conventions worth following)
- C-003: `src/@core`, `src/@layouts`, `src/@menu` adalah primitive template vendored — DO NOT edit; perluas lewat `src/components/*`, `src/features/*`, `src/views/*` (source: CLAUDE.md §Template origin)
- C-004: Halaman Beranda, Tentang Kami, dan Kontak dapat diakses tanpa login (source: PRD §Latar belakang; PRD §Ruang lingkup)

## §D. Anti-patterns

- D-001: NEVER membangun autentikasi baru, panel admin, notifikasi email, multi-bahasa, atau CMS dalam rilis ini (source: PRD §Ruang lingkup)
- D-002: NEVER menampilkan foto tim — daftar tim hanya nama + peran (source: PRD §Halaman Tentang Kami)

## §E. Performance constraints

- E-001: Halaman statis termuat < 2 detik di koneksi 3G; cara ukur belum ditetapkan (OQ-CN-1) (source: PRD §Non-functional — Performa)

## §F. Compliance

- Tidak ada ketentuan kepatuhan/regulasi yang dinyatakan PRD (source: PRD — tidak ada bagian compliance).
