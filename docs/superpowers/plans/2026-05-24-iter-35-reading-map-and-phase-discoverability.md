# Iter 35 Reading Map + Phase Discoverability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** Surface phase context in vault + give users a clear "where to read at each pipeline stage" map + fix 1 stale doc line. All in one iter per simplification + flawless directive.

**Architecture:** 1 new user-facing reading-map.md (companion to implementer-facing paths.md). vault.json gains `phase` + `phase_total` fields written by generate-intent (with new `--phase=N` flag); 00-index.md gains §Phase context block. execute-bolts end-of-chain hint + orchestrate-flow chain summary reference Phase N+1 when applicable. Back-compat by construction: missing `phase` field defaults to `phase: 1, phase_total: 1`.

**Tech Stack:** Markdown-driven. Plugin v3.25.0 → v3.26.0.

**Spec:** `docs/superpowers/specs/2026-05-24-iter-35-reading-map-and-phase-discoverability-design.md`

---

## Step-number insertion points (deep-search verified)

| File | Insertion point | Note |
|---|---|---|
| `generate-intent/SKILL.md` line 36-91 (Mode B KB sub-mode) | Add `--phase=N` handling inside Mode B procedure after existing Step 2 (data-mutation-policy.md read) | Mode B is the only mode that uses --phase; greenfield/Mode A defaults to phase=1 |
| `generate-intent/references/vault-contract.md` line 7-49 (§schema) | Extend schema with phase + phase_total fields | Single insertion |
| `00-index.md` write logic in generate-intent | After existing header generation | New §Phase context block |
| `execute-bolts/SKILL.md` chain-completion next_action | Append condition: when vault.phase < vault.phase_total, hint = "Phase N+1 next" | One block addition |
| `orchestrate-flow/SKILL.md` Step 7 (line 306, Emit final summary) | Append optional Phase context section | Inside existing Step 7 body |

---

## File Structure

**New (1):**
- `plugins/mega-sdd/references/reading-map.md` (~120 LOC; user-facing reader's guide)

**Modified:**
- `plugins/mega-sdd/skills/scan-codebase/SKILL.md` (line 37 stale prose fix; bump 2.6.1→2.6.2)
- `plugins/mega-sdd/skills/generate-intent/SKILL.md` (+ `--phase=N` flag in Mode B + write phase to vault.json + write §Phase context to 00-index.md; bump 1.13.0→1.14.0)
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (+ phase + phase_total fields in §schema)
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` (end-of-chain hint for next phase; bump 2.7.0→2.7.1)
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (Step 7 phase context surfacing; bump 3.1.0→3.1.1)
- `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md` (+ reading-map.md cross-ref; bump 1.3.2→1.3.3)
- `tests/skill-triggering/generate-intent.test.md` (+ GI-PH1 + GI-PH2 cases)
- `plugins/mega-sdd/.claude-plugin/plugin.json` (3.25.0 → 3.26.0)
- `CHANGELOG.md` (+ [3.26.0] entry)
- `plugins/mega-sdd/README.md` (+ "What's new in v3.26.0")
- `README.md` (repo root, version bump 3 spots)

---

## Task ordering (4 tasks per simplification, atomic commits per task)

1. **Task 1 — Reading-map + scan-codebase audit fix** (~1.5hr): new file + 1 line fix in single commit
2. **Task 2 — Phase fields (producer)** (~2hr): vault.json schema + generate-intent --phase flag + 00-index.md §Phase context write — atomic
3. **Task 3 — Phase propagation (consumer)** (~1.5hr): execute-bolts hint + orchestrate-flow summary + using-mega-sdd cross-ref — atomic
4. **Task 4 — Tests + release v3.26.0** (~1.5hr): 2 trigger tests + plugin/CHANGELOG/READMEs + push

---

## Task 1: Reading map + scan-codebase audit fix

**Files:**
- Create: `plugins/mega-sdd/references/reading-map.md`
- Modify: `plugins/mega-sdd/skills/scan-codebase/SKILL.md` (line 37 + bump version to 2.6.2)

- [ ] **Step 1.1: Write reading-map.md**

Write `plugins/mega-sdd/references/reading-map.md` using the spec's §2 verbatim content. ~120 LOC covering 7 pipeline stages + Phase 2+ workflow + E2E one-liner + cross-refs to paths.md / knowledge-base-schema.md / vault-contract.md.

Spec source: `docs/superpowers/specs/2026-05-24-iter-35-reading-map-and-phase-discoverability-design.md` §2.

- [ ] **Step 1.2: Fix scan-codebase line 37 + bump version**

Edit `plugins/mega-sdd/skills/scan-codebase/SKILL.md`:

Line 37 (current):
```
`codebase-map.md` written to repo root (or CWD if outside repo). Idempotent — overwrites prior map.
```

Replace with:
```
`codebase-map.md` written to `.mega-sdd/codebase/codebase-map.md` (v3.4+ canonical per `plugins/mega-sdd/references/paths.md`). Override via `--out=<path>` flag. Idempotent — overwrites prior map.
```

Bump frontmatter `version: 2.6.1` → `version: 2.6.2`.

- [ ] **Step 1.3: Verify + commit**

Run:
```bash
test -f plugins/mega-sdd/references/reading-map.md && wc -l plugins/mega-sdd/references/reading-map.md
grep "^## Stage [1-7]" plugins/mega-sdd/references/reading-map.md | wc -l
grep "codebase-map.md.*\.mega-sdd/codebase" plugins/mega-sdd/skills/scan-codebase/SKILL.md | head -2
grep "^version:" plugins/mega-sdd/skills/scan-codebase/SKILL.md
```

Expected: reading-map.md ≥100 lines; 7 stages present; line 37 references .mega-sdd/codebase; scan-codebase version 2.6.2.

Commit:
```bash
git add plugins/mega-sdd/references/reading-map.md plugins/mega-sdd/skills/scan-codebase/SKILL.md
git commit -m "$(cat <<'EOF'
docs(iter-35): reading-map.md + scan-codebase audit closure

NEW: plugins/mega-sdd/references/reading-map.md (user-facing companion
to implementer-facing paths.md). Indexed by 7 pipeline stages + Phase 2+
workflow + E2E one-liner. ⭐ marks primary entry-point per stage.

scan-codebase v2.6.1 → v2.6.2: line 37 stale prose fixed. Output is
.mega-sdd/codebase/codebase-map.md (v3.4+ canonical), not repo root.

Closes UX gap surfaced in field test: user knows where to read at
each stage; closes 1 stale doc bug from deep audit.
EOF
)"
```

---

## Task 2: Phase fields — producer (vault.json schema + generate-intent + 00-index.md)

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (+ phase + phase_total fields)
- Modify: `plugins/mega-sdd/skills/generate-intent/SKILL.md` (+ `--phase=N` flag in Mode B + write fields to vault.json + write §Phase context to 00-index.md; bump 1.13.0→1.14.0)

- [ ] **Step 2.1: Extend vault-contract.md schema**

Edit `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`. Locate `## §schema — vault.json manifest` section (line 7). Add 2 new fields to the existing schema block:

```yaml
phase: <int>          # NEW v1.14.0+ Iter 35 — which phase this vault represents (1, 2, 3, ...). Default 1 if not legacy-rebuild.
phase_total: <int>    # NEW v1.14.0+ Iter 35 — total phases planned (parsed from suggested-phasing.md `## Phase` heading count). Default 1 if not legacy-rebuild.
```

Add field-rule entry below in `### Field rules`:

```markdown
- `phase` + `phase_total`: REQUIRED v1.14.0+. Defaults `phase: 1, phase_total: 1` for back-compat (greenfield + Mode A PRD-driven + single-phase Mode B). Mode B with `--kb` parses `<KB>/99-rebuild-architecture/suggested-phasing.md` for phase count. Missing field on old vault.json (pre-v3.26.0) → treat as `phase: 1, phase_total: 1`.
```

- [ ] **Step 2.2: Add --phase=N flag to generate-intent Mode B**

Edit `plugins/mega-sdd/skills/generate-intent/SKILL.md`. Locate `### Mode B (KB sub-mode) — --kb=<path>` section (line 36+). Add new step after existing Step 2 (data-mutation-policy.md read):

```markdown
2.5. **Parse `--phase=N` flag (v1.14.0+, Iter 35).**

Default: `--phase=1` (when flag absent).

When `--kb` AND `--phase=N`:
a. Read `<KB>/99-rebuild-architecture/suggested-phasing.md`. Count `## Phase` heading occurrences → `phase_total`.
b. Validate `N` ≤ `phase_total`. If out of range → error message: "Phase <N> requested but suggested-phasing.md has only <phase_total> phases. Available: 1..<phase_total>." Halt invocation (no halt-protocol envelope needed — invocation-time validation).
c. Read `## Phase <N>` section content (scope + deliverables + acceptance criteria).
d. Scope vault generation to this phase's deliverables — extract claims from KB filtered by Phase N's scope. Out-of-phase domains may still be cited but not woven into Phase N's vault.
e. Persist: write `phase: N`, `phase_total: <phase_total>` to `vault.json` (Step 11 below — vault.json write).

Defensive fallback: if `suggested-phasing.md` absent OR has zero `## Phase` headers → log "no phasing detected in KB; treating as single-phase (phase: 1, phase_total: 1)" + proceed.

When `--phase` flag absent AND `--kb` set → assume `--phase=1` AND set `phase_total` from suggested-phasing.md (or 1 if absent).
When `--kb` not set (Mode A / Mode B free-text) → always `phase: 1, phase_total: 1`.
```

- [ ] **Step 2.3: Add §Phase context block to 00-index.md generation**

In `generate-intent/SKILL.md`, locate the step where `00-index.md` is written (search for "00-index.md" — appears in template logic). Add instruction:

After the existing 00-index.md header (vault name, generation timestamp, etc.), generate-intent MUST emit a `## Phase context (v3.26+)` block:

```markdown
## Phase context (v3.26+)

**Phase:** <N> of <M>

**This vault covers:** <1-line summary from suggested-phasing.md §Phase N "scope" or "deliverables" — first sentence wins>

<IF phase_total > 1 AND N < phase_total:>
**Upcoming phases:**
- Phase <N+1>: <1-line from suggested-phasing.md §Phase N+1>
- Phase <N+2>: <1-line from suggested-phasing.md §Phase N+2>
- ...

**To start the next phase** (after this phase's bolts complete):

```bash
/mega-sdd:generate-intent --kb=<KB-path> --phase=<N+1>
```

**Full phased plan:** `.mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md`
</IF>

<IF phase_total == 1:>
**Project type:** single-phase (greenfield OR Mode A PRD-driven OR Mode B without legacy-rebuild phasing)
</IF>
```

Note: when `phase_total == 1`, omit upcoming phases + next-phase command (cleaner display for greenfield projects).

- [ ] **Step 2.4: Update generate-intent handoff YAML to include phase**

Locate handoff YAML example in generate-intent SKILL.md. Add fields:

```yaml
phase: 1                     # NEW v1.14.0+, Iter 35
phase_total: 3               # NEW v1.14.0+, Iter 35
```

Inside the existing handoff structure (top-level OR in metadata block per existing convention).

- [ ] **Step 2.5: Bump generate-intent version 1.13.0 → 1.14.0**

Edit frontmatter:
```yaml
version: 1.14.0
```

- [ ] **Step 2.6: Verify + commit**

Run:
```bash
echo "=== vault-contract.md schema has phase + phase_total ==="
grep "phase:\|phase_total:" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | head -5

echo "=== generate-intent Step 2.5 + version 1.14.0 ==="
grep "Step 2.5\|^version:\|--phase=" plugins/mega-sdd/skills/generate-intent/SKILL.md | head -5

echo "=== Phase context block in 00-index.md generation ==="
grep "Phase context\|## Phase context" plugins/mega-sdd/skills/generate-intent/SKILL.md | head -3
```

Expected: schema has both fields; generate-intent has Step 2.5 + version 1.14.0 + --phase= flag; §Phase context referenced.

Commit:
```bash
git add plugins/mega-sdd/skills/generate-intent/references/vault-contract.md \
        plugins/mega-sdd/skills/generate-intent/SKILL.md
git commit -m "$(cat <<'EOF'
feat(iter-35): phase fields (producer) — vault.json schema + --phase flag + 00-index.md §Phase context

vault-contract.md: + phase + phase_total fields in §schema. Back-compat
default phase: 1, phase_total: 1 when fields absent.

generate-intent v1.13.0 → v1.14.0:
- NEW Step 2.5 (Mode B KB sub-mode): parse --phase=N flag, read
  <KB>/99-rebuild-architecture/suggested-phasing.md, validate N ≤
  phase_total, scope vault to Phase N's deliverables
- Defensive: suggested-phasing.md absent OR zero ## Phase headers →
  fallback phase: 1, phase_total: 1 + log
- Persist phase + phase_total to vault.json
- Emit §Phase context block in 00-index.md (Phase N of M + upcoming
  phases + next-phase command — omits upcoming/command when phase_total=1)
- Handoff YAML includes phase + phase_total

Producer side complete; Task 3 propagates to execute-bolts + orchestrate-flow
end-of-chain consumers (atomic per simplification).
EOF
)"
```

---

## Task 3: Phase propagation — consumers (execute-bolts + orchestrate-flow + using-mega-sdd cross-ref)

**Files:**
- Modify: `plugins/mega-sdd/skills/execute-bolts/SKILL.md` (end-of-chain `next_action.hint`; bump 2.7.0→2.7.1)
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (Step 7 summary; bump 3.1.0→3.1.1)
- Modify: `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md` (+ reading-map.md cross-ref; bump 1.3.2→1.3.3)

- [ ] **Step 3.1: Add phase-aware next_action to execute-bolts**

Edit `plugins/mega-sdd/skills/execute-bolts/SKILL.md`. Locate end-of-chain handoff emission (after final bolt completes). Add conditional logic:

```markdown
### End-of-chain phase context (v2.7.1+, Iter 35)

After final bolt completes successfully (status==completed AND blockers==[]), inspect `vault.json` for `phase` + `phase_total` fields:

IF `vault.phase < vault.phase_total`:
  Set handoff `next_action`:
  ```yaml
  next_action:
    type: continue_to_next_phase
    suggested_skill: mega-sdd:generate-intent
    suggested_args: ["--kb=<KB-path-from-vault.json.kb_source>", "--phase=<phase+1>"]
    hint: "Phase <N> complete. Next: Phase <N+1>. Plan: .mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md §Phase <N+1>"
  ```

IF `vault.phase == vault.phase_total` (final phase) OR `phase_total == 1`:
  Set handoff `next_action`:
  ```yaml
  next_action:
    type: chain_complete
    hint: "All phases complete (Phase <N> of <M>). Pipeline finished."
  ```

IF `phase` field absent in vault.json (pre-v3.26.0 vault):
  Default treatment: act as if `phase: 1, phase_total: 1` → chain_complete hint.
```

Bump frontmatter `version: 2.7.0` → `version: 2.7.1`.

- [ ] **Step 3.2: Add phase context to orchestrate-flow Step 7 summary**

Edit `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`. Locate Step 7 "Emit final summary" (line 306). Append to summary content:

```markdown
**Phase context (v3.1.1+, Iter 35):**

If `vault.json` has `phase` field, append to summary:

IF `vault.phase < vault.phase_total`:
  "Phase <N> of <M> complete. To start Phase <N+1>: see `.mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md` §Phase <N+1> OR run `/mega-sdd:generate-intent --kb=<KB> --phase=<N+1>`."

IF `vault.phase == vault.phase_total`:
  "Phase <N> of <M> complete. All phases finished."

IF `phase` field absent (single-phase project OR pre-v3.26.0 vault):
  Omit phase context section.

This complements the execute-bolts handoff `next_action.hint` from Iter 35 — orchestrate-flow surfaces the same info at chain summary level for user visibility.
```

Bump frontmatter `version: 3.1.0` → `version: 3.1.1`.

- [ ] **Step 3.3: Add reading-map cross-ref to using-mega-sdd**

Edit `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md`. Find a suitable location (probably after "The pipeline (canonical)" section or in "See also"). Add:

```markdown
## Reading guide (v1.3.3+, Iter 35)

For users wondering "at this pipeline stage, where do I look?" — see `plugins/mega-sdd/references/reading-map.md`. Indexed by 7 pipeline stages with ⭐ markers for primary entry-points. Companion to implementer-facing `paths.md`.
```

Bump frontmatter `version: 1.3.2` → `version: 1.3.3`.

- [ ] **Step 3.4: Verify + commit**

Run:
```bash
echo "=== execute-bolts phase logic + version 2.7.1 ==="
grep "continue_to_next_phase\|phase context\|^version:" plugins/mega-sdd/skills/execute-bolts/SKILL.md | head -5

echo "=== orchestrate-flow phase context + version 3.1.1 ==="
grep "phase context\|Phase <N>\|^version:" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | head -5

echo "=== using-mega-sdd Reading guide + version 1.3.3 ==="
grep "Reading guide\|reading-map.md\|^version:" plugins/mega-sdd/skills/using-mega-sdd/SKILL.md | head -3
```

Expected: execute-bolts has phase logic + 2.7.1; orchestrate-flow has phase context + 3.1.1; using-mega-sdd has Reading guide + 1.3.3.

Commit:
```bash
git add plugins/mega-sdd/skills/execute-bolts/SKILL.md \
        plugins/mega-sdd/skills/orchestrate-flow/SKILL.md \
        plugins/mega-sdd/skills/using-mega-sdd/SKILL.md
git commit -m "$(cat <<'EOF'
feat(iter-35): phase propagation (consumers) — execute-bolts + orchestrate-flow + reading-map cross-ref

execute-bolts v2.7.0 → v2.7.1: end-of-chain next_action surfaces Phase
N+1 hint when vault.phase < vault.phase_total. Single-phase + final-phase
+ pre-v3.26.0 vault all handled cleanly.

orchestrate-flow v3.1.0 → v3.1.1: Step 7 final summary appends phase
context when vault.json has phase field. Same Phase N+1 surfacing for
user visibility at chain summary level.

using-mega-sdd v1.3.2 → v1.3.3: + Reading guide section pointing to
reading-map.md (Task 1 deliverable). Closes UX loop — anchor skill
surfaces the reading guide for users.

Consumer side complete in same iter as producer (Task 2). Per propagation-
within-iter standing directive: producer + consumer ship atomically.
EOF
)"
```

---

## Task 4: Tests + release v3.26.0 + push

**Files:**
- Modify: `tests/skill-triggering/generate-intent.test.md` (+ 2 cases GI-PH1, GI-PH2)
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json` (3.25.0 → 3.26.0)
- Modify: `CHANGELOG.md` (+ [3.26.0] entry)
- Modify: `plugins/mega-sdd/README.md` (+ "What's new in v3.26.0")
- Modify: `README.md` (repo root, 3.25.0 → 3.26.0 in 3 spots)

- [ ] **Step 4.1: Add GI-PH1 + GI-PH2 to generate-intent.test.md**

Append to `tests/skill-triggering/generate-intent.test.md` under `## Iter 35 — Phase discoverability (v1.14+, v3.26+)`:

```markdown
### GI-PH1 — Default phase=1 (Mode B with --kb, no explicit --phase)

**Setup:**
- `.mega-sdd/knowledge-base/` exists with valid extraction
- `<KB>/99-rebuild-architecture/suggested-phasing.md` has 3 `## Phase` headers (Phase 1, 2, 3)
- No `--phase` flag in invocation

**Trigger:** `/mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/`

**Expected:**
- Step 2.5 parses suggested-phasing.md → phase_total = 3
- Default --phase=1 applies
- vault.json gets `phase: 1, phase_total: 3`
- 00-index.md `## Phase context` block emitted:
  - "Phase 1 of 3"
  - This vault covers: <1-line Phase 1 summary from suggested-phasing.md>
  - Upcoming phases: Phase 2 + Phase 3 (1-liners each)
  - Next-phase command: `/mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/ --phase=2`
  - Full phased plan ref to suggested-phasing.md
- Vault content scoped to Phase 1's deliverables (not all phases mixed)

### GI-PH2 — Explicit --phase=2

**Setup:** Same KB as GI-PH1 (3 phases)

**Trigger:** `/mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/ --phase=2`

**Expected:**
- Step 2.5 reads `## Phase 2` section from suggested-phasing.md
- vault.json gets `phase: 2, phase_total: 3`
- 00-index.md `## Phase context` block:
  - "Phase 2 of 3"
  - Vault scope reflects Phase 2 deliverables
  - Upcoming: Phase 3 only (Phase 1 already done; not listed as upcoming)
  - Next-phase command: `--phase=3`
- Vault content filtered to Phase 2 scope; not mixed with Phase 1 or 3
```

- [ ] **Step 4.2: Bump plugin.json 3.25.0 → 3.26.0**

Edit `plugins/mega-sdd/.claude-plugin/plugin.json`:
```json
"version": "3.26.0",
```

- [ ] **Step 4.3: Add CHANGELOG entry**

Edit `CHANGELOG.md`. Add at TOP (above existing [3.25.0]):

```markdown
## [3.26.0] - 2026-05-24

### Iter 35 — Reading Map + Phase Discoverability (with audit closure)

**Feature iter** (~5-7hr). Per simplification + flawless directive: 3 problems solved in 1 iter; 1 new file; atomic commits per surface sync; no deferrals to Iter 36.

**Skills bumped:**
- `scan-codebase` 2.6.1 → 2.6.2 (line 37 stale prose fix — audit closure)
- `generate-intent` 1.13.0 → 1.14.0 (`--phase=N` flag + vault.json schema extension + 00-index.md §Phase context block)
- `execute-bolts` 2.7.0 → 2.7.1 (end-of-chain next_action references Phase N+1)
- `orchestrate-flow` 3.1.0 → 3.1.1 (chain summary surfaces phase context)
- `using-mega-sdd` 1.3.2 → 1.3.3 (reading-map.md cross-ref)

**New plugin files (1):**
- `plugins/mega-sdd/references/reading-map.md` — user-facing pipeline-stage-to-location guide (companion to implementer-facing paths.md)

**vault.json schema extension:**
- `phase: int` — which phase this vault represents (default 1)
- `phase_total: int` — total phases planned (default 1 if not legacy-rebuild)
- Back-compat: missing fields → treated as `phase: 1, phase_total: 1`

**generate-intent --phase=N flag (Mode B with --kb):**
- Parses `<KB>/99-rebuild-architecture/suggested-phasing.md` for phase plan
- Scopes vault to Phase N's deliverables
- Validates N ≤ phase_total at invocation time
- Defensive fallback when suggested-phasing.md absent or empty

**00-index.md §Phase context block:**
- Surfaces "Phase N of M" at top of vault entrypoint
- Lists upcoming phases with 1-line summaries
- Provides next-phase command verbatim
- Omits upcoming/command sections for single-phase projects (cleaner display)

**Audit closure:**
- `scan-codebase/SKILL.md` line 37 stale prose fixed (claimed "repo root" — actual: `.mega-sdd/codebase/codebase-map.md` per paths.md v3.4+)
- Verified: AGENTS.md at repo root is INTENTIONAL per tool-interop standard (Continue.dev/Cursor/Aider discoverability)
- Verified: all mega-sdd-generated artifacts (vault, binding, units, bolts, memory, KB, codebase, configs) live under `.mega-sdd/` or `~/.mega-sdd/` per paths.md canonical v3.4+

**Trigger test coverage (+2 cases):**
- GI-PH1 — default phase=1 with --kb (auto phase_total from suggested-phasing.md)
- GI-PH2 — explicit --phase=2 (vault scoped to Phase 2 deliverables)

**Standing user directives applied:**
- "simplifikasi + flawless" — 1 new file, 3 problems in 1 iter, atomic commits
- "propagation within iter" — schema + producer + consumer ship together
- "reuse over reinvent" — reading-map.md cross-refs paths.md instead of duplicating layout
- "deep search" — verified insertion points (generate-intent Mode B Step 2.5 insertion) before writing

**Back-compat preserved:**
- Old vaults without `phase` field → default `phase: 1, phase_total: 1`
- Mode A (PRD-driven) + Mode B free-text → always `phase: 1, phase_total: 1` (no legacy-rebuild phasing)
- Single-phase projects → cleaner display (no upcoming-phases noise)

**Plugin:** v3.25.0 → v3.26.0

**Spec:** `docs/superpowers/specs/2026-05-24-iter-35-reading-map-and-phase-discoverability-design.md`
**Plan:** `docs/superpowers/plans/2026-05-24-iter-35-reading-map-and-phase-discoverability.md`
```

- [ ] **Step 4.4: Add README "What's new in v3.26.0"**

Edit `plugins/mega-sdd/README.md`. Add at top of "What's new" section:

```markdown
### v3.26.0 (Iter 35) — Reading Map + Phase Discoverability

mega-sdd now tells you **where to look at each pipeline stage** + **what phase your vault represents**.

**What changed:**

- **NEW: `plugins/mega-sdd/references/reading-map.md`** — user-facing guide indexed by pipeline stage. "After stage X, look at file Y at location Z." ⭐ marks primary entry-point per stage.
- **Phase fields in `vault.json`** — `phase` + `phase_total`. Surfaces at top of `00-index.md §Phase context`: "Phase 1 of 3" + upcoming phases + next-phase command.
- **`generate-intent --phase=N` flag** — bootstrap Phase 2/3+ vaults from the same KB. Mode B with `--kb` parses `<KB>/99-rebuild-architecture/suggested-phasing.md` for the plan.
- **End-of-chain hint** — execute-bolts + orchestrate-flow surface "Phase 1 complete. Phase 2 next: run `/mega-sdd:generate-intent --kb=<KB> --phase=2`" when applicable.

**Why this matters:**

Before: vault only contained Phase 1; user had to know `suggested-phasing.md` existed deep in the KB. Now: vault tells you the phase + how to get to next phase. No more "where's Phase 2?" friction.

**Audit closure:** all mega-sdd-generated files live under `.mega-sdd/` or `~/.mega-sdd/` (verified). AGENTS.md at repo root is INTENTIONAL (tool-interop standard). One stale doc line fixed in scan-codebase.

**Plugin v3.25.0 → v3.26.0.**

See [docs/superpowers/specs/2026-05-24-iter-35-reading-map-and-phase-discoverability-design.md](../../docs/superpowers/specs/2026-05-24-iter-35-reading-map-and-phase-discoverability-design.md) for full design.
```

- [ ] **Step 4.5: Bump repo root README version (3 spots)**

Edit `README.md` (repo root). Replace ALL occurrences of `3.25.0` with `3.26.0`:
- Line ~9: `**Version:** 3.25.0` → `**Version:** 3.26.0`
- Folder layout tree: `# the plugin itself (v3.25.0)` → `# the plugin itself (v3.26.0)`
- Versioning section: `Currently 3.25.0.` → `Currently 3.26.0.`

- [ ] **Step 4.6: Final verification**

Run:
```bash
echo "=== plugin.json ==="
grep '"version"' plugins/mega-sdd/.claude-plugin/plugin.json

echo "=== Skill versions (5 bumped + verify) ==="
for skill in scan-codebase generate-intent execute-bolts orchestrate-flow using-mega-sdd; do
  echo "  $skill: $(grep '^version:' plugins/mega-sdd/skills/$skill/SKILL.md | head -1)"
done

echo "=== reading-map.md present ==="
test -f plugins/mega-sdd/references/reading-map.md && echo "EXISTS ($(wc -l < plugins/mega-sdd/references/reading-map.md) lines)"

echo "=== vault-contract phase fields ==="
grep "phase:\|phase_total:" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | head -3

echo "=== GI-PH trigger tests ==="
grep "^### GI-PH" tests/skill-triggering/generate-intent.test.md

echo "=== CHANGELOG top ==="
head -3 CHANGELOG.md

echo "=== READMEs version refresh ==="
grep "3.26.0\|3.25.0" README.md | head -5
grep "v3.26.0\|v3.25.0" plugins/mega-sdd/README.md | head -3
```

Expected: plugin 3.26.0; all 5 skill versions correct; reading-map.md ≥100 lines; vault-contract has phase fields; 2 GI-PH cases; CHANGELOG [3.26.0]; READMEs at 3.26.0 (no stale 3.25.0 in current-version contexts).

- [ ] **Step 4.7: Commit + push**

```bash
git add tests/skill-triggering/generate-intent.test.md \
        plugins/mega-sdd/.claude-plugin/plugin.json \
        CHANGELOG.md \
        plugins/mega-sdd/README.md \
        README.md
git commit -m "$(cat <<'EOF'
release(iter-35): mega-sdd v3.26.0 — reading map + phase discoverability

Feature iter (~5-7hr). 3 problems solved in 1 iter (simplification + flawless):
1. Reading map: where to read at each pipeline stage (NEW reading-map.md)
2. Phase discoverability: vault.json phase fields + --phase=N flag + 00-index §Phase context
3. Audit closure: 1 stale prose line fix in scan-codebase

5 skill bumps (one per modified skill); plugin v3.25.0 → v3.26.0.

Standing directives applied:
- simplifikasi: 1 new file (reading-map.md), reuses paths.md (no duplication)
- flawless: producer (schema + 00-index) + consumer (execute-bolts hint +
  orchestrate-flow summary) ship atomically per surface sync directive
- propagation within iter: 4 tasks; each task atomic; no deferrals
EOF
)"
git push origin main
```

- [ ] **Step 4.8: Verify final state**

```bash
git log --oneline -7
```

Expected: 5 Iter 35 commits at top (T1 reading-map+audit, T2 phase producer, T3 phase consumer, T4 release), pushed to origin/main.

---

## Self-review

**Spec coverage:** all 11 acceptance criteria distributed across T1-T4. T1 covers reading-map + audit (criteria 2, 3); T2 covers schema + producer (criteria 4, 5); T3 covers consumer + cross-ref (criteria 6, 7, 8); T4 covers tests + release (criteria 1, 9, 11).

**Placeholder scan:** zero TBD/TODO. Every step has concrete content.

**Type consistency:** `phase`/`phase_total` field names consistent across vault-contract + generate-intent + execute-bolts + orchestrate-flow + tests. Version bumps consistent (scan 2.6.2 + intent 1.14.0 + bolts 2.7.1 + orchestrate 3.1.1 + using 1.3.3). Plugin 3.26.0 everywhere.

**Simplification check:** 1 new file. 4 tasks. No deferred items. ✓

**Flawless check:** schema + producer + consumer all in iter 35 (not split across iters); halt-protocol not needed (no new halts; invocation-time validation only); atomic per surface. ✓

---

**End of plan.**

Total tasks: 4
Estimated execution: ~5-7 hours
