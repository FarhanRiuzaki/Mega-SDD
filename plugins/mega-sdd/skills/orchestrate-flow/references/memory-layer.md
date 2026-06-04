# Memory Layer — Single Memory I/O Point

When memory is enabled (default; opt-out via `--memory-off`), the orchestrator is the SINGLE memory I/O point for the chain. Skills do not re-read disk; they receive slices via handoff YAML `metadata.memory_context` and emit writes via `metadata.memory_writes`. This keeps autonomy mode FAST (I/O batched at orchestrator level) and CONSISTENT (single source of truth per chain run).

## Contents

- [Chain start (single memory read)](#chain-start-single-memory-read)
- [Per-phase invocation](#per-phase-invocation)
- [Per-phase write batching](#per-phase-write-batching)
- [Chain end](#chain-end)
- [Anti-halu rails](#anti-halu-rails)

## Chain start (single memory read)

Before invoking the first skill in `--deep` mode:

1. Read user-scope: `~/.mega-sdd/memory/preferences.md` + `~/.mega-sdd/memory/patterns.md`
2. Read project-scope: `<cwd-project>/.mega-sdd/memory/decisions.md` + `conventions.md` + `outcomes.md`
3. Read vault-scope (if vault detected): `<vault>/.memory/classifier-accuracy.json` + `bind-history.md` + `bolt-outcomes.json`
4. Verify all `memory_schema` versions match expected; halt with `memory_schema_mismatch` blocker if any differ
5. Build per-skill memory slices (filter to only what each skill needs)
6. Surface chain history in confirmation: "Past 3 runs: 2 completed, 1 halted on bind_conflict. Continue?"

## Per-phase invocation

When invoking each skill via the Skill tool:

1. Pass that skill's memory slice via handoff YAML `metadata.memory_context` field (per the handoff-contract reference `§Memory layer integration`, indexed in SKILL.md §Specialist references)
2. Skill reads from the in-memory slice — no disk re-read

## Per-phase write batching

When a skill emits a handoff with `metadata.memory_writes`:

1. Validate each write entry (file, scope, action, content)
2. Append to the target file per scope rules (resolve absolute path from CWD + vault)
3. Atomic per-file append (race-tolerant)
4. Log writes to chain progress chat (one line per write)
5. Failed writes logged but do NOT halt chain (memory is optional)

## Chain end

After the last skill completes:

1. Final memory summary in chat: "Chain wrote N memory entries across scopes: user (X), project (Y), vault (Z)"
2. If pending suggestions accumulated (≥1 threshold crossed): announce "Mega-SDD has N pending learning suggestions. Review via `/mega-sdd:memory review`"

## Anti-halu rails

- Memory schema mismatch HALTS the chain (cannot continue with mixed schemas)
- Memory I/O failures (disk, perm) logged but do NOT halt (graceful degradation)
- Suggestions surfaced at chain end; NEVER auto-applied
- `--memory-off` propagates to all sub-skills automatically (passed as a flag in handoff invocation args)

## See also

SKILL.md §Specialist references indexes the related orchestrate-flow references: handoff-contract (`§Memory layer integration` — the `metadata.memory_context` / `metadata.memory_writes` schema and orchestrator read/write protocol) and chain-execution (where the chain-start read and end-of-chain routing-outcomes write sit in the execution flow).
