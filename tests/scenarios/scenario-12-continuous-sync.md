# Scenario 12 — Continuous sync (never-ending development)

**When:** development "finished" via mega-sdd (the guarded pipeline — a vault exists), then the code moved on — a manual hotfix, an AI-prompted change outside the pipeline, or a `git pull`. The vault/binding/units must catch up WITHOUT a cold full re-run.
**Time:** ~10 min (small delta) · **Spec:** `docs/superpowers/specs/2026-06-10-living-vault-continuous-sync-design.md` (the 9.0 chain: `docs/superpowers/specs/2026-09-27-v9-simplification-design.md` §2 + §7 #5)

## Setup (the "after" state)

A project that already completed the pipeline: a plan-born vault (`context.md` + `units/`), per-unit bindings written by the JIT bind at dispatch (`bolts/U-XXX/binding.json`), committed bolts (bolt-reports carry `target_hashes`), and the symbol index `.mega-sdd/codebase/symbol-index.json` whose `head_commit` is the freshness stamp. There is no `codebase-map.md` and no whole-vault `binding.md` — neither has a producer since 9.0.

A pre-9.0 layout-2 vault (no `context.md`) does not sync as it is: the front door proposes `/mega-sdd:migrate-paths --vault-layout=3` first (then the mandatory full JIT re-bind), never silently.

## Act 1 — the code moves (three ways, all captured)

1. **In-session AI edit** — in a NORMAL Claude session (not a mega-sdd run), ask: "fix the rounding bug in `app/Services/PriceCalculator.php`". The PostToolUse hook journals the write to `.mega-sdd/codebase/.dirty-paths.jsonl` instantly — even before commit.
2. **Manual edit** — a teammate renames `failed_debit_count` → `failed_attempts` in a model and commits.
3. **git pull** — upstream merges land. (2 and 3 are caught by the git channel: HEAD ≠ the symbol index's `head_commit`.)

Since v7.5.0, an inline edit of a `[LOCKED]`-anchored file gets an immediate one-line context notice (0 fork), before the session-start state block.

## Act 2 — the system notices (ambient, zero effort)

Open a new session in the project. Since 8.8.0 (the state anchor, spec `docs/superpowers/specs/2026-09-25-state-anchor-design.md` §6) session start prints the **state block** — HEAD, the per-vault verdict from the last engine check, and the rule line (the old repo-wide "codebase moved" line is gone). HEAD moved past the last check (the teammate commit + the pull), so this is the MISS form: the cached status word, plus a content-only delta from ONE `git diff`:

```
mega-sdd state @ f6e5d4c3b2a1 (main) · as of check a1b2c3d4; later moves checked by content only:
- shop: FRESH (as of a1b2c3d4) · changed since: app/Services/PriceCalculator.php
Rule: code at HEAD decides what the code IS (files, symbols, lines, what is built). Memory, CLAUDE.md and vault/unit/bolt-report claims about what the code IS are derived: no SHA = hint, contradicts HEAD = STALE; say so, never use them silently. What the code SHOULD do stays with the vault: a spec-vs-code mismatch is a CONFLICT for a human.
```

After the next GROUND (M/L entry — the front door or sync) the engine recomputes and the line reads `shop: STALE since a1b2c3d4 · 1 file(s): app/Services/PriceCalculator.php · f6e5d4c fix: price rounding`. (The per-unit bindings carry script stamps, so the vault can read FRESH; a pre-9.0 vault's model-typed stamps render as `(stamp model-typed: hint)` instead.)

(The block is informational and never tells the model to run `/mega-sdd` or sync — a continuation prompt like `lanjut` with no chain marker this session stays tier S; the sync proposal appears when YOU enter an M/L lane. Open the front door or invoke sync yourself:)

## Act 3 — autonomous reconcile (one confirmation, zero mid-chain questions)

```
/mega-sdd:sync --auto
```

Expected chain (Mode D):

| Phase | What you should see |
|---|---|
| Change summary | journal rows ∪ git delta, deduped (e.g., "3 changed paths") — shown BEFORE the confirm |
| `scripts/derive-changed-paths.sh --vault <vault>` | changed set = git delta since the index stamp ∪ working tree ∪ journal rows → `<vault>/.sync-changed-paths.txt` (a script, zero model tokens); the journal is rotated (`.consumed-<ts>`) after the write and deleted on the next successful run |
| `scripts/sync-intersect.sh --cwd=. --vault=<vault> --paths=@<vault>/.sync-changed-paths.txt` | the short-circuit gate: changed set ∩ (binding anchors ∪ unit `target_files`) empty → one-line `SYNC-REPORT.md` "in sync", chain ENDS; exit 4 → continue; any other exit → the full chain (fail-closed) |
| `detect-drift --scope=@<vault>/.sync-changed-paths.txt` (scoped to the changed set — the forked skill can't re-resolve the now-consumed journal) | finds the rename as `name drift [HIGH]` from the `## Data model` / `## Flows` sections; under `--auto` it does NOT ask — queues the direction call. Architecture-prose drift is not detectable on a plan-born vault (named in the report as n/a, never "no drift") |
| `scripts/rebind-units.sh --cwd=. --vault=<vault> --paths=@<vault>/.sync-changed-paths.txt` | ONLY the units whose `target_files` ∪ `## Anchors` ∪ per-unit binding anchors intersect the changed set are re-verdicted by the SAME JIT writers (`derive-unit-claims` → `write-unit-binding` → `validate-handoff-binding-units --units=`); exit 0 = nothing affected, 4 = re-bound (read `gate`); a CONFLICT closes the gate for the affected units exactly as at dispatch — never auto-resolved |
| `plan --reconcile` | existing unit IDs updated in place: `task_type` flips only from the unit's refreshed `bolts/U-XXX/binding.json` claims (e.g. a `create` unit whose file landed out of band, its claim resolved `KEEP_CODE` → `extend`, or `verify` when every target is present; an unresolved CONFLICT → no flip); `status:` recomputed from `compute-unit-staleness.sh`; a unit whose `context.md` home is gone → `superseded`. It adds no unit and never rewrites `context.md` |
| `execute-bolts --all --lite` | only stale units re-run; `superseded` skipped with a warning; the run ends with `delivery-check.sh` |

End of run: `<vault>/SYNC-REPORT.md` (per-phase outcomes, the verify-recommended (transitive impact) list, and the closing staleness verification `stale=0 ✅`) and, because the rename needs a human direction call, `<vault>/PENDING-SYNC.md` with one open item.

A NEW requirement is not the reconcile pass's to fill: it goes `diff-vault` (a PRD revision, or `--from-prompt` for a ticket-scale brief) → `plan --regenerate`. No baseline (no symbol index, or `derive-changed-paths.sh` exit 3) → detect-drift is skipped and the FULL re-bind runs (`rebind-units.sh --units=all`) → `plan --reconcile` → `execute-bolts --all --lite` — never a guessed scope.

Full audit = `scripts/rebind-units.sh --units=all` (the meaning of `sync --full-bind`): every unit re-verdicted, every open CONFLICT blocking.

**Replay (fixture-driven, CI):** `bash tests/v8-layout3/test-state-sync-lite.sh` — both channels reach `maintenance_sync` with the 5-hop chain above (the short-circuit is a gate between hops, not a hop), hop 1 and hop 3 are executed on the fixture (only the touched unit is re-bound, sibling untouched), a pre-9.0 layout-2 vault routes to `layout2_needs_migration` (migrate-paths proposed, no sync chain), a retired `lane: standard` key gets a one-line note and changes nothing, and the "re-run → in sync" criterion below holds (stamp == HEAD + no journal → not `maintenance_sync`). Replayed 2026-09-27 on the 9.0 working tree: 9/9 PASS.

## Act 4 — clear the queue (when you're ready)

Open `PENDING-SYNC.md`: the rename drift asks *vault stale (code is right) vs code regressed (vault is right)*. Decide → `UPDATE_VAULT` drafts the patch with git provenance (`f6e5d4 "rename to failed_attempts" — <teammate>, <date>`); ACCEPT applies it, bumps the vault version, regenerates `vault.json` under the lock. Or run with `--auto-apply=safe` next time to auto-apply this exact class.

`auto_verify_on_edit: true` (default false) offers the touched unit's acceptance run.

## Pass criteria

- [ ] All three change channels detected (journal for in-session; git for manual/pull)
- [ ] The session-start state block named the moved path under the vault (miss form: "changed since: …"); GROUND then named it STALE (file + commit); after a clean sync + GROUND it no longer does
- [ ] No mid-chain questions under `--auto`; human decisions queued, chain completed
- [ ] Units outside the changed set keep their `bolts/U-XXX/binding.json` byte-identical (the scoped re-bind never touches them)
- [ ] No open CONFLICT silently cleared: one outside the changed set still closes its unit's gate at dispatch (`--full-bind` re-verdicts every unit)
- [ ] `plan --reconcile` added no unit; every flip names its claim id
- [ ] `SYNC-REPORT.md` closing verification: `stale=0` or explained
- [ ] When bolts re-ran: the run ends with the result contract — the acceptance-criterion → test table, `delivery-check.sh` `VERDICT: PASS` on the final commit, the assumptions and decisions made
- [ ] Re-running `/mega-sdd:sync` immediately → "in sync", stops (no vacuous re-run)

## Anti-patterns this scenario guards against

- Re-binding every unit of a large vault for a 3-file change
- The vault silently rotting while hotfixes pile up
- Autonomy that auto-resolves CONFLICTs (it never does — the moat is intact)
- A sync that says "done" without proving staleness reached zero
