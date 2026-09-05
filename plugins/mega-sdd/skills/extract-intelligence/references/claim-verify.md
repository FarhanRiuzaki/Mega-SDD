# Claim-verify lane — adversarial verification per module (7.25.0)

Spec: `docs/superpowers/specs/2026-09-05-kb-verify-lane-design.md` Fase 3. Field
basis: audit KB Host-AS400 menemukan 8 klaim WRONG (2 arah-uang) di KB yang lolos
semua gate struktural — extraction single-pass tidak pernah dicek lawan; disiplin
prosa (P1-P6) tanpa verifikasi = doktrin kita sendiri ("prose enforces nothing").
Lane ini = subagent reviewer read-only, blind, findings-only — pola panel
execute-bolts dibawa ke extraction.

## Kapan jalan

Per module, SETELAH per-module quality gate PASS (structural) dan SEBELUM
synthesis. Multi-module: dispatch verifier per modul dalam batch (paralel, ≤
`--max-parallel`, read-only jadi murah). **Single-module (xs) TETAP dispatch
verifier** — extraction-nya jalan di main thread, dan penulisnya tidak boleh
memeriksa dirinya sendiri; blindness adalah inti lane ini.

## Dispatch core (yang controller ketik per modul)

Metode + grading + REPORT BACK ride di body agent `mega-sdd:claim-verifier` —
jangan re-type. Controller ketik HANYA:

```
ROLE: Claim verifier — module <domain> (adversarial, read-only).
CONTEXT: legacy root <abs path>; stack(s): <stacks from census.json>.
VERIFY: <kb>/modules/<domain>.prd.md
SAMPLE: N=12 (spread across all sections; 100% [LOCKED] + 100% money-class on top).
mega-sdd-trace:extract-intelligence
```

Model tier per role `extract-intelligence-verify` dari
`plugins/mega-sdd/references/model-tiers.md`; override via handoff
`metadata.model_tiers`.

## Yang controller lakukan dengan hasilnya

1. Simpan blok `VERIFY REPORT` verbatim ke file sementara, lalu **Run**
   `scripts/write-verify-state.sh --kb-dir=<kb> --report-file=<tmp>` (path
   plugin-root; SKILL.md membawa bentuk runnable-nya) — satu-satunya writer
   `<kb>/.verify/<domain>.json`; parse gagal = loud, jangan hand-edit JSON-nya.
2. **`wrong_load_bearing > 0` atau state FAIL** → re-dispatch `domain-extractor`
   modul itu SEKALI dengan findings verbatim sebagai feedback → quality gate ulang
   → verifier ulang (fresh dispatch). Gagal lagi → **halt** `quality_gate_failed`
   (subtype `claim_verify_failed`), findings verbatim di halt.
3. `wrong == 0` tapi `imprecise > 0` → perbaiki inline di main thread (sitasi/
   presisi — bukan re-dispatch), catat di chat satu baris, re-run
   `write-verify-state.sh` TIDAK perlu (imprecise tidak menggagalkan state).

## Enforcement (deterministik, di census gate)

`validate-extract-census.sh` membaca `.verify/<domain>.json` per PRD dan
**merecompute** dari artifact (B1 pattern): jumlah `[LOCKED]` di body harus ≤
`locked_checked`, dan `locked+money+sampled ≥ min(8, jumlah sitasi)`. Halt types:
`claim_verify_missing` / `claim_verify_failed` / `claim_verify_incomplete`.
Report yang under-scoped atau di-forge tidak bisa lolos — coverage-nya dihitung
ulang, bukan dipercaya.

## Scope kejujuran

- Gate menegakkan: state ada + verdict PASS + LOCKED coverage + sample floor.
- "Money-class tercakup 100%" adalah kewajiban PROSA verifier (tidak bisa
  direcompute deterministik) — kelasnya sama dengan disiplin P1-P6: yang
  berubah, sekarang ada mata kedua yang memeriksanya.
- Biaya terukur (patokan audit lapangan): ±150-220k token per modul, read-only.
