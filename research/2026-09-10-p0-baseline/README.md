# v8 P0 — baseline 7.31 terdekomposisi per fase (runbook + hasil)

**Status:** RUNBOOK SIAP — hasil **BELUM ADA** (butuh dua run interaktif oleh owner; angka lab tidak pernah dipakai buat klaim waktu — konvensi P5/A7 "never self-reported").
**Keputusan yang bergantung padanya:** gate owner 2026-09-10 — *"Kill-criterion: pra-kode < 25 % time-to-first-code ⇒ berhenti di P1 (JIT bind saja)."* P2 (`plan` + `context.md`) hanya jalan kalau angka ini lolos.
**Spec:** `docs/superpowers/specs/2026-09-10-v8-fused-pipeline-design.md` §0 (baris "BELUM TERBUKTI") + §7 P0.

## Kenapa runbook ini ada

P5 (`research/2026-08-04-p5-measurement-runbook.md`) mengukur end-to-end: klasik 1h53m / express 1h45m net ke bolt pertama. Yang TIDAK ada: pembagian waktu itu ke **pra-kode** (intent → bind → units) vs **bolt-1** (dispatch → commit unit pertama) di arm express. Dekomposisi klasik (dari timeline P5) = 155 m pra-kode vs 43 m bolt-1, tapi itu arm 5.9.0. v8 hanya melipat pra-kode; kalau di 7.3x pra-kode sudah kecil, fusion tidak membayar. Angka itu yang diukur di sini.

## Alat (sudah ada di repo)

`research/2026-08-04-p5-extract.py` sekarang mencetak **phase decomposition** setelah tabel P5 (ditambahkan 2026-09-10): batas fase = record transkrip deterministik (dispatch `Skill` `mega-sdd:*` main-lane, dispatch `Agent` `bolt-implementer`, `Bash` `ground.sh`/`derive-state.sh`), tiap segmen dapat gross/wait/net/raw/cw, lalu dua baris **PRE-CODE** (start → dispatch bolts pertama) dan **BOLT-1** (dispatch → commit unit pertama) + baris `pre-code share of net time-to-first-code: N%` yang langsung dibandingkan ke kill-criterion. Konvensi wait/idle/cw identik dengan P5 (tidak diubah). Smoke-tested 2026-09-10 pada transkrip nyata: jumlah net segmen == net endpoint.

## Dua skenario

| Arm | PRD | Skala (`derive-project-scale.sh`, MEASURED) | Repo | Task class |
|---|---|---|---|---|
| **xs-3screen** | `research/2026-09-10-p0-baseline/prd-3screen-xs.md` (rekonstruksi "3 screen statis" tim; 3 halaman + 1 form + 1 entitas + 1 flow) | `{"project_scale":"xs","screens":3,"entities":1,"flows":1}` | fresh clone `training-nextjs` @ `c6821ad` (starterkit Next.js yang sama dengan P5) → `Project/TRAINING/p0-xs-arm/` | XS greenfield — baseline resmi tier XS tetap angka tim (Windows+Falcon); angka ini = pembanding lab yang dilabeli |
| **clinic** | `tests/scenarios/sample-prd-clinic.md` | `standard` (7 screen / 4 entitas / 6 flow) | fresh clone yang sama → `Project/TRAINING/p0-clinic-arm/` | standard greenfield, ~10 unit — kelas yang dipakai P2 untuk ukur context-rot PLAN |

Fixture xs sengaja di `research/` bukan `tests/scenarios/`: sweep korpus `tests/size-weighted/test-project-scale.sh` §12 memin "semua PRD di `tests/scenarios/*.md` = standard" — fixture xs di sana akan mematahkan pin itu.

## Prosedur (owner menjalankan; satu run per arm, n=1 — disclosed)

1. **Plugin = 7.31.0** (rilis P0). Update paksa sebelum launch (resep terbukti `headless-plugin-update`): `claude plugin marketplace update` lalu `claude plugin update -y`; cek `/plugin` menunjukkan 7.31.0. Jangan `git pull` saja — cache tidak ikut.
2. Siapkan clone: `git clone <training-nextjs> p0-xs-arm && cd p0-xs-arm && git checkout c6821ad && npm install` (npm install DI LUAR clock; P5 juga begitu). Salin PRD ke `PRD/prd-company-profile.md`. Ulangi untuk `p0-clinic-arm` dengan `PRD/prd-clinic.md`.
3. Sesi Claude Code **baru** di clone, `/model opus` (paritas model dengan kedua arm P5 — confound terbesar yang bisa dikontrol).
4. Minta polos: *"jalankan mega-sdd dari PRD/prd-company-profile.md sampai bolt pertama"*. Jawab OQ dengan tempo natural (waktu jawab = human-wait, dikurangkan). Jangan `--classic`, jangan `--lean`, jangan flag lain — default 7.31.0 apa adanya.
5. Stop minimum = commit `type(U-XXX):` pertama (endpoint primer). Boleh lanjut sampai semua unit untuk angka sekunder.
6. Setelah selesai: `/mega-sdd:analyze` (counterweight kualitas), lalu serahkan **path transkrip `.jsonl`** + `git log --format="%h %cI %s"`.
7. Ekstraksi (siapa pun, deterministik): `python3 research/2026-08-04-p5-extract.py <transcript.jsonl> <first-unit-commit-iso>` → salin tabel P5 + tabel fase + baris share ke §Hasil di bawah, label **MEASURED**.

Catatan jujur: (a) n=1 per arm — variansi run tidak terukur, disclosed; (b) mesin lab (macOS) ≠ mesin tim (Windows+Falcon) — angka wall-clock absolut bukan klaim, yang dipakai = **rasio** pra-kode/bolt-1 (kill-criterion adalah rasio, sengaja); (c) kalau run terputus/kompaksi, catat — ekstraktor menghitung gap > 10 menit sebagai idle.

## Aturan keputusan (dikunci sebelum angka ada)

| Hasil | Keputusan |
|---|---|
| share pra-kode < 25 % di **kedua** arm | v8 lane BUILD tidak membayar → **P2 tidak dibangun**; P1 (JIT bind + grammar unit) tetap jalan (bukti mandiri). |
| share ≥ 25 % di salah satu arm | P2 CONDITIONAL lanjut sesuai gate (context-rot + conflict-at-dispatch diukur di P2). |
| ekstraktor tidak menemukan dispatch `execute-bolts`/`bolt-implementer` | run tidak lewat pipeline → ulangi; bukan data. |

Angka pembanding yang sudah ada (P5, klasik 5.9.0, MEASURED): pra-kode 155 m vs bolt-1 43 m ⇒ share ≈ 78 %. Kalau 7.31 masih di kelas itu, kill-criterion tidak menyala.

## Hasil

_Belum ada. Isi tabel di bawah dari output ekstraktor, jangan dari ingatan._

| Arm | plugin | model | gross → ep1 | human-wait | **net → ep1** | PRE-CODE net | BOLT-1 net | **share pra-kode** | cw tok pra-kode / bolt-1 | ASK events | OQ (vault.json) | rework commits | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| xs-3screen | 7.31.0 | opus | — | — | — | — | — | — | — | — | — | — | — |
| clinic | 7.31.0 | opus | — | — | — | — | — | — | — | — | — | — | — |

Transkrip + `git log` yang dipakai: _(path, commit endpoint)_.
