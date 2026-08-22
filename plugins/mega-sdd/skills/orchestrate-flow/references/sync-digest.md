# Sync digest contracts — PENDING-SYNC.md + SYNC-REPORT.md (Mode D autonomous)

Per spec `2026-06-10-living-vault-continuous-sync-design.md §3.7`. Both files live at the VAULT root. PENDING-SYNC.md is append-per-run (open decisions accumulate until resolved); SYNC-REPORT.md is overwrite (latest run's truth).

## PENDING-SYNC.md — the deferred-decision queue

Written by the sync chain whenever an autonomous run defers a human decision. Sections in priority order; every entry cites its source artifact. Resolved entries are marked `✅ RESOLVED <date>` in place (audit trail), not deleted.

```markdown
# Pending sync decisions
**Last sync run**: <ISO8601> · **Open items**: N

## 1. CONFLICTs (BLOCKING — gate closed for affected units)
- [ ] CONFLICT-7 — <one-line> → resolve via `resolve-oq --binding <vault>/binding.md`
      (source: binding.md §CONFLICT-7; affected units: U-004, U-009)

## 2. Drift direction calls (vault stale vs code regressed — your call)
- [ ] DRIFT-N3 [HIGH] name-drift: vault `failed_debit_count` vs code `failed_attempts`
      (source: DRIFT-REPORT.md §N3; anchor app/models/account.rb:42)

## 3. Write-back drafts awaiting human triage
- [ ] PATCH-2 → model.md §Account — proposed_patch preserved on its PENDING-SYNC.md entry
      (provenance: a1b2c3 "hotfix rounding" — <author>, <date>)
```

Consumers: the session-start staleness notice points HERE (instead of suggesting a fresh sync) when open items exist; `resolve-oq --binding` marks the CONFLICT entries resolved as it goes.

## SYNC-REPORT.md — the run report (overwrite)

```markdown
# Sync report — <ISO8601>
**Trigger**: <N journal rows ∪ M git-delta paths (deduped → K changed paths)>
**Mode**: --auto [--auto-apply=safe]

| Phase | Outcome |
|---|---|
| scan --changed-only | merged K paths; F full-scan fallback? (reason) |
| detect-drift (scoped) | X findings (H high / M med / L low); A auto-applied; Q queued |
| bind --paths | C claims re-verdicted, R carried forward; conflicts: N (queued) |
| generate-units --reconcile | T task_type flips; S → stale; P → superseded; W new units |
| execute-bolts | B stale/new units executed; superseded skipped: V |
| full-suite gate (B2) | green\|red (P passed / F failed); bolts/_batch-suite.json (source: sync) |

## Applied patches (provenance)
- model.md §Account — name-drift (synced from code: a1b2c3 "…" — author, date)

## Queued (see PENDING-SYNC.md)
- 1 CONFLICT, 2 drift calls, 1 draft

## Closing staleness verification
`compute-unit-staleness.sh`: stale=0 ✅ | stale=N — explained: <e.g., U-004 blocked by CONFLICT-7>

## Closing full-suite gate (B2)
`<full-suite command>` @ HEAD: green ✅ (P passed / F failed) → bolts/_batch-suite.json (written_by: run-full-suite.sh)
```

**Rails:** the report never claims `completed` while PENDING-SYNC.md gained a CONFLICT (handoff `status: paused`, digest path in `next_action`). The closing staleness line is MANDATORY — a sync that cannot verify its own result says so explicitly. **Closing full-suite gate (B2):** when the sync reconciled ANY code change (an out-of-band edit, a re-bind that touched code, or a re-executed unit), it MUST **first COMMIT the reconciled changes**, then run `bash <plugin>/scripts/run-full-suite.sh --cwd=<root>` — the ONLY sanctioned writer of `<vault>/bolts/_batch-suite.json` (it stamps `written_by`, refuses a dirty code tree, and pins the 40-hex HEAD itself) — this is the catch for the *post*-batch out-of-band edit the within-`execute-bolts` gate has already passed. RED → the report states it and the handoff is `status: paused` (the same PreToolUse `batch_suite_red` gate then blocks the next bolt). The `SYNC-REPORT.md` emission consumes this artifact; it does not re-run the suite itself.

## Lifecycle (the queue must not rot)

- **Archive resolved rows:** when PENDING-SYNC.md exceeds 100 KB OR carries >50 `✅ RESOLVED` rows, the next sync run moves resolved rows to `PENDING-SYNC.archive.md` (append; audit trail preserved) and rewrites the live file with open items only.
- **Open-queue pressure:** >50 OPEN items → the sync summary says so loudly ("queue needs a triage session — consider `resolve-oq --binding` batch") instead of quietly appending more.
- **Stale-decision check:** an open item older than the vault's current version (vault bumped since it was queued) gets a `⚠ stale?` marker — the underlying finding may have been mooted; re-verify before deciding.
