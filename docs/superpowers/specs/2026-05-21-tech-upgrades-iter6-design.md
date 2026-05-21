# Tech Upgrades — Iter 6 (Tree-sitter + ast-grep + PageRank + AGENTS.md + Checkpoint-graph)

**Status**: Proposed (design only; awaiting execution kickoff)
**Date**: 2026-05-21
**Author**: Farhan Riuzaki (via Claude collaboration)
**Builds on**: Iters 1-5 (all shipped in plugin 2.1.0)
**Research base**: deep-search agent landscape report (Aider, ast-grep, Plandex, LangGraph, AGENTS.md ecosystem)
**Targets**: scan-codebase, generate-units, execute-bolts, orchestrate-flow, bind-codebase, + 1 new skill
**Plugin version affected**: 2.1.0 → 3.0.0 (major — new native binary deps; Hard Rule grammar v2)

---

## 1. Motivation

Research validates mega-sdd's architectural direction:
- **Cline (62k ⭐) Plan-vs-Act** ≡ our vault→bolt split
- **GitHub Spec Kit (104k ⭐) 4-phase gated workflow** ≡ our intent→bind→units→bolts
- **AGENTS.md (LF-backed, 60k+ repos)** ≡ our vault as machine-readable contract
- **Aider's repo-map** ≡ what we'd do better with tree-sitter
- **Anthropic memory tool** ≡ our markdown-driven memory philosophy

But: 3 specific subsystems use weaker tech than the state of the art. This iter swaps the engine without changing the architecture.

### Pain points to fix

1. `scan-codebase` uses regex/grep → AST imprecision. Aider proves tree-sitter is the right answer.
2. Hard Rule grammar v1 is bespoke 5-type → limited expressivity. ast-grep YAML rules give 5-10× expressivity + fix templates + single Rust binary.
3. `generate-units` populates `target_files` from manual binding citations → no symbol-graph awareness. PageRank-on-symbol-graph (Aider) auto-ranks candidates.
4. Vault output is mega-sdd-specific → no interop with the 60k-repo AGENTS.md ecosystem.
5. `--resume` is CWD-driven → can't resume mid-skill failures. LangGraph-style checkpoint-per-step closes the gap.

## 2. Critical assessment (anti-patterns confirmed)

Per research report §4, the following are REJECTED for Iter 6:

- Vector embeddings (ruflo / mem0 / Continue's `@codebase`) — fuzzy by definition; conflicts with citation discipline
- CodeQL semantic DB — minutes-long DB build, GitHub-coupled, Datalog learning curve
- Multi-agent crew frameworks (CrewAI / AutoGen) — solving wrong problem (coordination ≠ correctness)
- DSPy auto-optimization — needs train set + Python runtime (we borrow the *concept* of typed signatures only — already done in handoff YAML)
- Docker-sandboxed runtimes (OpenHands) — kills "single plugin, no infra" invariant
- Semgrep ruleset adoption — Dec-2024 license shift; ast-grep cleaner long-term

## 3. Goals + Non-goals

### Goals

1. Replace regex-based codebase scanning with tree-sitter AST parsing.
2. Replace bespoke Hard Rule grammar with ast-grep YAML rules (backward-compat for v1 grammar via auto-migration on first run).
3. Add PageRank-on-symbol-graph ranking for `generate-units` target_files population.
4. Emit AGENTS.md as a thin compatibility veneer (vault + binding → AGENTS.md format).
5. Add per-skill checkpoint files for genuine mid-skill resume.
6. Backward compatibility: existing v2.1 vaults / projects / units continue to work.
7. Anti-halu invariants preserved (all 8 layers across all iters).

### Non-goals

- Replace Claude Code skill plugin architecture.
- Adopt multi-agent crew patterns.
- Add vector indexing for code search.
- Move away from markdown / JSON to binary memory formats.
- Replace Anthropic Claude as the LLM.
- Add runtime dependency on Python or Node.

## 4. The five swaps

### 4.1 Swap #1 — Tree-sitter for `scan-codebase`

**Current**: regex/grep extraction in `scan-codebase` Procedure §5-9. Misses:
- Magic methods / metaprogramming
- Multi-line function definitions in some langs
- Decorators / annotations precision

**New**: tree-sitter via single ~5MB native binary distributed by user's package manager (homebrew, apt, cargo install, etc.). Skill detects via `which tree-sitter` or `command -v`; falls back to v1 regex if absent.

**Architecture**:
```
plugins/mega-sdd/skills/scan-codebase/
├── SKILL.md                       # version 1.2 → 2.0
├── references/
│   ├── codebase-map-schema.md     # output schema unchanged; precision tier added
│   └── tree-sitter-integration.md # NEW: how to invoke, query files, fallback
└── queries/                       # NEW directory
    ├── tags.scm                   # adapted from Aider's tags.scm
    ├── tags-typescript.scm
    ├── tags-php.scm
    ├── tags-python.scm
    ├── tags-rust.scm
    └── tags-go.scm
```

**Distribution strategy** (per DESIGN-OQ-1):
- Document tree-sitter install in plugin README + `scan-codebase/SKILL.md` Halt conditions
- Skill emits `dep_missing` blocker YAML if tree-sitter not on PATH; offers install commands
- `.scm` query files bundled inside plugin (~50KB total)
- Per-language grammars: `tree-sitter` CLI downloads them lazily on first use

**Trade-off**:
- ✅ Precision boost (no more "found `function` in a comment" errors)
- ✅ Single native binary (no Python/Node)
- ⚠️ User must install tree-sitter once
- ⚠️ Grammar drift on bleeding-edge syntax (pin grammar versions in queries/)

### 4.2 Swap #2 — ast-grep for Hard Rule grammar v2

**Current**: Iter 3 introduced 5-type grammar (DO_NOT_MODIFY, DO_NOT_ADD_DEPS, NAMING_RULE, SIGNATURE_RULE, FILE_PRESENCE_RULE). Bespoke parser in execute-bolts pre/post-flight.

**New**: ast-grep YAML rules. The 5 types map cleanly:

```yaml
# v1: DO NOT modify src/Models/User.php
# v2: ast-grep rule
id: do-not-modify-user-php
language: php
rule:
  pattern: $$$
  inside:
    file: src/Models/User.php
fix: forbidden
```

```yaml
# v1: function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>
# v2: ast-grep rule
id: preserve-authenticate-user-signature
language: typescript
rule:
  pattern: |
    function authenticateUser($EMAIL: string, $PASSWORD: string): Promise<User> {
      $$$
    }
constraints:
  EMAIL: { regex: "^[a-zA-Z0-9_]+$" }
  PASSWORD: { regex: "^[a-zA-Z0-9_]+$" }
```

**Migration path** (per DESIGN-OQ-2):
- v1 rules in existing units automatically converted to v2 on first `execute-bolts` run after 3.0 upgrade
- Migration writes converted rules + commits `<vault>/units/.migration-log.md`
- Original v1 rules preserved as comments for audit
- If v1 → v2 conversion is ambiguous → halt with `hard_rule_migration_ambiguous` blocker; user reviews

**Architecture**:
```
plugins/mega-sdd/skills/execute-bolts/
├── SKILL.md                          # version 1.4 → 2.0
├── references/
│   ├── superpowers-bridge.md         # unchanged
│   ├── bolt-contract.md              # unchanged
│   └── hard-rule-grammar-v2.md       # NEW: ast-grep patterns for the 5 (now expandable) rule types
└── scripts/
    └── migrate-v1-rules.sh           # NEW: v1 → v2 migration helper
```

**Expanded rule types** (v2 enables, previously impossible in v1):
- Cross-file invariants ("function X MUST be called by function Y at least once")
- Type-aware refactors ("all `useState<string>` MUST migrate to `useState<UserName>`")
- Naming pattern with semantic anchor ("controllers in src/Http/Controllers MUST extend BaseController")

**Trade-off**:
- ✅ 5-10× expressivity
- ✅ Fix templates (rule can suggest auto-fix)
- ✅ Single Rust binary (no Python)
- ⚠️ Migration path needs care for v1 vaults
- ⚠️ ast-grep is syntax-only — for dataflow checks (none in current 5 types) we'd need different tooling

### 4.3 Swap #3 — PageRank symbol graph for `generate-units`

**Current**: `generate-units` Step 7 populates `target_files` from binding citations. Often misses related files that share symbols.

**New**: Build symbol graph from tree-sitter (Swap #1's output), run PageRank to rank files, suggest top-K as candidate target_files.

**Edge definition** (per DESIGN-OQ-3):
- File A → File B edge if A imports B OR A references symbol defined in B
- Both directions (bidirectional graph for PageRank)
- Weight = ref count (more refs = higher weight)

**Algorithm**:
1. After tree-sitter scan → all symbol defs + refs
2. Build directed graph: nodes = files, edges = symbol references
3. For each unit candidate's `vault_source` section, find seed files (cited in binding)
4. Personalized PageRank from seed → rank all files
5. Top-K (K=5 by default, configurable) suggested as additional target_files candidates
6. User confirms via render pass (`generate-units` Step 12.4)

**Trade-off**:
- ✅ Auto-bind to related files without explicit user input
- ✅ Reduces "I forgot to add this file" errors
- ⚠️ Suggestions need human review (per anti-halu: never auto-add target_files silently)

### 4.4 Swap #4 — AGENTS.md emitter (new skill)

**Current**: vault is mega-sdd-specific; other tools (Continue, Cursor, AGENTS.md-aware IDEs) can't consume.

**New**: NEW skill `mega-sdd:emit-agents-md` that flattens vault + binding + units summary into AGENTS.md schema.

**Output**:
- `<repo-root>/AGENTS.md` — generated from vault's 00-index + binding summary + units list
- Standard AGENTS.md headings: Build/Run commands, Code style, Test commands, Conventions
- Includes a `<!-- generated_by: mega-sdd:emit-agents-md v1.0 -->` HTML comment for tooling detection

**Architecture**:
```
plugins/mega-sdd/skills/emit-agents-md/   # NEW
├── SKILL.md                              # 1.0.0
└── references/
    └── agents-md-schema.md               # AGENTS.md format spec
plugins/mega-sdd/commands/
└── emit-agents-md.md                     # NEW slash command
```

**Trigger options** (per DESIGN-OQ-4):
- Explicit: `/mega-sdd:emit-agents-md`
- Auto: orchestrate-flow `--deep` runs this at chain end (after execute-bolts)
- Opt-out: `--no-agents-md` flag on auto-mode

**Trade-off**:
- ✅ 60k+ repo ecosystem visibility
- ✅ Zero runtime cost (pure write-out)
- ⚠️ One more file to keep in sync (mitigation: idempotent regeneration on each chain)

### 4.5 Swap #5 — Checkpoint-graph for `orchestrate-flow`

**Current**: `--resume` (Iter 4) reads CWD artifact presence to rebuild cursor. Cannot resume MID-SKILL (e.g., bind-codebase crashed at claim #45 of 100).

**New**: Each skill writes per-step checkpoint files. Resume reads checkpoints + replays from last checkpoint.

**Architecture**:
```
<vault>/.mega-sdd/checkpoints/
├── 2026-05-21T10:00:00Z-extract-intelligence-step-3.yaml   # Wave 3 of 5 complete
├── 2026-05-21T10:30:00Z-generate-intent-step-3.yaml         # Step 3 (file generation) complete
├── 2026-05-21T11:00:00Z-bind-codebase-claim-45.yaml         # 45 of 100 claims processed
└── ...
```

**Checkpoint schema** (per DESIGN-OQ-5):
```yaml
checkpoint:
  skill: bind-codebase
  step: claim_validation
  step_id: claim-45
  cursor: { claim_index: 45, claim_id: C-045 }
  state: { confirmed: 30, conflict: 1, oq: 14 }
  next_step: claim-46
  artifacts_so_far: [<list of files written>]
  resume_command: "/mega-sdd:bind-codebase ./vault --resume-from=claim-46"
```

**Rotation policy**:
- Keep checkpoints for last 3 runs
- Older checkpoints moved to `<vault>/.mega-sdd/checkpoints-archive/`
- `mega-sdd:memory prune` cleans archive >180 days

**Trade-off**:
- ✅ Mid-skill resume (e.g., bind-codebase crashed at claim 45 → resume at claim 46)
- ✅ Audit trail of per-step progress
- ⚠️ More YAML on disk (mitigation: rotation policy)

## 5. Backward compatibility

| Existing artifact | Iter 6 behavior |
|---|---|
| v2.1 vault without checkpoints/ dir | scan-codebase + bind-codebase still work; no resume mid-skill capability |
| v2.1 unit with v1 Hard Rule grammar | Auto-migrated to v2 on first execute-bolts; original preserved as comments |
| v2.1 scan-codebase run (regex output) | Re-run with tree-sitter produces higher-precision map; old map preserved as `codebase-map.regex.md.bak` |
| v2.1 generate-units run (manual target_files) | PageRank suggestions ADDED to candidates; user reviews; no silent rewrite |
| AGENTS.md already exists in repo (user-authored) | mega-sdd appends to existing OR creates `AGENTS.mega-sdd.md` if mode != overwrite |

## 6. New commands (Iter 6)

- `/mega-sdd:emit-agents-md` — generate AGENTS.md from vault + binding (new)
- `/mega-sdd:scan-codebase --engine=tree-sitter|regex` — engine selector (default tree-sitter when available)
- `/mega-sdd:execute-bolts --hard-rule-grammar=v1|v2` — grammar selector (default v2; v1 for migration testing)

## 7. Anti-hallucination invariants (preserved across all iters)

ALL 8 anti-halu layers from previous iters remain non-negotiable:

1. Intent OQs (citation or halt)
2. OQ classification (business vs tech)
3. Binding gate (CONFLICT blocks)
4. Implementation-state classification
5. Unit grounding (target_files whitelist)
6. Hard Rule pre/post-flight (Iter 3; now v2 grammar but same enforcement)
7. Drift detection
8. Interface lock (multi-squad)

Plus memory layer Iter 5 invariants (suggestion-only, audit log, rollback path) unchanged.

Iter 6 additions DO NOT introduce new fuzzy logic:
- Tree-sitter parses ARE deterministic (AST nodes are exact, not approximate)
- ast-grep matches are exact AST pattern matches (no semantic similarity)
- PageRank suggestions surface as SUGGESTIONS (per anti-halu rail: never silent rewrite)
- AGENTS.md emission is pure transformation (no inference)
- Checkpoint resume replays deterministically (no LLM in the loop)

## 8. Open design questions ([ITER6-OQ])

- **[ITER6-OQ-1] Tree-sitter distribution model** — bundle binaries in plugin? rely on user install? Options: (a) document install commands; halt on absence; (b) bundle precompiled binaries per platform in plugin (~5MB × 3 platforms = 15MB plugin size increase); (c) hybrid — bundle for common platforms (macOS arm64 + Linux x86_64) + halt with install command for others. **Recommendation: (a)** — keep plugin small; doc install in README.

- **[ITER6-OQ-2] ast-grep v1→v2 migration** — auto-migrate on first run? Or require explicit `/mega-sdd:migrate-rules`? Options: (a) auto-migrate on first execute-bolts post-3.0 upgrade; (b) explicit migration command; user confirms before rules are rewritten. **Recommendation: (b)** — explicit migration preserves auditability.

- **[ITER6-OQ-3] PageRank edge definition** — bidirectional? weighted by ref count? Options: (a) bidirectional, weighted; (b) directed only (import-direction); (c) bidirectional, unweighted. **Recommendation: (a)** — Aider's approach; battle-tested at 45k stars.

- **[ITER6-OQ-4] AGENTS.md trigger** — auto on every chain or explicit? Options: (a) auto at chain end; (b) explicit only; (c) opt-in via config flag. **Recommendation: (c)** — config flag default-on; users can disable per-project via `~/.mega-sdd/config.yaml`.

- **[ITER6-OQ-5] Checkpoint schema** — YAML or JSON? Options: (a) YAML (human-readable, slow parse); (b) JSON (less readable, fast parse); (c) JSON Lines (append-only, race-tolerant). **Recommendation: (c)** — JSONL for append-only nature aligns with memory layer convention.

- **[ITER6-OQ-6] Major version bump (3.0.0)** — what breaks? Options: (a) v2.1 vaults continue working unchanged (claim: nothing breaks); (b) v2.1 Hard Rules need v2 migration (claim: rules break); (c) v2.1 codebase-map needs regen (claim: scans break). **Recommendation: only ast-grep v1→v2 migration is breaking**; everything else is additive. Migration helper provided.

- **[ITER6-OQ-7] Checkpoint rotation interval** — how aggressive? Options: (a) keep last 3 runs; archive rest; prune archive >180 days (matches memory layer); (b) keep all checkpoints indefinitely (disk grows); (c) keep last run only. **Recommendation: (a)** — consistent with memory layer rotation.

## 9. Test coverage

New tests for each swap:

- `tests/skill-triggering/scan-codebase.test.md` — extended with TS1-TS5 (tree-sitter cases)
- `tests/skill-triggering/execute-bolts.test.md` — extended with AG1-AG6 (ast-grep cases) + MIG1-MIG3 (v1→v2 migration)
- `tests/skill-triggering/generate-units.test.md` — extended with PR1-PR3 (PageRank cases)
- `tests/skill-triggering/emit-agents-md.test.md` — NEW (AM1-AM4)
- `tests/skill-triggering/orchestrate-flow.test.md` — extended with CP1-CP3 (checkpoint cases)
- `tests/integration/e2e-iter6.test.md` — NEW (full pipeline run validating all 5 swaps end-to-end)

## 10. Validation plan

### Scenario A — Fresh project, all swaps active
- Fixture: Laravel project; tree-sitter installed
- Run `/mega-sdd:auto ./prd.md --deep`
- Verify: scan-codebase uses tree-sitter (chat says "engine: tree-sitter"); generate-units PageRank suggestions surface; execute-bolts uses ast-grep grammar v2; AGENTS.md generated at chain end; checkpoints written per skill

### Scenario B — Tree-sitter not installed (graceful degradation)
- Fixture: project; tree-sitter NOT on PATH
- Run `/mega-sdd:auto ./prd.md`
- Verify: scan-codebase falls back to regex; chat warns "tree-sitter not found; using regex fallback (lower precision)"; pipeline continues

### Scenario C — v2.1 vault migration to v2 rules
- Fixture: existing v2.1 vault with 3 units using v1 Hard Rules
- Run `/mega-sdd:execute-bolts --migrate-rules`
- Verify: v1 rules converted to v2 ast-grep YAML; original preserved as comments; `.migration-log.md` written; subsequent bolts use v2

### Scenario D — Mid-skill resume via checkpoint
- Setup: bind-codebase crashes at claim 45 of 100 (simulate via SIGKILL)
- Run `/mega-sdd:bind-codebase --resume`
- Verify: reads `checkpoints/<latest>-bind-codebase-claim-45.yaml`; resumes from claim 46; final binding.md has all 100 claims processed

### Scenario E — AGENTS.md interop
- Run `/mega-sdd:auto ./prd.md --deep`
- Verify: AGENTS.md generated; opens in Continue.dev (manual check); contains valid Build / Test / Conventions sections

## 11. References

- Iter 1-5 design specs (chronological)
- Research agent report (2026-05-21, this session)
- Aider repo-map (https://aider.chat/2023/10/22/repomap.html)
- ast-grep (https://github.com/ast-grep/ast-grep)
- tree-sitter (https://github.com/tree-sitter/tree-sitter)
- AGENTS.md spec (https://agents.md/)
- LangGraph checkpoint pattern (research report Cat 5)
- Mega-sdd CLAUDE.md contributor guidelines (every behavior change traces to spec)
