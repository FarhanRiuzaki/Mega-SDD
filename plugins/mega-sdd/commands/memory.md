---
description: Inspect / manage mega-sdd's persistent memory across user / project / vault scopes. Self-learning is suggestion-only (never auto-applied without user ACCEPT). Operations — list / show / search / review / prune / promote / diff / export / import / clear.
argument-hint: <operation> [args] [--scope=<user|project|vault>] [--memory-off]
---

Invoke the `mega-sdd:memory` skill via the Skill tool.

User arguments: $ARGUMENTS

Operations (per `skills/memory/SKILL.md` §Inputs):

```
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

Memory scopes (per `skills/memory/references/memory-schema.md` §3):

- `~/.mega-sdd/memory/` — USER scope (cross-project, opt-in promotion only)
- `<project-root>/.mega-sdd/memory/` — PROJECT scope (canonical per `plugins/mega-sdd/references/paths.md`; per-repo, git-trackable per-file per MEMORY-OQ-2). Legacy path `<project-root>/.mega-sdd-memory/` honored for back-compat only when already present.
- `<vault-path>/.memory/` — VAULT scope (per-vault, ephemeral; archived on vault delete per MEMORY-OQ-5)

Hard rails (anti-halu):

- Memory is SUGGESTION-ONLY. NEVER enforcement.
- Every suggestion CITES its source memory entry.
- Current evidence ALWAYS wins over memory.
- No silent auto-tuning. Every learning requires explicit user ACCEPT via `/mega-sdd:memory review`.
- Audit trail mandatory — every accepted learning has a `learning-log.md` entry with rollback path.
- Cross-project promotion explicit (NEVER automatic).
- `--memory-off` disables both reads and writes (skill-level flag).
- `clear --scope=<scope>` requires DOUBLE-CONFIRM (`--confirm-twice` flag + interactive prompt).

On completion, the skill outputs operation-specific results (table, list, JSON, or interactive walk). Memory operations are side-skill — they do NOT trigger pipeline continuation.

For pipeline integration: when running under `/mega-sdd:auto --deep`, the orchestrator reads memory ONCE at chain start and passes relevant slices to skills via handoff YAML `metadata.memory_context` (per MEMORY-OQ-7). Skills emit writes via handoff `metadata.memory_writes`; orchestrator batches persistence at chain end.
