---
description: Static analysis of vault units for quality + grounding. Per-unit quality breakdown (HIGH/MEDIUM/LOW grounding_confidence), anchor verification status, Hard Rule coverage, acceptance_test presence, module + squad assignment status, Migration notes structure (extend units), task_type validity vs binding state. Returns prioritized recommendations for unit improvements before bolt execution. Read-only; never modifies vault.
argument-hint: [vault-path] [--module=<id>] [--squad=<id>] [--strict] [--format=table|json]
---

Static lint of vault units. Read-only diagnostic; surfaces issues BEFORE bolts run so user can fix vault/binding/units instead of debugging failed bolts.

User arguments: $ARGUMENTS

## Procedure

### Step 1 — Resolve vault path

Probe both v3.4+ (`.mega-sdd/vaults/*/`) and legacy (`docs/mega-sdd/vaults/*/`) locations. Use positional arg if given. Halt if no vault found.

### Step 2 — Load context

For each lint check, load:
- `<vault>/vault.json` — manifest
- `<vault>/units/U-*.md` — all units with frontmatter + body
- `<vault>/binding.md` (if exists) — Implementation State Map + field_diff
- `<vault>/_meta/modules.yaml` (if exists) — module definitions
- `<vault>/_meta/squads.yaml` (if exists) — squad partition
- `<repo>/codebase-map.md` (probe both new + legacy paths) — for anchor verification
- `<vault>/.memory/bolt-outcomes.json` (if exists) — past bolt results for context

### Step 3 — Per-unit lint checks

For each unit, run these checks:

#### Frontmatter checks (HARD — failures = unit invalid)
- [ ] `id` present + matches U-XXX pattern + zero-padded
- [ ] `title` non-empty
- [ ] `vault_source` present + format valid (file#anchor or file:section)
- [ ] `task_type` is one of `create | extend | verify`
- [ ] `target_files` non-empty (UNLESS `task_type: verify` — then must be empty or operation:none)
- [ ] `acceptance_test` has ≥1 entry with `type: test`
- [ ] `depends_on` references resolve (no dangling unit IDs)
- [ ] `binding_refs` if present, references resolve to claims in binding.md

#### Iter 8+ defensive checks
- [ ] `grounding_confidence` present (HIGH | MEDIUM | LOW)
- [ ] `grounding_evidence.anchors_verified` reasonable for task_type
- [ ] `grounding_evidence.binding_state_summary` consistent with task_type
- [ ] If LOW confidence → flag for review

#### Iter 11+ module checks
- [ ] `module: <id>` present (M-XXX or M-default)
- [ ] Module ID resolves to entry in `_meta/modules.yaml` (or M-default fallback)
- [ ] If `M-unassigned` → flag for module assignment review

#### Iter 1.1 squad checks (only if `_meta/squads.yaml` declares ≥2 squads)
- [ ] `squad: <id>` present
- [ ] Squad ID resolves to entry in squads.yaml
- [ ] Cross-squad `depends_on` routed via `consumes_interfaces`

#### Body checks (SOFT — warnings)
- [ ] `## Goal` present and 1-2 sentences
- [ ] `## Context (read first)` present with vault_source citation
- [ ] `## Anchors` per task_type mandatory rules (Iter 3+8)
- [ ] `## Implementation steps` has ≥1 sentence >15 words (directive prose check; Iter 3)
- [ ] `## Migration notes` MANDATORY for extend, ABSENT for create/verify (Iter 1+8)
- [ ] `## Hard rules` parseable per grammar v1 OR v2 (Iter 3+6)
- [ ] `## Anti-patterns` populated (informational; not enforced)
- [ ] `## Acceptance criteria` non-empty
- [ ] `## Out of scope` populated

#### Anchor verification (Iter 8 Step 12.4.5)
- [ ] For each Anchor `<file>:<line>` — probe file exists in codebase-map OR fs
- [ ] If file missing AND task_type: verify or extend → WARNING (anchor likely aspirational; review)
- [ ] If file missing AND task_type: create → OK (greenfield anchors acceptable)
- [ ] If file exists AND line out of range → WARNING (anchor may have drifted)

#### Hard Rule validation
- [ ] If v1 grammar: parse each line against 5 closed types
- [ ] If v2 grammar: validate YAML via ast-grep parse-via-scan (Iter 9 Bug 7 fix)
- [ ] Mixed grammar in single unit → halt-equivalent warning
- [ ] `SIGNATURE_RULE function <name>` references symbol in codebase-map (else `hard_rule_unanchored` warning)

#### Binding consistency (when binding.md exists)
- [ ] `task_type` matches binding's Implementation State Map per state→task_type mapping (Iter 1 + Iter 8 v1.7+ PARTIAL_FIELDS_*)
- [ ] If binding state PARTIAL_FIELDS_MISSING/SURPLUS → unit's Migration notes match field_diff ADD/KEEP/REMOVE
- [ ] If binding state IMPLEMENTED → task_type=verify (not create)

### Step 4 — Compute summary metrics

```
Total units: N
By task_type: create=N1, extend=N2, verify=N3
By grounding_confidence: HIGH=H, MEDIUM=M, LOW=L
Anchors total / verified: T / V (V/T %)
Hard Rules: units with ≥1 rule = K / N
Module assignment: assigned / unassigned
Squad assignment (if multi-squad): per-squad count
Cross-module depends_on edges: count
Average target_files per unit: AVG
LOC estimate (sum of unit estimates): EST
```

### Step 5 — Render output

Default `--format=table`:

```
Vault: leave-management v3 | Units: 13 | Modules: 4 | Squads: 2

PER-UNIT:
ID      Module      Squad     task    Ground   Anchors  Hard      Issues
U-001   M-auth      squad-be  create  HIGH     -        2 rules   ✓
U-002   M-auth      squad-be  create  HIGH     -        1 rule    ✓
U-003   M-auth      squad-be  create  HIGH     -        0 rules   ⚠️ no Hard Rules
U-007   M-auth      squad-be  extend  HIGH     3/3 ✓    2 rules   ✓
U-008   M-auth      squad-be  create  MEDIUM   -        0 rules   ⚠️ no Hard Rules
U-010   M-leave     squad-be  create  HIGH     -        1 rule    ✓
U-013   M-leave     squad-be  create  LOW      0/2 ✗    0 rules   ⚠️ LOW grounding + missing anchors
U-FE-01 M-auth      squad-fe  create  HIGH     1/1 ✓    0 rules   ✓
...

SUMMARY:
  Quality: 11 HIGH | 1 MEDIUM | 1 LOW
  Anchors: 6/6 verified (100%)
  Hard Rules: 9/13 units have ≥1 rule (4 units bare)
  Module coverage: 13/13 assigned (no M-unassigned)
  Cross-module deps: 0 (clean)
  Frontmatter issues: 0

RECOMMENDATIONS (prioritized):
  ⚠️ U-013 LOW grounding + 0/2 anchors verified
     → Review binding state for this claim; consider re-running bind-codebase
     → If unavoidable LOW (greenfield deep dive), accept + monitor bolt outcome

  ⚠️ 4 units have no Hard Rules (U-003, U-008, U-FE-02, U-INT-01)
     → If touching shared/existing code, consider adding DO_NOT_MODIFY rules
     → Not mandatory; just risk-reduction

  ✓ All other units pass lint cleanly. Safe to proceed with /mega-sdd:execute-bolts.
```

For `--format=json`: structured JSON output for tooling integration.

### Step 6 — Filter flags

- `--module=<id>` — lint only units in module M-X
- `--squad=<id>` — lint only units in squad S-X
- `--strict` — promote SOFT warnings to halt-equivalent failures (CI mode)

### Step 7 — Hand-off

After display:
- If 0 LOW + 0 frontmatter issues → suggest `/mega-sdd:execute-bolts` or `/mega-sdd:list-modules` to start
- If LOW units exist → suggest review specific units before bolt; OR proceed with `--force` accepting risk
- If frontmatter issues → suggest `/mega-sdd:generate-units --refresh` to regenerate problematic units

## Anti-halu rails

- Lint is READ-ONLY — never modifies vault, units, binding, memory
- All checks based on DETERMINISTIC signals (file presence, frontmatter field presence, regex matches)
- Anchor verification via Bash file probe or codebase-map lookup (not LLM judgment)
- Hard Rule validation via ast-grep parse (when v2 installed) or grammar regex (v1)
- Recommendations cite specific units + specific check that failed (no vague suggestions)

## Halt conditions

- Vault not found → halt with helpful error
- Vault.json corrupt / missing → halt
- `--strict` flag + any SOFT warning → halt-equivalent exit (CI integration)

## References

- `plugins/mega-sdd/skills/generate-units/references/unit-schema.md` — unit frontmatter + body schema
- `plugins/mega-sdd/skills/generate-units/references/defensive-generation.md` — grounding_confidence + anchor verification
- `plugins/mega-sdd/skills/generate-units/references/modules-schema.md` — module assignment
- `plugins/mega-sdd/skills/bind-codebase/references/binding-contract.md` — binding state → task_type mapping
- `plugins/mega-sdd/skills/execute-bolts/references/hard-rule-grammar-v2.md` — Hard Rule grammar
