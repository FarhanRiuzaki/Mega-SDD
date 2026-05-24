# Unit Schema

A "unit" is an atomic, AI-executable dev prompt derived from a (bound-)vault. Each unit corresponds to one bolt — one PR-sized code commit. Units are the contract handed off to `execute-bolts` via superpowers.

## Required frontmatter

```yaml
---
id: U-001                         # zero-padded, monotonic
title: <short imperative phrase>
vault_source: <vault-file:section>  # which vault section this unit derives from
task_type: create                  # (v1.2+) create | extend | verify
                                   # create: new code, target_files all `create`
                                   # extend: modify existing; Migration notes mandatory
                                   #   Iter 1 (v1.2): reserved (no auto-emit; manual only)
                                   #   Iter 8 (v2.1+): AUTO-emitted for PARTIAL_FIELDS_* binding states with Migration notes populated from binding's field_diff
                                   # verify: NO code generation; only acceptance_test against existing implementation
                                   # Default: create. Auto-assigned from binding.md Implementation State Map when present.
grounding_confidence: HIGH | MEDIUM | LOW   # (v2.1+, Iter 8) — reflects defensive generation checks
                                   # HIGH = binding present + all anchors verified + no target collisions + binding state all HIGH-conf
                                   # MEDIUM = binding present BUT some anchors aspirational OR some UNKNOWN state OR codebase-map precision: regex
                                   # LOW = no binding (standalone generate-units) OR no codebase-map OR significant unverified anchors
                                   # Required when v2.1+ generated; omitted in pre-v2.1 units.
grounding_evidence:                # (v2.1+, Iter 8) — descriptive metadata; not enforced downstream
  upstream_artifacts: []           # what was consulted: [codebase-map.md, binding.md]
  anchors_verified: <N>/<M>        # how many of M anchors resolved (file exists + line valid)
  target_files_collision_check: passed | warning | resolved-via-prompt
  binding_state_summary: {}        # { IMPLEMENTED: N, PARTIAL_FIELDS_MISSING: N, ... }
mutability:                        # (v2.5.1+, Iter 25 — propagates Iter 22 mutability tier from binding/KB)
  tier: LOCKED | INTENT | ARTIFACT # tier of the vault claims this unit implements
  source: kb_locked | kb_intent | kb_artifact | vault_locked | inferred
  rationale: <string>              # 1-line reason (e.g., "BI Reg 23/2/2021 §4 — field name + type + validation MUST preserve")
  rebuild_freedom:                 # what rebuild may change
    field_names: yes | no          # for LOCKED + integration-contract → no
    field_types: yes | no          # for LOCKED → no
    storage_shape: yes | no        # for LOCKED + audit-required → no
    flow_implementation: yes | no  # for INTENT → yes; LOCKED + algorithm-specified → no
  # Pre-v2.5.1 units OR units without KB-derived claims → field omitted; downstream treats as INTENT (safe default).
squad: <squad-id>                  # OPTIONAL — required when ≥2 squads declared in _meta/squads.yaml
                                   # Format: squad-<kebab-case>. Omit or set to `default` for single-squad projects.
scope: <scope-id>                  # (v2.5.4+, Iter 29 — P1-3) OPTIONAL — written when source vault.json has `scope` field
                                   # e.g., "BE", "MW", "FE". Matches vault.json `scope_metadata.id`.
                                   # Omitted entirely for legacy single-scope vaults.
scope_name: "<scope-name>"         # (v2.5.4+, Iter 29 — P1-3) OPTIONAL — written alongside `scope:`
                                   # e.g., "Backend API". Matches vault.json `scope_metadata.name`.
                                   # Omitted entirely for legacy single-scope vaults.
module: <module-id>                # (v2.2+, Iter 11) — semantic grouping per _meta/modules.yaml
                                   # Format: M-<kebab-case>. Auto-derived from vault_source matching modules.yaml.
                                   # M-default for vaults without modules.yaml. M-unassigned for unit's vault_source not matching any module.
depends_on: []                     # list of unit IDs that must complete first
                                   # MUST be same-squad units only when multi-squad mode active.
                                   # Cross-squad coupling MUST route through `consumes_interfaces` (see below).
target_files:                      # exact files this unit MAY touch (whitelist)
                                   # For task_type=verify: may be empty OR all entries `operation: none`
  - path: src/api/auth.ts
    operation: modify              # create | modify | delete | none (none for verify-type)
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

## Required body sections (v1.3+, Iter 3 — polished AI-coding-prompt shape)

```markdown
## Goal
<1-2 sentences — what this unit produces>

## Context (read first)
<which vault sections, which binding entries, KB sections (if KB present), and WHY this scope exists. Conversational directive prose, NOT bullets. Aim for 2-4 sentences that orient an AI coding agent: what's the surrounding system, what's the user-visible outcome, what changes nothing.>

## Anchors  (v1.2+ schema; v1.3+ mandatory for ALL task_types when binding evidence exists)
<file:line where existing code lives that this unit references or modifies. AI coding agent reads these BEFORE writing.>
<For task_type=verify and task_type=extend: MANDATORY — cite the implementation anchor from binding.>
<For task_type=create: MANDATORY when at least one binding entry exists pointing to a related pattern in codebase-map. Cite the closest pattern to follow. Optional when fully greenfield.>

- src/Http/Controllers/UserController.php:45-67 — existing pattern; follow this shape
- src/Models/User.php:12 — entity to extend
- docs/knowledge-base/10-domains/10-cif-customer.md §5 (if KB present) — domain behavior to honor

## Hard rules  (v1.3+, Iter 3 — validated at bolt time by execute-bolts pre/post-flight)
<Machine-parseable constraints. Grammar closed in v1 per DESIGN-OQ-4 (5 rule types). One rule per line. Empty section allowed (no rules to enforce).>

- DO NOT modify <path>
- DO NOT add new <manifest-file> dependencies
- file:<path-glob> MUST follow <case-style> naming
- function <name> MUST preserve signature: <type-signature>
- file <path> MUST exist after bolt

## Anti-patterns  (v1.3+ — guidance, NOT validated)
<Conversational don'ts drawn from binding CONFLICTS + KB gotchas + tech-OQ recommendations + experience. AI agent reads these as context; not machine-enforced.>

- Don't bypass middleware `auth.role` — RBAC pattern in routes/web.php:34
- Don't replicate the typo `cfkdhl → CFKDDL` from legacy at <legacy-anchor>
- Don't add a new HTTP error envelope; existing pattern at ErrorResource.php:12 is canonical

## Implementation steps  (v1.3+ — directive prose, not bullet schema)
<Written like a senior teammate briefing another teammate. AT LEAST one sentence >15 words. Reference Anchors inline. Avoid pure bullet checklists.>
<For task_type=verify: ONE line — "No code changes. Run acceptance tests against existing implementation at <anchor>.">
<For task_type=create: directive prose explaining the build sequence with anchor references.>
<For task_type=extend: directive prose with explicit "first read Anchor A to see existing shape; then add X following that shape" framing.>

First, open `app/Http/Controllers/UserController.php` and look at the `index` method at line 45 to see how the existing read endpoints structure their response. Then add a `store` method that mirrors this shape but accepts validated input from `StoreUserRequest`. The trickier part is the role assignment — see the Anchor at `routes/api.php:34` for how roles are attached after the existing flow.

## Migration notes  (v1.2+; mandatory for task_type=extend; omitted otherwise)
<Three sub-lists when this section is present:>
- **REMOVE**: <code to delete>
- **KEEP**: <code to preserve, do not touch>
- **ADD**: <new code to write>

## Acceptance criteria
<expanded form of frontmatter acceptance_test — exactly what passing means>
<For task_type=verify: ALL acceptance criteria must assert behavior of existing implementation — not new behavior.>

## Out of scope (for this unit)
<explicit list — prevents scope creep into adjacent units>
```

## Hard rule grammar (v1.3+, Iter 3 — closed v1 per DESIGN-OQ-4)

Five rule types supported. Unsupported grammar → halt at bolt time with `hard_rule_unparseable`.

```ebnf
RULE := DO_NOT_MODIFY | DO_NOT_ADD_DEPS | NAMING_RULE | SIGNATURE_RULE | FILE_PRESENCE_RULE

DO_NOT_MODIFY        := "DO NOT modify " <path>
DO_NOT_ADD_DEPS      := "DO NOT add new " <manifest> " dependencies"
NAMING_RULE          := <path-glob> " MUST follow " <case-style> " naming"
SIGNATURE_RULE       := "function " <name> " MUST preserve signature: " <type-sig>
FILE_PRESENCE_RULE   := "file " <path> " MUST exist after bolt"

where:
  <path>          = relative or absolute file path
  <path-glob>     = glob pattern (file:src/api/*.ts)
  <manifest>      = package.json | composer.json | Cargo.toml | go.mod | etc.
  <case-style>    = kebab-case | camelCase | snake_case | PascalCase
  <name>          = identifier (function name)
  <type-sig>      = parenthesized parameter list with types + return type
```

### Examples

```
DO NOT modify src/Models/User.php
DO NOT add new package.json dependencies
file:src/api/*.ts MUST follow kebab-case naming
function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>
file src/Models/AuditLog.php MUST exist after bolt
```

### Validation by execute-bolts

| Rule type | Pre-flight check | Post-flight check |
|---|---|---|
| `DO_NOT_MODIFY` | Snapshot file checksum | Compare checksum; differs → violated |
| `DO_NOT_ADD_DEPS` | Snapshot manifest content | Diff manifest; new top-level entry under deps/dependencies/etc. → violated |
| `NAMING_RULE` | (none — new-file only) | Apply case-style regex against all new files matching glob; mismatch → violated |
| `SIGNATURE_RULE` | Snapshot function signature via codebase-map symbol lookup | Re-extract signature; differs → violated |
| `FILE_PRESENCE_RULE` | (none) | Probe path exists in repo; missing → violated |

Unparseable rules halt with `hard_rule_unparseable` blocker. NEVER silently skip.

### Per-task_type contracts (v1.2+)

| task_type | target_files | Anchors | Migration notes | acceptance_test | Implementation steps body |
|---|---|---|---|---|---|
| `create` | All `operation: create` | Optional (cite related patterns) | Omitted | Tests for new functionality | Numbered build steps |
| `extend` | At least one `operation: modify`; new files allowed `operation: create` | MANDATORY | MANDATORY (REMOVE/KEEP/ADD) | Tests for new behavior; existing-behavior assertions in `existing_interfaces` | Numbered modification steps |
| `verify` | Empty OR all `operation: none` | MANDATORY (cite the existing implementation) | Omitted | All assertions against existing implementation | ONE line: "No code changes. Run acceptance tests against existing implementation at <anchor>." |

> **Iter 1 scope** (v1.2): `generate-units` auto-emits `create` and `verify` types based on the binding's Implementation State Map. `extend` type is in the schema (forward-compat for Iter 2/3) but does NOT auto-emit.
>
> **Iter 8 scope** (v2.1+): `extend` type AUTO-EMITTED when bind-codebase v1.7+ detects `PARTIAL_FIELDS_MISSING` or `PARTIAL_FIELDS_SURPLUS` or `PARTIAL_FIELDS_BOTH` states. Migration notes populated from binding's `field_diff` column (ADD/KEEP/REMOVE lists). User can override via interactive prompt for PARTIAL_FIELDS_SURPLUS (which signals ambiguity between feature drift / vault gap / legacy / rename).

## Atomicity rules

- One unit = one PR-sized commit. If the body steps would produce >300 lines of code change, SPLIT into U-001, U-001.1, U-001.2.
- `target_files` whitelist is enforced by `execute-bolts` — bolt may not touch files outside this list.
- `existing_interfaces` is enforced by acceptance tests — any test against a listed interface must continue passing.
- (v1.2+) `task_type` is enforced by `execute-bolts` — `verify` units MUST NOT modify any file; violations are halt-conditions at bolt time.
- (v1.3+, Iter 3) `## Hard rules` body section is parsed at bolt time. Pre-flight snapshots state; post-flight (before commit) validates. Violations halt with `hard_rule_violated`.
- (v1.3+, Iter 3) `## Implementation steps` MUST contain at least one sentence >15 words (directive prose check). Pure bullet checklists trigger render-pass warning.

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

### Scope fields (v2.5.4+, Iter 29)

Optional fields written ONLY when source vault.json has `scope` field (multi-scope vault per Iter 28):

- `scope: <id>` — e.g., `BE`, `MW`, `FE`. Matches vault.json `scope_metadata.id`.
- `scope_name: "<name>"` — e.g., `"Backend API"`. Matches vault.json `scope_metadata.name`.

Omitted entirely for legacy single-scope vaults (no `scope` field in source vault.json).

## Anti-hallucination rails

- Unit MAY ONLY reference vault sections + binding entries (cited explicitly).
- Unit MAY ONLY touch files listed in `target_files`.
- Unit MUST have at least one acceptance_test entry of type `test`. No exceptions.
- If unit body cannot meet a contract, halt — do not generate a partial unit.
- (v1.1+) In multi-squad mode, `depends_on` MUST be intra-squad only. Cross-squad direct deps halt with `cross_squad_dep_invalid`.
- (v1.1+) `consumes_interfaces` entries MUST resolve to existing interface files; status field is read at bolt time to gate execution.
- (v2.5.4+, Iter 29) `scope:` / `scope_name:` MUST be sourced verbatim from vault.json `scope_metadata`. NEVER inferred or invented. Omit both fields when vault has no `scope` field.
