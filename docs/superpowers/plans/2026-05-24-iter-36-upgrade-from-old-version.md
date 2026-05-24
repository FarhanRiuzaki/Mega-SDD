# Iter 36 Upgrade-from-Old-Version Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** Ship 1 consolidated upgrade guide for users coming from older mega-sdd versions.

**Architecture:** 1 new reference doc (`upgrade-from-old-version.md`) + 1 cross-ref in using-mega-sdd anchor skill. PATCH version bump 3.26.0 → 3.26.1 (doc-only; no behavior change).

**Tech Stack:** Markdown-driven. No new halts. No skill body changes beyond cross-ref.

**Spec:** `docs/superpowers/specs/2026-05-24-iter-36-upgrade-from-old-version-design.md`

---

## File Structure

**New (1):**
- `plugins/mega-sdd/references/upgrade-from-old-version.md` (~100 LOC; verbatim from spec §2)

**Modified:**
- `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md` (+ Upgrade guide cross-ref; bump 1.3.3 → 1.3.4)
- `plugins/mega-sdd/.claude-plugin/plugin.json` (3.26.0 → 3.26.1)
- `CHANGELOG.md` (+ [3.26.1] entry)
- `plugins/mega-sdd/README.md` (+ note about upgrade guide)
- `README.md` (repo root, version 3.26.0 → 3.26.1 in 3 spots)

---

## Tasks (2 total, ~2hr)

1. **Task 1 — upgrade-guide + using-mega-sdd cross-ref** (~1hr): NEW file + cross-ref + skill version bump; atomic commit
2. **Task 2 — Release v3.26.1** (~1hr): plugin.json + CHANGELOG + READMEs + push

---

## Task 1: upgrade-from-old-version.md + using-mega-sdd cross-ref

**Files:**
- Create: `plugins/mega-sdd/references/upgrade-from-old-version.md` (verbatim from spec §2)
- Modify: `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md` (+ Upgrade guide cross-ref; bump 1.3.3 → 1.3.4)

- [ ] **Step 1.1: Write upgrade-from-old-version.md**

Write `plugins/mega-sdd/references/upgrade-from-old-version.md` using spec §2 verbatim content (~100 LOC). Sections: TL;DR two paths + Compatibility matrix + Migration commands + Common halts + Decision tree + Per-iter behavior changes + Pre-flight checklist + See also.

Spec source: `docs/superpowers/specs/2026-05-24-iter-36-upgrade-from-old-version-design.md` §2.

- [ ] **Step 1.2: Add Upgrade guide cross-ref to using-mega-sdd**

Edit `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md`. Locate the Reading guide section (added Iter 35). Add a new section immediately below it:

```markdown
## Upgrade guide (v1.3.4+, Iter 36)

For users coming from older mega-sdd versions — `plugins/mega-sdd/references/upgrade-from-old-version.md` consolidates compatibility matrix + migration command order + halt-by-halt recovery + decision tree. Cross-refs `tests/scenarios/scenario-6-recovery-from-halt.md` for generic halt walkthrough.
```

Bump frontmatter `version: 1.3.3` → `version: 1.3.4`.

- [ ] **Step 1.3: Verify + commit**

```bash
test -f plugins/mega-sdd/references/upgrade-from-old-version.md && wc -l plugins/mega-sdd/references/upgrade-from-old-version.md
grep -c "^## " plugins/mega-sdd/references/upgrade-from-old-version.md
grep "Upgrade guide\|upgrade-from-old-version" plugins/mega-sdd/skills/using-mega-sdd/SKILL.md | head -2
grep "^version:" plugins/mega-sdd/skills/using-mega-sdd/SKILL.md
```

Expected: file ≥80 lines; ≥6 sections; cross-ref present; version 1.3.4.

Commit:
```bash
git add plugins/mega-sdd/references/upgrade-from-old-version.md plugins/mega-sdd/skills/using-mega-sdd/SKILL.md
git commit -m "$(cat <<'EOF'
docs(iter-36): upgrade-from-old-version guide + using-mega-sdd cross-ref

NEW: plugins/mega-sdd/references/upgrade-from-old-version.md (~100 LOC)
- TL;DR: Path A (regenerate) vs Path B (preserve)
- Compatibility matrix: 11 old-artifact types × works-as-is or migration path
- Migration commands in order: migrate-paths → memory migrate → migrate-rules
- Common halts after upgrade: invalid_handoff (Iter 33 F3), memory_schema_mismatch,
  handoff_type_mismatch (Iter 33 F4), provenance_missing (Iter 30), bind_conflict
- Decision tree: PRD/KB available → Path A; otherwise Path B with fallback to A
- Per-iter behavior changes summary (Iters 8/9/10/22/27/30/33/35)
- Pre-flight checklist (6 items)
- Cross-refs reading-map.md + paths.md + scenario-6 + CHANGELOG (no duplication)

using-mega-sdd v1.3.3 → v1.3.4: + Upgrade guide cross-ref section.

Per simplifikasi+flawless: 1 new file solves 1 UX problem (field-tested today —
user asked "akan work dengan versi skills terbaru?"). Atomic deliverables.
EOF
)"
```

---

## Task 2: Release v3.26.1 + push

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json` (3.26.0 → 3.26.1)
- Modify: `CHANGELOG.md` (+ [3.26.1] entry at TOP)
- Modify: `plugins/mega-sdd/README.md` (+ note about upgrade guide in "What's new in v3.26.0" section OR add tiny v3.26.1 patch note)
- Modify: `README.md` (repo root, 3.26.0 → 3.26.1 in 3 spots)

- [ ] **Step 2.1: Bump plugin.json**

Edit `plugins/mega-sdd/.claude-plugin/plugin.json`:
```json
"version": "3.26.1",
```

- [ ] **Step 2.2: Add CHANGELOG entry**

Edit `CHANGELOG.md`. Add at TOP (above [3.26.0]):

```markdown
## [3.26.1] - 2026-05-24

### Iter 36 — Upgrade-from-old-version guide

**Documentation iter** (~2hr; PATCH bump — no behavior change). Field-test feedback: users coming from older mega-sdd versions had no consolidated upgrade guide.

**New plugin files (1):**
- `plugins/mega-sdd/references/upgrade-from-old-version.md` — consolidates compatibility matrix + migration command order + halt-by-halt recovery + decision tree + pre-flight checklist

**Skill bumps:**
- `using-mega-sdd` 1.3.3 → 1.3.4 (Upgrade guide cross-ref)

**Coverage:**
- 11-row compatibility matrix (legacy paths, pre-v1.4 KBs, pre-v2.4 codebase-maps, vault scope/phase/binding evolution)
- 5 common halts mapped to recovery (invalid_handoff, memory_schema_mismatch, handoff_type_mismatch, provenance_missing, bind_conflict)
- 3 migration commands in canonical order (migrate-paths → memory migrate → migrate-rules)
- Decision tree: Path A (regenerate) vs Path B (preserve)

**Standing directives applied:**
- simplifikasi: 1 new file solves 1 problem
- flawless: covers all known compat halt sources from Iters 8/9/10/22/27/30/33/35
- reuse-first: cross-refs scenario-6 + CHANGELOG + paths.md + reading-map.md (no duplication)

**Plugin:** v3.26.0 → v3.26.1

**Spec:** `docs/superpowers/specs/2026-05-24-iter-36-upgrade-from-old-version-design.md`
```

- [ ] **Step 2.3: Update plugin README "What's new" with v3.26.1 note**

Edit `plugins/mega-sdd/README.md`. Add tiny patch note at TOP of "What's new" section:

```markdown
### v3.26.1 (Iter 36, patch) — Upgrade-from-old-version guide

For users coming from older mega-sdd versions: see `plugins/mega-sdd/references/upgrade-from-old-version.md`. Consolidates compat matrix + migration commands + halt recovery + decision tree (Path A regenerate vs Path B preserve). Documentation-only patch; no behavior change.

```

- [ ] **Step 2.4: Update repo root README version**

Edit `README.md` (repo root). Replace `3.26.0` with `3.26.1` in 3 spots:
- Line ~9: `**Version:** 3.26.0` → `**Version:** 3.26.1`
- Folder layout tree: `# the plugin itself (v3.26.0)` → `# the plugin itself (v3.26.1)`
- Versioning section: `Currently 3.26.0.` → `Currently 3.26.1.`

- [ ] **Step 2.5: Verify**

```bash
grep '"version"' plugins/mega-sdd/.claude-plugin/plugin.json
head -5 CHANGELOG.md
grep "3.26.1\|3.26.0" README.md | head -5
grep "v3.26.1\|v3.26.0" plugins/mega-sdd/README.md | head -3
test -f plugins/mega-sdd/references/upgrade-from-old-version.md && wc -l plugins/mega-sdd/references/upgrade-from-old-version.md
```

Expected: plugin 3.26.1; CHANGELOG [3.26.1] at top; READMEs at 3.26.1; upgrade guide ≥80 lines.

- [ ] **Step 2.6: Commit + push**

```bash
git add plugins/mega-sdd/.claude-plugin/plugin.json CHANGELOG.md plugins/mega-sdd/README.md README.md
git commit -m "$(cat <<'EOF'
release(iter-36): mega-sdd v3.26.1 — upgrade-from-old-version guide

PATCH bump (doc-only; no behavior change). Field-test feedback closure.

1 new reference doc consolidating upgrade UX:
- Compatibility matrix (11 old-artifact types)
- 5 common halts × recovery
- 3 migration commands in canonical order
- Decision tree (Path A regenerate vs Path B preserve)

using-mega-sdd v1.3.3 → v1.3.4 (cross-ref).
Plugin v3.26.0 → v3.26.1.
EOF
)"
git push origin main
```

- [ ] **Step 2.7: Verify final state**

```bash
git log --oneline -5
```

Expected: 3 Iter 36 commits visible at top (spec + plan + T1 + T2 = 4 actually, but spec+plan committed earlier so T1+T2 commits visible).

---

## Self-review

- 1 new file (upgrade-from-old-version.md) — simplifikasi ✓
- 1 problem solved (consolidated upgrade UX gap) — flawless ✓
- Cross-refs existing docs (reading-map, paths, scenario-6, CHANGELOG) — reuse-first ✓
- PATCH bump appropriate (doc-only) ✓
- 2 tasks total — minimum viable iter ✓

**End of plan.**

Total tasks: 2
Estimated execution: ~2 hours
