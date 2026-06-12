# bind-codebase — Constitution-aware CONFLICT surfacing (Step 2.10)

Per `generate-intent/references/vault-contract.md` §constitution. When `<vault>/constitution.md` exists:

a. **Read `constitution.md`** at the start of Step 2 (binding); cache for cross-referencing.
b. **For each CONFLICT detected**, scan constitution §A–F clauses for relevant rules.
c. **Cite constitution clauses** in `binding.md` CONFLICT entries when applicable:
   ```
   | C-007 | Auth uses Bearer | Code uses session | Constitution §B-001 mandates Sanctum auth on /api/* (clause precedence) | KEEP_VAULT |
   ```
d. **Constitution-violation as halt:** if existing code is in CONFLICT with the constitution AND the user passed `--strict-constitution`, surface `bind_conflict_constitution_violation`; the user resolves before the vault locks.
e. **Constitution hash persistence:** write `constitution_hash` (sha256 of `constitution.md` content) to `binding.md` frontmatter for later drift detection by `detect-drift`.

## Halt YAML — `bind_conflict_constitution_violation`

```yaml
blocker:
  type: bind_conflict_constitution_violation
  emitted_at: <ISO8601>
  emitted_by: bind-codebase
  details:
    conflict_id: C-007
    vault_claim: "<verbatim from vault>"
    codebase_reality: "<verbatim from codebase-map>"
    constitution_clause: "§B-001 — All API endpoints MUST use Sanctum auth middleware"
    violation_severity: high
  next_action: "Constitution clause §B-001 takes precedence. Either: (1) update codebase to satisfy the constitution (recommended; preserves the invariant), (2) update the constitution clause if no longer applicable (rare; requires user sign-off), (3) accept the conflict via /mega-sdd:resolve-oq --binding."
```

## Backward compatibility

- Vaults without `constitution.md` → Step 2.10 is SKIPPED gracefully; no halt, no citation. (This includes vaults generated with generate-intent's `--no-constitution` flag — bind-codebase itself needs no opt-out flag; absence of the file IS the opt-out.)
