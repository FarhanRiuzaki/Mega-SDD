# E2E: Memory Layer + Self-Learning (Iter 5)

End-to-end test for memory accumulation across multiple pipeline runs + threshold-based self-learning suggestion firing + rollback path.

## Fixture

**Repo state**: Laravel project at `./fixtures/e2e-memory-fixture/`:
- Existing User model + UserController (read endpoints)
- Auth flow uses session cookies (intentional pattern for repeated CONFLICT testing)
- 5 PRDs available: `prd-feature-1.md` through `prd-feature-5.md`
- Each PRD has at least one claim that produces a CONFLICT with the existing auth pattern (vault says Bearer auth; code uses session)

## Scenario A — Memory accumulation across 5 runs

### Run 1
**Run:** `/mega-sdd:auto ./fixtures/e2e-memory-fixture/prd-feature-1.md --deep`

**Expect chain progresses through:**
1. generate-intent → vault produced with ~10 OQs (mix business/tech)
2. scan-codebase → codebase-map written; conventions detected (phpunit, PascalCase)
3. bind-codebase → CONFLICT on auth claim (C-001); chain halts

**User action:** `/mega-sdd:resolve-oq --binding` → KEEP_CODE on C-001

**Run:** `/mega-sdd:auto --resume` → completes through bolts

**Validate memory writes after Run 1:**
- `<project>/.mega-sdd-memory/decisions.md` exists with 1 row in `## CONFLICT resolutions` (KEEP_CODE on auth pattern)
- `<project>/.mega-sdd-memory/conventions.md` exists with 2 detected conventions
- `<project>/.mega-sdd-memory/outcomes.md` exists with 1 run entry
- `<vault>/.memory/bind-history.md` has 2 entries (initial halt + post-resolve)
- `<vault>/.memory/classifier-accuracy.json` has 1 run entry
- `<vault>/.memory/bolt-outcomes.json` has bolt entries per unit
- `~/.mega-sdd/memory/preferences.md` has flag tally

### Runs 2-5
Same flow with different PRDs (each producing same auth CONFLICT pattern).

After each run, user picks KEEP_CODE on the auth conflict.

**Validate memory accumulates correctly:**
- After Run 2: decisions.md has 2 CONFLICT rows (both KEEP_CODE on auth)
- After Run 3: 3 rows
- After Run 4: 4 rows
- After Run 5: 5 rows (threshold hit per learning-rules.md §2.2 default threshold=5)

### Threshold fire after Run 5

**Expect:**
- `~/.mega-sdd/memory/patterns.md` `## Pending suggestions` section now has entry:
  ```
  - **#N** On next CONFLICT matching pattern `auth|session|login|token`: pre-fill KEEP_CODE in resolve-oq AskUserQuestion. Source: 5/5 observations in current project. Confidence: 1.00.
  ```
- `using-mega-sdd` anchor surfaces in next session: "Mega-SDD has 1 pending learning suggestion. Review now via `/mega-sdd:memory review`?"

## Scenario B — Accept learning + verify it applies

### Run 6: `/mega-sdd:memory review`

**Expect:**
- Walk pending suggestion via `AskUserQuestion`
- Show: pattern, source observations (5/5), confidence (1.00), suggested action
- Options: ACCEPT / REJECT / DEFER

**User action:** ACCEPT

**Expect:**
- `~/.mega-sdd/memory/learning-log.md` gets new entry "## Learning #1 — <date>"
- `~/.mega-sdd/memory/config.yaml` `applied:` section updated
- `patterns.md` suggestion marked `status: accepted`

### Run 7: New PRD with same auth pattern
**Run:** `/mega-sdd:auto ./fixtures/.../prd-feature-6.md --deep`

**Expect:**
- Chain reaches bind-codebase
- CONFLICT detected on auth claim
- bind-codebase passes resolution suggestion via blocker YAML `next_action.suggested_resolution: KEEP_CODE`
- Chain halts (CONFLICT still blocks; memory doesn't bypass safety)

**User runs resolve-oq:**
- AskUserQuestion shows KEEP_CODE **pre-filled** as default (per learning #1)
- Citation in prompt: "Past pattern (5/5): KEEP_CODE on auth conflicts. Per learning #1 in `learning-log.md`."
- User accepts default → KEEP_CODE applied

## Scenario C — Rollback

### Run 8: User edits learning-log.md to roll back

**User action:** Edit `~/.mega-sdd/memory/learning-log.md` Learning #1 block; add `rolled_back_at: <date>`

**Run 9: New PRD with same auth pattern**

**Expect:**
- bind-codebase HALT with CONFLICT (same as before)
- resolve-oq AskUserQuestion does NOT pre-fill KEEP_CODE anymore
- Available options shown without bias
- Citation noted: "Learning #1 was rolled back; no default suggestion"

## Scenario D — `--memory-off` graceful degradation

**Run 10:** `/mega-sdd:auto ./fixtures/.../prd-feature-7.md --deep --memory-off`

**Expect:**
- NO memory reads (no "past pattern: ..." messages)
- NO memory writes (memory files line counts unchanged after run)
- Pipeline output IDENTICAL to a hypothetical fresh-no-memory run
- Halt blockers fire identically (CONFLICT on auth still blocks; memory off doesn't bypass safety)

## Scenario E — Cross-vault project consistency

**Setup:** Run scenario A on vault-1, then create vault-2 in same project for a different feature

**Run 11:** `/mega-sdd:auto ./fixtures/.../prd-different-feature.md --deep` (new vault)

**Expect:**
- generate-intent reads `<project>/.mega-sdd-memory/conventions.md`
- Detects established conventions (phpunit, PascalCase)
- Auto-classifier downgrades OQs about those conventions from `tech/recommend` to `tech/scan` (since the convention is established)
- scan-codebase skips verbose re-detection (still verifies signal, but doesn't re-emit detection log)
- Faster chain run; identical safety guarantees

## Scenario F — Memory survives vault archival

**User action:** Delete vault-1 directory

**Expect (per MEMORY-OQ-5 resolved (b) archive):**
- Vault-scope `.memory/` files moved to `<project>/.mega-sdd-memory/archived-vaults/<vault-id>/`
- Audit trail preserved
- Future patterns referenced via archived bind-history continue to work

## Pass criteria

Scenarios A-F all execute as described. Memory layer accumulates correctly. Threshold-based suggestion fires after 5 observations. ACCEPT applies learning; rollback reverts. `--memory-off` disables both directions cleanly. Cross-vault project context works. Vault archival preserves memory.

All anti-halu invariants from `skills/memory/references/learning-rules.md` §6 verified across the scenarios.
