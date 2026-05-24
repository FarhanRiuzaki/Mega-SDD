# Iter 37 Scenarios + README Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** Add 2 missing scenarios (Iter 34 + Iter 35) + audit/fix repo + plugin READMEs + scenarios chooser. PATCH bump v3.26.1 → v3.26.2 (doc-only).

**Spec:** `docs/superpowers/specs/2026-05-24-iter-37-scenarios-coverage-and-readme-audit-design.md`

---

## Tasks (3 total, ~3-4hr)

1. **T1 — Create 2 scenarios** (~2hr): scenario-10 phased-rebuild + scenario-11 model-tier-override
2. **T2 — README audit** (~1hr): chooser update + repo README "13-layer" fix + plugin README structure + stale v3.18.1
3. **T3 — Release v3.26.2** (~30min): plugin.json + CHANGELOG + READMEs version bump + push

---

## Task 1: Create 2 scenarios

**Files:**
- Create: `tests/scenarios/scenario-10-phased-rebuild-walkthrough.md`
- Create: `tests/scenarios/scenario-11-model-tier-override.md`

- [ ] **Step 1.1: Write scenario-10**

Write `tests/scenarios/scenario-10-phased-rebuild-walkthrough.md` per spec §2 verbatim (~140 LOC). Sections: What you'll learn + Story + Pipeline overview + Steps 1-5 + Pass criteria + Failure modes + Related artifacts + See also.

Spec source: `docs/superpowers/specs/2026-05-24-iter-37-scenarios-coverage-and-readme-audit-design.md` §2.

- [ ] **Step 1.2: Write scenario-11**

Write `tests/scenarios/scenario-11-model-tier-override.md` per spec §3 verbatim (~80 LOC). Sections: What you'll learn + Catalog summary + Override mechanism (4 levels) + 4 examples (cost-sensitive run / project-wide config / user-scope preference / unknown role tolerance) + When to escalate to opus + When to drop to haiku + Verify override applied + See also.

Spec source: `docs/superpowers/specs/2026-05-24-iter-37-scenarios-coverage-and-readme-audit-design.md` §3.

- [ ] **Step 1.3: Verify + commit**

```bash
test -f tests/scenarios/scenario-10-phased-rebuild-walkthrough.md && wc -l tests/scenarios/scenario-10-phased-rebuild-walkthrough.md
test -f tests/scenarios/scenario-11-model-tier-override.md && wc -l tests/scenarios/scenario-11-model-tier-override.md
grep -c "^## Step\|^## Example" tests/scenarios/scenario-10-phased-rebuild-walkthrough.md tests/scenarios/scenario-11-model-tier-override.md
```

Expected: both files exist; scenario-10 ≥120 lines; scenario-11 ≥70 lines.

Commit:
```bash
git add tests/scenarios/scenario-10-phased-rebuild-walkthrough.md tests/scenarios/scenario-11-model-tier-override.md
git commit -m "$(cat <<'EOF'
docs(iter-37): 2 new scenarios (phased rebuild + model tier override)

scenario-10 — Phased Rebuild Walkthrough (~3hr; tutorial for Iter 35):
- Full legacy → KB → Phase 1 vault → bolts → Phase 2 vault workflow
- Shows --phase=N flag usage; 00-index.md §Phase context surfacing;
  execute-bolts end-of-Phase-1 hint to next phase
- Concrete TradeFinance example with 3 phases

scenario-11 — Model Tier Override (~5min; tutorial for Iter 34):
- Curated catalog (17 roles × tier) explained
- 4 override mechanisms with concrete examples (CLI / project / user / unknown)
- Tier escalation/de-escalation rubric
- Verify override applied via chain output

Closes scenario coverage gap field-tested today. Per simplifikasi: 2 NEW
files; no behavior changes; no skill bumps.
EOF
)"
```

---

## Task 2: README audit + scenarios chooser update

**Files:**
- Modify: `tests/scenarios/README.md` (chooser table — add scenarios 10/11 + entries for 7/8/9 if missing)
- Modify: `README.md` (repo root, "13-layer" → "15-layer" header)
- Modify: `plugins/mega-sdd/README.md` (fix stale v3.18.1 reference; normalize "What's new" structure)

- [ ] **Step 2.1: Update scenarios/README.md chooser**

Read `tests/scenarios/README.md`. Locate the "Quick chooser" table. Replace/extend with the full table per spec §4.3 (11 rows: 9 scenarios + upgrade-guide pointer + ... actually 11 total scenarios so 11 rows + 1 upgrade row = 12 rows).

Match the format/style of the existing table.

- [ ] **Step 2.2: Fix repo README "13-layer" → "15-layer"**

Edit `README.md`. Locate the line:
```
**13-layer anti-hallucination defense** (v3.18.0):
```

Replace with:
```
**15-layer anti-hallucination defense** (v3.24+, includes Iter 33 F3+F4):
```

The 14 + 15 entries are already in the list — just header was stale.

- [ ] **Step 2.3: Audit plugin README**

Edit `plugins/mega-sdd/README.md`. Three fixes:

(a) **Stale v3.18.1 reference**: locate the line `├── .claude-plugin/plugin.json    # plugin manifest (v3.18.1)` and update to `(v3.26.2)`.

(b) **Normalize "What's new" structure**: currently has duplicate `## What's new in v3.26.1` + `### v3.26.1` patterns. Pick ONE pattern (use `### v3.26.X` consistently under a single `## What's new` parent section). Each iter gets `### v3.X.Y (Iter N) — <title>` heading then content.

Order: newest first. Final structure:
```
## What's new

### v3.26.2 (Iter 37) — Scenarios coverage + README audit
[content — see Task 3 Step 3.3]

### v3.26.1 (Iter 36, patch) — Upgrade-from-old-version guide
[existing content]

### v3.26.0 (Iter 35) — Reading Map + Phase Discoverability
[existing content]

### v3.25.0 (Iter 34) — Dynamic Model Selection
[existing content]

### v3.24.0 (Iter 33) — Flawless Seamless Intelligence
[existing content]

### v3.23.0 (Iter 32) — Starterkit-Aware Deep Scan
[existing content]

### v3.22.0 (Iters 17-30)
[existing content]
```

(c) Bump plugin README version in "What's in this folder" to v3.26.2.

- [ ] **Step 2.4: Verify**

```bash
echo "=== Scenarios chooser updated ==="
grep -c "scenario-1[01]" tests/scenarios/README.md

echo "=== Repo README header ==="
grep "15-layer\|13-layer" README.md | head -3

echo "=== Plugin README v3.18.1 (should be 0 matches) ==="
grep -c "v3.18.1" plugins/mega-sdd/README.md

echo "=== Plugin README What's new structure ==="
grep "^### v3\.\|^## What's new" plugins/mega-sdd/README.md | head -10
```

Expected: chooser has scenario-10/11; repo README "15-layer"; plugin README zero v3.18.1; What's new structure normalized.

- [ ] **Step 2.5: Commit**

```bash
git add tests/scenarios/README.md README.md plugins/mega-sdd/README.md
git commit -m "$(cat <<'EOF'
docs(iter-37): README audit — chooser + anti-halu header + plugin structure

3 doc fixes (no behavior change):

1. tests/scenarios/README.md chooser: added scenarios 10/11 to table; verified
   all 11 scenarios listed; pointer to upgrade-guide for old-version users
2. repo README: '13-layer anti-hallucination defense (v3.18.0)' → '15-layer
   anti-hallucination defense (v3.24+, includes Iter 33 F3+F4)' — entries
   14+15 were already in the list; just header was stale
3. plugin README: stale 'v3.18.1' reference in 'What's in this folder' table
   fixed → v3.26.2. 'What's new' section structure normalized (### per
   version under ## What's new parent; newest first)
EOF
)"
```

---

## Task 3: Release v3.26.2 + push

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json` (3.26.1 → 3.26.2)
- Modify: `CHANGELOG.md` (+ [3.26.2] entry at TOP)
- Modify: `plugins/mega-sdd/README.md` (+ v3.26.2 entry at top of What's new)
- Modify: `README.md` (repo root, 3.26.1 → 3.26.2 in 3 spots)

- [ ] **Step 3.1: Bump plugin.json**

Edit `plugins/mega-sdd/.claude-plugin/plugin.json`:
```json
"version": "3.26.2",
```

- [ ] **Step 3.2: Add CHANGELOG entry**

Edit `CHANGELOG.md`. Add at TOP (above [3.26.1]):

```markdown
## [3.26.2] - 2026-05-24

### Iter 37 — Scenarios Coverage + README Audit

**Documentation iter** (~3-4hr; PATCH bump — no behavior change). Field-test feedback closure: missing scenarios for Iters 34/35 + README staleness.

**New scenarios (2):**
- `tests/scenarios/scenario-10-phased-rebuild-walkthrough.md` — Iter 35 tutorial (legacy → KB → Phase 1 vault → bolts → Phase 2 vault workflow)
- `tests/scenarios/scenario-11-model-tier-override.md` — Iter 34 tutorial (curated catalog + 4 override mechanisms + tier escalation rubric)

**Modified docs:**
- `tests/scenarios/README.md` — chooser updated to include all 11 scenarios + upgrade-guide pointer
- `README.md` (repo root) — "13-layer anti-hallucination defense (v3.18.0)" → "15-layer anti-hallucination defense (v3.24+, includes Iter 33 F3+F4)". Entries 14+15 (schema validation + type-check) were already in the list; header was stale.
- `plugins/mega-sdd/README.md` — fixed stale v3.18.1 reference in "What's in this folder"; normalized "What's new" structure (### per version under ## What's new parent, newest first); added v3.26.2 entry

**Plugin:** v3.26.1 → v3.26.2

**No skill version bumps** — pure documentation iter.

**Standing directives applied:**
- simplifikasi: 2 new files (one per missing iter scenario); skipped separate Iter 36 scenario (upgrade-from-old-version.md IS the upgrade walkthrough)
- flawless: 3 problems (missing scenarios + repo README stale + plugin README stale) all solved in 1 iter
- reuse-first: scenarios cross-ref reading-map.md + model-tiers.md + upgrade-from-old-version.md; chooser cross-refs all existing docs

**Spec:** `docs/superpowers/specs/2026-05-24-iter-37-scenarios-coverage-and-readme-audit-design.md`
**Plan:** `docs/superpowers/plans/2026-05-24-iter-37-scenarios-coverage-and-readme-audit.md`
```

- [ ] **Step 3.3: Add v3.26.2 entry to plugin README "What's new"**

Edit `plugins/mega-sdd/README.md`. Add at top of "## What's new" section:

```markdown
### v3.26.2 (Iter 37, patch) — Scenarios Coverage + README Audit

mega-sdd now ships **scenarios for all user-facing features through Iter 35**, plus README audit for 1:1 accuracy with current state.

**What changed:**

- **NEW scenarios:** 
  - `tests/scenarios/scenario-10-phased-rebuild-walkthrough.md` — phased legacy rebuild tutorial (Iter 35 phase discoverability)
  - `tests/scenarios/scenario-11-model-tier-override.md` — model tier override tutorial (Iter 34)
- **Scenarios chooser** (`tests/scenarios/README.md`) — now lists all 11 scenarios + upgrade-guide pointer
- **README audit** — fixed stale "13-layer anti-hallucination" header (now 15-layer per Iter 33 F3+F4 additions); fixed stale v3.18.1 reference; normalized "What's new" structure

**Why this matters:** field-test feedback — users coming to mega-sdd needed walkthroughs for the Iter 34/35 features. Now every iter has either a scenario OR a reference doc serving as tutorial.

**Plugin v3.26.1 → v3.26.2** (PATCH — pure documentation; no skill behavior changes).

```

- [ ] **Step 3.4: Bump repo root README version**

Edit `README.md`. Replace `3.26.1` with `3.26.2` in 3 spots (line 9 header, folder layout tree, versioning section).

- [ ] **Step 3.5: Verify**

```bash
grep '"version"' plugins/mega-sdd/.claude-plugin/plugin.json
head -5 CHANGELOG.md
grep "v3.26.2\|v3.26.1" plugins/mega-sdd/README.md | head -5
grep "3.26.2\|3.26.1" README.md | head -5
ls tests/scenarios/scenario-1*.md
```

Expected: plugin 3.26.2; CHANGELOG [3.26.2] at top; READMEs at 3.26.2; scenarios 10/11 exist.

- [ ] **Step 3.6: Commit + push**

```bash
git add plugins/mega-sdd/.claude-plugin/plugin.json CHANGELOG.md plugins/mega-sdd/README.md README.md
git commit -m "$(cat <<'EOF'
release(iter-37): mega-sdd v3.26.2 — scenarios coverage + README audit

PATCH bump (doc-only). Field-test feedback closure for missing scenarios
+ README staleness.

2 new scenarios (Iter 34 + Iter 35 tutorials). Scenarios chooser updated.
Repo README anti-halu header fixed (13 → 15 layers). Plugin README
structure normalized + stale v3.18.1 reference fixed.

No skill bumps. Plugin v3.26.1 → v3.26.2.
EOF
)"
git push origin main
```

- [ ] **Step 3.7: Verify final state**

```bash
git log --oneline -7
```

Expected: Iter 37 commits at top.

---

## Self-review

- 2 new scenario files + 3 README fixes (simplifikasi ✓)
- All 3 doc gaps closed in 1 iter (flawless ✓)
- No skill bumps (doc-only iter; PATCH appropriate ✓)
- Cross-refs existing docs (reuse-first ✓)

**End of plan.**

Total tasks: 3
Estimated execution: ~3-4 hours
