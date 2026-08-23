# Balasan untuk feedback tim (Igoo0/feedback-mega-sdd, diukur di 6.12.0)

Terima kasih — ini feedback terbaik yang pernah diterima plugin ini. Rasio 17.9:1 per unit, 5.8:1 spec:kode, 12/26 validator SKIP: itu pengukuran, bukan kesan. Dan framing kalian sendiri jujur: masalahnya **time-to-first-code + fixed overhead**, bukan total biaya. Kami pakai framing itu apa adanya di bawah.

Konteks penting yang kalian catat sendiri: pengukuran kalian jalan di **6.12.0** dengan drift versi (empat instalasi dormant di cache). Sejak itu program v7 (7.0.0→7.5.0, ~40 rilis) menyerang persis kelas keluhan kalian. Dokumen ini memetakan tiap keluhan → status di **7.5.0**, dengan bukti — dan mengakui yang belum kejawab.

## Peta keluhan → status di 7.5.0

| Keluhan kalian (6.12.0) | Status | Bukti |
|---|---|---|
| 7j45m brief→kode pertama; intent 14,4 mnt/turn | **Sebagian kejawab — tolong re-test** | Express spine kini default (OQ dibatch di muka, auto-defer tercatat); context statis 10 lane pipeline turun **728k→656k token (−10%)** (tracer, baseline di `benchmarks/`); context sampai bolt pertama **−34%** pada benchmark task-class; anchor session-start kini berbobot S/M/L (proyek kecil memuat anchor slim). Angka wall-clock yang jujur harus datang dari mesin kalian — lihat §Ajakan re-test |
| Overhead hook terasa (sesi berat) | **Kejawab di 7.5.0** | Spawn per event dipangkas: UserPromptSubmit 4→**1** proses, PreToolUse Edit 4→**1**, PostToolUse 5→**2**, Stop 13→**4**, SessionStart 16→**2**; fan-out validator saat sesi armed **93→1 spawn (0 python)**. Terukur: pajak hook chain 30-call = **3,8 s** di macOS; proyeksi laptop kantor (CrowdStrike ~220 ms/spawn) ~15 s @30–40 call — dulu ~2 menit. Harness pin: `tests/weighted-routing/test-spawn-ceilings.sh` |
| **Bobot spec tidak menyesuaikan ukuran** (17.9:1 di unit 22 baris; 28 OQ untuk 3 screen) | **BELUM kejawab — prioritas 1 kami berikutnya, desain sedang di gate** | Kalian benar: routing v7.1 menskalakan panel review + model, TIDAK menskalakan dispatch prompt & kedalaman vault. Rencana: tier `xs` per-unit (dispatch prompt XS = frontmatter + requirements + hard rules + anchors + acceptance test saja; target rasio unit kelas 22-baris ≤5:1) + `project_scale` di vault (XS tidak mengemisi bagian opsional; ambang auto-resolve OQ teknis naik — OQ bisnis tetap keputusan manusia). Rail anti-halu tidak dilonggarkan: XS memangkas *muatan*, bukan *bukti* |
| 12/26 validator SKIP karena pack `_universal` | **Sebagian; sisanya masuk desain yang sama** | Basis angka kalian kami reproduksi persis: roster 6.12.0 = 26 boundary. Di 7.5.0 roster = **23** (`conflict_classification`, `domain_rules`, `vault_binding_coverage` dihapus/di-demote; `starterkit-metrics` menyusul di 7.5.0 — state-nya terbukti nol pembaca). Sisa SKIP-by-construction di pack universal (validator yang menganggur karena pack tidak mendeklarasikan konvensi) direncanakan **tidak di-dispatch sama sekali** — daftar per pack dihitung sekali |
| `/mega-sdd` "NEVER registered"; wrapper resolve ke instalasi 6.6.0 | **Bug kalian terkonfirmasi + FIXED** | Rekomendasi №2 kalian tepat: wrapper lama membaca `installed_plugins.json[0]` buta — di mesin dengan instalasi dormant, `[0]` bisa menunjuk versi tua. Wrapper v2 kini memilih entry `scope: "user"` dengan **versi tertinggi** (tie → `lastUpdated` terbaru), dan wrapper v1 yang sudah terpasang di-refresh otomatis saat session start. Test: `tests/hooks/front-door-wrapper.test.sh`. Surface command juga sudah dirapikan jadi 3 verb + 3 one-timer (6.0.0/7.4.0) |
| TOKEN-COST-REPORT kosong; atribusi cost nyasar | **Kejawab dengan cara berbeda: dihapus by design (7.3.0)** | Keputusan sadar: cost accounting di dalam plugin selalu proxy yang bisa nyasar (persis yang kalian alami). Seluruh lane observability dihapus; atribusi cost = tanggung jawab AI gateway kantor, yang melihat token sebenarnya. Kontraknya: `docs/gateway-contract.md` (tag `mega-sdd-trace:turn` baris pertama tiap turn SDD) |
| Turn 14 menit tanpa artefak antara → terasa freeze | **Sebagian** | Tiap fase menulis artefak on-disk yang bisa diintip saat jalan (vault incremental, `binding.md` + blockers, ledger + commit per bolt), dan 7.5.0 menambah notice `additionalContext` real-time (edit file ter-LOCK → satu baris konteks, 0 fork). Turn generate-intent yang panjang = akar yang sama dengan keluhan waktu; fase program berikutnya (script-ification) menyerang persis itu |
| Figma slicing berat/lama; detail melenceng dari PNG | **Direncanakan: plugin `mega-sdd-extras`** | Kalian pemakai nyata workflow design→code — persis syarat yang dipasang waktu `slice-design` dihapus dari core (7.4.0). Rencana: revive sebagai plugin **extras** terpisah di marketplace yang sama, **per-page** (batch 4 page = sumber beratnya), dan pakai **koneksi Figma MCP langsung** begitu akun kalian jalan — PNG membuang token desain (spacing/warna/komponen), makanya detail melenceng. Core tidak terbebani |

## Cara update yang benar (sekaligus membereskan drift versi kalian)

Drift yang kalian alami (empat instalasi dormant, wrapper nyangkut di 6.6.0) sekarang punya dua obat:

1. **Update**: `/plugin marketplace update mega-sdd` → `/reload-plugins` → konfirmasi versi di `/plugin` = **7.5.1** (patch yang membawa wrapper fix di bawah). (CI kami sekarang punya guard: versi manifest wajib == tag CHANGELOG terbaru, jadi "rilis tanpa bump" tidak bisa lolos lagi.)
2. **Wrapper**: tidak perlu apa-apa — session start berikutnya me-refresh wrapper ke v2 yang version-aware. Kalau mau langsung: `bash <installPath>/scripts/install-front-door.sh --force`.

Floor versi Windows tetap berlaku: laptop kantor minimal 5.9.0; 7.5.0 sudah diverifikasi jalur dispatch-nya via simulasi ntpath dan diukur spawn-nya — tapi belum ada yang menjalankannya di mesin Falcon fisik, jadi kalau kalian update duluan, kabari hasilnya (runbook: `research/2026-08-23-v7.5.0-office-verification-runbook.md`; kalau rusak, revert path-nya tercatat di sana).

## Ajakan re-test

Ulangi skenario yang sama (3 screen statis, brief yang sama) di 7.5.1 dan ukur dua angka yang kalian ukur dulu: **wall-clock brief→kode pertama** dan **rasio instruksi:kode di unit terkecil**. Kami sengaja tidak mengklaim angka wall-clock dari lab — mesin kalian (Windows + Falcon) adalah kondisi yang sebenarnya, dan pengukuran kalian yang pertama sudah terbukti bisa dipercaya. Prediksi kami yang bisa ditagih: overhead hook per sesi turun ~8×, context per fase turun 10–34% tergantung lane, dan kalau angka 17.9:1 belum turun signifikan — memang belum: itu menunggu tier XS di atas, dan angka kalian jadi baseline resminya.

---

*Dokumen ini bagian dari triage `research/2026-08-23-team-feedback-triage.md`. Pertanyaan/temuan baru: buka issue atau tulis balik di dokumen feedback kalian.*
