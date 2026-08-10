---
id: U-XXX
title: <imperative title>
vault_source: <e.g., 02-architecture.md#auth>
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

## Context

- **Vault source:** <citation>
- **Binding refs:** <C-XX, OQ-XX or "none">
- **Why this scope:** <reasoning>

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
