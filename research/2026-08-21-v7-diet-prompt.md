# PROMPT — mega-sdd v7 "Weighted Routing + Diet"

> Paste ke Claude Code di root repo `mega-sdd-github`. Permission: full bypass (boleh delete). Bahasa narasi: Indonesia + English technical terms.

---

Lo adalah maintainer `plugins/mega-sdd`. Tujuan sesi ini: bikin plugin **ringan, berbobot (weighted), dan tetap grounded** — tanpa over-engineering. Ada 3 pekerjaan, kerjakan berurutan, satu commit per fase, dan berhenti minta approval gue di setiap gate yang gue tandai **[GATE]**.

## Konteks & masalah

- Plugin ini = pipeline spec-driven: PRD/idea → intent → vault → bind → units → bolts (coding) → emit dokumen (PRD/FSD/SIT/UAT). Itu nilai intinya. Jangan diubah.
- **Masalah 1 — semua dipukul rata.** Routing sekarang keyword/CWD-based (`using-mega-sdd` anchor + `commands/mega-sdd.md` front door): begitu ada `.mega-sdd/` di CWD atau keyword SDD, semua prompt — termasuk "cari bug di fungsi X" — masuk front door → `ground.sh` → `derive-state` → status view → chain proposal → hooks gate. Feedback dev: bug hunt kecil bisa 20 menit, padahal tanpa skill cuma beberapa menit.
- **Masalah 2 — terlalu banyak script.** `scripts/` ±116 file shell (±36k baris) + `scripts/_lib/*.py` 12 file (±4k baris), hooks 7 event (PreToolUse nge-gate Skill|Bash|Edit|Write, PostToolUse hampir semua tool). Gue nggak tau mana yang masih load-bearing.
- **Masalah 3 — vault 7 file** (`00-index` … `06-constraints`) kebanyakan untuk LLM; bikin konteks boros dan justru nambah peluang halu karena info tersebar/duplikat antar file.

Prinsip yang **tidak boleh dilanggar**: anti-halu tetap ada (claim → cite anchor PRD/code; uncertain → OQ, bukan tebakan; binding CONFLICT tetap blocking sebelum units; `target_files` whitelist di unit). Yang boleh dipotong adalah *mekanisme*-nya, bukan *jaminan*-nya.

---

## Fase 0 — Audit & baseline (read-only) **[GATE]**

Jangan edit apapun dulu. Hasilkan `research/<tanggal>-v7-diet-audit.md` berisi:

1. **Reachability map script.** Untuk setiap file di `scripts/`, `scripts/_lib/`, `hooks/`: siapa yang memanggil (grep dari `skills/*/SKILL.md`, `skills/*/references/*`, `commands/*.md`, `hooks/*`, `agents/*.md`, script lain). Tandai: `LOAD-BEARING` (dipanggil oleh gate/validator yang menjaga anti-halu), `CONVENIENCE` (report/format/telemetry/tooling opsional), `ORPHAN` (tidak ada yang memanggil), `DUPLICATE` (fungsinya sudah ada di script lain atau bisa dilakukan LLM dengan instruksi 3 baris). Sertakan jumlah baris.
2. **Python audit.** Per file `_lib/*.py`: siapa importer-nya, apakah perlu Python (parsing AST/YAML kompleks yang rapuh di bash) atau bisa dihapus/diganti. Default sikap: **hapus** kecuali ada alasan konkret yang lo tulis.
3. **Trace "cari bug" end-to-end.** Simulasikan prompt `"ada bug di <fungsi>, tolong cari"` di project dengan `.mega-sdd/` ada: list urutan hook → anchor → front door → script yang jalan, dan perkiraan token/waktu per langkah. Ini baseline yang mau kita pangkas.
4. **Vault 7-file audit.** Per file 00–06: apa isinya, siapa konsumennya (bind/units/bolts/emit/scripts mana yang parse), field mana yang duplikat antar file, mana yang hanya "nice to have".
5. Rekomendasi awal: target jumlah script, jumlah python, jumlah file vault, dan daftar yang mau dihapus. Angka harus dari hasil grep, bukan perkiraan.

Berhenti, tunjukkan ringkasannya, tunggu approval gue.

---

## Fase 1 — Weighted routing (pembobotan) **[GATE sebelum implementasi]**

Tambahkan **task weight classifier** yang deterministik dan murah (tanpa script berat, tanpa model call tambahan) di dua tempat: anchor `using-mega-sdd` (routing core, yang di-inject session-start) dan front door `commands/mega-sdd.md`. Tiga tier saja:

| Tier | Sinyal (cukup satu yang kuat) | Yang jalan |
|---|---|---|
| **S — direct** | bug hunt / fix 1–3 file / pertanyaan tentang kode / refactor lokal / tidak menyebut PRD, vault, unit, bolt, spec, sync; tidak ada artifact arg | **Tidak lewat pipeline.** Jawab seperti Claude Code biasa. Boleh baca vault *read-only* hanya jika user sebut nama domain yang ada di vault — maksimal 1 file, tanpa ground/derive-state/status view. Hook PreToolUse tidak boleh nge-gate Edit/Write di tier ini. |
| **M — delta** | perubahan fitur kecil pada vault existing, "tambah field", "ubah flow X", brief 1–2 kalimat yang match entity di vault | Lane delta yang sudah ada (`diff-vault` → re-bind scoped → `units --reconcile` → bolts stale/new). **Skip** advisor, analyze penuh, lint penuh, modules-summary, emit proposal. Satu konfirmasi. |
| **L — full** | PRD/BRD file, legacy dir, `--greenfield`, epic baru, `/mega-sdd` eksplisit dengan artifact, `sync` setelah banyak perubahan | Chain penuh seperti sekarang. |

Aturan:
- Klasifikasi ditulis sebagai **tabel keputusan di markdown** (anchor), bukan script baru. Kalau benar-benar perlu bantuan mekanis, satu fungsi kecil di `derive-state.sh` yang output `weight: S|M|L` ke `state.json` — bukan file baru.
- Default saat ragu: **S**, lalu tawarkan satu baris "mau masuk pipeline? (`/mega-sdd …`)". Kebalikan dari sekarang (sekarang default-nya masuk pipeline). User selalu bisa override: flag `--weight=S|M|L` atau `--full`.
- Tier S harus terukur: untuk prompt bug-hunt, **nol** script mega-sdd yang dieksekusi selain hook session-start yang sudah ada. Buktikan lewat trace di Fase 0 (before) vs after.
- Hooks: review matcher `PreToolUse` (Skill|Bash|Edit|Write) dan `PostToolUse` (hampir semua). Gate hanya boleh aktif ketika sebuah chain mega-sdd **sedang berjalan** (ada marker/state aktif), bukan cuma karena ada `.mega-sdd/` di CWD. Kalau marker ini belum ada, buat yang paling sederhana (satu file state yang sudah ada, jangan tambah mekanisme baru).
- Tulis ke `references/halt-protocol.md`/`routing-rules.md` seperlunya, dan update README (bagian routing) + CHANGELOG.

Tunjukkan desain tabel + perubahan file yang akan disentuh, tunggu approval, baru implement.

---

## Fase 2 — Script & Python diet

Berdasarkan audit Fase 0 yang sudah gue approve:

- **Hapus** semua `ORPHAN` dan `DUPLICATE`. Hapus test yang hanya menguji script yang dihapus.
- **Python:** hapus yang tidak punya alasan konkret. Kalau ada yang tersisa, gabung ke satu modul kalau masuk akal; tidak boleh ada `.py` yang hanya dipanggil oleh satu script yang juga bisa dihapus.
- **CONVENIENCE** (telemetry, token-cost report, seeding budget, replay, predictive-preflight, ui-quality, dsb): default **hapus** kecuali ada user-facing value yang jelas dan murah. Tulis alasan 1 baris per item yang lo pertahankan.
- **LOAD-BEARING** dipertahankan tapi cek duplikasi antar validator (contoh: `validate-handoff-*`, `validate-*-consistency`, `build-dispatch-prompt.sh` 3.7k baris — apakah sebagian bisa jadi instruksi markdown di skill daripada script generator?). Prinsip: **script untuk hal yang harus deterministik** (AST check, parity/consistency check, state derivation, gate); **markdown/LLM untuk hal yang judgment-based**. Jangan sebaliknya.
- Setelah hapus: jalankan `tests/graph/run-all.sh` + test lain yang relevan, pastikan hijau atau dihapus bersama script-nya. Grep ulang: tidak boleh ada referensi ke file yang sudah tidak ada (SKILL.md, references, README, hooks, CLAUDE.md).
- Laporkan before/after: jumlah file, jumlah baris, daftar yang dihapus + alasan satu baris.

---

## Fase 3 — Vault simplification **[GATE]**

Target: dari 7 file menjadi **3–4 file** yang lebih mudah dipegang LLM, tanpa mengurangi grounding. Usulan awal (lo boleh argue):

- `vault.md` — overview + architecture + decisions (satu narasi, section `##` jelas, setiap claim punya `[src: PRD §x]` atau `[src: path:line]`).
- `model.md` — data model + flows (entity & flow itu yang paling sering di-bind; jangan dipisah dari satu sama lain).
- `constraints.md` — hard rules + constraints + **Open Questions** (OQ tinggal di satu tempat, bukan tersebar).
- `vault.json` tetap sebagai index mesin (derive dari md seperti sekarang); `00-index.md` dihapus kalau isinya bisa di-derive.

Syarat:
- Setiap section punya format yang stabil dan **tidak bisa diisi asal**: kalau tidak ada sumber, tulis `OQ-xxx`, bukan kalimat. Kasih template per file di `generate-intent/references/`.
- Update semua konsumen (bind, units, bolts, emit-*, `derive-vault-json.sh`, `vault_md.py` kalau masih ada, tests fixtures `tests/graph/fixtures/derive-vault/`). Sediakan migrasi untuk vault 7-file lama lewat `commands/migrate-paths.md` yang sudah ada — jangan bikin command baru.
- Tunjukkan contoh vault hasil dari `tests/scenarios/sample-prd-clinic.md` sebelum/sesudah, tunggu approval, baru ubah konsumen.

---

## Rambu umum

- **Jangan over-engineer.** Kalau solusi butuh file/mekanisme baru, tanya dulu apakah bisa pakai yang sudah ada. Tidak boleh menambah script baru netto; target akhir jumlah script turun signifikan.
- Jangan menyentuh gate anti-halu: binding gate, OQ business human-decided, `target_files` whitelist, hard-rule pre/post-flight.
- Satu commit per fase, pesan commit jelas, CHANGELOG entry versi 7.0.0 (breaking: vault layout + routing default).
- Setiap fase ditutup dengan ringkasan pendek: apa yang dihapus, apa yang berubah, apa yang gue perlu putuskan.
- Verifikasi akhir: ulangi trace "cari bug" dari Fase 0 — harus tier S, nol script mega-sdd, dan jawabannya setara dengan Claude Code tanpa plugin.

Mulai dari Fase 0.
