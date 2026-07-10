# Unit Schema

A "unit" is an atomic, AI-executable dev prompt derived from a (bound-)vault. Each unit corresponds to one bolt — one PR-sized code commit. Units are the contract handed off to `execute-bolts` via superpowers.

## Contents
- Required frontmatter
- Required body sections (polished AI-coding-prompt shape)
- Hard rule grammar (closed 5-type set; EBNF + validation table)
- Per-task_type contracts
- Atomicity rules
- Multi-squad rules
- Interface reference resolution
- Dependency graph
- ID stability
- Greenfield vs brownfield (+ scope fields)
- Anti-hallucination rails

(Note: the headings inside "Required body sections" — Goal, Context, Anchors, Hard rules, Anti-patterns, Implementation steps, Migration notes, Acceptance criteria, Out of scope — are the unit body's own section template, not sections of this reference.)

## Required frontmatter

```yaml
---
id: U-001                         # zero-padded, monotonic
title: <short imperative phrase>
vault_source: <vault-file:section>  # which vault section this unit derives from
task_type: create                  # create | extend | verify
                                   # create: new code, target_files all `create`
                                   # extend: modify existing; Migration notes mandatory
                                   #   AUTO-emitted for PARTIAL_FIELDS_* binding states with Migration notes populated from binding's field_diff
                                   # verify: NO code generation; only acceptance_test against existing implementation
                                   # Default: create. Auto-assigned from binding.md Implementation State Map when present.
status: implemented                # OPTIONAL (living-vault lifecycle; absence = legacy/not-yet-executed)
                                   # implemented: bolt committed AND all bolt-report target_hashes still match the working tree
                                   # stale: bolt committed BUT a target file changed since (per scripts/compute-unit-staleness.sh)
                                   #   - eligible for re-execution in the sync lane
                                   # superseded: the claim this unit derives from vanished from the (re-)bound vault
                                   #   - assigned ONLY by generate-units --reconcile; unit kept (audit trail), never deleted;
                                   #     execute-bolts SKIPS superseded units with a warning
grounding_confidence: HIGH | MEDIUM | LOW
risk: low | medium | high | critical   # OPTIONAL — written by generate-units Step 2.5 from the risk signals in references/adversarial-test-prompt.md (auth/payment/PII/regulatory-touching targets, LOCKED-claim refs); consumed by Step 9.5 (risk: high|critical auto-escalates to a separate adversarial-review subagent; critical bumps the review model). Absent = low.   # — reflects defensive generation checks
                                   # HIGH = binding present + all anchors verified + no target collisions + binding state all HIGH-conf
                                   #   AND (verify units only, A1) every acceptance criterion grounded in a NON-TEST source
                                   #   anchor `[grounded: path:line]` — see ## Acceptance criteria. A verify unit certifies
                                   #   EXISTING behavior; a criterion present only in a test stub / the PRD is NOT grounding.
                                   #   Any ungrounded criterion → NOT HIGH (downgrade, or split verify[built]+create[unbuilt]).
                                   #   Enforced: validate-unit-spec.sh halt verify_grounding_untrusted (HIGH verify units only).
                                   # MEDIUM = binding present BUT some anchors aspirational OR some UNKNOWN state OR codebase-map precision: regex
                                   # LOW = no binding (standalone generate-units) OR no codebase-map OR significant unverified anchors
                                   # Required on newly generated units; may be absent on legacy units.
grounding_evidence:                # — descriptive metadata; not enforced downstream
  upstream_artifacts: []           # what was consulted: [codebase-map.md, binding.md]
  anchors_verified: <N>/<M>        # how many of M anchors resolved (file exists + line valid)
  target_files_collision_check: passed | warning | resolved-via-prompt
  binding_state_summary: {}        # { IMPLEMENTED: N, PARTIAL_FIELDS_MISSING: N, ... }
mutability:                        # propagates the mutability tier from binding/KB
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
scope: <scope-id>                  # OPTIONAL — written when source vault.json has `scope` field
                                   # e.g., "BE", "MW", "FE". Matches vault.json `scope_metadata.id`.
                                   # Omitted entirely for legacy single-scope vaults.
scope_name: "<scope-name>"         # OPTIONAL — written alongside `scope:`
                                   # e.g., "Backend API". Matches vault.json `scope_metadata.name`.
                                   # Omitted entirely for legacy single-scope vaults.
reuse_candidates:                  # OPTIONAL — fast-path hints from reuse-index.yaml (NOT exhaustive; the bolt reads the full index)
  - { name: <symbol>, path: <file>, signature: <sig>, purpose: <1-line> }
                                   # Absent when no candidate matched; never fabricated.
                                   # These are hints — the bolt receives the full reuse-index.yaml path and scans it at write time.
module: <module-id>                # — semantic grouping per _meta/modules.yaml
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
  - type: test                     # test | manual | lint | typecheck | render
    command: "npm test -- auth"
    expects: "passes"
    ears: "WHEN a login request carries an expired token THE SYSTEM SHALL respond 401 with problem+json"
                                   # OPTIONAL (additive, backward-compatible) — an EARS-shaped statement
                                   # ("WHEN <trigger> THE SYSTEM SHALL <response>" / "WHILE <state> ..." /
                                   # "IF <condition> THEN THE SYSTEM SHALL ...") making the criterion
                                   # machine-checkable. When present, the bolt's TDD test MUST assert
                                   # exactly this statement (and PBT properties MAY be derived from it).
                                   # Absent → prose `expects:` remains the criterion (no behavior change);
                                   # validators tolerate absence everywhere.
  - type: manual
    desc: "Hit /login with valid creds, expect 200 + token"
  - type: render                   # REQUIRED for any unit whose target_files include a
                                   # detail/show view (code-delivery slice D). Asserts the
                                   # detail route renders a real field — catches empty-model
                                   # show / branch `—` / null-timestamp crashes a route-200
                                   # smoke test misses. Derived from the active framework
                                   # pack `## Test patterns` -> detail_view_render template.
    command: "php artisan test --filter WidgetShowRendersTest"
    expects: "GET detail route 200 + asserts a real display field renders"
superpowers_skills:                # which superpowers skills execute-bolts invokes
  - test-driven-development
  - subagent-driven-development
binding_refs:                      # binding manifest IDs this unit honors
  - C-001
  - OQ-012
estimated_complexity: small        # small | medium | large
---
```

## Required body sections (polished AI-coding-prompt shape)

```markdown
## Goal
<1-2 sentences — what this unit produces>

## Context (read first)
<which vault sections, which binding entries, KB sections (if KB present), and WHY this scope exists. Conversational directive prose, NOT bullets. Aim for 2-4 sentences that orient an AI coding agent: what's the surrounding system, what's the user-visible outcome, what changes nothing.>

## Anchors  (mandatory for ALL task_types when binding evidence exists)
<file:line where existing code lives that this unit references or modifies. AI coding agent reads these BEFORE writing.>
<For task_type=verify and task_type=extend: MANDATORY — cite the implementation anchor from binding.>
<For task_type=create: MANDATORY when at least one binding entry exists pointing to a related pattern in codebase-map. Cite the closest pattern to follow. Optional when fully greenfield.>

- src/Http/Controllers/UserController.php:45-67 — existing pattern; follow this shape
- src/Models/User.php:12 — entity to extend
- docs/knowledge-base/10-domains/10-cif-customer.md §5 (if KB present) — domain behavior to honor

## Hard rules  (validated at bolt time by execute-bolts pre/post-flight)
<Machine-parseable constraints. Grammar closed in v1 per DESIGN-OQ-4 (5 rule types). One rule per line. Empty section allowed (no rules to enforce).>

- DO NOT modify <path>
- DO NOT add new <manifest-file> dependencies
- file:<path-glob> MUST follow <case-style> naming
- function <name> MUST preserve signature: <type-signature>
- file <path> MUST exist after bolt

## Anti-patterns  (guidance, NOT validated)
<Conversational don'ts drawn from binding CONFLICTS + KB gotchas + tech-OQ recommendations + experience. AI agent reads these as context; not machine-enforced.>

- Don't bypass middleware `auth.role` — RBAC pattern in routes/web.php:34
- Don't replicate the typo `cfkdhl → CFKDDL` from legacy at <legacy-anchor>
- Don't add a new HTTP error envelope; existing pattern at ErrorResource.php:12 is canonical

## Implementation steps  (directive prose, not bullet schema)
<Written like a senior teammate briefing another teammate. AT LEAST one sentence >15 words. Reference Anchors inline. Avoid pure bullet checklists.>
<For task_type=verify: ONE line — "No code changes. Run acceptance tests against existing implementation at <anchor>.">
<For task_type=create: directive prose explaining the build sequence with anchor references.>
<For task_type=extend: directive prose with explicit "first read Anchor A to see existing shape; then add X following that shape" framing.>

First, open `app/Http/Controllers/UserController.php` and look at the `index` method at line 45 to see how the existing read endpoints structure their response. Then add a `store` method that mirrors this shape but accepts validated input from `StoreUserRequest`. The trickier part is the role assignment — see the Anchor at `routes/api.php:34` for how roles are attached after the existing flow.

## Migration notes  (mandatory for task_type=extend; omitted otherwise)
<Three sub-lists when this section is present:>
- **REMOVE**: <code to delete>
- **KEEP**: <code to preserve, do not touch>
- **ADD**: <new code to write>

## Acceptance criteria
<expanded form of frontmatter acceptance_test — exactly what passing means>
<For task_type=verify: ALL acceptance criteria must assert behavior of existing implementation — not new behavior.>
<For task_type=verify with grounding_confidence: HIGH (A1 — per-AC source grounding): prefix EACH criterion
 with a grounding marker that proves the asserted behavior already exists in NON-TEST source:
   - [grounded: src/Services/Purchase.php:142] the 4th daily purchase is rejected
   - [grounded: app/config/limits.php:8] minimum purchase is enforced at Rp 10.000
 A criterion you cannot ground — its behavior lives only in a test stub, the PRD, or nowhere yet — is marked
   - [ungrounded] source-of-fund validation
 and means the unit is NOT verify+HIGH: downgrade grounding_confidence, OR split a verify[built] unit (the
 grounded criteria) from a create[unbuilt] unit (the ungrounded ones). A test-file path is NOT grounding
 (tests can assert behavior that does not exist). Once ANY criterion carries a marker the unit opts in and
 EVERY criterion must be `[grounded: <non-test path>:<line>]`; legacy units with no markers are tolerated.
 Enforced by validate-unit-spec.sh → verify_grounding_untrusted (blocks the next execute-bolts).>

## Out of scope (for this unit)
<explicit list — prevents scope creep into adjacent units>
```

## Hard rule grammar (closed v1)

Five mechanical rule types + a directive tier (generic `MUST/MUST NOT/DO NOT/NEVER/ALWAYS` prose — accepted but not machine-checkable; recorded `attested` with `--attest-directives` else `directive_unverified` at post-flight). Modal-synonym carve-out: `MUST NOT modify <path>` / `NEVER add new <manifest> dependencies` with a PATH-SHAPED object (contains `.` or `/`) classify as the mechanical productions, never directive — they cannot be attested past; a prose object (`MUST NOT modify existing API contracts`) stays a directive. A line matching neither a mechanical type nor the directive tier → halt at bolt time with `hard_rule_unparseable`.

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

A line matching neither a mechanical type nor the directive tier is unparseable → halt with `hard_rule_unparseable` blocker. NEVER silently skip.

### Per-task_type contracts

| task_type | target_files | Anchors | Migration notes | acceptance_test | Implementation steps body |
|---|---|---|---|---|---|
| `create` | All `operation: create` | Optional (cite related patterns) | Omitted | Tests for new functionality | Numbered build steps |
| `extend` | At least one `operation: modify`; new files allowed `operation: create` | MANDATORY | MANDATORY (REMOVE/KEEP/ADD) | Tests for new behavior; existing-behavior assertions in `existing_interfaces` | Numbered modification steps |
| `verify` | Empty OR all `operation: none` | MANDATORY (cite the existing implementation) | Omitted | All assertions against existing implementation | ONE line: "No code changes. Run acceptance tests against existing implementation at <anchor>." |

> `generate-units` auto-emits `create` and `verify` types based on the binding's Implementation State Map.
>
> `extend` type is AUTO-EMITTED when bind-codebase detects `PARTIAL_FIELDS_MISSING` / `PARTIAL_FIELDS_SURPLUS` / `PARTIAL_FIELDS_BOTH` states. Migration notes populated from binding's `field_diff` column (ADD/KEEP/REMOVE lists). User can override via interactive prompt for PARTIAL_FIELDS_SURPLUS (which signals ambiguity between feature drift / vault gap / legacy / rename).

## Atomicity rules

- One unit = one PR-sized commit. If the body steps would produce >300 lines of code change, SPLIT into multiple sequential units (allocated U-00N at Step 6 topological numbering) with an explicit `depends_on` chain — never dotted sub-IDs (U-001.1 would break the content-hash ID-stability contract `--refresh`/`--reconcile` depend on). The >300 LOC / ≤5 files threshold is an authoring judgment (advisory — no validator measures it).
- `target_files` whitelist is enforced by `execute-bolts` at three layers: the dispatch prompt forbids out-of-whitelist writes (rules tier), the review panel checks scope (judgment tier), and the deterministic B3 whitelist observer (`validate-bolt-artifacts.sh --whitelist-scan`, Stop-hook + gate-time) diffs each bolted unit's COMMITTED paths against `target_files` ∪ sanctioned extras (vault/bolt artifacts, `.mega-sdd/`, test files) — escaped paths block the next `execute-bolts` with `whitelist_violation`.
- `existing_interfaces` is enforced by acceptance tests — any test against a listed interface must continue passing.
- `task_type` is enforced by `execute-bolts` — `verify` units MUST NOT modify any file; violations are halt-conditions at bolt time.
- `## Hard rules` body section is parsed at bolt time. Pre-flight snapshots state; post-flight validates against the implementer's landed commit (detect-after topology per execute-bolts SKILL.md). Violations halt with `hard_rule_violated` and gate further bolts until fixed.
- `## Implementation steps` MUST contain at least one sentence >15 words (directive prose check). Pure bullet checklists trigger render-pass warning.

## Multi-squad rules

Applies only when `_meta/squads.yaml` exists with ≥2 squads. Single-squad / no-squad-config vaults skip these rules.

- `squad:` field is REQUIRED on every unit. `generate-units` assigns based on the routing rules in `generate-intent/references/squad-partition.md` (cross-skill ref — the layer-hint table, hybrid feature>layer priority, and squads.yaml validation live there).
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
- `diff-vault` preserves IDs by content hash
- `generate-units` with `--refresh` flag re-numbers; default does not

## Greenfield vs brownfield

- **Greenfield:** units derived directly from vault (no binding). `binding_refs` is empty.
- **Brownfield:** units derived from bound-vault. `binding_refs` populated; OQs propagate to unit acceptance criteria as "TBD: <question>" items.

### Scope fields

Optional fields written ONLY when source vault.json has `scope` field (multi-scope vault):

- `scope: <id>` — e.g., `BE`, `MW`, `FE`. Matches vault.json `scope_metadata.id`.
- `scope_name: "<name>"` — e.g., `"Backend API"`. Matches vault.json `scope_metadata.name`.

Omitted entirely for legacy single-scope vaults (no `scope` field in source vault.json).

## Anti-hallucination rails

- Unit MAY ONLY reference vault sections + binding entries (cited explicitly).
- Unit MAY ONLY touch files listed in `target_files`.
- Unit MUST have at least one acceptance_test entry of type `test`. No exceptions.
- (slice D) Any unit whose `target_files` include a detail/show view (matching the active framework pack `## Test patterns` -> `detail_view_glob`) MUST ALSO carry at least one acceptance_test entry of type `render`. Absent → `validate-unit-spec.sh` emits `render_test_missing` and BLOCKS `execute-bolts`. The render test is derived from the pack `detail_view_render` template; a prose `## Tests` / `## Acceptance` bullet does NOT satisfy this — it must be a structured `acceptance_test:` entry with `type: render` (or `kind: render`). Packs that omit `## Test patterns` → check SKIPs (the stack never declared a detail-view convention).
- If unit body cannot meet a contract, halt — do not generate a partial unit.
- In multi-squad mode, `depends_on` MUST be intra-squad only. Cross-squad direct deps halt with `cross_squad_dep_invalid`.
- `consumes_interfaces` entries MUST resolve to existing interface files; status field is read at bolt time to gate execution.
- `scope:` / `scope_name:` MUST be sourced verbatim from vault.json `scope_metadata`. NEVER inferred or invented. Omit both fields when vault has no `scope` field.
