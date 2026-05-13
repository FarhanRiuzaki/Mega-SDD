# Unit Schema

A "unit" is an atomic, AI-executable dev prompt derived from a (bound-)vault. Each unit corresponds to one bolt — one PR-sized code commit. Units are the contract handed off to `execute-bolts` via superpowers.

## Required frontmatter

```yaml
---
id: U-001                         # zero-padded, monotonic
title: <short imperative phrase>
vault_source: <vault-file:section>  # which vault section this unit derives from
depends_on: []                     # list of unit IDs that must complete first
target_files:                      # exact files this unit MAY touch (whitelist)
  - path: src/api/auth.ts
    operation: modify              # create | modify | delete
  - path: tests/auth.test.ts
    operation: create
existing_interfaces:               # contracts that MUST be preserved
  - file: src/types/user.ts
    symbol: User
    note: "do not change shape; add optional field if needed"
acceptance_test:                   # how to verify the bolt succeeded
  - type: test                     # test | manual | lint | typecheck
    command: "npm test -- auth"
    expects: "passes"
  - type: manual
    desc: "Hit /login with valid creds, expect 200 + token"
superpowers_skills:                # which superpowers skills execute-bolts invokes
  - test-driven-development
  - subagent-driven-development
binding_refs:                      # binding manifest IDs this unit honors
  - C-001
  - OQ-012
estimated_complexity: small        # small | medium | large
---
```

## Required body sections

```markdown
## Goal
<1-2 sentences — what this unit produces>

## Context
<which vault sections, which binding entries, why this scope>

## Implementation steps
<numbered list — bite-sized, like a writing-plans plan but for ONE unit>

1. Step 1...
2. Step 2...

## Acceptance criteria
<expanded form of frontmatter acceptance_test — exactly what passing means>

## Out of scope (for this unit)
<explicit list — prevents scope creep into adjacent units>
```

## Atomicity rules

- One unit = one PR-sized commit. If the body steps would produce >300 lines of code change, SPLIT into U-001, U-001.1, U-001.2.
- `target_files` whitelist is enforced by `execute-bolts` — bolt may not touch files outside this list.
- `existing_interfaces` is enforced by acceptance tests — any test against a listed interface must continue passing.

## Dependency graph

`depends_on` builds a DAG. `generate-units` rejects cycles. `execute-bolts` topologically sorts the graph; independent units may run in parallel under `subagent-driven-development`.

## ID stability

Unit IDs are stable across regenerations:
- `vault-diff` preserves IDs by content hash
- `generate-units` with `--refresh` flag re-numbers; default does not

## Greenfield vs brownfield

- **Greenfield:** units derived directly from vault (no binding). `binding_refs` is empty.
- **Brownfield:** units derived from bound-vault. `binding_refs` populated; OQs propagate to unit acceptance criteria as "TBD: <question>" items.

## Anti-hallucination rails

- Unit MAY ONLY reference vault sections + binding entries (cited explicitly).
- Unit MAY ONLY touch files listed in `target_files`.
- Unit MUST have at least one acceptance_test entry of type `test`. No exceptions.
- If unit body cannot meet a contract, halt — do not generate a partial unit.
