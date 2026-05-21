# Memory & Self-Learning Layer — Iter 5

**Status**: Proposed (design only; awaiting execution kickoff)
**Date**: 2026-05-21
**Author**: Farhan Riuzaki (via Claude collaboration)
**Builds on**: Iters 1-4 (all shipped in plugin 2.0.0). Inspired by ruflo (memory persistence concept; NOT the vector-DB / binary-store implementation).
**Targets**: 6 writer skills + 4 reader skills + new `mega-sdd:memory` command
**Plugin version affected**: 2.0.0 → 2.1.0 (minor — purely additive)

---

## 1. Motivation

User request:
> "gue pengen punya memory juga, agar bisa tau context dan continues context. dan self learning. ;p coba baca juga skills ini https://github.com/ruvnet/ruflo"

Three problems to solve:

1. **Context discontinuity** — every session starts from zero. Pipeline outcomes (which OQs got which resolutions, which CONFLICTs were resolved which way, which Hard Rules got violated and how the user fixed them) are recorded in artifacts (vault.json, binding.md, bolt-report.md) but not in a form that influences FUTURE pipeline runs.

2. **No self-learning** — auto-classifier (Iter 2) tags OQs based on a static heuristic table. If the user consistently overrides `tech/recommend` to `business/blocking` for a specific kind of question, mega-sdd doesn't learn. Same for CONFLICT resolution patterns (user always picks KEEP_CODE on auth-related conflicts), Hard Rule violations, etc.

3. **Cross-vault patterns lost** — when a project goes through multiple vaults (different milestones), each new vault re-learns from scratch what the project's conventions are (test framework, naming case, error envelope shape).

## 2. Critical assessment of ruflo as inspiration

Ruflo is a massive multi-agent platform (~521MB TypeScript, 53k stars). It uses:
- Vector embeddings + HNSW indexing (`AgentDB.rvf` binary format)
- SONA neural patterns + ReasoningBank + Graph intelligence (PageRank)
- GPU acceleration for vector search
- Auto-learning swarm intelligence

### Where ruflo's approach DOES NOT fit mega-sdd

| Ruflo approach | Why not in mega-sdd |
|---|---|
| Vector embeddings for semantic retrieval | Fuzzy by nature; conflicts with mega-sdd anti-halu rails (cite or halt, never approximate-match) |
| Binary `.rvf` format | Mega-sdd: markdown as source-of-truth, git-trackable, human-reviewable |
| GPU-accelerated search | Overkill; mega-sdd runs in Claude Code, no GPU assumption |
| Massive plugin ecosystem | Mega-sdd: single opinionated plugin, no third-party deps beyond superpowers |
| Auto-tune neural weights | Opaque learning; user can't audit what changed |
| Cross-project auto-propagation | Privacy/safety risk; user-explicit promotion required |

### Where ruflo's CONCEPTS apply

- ✅ Memory persists across sessions
- ✅ Self-learning from past outcomes
- ✅ Continuous feedback loop (pipeline → memory → next pipeline)

These concepts translate to a SIMPLE mega-sdd implementation using markdown + JSON, no vector store.

## 3. Critical relationship to Claude Code's built-in memory

Claude Code already has `auto memory` at `~/.claude/projects/<project>/memory/`. Types: `user / feedback / project / reference`. Format: markdown with frontmatter.

**Claude Code memory = SOCIAL** (how Claude works with this user/team).
**Mega-sdd memory = OPERATIONAL** (pipeline state, decision history, outcome analytics).

These are COMPLEMENTARY, not duplicative. Mega-sdd memory writes to different directories with different schemas; both layers can coexist without interference.

**Hard rule**: mega-sdd MUST NOT write to `~/.claude/projects/.../memory/`. That's Claude Code's territory. Mega-sdd writes to `~/.mega-sdd/memory/` (user scope) and `<project>/.mega-sdd-memory/` (project scope) and `<vault>/.memory/` (vault scope).

## 4. Goals + Non-goals

### Goals

1. Pipeline outcomes persist across sessions in human-readable markdown / JSON.
2. Skills consult memory at startup to suggest informed defaults (NEVER impose).
3. Self-learning via threshold-based suggestions (e.g., "you picked KEEP_CODE 5 times; want me to pre-fill this as default?"). User confirms before any heuristic changes.
4. Three memory scopes: USER (cross-project, opt-in), PROJECT (per-repo), VAULT (per-vault).
5. New `mega-sdd:memory` skill for list / show / search / prune / promote / diff operations.
6. Backward compatible — existing pipelines work without memory dirs; memory directories are created lazily.
7. Anti-halu invariants preserved across all skills (memory is suggestion only; never enforcement).

### Non-goals

- Vector embeddings, RAG retrieval, semantic search.
- Binary memory formats.
- Auto-tuning heuristics without user consent.
- Cross-project automatic propagation (always explicit promote via `mega-sdd:memory promote`).
- Replacement of Claude Code's built-in memory system.
- GPU / ML model training.
- Real-time analytics dashboard.

## 5. Memory Architecture

### 5.1 Three scopes

```
~/.mega-sdd/memory/                       # USER scope (cross-project, opt-in)
├── preferences.md                         # observed flag/mode defaults
└── patterns.md                            # learned cross-project patterns

<project-root>/.mega-sdd-memory/           # PROJECT scope (per-repo)
├── decisions.md                           # OQ resolutions, CONFLICT actions, ACCEPTs
├── conventions.md                         # detected conventions (test framework, naming, error format)
└── outcomes.md                            # halt patterns, retry counts, success rates per run

<vault-path>/.memory/                      # VAULT scope (per-vault, ephemeral within vault lifecycle)
├── classifier-accuracy.json               # auto-classifier tag vs user-override metrics
├── bind-history.md                        # per-binding-run verdicts + state map summaries
└── bolt-outcomes.json                     # per-bolt success/failure + Hard Rule violations
```

**Scope lifetimes**:
- VAULT scope: lives with the vault. Deleted when vault is archived/deleted.
- PROJECT scope: lives at repo root. Survives vault lifecycle; git-trackable; team-shareable.
- USER scope: lives in user's home dir. Cross-project; NEVER auto-shared; user explicit `promote` action required.

### 5.2 File format conventions

All memory files follow mega-sdd's existing conventions:
- Markdown for narrative + tables (human-reviewable)
- JSON only for high-volume structured data (classifier metrics, bolt outcomes)
- YAML frontmatter where useful (skill emissions stamped)
- Every entry CITES its source run (`run_at: <ISO8601>` + `source_skill: <skill-name>`)

### 5.3 Schemas

Detailed in `references/memory-schema.md` (new file under `mega-sdd:memory` skill). Summary:

**`<project>/.mega-sdd-memory/decisions.md`**:

```markdown
# Project Decision History

## CONFLICT resolutions
| date | conflict | resolution | rationale | source-run |
|---|---|---|---|---|
| 2026-05-20 | Auth uses Bearer vs session cookies | KEEP_CODE | Legacy auth stable | bind-codebase v1.5, vault leave-mgmt v3 |

## OQ resolutions
| date | oq-id | category | resolution | source-run |
|---|---|---|---|---|

## Recommendation outcomes
| date | oq-id | recommendation | action (ACCEPT/OVERRIDE/REJECT) | source-run |
|---|---|---|---|---|
```

**`<project>/.mega-sdd-memory/conventions.md`**:

```markdown
# Detected Conventions

## Test framework
- **phpunit** (detected 2026-05-20 from phpunit.xml + tests/ dir)
- Last confirmed: scan-codebase v1.1, run #4

## Naming
- File case: PascalCase (PHP classes), kebab-case (routes)
- Test suffix: *Test.php

## Error envelope
- AS-IS: ad-hoc `{error, message, status}` (run #1-3)
- DESIRED: RFC 7807 (accepted in OQ-AR-7 recommendation, run #4)
- Convention evolution: pending Iter 3 hard-rule emission on next bind
```

**`<vault>/.memory/classifier-accuracy.json`**:

```json
{
  "vault_id": "leave-management",
  "classifier_version": "1.4.0",
  "runs": [
    {
      "run_at": "2026-05-20T10:00:00Z",
      "source_skill": "generate-intent",
      "total_oqs": 48,
      "tags_emitted": {
        "tech_scan_high": 8,
        "tech_recommend_medium": 2,
        "business_blocking_high": 12,
        "business_blocking_low": 26
      },
      "user_overrides": [
        {
          "oq_id": "OQ-AR-3",
          "auto_tag": "tech_recommend_medium",
          "user_tag": "business_blocking_high",
          "user_reason": "this is a product decision, not a tech recommendation"
        }
      ],
      "accuracy_estimate": 0.979
    }
  ]
}
```

**`<vault>/.memory/bolt-outcomes.json`**:

```json
{
  "vault_id": "leave-management",
  "bolts": [
    {
      "unit_id": "U-007",
      "run_at": "2026-05-20T11:00:00Z",
      "task_type": "create",
      "status": "halted_postflight",
      "halt_reason": "hard_rule_violated",
      "violated_rule": "DO NOT modify src/Models/User.php",
      "resolution": "user_edited_unit",
      "resolution_at": "2026-05-20T11:30:00Z",
      "resolution_note": "Switched task_type to extend; filled Migration notes"
    }
  ]
}
```

**`~/.mega-sdd/memory/preferences.md`**:

```markdown
# Mega-SDD User Preferences (observed; not enforced)

## Flag defaults
- **OUTPUT_MODE**: compact (chosen 5/5 runs)
- **PRD_STATUS**: draft (chosen 4/5 runs)
- **--auto flag**: used 7/7 runs

## Suggestions
- After 5 runs always compact: prompt Step 0.7 default to "compact" — pending user confirmation via `/mega-sdd:memory promote`
```

**`~/.mega-sdd/memory/patterns.md`**:

```markdown
# Mega-SDD Learned Patterns (cross-project, suggestions only)

## CONFLICT resolution patterns
- 8/10 times user picks KEEP_CODE on auth-related conflicts (across 3 projects)
- 5/5 times user picks KEEP_VAULT on data-model rename conflicts (1 project)

## Hard Rule violation patterns
- 3/5 hard_rule_violated cases ended with user editing unit, NOT reverting code

## Recommendation acceptance patterns
- RFC 7807 error envelope recommendations: 4/4 ACCEPT
- "use latest stable Laravel" recommendations: 2/3 OVERRIDE (user prefers LTS)

## Pending suggestions
- On next auth-related CONFLICT: pre-fill KEEP_CODE in resolve-oq AskUserQuestion (user still confirms)
- After 3rd revert of same Hard Rule: propose removing it from Suggested Unit Hard Rules
```

## 6. Writer Contracts

Which skill writes what, when. Triggered ONLY when memory is enabled (default on; opt-out via `--memory-off`).

| Skill | File | Trigger | Append/Replace |
|---|---|---|---|
| `resolve-oq` | `<project>/.mega-sdd-memory/decisions.md` | After each OQ marked resolved | Append (new table row) |
| `resolve-oq --binding` | `<project>/.mega-sdd-memory/decisions.md` | After CONFLICT resolved | Append |
| `bind-codebase` | `<vault>/.memory/bind-history.md` | After binding completes | Append (new run entry) |
| `bind-codebase` | `<project>/.mega-sdd-memory/conventions.md` | When new convention detected (incrementally) | Update existing or append |
| `generate-intent` | `<vault>/.memory/classifier-accuracy.json` | After OQ classifier runs | Append (new run entry) |
| `generate-intent` | `~/.mega-sdd/memory/preferences.md` | When user picks flag at Step 0.5-0.7 | Update tally |
| `scan-codebase` | `<project>/.mega-sdd-memory/conventions.md` | After scan completes | Append (new detections) |
| `execute-bolts` | `<vault>/.memory/bolt-outcomes.json` | After each bolt commits OR halts | Append |
| `execute-bolts` | `<project>/.mega-sdd-memory/outcomes.md` | After run completes (success or halt) | Append (run summary) |

**Anti-halu writer rails**:
- Memory writes happen AFTER the skill's primary output (vault.json, binding.md, bolt-report.md). Memory is derivative; primary artifacts are source of truth.
- If memory write fails (disk full, permission), skill continues — memory is OPTIONAL, not critical.
- Every memory entry includes `source_run` identifier so it's traceable back to the artifact.
- Memory writes are append-only by default. Updates require explicit "supersedes" marker.

## 7. Reader Contracts

Which skill reads what, what it does with it.

| Skill | Reads | How it uses memory |
|---|---|---|
| `generate-intent` | `<project>/.mega-sdd-memory/conventions.md` + `~/.mega-sdd/memory/preferences.md` | At Step 0.5-0.7 (flag setup): pre-fill `AskUserQuestion` defaults based on past picks. Surface as "Default observed from history: <value>. Use? Y/N/Other". |
| `generate-intent` | `<project>/.mega-sdd-memory/conventions.md` | At OQ generation (auto-classifier): when convention is known, downgrade related OQs from `tech/recommend` to `tech/scan` with `scan_query` pointing to convention entry. |
| `bind-codebase` | `<project>/.mega-sdd-memory/decisions.md` | When CONFLICT detected: search past CONFLICT resolutions for similar pattern. If found → SUGGEST same resolution in resolve-oq prompt. User still picks. |
| `bind-codebase` | `~/.mega-sdd/memory/patterns.md` | When CONFLICT detected AND no project-scope match: search user-scope patterns. SUGGEST if 5+ consistent matches across projects. |
| `generate-units` | `<vault>/.memory/classifier-accuracy.json` | If past unit had Hard Rule violated → propose adding the rule as Anti-pattern in current unit (informational warning). |
| `generate-units` | `<project>/.mega-sdd-memory/decisions.md` | Auto-pull KB-suggested Anti-patterns (from binding) merged with past CONFLICT resolutions touching same files. |
| `execute-bolts` | `<vault>/.memory/bolt-outcomes.json` | If unit U-X previously halted on rule Y → surface to user before execution: "U-X halted last run on Y. Same risk now. Continue?" |
| `orchestrate-flow` | `<project>/.mega-sdd-memory/outcomes.md` | Show run history summary in chain confirmation: "Last 3 runs: 2 completed, 1 halted (bind_conflict). Continue?" |

**Anti-halu reader rails**:
- Memory suggestions ALWAYS surface to user; never silently auto-applied (per scope decision: suggestion-only).
- Every suggestion cites the source memory entry (`per .mega-sdd-memory/decisions.md row 5`).
- Skills running with `--memory-off` skip ALL memory reads (default-of-defaults behavior).
- Memory contents are informational; if memory contradicts current evidence (e.g., past pattern says KEEP_CODE but current code structure changed), CURRENT EVIDENCE wins; memory is suggestion only.

## 8. Self-Learning Mechanism

### 8.1 Threshold-based suggestions (per AUTONOMY-OQ-resolved Suggestion-only)

After accumulating N consistent observations, propose a learning update:

| Observation type | Threshold | Suggested action |
|---|---|---|
| User overrides classifier on pattern X | 5 overrides in 1 project OR 3 across projects | Propose updating `references/vault-contract.md` heuristic table |
| User picks KEEP_CODE on conflicts matching pattern Y | 5 times | Propose pre-filling KEEP_CODE on next match (user confirms each time) |
| Hard Rule Z violated and reverted | 3 times | Propose removing Z from Suggested Unit Hard Rules (binding.md emits fewer) |
| Recommend mode REJECT for category C | 3 rejects | Propose flipping default `resolution_mode` from `recommend` to `blocking` for C |
| Convention X detected consistently | 2 scan runs | Promote from "detected" to "established"; auto-include in next scan-codebase output |

### 8.2 Suggestions surface mechanism

Suggestions accumulate in `~/.mega-sdd/memory/patterns.md` under `## Pending suggestions` section. On next pipeline invocation:

1. `using-mega-sdd` reads patterns.md at session start.
2. If pending suggestions exist, surface in chat: "Mega-SDD observed patterns and has 3 suggestions. Review now via `/mega-sdd:memory review` or skip."
3. User can ACCEPT (applies the learning) / REJECT (clears the suggestion) / DEFER (re-asks next session).
4. Accepted suggestions update the relevant heuristic / default / convention.

### 8.3 Audit trail

Every accepted learning suggestion writes an entry to `~/.mega-sdd/memory/learning-log.md`:

```markdown
## Learning #4 — 2026-05-21
- **Source observations**: `.mega-sdd-memory/decisions.md` rows 7-11 (5 KEEP_CODE picks on auth conflicts)
- **Suggested action**: Pre-fill KEEP_CODE in resolve-oq AskUserQuestion when CONFLICT matches `auth|session|login|token` pattern
- **User decision**: ACCEPT
- **Effective from**: 2026-05-21
- **Rollback**: Edit this entry, set `rolled_back_at: <date>`; `mega-sdd:memory` skips the learning rule.
```

Audit log = user can ALWAYS see what learning has been applied AND revert it.

## 9. New skill: `mega-sdd:memory`

### 9.1 Command surface

```bash
/mega-sdd:memory list                          # show all memory entries by scope
/mega-sdd:memory show <topic>                  # inspect specific topic (e.g., conventions, decisions)
/mega-sdd:memory search "auth"                 # grep across memory files
/mega-sdd:memory review                        # walk pending suggestions interactively
/mega-sdd:memory prune                         # interactive cleanup of stale entries
/mega-sdd:memory promote <key> --to=user       # promote project-scope to user-scope
/mega-sdd:memory diff [--since=<date>]         # show what's changed since last review
/mega-sdd:memory export <path>                 # export memory bundle for sharing
/mega-sdd:memory import <path>                 # import memory bundle (with confirmation)
/mega-sdd:memory clear --scope=<user|project|vault> # nuclear option; confirm twice
```

### 9.2 Skill structure

```
plugins/mega-sdd/skills/memory/
├── SKILL.md
└── references/
    ├── memory-schema.md           # full schemas + per-file format specs
    └── learning-rules.md          # threshold table + audit-log format
```

### 9.3 Trigger phrases

**English**: "show memory", "review patterns", "what mega-sdd learned", "prune memory", "promote to user scope", "memory diff"
**Indonesian**: "lihat memory", "review pattern", "apa yang mega-sdd pelajari", "bersihin memory", "ekspor memory"

## 10. Anti-hallucination invariants

These are NON-NEGOTIABLE for the memory layer:

1. **Memory is suggestion only**. Never enforcement. Every suggestion surfaces for user confirmation.
2. **Every suggestion cites source**. `per .mega-sdd-memory/decisions.md row N` or `per ~/.mega-sdd/memory/patterns.md section X`.
3. **Current evidence wins over memory**. If past pattern says KEEP_CODE but current binding shows the conflict has different semantics, memory is informational; current run decides.
4. **No silent auto-tuning**. Learning is OPT-IN per suggestion. User reviews each via `mega-sdd:memory review`.
5. **Audit log mandatory**. Every applied learning has a `learning-log.md` entry with rollback path.
6. **No fabricated citations**. Memory writers cite the SOURCE artifact (vault.json, binding.md). Readers cite the memory entry. No invention.
7. **Cross-project promotion explicit**. User MUST run `mega-sdd:memory promote <key> --to=user`; never automatic.
8. **`--memory-off` is honored**. Skills skip all memory reads + writes when this flag is set; useful for privacy-sensitive sessions or one-off experiments.
9. **Memory contents do NOT affect halt-protocol**. CONFLICT still blocks. business OQ P1 still pauses. Hard Rule violated still halts. Memory only suggests defaults at decision points; never bypasses safety gates.
10. **Memory files are human-reviewable markdown / JSON**. Never binary. Git-trackable (project scope can be committed to repo if team wants).

## 11. Backward compatibility

All changes are PURELY ADDITIVE:

- Existing pipelines run without memory directories — skills lazily create them on first write.
- v2.0 vaults / projects without memory dirs → readers find no files; default behavior unchanged.
- `--memory-off` flag is opt-out (default = on). Users worried about privacy can disable globally via `~/.mega-sdd/config.yaml` (new file; defaults inferred if absent).
- v2.0 skills (extract-intelligence, generate-intent, scan-codebase, bind-codebase, generate-units, execute-bolts) keep working without memory awareness if user disables.
- Memory files have schema versions (`memory_schema: 1`) so future iters can migrate.

## 12. Test coverage

New `tests/skill-triggering/memory.test.md` covering:
- M1: List by scope
- M2: Show specific topic
- M3: Search across all files
- M4: Review pending suggestions
- M5: Prune stale entries
- M6: Promote project → user scope (with confirmation)
- M7: Diff since date
- M8: Export / Import roundtrip
- M9: Clear scope (with double-confirm)

Extended tests for each writer skill:
- Each writer test gets a new case verifying memory write happens on success path
- Verify writes go to correct scope (vault/project/user)
- Verify writes are append-only by default
- Verify `--memory-off` flag suppresses writes

Extended tests for each reader skill:
- Each reader test gets a new case verifying memory consultation surfaces as suggestion (not enforcement)
- Verify reads cite source memory entry
- Verify reads skip when memory absent (graceful degradation)

New integration test: `tests/integration/e2e-memory-self-learning.test.md`:
- Run pipeline 5 times on same project
- Verify memory accumulates correctly across runs
- Verify threshold-based suggestion fires after 5th similar pattern
- Verify accepting suggestion writes to learning-log.md
- Verify rollback path works

## 13. Open design questions ([MEMORY-OQ])

These need user decision before execution. Recommendations included.

- **[MEMORY-OQ-1] Memory schema version migration path** — when future iters change schemas, old memory files need migration. Options: (a) version-stamp every memory file with `memory_schema: N`; skill checks version and migrates on read; (b) ignore old versions; user manually re-runs `mega-sdd:memory clear`. **Recommendation: (a)** — auto-migrate with audit log entry.

- **[MEMORY-OQ-2] Project scope memory in git?** — Should `<project>/.mega-sdd-memory/` be tracked by git or `.gitignore`'d? Options: (a) Default `.gitignore`d (privacy); user opts in to commit. (b) Default committed (team-shared knowledge); user opts out. (c) Per-file decision (e.g., conventions.md committed; outcomes.md gitignored). **Recommendation: (c)** — surface this in skill output with clear opt-in/opt-out per file.

- **[MEMORY-OQ-3] User-scope encryption / privacy** — `~/.mega-sdd/memory/` contains observed patterns. If user shares the home dir (rare but possible) or runs on shared infra → leak risk. Options: (a) Plain markdown (current proposal); (b) Optional encryption via `gpg` or similar. **Recommendation: (a)** for simplicity; document risk; advise users to opt-out via `--memory-off` on shared infra.

- **[MEMORY-OQ-4] Threshold tuning** — current thresholds (5 for classifier overrides, 3 for Hard Rule reverts) are arbitrary. Options: (a) Hardcoded with comments explaining choice; (b) Configurable per-user via `~/.mega-sdd/config.yaml`; (c) Adaptive (lower threshold for rapid feedback in new projects). **Recommendation: (b)** — configurable, default values documented.

- **[MEMORY-OQ-5] Vault-scope memory survival** — when vault is deleted/archived, what happens to `<vault>/.memory/`? Options: (a) Delete with vault (lost). (b) Move to project scope under `archived-vaults/<vault-id>/`. (c) Promote relevant patterns to project scope before deletion. **Recommendation: (b)** — move to archive, preserve audit trail.

- **[MEMORY-OQ-6] Concurrent runs collision** — if user runs 2 mega-sdd pipelines concurrently in same project, memory write conflicts. Options: (a) File lock with retry (.flock); (b) Append-only with timestamp ordering; race-condition tolerant. (c) Halt second run with `memory_in_use` blocker. **Recommendation: (b)** — append-only writes are inherently race-tolerant if each write is atomic (a single fs.append call).

- **[MEMORY-OQ-7] What about Iter 4 autonomy mode?** — When `/mega-sdd:auto --deep` runs end-to-end, does memory consultation slow it down? Options: (a) Read memory ONCE at chain start; cache per chain. (b) Re-read per skill. **Recommendation: (a)** — single read at orchestrator level; pass relevant slices to skills via handoff YAML.

## 14. Pipeline integration with Iter 4 (autonomy)

Memory layer integrates with Iter 4's handoff YAML protocol:

- Orchestrator (`/mega-sdd:auto` or `orchestrate-flow --deep`) reads memory ONCE at chain start.
- Passes relevant memory slices to each skill via handoff `metadata.memory_context` field.
- Each skill reads from this in-memory slice (avoids re-reading disk per skill).
- Each skill emits its memory updates in handoff `metadata.memory_writes` list.
- Orchestrator batches writes at chain end (or per-phase on halt).

This keeps autonomy fast AND memory-aware. Plus handoff YAML schema extension:

```yaml
handoff:
  emitted_by: bind-codebase
  status: completed
  artifacts: [...]
  next_action: {...}
  metadata:
    memory_context:                      # IN — orchestrator-provided
      project_decisions_relevant: [...]
      user_patterns_relevant: [...]
    memory_writes:                       # OUT — for orchestrator to persist
      - file: <project>/.mega-sdd-memory/decisions.md
        action: append
        content: "| 2026-05-21 | ... | KEEP_CODE | ..."
      - file: <vault>/.memory/bind-history.md
        action: append
        content: "## Run #5..."
```

## 15. Validation plan

### Scenario A — First pipeline run on a new project
- No memory exists yet.
- Pipeline runs; memory directories created lazily.
- Verify: `<project>/.mega-sdd-memory/` exists with `decisions.md`, `conventions.md`, `outcomes.md` after run.
- Verify: `<vault>/.memory/` has `classifier-accuracy.json` + `bind-history.md` + `bolt-outcomes.json`.
- Verify: `~/.mega-sdd/memory/preferences.md` has 1 entry per flag picked.

### Scenario B — 5 runs with consistent override
- Run pipeline 5 times; in each run, override OQ-AR-3 classifier from `tech/recommend` to `business/blocking`.
- After 5th run, verify `classifier-accuracy.json` shows 5 overrides on same pattern.
- Verify `~/.mega-sdd/memory/patterns.md` lists pending suggestion: "Pattern Y consistently overridden. Apply learning?"
- User runs `/mega-sdd:memory review` → ACCEPT.
- 6th run: classifier auto-tags OQ-AR-3 (or similar) as `business/blocking` directly.
- Verify learning-log.md entry exists with audit trail.

### Scenario C — Suggestion-only invariant
- Memory has past pattern: KEEP_CODE on auth conflicts.
- New CONFLICT on auth.
- Verify: resolve-oq prompt shows KEEP_CODE as PRE-FILLED default + cites past pattern source.
- Verify: prompt still requires user confirmation; not silent auto-pick.

### Scenario D — `--memory-off` graceful degradation
- Run pipeline with `--memory-off` flag.
- Verify: no memory reads (no "suggested from past:" messages).
- Verify: no memory writes (memory dirs don't get new entries).
- Verify: pipeline output IDENTICAL to a hypothetical first-run-no-memory scenario.

### Scenario E — Cross-vault project consistency
- 2 vaults in same project.
- 1st vault establishes conventions (test framework: phpunit; naming: PascalCase).
- 2nd vault generation: verify conventions.md is consulted at scan-codebase + generate-intent.
- Verify: 2nd vault's auto-classifier uses `tech/scan` (not `tech/recommend`) for already-detected conventions.

## 16. References

- `docs/superpowers/specs/2026-05-20-tech-oq-autoresolve-design.md` — Iter 2 OQ classification context
- `docs/superpowers/specs/2026-05-20-autonomy-layer-design.md` — Iter 4 handoff YAML protocol (extended in §14)
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` — handoff YAML schema (gets `metadata.memory_*` extension)
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` — OQ schema (consulted by classifier-accuracy.json)
- ruflo (https://github.com/ruvnet/ruflo) — INSPIRATION for memory persistence + self-learning concepts. NOT implementation copy.
- Claude Code built-in `auto memory` system (`~/.claude/projects/<project>/memory/`) — COMPLEMENTARY (mega-sdd memory writes elsewhere; never duplicates).
