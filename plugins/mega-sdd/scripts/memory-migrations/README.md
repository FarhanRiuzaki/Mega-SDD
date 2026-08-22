# Memory Schema Migrations

Per MEMORY-OQ-1 (Iter 5 design) + Iter 9 audit fix Gap E2E-1.

When `memory_schema` version bumps in future iters, migration scripts ship here. `mega-sdd:memory` skill auto-detects schema mismatch on read + invokes the relevant migration.

## Naming convention

`<from>-to-<to>.sh` (e.g., `1-to-2.sh`)

## Current state (v3.3.0)

- Memory schema version: **1** (unchanged since Iter 5)
- No migrations yet shipped (single version only)
- (v7: the `template-migration.sh` scaffold was removed — copy a prior migration from git history when a new one is needed)

## Migration script contract

Each migration script:

1. Takes `<memory-dir>` as positional argument (e.g., `~/.mega-sdd/memory/` or `<project>/.mega-sdd-memory/`)
2. Reads all memory files in the dir
3. Validates frontmatter `memory_schema` matches `<from>` version
4. Performs in-place upgrade to `<to>` version
5. Writes a backup to `<memory-dir>.backup.<from>-to-<to>.<ISO8601>` BEFORE in-place modification
6. Appends event to `~/.mega-sdd/memory/learning-log.md`: "## Migration <from> → <to> — <timestamp>"
7. Exit 0 on success; non-zero on failure (skill catches + presents to user)

## Invocation pattern

```bash
# Auto-invoked by mega-sdd:memory skill on schema mismatch detection
bash plugins/mega-sdd/scripts/memory-migrations/1-to-2.sh ~/.mega-sdd/memory/
```

Skill emits `memory_schema_mismatch` halt with: "Migration script available. Run via /mega-sdd:memory migrate --from=1 --to=2 ?"

User confirms via AskUserQuestion. Skill invokes the script. On success, schema mismatch resolved + resume chain.

## See also

- `plugins/mega-sdd/skills/memory/references/memory-schema.md` §7 — Schema migration design
- `docs/superpowers/audits/2026-05-21-pipeline-audit-v3.2.md` — Gap E2E-1 / D-3 origin
