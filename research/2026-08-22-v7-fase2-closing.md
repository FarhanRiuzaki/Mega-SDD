# v7 Fase 2 — catatan penutup (script & hook diet)

**Status: SHIPPED — 16 commit `27576cf..9bbbd3f` (2026-08-22), semua CI GitHub hijau (run terakhir №16 = 32563069798, success). GATE ACCEPTED** ([keputusan](2026-08-21-v7-gate2-close.md)). Leg scm menyusul via VPN kantor (user push sendiri).

Sumber keputusan: [audit §6.2–6.6](2026-08-21-v7-diet-audit.md) + [gate-0](2026-08-21-v7-gate0-decision.md) + [backlog Fase 1 §5](2026-08-21-v7-phase1-proof.md).

## Before/after

| Permukaan | Before (c735725) | After (9bbbd3f) | Delta |
|---|---|---|---|
| Script shell | 118 file / 36.341 baris | 87 file / 33.259 baris | −31 file / −3.082 baris |
| Python `_lib` | 12 file / 3.905 baris | 11 file / 3.688 baris | −1 file / −217 baris |
| 8 hook event | 4.029 baris | 3.773 baris | −256 baris |
| session-start spawn | ±22–26 fork | 0 fork (no-signal) / 8 fork (SDD+index) | tier-S S17/S18 terukur |
| Test suite | 239 | 233 (semua hijau) | −6 (mati bareng scriptnya + 1 konsolidasi) |

Merge memotong FILE bukan baris — kontrak menyatu, bukan hilang (ekspektasi gate).

## Trace tier-S ulang (post-diet)

19/19 arm hijau live: un-armed Edit/Bash/Read/UPS = 0 fork; PostToolUse Write 1 fork + journal utuh; Stop/SubagentStop non-SDD 0; anti-forge semua DENY (termasuk spoof); armed fan-out utuh (25 python — was 27, 2 validator memang dihapus/merge — `.validation-blockers.json` tertulis); subagent fail-closed. **Diet tidak meregresi Fase 1.**

## Daftar aksi (alasan satu baris)

### Hooks (№1–3, `27576cf` `6796138` `f40baa9`)
- C1 9-guard + rotasi telemetry: session-start → `ground.sh` — session-start tidak boleh menulis vault artifact; battery verbatim, jalan saat GROUND.
- Handoff: absent-only → FULL gate-time recompute + `content_sha256` dedup di `validate-handoff-yaml.sh`; **leg Stop dihapus di commit yang sama** — nol jendela tanpa penjaga (`test-handoff-gate-time-recompute` h1–h5).
- Staleness fallback bash dihapus (`derive-state.sh` = satu-satunya engine); `hook-debug.log` >20k rotasi single-generation.

### DELETE 14 script + 1 py (№4, `7e60466`) — per gate-0 §6.2
| File | Alasan |
|---|---|
| validate-vault-binding-coverage.sh | duplikat cakupan `validate-handoff-binding-units` + gate |
| validate-conflict-classification.sh | grammar CONFLICT + blocking tetap di gate; rung hook phantom |
| validate-kb-reengineering.sh | overclaim "halt-enforces" — prose bukan gate |
| check-recursion-budget.sh, classify-iter.sh | tidak pernah ter-wire ke rung mana pun |
| validate-pandoc-render.sh | pandoc tidak dipakai; wiring `PostToolUseFailure` hidup hanya untuknya (ikut dihapus) |
| verify-mermaid.sh + mermaid_parse_oracle.mjs | tokenizer heuristik tetap; mandat Mermaid utuh di gate lain |
| build-project-index.sh | tersubstitusi reuse-index (v5.28–5.31) |
| memory-migrations/template-migration | migrasi one-shot yang sudah lewat masanya |
| replay.sh + replay.md | lane replay mati sejak express spine |
| measure-fork-ab/-tokens/-seeds + seeding_budget.py | instrumen ukur riset, bukan runtime |
| enrich-workflows-staging.sh | staging enrichment tak ada konsumen |

### DEMOTE 3 (№5, `5788932`) — relocate-then-delete
- audit-domain-rules.sh → 3 baris instruksi LLM di analyze SKILL (Mode B).
- copy-consumer-guide.sh → satu baris `cp` di generate-intent Step 3.
- scaffold-pack.sh → langkah hand-copy di framework-conventions README; lint = jaring pengaman leak.

### MERGE 10/10 grup (№6–15, `eb7a2ed`..`92cca8a`) — fold verbatim + parity-proof SEBELUM delete; nama state-file & exit code TIDAK berubah
| Grup | Host | Mode |
|---|---|---|
| sync-superpowers + sync-ui-ux | `sync-vendored.sh` (baru, 2 leg independen) | — |
| stamp-phase | `derive-binding-json.sh` | PHASE 0 |
| check-dep-authorization | `validate-new-deps.sh` | `--unit=` |
| check-citation-drift | `build-citation-map.sh` | `--check-drift` |
| scan-secrets-code | `secret-scan.sh` | `--code` |
| list-modules | `query-graph.sh` | `--modules` |
| ui-deferral | `validate-ui-quality.sh` | `--deferral` |
| 5 KB/flows validator | `validate-kb.sh` (baru) | `--surface=output\|citations\|flows\|markers\|vault-flows` (parity byte-identical ×5) |
| cross-cutting + fanout-parity | `validate-sibling-consistency.sh` | `--cross-cutting` (BLOCKING) / `--fanout-parity` (ADVISORY) |
| predictive-preflight | `validate-preflight.sh` | `--predictive` |

### Tier B + CI diet (№16, `9bbbd3f`)
- Header "Branch 14" vault-flow-staging dibetulkan (ADVISORY via analyze).
- CI: docs-only push skip loop suite — **manifest-validate TETAP jalan** (keputusan eksplisit); npm cache; `fetch-depth: 0` agar `event.before` resolvable.

## Keputusan gate (2026-08-22) — dari [gate2-close](2026-08-21-v7-gate2-close.md)

1. **Starterkit — DEFERRED → diputus opsi (b) dibatasi.** Bukti yang membalik gate-0: `deep-scan-dispatch.md` = **satu-satunya producer `reuse-index.yaml`**, source graph code layer v6.20.0 + reuse-first (dua-duanya mandat). Keputusan: bedah reuse-only — cabang `starterkit-context.yaml` dihapus (konsumen mati), cabang reuse-index utuh; `starterkit-context-schema.md` dihapus, `reuse-index-schema.md` tetap. Batas keras: >1 commit bersih dengan parity reuse-index byte-identical → berhenti, ambil opsi (a) keep.
2. **`ref_loaded` — KEEP.** Investasi D1 v6.13 baru + test pins; memotongnya tidak menghemat apa pun yang terasa dev. Token-cost SELESAI.
3. **build-dispatch-prompt template + `_lib/unit_parse.py` — dikerjakan SEBELUM Fase 3** (Fase 3 juga menyentuh file ini; hindari ubah 3.7k baris dua kali). Gate: golden parity harness, output byte-identical, satu commit template + satu commit unit_parse.
4. **`xargs -P` CI — verifikasi no-shared-state dulu**; bersih → commit, ada satu penulis state repo bersama → skip + catat, jangan di-fix sekarang.

## Pelajaran standing
1. Zero-phantom grep WAJIB tanpa `--include=*.sh` — file hook tanpa ekstensi lolos filter (3 rung phantom ketemu terlambat).
2. Shim PATH: `command -v` di shell ber-fungsi rtk mengembalikan NAMA bukan path → shim rekursif hang; validasi `case "$real" in /*)`.
3. Merge = fold verbatim + parity twin-fixture SEBELUM delete original.
4. SATU grup per commit — edit grup N+1 sebelum grup N committed mencemari suite (terjadi sekali, di-recover).

## Berikutnya
№3 ekstraksi → №1 starterkit bedah → №4 xargs verifikasi → **Fase 3 gate**: contoh before/after vault dari `sample-prd-clinic.md` layout 4 file (`vault.md`/`model.md`/`flows.md`/`constraints.md` + `vault.json`), 00-index → YAML frontmatter vault.md, OQ terpusat di constraints.md, migrate-paths + full re-bind wajib + dual-layout read satu minor. Berhenti di contoh.
