# 7.30.0 — `knowledge_base:` di config.yaml: KB bersama di luar project (monorepo)

**Tanggal:** 2026-09-07 · **Sumber:** run lapangan monorepo-acquisition (FE `apps/web` + BE `apps/api`,
KB domain dipasang sebagai git submodule di `knowledge/mcf-domain-knowledge/`). Owner: "gas jalan 1" —
tambah reader config supaya mega-sdd auto-detect KB bersama, bukan symlink.

## Masalah

Probe KB (`state_probes.probe_knowledge_base`, probe 8) cuma lihat 4 path DI DALAM project:
`.mega-sdd/knowledge-base/README.md` → `docs/knowledge-base/README.md` →
`docs/mega-sdd/knowledge-base/README.md` → `old-reference/knowledge-base/README.md`. Di monorepo dua
tim, KB-nya satu dan hidup di luar kedua app. Akibatnya:

- `apps/api` → `knowledge_base: absent`, padahal KB ada dua level di atas.
- `apps/web` → yang terdeteksi justru KB LAMA (copy Juli, grammar numbered-tree) yang masih tersimpan
  di `.mega-sdd/knowledge-base/` karena disitasi vault.
- Scaffold `probe_paths.knowledge_base_candidates` yang ditulis `migrate-paths.sh` sejak lama
  **tidak pernah dibaca** (`references/paths.md` sudah jujur soal ini). Key itu bentuknya list bersarang
  dan isinya cuma mengulang default — bukan alat untuk kasus ini.

Symlink `apps/<app>/.mega-sdd/knowledge-base → ../../knowledge/...` ditolak: sebagian tim di Windows,
symlink git di sana rapuh, dan untuk `apps/web` berarti menimpa KB lama yang masih disitasi.

## Bentuk (satu key, satu probe, prosa ikut)

1. **Key baru `knowledge_base:` (top-level, string path) di `.mega-sdd/config.yaml`.**
   Path ke DIREKTORI KB (yang berisi `README.md`), relatif terhadap project root, boleh absolut,
   `~` di-expand. Contoh monorepo: `knowledge_base: ../../knowledge/mcf-domain-knowledge/.mega-sdd/knowledge-base/`.
   Reader mengikuti kontrak `probe_spine`/`probe_profile`: regex satu baris, top-level saja, absen /
   tak terbaca → default (4 generasi lama, urutan tak berubah).
2. **Precedence: config menang, dan TIDAK jatuh ke default kalau path config-nya kosong.**
   `knowledge_base` yang dikonfigurasi tapi `README.md`-nya tidak ada → `present: false`,
   `configured: <path>`, `configured_missing: true`, plus satu `derived.notes` yang menyebut path-nya
   (kasus nyata: submodule belum di-init). Jatuh diam-diam ke KB lokal yang basi adalah bug yang
   memang mau dicegah — lebih baik jujur "absent, configured missing" daripada rute ke KB salah.
3. **Shape probe** dapat field `source: "config" | "default" | null`. `path` tetap path README
   (relatif seperti yang dikonfigurasi, dinormalisasi), jadi `kb_no_vault` yang memakai
   `os.path.dirname(path)` otomatis menghasilkan `generate-intent --kb=../../knowledge/.../knowledge-base`
   tanpa perubahan di jalur routing.
4. **Prosa yang menyebut urutan 4 path** diamandemen supaya konsisten dengan probe (routing-rules §probe 8,
   orchestrate-flow SKILL §status view, generate-intent SKILL baris auto-detect + `kb-submode.md`
   §KB auto-detection, `project-config.md`, README §Per-project config, komentar `paths.md` +
   scaffold `migrate-paths.sh`).
5. **Cakupan hooks: nol.** Tidak ada hot path yang membaca key ini — probe hanya jalan di
   `derive-state.sh` (script lane). Doktrin hook cost tetap utuh.

## Yang sengaja TIDAK berubah

- Validator `kb_*` di `run-analyze.sh` tetap membaca `${CWD}/.mega-sdd/knowledge-base/` — mereka
  memvalidasi KB yang DIPRODUKSI project ini (extract-intelligence). KB bersama divalidasi di repo
  asalnya sendiri; project konsumen tidak mengulang analyze KB milik orang lain.
- `generate-intent --kb=<path>` eksplisit tetap menang atas auto-detect (Rule 1 — explicit flag wins).
- `probe_paths.knowledge_base_candidates` tetap TANPA reader; komentarnya sekarang mengarahkan ke
  `knowledge_base:`. Menghapus scaffold-nya = urusan migrate-paths, bukan spec ini.

## Test

`plugins/mega-sdd/tests/state/test-derive-state.sh` +seksi f11 (5 fixture):

| Fixture | Setup | Pin |
|---|---|---|
| f11a-kb-config-external | config → `../shared-kb/kb/`, README ada di luar project, tanpa KB lokal | `present`, `source=config`, `path=../shared-kb/kb/README.md`, position `kb_no_vault`, chain `generate-intent --kb=../shared-kb/kb` |
| f11b-kb-config-missing | config → path yang tidak ada, KB lokal basi ADA | `present=false`, `configured_missing`, position BUKAN `kb_no_vault`, ada note yang menyebut path |
| f11c-kb-config-wins | config valid + KB lokal ada | `source=config`, path = yang dikonfigurasi (bukan lokal) |
| f11d-kb-default | tanpa config, KB lokal ada | `source=default`, path `.mega-sdd/knowledge-base/README.md` (pin regresi) |
| f11e-kb-config-absolute | config path absolut | `present`, `source=config` |

Ditambah satu kasus di `tests/skill-triggering/generate-intent.test.md` (GI-KB-CFG): tanpa arg
posisional, `knowledge_base:` terisi → Mode B KB sub-mode dengan `--kb=<path config>` implisit,
konfirmasi ke user tetap.

## Ditunda tercatat

- Multi-KB (list kandidat berurutan) — belum ada kasus lapangan; satu path cukup untuk monorepo dua
  tim. Kalau muncul, bentuknya `knowledge_base:` menerima list dan probe mengambil hit pertama.
- `validate-kb.sh` / analyze `kb_discovery` untuk KB eksternal — lihat §Yang sengaja tidak berubah.

Pin: test-derive-state f11a–f11e. plugin 7.29.1→7.30.0; generate-intent 2.22.1→2.23.0;
orchestrate-flow 2.28.2→2.28.3.
