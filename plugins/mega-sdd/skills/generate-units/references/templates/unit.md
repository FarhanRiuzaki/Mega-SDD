---
id: U-XXX
title: <imperative title>
vault_source: <e.g., vault.md#Architecture — legacy vaults: 02-architecture.md#auth>
prd_source: <e.g., docs/PRD.md#halaman-kontak — PRD heading slug or :line this unit implements; list allowed; omit ONLY if the requirement has no PRD home (v8 P1)>
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

<1-2 sentences — xs class (1–2 acceptance entries AND ≤3 steps): ONE line; Context ≤2 sentences; drop Anti-patterns/Out of scope unless every item is sourced (unit-schema.md §xs body diet)>

## Context (read first)

<Conversational directive prose, NOT bullets — 2-4 sentences citing the vault sections, the binding entries (C-XX / OQ-XX, or "none"), and why this scope exists: the surrounding system, the user-visible outcome, what changes nothing. (Shape per unit-schema.md §Required body sections.)>

## Claims

<brownfield only — one line per expectation about EXISTING code (unit-schema.md §Claims grammar): `- C-U-XXX-01 "<verbatim>" — expect: <path>[:<symbol>] | <path> — must-exist | <path> — must-not-exist`. Greenfield / create-only: delete this section.>

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
