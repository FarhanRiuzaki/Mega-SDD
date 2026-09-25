# State anchor — before/after di repro Fase 0 (8.7.2 vs 8.8.0)

Permintaan brief Fase 2: "before/after on the Fase-0 repro". Satu run, satu tabel.

## Cara ngukur

- `research/2026-09-25-state-anchor-audit/repro.sh` dijalankan dua kali, masing-masing ke outdir scratch:
  - **before** = plugin di `e15465f3` (8.7.2), diambil lewat `git archive`;
  - **after** = plugin di commit rilis 8.8.0.
- Playground sama (monorepo: `apps/web` = vault FE lite, `apps/api` = vault BE classic), checkpoint sama.
- Kedua run berakhir dengan `R status unchanged: yes`, artinya repo nggak disentuh.
- Capture yang dibandingkan:
  - `10-sessionstart-startup-*` — yang disuntik ke model di awal sesi;
  - `47-pretooluse-agent-bolt-implementer` — verdict dispatch bolt untuk unit FE U-002;
  - `42d-U-002-binding-json` — hasil writer.

## Awal sesi: yang disuntik ke model

| Checkpoint | 8.7.2 | 8.8.0 (sesi pertama setelah pindah HEAD) | 8.8.0 setelah GROUND |
|---|---|---|---|
| A (seed) | tidak ada baris | `FRESH: web` · `api: no scope change … (stamp model-typed: hint)` + baris aturan | sama |
| ctl-B (commit BE saja) | `codebase moved since last scan (… stamp ≠ HEAD)` — repo-wide, tanpa scope | miss: `web: FRESH (as of …)` · `api: … no further scope change`, lalu baris aturan | `FRESH: web` · `api: STALE since 86d8b1c7 · 1 file(s): apps/api/src/models/LeaveRequest.php · 577cc8d feat(api): …` |
| C1 / ctl-C1 (FE: client.ts + LoginForm) | baris "codebase moved" yang sama | miss: `web: FRESH (as of …) · changed since: apps/web/src/api/client.ts, …LoginForm.tsx` | `web: STALE since … · apps/web/src/api/client.ts · fix(web): v2 auth endpoint … · pending: U-002` + `implemented code changed since bolt: U-001 (LoginForm.tsx)` |
| C2 / ctl-C2(-green) (FE: +5 baris di atas anchor) | baris "codebase moved" yang sama | miss: `web: … changed since: apps/web/src/api/client.ts` | `web: STALE since … · client.ts · feat(web): token refresh helper · pending: U-002` |
| ctl-D (edit belum di-commit) | tidak ada baris | `FRESH: web` | `web: FRESH · dirty 1 (as of check)` |
| E (history ditulis ulang + gc) | baris "codebase moved" yang sama | miss: `later moves UNVERIFIED` | `web: STALE · stamp unreachable (history rewritten or gc) — whole scope · dirty 1` + api idem |

Catatan dari run ini: di 8.8.0 awalnya, jalur miss di kontrol (checkout hasil `cp -a`) keluar sebagai "later moves UNVERIFIED". Penyebabnya cache nyimpen `top=` absolut milik checkout asal. Udah diperbaiki: jalur miss sekarang pakai worktree top yang live. Diverifikasi di checkout hasil copy: `changed since: apps/web/src/api/client.ts`.

## Dispatch bolt U-002 (FE) — verdict gate

| Checkpoint | 8.7.2 | 8.8.0 (urutan controller di repro) |
|---|---|---|
| A | ALLOW | ALLOW |
| ctl-B, C1, C2, D | DENY `binding->units` (Pass-5 / JIT lama) | DENY `binding->units` + `binding-freshness` · `stamp_null (index_stale)` |
| ctl-C1, ctl-C2, **ctl-C2-green**, E | **ALLOW** | DENY `binding-freshness` · `stamp_null (index_stale)` |
| ctl-D | ALLOW | ALLOW |

Kenapa `index_stale`: controller simulasi di repro masih pakai urutan LAMA (bind 3.9 dulu, index belakangan), dan GROUND menunda rebuild index selama sync pending. Jadi writer jujur nge-null stamp yang verdict simbolnya datang dari index lama. Di urutan BARU (step 0 3.9: index dulu, `jit-bind-and-quarantine.md`), kasus yang sama diputar ulang:

| Kasus (urutan baru: index → 3.9 → prompt) | Stamp | Anchor U-002 | Leg binding-freshness |
|---|---|---|---|
| ctl-B (commit BE saja) | HEAD | `client.ts:6`, `:16` (file FE memang nggak berubah) | ALLOW |
| ctl-C2-green | HEAD | `client.ts:11`, `:21` (R1-shift di 3.9) | ALLOW |

## Kasus yang memicu program ini: ctl-C2-green

Teammate nambah 5 baris di atas `login()`. Suite batch hijau lagi. Unit U-002 di-dispatch.

| | 8.7.2 | 8.8.0 |
|---|---|---|
| binding U-002 | `unit-binding/1`, head short-8, `client.ts:6` **CONFIRMED** (cuma dicek range-nya) | `unit-binding/2`; di 3.9 ladder langsung **R1-shift `:6 → :11`, `:16 → :21`** dan `## Anchors` di unit ditulis ulang |
| dispatch pertama | **ALLOW** | DENY `stamp_null (index_stale)`, remedy: 3.9b |
| setelah satu 3.9b + prompt rebuild | — | stamp = HEAD, dispatch **ALLOW** |
| anchor yang diterima implementer (`dispatch-prompt.md`) | `client.ts:6`, `client.ts:16` — "content drift NOT checked" (baris 6 sekarang `export interface LoginResponse`) | `client.ts:11` (`login()`), `client.ts:21` (`logout()`) — "block content checked at bind by the content ladder"; plus `binding_sha256` |

## Yang belum dibuktikan run ini

- **Perilaku model.** Run ini membuktikan mekanismenya: apa yang disuntik, apa yang di-gate, anchor mana yang sampai ke implementer. Apakah model memang berhenti percaya memory yang basi, itu urusan acceptance run D33 (30 run), dan belum jalan.
- **Windows.** Semua angka dari macOS. Cek D32: `windows-check.sh` di folder ini.
