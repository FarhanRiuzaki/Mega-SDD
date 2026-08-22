# Upgrading from an older mega-sdd version

> Field-test feedback: users with old mega-sdd projects need a clear "what works / what migrates / what halts" guide. This doc consolidates the answer.

**Companion docs:** `reading-map.md` (where to read), `paths.md` (canonical layout), `CHANGELOG.md` (per-iter behavior changes), `tests/scenarios/scenario-6-recovery-from-halt.md` (generic halt recovery walkthrough).

## Contents

- Upgrading to 7.0.0 (the vault layout-2 major)
- Upgrading to 6.0.0 (the alias-removal major)
- TL;DR — two paths
- Per-iter behavior changes (Iter 36-62, added Iter 62 per F-E-4)
- Recommended upgrade paths
- Compatibility matrix
- Migration commands — run in this order
- Common halts after upgrade + recovery
- Decision tree
- Per-iter behavior changes (what changed between iters affects you)
- Pre-flight checklist before upgrade
- See also

## Upgrading to 7.0.0 (the vault layout-2 major)

**What changed:** `generate-intent` now emits the **4-file layout-2 vault** (`vault.md` / `model.md` / `flows.md` / `constraints.md` + `vault.json`) instead of the 7-file `00-index.md … 06-constraints.md` set. The six Vault Lock values live as `vault.md` YAML frontmatter; ALL Open Questions live in `constraints.md ## Open Questions` (per-line `[origin: <file>#<anchor>]` keeps locality; the 00-index roll-up is retired); `## Overview` / `## Architecture` / `## Decisions` are EXACT hard-header anchors (deriver + claims-ledger exit 2 when missing). Mapping table: `references/paths.md §Vault layout`.

**What did NOT break:** every EXISTING 7-file vault keeps working — every reader (deriver, ledger, validators, hook dispatch, emission builders, skills) is **dual-layout for one minor cycle** (probes the layout-2 file first, falls back to the legacy name; floor v5.9.0). Binding, units, bolts, gates: untouched.

**Migrating an existing vault (optional, recommended):**
1. `bash $PLUGIN_ROOT/scripts/migrate-paths.sh --vault-layout --cwd=<project>` — DRY-RUN preview (names what moves and what ceremony drops).
2. Commit your tree, then re-run with `--apply` (dirty tree is refused). The rung concatenates verbatim, stamps `[origin:]` on moved OQs, rewrites unit doc-name refs, runs `derive-vault-json`.
3. **MANDATORY next step: full re-bind** — the merge shifted line numbers, so `binding.md`/`binding.json`/`.citation-map.json` anchors are stale; they are REGENERATED (run bind again), never patched. Graph + emissions self-heal on the next run.

## Upgrading to 6.0.0 (the alias-removal major)

**What broke (the ONLY break):** the 24 `/mega-sdd:<stage>` typed deprecation aliases no longer register as slash commands (`generate-intent`, `scan-codebase`, `bind-codebase`, `generate-units`, `execute-bolts`, `resolve-oq`, `detect-drift`, `diff-vault`, `analyze`, `graph`, `lint-units`, `list-modules`, `replay`, `migrate-rules`, `validate-handoff`, `enrich-semantics`, `analyze-parallelism`, `extract-intelligence`, `orchestrate-flow`, `auto`, `emit-fsd`, `emit-prd`, `emit-sit`, `emit-agents-md`). Removal per policy: demoted at 5.0.0, removable the following major after telemetry review (performed 2026-08-04; honest scope: the telemetry corpus records skill events + ref-loads and has NO channel that logs typed command invocations, so it can attest no alias usage — the review is discharged procedurally, and the field floor is covered by this guide, not by the corpus).

**What did NOT break:** every artifact (vault, binding.md, units, bolts), every gate and hook contract, the classic spine (`--classic` / `spine: classic`), all legacy read-side paths (`docs/mega-sdd/…`, `.mega-sdd-memory/` — deliberately KEPT, they cost one glob each), and all four maintenance one-timers. **Typing an old form still works in practice:** an unregistered legacy form (say, the old typed analyze alias) arrives as plain text and routes to the matching skill — you lose only the registered slash-command autocompletion.

**The 6.0.0 surface:** `/mega-sdd` (front door) · `/mega-sdd:sync` · `/mega-sdd:emit <prd|fsd|sit|uat>` + one-timers `install-deps` / `update-plugin` / `memory` / `migrate-paths`. Everything else: natural-language phrase ("cek konsistensi", "lint units", "cek drift", "blast radius"). The full 24-row old-form → new-way map lives in the plugin `README.md §Commands you'll actually use`.

**Where the alias content went (nothing was deleted blind):** `lint-units`/`analyze-parallelism`/`list-modules`/`enrich-semantics` procedures → `skills/orchestrate-flow/references/diagnostics-procedures.md`; `validate-handoff` → `skills/bind-codebase/references/handoff-validation.md`; `migrate-rules` → `skills/execute-bolts/references/` (the relocated `replay` lane was later removed entirely in v7 — git history); `analyze` modes → `skills/analyze/SKILL.md`.

**Office-floor path (v5.9.0 laptops):** `/mega-sdd:update-plugin` → `/plugin marketplace update mega-sdd` → restart/`/reload-plugins`. No project migration needed — 6.0.0 changes the COMMAND surface only; a 5.x vault/binding/units tree is consumed unchanged, and the express spine has been the default since 5.35.0.

**Also in 6.0.0:** the on-demand doc pack now derives fully from the modern vault generation (FSD §5 from `04-flows.md` when `02-functional.md` is absent, §6 from `06-constraints.md`, §10/PRD §6 accept the `tag`/`text` vault.json OQ shape) — older vaults keep their legacy sources via first-hit-wins.

## TL;DR — two paths

**Path A (easiest, recommended): Regenerate from inputs**
Keep your original PRD or KB; regenerate vault + binding + units fresh on the new schema. Skips most compat issues. ~5 min.

**Path B (preserve existing vault + binding + bolts):**
Run migrations → expect 1-2 schema halts → recover via halt envelope hints. ~15-30 min.

> **v3.41.0+ Iter 62 update (per F-E-4):** target version refreshed from v3.26.1 (Iter 36 doc baseline) to v3.41.0. Per-iter behavior summary covers Iter 36-62 (table below). Existing migration commands + recovery sections still valid; new sections cover Iter 54+ (emit-fsd), Iter 55+ (install-deps), Iter 60 (F4 bypass tightening).

## Per-iter behavior changes (Iter 36-62, added Iter 62 per F-E-4)

| Iter | Plugin version | What changed | Migration impact |
|---|---|---|---|
| 36 | v3.26.1 | Upgrade guide consolidation (this doc origin) | none (doc-only) |
| 37 | v3.26.2 | Scenarios coverage + README audit | none |
| 38 | (audit) | E2E pipeline audit (37 findings) | none |
| 39-52 | v3.26.3 → v3.35.1 | Iter 38 audit closure | mostly compatible; some skill schemas refined |
| 43, 48, 52 | (fix-forward) | Caught 4 release-blocker regressions | run `--resume` after patches |
| 53 | v3.36.0 | Consumer wiring closure (3 PARTIAL → USED) | new `quality_gate_failed:starterkit_metrics_inconsistent` subtype |
| 54 | v3.37.0 | **NEW skill `emit-fsd`** (Confluence FSD generator) | optional opt-out via `--no-fsd` |
| 55 | v3.38.0 | **NEW skill `install-deps`** (OS-aware auto-installer) | user-explicit invocation; not auto-triggered |
| 56 | (audit) | Deep audit of v3.38.0 (38 findings) | none |
| 57 | v3.38.1 | CRITICAL fix-forward (B-P1 + D1 + F-E-2) | binding.md gains `binding_metadata:` block (additive); `--rollback` menu default flipped to `[I] interactive` (safer) |
| 58 | v3.39.0 | Halt taxonomy: +9 enum entries + `quality_gate_failed` subtypes | downstream consumers branch on `details.subtype` for `quality_gate_failed` |
| 59 | v3.39.1 | Contract sweep: emit-fsd + install-deps Per-skill blocks | adds TYPE annotations (advisory until Iter 60) |
| 60 | v3.40.0 | **F4 bypass tightening — anti-halu rail behavior change** | fields without TYPE annotation halt-against-author; migration via `--legacy-type-bypass (RETIRED in v4.75.0 — un-annotated fields are warn-only under the deterministic validator; no migration flag needed)` for one chain run |
| 61 | v3.40.1 | Catch-all P2/P3 closure | emit-fsd citation slot extraction wired (Iter 54 dead-code fixed); test fixtures added |
| 62 | v3.41.0 | Remaining Iter 56 audit closure (scenario sweep + doc bulk) | scenario-6 +8 walkthroughs; predictive-check coverage extended; `next_action` canonical shape documented |

## Recommended upgrade paths

- **v3.0-v3.25 → v3.41.0:** use Path A (regenerate from PRD/KB). Many schema + behavior changes accumulated; regen is faster than migrating each artifact.
- **v3.26-v3.37 → v3.41.0:** use Path B with `--legacy-type-bypass (RETIRED in v4.75.0 — un-annotated fields are warn-only under the deterministic validator; no migration flag needed)` flag for first chain run; remove flag after handoff TYPE annotations are in place.
- **v3.38-v3.40 → v3.41.0:** seamless upgrade; existing chains compatible.

## Compatibility matrix

| Old artifact | Works on v3.41.0? | What to do |
|---|---|---|
| `docs/mega-sdd/vaults/<slug>/` legacy path | Read OK (back-compat probe) | Optional: `/mega-sdd:migrate-paths` |
| `.mega-sdd-memory/` legacy path | Read OK (back-compat probe) | Same |
| `<repo-root>/codebase-map.md` legacy location | Read OK (back-compat probe) | Re-run `scan-codebase` to write canonical `.mega-sdd/codebase/codebase-map.md` |
| Pre-v1.4 KB without `[LOCKED]/[INTENT]/[ARTIFACT]` markers | Yes — all claims default to `[INTENT]` (safe middle-ground) | None (auto-fallback) |
| Pre-v2.4 codebase-map without §7 Framework | Yes — falls back to `_universal` framework pack | None |
| Vault without `scope_metadata` (legacy single-scope) | Yes — treated as legacy single-vault; `scope:` blocks omitted | None |
| Vault without `phase`/`phase_total` fields (pre-Iter-35) | Yes — defaults to `phase: 1, phase_total: 1` | None |
| Pre-Iter-8 binding without `PARTIAL_FIELDS_*` states | Yes — unknown states default to `create` (conservative) | Consider re-binding for finer task_type granularity |
| Pre-Iter-46 binding without `binding_metadata.codebase_map_provenance` field (Iter 57 fix-forward) | Yes — orchestrate-flow Step 3 falls through to "no-snapshot" branch (keeps scan-codebase in chain) | Optional: re-run bind-codebase to populate field for chain-optimization benefit |
| Old `memory_schema:` version stamp | May halt `memory_schema_mismatch` | `/mega-sdd:memory migrate` |
| Pre-Iter-30 bolt-reports without provenance trailer | New bolts OK; re-running old bolts halts | Skip re-runs OR add trailer manually |
| Pre-Iter-33 handoff YAML missing `scope:`/`mutability:` blocks | Halt `invalid_handoff` on re-run via orchestrate-flow Step 6.b validation gate | Edit handoff template OR regenerate vault (Path A) |
| Pre-Iter-60 skill handoffs with fields lacking TYPE annotation | Halt `handoff_type_mismatch` (strict default v3.40.0+) | Run with `--legacy-type-bypass (RETIRED in v4.75.0 — un-annotated fields are warn-only under the deterministic validator; no migration flag needed)` flag for one chain run; fix handoff-contract.md TYPE annotations; remove flag |
| Pre-Iter-58 chain emitting halt names from the 9 newly-enumerated orphans | Now accepted (Iter 58 closed enum gap) | None — no action needed |

## Migration commands — run in this order

```bash
# 1. Canonicalize paths (legacy → .mega-sdd/)
/mega-sdd:migrate-paths --dry-run        # preview only
/mega-sdd:migrate-paths                  # actual move via git mv (preserves history)

# 2. Migrate memory schema (auto-detects out-of-date stamps)
/mega-sdd:memory migrate

# 3. Migrate Hard Rules v1 grammar → v2 ast-grep YAML (per-unit confirm)
#    (not a slash command since 6.0.0 — ask by phrase:)
#    "/mega-sdd" → "migrate hard rules <vault-path>"
```

All three are idempotent — safe to re-run.

## Common halts after upgrade + recovery

### `postflight_evidence_missing` / `hard_rule_violated` on PREVIOUSLY-GREEN bolts (v4.79.0 Hard-rule engine hardening)

**Cause:** the B1 gate RECOMPUTES each committed Hard-rule bolt's postflight scan from git/fs ground truth, and v4.79.0 fixed several engine holes — so a bolt that passed under the old engine can flip to fail at the next `execute-bolts` gate purely from upgrading. Expected flips (each means the lock was previously being dodged, not a false alarm): `*`/`+`/numbered-bullet locks now execute; v2 ast-grep rules with relative `files:` globs were silently INERT and now actually scan; `MUST NOT modify <path>` / `NEVER add new <manifest> dependencies` (path-shaped object) recompute as MECHANICAL past old attestations; SIGNATURE_RULE now requires exact parameter-list equality (added params fail). Also: a wrapped directive bullet is now lexed JOINED with its continuation lines, so its attest carry-forward key changes — a previously attested directive downgrades to `directive_unverified` once.

**Recovery:** fix the violating code forward (or `git revert` the bolt commit) and re-run `scripts/run-postflight-scan.sh --cwd=<root> --unit=U-XXX`; re-attest re-keyed directives with `--attest-directives="<who/why>"`. If the RULE text is wrong, edit the unit's `## Hard rules` and COMMIT the edit as `fix(U-XXX): correct hard rule` — the gate recomputes against the unit text at the newest unit commit.

### `whitelist_violation` / new B-gate blocks on legacy layouts / suite refusals (v4.80.0 validator hardening)

**Cause:** three v4.80.0 hardenings surface on upgrade. (i) **B3 anchored matching** — the whitelist observer no longer honors suffix/fnmatch tolerances, so a past bolt commit (within the 300-commit walk) that relied on them (`legacy/app/config.py` for target `app/config.py`; `src/a/b/x.py` for `src/*.py`) now flips `whitelist_violation`. That commit DID escape its declared scope — review it; if the change is right, add the escaped paths to the unit's `target_files` and re-save. (ii) **Legacy-layout activation** — a project whose vault lives under `docs/mega-sdd/` or a `*-bound/` sibling (pre-`migrate-paths`, no `.mega-sdd/` dir) previously got ZERO B1/B2/B3/orphan coverage; on upgrade the gates activate at once (a `.mega-sdd/` dir is created for state) and `bolt_artifacts_missing` / `postflight_evidence_missing` / `batch_suite_gate_missing` are likely on the first `execute-bolts` — the dormant gates never forced those artifacts. Follow each halt's remediation (backfill or re-run); this is coverage arriving, not breakage. (iii) **run-full-suite refusals** — the wrapper now exits 2 on a dirty CODE tree, an empty repo, or a non-substantive `--vault`: commit or stash code changes first (add untracked litter like `.env`/caches to `.gitignore` — never commit secrets to clear a gate).

### `invalid_handoff` (Iter 33 F3 schema validation gate)

**Cause:** old skill body emits handoff YAML missing `scope:` / `mutability:` / `constitution:` blocks; new orchestrate-flow Step 6.b validates against handoff-contract.md REQUIRED/CONDITIONAL/OPTIONAL annotations.

**Halt envelope shows:** `details.failing_skill` + `details.missing_field` + `details.field_severity` + `next_action.hint` (the exact skill template to edit).

**Recovery — two options:**
- **Easy (Path A):** regenerate vault — `generate-intent --kb=<KB>` (or your PRD) → fresh handoff schema. ~5 min.
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
- Full bolt re-run via `execute-bolts --unit=U-XXX` (regenerates everything)

### `bind_conflict` (existing since v0.x)

**Cause:** vault claim contradicts existing code (PRD says X, code does Y).

**Recovery:** halt envelope `details.conflicts[]` shows per-conflict `suggested_action`: `KEEP_VAULT` | `KEEP_CODE` | `DEFER` | `SPLIT`. Choose per claim; re-run.

For full halt taxonomy + recovery walkthrough: `tests/scenarios/scenario-6-recovery-from-halt.md`.

## Decision tree

```
Start: I have an old mega-sdd project on v3.26.1+

  Q: Do I still have the original PRD / KB / brief that generated the vault?

  ├── YES + I want fresh modern artifacts (Path A — RECOMMENDED)
  │     → /mega-sdd <original-input>
  │     → Lets pipeline regenerate vault + binding + units fresh on new schema
  │     → 5 min; minimal friction
  │
  └── NO + I want to preserve existing work (Path B — preservation mode)
        ↓
        /mega-sdd:migrate-paths           # canonicalize legacy paths
        ↓
        /mega-sdd:memory migrate          # if memory_schema_mismatch fires
        ↓
        /mega-sdd --resume           # continues pipeline; halts on real schema gaps
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
2. ✅ Note current plugin version (compare against the latest in `CHANGELOG.md` after)
3. ✅ Decide: Path A (regenerate) OR Path B (preserve)
4. ✅ If Path B: backup `~/.mega-sdd/memory/` to a safe location (memory migrate creates its own backup but extra safety is cheap)
5. ✅ Update plugin: `/mega-sdd:update-plugin` → `/plugin marketplace update mega-sdd` → restart / `/reload-plugins`
6. ✅ Run the migration sequence per above

## See also

- `plugins/mega-sdd/references/reading-map.md` — where to read at each pipeline stage (Iter 35)
- `plugins/mega-sdd/references/paths.md` — canonical write paths (v3.4+ Iter 10)
- `CHANGELOG.md` — per-iter behavior changes
- `tests/scenarios/scenario-6-recovery-from-halt.md` — generic halt recovery walkthrough
- `plugins/mega-sdd/commands/migrate-paths.md` — path migration command details
- `plugins/mega-sdd/skills/execute-bolts/references/migrate-rules.md` — Hard Rules grammar migration
