# Learning Rules — Threshold-Based Self-Learning

Self-learning in mega-sdd is **suggestion-only** (design lock). This document defines:

1. Observation patterns mega-sdd tracks
2. Thresholds before a suggestion fires
3. Suggested actions per pattern type
4. Audit log format + rollback path

---

## Contents

- 1. Threshold table
- 2. Observation patterns mega-sdd tracks
- 3. Suggestion review flow (`/mega-sdd:memory review`)
- 4. Audit log format (`~/.mega-sdd/memory/learning-log.md`)
- Learning #N — <ISO8601 timestamp>
- 5. Rollback path
- 6. Anti-halu rails
- 7. References

## 1. Threshold table

All thresholds are user-configurable via `~/.mega-sdd/memory/config.yaml` (per MEMORY-OQ-4 resolved). Defaults below:

| Observation pattern | Default threshold | Confidence min | Scope |
|---|---|---|---|
| Classifier override on same pattern X | 5 per-project OR 3 cross-project | 0.80 | per-project → user (via promote) |
| User picks same CONFLICT resolution on similar conflicts | 5 within same project OR 3 cross-project | 0.80 | per-project → user |
| Hard Rule Z violated AND reverted (not auto-fixed) | 3 reverts | 0.66 | per-vault → project |
| Recommendation REJECT on category C | 3 rejects | 0.66 | per-project |
| Convention X detected consistently across runs | 2 scan runs | 1.00 (binary) | per-project |
| Flag F picked same value across runs | 5 runs | 0.80 | per-user (cross-project) |
| Drift direction D on same fingerprint class | 3 same-direction resolutions | 0.80 | per-vault |
| Sync write-back class consistently ACCEPTed | 3 consecutive sync runs | 1.00 (binary) | per-project |
| Acceptance-test concern C recurs across bolts | 3 bolts | 0.66 | per-vault → project |

Thresholds higher than 5 hits = conservative; lower thresholds = aggressive learning. Configure per use case.

**When thresholds are evaluated (owned step — not implied):** orchestrate-flow runs the threshold pass ONCE at chain end (Step 7.6 extract-learnings) over the rows touched this chain, appending threshold-crossing candidates to `## Pending suggestions` with `status: pending`. `/mega-sdd:memory review` also evaluates on demand. No skill evaluates thresholds mid-chain.

## 2. Observation patterns mega-sdd tracks

### 2.1 Classifier override pattern

**Source**: `<vault>/.memory/classifier-accuracy.json` `user_overrides` array
**Pattern key**: combination of (auto_tag, user_tag, regex over OQ text)
**Aggregation**: per-vault initially; promoted to project when threshold hit; promoted to user via explicit `mega-sdd:memory promote`
**Suggested action**: Update `generate-intent/references/vault-contract.md` heuristic table

Example:
```yaml
observation:
  pattern_key: "tech_recommend_medium → business_blocking_high on text matching 'should we (support|allow|enable)'"
  occurrences: 7
  projects: ["proj-a", "proj-b", "proj-c"]
  confidence: 0.875
suggestion:
  action: "Add to vault-contract.md heuristic table: 'should we (support|allow|enable)' → category: business, resolution_mode: blocking"
  effective_after_accept: "next generate-intent runs"
```

### 2.2 CONFLICT resolution pattern

**Source**: `<project>/.mega-sdd/memory/decisions.md` `## CONFLICT resolutions` table
**Pattern key**: regex over the conflict claim text + resolution choice
**Aggregation**: per-project; promote to user-scope `patterns.md` when 3+ projects show same pattern
**Suggested action**: Pre-fill that resolution in resolve-oq's AskUserQuestion (user still confirms each time)

Example:
```yaml
observation:
  pattern_key: "claim matching 'auth|session|login|token' → KEEP_CODE"
  occurrences: 8
  total_relevant: 10
  confidence: 0.80
  projects: ["proj-a", "proj-b"]
suggestion:
  action: "Pre-fill KEEP_CODE in resolve-oq --binding when claim matches 'auth|session|login|token'"
  effective_after_accept: "next resolve-oq runs"
```

### 2.3 Hard Rule violation + revert pattern

**Source**: `<vault>/.memory/bolt-outcomes.json` `bolts[].violated_rules` + `bolts[].resolution`
**Pattern key**: rule string + resolution type
**Aggregation**: per-vault; promote to project when same rule violated and reverted 3+ times across vaults
**Suggested action**: Propose removing the rule from Suggested Unit Hard Rules (bind-codebase emits fewer)

Example:
```yaml
observation:
  pattern_key: "rule 'DO NOT modify src/Models/User.php' violated AND user_edited_unit"
  occurrences: 4
  confidence: 1.00
  vaults: ["v1", "v2", "v3", "v4"]
suggestion:
  action: "Remove 'DO NOT modify src/Models/User.php' from bind-codebase Suggested Unit Hard Rules; the rule consistently obstructs intended extensions"
  effective_after_accept: "next bind-codebase runs (rule still allowed if manually added to unit)"
```

### 2.4 Recommendation REJECT pattern

**Source**: `<project>/.mega-sdd/memory/decisions.md` `## Recommendation outcomes` table
**Pattern key**: recommendation category + REJECT action
**Aggregation**: per-project
**Suggested action**: Flip default `resolution_mode` from `recommend` to `blocking` for that category (user MUST decide)

Example:
```yaml
observation:
  pattern_key: "category 'library version' recommendations → REJECT"
  occurrences: 3
  total_relevant: 3
  confidence: 1.00
suggestion:
  action: "Update vault-contract.md heuristic: 'which version of X' → category: business / blocking (was: tech / recommend)"
  effective_after_accept: "next generate-intent runs"
```

### 2.5 Convention detection pattern

**Source**: `<project>/.mega-sdd/memory/conventions.md` confirmation count
**Pattern key**: convention name + detected value
**Aggregation**: per-project across scan-codebase runs
**Suggested action**: Promote convention from "detected" to "established"; auto-include in scan-codebase output without re-detection

Example:
```yaml
observation:
  pattern_key: "test framework = phpunit"
  occurrences: 3
  status: "consistent across runs"
  confidence: 1.00
suggestion:
  action: "Mark phpunit as 'established' in conventions.md; scan-codebase emits stable signal without re-probing"
  effective_after_accept: "next scan-codebase runs"
```

### 2.6 Flag value pattern

**Source**: `~/.mega-sdd/memory/preferences.md` `## Flag defaults` table
**Pattern key**: flag name + most-picked value
**Aggregation**: per-user (cross-project)
**Suggested action**: Update Claude Code's `AskUserQuestion` to pre-select that value

Example:
```yaml
observation:
  pattern_key: "OUTPUT_MODE = compact"
  occurrences: 5
  total: 5
  confidence: 1.00
suggestion:
  action: "Pre-fill OUTPUT_MODE = compact at Step 0.7; still ask user to confirm"
  effective_after_accept: "next generate-intent runs"
```

### 2.7 Drift direction pattern

**Source**: `<vault>/.memory/drift-history.md` `## Direction calls` table
**Pattern key**: drift fingerprint class (`<category>:<vault-section>:*` — class, not exact name) + direction
**Aggregation**: per-vault
**Suggested action**: Pre-fill that direction in detect-drift Step 5 / the PENDING-SYNC.md entry (`source: drift-history, n=N`). **Never auto-resolves** — under `--auto` the finding still queues; the suggestion rides along.

```yaml
observation:
  pattern_key: "name-drift:03-data-model:* → code_right"
  occurrences: 3
  confidence: 1.00
suggestion:
  action: "Pre-fill direction=code_right for name-drift findings in 03-data-model (user still confirms)"
  effective_after_accept: "next detect-drift runs on this vault"
```

### 2.8 Sync write-back class pattern

**Source**: `<project>/.mega-sdd/memory/outcomes.md` `kind: sync` rows
**Pattern key**: safe write-back class queued AND later ACCEPTed unchanged, 3 consecutive sync runs
**Aggregation**: per-project
**Suggested action**: Default `--auto-apply=safe` for `/mega-sdd:sync` in this project. This widens the autonomy surface — it fires as ONE suggestion and applies ONLY on explicit ACCEPT (recorded in learning-log.md; rollback per §5).

### 2.9 Acceptance-test concern recurrence

**Source**: `<vault>/.memory/bolt-outcomes.json` `bolts[].concerns`
**Pattern key**: normalized concern text class across bolts
**Aggregation**: per-vault; promote to project when the same class recurs in 2+ vaults
**Suggested action**: Surface as a generate-units advisory ("3 bolts flagged brittle column-order assertions — consider a unit Hard rule or test-helper note"); NEVER edits units automatically.

---

## 3. Suggestion review flow (`/mega-sdd:memory review`)

1. Read `~/.mega-sdd/memory/patterns.md` `## Pending suggestions` section
2. For each pending suggestion:
   - Show via `AskUserQuestion`:
     - **Question**: "Mega-SDD observed pattern X (Y times, confidence Z). Suggested action: <action>. ACCEPT?"
     - **Options**: ACCEPT / REJECT / DEFER
3. On ACCEPT:
   - Write entry to `~/.mega-sdd/memory/learning-log.md`
   - Update target heuristic file (e.g., add row to vault-contract.md auto-classifier table, set config.yaml `applied:` entry)
   - Mark suggestion in patterns.md as `status: accepted` (don't delete; audit trail)
4. On REJECT:
   - Write entry to learning-log.md as `user_decision: REJECT` + capture `user_reason` if provided
   - Mark suggestion as `status: rejected`
   - Same observation won't re-trigger suggestion (filtered by `learning-log.md` history)
5. On DEFER:
   - Increment `deferred_count`
   - If `deferred_count > 3` → auto-prune (likely irrelevant)

## 4. Audit log format (`~/.mega-sdd/memory/learning-log.md`)

Every accepted / rejected / rolled-back learning gets a chronological entry:

```markdown
## Learning #N — <ISO8601 timestamp>

- **Pattern**: <pattern key>
- **Source observations**: <citations — file paths + row numbers>
- **Suggested action**: <action description>
- **User decision**: ACCEPT | REJECT | DEFER
- **User reason** (if REJECT or DEFER): <optional>
- **Applied to** (if ACCEPT): <target file + key + value>
- **Effective from**: <ISO8601 date>
- **Rollback**: To revert this learning, set `rolled_back_at: <date>` below. Mega-sdd will skip this learning rule going forward.
```

## 5. Rollback path

To roll back an accepted learning:

1. Edit the relevant `## Learning #N` block in `learning-log.md`
2. Add field at bottom: `rolled_back_at: <ISO8601>`
3. Add reason: `rollback_reason: <text>`
4. Save. Mega-sdd reads this on next session start and treats the learning as inactive.

The original learning effects (e.g., heuristic table update) may need manual reversal. The learning-log entry documents both directions.

## 6. Anti-halu rails

- **No silent learning**. Every change requires explicit user ACCEPT.
- **Audit trail mandatory**. Even rejected/deferred suggestions logged.
- **Rollback always available**. No "permanent" learning.
- **Confidence threshold**. Suggestions only fire when consistency ratio ≥ `confidence_minimum` (default 0.80).
- **Conservative defaults**. When in doubt, propose MORE work (more OQs, more confirmations) rather than less.
- **Cross-project promotion explicit**. Project-scope patterns NEVER auto-promote to user-scope; explicit `mega-sdd:memory promote` required.
- **Memory contradicts current evidence → current evidence wins**. Memory is suggestion only; current binding / scan results are authoritative.

## 7. References

- `references/memory-schema.md` — file formats + scope architecture
- `docs/superpowers/specs/2026-05-21-memory-self-learning-design.md` — design rationale + 7 MEMORY-OQ resolutions
