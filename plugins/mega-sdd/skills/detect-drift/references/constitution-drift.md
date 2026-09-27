# detect-drift — constitution drift detection

Loaded when `<vault>/constitution.md` exists. Extends the drift scan to validate code against constitution clauses, in addition to vault-claim drift. Per `plugins/mega-sdd/references/vault-core.md §constitution` (the §A–§F clause schema the severity categories below key on).

## Procedure additions

After the existing drift scan (entities, flows, decisions):

1. **Read** `constitution.md` + `constitution_hash` from `vault.json`.
2. **Validate the constitution hasn't drifted from binding**: compute the current sha256 of `constitution.md`; compare to `binding.md`'s `constitution_hash` (layout-2); on a layout-3 vault compare to `vault.json` `constitution_hash` — there is no `binding.md`. On mismatch → halt `constitution_drift_detected` (the constitution changed since it was pinned).
3. **Scan code for clause violations (§A–§F)**: for each clause with a mechanically detectable pattern, run an ast-grep or regex probe (ast-grep absent → regex fallback, lower precision; run `/mega-sdd:install-deps --tools=ast-grep` to install automatically); prose-only clauses are flagged "manual review needed" (never fabricate a violation).
4. **Categorize**: `constitution_violation_critical` (§B Security, §F Compliance — halt-equivalent); `constitution_violation_standard` (§A Coding, §C Architecture, §E Performance — warning); `constitution_violation_advisory` (§D Anti-patterns — flag for review).

## Halt YAML — `constitution_drift_detected`

```yaml
blocker:
  type: constitution_drift_detected
  emitted_at: <ISO8601>
  emitted_by: detect-drift
  details:
    constitution_hash_at_binding: <sha256>
    constitution_hash_current: <sha256>
    binding_dated: <ISO8601 — binding.md (layout-2); vault.json generated_at (layout-3)>
    constitution_modified_at: <ISO8601 from fs mtime>
  next_action: "Constitution.md modified since the pinned hash. Revert constitution.md to the pinned state, OR accept the change: bolts already read the live constitution.md at dispatch (priority 9); no script re-pins constitution_hash yet. Layout-2 vault: /mega-sdd:migrate-paths --vault-layout=3 first."
```

After emit, the skill stops; no report is generated for the mismatched scope.

## Report extension — `## Constitution Findings`

```markdown
## Constitution Findings

### Critical violations (§B Security, §F Compliance)
- src/Http/Controllers/UserController.php:45 violates §B-001 (Sanctum auth middleware required); current uses session auth

### Standard violations (§A Coding, §C Architecture, §E Performance)
- src/Models/Order.php:78 violates §C-002 (Models MUST NOT have side effects); fires direct email

### Advisory (§D Anti-patterns)
- src/Services/SwiftDispatcher.php:120 may replicate legacy cfkdhl→CFKDDL pattern (§D-001); manual review recommended
```

## Anti-hallucination rails

- Constitution detection uses ast-grep rules when ast-grep is available (the GROUND / symbol-index probe, the same test step 3 uses); absent → regex fallback with a caveat.
- Findings cite specific `file:line` + specific clause ID.
- Mechanically detectable clauses use a deterministic ast-grep YAML rule.
- Prose-only clauses are flagged "manual review needed" — never fabricated.
- `--no-constitution-drift` opts out (preserves prior behavior).

## Backward compatibility

- Vaults without `constitution.md` → this section is skipped gracefully.
- Existing vault-claim drift detection is unchanged.

## Scope-aware scanning

When `vault.json` has a `scope` field, the drift scan defaults to scope-filtered files (only those referenced by the current scope's units/binding), and the report header adds `**Scope-filtered drift**: yes`. Legacy single-vaults (no scope) scan the full codebase. `--full-scan` forces a full scan even on a scoped vault. The handoff YAML includes a `scope:` block per the handoff contract when applicable.
