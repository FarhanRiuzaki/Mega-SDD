# Unit Schema

A "unit" is an atomic, AI-executable dev prompt derived from a (bound-)vault. Each unit corresponds to one bolt — one PR-sized code commit. Units are the contract handed off to `execute-bolts` via superpowers.

## Required frontmatter

```yaml
---
id: U-001                         # zero-padded, monotonic
title: <short imperative phrase>
vault_source: <vault-file:section>  # which vault section this unit derives from
squad: <squad-id>                  # OPTIONAL — required when ≥2 squads declared in _meta/squads.yaml
                                   # Format: squad-<kebab-case>. Omit or set to `default` for single-squad projects.
depends_on: []                     # list of unit IDs that must complete first
                                   # MUST be same-squad units only when multi-squad mode active.
                                   # Cross-squad coupling MUST route through `consumes_interfaces` (see below).
target_files:                      # exact files this unit MAY touch (whitelist)
  - path: src/api/auth.ts
    operation: modify              # create | modify | delete
  - path: tests/auth.test.ts
    operation: create
existing_interfaces:               # contracts that MUST be preserved (in-codebase interfaces)
  - file: src/types/user.ts
    symbol: User
    note: "do not change shape; add optional field if needed"
produces_interfaces: []            # OPTIONAL — list of vault interface IDs this unit produces
                                   # Refs the kebab-id from interfaces/<id>.md frontmatter.
                                   # Only meaningful in multi-squad mode.
consumes_interfaces: []            # OPTIONAL — list of vault interface IDs this unit depends on
                                   # `execute-bolts` halts (cross_squad_interface_draft) if any referenced
                                   # interface has status: draft.
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

## Multi-squad rules (v1.1+)

Applies only when `_meta/squads.yaml` exists with ≥2 squads. Single-squad / no-squad-config vaults skip these rules.

- `squad:` field is REQUIRED on every unit. `generate-units` assigns based on `squad-partition.md` routing rules.
- `depends_on` MUST reference units with the SAME `squad:`. Cross-squad direct deps are rejected with `cross_squad_dep_invalid` halt.
- Cross-squad coupling MUST go through interface notes:
  - Producer side: declare `produces_interfaces: [<id>, ...]` listing every interface this unit creates/implements.
  - Consumer side: declare `consumes_interfaces: [<id>, ...]` listing every interface this unit reads/calls.
- Every entry in `produces_interfaces` and `consumes_interfaces` MUST exist as an `interfaces/<id>.md` file in the vault. Dangling references fail validation.
- A unit that `consumes_interfaces` a `status: draft` interface CAN be generated but CANNOT be executed: `execute-bolts` halts with `cross_squad_interface_draft` until the producer squad locks the interface.

## Interface reference resolution

When `generate-units` emits a unit with `consumes_interfaces: [api-leave-request-submit]`:
1. Verify `<vault>/interfaces/api-leave-request-submit.md` exists.
2. Read its frontmatter: `producer`, `status`.
3. Confirm `producer` squad ≠ the unit's `squad` (it's a CROSS-squad interface, not intra-squad).
4. Record the interface's status — `execute-bolts` reads this at execution time to decide halt vs run.

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
- (v1.1+) In multi-squad mode, `depends_on` MUST be intra-squad only. Cross-squad direct deps halt with `cross_squad_dep_invalid`.
- (v1.1+) `consumes_interfaces` entries MUST resolve to existing interface files; status field is read at bolt time to gate execution.
