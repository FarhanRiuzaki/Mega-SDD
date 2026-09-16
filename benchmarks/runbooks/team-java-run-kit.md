# Kit pengukuran run Java tim — bukti lapangan playbook code style (8.1.0 / 8.2.0)

**Untuk siapa:** tim yang menjalankan mega-sdd di proyek backend Java (Spring). Kit ini yang menutup gate bukti "playbook code style selesai" — angka dari repo plugin (skenario Laravel/TS) tidak bisa menggantikannya.
**Status:** MENUNGGU TIM (belum ada data). Setelah diisi, hasilnya masuk `research/2026-09-15-v8-p3-report.md §6h` atau doc riset baru.

## 0. Yang kami butuh dari run LAMA (kolom *before*) — kalau masih ada

1. Versi plugin saat run lama: `claude plugin list` (atau `cat ~/.claude/plugins/installed_plugins.json | grep -A2 mega-sdd`). Masukan tim ditulis untuk run **sebelum 8.0.1**, jadi kemungkinan 7.x.
2. 3 file hasil bolt dari run lama (file `.java` yang dibuat implementer, apa adanya — jangan dirapikan dulu). Kalau repo-nya masih ada, cukup `git log --grep='SDD-PROVENANCE' --oneline | head` dan sebutkan commit pertama–terakhir bolt.

## 1. Update plugin dulu (wajib — `git pull` saja tidak meng-update cache)

```bash
claude plugin marketplace update
claude plugin update mega-sdd -y
claude plugin list | grep mega-sdd      # harus ≥ 8.2.0
```

## 2. Jalankan seperti biasa

Pipeline normal (`/mega-sdd` → plan → execute-bolts) di proyek Java yang sama / sejenis. Tidak ada flag khusus. Yang berubah otomatis di ≥ 8.1.0: Iron Rule 6 (komentar KENAPA, tes hapus, docblock hanya bila ada pembaca atau public API lintas modul), dan dispatch tiap unit membawa section `## Code style` dari `spring.md` (Javadoc: dibaca Checkstyle bila `checkstyle.xml` ada, springdoc bila `therapi-runtime-javadoc` di classpath).

## 3. Ukur (± 5 menit, dari root repo Java)

```bash
# base = commit SEBELUM bolt pertama; head = commit bolt terakhir (default HEAD)
python3 <path-ke-plugin-repo>/benchmarks/scripts/p3-comment-ratio.py . <base-commit> --json comment-ratio.json
```

Yang dilaporkan skrip (MEASURED, per file dan total): `code`, `comment`, `docblock` (Javadoc), `provenance` (trailer mega-sdd — 2 baris, jangan dihapus), `source_anchor`, dan rasio `comment/code` dengan & tanpa provenance.

Tambahkan dua angka manual:

| Angka | Cara |
|---|---|
| Merah lint L0 karena doc-comment HILANG | hitung finding `MissingJavadocMethod`/`JavadocMethod` (Checkstyle) atau warning springdoc di log run; target **0** |
| Spot-check 3 file | buka 3 file bolt; tulis komentar yang tersisa: kelas KENAPA (aturan bisnis + sumber, workaround, side effect) atau APA (ulang signature, `// Step 1`) |

## 4. Kirim balik

- `comment-ratio.json` + dua angka di atas + versi plugin + (kalau ada) 3 file run lama.
- Pembanding yang sudah ada dari repo plugin (Laravel/TS, bukan Java): rasio docblock/provenance/sisa 0,065/0,128/0,140 → 0,000/0,043/0,059 setelah 8.0.2 (`CHANGELOG.md [8.0.3] Notes`).

## 5. Kalau hasilnya masih berisik

Kirim contoh komentarnya. Aturan per stack ada di satu tempat — `plugins/mega-sdd/references/framework-conventions/spring.md §Code style (self-documenting)` — dan diubah lewat rilis, bukan lewat prompt per run. Jangan menambahkan validator penghitung komentar (keputusan F.5: aturan gaya, bukan gate).
