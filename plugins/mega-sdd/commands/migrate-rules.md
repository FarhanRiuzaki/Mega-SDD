---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: <vault-path> [--dry-run] [--auto-confirm] [--to=v2]
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:migrate-rules` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Invoke the Hard Rule grammar migration helper via Bash + `mega-sdd:execute-bolts` skill consultation.

User arguments: $ARGUMENTS

Argument parsing:
- First positional: vault path (required)
- `--dry-run`: preview changes without writing
- `--auto-confirm`: tells the shell script to run non-interactively (it only DETECTS v1 rules — the real per-unit confirmation is the skill's Step-4 AskUserQuestion). The agent path (Bash tool = no TTY) MUST pass this or `--dry-run`, or the script's TTY guard aborts. "Interactive" describes a direct human terminal run of the script, not the skill flow.
- `--to=v2` (default): migrate v1 → v2
- `--to=v1`: NOT implemented — the detector script rejects it with a clear error (reverse migration was never built; do not present it as available)

Procedure:

1. **Verify vault**: `<vault-path>/units/U-*.md` exists; halt with helpful error if not.

2. **Pre-flight**: probe `ast-grep` on PATH (required for v2 syntax validation). If absent, halt with install commands per `execute-bolts/references/hard-rule-grammar-v2.md` §Installation guidance.

3. **Run migrate script** (detection only — it modifies no unit). The agent runs it
   non-interactively (no TTY under the Bash tool), so pass `--auto-confirm` (or `--dry-run`):
   ```bash
   bash plugins/mega-sdd/skills/execute-bolts/scripts/migrate-v1-rules.sh <vault-path> --auto-confirm
   ```
   The script walks units and identifies v1 rules; the actual per-unit confirmation is Step 4 below (the skill's AskUserQuestion), NOT a prompt inside the script.

4. **Per unit (when --auto-confirm not set)**:
   - Show v1 rules detected
   - Show proposed v2 YAML conversion (Claude transforms via pattern matching per `execute-bolts/references/hard-rule-grammar-v2.md` §Mapping v1 → v2)
   - User confirms: ACCEPT / SKIP / EDIT (edit proposed v2 inline)
   - On ACCEPT: write v2 YAML; preserve v1 as HTML comment for audit
   - On SKIP: no changes; log to .migration-log.md
   - On EDIT: surface editor; user provides custom v2 YAML

5. **Validate after migration** (the SKILL performs this — the shell script only detects):
   - Parse each emitted v2 rule via parse-via-scan (`ast-grep test --validate` does NOT exist — snippet in `execute-bolts/references/hard-rule-grammar-v2.md` §Pre-flight)
   - If any rule fails to parse → halt; user fixes manually. The unit's v2 blocks are NOT written until they parse.

6. **Write log** to `<vault-path>/units/.migration-log.md`:
   - The shell script logs DETECTION only (`detected (delegated to skill)` / skipped) — it modifies no unit.
   - The skill appends the actual outcome per unit (migrated / skipped / failed) AFTER the v2 YAML lands and parses; a unit is never logged `migrated` before its file changed.
   - Total v1 rules → v2 rules count; timestamp + tool version.

Hard rails (anti-halu):

- Migration NEVER silent. User confirms per unit (--auto-confirm explicit opt-in).
- v1 rules preserved as HTML comments below ## Hard rules header. Audit trail intact.
- Failed v2 validation HALTS migration (don't ship broken rules).
- `--dry-run` mode shows planned changes without writing. Always run dry-run first on production vaults.
- Rollback: `git revert` the migration commit (`--to=v1` is NOT implemented — the script rejects it).

On completion:
- Announce: "Migrated N units (M v1 rules → K v2 rules). Skipped P units. Log: <path>"
- Suggest next step: `/mega-sdd:execute-bolts --hard-rule-grammar=v2 <unit-id>` to validate v2 grammar end-to-end.

Backward compat: post-migration units may co-exist with non-migrated units in same vault. `execute-bolts` auto-detects per-unit grammar.
