# Trigger test — /mega-sdd:sync (orchestrate-flow Mode D)

How to run: for each prompt, start a FRESH session in a repo matching the CWD state, send the prompt verbatim, record routing. Pass = observed routing matches `expect`.

"Bound vault" below = a layout-3 vault (`context.md`) whose units carry per-unit `bolts/U-*/binding.json` (the JIT bind), with the GROUND symbol index present — the freshness substrate whose `head_commit` is the sync baseline. A layout-2 (pre-9.0) vault takes `/mega-sdd:migrate-paths --vault-layout=3` first; sync never runs on it directly.

## Should route to the sync lane (orchestrate-flow --sync / Mode D)

| # | Prompt | CWD state | expect |
|---|---|---|---|
| T1 | `/mega-sdd:sync` | bound vault, journal non-empty | sync chain proposed (command route) |
| T2 | "kode-nya udah berubah manual, lanjutin mega-sdd dari kondisi sekarang" | bound vault, HEAD ≠ symbol-index `head_commit` | Mode D sync chain |
| T3 | "the code moved on since the last scan, catch the vault up" | bound vault, change signal present | Mode D sync chain |
| T4 | "we hotfixed prod last week — is the vault still right? bring everything in sync" | bolts complete, HEAD ≠ index stamp | Mode D sync chain |
| T5 | "lanjut" (continuation) | bolts complete + journal non-empty, a chain ran this session | orchestrate-flow proposes Mode D (change signal outranks "pipeline complete") |
| T6 | `/mega-sdd:sync --full-bind` (or "apakah kode masih sinkron dengan spec?") | bound vault | the whole-vault JIT sweep: `rebind-units.sh --units=all` (`derive-unit-claims.sh --units=all` → `write-unit-binding.sh` per unit → `validate-handoff-binding-units.sh --units=all`); every open CONFLICT BLOCKS; CONFIRMED/CONFLICT/OQ totals in the Sync report |

## Should NOT route to sync (near-misses)

| # | Prompt | CWD state | expect |
|---|---|---|---|
| N1 | "scan codebase ini" | fresh brownfield repo, no vault | the front door's Lane 0 (GROUND: state digest + symbol index) — not Mode D, and no scan skill (scan-codebase was removed in 9.0) |
| N2 | "sync my fork with upstream" | any | NOT mega-sdd (git operation) |
| N3 | "is the code in sync?" | bound vault, NO change signal | detect-drift standalone (informational), not the full sync chain |
| N4 | "the PRD changed" | new PRD revision present | diff-vault (outranks sync per routing precedence) |
| N5 | `/mega-sdd:sync` | bound vault, journal empty, HEAD == index stamp | reports "in sync", stops — NO vacuous re-runs |
| N6 | "tambah kolom npwp di form nasabah" (chat brief, code untouched) | bound vault, journal empty | NOT the sync lane — no change signal exists; the delta lane (diff-vault --from-prompt) is a front-door overlay with its OWN scope file (`.delta-changed-paths.txt`), never `.sync-changed-paths.txt`; sync surfaces stay untouched |
| N7 | `/mega-sdd:sync` | layout-2 vault only | propose `/mega-sdd:migrate-paths --vault-layout=3` (then `rebind-units.sh --units=all`), never run silently — no sync chain on layout-2 |

## Post-trigger contract checks

- [ ] Change summary shown BEFORE chaining (journal rows + git delta count)
- [ ] `derive-changed-paths.sh` wrote `<vault>/.sync-changed-paths.txt` (git diff from the index stamp ∪ working tree ∪ journal); the journal was rotated ONLY after that write succeeded
- [ ] `sync-intersect.sh` ran before any re-verdict: exit 0 → one-line SYNC-REPORT.md + END; exit 4 → proceed; any other exit → full chain (fail-closed)
- [ ] detect-drift scoped to the changed paths (`--scope=@<vault>/.sync-changed-paths.txt`); findings direction-neutral, queued to PENDING-SYNC.md
- [ ] Binding CONFLICT gate behavior unchanged (an open CONFLICT still closes its unit at execute-bolts run start, the derive-exec-plan.sh quarantine)
- [ ] Re-bind used `rebind-units.sh --paths=@<vault>/.sync-changed-paths.txt`: only units whose `target_files` ∪ `## Anchors` ∪ binding anchors meet the changed set were re-verdicted; untouched units kept their `binding.json`
- [ ] `plan --reconcile` changed ONLY task_type/status of existing unit IDs; vanished claims marked `superseded` (file kept); no unit added (a new requirement goes `diff-vault` → `plan --regenerate`)
- [ ] `compute-unit-staleness.sh` output drove `status:`; legacy units (no target_hashes) left without status — never guessed
- [ ] No change signal → "in sync" + stop
