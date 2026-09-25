# Scenario 12 — Continuous sync (never-ending development)

**When:** development "finished" via mega-sdd, then the code moved on — a manual hotfix, an AI-prompted change outside the pipeline, or a `git pull`. The vault/map/binding/units must catch up WITHOUT a cold full re-run.
**Time:** ~10 min (small delta) · **Spec:** `docs/superpowers/specs/2026-06-10-living-vault-continuous-sync-design.md`

## Setup (the "after" state)

A project that already completed the pipeline: `.mega-sdd/codebase/codebase-map.md` (with `last_scanned_commit` stamp), a bound vault, units, committed bolts (bolt-reports carry `target_hashes`).

## Act 1 — the code moves (three ways, all captured)

1. **In-session AI edit** — in a NORMAL Claude session (not a mega-sdd run), ask: "fix the rounding bug in `app/Services/PriceCalculator.php`". The PostToolUse hook journals the write to `.mega-sdd/codebase/.dirty-paths.jsonl` instantly — even before commit.
2. **Manual edit** — a teammate renames `failed_debit_count` → `failed_attempts` in a model and commits.
3. **git pull** — upstream merges land. (2 and 3 are caught by the git channel: HEAD ≠ the map's `last_scanned_commit`.)

Since v7.5.0, an inline edit of a `[LOCKED]`-anchored file gets an immediate one-line context notice (0 fork), before the session-start state block.

## Act 2 — the system notices (ambient, zero effort)

Open a new session in the project. Since 8.8.0 (the state anchor, spec `docs/superpowers/specs/2026-09-25-state-anchor-design.md` §6) session start prints the **state block** — HEAD, the per-vault verdict from the last engine check, and the rule line (the old repo-wide "codebase moved" line is gone). HEAD moved past the last check (the teammate commit + the pull), so this is the MISS form: the cached status word, plus a content-only delta from ONE `git diff`:

```
mega-sdd state @ f6e5d4c3b2a1 (main) · as of check a1b2c3d4; later moves checked by content only:
- shop: no scope change since a1b2c3d4 (stamp model-typed: hint) (as of a1b2c3d4) · changed since: app/Services/PriceCalc.php
Rule: code at HEAD decides what the code IS (files, symbols, lines, what is built). Memory, CLAUDE.md and vault/unit/bolt-report claims about what the code IS are derived: no SHA = hint, contradicts HEAD = STALE; say so, never use them silently. What the code SHOULD do stays with the vault: a spec-vs-code mismatch is a CONFLICT for a human.
```

After the next GROUND (M/L entry — the front door or sync) the engine recomputes and the line reads `shop: STALE since a1b2c3d4 · 1 file(s): app/Services/PriceCalc.php · f6e5d4c fix: price rounding (stamp model-typed: hint)`.

(The block is informational and never tells the model to run `/mega-sdd` or sync — a continuation prompt like `lanjut` with no chain marker this session stays tier S; the sync proposal appears when YOU enter an M/L lane. Open the front door or invoke sync yourself:)

## Act 3 — autonomous reconcile (one confirmation, zero mid-chain questions)

```
/mega-sdd:sync --auto
```

Expected chain (Mode D):

| Phase | What you should see |
|---|---|
| Change summary | journal rows ∪ git delta, deduped (e.g., "3 changed paths") — shown BEFORE the confirm |
| `scan-codebase --changed-only` | only the 3 paths re-extracted; untouched map rows byte-identical; journal rotated (`.consumed-<ts>`), deleted after the write |
| `detect-drift --scope=@<vault>/.sync-changed-paths.txt` (scoped to scan's changed set — the forked skill can't re-resolve the now-consumed journal) | finds the rename as `name drift [HIGH]`; under `--auto` it does NOT ask — queues the direction call |
| `bind-codebase --paths=@…` | only affected claims re-verdicted; everything else `provenance: carried_forward`; any prior ACTIVE CONFLICT re-validated regardless |
| `generate-units --reconcile` | the price-calc unit flips per the new state (e.g., `create → verify`); `status:` recomputed from `compute-unit-staleness.sh`; nothing duplicated |
| `execute-bolts` | only stale/new units re-run; `superseded` skipped with a warning |

End of run: `<vault>/SYNC-REPORT.md` (per-phase outcomes + closing staleness verification `stale=0 ✅`) and, because the rename needs a human direction call, `<vault>/PENDING-SYNC.md` with one open item.

### Act 3 on the lite lane / a layout-3 vault (v8 P3, 8.0)

A plan-born project (`--lite` / config `lane: lite`, vault = `context.md`, units bound PER UNIT at dispatch → `bolts/U-XXX/binding.json`, no `binding.md`, no codebase-map — the symbol index is the freshness substrate) reaches the same Mode D position on the same two channels, but the state engine renders the **re-keyed chain**:

| Phase | What you should see |
|---|---|
| `scripts/derive-changed-paths.sh --vault <vault>` | changed set = git delta since the index stamp ∪ working tree ∪ journal rows → `<vault>/.sync-changed-paths.txt` (no map to refresh — a script, zero model tokens) |
| `detect-drift --scope=@<vault>/.sync-changed-paths.txt` | as on the classic lane; Architecture-prose drift is NOT detectable on layout-3 (deliberate degradation, CHANGELOG 8.0.0) — the rename still surfaces as `name drift` from the Data-model / Flows sections |
| `scripts/rebind-units.sh --cwd . --vault <vault> --paths=@<vault>/.sync-changed-paths.txt` | ONLY the units whose `target_files` ∪ `## Anchors` ∪ per-unit binding anchors intersect the changed set are re-verdicted by the SAME JIT writers (`derive-unit-claims` → `write-unit-binding` → `validate-handoff-binding-units --units=`); exit 0 = nothing affected, 4 = re-bound (read `gate`); a CONFLICT closes the gate for the affected units exactly as at dispatch — never auto-resolved |
| `plan --reconcile` | `task_type` / `status` follow the per-unit binding evidence; nothing duplicated (never `generate-units`, which reads the layout-2 docs and FATALs here: `units_folded_into_plan`) |
| `execute-bolts --all --lite` | only stale/new units re-run |

Full audit on this lane = `scripts/rebind-units.sh --units=all` (the meaning of `sync --full-bind`). `bind-codebase` on a per-unit-bound vault is a preflight FATAL with a one-line KENAPA (`bind_folded_into_bolts`).

**Replay (fixture-driven, CI):** `bash tests/v8-layout3/test-state-sync-lite.sh` — both channels reach `maintenance_sync` with the 5-hop chain above, hop 1 and hop 3 are executed on the fixture (only the touched unit is re-bound, sibling untouched), the classic layout-2 chain is proven unchanged as a control, and the "re-run → in sync" criterion below holds (stamp == HEAD + no journal → not `maintenance_sync`). Replayed 2026-09-15 on 8.0.0-candidate: 6/6 PASS.

## Act 4 — clear the queue (when you're ready)

Open `PENDING-SYNC.md`: the rename drift asks *vault stale (code is right) vs code regressed (vault is right)*. Decide → `UPDATE_VAULT` drafts the patch with git provenance (`f6e5d4 "rename to failed_attempts" — <teammate>, <date>`); ACCEPT applies it, bumps the vault version, regenerates `vault.json` under the lock. Or run with `--auto-apply=safe` next time to auto-apply this exact class.

`auto_verify_on_edit: true` (default false) offers the touched unit's acceptance run.

## Pass criteria

- [ ] All three change channels detected (journal for in-session; git for manual/pull)
- [ ] The session-start state block named the moved path under the vault (miss form: "changed since: …"); GROUND then named it STALE (file + commit); after a clean sync + GROUND it no longer does
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
