# Changelog

All notable changes to this skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] — 2026-05-21

### Added — Tech Upgrades (Iter 6, major version bump)

Per spec `docs/superpowers/specs/2026-05-21-tech-upgrades-iter6-design.md`. All 7 ITER6-OQs resolved per recommended defaults. Research-driven: deep-search of 30+ tools/libs (Aider, Cline, Plandex, ast-grep, tree-sitter, AGENTS.md ecosystem, LangGraph) identified 5 high-leverage swaps that strengthen mega-sdd without violating core invariants.

Realizes "more robust, more intelligent, still markdown-driven". Pipeline architecture unchanged; engines swapped at key points.

**Five swaps:**

1. **scan-codebase → tree-sitter engine** (Swap #1)
   - AST-precise symbol extraction replaces regex (Aider's proven pattern, 45k ⭐)
   - 100+ language grammars via tree-sitter CLI (~5MB native binary)
   - `.scm` query files bundled in `skills/scan-codebase/queries/`
   - Engine auto-detected via `command -v tree-sitter`; graceful fallback to regex (v1.2 behavior preserved)
   - `--engine=tree-sitter|regex` flag for forced engine
   - Codebase-map.md gains `engine` + `precision_tier` + `tree_sitter_version` + `grammars_used` frontmatter

2. **Hard Rule grammar v2 → ast-grep YAML** (Swap #2)
   - Replaces bespoke 5-type grammar (Iter 3 v1) with ast-grep YAML rules
   - 5-10× expressivity (semantic patterns + fix templates + constraints)
   - Single Rust binary (no Python/Node)
   - Single ast-grep covers 100+ langs via shared tree-sitter grammars
   - v1 grammar preserved as legacy path; auto-detected per unit (YAML blocks = v2; bullet lines = v1)
   - Mixed-grammar unit halts (`hard_rule_mixed_grammar`); user migrates via new `/mega-sdd:migrate-rules` command
   - Per ITER6-OQ-2: explicit per-unit migration confirm; v1 rules preserved as HTML comments for audit

3. **PageRank symbol-graph for generate-units target_files** (Swap #3)
   - Personalized PageRank on file-level symbol-reference graph (Aider's repo-map algorithm)
   - Seed = binding citations + existing target_files; rank top-K (default 5) non-seed files
   - Surfaces in unit body as `## PageRank suggestions` section (informational only — NEVER silent rewrite)
   - User reviews + manually promotes to `target_files` frontmatter
   - Requires `precision_tier: ast` (tree-sitter scan); skipped gracefully on regex tier
   - Symbol graph cached at `<vault>/.mega-sdd/symbol-graph.json` per scan run
   - `--skip-pagerank` flag disables; `--target-suggestions=N` configures K

4. **AGENTS.md emitter (new skill)** (Swap #4)
   - NEW skill `mega-sdd:emit-agents-md` (v1.0)
   - NEW command `/mega-sdd:emit-agents-md`
   - Flattens vault + binding + units summary into AGENTS.md schema (Linux Foundation AAIF; 60k+ repo ecosystem)
   - Tool-agnostic visibility — Continue.dev, Cursor, Aider, Copilot can consume mega-sdd intelligence without knowing mega-sdd specifics
   - 8 conditional sections: Project overview, Build commands, Test commands, Code style, Architecture, Decisions, Open questions, Mega-sdd interop notes
   - Generation marker (HTML comment) MANDATORY for idempotent re-emission
   - `--mode=overwrite|append|sibling` (default `sibling` if user-authored AGENTS.md detected)
   - Per ITER6-OQ-4: config-flag default-on; per-project opt-out via `~/.mega-sdd/memory/config.yaml` `defaults.emit_agents_md: false`
   - Auto-emitted at chain end when `orchestrate-flow --deep` runs (opt-out via `--no-agents-md`)

5. **Checkpoint-graph for orchestrate-flow** (Swap #5)
   - Per-step JSONL checkpoints at `<vault>/.mega-sdd/checkpoints/` (LangGraph-inspired pattern)
   - Enables mid-skill resume (e.g., bind-codebase crashed at claim 45 of 100 → resume at claim 46)
   - Per ITER6-OQ-5: JSONL format (append-only, race-tolerant, aligns with memory layer convention)
   - Per ITER6-OQ-7: rotate last 3 runs; archive rest; prune >180d (matches memory layer)
   - Skill responsibilities: extract-intelligence per wave, bind-codebase per claim, generate-units per unit, execute-bolts per bolt
   - Handoff YAML extended with `checkpoints` field (latest_step_id, checkpoint_file, resume_command)
   - Backward compat: v2.1 skills without checkpoint emission fall back to Iter 4 CWD-driven resume

### Added — New skills + commands

- `mega-sdd:emit-agents-md` v1.0 (AGENTS.md flattener)
- `/mega-sdd:emit-agents-md` command
- `/mega-sdd:migrate-rules` command (v1 → v2 Hard Rule migration helper)

### Added — New references

- `scan-codebase/references/tree-sitter-integration.md` (Swap #1 mechanics + fallback behavior)
- `scan-codebase/queries/tags-{typescript,php,python}.scm` (initial language coverage)
- `scan-codebase/queries/VERSIONS.md` (tested tree-sitter grammar version matrix)
- `execute-bolts/references/hard-rule-grammar-v2.md` (Swap #2 grammar + v1→v2 mapping)
- `execute-bolts/scripts/migrate-v1-rules.sh` (migration scaffold)
- `generate-units/references/pagerank-targeting.md` (Swap #3 algorithm + render-pass integration)
- `emit-agents-md/SKILL.md` + `references/agents-md-schema.md` (Swap #4)
- `orchestrate-flow/references/checkpoint-protocol.md` (Swap #5)

### Changed — Skill versions

- `scan-codebase`: 1.2.0 → 2.0.0 (tree-sitter engine; graceful regex fallback)
- `execute-bolts`: 1.4.0 → 2.0.0 (ast-grep v2 grammar; v1 legacy path preserved)
- `generate-units`: 1.5.0 → 2.0.0 (PageRank target_files suggestions; opt-out via `--skip-pagerank`)
- `emit-agents-md`: NEW at 1.0.0
- `orchestrate-flow`: 1.4.0 → 2.0.0 (checkpoint protocol; mid-skill resume)

(Other skills unchanged — generate-intent v1.6, bind-codebase v1.6, memory v1.0, resolve-oq v0.5, using-mega-sdd v1.2, extract-intelligence v1.1.)

### Anti-hallucination invariants — PRESERVED

Iter 6 adds DETERMINISTIC tech (AST parses, ast-grep matches, PageRank ranks) — NO new fuzzy logic introduced. All 8 anti-halu layers (Iters 1-5) + memory layer invariants intact:

1. Tree-sitter parses are deterministic (AST nodes exact, not approximate)
2. ast-grep matches are exact AST pattern matches (no semantic similarity / vector retrieval)
3. PageRank suggestions surface in unit body as SUGGESTIONS (never silent rewrite of `target_files`)
4. AGENTS.md emission is pure transformation (no inference; cites every claim's source)
5. Checkpoint resume replays deterministically (no LLM in the loop; cursor-driven)
6. v1 → v2 Hard Rule migration: explicit per-unit confirm (per ITER6-OQ-2); v1 preserved as HTML comments for audit
7. Engine fallbacks graceful: scan-codebase regex when tree-sitter absent; v1 grammar when ast-grep absent

### Backward compatibility

- v2.1 codebase-map.md (regex output) → re-scan with tree-sitter produces higher-precision map; old preserved as `.bak`
- v2.1 units with v1 Hard Rules → execute-bolts v1.4 path preserved; explicit migration via `/mega-sdd:migrate-rules` when ready
- v2.1 vaults without checkpoints/ dir → CWD-driven resume continues to work (Iter 4 behavior)
- Tree-sitter not installed → regex fallback; warning emitted; pipeline functional
- ast-grep not installed AND unit has v2 rules → halt with install commands; v1 rules still work
- AGENTS.md user-authored without marker → halt; ask user for overwrite/append/sibling choice

### Breaking changes (justifies major bump per ITER6-OQ-6)

ONLY ast-grep v1→v2 migration is breaking — and even that has a legacy preservation path. Specifically:

- Generating NEW units in v3.0 produces v2 grammar by default (v1 still selectable via `--hard-rule-grammar=v1`)
- Mixed-grammar units in same vault → halt `hard_rule_mixed_grammar`; user migrates first
- Otherwise everything is additive

### New tests

- `tests/skill-triggering/scan-codebase.test.md` — extended with TS1-TS5 (tree-sitter cases + fallback)
- `tests/skill-triggering/execute-bolts.test.md` — extended with AG1-AG6 (ast-grep v2 cases) + MIG1-MIG3 (v1→v2 migration)
- `tests/skill-triggering/generate-units.test.md` — extended with PR1-PR3 (PageRank suggestion cases)
- `tests/skill-triggering/emit-agents-md.test.md` — NEW (AM1-AM4: detect mode, sibling write, idempotent regen, conditional sections)
- `tests/skill-triggering/orchestrate-flow.test.md` — extended with CP1-CP3 (checkpoint emission + mid-skill resume)
- `tests/integration/e2e-iter6.test.md` — NEW (full pipeline E2E validating all 5 swaps)

### Locked ITER6-OQ resolutions (from spec §8)

- ITER6-OQ-1: Tree-sitter dist — document install commands; don't bundle binaries (keeps plugin small)
- ITER6-OQ-2: ast-grep v1→v2 migration — explicit per-unit confirm via `/mega-sdd:migrate-rules`; v1 preserved as audit
- ITER6-OQ-3: PageRank graph — bidirectional + weighted by ref count (Aider's proven approach)
- ITER6-OQ-4: AGENTS.md trigger — config flag default-on; per-project opt-out via `~/.mega-sdd/memory/config.yaml`
- ITER6-OQ-5: Checkpoint format — JSONL (append-only, race-tolerant; aligns with memory layer)
- ITER6-OQ-6: Major version 3.0 justified — only ast-grep v1→v2 migration breaks; everything else additive
- ITER6-OQ-7: Checkpoint rotation — keep last 3 runs; archive rest; prune >180d (consistent with memory layer)

### Iteration vision update

| Iter | Plugin | Status |
|---|---|---|
| extract-intelligence | 1.4.0 | ✅ Shipped |
| Iter 1 (impl-state + task_type) | 1.5.0 | ✅ Shipped |
| Iter 2 (tech-OQ classifier + scan/recommend) | 1.6.0 | ✅ Shipped |
| Iter 3 (Hard rules + pre/post-flight + polished prompts) | 1.7.0 | ✅ Shipped |
| Iter 4 (Autonomy Layer + /mega-sdd:auto) | 2.0.0 | ✅ Shipped |
| Iter 5 (Memory + self-learning) | 2.1.0 | ✅ Shipped |
| Iter 6 (Tech upgrades: tree-sitter + ast-grep + PageRank + AGENTS.md + checkpoint-graph) | 3.0.0 | ✅ Shipped (this entry) |

Pipeline now uses production-grade tech (proven at scale by Aider 45k ⭐, ast-grep 14k ⭐, AGENTS.md 60k+ repos, LangGraph 33k ⭐ patterns) while preserving the markdown-driven + citation-disciplined + halt-on-blocker core.

## [2.1.0] — 2026-05-21

### Added — Memory + Self-Learning Layer (Iter 5)

Per spec `docs/superpowers/specs/2026-05-21-memory-self-learning-design.md`. All 7 MEMORY-OQs resolved per recommended defaults. Inspired by ruflo (memory persistence concept; NOT vector-DB / binary-store implementation — mega-sdd stays markdown-driven).

Solves: context discontinuity across sessions + no self-learning from past outcomes + cross-vault patterns lost. Complementary to (NOT duplicative of) Claude Code's built-in `auto memory` — mega-sdd memory is OPERATIONAL (pipeline state); Claude Code memory is SOCIAL (working style).

**Three memory scopes:**

```
~/.mega-sdd/memory/                       # USER scope (cross-project, opt-in promotion only)
├── preferences.md                         # observed flag/mode defaults
├── patterns.md                            # learned cross-project patterns + pending suggestions
├── learning-log.md                        # audit log of accepted/rejected learnings
└── config.yaml                            # thresholds + opt-outs

<project-root>/.mega-sdd-memory/           # PROJECT scope (per-repo, git-trackable per-file)
├── decisions.md                           # OQ resolutions + CONFLICT actions + Recommendation outcomes
├── conventions.md                         # detected conventions (test framework, naming, error format)
└── outcomes.md                            # halt patterns + retry counts + success rates per run

<vault-path>/.memory/                      # VAULT scope (per-vault, ephemeral; archived on delete)
├── classifier-accuracy.json               # auto-classifier tag vs user-override metrics
├── bind-history.md                        # per-binding-run verdicts + state map summaries
└── bolt-outcomes.json                     # per-bolt success/failure + Hard Rule violations
```

**Self-learning** — threshold-based + suggestion-only (per Iter 5 design lock):
- 5 consistent classifier overrides → propose heuristic table update
- 5 same-resolution CONFLICTs → propose pre-fill default in resolve-oq
- 3 Hard Rule violation+reverts → propose removing rule from binding suggestions
- 3 recommendation REJECTs → propose flipping `resolution_mode` from `recommend` to `blocking`
- 2 convention detections → promote to "established" (skip verbose re-detection)
- 5 same flag picks → propose pre-fill in AskUserQuestion

All learnings reviewed via `/mega-sdd:memory review`. User picks ACCEPT / REJECT / DEFER per suggestion. Accepted learnings written to `learning-log.md` with rollback path (edit log entry, add `rolled_back_at: <date>`).

### Added — New skill `mega-sdd:memory`

```bash
/mega-sdd:memory list [--scope=<user|project|vault>] [--format=table|json]
/mega-sdd:memory show <topic> [--scope=<scope>]
/mega-sdd:memory search <query> [--scope=<scope>]
/mega-sdd:memory review [--auto-accept-threshold=N]
/mega-sdd:memory prune [--older-than=<duration>] [--dry-run]
/mega-sdd:memory promote <key> --to=<user|project>
/mega-sdd:memory diff [--since=<date>] [--scope=<scope>]
/mega-sdd:memory export <output-path> [--scope=<scope>]
/mega-sdd:memory import <input-path> [--scope=<scope>]
/mega-sdd:memory clear --scope=<user|project|vault> [--confirm-twice]
```

### Added — `--memory-off` flag on all skills

Disables both memory reads AND writes for that invocation. Honored across all 8 skills (extract-intelligence skipped — its outputs flow through generate-intent which respects the flag).

### Changed — Handoff YAML extended with `metadata` field

Per `orchestrate-flow/references/handoff-contract.md` §metadata extension. Per AUTONOMY-OQ-7 + MEMORY-OQ-7 (both single-read-at-orchestrator):

```yaml
handoff:
  # ... existing fields ...
  metadata:                             # v2.1+ (Iter 5)
    memory_context:                     # IN — orchestrator provides relevant memory slices
      project_decisions_relevant: []
      project_conventions_relevant: []
      vault_outcomes_relevant: []
      user_patterns_relevant: []
      user_preferences_relevant: []
    memory_writes:                      # OUT — skill emits writes for orchestrator to persist
      - file: <relative-or-absolute-path>
        scope: user | project | vault
        action: append | update
        content: |
          <markdown row or JSON entry>
        source_run: <skill-name>@<timestamp>
```

Orchestrator reads memory ONCE at chain start, passes slices to skills via handoff (no per-skill disk re-read), batches writes at chain end (atomic per-file via append-only per MEMORY-OQ-6).

### Changed — Skill versions

- `memory`: NEW at 1.0.0
- `orchestrate-flow`: 1.3.0 → 1.4.0 (chain-start memory read + per-phase write batching)
- `using-mega-sdd`: 1.2.0 (unchanged — auto-trigger logic same; memory layer is downstream)
- `generate-intent`: 1.5.0 → 1.6.0 (reads preferences + conventions; writes preferences + classifier-accuracy)
- `scan-codebase`: 1.1.0 → 1.2.0 (writes conventions; reads to skip established convention re-detection)
- `bind-codebase`: 1.5.0 → 1.6.0 (reads decisions + patterns for CONFLICT resolution suggestions; writes bind-history + Hard Rule downgrade based on violation patterns)
- `generate-units`: 1.4.0 → 1.5.0 (reads bolt-outcomes for Anti-pattern suggestions; reads decisions for past CONFLICT KEEP_CODE files; no direct writes)
- `execute-bolts`: 1.3.0 → 1.4.0 (writes bolt-outcomes + outcomes; reads to surface past-halt warnings)
- `resolve-oq`: 0.4.0 → 0.5.0 (writes decisions on each OQ + CONFLICT resolution + Recommendation outcome)
- `extract-intelligence`: 1.1.0 (unchanged — operates outside project memory context)

### New command

- `commands/memory.md` — `/mega-sdd:memory` operations entrypoint

### New tests

- `tests/skill-triggering/memory.test.md` — 9 operations (M1-M9) + 7 anti-halu invariants (AH1-AH7)
- `tests/integration/e2e-memory-self-learning.test.md` — 6 scenarios (A-F) covering accumulation, threshold-fire, accept-learning, rollback, --memory-off graceful degradation, cross-vault consistency, archival

### Anti-hallucination invariants — PRESERVED

Memory layer is SUGGESTION-ONLY across all touchpoints. The 10 invariants from spec §10:

1. Memory is suggestion only — never enforcement
2. Every suggestion cites source memory entry
3. Current evidence wins over memory
4. No silent auto-tuning (explicit ACCEPT via `/mega-sdd:memory review`)
5. Audit log mandatory (every learning has rollback path)
6. No fabricated citations (writers cite source artifact; readers cite memory entry)
7. Cross-project promotion explicit (NEVER automatic)
8. `--memory-off` honored everywhere
9. Memory does NOT affect halt-protocol (CONFLICT still blocks, business OQ P1 still pauses, hard_rule_violated still halts)
10. Memory files are human-reviewable markdown / JSON (never binary)

### Backward compatibility

PURELY ADDITIVE:
- v2.0 pipelines work without memory dirs — skills lazily create on first write
- Memory dirs don't exist yet → readers find no files → default behavior unchanged
- `--memory-off` opt-out preserves identical behavior to v2.0
- Schema versions (`memory_schema: 1`) stamped; future migration supported per MEMORY-OQ-1
- Existing handoff YAML producers (Iter 4) keep working; new `metadata` field is optional

### Locked MEMORY-OQ resolutions (from spec §13)

- MEMORY-OQ-1: Schema versioning + auto-migrate with audit log
- MEMORY-OQ-2: Per-file gitignore (decisions.md + conventions.md tracked; outcomes.md gitignored)
- MEMORY-OQ-3: Plain markdown (no encryption); document privacy risk; `--memory-off` for sensitive contexts
- MEMORY-OQ-4: Configurable thresholds via `~/.mega-sdd/memory/config.yaml`
- MEMORY-OQ-5: Vault-scope memory archived to `<project>/.mega-sdd-memory/archived-vaults/<vault-id>/` on vault delete
- MEMORY-OQ-6: Append-only writes (race-tolerant via atomic single-write fs.append)
- MEMORY-OQ-7: Single memory read at orchestrator chain-start; slices passed via handoff YAML

### Iteration vision update

| Iter | Plugin | Status |
|---|---|---|
| extract-intelligence | 1.4.0 | ✅ Shipped |
| Iter 1 (impl-state + task_type) | 1.5.0 | ✅ Shipped |
| Iter 2 (tech-OQ classifier + scan/recommend) | 1.6.0 | ✅ Shipped |
| Iter 3 (Hard rules + pre/post-flight + polished prompts) | 1.7.0 | ✅ Shipped |
| Iter 4 (Autonomy Layer + /mega-sdd:auto) | 2.0.0 | ✅ Shipped |
| Iter 5 (Memory + self-learning) | 2.1.0 | ✅ Shipped (this entry) |

## [2.0.0] — 2026-05-20

### Added — Autonomy Layer (Iter 4 of vision; major version bump)

Per spec `docs/superpowers/specs/2026-05-20-autonomy-layer-design.md`. All 7 AUTONOMY-OQs resolved per recommended defaults.

Realizes the user-stated vision: "skills as agents that auto-route through the pipeline" + "PRD upload → vault → units in one motion" + "legacy code → rebuild project in one motion". The pipeline shape stays identical; the orchestration becomes autonomous through clean paths while preserving every existing halt-protocol blocker.

**Four coordinated pillars:**

1. **Deep-chain mode in `orchestrate-flow`**
   - New `--deep` flag lifts the 3-skill cap; chain extends to pipeline-end
   - Per AUTONOMY-OQ-1: single upfront confirmation covers ALL phases including `execute-bolts` (bolts have their own safety via target_files whitelist + Hard rules)
   - Per AUTONOMY-OQ-2: `--resume` is CWD-driven (no persisted state file). Cursor position derives from artifact presence.
   - Per AUTONOMY-OQ-4: One-line progress indication before/after each phase (`▶ Phase N of M: ...`)
   - Backward compatible: default mode (no `--deep`) still cap-3.

2. **Auto-continue handoffs via handoff YAML protocol**
   - New `references/handoff-contract.md` defines the shared protocol
   - Every skill emits a `handoff:` YAML record when invoked with `--auto` (per AUTONOMY-OQ-5: required only under `--auto`)
   - Orchestrator parses `next_action.suggested_skill` + `next_action.suggested_args` and auto-invokes the next phase
   - Status values: `completed` (auto-continue), `paused` (chain stops awaiting user), `halted` (blocker fires; chain stops)
   - Required schema includes `artifacts` (orchestrator verifies skill output exists) + `blockers` (verbatim halt YAMLs)

3. **Sharper `using-mega-sdd` auto-trigger**
   - Auto-invoke `/mega-sdd:auto` (or `orchestrate-flow --deep`) when BOTH strong CWD signal AND user prompt intent keyword present
   - Per AUTONOMY-OQ-3: general questions ("explain X", "fix bug Y") do NOT auto-trigger even with strong CWD; prompt MUST contain mega-sdd intent
   - New trigger keywords: `auto`, `rebuild`, `lanjut`, `next`, `jalankan otomatis`, `proceed`, `go`

4. **One-shot `/mega-sdd:auto` entrypoint**
   - NEW slash command at `commands/auto.md`
   - Input shape detection: legacy codebase / vault dir / PRD file / quoted brief / empty → CWD inspection
   - Routes to `orchestrate-flow --deep --auto` with detected starting phase
   - Per AUTONOMY-OQ-7: `--out=<path>` REQUIRED for legacy rebuild scenarios (extract-intelligence) — never conflate extract output with rebuild project dir
   - Flag surface: `--deep` / `--shallow` / `--step-after=<phase>` / `--stop-after=<phase>` / `--resume` / `--manual`

### Changed — Schema additions

- **New reference**: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` — shared protocol definition + per-skill expected emissions + orchestrator consumption logic + anti-halu invariants
- `orchestrate-flow/references/routing-rules.md`: new §Deep-chain decision matrix + §Resume mechanics
- `orchestrate-flow/SKILL.md`: new Step 8 (Resume support); Procedure §3 splits cap-3 vs `--deep`; progress indication mandate; new flags

### Changed — Skill versions

- `orchestrate-flow`: 1.2.0 → 1.3.0 (--deep flag + --resume + auto-continue + progress indication)
- `using-mega-sdd`: 1.1.0 → 1.2.0 (sharper auto-trigger rules + new keywords)
- `extract-intelligence`: 1.0.0 → 1.1.0 (handoff YAML emission)
- `generate-intent`: 1.4.0 → 1.5.0 (handoff YAML emission)
- `scan-codebase`: 1.0.0 → 1.1.0 (handoff YAML emission)
- `bind-codebase`: 1.4.0 → 1.5.0 (handoff YAML emission)
- `generate-units`: 1.3.0 → 1.4.0 (handoff YAML emission)
- `execute-bolts`: 1.2.0 → 1.3.0 (handoff YAML emission)

### New command

- `commands/auto.md` — `/mega-sdd:auto` one-shot entrypoint

### Anti-hallucination invariants — PRESERVED (the core promise)

`--deep` mode is autonomy through CLEAN paths only. EVERY existing halt fires identically:
- `bind_conflict` — bound-vault not produced; chain halts
- `oq_business_p1_unresolved` (Iter 2 + --strict) — chain pauses for stakeholder triage
- `dedup_ambiguous` (Iter 1) — chain halts; user reviews
- `hard_rule_violated` (Iter 3 post-flight) — code stays in working tree; bolt halts pre-commit
- `hard_rule_unparseable` / `hard_rule_unanchored` (Iter 3) — chain halts
- `cross_squad_*` (multi-squad halts) — chain halts
- `quality_gate_failed` (extract-intelligence wave gates) — chain halts
- `oq_recommend_underspecified` / `oq_recommend_citation_invalid` (Iter 2) — chain halts
- `mode_migrate` — chain halts
- `dep_missing` (superpowers unavailable) — chain halts
- `cycle_detected` / `interface_ref_missing` / `cross_squad_ambiguous` / `verify_unit_writable` — chain halts

Additional rails for autonomy mode:
- ONE upfront confirmation required (NEVER zero). Single confirm = OK; confirm zero = unsafe.
- Per AUTONOMY-OQ-5: handoff YAML required ONLY under `--auto`. Standalone skill invocations may emit informationally.
- Per AUTONOMY-OQ-2: no persisted state file. `--resume` rebuilds state from CWD. Halts re-fire if blockers unresolved.
- Skills MUST NOT lie about status. If acceptance tests failed → status: halted, never completed.
- Skills MUST list every artifact in handoff YAML. Missing artifacts → orchestrator detects gap → chain halts.

### Backward compatibility

All changes additive:
- v1.7 `orchestrate-flow` (no --deep) → unchanged behavior. 3-skill cap intact.
- v1.7 standalone skill invocations (no --auto) → unchanged behavior. No handoff YAML emitted.
- v1.7 existing pipelines (PRD → vault → … manually invoked per phase) → continue to work.
- New `/mega-sdd:auto` command is opt-in. Existing per-skill commands all still work.
- v1.7 skills missing handoff emission (pre-Iter-4 skills) → orchestrator treats them as `status: completed` with `next_action: null`. Chain stops after. Degraded but safe.

### Why major version bump (per AUTONOMY-OQ-6)

- New top-level entrypoint (`/mega-sdd:auto`)
- Cap-lift in `orchestrate-flow` (semantic change in chain depth)
- `using-mega-sdd` auto-invokes orchestrate-flow without user typing commands (behavior change in anchor skill)
- All 8 skills add handoff emission contract (behavior change collectively)

Major bump (2.0) signals "the orchestration model has evolved". Skills still behave identically when not invoked with --auto.

### New tests

- `tests/skill-triggering/auto.test.md` — NEW. 13 cases: A1-A5 input detection, H1-H3 halt cases, F1-F5 flag behavior, HP1-HP3 halt-protocol preservation
- `tests/skill-triggering/orchestrate-flow.test.md` — extended with DC1-DC6 (deep-chain mode) + RES1-RES3 (resume mechanics)
- `tests/integration/e2e-autonomy-clean.test.md` — NEW. End-to-end full pipeline clean run with V1-V5 validation checks
- `tests/integration/e2e-autonomy-halt.test.md` — NEW. End-to-end halt + resolve + resume cycle with V1-V5 validation checks

### Iteration vision complete

| Iter | Plugin | Status |
|---|---|---|
| extract-intelligence | 1.4.0 | ✅ Shipped |
| Iter 1 (impl-state + task_type) | 1.5.0 | ✅ Shipped |
| Iter 2 (tech-OQ classifier + scan/recommend) | 1.6.0 | ✅ Shipped |
| Iter 3 (Hard rules + pre/post-flight + polished prompts) | 1.7.0 | ✅ Shipped |
| Iter 4 (Autonomy Layer + /mega-sdd:auto) | 2.0.0 | ✅ Shipped (this entry) |

The full vision from `2026-05-20-tech-oq-autoresolve-design.md` + `2026-05-20-autonomy-layer-design.md` + `2026-05-20-extract-intelligence-skill-design.md` is now realized. Pipeline maps cleanly to superpowers' `read → scan → writing-plans → executing-plans (subagent-driven)` shape.

## [1.7.0] — 2026-05-20

### Added — Polished AI-Coding-Prompt Units + Hard Rule Pre/Post-Flight (Iter 3 of tech-OQ vision)

Per spec `docs/superpowers/specs/2026-05-20-tech-oq-autoresolve-design.md` §6 (Iter 3). DESIGN-OQ-4, OQ-5, OQ-6 locked.

Solves "unit reads like a Jira ticket, not an AI coding prompt" pain — and adds the runtime safety net so bolts execute autonomously without violating constraints:

- **Unit body restructure** — `## Anchors` mandatory when binding evidence exists; `## Anti-patterns` for informational don'ts; `## Hard rules` for machine-validated constraints; `## Implementation steps` rendered as directive prose (not bullet schema).
- **Hard Rule grammar (closed v1 per DESIGN-OQ-4)** — 5 rule types: `DO NOT modify <path>`, `DO NOT add new <manifest> dependencies`, `<path-glob> MUST follow <case-style> naming`, `function <name> MUST preserve signature: <type-sig>`, `file <path> MUST exist after bolt`. Unparseable → halt `hard_rule_unparseable`.
- **`execute-bolts` pre-flight scan** — captures deterministic state snapshot per rule before bolt runs (sha256 for DO_NOT_MODIFY, manifest deps section for DO_NOT_ADD_DEPS, function signature for SIGNATURE_RULE). Persisted to `<vault>/bolts/U-XXX/preflight.json`.
- **`execute-bolts` post-flight validation** — runs BEFORE commit. Re-validates each rule against current state. ANY violation → halt `hard_rule_violated`; code changes remain in working tree (NOT committed); user reviews + reverts/edits.
- **`bind-codebase` Suggested Unit Hard Rules** — emits machine-parseable Hard rules + Anti-patterns drawn from Implementation State Map + CONFLICT resolutions + KB `[VERIFIED]` gotchas. Per DESIGN-OQ-6: KB items default to Anti-patterns; promoted to Hard rules ONLY when `[VERIFIED]` AND mechanically detectable.
- **`generate-units` render pass** (new Step 12.4) — validates Anchors mandatory rule, Hard rule grammar, Migration notes structure, directive prose density. Halts with `unit_underspecified` or `hard_rule_unparseable`. Auto-pulls Hard rules + Anti-patterns from `binding.md` Suggested Unit Hard Rules section.
- **`task_type: verify` special path** in execute-bolts — skips code generation; runs acceptance tests against existing implementation; skips post-flight Hard rule scan (no changes to validate).

### Changed — Schema additions

- `generate-units/references/unit-schema.md`: body sections restructured with directive prose guidance, Anchors mandatory rules per task_type, Anti-patterns section, Hard rules section with 5-grammar productions + validation table.
- `bind-codebase/SKILL.md` + `references/binding-contract.md`: new Procedure §2.8 (Suggested Unit Hard Rules emission) + new "## Suggested Unit Hard Rules" section in binding.md template.

### Changed — Skill versions

- `generate-units`: 1.2.0 → 1.3.0 (new Step 12.4 render pass; auto-pull from binding suggestions)
- `execute-bolts`: 1.1.0 → 1.2.0 (Pre-flight Step 4 + Post-flight validation step; new outputs preflight.json + postflight.json)
- `bind-codebase`: 1.3.0 → 1.4.0 (new Procedure §2.8 Suggested Unit Hard Rules; new section in binding.md)

### Anti-hallucination invariants

- Hard rule grammar closed v1 (5 productions per DESIGN-OQ-4). Unparseable → halt; NEVER silently skip.
- Pre-flight snapshot is mandatory when `## Hard rules` non-empty per DESIGN-OQ-5. No `--skip-preflight` flag.
- Post-flight runs BEFORE commit. Violations preserve code changes in working tree for user review.
- `SIGNATURE_RULE` referencing symbol absent in codebase-map → halt `hard_rule_unanchored` (can't validate what doesn't exist).
- `verify` units cannot write code — task_type enforcement at bolt time.
- KB `[INFERRED]` and `[OPEN]` items → Anti-patterns ONLY (per DESIGN-OQ-6); never auto-promoted to Hard rules.
- Suggested Hard Rules referencing unanchored files → suppressed (would fail at bolt time anyway).
- Auto-population from binding does NOT bypass render-pass validation — emitted rules must parse.

### Backward compatibility

All changes additive. Behaviors preserved:
- v1.6 units without `## Hard rules` body section → execute-bolts skips pre/post-flight (current behavior).
- v1.6 units without `## Anchors` / `## Anti-patterns` → render pass treats schema as legacy; halts only when binding evidence dictates Anchors required.
- v1.6 binding.md without "## Suggested Unit Hard Rules" → generate-units fills sections from vault-only context (no auto-pull).
- Greenfield projects (no binding) → no Anchors mandatory; no Hard rules suggestions; standard create-unit shape.
- Existing per-skill `--auto` flags unchanged.

### New tests

- `tests/skill-triggering/execute-bolts.test.md` — 11 cases HR1-HR11 covering Hard Rule pre-flight snapshot, post-flight violations per rule type (DO_NOT_MODIFY / DO_NOT_ADD_DEPS / SIGNATURE / NAMING / FILE_PRESENCE), unparseable / unanchored rule halts, verify-unit path, all-clean path, multi-rule violation.
- `tests/skill-triggering/generate-units.test.md` — 9 cases PP1-PP9 covering Anchors mandatory rule per task_type, grammar parse, Migration notes structure, directive prose density, verify single-line allowed, Anti-patterns + Hard rules auto-pull from binding.
- `tests/skill-triggering/bind-codebase.test.md` — 8 cases SHR1-SHR8 covering implementation-state-derived rules, KB [VERIFIED] → Hard rules, KB [INFERRED]/[OPEN] → Anti-patterns only, unanchored suggestion suppression, CONFLICT resolution paths, empty section default.

### Locked DESIGN-OQ resolutions (from parent spec, restated)

- DESIGN-OQ-4: Hard rule grammar closed v1 — 5 rule types. Revisit extensibility in v2 if real-world need emerges.
- DESIGN-OQ-5: No `--skip-preflight`. Pre-flight scan is the contract.
- DESIGN-OQ-6: KB gotchas → Anti-patterns by default. Promoted to Hard rules ONLY when `[VERIFIED]` AND mechanically detectable.

### Iter 4 — Designed, awaiting kick-off

Per spec `2026-05-20-autonomy-layer-design.md`, Iter 4 (plugin 2.0.0) ships the Autonomy Layer: `--deep` chain mode in `orchestrate-flow`, auto-continue at skill handoffs, sharper `using-mega-sdd` auto-trigger, one-shot `/mega-sdd:auto` entrypoint. Bridges to superpowers' `executing-plans` shape literally.

## [1.6.0] — 2026-05-20

### Added — Tech-OQ Auto-Classification + Scan/Recommend Resolution Modes (Iter 2 of tech-OQ vision)

Per spec `docs/superpowers/specs/2026-05-20-tech-oq-autoresolve-design.md` §5 (Iter 2). DESIGN-OQ-3 locked: only `classification_confidence: high` auto-resolves; medium/low go to review.

Solves "OQ list buried in technical noise" pain — tech ambiguities deterministically answerable from codebase no longer clog the human review channel:

- **OQ schema extended** (`vault-contract.md`) with `category` (business | tech), `resolution_mode` (blocking | scan | recommend | hard_rule), `classification_confidence` (high | medium | low), plus mode-specific fields (`scan_query`, `recommendation`, `rationale`, `scan_citations`, `fallback_if_wrong`).
- **Auto-classifier** in `generate-intent` (new Step 3.5) tags every OQ at generation time per heuristic table. Conservative default: `business / blocking / low` when no pattern matches.
- **`00-index.md` Auto-Classification Review section** lists every tech-tagged OQ + medium/low confidence cases for one-pass user review before binding runs.
- **`bind-codebase` scan resolution** (new Procedure §2.6): tech OQs with `resolution_mode: scan` AND `confidence: high` auto-resolve via codebase-map probe. Single match → resolved. No match / ambiguous → flip to `blocking` (NEVER guess).
- **`bind-codebase` recommend surfacing** (new Procedure §2.7): tech OQs with `resolution_mode: recommend` AND `confidence: high` surface in `binding.md` "## Tech-OQ Recommendations (review required)" section. Recommendations carry full audit trail (rationale + scan_citations + fallback_if_wrong) + ACCEPT/OVERRIDE/REJECT actions. NEVER auto-accepted.
- **DESIGN-OQ-3 gate**: ONLY `classification_confidence: high` tech OQs are processed by scan/recommend. Medium/low confidence skip auto-resolution.

### Changed — Schema additions

- `generate-intent/references/vault-contract.md`: extended §OQ-conventions with Category + Resolution mode + Classification confidence + Auto-classifier heuristic table (10 patterns) + Auto-Classification Review section template + Updated OQ schema (markdown + vault.json) + Validation rules.
- `bind-codebase/references/binding-contract.md`: new §Tech-OQ Auto-Resolution covering scan + recommend mode mechanics, confidence gate, anti-halu enforcement, blocking rule interaction.

### Changed — Skill versions

- `generate-intent`: 1.3.0 → 1.4.0 (new Step 3.5: OQ auto-classification; validation gate)
- `bind-codebase`: 1.2.0 → 1.3.0 (new Procedure §2.6 scan resolution + §2.7 recommend surfacing)

### Anti-hallucination invariants

- Tech-OQ scan with no/multiple matches → flip to `blocking`, NEVER guess.
- Recommendations NEVER auto-accepted. ACCEPT requires explicit user action.
- Recommend mode `scan_citations` MUST verify in codebase-map / KB. Unverifiable citation → halt `oq_recommend_citation_invalid` (detects fabrication).
- Recommend mode requires all 4 audit-trail fields (`recommendation`, `rationale`, `scan_citations`, `fallback_if_wrong`). Missing any → halt `oq_recommend_underspecified`.
- Confidence gate enforced: medium/low confidence skip auto-resolve (per DESIGN-OQ-3); preserves safety-by-default.
- Conservative default at classification time: when heuristic ambiguous, → `business / blocking / low` (NEVER fabricate tech tag).
- Tech-OQ resolution operates orthogonally to verdict layer: CONFLICT still blocks bound-vault production.

### Backward compatibility

- OQs without `category` field → treated as `business` by all skills (no auto-resolve).
- v1.5 vaults without `resolution_mode` field on business OQs → defaults to `blocking` (current behavior).
- Greenfield projects → auto-classifier runs but most OQs default to `business/blocking/low` (limited codebase context); zero behavior change vs v1.5.
- `--no-kb` flag (from v1.1) still respected; KB consultation in recommend mode citation validation is gated on KB presence.

### New tests

- `tests/skill-triggering/generate-intent.test.md` — 7 new cases (CL1-CL7) for auto-classifier behavior including fabrication-detection guard.
- `tests/skill-triggering/bind-codebase.test.md` — 8 new cases (TQ1-TQ8) for scan resolution + recommend surfacing including no-match, ambiguous, citation-invalid, underspecified halt cases.

### Iter 3 + Iter 4 — Designed, awaiting kick-off

Per spec, Iter 3 (plugin 1.7) ships polished unit prompt-shape body (Anchors + Anti-patterns + Migration notes + Hard rules) + execute-bolts pre-flight + post-flight hard-rule validation. Iter 4 (Autonomy Layer, plugin 2.0) wraps the pipeline in `/mega-sdd:auto` one-shot entrypoint with deep-chain mode. Both are documented in their respective spec files.

## [1.5.0] — 2026-05-20

### Added — Implementation-State Classification + task_type Units (Iter 1 of tech-OQ vision)

Per spec `docs/superpowers/specs/2026-05-20-tech-oq-autoresolve-design.md` Iter 1 (DESIGN-OQ resolutions locked at approval).

Solves the brownfield pain "unit is generated even when the target function already exists":

- **bind-codebase** classifies every CONFIRMED claim with `state: IMPLEMENTED | NEW | UNKNOWN` (Iter 1 binary set; PARTIAL deferred to Iter 2 where `recommend` resolution handles ambiguity). Each row carries an `anchor` citation + `confidence` label (high/medium/low). Recorded in `binding.md` under new "## Implementation State Map" section.
- **generate-units** reads the map and assigns `task_type: create | verify` per unit:
  - All NEW claims (or no binding) → `task_type: create` (current behavior)
  - All IMPLEMENTED with high confidence → `task_type: verify` — NO code generation; only acceptance tests against the existing implementation cited via the `## Anchors` body section
  - Mix of NEW + IMPLEMENTED → SPLIT into one `verify` + one `create` chained via `depends_on`
  - UNKNOWN (any confidence) → conservative `create` with a body note about the unclassified anchor
- **`extend` task_type** added to the schema (forward-compat for Iter 2/3). Iter 1 does NOT auto-emit `extend` from UNKNOWN states; user manually edits frontmatter + fills Migration notes when needed.
- **Dedup gate** (`generate-units` step 12.5) — halts with `dedup_ambiguous` blocker if a `create` unit's `target_files` all already exist in codebase-map. NEVER silent-rewrites.
- **OQ category tagging** (Iter 1 scaffolding) — every OQ carries `category: business | tech` (default `business`). Iter 1 records the tag only; Iter 2 (plugin 1.6) will activate `scan` + `recommend` auto-resolve.

### Changed — Schema additions

- `bind-codebase/references/binding-contract.md`: new §Implementation-State Classification with classification logic per claim type (endpoint / entity / method) + confidence labeling + binding.md template extension.
- `generate-units/references/unit-schema.md`: new frontmatter field `task_type`; new body sections `## Anchors` (mandatory for verify/extend) and `## Migration notes` (mandatory for extend); per-task_type contract table.
- `generate-intent/references/vault-contract.md`: new §Category in §OQ-conventions with markdown + vault.json schema and the heuristic table.

### Changed — Skill versions

- `bind-codebase`: 1.1.0 → 1.2.0 (Procedure step 2.5 added; binding.md template extended; anti-halu rails extended)
- `generate-units`: 1.1.0 → 1.2.0 (Procedure step 2.5 + step 12.5 added; per-task_type unit emission; dedup halt)
- `generate-intent`: 1.2.0 → 1.3.0 (OQ category tagging; no auto-resolve in Iter 1)

### Anti-hallucination invariants preserved

- Binding gate non-negotiable: CONFLICT still BLOCKS. Implementation-state classification annotates CONFIRMED only.
- Never promote `NEW` to `IMPLEMENTED` via inference. Anchor citations required for IMPLEMENTED.
- `UNKNOWN` defaults to conservative `create` (downstream); never silently advanced to a higher-confidence label.
- `verify` units NEVER generate code; only run acceptance tests. Missing anchor → downgrade to create.
- `extend` task_type requires Migration notes; missing → halt (forward-compat enforcement).
- Dedup ambiguity → halt with `dedup_ambiguous`; never silent-rewrite a unit.

### Backward compatibility

All changes are additive. Behaviors preserved when:
- v1.4 vault loaded — OQs without `category` → treated as `business` (no auto-resolve). No behavior change.
- v1.4 binding.md without Implementation State Map → generate-units treats every claim as `NEW`-equivalent → all units `task_type: create`. Identical to v1.4 output.
- v1.4 units without `task_type` field → bolt-time behavior unchanged; new fields ignored.
- Greenfield projects (no scan-codebase / no binding) → no Impl State Map → all units `task_type: create`. Identical to v1.4.

### New tests

- `tests/skill-triggering/bind-codebase.test.md` — 5 new cases (IS1-IS5) for Implementation-State Classification.
- `tests/skill-triggering/generate-units.test.md` — 8 new cases (TT1-TT8) for task_type assignment + dedup halt.
- `tests/integration/e2e-impl-state.test.md` (new) — full pipeline on a brownfield Laravel fixture with partial existing implementation; covers verify/create split + dedup negative cases.

### Locked DESIGN-OQ resolutions (from spec)

- Iter 1 uses binary states (IMPLEMENTED / NEW / UNKNOWN); PARTIAL deferred to Iter 2.
- Dedup halts on ambiguity — never silent rewrites.
- Iter 2 classifier accuracy: high-conf only auto-resolves; medium/low go to review.
- Iter 3 hard-rule grammar closed v1 (5 rule types).
- Pre-flight scan is the contract (no `--skip-preflight`).
- KB gotchas → Anti-patterns by default; promoted to Hard rules only when `[VERIFIED]` + mechanically detectable.

### Iter 2 + Iter 3 — Designed, awaiting kick-off

The full 3-iteration vision is in the spec doc. Iter 2 activates tech-OQ auto-resolve via `scan`/`recommend` modes. Iter 3 introduces hard rules + bolt-time pre-flight validation + polished prompt-shape unit body (Anchors + Anti-patterns + Migration notes + Hard rules). Each iteration is its own PR with its own version bump.

## [1.4.0] — 2026-05-20

### Added — `extract-intelligence` skill + KB-as-context pipeline integration

Per spec `docs/superpowers/specs/2026-05-20-extract-intelligence-skill-design.md`.

New skill for the legacy-rebuild scenario where the legacy codebase is the only "spec" — no PRD exists and the rebuild is on a different stack:

- **New skill `extract-intelligence`** (v1.0.0) — wave-based parallel-subagent extractor. 5 sequential waves (Prep → Foundation → Masters → Workflows → Integrations → Synthesis), ≤5 parallel subagents per wave, hard cap 8. Produces `docs/knowledge-base/` — multi-file tech-agnostic knowledge base organized by business domain (not by code structure).
- **Output contract** — every domain file carries YAML frontmatter (`generated_by`, classification, criticality, `verified_count`, `inferred_count`, `open_count`, `source_files_cited`) plus the mandatory 11-section template (Purpose → Source References).
- **Anti-hallucination discipline** — `[VERIFIED] / [INFERRED] / [OPEN]` markers on every non-trivial claim, `file:line` citations required, tech-agnostic vocabulary outside `## 11. Source References` and `50-integrations/`, ambiguous → `[OPEN]` never silent default, Wave 5 synthesis on main thread only.
- **Quality gates between waves** — grep checks for section presence, frontmatter compliance, and forbidden patterns. Halt on second gate failure.
- **New slash command** `/mega-sdd:extract-intelligence <legacy-path> [--out=<path>] [--seed=<path>] [--max-parallel=N] [--auto]`.
- **References split** — `references/knowledge-base-schema.md` (output shape, frontmatter contract, 11-section template) + `references/wave-dispatch-templates.md` (per-wave agent prompts, gate grep commands, token budget guidance).
- **Trigger test** — `tests/skill-triggering/extract-intelligence.test.md` covers explicit + natural English + Indonesian + orchestrate-flow auto-route + behavior checks (B1-B7).

### Changed — KB consumption integrated into existing pipeline

`extract-intelligence` is a side-lane upstream of `generate-intent`. Three existing skills updated so the rest of the pipeline can read KB as context:

- **`using-mega-sdd`** (1.0.0 → 1.1.0) — adds `docs/knowledge-base/`, `docs/mega-sdd/knowledge-base/`, `old-reference/knowledge-base/` to CWD signals. Adds trigger keywords (`reverse engineer`, `extract intelligence`, `legacy intelligence`) + Indonesian variants (`pecah legacy`, `rebuild di stack baru`, `source of truth dari legacy`). Phase ownership table extended.
- **`orchestrate-flow`** (1.1.0 → 1.2.0) — CWD inspection adds knowledge-base detection (probe order: `docs/knowledge-base/`, `docs/mega-sdd/knowledge-base/`, `old-reference/knowledge-base/`). Decision matrix adds two new rows: legacy + no PRD + rebuild intent → propose `extract-intelligence` → `generate-intent --kb=<kb>`; KB present + no vault → propose `generate-intent --kb=<kb>` directly.
- **`generate-intent`** (1.1.0 → 1.2.0) — new `--kb=<path>` flag (Mode B sub-mode). Consumes KB README + domain files as PRD-equivalent source quotes. Marker-aware: KB `[VERIFIED]` → vault body without re-asking; `[INFERRED]` → confirmation prompt; `[OPEN]` → vault OQ with original tag preserved. Q&A shorter (≤5) when `--kb` set. Detection rule 0 (kb flag) takes precedence; rule 6 auto-detects CWD knowledge-base.
- **`bind-codebase`** (1.0.0 → 1.1.0) — adds KB consultation as secondary ground truth when codebase-map verdict is "not found" (never overrides CONFLICT). KB `[VERIFIED]` → CONFIRMED (via KB note); `[INFERRED]` → CONFIRMED with downstream-revisit note; `[OPEN]` → OQ. Flags: `--kb=<path>` (override auto-probe), `--no-kb` (skip).

### Backward compatibility

All changes are additive. Projects without a knowledge-base behave identically to v1.3. KB consultation in `bind-codebase` is gated on KB presence; absence skips it. The `--kb` flag in `generate-intent` is opt-in (or auto-detected from CWD only when no other input is provided).

### Naming notice

`extract-intelligence` is the mega-sdd-flavored counterpart to `superpowers:reverse-engineering-legacy-codebase`. The skill name was chosen to avoid collision with the superpowers skill of similar purpose. Use the mega-sdd version when the next step is mega-sdd unit/bolt generation. Use the superpowers version when the workflow is standalone reverse-engineering with no downstream mega-sdd pipeline.

### Skill versions

- `extract-intelligence`: new at 1.0.0
- `using-mega-sdd`: 1.0.0 → 1.1.0
- `orchestrate-flow`: 1.1.0 → 1.2.0
- `generate-intent`: 1.1.0 → 1.2.0
- `bind-codebase`: 1.0.0 → 1.1.0

### New tests

- `tests/skill-triggering/extract-intelligence.test.md` — 6 trigger cases (E1-E6) + 7 behavior checks (B1-B7)

### Validated against

Bank Mega Trade Finance legacy PHP system (~600 files, MySQL + MSSQL + LDAP + SWIFT FTP) — 35 MD files, ~968 KB output, 13 business domains, 430 OQs surfaced, 41 hidden gotchas catalogued in ~3 hours wall-clock for 15 agent dispatches across 5 waves.

## [1.3.0] — 2026-05-17

### Added — Obsidian-friendly vault + multi-squad subagent execution

Per spec `docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md`.

Lightweight Obsidian compatibility:
- 7 prose templates gain minimal YAML frontmatter (`type`, `doc_id`, `aliases`, `tags`)
- Internal cross-refs converted to Obsidian wikilink syntax `[[file#heading]]`
- Optional `.obsidian/graph.json` template with squad color groups

Multi-squad partition as a dimension threaded through the existing 5-phase pipeline (zero pipeline change, README flowchart intact):
- New `_meta/squads.yaml` declaring squad partition (layer / feature / hybrid models)
- New `interfaces/` folder for cross-squad contracts (architect-authored, status: draft → locked)
- Units gain optional `squad:`, `produces_interfaces:`, `consumes_interfaces:` frontmatter fields
- `execute-bolts --per-squad` spawns one Claude subagent per declared squad via existing `subagent-driven-development`
- `execute-bolts --squad=<id>` filters to one squad for dev-team handoff
- `generate-units` validates intra-squad-only `depends_on` and interface reference resolution
- `orchestrate-flow` detects multi-squad mode and suggests appropriate flags

### Halt protocol extensions (vault-contract.md §halt-protocol)

Four new blocker types:
- `cross_squad_dep_invalid` (generate-units rejects cross-squad direct depends_on)
- `interface_ref_missing` (generate-units dangling interface reference)
- `cross_squad_ambiguous` (generate-units two squads claim same artifact)
- `cross_squad_interface_draft` (execute-bolts consumer waits for producer to lock interface)

### Skill versions

- `generate-intent`: 1.0.0 → 1.1.0
- `generate-units`: 1.0.0 → 1.1.0
- `execute-bolts`: 1.0.0 → 1.1.0
- `orchestrate-flow`: 1.0.0 → 1.1.0

### Backward compatibility

- Existing v1.0–v1.2 vaults work unchanged (single-squad / no-squad-config mode active)
- Multi-squad is OPT-IN via the new Q&A in `generate-intent`
- No new skills; plugin skill count unchanged
- AI consumer skills (`bind-codebase`, `resolve-oq`, `detect-drift`, `diff-vault`) behave identically across v1.2 and v1.3 single-squad vaults

### New tests

- `tests/skill-triggering/`: 14 new cases across `generate-units`, `execute-bolts`, `orchestrate-flow`
- `tests/integration/e2e-multi-squad.test.md`: full multi-squad pipeline walkthrough

## [1.2.0] — 2026-05-13

### Added — Mode auto-detect for generate-intent

- **`generate-intent` auto-detects Mode A (PRD parse) vs Mode B (free-text Q&A)** from positional argument shape — no flag required.
  - Existing file path → Mode A
  - Quoted brief or whitespace input → Mode B
  - `--from-prompt` flag still works for explicit override
  - Edge cases (missing file, bare word, flag+positional conflict) handled with user-facing warnings
- New test fixture `tests/skill-triggering/generate-intent.test.md` covers 10 auto-detect cases (AD1-AD10) mapping to 6 detection rules + 2 edge cases.

### Changed — Tiered README

- **Root `README.md`** restructured for tiered surface:
  - Front-page (always visible): TL;DR + Why + actor flow diagram + 3 Primary commands + Anti-hallucination + Install (~150 lines visible)
  - 5 collapsed `<details>` sections preserve full content: Advanced commands (8 more), Architecture deep dive (5W1H, detailed Mermaid, ASCII, halt protocol, etc.), Repository structure, Migration from grand-design-spec, Procedure cheat-sheet
  - Single visible Mermaid (actor flow); detailed pipeline moved to Architecture deep dive
  - All v1.1 content preserved — just relocated/collapsed
- **`plugins/mega-sdd/README.md`** refreshed to mirror tiered style at smaller scale.
- **Cheat-sheet** updated: greenfield scenario now shows `/mega-sdd:generate-intent "your idea"` (no `--from-prompt` needed thanks to auto-detect).

### Migration

Fully backwards compatible. Existing v1.0.x/v1.1.x vaults load unchanged. All existing invocation patterns continue to work:
- `--from-prompt "..."` — still works, takes precedence as explicit override
- `./prd.md` — still works
- Empty args + CWD scan — still works
- New: just type `"your brief"` directly without any flag — auto-detected as Mode B.

### Marketplace

- `mega-sdd@1.2.0` published
- `grand-design-spec@0.16.0` continues deprecated; removed at v1.3.0 per existing schedule

## [1.1.0] — 2026-05-13

### Added — Source-code OQ deferral + structured halt protocol

- **resolve-oq 4-action menu** — Per OQ: Answer / Defer-to-binding / Out-of-scope / Skip. Defer option appears only in brownfield context (vault.mode=existing AND repo signals present).
- **resolve-oq `--binding` mode** — Procedure documented for walking CONFLICT + propagated deferred-OQ entries from `binding.md`. Per-conflict actions: KEEP_VAULT / KEEP_CODE / DEFER / SPLIT.
- **bind-codebase auto-resolution** — Deferred-binding OQs auto-resolve against codebase-map evidence (high-confidence single match); else propagate to `binding.md` Open Questions for user resolution via `resolve-oq --binding`.
- **vault-contract §halt-protocol** extended 3 → 8 structured types: + `bind_conflict`, `dep_missing`, `test_fail`, `cycle_detected`, `mode_migrate`.
- **routing-rules.md** intent gate excludes deferred OQs (`Vault has unresolved P0/P1 OQs with status != deferred` — deferred propagate to binding).

### Changed — Skill alignment

- **vault.json OQ schema** gains optional fields: `status` (pending|resolved|deferred|out-of-scope), `defer_to` (binding|stakeholder), `deferred_at`, `deferred_reason`, `out_of_scope_reason`. Backwards compatible — absent `status` treated as `pending`. Pre-v1.1 `defer_note` semantics now unified under `deferred_reason`.
- **bind-codebase SKILL.md** standardizes `<vault>-bound/` sibling naming throughout (was mixed with generic `bound-vault/`).
- **generate-intent SKILL.md** `--auto` default output path aligned to `docs/mega-sdd/vaults/<slug>/` (was `./<slug>-spec/`).
- **commands/detect-drift.md** output filename corrected to `DRIFT-REPORT.md` (matches skill SKILL.md).
- **bind-codebase, execute-bolts, generate-units, orchestrate-flow** emit structured halt YAML per §halt-protocol (was prose-only).
- **resolve-oq stakeholder-defer reconciliation** — Old Step 2c bespoke `defer_note` semantic merged into the new unified OQ schema (`defer_to: stakeholder` + `deferred_reason`).

### Fixed — README defects (audit findings F1-F8)

- Halt protocol section: 5 fabricated types replaced with the now-real 8-type list.
- `--chain` flag references removed (3 spots in cheat-sheet) — flag never existed.
- `update-plugin` moved from skills table to commands footnote (no backing SKILL.md).
- Skill count "11" corrected to "10 + 1 command-only".
- Plugin version aligned across `plugin.json`, marketplace.json, and both READMEs.
- Both diagrams add `{P0/P1 non-deferred OQs?}` intent-gate decision node visible in actor flow + detailed pipeline.
- Defense layer 4 wording: "runs post-bolt" → "suggested post-bolt; runs on demand".

### Migration

Fully backwards compatible. Existing v1.0.x vaults load without conversion. To benefit from new resolve-oq actions, re-invoke `resolve-oq` on existing vaults — 4-action menu appears for any pending OQ.

### Marketplace

- `mega-sdd@1.1.0` published
- `grand-design-spec@0.16.0` continues deprecated; removed at v1.2.0 per existing schedule

## [1.0.0] — 2026-05-13

### BREAKING — rename to mega-sdd

The plugin is renamed from `grand-design-spec` to `mega-sdd`. All skill, command, and namespace identifiers change. See migration table in `plugins/mega-sdd/README.md`.

### Added — Spec-Driven Development pipeline

- **`scan-codebase` skill** — heuristic repo mapping → `codebase-map.md` (brownfield prep)
- **`bind-codebase` skill** — vault validation gate; produces `bound-vault/` + `binding.md`; BLOCKS unit generation on conflicts (the keystone anti-hallucination layer)
- **`generate-units` skill** — bound-vault → atomic AI-executable unit specs with dependency graph
- **`execute-bolts` skill** — unit → code via superpowers integration; TDD discipline; halt protocol
- **`using-mega-sdd` anchor skill** — session-start injected for SDD-scoped sessions (scoped triggers)
- **SessionStart hook** — injects anchor when SDD signals detected in CWD; surfaces install hint if superpowers missing
- **Vendored superpowers fallback** — `_vendored/` namespace ensures bolts execute even when superpowers plugin not installed; `scripts/sync-superpowers.sh` automates refresh

### Changed

- `grand-design-spec` skill → `generate-intent` (absorbs `from-prompt` mode as `--from-prompt` flag)
- `flow` skill → `orchestrate-flow` (extended routing for new SDD phases; 3-skill chain cap preserved)
- `drift-detect` skill → `detect-drift`
- `vault-diff` skill → `diff-vault`
- `update` skill → `update-plugin` (now also runs dep-doctor)
- All version frontmatters → `1.0.0`

### Removed

- `from-prompt` skill (absorbed into `generate-intent`)
- `from-prompt` command (deprecated alias retained for back-compat, removed in v1.2)

### Deprecated

- `grand-design-spec` listing in marketplace (will be removed in 2 release cycles)
- `/mega-sdd:from-prompt` command alias (use `--from-prompt` flag instead)

### Marketplace

- Added `mega-sdd` entry (version 1.0.0)
- Marked `grand-design-spec` entry as deprecated, pointing to `mega-sdd`

### Documentation

- Plugin README rewritten with Mermaid flow diagram + ASCII fallback + procedure cheat-sheet
- New CLAUDE.md (contributor guidelines for AI agents)
- New tests/ tree with skill-triggering fixtures + hook + vendoring tests
- New `docs/mega-sdd/` output convention dirs

### Migration

Existing `grand-design-spec` users:
1. `/plugin install mega-sdd`
2. Replace `grand-design-spec:` → `mega-sdd:` in any scripts/docs (use rename table in plugin README)
3. Existing vaults are compatible — no manual conversion needed
4. To benefit from binding gate on existing vaults: run `/mega-sdd:scan-codebase` then `/mega-sdd:bind-codebase <vault>`

## [0.15.0] — 2026-05-10

The prompt-input release. Adds `/grand-design-spec:from-prompt` so users can start from a free-text brief instead of a PRD doc — eliminating the ChatGPT-to-Claude round-trip for prompt engineering. The orchestrator's `flow` chain becomes default-on across all rules: every invocation now walks the lifecycle to its natural endpoint without opt-in friction.

### Skill version moves

- `from-prompt`: **NEW at 0.1.0** (brief → seed-PRD elaborator)
- `flow`: 0.1.0 → **0.2.0** (Rule 0 + default-on chaining for Rules 1, 2, 4, 5, 6 + arg parsing extension for free-text prompts)
- `grand-design-spec`: unchanged at 0.10.0 (consumes seed-PRD.md as a normal source — no behavior change needed)
- `resolve-oq`: unchanged at 0.4.0
- `vault-diff`: unchanged at 0.3.0
- `drift-detect`: unchanged at 0.3.0

### Added

- **`/grand-design-spec:from-prompt`** — converts a free-text brief into `<output-dir>/source/seed-PRD.md`. Workflow: capture brief verbatim → adaptive Q&A across 10 fixed taxonomy topics (skip topics already covered in brief, hard cap at 10 questions) → compose seed-PRD with citation markers (`(brief)` / `(Q&A §N)` / `(unspecified)`) on every claim → write to disk. Substance prompts always interactive even with `--auto`. Halt protocol: emits `blocker` (type=`oq_blocker`, tag=`OQ-FROMPROMPT-0`) when brief is unparseable in `--auto` mode.
- **Rule 0 in `flow`'s decision matrix** — fires when no vault and no PRD file detected and prompt arg given. Auto-chains `from-prompt → grand-design-spec → resolve-oq (scope=p1-only)`. drift-detect not applicable (mode=new for prompt-input vaults).
- **Default-on chaining for `flow` Rules 1, 2, 4, 5, 6** — `resolve-oq` and `drift-detect` (when applicable) now chain automatically instead of being opt-in/conditional. User skips individual steps via `Edit plan: skip step N` in Step 3 confirmation. Plan-confirmation step still surfaces full chain before any skill runs.
- **Free-text arg parsing in `flow` Step 0** — args >20 chars without path-like characters are recognized as prompts (persisted as `EXPLICIT_PROMPT`). Borderline ambiguous args trigger `AskUserQuestion` clarification.
- **`seed-PRD` as a recognized `vault.json.source_documents[].type`** value — documented in `from-prompt/SKILL.md` references; `vault-contract.md` §schema treats `type` as free-form so no contract change required.

### Changed

- **`flow/SKILL.md`** Step 0 arg-parsing block extended to recognize free-text prompts; Decision matrix block fully replaced with v0.2 7-rule revision (adds Rule 0, marks Rules 1/2/4/5/6 as default-on); version 0.1.0 → 0.2.0.
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.14.0 → 0.15.0.
- **`README.md`** + **`plugins/grand-design-spec/README.md`** — add `/grand-design-spec:from-prompt` row, update lifecycle diagram (from-prompt as new entry point), update repo structure with `from-prompt/` skill dir, bump changelog footer.

### Backward compatibility

- v0.14 vaults continue to work unchanged. seed-PRD.md is just another source for `grand-design-spec` — no schema or vault structure changes.
- Direct invocation of `flow` with file/dir args works exactly as v0.14 (Rule 0 only fires when args are free text).
- Direct invocation of `flow` without args produces a Rule 7 STOP if WORK_DIR is empty — same as v0.14, with updated error message mentioning prompt option.
- Default-on chaining is a behavior change for users who relied on opt-in chains in v0.14. Mitigation: plan-confirmation step shows the full chain; user edits to skip steps they don't want. No anti-halu rail changes.
- Direct invocation of any sub-skill (`from-prompt`, `grand-design-spec`, etc.) without `flow` is unchanged — full interactive behavior when `--auto` is not passed.

### Notes

- The orchestrator stays **stateless by design**. Re-running `flow` re-inspects CWD; no `.gds-state.json` is written.
- **Hard cap of 3 skills per chain** stays at 3 (verified across all 7 rules including the new Rule 0).
- **`flow` does NOT run sub-skills in parallel** — sequential only.
- Audit findings deferred to v0.16+: vault evolution from a new prompt (`from-prompt → vault-diff` chain), multi-turn brief refinement, seed-PRD versioning across runs, voice-input briefs, reorder-and-edit-args plan editing in flow.

## [0.14.0] — 2026-05-10

The agentic upgrade. Adds `/grand-design-spec:flow`, a multi-skill lifecycle orchestrator that turns the plugin from "4 separate tools" into "one workflow." Inspects CWD, proposes a sub-skill chain (e.g., "vault-diff → resolve-oq for new P1s"), confirms once, executes in `--auto` mode. Anti-halu rails preserved by composition — every rail lives in a sub-skill, untouched.

### Skill version moves

- `flow`: **NEW at 0.1.0** (lifecycle orchestrator)
- `grand-design-spec`: 0.9.0 → **0.10.0** (added `--auto` flag for logistical prompts)
- `resolve-oq`: 0.3.0 → **0.4.0** (added `--auto` for logistics; per-OQ choices stay interactive)
- `vault-diff`: 0.2.0 → **0.3.0** (added `--auto` flag; conflicts emit `blocker` type=`diff_conflict`)
- `drift-detect`: 0.2.0 → **0.3.0** (added `--auto` flag; skips interactive walkthrough; framework mismatch emits `blocker` type=`drift_framework_mismatch`)

### Added

- **`/grand-design-spec:flow`** — the orchestrator command. Inspects WORK_DIR for vault, PRD, codebase signals, P1 count, mode-migration trigger, git state. Applies a 7-rule decision matrix to build a proposed chain (max 3 skills). Single user confirmation (Run / Edit / Cancel). Edit supports `skip step N` and `stop after step N` in v0.1; reordering deferred. Stateless — resumption is just re-invoking. Pauses on `blocker` artifacts; surfaces YAML verbatim in chat.
- **`§halt-protocol`** in `references/vault-contract.md` — unified `blocker` envelope with three types: `oq_blocker` (per v0.11), `diff_conflict` (vault-diff conflicts), `drift_framework_mismatch` (drift-detect framework mismatches). Schema, field rules, type-specific guidance, multi-blocker array form, and v0.11 → v0.14 backward-compat note.
- **`--auto` convention** documented in CONTRIBUTING.md — required for any future skill with prompts. Skips logistical prompts (paths, modes, scopes); never skips substance prompts (stakeholder answers, conflict resolutions); emits `blocker` when halted autonomously.

### Changed

- **`00-index.md` template Halt protocol section** — emits `blocker: type: oq_blocker` (new unified envelope) instead of legacy `oq_blocker:` form. Backward-compat note appended for AI consumers reading v0.13 vaults.
- **`grand-design-spec/SKILL.md`** — adds `## --auto flag` section before Workflow describing how Step 0–0.7 prompts default in `--auto` mode (output folder slug-derived, mode inferred from codebase signals, PRD_STATUS=draft, OUTPUT_MODE=compact). Anti-halu rails (Figma "do you have screenshots?", destructive overwrite confirmation, OQ tagging, source citation) NEVER bypassed.
- **`resolve-oq/SKILL.md`** — adds `## --auto flag` section. Substance prompts (per-OQ Resolve/OOS/Defer/Skip choice, cross-cutting landing) ALWAYS interactive. Logistics (vault path, resume detection, scope, lock ack default) auto-defaulted.
- **`vault-diff/SKILL.md`** — adds `## --auto flag` section. Conflicts (Resolved-OQ, Decision) emit `blocker` (type=`diff_conflict`) and pause. Auto-applies non-conflict changes ≤ 50; emits `blocker` if change count exceeds cap (per OQ-FLOW-3 spec decision).
- **`drift-detect/SKILL.md`** — adds `## --auto flag` section. Skips Step 5 interactive walkthrough; writes `DRIFT-REPORT.md` only (no `DRIFT-ACTIONS.md` — deliberate human decision). Framework mismatch emits `blocker` (type=`drift_framework_mismatch`).
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.13.0 → 0.14.0.
- **`README.md`** + **`plugins/grand-design-spec/README.md`** — add `/grand-design-spec:flow` to commands tables, update lifecycle diagram (flow as recommended entry point), update repo structure with `flow/` skill dir.

### Backward compatibility

- v0.13 vaults continue to work read-only.
- AI consumers reading vault halts should accept both `oq_blocker:` (legacy v0.11–v0.13 form) and `blocker: type: oq_blocker` (new v0.14 form) for one release cycle. v0.15+ may drop legacy support.
- Direct sub-skill invocation (without `flow`) is unchanged when `--auto` is not passed — full interactive behavior per v0.13.
- `flow` is opt-in. Users who prefer manual sub-skill invocation can ignore it entirely.

### Notes

- The orchestrator is **stateless by design**. No `.gds-state.json` is written. This simplifies the contract (every flow run re-inspects CWD) but means "did I forget drift-detect?" recall depends on user re-running flow.
- **Hard cap of 3 skills per chain** prevents runaway chains. Beyond 3, orchestrator surfaces and asks for explicit confirmation.
- **`flow` does NOT run sub-skills in parallel** — sequential only. Sub-skills modifying the same vault would race otherwise.
- Audit findings deferred to v0.15+: state file with lifecycle position tracking (Approach 2 from brainstorming), reorder-and-edit-args plan editing, scheduled-mode drift-detect via `schedule` skill, self-critiquing loops (Approach 4 from brainstorming).

## [0.13.0] — 2026-05-09

Driven by the ship-readiness audit at `docs/superpowers/specs/2026-05-09-plugin-audit-design.md`. Closes 3 HIGH and 4 MED audit findings. Acknowledges that v0.11 vault.json parity was incomplete (only `resolve-oq` got write-back; `vault-diff` was missed) and lands the fix.

### Skill version moves

- `grand-design-spec`: 0.8.0 → 0.9.0 (references shared `vault-contract.md`, adds OQ_BLOCKER halt-protocol self-check)
- `resolve-oq`: 0.2.0 → 0.3.0 (removes `lock-vault` forward-references, adds vault.json count-match self-check)
- `vault-diff`: 0.1.0 → 0.2.0 (**adds Step 6.5 vault.json refresh** — closes the v0.11 parity gap)
- `drift-detect`: unchanged at 0.2.0 (documentation-only change: explicit `vault.json` reconciliation boundary)

### Added

- **`references/vault-contract.md`** (M-1, L-8, L-9) — single source of truth for the `vault.json` schema, OQ tagging conventions, status marker semantics, ID stability rules, and "Skill instruction language" boilerplate. All 4 skills now reference it instead of duplicating content.
- **`vault-diff` Step 6.5 — Refresh `vault.json`** (H-1) — after applying approved changes in Step 6, regenerate the manifest from post-apply markdown so `entities[]`, `flows[]`, `adrs[]`, `open_questions[]`, and `open_questions_summary` reflect the new state. Step 8 self-check gains 4 vault.json invariants.
- **`drift-detect` `vault.json` reconciliation boundary** (H-2) — Step 6 now explicitly documents that drift-detect produces reports only and never regenerates `vault.json`. Vault.json regen happens via `resolve-oq` (for OQ-tagged actions) or manual edit + `grand-design-spec` re-run (for entity/flow/ADR additions). Per audit OQ-AUDIT-1 decision: explicit boundary, not auto-reconcile.
- **Template compact/full markers** (M-5) — `01-overview`, `02-architecture`, `03-data-model`, `04-flows`, `05-decisions` templates now carry `<!-- compact-skip -->` and `<!-- full-only -->` HTML comments around mode-conditional content. Replaces 5 memorized runtime transformation rules with mechanical markers. `00-index` and `06-constraints` have no compact-conditional content (unchanged).
- **`grand-design-spec` Step 4 self-check** (M-6) — verifies `00-index.md` contains the "Halt protocol for autonomous runs", "Parallel-work guidance", and "Companion skills for vault evolution" sub-sections per template.
- **`resolve-oq` Step 4 self-check** (M-8) — verifies `vault.json.open_questions_summary.total` matches markdown roll-up; verifies promoted ADRs appear in `vault.json.adrs[]`.
- **`CONTRIBUTING.md`** (M-3) — documents the versioning rule (independent semver per skill, with CHANGELOG enumerating per-skill moves), commit-message scopes, tagging discipline, new-skill checklist, and spec/plan workflow.

### Removed

- **`lock-vault` forward-references** (H-3) — `resolve-oq/SKILL.md` previously mentioned a `lock-vault` skill "(when available)" twice. Replaced with explicit manual-edit instructions for `00-index.md` Vault Lock Status. Building a real `lock-vault` skill is a v0.14+ candidate.

### Changed

- `plugin.json` and `marketplace.json` plugins[0].version bumped 0.12.1 → 0.13.0 (skill behavior changes + new file structure).
- `grand-design-spec/SKILL.md` body shrinks ~60 lines as the duplicated `vault.json` schema and OQ tagging convention move to `vault-contract.md`. Net change: smaller skill body + one new reference file.

### Backward compatibility

- Existing v0.12 vaults continue to work read-only.
- Re-running `vault-diff` against a v0.12 vault now produces an updated `vault.json` (previously skipped). If the v0.12 vault was created before vault.json was introduced (pre-v0.11), Step 6.5 generates a fresh manifest from the markdown.
- Skills that don't bump (drift-detect) maintain the same input/output contract.
- The new `references/vault-contract.md` is referenced by skills but loaded on-demand — no eager-load cost on existing flows that don't touch the schema.

### Notes

- The v0.11 CHANGELOG entry implied vault.json parity that didn't exist for `vault-diff`. v0.13 explicitly closes that gap and the CHANGELOG now enumerates per-skill version moves to prevent the same drift.
- Audit findings deferred to v0.14+: a real `lock-vault` skill (H-3 alternative), template footer extraction (L-10), trigger-phrase canonical source (L-11), OQ category enumeration (M-2), `grand-design-spec/SKILL.md` progressive disclosure (L-12), tag backfill for v0.7-v0.12 (L-7).

## [0.12.1] — 2026-05-09

### Added

- **`/grand-design-spec:update`** — convenience command that pulls the latest plugin from `origin/main` (fast-forward only), shows before/after versions, and instructs the user to finish with the built-in `/plugin marketplace update grand-design-spec` to rebuild the cache. Custom slash commands can't invoke built-ins, so the cache-refresh step stays explicit.

### Changed

- `plugin.json` and `marketplace.json` plugins[0].version bumped 0.12.0 → 0.12.1 (additive command).

## [0.12.0] — 2026-05-09

Surfacing companion skills as user-typeable slash commands.

### Added

- **`/grand-design-spec:grand-design-spec`** — main vault generator now invokable from autocomplete with optional `[prd-path] [figma-url]` arguments.
- **`/grand-design-spec:resolve-oq`** — interactive Open Questions resolver, callable directly with `[vault-path] [optional OQ tag]`.
- **`/grand-design-spec:vault-diff`** — vault ↔ revised PRD diff report, callable with `[old-vault] [new-prd]`.
- **`/grand-design-spec:drift-detect`** — vault ↔ codebase reconciliation, callable with `[vault-path] [codebase-root]`.

### Why

Until v0.11, the three companion skills (`resolve-oq`, `vault-diff`, `drift-detect`) were Claude-invoked only via the Skill tool — they did not appear in the `/` autocomplete menu, so users had to ask Claude in prose to trigger them. v0.12 adds explicit command files in `plugins/grand-design-spec/commands/` that mirror each skill, making the full lifecycle (generate → resolve → diff → drift) discoverable from the slash menu.

### Changed

- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.11.0 → 0.12.0 (additive feature: command surface).

### Backward compatibility

- No skill behavior changed — command files are thin wrappers that delegate to the existing skills.
- Users on v0.11 can keep invoking skills via prose; v0.12 simply exposes a faster discovery path.

## [0.11.0] — 2026-05-09

Driven by audit findings from the TimeOff smoke-test dogfood (commit `e6bada4`). Three Tier-1 refinements + two Tier-2 quick wins, focused on bridging vault generation to actual consumption by AI dev tools.

### Added

- **`vault.json` machine-readable manifest** (R1, generated alongside the 7 markdown files in Step 3). Structured index of entities, flows, ADRs, OQs (with state + priority + category + resolver_owner), source documents, and Step-2 design-system flags. Markdown stays human-authoritative; JSON optimizes machine consumption — AI dev tools load context in <1K tokens instead of brute-parsing 25K+ of prose. Schema documented inline in SKILL.md Step 3. Step 4 self-check verifies markdown ↔ JSON consistency on every regeneration.
- **`OQ_BLOCKER` halt artifact format** for autonomous AI consumers (R2). Defined in `00-index.md` template "Halt protocol for autonomous runs" sub-section. When an AI agent hits an unresolved P1 OQ in non-interactive mode, instead of silent halt it emits a structured YAML artifact with `tag`, `priority`, `blocking_task`, `resolver_owner`, `resolver_route`, `vault_version`. Agent runners can route this to ticketing / Slack / on-call pages reliably. Single-blocker and multi-blocker formats both defined.
- **Mode migration trigger** (R3) — new Vault Lock Status field `mode_migrate_after`. Captures the event that flips a `mode=new` vault to `mode=existing` (e.g., "first commit on main", "first prod deploy", "sprint-1 demo"). Step 0.5 of `grand-design-spec` now prompts for this when mode=new. After trigger fires, user manually flips mode + bumps version + adds Changelog, OR runs `vault-diff`. Once flipped, `drift-detect` becomes applicable.
- **Parallel-work guidance** in `00-index.md` template (R5) — when P1 OQs block a task, lists artifact types the dev/AI can still produce in parallel (test specs from DoD, scaffolded ORM models with TODO markers, UI stubs, OOS confirmations). Each parallel artifact must carry the OQ tag(s) it depends on so it's revisited on resolution.
- **Cross-cutting OQ multi-doc landing pattern** in `resolve-oq` Step 2c (R7). When a single OQ resolution legitimately affects 3+ docs (tech-stack, multi-tenancy, auth, compliance), skill writes the primary entry once and adds terse cross-reference lines in other affected docs (`> Resolves OQ-{tag}: see {primary-doc}.md#{anchor}`). All point back to the OQ tag for audit. Heuristic for "cross-cutting" documented inline.
- **`vault.json` write-back in `resolve-oq`** — every Resolve / Out-of-Scope / Defer outcome updates the manifest's `open_questions[]` status field, recomputes `open_questions_summary` counts, and (for promoted Resolve) appends new ADRs to `adrs[]`. Keeps machine-readable index in sync with markdown.
- **`drift-detect` mode-migration awareness** — when run on a `mode=new` vault, surfaces the `mode_migrate_after` trigger so the user knows what to do before re-running. Better failure mode than the previous flat "this skill doesn't apply".

### Changed

- **`grand-design-spec` SKILL.md** version bumped 0.7.0 → 0.8.0 (added `vault.json` generation in Step 3 + Step 4 self-check + Step 0.5 migration trigger + halt protocol section in template).
- **`resolve-oq` SKILL.md** version bumped 0.1.0 → 0.2.0 (cross-cutting OQ multi-doc landing + vault.json write-back).
- **`drift-detect` SKILL.md** version bumped 0.1.0 → 0.2.0 (mode-migration awareness in Step 0).
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.10.0 → 0.11.0 (skill behavior changes).
- **`00-index.md` template** — Vault Lock Status gains `mode_migrate_after` field; Implementation Notes section gains "Halt protocol for autonomous runs" + "Parallel-work guidance" sub-sections.

### Backward compatibility

- Existing v0.10 vaults continue to work read-only. Companion skills (`resolve-oq`, `vault-diff`, `drift-detect`) handle the absence of `vault.json` gracefully — they fall back to parsing markdown.
- To upgrade an existing v0.10 vault to v0.11: re-run `/grand-design-spec:vault-diff` against the same PRD; the diff session writes `vault.json` and adds `mode_migrate_after` to Vault Lock Status. Or edit `00-index.md` manually.
- Existing OQs resolved before v0.11 carry no `vault.json` entry; the next resolve-oq round repopulates the manifest from current markdown state.

### Notes

- The audit that drove this release: vault generation works (TimeOff smoke test, 1187 lines, 48 OQs, 95% anti-halu compliance), but AI dev consumption was the bottleneck — 25K+ tokens to load full markdown, no halt protocol for autonomous runs, no migration path for greenfield projects, fuzzy boundaries on cross-cutting OQ resolution. v0.11 directly addresses these.
- Tier 2 items deferred to v0.12+: `extract-context <flow-id>` skill (return min vault subset for a specific flow), DoD → test spec auto-conversion, pre-commit drift-detect integration, vault → tickets generator.
- Mega Rencana (`mode=existing`, mobile-app, ID) and TimeOff (`mode=new`, web-app, EN) smoke fixtures remain valid as v0.11 examples; regenerating them produces vault.json automatically.

## [0.10.0] — 2026-05-08

### Added
- **`drift-detect` skill (new, v0.1.0)** — detects drift between a `mode=existing` vault (target spec) and live codebase (current reality). Heuristic scan of entities, flows, endpoints, and decisions; produces a structured `DRIFT-REPORT.md` with confidence-rated findings. Closes the loop between vault generation and shipped code for revamp / extension projects. Invoke with `/grand-design-spec:drift-detect`.
- **Eight drift outcome categories**: Missing in code, Missing in vault, Name drift, Type drift, Behavior drift, Decision violation, Decision unwritten, Confirmed match.
- **Confidence ratings per finding** — `high` (exact name + type match found / not-found), `medium` (similar names but different signatures), `low` (heuristic keyword guess). Low-confidence findings carry explicit "verify manually" caveats.
- **Direction-neutral framing** — every finding presents vault state and code state side-by-side. The skill never says "code is wrong" or "vault is stale"; only "they disagree, here's where each lives".
- **Decision violations & unwritten ADRs surfaced PRIORITY-1** — these correspond to compliance / architectural debt and most often require stakeholder review.
- **Framework auto-detection** — skill identifies the codebase framework (Laravel, Rails, Spring, Express, Django, Flutter, etc.) via lockfile / manifest signatures and proposes default scope dirs. User confirms or overrides.
- **Drift scope selection** — `full` (default), `schema-only`, `flows-only`, `decisions-only`, or `single-doc`.
- **`DRIFT-ACTIONS.md` artifact** — captured user decisions per finding (split into Code-side actions and Vault-side actions). The skill never executes code changes; it produces an actionable list for engineering team follow-up.
- **OQ cross-reference scan** — detects when codebase mentions `OQ-{CODE}-{N}` tags and flags any references to still-open OQs as "code references unresolved OQ".

### Changed
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.9.0 → 0.10.0 (new skill addition).

### Notes
- The skill is **heuristic**, not a static analyzer. False positives and false negatives both happen. Treat findings as triggers for human review, not verdicts.
- Decision compliance is the lowest-confidence axis — keyword-based detection only catches obvious cases. For comprehensive compliance, this skill complements (not replaces) code review and architecture review.
- The skill writes report artifacts but **never modifies the codebase or the vault directly**. All actions are captured for deliberate human follow-up.
- For `mode=new` projects there's no codebase to scan — the skill bails politely and points to `vault-diff` if the user is comparing PRD versions.
- The four skills now form a complete vault lifecycle: `grand-design-spec` (initial generation) → `resolve-oq` (interactive OQ resolution) → `vault-diff` (vault evolution across source revisions) → `drift-detect` (vault vs codebase reconciliation for `mode=existing`).

## [0.9.0] — 2026-05-08

### Added
- **`vault-diff` skill (new, v0.1.0)** — evolves an existing vault when the PRD/BRD/Figma source revisions, without losing resolved OQs, ADR provenance, or Changelog history. Invoke with `/grand-design-spec:vault-diff`. The naive alternative ("delete vault, regenerate") destroys every captured stakeholder decision and starts the OQ list from zero — this skill exists specifically to make vaults survive past sprint 1.
- **Eight diff outcome categories** with explicit handling rules: Auto-resolved OQ, New OQ, Added (entity/flow/decision/section), Changed, Removed (annotated, never deleted), Resolved-OQ conflict, Decision conflict, Unchanged.
- **`VAULT-DIFF.md` artifact** — the skill writes a structured diff report into the vault directory before applying changes. Persistent record the user reviews offline; conflicts surfaced at the top of the file so reviewers see them first.
- **Conflict-first walkthrough** — Step 5 prioritizes Resolved-OQ conflicts and Decision conflicts before any other category. User decision required for each (Supersede / Keep vault / Capture both / Skip). Skill never auto-decides on conflicts.
- **Diff scope selection** — `full` (default), `oq-only` (fast pass for minor PRD clarifications), or `specific-docs` (surgical update of named docs only).
- **Removed-content preservation** — entities/flows/decisions removed from new PRD are NOT deleted from vault; they get a `> **Removed in v{X.Y}**` banner. The vault retains history; the Changelog records the removal.
- **Identifier stability** — OQ tags, flow IDs, ADR D-XXX numbers all survive the diff. New entries get next-available IDs; existing IDs preserved in place.
- **Git safety check** — Step 0 runs `git status` and recommends commit-before-diff so the diff session is rollback-able. Doesn't refuse without git, but warns.

### Changed
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.8.0 → 0.9.0 (new skill addition).

### Notes
- The skill never auto-resolves conflicts. "Auto-resolve all" requests are refused — conflicts (vault state vs new PRD) are exactly the cases requiring human judgment.
- Major scope shifts (>50% removed entities, >30% added, project name divergence) trigger a "this looks like a different project, are you sure?" prompt before proceeding.
- LOCKED vaults require explicit unlock confirmation before diff is applied (re-sign-off needed after).
- The three skills now form a complete vault lifecycle: `grand-design-spec` (initial generation) → `resolve-oq` (interactive OQ resolution) → `vault-diff` (evolution across source revisions).

## [0.8.0] — 2026-05-08

### Added
- **`resolve-oq` skill (new, v0.1.0)** — interactive resolver for Open Questions in an existing vault. Companion to the main `grand-design-spec` skill. Walks the OQ roll-up by priority (P1 → P2 → P3), captures stakeholder answers per OQ, updates the vault, and bumps version + Changelog. Invoke with `/grand-design-spec:resolve-oq`.
- **Four resolution outcomes per OQ**: `Resolve` (capture answer inline or promote to a target section like new ADR / field constraint), `Out of Scope` (move to OOS section with rationale), `Defer` (keep open with stakeholder + target date), `Skip` (no change, return next round).
- **Resume support** — re-running the skill on a partially-resolved vault detects prior rounds via Changelog entries and offers to continue from current state.
- **Resolution scope selection** — `p1-only` (focused first pass), `p1-then-p2`, `all-priorities`, `by-category` (group by roll-up category, useful when each category aligns with a different stakeholder), or `single-oq` (jump to a tag).
- **Auto-classification of resolution destination** by OQ code prefix (`OV-` → 01-overview, `AR-` → 02-architecture, `DM-` → 03-data-model, `FL-` → 04-flows, `DC-` → 05-decisions, `CN-` → 06-constraints), with explicit user override allowed.
- **OQ tag preservation** through resolution — every OQ identifier survives via `[x]` resolved markers, `[~]` out-of-scope markers, or stays `[ ]` with a Deferred annotation. Full audit trail of what was decided when.
- **Atomic per-OQ edits** — bail-out at any time preserves partial progress for the next run.

### Changed
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.7.0 → 0.8.0 (new skill addition).

### Notes
- The new skill never auto-fills answers. Refusing "answer all OQs for me" is a hard guarantee — the skill exists to capture **stakeholder** input, not Claude's guesses. Offer Defer instead.
- Resolution density adapts to the parent vault's `OUTPUT_MODE`. Compact vaults get inline resolutions or 1-paragraph promoted ADRs; full vaults get multi-section promoted ADRs.
- The `grand-design-spec` skill itself remains at v0.7.0 — no changes to the main vault generator in this release.

## [0.7.0] — 2026-05-08

### Added
- **`OUTPUT_MODE=compact|full` flag (Step 0.7).** New mandatory step after PRD status flag. Captures the verbosity tier of vault output. Drives Step 3 generation rules per the Output mode policy table. Default: `compact`.
  - `compact` (default) — table-first, prose-cut, ~40% lighter token output. 1-line TL;DR header, API contracts as tabel (skip JSON example unless payload non-trivial), DBML-only entity descriptions, ADR as 1-paragraf format, OQ entries as 1-line, glossary skips generic IT terms.
  - `full` — verbose, prose-rich. 3-line TL;DR header, full request/response JSON per endpoint, prose entity descriptions alongside DBML, multi-bullet ✅⚠️ consequences per ADR. For audiences including non-technical reviewers (BO, legal, compliance).
- **Output mode policy table** in `## File-by-file content guide` mapping per-doc behavior (TL;DR, API contracts, entity descriptions, flow blocks, decision blocks, glossary, OQ entries) across both modes. Replaces the prior vague "as simple as possible" guidance with concrete, measurable rules.
- **Auto-default conditions** — skill picks `compact` without asking when user explicitly requested terse output or runs in autonomous / no-pause mode. Echoes auto-default with reason.
- **Hard invariants section** — explicit list of anti-hallucination guarantees preserved in BOTH modes (source citation, OQ tag + priority, DoD per flow, decision source, Out of Scope never empty). Compact mode never weakens grounding.
- **Step 4 self-check items** for output mode compliance — 8 new checks covering compact-mode formatting + 6 hard-invariant checks that apply regardless of mode.
- **`Output mode` field in `00-index.md > Vault Lock Status`.** Surfaced to downstream AI consumers + readers so they know which verbosity tier the vault was generated in.
- **Step 5 hint** — when `compact` mode used, summary mentions opt-in to `full` mode for re-run if needed.

### Changed
- **`## Length & simplicity policy`** renamed to **`## Output mode policy`** and rewritten from 4-bullet vague guidance to a 10-row aspect-by-mode tabel + invariants block + audience principle.
- **Per-doc TL;DR template** updated to show both 1-line (compact) and 3-line (full) format with mode markers.
- **`02-architecture.md` API contracts guidance** — adds explicit compact behavior (tabel default, JSON only for non-trivial payloads) vs full behavior (full JSON per endpoint).
- **`03-data-model.md` guidance** — compact = DBML + 1-line `Purpose:` per entity, skip prose section. Full = DBML + per-entity prose + field-level validation tabel.
- **`04-flows.md` guidance** — compact skips Preconditions/Postconditions blocks (derivable from steps + DoD), keeps Steps + DoD + cross-cutting handoffs. Full = all template sections.
- **`05-decisions.md` guidance** — compact = 1-paragraf ADR format, full = multi-section block with Status/Date/Context/Decision/Consequences/Source.
- **`00-index.md > Glossary` and `> Open Questions roll-up`** — compact mode cuts generic IT terms from glossary, OQ entries become single-line. Full mode preserves prior verbose format.
- **`SKILL.md` frontmatter** version bumped 0.6.0 → 0.7.0.
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.6.0 → 0.7.0.

### Backward compatibility
- v0.6 vaults remain valid. No migration step.
- v0.7 with `OUTPUT_MODE=full` produces output **structurally identical to v0.6** (modulo the new `Output mode` line in Vault Lock Status). Use `full` to retain v0.6 verbosity verbatim.
- v0.7 with `OUTPUT_MODE=compact` (the new default) produces a leaner vault that preserves every source citation, every Open Question, every Definition of Done, every cross-cutting handoff — only narrative scaffolding is cut.
- The four v0.6 design-system detection flags (`HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`) and conditional sections continue to work unchanged in v0.7. Output mode only controls verbosity per-section, not section presence.

### Notes
- Anti-halu invariants are **hard guarantees** in both modes. Compact mode trades narrative scaffolding for token efficiency, never grounding strength. A compact-mode vault and a full-mode vault generated from the same PRD will list the same OQs (with same tags + priorities), cite the same sources, and contain the same DoD checklists — only the prose density differs.
- The "audience principle" is documented inline: compact targets builders (architect, dev, QA) who can read tabel + DoD without prose hand-holding; full targets cross-functional reviewers (PM, BO, legal, compliance) who need narrative context.

## [0.6.0] — 2026-05-08

### Added
- **Optional design-system coverage for UI projects.** When source documents (PRD / Figma via MCP / uploaded tokens files) explicitly contain design-system content, the vault now emits two new sections:
  - **`02-architecture.md > UI components & patterns`** sub-section under each UI layer. Components table (spec voice) + Patterns prose (guide voice — when-to-use rules). Triggered by `HAS_UI_COMPONENTS=true` flag from Step 2 detection.
  - **`06-constraints.md > Design system`** top-level section alongside Technical / Business / NFR. Three sub-blocks (Tokens / Accessibility / Voice & brand), each independently conditional on its specific flag.
- **Step 2 design-system content detection.** Skill scans all sources for explicit mentions of UI components, design tokens, a11y standards, and voice/brand rules. Persists four flags: `HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`. Flags drive Step 3 conditional generation.
- **Source merge rules** when multiple design-system sources are provided (Figma + tokens.json, multiple Figma URLs, etc.). Higher priority wins for the same value (Figma > tokens file > PRD-stated). Equal-precedence disagreement → emit `OQ-CN-{N} [P1]` with both quoted values; never silent pick.
- **Conditional UI/UX or FE Dev reading path** in `00-index.md`. Appears only when at least one of the new design-system sections is present.
- **Conditional design-system glossary entries** in `00-index.md` (design tokens, design system, WCAG, a11y, semantic HTML). Appear only when terms are used elsewhere in the vault.
- **Six new Step 4 self-check items** for design-system grounding. Apply only when at least one design-system section is present in the vault.

### Changed
- **Anti-hallucination rule extended** from v0.5's "no invented content within sections" to v0.6's "no invented sections." Section presence is determined by source coverage alone — `PROJECT_SHAPE` is NOT a trigger. Vault never auto-creates design-system sections because shape inference suggests UI. Vault never defaults to industry standards (WCAG 2.1 AA, Material Design, iOS HIG, Tailwind defaults) when sources are silent.
- **Push-back rules** gain explicit "design-system absence is acceptable" sub-section. Skill MUST NOT prompt the user for missing design-system sources. PRD silent on FE → vault silent on FE. No exception, no questioning.
- **`SKILL.md` frontmatter** version bumped 0.5.0 → 0.6.0.
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.5.0 → 0.6.0.

### Backward compatibility
- v0.5 vaults remain valid. No migration step.
- v0.6 for projects without design-system source coverage produces output **identical to v0.5**. The four detection flags simply stay `false` and no sections are added.
- v0.6 with full design-system coverage adds two sub-sections, one top-level section, one reading path, and up to five glossary entries — all conditional, all source-cited.

### Notes
- The four detection flags (`HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`) are independent. A project might surface tokens but not components (e.g., PRD spells out brand colors but Figma is unavailable), and vice versa. Each flag is independently evaluated.
- Existing-codebase reconciliation for design system remains the downstream AI consumer's job. Vault generator never reads codebase, even when `IMPLEMENTATION_MODE=existing` and a design-system package exists in the repo.

## [0.5.0] — 2026-05-08

### Added
- **`PRD_STATUS=final|draft` flag (Step 0.6).** New mandatory step after implementation mode flag. Captures whether the source PRD/BRD is signed-off (`final`) or still in flux (`draft`). Drives gap-handling and push-back behavior throughout the workflow.
  - `final` → skill never pauses for clarification, even when gap count is large or PRD is contradictory. All ambiguities funnel into Open Questions roll-up. User triages OQ list with stakeholder offline, post-vault.
  - `draft` → existing behavior preserved. Skill pauses when gap count > 10, surfaces contradictions inline, asks for resolution before generating.
- **`PRD status` field in `00-index.md > Vault Lock Status`.** Surfaced to downstream AI consumers (Claude Code, Cursor) so they know the OQ list is the authoritative gap inventory under `final` mode.
- **PRD source file annotation.** `<filename> — FINAL | DRAFT` marker in Vault Lock Status PRD source line.

### Fixed
- **Tool name references for Claude Code distribution.** SKILL.md previously used Claude.ai sandbox API names that don't resolve under `/plugin install`:
  - `tool_search(query="figma")` → `ToolSearch` with `query: "figma"` or `query: "select:..."` syntax.
  - `ask_user_input_v0` → `AskUserQuestion`.
  - `present_files` → no tool needed in Claude Code (files already on disk after Step 3); fall back kept for Claude.ai sandbox.
  - `view` (template read) → `Read`.
- **Step 3 template path stale post-v0.4.0 restructure.** Plugin-installed skills no longer land at `~/.claude/skills/`. Updated to use `${CLAUDE_PLUGIN_ROOT}/skills/grand-design-spec/references/templates/` as the primary path. Manual-install and Claude.ai sandbox paths kept as fallbacks.
- **Push-back rules** restructured to clearly distinguish always-push-back cases (Figma missing, "just guess the rest", path mismatch) from `draft`-only cases (missing sections, contradictions, large gap count).
- **`03-data-model.md` template typo**: "follow project conventions Han already confirmed" → "follow project conventions you've already confirmed with the team".
- **`.gitignore`**: removed project-specific `mega-rencana-spec/` entry (test fixture leak).

### Changed
- **`marketplace.json`**: dropped redundant top-level `version` field. Marketplace itself isn't versioned; each plugin entry now owns its version (`plugins[].version: "0.5.0"`).
- **`plugin.json`** version bumped 0.4.0 → 0.5.0.
- **`SKILL.md` frontmatter** version bumped 0.4.0 → 0.5.0.
- **README "What happens next"** updated with the new PRD-status question.

### Notes
- `final` mode does NOT relax anti-hallucination guarantees. Skill still refuses "just guess the rest" — `final` only changes whether the skill pauses to ask stakeholder synchronously, not whether Claude can fill in blanks. Gaps remain Open Questions, never silently filled.
- For `final` mode contradictions, the skill writes OQ entries with both PRD quotes side-by-side so stakeholder can rule which is canonical without re-reading the original doc.

## [0.4.0] — 2026-05-08

### Changed
- **Repository restructured to Claude Code Plugin Marketplace format.** Added `.claude-plugin/marketplace.json` at repo root and `plugins/grand-design-spec/.claude-plugin/plugin.json` at plugin root. Skill files (`SKILL.md`, `references/templates/*.md`) moved to `plugins/grand-design-spec/skills/grand-design-spec/`. Marketplace catalog points to the plugin via relative path source `./plugins/grand-design-spec`.
- **Install flow.** Now installable via `/plugin marketplace add <gitlab-url>` + `/plugin install grand-design-spec@grand-design-spec` instead of manual `git clone` to `~/.claude/skills/`. Version pinning via `#v0.4.0` ref appended to the GitLab URL.
- **Plugin-level README** added at `plugins/grand-design-spec/README.md` (focused on what the plugin does + trigger phrases). Root `README.md` now describes the marketplace itself and installation across Claude Code, Claude.ai, and Claude API.
- **`SKILL.md` frontmatter** version bumped 0.3.0 → 0.4.0. No skill content changes — behavior identical to v0.3.0.

### Notes
- Existing users who installed via `git clone` to `~/.claude/skills/` should remove the old clone (`rm -rf ~/.claude/skills/grand-design-spec`) before installing via `/plugin install` to avoid duplicate skill registration.

## [0.3.0] — 2026-05-08

### Added
- **Project Shape Registry** in `SKILL.md`. 5 pre-templated shapes (`mobile-app`, `web-app`, `api-only`, `multi-platform`, `data-pipeline`) + `custom` fallback. Skill is now general-purpose, not biased toward mobile banking.
- **Step 2 — Project shape inference + confirmation**. Skill infers shape from PRD content using heuristics, presents reasoning to user, asks for confirm/override. Custom shape triggers user-described layers.
- **`PROJECT_SHAPE` flag** persisted alongside `IMPLEMENTATION_MODE`, drives sub-section structure in `02-architecture.md`, `04-flows.md`, and reading paths in `00-index.md`.
- **Project shape field** in `00-index.md > Vault Lock Status`.
- **Shape-aware Implementation Notes for AI Consumers** in `00-index.md` — instructs AI consumer to confirm both shape AND mode before code work, and to use the relevant layer section based on what's being implemented.

### Changed
- **`02-architecture.md` template** is now shape-agnostic. Layer sub-sections derived from `PROJECT_SHAPE`, not hardcoded "Mobile / Backend / Integrations".
- **`04-flows.md` template** is now shape-agnostic. Flow type sub-sections derived from `PROJECT_SHAPE`. Flow ID prefixes (`F-U-`, `F-S-`, `F-C-`, `F-P-`, `F-X-`) documented for use across shapes.
- **Reading paths in `00-index.md`** are now shape-conditional. Common patterns documented for each pre-templated shape.

### Fixed
- Removed mobile-banking bias. Skill no longer assumes UI exists, no longer hardcodes "Mobile" as a layer, no longer assumes user flows are mobile-facing.

## [0.2.0] — 2026-05-08

### Added
- **Step 0.5 — Implementation mode flag (simplified)**. Skill asks `new` vs `existing` — flag-only, no codebase reference. Mode is metadata that drives downstream AI consumer behavior.
- **`00-index.md > Vault Lock Status`**. Records vault version, lock timestamp, sign-off, status (DRAFT vs LOCKED), and PRD source. Vault locks against requirement, not codebase.
- **`00-index.md > Changelog`**. Tracks vault revisions per PRD update.
- **`00-index.md > Implementation Notes for AI Consumers`**. Explicit instructions for downstream AI dev tools (Claude Code, Cursor) on what to verify with user before writing/modifying code, especially in `existing` mode (cross-check entities/flows/decisions vs existing codebase).
- **Per-layer addressability in `02-architecture.md`**. Sub-sections `### Mobile / Frontend`, `### Backend`, `### Integrations` so each role can deep-link.
- **Per-type addressability in `04-flows.md`**. Sub-sections `### User flows (mobile-facing)`, `### Backend / system flows`, `### Cross-cutting flows`.
- **Deep-link reading paths in `00-index.md`**. Reading paths now use anchor links (e.g. `02-architecture.md#backend`).

### Changed
- Vault structure remains 7 files regardless of mode. Mode flag drives content of `00-index.md > Implementation Notes for AI Consumers`, not file count.
- Anti-halu rules clarified: vault locks **requirement**, not codebase. Codebase reconciliation is the AI consumer's job, instructed via Implementation Notes.

### Removed (vs 0.2.0-alpha conceptual draft, never released)
- `07-integration.md` was conceptually drafted in v0.2.0-alpha and dropped before stable release. Integration mapping to existing codebase belongs to AI consumer at consumption time, not to vault generator.
- Step 0.5 no longer asks for codebase reference (repo URL, local path).

## [0.1.0] — 2026-05-08

### Added
- Initial skill release.
- 7 file vault output: `00-index.md`, `01-overview.md`, `02-architecture.md`, `03-data-model.md`, `04-flows.md`, `05-decisions.md`, `06-constraints.md`.
- Anti-hallucination by construction: every claim must cite source, ambiguities flagged as Open Questions, Out of Scope explicit.
- Step 0 — Output path setup with cross-platform handling (sandbox detection, alien path warning, mkdir variants for Mac/Linux/WSL/Windows).
- Step 1 — Environment-aware input file detection (sandbox vs local Claude Code).
- Step 2 — Extract before writing with gap threshold (>10 → ask).
- Step 3 — Generate with template scaffolding from `references/templates/`.
- Step 4 — Self-check with grounding, readability, simplicity, output integrity verification.
- Step 5 — Present with top blocker surfacing.
- TL;DR header (3 lines: what / for whom / when to read) on every numbered doc.
- Open Question tagging: `OQ-{DOC_CODE}-{N}` with priority `[P1|P2|P3]`.
- 00-index sections: Executive Summary, Project Readiness Status, Reading paths by role, Glossary, OQ roll-up.
- Length & simplicity policy: simple by default; only `04-flows.md` may be complete-wajar.
- Readability standards: EN/ID convention (code EN, prose ID), anti-AI-tone read-aloud test, glossary mandate, cross-ref budget, date format convention.
- Push-back behavior: refuses "just guess the rest" requests, offers to mark as Open Questions instead.
- Templates for all 7 numbered docs.
- README.md with installation instructions for Claude Code (personal & project), Claude.ai/Desktop (zip upload), and Claude API.
- MIT License.
