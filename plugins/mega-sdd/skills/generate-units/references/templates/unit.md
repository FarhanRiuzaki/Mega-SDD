---
id: U-XXX
title: <imperative title>
vault_source: <e.g., vault.md#Architecture — legacy vaults: 02-architecture.md#auth>
task_type: create                  # create | extend | verify — from the binding Implementation State Map when present (unit-schema.md)
grounding_confidence: HIGH         # HIGH | MEDIUM | LOW per unit-schema.md — required on newly generated units
module: M-default                  # M-<kebab> per _meta/modules.yaml; M-default when no modules.yaml
depends_on: []
target_files:
  - path: <src/...>
    operation: modify
existing_interfaces:
  - file: <src/types/...>
    symbol: <SymbolName>
    note: <preserve contract>
acceptance_test:
  - type: test
    command: <command>
    expects: ""                # substring the runner LITERALLY prints, or EMPTY (exit-0 criterion) — never a description (unit-schema.md)
binding_refs: []
---

# Unit U-XXX — <Title>

## Goal

<1-2 sentences>

## Context (read first)

<Conversational directive prose, NOT bullets — 2-4 sentences citing the vault sections, the binding entries (C-XX / OQ-XX, or "none"), and why this scope exists: the surrounding system, the user-visible outcome, what changes nothing. (Shape per unit-schema.md §Required body sections.)>

## Implementation steps

1. <step 1>
2. <step 2>
3. <step 3>

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
<TBD OQ items / prose-only constraints, if any — verify units: expanded criteria per unit-schema §Acceptance criteria>

## Out of scope

- <thing 1 not in this unit>
- <thing 2 belongs to U-XXX>
