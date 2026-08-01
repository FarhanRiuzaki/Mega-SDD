# E2E: Iter 6 Tech Upgrades — Full Pipeline (5 Swaps)

End-to-end integration test validating all 5 Iter 6 swaps working together in a single chain run.

## Fixture

**Repo state**: Brownfield Laravel project at `./fixtures/e2e-iter6-fixture/`:
- Existing User model + UserController (matches Iter 1 e2e fixture)
- PRD `prd-extend-user.md` adds new audit-log feature
- Pre-installed: tree-sitter CLI + ast-grep CLI

## Test steps

### Step 1: Invocation
**Run:** `/mega-sdd:auto ./fixtures/e2e-iter6-fixture/prd-extend-user.md --deep`

**Expect chain proposal**:
```
Proposed pipeline (--deep):
  1. generate-intent → vault
  2. scan-codebase → codebase-map.md (engine: tree-sitter)
  3. bind-codebase → binding.md + bound-vault
  4. generate-units → units/ (with PageRank suggestions)
  5. execute-bolts → bolts (with ast-grep v2 Hard Rules)
  6. emit-agents-md → AGENTS.md (auto-emit at chain end)
```

User confirms.

### Step 2: Phase 2 (scan-codebase) uses tree-sitter

**Expect chat**:
```
▶ Phase 2 of 6: invoking scan-codebase (./ --auto)
  Engine: tree-sitter (detected via `command -v tree-sitter`)
  Grammars loaded: typescript, php
  ...
✓ Phase 2 of 6: scan-codebase → status: completed, precision_tier: ast
```

**Verify** `codebase-map.md` frontmatter:
```yaml
engine: tree-sitter
precision_tier: ast
tree_sitter_version: <version>
grammars_used: ["php"]
```

### Step 3: Phase 4 (generate-units) emits PageRank suggestions

**Expect** units have a new `## PageRank suggestions` section:
```markdown
## PageRank suggestions (review)

Files ranked highly relevant by symbol-graph analysis:
- `app/Http/Middleware/Authenticate.php` (rank: 0.42, refs to: User model)
- `tests/Feature/AuthTest.php` (rank: 0.31, refs to: existing auth tests)
...

ACTION: Review each. To promote any to `target_files`, edit the unit's `target_files:` frontmatter list manually.
```

**Verify** suggestions did NOT auto-add to `target_files` frontmatter (anti-halu rail).

### Step 4: Phase 5 (execute-bolts) validates ast-grep v2 rules

**Setup**: unit U-003 has v2 Hard Rule:
```yaml
id: do-not-modify-user-php
language: php
rule:
  pattern: $$$
  inside:
    file: app/Models/User.php
```

**Expect chat**:
```
▶ Phase 5 of 6: invoking execute-bolts (--all --parallel --auto)
  Hard Rule grammar: v2 (ast-grep detected)
  Pre-flight: 3 rules parsed, 3 snapshots captured
  ...
  Post-flight: validating rule do-not-modify-user-php... PASSED
  ...
✓ Phase 5 of 6: execute-bolts → status: completed
```

### Step 5: Phase 6 (emit-agents-md) writes AGENTS.md

**Expect**: `<repo-root>/AGENTS.md` written with mega-sdd marker + sections per `agents-md-schema.md`.

**Verify** AGENTS.md contains:
- Project overview (from vault 01-overview.md)
- Build commands (from conventions.md)
- Test commands (from conventions.md: phpunit)
- Architecture overview (from vault 02-architecture.md)
- Key decisions (from vault 05-decisions.md ADRs)
- Open questions (from vault 00-index.md OQ roll-up)
- Mega-sdd interop notes

### Step 6: Mid-skill resume (Swap #5)

**Setup**: simulate bind-codebase crash at claim 30 of 50 (via SIGKILL after checkpoint write)

**Verify** `<vault>/.mega-sdd/checkpoints/<timestamp>-bind-codebase-claim-30.jsonl` exists with cursor state.

**Run**: `/mega-sdd:auto --resume`

**Expect**:
- No upfront confirmation (chain was approved at Step 1)
- Orchestrator reads checkpoint; identifies bind-codebase incomplete at claim 30
- Re-invokes bind-codebase with `--resume-from=claim-30`
- bind-codebase resumes from claim 31; processes remaining 20 claims
- Chain continues to phases 4-6 per Iter 4 handoff YAML protocol

## Validation checks

### V1: All 5 swaps active end-to-end
- ✅ tree-sitter precision_tier in codebase-map.md
- ✅ PageRank suggestions block in unit body
- ✅ ast-grep v2 Hard Rule pre/post-flight in bolt-report.md
- ✅ AGENTS.md generated at repo root
- ✅ Checkpoint JSONL files in `<vault>/.mega-sdd/checkpoints/`

### V2: Anti-halu rails preserved
- ✅ No silent rewrites (PageRank suggestions never auto-added)
- ✅ Hard Rule violations halt the run detect-after (bolt commit already landed; every further `execute-bolts` blocked until fixed-forward or reverted)
- ✅ AGENTS.md does NOT invent info absent from vault
- ✅ Tree-sitter parses are deterministic (re-run same scan → same output)
- ✅ Checkpoint replay is deterministic (same cursor state → same skill output)

### V3: Backward compat
- ✅ Vault without checkpoints/ dir → CWD-driven resume still works
- ✅ Re-run with `--engine=regex` flag forces v1 scan path
- ✅ Re-run with `--hard-rule-grammar=v1` forces v1 Hard Rules

### V4: Graceful degradation
- ✅ Tree-sitter not installed → regex fallback with warning
- ✅ ast-grep not installed AND unit has v2 rules → halt with install commands
- ✅ PageRank skipped when precision_tier: regex (no halt; warning only)
- ✅ AGENTS.md emission skipped when config flag `defaults.emit_agents_md: false`

## Pass criteria

Steps 1-6 succeed. V1-V4 validation checks all pass. Wall-clock time: ≤15 minutes (depends on test suite size).
