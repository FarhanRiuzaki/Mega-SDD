# Memory Layer — Single Memory I/O Point

When memory is enabled (default; opt-out via `--memory-off`), the orchestrator is the SINGLE memory I/O point for the chain. Skills do not re-read disk; they receive slices via handoff YAML `metadata.memory_context` and emit writes via `metadata.memory_writes`. This keeps autonomy mode FAST (I/O batched at orchestrator level) and CONSISTENT (single source of truth per chain run).

## Contents

- [Chain start (single memory read)](#chain-start-single-memory-read)
- [Per-phase invocation](#per-phase-invocation)
- [Per-phase write batching](#per-phase-write-batching)
- [Chain end](#chain-end)
- [Mode D (sync) memory](#mode-d-sync-memory)
- [Anti-halu rails](#anti-halu-rails)

## Chain start (single memory read)

Before invoking the first skill in `--deep` mode:

1. If a scope `_index.md` exists, consult it FIRST and open only the files the chain needs (just-in-time; a stale index is a hint, never the data — when in doubt, read the file)
2. Read user-scope: `~/.mega-sdd/memory/preferences.md` + `~/.mega-sdd/memory/patterns.md`
3. Read project-scope: `<cwd-project>/.mega-sdd/memory/decisions.md` + `conventions.md` + `outcomes.md`
4. Read vault-scope (if vault detected): `<vault>/.memory/classifier-accuracy.json` + `bind-history.md` + `bolt-outcomes.json` (+ `drift-history.md` when the chain includes detect-drift)
5. Verify all `memory_schema` versions match expected; halt with `memory_schema_mismatch` blocker if any differ
6. Build per-skill memory slices (filter to only what each skill needs)
7. Surface chain history in confirmation: "Past 3 runs: 2 completed, 1 halted on bind_conflict. Continue?"

## Per-phase invocation

When invoking each skill via the Skill tool:

1. Pass that skill's memory slice via handoff YAML `metadata.memory_context` field (per the handoff-contract reference `§Memory layer integration`, indexed in SKILL.md §Specialist references)
2. Skill reads from the in-memory slice — no disk re-read

## Per-phase write batching

When a skill emits a handoff with `metadata.memory_writes`:

1. Validate each write entry (file, scope, action, content)
2. **Secret-scan the content** (`scripts/secret-scan.sh --check`); findings → redact the value (`[REDACTED-SECRET]`) before appending — memory files can be git-tracked
3. Append to the target file per scope rules (resolve absolute path from CWD + vault)
4. Atomic per-file append (race-tolerant)
5. Log writes to chain progress chat (one line per write)
6. Failed writes logged but do NOT halt chain (memory is optional)

## Chain end

After the last skill completes:

1. **Step 7.6 — extract-learnings (the owned threshold pass).** Run the `memory/references/learning-rules.md §1` threshold pass ONCE over the rows touched this chain (per-pattern: classifier overrides, CONFLICT resolutions, Hard-Rule reverts, recommendation rejects, conventions, flags, drift directions, sync write-back classes, concern recurrences). Each threshold-crossing candidate is APPENDED to the user-scope `patterns.md` `## Pending suggestions` with `status: pending` + source citations. Nothing is applied — `/mega-sdd:memory review` remains the only pending → applied path. No skill evaluates thresholds mid-chain.
2. Regenerate each touched scope's `_index.md` (per `memory/references/memory-schema.md §8.5`): per file — row count, last-entry date, one-line current-state summary, pending-suggestion count, size flag (> 256 KB → `prune?` suggestion; never auto-prune)
3. Final memory summary in chat: "Chain wrote N memory entries across scopes: user (X), project (Y), vault (Z)"
4. If pending suggestions accumulated (≥1 threshold crossed): announce "Mega-SDD has N pending learning suggestions. Review via `/mega-sdd:memory review`"

## Mode D (sync) memory

Each `--sync` run appends ONE `kind: sync` row to project-scope `outcomes.md` (schema: `memory/references/memory-schema.md §outcomes`): trigger channel mix (journal/git), per-phase outcome counts, applied-vs-queued patch tally, `--auto-apply=safe` accept/reject tally, closing staleness. This is what makes the §2.8 learning pattern (suggest defaulting `--auto-apply=safe` after 3 consistently-ACCEPTed runs) observable — the suggestion itself fires only at the Step 7.6 pass and applies only on explicit ACCEPT.

## Anti-halu rails

- Memory schema mismatch HALTS the chain (cannot continue with mixed schemas)
- Memory I/O failures (disk, perm) logged but do NOT halt (graceful degradation)
- Suggestions surfaced at chain end; NEVER auto-applied
- `--memory-off` propagates to all sub-skills automatically (passed as a flag in handoff invocation args)

## See also

SKILL.md §Specialist references indexes the related orchestrate-flow references: handoff-contract (`§Memory layer integration` — the `metadata.memory_context` / `metadata.memory_writes` schema and orchestrator read/write protocol) and chain-execution (where the chain-start read and end-of-chain routing-outcomes write sit in the execution flow).
