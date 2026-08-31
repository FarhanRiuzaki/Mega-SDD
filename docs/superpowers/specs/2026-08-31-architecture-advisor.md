# 7.14.0 — Architecture advisor (bentuk minimal): konsultasi arsitektur target di atas KB

**Tanggal:** 2026-08-31 · **Keputusan user:** "gas di sisi enhance layer mega-sdd dulu" — konteks: revamp core multifinance (.NET + SP-heavy), user tidak pegang detail legacy; AI berperan konsultan yang menerima legacy code.

## Masalah

Pipeline menjawab "sistem ini NGAPAIN" (extract-intelligence, deskriptif) tapi tidak punya tempat baku untuk "arsitektur target-nya SEBAIKNYA apa". Praktik lapangan (HOST-AS400) menaruh topologi+ADR di vault.md — ditulis ad-hoc, tanpa prosedur, tanpa jejak opsi yang ditolak. Untuk user yang tidak tahu detail legacy, langkah ini paling butuh disiplin: rekomendasi harus dari bukti KB + jawaban manusia, bukan "best practice" mengambang.

## Bentuk (MINIMAL — reference + wiring, BUKAN skill baru)

Sesuai doktrin no-gimmick + saran "ukur dulu": v1 = satu reference prosedur + dua kalimat wiring + test struktural. Promosi ke skill/routing keyword sendiri DITUNDA sampai ada bukti pemakaian lapangan (revamp user = field test pertama).

1. **`plugins/mega-sdd/references/architecture-advisor.md`** (plugin-root ref, pola model-tiers/halt-protocol) — prosedur 4 langkah:
   - **Langkah 1 — Evidence digest dari KB**: constraint yang KELIHATAN dari kode, tiap butir bersitasi KB (coupling antar modul via objek DB bersama, volume/beban yang terlihat, batch window/job, titik integrasi eksternal, permukaan regulasi, permukaan `[LOCKED]` terpadat).
   - **Langkah 2 — Constraint census (fakta yang TIDAK kelihatan dari kode)**: `AskUserQuestion` batched, keterangan per opsi (kontrak OQ-keterangan): ukuran+skill tim, kematangan ops, batasan hosting/regulator, budget/timeline, kebutuhan koeksistensi (strangler vs cutover), target NFR. Tidak terjawab → OQ `deferred` tercatat, BUKAN diasumsikan.
   - **Langkah 3 — Opsi (2–3)**: per opsi: topologi (diagram **Mermaid wajib** — mandat flows), kandidat stack, fit terhadap TIAP constraint census + bukti, biaya/risiko, jalur migrasi. Rekomendasi boleh dan ditandai sebagai rekomendasi.
   - **Langkah 4 — Keputusan → ADR**: user mengetok → tulis `knowledge-base/decisions/ADR-NNN-<slug>.md` (template di ref: Status/Context bersitasi/Decision/Options-considered dengan alasan tolak/Consequences + blok klaim ber-grammar `[INTENT]` supaya vault bisa mengutipnya). Belum diketok → `Status: proposed` + OQ.
   - **Rail di paling atas**: proposal-first selamanya — advisor TIDAK PERNAH memutus; tiap klaim rekomendasi wajib sitasi KB atau jawaban census; unknown tetap OQ. Bahasa output Tier-3 = Indonesia + istilah teknis English.
2. **Wiring extract-intelligence** (SKILL 2.1.0): hand-off announce Step 5 menawarkan konsultasi advisor (muat ref) SEBELUM `generate-intent --kb` bila arsitektur target belum diputuskan — tawaran (advisory), bukan auto.
3. **Wiring generate-intent** (SKILL 2.19.0, satu kalimat + kb-submode.md): `--kb` mengonsumsi `knowledge-base/decisions/ADR-*.md` `Status: accepted` sebagai dokumen input sah (keputusan manusia = source class yang sama dengan PRD); klaim vault yang lahir darinya mengutip ADR-nya. `Status: proposed` TIDAK dikonsumsi sebagai keputusan — muncul sebagai OQ.

## Rails (moat-check)

- No fabrication utuh: ADR = dokumen keputusan manusia (source sah); advisor tidak menulis klaim tak bersumber ke vault.
- Human-decision surface = proposal-first (kelas moat).
- Zero perubahan gate/hook. Zero biaya saat tidak dipakai (ref dimuat on-demand).

## Test

`tests/architecture-advisor/test-advisor-wired.sh`: ref ada + ToC (>100 baris) + rail proposal-first + census manusia + mandat Mermaid + template ADR ber-`[INTENT]` + keterangan; extract-intelligence me-route ke ref (one-level rule); generate-intent/kb-submode menyebut konsumsi `decisions/ADR-*` accepted-only.

## Ditunda (tercatat, menunggu bukti lapangan dari revamp user)

Routing keyword sendiri ("konsultasi arsitektur", "tentuin arsitektur"); promosi ke skill penuh; integrasi context7/WebSearch baku di Langkah 3 (hari ini: model boleh riset live, tidak diwajibkan prosedur).
