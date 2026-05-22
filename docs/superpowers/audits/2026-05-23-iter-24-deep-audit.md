# Deep Audit Report — mega-sdd v3.16.0 (Post-Iter-24)

Date: 2026-05-23
Auditor: claude (general-purpose agent)
Plugin version (per `plugins/mega-sdd/.claude-plugin/plugin.json`): **3.16.0**

## Summary

Overall health: **YELLOW**. Skill versions are internally consistent with CHANGELOG (no claim-vs-implementation drift in `version:` frontmatter). However, Iter 21 ("path-default hotfix — no excuse") did NOT propagate to four downstream skills, six command files, and the canonical handoff-contract examples — the same class of bug that hotfix was intended to close is still present. Iter 22 (mutability tiers) and Iter 23 (framework packs) are correctly implemented in the producer skills but have not propagated to the consumer skills (`generate-units`, `execute-bolts`, `emit-agents-md`, `detect-drift`, `memory`, `resolve-oq`). Two sequence bugs found in `bind-codebase` (duplicate step `2.5`, step `2.10` declared but inline text still cites it as `2.9`). Two broken cross-references found in `detect-drift` + `diff-vault`. Halt taxonomy is inconsistent between handoff-contract and orchestrate-flow (one halt renamed across files).

Findings count: **8 P0**, **9 P1**, **7 P2**, **3 Advisory** = 27 total.

---

## File Inventory

| Category | Count | Notes |
|---|---:|---|
| Skills (`skills/<name>/SKILL.md`) | 13 | bind-codebase, detect-drift, diff-vault, emit-agents-md, execute-bolts, extract-intelligence, generate-intent, generate-units, memory, orchestrate-flow, resolve-oq, scan-codebase, using-mega-sdd |
| Skill references (`skills/*/references/*.md`) | 33 | binding-contract, conflict-resolution, agents-md-schema, bolt-contract, hard-rule-grammar-v2, squad-subagent, superpowers-bridge, knowledge-base-schema, wave-dispatch-templates, from-prompt-mode, squad-partition, 9 vault templates, vault-contract, defensive-generation, modules-schema, pagerank-targeting, pbt-integration, unit-schema + unit.md template, learning-rules, memory-schema, checkpoint-protocol, handoff-contract, routing-rules, recommendation-context, codebase-map-schema, tree-sitter-integration |
| Plugin-level references (`references/*.md`) | 2 + folder | `paths.md`, `tooling-install.md`, plus `framework-conventions/` (5 files: README, _template, _universal, laravel, laravel-base-26) |
| Commands (`commands/*.md`) | 20 | analyze-parallelism, auto, bind-codebase, detect-drift, diff-vault, emit-agents-md, execute-bolts, extract-intelligence, generate-intent, generate-units, lint-units, list-modules, memory, migrate-paths, migrate-rules, orchestrate-flow, replay, resolve-oq, scan-codebase, update-plugin |
| Hooks (`hooks/`) | 3 | `hooks.json`, `run-hook.cmd`, `session-start` |
| Scripts (`scripts/`) | 2 + folder | `migrate-v1-rules.sh`, `sync-superpowers.sh`, plus `memory-migrations/` (README + template-migration.sh + architecture.md) |
| Vendored skills (`skills/_vendored/`) | 5 SKILL.md + 5 supporting | executing-plans, subagent-driven-development (+ 3 prompt files), test-driven-development (+ anti-patterns), using-git-worktrees, ATTRIBUTION |
| Tests/scenarios (`tests/`) | 23 | 6 scenario-*.md + sample-prd-clinic.md (root); 8 e2e in `integration/`; 12 trigger tests in `skill-triggering/`; 2 hook tests; 1 vendoring test |
| Docs outside plugin (`docs/`) | 23 | 1 `mega-sdd/architecture.md` + 3 audit reports + 8 plans + 11 specs (superpowers/) |
| Plugin-root docs | 3 | `README.md`, `CLAUDE.md`, `LICENSE` |
| Scan-codebase queries | 4 | `VERSIONS.md`, `tags-php.scm`, `tags-python.scm`, `tags-typescript.scm` |
| Execute-bolts scripts | 0 | empty `.gitkeep` only |

Nothing categorized as "uncategorized."

---

## Version Consistency Matrix

| Skill | SKILL.md `version:` | Latest CHANGELOG entry | Match? |
|---|---|---|---|
| `bind-codebase` | 1.9.0 | Iter 23 §Updated skills: `1.8.1 → 1.9.0` | ✓ |
| `detect-drift` | 1.2.0 | Iter 20 Bug 3: `1.1.0 → 1.2.0` | ✓ |
| `diff-vault` | 1.2.0 | Iter 20 §Implementation (line ~325): `v1.1.0 → v1.2.0` (handoff YAML) | ✓ |
| `emit-agents-md` | 1.2.1 | Iter 21: `v1.2.0 → v1.2.1` (probe order flip) | ✓ |
| `execute-bolts` | 2.4.0 | Iter 18 §PBT: `v2.3 → v2.4` | ✓ |
| `extract-intelligence` | 1.4.0 | Iter 22: `v1.3.0 → v1.4.0` (mutability tiers) | ✓ |
| `generate-intent` | 1.10.0 | Iter 22: `v1.9.1 → v1.10.0` (KB tier routing) | ✓ |
| `generate-units` | 2.5.0 | Iter 18 §PBT: `v2.4 → v2.5` | ✓ |
| `memory` | 1.2.0 | Iter 10: `1.1.0 → 1.2.0` (project-scope path moved) | ✓ |
| `orchestrate-flow` | 2.3.1 | Iter 21: `v2.3.0 → v2.3.1` (CWD probe order flip) | ✓ |
| `resolve-oq` | 0.9.0 | Iter 20 Bug 5: `v0.8.0 → v0.9.0` | ✓ |
| `scan-codebase` | 2.4.1 | Iter 24 §scan-codebase: `v2.4.0 → v2.4.1` | ✓ |
| `using-mega-sdd` | 1.2.1 | Iter 21: `v1.2.0 → v1.2.1` | ✓ |

**Result: 13/13 skill versions match their CHANGELOG-claimed version.** No version-frontmatter drift.

Plugin version 3.16.0 in plugin.json matches CHANGELOG topmost entry `## [3.16.0] — 2026-05-22` — ✓.

---

## Findings

### P0 — Critical (claim-vs-implementation bugs)

#### P0-1 — `bind-codebase` step sequence broken (duplicate step `2.5` + dangling `2.10`)
`plugins/mega-sdd/skills/bind-codebase/SKILL.md`
- Line 57: `2.5. **Implementation-state classification (v1.2+, Iter 1).**`
- Line 275: `2.5. **Deferred-OQ auto-resolution.**` ← duplicate number
- Line 417: `2.10. **Constitution-aware CONFLICT surfacing (v1.8+, Iter 20 …; renumbered v1.9 Iter 23 to accommodate framework pack step 2.8).**` ← positioned AFTER step 6 (line 415: `6. **Audit log.**`)

Effect: An agent executing the procedure linearly skips the constitution step (it sits after audit-log, the last step). Iter 23 renumbered "constitution from 2.9 to 2.10" but moved the block out of sequence in the file. The duplicate `2.5` further breaks "step 2.6 / 2.7" reference logic.

Fix: renumber `2.5 Deferred-OQ` → `2.6 Deferred-OQ`, move the `2.10 Constitution` block between current 2.9 and step 3, and re-flow the existing 2.6/2.7/2.8/2.9 chain.

#### P0-2 — `bind-codebase` backward-compat note cites WRONG step number
`plugins/mega-sdd/skills/bind-codebase/SKILL.md:449`
> `- v3.12 vaults without constitution.md → Step 2.9 SKIPPED gracefully`

But step 2.9 is "Emit Suggested Unit Hard Rules" (line 223), not constitution. Constitution is step 2.10 (post-renumber). The compat clause now reads as "skip Hard Rules emission when no constitution.md" — semantically wrong.

#### P0-3 — `bind-codebase` halt-conditions list incomplete (missing Iter 20 + Iter 23 halts)
`plugins/mega-sdd/skills/bind-codebase/SKILL.md:467-473`

The `## Halt conditions` section enumerates only `oq_recommend_underspecified` and `oq_recommend_citation_invalid` (Iter 2). It is MISSING the halts that the skill body actually declares:
- `framework_pack_missing` (line 215, Iter 23)
- `framework_pack_cycle` (line 216, Iter 23)
- `framework_pack_unparseable` (line 217, Iter 23)
- `bind_conflict_constitution_violation` (line 435, Iter 20)

Effect: agents scanning "what halts can this skill fire" via the canonical section get an incomplete answer. CHANGELOG Iter 23 line 143 claims these halts exist; the canonical halt-conditions section doesn't list them.

#### P0-4 — `generate-units` step sequence out of order (12.4.5 before 12.3)
`plugins/mega-sdd/skills/generate-units/SKILL.md`
- Line 295: `12.4.5. **Per-anchor verification (v2.1+, Iter 8).**`
- Line 309: `12.3. **Inject constitution clauses (v2.4+, Iter 17).**`
- Line 346: `12.4. **Polished-prompt render pass (v1.3+, Iter 3).**`
- Line 385: `12.5. **Deduplication check (v1.2+, Iter 1).**`

Order in file: 12 → 12.4.5 → 12.3 → 12.4 → 12.5. The `12.4.5` should come between `12.4` and `12.5`, OR be renumbered (e.g., 12.6).

#### P0-5 — Six commands still default to LEGACY paths despite Iter 21 hotfix
Iter 21 hotfix declared "by default harus ke `.mega-sdd/` — no excuse" for the SKILL.md procedures, but the corresponding `commands/*.md` slash-command wrappers were not updated. Concrete grep matches:

| File | Line | Stale default |
|---|---|---|
| `commands/extract-intelligence.md` | 2 | description says "Produces `docs/knowledge-base/`" |
| `commands/extract-intelligence.md` | 12 | `--out` default declared `docs/knowledge-base/` |
| `commands/extract-intelligence.md` | 14 | "default `docs/knowledge-base/`" |
| `commands/generate-intent.md` | 20 | "Output goes to `docs/mega-sdd/vaults/<auto-named>/`" |
| `commands/emit-agents-md.md` | 11 | "default: detect `docs/mega-sdd/vaults/*/vault.json`" |
| `commands/auto.md` | 13, 15 | CWD detection only probes `docs/mega-sdd/vaults/`, doesn't mention `.mega-sdd/vaults/` first |
| `commands/memory.md` | 28 | "PROJECT scope" path declared `<project-root>/.mega-sdd-memory/` (not `<project-root>/.mega-sdd/memory/`) |

Effect: users invoking via slash commands read stale defaults; SKILL.md procedure says one thing, slash command wrapper says another. Iter 21's "no excuse" rule was applied to SKILLS but not COMMANDS.

#### P0-6 — `orchestrate-flow` handoff-contract examples use legacy paths
`plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`
- Line 87-88: `extract-intelligence` artifacts example shows `/path/to/docs/knowledge-base/`
- Line 91: `suggested_args: ["--kb=docs/knowledge-base/", "--auto"]`
- Line 107-108: `generate-intent` artifacts example shows `/path/to/docs/mega-sdd/vaults/<slug>/`
- Line 49: `project_decisions_relevant: []  # rows from <project>/.mega-sdd-memory/decisions.md`

This is the canonical handoff contract — every skill emits handoff YAML based on these examples. Stale paths here propagate to every chain run.

#### P0-7 — Memory schema documents wrong default for PROJECT scope
`plugins/mega-sdd/skills/memory/SKILL.md:64`
```
<project-root>/.mega-sdd-memory/           # PROJECT scope (per-repo)
```
The architecture diagram shows the LEGACY path as the primary label, despite line 48 above it correctly declaring v3.4+ default is `<project-root>/.mega-sdd/memory/`. The diagram contradicts the spec immediately above it.

Also `plugins/mega-sdd/skills/memory/references/memory-schema.md:42, 54, 148, 190, 221, 249, 454` — entire schema spec uses `.mega-sdd-memory/` as the canonical PROJECT-scope path. This is the source of truth other skills cite (bind-codebase, resolve-oq, scan-codebase all reference `<project>/.mega-sdd-memory/decisions.md` in their memory tables).

Effect: every skill writing project-scope memory writes to the LEGACY path, even though paths.md says v3.4+ default is `.mega-sdd/memory/`. The Iter 21 hotfix didn't migrate memory paths.

#### P0-8 — Broken cross-references in `detect-drift` + `diff-vault`
- `plugins/mega-sdd/skills/detect-drift/SKILL.md:571` — `see ../grand-design-spec/references/vault-contract.md`
- `plugins/mega-sdd/skills/diff-vault/SKILL.md:471` — `see ../grand-design-spec/references/vault-contract.md`

Path `<skill-dir>/../grand-design-spec/references/vault-contract.md` resolves to `plugins/mega-sdd/skills/grand-design-spec/references/vault-contract.md` — does not exist (verified via `test -f` → MISSING).

Actual file is at `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`. Likely stale relative path from before the repo restructure.

---

### P1 — Important (significant doc drift, integration gaps)

#### P1-1 — Iter 22 mutability tiers not propagated to consumer skills
The 3-tier `[LOCKED]/[INTENT]/[ARTIFACT]` classification is implemented in `extract-intelligence` and `generate-intent` only. Zero references in:
- `bind-codebase/SKILL.md` — consults KB as secondary ground truth but treats all entries the same; should at minimum surface tier in CONFLICT entries when KB participates
- `bind-codebase/references/binding-contract.md` — schema doesn't include mutability_source field
- `detect-drift/SKILL.md` — should treat drift on `[LOCKED]` entities as higher severity than `[INTENT]`
- `resolve-oq/SKILL.md` + `references/recommendation-context.md` — KB-derived recommendations don't surface tier; user can't see "this is a LOCKED rule, must preserve"
- `memory/references/learning-rules.md` — no learning rule tracks mutability classification accuracy over time
- `emit-agents-md/references/agents-md-schema.md` — AGENTS.md export omits mutability summary entirely
- `orchestrate-flow/references/handoff-contract.md` — no `mutability:` field in handoff YAML
- `generate-units/references/unit-schema.md` — units don't carry `mutability:` annotation; bolts treat all fields the same

Verified by: `grep -rn "LOCKED\|INTENT\|ARTIFACT\|mutability"` across `skills/{bind-codebase,detect-drift,resolve-oq,memory,emit-agents-md,orchestrate-flow,generate-units}/` returns ZERO non-coincidental matches (one match for "🔒 LOCKED" vault status is unrelated).

#### P1-2 — Iter 23 framework pack not propagated to downstream consumers
Framework pack is loaded by `bind-codebase` (Step 2.8) and feeds into "Suggested Unit Hard Rules" → flows to `generate-units` transitively. But these skills don't acknowledge it directly:
- `generate-units/SKILL.md` — has zero `grep` matches for "framework_pack", "framework-conventions", "laravel-base-26"; units don't cite which framework pack rules were injected
- `execute-bolts/SKILL.md` — same; "framework detected" only refers to test framework, not convention pack
- `emit-agents-md/{SKILL.md, agents-md-schema.md}` — AGENTS.md doesn't include `Framework: laravel-base-26` declaration; tools consuming AGENTS.md don't know which conventions apply
- `extract-intelligence` `99-rebuild-architecture/suggested-erd.md` — Iter 22 added Universal ERD Quality Rails; CHANGELOG Iter 23 §"How this composes" claims framework pack ERD additions overlay, but `references/knowledge-base-schema.md` §ERD Quality Rails (line 209) only references `framework-conventions/` as a generic pointer, no concrete overlay logic
- `generate-intent` vault output `02-architecture.md` — should reflect framework conventions; template `references/templates/02-architecture.md` has zero framework-aware fields

#### P1-3 — Halt-type name inconsistency: `cross_module_dep_invalid` vs `cross_squad_dep_invalid`
- `orchestrate-flow/SKILL.md:177` lists halt `cross_module_dep_invalid` as always-stop
- `orchestrate-flow/references/handoff-contract.md:176` declares generate-units emits `cross_squad_dep_invalid`

Either Iter 11 (module layer, v3.4.0) renamed "squad" to "module" inconsistently across these two files, or one is a typo. CHANGELOG mentions both terms.

#### P1-4 — Checkpoint + symbol-graph paths still use LEGACY layout per Iter 10 spec
`plugins/mega-sdd/references/paths.md:80-81` declares v3.4+ defaults:
- `execute-bolts | checkpoints | <vault>/.internal/checkpoints/` (legacy `<vault>/.mega-sdd/checkpoints/`)
- `execute-bolts | symbol-graph | <vault>/.internal/symbol-graph.json` (legacy `<vault>/.mega-sdd/symbol-graph.json`)

But every consumer uses the LEGACY path as the default:
- `generate-units/SKILL.md:272` — `<vault>/.mega-sdd/symbol-graph.json`
- `generate-units/references/pagerank-targeting.md:82` — same
- `orchestrate-flow/SKILL.md:152, 277, 287` — `<vault>/.mega-sdd/checkpoints/`
- `orchestrate-flow/references/checkpoint-protocol.md:16, 68, 69, 82` — same
- `orchestrate-flow/references/handoff-contract.md:32` — same

Iter 21 hotfix missed this category entirely.

#### P1-5 — `resolve-oq/references/recommendation-context.md` examples use 3 different stale paths
Lines 25, 31, 36, 41, 60, 129, 130, 132, 217, 233 — repeatedly cites `docs/knowledge-base/`, `.mega-sdd-memory/`, `docs/mega-sdd/vaults/`. The whole reference doc is in pre-v3.4 idiom.

#### P1-6 — Scenarios don't reflect Iter 22-24 vocabulary
6 scenarios at `tests/scenarios/` — zero mention of `[LOCKED]/[INTENT]/[ARTIFACT]`, framework convention packs, or `laravel-base-26`. Iter 22-24 added behaviors that aren't covered by any walkthrough. `scenario-4-legacy-rebuild.md` is the obvious candidate (KB-driven legacy rebuild) — it should demonstrate tier classification but doesn't.

Additionally `scenario-4-legacy-rebuild.md:152` still cites `docs/knowledge-base/10-domains/...` (should be `.mega-sdd/knowledge-base/...` per Iter 21).

#### P1-7 — `scan-codebase` framework section emits example with `pack_path` for plain `laravel`, not `laravel-base-26`
`plugins/mega-sdd/skills/scan-codebase/SKILL.md:148-153` — YAML example shows `name: laravel` / `pack_path: …/laravel.md`, but the immediately-preceding detection table (line 123) added Vuexy fingerprint that should emit `name: laravel-base-26`. No example shows the starterkit case. Could mislead implementers about output shape.

#### P1-8 — `extract-intelligence` `## Memory layer` writes to legacy path
`plugins/mega-sdd/skills/extract-intelligence/SKILL.md` — KB extraction is "FIRST skill" in legacy-rebuild scenarios (per Iter 21 fix rationale). Memory writes should default to `.mega-sdd/memory/`. Need to verify; the Iter 21 fix focused on `--out=` of KB, not memory writes from this skill.

#### P1-9 — `emit-agents-md/agents-md-schema.md` missing convergence/replay/PBT data
Iters 17, 18, 19 added significant state (constitution_hash, replay snapshots, PBT properties_validated, cycle_count). The AGENTS.md schema includes constitution flattening (Iter 17 — good) but has zero references to PBT or convergence data. Tools consuming AGENTS.md don't see this state.

---

### P2 — Cleanup (minor inconsistencies)

#### P2-1 — `lint-units.md` command probes legacy vault location first
`commands/lint-units.md:14` — "Probe both v3.4+ (`.mega-sdd/vaults/*/`) and legacy (`docs/mega-sdd/vaults/*/`) locations" — order is correct, just worth noting it's NOT an issue. (Excluded from P0-5.)

#### P2-2 — `memory.md` command description still references `.mega-sdd-memory/`
`commands/memory.md:28` — Same as P0-5; counted there.

#### P2-3 — `bind-codebase/SKILL.md` step `2.10` description self-references its own renumbering
Line 417: `Constitution-aware CONFLICT surfacing (v1.8+, Iter 20 — closes Iter 17 Bug 2; renumbered v1.9 Iter 23 to accommodate framework pack step 2.8).` — overly chatty; better as standalone procedural text.

#### P2-4 — `using-mega-sdd` triggers list very long; no Indonesian phrase drift detected
Indonesian phrases (`pecah PRD`, `siapkan context`, `jalankan otomatis`, etc.) are consistent across skills. No drift found.

#### P2-5 — `scan-codebase/SKILL.md:222, 228` still references `.mega-sdd-memory/conventions.md` as default
Memory layer tables still cite old path; consistent with P0-7.

#### P2-6 — `_template.md` framework convention pack — unverified
Did not deeply check `references/framework-conventions/_template.md` schema completeness vs `laravel.md`/`laravel-base-26.md`/`_universal.md`. Pack linter is listed as "deferred" in CHANGELOG Iter 23, so this is known.

#### P2-7 — Two `.DS_Store` files committed (`docs/.DS_Store`, plugin root `.DS_Store`)
macOS metadata; should be `.gitignore`d. Not behavioral but pollutes repo.

---

### Advisory (worth noting, not necessarily fixing now)

#### ADV-1 — Constitution lacks a vault template file
`generate-intent/references/templates/` contains `00-index.md` through `06-constraints.md` + interface templates + Obsidian/squads templates, but NO `constitution.md` template. Iter 17 added it as the 8th vault file; `generate-intent/SKILL.md:550-580` describes how to write it freeform from PRD/KB extraction. Could benefit from a template scaffold to enforce §A-F section structure.

#### ADV-2 — `data-mutation-policy.md` (Iter 22) has no schema validator
The contract between extract-intelligence (writer) and generate-intent (reader) is markdown-table-based and parsed by description, not by a schema doc. If the table format drifts, downstream KB→vault routing silently degrades.

#### ADV-3 — Vendored superpowers skills predate `superpowers:` plugin migrations
`skills/_vendored/{executing-plans,subagent-driven-development,test-driven-development,using-git-worktrees}/SKILL.md` — not part of this audit's primary scope; verify periodically against upstream changes via `scripts/sync-superpowers.sh`.

---

## Recommendation — Iter 25 Top 5 Scope

Based on findings, the biggest leverage fixes (highest ratio of correctness gain to surface area changed):

1. **Fix bind-codebase step sequence (P0-1, P0-2, P0-3)** — restore linear procedure flow, complete halt-conditions section. ~30 min of careful renumbering + re-reading.

2. **Complete the Iter 21 hotfix to commands/* and references/* (P0-5, P0-6, P0-7, P1-4, P1-5)** — propagate the "no-excuse `.mega-sdd/`" rule into:
   - 6 command files
   - `orchestrate-flow/references/handoff-contract.md` examples
   - `memory/SKILL.md` diagram + `memory/references/memory-schema.md` whole schema
   - `recommendation-context.md` examples
   - All `<vault>/.mega-sdd/{checkpoints,symbol-graph}.json` → `<vault>/.internal/...` migrations
   This is the single biggest doc-vs-spec drift remaining post-Iter-21.

3. **Iter 22 propagation patch (P1-1)** — add mutability awareness to (at minimum) `bind-codebase` (CONFLICT severity), `detect-drift` (LOCKED-entity escalation), `resolve-oq` (KB tier in recommendations), `unit-schema.md` (per-claim mutability field), `agents-md-schema.md` (summary table). Without this, Iter 22 is a producer-only feature.

4. **Iter 23 framework pack propagation patch (P1-2)** — explicitly cite framework pack source in generate-units output (currently transitive only via binding.md), include framework declaration in AGENTS.md schema, demonstrate the laravel-base-26 detection path in scan-codebase example YAML (P1-7).

5. **Fix broken cross-references + add scenarios coverage (P0-8, P1-6)** — repoint `../grand-design-spec/references/vault-contract.md` → `../generate-intent/references/vault-contract.md` in `detect-drift` + `diff-vault`; update scenario-4 (legacy rebuild) to demonstrate Iter 22 tier flow + Iter 24 starterkit detection.

Optional bonus: deferred Iter 23 pack linter (`_lint.md`) would catch many of these doc drifts mechanically going forward.

---

## Methodology notes

Read-only audit performed via `Read`, `Bash` (grep/find/ls/test), `Glob`. No files edited. Total tool calls: ~30. Key grep patterns:
- Path defaults: `grep -rn "docs/knowledge-base\|docs/mega-sdd/vaults\|\.mega-sdd-memory"` filtered for non-legacy context
- Mutability propagation: `grep -rn "LOCKED\|INTENT\|ARTIFACT\|mutability"` excluding `🔒 LOCKED` vault-status semantics
- Framework pack propagation: `grep -rn "framework-conventions\|framework_pack\|laravel-base-26"`
- Cross-reference integrity: `grep -rn "references/[a-z_-]\+\.md"` + `test -f` on resolved relative paths
- Step numbering: `grep -nE "^[0-9]+\.[0-9]*\.?\s*\*\*"` per SKILL.md

The audit took ~25 minutes of investigation against the v3.16.0 plugin state.
