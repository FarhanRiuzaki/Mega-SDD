---
description: Migrate v1 Hard Rule grammar (Iter 3 5-type) to v2 ast-grep YAML rules (Iter 6). Walks vault units; offers per-unit migration via AskUserQuestion (explicit confirm per ITER6-OQ-2). v1 rules preserved as HTML comments for audit. Writes .migration-log.md.
argument-hint: <vault-path> [--dry-run] [--auto-confirm] [--to=v1|v2]
---

Invoke the Hard Rule grammar migration helper via Bash + `mega-sdd:execute-bolts` skill consultation.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: vault path (required)
- `--dry-run`: preview changes without writing
- `--auto-confirm`: skip per-unit AskUserQuestion (use with caution; default = interactive)
- `--to=v2` (default): migrate v1 → v2
- `--to=v1`: reverse migration (v2 → v1) for rollback testing; experimental

Procedure:

1. **Verify vault**: `<vault-path>/units/U-*.md` exists; halt with helpful error if not.

2. **Pre-flight**: probe `ast-grep` on PATH (required for v2 syntax validation). If absent, halt with install commands per `execute-bolts/references/hard-rule-grammar-v2.md` §Installation guidance.

3. **Run migrate script**:
   ```bash
   bash plugins/mega-sdd/skills/execute-bolts/scripts/migrate-v1-rules.sh <vault-path> [flags]
   ```
   Script walks units, identifies v1 rules, offers per-unit migration via interactive prompt.

4. **Per unit (when --auto-confirm not set)**:
   - Show v1 rules detected
   - Show proposed v2 YAML conversion (Claude transforms via pattern matching per `execute-bolts/references/hard-rule-grammar-v2.md` §Mapping v1 → v2)
   - User confirms: ACCEPT / SKIP / EDIT (edit proposed v2 inline)
   - On ACCEPT: write v2 YAML; preserve v1 as HTML comment for audit
   - On SKIP: no changes; log to .migration-log.md
   - On EDIT: surface editor; user provides custom v2 YAML

5. **Validate after migration**:
   - Run `ast-grep test --validate <each-v2-rule>` to confirm parseable
   - If any rule fails validation → halt; user fixes manually

6. **Write log** to `<vault-path>/units/.migration-log.md`:
   - Per-unit migration status (migrated / skipped / failed)
   - Total v1 rules → v2 rules count
   - Timestamp + tool version

Hard rails (anti-halu, per Iter 6 spec §7):

- Migration NEVER silent. User confirms per unit (--auto-confirm explicit opt-in).
- v1 rules preserved as HTML comments below ## Hard rules header. Audit trail intact.
- Failed v2 validation HALTS migration (don't ship broken rules).
- `--dry-run` mode shows planned changes without writing. Always run dry-run first on production vaults.
- Rollback: `--to=v1` reverses migration (experimental); for safer rollback, `git revert` the migration commit.

On completion:
- Announce: "Migrated N units (M v1 rules → K v2 rules). Skipped P units. Log: <path>"
- Suggest next step: `/mega-sdd:execute-bolts --hard-rule-grammar=v2 <unit-id>` to validate v2 grammar end-to-end.

Backward compat: post-migration units may co-exist with non-migrated units in same vault. `execute-bolts` auto-detects per-unit grammar.
