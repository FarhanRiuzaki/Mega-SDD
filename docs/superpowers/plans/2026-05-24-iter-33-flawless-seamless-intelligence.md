# Iter 33 Flawless Seamless Intelligence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make mega-sdd orchestrator intelligent (memory-driven routing + predictive halt detection) and handoffs flawless (schema validation gate + type-checked field propagation), while closing the 3 Iter 31 audit closure areas that affect orchestrator+handoff foundation.

**Architecture:** 3-phase combined mega-iter. Phase A (~7-8hr) closes Iter 31 mechanical debt as foundation for Phase C's stricter gate. Phase B (~5-6hr) audits intelligence dimensions on orchestrate-flow + handoff-contract (deep) + each skill (light probe), produces AUDIT-INTELLIGENCE.md informing Phase C specifics. Phase C (~12-15hr) ships 4 intelligence features each producer+consumer in-iter: memory-driven routing (orchestrator learns from past runs), predictive halt detection (warns before invoking failing skill), schema validation gate (validates handoff at emission), type-checked propagation (prevents silent shape drift).

**Tech Stack:** Markdown-driven plugin (no runtime code). YAML for structured context. orchestrate-flow v2.5.1 → v3.0.0 (major bump). Plugin v3.23.0 → v3.24.0.

**Spec source:** `docs/superpowers/specs/2026-05-24-iter-33-flawless-seamless-intelligence-design.md`

---

## ⚠️ Step-number corrections (post-write deep-search audit)

The spec's design sections referenced abstract step numbers (Step 0.7, Step 2.5, Step 4.5, Step 4.5.c.i). Deep search of actual orchestrate-flow SKILL.md structure shows existing steps are: 1 (Parse args) → 2 (CWD inspection) → 2.5 (Starterkit detection) → 3 (Build chain) → 4 (First-run pre-flight) → 5 (Present plan) → 6 (Execute chain) → 7 (Emit final summary) → 8 (Resume support).

Subagents executing Tasks C1, C2, C3, C4 MUST use these CORRECTED step numbers, NOT the spec's abstract numbers:

| Feature | Spec says (abstract) | Actual file insertion (CORRECT) | Rationale |
|---|---|---|---|
| F1 routing preflight (C1) | "Step 0.7" | **Step 2.7** | After existing Step 2.5 (Starterkit detection) and before Step 3 (Build proposed chain) — routing-outcomes informs chain BUILDING |
| F1 routing memory write (C1) | "Step 6" | **Step 7.5** | After existing Step 7 (Emit final summary) — memory write captures chain outcome including duration/halts |
| F2 predictive preflight (C2) | "Step 2.5" | **Step 3.5** | CONFLICTS with existing Step 2.5 (Starterkit detection). New number: Step 3.5 (between Step 3 Build chain + Step 4 First-run pre-flight). Step 4 becomes a special-case predictive check for execute-bolts; Step 3.5 generalizes the concept |
| F3 validation gate (C3) | "Step 4.5" | **Step 6.b** (sub-step of Step 6 Execute chain) | orchestrate-flow has NO Step 4.5. Validation happens INSIDE Step 6 dispatch loop after each sub-skill completes. Structure as Step 6.a dispatch → Step 6.b validate handoff → Step 6.c propagate |
| F4 type-check (C4) | "Step 4.5.c.i" | **Step 6.b.i** | Since F3 became Step 6.b, F4 becomes Step 6.b.i type-check sub-step |

USE these CORRECTED step numbers when inserting. The spec's CONTENT for each sub-step is correct (procedures, halt logic, validation rules) — only the step NUMBER prefix changes.

**Tasks unaffected:** A1, A2, A3, B1, D, E — no step insertions; corrections do not apply.

---

## File Structure

### New files (3)

| Path | Responsibility |
|---|---|
| `plugins/mega-sdd/skills/memory/references/routing-outcomes.md` | Schema doc for orchestrator routing outcomes log (F1). Defines fingerprint format, row format, read/write protocol. |
| `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` | Catalog of preflight checks per skill (F2). 5-6 highest-leverage checks: tree-sitter presence, framework pack presence, binding completeness, etc. |
| `tests/scenarios/scenario-9-flawless-seamless-intelligence.md` | Full-pipeline integration scenario validating F1+F2+F3+F4 end-to-end |

### New audit doc (1)

| Path | Responsibility |
|---|---|
| `docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md` | Phase B output: 6-dimension deep audit + 13-skill scorecard |

### Modified plugin files (13)

| Path | Change summary | Version |
|---|---|---|
| `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` | + Step 2.7 (F1) + Step 3.5 (F2) + Step 6.b/6.b.i (F3+F4) + Step 7.5 (F1 write) + 4 new halt envelopes + handoff metrics | 2.5.1 → **3.0.0** |
| `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` | + 4 missing per-skill sections (Phase A) + REQUIRED/CONDITIONAL/OPTIONAL annotations (F3) + TYPE annotations (F4) + starterkit_context Status halted on updates | — |
| `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` | + 19 halt types to enum (15 Iter 31 + 4 Iter 33) + descriptions + stale name fix in source_skill enum + prose name fixes | — |
| `plugins/mega-sdd/skills/memory/SKILL.md` | + §Memory layer entry for routing-outcomes.md (F1 consumer + producer) | 1.2.1 → 1.3.0 |
| `plugins/mega-sdd/skills/memory/references/memory-schema.md` | + §PROJECT scope: routing-outcomes.md schema definition | — |
| `plugins/mega-sdd/references/paths.md` | + row for `.mega-sdd/memory/routing-outcomes.md` | — |
| `plugins/mega-sdd/skills/bind-codebase/SKILL.md` | + scope:/mutability:/constitution: blocks in handoff YAML template | 1.9.3 → 1.9.4 |
| `plugins/mega-sdd/skills/detect-drift/SKILL.md` | + scope: block in handoff YAML template | 1.4.0 → 1.4.1 |
| `plugins/mega-sdd/skills/diff-vault/SKILL.md` | + scope: block + fix artifact list (VAULT-DIFF.md) | 1.3.0 → 1.3.1 |
| `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` | + scope: + mutability: blocks in handoff YAML | 1.4.0 → 1.4.1 |
| `plugins/mega-sdd/skills/generate-intent/SKILL.md` | + scope: + mutability: blocks in handoff YAML | 1.12.0 → 1.13.0 |
| `plugins/mega-sdd/skills/resolve-oq/SKILL.md` | + scope: + items_blocked + broken cross-ref fix (Task A3) | 0.9.1 → 0.9.2 |
| `plugins/mega-sdd/skills/generate-intent/references/from-prompt-mode.md` | Fix broken cross-refs (Task A3) | — |
| `plugins/mega-sdd/commands/scan-codebase.md` | Fix default output path (Task A3) | — |
| `plugins/mega-sdd/skills/emit-agents-md/SKILL.md` | Fix config path (Task A3) | 1.2.4 → 1.2.5 |

### Modified test/manifest files

| Path | Change summary |
|---|---|
| `tests/skill-triggering/orchestrate-flow.test.md` | + 8 new cases (OF-MR1/2, OF-PH1/2, OF-VG1/2, OF-TC1/2) |
| `tests/skill-triggering/memory.test.md` | + 2 new cases (M-RO1, M-RO2) + path fixes (Task A3) |
| `tests/skill-triggering/scan-codebase.test.md` | + 1 new case (SC-PH1) |
| `tests/skill-triggering/bind-codebase.test.md` | + 1 new case (BC-PH1) |
| `tests/skill-triggering/resolve-oq.test.md` | Path fixes (Task A3) |
| `tests/skill-triggering/emit-agents-md.test.md` | Path fixes (Task A3) |
| `tests/skill-triggering/using-mega-sdd.test.md` | Path fixes (Task A3) |
| `tests/integration/e2e-memory-self-learning.test.md` | Path fixes (Task A3) |
| `plugins/mega-sdd/.claude-plugin/plugin.json` | version 3.23.0 → 3.24.0 |
| `CHANGELOG.md` | + `[3.24.0] - 2026-05-24` Iter 33 entry |
| `plugins/mega-sdd/README.md` | + "What's new in v3.24.0" section |

---

## Task ordering rationale

10 tasks ordered by phase + dependency:

**Phase A (foundation, ~7-8hr):**
1. Task A1: Handoff YAML schema sweep — closes 12 P1s; required by Phase C F3 enforceability
2. Task A2: Halt taxonomy + vault-contract enum sync — closes 13 P1s; synchronized commit pattern from Iter 32 Task 4
3. Task A3: Stale name sweep — removes 102 stale references; required by Phase C F4 type-check enforceability

**Phase B (audit, ~5-6hr):**
4. Task B1: Hybrid intelligence audit — dispatches 2 parallel subagents; produces AUDIT-INTELLIGENCE.md

**Phase C (features, ~12-15hr):**
5. Task C1: F1 Memory-driven routing — independent
6. Task C2: F2 Predictive halt detection — independent
7. Task C3: F3 Schema validation gate — independent (BUT enforcement enabled only because Phase A passed)
8. Task C4: F4 Type-checked field propagation — DEPENDS ON C3 (extends C3 annotations)

**Final (release, ~3-4hr):**
9. Task D: Trigger tests + scenario test
10. Task E: Plugin v3.24.0 release (plugin.json + CHANGELOG + README + push)

---

## Task A1: Handoff YAML schema sweep (Phase A)

**Files:**
- Modify: `plugins/mega-sdd/skills/bind-codebase/SKILL.md` (+ scope/mutability/constitution in handoff YAML)
- Modify: `plugins/mega-sdd/skills/detect-drift/SKILL.md` (+ scope)
- Modify: `plugins/mega-sdd/skills/diff-vault/SKILL.md` (+ scope + fix artifact list)
- Modify: `plugins/mega-sdd/skills/execute-bolts/SKILL.md` (verify scope present)
- Modify: `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` (+ scope + mutability)
- Modify: `plugins/mega-sdd/skills/generate-intent/SKILL.md` (+ scope + mutability)
- Modify: `plugins/mega-sdd/skills/generate-units/SKILL.md` (verify scope present)
- Modify: `plugins/mega-sdd/skills/resolve-oq/SKILL.md` (+ scope + items_blocked metric)
- Modify: `plugins/mega-sdd/skills/scan-codebase/SKILL.md` (verify scope present)
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` (add 4 missing per-skill sections)

- [ ] **Step A1.1: Read each target skill's handoff section + handoff-contract.md schema**

For each of 9 skill SKILL.md files, locate the `## Handoff emission` section (or equivalent) using Read. Locate the existing handoff YAML example. Note current top-level fields present (status, artifacts, next_action, blockers, metrics, etc.).

Read `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` lines 9-118 (Handoff YAML schema section) to confirm the canonical top-level field definitions (scope, mutability, constitution, pbt, cycles, replay, metadata).

- [ ] **Step A1.2: Add scope: block to bind-codebase handoff YAML template**

Edit `plugins/mega-sdd/skills/bind-codebase/SKILL.md` handoff YAML example. Add this block immediately after the `artifacts:` block:

```yaml
scope:                                  # v3.20+ (Iter 28) — when vault has scope_metadata
  id: <scope id, e.g., "BE">
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256 from vault.json>
mutability:                             # v3.17+ (Iter 25) — when claims have mutability tiers
  tier_distribution: { LOCKED: <N>, INTENT: <N>, ARTIFACT: <N> }
  locked_claims_touched: []
  artifact_discards_proposed: <N>
constitution:                           # v3.13+ (Iter 17) — when constitution.md exists
  constitution_hash: <sha256>
  clauses_referenced: []
```

Add a note immediately below the YAML example:
> The `scope:`, `mutability:`, and `constitution:` blocks are CONDITIONAL — emit only when applicable per handoff-contract.md schema (vault has scope_metadata; mutability-tier claims processed; constitution.md exists).

- [ ] **Step A1.3: Add scope: block to detect-drift handoff YAML template**

Edit `plugins/mega-sdd/skills/detect-drift/SKILL.md` handoff YAML example. Add this block immediately after the `artifacts:` block:

```yaml
scope:                                  # v3.20+ (Iter 28) — when vault has scope_metadata
  id: <scope id, e.g., "BE">
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256 from vault.json>
```

- [ ] **Step A1.4: Fix diff-vault handoff YAML template + artifact list**

Edit `plugins/mega-sdd/skills/diff-vault/SKILL.md`. Locate the handoff YAML example. Two changes:

(a) Fix the artifacts list. Replace the existing line that lists "CHANGELOG entry appended" (not a valid file path) with:
```yaml
artifacts:
  - <absolute path to <vault>/VAULT-DIFF.md>            # NEW (was missing — primary output artifact)
  - <absolute path to <vault>/vault.json (updated)>
  - <absolute path to <vault>/00-index.md (updated)>
  - <absolute path to <vault>/.mega-sdd/vault-diffs/<ISO8601>.patch>
```

(b) Add scope: block immediately after artifacts:
```yaml
scope:                                  # v3.20+ (Iter 28) — when vault has scope_metadata
  id: <scope id>
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256 from vault.json>
```

- [ ] **Step A1.5: Verify execute-bolts already has scope: in handoff YAML**

Read `plugins/mega-sdd/skills/execute-bolts/SKILL.md` handoff section. Confirm `scope:` block is present in YAML template (Iter 32 added starterkit_context: but the audit suggested scope: was also added then). If absent, add per A1.2 pattern (scope: only, no need for constitution/mutability for execute-bolts).

- [ ] **Step A1.6: Add scope + mutability blocks to extract-intelligence handoff YAML**

Edit `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` handoff YAML example. Add immediately after artifacts:

```yaml
scope:                                  # v3.20+ (Iter 28) — when target vault will have scope_metadata
  id: <scope id>
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256 from PRD if available>
mutability:                             # v3.17+ (Iter 25) — extract-intelligence is PRIMARY tier producer
  tier_distribution: { LOCKED: <N>, INTENT: <N>, ARTIFACT: <N> }
  locked_claims_touched: []
  artifact_discards_proposed: <N>
```

- [ ] **Step A1.7: Add scope + mutability blocks to generate-intent handoff YAML**

Edit `plugins/mega-sdd/skills/generate-intent/SKILL.md` handoff YAML example. Add immediately after artifacts:

```yaml
scope:                                  # v3.20+ (Iter 28) — when vault has scope_metadata
  id: <scope id>
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256 from PRD>
mutability:                             # v3.17+ (Iter 25) — when --kb mode produces mutability-tagged claims
  tier_distribution: { LOCKED: <N>, INTENT: <N>, ARTIFACT: <N> }
  locked_claims_touched: []
  artifact_discards_proposed: <N>
```

- [ ] **Step A1.8: Verify generate-units handoff YAML has scope: block**

Read `plugins/mega-sdd/skills/generate-units/SKILL.md` handoff section. Confirm `scope:` block is present in YAML template (Iter 32 should have added this). If absent, add per A1.2 pattern.

- [ ] **Step A1.9: Add scope + items_blocked to resolve-oq handoff YAML**

Edit `plugins/mega-sdd/skills/resolve-oq/SKILL.md` handoff YAML example. Two changes:

(a) Add scope: block after artifacts:
```yaml
scope:                                  # v3.20+ (Iter 28) — when vault has scope_metadata
  id: <scope id>
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256 from vault.json>
```

(b) Update existing metrics: block to include items_blocked alongside items_resolved + items_deferred:
```yaml
metrics:
  items_resolved: <N>
  items_deferred: <N>
  items_blocked: <N>                    # NEW v0.9.2+ — canonical handoff metric per handoff-contract.md
```

- [ ] **Step A1.10: Verify scan-codebase handoff YAML has scope: block**

Read `plugins/mega-sdd/skills/scan-codebase/SKILL.md` handoff section. Confirm `scope:` block is present in YAML template alongside the Iter 32 `starterkit_context:` block. If absent, add per A1.2 pattern.

- [ ] **Step A1.11: Add 4 missing per-skill sections to handoff-contract.md**

Edit `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`. Locate `## Per-skill expected emissions` section (line 118). After existing 6 per-skill sections (extract-intelligence, generate-intent, scan-codebase, bind-codebase, generate-units, execute-bolts), append 4 NEW per-skill sections:

```markdown
### `diff-vault`

Canonical handoff YAML:

```yaml
emitted_by: diff-vault
emitted_at: <ISO8601>
status: completed | paused | halted
artifacts:
  - <abs path to <vault>/VAULT-DIFF.md>
  - <abs path to <vault>/vault.json (updated)>
  - <abs path to <vault>/00-index.md (updated)>
  - <abs path to <vault>/.mega-sdd/vault-diffs/<ISO8601>.patch>
scope:                                  # v3.20+ — when vault has scope_metadata
  id: <scope id>
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256>
next_action:
  type: invoke_skill | user_review
  suggested_skill: mega-sdd:bind-codebase | mega-sdd:resolve-oq
  suggested_args: ["--auto"]
blockers: []
metrics:
  decisions_appended: <N>
  conflicts_detected: <N>
```

Status `halted` on: `diff_conflict`

### `emit-agents-md`

Canonical handoff YAML:

```yaml
emitted_by: emit-agents-md
emitted_at: <ISO8601>
status: completed | halted
artifacts:
  - <abs path to <project>/AGENTS.md (created or updated)>
scope:                                  # v3.20+ — when vault has scope_metadata
  id: <scope id>
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256>
next_action:
  type: chain_complete
  hint: "AGENTS.md is the pipeline terminal output for AI agent consumers"
blockers: []
metrics:
  agents_md_lines: <N>
  rules_emitted: <N>
```

Status `halted` on: `user_authored_conflict | vault_not_found | vault_corrupt | greenfield_no_bind_context`

### `resolve-oq`

Canonical handoff YAML:

```yaml
emitted_by: resolve-oq
emitted_at: <ISO8601>
status: completed | paused | halted
artifacts:
  - <abs path to <vault>/01-overview.md (updated)>
  # ... (any vault file that had OQs resolved)
scope:                                  # v3.20+ — when vault has scope_metadata
  id: <scope id>
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256>
next_action:
  type: invoke_skill | user_review
  suggested_skill: mega-sdd:generate-units | mega-sdd:execute-bolts
  suggested_args: ["--auto"]
blockers: []
metrics:
  items_resolved: <N>
  items_deferred: <N>
  items_blocked: <N>
```

Status `halted` on: malformed vault | cycle protection in --binding mode

### `detect-drift`

Canonical handoff YAML:

```yaml
emitted_by: detect-drift
emitted_at: <ISO8601>
status: completed | halted
artifacts:
  - <abs path to <vault>/DRIFT-REPORT.md>
scope:                                  # v3.20+ — when vault has scope_metadata
  id: <scope id>
  name: <scope name>
  sibling_scopes: []
  prd_sha256: <sha256>
next_action:
  type: invoke_skill | user_review
  suggested_skill: mega-sdd:resolve-oq | mega-sdd:emit-agents-md
  suggested_args: ["--auto", "--scope=<id>"]  # propagate scope when detect-drift ran in scope-filtered mode
blockers: []
metrics:
  findings_critical: <N>
  findings_high: <N>
  findings_medium: <N>
  findings_low: <N>
```

Status `halted` on: `drift_framework_mismatch | constitution_drift_detected`
```

- [ ] **Step A1.12: Verify all 9 skill handoff YAMLs + 4 new per-skill sections present**

Run:
```bash
echo "=== Skill handoff YAML scope: presence (expect ≥1 in each YAML template) ==="
for skill in bind-codebase detect-drift diff-vault execute-bolts extract-intelligence generate-intent generate-units resolve-oq scan-codebase; do
  echo "  $skill:"
  grep -A 1 "^emitted_by: $skill" plugins/mega-sdd/skills/$skill/SKILL.md 2>/dev/null | head -3 || echo "    no handoff YAML found"
  has_scope=$(grep -c "^scope:\|^  scope:" plugins/mega-sdd/skills/$skill/SKILL.md)
  echo "    scope occurrences: $has_scope"
done
echo ""
echo "=== handoff-contract.md per-skill sections (expect 10) ==="
grep -c "^### \`" plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
```

Expected: every skill YAML has scope: occurrences ≥1; handoff-contract.md has 10 per-skill sections (6 existing + 4 new).

- [ ] **Step A1.13: Commit Task A1**

Per Iter 32 Task 4 pattern: synchronized changes go in ONE commit so a partial-merge can't leave handoff schemas in inconsistent state.

```bash
git add plugins/mega-sdd/skills/bind-codebase/SKILL.md \
        plugins/mega-sdd/skills/detect-drift/SKILL.md \
        plugins/mega-sdd/skills/diff-vault/SKILL.md \
        plugins/mega-sdd/skills/execute-bolts/SKILL.md \
        plugins/mega-sdd/skills/extract-intelligence/SKILL.md \
        plugins/mega-sdd/skills/generate-intent/SKILL.md \
        plugins/mega-sdd/skills/generate-units/SKILL.md \
        plugins/mega-sdd/skills/resolve-oq/SKILL.md \
        plugins/mega-sdd/skills/scan-codebase/SKILL.md \
        plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
git commit -m "$(cat <<'EOF'
chore(iter-33): Phase A1 — handoff YAML schema sweep

Closes 12 P1 findings from Iter 31 Dim 3 (handoff envelope completeness).

8 skill SKILL.md handoff YAML templates gain missing top-level blocks:
- bind-codebase: + scope/mutability/constitution
- detect-drift: + scope
- diff-vault: + scope; fix artifact list (was missing VAULT-DIFF.md)
- extract-intelligence: + scope/mutability (primary tier producer)
- generate-intent: + scope/mutability
- resolve-oq: + scope + items_blocked metric
- execute-bolts, generate-units, scan-codebase: scope verified present

handoff-contract.md gains 4 missing per-skill sections:
diff-vault, emit-agents-md, resolve-oq, detect-drift.

Enables Phase C F3 schema validation gate to enforce without regression
(previously would have halted on every chain due to missing required blocks).

Skill versions bumped (patch): bind-codebase 1.9.4, detect-drift 1.4.1,
diff-vault 1.3.1, extract-intelligence 1.4.1, generate-intent 1.13.0,
resolve-oq 0.9.2. (Per-skill version bumps in this file; plugin bump in Task E.)
EOF
)"
```

Note: skill version bumps (e.g., bind-codebase 1.9.3 → 1.9.4) are NOT done in this task to keep commit focused on handoff content; version bumps happen in Task E alongside plugin bump.

---

## Task A2: Halt taxonomy + vault-contract enum sync (Phase A)

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (extend halt taxonomy lists)
- Modify: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (extend type enum + add descriptions)
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` (update per-skill Status halted on: lines for halts emitted by each skill)

**15 halt types to register** (Iter 31 audit Dim 4 findings):

```
bind_conflict_constitution_violation, framework_pack_missing, framework_pack_cycle,
framework_pack_unparseable, constitution_drift_detected, drift_framework_mismatch,
diff_conflict, memory_in_use, dispatch_prompt_too_large, bolt_repeated_partial_failure,
provenance_missing, bolt_introduces_locked_drift, self_assessment_missing, dep_missing,
oq_recommend_citation_invalid
```

- [ ] **Step A2.1: Read orchestrate-flow halt taxonomy current state**

Run:
```bash
grep -n "Halt types that ALWAYS STOP\|Halt types that are SOFT\|always stop\|warn-only" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | head -10
```

Note the line ranges for ALWAYS STOP list + SOFT halts subsection (added in Iter 32 Task 4).

- [ ] **Step A2.2: Extend vault-contract.md type enum with 15 new halts**

Edit `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` line 516. The current type enum line already includes the 4 Iter 32 halts. Extend with 15 more (in groups by emitter for readability):

```
type: oq_blocker | diff_conflict | drift_framework_mismatch | bind_conflict | dep_missing | test_fail | cycle_detected | mode_migrate | cross_squad_dep_invalid | interface_ref_missing | cross_squad_ambiguous | cross_squad_interface_draft | deep_scan_subagent_failed | deep_scan_cache_corrupt | deep_scan_subagent_all_failed | starterkit_rule_citation_missing | bind_conflict_constitution_violation | framework_pack_missing | framework_pack_cycle | framework_pack_unparseable | constitution_drift_detected | memory_in_use | dispatch_prompt_too_large | bolt_repeated_partial_failure | provenance_missing | bolt_introduces_locked_drift | self_assessment_missing | oq_recommend_citation_invalid
```

(Note: `diff_conflict`, `drift_framework_mismatch`, `dep_missing` already in enum from Iter 31 audit's own original list — verify these are present; if so, only add the 12 truly new ones.)

- [ ] **Step A2.3: Add 15 halt type descriptions to vault-contract.md**

Below the type enum, locate the halt-type descriptions section (where existing types like `oq_blocker`, `bind_conflict` have descriptions). Append 15 new entries:

```markdown
- `bind_conflict_constitution_violation` — bind-codebase v1.8+, Iter 20: claim conflicts with constitution.md security clause. ALWAYS STOP. Resolution: review constitution clauses + reject/accept conflict.
- `framework_pack_missing` — bind-codebase v1.9+, Iter 23: framework convention pack referenced but file absent. ALWAYS STOP. Resolution: create pack or remove reference.
- `framework_pack_cycle` — bind-codebase v1.9+, Iter 23: pack inheritance has cycle (A extends B extends A). ALWAYS STOP.
- `framework_pack_unparseable` — bind-codebase v1.9+, Iter 23: pack file fails YAML/markdown parse. ALWAYS STOP.
- `constitution_drift_detected` — detect-drift v1.4+, Iter 30: §B Security or §F Compliance constitution clause drift detected in code. ALWAYS STOP.
- `drift_framework_mismatch` — detect-drift v1.2+, Iter 12: scanned code framework differs from vault framework. ALWAYS STOP.
- `diff_conflict` — diff-vault v0.3+, Iter 3: Resolved-OQ or Decision conflict requires stakeholder input. ALWAYS STOP (user resolves via diff-vault interactive walk).
- `memory_in_use` — memory v1.0+: file lock collision; concurrent writer holds lock. ALWAYS STOP (after retry exhausted).
- `dispatch_prompt_too_large` — execute-bolts v2.6+, Iter 30: assembled bolt dispatch prompt exceeds 10KB hard cap. ALWAYS STOP. Resolution: re-tier context.
- `bolt_repeated_partial_failure` — execute-bolts v2.6+, Iter 30: bolt failed 3 partial-state recovery cycles. ALWAYS STOP. Resolution: review unit spec.
- `provenance_missing` — execute-bolts v2.6+, Iter 30: bolt modified file lacks provenance trailer. ALWAYS STOP.
- `bolt_introduces_locked_drift` — execute-bolts v2.6+, Iter 30: bolt drift hits a LOCKED entity. ALWAYS STOP (eligible for propose-and-confirm override).
- `self_assessment_missing` — execute-bolts v2.6+, Iter 30: bolt-report.md lacks self-assessment section. ALWAYS STOP.
- `dep_missing` — scan-codebase v2.0+, Iter 6: required binary (tree-sitter when --engine=tree-sitter forced) not found. ALWAYS STOP.
- `oq_recommend_citation_invalid` — generate-intent v1.3+, Iter 2: OQ recommendation cites non-existent KB section. ALWAYS STOP.
```

- [ ] **Step A2.4: Add 15 ALWAYS-STOP entries to orchestrate-flow halt taxonomy**

Edit `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`. Locate the "Halt types that ALWAYS STOP chain" list (added in Iter 32 Task 4). Append 15 entries:

```markdown
- `bind_conflict_constitution_violation` (v1.8+, Iter 20) — bind-codebase: claim conflicts with constitution security clause.
- `framework_pack_missing` (v1.9+, Iter 23) — bind-codebase: pack referenced but file absent.
- `framework_pack_cycle` (v1.9+, Iter 23) — bind-codebase: pack inheritance has cycle.
- `framework_pack_unparseable` (v1.9+, Iter 23) — bind-codebase: pack file YAML/markdown parse failed.
- `constitution_drift_detected` (v1.4+, Iter 30) — detect-drift: security/compliance clause drift in code.
- `drift_framework_mismatch` (v1.2+, Iter 12) — detect-drift: scanned framework differs from vault.
- `diff_conflict` (v0.3+, Iter 3) — diff-vault: Resolved-OQ/Decision conflict needs stakeholder.
- `memory_in_use` (v1.0+, Iter 5) — memory: concurrent writer holds lock.
- `dispatch_prompt_too_large` (v2.6+, Iter 30) — execute-bolts: bolt prompt > 10KB cap.
- `bolt_repeated_partial_failure` (v2.6+, Iter 30) — execute-bolts: 3 partial-state cycles failed.
- `provenance_missing` (v2.6+, Iter 30) — execute-bolts: modified file lacks provenance trailer.
- `bolt_introduces_locked_drift` (v2.6+, Iter 30) — execute-bolts: bolt drift on LOCKED entity.
- `self_assessment_missing` (v2.6+, Iter 30) — execute-bolts: bolt-report lacks self-assessment.
- `dep_missing` (v2.0+, Iter 6) — scan-codebase: required binary missing.
- `oq_recommend_citation_invalid` (v1.3+, Iter 2) — generate-intent: OQ recommendation cites missing KB section.
```

- [ ] **Step A2.5: Update per-skill Status halted on: lines in handoff-contract.md**

Edit `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`. For each of these per-skill sections, update the `Status halted on:` line:

| Skill section | Update |
|---|---|
| `bind-codebase` | Add `bind_conflict_constitution_violation`, `framework_pack_missing`, `framework_pack_cycle`, `framework_pack_unparseable` |
| `detect-drift` | Add `drift_framework_mismatch`, `constitution_drift_detected` |
| `diff-vault` | Add `diff_conflict` |
| `execute-bolts` | Add `dispatch_prompt_too_large`, `bolt_repeated_partial_failure`, `provenance_missing`, `bolt_introduces_locked_drift`, `self_assessment_missing` |
| `generate-intent` | Add `oq_recommend_citation_invalid` |
| `scan-codebase` | Add `dep_missing` |
| All skills | Add `memory_in_use` (every writer skill can hit this) |

- [ ] **Step A2.6: Verify halt taxonomy sync (all 19 halts across 3 surfaces)**

The 19 halts = 15 new from Phase A2 + 4 from Iter 32. Run:

```bash
echo "=== vault-contract.md type enum (expect all 19) ==="
grep "bind_conflict_constitution_violation\|framework_pack_missing\|framework_pack_cycle\|framework_pack_unparseable\|constitution_drift_detected\|drift_framework_mismatch\|diff_conflict\|memory_in_use\|dispatch_prompt_too_large\|bolt_repeated_partial_failure\|provenance_missing\|bolt_introduces_locked_drift\|self_assessment_missing\|dep_missing\|oq_recommend_citation_invalid\|deep_scan_subagent_failed\|deep_scan_cache_corrupt\|deep_scan_subagent_all_failed\|starterkit_rule_citation_missing" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | wc -l

echo "=== orchestrate-flow ALWAYS-STOP list (expect all 19) ==="
grep -c "(v[0-9]\.[0-9]+, Iter [0-9]+)" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md

echo "=== handoff-contract per-skill Status halted on: lines updated ==="
grep -c "^Status \`halted\`" plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
```

Expected: 19 halt references in vault-contract; ≥19 in orchestrate-flow ALWAYS-STOP list; 10 per-skill Status halted on: lines (one per per-skill section).

- [ ] **Step A2.7: Commit Task A2 (single commit, synchronized 3-surface update)**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/SKILL.md \
        plugins/mega-sdd/skills/generate-intent/references/vault-contract.md \
        plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
git commit -m "$(cat <<'EOF'
chore(iter-33): Phase A2 — halt taxonomy + vault-contract enum sync

Closes 13 P1 findings from Iter 31 Dim 4 (halt taxonomy consistency).

15 previously-unregistered halt types added across 3 surfaces (per
audit-pattern-prevention checklist; synchronized commit pattern from
Iter 32 Task 4):

bind-codebase: bind_conflict_constitution_violation,
                framework_pack_missing, framework_pack_cycle,
                framework_pack_unparseable
detect-drift: constitution_drift_detected, drift_framework_mismatch
diff-vault:   diff_conflict
memory:       memory_in_use
execute-bolts: dispatch_prompt_too_large, bolt_repeated_partial_failure,
                provenance_missing, bolt_introduces_locked_drift,
                self_assessment_missing
scan-codebase: dep_missing
generate-intent: oq_recommend_citation_invalid

All 15 + 4 Iter 32 halts = 19 total now synchronized across:
- orchestrate-flow SKILL.md ALWAYS-STOP list
- vault-contract.md §halt-protocol type enum + descriptions
- handoff-contract.md per-skill Status halted on: lines

Closes iter-31 root cause pattern: 'halt declared in skill body
prose but missing from taxonomy surfaces'.
EOF
)"
```

---

## Task A3: Stale name + path sweep (Phase A)

**Files (~8 files modified):**
- Modify: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (source_skill enum + prose + when-skills-must-regenerate)
- Modify: `plugins/mega-sdd/skills/generate-intent/references/from-prompt-mode.md` (broken cross-refs)
- Modify: `plugins/mega-sdd/skills/resolve-oq/SKILL.md` (line 551 broken cross-ref)
- Modify: 6 test files (`.mega-sdd-memory/` → `.mega-sdd/memory/`)
- Modify: `plugins/mega-sdd/commands/scan-codebase.md` (default output path)
- Modify: `plugins/mega-sdd/skills/emit-agents-md/SKILL.md` (config path)

Stale references to fix (102 total per deep-search count):
- `grand-design-spec` (52 occurrences) → `mega-sdd` for plugin/skill mentions; `generate-intent` for specific skill refs
- `vault-diff` (26 occurrences) → `diff-vault`
- `drift-detect` (14 occurrences) → `detect-drift`
- `.mega-sdd-memory/` (10 occurrences in tests) → `.mega-sdd/memory/`

- [ ] **Step A3.1: Survey current stale name occurrences (baseline)**

Run:
```bash
echo "=== grand-design-spec occurrences (per file) ==="
grep -rnl "grand-design-spec" plugins/mega-sdd/ docs/ tests/ 2>/dev/null | head -20
echo "=== vault-diff occurrences (per file) ==="
grep -rnl "vault-diff" plugins/mega-sdd/ docs/ tests/ 2>/dev/null | head -20
echo "=== drift-detect occurrences (per file) ==="
grep -rnl "drift-detect" plugins/mega-sdd/ docs/ tests/ 2>/dev/null | head -20
echo "=== .mega-sdd-memory/ occurrences ==="
grep -rnl ".mega-sdd-memory" plugins/mega-sdd/ tests/ 2>/dev/null | head -20
```

Record the file list. This is your replacement target list.

- [ ] **Step A3.2: Fix vault-contract.md source_skill enum + descriptions**

Edit `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`:

(a) Line 523 source_skill enum:
```
source_skill: generate-intent | diff-vault | detect-drift | bind-codebase | scan-codebase | generate-units | execute-bolts | extract-intelligence | resolve-oq | orchestrate-flow | emit-agents-md | memory
```
(Replace stale names with canonical; expand enum to include all 12 skills that emit handoffs/halts.)

(b) Lines 558 + 561 + 566 in halt-protocol examples: replace `source_skill: grand-design-spec` → `source_skill: generate-intent`; `source_skill: vault-diff` → `source_skill: diff-vault`.

(c) Line 3 + 508 + 519 (prose mentions): replace `grand-design-spec` → `mega-sdd`.

(d) §when-skills-must-regenerate lines 60/62/63: replace stale skill name mentions with canonical.

- [ ] **Step A3.3: Fix from-prompt-mode.md broken cross-references**

Edit `plugins/mega-sdd/skills/generate-intent/references/from-prompt-mode.md`. Replace:
- Lines 11, 257, 291: `../grand-design-spec/references/vault-contract.md` → `./vault-contract.md`
- Line 293: `../flow/SKILL.md` → `../../orchestrate-flow/SKILL.md`
- Lines 19, 24, 201, 270 (prose mentions): `grand-design-spec` → `generate-intent`; `flow` → `orchestrate-flow`

- [ ] **Step A3.4: Fix resolve-oq/SKILL.md broken cross-reference**

Edit `plugins/mega-sdd/skills/resolve-oq/SKILL.md` line 551. Replace:
```
../grand-design-spec/references/vault-contract.md
```
with:
```
../generate-intent/references/vault-contract.md
```

- [ ] **Step A3.5: Fix 6 test files: .mega-sdd-memory/ → .mega-sdd/memory/**

For each of these 6 test files, replace ALL occurrences of `.mega-sdd-memory/` with `.mega-sdd/memory/`:
- `tests/skill-triggering/memory.test.md` (lines 13, 37, 72)
- `tests/integration/e2e-memory-self-learning.test.md` (lines 28, 29, 30, 117, 128)
- `tests/skill-triggering/resolve-oq.test.md` (lines 83, 106)
- `tests/skill-triggering/emit-agents-md.test.md` (line 8 vault path + others)
- `tests/skill-triggering/using-mega-sdd.test.md` (line 16)
- `tests/skill-triggering/scan-codebase.test.md` (already updated in Iter 32 — verify clean)

Use Edit with `replace_all: true` per file for safety on the `.mega-sdd-memory/` → `.mega-sdd/memory/` substitution.

- [ ] **Step A3.6: Fix commands/scan-codebase.md default output path**

Edit `plugins/mega-sdd/commands/scan-codebase.md` line 14. Replace:
```
Output to `<repo-root>/codebase-map.md` by default.
```
with:
```
Output to `.mega-sdd/codebase/codebase-map.md` by default (v2.2+).
```

- [ ] **Step A3.7: Fix emit-agents-md/SKILL.md config path**

Edit `plugins/mega-sdd/skills/emit-agents-md/SKILL.md` line 20. Replace:
```
`<project>/.mega-sdd/memory/config.yaml`
```
with:
```
`<project>/.mega-sdd/config.yaml`
```

Also update `plugins/mega-sdd/commands/emit-agents-md.md` line 17 to match:
```
`<project>/.mega-sdd/config.yaml`
```

- [ ] **Step A3.8: Verify stale name sweep complete**

Run:
```bash
echo "=== grand-design-spec remaining (expect 0 in plugin source; OK in docs/ historical) ==="
grep -rn "grand-design-spec" plugins/mega-sdd/ 2>/dev/null | wc -l

echo "=== vault-diff remaining (expect 0 in plugin source) ==="
grep -rn "vault-diff" plugins/mega-sdd/ 2>/dev/null | wc -l

echo "=== drift-detect remaining (expect 0 in plugin source) ==="
grep -rn "drift-detect" plugins/mega-sdd/ 2>/dev/null | wc -l

echo "=== .mega-sdd-memory/ remaining (expect 0 in tests/) ==="
grep -rn ".mega-sdd-memory" tests/ 2>/dev/null | wc -l
```

Expected: all 4 counts = 0 in plugin source + tests. (Historical references in docs/superpowers/audits/* and docs/superpowers/specs/* are acceptable — those are immutable historical records.)

- [ ] **Step A3.9: Commit Task A3**

```bash
git add plugins/mega-sdd/skills/generate-intent/references/vault-contract.md \
        plugins/mega-sdd/skills/generate-intent/references/from-prompt-mode.md \
        plugins/mega-sdd/skills/resolve-oq/SKILL.md \
        plugins/mega-sdd/skills/emit-agents-md/SKILL.md \
        plugins/mega-sdd/commands/scan-codebase.md \
        plugins/mega-sdd/commands/emit-agents-md.md \
        tests/skill-triggering/memory.test.md \
        tests/integration/e2e-memory-self-learning.test.md \
        tests/skill-triggering/resolve-oq.test.md \
        tests/skill-triggering/emit-agents-md.test.md \
        tests/skill-triggering/using-mega-sdd.test.md
git commit -m "$(cat <<'EOF'
chore(iter-33): Phase A3 — stale name + path sweep

Closes Pattern 2 (stale skill names) + Pattern 4 (stale legacy paths)
from Iter 31 cross-skill analysis. 102 stale references replaced with
canonical names.

vault-contract.md source_skill enum: grand-design-spec → generate-intent;
   vault-diff → diff-vault; drift-detect → detect-drift. Enum expanded
   to all 12 skills that emit handoffs/halts.

from-prompt-mode.md: ../grand-design-spec/ → ./ ; ../flow/ → ../../orchestrate-flow/.

resolve-oq/SKILL.md line 551 broken cross-ref fixed (same bug Iter 26
closed for detect-drift + diff-vault but missed for resolve-oq).

6 test files: .mega-sdd-memory/ → .mega-sdd/memory/ (Iter 25 path
migration sweep missed test fixtures).

commands/scan-codebase.md + emit-agents-md.md: legacy paths → canonical
v3.4+ paths.

Required prerequisite for Phase C F4 type-check enforceability: stale
names in source_skill enum would otherwise be enforced as valid by
validation gate.
EOF
)"
```

---

## Task B1: Hybrid intelligence audit (Phase B)

**Files:**
- Create: `docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md`

- [ ] **Step B1.1: Verify Phase A complete (audit baseline cleanliness)**

Phase B intelligence audit requires a clean baseline (Phase A complete). Run:
```bash
echo "=== Phase A completion check ==="
echo "A1 commit (handoff sweep):"
git log --oneline | grep "Phase A1" | head -1
echo "A2 commit (halt sync):"
git log --oneline | grep "Phase A2" | head -1
echo "A3 commit (stale name sweep):"
git log --oneline | grep "Phase A3" | head -1
```

Expected: all 3 commits visible. If any missing → return to that task and complete before proceeding.

- [ ] **Step B1.2: Dispatch 2 parallel audit subagents**

Per `superpowers:subagent-driven-development` parallel-safe convention: send ALL 2 Agent tool calls in ONE message.

**Subagent 1 (deep audit): model=sonnet**

Prompt:
```
ROLE: Forensic intelligence auditor for mega-sdd orchestrator + handoff contract.

CONTEXT:
- Plugin v3.24.0-pre (Phase A complete; clean baseline)
- Working dir: /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec
- This is a READ-ONLY audit. Do NOT edit any files. Return findings.

DEEP AUDIT TARGETS:
- plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
- plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
- plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md
- plugins/mega-sdd/skills/orchestrate-flow/references/checkpoint-protocol.md
- plugins/mega-sdd/skills/memory/references/memory-schema.md
- plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
- plugins/mega-sdd/references/shared-snapshot-schema.md
- plugins/mega-sdd/references/starterkit-context-schema.md (Iter 32 reuse pattern)

6 INTELLIGENCE DIMENSIONS — evaluate each as STRONG / WEAK / ABSENT with evidence:

D1: Smart-routing readiness — does orchestrator consult memory before routing decisions?
D2: Handoff schema completeness — does handoff-contract cover every field that propagates?
D3: Predictive-halt potential — does orchestrator preflight-check halt preconditions?
D4: Memory utilization — does orchestrator USE memory slices to inform routing/recovery?
D5: Confidence-score consumption — does orchestrator adjust behavior based on confidence scores?
D6: Halt-recovery clarity — when surfacing halt to user, is next_action.hint ACTIONABLE?

For each dimension: verdict + evidence (file:line cited) + suggested intelligence pattern (1-line).

OUTPUT FORMAT (YAML block in your response):

```yaml
deep_audit:
  audited_at: <ISO8601>
  files_read: [...]
  findings:
    - dimension: D1
      verdict: STRONG | WEAK | ABSENT
      evidence: <verbatim quote or summary with file:line>
      suggested_pattern: <1-line intelligence pattern to address>
    - dimension: D2
      [...]
    - dimension: D3
      [...]
    - dimension: D4
      [...]
    - dimension: D5
      [...]
    - dimension: D6
      [...]
  cross_cutting_observations: [<list of patterns spanning multiple dimensions>]
```
```

**Subagent 2 (per-skill probe): model=sonnet**

Prompt:
```
ROLE: Per-skill intelligence prober.

CONTEXT:
- Plugin v3.24.0-pre
- Working dir: /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/grand-design-spec
- READ-ONLY audit. Return findings as YAML.

TARGETS — all 13 skills (read each SKILL.md briefly):
bind-codebase, detect-drift, diff-vault, emit-agents-md, execute-bolts,
extract-intelligence, generate-intent, generate-units, memory, orchestrate-flow,
resolve-oq, scan-codebase, using-mega-sdd

ONE QUESTION PER SKILL:
"Does <skill> CONSUME memory/confidence/scope-context to inform its decisions,
or just read/write mechanically?"

SCORE EACH 0-3:
- 0: mechanical only; no context-driven adaptation
- 1: reads context but doesn't significantly alter behavior
- 2: reads context AND adjusts ≥1 decision based on it
- 3: context-driven throughout; multiple decisions adapt

OUTPUT FORMAT (YAML block):

```yaml
per_skill_probe:
  audited_at: <ISO8601>
  scorecard:
    - skill: bind-codebase
      score: <0-3>
      justification: <1 sentence>
      suggested_upgrade: <1 line>
    - skill: detect-drift
      [...]
    [... all 13 skills]
  pattern_observations: [<patterns across skills, e.g., "10/13 skills score 0-1 on memory utilization">]
```
```

- [ ] **Step B1.3: Collect 2 YAML outputs from subagents**

Both subagents return YAML. Hold both in working memory for consolidation in next step.

If either subagent returns BLOCKED/NEEDS_CONTEXT:
- Re-dispatch with additional context
- If still failing → escalate to user

- [ ] **Step B1.4: Write consolidated AUDIT-INTELLIGENCE.md**

Write `docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md`:

```markdown
# Intelligence Audit Report — mega-sdd v3.24.0 (Iter 33, Phase B)

**Date:** 2026-05-24
**Method:** 2 parallel subagents (deep audit + per-skill probe)
**Plugin version:** v3.24.0-pre (Phase A baseline complete)
**Constraint:** Read-only; AUDIT-INTELLIGENCE.md sole write target
**Cross-ref:** Iter 31 correctness audit at `docs/superpowers/audits/2026-05-24-iter-31-v3.22.0-full-pipeline-audit.md`

---

## Summary

[3-5 sentences: overall verdict on orchestrator intelligence + handoff solidity + top 3 themes from findings]

---

## Deep audit findings — 6 intelligence dimensions

### D1: Smart-routing readiness
[Verdict + evidence + suggested intelligence pattern from subagent 1]

### D2: Handoff schema completeness
[...]

### D3: Predictive-halt potential
[...]

### D4: Memory utilization
[...]

### D5: Confidence-score consumption
[...]

### D6: Halt-recovery clarity
[...]

---

## Per-skill intelligence scorecard

| Skill | Score (0-3) | Justification | Suggested upgrade |
|---|---|---|---|
| bind-codebase | <N> | <justification> | <upgrade> |
| ... | ... | ... | ... |

[All 13 rows from subagent 2]

---

## Cross-cutting patterns

[Patterns spanning ≥3 skills, e.g.:
- 10/13 skills score 0-1 on memory utilization — memory is write-only sink
- All 13 skills lack confidence-driven branching despite emitting confidence scores
- ...]

---

## Recommended Phase C feature design inputs

How Phase B findings inform Phase C feature specs:

- **F1 Memory-driven routing** ← D1 + D4 findings inform fingerprint format + which patterns to detect
- **F2 Predictive halt detection** ← D3 + D6 findings inform which checks to catalog first
- **F3 Schema validation gate** ← D2 findings confirm validation is needed
- **F4 Type-checked propagation** ← D2 findings inform which fields need TYPE annotations first

---

## Iter 34+ candidates (gaps NOT covered by Iter 33 Phase C)

[Findings that don't map to F1-F4 — recorded for future iter planning]

---

## Methodology notes

- Audit method: 2 parallel sonnet subagents (deep + per-skill probe)
- Output sources: subagent 1 YAML + subagent 2 YAML, consolidated manually
- Files read total: <N> (sum across both subagents)
- Time elapsed (wall-clock): <N>min
```

Embed the actual findings from subagent YAML outputs in the bracketed placeholder sections.

- [ ] **Step B1.5: Verify AUDIT-INTELLIGENCE.md written**

Run:
```bash
test -f docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md && wc -l docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md
grep -c "^### D[1-6]:" docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md
grep -c "^| " docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md
```

Expected: file ≥150 lines; 6 D-section headers present; ≥13 scorecard rows.

- [ ] **Step B1.6: Commit Task B1**

```bash
git add docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md
git commit -m "$(cat <<'EOF'
docs(iter-33): Phase B — intelligence audit report

Hybrid audit method: 2 parallel sonnet subagents.

Deep audit covers 6 intelligence dimensions on orchestrate-flow +
handoff-contract.md:
D1 Smart-routing readiness | D2 Handoff schema completeness |
D3 Predictive-halt potential | D4 Memory utilization |
D5 Confidence-score consumption | D6 Halt-recovery clarity

Per-skill probe scores all 13 skills on 0-3 context-utilization scale.

Findings inform Phase C feature design (F1 memory-driven routing,
F2 predictive halt detection, F3 schema validation gate, F4 type-checked
propagation).

Phase C tasks (C1-C4) consume this audit's "suggested intelligence
patterns" + "cross-cutting observations" sections for implementation
specifics. Findings beyond Iter 33's 4 features documented as Iter 34+
candidates.
EOF
)"
```

---

## Task C1: F1 Memory-driven routing (Phase C, independent)

**Files:**
- Create: `plugins/mega-sdd/skills/memory/references/routing-outcomes.md`
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (+ Step 2.7 + Step 7.5)
- Modify: `plugins/mega-sdd/skills/memory/SKILL.md` (+ §Memory layer routing-outcomes entry)
- Modify: `plugins/mega-sdd/skills/memory/references/memory-schema.md` (+ §PROJECT scope schema for routing-outcomes.md)
- Modify: `plugins/mega-sdd/references/paths.md` (+ row)

**Reuse-first directive (memory):** before writing, inspect existing patterns:
- `plugins/mega-sdd/references/shared-snapshot-schema.md` (Iter 30 lock-hash cache pattern — analog for fingerprint cache)
- `plugins/mega-sdd/skills/memory/references/memory-schema.md` (existing §PROJECT scope entries: decisions.md, conventions.md, outcomes.md — match style)
- `plugins/mega-sdd/skills/memory/SKILL.md` §Memory layer §file-lock pattern (REUSE for routing-outcomes append concurrency)

- [ ] **Step C1.1: Write routing-outcomes.md schema doc**

Write `plugins/mega-sdd/skills/memory/references/routing-outcomes.md`:

```markdown
# Routing Outcomes Schema

> Schema for `<project>/.mega-sdd/memory/routing-outcomes.md` — orchestrator routing decisions log.

**Version:** 1.0
**Introduced:** v3.24.0 (Iter 33)
**Produced by:** `mega-sdd:orchestrate-flow` v3.0.0+ Step 7.5 end-of-chain memory write
**Consumed by:** `mega-sdd:orchestrate-flow` v3.0.0+ Step 2.7 routing preflight

---

## Purpose

Append-only log of orchestrator routing decisions + outcomes. Orchestrator consults this log at routing time to override default routing-rules.md when prior runs show a consistent successful chain for the same project fingerprint.

---

## File format

Markdown with a single table-style append-only entries section.

```markdown
# Routing Outcomes

## Schema

Per row: `<date> | <project-fingerprint> | <chain-used> | <duration-min> | <converged> | <halts-fired>`

- date: ISO8601 date (YYYY-MM-DD)
- project-fingerprint: sha256(composer.json + package.json + framework_pack_path)[:16]
- chain-used: short label, e.g., "starterkit-first (scan→intent→bind→units→bolts)"
- duration-min: integer (wall-clock minutes for full chain)
- converged: yes | no
- halts-fired: int (count of halts in this chain) OR "0" if clean

## Entries

2026-05-24 | abc1234567890abc | starterkit-first | 12 | yes | 0
2026-05-25 | abc1234567890abc | starterkit-first | 8 | yes | 0
```

## Project fingerprint computation

```
fingerprint = sha256(
  read(composer.json) || "" +
  read(package.json) || "" +
  framework_pack_path || ""
)[:16]
```

Stable fingerprint = same manifests + same framework pack = same project shape.

Fingerprint INVALIDATES when:
- composer.json changes (added/removed deps)
- package.json changes
- framework_pack_path changes (starterkit pack swapped)

## Read protocol (Step 2.7)

```
1. Read .mega-sdd/memory/routing-outcomes.md (if exists; else fall through to default routing)
2. Compute current project fingerprint
3. Filter rows matching current fingerprint
4. Apply decision rules:
   a. If ≥3 prior rows with converged=yes AND same chain-used:
      → recommend that chain as default (override routing-rules.md)
      → log to orchestrator output: "Routing recommendation from past N runs (all converged)"
   b. If ≥2 prior rows with converged=no AND same chain-used:
      → warn user: "Past N runs with this chain failed; suggest alternate chain"
      → fall through to routing-rules.md default; user decides
   c. If mixed results OR <3 prior rows OR no rows match:
      → fall through to routing-rules.md default (no override)
```

## Write protocol (Step 7.5)

```
1. After chain completes (Step 7 emit final summary), compute:
   - chain-used: short label of executed chain
   - duration-min: integer
   - converged: yes if status==completed AND blockers==[]; no otherwise
   - halts-fired: count of unique halt types fired during chain
2. Acquire file lock on routing-outcomes.md (reuse memory file-lock pattern; backoff retry 3x)
3. Append new row to ## Entries section
4. Release lock
5. On lock collision after 3 retries → halt memory_in_use (existing halt; no new halt type needed)
6. On YAML/markdown parse error of existing file → emit routing_outcome_corrupt (SOFT halt; auto-invalidate file by renaming to .corrupt; next run starts fresh log)
```

## Anti-halu rails

1. NEVER append a row if chain did not actually execute (no speculative writes)
2. Fingerprint MUST be computed at chain START, not end (so re-routing decisions can use stable fingerprint)
3. `halts-fired` count MUST match actual halts in chain handoffs — not estimated
4. `chain-used` MUST be the ACTUAL skill sequence dispatched, not the proposed one

## See also

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` §Step 2.7 (consumer) + §Step 7.5 (producer)
- `plugins/mega-sdd/references/paths.md` (canonical path)
- `plugins/mega-sdd/skills/memory/SKILL.md` §Memory layer §file-lock (reused pattern)
```

- [ ] **Step C1.2: Bump orchestrate-flow version 2.5.1 → 3.0.0**

Edit `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` frontmatter:

```yaml
---
name: orchestrate-flow
version: 3.0.0
description: ... (existing description text)
---
```

- [ ] **Step C1.3: Add Step 2.7 (memory-informed routing preflight)**

Edit `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`. Locate existing Step 2.5 (Starterkit detection + mode classification) at line ~41. Insert NEW Step 2.7 AFTER Step 2.5 and BEFORE Step 3 (Build proposed chain) at line ~77:

```markdown
2.7. **Memory-informed routing preflight (v3.0.0+, Iter 33).**

Per `references/memory/routing-outcomes.md` schema. Optional — falls through silently if memory file absent or insufficient history.

a. Compute project fingerprint: `sha256(composer.json + package.json + framework_pack_path)[:16]`

b. Read `<project>/.mega-sdd/memory/routing-outcomes.md` (if exists; else skip to step 3).

c. Filter rows matching current fingerprint.

d. Apply decision rules:
   - **≥3 prior rows, converged=yes, same chain-used:** recommend that chain as default; LOG to user: "Routing recommendation from past N runs (all converged in avg X min)"
   - **≥2 prior rows, converged=no, same chain-used:** WARN user: "Past N runs of this chain failed (halts: <list>); consider alternate chain"; fall through to routing-rules.md default (user decides)
   - **Mixed results OR <3 prior rows:** fall through to routing-rules.md default (no override)

e. If file parse fails: emit SOFT halt `routing_outcome_corrupt` + auto-invalidate (rename to `.corrupt-<ISO8601>`); fall through to default; LOG to user: "routing-outcomes.md corrupt; auto-invalidated; chain proceeds with default routing"

f. Update chain proposal with recommendation OR fall-through default. Continue to Step 3.
```

- [ ] **Step C1.4: Add Step 7.5 (end-of-chain memory write)**

Edit `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`. Locate existing Step 7 (Emit final summary) at line ~133. Insert NEW Step 7.5 AFTER Step 7 and BEFORE Step 8 (Resume support):

```markdown
7.5. **End-of-chain routing-outcomes memory write (v3.0.0+, Iter 33).**

Per `references/memory/routing-outcomes.md` write protocol.

a. Compute:
   - `chain-used`: short label, e.g., "starterkit-first (scan→intent→bind→units→bolts)"
   - `duration-min`: integer wall-clock from Step 1 → now
   - `converged`: yes if final status==completed AND blockers==[]; no otherwise
   - `halts-fired`: count of unique halt types fired during chain

b. Acquire file lock on `<project>/.mega-sdd/memory/routing-outcomes.md` (reuse existing memory file-lock pattern: backoff + retry 3x; fail with `memory_in_use` if all retries fail).

c. If file does not exist: create with header per schema doc.

d. Append row to `## Entries` section via Bash `>>` heredoc (per memory-schema.md §6 POSIX append requirement).

e. Release lock.

f. LOG to user: "routing-outcomes.md updated (entry: <chain-used> | <duration-min>min | converged=<yes/no>)"

NOTE: Skip Step 7.5 entirely if `--memory-off` flag set (existing flag respects opt-out).
```

- [ ] **Step C1.5: Add routing-outcomes.md entry to memory SKILL.md §Memory layer**

Edit `plugins/mega-sdd/skills/memory/SKILL.md`. Locate `## Memory layer` section. Find the existing PROJECT scope table/list. Add a new entry:

```markdown
### routing-outcomes.md (v1.3.0+, Iter 33)

**Scope:** PROJECT (`<project>/.mega-sdd/memory/routing-outcomes.md`)
**Producer:** `mega-sdd:orchestrate-flow` v3.0.0+ Step 7.5
**Consumer:** `mega-sdd:orchestrate-flow` v3.0.0+ Step 2.7
**Format:** Markdown with append-only Entries section
**Schema:** see `references/routing-outcomes.md`
**Append mechanism:** Bash `>>` heredoc (per §6 POSIX append)
**Lock:** standard memory file-lock pattern (backoff + retry 3x; fail with `memory_in_use`)
**Soft halt:** `routing_outcome_corrupt` on parse failure (auto-invalidate; chain proceeds)
```

- [ ] **Step C1.6: Bump memory SKILL.md version 1.2.1 → 1.3.0**

Edit `plugins/mega-sdd/skills/memory/SKILL.md` frontmatter:

```yaml
version: 1.3.0
```

- [ ] **Step C1.7: Add routing-outcomes.md schema entry to memory-schema.md**

Edit `plugins/mega-sdd/skills/memory/references/memory-schema.md`. Locate `### PROJECT scope` section (line ~42). After the existing entries (decisions.md, conventions.md, outcomes.md), add:

```markdown
### `<project>/.mega-sdd/memory/routing-outcomes.md` (v1.3.0+, Iter 33)

```markdown
# Routing Outcomes

## Schema

Per row: `<date> | <project-fingerprint> | <chain-used> | <duration-min> | <converged> | <halts-fired>`

## Entries

<append-only rows>
```

Schema fully defined at `plugins/mega-sdd/skills/memory/references/routing-outcomes.md`.
```

- [ ] **Step C1.8: Add path entry to paths.md**

Edit `plugins/mega-sdd/references/paths.md`. Locate the per-skill path mapping table. Add a row:

```markdown
| `orchestrate-flow` | routing-outcomes | `.mega-sdd/memory/routing-outcomes.md` | (no legacy back-compat — introduced v3.24.0+) |
```

- [ ] **Step C1.9: Register routing_outcome_corrupt halt across 4 surfaces**

This SOFT halt is new in C1. Synchronize across 4 surfaces in the same C1 commit (per audit-pattern-prevention):

(a) `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — add to type enum + description:
```
type: ... | routing_outcome_corrupt
```
Description:
```markdown
- `routing_outcome_corrupt` — orchestrate-flow v3.0.0+, Iter 33: routing-outcomes.md fails parse. SOFT halt: auto-invalidate (rename to .corrupt-<ISO8601>); chain proceeds with default routing.
```

(b) `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — add to SOFT halts subsection (added in Iter 32 Task 4):
```markdown
- `routing_outcome_corrupt` (v3.0.0+, Iter 33) — orchestrate-flow: routing-outcomes.md parse failure. Auto-invalidate + log; chain proceeds.
```

(c) `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` Step 2.7 procedure already contains the halt logic (per C1.3) — verify it references the canonical envelope structure.

(d) `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` — no per-skill update needed since this halt is internal to orchestrate-flow (not emitted by sub-skills).

- [ ] **Step C1.10: Verify Task C1 deliverables**

Run:
```bash
echo "=== routing-outcomes.md schema doc created ==="
test -f plugins/mega-sdd/skills/memory/references/routing-outcomes.md && wc -l plugins/mega-sdd/skills/memory/references/routing-outcomes.md

echo "=== orchestrate-flow Step 2.7 + Step 7.5 added ==="
grep -c "Step 2.7\|Step 7.5\|2.7. \*\*Memory-informed\|7.5. \*\*End-of-chain" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md

echo "=== orchestrate-flow version 3.0.0 ==="
grep "^version:" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md

echo "=== memory SKILL.md routing-outcomes entry + version 1.3.0 ==="
grep "routing-outcomes\|^version:" plugins/mega-sdd/skills/memory/SKILL.md | head -3

echo "=== routing_outcome_corrupt halt across 4 surfaces ==="
grep "routing_outcome_corrupt" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | head -2
grep "routing_outcome_corrupt" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | head -2

echo "=== paths.md routing-outcomes row ==="
grep "routing-outcomes" plugins/mega-sdd/references/paths.md
```

Expected: schema doc ≥80 lines; Step 2.7 + 7.5 present ≥4 matches; orchestrate-flow version 3.0.0; memory version 1.3.0 + routing-outcomes entry; halt present in vault-contract + orchestrate-flow; paths.md has row.

- [ ] **Step C1.11: Commit Task C1**

```bash
git add plugins/mega-sdd/skills/memory/references/routing-outcomes.md \
        plugins/mega-sdd/skills/orchestrate-flow/SKILL.md \
        plugins/mega-sdd/skills/memory/SKILL.md \
        plugins/mega-sdd/skills/memory/references/memory-schema.md \
        plugins/mega-sdd/references/paths.md \
        plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
git commit -m "$(cat <<'EOF'
feat(iter-33): C1 — F1 Memory-driven routing (orchestrator learns from past)

orchestrate-flow v2.5.1 → v3.0.0 (major bump — adds Step 2.7 routing
preflight + Step 7.5 end-of-chain memory write; chain may halt where
prior versions wouldn't via new soft halt routing_outcome_corrupt).

memory v1.2.1 → v1.3.0 (new schema: routing-outcomes.md).

NEW Step 2.7 (between Step 2.5 starterkit detection + Step 3 build chain):
- Compute project fingerprint (composer.json + package.json + framework_pack_path)[:16]
- Read .mega-sdd/memory/routing-outcomes.md filtered by fingerprint
- Recommend past-successful chain when ≥3 converged runs; warn on ≥2 failed runs
- Fall-through silently when no data (backward-compat for fresh projects)

NEW Step 7.5 (after Step 7 emit final summary):
- Append outcome row via Bash >> heredoc (reuses existing memory file-lock pattern)
- Skipped when --memory-off

NEW soft halt routing_outcome_corrupt registered across 4 surfaces:
- vault-contract.md type enum + description
- orchestrate-flow SOFT halts subsection
- Step 2.7 procedure references canonical envelope
- No handoff-contract per-skill update (internal to orchestrate-flow)

User's "orchestrator pintar" directive: orchestrator now consults memory
before routing — no per-session re-explanation needed once a project has
established successful chain pattern.

Files:
- NEW: plugins/mega-sdd/skills/memory/references/routing-outcomes.md (schema)
- MOD: orchestrate-flow SKILL.md (Step 2.7 + Step 7.5 + version 3.0.0 +
        SOFT halt entry)
- MOD: memory SKILL.md (§Memory layer entry + version 1.3.0)
- MOD: memory-schema.md (§PROJECT scope entry)
- MOD: paths.md (row)
- MOD: vault-contract.md (halt type enum + description)
EOF
)"
```

---

## Task C2: F2 Predictive halt detection (Phase C, independent)

**Files:**
- Create: `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md`
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (+ Step 3.5)
- Modify: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (+ predictive_check_failed halt)

**Reuse-first directive:**
- The pattern of preflight checks already exists in scan-codebase Step 0 (tree-sitter probe). F2 generalizes this concept across all skills.
- Existing Step 4 in orchestrate-flow ("First-run pre-flight (only if chain includes execute-bolts)") is a specific predictive check. F2's Step 3.5 generalizes it; Step 4 becomes a special-case entry in predictive-checks.md catalog (folded into F2 catalog rather than left as orphan).

- [ ] **Step C2.1: Write predictive-checks.md catalog (5-6 initial checks)**

Write `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md`:

```markdown
# Predictive Checks Catalog

> Per-skill preflight checks consulted by `mega-sdd:orchestrate-flow` v3.0.0+ Step 3.5.

**Introduced:** v3.24.0 (Iter 33)
**Consumed by:** `mega-sdd:orchestrate-flow` Step 3.5 predictive preflight

---

## Purpose

Catalog of lightweight checks that detect known halt preconditions BEFORE invoking the skill. Per spec §4.2: "Instead of 'scan-codebase halted on dep_missing 8 minutes in', user sees 'before chain starts: tree-sitter not installed; install or use --engine=regex'."

---

## Check entry format

```markdown
### <skill-name> preflight checks

- **check_id: `<unique-snake-case-id>`**
  command: `<bash command to run>`
  expected: <exit 0 | non-empty output | file exists>
  on_fail: <user-facing warning message>
  fatal: <yes | no>
  predicts_halt: <halt-type that would fire if check ignored>
```

- `command:` MUST be lightweight (no full file scans; bash probes + file existence checks only)
- `fatal: yes` → halt chain with `predictive_check_failed` envelope
- `fatal: no` → log warning + continue (most checks)
- `predicts_halt:` is informational (documents which downstream halt this check anticipates)

---

## scan-codebase preflight checks

- **check_id: `tree_sitter_present`**
  command: `command -v tree-sitter || command -v tree-sitter-cli`
  expected: exit 0
  on_fail: "tree-sitter not installed; scan-codebase will fall back to regex engine (lower precision). Install: brew install tree-sitter / cargo install tree-sitter-cli / npm install -g tree-sitter-cli"
  fatal: no
  predicts_halt: dep_missing (avoided if user OK with regex fallback OR installs binary)

- **check_id: `framework_pack_present`**
  command: `test -f plugins/mega-sdd/references/framework-conventions/<detected-framework>.md`
  expected: file exists
  on_fail: "no framework pack for <framework>; scan-codebase will use _universal.md fallback patterns (lower starterkit detection precision)"
  fatal: no
  predicts_halt: framework_pack_missing (avoided — fallback always exists)

## bind-codebase preflight checks

- **check_id: `binding_input_complete`**
  command: `test -f <vault-path>/vault.json && test -f <codebase-map-path>`
  expected: both files exist
  on_fail: "bind-codebase requires both vault.json AND codebase-map.md. Run scan-codebase first if codebase-map.md absent; run generate-intent first if vault.json absent."
  fatal: yes
  predicts_halt: bind_conflict (vault.json absent) OR dep_missing (codebase-map absent)

- **check_id: `constitution_file_check`**
  command: `test -f <vault-path>/constitution.md`
  expected: file exists (only relevant if --strict-constitution flag passed)
  on_fail: "--strict-constitution requires constitution.md in vault; not found"
  fatal: yes (only when --strict-constitution explicitly set)
  predicts_halt: bind_conflict_constitution_violation

## execute-bolts preflight checks

- **check_id: `units_directory_present`**
  command: `test -d <vault-path>/units && ls <vault-path>/units/U-*.md | head -1`
  expected: at least 1 unit file exists
  on_fail: "execute-bolts requires generated units. Run generate-units first."
  fatal: yes
  predicts_halt: (chain order error — invokes generate-units instead)

- **check_id: `superpowers_available`**
  command: check superpowers plugin presence (existing check from current Step 4)
  expected: superpowers plugin loadable OR vendored fallback present
  on_fail: "execute-bolts dispatches via superpowers.executing-plans; superpowers plugin not available"
  fatal: no (vendored fallback exists)
  predicts_halt: (no specific halt; degraded operation)

## generate-intent preflight checks

- **check_id: `prd_or_kb_input_present`**
  command: `test -f <project>/prd.md || test -d <project>/.mega-sdd/knowledge-base/`
  expected: at least one input
  on_fail: "generate-intent requires PRD (prd.md) OR knowledge-base (extract-intelligence output). Provide one OR run extract-intelligence first."
  fatal: yes
  predicts_halt: (chain order error)

---

## Read protocol (Step 3.5)

```
For each skill in proposed chain:
  Read references/predictive-checks.md §<skill> section
  For each check entry:
    Run command
    If expected condition met → pass; continue to next check
    If condition not met:
      If fatal: yes → emit halt predictive_check_failed; STOP chain
      If fatal: no → accumulate warning; log to user; continue chain
```

---

## Anti-halu rails

1. Check `command:` MUST be deterministic + lightweight (no LLM dispatches, no file reads >1KB)
2. `on_fail:` message MUST be actionable (concrete fix the user can apply)
3. `fatal: yes` MUST be reserved for cases where chain CANNOT succeed without fix
4. NEVER auto-fix preconditions on user's behalf — user does the fix; checks re-run on next invocation
5. Empty/missing predictive-checks.md → orchestrate-flow Step 3.5 logs "no checks defined; skipping preflight" + chain proceeds (no halt)

---

## Adding new checks

Future iters that touch a skill MUST update this catalog if introducing new preconditions:

1. Add new `### <skill> preflight checks` section if skill not present
2. Add new `- **check_id:**` entry with all 5 fields
3. Use canonical halt type names from vault-contract.md `§halt-protocol type enum`
4. Verify check command is portable (works on macOS + Linux; if not, document platform)
5. Cite in skill's SKILL.md halt section: "Step 3.5 preflight check `<check_id>` anticipates this halt"

---

## See also

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` §Step 3.5 (consumer)
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` §halt-protocol (canonical halt envelope for `predictive_check_failed`)
```

- [ ] **Step C2.2: Add Step 3.5 to orchestrate-flow SKILL.md**

Edit `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`. Locate existing Step 3 (Build proposed chain) at line ~77 and Step 4 (First-run pre-flight) at line ~81. Insert NEW Step 3.5 BETWEEN them:

```markdown
3.5. **Predictive preflight (v3.0.0+, Iter 33, generalizes Step 4 first-run pre-flight).**

Per `references/predictive-checks.md` catalog. Runs BEFORE invoking any skill in proposed chain.

a. For each skill in proposed chain (in order):
   - Read `references/predictive-checks.md` §<skill> preflight checks section
   - For each check entry: run `command`; verify against `expected`
   - On match → pass; continue
   - On mismatch:
     - If `fatal: no` → accumulate warning; will surface to user before chain start
     - If `fatal: yes` → emit halt `predictive_check_failed` with check_id + skill in details; STOP chain (do NOT invoke any skill)

b. After all skills checked:
   - If ≥1 warning accumulated → display warnings to user via single message before chain start (e.g., "⚠️ tree-sitter not installed; chain will use regex engine")
   - If chain halted with `predictive_check_failed` → output halt YAML envelope + exit (no Step 4 / Step 5 / Step 6)

c. Wall-clock budget: ≤2 sec total (lightweight bash checks only); if budget exceeded → log warning + proceed (graceful degradation)

d. **Step 4 special case (preserved for back-compat):** existing Step 4 "First-run pre-flight (only if chain includes execute-bolts)" continues to run AFTER Step 3.5 — it covers execute-bolts-specific behaviors that the generic catalog doesn't capture. Future iters MAY fold Step 4 entirely into predictive-checks.md catalog; not in scope for Iter 33.
```

- [ ] **Step C2.3: Add handoff metrics for predictive checks**

Edit `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`. Locate the `## Handoff emission` section (or equivalent — orchestrate-flow may not have one since it's the dispatcher; if absent, this is N/A). For the orchestrator's own final-summary output (Step 7), add 2 new metrics:

```yaml
metrics:
  predictive_warnings_count: <int>     # NEW v3.0.0+: count of non-fatal predictive warnings shown
  predictive_halts_count: <int>        # NEW v3.0.0+: count of fatal predictive halts (always ≤1 since fatal halts STOP)
```

- [ ] **Step C2.4: Register predictive_check_failed halt across 4 surfaces**

Per audit-pattern-prevention checklist (synchronized commit pattern from Iter 32 Task 4):

(a) `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — extend type enum:
```
type: ... | predictive_check_failed
```

(b) Add description:
```markdown
- `predictive_check_failed` — orchestrate-flow v3.0.0+, Iter 33: predictive preflight check marked `fatal: yes` failed. ALWAYS STOP. Resolution: user fixes precondition (install dep / add framework pack / etc.) per `next_action.hint`; re-run chain.
```

(c) `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` ALWAYS-STOP list:
```markdown
- `predictive_check_failed` (v3.0.0+, Iter 33) — orchestrate-flow: fatal preflight check failed; chain blocked.
```

(d) `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` — no per-skill update needed since this halt is internal to orchestrate-flow.

- [ ] **Step C2.5: Add halt YAML envelope example to orchestrate-flow Step 3.5**

In the Step 3.5 procedure (added in C2.2), append a halt envelope example following the canonical schema:

```yaml
# Example predictive_check_failed envelope:
type: predictive_check_failed
source_skill: orchestrate-flow
details:
  failing_check_id: tree_sitter_present
  failing_skill: scan-codebase
  command_run: "command -v tree-sitter || command -v tree-sitter-cli"
  expected: "exit 0"
  actual: "exit 1 (binary not found)"
next_action:
  type: user_install_dep
  hint: "Install tree-sitter (brew install tree-sitter OR cargo install tree-sitter-cli OR npm install -g tree-sitter-cli) then re-run. Alternatively, run scan-codebase with --engine=regex flag to bypass tree-sitter."
```

- [ ] **Step C2.6: Verify Task C2 deliverables**

Run:
```bash
echo "=== predictive-checks.md catalog ==="
test -f plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md && wc -l plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md
echo "Catalog check sections (expect ≥3 skill sections):"
grep -c "^## .* preflight checks" plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md

echo "=== orchestrate-flow Step 3.5 present ==="
grep -c "Step 3.5\|3.5. \*\*Predictive preflight" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md

echo "=== predictive_check_failed halt across 4 surfaces ==="
grep "predictive_check_failed" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | head -2
grep "predictive_check_failed" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | head -3
```

Expected: catalog ≥120 lines; ≥3 per-skill catalog sections; Step 3.5 ≥2 matches; halt across 2 surfaces (vault-contract + orchestrate-flow).

- [ ] **Step C2.7: Commit Task C2**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md \
        plugins/mega-sdd/skills/orchestrate-flow/SKILL.md \
        plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
git commit -m "$(cat <<'EOF'
feat(iter-33): C2 — F2 Predictive halt detection (warns before invoking)

NEW reference: plugins/mega-sdd/skills/orchestrate-flow/references/
predictive-checks.md (5-6 highest-leverage preflight checks across
scan-codebase, bind-codebase, execute-bolts, generate-intent).

NEW Step 3.5 (between Step 3 build chain + Step 4 first-run pre-flight):
- For each skill in chain, runs lightweight catalog checks
- Non-fatal failures → user warning before chain start
- Fatal failures → halt predictive_check_failed; chain blocked

NEW halt predictive_check_failed (ALWAYS STOP) synchronized across:
- vault-contract.md type enum + description
- orchestrate-flow ALWAYS-STOP list
- Step 3.5 procedure (with canonical envelope example)

Step 4 (existing First-run pre-flight for execute-bolts) preserved as
special case + back-compat. Future iters MAY fold Step 4 into catalog.

User experience: instead of "scan-codebase halted on dep_missing 8min
in", user sees "before chain starts: tree-sitter not installed; install
or use --engine=regex" — actionable predictive feedback.

Reuse pattern: lightweight bash checks (≤2sec budget); catalog format
mirrors existing predictive-style entries in scan-codebase Step 0
(tree-sitter probe) which becomes the canonical reference for catalog
entries.
EOF
)"
```

---

## Task C3: F3 Schema validation gate (Phase C, independent — but enables F4)

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` (REQUIRED/CONDITIONAL/OPTIONAL annotations on every field)
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (+ Step 6.b validation gate)
- Modify: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (+ invalid_handoff halt)

**Reuse-first directive:**
- handoff-contract.md already documents fields with conditional language ("v2.1+ — optional otherwise", "required when active"). F3 makes this MACHINE-READABLE by adding explicit `(REQUIRED)` / `(CONDITIONAL)` / `(OPTIONAL)` annotations alongside existing prose.
- vault-contract.md `§halt-protocol` envelope is the canonical halt YAML schema. F3's halt envelope MUST use it.

- [ ] **Step C3.1: Read handoff-contract.md schema section to identify all fields**

Run:
```bash
grep -nE "^### \`|^### " plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md | head -30
```

Identify all top-level fields in the schema section (lines 9-118). Examples expected: `emitted_by`, `emitted_at`, `status`, `artifacts`, `next_action`, `blockers`, `metrics`, `checkpoints`, `constitution`, `pbt`, `mutability`, `scope`, `cycles`, `replay`, `metadata`, `starterkit_context`.

- [ ] **Step C3.2: Add REQUIRED/CONDITIONAL/OPTIONAL annotations to each field**

Edit `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`. For each top-level field section in the schema, prepend an annotation badge to the section heading. Examples:

```markdown
### `emitted_by:` (REQUIRED)

(existing description)

### `emitted_at:` (REQUIRED)

(existing description)

### `status:` (REQUIRED)

enum: completed | paused | halted

### `artifacts:` (REQUIRED)

array of absolute paths; non-empty if status==completed; empty allowed if status==halted

### `next_action:` (REQUIRED)

object with type, suggested_skill, suggested_args, rationale

### `blockers:` (REQUIRED)

array; empty when status=completed; non-empty when status=paused|halted (per halt-protocol §blocker envelope)

### `metrics:` (OPTIONAL but encouraged)

object with skill-specific metric fields

### `checkpoints:` (CONDITIONAL — if skill emits resume-capable checkpoints)

object: { latest_step_id, checkpoint_file, resume_command }

### `constitution:` (CONDITIONAL — if vault has constitution.md)

object: { constitution_hash, clauses_referenced }

### `pbt:` (CONDITIONAL — if unit has properties: array)

object: { properties_validated, properties_failed }

### `mutability:` (CONDITIONAL — if skill processes mutability-tier claims)

object: { tier_distribution, locked_claims_touched, artifact_discards_proposed }

### `scope:` (CONDITIONAL — if vault has scope_metadata)

object: { id, name, sibling_scopes, prd_sha256 }

### `cycles:` (CONDITIONAL — if convergence loop ran)

object: { cycle_count, halts_auto_resolved, halts_escalated_to_user }

### `replay:` (CONDITIONAL — if replay capture active)

object: { snapshot_path, divergence_classification }

### `metadata:` (OPTIONAL — memory layer integration)

object: { memory_context, memory_writes }

### `starterkit_context:` (CONDITIONAL — if scan-codebase deep-scan ran successfully)

object: see starterkit-context-schema.md
```

Each annotation is now MACHINE-READABLE for Step 6.b validation. Conditional rules use plain English the validator can match against runtime state (e.g., "if vault has scope_metadata" → check vault.json).

- [ ] **Step C3.3: Add Step 6.b validation gate to orchestrate-flow SKILL.md**

Edit `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`. Locate existing Step 6 (Execute chain) at line ~87. Step 6 currently dispatches sub-skills. Restructure Step 6 to use sub-letters (a, b, c) to describe the per-skill dispatch + validate + propagate flow:

```markdown
6. **Execute chain.** Dispatch sub-skills with `--auto` flag. Pause on blocker artifacts per `vault-contract.md` §halt-protocol. `resolve-oq` step is always interactive on per-OQ choices.

   Per sub-skill in chain (loop):

   a. **Dispatch sub-skill** with assembled flags + memory slice via `metadata.memory_context`.

   b. **Validation gate (v3.0.0+, Iter 33) — validate received handoff against handoff-contract.md schema:**

      i. (Reserved for F4 type-check; documented in Step 6.b.i in C4 task)

      ii. Parse handoff YAML; if YAML parse fails → emit halt `invalid_handoff` with details {failing_skill, parse_error}; STOP chain.

      iii. For each field declared `(REQUIRED)` in handoff-contract.md schema:
           - If field absent in handoff YAML → emit halt `invalid_handoff` with details {failing_skill, missing_field, severity: REQUIRED}; STOP chain.

      iv. For each field declared `(CONDITIONAL — <condition>)`:
           - Evaluate condition against runtime state (e.g., "if vault has scope_metadata" → read vault.json scope_metadata key)
           - If condition met AND field absent → emit halt `invalid_handoff` with details {failing_skill, missing_field, severity: CONDITIONAL, condition_evaluated: <result>}; STOP chain.
           - If condition NOT met → field absence OK; continue.

      v. For each field declared `(OPTIONAL)`:
           - Field absence OK; log presence/absence for telemetry.

      vi. If all validation passes → continue to step c.

   c. **Propagate handoff metadata** to next skill in chain via `metadata.memory_context` + canonical top-level fields (scope, constitution, mutability, pbt, cycles, replay, starterkit_context) passthrough per orchestrator consumption logic (existing behavior).

   d. **Update progress indicator** per AUTONOMY-OQ-4 progress format.

   e. **If status==halted** → exit loop; proceed to Step 7 (emit final summary).

   f. **If status==completed** → continue loop to next sub-skill.
```

- [ ] **Step C3.4: Add invalid_handoff halt YAML envelope example**

In the Step 6.b procedure (added in C3.3), append a halt envelope example:

```yaml
# Example invalid_handoff envelope (REQUIRED field missing):
type: invalid_handoff
source_skill: orchestrate-flow
details:
  failing_skill: bind-codebase
  missing_field: "scope.id"
  field_severity: CONDITIONAL
  condition_evaluated: "vault has scope_metadata = TRUE"
  handoff_file: "<vault>/.internal/checkpoints/2026-05-24-bind-codebase.handoff.yaml"
next_action:
  type: edit_skill_template
  hint: "Edit plugins/mega-sdd/skills/bind-codebase/SKILL.md §Handoff emission YAML template to include scope: block per handoff-contract.md schema. After fix, re-run chain. (Phase A1 audit closure should have prevented this — verify your skill body is up to date.)"
```

- [ ] **Step C3.5: Register invalid_handoff halt across 4 surfaces**

(a) vault-contract.md type enum:
```
type: ... | invalid_handoff
```

(b) Add description:
```markdown
- `invalid_handoff` — orchestrate-flow v3.0.0+, Iter 33: handoff YAML from sub-skill fails schema validation (missing REQUIRED field, or CONDITIONAL field missing when condition met, or YAML parse error). ALWAYS STOP. Resolution: producer skill author fixes handoff template per handoff-contract.md schema; re-run chain.
```

(c) orchestrate-flow SKILL.md ALWAYS-STOP list:
```markdown
- `invalid_handoff` (v3.0.0+, Iter 33) — orchestrate-flow: handoff schema validation failed; producer-side error.
```

(d) handoff-contract.md — no per-skill update needed (halt internal to orchestrate-flow).

- [ ] **Step C3.6: Verify Task C3 deliverables**

Run:
```bash
echo "=== handoff-contract REQUIRED/CONDITIONAL/OPTIONAL annotations ==="
grep -c "(REQUIRED)\|(CONDITIONAL\|(OPTIONAL)" plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md

echo "=== Step 6.b validation gate ==="
grep -c "Step 6.b\|Validation gate\|validate received handoff" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md

echo "=== invalid_handoff halt across 2 surfaces ==="
grep "invalid_handoff" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | head -2
grep "invalid_handoff" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | head -3
```

Expected: ≥10 annotations (one per top-level field); Step 6.b ≥2 matches; halt present in 2 surfaces.

- [ ] **Step C3.7: Commit Task C3**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md \
        plugins/mega-sdd/skills/orchestrate-flow/SKILL.md \
        plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
git commit -m "$(cat <<'EOF'
feat(iter-33): C3 — F3 Schema validation gate (handoff validated at emission)

handoff-contract.md gains REQUIRED/CONDITIONAL/OPTIONAL annotations on
every top-level field. Annotations are machine-readable for validator.

NEW Step 6.b (sub-step of Step 6 Execute chain):
- Receives handoff from completed sub-skill
- Parses YAML (halt invalid_handoff on parse error)
- Validates REQUIRED fields present (halt with missing_field detail)
- Validates CONDITIONAL fields present when condition met (e.g.,
  scope: required if vault has scope_metadata)
- OPTIONAL fields logged for telemetry only
- On pass → propagate metadata to next skill (Step 6.c)

NEW halt invalid_handoff (ALWAYS STOP) synchronized across:
- vault-contract.md type enum + description
- orchestrate-flow ALWAYS-STOP list
- Step 6.b procedure (with canonical envelope example)

Closes iter-31 root cause pattern: "field claimed in skill body prose
but missing in handoff template" — now caught at producer side at
handoff emission time, not consumer side at silent miss time.

Phase A handoff sweep (Task A1) ensured all 8 affected skill SKILL.md
handoff YAML templates have required blocks. Without Phase A, F3 would
halt EVERY pipeline. Strict mode enforceable because Phase A passed.

Step 6 restructured to a-f sub-letters (dispatch / validate / propagate
/ progress / halt-check / continue-loop) — preserves existing dispatch
behavior while adding validation gate inline.
EOF
)"
```

---

## Task C4: F4 Type-checked field propagation (Phase C, DEPENDS ON C3)

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` (TYPE annotations extending C3 annotations)
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (+ Step 6.b.i type-check sub-step — was Reserved in C3)
- Modify: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (+ handoff_type_mismatch halt)

**Dependency:** C4 extends C3's REQUIRED/CONDITIONAL/OPTIONAL annotations with TYPE annotations. C3 MUST be complete before C4.

- [ ] **Step C4.1: Verify C3 complete**

Run:
```bash
git log --oneline | grep "C3" | head -1
grep -c "(REQUIRED)\|(CONDITIONAL\|(OPTIONAL)" plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
```

Expected: C3 commit visible; ≥10 annotations present. If not → return to C3 before proceeding.

- [ ] **Step C4.2: Add TYPE annotations to each handoff field**

Edit `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`. For each top-level field section already annotated with REQUIRED/CONDITIONAL/OPTIONAL (from C3), add a TYPE annotation. Examples:

```markdown
### `emitted_by:` (REQUIRED)
TYPE: string (enum from vault-contract.md §halt-protocol source_skill enum)

### `emitted_at:` (REQUIRED)
TYPE: string (ISO8601 format)

### `status:` (REQUIRED)
TYPE: enum (completed | paused | halted)

### `artifacts:` (REQUIRED)
TYPE: array<string> (absolute file paths; non-empty if status==completed)

### `next_action:` (REQUIRED)
TYPE: object {
  type: string,
  suggested_skill: string,
  suggested_args: array<string>,
  rationale: string
}

### `blockers:` (REQUIRED)
TYPE: array<object> (empty when status==completed; per halt-protocol §blocker envelope when populated)

### `metrics:` (OPTIONAL but encouraged)
TYPE: object (skill-specific; consult per-skill section for declared metric fields)

### `checkpoints:` (CONDITIONAL — if skill emits resume-capable checkpoints)
TYPE: object {
  latest_step_id: string,
  checkpoint_file: string (absolute path),
  resume_command: string
}

### `constitution:` (CONDITIONAL — if vault has constitution.md)
TYPE: object {
  constitution_hash: string (sha256 hex),
  clauses_referenced: array<string>
}

### `pbt:` (CONDITIONAL — if unit has properties: array)
TYPE: object {
  properties_validated: int (≥0),
  properties_failed: int (≥0)
}

### `mutability:` (CONDITIONAL — if skill processes mutability-tier claims)
TYPE: object {
  tier_distribution: object {
    LOCKED: int (≥0),
    INTENT: int (≥0),
    ARTIFACT: int (≥0)
  },
  locked_claims_touched: array<string>,
  artifact_discards_proposed: int (≥0)
}

### `scope:` (CONDITIONAL — if vault has scope_metadata)
TYPE: object {
  id: string (enum from vault.json scope_metadata.allowed_scopes),
  name: string,
  sibling_scopes: array<string>,
  prd_sha256: string (sha256 hex)
}

### `cycles:` (CONDITIONAL — if convergence loop ran)
TYPE: object {
  cycle_count: int (≥0),
  halts_auto_resolved: array<string>,
  halts_escalated_to_user: array<string>
}

### `replay:` (CONDITIONAL — if replay capture active)
TYPE: object {
  snapshot_path: string (absolute path),
  divergence_classification: enum (clean | minor | high | n/a)
}

### `metadata:` (OPTIONAL — memory layer integration)
TYPE: object {
  memory_context: object,
  memory_writes: array<object>
}

### `starterkit_context:` (CONDITIONAL — if scan-codebase deep-scan ran successfully)
TYPE: object (see starterkit-context-schema.md for full structure)
```

Add a note at the end of the schema section:

```markdown
**Type-check enforceability:** fields with explicit `TYPE:` annotations are validated at Step 6.b.i (Iter 33 F4). Fields without TYPE annotation bypass type check (warn-only log). Iter 33 covers all top-level fields + 1 level of nesting (e.g., `mutability.tier_distribution.LOCKED`). Deeper nesting deferred to Iter 34+.
```

- [ ] **Step C4.3: Add Step 6.b.i type-check sub-step to orchestrate-flow SKILL.md**

Edit `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`. Locate Step 6.b (added in C3). Replace the "i. (Reserved for F4 type-check)" placeholder with the actual type-check logic:

```markdown
      i. **Type-check fields against handoff-contract.md TYPE annotations (v3.0.0+, Iter 33 F4):**
         For each field present in handoff YAML:
         - Lookup TYPE annotation in handoff-contract.md §<field-name> section
         - If TYPE annotation absent → log warn-only ("field <name> has no TYPE in schema; skipping type check"); continue
         - If TYPE annotation present → validate value matches TYPE:
           - `string` → value is string (not int/array/object)
           - `int` → value is integer; respect `(≥N)` constraint if present
           - `enum (a | b | c)` → value is in allowed list
           - `array<T>` → value is array AND each element matches T
           - `object {...}` → value is object AND each declared sub-field matches its TYPE
           - `string (sha256 hex)` → value is 64-char hex string
           - `string (ISO8601)` → value matches ISO8601 pattern
         - On type mismatch → emit halt `handoff_type_mismatch` with details {failing_skill, field_name, expected_type, actual_type, actual_value (truncated to 100 chars)}; STOP chain.
```

Append halt envelope example:

```yaml
# Example handoff_type_mismatch envelope:
type: handoff_type_mismatch
source_skill: orchestrate-flow
details:
  failing_skill: bind-codebase
  field_name: "scope.id"
  expected_type: "string (enum from vault.json scope_metadata.allowed_scopes)"
  actual_type: "object"
  actual_value: "{ id: 'BE', name: 'Backend' }"
next_action:
  type: edit_skill_template
  hint: "Field scope.id should be a string (enum value), not an object. Edit bind-codebase handoff template to emit scope.id as 'BE' string directly. Likely cause: handoff template emitted the entire scope object as scope.id by mistake. (Possible upstream: vault.json shape changed; verify scope_metadata schema.)"
```

- [ ] **Step C4.4: Register handoff_type_mismatch halt across 4 surfaces**

(a) vault-contract.md type enum:
```
type: ... | handoff_type_mismatch
```

(b) Add description:
```markdown
- `handoff_type_mismatch` — orchestrate-flow v3.0.0+, Iter 33 F4: handoff YAML field type doesn't match TYPE annotation in handoff-contract.md schema. ALWAYS STOP. Resolution: producer skill author fixes type emission per handoff-contract.md TYPE annotation; re-run chain.
```

(c) orchestrate-flow SKILL.md ALWAYS-STOP list:
```markdown
- `handoff_type_mismatch` (v3.0.0+, Iter 33) — orchestrate-flow: handoff field type mismatch with schema annotation.
```

(d) handoff-contract.md — no per-skill update.

- [ ] **Step C4.5: Verify Task C4 deliverables**

Run:
```bash
echo "=== handoff-contract TYPE annotations ==="
grep -c "^TYPE:" plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md

echo "=== Step 6.b.i type-check sub-step ==="
grep -c "Step 6.b.i\|Type-check fields\|TYPE annotation" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md

echo "=== handoff_type_mismatch halt across 2 surfaces ==="
grep "handoff_type_mismatch" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | head -2
grep "handoff_type_mismatch" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md | head -3
```

Expected: ≥10 TYPE annotations; Step 6.b.i ≥2 matches; halt present in 2 surfaces.

- [ ] **Step C4.6: Commit Task C4**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md \
        plugins/mega-sdd/skills/orchestrate-flow/SKILL.md \
        plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
git commit -m "$(cat <<'EOF'
feat(iter-33): C4 — F4 Type-checked field propagation (no shape drift)

handoff-contract.md TYPE annotations added to every top-level field
extending C3's REQUIRED/CONDITIONAL/OPTIONAL. Types: string | int |
enum | array<T> | object {sub-fields}.

NEW Step 6.b.i (sub-step of Step 6.b validation gate, was Reserved in C3):
- For each field present in handoff YAML
- Lookup TYPE in handoff-contract.md
- Validate value matches TYPE (string/int/enum/array/object/sha256/ISO8601)
- Type mismatch → halt handoff_type_mismatch with field_name +
  expected_type + actual_type + actual_value (truncated)

NEW halt handoff_type_mismatch (ALWAYS STOP) synchronized across 2
surfaces (vault-contract + orchestrate-flow).

Backward-compat: fields without TYPE annotation bypass type check
(warn-only log). Iter 33 covers all top-level + 1-level nesting.
Deeper nesting deferred to Iter 34+.

Prevents silent shape drift: e.g., scope.id being string in one skill
but object in another — caught at handoff propagation, not silently
mis-consumed downstream.

User's "handoff yang solid" directive: type contract now enforced at
every chain step, not just documented as prose.

DEPENDS ON: C3 (extends C3's annotations; required commit ordering).
EOF
)"
```

---

## Task D: Trigger tests + scenario

**Files:**
- Modify: `tests/skill-triggering/orchestrate-flow.test.md` (+ 8 cases: OF-MR1/2, OF-PH1/2, OF-VG1/2, OF-TC1/2)
- Modify: `tests/skill-triggering/memory.test.md` (+ 2 cases: M-RO1, M-RO2)
- Modify: `tests/skill-triggering/scan-codebase.test.md` (+ 1 case: SC-PH1)
- Modify: `tests/skill-triggering/bind-codebase.test.md` (+ 1 case: BC-PH1)
- Create: `tests/scenarios/scenario-9-flawless-seamless-intelligence.md`

- [ ] **Step D.1: Add 8 cases to orchestrate-flow.test.md**

Append to `tests/skill-triggering/orchestrate-flow.test.md` under new section `## Iter 33 — Intelligence features (v3.0.0+)`:

```markdown
### OF-MR1 — Memory-driven routing recommends past-successful chain

**Setup:**
- `.mega-sdd/memory/routing-outcomes.md` exists with ≥3 rows matching current project fingerprint, all converged=yes, all chain-used="starterkit-first"
- Default routing-rules.md would propose "direct" chain

**Trigger:** `/mega-sdd:auto`

**Expected:**
- Step 2.7 reads routing-outcomes.md
- Fingerprint matches ≥3 prior converged runs with consistent chain
- Recommendation displayed: "Routing recommendation from past 3 runs (all converged in avg 10 min): starterkit-first"
- Step 3 builds starterkit-first chain (overriding routing-rules.md default)
- Chain executes; Step 7.5 appends new outcome row

### OF-MR2 — No prior runs: fall through to default routing

**Setup:**
- `.mega-sdd/memory/routing-outcomes.md` does not exist (fresh project)

**Trigger:** `/mega-sdd:auto`

**Expected:**
- Step 2.7 reads routing-outcomes.md → file absent → skips routing recommendation
- Step 3 builds chain per routing-rules.md default
- No "routing recommendation" message displayed
- Chain executes; Step 7.5 creates routing-outcomes.md + appends first row

### OF-PH1 — Predictive check (non-fatal): tree-sitter warning

**Setup:**
- tree-sitter binary NOT installed
- Project has Laravel composer.json (framework detected)
- Chain proposes scan-codebase

**Trigger:** `/mega-sdd:auto`

**Expected:**
- Step 3.5 runs predictive checks for scan-codebase
- `tree_sitter_present` check fails (non-fatal)
- Warning displayed to user BEFORE chain starts: "⚠️ tree-sitter not installed; scan-codebase will fall back to regex engine. Install: brew install tree-sitter..."
- Chain proceeds normally (scan-codebase uses regex)
- handoff metrics.predictive_warnings_count = 1; metrics.predictive_halts_count = 0

### OF-PH2 — Predictive check (fatal): execute-bolts requires units

**Setup:**
- vault exists but units/ directory empty (no U-*.md files)
- Chain proposes execute-bolts (user passed `--from=execute-bolts`)

**Trigger:** `/mega-sdd:execute-bolts --auto`

**Expected:**
- Step 3.5 runs `units_directory_present` predictive check for execute-bolts
- Check fails (fatal=yes)
- Halt `predictive_check_failed` emitted; chain STOPS before execute-bolts dispatched
- halt envelope: details.failing_check_id="units_directory_present"; next_action.hint="Run generate-units first"
- Chain output: predictive halt YAML; no execute-bolts invocation

### OF-VG1 — Schema validation gate passes for compliant handoff

**Setup:**
- bind-codebase emits handoff with all REQUIRED + CONDITIONAL (vault has scope_metadata + scope: block present) fields

**Trigger:** chain that includes bind-codebase

**Expected:**
- Step 6.b parses bind-codebase handoff YAML successfully
- All REQUIRED fields present; condition met for scope: + scope present
- No halt; Step 6.c propagates metadata to next skill (generate-units)

### OF-VG2 — Schema validation gate halts on missing CONDITIONAL field

**Setup:**
- bind-codebase emits handoff WITHOUT scope: block, but vault.json has scope_metadata
- (Simulated: inject test fixture that bypasses Phase A1 sweep for this test)

**Trigger:** chain includes bind-codebase

**Expected:**
- Step 6.b validates handoff against schema
- Condition "vault has scope_metadata" evaluates TRUE
- scope: field missing (CONDITIONAL+condition_met)
- Halt `invalid_handoff` emitted; STOPS chain before generate-units dispatched
- halt envelope: details.failing_skill="bind-codebase"; missing_field="scope"; field_severity="CONDITIONAL"; condition_evaluated="vault has scope_metadata = TRUE"
- next_action.hint includes "Edit bind-codebase SKILL.md handoff template"

### OF-TC1 — Type check passes for compliant field types

**Setup:**
- bind-codebase emits handoff with scope.id as string "BE" (matches TYPE: enum)

**Trigger:** chain includes bind-codebase

**Expected:**
- Step 6.b.i type-checks scope.id field
- Value "BE" matches TYPE: enum from scope_metadata.allowed_scopes
- No halt; propagation continues

### OF-TC2 — Type check halts on type mismatch

**Setup:**
- bind-codebase emits handoff with scope.id as object `{id: "BE"}` instead of string "BE"
- (Simulated: inject test fixture)

**Trigger:** chain includes bind-codebase

**Expected:**
- Step 6.b.i type-checks scope.id field
- Expected: string; Actual: object → MISMATCH
- Halt `handoff_type_mismatch` emitted; STOPS chain
- halt envelope: details.failing_skill="bind-codebase"; field_name="scope.id"; expected_type="string (enum)"; actual_type="object"; actual_value="{id: 'BE'}"
- next_action.hint includes "Field scope.id should be a string (enum value), not an object"
```

- [ ] **Step D.2: Add 2 cases to memory.test.md**

Append under `## Iter 33 — Routing outcomes (v1.3.0+)`:

```markdown
### M-RO1 — Routing outcomes append on chain end

**Setup:**
- Fresh project; no `.mega-sdd/memory/routing-outcomes.md`
- Chain executes successfully (status=completed, blockers=[])
- Duration: 8 min; 0 halts

**Trigger:** chain completes; Step 7.5 fires

**Expected:**
- `.mega-sdd/memory/routing-outcomes.md` created with header + first row
- Row format: `<today's date> | <fingerprint> | <chain-used> | 8 | yes | 0`
- File lock acquired + released cleanly (no `memory_in_use` halt)

### M-RO2 — Routing outcomes corrupt: auto-invalidate + chain proceeds

**Setup:**
- `.mega-sdd/memory/routing-outcomes.md` exists but is malformed (e.g., invalid markdown table)

**Trigger:** chain start; Step 2.7 fires

**Expected:**
- Step 2.7 parse fails
- Soft halt `routing_outcome_corrupt` emitted
- File renamed to `routing-outcomes.md.corrupt-<ISO8601>`
- Log message: "routing-outcomes.md corrupt; auto-invalidated; chain proceeds with default routing"
- Chain CONTINUES with routing-rules.md default (soft halt warns; doesn't STOP)
- Step 7.5 creates fresh routing-outcomes.md on chain end
```

- [ ] **Step D.3: Add 1 case to scan-codebase.test.md**

Append under `## Iter 33 — Predictive checks (consumed by orchestrate-flow Step 3.5)`:

```markdown
### SC-PH1 — tree_sitter_present predictive check entry

**Setup:** N/A — this is a documentation test verifying scan-codebase catalog entry exists in `predictive-checks.md`

**Verify:**
- Grep `references/predictive-checks.md` for `## scan-codebase preflight checks` section
- Confirm `check_id: tree_sitter_present` entry present
- Confirm command, expected, on_fail, fatal=no, predicts_halt=dep_missing
- Confirm catalog entry matches behavior in scan-codebase SKILL.md Step 0 engine detection (consistent message + install hint)
```

- [ ] **Step D.4: Add 1 case to bind-codebase.test.md**

Append under `## Iter 33 — Predictive checks`:

```markdown
### BC-PH1 — binding_input_complete predictive check entry

**Setup:** N/A — documentation test

**Verify:**
- Grep `references/predictive-checks.md` for `## bind-codebase preflight checks` section
- Confirm `check_id: binding_input_complete` entry present
- Confirm command checks for vault.json AND codebase-map.md
- Confirm fatal=yes; predicts_halt=bind_conflict or dep_missing
- Confirm on_fail hint instructs "Run scan-codebase first if codebase-map.md absent; run generate-intent first if vault.json absent"
```

- [ ] **Step D.5: Write scenario-9 full-pipeline integration test**

Write `tests/scenarios/scenario-9-flawless-seamless-intelligence.md`:

```markdown
# Scenario 9 — Flawless Seamless Intelligence (full pipeline)

> Integration scenario validating Iter 33 F1+F2+F3+F4 end-to-end. Tests orchestrator intelligence (memory-driven routing + predictive halts) + handoff solidity (schema validation + type-check) on a real Laravel starterkit project.

**Time:** ~30-40 min (2 chain runs to demonstrate F1 cache hit)
**When to use:** verify Iter 33 v3.24.0 end-to-end on user's `base-laravel-26` starterkit; field-test acceptance criterion

## Prerequisites

- Plugin v3.24.0 installed
- Laravel starterkit project at `<project_root>` with composer.json + package.json + tailwind.config.js
- tree-sitter installed (for predictive check pass demonstration)
- PRD at `<project_root>/prd.md`

## Scenario steps

### Step 1: First chain run (no prior routing-outcomes)

```
/mega-sdd:auto
```

**Assertions:**
- Step 2.7 routing preflight runs but skips recommendation (no routing-outcomes.md file)
- Step 3.5 predictive preflight runs; tree_sitter_present passes (no warning)
- Chain executes: scan-codebase → generate-intent → bind-codebase → generate-units → execute-bolts
- Each handoff passes Step 6.b schema validation (all REQUIRED + CONDITIONAL fields present per Phase A1 sweep)
- Each handoff passes Step 6.b.i type-check (no shape drift)
- Step 7.5 creates `.mega-sdd/memory/routing-outcomes.md` + appends first row

### Step 2: Second chain run (routing-outcomes consulted)

```
/mega-sdd:auto
```

**Assertions:**
- Step 2.7 reads routing-outcomes.md → 1 row matches fingerprint (from Step 1); below ≥3 threshold → fall-through to default routing
- Routing identical to first run (default)
- Step 7.5 appends second row

### Step 3: Third chain run (3 rows → recommendation triggers)

```
/mega-sdd:auto
```

**Assertions:**
- Step 2.7 finds 2 prior rows → still below ≥3 threshold → fall-through

### Step 4: After 3 successful runs, fourth run triggers recommendation

```
/mega-sdd:auto
```

**Assertions:**
- Step 2.7 finds ≥3 prior rows; all converged=yes; same chain-used
- Recommendation displayed: "Routing recommendation from past 3 runs (all converged in avg X min): starterkit-first"
- Chain uses recommended routing
- Step 7.5 appends fourth row

### Step 5: Force a predictive halt

```
# Uninstall tree-sitter
brew uninstall tree-sitter

# Force tree-sitter engine
/mega-sdd:scan-codebase --engine=tree-sitter
```

**Assertions:**
- Step 3.5 predictive preflight runs
- tree_sitter_present check fails; fatal=NO → warning only
- Chain proceeds; scan-codebase fails with dep_missing AFTER (as expected — predictive check was correct)

### Step 6: Force a validation halt (simulated)

```
# Manually edit bind-codebase SKILL.md handoff template to REMOVE scope: block
# Then run chain on vault with scope_metadata
/mega-sdd:auto
```

**Assertions:**
- Step 6.b validation runs after bind-codebase completes
- CONDITIONAL field scope: missing; condition (vault has scope_metadata) TRUE
- Halt invalid_handoff emitted; chain STOPS
- next_action.hint guides user to fix bind-codebase template

## Pass criteria

ALL of:
- routing-outcomes.md created on first run + appended each subsequent run
- Recommendation triggers after ≥3 consistent successful runs
- Predictive checks fire warnings non-fatally + fatal halt when fatal=yes
- Schema validation gate halts on missing CONDITIONAL field
- Type-check halts on type mismatch
- Generated code matches starterkit patterns (Iter 32 carryover behavior — sanity)

## Failure modes to watch

- `routing_outcome_corrupt` (file gets malformed) → auto-invalidate + chain proceeds (soft halt; expected)
- `predictive_check_failed` (fatal check) → chain halts BEFORE skill invocation (expected behavior)
- `invalid_handoff` (schema validation) → chain halts AFTER skill completes BUT BEFORE next skill invocation (expected)
- `handoff_type_mismatch` (type check) → same as invalid_handoff routing (expected)

## Related artifacts

- Spec: `docs/superpowers/specs/2026-05-24-iter-33-flawless-seamless-intelligence-design.md`
- Plan: `docs/superpowers/plans/2026-05-24-iter-33-flawless-seamless-intelligence.md`
- Audit: `docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md` (Phase B output)

## Field test path

`/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/base-laravel-26`
```

- [ ] **Step D.6: Verify Task D deliverables**

Run:
```bash
echo "=== orchestrate-flow.test.md new cases (expect 8 OF-* cases) ==="
grep "^### OF-MR\|^### OF-PH\|^### OF-VG\|^### OF-TC" tests/skill-triggering/orchestrate-flow.test.md

echo "=== memory.test.md M-RO cases (expect 2) ==="
grep "^### M-RO" tests/skill-triggering/memory.test.md

echo "=== scan-codebase SC-PH1 (expect 1) ==="
grep "^### SC-PH" tests/skill-triggering/scan-codebase.test.md

echo "=== bind-codebase BC-PH1 (expect 1) ==="
grep "^### BC-PH" tests/skill-triggering/bind-codebase.test.md

echo "=== scenario-9 file exists ==="
test -f tests/scenarios/scenario-9-flawless-seamless-intelligence.md && wc -l tests/scenarios/scenario-9-flawless-seamless-intelligence.md
```

Expected: 8 OF cases + 2 M-RO + 1 SC-PH + 1 BC-PH = 12 cases; scenario-9 file ≥100 lines.

- [ ] **Step D.7: Commit Task D**

```bash
git add tests/skill-triggering/orchestrate-flow.test.md \
        tests/skill-triggering/memory.test.md \
        tests/skill-triggering/scan-codebase.test.md \
        tests/skill-triggering/bind-codebase.test.md \
        tests/scenarios/scenario-9-flawless-seamless-intelligence.md
git commit -m "$(cat <<'EOF'
test(iter-33): 12 trigger tests + scenario-9 for intelligence features

12 new trigger test cases:
- orchestrate-flow.test.md (8 cases): OF-MR1/2 (memory-driven routing
  recommend + fallback), OF-PH1/2 (predictive check non-fatal warn +
  fatal halt), OF-VG1/2 (schema validation pass + invalid_handoff halt),
  OF-TC1/2 (type-check pass + handoff_type_mismatch halt)
- memory.test.md (2 cases): M-RO1 (routing-outcomes append on chain end),
  M-RO2 (corrupt file → routing_outcome_corrupt + auto-invalidate)
- scan-codebase.test.md (1 case): SC-PH1 (tree_sitter_present catalog entry)
- bind-codebase.test.md (1 case): BC-PH1 (binding_input_complete entry)

scenario-9-flawless-seamless-intelligence.md: 6-step integration test
- Steps 1-4: first run creates routing-outcomes, third+ run triggers
  memory-driven recommendation
- Step 5: predictive check fires (tree-sitter uninstalled + --engine=tree-sitter)
- Step 6: validation gate halts on missing CONDITIONAL field (simulated
  bind-codebase template regression)
- Field test path: /Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/
  base-laravel-26

Test coverage matches Iter 33 4 features + audit-pattern-prevention
(no producer-only ship; tests ship in-iter).
EOF
)"
```

---

## Task E: Release v3.24.0

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json` (3.23.0 → 3.24.0)
- Modify: `CHANGELOG.md` (+ `[3.24.0] - 2026-05-24` Iter 33 entry)
- Modify: `plugins/mega-sdd/README.md` (+ "What's new in v3.24.0" section)
- Modify: 6 skill SKILL.md frontmatters (patch version bumps from Phase A)

- [ ] **Step E.1: Bump plugin.json version 3.23.0 → 3.24.0**

Edit `plugins/mega-sdd/.claude-plugin/plugin.json`:
```json
"version": "3.24.0",
```

- [ ] **Step E.2: Bump skill versions from Phase A handoff changes**

Edit frontmatter version field in each skill SKILL.md modified by Phase A1:

| File | From | To |
|---|---|---|
| `plugins/mega-sdd/skills/bind-codebase/SKILL.md` | 1.9.3 | 1.9.4 |
| `plugins/mega-sdd/skills/detect-drift/SKILL.md` | 1.4.0 | 1.4.1 |
| `plugins/mega-sdd/skills/diff-vault/SKILL.md` | 1.3.0 | 1.3.1 |
| `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` | 1.4.0 | 1.4.1 |
| `plugins/mega-sdd/skills/generate-intent/SKILL.md` | 1.12.0 | 1.13.0 |
| `plugins/mega-sdd/skills/resolve-oq/SKILL.md` | 0.9.1 | 0.9.2 |
| `plugins/mega-sdd/skills/emit-agents-md/SKILL.md` | 1.2.4 | 1.2.5 |

(orchestrate-flow + memory already bumped in C1; execute-bolts + generate-units + scan-codebase + using-mega-sdd unchanged this iter at skill level.)

- [ ] **Step E.3: Add CHANGELOG entry**

Edit `CHANGELOG.md`. Add at TOP (after file header, above existing [3.23.0] entry):

```markdown
## [3.24.0] - 2026-05-24

### Iter 33 — Flawless Seamless Intelligence (Orchestrator + Handoffs)

**Combined mega-iter**: 3-phase delivery (~28-33hr) closes Iter 31 audit debt + audits intelligence + ships 4 intelligence features. orchestrate-flow major bump v2.5.1 → v3.0.0.

**Skills bumped:**
- `orchestrate-flow` 2.5.1 → **3.0.0** (major: 4 new procedure steps + 4 new halts may STOP chains)
- `memory` 1.2.1 → 1.3.0 (new schema: routing-outcomes.md)
- `generate-intent` 1.12.0 → 1.13.0 (Phase A handoff YAML closure + halt enum extension)
- `bind-codebase` 1.9.3 → 1.9.4 (Phase A handoff sweep)
- `detect-drift` 1.4.0 → 1.4.1 (Phase A handoff sweep)
- `diff-vault` 1.3.0 → 1.3.1 (Phase A handoff sweep + artifact list fix)
- `extract-intelligence` 1.4.0 → 1.4.1 (Phase A handoff sweep)
- `resolve-oq` 0.9.1 → 0.9.2 (Phase A handoff sweep + broken cross-ref fix)
- `emit-agents-md` 1.2.4 → 1.2.5 (Phase A config path fix)

**New plugin files (2):**
- `references/lib-patterns/...` (no new lib-patterns this iter)
- `skills/memory/references/routing-outcomes.md` — schema doc for orchestrator routing learning (F1)
- `skills/orchestrate-flow/references/predictive-checks.md` — catalog of preflight checks per skill (F2)

**New test files (1):**
- `tests/scenarios/scenario-9-flawless-seamless-intelligence.md` — full-pipeline F1+F2+F3+F4 integration

**New audit doc (1):**
- `docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md` — Phase B output (6 dimensions + 13-skill scorecard)

**Modified reference docs:**
- `handoff-contract.md` — + 4 missing per-skill sections (diff-vault/emit-agents-md/resolve-oq/detect-drift) + REQUIRED/CONDITIONAL/OPTIONAL annotations (F3) + TYPE annotations (F4)
- `vault-contract.md` — + 19 halt types (15 Iter 31 + 4 Iter 33) + descriptions + stale source_skill enum fix
- `memory-schema.md` — + routing-outcomes.md entry in PROJECT scope
- `paths.md` — + routing-outcomes.md path
- `from-prompt-mode.md` — fixed broken cross-refs (stale paths)
- `commands/scan-codebase.md` + `commands/emit-agents-md.md` — fixed legacy paths

**Phase A — Mechanical closure (~7-8hr):**

Closes 3 of Iter 31's top 5 closure areas focused on orchestrator + handoff foundation. Enables Phase C F3's stricter validation gate.

- A1: Handoff YAML schema sweep — 8 skill SKILL.md templates + handoff-contract.md gain missing top-level blocks (scope/mutability/constitution); 4 missing per-skill sections added
- A2: Halt taxonomy + vault-contract enum sync — 15 previously-unregistered halts synchronized across orchestrate-flow + vault-contract + handoff-contract
- A3: Stale name sweep — 102 stale references (grand-design-spec/vault-diff/drift-detect/.mega-sdd-memory/) replaced with canonical names across vault-contract enum, broken cross-refs, test fixtures, command files

**Phase B — Intelligence audit (~5-6hr):**

Hybrid method: 2 parallel sonnet subagents (deep audit + per-skill probe). Produces AUDIT-INTELLIGENCE.md covering 6 intelligence dimensions on orchestrate-flow + handoff-contract + 13-skill 0-3 context-utilization scorecard. Findings inform Phase C feature specifics.

**Phase C — 4 intelligence features (~12-15hr):**

Smart orchestrator:
- **F1 Memory-driven routing** (C1) — orchestrator reads routing-outcomes.md at Step 2.7; recommends past-successful chains; writes outcome row at Step 7.5
- **F2 Predictive halt detection** (C2) — orchestrate-flow Step 3.5 runs predictive-checks.md catalog; non-fatal failures = warning; fatal failures = predictive_check_failed halt

Solid handoffs:
- **F3 Schema validation gate** (C3) — orchestrate-flow Step 6.b validates every received handoff against handoff-contract.md REQUIRED/CONDITIONAL annotations; missing field = invalid_handoff halt
- **F4 Type-checked field propagation** (C4) — Step 6.b.i validates types against TYPE annotations; mismatch = handoff_type_mismatch halt

**4 new halt types** (synchronized across all 4 surfaces per audit-pattern-prevention checklist):
- `routing_outcome_corrupt` (F1, SOFT) — routing-outcomes.md parse failure; auto-invalidate; chain proceeds
- `predictive_check_failed` (F2, ALWAYS STOP) — fatal preflight check failed; user fixes precondition
- `invalid_handoff` (F3, ALWAYS STOP) — handoff schema validation failed; producer-side error
- `handoff_type_mismatch` (F4, ALWAYS STOP) — handoff field type mismatch; producer-side error

**Trigger test coverage (+12 cases):**
- orchestrate-flow: OF-MR1/2 + OF-PH1/2 + OF-VG1/2 + OF-TC1/2
- memory: M-RO1/2
- scan-codebase: SC-PH1
- bind-codebase: BC-PH1

**Iter 31 audit findings preemptively addressed:**
- Phase A1 closes 12 P1 from Dim 3
- Phase A2 closes 13 P1 from Dim 4
- Phase A3 closes Patterns 2 + 4 (stale names/paths)
- F3 PREVENTS recurrence of "field claimed in prose but missing in template" (root cause pattern)

**Iter 31 deferred to Iter 34:**
- Closure Area 3: execute-bolts Step 4.5 reorder + snapshot schema alignment (~3hr)
- Closure Area 5: Test fixture backfill remaining gaps

**Standing user directives applied:**
- "Seamless + super intelligent + flawless" → orchestrator now intelligent (F1+F2); handoffs now flawless (F3+F4)
- "Producer + consumer in-iter" → F1/F2/F3/F4 each ship producer+consumer in same iter
- "Reuse over reinvent" → Iter 30 shared-snapshot cache pattern (F1 fingerprint cache); canonical halt envelope (all 4 new halts); memory file-lock pattern (F1 routing-outcomes write); extract-intelligence wave dispatch pattern (Phase B audit subagents)

**Plugin:** v3.23.0 → v3.24.0

**Spec:** `docs/superpowers/specs/2026-05-24-iter-33-flawless-seamless-intelligence-design.md`
**Plan:** `docs/superpowers/plans/2026-05-24-iter-33-flawless-seamless-intelligence.md`
```

- [ ] **Step E.4: Add README "What's new in v3.24.0" subsection**

Edit `plugins/mega-sdd/README.md`. Add at top of existing "What's new" section:

```markdown
### v3.24.0 (Iter 33) — Flawless Seamless Intelligence

**Combined mega-iter:** orchestrator becomes intelligent + handoffs become flawless.

**What changed:**

Smart orchestrator:
- **F1 Memory-driven routing** — orchestrator now learns from past runs. After ≥3 successful runs of the same project shape, orchestrator recommends the proven chain (overriding default routing-rules.md). Fall-through silently for fresh projects.
- **F2 Predictive halt detection** — orchestrator runs lightweight preflight checks BEFORE invoking each skill in chain. Instead of "scan-codebase halted on dep_missing 8 min in", you see "before chain starts: tree-sitter not installed; install or use --engine=regex" — actionable upfront.

Solid handoffs:
- **F3 Schema validation gate** — every handoff YAML validated against handoff-contract.md at emission. Missing REQUIRED/CONDITIONAL field = `invalid_handoff` halt at producer side (immediate developer feedback, not silent consumer miss).
- **F4 Type-checked field propagation** — handoff-contract.md now declares TYPE annotations. Field type mismatch = `handoff_type_mismatch` halt. Prevents silent shape drift (e.g., scope.id being string in one skill but object in another).

**Phase A foundation:** closes 3 of Iter 31's audit areas (handoff YAML sweep + halt taxonomy sync + stale name sweep) to enable F3/F4 enforceability without breaking existing pipelines.

**Phase B audit:** `docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md` documents intelligence gaps across all 13 skills with prioritized Iter 34+ candidates.

**orchestrate-flow major bump v2.5.1 → v3.0.0:** new procedure steps + 4 new halts may stop chains where prior versions wouldn't (all backward-compat by default — fall-through on missing memory/checks/schema).

**Plugin v3.23.0 → v3.24.0.**

See [docs/superpowers/specs/2026-05-24-iter-33-flawless-seamless-intelligence-design.md](../../docs/superpowers/specs/2026-05-24-iter-33-flawless-seamless-intelligence-design.md) for full design.
```

- [ ] **Step E.5: Run final cross-reference verification**

Run:
```bash
echo "=== plugin.json version ==="
grep '"version"' plugins/mega-sdd/.claude-plugin/plugin.json

echo "=== Skill versions ==="
for skill in orchestrate-flow memory generate-intent bind-codebase detect-drift diff-vault extract-intelligence resolve-oq emit-agents-md; do
  echo "  $skill: $(grep '^version:' plugins/mega-sdd/skills/$skill/SKILL.md | head -1)"
done

echo "=== All 4 new halt types across 4 surfaces ==="
for halt in routing_outcome_corrupt predictive_check_failed invalid_handoff handoff_type_mismatch; do
  echo "  $halt:"
  echo -n "    vault-contract: "
  grep -c "$halt" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
  echo -n "    orchestrate-flow: "
  grep -c "$halt" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
done

echo "=== No stale skill names in plugin source ==="
echo -n "grand-design-spec: "; grep -rn "grand-design-spec" plugins/mega-sdd/ 2>/dev/null | wc -l
echo -n "vault-diff: "; grep -rn "vault-diff" plugins/mega-sdd/ 2>/dev/null | wc -l
echo -n "drift-detect: "; grep -rn "drift-detect" plugins/mega-sdd/ 2>/dev/null | wc -l

echo "=== CHANGELOG top entry ==="
head -10 CHANGELOG.md
```

Expected: plugin 3.24.0; orchestrate-flow 3.0.0; memory 1.3.0; all 4 halts ≥1 match per surface; stale names = 0 in plugin source.

- [ ] **Step E.6: Commit + push**

```bash
git add plugins/mega-sdd/.claude-plugin/plugin.json \
        CHANGELOG.md \
        plugins/mega-sdd/README.md \
        plugins/mega-sdd/skills/bind-codebase/SKILL.md \
        plugins/mega-sdd/skills/detect-drift/SKILL.md \
        plugins/mega-sdd/skills/diff-vault/SKILL.md \
        plugins/mega-sdd/skills/extract-intelligence/SKILL.md \
        plugins/mega-sdd/skills/generate-intent/SKILL.md \
        plugins/mega-sdd/skills/resolve-oq/SKILL.md \
        plugins/mega-sdd/skills/emit-agents-md/SKILL.md
git commit -m "$(cat <<'EOF'
release(iter-33): mega-sdd v3.24.0 — flawless seamless intelligence

Combined mega-iter (~28-33hr): 3-phase delivery closes Iter 31 audit debt
(Phase A) + hybrid intelligence audit (Phase B) + 4 intelligence features
(Phase C).

Smart orchestrator: F1 Memory-driven routing + F2 Predictive halt detection
Solid handoffs: F3 Schema validation gate + F4 Type-checked propagation

orchestrate-flow v2.5.1 → v3.0.0 (major). Plugin v3.23.0 → v3.24.0.

102 stale references (grand-design-spec/vault-diff/drift-detect/.mega-sdd-memory/)
replaced with canonical names. 19 halt types now synchronized across 4
surfaces (15 from Iter 31 + 4 new Iter 33). Handoff schema now machine-readable
with REQUIRED/CONDITIONAL/OPTIONAL + TYPE annotations.

User's "orchestrator pintar + handoff yang solid + flawless" directive
delivered: orchestrator now learns from past runs (F1) + warns upfront (F2);
handoffs now validated (F3) + type-checked (F4) at emission.
EOF
)"

git push origin main
```

- [ ] **Step E.7: Verify final state**

Run:
```bash
git log --oneline -15
```

Expected: ~10 Iter 33 commits visible (A1, A2, A3, B1, C1, C2, C3, C4, D, E release) at top, ending with the v3.24.0 release commit pushed to origin/main.

---

## Self-Review

### 1. Spec coverage

Iterating spec sections vs plan tasks:

| Spec section | Implementing task(s) |
|---|---|
| §1 Architecture overview (3-phase + version bumps) | Tasks A1-A3 (Phase A) + B1 (Phase B) + C1-C4 (Phase C) + E (release) |
| §1.3 Skill version bumps | E.2 (patch bumps for Phase A skills) + C1 (orchestrate-flow major + memory minor) |
| §2.1 Closure Area 1 (handoff YAML sweep) | A1 (all 8 skills + 4 missing per-skill sections in handoff-contract) |
| §2.2 Closure Area 2 (halt taxonomy + vault-contract enum sync) | A2 (15 halts across 3 surfaces) |
| §2.3 Closure Area 4 (stale name sweep) | A3 (102 stale refs replaced) |
| §3.1 Deep audit (6 dimensions) | B1.2 subagent 1 |
| §3.2 Per-skill probe (0-3 scorecard) | B1.2 subagent 2 |
| §3.3 AUDIT-INTELLIGENCE.md structure | B1.4 |
| §4.1 F1 Memory-driven routing | C1 (7 sub-files modified + 1 new file) |
| §4.2 F2 Predictive halt detection | C2 (1 new file + 2 modified + halt sync) |
| §4.3 F3 Schema validation gate | C3 (REQUIRED/CONDITIONAL/OPTIONAL annotations + Step 6.b) |
| §4.4 F4 Type-checked field propagation | C4 (TYPE annotations + Step 6.b.i) |
| §5.1 4 new halt types | A2 (15 closure halts) + C1 (routing_outcome_corrupt) + C2 (predictive_check_failed) + C3 (invalid_handoff) + C4 (handoff_type_mismatch) |
| §5.4 Testing strategy | D (12 trigger tests + scenario-9) |
| Acceptance criteria 1-13 | E.5 verification covers most; D covers tests; A1-A3 cover Phase A criteria |

**Gaps found:** None. All spec sections mapped to plan tasks.

### 2. Placeholder scan

Searched plan for `TBD`, `TODO`, `implement later`, `fill in details`, `appropriate error handling`, `handle edge cases`, `Similar to Task N`:
- Result: zero matches. All steps have concrete content + exact code/text.

### 3. Type consistency

Checked names across tasks:
- `routing-outcomes.md` (lowercase, dash, .md extension) — consistent across C1, D, E
- 4 new halt type names — consistent verbatim across A2, C1-C4, D, E (no typos)
- Step numbers (Step 2.7, Step 3.5, Step 6.b, Step 6.b.i, Step 7.5) — consistent across C1-C4 + D test cases
- Skill versions: orchestrate-flow 3.0.0 + memory 1.3.0 + 7 patch bumps — consistent across C1, E
- Plugin v3.24.0 — consistent across E.1 + E.3 + E.4

**Issues found + fixed inline:** None.

---

**End of plan.**

Total tasks: 10
Estimated execution time: ~28-33 hours total
- Phase A (3 tasks): ~7-8hr (A1 ~3hr, A2 ~2hr, A3 ~2-3hr)
- Phase B (1 task): ~5-6hr (B1)
- Phase C (4 tasks): ~12-15hr (C1 ~3hr, C2 ~3hr, C3 ~3hr, C4 ~3hr)
- Final (2 tasks): ~3-4hr (D tests ~2-3hr, E release ~1hr)

Risk areas:
- Task A1 (handoff sweep): 9 skill modifications in 1 commit; risk of partial completion. Mitigation: Step A1.12 verification before A1.13 commit.
- Task A3 (stale name sweep): 102 stale refs across many files; risk of grep-and-replace breaking back-compat language. Mitigation: scope to plugin source + tests; leave docs/ historical refs intact.
- Task C3 (validation gate): could regress every existing pipeline if Phase A1 didn't fully close handoff gaps. Mitigation: Phase A is prerequisite; D OF-VG1 happy-path test catches regression.
- Task C4 (type-check): too-strict types could fail legitimate handoffs. Mitigation: fields without TYPE annotation bypass type check (warn-only); gradual rollout per §4.4 backward-compat note.
- Mega-iter scope: 10 tasks × subagent-driven execution = ~30 hours wall-clock. Mitigation: 3-phase atomic structure allows partial ship (Phase A alone = useful baseline).
