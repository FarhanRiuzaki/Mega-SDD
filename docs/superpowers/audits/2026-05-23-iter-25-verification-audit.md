# Verification Audit — mega-sdd v3.17.0 (Post-Iter-25)

**Date:** 2026-05-23
**Auditor:** claude (4 parallel general-purpose subagents)
**Plugin version (per `plugin.json`):** 3.17.0
**Commit under review:** `69fb3c3 fix(iter-25): audit closure — 27 findings from v3.16.0 deep audit (v3.17.0)`
**Predecessor audit:** `docs/superpowers/audits/2026-05-23-iter-24-deep-audit.md` (v3.16.0, 27 findings)

## Executive summary

Overall health: **YELLOW**.

Commit `69fb3c3` claims **27 findings closed**. Independent verification finds **~16 of 24 actionable findings fully closed**, **6 partial**, **1 not addressed (P1-9)**, with **6 new structural gaps** discovered during verification (chiefly in halt-taxonomy coherence and handoff-contract per-skill coverage).

Critical assessment: Iter 25 made meaningful progress on the Iter 21 "no-excuse `.mega-sdd/`" hotfix and the Iter 22 mutability propagation, but **the same audit pattern repeats**: producer skills are updated, consumer skills lag. Two output-template legacy paths in `emit-agents-md/SKILL.md` will pollute every emitted `AGENTS.md` artifact in v3.4+ projects — this is the highest user-visible regression of the release.

Counts by severity:

| Severity | Open (from v3.16.0 audit) | Closed in v3.17.0 | Partial | Not addressed | New from verification |
|---|---:|---:|---:|---:|---:|
| **P0** | 8 | 4 | 4 | 0 | 0 |
| **P1** | 9 | 5 | 3 | 1 | 5 |
| **P2** | 7 | 2 | 1 (regressed-style) | 4 | 1 |
| **Total actionable** | 24 | 11 | 8 | 5 | 6 |

The CHANGELOG line *"27 findings closed"* is overstated by ~10 findings.

---

## Closure verification — Iter 25 vs. v3.16.0 audit

### P0 (Critical)

| ID | Title | Status | Evidence |
|---|---|---|---|
| P0-1 | `bind-codebase` step sequence broken | **PARTIAL** | Duplicate `2.5` renumbered to `2.11` (line 278). But step `2.10` (constitution) still positioned AFTER step 6 (line 420 > line 418). Flow remains non-linear: `2.5→2.6→2.7→2.8→2.9→2.11→3→4→5→6→2.10`. |
| P0-2 | `bind-codebase` backward-compat cites wrong step | **FIXED** | Line 450-453 now correctly cites Step 2.10 = constitution. |
| P0-3 | `bind-codebase` halt-conditions incomplete | **FIXED** | All 4 halts now enumerated (lines 477-480). |
| P0-4 | `generate-units` step jumble | **PARTIAL** | 12.x range now linear (12.3→12.4→12.4.5→12.5→12.6). But step 12 "Audit log" precedes its substeps (logical inversion); separately, step 7.6 (line 235) precedes step 7.5 (line 261). |
| P0-5 | 6 commands defaulted to legacy paths | **FIXED** | All 5 command files updated to `.mega-sdd/` canonical defaults; legacy paths only as back-compat fallback. |
| P0-6 | `handoff-contract.md` examples used stale paths | **FIXED** | Lines 53, 91-92, 95, 111-112 all use canonical paths. |
| P0-7 | Memory schema documented legacy default | **FIXED** | `memory/SKILL.md:64` diagram + `memory-schema.md` lines 31, 42, 46, 68, 99, 137, 150, 153, 166, 192, 223, 251, 437, 456 all use `.mega-sdd/memory/`. |
| P0-8 | Broken cross-refs in `detect-drift` + `diff-vault` | **PARTIAL** | Both lines 571/471 fixed. But `diff-vault/SKILL.md:318` still references local `references/vault-contract.md` which does not exist in `diff-vault/references/`. One broken cross-ref remains. |

**P0 net: 4 fully fixed, 4 partial. No critical regressions.**

### P1 (Important)

| ID | Title | Status | Evidence |
|---|---|---|---|
| P1-1 | Iter 22 mutability not propagated | **PARTIAL** | 7 of 8 target files updated. `memory/references/learning-rules.md` has zero mutability-tracking rules; `bind-codebase/references/binding-contract.md` schema doesn't declare `mutability_source` field even though procedure emits it (procedure-vs-contract drift). |
| P1-2 | Iter 23 framework pack not propagated | **PARTIAL** | 4 of 6 targets updated. `emit-agents-md/SKILL.md` body still doesn't instruct the skill to emit `framework_pack_path` (schema declares it, procedure ignores it). `generate-intent/.../templates/02-architecture.md` template remains framework-pack-blind — new vaults won't carry framework metadata. |
| P1-3 | `cross_module_dep_invalid` vs `cross_squad_dep_invalid` | **FIXED** | Canonical name `cross_squad_dep_invalid` per `handoff-contract.md:180`; `orchestrate-flow/SKILL.md:177` aligned with back-compat note. |
| P1-4 | Checkpoint + symbol-graph paths still legacy | **FIXED** | All 5 file locations now use `.internal/` canonical paths. Zero legacy matches remaining. |
| P1-5 | `recommendation-context.md` stale paths | **FIXED** | Lines 25, 31, 36, 41, 60, 129, 130, 132, 217, 233 fully updated to v3.4+ canonical. |
| P1-6 | Scenarios don't reflect Iter 22-24 vocabulary | **FIXED** | `scenario-4-legacy-rebuild.md` now demos `[LOCKED]/[INTENT]/[ARTIFACT]` (line 153), tier distribution (lines 186-188), `laravel-base-26` Vuexy fingerprint (lines 177-178), and framework pack loading (line 189). Line 152 path also corrected. |
| P1-7 | `scan-codebase` example only shows plain `laravel` | **FIXED** | Lines 148-181 show BOTH plain `laravel` and `laravel-base-26` (starterkit) YAML detection blocks, with starterkit precedence rules. |
| P1-8 | `extract-intelligence` memory writes | **N/A** | Skill writes zero memory entries (verified). Audit conjecture moot; no path drift exists. |
| P1-9 | `agents-md-schema.md` missing PBT/replay/convergence | **NOT FIXED** | Grep for `properties_validated\|cycle_count\|replay_snapshot` returns zero. Only pre-existing `constitution_hash` (Iter 17) present. Audit explicitly listed this; Iter 25 commit message claims closure but evidence absent. |

**P1 net: 5 fully fixed, 3 partial, 1 not addressed.**

### P2 (Cleanup)

| ID | Title | Status |
|---|---|---|
| P2-1 | `lint-units.md` probe order — no issue | **N/A** (was already correct) |
| P2-2 | `memory.md` command path | **FIXED** (folded into P0-5) |
| P2-3 | `bind-codebase` chatty self-renumbering | **REGRESSED** — same chatty style now reads `"renumbered v1.9.1 Iter 25 — was duplicate 2.5"` |
| P2-4 | `using-mega-sdd` trigger drift | **N/A** (no drift) |
| P2-5 | `scan-codebase` memory path | **FIXED** (lines 239, 245) |
| P2-6 | `_template.md` framework pack schema | **DEFERRED** (per CHANGELOG Iter 23, knowingly) |
| P2-7 | `.DS_Store` files committed | **NOT FIXED** — `docs/.DS_Store` still present |

**P2 net: 2 fixed, 1 deferred (knowingly), 1 regressed-style, 3 unaddressed.**

---

## New findings (discovered during verification)

### NEW-P1-A — `emit-agents-md` output template emits legacy paths to every AGENTS.md

`plugins/mega-sdd/skills/emit-agents-md/SKILL.md` contains a fenced output template (the literal text emit-agents-md writes to disk) with hard-coded legacy paths:

- Line 44: `vault_source: docs/mega-sdd/vaults/<slug>/vault.json` (HTML comment in emitted AGENTS.md)
- Line 78: `Full vault at: docs/mega-sdd/vaults/<slug>/`

These are NOT compat-clause syntax — they are the actual artifact the skill emits. Every v3.4+ project that runs `emit-agents-md` will receive an AGENTS.md whose `vault_source:` annotation points to a path that does not exist in their layout.

This is the highest user-visible bug in v3.17.0 — it directly contradicts the Iter 21 "no-excuse `.mega-sdd/`" promise that was supposed to be CLOSED by Iter 25.

**Fix:** parameterize the template with `{{vault_path}}` resolved at emit-time from CWD probe (same priority order as elsewhere).

### NEW-P1-B — Stale version metadata across both READMEs

`README.md` (repo root):
- Line 9: `Version: 3.13.0` (should be 3.17.0)
- Line 90: `13-layer anti-hallucination defense (v3.13.0)` — stale annotation
- Line 334: `plugins/mega-sdd/ # the plugin itself (v3.8.0)` — stale annotation

`plugins/mega-sdd/README.md`:
- Line 6: `**Version:** 3.13.0` (should be 3.17.0)
- Line 44: `plugin manifest (v3.8.0)` — stale comment
- Line 47: `skills/ # 11 skills + _vendored/` — actual count is 13
- Lines 48-58: **all 13 per-skill version numbers in the inventory table are stale** (e.g., `using-mega-sdd v1.0` → actual 1.2.1; `bind-codebase v1.7.1` → 1.9.1; `generate-units v2.3` → 2.5.1)
- Line 97 + 99-108: claims 13 anti-hallucination layers, lists only 10

The "What's new in v3.17.0" prose IS current; only the version-number metadata is stale. This is trust-eroding for first-time readers — the version banner contradicts the release notes immediately below it.

### NEW-P1-C — `commands/orchestrate-flow.md` is stale 2 iterations behind

- Line 2: description claims "max 3 per chain" — obsolete in `--deep` mode (Iter 4, v2.3.0+)
- Line 3: argument-hint omits `--deep` and `--resume`

Users invoking via slash command cannot discover deep-chain execution from `--help`.

### NEW-P1-D — Halt taxonomy is fragmented across 3 sources of truth

Halt-type emission is distributed across `orchestrate-flow/SKILL.md §convergence`, `orchestrate-flow/references/handoff-contract.md`, and individual skill SKILL.md `Halt conditions` sections. Verification surfaced **5 halt types emitted by skills but missing from `handoff-contract.md` per-skill enumerations**:

| Halt type | Emitted by | Missing from contract |
|---|---|---|
| `pbt_citation_invalid` | `execute-bolts/SKILL.md:309` | `handoff-contract.md:201` |
| `hard_rule_mixed_grammar` | `execute-bolts/SKILL.md:75, :385` | `handoff-contract.md:201` |
| `verify_unit_writable` | `execute-bolts/SKILL.md:64, :201, :378` | `handoff-contract.md:201` |
| `bind_conflict_constitution_violation` | `bind-codebase/SKILL.md:438` | `handoff-contract.md:160-161` |
| `cross_squad_ambiguous` | `generate-units/SKILL.md:180, :514` | `handoff-contract.md:180` |
| `interface_ref_missing` | `generate-units/SKILL.md:168, :514` | `handoff-contract.md:180` |
| `constitution_drift_detected` | `detect-drift/SKILL.md:509` | No `detect-drift` section exists at all in contract |
| `quality_gate_failed` | enumerated in contract, but `extract-intelligence/SKILL.md:247` describes narratively — no `type: quality_gate_failed` YAML emission found |

Additionally, **`handoff-contract.md` lacks per-skill schemas for 4 of 10 skills** (`resolve-oq`, `detect-drift`, `diff-vault`, `memory`, `emit-agents-md`) — the orchestrator must reverse-engineer their handoff YAML from each SKILL.md.

The convergence loop (orchestrate-flow §convergence:160-178) enumerates only 4 cycle-eligible halts; the contract document never enumerates the auto-loop set. **Single-source-of-truth gap.**

### NEW-P1-E — Mode B free-text Q&A violates "single upfront confirmation" framing

`commands/auto.md:79` declares the contract: ONE upfront confirmation covers the whole pipeline. But `generate-intent/references/from-prompt-mode.md:74, :220` mandates `AskUserQuestion` per question during free-text brief intake, ALWAYS interactive — even under `--auto`.

This is an architectural exception (Mode B fundamentally cannot proceed without questions), but it is NOT called out in `auto.md`. Users invoking `/mega-sdd:auto "build me a clinic CRM"` will be surprised when the pipeline pauses 7-10 times for brief refinement.

**Fix:** add an explicit exception clause in `commands/auto.md` (and `orchestrate-flow/SKILL.md`) for Mode B inputs.

### NEW-P2-F — Command argument-hint flag drift

Verified gaps:
- `commands/execute-bolts.md:3` — missing `--auto`, `--per-squad`, `--squad=<id>`, `--module=<id>` (all accepted by skill)
- `commands/bind-codebase.md:3` — missing `--kb=<path>`, `--no-kb`, `--no-framework-pack`, `--framework-pack=<path>`, `--strict-constitution` (Iter 23 flags entirely absent)
- `commands/generate-units.md:3` — missing `--auto`

### Other notes worth flagging

- **Vendored superpowers not refreshed for release.** Last sync 2026-05-13 per `ATTRIBUTION.md`; v3.17.0 cut 2026-05-23. `CLAUDE.md:52` release process step 1 explicitly says "run `sync-superpowers.sh` and review vendored diffs". Step skipped.
- **`mutability_source` field shape inconsistency.** `unit-schema.md:29-38` uses nested block (`mutability.tier`, `mutability.source`); every other consumer uses flat `mutability_source` scalar. Consumers must accept both shapes.
- **`agents-md-schema.md` examples use legacy paths** (lines 96, 109, 125). Schema-doc-example only — not the live emitter — but AI agents may copy the example shape into output. P2.

---

## Headline failure pattern (cross-cutting)

The Iter 21 + Iter 25 hotfix campaigns share the same anti-pattern:

> **"Producer skills get updated; consumer skills and downstream artifact templates lag."**

Concretely:
- Iter 21 fixed SKILL.md procedure defaults; Iter 25 fixed COMMAND.md defaults; but `emit-agents-md/SKILL.md` output **template** (the artifact AGENTS.md inherits) was missed in both rounds.
- Iter 22 producer skills (`extract-intelligence`, `generate-intent`) classify mutability; Iter 25 propagated to 7 of 8 consumer skills but `learning-rules.md` (memory-side schema) still ignores mutability.
- Iter 23 framework pack producer (`scan-codebase`, `bind-codebase`); Iter 25 propagated to 4 of 6 consumer files but `02-architecture.md` template + `emit-agents-md/SKILL.md` body remain blind.
- Iter 17/18/19 added vault state (constitution, PBT properties, convergence cycles); only constitution propagated to `agents-md-schema.md`.

**Mechanical fix to break the pattern:** the deferred Iter 23 pack linter (`_lint.md`) referenced in CHANGELOG, generalized to **a schema-coherence linter** that walks every producer→consumer field reference and validates the schema declares it before any skill emits or consumes it. This would catch:
- `mutability_source` declared by procedure (P1-1) but absent from `binding-contract.md` schema
- `framework_pack_path` declared by schema but absent from `emit-agents-md/SKILL.md` procedure
- Halt types emitted by SKILL.md but absent from `handoff-contract.md` enumeration
- READMEs claiming versions that don't match `plugin.json`

---

## Recommendation — Iter 26 scope

**Highest leverage (close before next feature release):**

1. **Fix `emit-agents-md` output template** (NEW-P1-A) — replace hard-coded `docs/mega-sdd/vaults/` with `{{vault_path}}` template variable. Single-file, ~10-line change. Highest user-visible bug.

2. **Complete P0-1, P0-4, P0-8 partials** — move bind-codebase step 2.10 into linear sequence; resolve generate-units step 7.5/7.6 ordering + step 12 substep nesting; fix the remaining diff-vault:318 broken cross-ref.

3. **README + plugin README version metadata sweep** (NEW-P1-B) — single global bump from 3.13.0/3.8.0/v1.x stale annotations to current values. Also fix the 11→13 skill count and the truncated 10/13 anti-hallucination list. Trust-restoration.

4. **`commands/orchestrate-flow.md` refresh** (NEW-P1-C) — add `--deep` and `--resume` flags; remove obsolete "max 3 per chain" claim.

5. **Close P1-9** — add `properties_validated`, `cycle_count`, `replay_snapshot` to `agents-md-schema.md` (Iter 17/18/19 propagation, never landed).

**Architectural (worth a dedicated iter):**

6. **Halt-taxonomy consolidation** (NEW-P1-D) — make `handoff-contract.md` the single source of truth. Enumerate per-skill halt types for ALL 10 skills (currently 6 of 10). Add the 5 missing halts. Make orchestrate-flow §convergence reference the contract enumeration rather than maintaining its own.

7. **Schema-coherence linter** (mechanical fix for the headline pattern) — generalize the deferred Iter 23 pack linter into a producer↔consumer↔schema cross-validator. Catches future Iter 26+ drift mechanically.

**Cleanup:**

8. Close NEW-P1-E (Mode B exception in `auto.md`), NEW-P2-F (command argument-hint flag refresh), NEW-P1-A `binding-contract.md` mutability_source schema addition, P2-7 `.DS_Store` removal + `.gitignore`, vendored superpowers sync.

---

## Methodology

4 parallel general-purpose subagents executed read-only verification:

1. **P0 closure verification** — re-checked each of 8 P0 findings against current files. ~23 tool calls.
2. **P1+P2 closure verification** — re-checked each of 9 P1 findings + spot-checked 7 P2 findings. ~39 tool calls.
3. **Hands-off operation audit** — single-confirmation contract, halt protocol coherence, auto-trigger logic, handoff YAML completeness, resume/checkpoint, "ONE command" claim. ~35 tool calls.
4. **Consistency audit** — frontmatter shape, command-skill alignment, reference schema drift, triggers list, version sync, path canonicalization, vendored freshness. ~54 tool calls.

Total: ~151 read-only tool calls. No files edited. All findings cite `file:line`.

The 4 agents' JSON/structured outputs are preserved in conversation context and were cross-referenced for this consolidated report.
