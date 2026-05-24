# Upgrading from an older mega-sdd version

> Field-test feedback: users with old mega-sdd projects need a clear "what works / what migrates / what halts" guide. This doc consolidates the answer.

**Companion docs:** `reading-map.md` (where to read), `paths.md` (canonical layout), `CHANGELOG.md` (per-iter behavior changes), `tests/scenarios/scenario-6-recovery-from-halt.md` (generic halt recovery walkthrough).

## TL;DR — two paths

**Path A (easiest, recommended): Regenerate from inputs**
Keep your original PRD or KB; regenerate vault + binding + units fresh on the new schema. Skips most compat issues. ~5 min.

**Path B (preserve existing vault + binding + bolts):**
Run migrations → expect 1-2 schema halts → recover via halt envelope hints. ~15-30 min.

## Compatibility matrix

| Old artifact | Works on v3.26.1? | What to do |
|---|---|---|
| `docs/mega-sdd/vaults/<slug>/` legacy path | Read OK (back-compat probe) | Optional: `/mega-sdd:migrate-paths` |
| `.mega-sdd-memory/` legacy path | Read OK (back-compat probe) | Same |
| `<repo-root>/codebase-map.md` legacy location | Read OK (back-compat probe) | Re-run `scan-codebase` to write canonical `.mega-sdd/codebase/codebase-map.md` |
| Pre-v1.4 KB without `[LOCKED]/[INTENT]/[ARTIFACT]` markers | Yes — all claims default to `[INTENT]` (safe middle-ground) | None (auto-fallback) |
| Pre-v2.4 codebase-map without §7 Framework | Yes — falls back to `_universal` framework pack | None |
| Vault without `scope_metadata` (legacy single-scope) | Yes — treated as legacy single-vault; `scope:` blocks omitted | None |
| Vault without `phase`/`phase_total` fields (pre-Iter-35) | Yes — defaults to `phase: 1, phase_total: 1` | None |
| Pre-Iter-8 binding without `PARTIAL_FIELDS_*` states | Yes — unknown states default to `create` (conservative) | Consider re-binding for finer task_type granularity |
| Old `memory_schema:` version stamp | May halt `memory_schema_mismatch` | `/mega-sdd:memory migrate` |
| Pre-Iter-30 bolt-reports without provenance trailer | New bolts OK; re-running old bolts halts | Skip re-runs OR add trailer manually |
| Pre-Iter-33 handoff YAML missing `scope:`/`mutability:` blocks | Halt `invalid_handoff` on re-run via orchestrate-flow Step 6.b validation gate | Edit handoff template OR regenerate vault (Path A) |

## Migration commands — run in this order

```bash
# 1. Canonicalize paths (legacy → .mega-sdd/)
/mega-sdd:migrate-paths --dry-run        # preview only
/mega-sdd:migrate-paths                  # actual move via git mv (preserves history)

# 2. Migrate memory schema (auto-detects out-of-date stamps)
/mega-sdd:memory migrate

# 3. Migrate Hard Rules v1 grammar → v2 ast-grep YAML (per-unit confirm)
/mega-sdd:migrate-rules <vault-path>
```

All three are idempotent — safe to re-run.

## Common halts after upgrade + recovery

### `invalid_handoff` (Iter 33 F3 schema validation gate)

**Cause:** old skill body emits handoff YAML missing `scope:` / `mutability:` / `constitution:` blocks; new orchestrate-flow Step 6.b validates against handoff-contract.md REQUIRED/CONDITIONAL/OPTIONAL annotations.

**Halt envelope shows:** `details.failing_skill` + `details.missing_field` + `details.field_severity` + `next_action.hint` (the exact skill template to edit).

**Recovery — two options:**
- **Easy (Path A):** regenerate vault — `/mega-sdd:generate-intent --kb=<KB>` (or your PRD) → fresh handoff schema. ~5 min.
- **Surgical (Path B):** manually add the missing block to your skill's handoff template per `handoff-contract.md §schema`. Re-run chain.

### `memory_schema_mismatch`

**Cause:** memory file has older `memory_schema:` stamp than current version expects.

**Recovery:** `/mega-sdd:memory migrate` — auto-migrates with backup at `~/.mega-sdd/memory.backup.YYYYMMDD/`. Memory data fully preserved.

### `handoff_type_mismatch` (Iter 33 F4 type-check)

**Cause:** old handoff field has wrong type (e.g., `scope.id` as object instead of string enum).

**Recovery:** halt envelope shows `expected_type` + `actual_type` + `actual_value`. Either fix the skill template OR regenerate via Path A.

### `provenance_missing` (Iter 30)

**Cause:** old bolt-report lacks provenance trailer (introduced Iter 30).

**Recovery:** only fires on RE-running old bolts. New bolts emit trailer automatically. Options:
- Skip the re-run (use existing bolt outputs)
- Add provenance trailer to old file manually
- Full bolt re-run via `/mega-sdd:execute-bolts --unit=U-XXX` (regenerates everything)

### `bind_conflict` (existing since v0.x)

**Cause:** vault claim contradicts existing code (PRD says X, code does Y).

**Recovery:** halt envelope `details.conflicts[]` shows per-conflict `suggested_action`: `KEEP_VAULT` | `KEEP_CODE` | `DEFER` | `SPLIT`. Choose per claim; re-run.

For full halt taxonomy + recovery walkthrough: `tests/scenarios/scenario-6-recovery-from-halt.md`.

## Decision tree

```
Start: I have an old mega-sdd project on v3.26.1+

  Q: Do I still have the original PRD / KB / brief that generated the vault?

  ├── YES + I want fresh modern artifacts (Path A — RECOMMENDED)
  │     → /mega-sdd:auto <original-input>
  │     → Lets pipeline regenerate vault + binding + units fresh on new schema
  │     → 5 min; minimal friction
  │
  └── NO + I want to preserve existing work (Path B — preservation mode)
        ↓
        /mega-sdd:migrate-paths           # canonicalize legacy paths
        ↓
        /mega-sdd:memory migrate          # if memory_schema_mismatch fires
        ↓
        /mega-sdd:auto --resume           # continues pipeline; halts on real schema gaps
        ↓
        For each halt: read halt envelope next_action.hint; apply suggested fix
        ↓
        If halt persists after 2 fix attempts → fall back to Path A
```

## Per-iter behavior changes (what changed between iters affects you)

For full per-iter detail, see `CHANGELOG.md`. Highlights of iters that introduce migration-relevant changes:

- **Iter 8 (v3.x)** — Implementation-State Map adds `PARTIAL_FIELDS_*` states; old binding.md still parses (unknown states → `create`)
- **Iter 9 (v3.x)** — memory schema stamping; auto-migrate via `memory migrate`
- **Iter 10 (v3.4+)** — path consolidation under `.mega-sdd/`; `migrate-paths` command introduced
- **Iter 22 (v3.14+)** — KB mutability tiers `[LOCKED]/[INTENT]/[ARTIFACT]`; pre-Iter-22 KBs default all claims to `[INTENT]`
- **Iter 27 (v3.19+)** — starterkit-first pipeline reorder (scan-codebase runs FIRST in brownfield); old chains still work via routing-rules.md back-compat
- **Iter 30 (v3.22+)** — provenance trailer mandatory in bolts; old bolt-reports lack trailer; re-runs halt `provenance_missing`
- **Iter 33 (v3.24+)** — handoff schema validation gate (REQUIRED/CONDITIONAL/OPTIONAL + TYPE annotations); old handoffs may halt `invalid_handoff` / `handoff_type_mismatch`
- **Iter 35 (v3.26+)** — `phase`/`phase_total` fields in vault.json; old vaults default to `phase: 1, phase_total: 1`

## Pre-flight checklist before upgrade

1. ✅ Commit your current work (`git status`; commit any uncommitted changes)
2. ✅ Note current plugin version (was v3.X.Y; will be v3.26.1 after)
3. ✅ Decide: Path A (regenerate) OR Path B (preserve)
4. ✅ If Path B: backup `~/.mega-sdd/memory/` to a safe location (memory migrate creates its own backup but extra safety is cheap)
5. ✅ Update plugin: in Claude Code → `/plugin update mega-sdd`
6. ✅ Run the migration sequence per above

## See also

- `plugins/mega-sdd/references/reading-map.md` — where to read at each pipeline stage (Iter 35)
- `plugins/mega-sdd/references/paths.md` — canonical write paths (v3.4+ Iter 10)
- `CHANGELOG.md` — per-iter behavior changes
- `tests/scenarios/scenario-6-recovery-from-halt.md` — generic halt recovery walkthrough
- `plugins/mega-sdd/commands/migrate-paths.md` — path migration command details
- `plugins/mega-sdd/commands/migrate-rules.md` — Hard Rules grammar migration
