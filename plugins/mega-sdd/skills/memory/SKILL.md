---
name: memory
version: 1.7.1
description: Memory + self-learning layer across user / project / vault scopes; suggestion-only, never enforcement. Operations — list / show / search / review / prune / promote / diff / export / import / clear. Triggers — "show memory", "review patterns", "lihat memory", "review pattern", "apa yang mega-sdd pelajari", "prune memory", or paraphrases.
---

# Memory — Mega-SDD Context + Self-Learning Layer

Markdown-driven memory that persists pipeline outcomes across sessions. Skills WRITE outcomes to memory at natural checkpoints; skills READ memory for informed suggestions at decision points. Self-learning surfaces threshold-based suggestions to the user — never auto-applied without explicit ACCEPT.

**Announce at start:** "I'm using the memory skill to inspect / manage mega-sdd's persistent memory."

**Core principle:** Memory is SUGGESTION-ONLY, never enforcement. Every suggestion cites its source. Current evidence wins over memory. Cross-project propagation requires explicit user `promote` action.

## When to use

- User wants to inspect what mega-sdd has learned (`/mega-sdd:memory list` / `show` / `search`)
- Threshold-based learning suggestion is pending (`/mega-sdd:memory review`)
- Memory has stale entries needing cleanup (`/mega-sdd:memory prune`)
- User wants to share learned patterns across projects (`/mega-sdd:memory promote`)
- User wants to see what changed since last review (`/mega-sdd:memory diff`)
- User wants to export memory for team sharing or backup (`/mega-sdd:memory export`)
- User wants nuclear reset (`/mega-sdd:memory clear --scope=<scope>`)

**Don't use this skill for**:
- Claude Code's built-in `auto memory` (different system; mega-sdd memory is OPERATIONAL not SOCIAL)
- Memory writes during normal pipeline (those happen automatically inside writer skills)

## Inputs (per operation)

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

## Path resolution

Per `plugins/mega-sdd/references/paths.md`:

- **Project-scope memory**: `<project-root>/.mega-sdd/memory/` (was `<project-root>/.mega-sdd-memory/` in v3.3)
- **User-scope memory** (unchanged): `~/.mega-sdd/memory/`
- **Vault-scope memory** (unchanged): `<vault>/.memory/`
- **Detection**: probe both `<project>/.mega-sdd/memory/` AND `<project>/.mega-sdd-memory/` for back-compat
- **Migration**: `/mega-sdd:migrate-paths` moves legacy `.mega-sdd-memory/` to `.mega-sdd/memory/`

## Memory architecture

Three scopes — see `references/memory-schema.md` §3 Architecture for full details:

```
~/.mega-sdd/memory/                       # USER scope (cross-project, opt-in)
├── preferences.md                         # observed flag/mode defaults
├── patterns.md                            # learned cross-project patterns
└── learning-log.md                        # audit log of accepted learnings

<project-root>/.mega-sdd/memory/            # PROJECT scope (canonical)
├── decisions.md                           # OQ resolutions, CONFLICT actions, ACCEPTs
├── conventions.md                         # detected conventions (test framework, naming, error format)
├── outcomes.md                            # halt patterns, retry counts, success rates per run
└── routing-outcomes.md                    # orchestrator routing decisions log

# Legacy path: <project-root>/.mega-sdd-memory/ — read-side back-compat only;
# write-side defaults to .mega-sdd/memory/ (no-excuse rule).

<vault-path>/.memory/                      # VAULT scope (per-vault, ephemeral)
├── classifier-accuracy.json               # auto-classifier tag vs user-override metrics
├── bind-history.md                        # per-binding-run verdicts + state map summaries
└── bolt-outcomes.json                     # per-bolt success/failure + Hard Rule violations
```

### routing-outcomes.md

**Scope:** PROJECT (`<project>/.mega-sdd/memory/routing-outcomes.md`)
**Producer:** `mega-sdd:orchestrate-flow` Step 7.5
**Consumer:** `mega-sdd:orchestrate-flow` Step 2.7
**Format:** Markdown with append-only Entries section
**Schema:** see `references/routing-outcomes.md`
**Append mechanism:** `scripts/memory-write.sh` at emission time (per §6 canonical writer — scan + lock + atomic append inside the script)
**Lock:** owned by the script (backoff + retry 3x; exhaustion → `memory_in_use` telemetry, log-and-continue — never a chain halt)
**Soft halt:** `routing_outcome_corrupt` on parse failure (auto-invalidate; chain proceeds)

### preferences.md `## Model tiers` section

User-scope per-role model tier override. Format: markdown list with `- <role>: <tier>` per line. Schema: see `references/memory-schema.md §Model tiers`. Consumed by orchestrate-flow Step 2.8 override-chain resolution.

### file-lock

The canonical mega-sdd concurrent-write lock, cited across the plugin as "memory SKILL.md §file-lock". Semantics: acquire an exclusive advisory lock (`<target>.lock`, atomic create — `mkdir`/`O_EXCL`) BEFORE writing; on contention back off and retry 3×; all retries fail → `memory_in_use` blocker; a lock older than 30s is presumed crashed and stolen; release in a trap so a crashed writer never wedges the next one. Deterministic implementation (incl. the 30s stale-steal + trap-release): `scripts/memory-write.sh`. Field-level spec for lock path + backoff schedule: `generate-intent/references/vault-contract.md §Concurrency contract` (note: that section halts `memory_in_use` and defers a >30s orphan to the USER; the auto-steal + trap semantics live in the script) — the vault.json writers and the deep-scan Step 10.5.4 guard reuse the same lock-file pattern.

## Self-learning mechanism (suggestion-only)

After N consistent observations (thresholds configurable per `~/.mega-sdd/config.yaml`), pending suggestions accumulate in `~/.mega-sdd/memory/patterns.md` under `## Pending suggestions`. Default thresholds in `references/learning-rules.md`.

**Review flow** (`/mega-sdd:memory review`): an ACCEPT / REJECT / DEFER walk-through per pending suggestion — full procedure (ACCEPT writes `learning-log.md` + updates the target heuristic; REJECT filters re-triggers; DEFER auto-prunes after 3) in `references/learning-rules.md` §3 (Suggestion review flow).

**Anti-halu rails** (non-negotiable):
- NEVER auto-apply learning. Every change requires explicit user ACCEPT via `review`.
- Audit trail mandatory — every accepted learning has a `learning-log.md` entry with rollback path
- Rollback: edit log entry, set `rolled_back_at: <date>`; mega-sdd skips the learning rule
- Confidence threshold required (default 80% consistency across observations) before suggestion fires

## Procedure (per operation)

### `list`
1. Walk all three scope dirs
2. Per scope, list file paths + line counts + last-modified
3. Output table or JSON per `--format`

### `show <topic>`
1. Resolve topic (e.g., `decisions`, `conventions`, `patterns`, `preferences`)
2. Cat the relevant memory file with markdown rendering
3. Add summary stats at end (entry count, date range, source-run distribution)

### `search <query>`
1. Grep across all memory files in selected scope(s)
2. Output matched lines with file + line citation
3. Highlight query terms

### `review`
1. Read `~/.mega-sdd/memory/patterns.md` `## Pending suggestions` section
2. Parse each suggestion (source observations + suggested action + threshold confidence)
3. Present via `AskUserQuestion` one at a time
4. On ACCEPT: write to `learning-log.md`; update the target heuristic file; mark suggestion as accepted
5. On REJECT: write to `learning-log.md` with "rejected" status; clear from pending
6. On DEFER: keep in pending; bump `deferred_count`
7. Suggestions with `deferred_count > 3` auto-prune (likely irrelevant)

### `prune`
1. Walk memory files
2. For each entry older than `--older-than` (default 180 days), flag as candidate
3. Stale entries: those superseded by newer observations (e.g., conventions detected then changed)
4. Present candidates via `AskUserQuestion` per file (batch confirm)
5. `--dry-run` shows what would be pruned without writing

### `promote <key> --to=<user|project>`
1. Read source memory entry (project or vault scope)
2. Verify the entry exists + has enough source observations (>=2 by default)
3. Write to target scope with provenance: `promoted_from: <source-scope>`, `promoted_at: <date>`
4. Source entry stays (promotion does NOT remove source); user can `prune` source separately

### `diff [--since=<date>]`
1. Walk memory files
2. For each entry with `created_at >= --since`, list
3. Default `--since`: last `review` timestamp recorded in learning-log.md, OR 30 days ago

### `export <output-path>`
1. Bundle selected scope(s) into a single tarball/zip + manifest
2. Manifest lists files + checksums + memory schema version
3. Safe to share with team (PROJECT scope) or backup (USER scope)

### `import <input-path>`
1. Verify bundle manifest + checksums
2. Compare schema version; migrate if needed (per MEMORY-OQ-1 resolved auto-migrate)
3. Present import preview via `AskUserQuestion` (which files, how many entries, conflicts with existing)
4. On confirm: write to target scope; log import event

### `clear --scope=<scope>`
1. **DOUBLE-CONFIRM mandatory.** First AskUserQuestion: "Clear ALL <scope> memory? This deletes <N> files with <M> entries."
2. Second AskUserQuestion (after first ACCEPT): "Really clear? Type CLEAR-<scope> to confirm."
3. On both confirms: delete files; write to learning-log.md as "clear event"
4. NO undo. Memory is markdown/JSON — user should back up via `export` first if unsure.

## Halt conditions

- Schema version mismatch detected on read → halt; attempt auto-migrate (per MEMORY-OQ-1); user reviews migration result before proceeding
- File lock collision (concurrent runs) → backoff + retry (3x); fail with `memory_in_use` blocker if all retries fail
- Promote to USER scope without sufficient observations → halt; explain threshold

## Hand-off

- After `list` / `show` / `search` / `diff`: informational; no next-step suggestion
- After `review`: announce "N suggestions reviewed. N accepted. N rejected. Updated heuristics: <list>. Re-run pipeline to use new defaults."
- After `prune`: announce "Pruned N entries. Memory size: before / after."
- After `promote`: announce "<key> promoted to <scope>. Use on future runs."
- After `clear`: announce "<scope> memory cleared. Mega-sdd will rebuild memory from next pipeline run."

## Handoff emission (when --auto)

This skill emits a handoff YAML when invoked under `--auto` per the local template below (operative; `orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index):

```yaml
handoff:
  emitted_by: memory
  emitted_at: <ISO8601 timestamp>
  status: completed
  artifacts:
    - <list of memory files touched>
  next_action:
    suggested_skill: null    # memory is a side-skill; doesn't trigger pipeline continuation
    rationale: "Memory operation completed; pipeline continuation requires explicit invocation."
  blockers: []
  metrics:
    items_processed: <N entries inspected/written>
```

## References

- `references/memory-schema.md` — full per-file schemas + format specs + scope rules
- `references/learning-rules.md` — threshold tables + audit-log format + rollback path
- `references/instincts.md` — instinct schema (trigger→action, confidence 0.3–0.9), lifecycle, project→global promotion, SessionStart re-injection contract
- `docs/superpowers/specs/2026-05-21-memory-self-learning-design.md` — design spec this skill implements
- Claude Code built-in `auto memory` (`~/.claude/projects/<project>/memory/`) — COMPLEMENTARY system (mega-sdd memory writes elsewhere; never duplicates)
