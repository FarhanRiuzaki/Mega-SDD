---
description: [ADVANCED / AUTO-INVOKED] Show module progress. Auto-invoked by `/mega-sdd:auto` in chain end summary. Run standalone for mid-pipeline status check OR interactive DoD marking via --mark-dod flag. computes per-module unit completion + DoD checklist status. Supports --mark-dod for interactive DoD item toggling. Module = semantic grouping ABOVE atomic units (Iter 11; per references/modules-schema.md).
argument-hint: [vault-path] [--module=<id>] [--mark-dod=<module>] [--format=table|json]
---

Display module progress + DoD status for the current vault.

User arguments: $ARGUMENTS

## Procedure

### Step 1 — Resolve vault path

- If positional arg provided: use it
- Otherwise probe `<project>/.mega-sdd/vaults/*/vault.json` (v3.4+ layout) FIRST, then `<project>/docs/mega-sdd/vaults/*/vault.json` (legacy) — first match
- Halt if no vault found OR if vault.json malformed

### Step 2 — Load modules

Read `<vault>/_meta/modules.yaml`. If absent:
- If `<vault>/_meta/modules.yaml.auto` exists → suggest user rename to `modules.yaml` to lock in
- Otherwise emit chat: "No modules defined. Run `/mega-sdd:generate-units --derive-modules` to auto-derive, or write `_meta/modules.yaml` manually per `generate-units/references/modules-schema.md`."
- Fall back to display: "All units in M-default (single implicit module)"

### Step 3 — Compute per-module status

For each module:

1. **Filter units**: count of units where `module: <module-id>`
2. **Completion**: count units where bolt-outcomes.json shows `status: completed` for that unit
3. **In-progress**: count units where bolt-outcomes.json shows `status: halted_postflight` or partial outcomes
4. **Pending**: total - completed - in-progress
5. **DoD status**: read modules.yaml `dod:` checklist; cross-reference any auto-runnable items (test commands) by re-running them
6. **blocked_by**: list of modules in `blocked_by:` that aren't `status: completed` themselves
7. **Status label**:
   - `not-started` — 0 units completed
   - `in-progress` — >0 completed, <100%
   - `units-complete` — 100% units done, DoD not fully checked
   - `completed` — 100% units + all DoD items pass

### Step 4 — Render output

Default format `table`:

```
Vault: leave-management v3
Total units: 13 | Modules: 4

ID              Name                          Status         Units   DoD     Priority   Blocked-by
M-auth          Authentication & Auth         in-progress    2/5     2/3     P0         (none)
M-leave-mgmt    Leave Management              not-started    0/3     0/2     P1         M-auth (pending)
M-reporting     Reporting & Analytics         completed      2/2     3/3     P2         M-auth (ok)
M-admin         Admin Console                 in-progress    1/3     0/2     P1         (none)

⚠️ Cross-module dependency: M-leave-mgmt is blocked-by M-auth (3 units still pending in M-auth).

Next actionable:
  → Complete M-auth: 3 units pending (U-003, U-007, U-008)
  → Run: /mega-sdd:execute-bolts --module=M-auth
```

For `--format=json`: emit structured JSON (machine-parseable for scripting).

### Step 5 — Optional --mark-dod interactive flow

If `--mark-dod=<module-id>` flag:

1. Read module's DoD checklist
2. For each unchecked item: present via `AskUserQuestion`:
   - "DoD item: <text> — mark as passing?"
   - Options: (1) Mark passing (✓), (2) Skip, (3) Run associated test command (if applicable)
3. On (1): update `modules.yaml` checklist marker `- [x]`; log to memory `outcomes.md`
4. On (3): if item text matches `<test-command-pattern>` (e.g., `phpunit ...`), invoke via Bash; on success → mark passing
5. After all items reviewed: if all checked → mark module `status: completed`; congratulate; emit chat suggesting next module

### Step 6 — Hand-off

After display:
- If unblocked actionable module exists → suggest specific `--module=<id>` execute-bolts command
- If all modules blocked → suggest unblocking path (resolve OQ / fix issue / complete dependent module)
- If all modules complete → suggest `/mega-sdd:detect-drift` for periodic drift verification

## Halt conditions

- Vault not found / vault.json corrupt → halt with helpful error
- `--mark-dod` invoked but module ID unknown → halt with list of valid module IDs
- `--mark-dod` test command invocation fails → don't auto-mark; user resolves manually

## Anti-halu rails

- **Module status is derived from objective signals**: unit count from filesystem + bolt-outcomes.json from memory + DoD checklist from modules.yaml — NEVER inferred
- **DoD test commands**: invoked via Bash; exit code = pass/fail (deterministic). Never "LLM thinks it passes".
- **blocked_by status**: probed by recursively reading dependent module status. Cycle detection via Iter 11 cross-module DAG validation.

## References

- `plugins/mega-sdd/skills/generate-units/references/modules-schema.md` — module schema definition
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — `--module=<id>` execution flag
- `plugins/mega-sdd/skills/memory/SKILL.md` — bolt-outcomes.json memory storage
