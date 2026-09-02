# Spec — KB OQ resolution + kontrak bahasa OQ manusiawi (7.21.0)

**Dua masukan lapangan 2026-09-01/02, satu rilis karena nyentuh surface OQ yang sama:**

1. Owner: "hasil generate KB ga bisa di-resolve-oq, harusnya bisa." Root cause bukan jalur
   rusak — by design KB `[OPEN]` → PRD-kontrak §6 → propagate ke vault saat
   `generate-intent --kb` → baru resolve-oq jangkau. Tapi (a) Step-0 resolve-oq dead-end
   tanpa keterangan di KB-stage, dan (b) gap nyata: lane konsultan revamp butuh jawab
   pertanyaan legacy SEDINI mungkin (habis extract, expert masih hangat) — belum ada
   surface landasan jawaban stakeholder di KB.
2. Tim: "bahasa OQ / hasil generate seperti alien, sulit dipahami." Dua lapis: tim di 7.6
   (belum pernah lihat §Register 7.17.0) DAN kontrak penulisan teks OQ memang tipis —
   template cuma `OQ-<DOMAIN>-<NN> [P1|P2|P3] + apa yang di-resolve`, tidak ada yang
   melarang jargon internal jadi badan pertanyaan. §Register mengatur register (kaku vs
   natural); komprehensibilitas (jargon vs bahasa manusia) belum diatur.

## Lane A — resolve-oq KB mode

1. **Step 0 extended**: vault tidak terdeteksi TAPI KB terdeteksi (priority persis
   `kb-submode.md §KB auto-detection`: `.mega-sdd/knowledge-base/README.md` →
   `docs/knowledge-base/` → `docs/mega-sdd/knowledge-base/` →
   `old-reference/knowledge-base/`) → tawarkan **KB mode** via AskUserQuestion
   (keterangan: OQ §6 dijawab di KB, jawaban ikut ke vault saat `generate-intent --kb`).
   Vault DAN KB dua-duanya ada → vault menang (behavior lama); KB hanya jalur fallback.
   Tidak ada dua-duanya → STOP lama, utuh.
2. **Walk KB**: sumber = `## 6. Open Questions` tiap `<kb>/modules/*.prd.md` (tag
   `OQ-<DOMAIN>-<NN> [P1|P2|P3]` — konvensi sudah identik dengan vault). Prompt per-OQ =
   shape kanonik yang sama (4 slot + Other + Esc, keterangan rules). Perbedaan vs vault
   mode, eksplisit:
   - **No derive-vault-json** (KB tidak punya vault.json; markdown = satu-satunya state).
   - No lock check, no vault version bump. Round dicatat append ke `<kb>/README.md`
     `## Resolution rounds` (buat section bila belum ada; satu baris per round).
   - Landing per outcome: Resolve → `[x] → Resolved (stakeholder, <YYYY-MM-DD>): <answer>`;
     Defer → `[ ]` + `**Deferred**: <reason>`; OOS → `[~] → Out of scope: <reason>`.
   - **Honesty rail**: claim row di tabel §-nya TETAP `[OPEN]` (resolusi hidup di §6 dengan
     provenance stakeholder — BUKAN sitasi kode; downstream konsumsi §6). Jangan pernah
     flip marker claim jadi `[VERIFIED]`/`[INFERRED]` dari jawaban stakeholder.
3. **kb-submode routing row baru** (generate-intent --kb): §6 entry `[x]`-resolved →
   vault OQ lahir SUDAH `[x]` di `constraints.md ## Open Questions` (jawaban + provenance
   + tag kebawa; deriver otomatis map `[x]`→`resolved`); `[~]` → kebawa out_of_scope;
   unresolved `[ ]` → behavior lama utuh.
4. **Reachability** (pelajaran field-miss render-html/F-14): hand-off announce
   extract-intelligence menawarkan jawab-sekarang saat OQ `[OPEN]` > 0; description
   resolve-oq dapat trigger KB ("jawab OQ hasil extract", "resolve oq kb",
   "jawab open question kb").

## Lane B — kontrak OQ manusiawi (output-language §OQ authoring)

Rumah tunggal: `references/output-language.md` — section baru **§OQ authoring
(human-first)**, berlaku untuk SEMUA teks OQ yang DITULIS ke artifact (KB §6, vault
`constraints.md`, propagasi binding):

- Setiap OQ = pertanyaan UTUH yang bisa dijawab orang bisnis TANPA buka kode:
  (a) 1 kalimat konteks situasi dalam bahasa manusia; (b) pertanyaannya sendiri —
  jargon internal (nama SP/kolom/simbol) BOLEH sebagai penjelas dalam kurung, TIDAK BOLEH
  jadi subjek kalimat; (c) detail teknis (sitasi, marker) menyusul sebagai keterangan.
- Pasangan contoh dipin: ❌ `OQ-ACQ-03 [P1] grace_period NULL fallback semantics
  SP_CALC_DENDA?` → ✅ `OQ-ACQ-03 [P1] Kalau jatuh tempo lewat tapi masa tenggang belum
  diisi (kolom grace_period kosong — SP_CALC_DENDA:120), denda mulai dihitung dari hari
  ke berapa? [OPEN][?]`
- Tag/ID/marker tetap Tier-1 English verbatim (tidak berubah); yang diatur = badan teks.
- Pointer dari dua surface authoring: `prd-kontrak-template.md §6` (extract) dan
  `vault-core.md` aturan format OQ (generate-intent) — kontraknya SATU, di
  output-language; pointer jangan menduplikasi isi (pelajaran doc-audit dok-saling-kutip).

## Yang TIDAK berubah

- Jalur lama KB→vault→resolve tetap utuh (KB mode = tambahan, bukan pengganti).
- No-invention rail penuh di KB mode (jawaban hanya dari user sesi ini).
- vault mode resolve-oq byte-untouched di Step 0.6 dst (pin test-oq-collapse aman).
- Census validator & claim-table grammar TIDAK disentuh (resolusi hidup di §6 saja).

## Tests — `tests/resolve-oq-kb/test-resolve-oq-kb.sh`

A KB-mode section di resolve-oq SKILL (deteksi 4-path, §6 walk, no-derive, marker
formats, honesty rail claim-tetap-OPEN); B trigger KB di description; C routing row
resolved-§6 di kb-submode; D offer line di hand-off extract; E §OQ authoring di
output-language (konteks-1-kalimat + larangan jargon-sebagai-subjek + pasangan ❌/✅);
F pointer di template §6 + vault-core, tanpa duplikasi isi.

## Versions

resolve-oq 2.11.1→2.12.0 · generate-intent 2.20.0→2.21.0 · extract-intelligence
2.2.0→2.3.0 · plugin 7.20.0→7.21.0 (marketplace match).
