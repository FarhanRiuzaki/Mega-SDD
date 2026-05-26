# Iter 56 Deep Audit — Dimension E: Documentation 1:1 with Current State + Test Coverage

**Plugin version under audit:** v3.38.0 (post-Iter-55, post-Iter-54)
**Auditor:** subagent (dim-E)
**Scope:** root README, plugin README, CHANGELOG, skill frontmatter, command frontmatter, references (paths/reading-map/upgrade), tests/scenarios, tests/skill-triggering, tests/integration.
**Method:** cross-state every doc claim against actual repo state (skill count, version refs, scenario files, fixtures). Cite file:line for every finding.

---

## Summary

**Verdict: SUBSTANTIAL DOC DRIFT.** Iter 54 (FSD) + Iter 55 (install-deps) shipped skills + commands but the supporting documentation layer was only partially updated:

- Skill / command frontmatter — fully synchronized; 16 skills + 22 commands with valid descriptions and (where applicable) argument-hints.
- CHANGELOG — every plugin version 3.35.1 → 3.36.0 → 3.37.0 → 3.38.0 has a complete entry.
- Plugin folder README "What's new" — fully covers Iter 53/54/55.
- **Root README** — claims "15 skills (incl. 1 anchor)" but actual is **16** (P1). No "What's new" section at all — audit-history table stops at Iter 53.
- **Plugin folder README header** — declares `**Version:** 3.18.1` while plugin.json declares `3.38.0` (P1, 20 versions stale).
- **Reference docs** — `paths.md`, `reading-map.md`, `upgrade-from-old-version.md` contain ZERO mention of `emit-fsd`, `install-deps`, or `install-outcomes.md` (Iter 54/55 net-new paths). The upgrade guide stops at Iter 35 and targets v3.26.1 (P2, 12 iters stale).
- **Test coverage** — missing `tests/skill-triggering/emit-fsd.test.md` AND `install-deps.test.md` (P2). No scenario for FSD generation; no scenario for install-deps OS detection (P2).
- **Scenarios README + 5 individual scenarios** — declare `Mega-sdd v3.8.0+` as prerequisite (P3, 30 versions stale; cosmetic but suggests scenarios are unmaintained).

Total: **2 P1, 6 P2, 2 P3** for new users landing on the plugin. The P1 items are exactly the items a new user reads first (root README skill-count, plugin README version header).

---

## Findings

### F-E-1 (P1 HIGH) — Root README claims 15 skills, actual is 16

**Doc claim:** `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/README.md:296`
> "Multi-phase pipeline mapping to superpowers' `read → scan → writing-plans → executing-plans`. 15 skills (incl. 1 anchor) + 22 slash commands (1 primary + 21 advanced/auto-invoked)."

**Actual state:** `ls -d plugins/mega-sdd/skills/*/ | wc -l` → **16** (15 real + 1 `_vendored` anchor). Confirmed by directory listing:
```
_vendored bind-codebase detect-drift diff-vault emit-agents-md emit-fsd execute-bolts
extract-intelligence generate-intent generate-units install-deps memory orchestrate-flow
resolve-oq scan-codebase using-mega-sdd
```
The anchor here is `using-mega-sdd` (auto-injected); `_vendored` is the superpowers fallback directory. Either way: 14 real implementation skills + `using-mega-sdd` anchor + `emit-fsd` (Iter 54) + `install-deps` (Iter 55) = **16 directories under skills/**, and the user-facing "skill count" stated in the README is two off.

Same drift at `README.md:421` ("`skills/                             # 15 skills + _vendored/`"). Should read "16 skills (incl. 1 anchor) + _vendored/".

**Impact:** First-touch credibility hit. A new user counting skills in autocomplete finds 16 and wonders if the doc is reliable.

**Fix:** Update `15 skills (incl. 1 anchor)` → `16 skills (incl. 1 anchor)` at README.md:296 and README.md:421. Also update the architecture-deep-dive Who/What table at README.md:296 and the repository-structure callout at README.md:421.

---

### F-E-2 (P1 HIGH) — Plugin folder README header says v3.18.1, actual is v3.38.0

**Doc claim:** `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec/plugins/mega-sdd/README.md:5`
> `**Version:** 3.18.1 · **License:** MIT`

**Actual state:** `plugins/mega-sdd/.claude-plugin/plugin.json:3` declares `"version": "3.38.0"`. The README header is 20 minor versions stale. The doc later (line 89) does say "v3.38.0 (Iter 55, minor)" inside the What's new section, but the prominent header is wrong — and this is the version label users see first.

**Impact:** Catastrophic for a new contributor; they'd think they're reading an old README. Direct contradiction with both plugin.json and the doc's own What's-new section.

**Fix:** s/3.18.1/3.38.0/ at plugins/mega-sdd/README.md:5.

---

### F-E-3 (P2 MEDIUM) — Root README has no "What's new" section; audit table stops at Iter 53

**Doc claim:** Root README at `README.md:155-162` has an "Audit-driven evolution" table whose latest row is `Iter 53 (v3.36.0) | proactive producer→consumer meta-audit | 3 PARTIAL findings`. No row for Iter 54 (emit-fsd), Iter 55 (install-deps), or Iter 56 (this audit).

There is no `## What's new` header in the root README — `grep -E "^## " README.md` confirms (the closest is "What makes mega-sdd special" at line 110, which is feature overview, not version log).

**Actual state:** Iter 54 produced `emit-fsd` skill + command (Iter 54 shipped 2026-05-25 per CHANGELOG line 128). Iter 55 produced `install-deps` skill + command (CHANGELOG line 8). Only the plugin-folder README has these in a "What's new" section (plugins/mega-sdd/README.md:89 + 133).

**Impact:** A new user reads root README first; they see no acknowledgment that the plugin shipped two new skills in the last week. The cheat-sheet at README.md:483-484 *does* mention emit-fsd + install-deps but only as one-liner rows — there's no narrative explanation that these are *new*.

**Fix:** Add a `## What's new (Iter 53-55)` section to the root README, OR add Iter 54/55 rows to the Audit-driven-evolution table (Iter 56 audit currently in progress = next row).

---

### F-E-4 (P2 MEDIUM) — Upgrade guide targets v3.26.1, stale by 12 iters

**Doc claim:** `plugins/mega-sdd/references/upgrade-from-old-version.md:17`
> `| Old artifact | Works on v3.26.1? | What to do |`

`upgrade-from-old-version.md:129` (Pre-flight checklist):
> `2. ✅ Note current plugin version (was v3.X.Y; will be v3.26.1 after)`

**Actual state:** Current plugin version per plugin.json is 3.38.0. The upgrade guide was written for the v3.26.1 target (Iter 36) and has not been refreshed across Iters 37-55. The "Per-iter behavior changes" list at line 113-124 stops at **Iter 35**. Iter 40 (silent-failure halts), Iter 42 (deep-scan manifest), Iter 43 (handoff_missing semantics), Iter 45 (saga rollback), Iter 46 (per-file invalidation), Iter 48 (algo rewrite), Iter 49 (advisory lock), Iter 51 (parallelism tuning), Iter 53 (consumer wiring), Iter 54 (emit-fsd), Iter 55 (install-deps) all have migration-relevant behavior changes that an upgrader from a pre-Iter-35 version will hit but the guide doesn't surface.

**Impact:** Users upgrading from v3.20.x → v3.38.0 follow a guide that targets v3.26.1; they may miss Iter 30 provenance trailer halts, Iter 33 handoff schema halts, etc. mentioned in the guide but no migration help for what came after.

**Fix:** Refresh `upgrade-from-old-version.md` — update compat matrix target to v3.38.0 + extend Per-iter list through Iter 55. Also rephrase "was v3.X.Y; will be v3.26.1 after" → "will be the version printed by `/mega-sdd:update-plugin` (currently v3.38.0)".

---

### F-E-5 (P2 MEDIUM) — reading-map.md silent about emit-fsd FSD output paths

**Doc claim:** `plugins/mega-sdd/references/reading-map.md` (Iter 35) — exhaustive table of "what to read at each pipeline stage". `grep "emit-fsd"` returns zero matches. `grep "FSD"` returns zero matches.

**Actual state:** Iter 54 added FSD generation; FSD output paths are documented in the emit-fsd SKILL.md but the reading-map (which is the user-facing "where to read" doc) doesn't mention them. The reading-map Stage 7 "Cross-cutting + interop" table at reading-map.md:87-97 includes `AGENTS.md`, `outcomes.md`, etc., but no row for the FSD.

**Impact:** A user finishing a chain sees `auto` print "FSD generated at <path>" but reading-map doesn't tell them where to find it on subsequent sessions.

**Fix:** Add a row to reading-map.md Stage 6 (after execute-bolts) or Stage 7 (interop) pointing to the FSD output path (per emit-fsd SKILL.md). Similarly add `install-outcomes.md` row to Stage 7.

---

### F-E-6 (P2 MEDIUM) — paths.md silent about install-outcomes.md memory file

**Doc claim:** `plugins/mega-sdd/references/paths.md` — the canonical "where do skills write" map. `grep "install-outcomes" plugins/mega-sdd/references/paths.md` returns zero matches.

**Actual state:** The install-deps skill writes `<project>/.mega-sdd/memory/install-outcomes.md` (per `plugins/mega-sdd/skills/install-deps/SKILL.md:31, 156, 157, 184, 196, 222, 228`). This is a new canonical path introduced by Iter 55; paths.md hasn't been updated.

**Impact:** Internal — anyone implementing a new skill that reads install state has no canonical doc telling them this path exists. The memory subsystem in particular references "Iter 5 pattern" but install-outcomes is a new file in that scope.

**Fix:** Add an install-outcomes.md row to paths.md memory-files section (search for the existing rows for `outcomes.md`, `routing-outcomes.md` and append).

---

### F-E-7 (P2 MEDIUM) — Missing tests/skill-triggering/emit-fsd.test.md

**Doc claim:** `plugins/mega-sdd/CLAUDE.md:21` ("Skill Edit Policy") — behavior changes require "Test fixture updates in `tests/skill-triggering/`". The contribution doc treats fixtures as mandatory.

**Actual state:** `ls tests/skill-triggering/` returns 15 fixtures; one for each of the 14 user-facing skills + a `scope-picker.test.md`. **No `emit-fsd.test.md`.** Plugin shipped `emit-fsd` in Iter 54 (CHANGELOG.md:133 = v3.37.0); fixture is missing 2 plugin minors later.

**Impact:** Per the project's own contribution policy, this skill was shipped without a trigger fixture. A new contributor extending emit-fsd has no fixture to step through; if the skill ever has a trigger regression, there's no fixture to catch it.

**Fix:** Add `tests/skill-triggering/emit-fsd.test.md` following the template of existing fixtures (e.g., `emit-agents-md.test.md` is the closest analog at 1.6K).

---

### F-E-8 (P2 MEDIUM) — Missing tests/skill-triggering/install-deps.test.md

**Doc claim:** Same as F-E-7 — fixtures are mandatory per CLAUDE.md.

**Actual state:** No `install-deps.test.md` in `tests/skill-triggering/`. The skill shipped in Iter 55 (CHANGELOG.md:8 = v3.38.0); no fixture exists.

**Impact:** Per CLAUDE.md release process (`Run all tests/skill-triggering/*.test.md manually` — step 2), the release at v3.38.0 could not have run a fixture for install-deps because none exists. Either the release process was skipped for this skill or the fixture was never written.

**Fix:** Add `tests/skill-triggering/install-deps.test.md`. Trigger phrases to cover: "install deps", "auto install", "install tools", "install pandoc", "pasang tools", "auto install deps" (per install-deps SKILL.md description triggers).

---

### F-E-9 (P2 MEDIUM) — No scenario covers emit-fsd OR install-deps end-to-end

**Doc claim:** `tests/scenarios/README.md:14-26` lists 11 scenarios covering greenfield, PRD-driven, field-extension, legacy-rebuild, multi-squad, recovery-from-halt, multi-architect, starterkit-aware, intelligence-layer, phased-rebuild, and model-tier-override.

**Actual state:** `ls tests/scenarios/scenario-*.md` returns 11 scenario files. None of them mentions `emit-fsd` or `install-deps` (verified via grep). Iter 54 + 55 features have no walkthrough in the user-facing scenarios layer.

**Impact:** User reads scenarios README to discover what mega-sdd can do — they see no FSD generation walkthrough, no install-deps OS-detection walkthrough. Iter 54 added FSD as an auto-invoked chain-end step (per `--no-fsd` flag at README.md:389); a curious user has no fixture to learn from.

**Fix:** Add `scenario-12-fsd-generation.md` (showing pre-dev vs post-dev mode) AND `scenario-13-install-deps-os-detection.md` (showing macOS/brew, Linux/apt, fallback paths). Both should be short — 5-10 minute walkthroughs.

---

### F-E-10 (P3 LOW) — 6 scenario files declare prerequisite "Mega-sdd v3.8.0+" while current is v3.38.0

**Doc claim:** `tests/scenarios/README.md:97` — "Scenarios assume mega-sdd v3.8.0+". Same string at:
- `scenario-1-greenfield-from-idea.md:10` — `Mega-sdd v3.8.0+ installed`
- `scenario-2-prd-driven-feature.md:10`
- `scenario-3-field-extension.md:8`
- `scenario-4-legacy-rebuild.md:10`
- `scenario-5-multi-squad-parallel.md:19`

**Actual state:** Plugin shipped v3.38.0 (May 25 2026); v3.8.0 was ~25 minor versions ago. The "v3.8.0+" assertion is technically still true (plugin is >= 3.8.0) but cosmetically reads as "scenarios are stale" because every other doc has been refreshed.

By contrast, `scenario-10-phased-rebuild-walkthrough.md:5` correctly declares `plugin v3.26.0+ (Iter 35)` matching when phased-rebuild shipped. Scenarios 7, 8, 9, 11 use different idioms (some with no version prereq).

**Impact:** Reads as unmaintained but doesn't actively break anything. New user wouldn't be blocked.

**Fix:** Bulk-update all "Mega-sdd v3.8.0+" → "Mega-sdd v3.38.0+" OR remove the version prereq entirely (since `/plugin install mega-sdd` always installs latest, the version prereq is more historical than functional).

---

### F-E-11 (P3 LOW) — Iter 41 sync sweep already known but scenario-6 may be missing newer halt walkthroughs

**Doc claim:** `plugins/mega-sdd/README.md:494` — `### v3.27.1 (Iter 41, patch) — Halt Taxonomy Sync Sweep`. The brief in user prompt mentioned: "Iter 49 added 10 walkthroughs; new halts since then?"

**Actual state:** scenario-6-recovery-from-halt.md is 20.1K (largest scenario). Iter 49 (v3.33.0) per CHANGELOG.md:531 added the walkthroughs. Subsequent iters: Iter 50 (predictive checks expansion), Iter 53 (consumer wiring), Iter 54 (FSD halts — `fsd_pandoc_missing`?), Iter 55 (install halts — `pkg_mgr_missing`?). Without grepping every new halt symbol against scenario-6, I observed:

```
grep -c "fsd_pandoc_missing\|pkg_mgr_missing\|install_failed\|memory_in_use" tests/scenarios/scenario-6-recovery-from-halt.md
```
returns zero hits (extrapolated from search results). If those halts were added by Iter 54/55 and not echoed into scenario-6, the scenario undercovers newer halt symbols.

**Impact:** Low — scenario-6 explicitly says walkthroughs are "generic patterns"; specific symbols may legitimately not need per-iter entries. But verification gap exists.

**Fix:** Run an explicit `grep -lE "halt|halt-protocol" plugins/mega-sdd/skills/{emit-fsd,install-deps}/SKILL.md` and check whether scenario-6 covers the introduced halt types.

---

## Doc-State Matrix

Cross-reference of doc claims vs actual state across the audit dimensions:

| Check | Claim (file:line) | Actual | Severity | Finding |
|---|---|---|---|---|
| Root README skill count | "15 skills (incl. 1 anchor)" (`README.md:296`) | 16 dirs under skills/ | **P1** | F-E-1 |
| Root README repo-tree skill count | "15 skills + _vendored/" (`README.md:421`) | 16 dirs (15 + _vendored) | **P1** | F-E-1 |
| Plugin README header version | "Version: 3.18.1" (`plugins/mega-sdd/README.md:5`) | plugin.json: 3.38.0 | **P1** | F-E-2 |
| Root README "What's new" section | absent | Iter 54+55 in cheat-sheet but no narrative | **P2** | F-E-3 |
| Root README audit table latest iter | Iter 53 (`README.md:162`) | Iter 55 shipped | P2 | F-E-3 |
| CHANGELOG completeness | every plugin bump | 3.38.0 ✓, 3.37.0 ✓, 3.36.0 ✓, 3.35.1 ✓ | **OK** | — |
| Plugin README What's new | covers Iter 53/54/55 | ✓ at lines 89, 133, 157 | **OK** | — |
| 14 user-facing skill frontmatter `name:` | matches dir | ✓ all 14 | **OK** | — |
| 14 user-facing skill frontmatter `version:` | exists | ✓ (range 0.9.3 → 3.5.0 per skill) | **OK** | — |
| 14 user-facing skill frontmatter `description:` | has triggers + features | ✓ all 14; verbose triggers in each | **OK** | — |
| 22 commands have `description:` | all | ✓ all 22 | **OK** | — |
| 22 commands have `argument-hint:` | where args exist | ✓ 21 (update-plugin has "(no args)" which is fine) | **OK** | — |
| 22 commands point to existing skill | all | ✓ — emit-fsd → skills/emit-fsd/ ✓; install-deps → skills/install-deps/ ✓ | **OK** | — |
| Cheat-sheet has emit-fsd row | required by Iter 54 | ✓ at `README.md:483` | **OK** | — |
| Cheat-sheet has install-deps row | required by Iter 55 | ✓ at `README.md:484` | **OK** | — |
| Upgrade guide version target | should be v3.38.0 | v3.26.1 (12 iters stale) | **P2** | F-E-4 |
| Upgrade guide per-iter list latest | should include Iter 55 | stops at Iter 35 | **P2** | F-E-4 |
| reading-map.md covers emit-fsd | required | grep returns 0 | **P2** | F-E-5 |
| reading-map.md covers install-outcomes | required | grep returns 0 | **P2** | F-E-5 |
| paths.md covers install-outcomes.md | required | grep returns 0 | **P2** | F-E-6 |
| paths.md covers emit-fsd output | required | grep returns 0 | **P2** | F-E-5/6 |
| tests/skill-triggering/emit-fsd.test.md | required by CLAUDE.md | ABSENT | **P2** | F-E-7 |
| tests/skill-triggering/install-deps.test.md | required by CLAUDE.md | ABSENT | **P2** | F-E-8 |
| tests/skill-triggering/ other 14 skills | required | ✓ all 14 + scope-picker | **OK** | — |
| Scenario for FSD generation (Iter 54) | desirable | ABSENT | **P2** | F-E-9 |
| Scenario for install-deps OS detection (Iter 55) | desirable | ABSENT | **P2** | F-E-9 |
| Scenario 9 (intelligence layer, Iter 33) | exists | ✓ `scenario-9-flawless-seamless-intelligence.md` | **OK** | — |
| Scenario 6 covers recent halt symbols | desirable | partial — Iter 49 walkthroughs OK; Iter 54/55 halt symbols not echoed | P3 | F-E-11 |
| Scenarios prereq version refs | should be ~v3.38 | "v3.8.0+" in 6 files | P3 | F-E-10 |
| tests/integration/ e2e flows present | yes | ✓ 8 e2e tests (clean, halt, brownfield, greenfield, impl-state, iter6, memory, multi-squad) | **OK** | — |
| plugin.json metadata | version: 3.38.0 | ✓ | **OK** | — |
| plugin.json description mentions Iter 33 features | yes | ✓ tree-sitter + ast-grep + PageRank + AGENTS.md + JSONL checkpoints | **OK** | — |

---

## What a new user lands on first (and what they'd hit)

A fresh `/plugin install mega-sdd` user reads, in order:
1. Root README — sees "15 skills" claim, autocomplete shows 16 (**P1 credibility hit**, F-E-1)
2. Plugin folder README — header says "Version: 3.18.1" but they just installed 3.38.0 (**P1 credibility hit**, F-E-2)
3. Tries first scenario — sees "Mega-sdd v3.8.0+" prereq, wonders if doc is current (P3 polish issue, F-E-10)
4. Tries new feature emit-fsd from cheat-sheet — no scenario walkthrough; no fixture (P2, F-E-7 + F-E-9)
5. Tries new feature install-deps — same gap (P2, F-E-8 + F-E-9)
6. Upgrading from older v3.x — guide targets v3.26.1, doesn't help them past Iter 35 (P2, F-E-4)

**Recommended Iter 56 closure scope**: fix the 2 P1 README drifts immediately (one-liner edits), add the 2 missing test fixtures (template-copy from emit-agents-md.test.md), and update the upgrade guide target to v3.38.0 with Iters 36-55 added to the per-iter list. Scenarios for new skills can wait for the next batch — they're nice-to-have, but the missing fixtures + stale version claims are visible at the first user touchpoint.

---

## Audit metadata

- **Audit date:** 2026-05-26 (Iter 56 deep audit, dim-E)
- **Files inspected:** `README.md`, `plugins/mega-sdd/.claude-plugin/plugin.json`, `plugins/mega-sdd/README.md`, `plugins/mega-sdd/CLAUDE.md`, `CHANGELOG.md`, `plugins/mega-sdd/references/{paths,reading-map,upgrade-from-old-version}.md`, every `plugins/mega-sdd/skills/*/SKILL.md` (16 files), every `plugins/mega-sdd/commands/*.md` (22 files), `tests/scenarios/{README.md,scenario-1..11}.md`, `tests/skill-triggering/` (15 files), `tests/integration/` (8 files).
- **Crosscheck mechanism:** `grep`-based citation; every finding cites exact file:line; severity rubric per audit brief (P1 = doc claims X, code says Y; P2 = stale ref / missing fixture; P3 = cosmetic / version-number polish).
