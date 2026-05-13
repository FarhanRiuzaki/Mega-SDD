# Binding Contract — vault ↔ codebase

The binding contract specifies how vault claims are validated against `codebase-map.md`, what produces a CONFLICT vs OQ vs CONFIRMED, and the blocking rules for downstream phases.

## Claim categories (validated)

| Vault section | Claim type | Map section consulted |
|---|---|---|
| 01-overview.md | mode (greenfield/existing) | repo signals (`.git`, package.json) |
| 02-architecture.md | components, file paths | top-level structure, public interfaces |
| 03-data-model.md | entities, fields | data models / schemas |
| 04-flows.md | endpoints, handlers | routes / endpoints |
| 05-decisions.md | tech stack | languages, frameworks |
| 06-constraints.md | naming conventions | naming conventions, pattern signatures |

## Verdicts

For each claim:

- **CONFIRMED**: claim has matching evidence in codebase-map (entity exists, endpoint registered, naming matches majority).
- **CONFLICT**: claim contradicts codebase-map evidence (vault says "use bearer auth", code uses sessions).
- **OQ**: claim references a code element NOT in codebase-map (e.g., "the legacy user table" — map shows no `user` table).

## Blocking rules

| Outcome | Effect |
|---|---|
| All claims CONFIRMED | bound-vault produced; pipeline proceeds |
| ANY claim CONFLICT | bound-vault NOT produced; binding.md written with CONFLICT list; pipeline BLOCKED |
| Claims include OQ but no CONFLICT (default) | bound-vault produced; OQs propagated to unit-level grounding |
| Claims include OQ + `--strict` flag set | bound-vault NOT produced; pipeline BLOCKED until OQs resolved |

## Resolution paths

When binding blocks:

1. User runs `/mega-sdd:resolve-oq --binding ./binding.md` — interactive walker; updates vault with resolutions
2. Re-run `/mega-sdd:bind-codebase` — if all CONFLICTs now CONFIRMED or downgraded to OQ, bound-vault produced
3. Alternative: user edits vault manually + re-runs binding

## binding.md output structure

See `bind-codebase/SKILL.md` for the file template. Required sections:
- Summary counts (claims_total, confirmed, conflict, oq)
- Confirmed list (cite vault file:line + codebase evidence)
- Conflicts table (id, vault claim, codebase reality, resolution_needed)
- OQ table (id, question, vault source)

## bound-vault structure

`bound-vault/` is a copy of the vault directory with two augmentations:
1. Each markdown file gets inline binding annotations as HTML comments: `<!-- BIND: confirmed | conflict=C-01 | oq=OQ-12 -->`
2. `bound-vault/binding.md` is added (same content as standalone binding.md).
