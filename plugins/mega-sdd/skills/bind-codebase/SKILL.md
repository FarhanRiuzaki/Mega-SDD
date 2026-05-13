---
name: bind-codebase
version: 1.0.0
description: Validate a vault against `codebase-map.md`. Produces `bound-vault/` + `binding.md` with CONFIRMED/CONFLICT/OQ verdicts per claim. BLOCKS downstream unit generation on conflicts. Triggers — "bind vault to code", "validate vault against repo", "cek vault vs codebase", "binding gate", or paraphrases.
---

# Bind-Codebase

The brownfield anti-hallucination keystone. Refuses to let unit generation proceed against an ungrounded vault.

**Announce at start:** "I'm using the bind-codebase skill to validate the vault against the codebase map."

## When to use

- After `scan-codebase` produced `codebase-map.md` and the user has a vault
- `orchestrate-flow` auto-routes to this skill for brownfield projects
- User explicit: `/mega-sdd:bind-codebase <vault> [<codebase-map>]`

## Inputs

- Vault path (positional, required) — directory containing the 7-file vault
- Codebase map path (optional, default: `<repo-root>/codebase-map.md` or `./codebase-map.md`)
- Flags: `--strict` (block on OQ too, not just CONFLICT), `--auto`

## Outputs

- `binding.md` — always written, even when blocking
- `bound-vault/` — written only when no CONFLICTs (or `--strict` and no OQs)

## Procedure

1. **Load inputs.**
   - Read vault files (00-index, 01-overview, ..., vault.json)
   - Read codebase-map.md
   - If codebase-map missing: halt with message — instruct user to run `scan-codebase` first

2. **Per claim type (per `references/binding-contract.md`), produce verdict.**
   For each vault claim referencing code:
   - Search codebase-map for matching evidence
   - Apply verdict logic:
     - Exact match (file path + signature) → CONFIRMED
     - Found but contradicts → CONFLICT
     - Not found → OQ

3. **Aggregate counts.** Track `claims_total`, `confirmed`, `conflict`, `oq`.

4. **Write `binding.md`.** Use the template from `references/binding-contract.md`:

```yaml
---
vault: <vault path>
codebase_map: <map path>
bound_at: <ISO timestamp>
strict: <true/false>
---

# Binding Manifest

## Summary
- claims_total: N
- confirmed: N
- conflict: N
- oq: N

## Confirmed Claims (N)
- C-001 | <vault file:line> | <codebase evidence> | <claim text>
...

## Conflicts (N) — BLOCKING
| ID | Vault Claim | Codebase Reality | Resolution Needed |
|---|---|---|---|
| X-001 | ... | ... | KEEP_VAULT / KEEP_CODE / DEFER / SPLIT |

## Open Questions (N)
| ID | Question | Source |
|---|---|---|
| OQ-001 | ... | <vault file:line> |
```

5. **Decision gate:**
   - If `conflict == 0` AND (`oq == 0` OR `--strict` not set):
     - **Produce `bound-vault/`** — copy vault dir; inject inline binding annotations (HTML comments per binding-contract.md)
     - **Announce:** "Binding clean. Bound-vault written to `<path>`. Next: `/mega-sdd:generate-units <bound-vault>`."
   - If `conflict > 0` OR (`--strict` AND `oq > 0`):
     - **DO NOT** write bound-vault directory
     - **Announce blocker:** "Binding BLOCKED. <N> conflicts must be resolved. Run `/mega-sdd:resolve-oq --binding <binding.md>` or edit vault manually, then re-run bind-codebase."
     - Emit blocker YAML per `vault-contract.md` §halt-protocol

6. **Audit log.** Append entry to `<vault>/vault.json` changelog: `{ "event": "bind", "at": "...", "summary": "N confirmed, N conflict, N oq" }`.

## Anti-hallucination rails

- Never auto-resolve CONFLICTs. Always human-in-the-loop.
- Never write bound-vault while conflicts exist. The gate is non-negotiable.
- When evidence is ambiguous, default to OQ not CONFIRMED.
- Claim text in binding.md is verbatim from vault — no paraphrasing.

## Halt conditions

- Missing `codebase-map.md`: halt, instruct `scan-codebase` first
- Vault missing required files (00-index, vault.json): halt, instruct vault repair
- `claims_total == 0`: halt, vault has no code-referencing claims (likely greenfield — pipeline should skip binding)

## Hand-off

- Clean binding → suggest `/mega-sdd:generate-units <bound-vault>`
- Blocked → suggest `/mega-sdd:resolve-oq --binding <binding.md>`
