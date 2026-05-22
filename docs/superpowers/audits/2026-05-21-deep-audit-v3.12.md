# Mega-SDD Deep Audit (v3.12.0)

**Date**: 2026-05-21
**Trigger**: User request — "deep audit and find gaps about all this skills project"
**Method**: Empirical verification (file content, grep, version matrix) against documented claims across 19 iterations
**Bias check**: Honest, not promotional. Multiple GAPS found — Iter 17-19 have meaningful drift between documented behavior and shipped reality.

---

## Executive Summary

After 19 iterations, mega-sdd v3.12.0 has accumulated **significant drift** in the most recent iters. Foundation (Iter 0-14) is solid; Iter 15-19 has documentation-vs-implementation gaps.

| Severity | Count | Examples |
|---|---|---|
| 🔴 **Critical bugs** (claimed-but-not-implemented) | 5 | execute-bolts PBT, bind-codebase constitution, detect-drift constitution, emit-agents-md constitution, resolve-oq --non-interactive |
| 🟡 **Documentation drift** | 4 | README + plugin README outdated, scenarios outdated, handoff-contract.md missing fields |
| 🟠 **Coverage gaps** | 3 | No test fixtures for Iter 17-19, modules.yaml no JSON Schema, memory migration scripts placeholder only |

**Total touch points audited**: 12 skills × ~5 procedures + 20 commands + 8 references + 6 scenarios + ~14 test fixtures + CHANGELOG = ~140 audit points. **Drift density: ~9%** (12 issues / 140 points). Up from ~12% in Iter 9 audit but with HIGHER severity (claimed features not implemented vs. theoretical/algorithmic claims).

**Top-line verdict**: Iter 17-19 should be partially un-shipped OR have their gaps closed. Without fix, users invoking those features hit broken behavior.

---

## Part 1 — Skill Version Matrix (verified)

```
extract-intelligence: 1.2.0     (Iter 10 — folder consolidation)
generate-intent:      1.9.0     (Iter 17 — constitution gen)
scan-codebase:        2.3.0     (Iter 14 — ripgrep adoption)
bind-codebase:        1.7.1     (Iter 9 — audit Bug 1 fix)
generate-units:       2.5.0     (Iter 18 — PBT emission)
execute-bolts:        2.3.0     (Iter 18 — PBT validation; ⚠️ CLAIMED-NOT-IMPLEMENTED)
orchestrate-flow:     2.3.0     (Iter 19 — convergence loops)
resolve-oq:           0.8.0     (Iter 15 — handoff YAML)
diff-vault:           1.2.0     (Iter 15 — handoff YAML)
detect-drift:         1.1.0     (Iter 15 — handoff YAML)
memory:               1.2.0     (Iter 10 — folder paths)
emit-agents-md:       1.1.0     (Iter 10 — vault detection)
using-mega-sdd:       1.2.0     (Iter 13 — sharper auto-trigger)
```

Plugin version: 3.12.0.

✅ All skill versions stamped consistently. No mismatches.

---

## Part 2 — Critical Bugs (claimed-but-not-implemented)

### 🔴 Bug 1 — execute-bolts v2.3 has ZERO PBT references

**Claim** (CHANGELOG v3.11.0): "execute-bolts v2.2 → v2.3 runs PBT in acceptance phase; error-severity failures halt with counterexample preserved"

**Reality** (`grep -c "PBT|property-based|pbt_property_violated" plugins/mega-sdd/skills/execute-bolts/SKILL.md`): **0 matches**.

**Impact**: Users adding `properties:` to unit schema → execute-bolts has NO procedure to run them. Hard rules pre/post-flight scan won't touch PBT tests. `pbt_property_violated` halt type never fires.

**Severity**: HIGH. Version bumped without actual integration. Misleading.

**Fix**: Add PBT validation step to execute-bolts Procedure (after Step 4 Pre-flight, before Step 5 commit). Detect PBT framework; run tests; halt on error-severity violations with counterexample.

### 🔴 Bug 2 — bind-codebase has ZERO constitution references

**Claim** (CHANGELOG v3.10.0): "bind-codebase (v1.7+) cites constitution clauses when surfacing CONFLICTs; flags binding entries that violate constitution as halts"

**Reality** (`grep -c "constitution" plugins/mega-sdd/skills/bind-codebase/SKILL.md`): **0 matches**.

**Impact**: Constitution layer (Iter 17 hallmark) doesn't integrate at binding gate. CONFLICTs don't reference constitution clauses. Constitution violations not flagged as halts.

**Severity**: HIGH. Iter 17's primary integration point missing.

**Fix**: Add Step 2.9 to bind-codebase Procedure — read constitution.md; cross-reference CONFLICTs against §A-F clauses; surface clause citations in binding.md.

### 🔴 Bug 3 — detect-drift has ZERO constitution references

**Claim** (CHANGELOG v3.10.0): "detect-drift (v1.1+) flag code violating constitution as drift findings"

**Reality** (`grep -c "constitution" plugins/mega-sdd/skills/detect-drift/SKILL.md`): **0 matches**.

**Impact**: Code can drift from constitution silently. Iter 17's drift-aware integration missing.

**Severity**: MEDIUM-HIGH. detect-drift is event-driven (periodic check); less acute than Bug 2 but still violated claim.

**Fix**: Add constitution-drift detection — for each constitution §A-F clause, probe codebase for violations; flag as drift findings.

### 🔴 Bug 4 — emit-agents-md doesn't emit constitution

**Claim** (CHANGELOG v3.10.0 — implicit): constitution.md is project-facing rules; should be flattened into AGENTS.md for tool-agnostic consumption.

**Reality** (`grep -c "constitution" plugins/mega-sdd/skills/emit-agents-md/SKILL.md plugins/mega-sdd/skills/emit-agents-md/references/agents-md-schema.md`): **0 matches in either file**.

**Impact**: External tools (Continue.dev, Cursor) consuming AGENTS.md don't get constitution context. Iter 17 + Iter 6 interop incomplete.

**Severity**: MEDIUM. AGENTS.md is interop file; missing constitution section means external tools miss project invariants.

**Fix**: Add §Constitution section to AGENTS.md schema; emit-agents-md flattens constitution clauses.

### 🔴 Bug 5 — resolve-oq has no --non-interactive / --auto-accept flag

**Claim** (Iter 19 convergence loops): "Auto-invoke `resolve-oq --binding` with memory-pre-filled recommendations → re-run `bind-codebase`"

**Reality**: resolve-oq v0.8.0 has NO flag for non-interactive auto-accept of memory recommendations. Skill is fully interactive (uses AskUserQuestion).

**Impact**: Iter 19 convergence loop calling resolve-oq would still prompt user → "auto-loop" not actually automatic. Contradicts Iter 19 documentation.

**Severity**: HIGH. Core Iter 19 mechanic broken.

**Fix**: Add `--auto-accept-from-memory --confidence-min=0.80` flag to resolve-oq. When set: skill auto-applies memory recommendations meeting confidence threshold; skips AskUserQuestion for those; remains interactive for low-confidence cases.

---

## Part 3 — Documentation Drift

### 🟡 Drift D-1 — README outdated to v3.8.x layout

**Last comprehensive update**: v3.8.1 (docs patch with user-journey rewrite + mermaid).
**Current**: v3.12.0. Missing 3 iters worth of features.

Missing from README:
- **Iter 17 constitution layer** (8th vault file)
- **Iter 18 replay command** (`/mega-sdd:replay`)
- **Iter 18 property-based testing** (`properties:` schema)
- **Iter 19 convergence loops** (`--converge` mode in `/mega-sdd:auto`)

Mermaid pipeline diagram doesn't render constitution, replay, PBT, convergence.

**Fix**: README §Pipeline overview Mermaid updates + Quick start mentions + scenarios link.

### 🟡 Drift D-2 — plugin/mega-sdd/README.md outdated to v3.8.0

Same as Drift D-1 at plugin folder level. Missing 4 iters of features.

**Fix**: Sync plugin README to v3.12.0 reality.

### 🟡 Drift D-3 — Scenarios don't reference Iter 17-19 features

`tests/scenarios/` 6 walkthroughs written v3.8.x era. First-time users running scenarios won't discover:
- Constitution.md (8th vault file)
- Replay command for debugging
- PBT for invariant testing
- Convergence loops in auto mode

**Fix**: Add Scenario 7 — "Constitution + invariants" walkthrough; OR extend existing scenarios with "v3.10+" callouts.

### 🟡 Drift D-4 — handoff-contract.md missing Iter 17-19 schema

`plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` doesn't reference:
- `constitution_hash` field (per Iter 17 vault.json extension)
- Replay artifact paths (per Iter 18)
- Convergence cycle history (per Iter 19)
- New halt types: `pbt_property_violated`, `convergence_max_reached`

**Fix**: Extend handoff YAML schema with Iter 17-19 fields. Update halt protocol table.

---

## Part 4 — Coverage Gaps

### 🟠 Gap C-1 — No test fixtures for Iter 17, 18, 19

3 consecutive iterations without trigger tests OR integration tests:

- Iter 17 (constitution): no `tests/skill-triggering/` case for constitution.md generation or constitution clause injection into Hard Rules
- Iter 18 (replay + PBT): no test for `/mega-sdd:replay` command; no PBT emission test
- Iter 19 (convergence): no test for `--converge` flag behavior; no halt-loop test

**Fix**: Add 8-10 test cases across new artifacts:
- `tests/skill-triggering/generate-intent.test.md` CONST1-CONST3 (constitution generation)
- `tests/skill-triggering/generate-units.test.md` CONST4-CONST6 (constitution clause injection) + PBT1-PBT3 (property emission)
- `tests/skill-triggering/execute-bolts.test.md` PBT4-PBT6 (PBT validation; pbt_property_violated halt)
- `tests/skill-triggering/replay.test.md` NEW (RP1-RP4: capture, diff-vs-prior, divergence classification, --capture-only)
- `tests/skill-triggering/orchestrate-flow.test.md` CONV1-CONV4 (--converge flag, cycle-eligible halts, max-cycles limit, recurring-halt escalation)

### 🟠 Gap C-2 — modules.yaml has no JSON Schema validator

`generate-units/references/modules-schema.md` defines `_meta/modules.yaml` schema as Markdown prose. No machine-validatable JSON Schema. User-typed YAML can have schema errors that aren't caught until skill reads it.

**Fix**: Add `_meta/modules.schema.json` JSON Schema file. Include `check-jsonschema` validation step in generate-units when modules.yaml present. (Defers ITER6-DESIGN-OQ-deferred check-jsonschema integration.)

### 🟠 Gap C-3 — memory schema migration scripts placeholder only

Per Iter 9 audit fix, `plugins/mega-sdd/scripts/memory-migrations/` shipped with `template-migration.sh` scaffold + README. NO actual migration scripts because `memory_schema: 1` is still single version.

**Status**: Acceptable for now (no schema version 2 exists). Risk: when v2 schema introduced, must ship migration script in same release.

---

## Part 5 — Where mega-sdd is genuinely strong (balance)

For balance — audit confirms several iters are SOLID:

- **Iter 1-4 foundation** — task_type, OQ classification, Hard Rules, Autonomy — all integrate cleanly
- **Iter 5 memory layer** — 3 scopes well-defined; writers + readers documented + integrated
- **Iter 6 tech upgrades** — tree-sitter, ast-grep, PageRank, AGENTS.md, checkpoints — all actually shipped with procedure
- **Iter 8 defensive generation + field-level diff** — PARTIAL_FIELDS_MISSING fully integrated
- **Iter 9 audit fixes** — all 6 P0+P1 bugs actually fixed (verified)
- **Iter 10-13 consolidation iterations** — folder paths, modules, sprawl restoration — all shipped + integrated
- **Iter 14 reuse-stable tooling** — ripgrep + jd + markdownlint actually adopted in skill procedures
- **Iter 15 handoff YAML consistency** — all 3 affected skills have actual handoff sections (verified)
- **Iter 16 scan-first brownfield** — orchestrate-flow + generate-intent both updated

Pattern: foundation + middle iters good; **tail iters (17-19) over-promised + under-delivered**. Likely caused by:
- Iter 17 constitution: ambitious cross-skill integration; only 2 of 5 affected skills patched
- Iter 18 replay+PBT: 2 features bundled; PBT integration in execute-bolts skipped
- Iter 19 convergence: depends on resolve-oq capability not added

---

## Part 6 — Proposed Iter 20 fix scope

### P0 (ship immediately; close critical bug gaps)

1. **Fix Bug 1** (execute-bolts PBT integration) — add Procedure step + halt YAML; ~30 min
2. **Fix Bug 2** (bind-codebase constitution) — add Procedure step for constitution-aware CONFLICT surfacing; ~30 min
3. **Fix Bug 5** (resolve-oq --auto-accept-from-memory) — add flag + non-interactive mode for convergence loop; ~30 min

### P1 (in same patch if possible)

4. **Fix Bug 3** (detect-drift constitution) — add constitution-drift detection step; ~20 min
5. **Fix Bug 4** (emit-agents-md constitution) — add §Constitution section to AGENTS.md schema; ~20 min

### P2 (separate doc patch)

6. **Drift D-1, D-2** (README + plugin README sync) — update to v3.12 layout + Mermaid pipeline; ~30 min
7. **Drift D-4** (handoff-contract.md) — schema extension for Iter 17-19 fields; ~15 min

### P3 (separate test patch; lower urgency)

8. **Gap C-1** (test fixtures for Iter 17-19) — ~2 hours

### P4 (Iter 21+ if needed)

9. Gap C-2 (modules.yaml JSON Schema) — needs check-jsonschema integration design
10. Drift D-3 (scenarios update) — wait for field-test to inform real scenarios

**Total Iter 20 P0+P1**: ~2 hours dev work. Plugin 3.12.0 → 3.13.0 (minor — closing claim-vs-implementation gaps; technically additive but fixing CHANGELOG honesty).

---

## Part 7 — Why these gaps happened (post-mortem)

Honest reflection:

1. **Iter velocity exceeded validation discipline** — 19 iters shipped in one session. Each iter wrote design doc + CHANGELOG entry; some skipped actual procedure step addition + test fixture.

2. **CHANGELOG entries written aspirationally** — described intended integration; reality only partially shipped. Iter 9 audit warned about this (Drift D-1 to D-4); Iter 13 partially addressed; Iter 17-19 re-introduced the pattern.

3. **Cross-skill integration is HARDER than single-skill changes** — Iter 17 constitution touches 5 skills; only 2 actually patched. Easy to over-claim multi-skill integration.

4. **Lack of automated test runner** — mega-sdd has markdown trigger tests (manual run); without CI, no enforcement that claimed features work.

5. **User redirects mid-iter** — Iter 19 redirected from convergence to PBT+replay back to convergence; quality dropped during context switches.

### Process improvements for future iters

- Verify procedure step ACTUALLY added (grep test) before bumping version
- CHANGELOG entries should reference specific Procedure step numbers (forces verification)
- Multi-skill integrations need explicit "skill matrix" checklist in spec
- Audit every 3 iters (not just 9, 13, 21)

---

## Recommended action

Ship **Iter 20 — Critical Bug Closure Patch** addressing P0+P1 (Bugs 1-5). ~2 hours. Plugin 3.12.0 → 3.13.0.

After that, mega-sdd v3.13 will have honest claims-vs-implementation parity. Defer P2 (doc sync) + P3 (tests) to separate patches.

OR — pause + field-test mega-sdd at tradefinance-rebuild as-is; field-test will reveal which of these gaps actually matter.

---

## Appendix — verification commands run

```bash
# Version matrix
awk '/^version:/{print $2; exit}' plugins/mega-sdd/skills/*/SKILL.md

# Constitution integration check
grep -c "constitution" plugins/mega-sdd/skills/bind-codebase/SKILL.md       # 0
grep -c "constitution" plugins/mega-sdd/skills/detect-drift/SKILL.md         # 0
grep -c "constitution" plugins/mega-sdd/skills/emit-agents-md/SKILL.md       # 0

# PBT integration check
grep -c "PBT\|property-based\|pbt_property_violated" plugins/mega-sdd/skills/execute-bolts/SKILL.md  # 0

# Resolve-oq non-interactive flag check
grep -c "non-interactive\|auto-accept\|--auto-pre-fill" plugins/mega-sdd/skills/resolve-oq/SKILL.md  # 0

# Test coverage
ls tests/skill-triggering/ tests/integration/ | grep -iE "constitution|replay|pbt|property|converge"  # NONE
```
