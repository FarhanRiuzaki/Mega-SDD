# Defensive Generation

`generate-units` is defensively grounded — auto-detects missing upstream signals, cross-checks per unit before writing, and surfaces a `grounding_confidence` label so users instantly see how well-anchored each unit is.

Mitigates "ngawang" (floating/disconnected) units. User UX request:

> "ketika generate units. dan ketika generate itu ada di source code base, bisa auto detecs, atau kasih pertanyaan terlebih dahulu... nanti hasil yg di generate sudah cross check dlu/scan codebase dlu. jadi hasil nya lebih robust tidak ngawang"

## Contents
- Design principle
- Step 0.5 — Pre-flight upstream check
- Step 7.6 — Per-unit target_files cross-check
- Step 12.3 — Per-anchor verification
- Grounding confidence labels
- Halt vs warning matrix
- Anti-halu rails preserved
- Backward compatibility
- Examples
- Field-level diff detection (the "ngawang" mitigation)
- Six-state Implementation State Map + field_diff mechanics
- References

## Design principle

**Auto-detect first, ask only when genuinely ambiguous.** Avoid death-by-prompts.

- Missing upstream artifacts → auto-detect + offer to run (1 prompt, not per-unit)
- Per-unit collision (file exists vs task_type) → INTERACTIVE prompt only when ambiguous
- Anchor unresolved → WARNING in unit body (not halt; anchors can be aspirational)
- Confidence label HIGH/MEDIUM/LOW visible in unit frontmatter + chat output

## Step 0.5 — Pre-flight upstream check (NEW)

Before vault parsing (Step 1), detect missing upstream signals:

```
1. Probe for codebase-map.md (current dir OR repo root OR vault parent dir)
2. Probe for binding.md (vault-bound/ OR vault parent dir)
3. Build state snapshot:
   - codebase_map: present | absent
   - binding: present | absent
   - vault_mode: greenfield | existing (from vault.json)
```

### Decision matrix

| codebase_map | binding | vault_mode | Action |
|---|---|---|---|
| present | present | any | ✅ Proceed (current behavior; HIGH confidence) |
| absent | absent | greenfield | ✅ Proceed (no codebase context expected; MEDIUM confidence labeled) |
| absent | absent | existing | ⚠️ INTERACTIVE prompt — "Brownfield vault but no codebase-map/binding. Options: (1) auto-run scan-codebase + bind-codebase first (recommended), (2) proceed with reduced precision (LOW confidence), (3) cancel" |
| present | absent | existing | ⚠️ INTERACTIVE prompt — "Codebase-map present but no binding. Options: (1) run bind-codebase first (recommended), (2) proceed with file-existence checks only (MEDIUM confidence), (3) cancel" |
| absent | present | any | Warn — binding exists but no codebase-map (likely stale or mismatched); proceed with MEDIUM confidence |

### Auto-route action

If user picks "auto-run upstream":
- For codebase-map missing: invoke `mega-sdd:scan-codebase` first (per orchestrate-flow's auto-route pattern)
- For binding missing: invoke `mega-sdd:bind-codebase <vault>` next
- After auto-routes complete, return to generate-units Step 1

Both routes can short-circuit on halt (CONFLICT in binding, etc.) — same protocol as orchestrate-flow.

## Step 7.6 — Per-unit target_files cross-check (NEW)

After `target_files` populated (Step 7), BEFORE writing unit to disk:

For EACH `target_files` entry where `operation: create`:

```
1. Probe path existence (fs OR codebase-map §1)
2. If file does NOT exist → proceed normally (true create scenario)
3. If file EXISTS:
   a. Check if unit's binding_refs include a claim about this file's symbols
   b. If binding has IMPLEMENTED state for related claim → INTERACTIVE prompt:
      "Target file `<path>` already exists. Binding marked related claim IMPLEMENTED.
       Options for unit U-XXX:
         1. Convert to `verify` (no code change; assertion-only) (recommended)
         2. Convert to `extend` (modify file; fill Migration notes)
         3. Rename target file (provide new path)
         4. Force `create` anyway (overwrite — DANGEROUS)
         5. Skip this unit"
   c. If binding has NEW or UNKNOWN state (or no binding) → INTERACTIVE prompt:
      "Target file `<path>` exists but binding state is unclear.
       Options for unit U-XXX:
         1. Convert to `extend` (recommended for unclear state)
         2. Convert to `verify`
         3. Rename target file
         4. Force `create` (overwrite)
         5. Skip this unit"
```

### Prompt frequency control

- Prompts fire ONLY when there's a genuine collision (file exists + task_type=create)
- Same-session memory: if user picks "convert to extend" for unit U-007, similar collisions in U-008/U-009 surface same prompt with previous choice as default
- `--auto` flag suppresses interactive — defaults to safest option (convert to extend; user reviews later)
- `--collision-policy=<extend|verify|skip|prompt>` flag overrides for batch behavior

## Step 12.3 — Per-anchor verification (precondition check)

Before Step 12.4 (constitution inject) and Step 12.5 (polished-prompt render pass), verify each unit's `## Anchors`:

```
For each Anchor entry "<file>:<line-range> — <description>":
  1. Probe file existence (fs OR codebase-map)
  2. If file MISSING:
     - For greenfield units: WARNING (anchor likely aspirational/template)
     - For brownfield units: WARNING with stronger note "Anchor points to non-existent file; verify before bolt"
  3. If file EXISTS but line-range out of bounds:
     - WARNING "Anchor line-range may have drifted; codebase-map shows file has N lines"
  4. If file EXISTS and line-range valid:
     - ✓ Verified
```

Warnings surface in unit body as a footer `<!-- ⚠️ Anchor warnings: ... -->` HTML comment. NOT a halt — anchors can be aspirational (e.g., "this new file SHOULD follow the pattern at <future location>").

## Grounding confidence labels (NEW)

Every generated unit gets a `grounding_confidence` field in frontmatter:

```yaml
---
id: U-007
title: ...
task_type: create
grounding_confidence: HIGH | MEDIUM | LOW
grounding_evidence:
  upstream_artifacts: [codebase-map.md, binding.md]    # what was consulted
  anchors_verified: 3/3                                # how many anchors resolved
  target_files_collision_check: passed                 # whether step 7.6 raised
  binding_state_summary: { IMPLEMENTED: 2, NEW: 0, UNKNOWN: 1 }
---
```

### Confidence levels

| Level | Criteria |
|---|---|
| **HIGH** | binding present + all anchors verified + no target collisions + binding state all HIGH-conf |
| **MEDIUM** | binding present BUT some anchors aspirational OR some UNKNOWN state OR codebase-map precision: regex |
| **LOW** | no binding (standalone generate-units) OR no codebase-map OR significant unverified anchors |

### verify + HIGH: per-acceptance-criterion source grounding (A1)

`anchors_verified: N/M` proves the unit's `## Anchors` *symbols* exist (file exists + line valid). It does **not** prove each acceptance criterion's *behavior* exists — a verify unit could cite one real anchor (e.g. a `MIN_GRAM` constant) yet carry five LOCKED criteria whose behavior lives only in a test stub or the PRD, and still be stamped HIGH. That certifies UNBUILT behavior green. The defect is **partial** grounding, so "are all anchors test files?" misses it — the unit of measure is the **criterion**.

For a `task_type: verify` unit you intend to stamp `grounding_confidence: HIGH`, ground each acceptance criterion individually before writing:

1. For each criterion, locate the **non-test** source that already implements the asserted behavior (grep the codebase-map / binding anchors, not the test files). A test asserting the behavior is NOT proof the behavior exists.
2. Found → prefix the criterion `- [grounded: <non-test path>:<line>] <criterion>`.
3. Not found (behavior only in a test stub, the PRD, or nowhere) → `- [ungrounded] <criterion>`, and the unit is **not** verify+HIGH:
   - downgrade `grounding_confidence` (MEDIUM/LOW — honest), OR
   - **split**: a `verify` unit over the grounded criteria (built) + a `create`/`extend` unit over the ungrounded ones (unbuilt). This is the correct fix — it stops the bolt from skipping code for behavior that was never implemented.

Once any criterion carries a marker the unit opts in and **every** criterion must be `[grounded: …]`; a HIGH verify unit with an `[ungrounded]` (or test-only, or non-resolving) criterion is blocked by `validate-unit-spec.sh` → `verify_grounding_untrusted` (the next `execute-bolts` halts). Legacy verify units with no markers at all are tolerated (treated as the old symbol-existence semantics) — only newly stamped HIGH verify units are held to per-AC grounding. Grammar + examples: `generate-units/references/unit-schema.md` § Acceptance criteria.

### Chat output enhancement

After each unit written, emit one summary line:

```
✓ U-007 generated (task_type: extend, grounding: HIGH, anchors: 3/3 verified, target_files: 2 modify + 0 create)
⚠️ U-013 generated (task_type: create, grounding: LOW, anchors: 1/3 verified — 2 aspirational, target_files: 4 create)
```

Visual feedback so user instantly sees which units are well-grounded vs which need review.

## Halt vs warning matrix

Defensive generation introduces NEW signals but FEW new halts. Most checks are warnings (preserves pipeline flow):

| Check | Outcome | Severity |
|---|---|---|
| Pre-flight: brownfield + no codebase-map/binding | INTERACTIVE prompt (Step 0.5) | Soft halt (user decides) |
| Per-unit: file exists + task_type=create + IMPLEMENTED state | INTERACTIVE prompt (Step 7.6) | Soft halt (user decides) |
| Per-unit: file exists + task_type=create + UNKNOWN state | INTERACTIVE prompt | Soft halt |
| Per-anchor: file missing | WARNING in unit body | Soft (proceeds) |
| Per-anchor: line-range out of bounds | WARNING in unit body | Soft (proceeds) |
| All target_files collision + no path to resolve | HALT `target_files_collision` | Hard halt |
| Force-create on existing file via option 4 | WARNING + proceed (user accepted risk) | Soft (proceeds) |

## Anti-halu rails preserved

- Pre-flight auto-route uses existing scan-codebase + bind-codebase (no new code paths)
- Per-unit cross-check NEVER silent-rewrites task_type — always user confirms via prompt
- Anchor warnings DON'T fabricate citations; flag missing references for user review
- `grounding_confidence` is descriptive (frontmatter metadata), not prescriptive (doesn't gate downstream)
- `--auto` mode picks safest defaults (extend over create on collision; never force overwrite)

## Backward compatibility

- v3.1 vaults without upstream artifacts → trigger Step 0.5 prompts; user can decline to keep v3.1 behavior
- v3.1 units without `grounding_confidence` → treated as v3.1 schema; new field optional in frontmatter
- `--no-defensive` flag disables Steps 0.5 + 7.6 + 12.3 entirely (back to v3.1 behavior)
- `--auto` flag in chain mode (orchestrate-flow --deep) → defaults safest (no death by prompts in autonomous chains)

## Examples

### Example 1 — Pre-flight auto-route

```
$ /mega-sdd:generate-units ./vault/

⚠️ Defensive pre-flight check:
  - codebase-map.md: absent
  - binding.md: absent
  - vault mode: existing (brownfield)

This is a brownfield vault but upstream artifacts are missing. Options:
  1. Auto-run scan-codebase + bind-codebase first (recommended)
  2. Proceed with reduced precision (LOW grounding confidence)
  3. Cancel

> 1

Running mega-sdd:scan-codebase...
[scan-codebase output]

Running mega-sdd:bind-codebase ./vault/...
[bind-codebase output]

Resuming generate-units with HIGH confidence...
```

### Example 2 — Per-unit collision prompt

```
Generating U-007: Build user CRUD endpoints...

⚠️ Target file `app/Http/Controllers/UserController.php` already exists.
Binding marked claim C-007 (POST /api/users) as IMPLEMENTED with high confidence.

Options for U-007:
  1. Convert to `verify` (no code change; assertion-only) (recommended)
  2. Convert to `extend` (modify file; fill Migration notes)
  3. Rename target file (provide new path)
  4. Force `create` (overwrite — DANGEROUS)
  5. Skip this unit

> 1

✓ U-007 converted to task_type: verify; target_files cleared; acceptance_test added against UserController@store
```

### Example 3 — Anchor warning (non-halting)

```
Generating U-013: Add audit-log endpoint...

⚠️ Anchor warning in U-013:
  - app/Http/Controllers/AuditLogController.php:1 — file does not exist yet (aspirational anchor for new file; acceptable for create task)
  - app/Models/AuditLog.php:1 — file does not exist yet (aspirational)

Unit written with anchor warnings preserved as HTML comment in body footer.

✓ U-013 generated (task_type: create, grounding: MEDIUM, anchors: 0/2 verified — both aspirational for greenfield code, target_files: 3 create)
```

### Example 4 — Standalone generate-units LOW confidence

```
$ /mega-sdd:generate-units ./vault/ --no-defensive

⚠️ Defensive checks disabled. Generated units will have grounding_confidence: LOW unless binding exists.

[generates all units with LOW confidence labels]

Summary:
  ✓ 7 units generated, all LOW confidence (no upstream artifacts consulted)
  ⚠️ Recommend running scan-codebase + bind-codebase + re-generating for HIGH confidence
```

## Field-level diff detection (addresses "ngawang" at field granularity)

User example: PRD says login accepts (nip, nama, password). Codebase has only (nip, password). Under a binary IMPLEMENTED/NEW classification the vault claim would be CONFIRMED with state IMPLEMENTED → generate-units assigns `task_type: verify` → bolt skips code generation → **the missing `nama` field never gets added**. That's ngawang.

The PARTIAL_FIELDS_* states exist precisely to close this hole.

### bind-codebase enhancement (PARTIAL_FIELDS state)

For each CONFIRMED claim that specifies fields/params explicitly:

```
vault claim: "POST /api/login accepts { nip, nama, password }"
codebase-map §3 (routes) + §2 (handler signature): login(nip, password)

Set V = { nip, nama, password }  (vault claim fields)
Set C = { nip, password }         (code field set from tree-sitter signature extraction)

Diff:
- V ∩ C  = { nip, password }      (shared / KEEP)
- V \ C  = { nama }                (missing in code / ADD)
- C \ V  = { }                     (surplus in code / REMOVE or vault gap)
```

### Six-state Implementation State Map

| State | Definition | Code Signal |
|---|---|---|
| `IMPLEMENTED` | V == C (field sets match exactly) | tree-sitter signature == vault claim signature |
| `PARTIAL_FIELDS_MISSING` | C ⊂ V (code missing fields from claim) | extracted signature missing fields V \ C |
| `PARTIAL_FIELDS_SURPLUS` | V ⊂ C (code has extra fields not in claim) | extracted signature has extras C \ V; vault may need update |
| `PARTIAL_FIELDS_BOTH` | shared fields exist but both V\C and C\V non-empty (rare; bidirectional drift) | field-level set diff at precision_tier ast |
| `NEW` | C absent (symbol missing) | not in codebase-map |
| `UNKNOWN` | V ∩ C empty but symbol exists | semantic mismatch needs human review |

### binding.md output extension

Implementation State Map row gains `field_diff` column:

```yaml
## Implementation State Map
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-007 | CONFIRMED | PARTIAL_FIELDS_MISSING | LoginController.php:45 | high | ADD: [nama] · KEEP: [nip, password] · REMOVE: [] |
| C-019 | CONFIRMED | IMPLEMENTED | UserController.php:23 | high | (none — exact match) |
| C-023 | CONFIRMED | PARTIAL_FIELDS_SURPLUS | OrderController.php:88 | medium | ADD: [] · KEEP: [order_id, items] · REMOVE: [legacy_ref] · VAULT_REVIEW: code has fields not in vault claim |
```

### generate-units task_type for new states

| Implementation State | Unit task_type | Migration notes auto-populated |
|---|---|---|
| `IMPLEMENTED` (V == C) | `verify` — ONLY at `confidence: high`; medium/low → treat as UNKNOWN (a fuzzy anchor must not mint a verify) | (none; no code changes) |
| `PARTIAL_FIELDS_MISSING` (C ⊂ V) | `extend` | **ADD**: missing fields from V \ C · **KEEP**: shared fields V ∩ C · **REMOVE**: (none) |
| `PARTIAL_FIELDS_SURPLUS` (V ⊂ C) | `extend` with HUMAN REVIEW | **ADD**: (none) · **KEEP**: V ∩ C · **REMOVE**: C \ V (CAUTION — code has fields vault doesn't mention; could be feature drift OR vault gap; user reviews via interactive prompt) |
| `NEW` | `create` | (omitted; create task) |
| `UNKNOWN` | truncation-sourced → direct-probe sub-rule (task-typing.md §Full task_type table); otherwise `create` (conservative default) with note | (omitted; warning in body) |

For PARTIAL_FIELDS_SURPLUS specifically, generate-units fires INTERACTIVE prompt because surplus fields could indicate:
- Feature drift (code has logic not in spec — vault should be updated)
- Vault gap (spec is incomplete)
- Legacy fields to deprecate (REMOVE is correct)
- Field renaming (e.g., `legacy_ref` was renamed to something already in V)

### Example with user's login scenario

```
$ /mega-sdd:bind-codebase ./vault/

[binding output...]

## Implementation State Map
| Claim | Verdict | State | Anchor | Field diff |
|---|---|---|---|---|
| C-LOGIN-1 | CONFIRMED | PARTIAL_FIELDS_MISSING | LoginController@store:45 | ADD: [nama] · KEEP: [nip, password] |

$ /mega-sdd:generate-units ./vault-bound/

Generating U-001 from C-LOGIN-1...

⚠️ Claim has PARTIAL_FIELDS_MISSING — code missing field 'nama' from PRD spec.
  task_type: extend (recommended)
  Migration notes auto-populated:
    ADD: nama field — new validated input on POST /api/login
    KEEP: nip, password (existing logic intact)
    REMOVE: (none)
  Hard rule pre-fill suggestions:
    - DO NOT modify signature of `authenticate(nip, password)` private method (existing behavior preserved)
    - file:app/Http/Requests/LoginRequest.php MUST exist after bolt (validation request class for new field)

Proceed with extend? [Y/n/customize]
```

Unit content is now **field-aware**: bolt knows exactly which field to add, where existing fields are, and what NOT to touch.

### Cost / benefit

**Cost**: tree-sitter must extract signature details (parameter names) — already covered by the shipped .scm queries. bind-codebase needs field-comparison logic — ~50 lines new code per claim type.

**Benefit**: eliminates the #1 source of "ngawang" — implementations that LOOK complete but are missing specific fields the spec requires.

## References

- tree-sitter scan extracts signature details (leveraged for field diff)
- PageRank target_files suggestions (surface in Step 7.5; Step 7.6 cross-checks the picks)
- `bind-codebase/SKILL.md` — Implementation State Map (which Step 7.6 reads to decide prompt content)
- `bind-codebase/references/binding-contract.md` — six-state classification table
