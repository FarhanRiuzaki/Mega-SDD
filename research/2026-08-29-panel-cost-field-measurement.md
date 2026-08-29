# Review-panel cost — field measurement (HOST-AS400 / dd9000-gate)

**Tanggal**: 2026-08-29
**Sumber**: e2e run nyata, vault `dd9000-gate` (30 unit), gate DD9000 bank — bukan fixture, bukan estimasi.
**Status**: RESEARCH — belum ada spec, belum ada perubahan kode.

## 1. Biaya terukur per bolt (dilaporkan operator dari run berjalan)

| Tahap | Token | Waktu |
|---|---|---|
| Implementer round 1 | ~70k | 10 mnt |
| 4 lensa panel (paralel) | **~267k** | 4–6 mnt |
| Implementer round 2 | ~70k | ~10 mnt |
| **Per unit** | **~400k** | **~25 mnt** |

Proyeksi 30 unit: ~150 dispatch, **~12M token**, belasan jam wall-clock.

**Panel = 67% biaya token per unit.** Implementer dua ronde = 35%.

## 2. Tier router: `minimal` tidak terjangkau, `full` 100%

`scripts/resolve-review-tier.sh` dijalankan atas 30 unit vault ini (+ pack `elysia.md`):

```
full: 30/30   standard: 0/30   minimal: 0/30
```

Distribusi sinyal yang menyala:

| Sinyal | Menyala |
|---|---|
| 3 `file_count` (≥4 target_files) | 22/30 |
| 4 `vocabulary` | 18/30 |
| 6 `risk_field` (high\|critical) | 18/30 |
| 1 `auth_globs` | 2/30 |
| 2 `manifest` | 1/30 |

**Mekanismenya, bukan stempel risknya.** Predikatnya `if fired: tier = "full"` — OR atas enam predikat yang mengukur hal yang sama sekali berbeda. `file_count >= 4` itu fakta **ukuran**, bukan fakta risiko, dan dia kontributor terbesar. Hapus sinyal 6 seluruhnya pun masih ~28/30 `full`. Dengan enam predikat longgar di-OR, P(minimal satu menyala) → 1 di proyek nyata.

**Klaim yang terbantah oleh instrumentasi sendiri**: header skrip menyatakan rewrite P3 "makes `minimal` reachable". Diukur di vault 30-unit hidup: `minimal` = 0/30.

## 3. Router signal→lensa: diukur, TIDAK sepadan (−14%)

Peta relevansi yang diuji (setiap sinyal memberi lensa yang dibenarkannya, bukan keempatnya):

- `spec` — selalu (moat)
- `standards` — selalu (sonnet, murah)
- `quality` — `file_count ≥3` ∪ `risk: high|critical`
- `security` — `auth_globs` ∪ `manifest` ∪ `constitution_b` ∪ `vocabulary`(di-scope ke §Hard rules/Acceptance) ∪ `risk: critical`
- `design` — ui_bearing (tidak berubah)

Bobot token per lensa ≈ 267k/4, opus (quality, security) lebih mahal dari sonnet (spec, standards, design).

```
sekarang : 8670k token panel (30 unit)
usulan   : 7470k token panel  (−14%)
```

Scoping `vocabulary` ke seksi kontrak saja: 18/30 → 13/30 (hit di `## Implementation steps` 17×, `## Context (read first)` 9×, `## Goal` 8× = narasi, bukan kontrak).

**Kesimpulan: −14% tidak membenarkan sebuah spec.** Panel tetap 7.5M. Router bukan fat-nya.

## 4. Fat yang sebenarnya — dua kandidat, urut leverage

### 4a. Ronde 2 yang tidak diwajibkan kontrak (~70k + 10 mnt/unit = −17.5% token, −40% wall clock)

`review-panel.md §Attempt rounds` — Round-1 status mapping:

> Critical + temuan di balik spec-❌ masuk sebagai `open`; **Important/Minor masuk sebagai `advisory`** — recorded, surfaced, **never gating**.

Ledger hidup `bolts/U-001/findings.json`:

```json
{"id":"F-001","lens":"standards","severity":"important","status":"open", ...}
```

`important` distempel `open`. Kalau status itu bertahan sampai merge, dia menarik satu ronde fix (70k + 10 mnt) yang kontraknya sendiri bilang **tidak boleh** dipicu Important. Satu-satunya temuan sejauh ini adalah nit penamaan `nextCursor` → `next_cursor`.

Catatan kedua: skema ledger di disk (`unit_id`, `head_sha`, `round`, `lenses_reported`, `lenses_pending`) **berbeda** dari skema terdokumentasi (`schema`, `unit`, `attempt`, `findings`). Controller mengarang bentuk sendiri; `lenses_pending` tidak ada di kontrak manapun.

BELUM TERVERIFIKASI: panel U-001 masih 3 lensa pending, merge belum jalan. Bisa jadi `open` cuma placeholder pra-merge dan merge akan me-remap ke `advisory`. **Harus diperiksa sebelum ronde 2 menyala** — itu 70k + 10 mnt di unit ini saja.

### 4b. Artefak yang sama dibaca ulang N× (belum terukur)

`openapi.yaml` U-001 = 2110 baris. Empat lensa buta membaca berkas yang sama secara independen. 267k/4 ≈ 67k per lensa — konsisten dengan "slice unit + seluruh artefak + berkas tes" per lensa. Biaya panel karena itu berskala **ukuran artefak × jumlah lensa**, dan rail blind-dispatch yang memaksa pembacaan ulang itu.

Ini kandidat leverage terbesar tapi menyentuh moat (blind review = rail anti-rubber-stamp). Proposal-first, jangan dipotong buta.

## 5. Defect produser terpisah (bukan biaya, tapi mahal)

`bolts/U-001/bolt-report.md` mendarat **BLOCKED (`scope_creep_detected`)** sebelum commit bisa jalan:

- `## Implementation steps` step 9 + `acceptance_test[1]` menyebut `apps/api/test/contract/openapi-coverage.test.ts`
- `target_files` U-001 hanya memuat 2 path — berkas tes itu tidak ada di situ, dan tidak dimiliki unit lain manapun

Cabang manapun melanggar sebuah Iron Rule (commit → `whitelist_violation`; skip → acceptance_test gagal). **generate-units mengeluarkan unit yang secara struktural tidak dapat diselesaikan.** Terbakar satu dispatch implementer penuh (~70k + 10 mnt) sebelum ketahuan, plus edit `target_files` manual.

Kandidat gate: `validate-unit-spec.sh` — setiap path yang disebut `acceptance_test[].command` atau `## Implementation steps` harus ada di `target_files` atau dimiliki unit lain di DAG.

## 6. Yang TIDAK disentuh

- `risk: critical` → full. 3/30, jarang, penilaian konsekuensi eksplisit produser. Moat.
- Gate L0 deterministik (tsc, gitleaks, SAST, new-deps, dep-auth) — skrip, ~0 token, bukan fat.
- Post-flight Hard-rule scan + acceptance test — jaring regresi, bukan judgment.
