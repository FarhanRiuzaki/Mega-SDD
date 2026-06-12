# Trigger test — /mega-sdd:sync (orchestrate-flow Mode D)

How to run: for each prompt, start a FRESH session in a repo matching the CWD state, send the prompt verbatim, record routing. Pass = observed routing matches `expect`.

## Should route to the sync lane (orchestrate-flow --sync / Mode D)

| # | Prompt | CWD state | expect |
|---|---|---|---|
| T1 | `/mega-sdd:sync` | map+binding exist, journal non-empty | sync chain proposed (command route) |
| T2 | "kode-nya udah berubah manual, lanjutin mega-sdd dari kondisi sekarang" | map+binding exist, HEAD ≠ last_scanned_commit | Mode D sync chain |
| T3 | "the code moved on since the last scan, catch the vault up" | map+binding exist, change signal present | Mode D sync chain |
| T4 | "we hotfixed prod last week — is the vault still right? bring everything in sync" | bolts complete, HEAD ≠ stamp | Mode D sync chain |
| T5 | "lanjut" (continuation) | bolts complete + journal non-empty | orchestrate-flow proposes Mode D (change signal outranks "pipeline complete") |

## Should NOT route to sync (near-misses)

| # | Prompt | CWD state | expect |
|---|---|---|---|
| N1 | "scan codebase ini" | fresh brownfield repo, NO map | scan-codebase full (first-run, not Mode D) |
| N2 | "sync my fork with upstream" | any | NOT mega-sdd (git operation) |
| N3 | "is the code in sync?" | map+binding, NO change signal | detect-drift standalone (informational), not the full sync chain |
| N4 | "the PRD changed" | new PRD revision present | diff-vault (outranks sync per routing precedence) |
| N5 | `/mega-sdd:sync` | map+binding, journal empty, HEAD == stamp | reports "in sync", stops — NO vacuous re-runs |

## Post-trigger contract checks

- [ ] Change summary shown BEFORE chaining (journal rows + git delta count)
- [ ] `scan-codebase --changed-only` merged the map: untouched §2 rows byte-identical, changed rows re-cited, vanished files dropped
- [ ] Journal truncated ONLY after successful map write
- [ ] detect-drift scoped to changed paths; findings direction-neutral
- [ ] Binding CONFLICT gate behavior unchanged (conflicts still block unit/bolt continuation)
- [ ] Re-bind used `--paths`; carried-forward rows show `provenance: carried_forward`; every prior ACTIVE CONFLICT was re-validated (present as `### CONFLICT-N` in the new binding.md, fresh evidence)
- [ ] `generate-units --reconcile` changed ONLY units whose task_type/status/Migration notes moved; vanished claims marked `superseded` (file kept)
- [ ] `compute-unit-staleness.sh` output drove `status:`; legacy units (no target_hashes) left without status — never guessed
- [ ] No change signal → "in sync" + stop
