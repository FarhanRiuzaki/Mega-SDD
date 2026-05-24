# Iter 37 — Scenarios Coverage + README Audit

**Status:** Design approved 2026-05-24 (autonomous-execute mode)
**Plugin target:** v3.26.1 → v3.26.2 (PATCH — doc-only)
**Iter type:** Documentation iter — ~3-4hr
**User directive:** "simplifikasi + flawless"

---

## Background

User field-test feedback: "test2 scenario nya udah di buat belum? jadi semacam tutor dan panduan case2 tersebut. update dan audit juga readme agar 1:1 dengan current state".

Audit found:
- 2 new iters (34, 35) lack scenarios despite being user-facing features
- Iter 36 has documentation (upgrade-from-old-version.md) — that IS the walkthrough; no separate scenario needed
- Repo README has stale "13-layer anti-hallucination defense (v3.18.0)" — actually 15 layers since Iter 33
- Plugin README has stale `v3.18.1` reference in "What's in this folder" table
- Plugin README "What's new" section has structural inconsistency (mixed levels + ordering)
- scenarios/README.md chooser may not include all 9 existing scenarios

Per simplifikasi: bundle scenarios + README audit into one iter. Doc-only PATCH bump.

---

## §1 Architecture

**New (2):**
- `tests/scenarios/scenario-10-phased-rebuild-walkthrough.md` — Iter 35 tutorial (legacy → KB → Phase 1 vault → bolts → Phase 2 vault workflow)
- `tests/scenarios/scenario-11-model-tier-override.md` — Iter 34 tutorial (curated catalog + 3 override channels with concrete examples)

**Modified:**
- `tests/scenarios/README.md` — chooser table updated with scenarios 7-11
- `README.md` (repo root) — "13-layer" → "15-layer" + version 3.26.1 → 3.26.2 in 3 spots
- `plugins/mega-sdd/README.md` — fix stale v3.18.1 reference; restructure "What's new" section for consistency; bump v3.26.2
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.26.1 → 3.26.2
- `CHANGELOG.md` — + [3.26.2] entry

**Skill version bumps:** NONE (doc-only iter; no skill behavior changes).

**Plugin:** v3.26.1 → v3.26.2 (PATCH — pure documentation).

---

## §2 Scenario 10 — Phased Rebuild Walkthrough (Iter 35 tutorial)

`tests/scenarios/scenario-10-phased-rebuild-walkthrough.md`. ~140 LOC. Coverage:

```markdown
# Scenario 10 — Phased Rebuild Walkthrough

**Time:** ~3 hours wall-clock (mostly idle while extract-intelligence runs in waves; user-active time ~30 min spread across 3 sessions)
**When to use:** legacy codebase rebuild with multi-phase plan (Iter 35 phase discoverability)
**Prerequisites:** plugin v3.26.0+ (Iter 35); existing legacy codebase OR willingness to use sample

## What you'll learn

- How to extract a phased rebuild plan from legacy code
- How to generate Phase 1 vault (and what's IN scope vs OUT for that phase)
- Where Phase 2/3+ plans live + how to bootstrap each one
- How execute-bolts hints "Phase N+1 next" when ready

## Story

Imagine you have a legacy PHP app called "TradeFinance" (~50 controllers, 30 models). You want to rebuild on Laravel 12. Senior architect did a 30-min walkthrough; now you want mega-sdd to phase the rebuild.

## Pipeline overview

```
legacy-code/                                    
    ↓ extract-intelligence (5 waves, ~2hr)
.mega-sdd/knowledge-base/                       ← full domain extraction
    ↓ generate-intent --kb=.mega-sdd/knowledge-base/ --phase=1
.mega-sdd/vaults/phase-1/                       ← scoped to Phase 1 deliverables
    ↓ scan-codebase (target scaffold)
    ↓ bind-codebase (vault vs target)
    ↓ generate-units
    ↓ execute-bolts (atomic commits per unit)
[Phase 1 complete]
    ↓ generate-intent --kb=<KB> --phase=2
.mega-sdd/vaults/phase-2/
    ↓ ... (same pipeline for Phase 2)
```

## Step 1 — Extract intelligence from legacy

```bash
/mega-sdd:extract-intelligence ./old-tradefinance/
```

Expected: ~2hr wall-clock (waves 1-5 run in parallel where possible). Output: `.mega-sdd/knowledge-base/` with 30+ domain files + cross-domain workflows + `99-rebuild-architecture/suggested-phasing.md` (the phase plan).

Verify:
```bash
cat .mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md | head -40
```

You should see `## Phase 1` / `## Phase 2` / `## Phase 3` headers with scope + acceptance criteria per phase.

## Step 2 — Generate Phase 1 vault

```bash
/mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/ --phase=1
```

(Note: `--phase=1` is default; flag is for documentation clarity here.)

Expected: vault at `.mega-sdd/vaults/<slug>/`. Open `00-index.md`:

```markdown
## Phase context (v3.26+)

**Phase:** 1 of 3

**This vault covers:** Core auth + user management + basic transaction listing (per suggested-phasing.md §Phase 1)

**Upcoming phases:**
- Phase 2: Settlement workflow + risk approval
- Phase 3: Reporting + audit log

**To start the next phase** (after this phase's bolts complete):
```bash
/mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/ --phase=2
```

**Full phased plan:** `.mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md`
```

This block tells you exactly what you're building NOW + where Phase 2/3 plans live.

## Step 3 — Scan target scaffold + bind + units + bolts

```bash
/mega-sdd:auto
```

orchestrate-flow detects vault exists + propose chain → scan-codebase (target scaffold) → bind-codebase → generate-units → execute-bolts. Single confirmation; auto-continues.

Expected halt: maybe `bind_conflict` on some claims. Halt envelope shows `suggested_action: KEEP_VAULT | KEEP_CODE | DEFER | SPLIT`. Choose per claim; pipeline continues.

## Step 4 — Phase 1 complete; next-phase hint surfaces

When Phase 1 bolts finish, execute-bolts handoff `next_action.hint`:

```
Phase 1 complete. Next: Phase 2. Plan: .mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md §Phase 2
```

orchestrate-flow final summary repeats:

```
Phase 1 of 3 complete. To start Phase 2: see suggested-phasing.md §Phase 2 OR run /mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/ --phase=2.
```

## Step 5 — Start Phase 2

```bash
/mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/ --phase=2
```

NEW vault at `.mega-sdd/vaults/<slug-phase-2>/` scoped to Phase 2 deliverables. `00-index.md` Phase context now shows "Phase 2 of 3" + "Phase 3" upcoming.

Run pipeline again. Repeat for Phase 3.

## Pass criteria

- `suggested-phasing.md` has ≥2 `## Phase` headers
- Phase 1 vault `00-index.md` has §Phase context block with phase 1 of N + upcoming phases listed + next-phase command verbatim
- vault.json has `phase: 1`, `phase_total: N` fields
- execute-bolts end-of-Phase-1 surfaces "Phase 2 next" hint
- Phase 2 vault is distinct from Phase 1 vault (separate `.mega-sdd/vaults/` subdirectory)

## Failure modes

- `suggested-phasing.md` absent → fallback `phase: 1, phase_total: 1` (treats as single-phase); user can manually edit suggested-phasing.md to add phases
- `--phase=2` requested when phase_total=1 → invocation-time error: "Phase 2 requested but suggested-phasing.md has only 1 phase. Available: 1..1."
- Phase 2 vault references entities from Phase 1 that weren't built → manual review; expected behavior for cross-phase dependencies

## Related artifacts

- `plugins/mega-sdd/references/reading-map.md` §Stage 2 (vault) — where to read at each phase
- `plugins/mega-sdd/skills/extract-intelligence/references/knowledge-base-schema.md` §suggested-phasing.md — KB phase plan format
- `plugins/mega-sdd/skills/generate-intent/SKILL.md` Step 2.5 — --phase flag parsing

## See also

- [scenario-4 — Legacy rebuild](scenario-4-legacy-rebuild.md) — single-phase legacy rebuild (older flow)
- [scenario-6 — Recovery from halt](scenario-6-recovery-from-halt.md) — if bind_conflict fires
- `plugins/mega-sdd/references/upgrade-from-old-version.md` — if upgrading from older mega-sdd
```

---

## §3 Scenario 11 — Model Tier Override (Iter 34 tutorial)

`tests/scenarios/scenario-11-model-tier-override.md`. ~80 LOC. Coverage:

```markdown
# Scenario 11 — Model Tier Override

**Time:** ~5 minutes
**When to use:** override default model tiers per subagent role (cost control OR quality boost)
**Prerequisites:** plugin v3.25.0+ (Iter 34)

## What you'll learn

- mega-sdd uses a curated catalog (17 named roles × tier) for subagent dispatches
- 3 ways to override: CLI flag, project config, user preference
- When to escalate (opus) vs. when to drop (haiku)

## The catalog

By default mega-sdd picks tier per role per `plugins/mega-sdd/references/model-tiers.md`:

- 3 roles default **opus**: `extract-intelligence-wave-5` (synthesis), `pipeline-audit-consolidator`, `code-quality-reviewer`
- 12 roles default **sonnet**: deep-scan extractors, early waves, audit-per-skill, implementers, etc.
- 2 roles default **haiku**: `intelligence-audit-probe`, `domain-research`

Distribution is sonnet-dominant by design (rubric in catalog file).

## Override mechanism — 4 levels (highest precedence first)

1. **CLI flag** (per-run): `--model-tier=<role>:<tier>`
2. **Per-project config**: `<project>/.mega-sdd/config.yaml` `model_tiers:` section
3. **User-scope preference**: `~/.mega-sdd/memory/preferences.md` `## Model tiers` section
4. **Catalog default**: `references/model-tiers.md §Catalog`

## Example 1 — Cost-sensitive run (one-off)

You're testing a feature; don't need opus reviews. Override code-quality-reviewer to sonnet for THIS run:

```bash
/mega-sdd:auto --model-tier=code-quality-reviewer:sonnet ./prd.md
```

Multiple overrides allowed:

```bash
/mega-sdd:auto \
  --model-tier=code-quality-reviewer:sonnet \
  --model-tier=extract-intelligence-wave-5:sonnet \
  ./prd.md
```

## Example 2 — Project always wants cheaper reviews

You manage a project where team standardizes on sonnet reviews:

```yaml
# <project>/.mega-sdd/config.yaml
model_tiers:
  code-quality-reviewer: sonnet
  extract-intelligence-wave-5: sonnet
```

Applies to every mega-sdd run in this project. Doesn't affect other projects.

## Example 3 — User-scope quality boost

You always want deep audit consolidator on opus (the catalog default; you want to ensure it stays opus even if a project config tries to drop it):

```markdown
# ~/.mega-sdd/memory/preferences.md

## Model tiers

- `pipeline-audit-consolidator`: opus  # personal default — keep even if project overrides
```

Wait — but project config wins over user preference per precedence chain. So this preference only applies when project doesn't override.

The real use case: bumping intelligence-audit-probe from haiku to sonnet because you want more thorough scoring:

```markdown
# ~/.mega-sdd/memory/preferences.md

## Model tiers

- `intelligence-audit-probe`: sonnet  # default haiku is fine, but I prefer higher signal
```

## Example 4 — Unknown role tolerance

What if you reference a role not in catalog?

```yaml
# .mega-sdd/config.yaml
model_tiers:
  future-unreleased-role: opus
```

Iter 34 Step 2.8 emits SOFT halt `model_tier_unknown` + log: "Role 'future-unreleased-role' not in catalog; override ignored. Chain proceeds." 

Forward-compat: when a future iter adds `future-unreleased-role` to catalog, this override auto-applies on next run.

## When to escalate to opus

Per the catalog rubric (top of `model-tiers.md`):

- **Open-ended reasoning** (no fixed output schema)
- **Holistic synthesis** across many sources (≥10 documents or ≥5 categories)
- **Architectural decisions** (skill body design, schema design)
- **Deep code review** (cross-cutting concerns, security, performance)

If your override is for one of these → opus is correct.

## When to drop to haiku

Per the catalog rubric:

- Task is bounded scope (≤2 files read, ≤1KB output)
- Decision space is narrow (enum-like, ≤5 distinct outputs)
- No multi-document synthesis
- No architectural reasoning
- Speed/cost dominates quality

If your override is for a probe-style scoring or web fetch → haiku is correct.

## Verify override applied

After running with overrides, check chain output. orchestrate-flow logs final tier resolution:

```
Model tier overrides applied: code-quality-reviewer=sonnet (cli-flag); extract-intelligence-wave-5=sonnet (cli-flag)
```

handoff metadata.model_tiers + model_tier_sources blocks have the provenance trail (source: catalog | user | project | cli per role).

## See also

- `plugins/mega-sdd/references/model-tiers.md` — full catalog (17 roles × tier + rationale)
- `plugins/mega-sdd/references/reading-map.md` — Stage 7 cross-cutting (where overrides live)
```

---

## §4 README audits

### 4.1 Repo root README.md

Two fixes:

1. **"13-layer anti-hallucination defense (v3.18.0)" → "15-layer anti-hallucination defense (v3.24+, includes Iter 33 F3+F4)"**
   - Note: defenses 14 + 15 (schema validation + type-check) already listed in the section; just header is wrong

2. **Version 3.26.1 → 3.26.2** in 3 spots (line 9 header, folder layout tree, versioning section)

### 4.2 Plugin README.md

Multiple fixes:

1. **"What's in this folder" table** — line referencing `plugin.json    # plugin manifest (v3.18.1)` → `(v3.26.2)`
2. **"What's new" section structure** — currently has duplicate-style "## What's new in v3.26.1 (Iter 36, patch)" + "### v3.26.1 (Iter 36, patch)" patterns. Normalize to use ONE level (`##` per version, no nested `###`).
3. **Order**: newest first (v3.26.2 → 3.26.1 → 3.26.0 → 3.25.0 → 3.24.0 → 3.23.0)
4. **Add v3.26.2 "What's new" entry** for this iter (3 scenarios + README audit)

### 4.3 scenarios/README.md (chooser)

Update chooser table to include scenarios 7-11:

```markdown
| Your situation | Scenario | Time |
|---|---|---|
| First time trying mega-sdd; want minimum viable run | [Scenario 1 — Greenfield from idea](scenario-1-greenfield-from-idea.md) | 15 min |
| Have a PRD; existing project | [Scenario 2 — PRD-driven feature](scenario-2-prd-driven-feature.md) | 30 min |
| Field-level gap (PRD says X, code has Y) | [Scenario 3 — Field-level extension](scenario-3-field-extension.md) | 20 min |
| Legacy codebase → modern rebuild (single phase) | [Scenario 4 — Legacy rebuild](scenario-4-legacy-rebuild.md) | 4 hr |
| Multi-team coordination | [Scenario 5 — Multi-squad parallel](scenario-5-multi-squad-parallel.md) | 45 min |
| Something halted; need to recover | [Scenario 6 — Recovery from halt](scenario-6-recovery-from-halt.md) | 15 min |
| Multi-architect (BE/FE/MW shared PRD) | [Scenario 7 — Multi-architect](scenario-7-multi-architect.md) | 60 min |
| Starterkit-aware generation (auto-detected stack) | [Scenario 8 — Starterkit-aware generation](scenario-8-starterkit-aware-generation.md) | 30 min |
| End-to-end intelligence layer test | [Scenario 9 — Flawless seamless intelligence](scenario-9-flawless-seamless-intelligence.md) | 30-40 min |
| **Legacy rebuild with phased plan (multi-phase)** | **[Scenario 10 — Phased rebuild walkthrough](scenario-10-phased-rebuild-walkthrough.md)** | **~3 hr** |
| **Model tier override (cost/quality control)** | **[Scenario 11 — Model tier override](scenario-11-model-tier-override.md)** | **~5 min** |
| Upgrading from older mega-sdd | (not a scenario) See `plugins/mega-sdd/references/upgrade-from-old-version.md` | — |
```

---

## §5 Halt protocol + testing

No new halts. No skill behavior changes. Doc-only iter; no trigger tests required.

---

## Acceptance criteria

1. Plugin v3.26.1 → v3.26.2 (PATCH)
2. 2 new scenarios (10 + 11) — covers Iter 34 + Iter 35 user-facing features
3. scenarios/README.md chooser updated to include all 9 existing + 2 new = 11 scenarios
4. Repo README: "13-layer" → "15-layer"; version 3.26.2 in 3 spots
5. Plugin README: v3.18.1 reference fixed; "What's new" structure normalized; v3.26.2 entry added
6. CHANGELOG [3.26.2] entry
7. No skill version bumps (doc-only)

---

## Out of scope

- Updating older scenarios (1-7) to reference Iter 27 starterkit-first reorder — those scenarios still work via routing-rules.md back-compat probe order; refresh deferred to future iter if confusion surfaces
- Auto-generation of scenarios from CHANGELOG (would be a tool/automation feature; not needed for one-time backfill)

---

## Spec self-review

- 2 new scenario files + README audit (concentrated; minimal additions per simplifikasi)
- All 3 problems solved in 1 iter (no deferrals per flawless)
- Doc-only PATCH bump (appropriate semver)
- Cross-refs reading-map.md + model-tiers.md + upgrade-from-old-version.md (reuse-first)
