# execute-bolts — Hard Rule pre/post-flight scan

The anti-hallucination gate. Each unit's `## Hard rules` are validated against real codebase state **before** the bolt (pre-flight snapshot) and **after** the bolt (post-flight diff); any post-flight violation **HALTS BEFORE COMMIT** with the bolt's changes left uncommitted in the working tree for human review. The skill body owns the gate's existence + trigger; this file owns the grammar, snapshot formats, and per-rule mechanics.

## Contents
- Pre-flight: grammar detection
- Pre-flight: v2 (ast-grep) snapshot
- Pre-flight: v1 (legacy 5-grammar) snapshot
- `preflight.json` format
- Halt YAMLs (`hard_rule_unparseable`, `hard_rule_unanchored`)
- Post-flight: per-rule re-validation
- Framework-pack rule provenance
- Per-sibling cross-cutting registration scan
- Parent-thread post-flight re-scan
- Violation handling + `hard_rule_violated` halt YAML
- verify-unit special path

## Pre-flight: grammar detection

For each unit with a non-empty `## Hard rules` body section:

- YAML code blocks under `## Hard rules` → **v2 grammar** (ast-grep YAML; the grammar spec is the v2 Hard-rule-grammar ref listed in SKILL.md).
- Bulleted line items (`- DO NOT modify ...`) → **v1 grammar** (the 5-type legacy set).
- Mixed (both forms in one unit) → halt `hard_rule_mixed_grammar` (user migrates via `/mega-sdd:migrate-rules`).
- Override via `--hard-rule-grammar=v1|v2`.

**For v2 grammar:** probe `command -v ast-grep`. Absent → halt `dep_missing` (install guidance is in the v2 Hard-rule-grammar ref listed in SKILL.md). Validate each YAML block via `ast-grep test --validate`. Unparseable → halt `hard_rule_unparseable`.

**For v1 grammar (legacy path preserved):** parse each rule line against the 5-grammar set per `generate-units/references/unit-schema.md` §Hard rule grammar. NEVER silently skip an unrecognized line — unparseable → halt `hard_rule_unparseable`:

- `DO NOT modify <path>`
- `DO NOT add new <manifest> dependencies`
- `<path-glob> MUST follow <case-style> naming`
- `function <name> MUST preserve signature: <type-sig>`
- `file <path> MUST exist after bolt`

## Pre-flight: v2 (ast-grep) snapshot

For each rule, snapshot AST state via `ast-grep scan --rule <yaml> --json` (zero matches expected pre-bolt for "forbidden" rules). Persist the matched-files list + sha256 per matched file for the post-flight diff.

## Pre-flight: v1 (legacy 5-grammar) snapshot

- `DO_NOT_MODIFY <path>` → record `sha256(file content)` if the file exists; record "absent" otherwise.
- `DO_NOT_ADD_DEPS <manifest>` → record the manifest's dependency-section content.
- `NAMING_RULE <path-glob> <case-style>` → no pre-snapshot (post-flight checks new files only).
- `SIGNATURE_RULE function <name>` → read codebase-map §2 for the current signature; record verbatim. Not in codebase-map → halt `hard_rule_unanchored`.
- `FILE_PRESENCE_RULE file <path>` → no pre-snapshot.

## `preflight.json` format

Persist the snapshot as `<vault>/bolts/U-XXX/preflight.json` for post-flight comparison:

```json
{
  "unit_id": "U-001",
  "snapshot_at": "2026-05-20T10:00:00Z",
  "rules": [
    {"type": "DO_NOT_MODIFY", "path": "src/Models/User.php", "sha256": "abc123..."},
    {"type": "DO_NOT_ADD_DEPS", "manifest": "package.json", "deps_section": "..."},
    {"type": "SIGNATURE_RULE", "function": "authenticateUser", "signature_at_preflight": "(email: string, password: string) => Promise<User>"}
  ]
}
```

## Halt YAMLs

```yaml
blocker:
  type: hard_rule_unparseable
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    offending_line: "<verbatim>"
    expected_grammar: [DO_NOT_MODIFY, DO_NOT_ADD_DEPS, NAMING_RULE, SIGNATURE_RULE, FILE_PRESENCE_RULE]
  next_action: "Fix the unit's ## Hard rules section per generate-units/references/unit-schema.md §Hard rule grammar."
```

```yaml
blocker:
  type: hard_rule_unanchored
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    rule: "function <name> MUST preserve signature: ..."
    reason: "Referenced function not found in codebase-map; cannot snapshot or validate"
  next_action: "Verify the function name is correct OR remove this rule if the function doesn't exist yet."
```

## Post-flight: per-rule re-validation

After `executing-plans` completes and acceptance tests pass, run the post-flight scan **BEFORE committing**. This is the safety net.

**v2 grammar (ast-grep):**

```bash
# Per rule: run ast-grep scan; any match against "forbidden" patterns = VIOLATED
ast-grep scan --rule <rule-yaml-tempfile> --json <repo-root>
```

Parse the JSON output. Match found → VIOLATED with `file:line` + matched text as evidence. Zero matches → PASSED. For `files:`-scoped lock rules, also compare the current sha256 to the preflight snapshot (defense in depth).

**v1 grammar (legacy, preserved):**

| Rule type | Post-flight check |
|---|---|
| `DO_NOT_MODIFY <path>` | Compute current `sha256(file)`. Compare to preflight snapshot. Differs OR file appeared → VIOLATED. |
| `DO_NOT_ADD_DEPS <manifest>` | Read current manifest deps section. Diff against preflight snapshot. ANY new entry → VIOLATED. |
| `NAMING_RULE <path-glob> <case-style>` | Enumerate new files matching `path-glob`. Apply case-style regex. Mismatch → VIOLATED. |
| `SIGNATURE_RULE function <name>` | Re-extract current signature from codebase. Compare to preflight. Differs → VIOLATED. |
| `FILE_PRESENCE_RULE file <path>` | Probe `<path>` exists. Absent → VIOLATED. |

Post-flight results are written to `<vault>/bolts/U-XXX/postflight.json` (per-rule pass/fail + evidence).

> `--force-skip-postflight` skips the ast-grep step for ONE run only and is logged per the SKILL.md anti-bypass policy (handoff `notes.postflight_skipped: true` + `_summary.md`). It does NOT downgrade the rail; a follow-up re-run without the flag is required before drift-detect / merge.

## Framework-pack rule provenance

Framework-pack rules (pulled into a unit's Hard Rules by `generate-units` Step 12.4.5) are validated identically to other Hard Rules — the ast-grep `rule:` block from the pack runs against the codebase post-bolt. The violation surface includes a `framework_pack_source` field in the halt YAML so the user knows WHICH framework rule fired.

## Per-sibling cross-cutting registration scan (defense-in-depth)

When a unit fans out into N structurally-analogous sibling models (a module's golden exemplar plus siblings), a cross-cutting concern proven on the exemplar (e.g. registering the `BranchScoped` global scope) must be verified in EACH sibling's generated source — not once. The classic execution-fidelity miss: every sibling SPEC named the `BranchScoped` trait, but the bolt forgot the `addGlobalScope(new BranchScoped)` registration in several generated models — a silent cross-branch authorization leak that no unit-spec or Hard-Rule check catches (the spec was correct; the runtime call was dropped).

This is ENFORCED by `scripts/validate-cross-cutting-registration.sh`, which reads the active framework pack's `## Cross-cutting concerns` (each concern's `registration_signature` + `registration_target_glob`) and scans every generated source file that references the concern mechanism AND carries the `applies_when` column, flagging any that lack the registration call. It runs PostToolUse on model/source writes (→ `.cross-cutting-state.json`); PreToolUse Branch 11 blocks the NEXT `execute-bolts` on FAIL (honest detect-and-block-next — a hook cannot un-write a file a bolt just wrote mid-turn). This prose is defense-in-depth; the validator is the gate. Tech-agnostic: never assume a stack's registration idiom — it comes from the pack, so add a stack = add a pack.

## Parent-thread post-flight re-scan

The project-wide quality validators that scan GENERATED SOURCE/VIEWS — `validate-cross-cutting-registration.sh`, `validate-ui-quality.sh`, and (for vault edits) `validate-vault-oqs.sh` — fire via PostToolUse on the writer's Write/Edit. Under `--parallel` / `--per-squad`, the bolt subagent's writes are subagent-internal and invisible to the parent PostToolUse, so their state can be stale until a later parent-thread write re-triggers the project-wide rescan. To close that window: after each bolt batch completes, the parent thread (executing-plans) explicitly bash-invokes those validators against `$PROJECT_ROOT` so the gate state reflects current truth regardless of who wrote the files. This is the documented detect-and-block-next contract; the explicit post-flight invoke makes "next" deterministic rather than dependent on an incidental parent write.

## Violation handling + `hard_rule_violated` halt YAML

- **ANY rule violated → HALT BEFORE COMMIT.** The bolt's code changes remain in the working tree (uncommitted). The user reviews + reverts / edits.
- Emit the `hard_rule_violated` blocker YAML with `violated_rule` + evidence.
- `bolt-report.md` MUST be written with `status: halted_postflight` and list the violations.

```yaml
blocker:
  type: hard_rule_violated
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    violations:
      - rule: "DO NOT modify src/Models/User.php"
        evidence: "sha256 mismatch — preflight: abc123..., postflight: def456..."
      - rule: "function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>"
        evidence: "Signature changed; postflight: (email: string, password: string, twoFactor?: string) => Promise<User>"
  next_action: "Review changes in working tree; revert the offending modification OR edit the unit's Hard rules + re-run execute-bolts."
```

## verify-unit special path

`task_type: verify` units run a simplified flow (no code write):

1. Pre-flight: validate the unit's `target_files` is empty / all `operation: none` (else halt `verify_unit_writable` — verify units are read-only and must never be written).
2. Skip `executing-plans` (no code to write).
3. Run acceptance tests.
4. Skip the post-flight Hard-rule scan (no changes to validate).
5. Commit only `bolt-report.md` (no source changes); OR skip the commit entirely on `--no-empty-commits`.
