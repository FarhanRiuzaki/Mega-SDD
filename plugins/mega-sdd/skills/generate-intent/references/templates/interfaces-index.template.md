---
type: index
doc_id: interfaces-index
vault_version: "{{VAULT_VERSION}}"
aliases: [Interfaces Index, Cross-Squad Contracts]
tags: ["vault/{{PROJECT_SLUG}}", "doc/interfaces-index"]
---

# Cross-Squad Interfaces — Index

> Every cross-squad coupling MUST be represented by an interface note in this folder.
> Status `locked` is required before consumer-squad units can execute via
> `/mega-sdd:execute-bolts --squad=<consumer>`.

## Rules

1. One producer squad per interface; one or more consumer squads.
2. Schema is concrete (OpenAPI / GraphQL / DBML / event payload), not prose.
3. Status transitions: `draft` → `locked` (one-way; bump version to revise).
4. Each interface cites the vault flow + entities it implements.

## Interfaces in this vault

<!-- This list is hand-maintained or refreshed by an Obsidian Dataview / manual
     edit. Plugin does not auto-regenerate. -->

| ID | Title | Kind | Producer | Consumers | Status |
|----|-------|------|----------|-----------|--------|
| _none yet_ | — | — | — | — | — |

## How to author a new interface

1. Copy `interface-note.template.md` to this folder, renamed to `<kebab-id>.md`
2. Fill frontmatter (producer, consumers, kind, related_flows, related_entities)
3. Write the concrete schema in the `## Contract` section
4. Define DoD per side (producer + each consumer)
5. List blocking OQs (if any)
6. Append row to the table above

## Lock procedure

When stakeholders approve a draft interface:
1. Set `status: locked` in frontmatter
2. Set `locked_at: YYYY-MM-DD` (today)
3. Update this index table's Status column to `locked`
4. Re-run `/mega-sdd:execute-bolts --per-squad` to unblock consumer squads

## Anti-hallucination

- `execute-bolts` halts (`cross_squad_interface_draft`) if a unit `consumes_interfaces` something with `status: draft`
- `generate-units` halts (`cross_squad_dep_invalid`) if a unit's `depends_on` references a unit in a different squad (must route via interface instead)
