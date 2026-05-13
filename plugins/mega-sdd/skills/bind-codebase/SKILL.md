---
name: bind-codebase
version: 1.0.0
description: Validate a vault against `codebase-map.md`. Produces `<vault>-bound/` + `binding.md` with CONFIRMED/CONFLICT/OQ verdicts per claim. BLOCKS downstream unit generation on conflicts. Triggers — "bind vault to code", "validate vault against repo", "cek vault vs codebase", "binding gate", or paraphrases.
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
- `<vault>-bound/` (sibling of vault dir) — written only when no CONFLICTs (or `--strict` and no OQs)

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

2.5. **Deferred-OQ auto-resolution.**

   For each OQ in the vault with `status: deferred` AND `defer_to: binding`:

   a. **Extract** the OQ text and section context.

   b. **Search codebase-map.md for evidence:**
      - If OQ mentions a specific entity name → search §3 (data models / schemas) for exact match
      - If OQ mentions an endpoint path → search §4 (routes / endpoints) for exact match
      - If OQ mentions a file path or symbol name → search §2 (public interfaces) for exact match
      - Otherwise → string-search across all map sections with conservative fuzzy threshold

   c. **High-confidence match** (single unambiguous hit):
      - Set OQ status: `resolved`
      - Set `resolved_at: <now>`
      - Set `resolution: "Auto-resolved by bind-codebase. Evidence: <codebase-map citation>"`
      - Append entry to `binding.md` under a "## Auto-Resolved Deferred OQs" section:
        ```
        | OQ-ID | Question | Evidence (codebase-map) | Status |
        |---|---|---|---|
        | OQ-DATA-001 | ... | §3 entry: User table line 42 | auto-resolved |
        ```

   d. **No match found OR ambiguous match** (multiple hits or low confidence):
      - Do NOT modify OQ status (remains `deferred`)
      - Propagate to `binding.md` under "## Open Questions" section:
        ```
        | ID | Question | Source vault section | Auto-resolve attempted |
        |---|---|---|---|
        | OQ-DATA-001 | ... | 03-data-model.md | no match found |
        ```
      - These get walked by user via `/mega-sdd:resolve-oq --binding <binding.md>`

   e. **Conservative threshold:** When in doubt, prefer falling back to manual resolution (d). Never silently auto-resolve a deferred OQ that could be wrong. The user trusts the citation in (c); never write an evidence string that doesn't exist in codebase-map.

   Update aggregate counts (claims_total / confirmed / conflict / oq) to include any newly auto-resolved deferred OQs in `confirmed`.

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

## Auto-Resolved Deferred OQs (N)
| OQ-ID | Question | Evidence (codebase-map) | Status |
|---|---|---|---|
...

## Open Questions (N)
| ID | Question | Source | Auto-resolve attempted |
|---|---|---|---|
...
```

5. **Decision gate:**
   - If `conflict == 0` AND (`oq == 0` OR `--strict` not set):
     - **Produce `<vault>-bound/`** — copy vault dir; inject inline binding annotations (HTML comments per binding-contract.md)
     - **Announce:** "Binding clean. Bound-vault written to `<vault>-bound/` (sibling of vault directory). Next: `/mega-sdd:generate-units <vault>-bound/`."
   - If `conflict > 0` OR (`--strict` AND `oq > 0`):
     - **DO NOT** write the <vault>-bound/ sibling directory
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

- Clean binding → suggest `/mega-sdd:generate-units <vault>-bound/`
- Blocked → suggest `/mega-sdd:resolve-oq --binding <binding.md>`
