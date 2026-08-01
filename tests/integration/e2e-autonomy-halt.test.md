# E2E: Autonomy Layer — Halt and Resume (Iter 4)

End-to-end integration test for `--deep` mode halting on a blocker, user resolving, and resuming via `--resume`.

## Fixture

**Repo state**: Brownfield Laravel project at `./fixtures/e2e-autonomy-halt-fixture/`:
- Existing `User` model + `UserController` with `index` and `show` methods
- `prd-extend-user.md` PRD claims `POST /api/users` uses Bearer auth — codebase uses session cookies (intentional CONFLICT injection)
- No existing vault

## Test steps

### Step 1: Initial invocation
**Run:** `/mega-sdd:auto ./fixtures/e2e-autonomy-halt-fixture/prd-extend-user.md --deep`

**Expect**:
- Chain proposed: 5 phases (PRD → vault → scan → bind → units → bolts)
- User confirms

### Step 2: Chain progresses through Phase 1-2, halts at Phase 3
**Expect chat**:
```
▶ Phase 1 of 5: invoking generate-intent (./fixtures/.../prd-extend-user.md --auto)
✓ Phase 1 of 5: generate-intent → status: completed, items: 8 OQs, blocked: 0

▶ Phase 2 of 5: invoking scan-codebase (./ --auto)
✓ Phase 2 of 5: scan-codebase → status: completed

▶ Phase 3 of 5: invoking bind-codebase (./vault-path/ --auto)
⛔ Phase 3 of 5: bind-codebase → status: halted, items: 24 claims, blocked: 1

Blocker:
type: bind_conflict
emitted_at: 2026-05-20T...
emitted_by: bind-codebase
details:
  vault: ./vault-path/
  conflict_count: 1
  conflicts:
    - id: C-007
      vault_claim: "POST /api/users uses Bearer auth"
      codebase_reality: "Session cookies (Laravel session middleware)"
      suggested_action: KEEP_VAULT | KEEP_CODE | DEFER | SPLIT
next_action: "Run /mega-sdd:resolve-oq --binding /path/to/binding.md"

Chain stopped. Resolve the blocker and run /mega-sdd:auto --resume to continue.
```

### Step 3: User resolves the conflict
**Run:** `/mega-sdd:resolve-oq --binding /path/to/binding.md`

User decides KEEP_CODE (legacy auth stays; vault rewritten). resolve-oq updates vault + binding.md.

### Step 4: Resume via --resume
**Run:** `/mega-sdd:auto --resume`

**Expect chat**:
```
(No upfront confirmation — chain was approved at Step 1)

Re-inspecting CWD state...
- vault.json: present
- codebase-map.md: present
- binding.md: present (conflict_count: 0 after resolve-oq)
- vault-bound/: absent  ← cursor lands here

Resuming chain from Phase 3 of 5 (bind-codebase re-runs to produce bound-vault).

▶ Phase 3 of 5: invoking bind-codebase (./vault-path/ --auto)
✓ Phase 3 of 5: bind-codebase → status: completed, items: 24 claims, blocked: 0
   (vault-bound/ produced; conflict resolved via KEEP_CODE)

▶ Phase 4 of 5: invoking generate-units (./vault-bound/ --auto)
✓ Phase 4 of 5: generate-units → status: completed, items: 9 units, blocked: 0
   (9 units: 2 verify (existing User CRUD) + 7 create (new endpoints))

▶ Phase 5 of 5: invoking execute-bolts (--all --parallel --auto)
... (executes 9 units with pre/post-flight)
✓ Phase 5 of 5: execute-bolts → status: completed, items: 9 units, blocked: 0

📋 Final summary:
   Phases completed: 5 of 5 (Phase 3 ran twice — initial halt + post-resolve)
   Phases paused: 0
   Phases halted: 0 (after resolve)
   ...
```

## Validation checks

### V1: Halt preserves working state
- After Step 2 halt: vault exists, codebase-map exists, binding.md exists, vault-bound/ DOES NOT EXIST
- No silent code changes were committed (chain halted at binding phase before any code-write phases ran)

### V2: Blocker surfaced verbatim
- Blocker YAML in chat matches the structure in `plugins/mega-sdd/references/halt-protocol.md` §halt-protocol
- `next_action` field gives concrete resolution path

### V3: --resume skips upfront confirmation
- Step 4 invocation does NOT show an `AskUserQuestion` chain confirmation
- Chain re-runs CWD inspection and lands cursor on bind-codebase (the previously-halted phase)

### V4: CWD-driven cursor (no state file)
- No persistent `.mega-sdd-state.json` or similar file exists
- Cursor position derives PURELY from artifact presence in CWD
- If user manually deleted `binding.md` between Step 3 and Step 4, cursor would re-run scan-codebase too (correct behavior — CWD is the source of truth)

### V5: Halt re-fires if blocker unresolved
- Alternative path: user does NOT run resolve-oq between Step 2 and Step 4
- `/mega-sdd:auto --resume` re-runs bind-codebase
- Same `bind_conflict` blocker fires identically
- User CANNOT bypass a halt by re-invoking — safety net is preserved

## Pass criteria

All steps execute as described. V1-V5 validate that halt protocol is preserved, resume is CWD-driven, and no persisted state file exists. Total wall-clock: ≤ 15 minutes including resolve-oq interactive walk.
