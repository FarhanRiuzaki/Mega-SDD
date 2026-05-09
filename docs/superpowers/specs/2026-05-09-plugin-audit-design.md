# Plugin Audit — Ship-Readiness Findings & Recommendations

**Date**: 2026-05-09
**Plugin version at audit**: `0.12.1`
**Audit scope**: `plugins/grand-design-spec/` — skills, commands, templates, manifests. **Excludes** `examples/` per user direction.
**Goal**: Identify what should be fixed before tagging the next release (working name: `v0.13`).

---

## Severity rubric

| Level | Definition |
|-------|------------|
| **HIGH** | Real behavior bug or broken claim. Ship-blocker for `v0.13`. |
| **MED** | Fragile under normal use, will misfire eventually, or misleads users. Should fix this milestone. |
| **LOW** | Cleanup, DRY, future-proofing. Non-blocking — pick what fits the milestone budget. |

---

## Findings summary

| # | Severity | Area | One-liner |
|---|----------|------|-----------|
| H-1 | HIGH | vault-diff | Doesn't update `vault.json` after applying changes — markdown ↔ JSON drift accumulates |
| H-2 | HIGH | drift-detect | No `vault.json` reconciliation when vault-side actions land |
| H-3 | HIGH | resolve-oq, vault-diff | Forward-references to `lock-vault` skill that doesn't exist |
| M-1 | MED | shared schema | `vault.json` schema defined inline in one skill; other 3 reference fields blind |
| M-2 | MED | OQ taxonomy | Category labels free-form; resolve-oq's `by-category` UX is non-deterministic |
| M-3 | MED | versioning | Skill versions desynced from plugin (`0.1`/`0.2`/`0.8` vs plugin `0.12.1`) |
| M-4 | MED | versioning | `vault-diff` stuck at `0.1.0` despite v0.11 promising vault.json parity |
| M-5 | MED | templates | All 7 templates default to full-mode prose; compact-mode (default) requires runtime transformation |
| M-6 | MED | self-check | grand-design-spec Step 4 doesn't verify `OQ_BLOCKER` halt protocol section presence |
| M-7 | MED | self-check | vault-diff Step 8 self-check has no vault.json sync item (covered by H-1) |
| M-8 | MED | self-check | resolve-oq Step 4 doesn't verify vault.json count totals match markdown roll-up |
| M-9 | MED | examples residue | `examples/timeoff/vault/` predates v0.11, has no `vault.json` — README now claims v0.11+ generation produces one |
| L-1 | LOW | templates | `03-data-model.md` has both DBML + "Entity descriptions" prose; compact mode skips prose, template doesn't flag |
| L-2 | LOW | templates | `02-architecture.md` API contracts default to JSON blocks; compact wants table |
| L-3 | LOW | templates | `04-flows.md` has Preconditions/Postconditions; compact wants them dropped |
| L-4 | LOW | templates | `05-decisions.md` uses multi-section ADR format; compact wants 1-paragraph |
| L-5 | LOW | versioning | Skill version-bump rule isn't documented; bumps are inconsistent across skills |
| L-6 | LOW | versioning | CHANGELOG v0.11 entry implies vault-diff parity that doesn't exist |
| L-7 | LOW | versioning | No git tag for v0.7+ — pin examples in README only work for v0.6.0 and earlier |
| L-8 | LOW | DRY | OQ tagging convention duplicated across 4 SKILL.md files |
| L-9 | LOW | DRY | "Skill instruction language" boilerplate copy-pasted across 4 SKILL.md files |
| L-10 | LOW | DRY | 7 templates × ~150 lines of repeated mandatory-footer (Sources / OOS / OQ) — could be a single shim |
| L-11 | LOW | discoverability | Trigger phrases listed in both frontmatter `description` and "When to use" body — drift risk |
| L-12 | LOW | maintainability | `grand-design-spec/SKILL.md` is 774 lines; progressive disclosure would help |

---

## HIGH findings

### H-1. `vault-diff` never updates `vault.json`

**Where**: `plugins/grand-design-spec/skills/vault-diff/SKILL.md` Steps 6 + 7.
**Symptom**: After a `vault-diff` round, `vault.json` reflects pre-diff state. AI consumers loading the manifest see stale entities, missing flows, wrong OQ counts.
**Why it slipped**: v0.11 added vault.json + write-back logic to `resolve-oq` but didn't extend the same to `vault-diff`. CHANGELOG entry implies parity that doesn't exist.
**Fix shape**:
- Add Step 6.5 "Refresh `vault.json`": after applying markdown changes, regenerate the manifest by re-reading the 7 markdown files. New entities → `entities[]`; new flows → `flows[]`; new ADRs → `adrs[]`; auto-resolved OQs → `status: resolved`; new OQs → `status: open`.
- Add a self-check item to Step 8: *"`vault.json` totals match the post-apply markdown roll-up; new entities/flows/ADRs from this round all appear in the manifest."*
- Bump `vault-diff` SKILL version `0.1.0 → 0.2.0`.

### H-2. `drift-detect` doesn't reconcile `vault.json` when vault-side actions are accepted

**Where**: `plugins/grand-design-spec/skills/drift-detect/SKILL.md` Step 6.
**Symptom**: Lower-acuity than H-1 because drift-detect doesn't auto-edit. But when the user accepts `Promote to ADR` in the interactive walkthrough, the vault grows new content that should also exist in `vault.json`.
**Fix shape**:
- Step 6 currently only appends a Changelog note. Add: *"If any vault-side actions were applied during the walkthrough (new ADRs, new flows, etc.), regenerate `vault.json` from the now-updated markdown."*
- Or, scope down: explicitly note that drift-detect produces *recommendations*, not edits, and any vault.json reconciliation happens through `resolve-oq` / direct edit + manual regen. (This is honest about current behavior; the trade-off is users now have to remember the extra step.)

### H-3. Forward-references to a `lock-vault` skill that doesn't exist

**Where**:
- `resolve-oq/SKILL.md` Step 0 step 3 (lock check) and Step 5 (suggested next step)
- `vault-diff/SKILL.md` Step 0 push-back rule for LOCKED vaults

Each says `(when available)` to soften the reference, but a user can still type `/grand-design-spec:lock-vault` and get nothing.

**Fix shape** (pick one):
- **(a)** Build a minimal `lock-vault` skill: prompts for sign-off names + scope, edits `00-index.md` Vault Lock Status `Status: 🔒 LOCKED for <scope>` + appends Changelog. ~80 lines of SKILL.md, no new mechanics.
- **(b)** Replace forward-references with explicit manual-edit instructions: *"Edit `00-index.md` Vault Lock Status: change `Status: ⚠️ DRAFT` to `Status: 🔒 LOCKED for <scope>`, fill `Locked at` + `Locked by`, append a Changelog entry."*

Recommendation: **(b)** for `v0.13`, **(a)** as a v0.14 candidate. (b) is honest about current state in 5 minutes; (a) is a real feature scope.

---

## MED findings

### M-1. `vault.json` schema defined inline in one skill; others reference fields blind

**Where**: `grand-design-spec/SKILL.md` Step 3 has the schema. resolve-oq Step 2c step 9 references `entities[]`, `adrs[]`, `open_questions_summary` without seeing the schema.
**Risk**: Already concrete (H-1: vault-diff drifted). Future schema changes will break sibling skills silently.
**Fix shape**: Extract to `plugins/grand-design-spec/skills/grand-design-spec/references/vault-schema.md` (or `references/vault-contract.md` covering schema + OQ tag conventions + ID rules). All 4 skills reference it.

### M-2. OQ category taxonomy is free-form

**Where**: `00-index.md` template suggests categories ("PRD inconsistencies", "Tech stack & architecture", etc.) — no enumeration enforced.
**Risk**: `resolve-oq` `by-category` scope reads whatever the generator wrote. Across multiple vaults, categories drift.
**Fix shape**: Either pin a closed set in the shared contract file, OR explicitly document categories as free-form and lower expectations for `by-category` UX.
Recommendation: closed set of ~7 categories. Cheap, makes the manifest more useful.

### M-3. Skill versions desynced from plugin version

| Skill | Version |
|-------|---------|
| `grand-design-spec` | `0.8.0` |
| `resolve-oq` | `0.2.0` |
| `vault-diff` | `0.1.0` |
| `drift-detect` | `0.2.0` |
| **plugin** | **`0.12.1`** |

**Risk**: Contributors confused. Users reading SKILL.md think they have a v0.8 skill in a v0.12 plugin.
**Fix shape**: Document the rule in `CONTRIBUTING.md` (or top of CHANGELOG):
- Option (i): lockstep — bump every SKILL.md to `0.12.1` on plugin release.
- Option (ii): semver-on-skill — keep independent, but require CHANGELOG entries to enumerate per-skill version.
Recommendation: **(ii)** with stricter CHANGELOG discipline. Independent versioning is honest about which skill changed; the discipline cost is a paragraph per release.

### M-4. `vault-diff` SKILL version stuck at `0.1.0` despite v0.11 implying parity

CHANGELOG v0.11 entry mentions vault.json write-back in resolve-oq + drift-detect mode-migration awareness, but doesn't mention vault-diff. The skill was simply not updated.
**Fix shape**: Bumping to `0.2.0` is part of the H-1 fix. Add a CHANGELOG note acknowledging the gap.

### M-5. Templates are full-mode by default; compact-mode requires runtime transformation

**Where**: 7 templates in `references/templates/`. All render full-mode prose.
**Compact-mode runtime transformations the skill must do** (live, every generation):
- Collapse 3-line TL;DR → 1 line (every doc 01–06).
- Drop "Entity descriptions" prose section in 03 (DBML + 1-line Purpose only).
- Convert API contracts in 02 from JSON blocks → table.
- Drop Preconditions/Postconditions in 04.
- Collapse multi-section ADRs in 05 → 1 paragraph.
- Trim Glossary to product-specific terms only.

**Risk**: Each transformation is a place the skill can silently fail. Step 4 self-check covers some but not all (`OUTPUT_MODE` compliance items exist but rely on the skill correctly identifying its own output).

**Fix shape** (pick one):
- **(a)** Two template directories: `templates/compact/` + `templates/full/`. Doubles maintenance but eliminates runtime transformation.
- **(b)** Annotate single templates with `<!-- compact-skip -->` / `<!-- full-only -->` markers; skill respects them mechanically.
- **(c)** Status quo + tighten Step 4 self-check to verify each transformation rule.

Recommendation: **(b)** for v0.13. Cheap, keeps single source of truth, mechanically enforceable.

### M-6. No Step-4 check for `OQ_BLOCKER` halt protocol section

**Where**: `grand-design-spec/SKILL.md` Step 4 self-check.
**Symptom**: 00-index.md template includes the section. But if the skill writes 00-index from scratch (or a future template change drops it), nothing verifies it. The README now positions this as an anti-halu invariant.
**Fix shape**: Add to Step 4 self-check: *"`00-index.md` contains 'Halt protocol for autonomous runs' sub-section under Implementation Notes for AI Consumers."*

### M-7 / M-8. `vault-diff` and `resolve-oq` self-checks miss vault.json invariants

Already covered by H-1 fix. Add equivalent items to `resolve-oq` Step 4:
- *"`vault.json.open_questions_summary.total` matches the count of OQ entries in `00-index.md` roll-up after the round."*
- *"Every OQ marked `[x]`/`[~]`/`Deferred` in markdown has matching `status` in `vault.json`."*

### M-9. `examples/timeoff/vault/` is pre-v0.11

**Where**: `examples/timeoff/vault/` was generated under v0.10. README now states v0.11+ generation produces `vault.json` alongside the 7 .md files. The committed example doesn't have one.
**Fix shape**: Regenerate the TimeOff vault under current plugin. Commit + tag the regen commit (e.g., `chore(examples): regenerate TimeOff vault under v0.13`). Update `examples/README.md` to drop the "(generated under v0.10, no vault.json)" caveat.
**Note**: Audit excluded `examples/` per user direction, but this finding is *triggered by* skill changes propagating to the user-visible reference — surfaced for completeness. Decide whether to address as part of v0.13.

---

## LOW findings (cleanup)

### L-1 to L-4. Per-template compact-mode drift points
Subsumed by M-5 fix. If we go with option (b) (annotated templates), each becomes a 1-line markup change.

### L-5. Skill version-bump rule isn't documented
**Fix shape**: 5-line section in `CONTRIBUTING.md` (file doesn't exist yet — could be added) or top of CHANGELOG.

### L-6. CHANGELOG v0.11 entry implies vault-diff parity that doesn't exist
**Fix shape**: When v0.13 lands the H-1 fix, add a CHANGELOG note: *"v0.11 partially implemented vault.json parity (resolve-oq, drift-detect mode-awareness). v0.13 completes it (vault-diff write-back)."*

### L-7. No git tag for v0.7+
**Fix shape**: After pushing v0.13, create tags for current + missing milestones if useful: `git tag v0.13.0 && git push origin v0.13.0`. Backfilling v0.7-v0.12 tags is optional — most users only care about latest + LTS.

### L-8 to L-10. DRY opportunities
- L-8: OQ tagging convention duplicated across 4 SKILL.md files. **Fix**: hoist to `references/vault-contract.md` (same file as M-1 schema fix).
- L-9: "Skill instruction language" boilerplate prose. **Fix**: extract a 3-line shim, reference from each.
- L-10: 7 templates have repeated mandatory-footer (Sources / Out of Scope / Open Questions). **Fix**: single `templates/_footer.md` partial, referenced or string-replaced at generation. Lower priority — copy-paste isn't actively breaking anything.

### L-11. Trigger phrases duplicated in frontmatter + body
**Fix shape**: Make frontmatter `description` the canonical list; body section says *"see frontmatter description for trigger examples"*. Or vice versa. Pick one source.

### L-12. `grand-design-spec/SKILL.md` is 774 lines
**Fix shape**: Apply progressive-disclosure conventions from the `skill-development` skill — hoist long policy sections (Output mode policy, File-by-file content guide, OQ tagging convention) to `references/` files. Skill instruction body shrinks; references load only when a step explicitly cites them.

---

## Recommended fix priority for v0.13

**Must-fix (HIGH):**
1. H-1 `vault-diff` writes back `vault.json` (with skill bump 0.1 → 0.2)
2. H-2 `drift-detect` reconciles `vault.json` when vault-side actions land OR docs the boundary explicitly
3. H-3 Replace `lock-vault` forward-references with manual-edit instructions (or build a 1-prompt skill)

**Should-fix (MED):**
4. M-1 + L-8 + L-9 Extract `references/vault-contract.md` (schema + OQ conventions + boilerplate). Single change addresses 3 findings.
5. M-3 Document the skill-versioning rule. Cheap, removes contributor confusion.
6. M-5 Annotate templates with compact/full markers (option b). Removes 5 fragile runtime transformations.
7. M-6 + M-8 Add the missing Step-4 self-check items.

**Nice-to-have (LOW):**
8. M-9 Regenerate TimeOff example under v0.13 (out of strict scope but cheap).
9. L-12 Hoist policy sections out of `grand-design-spec/SKILL.md`.
10. L-7 Tag v0.13.

**Defer to v0.14 or later:**
- L-10 Template footer extraction (no active harm)
- L-11 Pick a single canonical source for trigger phrases (frontmatter vs body)
- M-2 OQ category enumeration (depends on whether `by-category` UX is actually used in the wild)
- A real `lock-vault` skill (H-3 option a)

---

## Out of scope

- `examples/` content quality (per user direction).
- Cross-platform behavior (Claude.ai sandbox vs Claude Code) — assumed equivalent.
- Plugin-installation UX from the marketplace side (handled by Claude Code core).
- Skill-instruction prose style / readability beyond what's in the findings.

---

## Open Questions

- **OQ-AUDIT-1** [P2]: For H-2 (drift-detect ↔ vault.json), do we want auto-reconciliation (matches H-1 pattern) or explicit-boundary-doc (cheaper, honest)? Affects scope of v0.13.
- **OQ-AUDIT-2** [P2]: For M-3 (skill versioning rule), lockstep or independent semver? Pick one for the CONTRIBUTING note.
- **OQ-AUDIT-3** [P3]: For M-2 (OQ taxonomy), is `by-category` actually used? If usage is rare, free-form is fine; otherwise enumerate.

---

## Sources

- `plugins/grand-design-spec/skills/grand-design-spec/SKILL.md` (v0.8.0, 774 lines)
- `plugins/grand-design-spec/skills/resolve-oq/SKILL.md` (v0.2.0)
- `plugins/grand-design-spec/skills/vault-diff/SKILL.md` (v0.1.0)
- `plugins/grand-design-spec/skills/drift-detect/SKILL.md` (v0.2.0)
- `plugins/grand-design-spec/skills/grand-design-spec/references/templates/*.md` (7 files)
- `plugins/grand-design-spec/commands/*.md` (5 files)
- `plugins/grand-design-spec/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `CHANGELOG.md` (v0.11 + v0.12 + v0.12.1 entries)
- `README.md` (root + plugin)
