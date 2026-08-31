# 7.15.0 — update-plugin cache sweep (dormant version dirs, confirm-first)

**Tanggal:** 2026-08-31 · **Permintaan user:** "ketika mega-sdd update plugin bisa auto remove atau hapus cache ga? supaya pas running yg jalan pasti yg latest."

## Masalah (terukur di mesin owner hari ini)

`~/.claude/plugins/cache/mega-sdd/mega-sdd/` menumpuk 8 direktori versi (6.12.0 → 7.8.0); `installed_plugins.json` hanya mereferensikan 7.8.0 → 7 direktori dormant. Kelas bug lapangan yang sama dengan drift tim (№B: wrapper nyangkut di 6.6.0 karena instalasi dormant). Resolver modern sudah kebal (wrapper v2 = scope user + versi tertinggi; walker fallback ground.sh = semver terbaru), tapi tumpukan dormant (a) menyesatkan manusia saat debug versi, (b) memperbesar permukaan kelas bug "resolver salah pilih" berikutnya, (c) buang disk.

## Bentuk — Step 5.5 di `commands/update-plugin.md` (prosedur command, zero kode baru)

Setelah Step 5 (report + nudge cache refresh):

1. Derive `REFERENCED` = semua versi mega-sdd yang muncul di `~/.claude/plugins/installed_plugins.json` (python one-liner, scope apa pun — bukan cuma [0], pelajaran wrapper).
2. `DORMANT` = direktori di `cache/mega-sdd/mega-sdd/` yang TIDAK ada di `REFERENCED`. Kosong → tulis "cache bersih", selesai.
3. **SATU AskUserQuestion** (pola batch-confirm install-deps; keterangan Indonesia): daftar versi dormant + ukurannya, versi aktif yang DIPERTAHANKAN, dan peringatan eksplisit: *jangan hapus kalau ada sesi Claude Code lain yang masih jalan dengan versi lama — sesi berumur panjang bisa masih memegang path dormant*. Opsi: **Hapus** (recommended) / **Biarkan**.
4. Pada "Hapus": `rm -rf` per direktori, dengan guard path — HANYA path yang match `~/.claude/plugins/cache/mega-sdd/mega-sdd/<semver>` persis; tidak pernah glob di luar prefix itu; versi `REFERENCED` tidak pernah masuk daftar.
5. Catatan konvergensi: versi aktif-lama baru jadi dormant SETELAH user menjalankan `/plugin marketplace update` + `/reload-plugins` — jadi run update-plugin BERIKUTNYA yang menyapunya. Dua kali update berturut-turut = cache konvergen ke satu versi.

## Rail

- **Tidak pernah silent auto-delete** — konfirmasi selalu (destruktif + hazard sesi paralel); "auto" yang diminta user dipenuhi sebagai "satu konfirmasi batch di dalam alur update", bukan tanpa-tanya.
- Versi yang direferensikan `installed_plugins.json` TIDAK PERNAH dihapus, scope apa pun.
- Hard rules command yang ada tetap: hanya beroperasi di `~/.claude/plugins/`, tanpa git destruktif, tanpa auto-restart.

## Kejujuran klaim

Sweep ini = higiene + pengecil permukaan bug; yang MENJAMIN "yang jalan pasti latest" tetap `/plugin marketplace update` + `/reload-plugins` (dan wrapper v2 + governance gateway `plugin_version` yang sudah ada). Command mengatakan ini eksplisit — tidak menjual sweep sebagai jaminan.

## Test

`tests/surface/test-update-plugin-sweep.sh` — pin struktural: Step 5.5 ada; derive REFERENCED dari installed_plugins.json (bukan `[0]`); AskUserQuestion + keterangan + peringatan sesi-lain; guard prefix path; klausul "referenced never deleted"; klausul kejujuran (sweep ≠ jaminan latest).
