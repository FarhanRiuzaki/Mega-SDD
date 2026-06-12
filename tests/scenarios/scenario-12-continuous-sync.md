# Scenario 12 — Continuous sync (never-ending development)

**When:** development "finished" via mega-sdd, then the code moved on — a manual hotfix, an AI-prompted change outside the pipeline, or a `git pull`. The vault/map/binding/units must catch up WITHOUT a cold full re-run.
**Time:** ~10 min (small delta) · **Spec:** `docs/superpowers/specs/2026-06-10-living-vault-continuous-sync-design.md`

## Setup (the "after" state)

A project that already completed the pipeline: `.mega-sdd/codebase/codebase-map.md` (with `last_scanned_commit` stamp), a bound vault, units, committed bolts (bolt-reports carry `target_hashes`).

## Act 1 — the code moves (three ways, all captured)

1. **In-session AI edit** — in a NORMAL Claude session (not a mega-sdd run), ask: "fix the rounding bug in `app/Services/PriceCalculator.php`". The PostToolUse hook journals the write to `.mega-sdd/codebase/.dirty-paths.jsonl` instantly — even before commit.
2. **Manual edit** — a teammate renames `failed_debit_count` → `failed_attempts` in a model and commits.
3. **git pull** — upstream merges land. (2 and 3 are caught by the git channel: HEAD ≠ the map's `last_scanned_commit`.)

## Act 2 — the system notices (ambient, zero effort)

Open a new session in the project. Session start prints ONE line:

```
mega-sdd: codebase moved since last scan (1 journaled write(s); map stamp a1b2c3d4 ≠ HEAD f6e5d4c3) — `/mega-sdd:sync` reconciles map → drift → binding → units.
```

Type `lanjut` (or anything continuation-shaped) — the anchor proposes `/mega-sdd:sync --auto` with ONE upfront confirmation. Or invoke it yourself.

## Act 3 — autonomous reconcile (one confirmation, zero mid-chain questions)

```
/mega-sdd:sync --auto
```

Expected chain (Mode D):

| Phase | What you should see |
|---|---|
| Change summary | journal rows ∪ git delta, deduped (e.g., "3 changed paths") — shown BEFORE the confirm |
| `scan-codebase --changed-only` | only the 3 paths re-extracted; untouched map rows byte-identical; journal rotated (`.consumed-<ts>`), deleted after the write |
| `detect-drift` (scoped) | finds the rename as `name drift [HIGH]`; under `--auto` it does NOT ask — queues the direction call |
| `bind-codebase --paths=@…` | only affected claims re-verdicted; everything else `provenance: carried_forward`; any prior ACTIVE CONFLICT re-validated regardless |
| `generate-units --reconcile` | the price-calc unit flips per the new state (e.g., `create → verify`); `status:` recomputed from `compute-unit-staleness.sh`; nothing duplicated |
| `execute-bolts` | only stale/new units re-run; `superseded` skipped with a warning |

End of run: `<vault>/SYNC-REPORT.md` (per-phase outcomes + closing staleness verification `stale=0 ✅`) and, because the rename needs a human direction call, `<vault>/PENDING-SYNC.md` with one open item.

## Act 4 — clear the queue (when you're ready)

Open `PENDING-SYNC.md`: the rename drift asks *vault stale (code is right) vs code regressed (vault is right)*. Decide → `UPDATE_VAULT` drafts the patch with git provenance (`f6e5d4 "rename to failed_attempts" — <teammate>, <date>`); ACCEPT applies it, bumps the vault version, regenerates `vault.json` under the lock. Or run with `--auto-apply=safe` next time to auto-apply this exact class.

## Pass criteria

- [ ] All three change channels detected (journal for in-session; git for manual/pull)
- [ ] Staleness notice appeared at session start; cleared after a clean sync
- [ ] No mid-chain questions under `--auto`; human decisions queued, chain completed
- [ ] Untouched map/binding rows byte-identical; carried-forward verdicts tagged
- [ ] No prior ACTIVE CONFLICT silently carried (always re-validated)
- [ ] `SYNC-REPORT.md` closing verification: `stale=0` or explained
- [ ] Re-running `/mega-sdd:sync` immediately → "in sync", stops (no vacuous re-run)

## Anti-patterns this scenario guards against

- Full re-scan of a 5k-file repo for a 3-file change
- The vault silently rotting while hotfixes pile up
- Autonomy that auto-resolves CONFLICTs (it never does — the moat is intact)
- A sync that says "done" without proving staleness reached zero
