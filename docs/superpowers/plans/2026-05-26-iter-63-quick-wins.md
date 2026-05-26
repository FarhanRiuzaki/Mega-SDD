# Iter 63 Quick Wins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship SP1 (Quick Wins) — FSD auto-invoke opt-out + ~1,500 line hot-tier relocation + deterministic classifier rules in CLAUDE.md + CHANGELOG archive rotation. Plugin v3.41.0 → v3.42.0 MINOR. Zero new skills/halts/schemas. Backward-compatible behavior change (FSD `--no-fsd` flag still works as no-op).

**Architecture:** All deliverables are markdown-driven edits to existing skills + references + commands + CLAUDE.md. No runtime code. Skill body trim is pure cut-paste relocation (HOT tier → SPECIALIST/COLD tier refs) — no rewrite, preserves correctness. CHANGELOG rotation is file split with cross-link. Classifier rules in Iter 63 are RULE DOC ONLY; runtime enforcement is Iter 65 (SP2).

**Tech Stack:** Markdown (skill bodies + references + CLAUDE.md), JSON (plugin.json version bump), Bash (verification commands).

**Spec source:** `docs/superpowers/specs/2026-05-26-iter-63-performance-sharpness-design.md` §3.1-3.6
**Audit source:** `docs/superpowers/audits/2026-05-26-iter-63-performance-audit.md`

**Versions:** Plugin `3.41.0 → 3.42.0` (MINOR); `orchestrate-flow 3.7.0 → 3.8.0` (MINOR); heavy-trim skills PATCH bumps per spec §3.6.

---

## File Structure (responsibility map)

**Create (5 files):**

| File | Responsibility |
|---|---|
| `CHANGELOG-ARCHIVE.md` at repo root | Holds v3.0.0–v3.26.x entries rotated from main CHANGELOG |
| `plugins/mega-sdd/skills/execute-bolts/references/t2-budget-tracker.md` | Iter 44 T2 running budget tracker procedural detail (moved from SKILL.md body) |
| `plugins/mega-sdd/skills/execute-bolts/references/saga-rollback.md` | Iter 45 saga compensating actions detail (moved from SKILL.md body) |
| `plugins/mega-sdd/skills/orchestrate-flow/references/validation-gate.md` | Iter 33 F3+F4 schema validation gate detail (moved from SKILL.md body) |
| `plugins/mega-sdd/skills/generate-intent/references/phase-context.md` | Iter 35 phase context detail (moved from SKILL.md body) |

**Modify (~20 files):**

| File | Change |
|---|---|
| `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` | Step 6 FSD default `on → off`; body trim 764 → ~500 lines; version 3.7.0 → 3.8.0 |
| `plugins/mega-sdd/commands/auto.md` | Add `--with-fsd` flag doc + cross-ref to orchestrate-flow command |
| `plugins/mega-sdd/commands/orchestrate-flow.md` | Add `--with-fsd` flag doc + cross-ref to auto command + scope clarification |
| `plugins/mega-sdd/skills/generate-intent/SKILL.md` | Body trim 1,267 → ~700; PATCH version bump |
| `plugins/mega-sdd/skills/execute-bolts/SKILL.md` | Body trim 1,012 → ~600; PATCH version bump |
| `plugins/mega-sdd/skills/generate-units/SKILL.md` | Body trim 826 → ~500; PATCH version bump |
| `plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md` | Consolidate adversarial review wiring detail (relocated from generate-units body) |
| `plugins/mega-sdd/CLAUDE.md` | + Classifier criteria (Section 4) + precedence rule + anti-recursive guard PREVIEW (rule doc only; Iter 65 ships runtime) |
| `CHANGELOG.md` | Trim to v3.27.0+ entries; add archive cross-ref header |
| `plugins/mega-sdd/.claude-plugin/plugin.json` | version 3.41.0 → 3.42.0 |
| `plugins/mega-sdd/README.md` | version refs + What's new + Iter 63 audit row |
| `README.md` (root) | version refs + audit-history table Iter 63 row |
| 5 medium-trim skills (extract-intelligence, scan-codebase, bind-codebase, emit-fsd, diff-vault) | Strip version-stamp prose 20-30% per audit; PATCH version bumps |

---

## Task 1: Section 1 — FSD auto-invoke opt-out

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` Step 6 diagnostics table
- Modify: `plugins/mega-sdd/commands/auto.md`
- Modify: `plugins/mega-sdd/commands/orchestrate-flow.md`

- [ ] **Step 1.1: Find Step 6 diagnostics table in orchestrate-flow**

Run: `grep -n "After all phases complete | \`emit-fsd\`" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`
Expected: 1 match (the Step 6 row for emit-fsd)

- [ ] **Step 1.2: Flip emit-fsd default in Step 6 table**

In `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`, find:
```markdown
   | After all phases complete | `emit-fsd` (per `commands/emit-fsd.md`, respecting `--no-fsd` flag on `auto`/`orchestrate-flow`) | `<vault>/fsd/FSD.pdf` (+ FSD.md, .citation-map.json) written; chain summary: "FSD emitted: N sections, M citations, mode: <pre-dev\|post-dev>" |
```

Replace with:
```markdown
   | After all phases complete | `emit-fsd` (per `commands/emit-fsd.md`, **OPT-IN since Iter 63 v3.42.0+** — requires `--with-fsd` flag on `auto`/`orchestrate-flow`. Legacy `--no-fsd` still works as no-op for back-compat. Reason: pandoc/LaTeX dependency + low user feedback signal per Iter 63 perf audit.) | `<vault>/fsd/FSD.pdf` (+ FSD.md, .citation-map.json) written ONLY when `--with-fsd` passed; chain summary: "FSD emitted: N sections, M citations, mode: <pre-dev\|post-dev>" |
```

- [ ] **Step 1.3: Update commands/auto.md flag table**

In `plugins/mega-sdd/commands/auto.md`, find the line:
```markdown
- `--no-fsd` — skip auto FSD generation at end of chain (Iter 54 — `/mega-sdd:emit-fsd` not auto-invoked)
```

Replace with:
```markdown
- `--with-fsd` — OPT-IN to auto FSD generation at end of chain (default: off since Iter 63 v3.42.0+; FSD generation is expensive — pandoc/LaTeX deps. Invoke `/mega-sdd:emit-fsd` manually for one-off generation.)
- `--no-fsd` — back-compat alias / no-op since Iter 63 v3.42.0+ (was opt-out flag pre-v3.42.0; now FSD is opt-in by default)
```

- [ ] **Step 1.4: Update commands/orchestrate-flow.md flag table**

In `plugins/mega-sdd/commands/orchestrate-flow.md`, find the `--no-fsd` description if present (audit if not):
```bash
grep -n "no-fsd" plugins/mega-sdd/commands/orchestrate-flow.md
```

If found, apply same replacement as Step 1.3. If not found, ADD the flag pair to the command's argument list section.

- [ ] **Step 1.5: Verify edits**

Run: `grep -c "with-fsd" plugins/mega-sdd/commands/auto.md plugins/mega-sdd/commands/orchestrate-flow.md plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`
Expected: ≥ 3 (at least one mention per file)

Run: `grep -c "OPT-IN since Iter 63" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`
Expected: 1

- [ ] **Step 1.6: Commit FSD opt-out**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/SKILL.md plugins/mega-sdd/commands/auto.md plugins/mega-sdd/commands/orchestrate-flow.md
git commit -m "feat(iter-63): FSD auto-invoke opt-out — flip default off (--with-fsd opt-in)

Per spec Section 3.1. FSD generation is expensive (pandoc/LaTeX deps) and
low user feedback signal per Iter 63 perf audit. Flip from default-on auto-
invoke to opt-in via --with-fsd flag.

Backward compat: --no-fsd still accepted as no-op. /mega-sdd:emit-fsd
standalone command unchanged — user invokes manually for FSD.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Section 5 — CHANGELOG archive rotation

**Files:**
- Create: `CHANGELOG-ARCHIVE.md` (repo root)
- Modify: `CHANGELOG.md` (repo root) — trim v3.0.0-v3.26.x entries; add cross-ref header

- [ ] **Step 2.1: Identify cutoff line**

Run: `grep -n "^## \[3\.27\.0\]\|^## \[3\.26\." CHANGELOG.md | head -5`
Expected: line numbers showing transition between v3.27.0 (keep) and v3.26.x (archive)

Save the line number of `## [3.27.0]` heading as `KEEP_FROM_LINE`. Everything FROM line 1 to KEEP_FROM_LINE-1 stays in main; everything FROM KEEP_FROM_LINE to end of v3.0 archive goes to archive.

Actually invert: lines 1-7 are header (Keep a Changelog preamble); FROM `## [3.27.0]` to start of FILE is recent; FROM `## [3.26.x]` to end is archive.

Run: `head -10 CHANGELOG.md`
Expected: shows the Keep-a-Changelog header (lines 1-7 typically) then the first `## [...]` entry.

- [ ] **Step 2.2: Extract archive content**

Find line range of v3.26.x and below using:
```bash
awk '/^## \[3\.27\.0\]/{found=1; print "STOP_LINE", NR; exit} END{if(!found) print "NOT_FOUND"}' CHANGELOG.md
```

Let `STOP_LINE` = line where v3.27.0 entry starts. Archive lines = `STOP_LINE` to end of file.

```bash
# Get archive content (v3.26.x and older):
awk -v stop=$STOP_LINE 'NR >= stop' CHANGELOG.md > /tmp/changelog-archive-content.md
```

- [ ] **Step 2.3: Create CHANGELOG-ARCHIVE.md**

Write `CHANGELOG-ARCHIVE.md` at repo root with structure:

```markdown
# Changelog Archive — pre-v3.27.0

> Historical entries for mega-sdd plugin v3.0.0 through v3.26.x, rotated from main `CHANGELOG.md` on 2026-05-26 (Iter 63 SP1).
>
> **For recent entries (v3.27.0+), see [`CHANGELOG.md`](CHANGELOG.md).**
>
> Rotation rule: when main CHANGELOG exceeds 2,000 lines OR 30 versions, oldest 50% rotate here.

(content from /tmp/changelog-archive-content.md follows below)

---

```

Then append the extracted archive content from Step 2.2.

- [ ] **Step 2.4: Trim main CHANGELOG.md**

Replace main `CHANGELOG.md` content from `STOP_LINE` to end with single line referencing archive. Use this awk command pattern:

```bash
awk -v stop=$STOP_LINE 'NR < stop' CHANGELOG.md > /tmp/changelog-recent.md
```

Then prepend an archive cross-ref note to the main file. The header section already has Keep-a-Changelog preamble; after line 7 (or wherever the preamble ends, before the first `## [...]` entry), insert:

```markdown
> **Pre-v3.27.0 history rotated to [`CHANGELOG-ARCHIVE.md`](CHANGELOG-ARCHIVE.md)** on 2026-05-26 (Iter 63 SP1 perf refactor). Rotation rule: when this file exceeds 2,000 lines OR 30 versions, oldest 50% rotate to archive.
```

Replace original CHANGELOG.md with `/tmp/changelog-recent.md` content + the archive cross-ref note inserted.

- [ ] **Step 2.5: Verify rotation math**

Run: `wc -l CHANGELOG.md CHANGELOG-ARCHIVE.md`
Expected: CHANGELOG.md ~1,500 lines or less; CHANGELOG-ARCHIVE.md ~4,000-4,200 lines.

Run: `grep -c "^## \[" CHANGELOG.md`
Expected: ~28 entries (v3.27.0 through v3.41.0).

Run: `grep -c "^## \[" CHANGELOG-ARCHIVE.md`
Expected: ~54 entries (pre-v3.27.0).

Run: `grep -c "rotated to.*CHANGELOG-ARCHIVE" CHANGELOG.md`
Expected: 1 (the cross-ref note added).

- [ ] **Step 2.6: Commit CHANGELOG rotation**

```bash
git add CHANGELOG.md CHANGELOG-ARCHIVE.md
git commit -m "feat(iter-63): CHANGELOG archive rotation — pre-v3.27.0 → CHANGELOG-ARCHIVE.md

Per spec Section 3.5. Main CHANGELOG.md trimmed from 5,663 lines → ~1,500
lines (73% reduction). Pre-v3.27.0 history (54 entries) rotated to
CHANGELOG-ARCHIVE.md at repo root. Cross-ref note added to main header.

Future rotation rule (per spec): when main CHANGELOG exceeds 2,000 lines
OR 30 versions, oldest 50% rotate to archive.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Section 4 — Deterministic classifier rules + anti-recursive guard preview in CLAUDE.md

**Files:**
- Modify: `plugins/mega-sdd/CLAUDE.md`

- [ ] **Step 3.1: Read CLAUDE.md current structure**

Run: `grep -n "^## " plugins/mega-sdd/CLAUDE.md`
Expected: list of top-level sections (Pull Request Requirements, Versioning, Release process, etc.)

- [ ] **Step 3.2: Append classifier + guard sections**

At the end of `plugins/mega-sdd/CLAUDE.md` (before any final separator), append:

```markdown
---

## Iter Ceremony Classifier (v3.42.0+, Iter 63 — runtime impl in Iter 65)

Per Iter 63 SP1 spec §3.4: each iter has type PATCH/MINOR/MAJOR determined by deterministic git/filesystem inputs — NO LLM self-judgment. Same enum evaluated at TWO points (dual EP per spec meta-tune #1):

### Evaluation Point 1 (EP1) — Ceremony gating, PRE-work

Determines what artifacts to emit (CHANGELOG / spec / plan / audit). Inputs:

- `est_files_changed` = `git diff --stat HEAD | wc -l` (working tree vs HEAD)
- `est_halt_enum_diff` = grep working tree diff of vault-contract.md halt enum
- `est_new_skill_dir` = check working tree for new `plugins/mega-sdd/skills/<new>/` directories
- `breaking_marker` = user explicit flag `--iter-type=<>` OR scope-statement in brainstorming session
- Fallback (no working-tree changes yet): user's stated iter-type from brainstorming intent; default PATCH

### Evaluation Point 2 (EP2) — Version-bump labeling, POST-work

Determines plugin.json version bump (PATCH/MINOR/MAJOR) + CHANGELOG label. Inputs:

- `files_changed` = `git diff --name-only HEAD~1 HEAD | wc -l`
- halt-enum diff = `git diff HEAD~1 HEAD -- plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | grep -c "^[+-].*type:.*|"`
- new skill dir = `git diff HEAD~1 HEAD --name-status | grep "^A.*plugins/mega-sdd/skills/.*/SKILL.md"`
- handoff-contract field diff = same pattern on `handoff-contract.md`
- breaking change marker = `git log -1 --pretty=%B | grep -c "BREAKING CHANGE:"`

### Classifier criteria (same enum, both EPs)

| Iter type | Criteria (machine-checkable) | Required artifacts | Optional |
|---|---|---|---|
| **PATCH** | `files_changed ≤ 5` AND no halt-enum diff AND no new skill dir AND no `BREAKING CHANGE:` marker | CHANGELOG entry only | (nothing) |
| **MINOR** | `files_changed 5-15` OR new halt-enum entry OR new field in handoff-contract OR existing skill body modified | CHANGELOG entry | Spec (only if brainstorming skill invoked) |
| **MAJOR** | new skill dir OR `BREAKING CHANGE:` commit marker OR `files_changed > 15` | CHANGELOG + spec + plan | Audit (only if explicitly requested) |

### Precedence rule (uniform across plugin)

```
explicit user flag (--iter-type=major) > classifier output > default (PATCH)
```

### EP1 vs EP2 drift handling

If EP1 classified PATCH but EP2 reveals MAJOR criteria met (scope grew during work): emit drift warning + retroactively generate missing artifacts (spec/plan) under accelerated rules (compressed prose; not full ceremony). Log to telemetry as `ceremony_classifier_drift` event for Iter 68 analysis.

**Runtime impl shipped in Iter 65** (SP2) — `plugins/mega-sdd/scripts/classify-iter.sh` script + orchestrate-flow integration. Iter 63 ships RULE DOC only.

---

## Anti-Recursive Guard (v3.42.0+, Iter 63 PREVIEW — runtime impl in Iter 65)

Per Iter 63 SP1 spec §7. Prevents validating-the-validation recursion + caps re-plan loops.

### RULE 1 — Re-plan triggers (CLOSED ENUM, no LLM judgment)

```
re-plan triggered by ONE of:
  execution_failed    | commit failed / test failed / halt fired
  ambiguity_increased | new contract mismatch detected POST-plan
  contract_mismatch   | handoff field TYPE drift caught at Iter 33 F4 validation gate
                      | (strictly TYPE drift — see RULE 1.5)
```

### RULE 1.5 — Explicit exclusion (binding CONFLICT NOT a re-plan trigger)

`bind-codebase` CONFLICT hard-gate stays human-halt (user resolves via `resolve-oq` OR vault edit). Guard MUST NOT loop binding gate into re-plan cycles. Scope of `contract_mismatch` is **HANDOFF FIELD TYPE DRIFT ONLY** — not broader semantic disagreement.

### RULE 2 — Hard caps per task (CONFIGURABLE DEFAULTS, tune post-Iter 68)

```
max_replan_count:    2  (DEFAULT — magic number; tune post-Iter 68 telemetry)
max_revalidate_count: 3  (DEFAULT — same caveat)
```

Exceeded → halt (NAMING DEFERRED to Iter 65 implementation per spec meta-tune #5). Iter 65 evaluates reuse-first options BEFORE creating new halt enum entry: (a) generalize `bolt_repeated_partial_failure` semantic, (b) add `quality_gate_failed` subtype, (c) LAST RESORT only — new halt enum entry.

### RULE 3 — No validating-the-validation

Validators are LEAF NODES in execution graph, not internal nodes. If validation step itself fails, halt directly — DO NOT spawn meta-validation. "Plan to validate the validation plan" is recursion → prohibited.

**Runtime impl shipped in Iter 65** (SP2) — `plugins/mega-sdd/scripts/check-recursion-budget.sh` script + ephemeral state file `<project>/.mega-sdd/.replan-budget`. Iter 63 ships RULE DOC only.

---
```

- [ ] **Step 3.3: Verify CLAUDE.md additions**

Run: `grep -c "Iter Ceremony Classifier\|Anti-Recursive Guard\|RULE 1.5\|EP1\|EP2" plugins/mega-sdd/CLAUDE.md`
Expected: ≥ 5 matches (all key anchors present)

Run: `wc -l plugins/mega-sdd/CLAUDE.md`
Expected: previous count + ~75 lines

- [ ] **Step 3.4: Commit CLAUDE.md classifier + guard rules**

```bash
git add plugins/mega-sdd/CLAUDE.md
git commit -m "feat(iter-63): + deterministic iter classifier + anti-recursive guard rules (DOC ONLY)

Per spec Section 3.4 + Section 4 + Section 7. Adds two plugin-wide rule
sections to CLAUDE.md:

1. Iter Ceremony Classifier — PATCH/MINOR/MAJOR enum determined by
   deterministic git/fs inputs. Dual evaluation points (EP1 pre-work,
   EP2 post-work). Precedence: explicit flag > classifier > default.

2. Anti-Recursive Guard preview — closed-enum re-plan triggers, binding
   CONFLICT explicit exclusion, configurable hard caps, no-validating-
   validation rule.

Iter 63 ships RULE DOC ONLY. Runtime enforcement (classify-iter.sh,
check-recursion-budget.sh, orchestrate-flow integration) lands in Iter 65
(SP2 spec).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Section 3 — Command differentiation (cross-refs)

**Files:**
- Modify: `plugins/mega-sdd/commands/auto.md` (cross-ref block at top)
- Modify: `plugins/mega-sdd/commands/orchestrate-flow.md` (cross-ref block at top)

- [ ] **Step 4.1: Add cross-ref block to commands/auto.md**

In `plugins/mega-sdd/commands/auto.md`, immediately AFTER the frontmatter `---` closing line, BEFORE the body content, INSERT:

```markdown
> **`/mega-sdd:auto` vs `/mega-sdd:orchestrate-flow`** (Iter 63 clarification): both invoke the orchestrate-flow skill. The difference:
>
> - **`/mega-sdd:auto`** (this command) — user-facing entry-point. Detects input shape (PRD file / legacy code / brief / vault state) + proposes chain + single confirm. **Use this for typical workflows.**
> - **`/mega-sdd:orchestrate-flow`** — power-user lower-level chain executor. Skips input-shape detection (assumes user already knows what to chain). Use for advanced cases (custom chain composition, debugging).
>
> Both accept same flags. Both invoke the same skill. The difference is which front-door makes sense for your context.
```

- [ ] **Step 4.2: Add cross-ref block to commands/orchestrate-flow.md**

In `plugins/mega-sdd/commands/orchestrate-flow.md`, immediately AFTER the frontmatter `---` closing line, INSERT:

```markdown
> **`/mega-sdd:orchestrate-flow` vs `/mega-sdd:auto`** (Iter 63 clarification): both invoke the orchestrate-flow skill. The difference:
>
> - **`/mega-sdd:orchestrate-flow`** (this command) — power-user lower-level chain executor. Skips input-shape detection. Use when you know exactly what skills to chain (e.g., custom composition, partial pipeline re-run, debugging).
> - **`/mega-sdd:auto`** — user-facing entry-point with input-shape detection + chain proposal + single confirm. **Typical users should start there.**
>
> Both accept same flags. Both invoke the same skill. The difference is which front-door makes sense for your context.
```

- [ ] **Step 4.3: Verify cross-refs**

Run: `grep -c "vs.*orchestrate-flow\|vs.*auto" plugins/mega-sdd/commands/auto.md plugins/mega-sdd/commands/orchestrate-flow.md`
Expected: ≥ 2 (both files have cross-ref block)

- [ ] **Step 4.4: Commit command differentiation**

```bash
git add plugins/mega-sdd/commands/auto.md plugins/mega-sdd/commands/orchestrate-flow.md
git commit -m "docs(iter-63): clarify /mega-sdd:auto vs /mega-sdd:orchestrate-flow

Per spec Section 3.3. Both commands invoke same skill. Difference is
front-door semantics: auto = user-facing entry with input-shape detection
+ chain proposal; orchestrate-flow = power-user lower-level executor.

No deprecation, no merge. Cross-ref blocks added to both command files
to eliminate audit-flagged ambiguity (Iter 56 finding C-001).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Section 2a — generate-intent body trim (1,267 → ~700 lines)

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-intent/SKILL.md` — body trim
- Create: `plugins/mega-sdd/skills/generate-intent/references/phase-context.md` — moved Iter 35 phase context detail

**Strategy:** move-to-references + structural cleanup. NO rewrite. Targets:

1. **Halt-protocol descriptions** in generate-intent SKILL.md — these are MIRRORED in `references/vault-contract.md` §halt-protocol (where they're canonical). Remove the mirrored copies from SKILL.md body; replace with single cross-ref line.

2. **Iter 35 phase context detail** — multi-paragraph procedural description of `--phase=N` flag behavior + phase_total tracking + 00-index.md §Phase context block emission. Move to new `references/phase-context.md`. Body keeps single-line summary + cross-ref.

3. **Version-stamp prose** — lines like "v1.10+, Iter 46:" + multi-paragraph rationale of why behavior changed in that iter. Git log has this history. Strip prose; keep only behavioral spec.

- [ ] **Step 5.1: Snapshot current size**

Run: `wc -l plugins/mega-sdd/skills/generate-intent/SKILL.md`
Expected: ~1,267 lines (audit baseline)

- [ ] **Step 5.2: Create references/phase-context.md (relocation target)**

Create `plugins/mega-sdd/skills/generate-intent/references/phase-context.md` with header:

```markdown
# Phase Context — generate-intent Iter 35 behavior

> Consumed by `generate-intent/SKILL.md` Mode B KB sub-mode (when `--phase=N` flag passed). Relocated from SKILL.md body in Iter 63 SP1 (hot-tier trim).

## Overview

`generate-intent --kb=<kb> --phase=N` produces a phase-scoped vault from a knowledge base. Phase context lets users build complex projects in slices (Phase 1: core auth, Phase 2: payment, etc.) instead of one mega-vault.

## vault.json fields

- `phase: <int>` — current phase number (1-indexed)
- `phase_total: <int>` — total phases in project (from KB suggested-phasing.md)
- Both fields OPTIONAL pre-v3.26.0 (default `phase: 1, phase_total: 1` for back-compat)

## 00-index.md §Phase context block

When `phase` field present in vault.json, generate-intent emits §Phase context section in 00-index.md:

[Engineer: copy the actual content from SKILL.md procedural detail about phase context — Step 3.x onward — into this reference file. Preserve all behavioral specifics. ~50-80 lines expected.]

## Consumer

`orchestrate-flow/SKILL.md` Step 7 (final summary) reads vault.json `phase` field; emits phase-aware "next phase" hint at chain end (Iter 35 behavior).
```

(Engineer will copy the detailed procedural content from generate-intent SKILL.md during trim Step 5.3.)

- [ ] **Step 5.3: Trim generate-intent SKILL.md body**

In `plugins/mega-sdd/skills/generate-intent/SKILL.md`, perform these cuts in order:

**A. Halt-protocol description block** — find any section in SKILL.md that ENUMERATES halt types (`oq_blocker`, `oq_tech_missing_mode`, etc.) with descriptions matching vault-contract.md content. Replace the full block with:

```markdown
> Halt-protocol enumeration + descriptions: canonical in `references/vault-contract.md` §halt-protocol. generate-intent emits these halts:
> `oq_blocker | oq_tech_missing_mode | oq_recommend_underspecified | oq_scan_missing_query | oq_business_p1_unresolved | prd_no_scopes_block_user_rejected_retrofit | prd_retrofit_low_confidence | scope_not_declared_in_prd | memory_in_use`
```

**B. Iter 35 phase context detail** — find Iter 35 procedural detail about `--phase=N` flag + phase_total tracking + 00-index.md emission. Cut the multi-paragraph block (~50-80 lines). Replace with:

```markdown
> Phase context (Iter 35, v1.14+): when `--phase=N` flag passed in Mode B KB sub-mode, vault.json gains `phase` + `phase_total` fields; 00-index.md emits §Phase context block. Full procedural detail: `references/phase-context.md`.
```

**C. Version-stamp prose strip** — find lines matching pattern `**v<version>+, Iter <N> (<rationale>)**` followed by multi-paragraph explanation. Keep the behavioral spec; strip the version-stamp explanation paragraphs. Example transformation:

BEFORE:
```markdown
**v1.4+, Iter 2 (Auto-classifier)**: Iter 2 introduced auto-classification for OQ category + resolution_mode + classification_confidence per `references/vault-contract.md` §Auto-classifier heuristics. Pre-v1.4 vaults relied on manual category tagging; auto-classifier reduces stakeholder triage time by ~40% per Iter 2 measurement. Behavior: every OQ gains 3 fields...
```

AFTER:
```markdown
**Auto-classifier (v1.4+)**: every OQ gains `category`/`resolution_mode`/`classification_confidence` fields per `references/vault-contract.md` §Auto-classifier heuristics.
```

Apply this transformation to all version-stamp prose blocks in the file. Target: trim ~400-500 lines.

- [ ] **Step 5.4: Move phase-context content from SKILL.md to reference**

After Step 5.3.B cut the phase context block, paste the cut content into `references/phase-context.md` (replacing the `[Engineer: copy the actual content...]` placeholder from Step 5.2).

- [ ] **Step 5.5: Verify size + content integrity**

Run: `wc -l plugins/mega-sdd/skills/generate-intent/SKILL.md plugins/mega-sdd/skills/generate-intent/references/phase-context.md`
Expected: SKILL.md ~700 lines (target); phase-context.md ~80-100 lines.

Run: `grep -c "halt-protocol\|Auto-classifier\|--phase=N" plugins/mega-sdd/skills/generate-intent/SKILL.md`
Expected: ≥ 3 (all key behaviors still referenced; even if detail moved)

Run: `grep -c "references/phase-context.md\|references/vault-contract.md" plugins/mega-sdd/skills/generate-intent/SKILL.md`
Expected: ≥ 2 (cross-refs to relocated content)

- [ ] **Step 5.6: Bump generate-intent skill version (PATCH)**

Find frontmatter: `version: 1.16.0` → replace with `version: 1.16.1`

- [ ] **Step 5.7: Commit generate-intent trim**

```bash
git add plugins/mega-sdd/skills/generate-intent/SKILL.md plugins/mega-sdd/skills/generate-intent/references/phase-context.md
git commit -m "perf(iter-63): generate-intent body trim 1,267 → ~700 lines (hot-tier relocation)

Per spec Section 3.2 + audit T-001. Move-to-references + structural
cleanup. No rewrite — preserves correctness.

Relocations:
- Halt-protocol descriptions: cross-ref to canonical vault-contract.md
- Iter 35 phase context detail (~80 lines) → references/phase-context.md
- Version-stamp prose stripped (git log has history)

Hot-tier reduction: 1,267 → ~700 lines (-45%). References net +80 lines.
Backward compat preserved (all behaviors still callable).

Skill version: 1.16.0 → 1.16.1 (PATCH — trim, no behavior change)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Section 2b — execute-bolts body trim (1,012 → ~600 lines)

**Files:**
- Modify: `plugins/mega-sdd/skills/execute-bolts/SKILL.md`
- Create: `plugins/mega-sdd/skills/execute-bolts/references/t2-budget-tracker.md`
- Create: `plugins/mega-sdd/skills/execute-bolts/references/saga-rollback.md`

**Strategy:** Move Iter 44 T2 budget tracker procedural detail + Iter 45 saga compensating actions detail to references. Body keeps single-line summaries + cross-refs.

- [ ] **Step 6.1: Snapshot current size**

Run: `wc -l plugins/mega-sdd/skills/execute-bolts/SKILL.md`
Expected: ~1,012 lines

- [ ] **Step 6.2: Create references/t2-budget-tracker.md**

Create the reference file with header + placeholder for content move:

```markdown
# T2 Budget Tracker — execute-bolts Iter 44 mechanism

> Consumed by `execute-bolts/SKILL.md` Step 4.5.a.5. Relocated from SKILL.md body in Iter 63 SP1 (hot-tier trim).

## Overview

Per Iter 44 (closes audit D1-003), execute-bolts tracks running T2 (tier-2) context consumption per bolt + applies progressive section-level truncation based on priority order. Replaces the prior "single-halt at 10KB" enforcement from Iter 30.

## Running budget structure

[Engineer: copy from SKILL.md Step 4.5.a.5 onward — the `running_budget` YAML block + per-section update logic + truncation cascade table. ~150-200 lines expected.]

## Consumer

`bolt-dispatch-prompt.md` §Tier-loading algorithm uses this tracker to enforce 7KB target / 10KB hard cap. Bolt subagent reads `### T2 budget tracker` section of dispatch prompt to understand truncation context (sets `confidence: MEDIUM` for truncated claims).
```

- [ ] **Step 6.3: Create references/saga-rollback.md**

Create the reference file with header + placeholder:

```markdown
# Saga Compensating Actions — execute-bolts Iter 45 mechanism

> Consumed by `execute-bolts/SKILL.md` `--rollback` flag (v2.9.0+). Relocated from SKILL.md body in Iter 63 SP1 (hot-tier trim).

## Overview

Per Iter 45 (closes audit Pattern D / D3-009), execute-bolts emits `rollback_hints[]` per significant step (file write / dep add / migration / etc.). On `--rollback` flag, applies hints in reverse order as compensating actions (saga pattern from microservices.io).

## Step type canonical taxonomy

[Engineer: copy from SKILL.md the step type table — file_created / file_modified / composer_dep_added / migration_executed / etc. ~50-80 lines expected.]

## Bolt subagent contract

[Engineer: copy from SKILL.md the bolt-report.md `## Rollback hints` emission contract. ~30 lines.]

## --rollback flow

[Engineer: copy from SKILL.md the --rollback procedure — read partial-state, display reverse-order list with idempotency markers, AskUserQuestion gate with [I] interactive default (Iter 57 fix-forward), apply actions, rename .rolled-back-<ISO8601>. ~80 lines.]

## Out of scope

- Auto-rollback on crash (user-initiated only)
- Cross-bolt saga (single bolt scope)
- DB introspection for migration_executed rollback
```

- [ ] **Step 6.4: Trim execute-bolts SKILL.md body**

In `plugins/mega-sdd/skills/execute-bolts/SKILL.md`, perform these cuts:

**A. T2 budget tracker block** — find Step 4.5.a.5 procedural detail (Iter 44). Cut the multi-section block including running_budget YAML + per-section update logic + truncation cascade table. Paste cut content into `references/t2-budget-tracker.md` (replace placeholder from Step 6.2). Replace in SKILL.md with:

```markdown
**a.5 Initialize T2 budget tracker (Iter 44 v2.8.0+)**

Track running T2 consumption + apply progressive section-level truncation per priority order. Replaces Iter 30 "single-halt at 10KB" enforcement.

Detail: `references/t2-budget-tracker.md` (running_budget structure, per-section update logic, truncation cascade table).
```

**B. Saga compensating actions block** — find the §Saga compensating actions section (Iter 45). Cut the entire section (step type taxonomy + bolt contract + --rollback flow). Paste into `references/saga-rollback.md` (replace placeholders from Step 6.3). Replace in SKILL.md with:

```markdown
### Saga compensating actions (v2.9.0+, Iter 45 — `--rollback` flag)

Closes Iter 38 audit Pattern D. Forward-only `--resume` cannot undo non-idempotent prior steps (composer dep adds, migrations, external API calls). `--rollback` applies `rollback_hints[]` from partial-state.json v2.0 in reverse order with per-step confirmation (Iter 57 fix-forward: default `[I] interactive`, not batch).

Detail: `references/saga-rollback.md` (step type taxonomy, bolt contract, --rollback flow, idempotency markers, out-of-scope list).
```

**C. Version-stamp prose strip** — apply same pattern as Task 5 Step 5.3.C. Target additional ~80-100 lines.

- [ ] **Step 6.5: Verify size + content integrity**

Run: `wc -l plugins/mega-sdd/skills/execute-bolts/SKILL.md plugins/mega-sdd/skills/execute-bolts/references/t2-budget-tracker.md plugins/mega-sdd/skills/execute-bolts/references/saga-rollback.md`
Expected: SKILL.md ~600 lines; t2-budget-tracker.md ~150-200 lines; saga-rollback.md ~150-200 lines.

Run: `grep -c "references/t2-budget-tracker.md\|references/saga-rollback.md" plugins/mega-sdd/skills/execute-bolts/SKILL.md`
Expected: ≥ 2 (cross-refs present)

- [ ] **Step 6.6: Bump execute-bolts skill version (PATCH)**

Find frontmatter: `version: 2.10.1` → replace with `version: 2.10.2`

- [ ] **Step 6.7: Commit execute-bolts trim**

```bash
git add plugins/mega-sdd/skills/execute-bolts/SKILL.md plugins/mega-sdd/skills/execute-bolts/references/t2-budget-tracker.md plugins/mega-sdd/skills/execute-bolts/references/saga-rollback.md
git commit -m "perf(iter-63): execute-bolts body trim 1,012 → ~600 lines (hot-tier relocation)

Per spec Section 3.2 + audit T-002. Move-to-references + structural
cleanup. No rewrite.

Relocations:
- Iter 44 T2 budget tracker detail (~180 lines) → references/t2-budget-tracker.md
- Iter 45 saga compensating actions detail (~180 lines) → references/saga-rollback.md
- Version-stamp prose stripped

Hot-tier reduction: 1,012 → ~600 lines (-41%). References net +360 lines.

Skill version: 2.10.1 → 2.10.2 (PATCH — trim, no behavior change)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: Section 2c — generate-units body trim (826 → ~500 lines)

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-units/SKILL.md`
- Modify: `plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md` (consolidate)

**Strategy:** Move adversarial review wiring detail to existing `references/adversarial-test-prompt.md` (consolidation, not new file).

- [ ] **Step 7.1: Snapshot current size**

Run: `wc -l plugins/mega-sdd/skills/generate-units/SKILL.md plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md`
Expected: SKILL.md ~826; adversarial-test-prompt.md ~current size.

- [ ] **Step 7.2: Trim generate-units body — adversarial review block**

In `plugins/mega-sdd/skills/generate-units/SKILL.md`, find Step 9.5 (Iter 47 adversarial review pass) + the `_authored_by` 7-value enum + NOTE injection contract for execute-bolts. This content is partially mirrored in `references/adversarial-test-prompt.md` already.

Cut the procedural detail (NOT the step header) from SKILL.md. Append the cut content to `references/adversarial-test-prompt.md` under a new section `## Iter 47 adversarial review procedure (relocated from SKILL.md Iter 63)`.

Replace in SKILL.md with:
```markdown
### Step 9.5: Adversarial review pass (Iter 47, v2.7.0+)

Author independent adversarial review of generated unit acceptance_test. Sets `_authored_by` provenance value (7-value enum) that execute-bolts reads to inject NOTE warning when test may have blind spots.

Detail: `references/adversarial-test-prompt.md` (canonical prompt template, default mode + opt-in subagent mode, gap merge logic, 7 _authored_by provenance values, consumer wiring in execute-bolts §Step 4.5.a).
```

- [ ] **Step 7.3: Apply version-stamp prose strip**

Same pattern as previous tasks. Target ~150-200 additional lines.

- [ ] **Step 7.4: Verify size + content integrity**

Run: `wc -l plugins/mega-sdd/skills/generate-units/SKILL.md`
Expected: ~500 lines

Run: `grep -c "references/adversarial-test-prompt.md\|_authored_by" plugins/mega-sdd/skills/generate-units/SKILL.md`
Expected: ≥ 2 (cross-ref + at least one behavior mention preserved)

- [ ] **Step 7.5: Bump generate-units skill version (PATCH)**

Find frontmatter: `version: 2.7.1` → replace with `version: 2.7.2`

- [ ] **Step 7.6: Commit generate-units trim**

```bash
git add plugins/mega-sdd/skills/generate-units/SKILL.md plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md
git commit -m "perf(iter-63): generate-units body trim 826 → ~500 lines (hot-tier relocation)

Per spec Section 3.2 + audit T-003. Adversarial review wiring detail
consolidated into existing references/adversarial-test-prompt.md.
Version-stamp prose stripped.

Hot-tier reduction: 826 → ~500 lines (-39%). adversarial-test-prompt.md
gains ~200 lines of relocated content.

Skill version: 2.7.1 → 2.7.2 (PATCH — trim, no behavior change)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Section 2d — orchestrate-flow body trim (764 → ~500 lines) + FSD opt-out version bump

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — body trim + version bump 3.7.0 → 3.8.0
- Create: `plugins/mega-sdd/skills/orchestrate-flow/references/validation-gate.md`

**Strategy:** Move Iter 33 F3+F4 validation gate detail (Step b.i schema validation procedure) to new reference. Body keeps step header + cross-ref.

- [ ] **Step 8.1: Snapshot current size**

Run: `wc -l plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`
Expected: ~764 lines

- [ ] **Step 8.2: Create references/validation-gate.md**

Create the reference file:

```markdown
# Schema + Type Validation Gate — orchestrate-flow Iter 33 F3+F4 + Iter 60 strict default

> Consumed by `orchestrate-flow/SKILL.md` Step 6 sub-step b.i. Relocated from SKILL.md body in Iter 63 SP1 (hot-tier trim).

## Overview

Per Iter 33 F3 (schema validation) + F4 (type-check) + Iter 60 (bypass tightening): every cross-skill handoff is validated at the orchestrator boundary against `handoff-contract.md` schema annotations.

## F3 — REQUIRED/CONDITIONAL/OPTIONAL field validation

[Engineer: copy from SKILL.md Step 6 sub-step b.iii (REQUIRED) + b.iv (CONDITIONAL) + b.v (OPTIONAL) procedural detail. ~50-80 lines.]

## F4 — TYPE annotation validation

[Engineer: copy from SKILL.md Step 6 sub-step b.i procedural detail — TYPE language enumeration (string/int/enum/array/object/sha256/ISO8601/bool/nullable), validation logic per type, halt_type_mismatch envelope. ~60-100 lines.]

## Iter 60 strict default (anti-halu rail strengthening)

Pre-Iter-60: missing TYPE annotation → warn-only + continue. Post-Iter-60: missing TYPE annotation → halt `handoff_type_mismatch` (halt-against-author). Migration flag `--legacy-type-bypass` available for one chain run.

## Halt envelopes

[Engineer: copy from SKILL.md the example halt YAML envelopes for handoff_type_mismatch / invalid_handoff / handoff_missing / artifact_missing. ~40-60 lines.]
```

- [ ] **Step 8.3: Trim orchestrate-flow SKILL.md body**

In `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`, find Step 6 sub-step b.i through b.vi (validation gate procedural detail). Cut the procedural body (KEEP the step headers + halt names). Paste cut content into `references/validation-gate.md` (replace placeholders from Step 8.2).

Replace in SKILL.md with:
```markdown
b. **Validation gate (v3.0.0+, Iter 33 F3+F4; bypass tightened Iter 60 per audit C-005):**

   Validate received handoff against `references/handoff-contract.md` schema annotations. 10 sub-steps:

   0. Handoff presence check (chat-block detection per Iter 43 fix-forward) — halt `handoff_missing` on absence
   i. Type-check fields against TYPE annotations — halt `handoff_type_mismatch` on mismatch OR missing annotation (Iter 60 strict default)
   ii. YAML parse — halt `invalid_handoff` on parse failure
   iii. REQUIRED fields — halt `invalid_handoff` on absence
   iv. CONDITIONAL fields — halt `invalid_handoff` if condition met AND field absent
   v. OPTIONAL fields — log only
   vi. All schema checks pass → continue
   vii. Artifact existence check — halt `artifact_missing` on absent paths
   viii. Cross-metric consistency (Iter 53 starterkit_metrics_inconsistent) — halt `quality_gate_failed` with subtype on inconsistency
   ix. (was viii in pre-Iter-53) All checks pass → continue to step c

Procedural detail (TYPE language enum, halt envelope templates, F3 vs F4 distinction, Iter 60 migration flag): `references/validation-gate.md`.
```

- [ ] **Step 8.4: Apply version-stamp prose strip + Section 1 version bump**

Apply version-stamp prose strip pattern. Target ~80 additional lines.

Also bump orchestrate-flow version per spec §3.1: find frontmatter `version: 3.7.0` → replace with `version: 3.8.0` (MINOR — FSD default flip from Task 1 + body trim combined).

- [ ] **Step 8.5: Verify size + content integrity**

Run: `wc -l plugins/mega-sdd/skills/orchestrate-flow/SKILL.md plugins/mega-sdd/skills/orchestrate-flow/references/validation-gate.md`
Expected: SKILL.md ~500 lines; validation-gate.md ~150-200 lines.

Run: `grep -c "references/validation-gate.md\|handoff_type_mismatch" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`
Expected: ≥ 2

Run: `grep "^version:" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`
Expected: `version: 3.8.0`

- [ ] **Step 8.6: Commit orchestrate-flow trim + version bump**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/SKILL.md plugins/mega-sdd/skills/orchestrate-flow/references/validation-gate.md
git commit -m "perf(iter-63): orchestrate-flow body trim 764 → ~500 + version 3.7.0 → 3.8.0 (FSD default flip)

Per spec Section 3.1 + Section 3.2 + audit T-004. Iter 33 F3+F4
validation gate detail relocated to references/validation-gate.md.
Step 6 keeps step headers + halt names + cross-ref to detail.

Version bump 3.7.0 → 3.8.0 MINOR — combines:
  - Task 1: FSD default flip on→off (auto-invoke behavior change)
  - Task 8: body trim 764 → ~500 (hot-tier relocation)

Hot-tier reduction: 764 → ~500 lines (-35%). validation-gate.md ~180 lines.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: Section 2e — Medium-trim 5 remaining heavy skills (20-30% each)

**Files:** Modify (apply version-stamp prose strip):
- `plugins/mega-sdd/skills/extract-intelligence/SKILL.md`
- `plugins/mega-sdd/skills/scan-codebase/SKILL.md`
- `plugins/mega-sdd/skills/bind-codebase/SKILL.md`
- `plugins/mega-sdd/skills/emit-fsd/SKILL.md`
- `plugins/mega-sdd/skills/diff-vault/SKILL.md`

**Strategy:** Per audit, these 5 skills are heavy but lighter than the top 4. Apply version-stamp prose strip pattern (lines like "**v1.10+, Iter 46 (rationale)**: multi-paragraph explanation") — keep behavioral spec, strip historical context (git log has it). Target 20-30% reduction per file.

- [ ] **Step 9.1: For each skill, snapshot + trim + verify + commit**

For each of the 5 skills above:

```bash
SKILL=<one of: extract-intelligence | scan-codebase | bind-codebase | emit-fsd | diff-vault>
FILE=plugins/mega-sdd/skills/$SKILL/SKILL.md

# Snapshot
BEFORE=$(wc -l $FILE | awk '{print $1}')
echo "Before: $BEFORE lines"
```

Apply version-stamp prose strip (same pattern as Task 5 Step 5.3.C):

- Find lines matching `**v<X.Y>+, Iter <N> (<rationale>)**` followed by multi-paragraph explanation
- Keep the BEHAVIORAL spec line (what the version does)
- Strip the RATIONALE paragraphs (why it was needed, what it replaced — git log + spec docs have this)
- Strip lines marked `**Iter 56 fix-forward note:**` etc. (closure notes that are now historical)

Bump version frontmatter PATCH (current → current+0.0.1).

```bash
# Verify trim
AFTER=$(wc -l $FILE | awk '{print $1}')
REDUCTION=$(( (BEFORE - AFTER) * 100 / BEFORE ))
echo "After: $AFTER lines ($REDUCTION% reduction)"
# Expected: 20-30% reduction
```

Commit per-skill:
```bash
git add $FILE
git commit -m "perf(iter-63): $SKILL version-stamp prose strip ($REDUCTION% trim)

Per spec Section 3.2 + audit T-005/006/007/008/009. Strip version-stamp
prose + Iter fix-forward notes. Git log + spec docs preserve history.

Skill version: PATCH bump (trim, no behavior change)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

Repeat for all 5 skills.

- [ ] **Step 9.2: Verify aggregate trim**

Run: `wc -l plugins/mega-sdd/skills/*/SKILL.md | tail -1`
Expected: total skill body lines reduced from 8,174 → ~6,500 (target hit).

---

## Task 10: Section 6 — Atomic release + READMEs + final CHANGELOG entry

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json` — v3.41.0 → v3.42.0
- Modify: `plugins/mega-sdd/README.md` — version refs + What's new
- Modify: `README.md` (root) — version refs + audit table Iter 63 row
- Modify: `CHANGELOG.md` — Iter 63 entry

- [ ] **Step 10.1: Plugin.json version bump**

In `plugins/mega-sdd/.claude-plugin/plugin.json`:

Find: `"version": "3.41.0",` → Replace with: `"version": "3.42.0",`

- [ ] **Step 10.2: Plugin README version refs + What's new**

In `plugins/mega-sdd/README.md`:

Find: `**Version:** 3.41.0 · **License:** MIT` → Replace: `**Version:** 3.42.0 · **License:** MIT`

Find: `├── .claude-plugin/plugin.json    # plugin manifest (v3.41.0)` → Replace: `├── .claude-plugin/plugin.json    # plugin manifest (v3.42.0)`

Find existing What's new section. INSERT BEFORE the most recent entry (v3.41.0):

```markdown
### v3.42.0 (Iter 63, minor) — Performance + Sharpness SP1 (Quick Wins)

User direction shift: feature work → performance / sharpness. "Senior engineer collaborator, not verbose assistant." Research-driven (LangChain Deep Agents 3-tier, Claude Code 95% lazy-load pattern, Cline complexity-gated Plan/Act, Morph context rot 30%+ empirical).

Iter 63 SP1 = Quick Wins ship (3 sub-projects total; SP2 + SP3 are roadmap).

**6 deliverables (no new skills, no new halts, no new schemas):**

1. **FSD auto-invoke opt-out** — emit-fsd flips from default-on auto-invoke to opt-in via `--with-fsd` flag. Legacy `--no-fsd` still works as no-op (back-compat). Standalone `/mega-sdd:emit-fsd` unchanged.
2. **Skill body trim ~1,500 lines hot-tier relocation** — move-to-references + structural cleanup (NO rewrite) across 9 heavy skills:
   - generate-intent 1,267 → ~700 (-45%) → +references/phase-context.md
   - execute-bolts 1,012 → ~600 (-41%) → +references/t2-budget-tracker.md + saga-rollback.md
   - generate-units 826 → ~500 (-39%) → consolidated into existing adversarial-test-prompt.md
   - orchestrate-flow 764 → ~500 (-35%) → +references/validation-gate.md
   - 5 medium-trim skills 20-30% each via version-stamp prose strip
3. **Command differentiation** — /mega-sdd:auto vs /mega-sdd:orchestrate-flow cross-ref blocks (no merge, no deprecation; eliminates audit C-001 ambiguity)
4. **Deterministic iter classifier rules** — added to plugins/mega-sdd/CLAUDE.md. Dual evaluation point (EP1 pre-work / EP2 post-work). PATCH/MINOR/MAJOR enum from git/fs counts; NO LLM judgment. Precedence: explicit flag > classifier > default. **DOC ONLY in Iter 63; runtime impl in Iter 65.**
5. **CHANGELOG archive rotation** — main CHANGELOG.md trimmed 5,663 → ~1,500 lines (73% reduction). Pre-v3.27.0 history rotated to CHANGELOG-ARCHIVE.md at repo root with cross-ref. Future rotation rule: 2,000-line / 30-version threshold.
6. **Anti-recursive guard rule doc** — preview added to CLAUDE.md (closed-enum re-plan triggers, binding CONFLICT explicit exclusion, configurable hard caps, no-validating-validation rule). Runtime impl in Iter 65.

**Effect on hot context:**
- Skill bodies: 8,174 → ~6,500 lines (-20%; loads every session via anchor)
- References: ~10,132 → ~11,132 lines (+1,000; loads on-demand)
- Plugin total: ~18,306 → ~17,632 lines (~-3.7%; near-flat)
- **Win is hot-tier RELOCATION, not deletion. Iter 66 (SP2) lazy-loading completes the picture.**

**Roadmap embedded in spec for SP2 (Iter 64-70, ~1 week edit work + 3-4 week telemetry soak gap):**
- Iter 64: 3-tier context architecture + START telemetry collection (cheap append-only)
- Iter 65: Complexity classifier RUNTIME (classify-iter.sh) + anti-recursive guard RUNTIME (check-recursion-budget.sh)
- Iter 66: Lazy reference loading per Claude Code 95% pattern
- Iter 67: Plan/Act mode COMPLEXITY-GATED (NOT universal — economics)
- Iter 68: Telemetry ANALYZE + SP3 gate decision
- Iter 69: Token budget enforcement (data-driven thresholds)
- Iter 70: Skill consolidation evaluation (data-driven)

**SP3 (v4.0.0 candidate)** R&D UNCOMMITTED with explicit Fork A/B decision required (correctness layer vs own runtime).

**Skill bumps:**
- `orchestrate-flow` 3.7.0 → 3.8.0 (MINOR — FSD default flip + body trim)
- `generate-intent` 1.16.0 → 1.16.1 (PATCH — trim)
- `execute-bolts` 2.10.1 → 2.10.2 (PATCH — trim)
- `generate-units` 2.7.1 → 2.7.2 (PATCH — trim)
- 5 medium-trim skills PATCH bumps per per-skill commit

**Plugin v3.41.0 → v3.42.0** (MINOR — auto-invoke behavior change with backward-compat).

**Last iter under OLD ceremony rules.** Iter 64+ subject to new deterministic classifier (most future iters will be PATCH = CHANGELOG entry only, no spec/plan ceremony per ~70% estimate).

```

- [ ] **Step 10.3: Root README version refs + audit table row**

In root `README.md`:

Find: `**Plugin:** \`mega-sdd\` · **Version:** 3.41.0 · **License:** MIT` → Replace: `**Plugin:** \`mega-sdd\` · **Version:** 3.42.0 · **License:** MIT`

Find: `├── plugins/mega-sdd/                       # the plugin itself (v3.41.0)` → Replace: `├── plugins/mega-sdd/                       # the plugin itself (v3.42.0)`

Find: `- **Plugin**: SemVer. Major bump for breaking renames, rails changes, marketplace incompatibility, or new top-level entrypoints. v3.0 = ast-grep grammar migration. Currently 3.41.0.` → Replace: `Currently 3.42.0.`

Find existing audit-history table. INSERT new row after the Iter 56 row:

```markdown
| Iter 63 (v3.42.0) | Performance + sharpness SP1 — Quick Wins | 7 audit findings closed (sizing + duplication + bloat) | Iter 63 ships ~1,500 line hot-tier relocation + FSD opt-out + classifier rules. SP2 (Iter 64-70) + SP3 (v4.0.0 candidate) roadmap committed in spec |
```

- [ ] **Step 10.4: CHANGELOG.md Iter 63 entry**

In `CHANGELOG.md` (now trimmed to v3.27.0+), find existing top entry `## [3.41.0] - 2026-05-26`. INSERT BEFORE it:

```markdown
## [3.42.0] - 2026-05-26

### Iter 63 — Performance + Sharpness SP1 (Quick Wins)

**Direction shift: feature work → performance + sharpness.** User shift from "more features" to "lean context, faster iteration, deterministic output, senior engineer collaborator." Research-driven (LangChain Deep Agents 3-tier, Claude Code 95% lazy-load, Cline complexity-gated Plan/Act, Morph context rot 30%+ empirical).

Iter 63 = Sub-Project 1 (Quick Wins) of 3-part roadmap. SP2 + SP3 roadmap embedded in spec.

**6 deliverables (Iter 63 SP1):**

1. **FSD auto-invoke opt-out** — `emit-fsd` flips from default-on auto-invoke to opt-in via `--with-fsd` flag. Reason: pandoc/LaTeX expensive + low user feedback signal per Iter 63 perf audit. `--no-fsd` legacy flag still accepted as no-op (back-compat). Standalone `/mega-sdd:emit-fsd` unchanged.

2. **Skill body trim ~1,500 lines hot-tier relocation** — move-to-references + structural cleanup. NO rewrite. Per audit:
   - generate-intent 1,267 → ~700 lines (-45%); +references/phase-context.md
   - execute-bolts 1,012 → ~600 lines (-41%); +references/t2-budget-tracker.md + saga-rollback.md
   - generate-units 826 → ~500 lines (-39%); consolidated into adversarial-test-prompt.md
   - orchestrate-flow 764 → ~500 lines (-35%); +references/validation-gate.md
   - 5 medium-trim skills (extract-intelligence, scan-codebase, bind-codebase, emit-fsd, diff-vault) 20-30% each via version-stamp prose strip

3. **Command differentiation** — `/mega-sdd:auto` vs `/mega-sdd:orchestrate-flow` cross-ref blocks in both command files. No merge, no deprecation. Eliminates Iter 56 audit C-001 ambiguity.

4. **Deterministic iter classifier rules** — PATCH/MINOR/MAJOR enum from git/fs inputs (NO LLM judgment). Dual evaluation point (EP1 pre-work for ceremony gating; EP2 post-work for version-bump labeling). Precedence: explicit flag > classifier > default. Added to plugins/mega-sdd/CLAUDE.md. **DOC ONLY in Iter 63; runtime impl ships Iter 65 (SP2).**

5. **CHANGELOG archive rotation** — main CHANGELOG trimmed 5,663 → ~1,500 lines (73% reduction). Pre-v3.27.0 history rotated to CHANGELOG-ARCHIVE.md at repo root. Future rotation rule: 2,000-line / 30-version threshold.

6. **Anti-recursive guard rule doc** — closed-enum re-plan triggers (`execution_failed | ambiguity_increased | contract_mismatch`), binding CONFLICT EXPLICITLY EXCLUDED (RULE 1.5; human-halt stays), configurable hard caps (max_replan=2, max_revalidate=3 defaults — tune post-Iter 68 telemetry), no-validating-validation rule. Halt naming for cap-exceeded DEFERRED to Iter 65 (reuse-first evaluation: `bolt_repeated_partial_failure` generalize / `quality_gate_failed` subtype / new enum LAST RESORT).

**Effect on hot context (per spec meta-tune #3 — math reconciled):**
- Skill bodies (HOT tier, loads every session): 8,174 → ~6,500 lines (-1,674 / -20%)
- References (SPECIALIST/COLD, loads on-demand): ~10,132 → ~11,132 lines (+1,000 due to relocation)
- Pure deletion (version-stamp prose, redundant historical context, mirrored content): ~-674 lines
- Plugin total: ~18,306 → ~17,632 lines (~-3.7%; near-flat)
- **The win is hot-tier RELOCATION, not deletion.** Iter 66 (SP2) lazy-loading completes the picture.

**Surface changes:**

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — Step 6 FSD opt-out + body trim + version 3.7.0 → 3.8.0
- `plugins/mega-sdd/commands/auto.md` + `commands/orchestrate-flow.md` — `--with-fsd` flag + cross-ref blocks
- `plugins/mega-sdd/skills/generate-intent/SKILL.md` — body trim; version 1.16.0 → 1.16.1
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — body trim; version 2.10.1 → 2.10.2
- `plugins/mega-sdd/skills/generate-units/SKILL.md` — body trim; version 2.7.1 → 2.7.2
- 5 medium-trim skill SKILL.md files — PATCH version bumps
- `plugins/mega-sdd/skills/generate-intent/references/phase-context.md` — NEW (relocated content)
- `plugins/mega-sdd/skills/execute-bolts/references/t2-budget-tracker.md` — NEW
- `plugins/mega-sdd/skills/execute-bolts/references/saga-rollback.md` — NEW
- `plugins/mega-sdd/skills/orchestrate-flow/references/validation-gate.md` — NEW
- `plugins/mega-sdd/skills/generate-units/references/adversarial-test-prompt.md` — consolidated (~+200 lines)
- `plugins/mega-sdd/CLAUDE.md` — + classifier section + anti-recursive guard section (~+75 lines)
- `CHANGELOG.md` — rotated to ~1,500 lines + this entry
- `CHANGELOG-ARCHIVE.md` — NEW (pre-v3.27.0 entries)
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.41.0 → 3.42.0
- `plugins/mega-sdd/README.md` + `README.md` (root) — version refs + What's new + audit table row

**Skill version bumps:**
- `orchestrate-flow` 3.7.0 → 3.8.0 (MINOR — FSD default flip + body trim)
- `generate-intent` 1.16.0 → 1.16.1 (PATCH — body trim)
- `execute-bolts` 2.10.1 → 2.10.2 (PATCH — body trim)
- `generate-units` 2.7.1 → 2.7.2 (PATCH — body trim)
- `extract-intelligence`, `scan-codebase`, `bind-codebase`, `emit-fsd`, `diff-vault` — PATCH bumps per per-skill trim commit

**Plugin v3.41.0 → v3.42.0** (MINOR — auto-invoke behavior change with backward-compat flag).

**Roadmap (committed in spec; not in this CHANGELOG):**

- **SP2 (Iter 64-70, ~1 week edit + 3-4 week telemetry soak):** 3-tier context architecture + telemetry collection start (Iter 64) + classifier/guard runtime (Iter 65) + lazy reference loading (Iter 66) + complexity-gated Plan/Act (Iter 67) + telemetry analyze + SP3 gate (Iter 68) + budget enforcement (Iter 69) + skill consolidation (Iter 70)
- **SP3 (v4.0.0 candidate):** R&D UNCOMMITTED. Explicit Fork A (correctness layer on top of host runtime) vs Fork B (own runtime — Cline-pattern) decision REQUIRED before SP3 work starts. Decision inputs: SP2 telemetry, user base composition, host runtime availability.

**Last iter under OLD ceremony rules.** Iter 64+ subject to new deterministic classifier (estimated ~70% of future iters skip spec+plan ceremony per audit's recent-iter distribution).

**Audit source:** `docs/superpowers/audits/2026-05-26-iter-63-performance-audit.md`
**Spec source:** `docs/superpowers/specs/2026-05-26-iter-63-performance-sharpness-design.md`
**Plan source:** `docs/superpowers/plans/2026-05-26-iter-63-quick-wins.md`

---
```

- [ ] **Step 10.5: Verify all version refs aligned**

Run: `grep -rn "3\.41\.0" plugins/mega-sdd/README.md README.md plugins/mega-sdd/.claude-plugin/plugin.json CHANGELOG.md 2>/dev/null | grep -v "→ 3\.42\.0\|## \[3\.41\.0\]\|v3\.41\.0 (Iter 62" | head -5`
Expected: empty (no stale refs outside historical entries)

Run: `grep -c "3\.42\.0" plugins/mega-sdd/README.md README.md plugins/mega-sdd/.claude-plugin/plugin.json CHANGELOG.md`
Expected: ≥ 5 (version present in all 4 files)

- [ ] **Step 10.6: Atomic release commit**

```bash
git add CHANGELOG.md README.md plugins/mega-sdd/.claude-plugin/plugin.json plugins/mega-sdd/README.md
git commit -m "$(cat <<'EOF'
release(iter-63): mega-sdd v3.42.0 — Performance + Sharpness SP1 (Quick Wins)

MINOR bump. User direction shift: feature work -> performance + sharpness.
Research-driven (LangChain 3-tier, Claude Code 95% lazy-load, Cline
complexity-gated Plan/Act, Morph context rot empirical).

SP1 ships 6 deliverables in this iter:
  1. FSD auto-invoke opt-out (--with-fsd flag; --no-fsd back-compat no-op)
  2. Skill body trim ~1,500 lines hot-tier relocation (4 heaviest + 5 medium)
  3. /mega-sdd:auto vs /mega-sdd:orchestrate-flow cross-ref clarification
  4. Deterministic iter classifier rules in CLAUDE.md (DOC; runtime Iter 65)
  5. CHANGELOG archive rotation (main 5,663 -> ~1,500 lines)
  6. Anti-recursive guard rule preview in CLAUDE.md (DOC; runtime Iter 65)

Effect on hot context:
  Skill bodies (HOT): 8,174 -> ~6,500 lines (-20%)
  References (SPECIALIST/COLD): ~10,132 -> ~11,132 lines (+1,000 relocation)
  Pure deletion: ~-674 lines (version-stamp prose, mirrored halt descriptions)
  Plugin total: ~18,306 -> ~17,632 lines (~-3.7%; near-flat)

Win is HOT-TIER RELOCATION, not deletion. Iter 66 (SP2) lazy-loading completes.

Roadmap committed in spec:
  SP2 (Iter 64-70, ~1 week edit + 3-4 week soak): 3-tier context + telemetry
    collect (Iter 64) + classifier/guard runtime (Iter 65) + lazy loading
    (Iter 66) + complexity-gated Plan/Act (Iter 67) + telemetry analyze +
    SP3 gate (Iter 68) + budget enforcement (Iter 69) + consolidation (Iter 70)
  SP3 (v4.0.0 candidate): R&D UNCOMMITTED. Explicit Fork A vs B decision required.

Skill bumps:
  orchestrate-flow 3.7.0 -> 3.8.0 (MINOR — FSD flip + body trim)
  generate-intent 1.16.0 -> 1.16.1 (PATCH — trim)
  execute-bolts 2.10.1 -> 2.10.2 (PATCH — trim)
  generate-units 2.7.1 -> 2.7.2 (PATCH — trim)
  5 medium-trim skills PATCH bumps per per-skill commit

Plugin v3.41.0 -> v3.42.0 (MINOR — auto-invoke behavior change, back-compat).

LAST ITER UNDER OLD CEREMONY. Iter 64+ subject to deterministic classifier
in CLAUDE.md (~70% of future iters will skip spec+plan ceremony per
audit-projected distribution).

Spec: docs/superpowers/specs/2026-05-26-iter-63-performance-sharpness-design.md
Audit: docs/superpowers/audits/2026-05-26-iter-63-performance-audit.md
Plan: docs/superpowers/plans/2026-05-26-iter-63-quick-wins.md

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10.7: Push all Iter 63 commits**

```bash
git push origin main
git log --oneline -12
```

Expected: 10 atomic commits from this plan + push success to origin/main.

---

## Self-Review (writing-plans skill checklist)

**1. Spec coverage:**
- §3.1 (FSD opt-out) → Task 1 ✓
- §3.2 (skill trim ~1,500 lines) → Tasks 5, 6, 7, 8, 9 ✓
- §3.3 (command differentiation) → Task 4 ✓
- §3.4 (deterministic classifier with EP1/EP2) → Task 3 (CLAUDE.md classifier section) ✓
- §3.5 (CHANGELOG archive) → Task 2 ✓
- §3.6 (release versioning) → Task 10 ✓
- §7 (anti-recursive guard rule preview) → Task 3 (CLAUDE.md guard section) ✓
- §10 out-of-scope → not implemented (intentional) ✓

**Spec coverage: 100% — every Iter 63 SP1 requirement has a task.**

**2. Placeholder scan:**
- Task 5 Step 5.2 + Step 6.2 + Step 6.3 + Step 8.2 use `[Engineer: copy from SKILL.md ...]` placeholders in NEW reference files — these are INSTRUCTIONS to the engineer about WHAT to copy (not TBD content). The actual content is in the source file; instruction tells engineer where to find it.
- Task 9 uses `<one of: extract-intelligence | ...>` template variable — engineer iterates through 5 skills.
- No "TBD", "TODO", "implement later", "add appropriate handling" patterns.

**Placeholder scan: clean (engineer-instruction placeholders are deliberate).**

**3. Type consistency:**
- Version numbers consistent across tasks (3.41.0 → 3.42.0; orchestrate-flow 3.7.0 → 3.8.0; per-skill PATCH bumps)
- File paths consistent (e.g., `plugins/mega-sdd/skills/<skill>/SKILL.md` pattern uniform)
- Reference file naming consistent (`<topic>.md` under `references/`)
- Halt names consistent (no new halts introduced; preserves existing taxonomy)
- Command flag names consistent (`--with-fsd` vs `--no-fsd` — both documented per back-compat)

**Type consistency: clean.**

**Plan ready for execution.**

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-26-iter-63-quick-wins.md`.

Per Iter 53-55 precedent (literal-paste markdown plans where every file's content is in the plan), **inline execution** per simplifikasi standing directive. Auto mode active.

10 atomic tasks, atomic commits per task, final release commit + push in Task 10.

Proceeding with inline execution.
