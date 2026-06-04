# generate-units — task_type assignment & target_files detail

## Contents
- Full task_type table (binding state → task_type)
- `verify` unit specifics
- `extend` activation + Migration-notes auto-population
- Step 7 — target_files whitelist
- Step 7.5 — PageRank target_files suggestions
- Step 7.6 — Per-unit target_files collision check

Loaded by `generate-units/SKILL.md` Steps 2.5 / 7 / 7.5 / 7.6. The BODY keeps the moat-critical skeleton (read Implementation State Map → assign `task_type: create | verify`, the CONFLICT block, OQ-ID carry, anchors-mandatory rule); this file carries the full state matrix and the brownfield target_files mechanics. Emitted halt YAML lives in the halt-protocol reference listed in the skill router.

## Full task_type table (Step 2.5)

If bound-vault has `binding.md` with an Implementation State Map, assign `task_type` per the table. If no Implementation State Map (greenfield OR pre-State-Map binding) → every candidate is `create`. For each candidate unit, find the binding claims it derives from (via vault claim → binding C-XXX mapping) and aggregate their states:

| Bound claim states (set: IMPLEMENTED / PARTIAL_FIELDS_MISSING / PARTIAL_FIELDS_SURPLUS / NEW / UNKNOWN) | Unit task_type |
|---|---|
| All NEW, or no binding | `create` |
| All IMPLEMENTED with `confidence: high` | `verify` |
| **PARTIAL_FIELDS_MISSING** — code missing fields from claim | `extend` with Migration notes auto-populated from binding's `field_diff`: ADD/KEEP/REMOVE lists |
| **PARTIAL_FIELDS_SURPLUS** — code has fields not in claim | `extend` with HUMAN REVIEW interactive prompt (could be feature drift, vault gap, legacy deprecation, or rename) |
| **PARTIAL_FIELDS_BOTH** — both directions diff | strong warning; surface interactive prompt; usually signals semantic mismatch needing vault update OR code triage |
| Mix of NEW + IMPLEMENTED | SPLIT — emit one `create` unit for NEW claims, one `verify` unit for IMPLEMENTED claims; chain via `depends_on` so verify runs first |
| Any UNKNOWN (regardless of confidence) | `create` (conservative default per DESIGN-OQ-1) — surface a note in unit body: "Binding marked one or more claims as UNKNOWN (anchor: ...). Verify manually whether this work is needed." |
| Mix of CONFIRMED + CONFLICT | Halt — binding gate should have blocked already; report inconsistency |

> The `Mix of CONFIRMED + CONFLICT` row is a backstop. The primary defense is the SKILL.md hard gate: unresolved CONFLICT entries in binding.md BLOCK unit generation outright (invariant #2). If a CONFLICT reaches this table, the gate was bypassed — halt and report the inconsistency rather than generating.

The full five-state model + `field_diff` mechanics are specified in the defensive-generation reference (§Five-state Implementation State Map) listed in the skill router.

## `verify` unit specifics

Enforced by the per-task_type contracts in the unit-schema reference (listed in the skill router):
- `target_files` is empty OR all entries `operation: none`
- `acceptance_test` carries assertions that prove existing implementation still works
- Body's `## Implementation steps` is ONE line: "No code changes. Run acceptance tests against existing implementation at <anchor>."
- Body's `## Anchors` section is MANDATORY — cite the file:line where the implementation lives (from binding's `anchor` field)
- Estimated complexity: small

## `extend` activation + Migration-notes auto-population

`extend` was forward-compat-only in the initial schema (deferred PARTIAL state). It is now auto-emitted for `PARTIAL_FIELDS_*` states with Migration notes populated from binding's `field_diff` column. UNKNOWN states still default to `create` (conservative — no field-diff signal available).

When binding state is **PARTIAL_FIELDS_MISSING**:
- **ADD** sub-list = `field_diff.ADD` from binding (missing fields to add)
- **KEEP** sub-list = `field_diff.KEEP` (shared fields; bolt MUST NOT modify their behavior)
- **REMOVE** sub-list = (empty)

When binding state is **PARTIAL_FIELDS_SURPLUS**:
- **ADD** sub-list = (empty)
- **KEEP** sub-list = `field_diff.KEEP`
- **REMOVE** sub-list = `field_diff.REMOVE` with CAUTION note
- INTERACTIVE prompt fires: user decides if surplus is feature drift / vault gap / legacy / rename

When binding state is **PARTIAL_FIELDS_BOTH**:
- Both lists populated; HUMAN REVIEW mandatory before bolt
- Strong warning in unit body

## Step 7 — target_files whitelist

- Greenfield: list expected files (from vault component definitions)
- Brownfield: list bound-vault citations (specific file paths from binding)
- If a unit can't determine target_files: halt — vault too vague

## Step 7.5 — PageRank target_files suggestions

When `codebase-map.md` frontmatter has `precision_tier: ast` (tree-sitter scan):

- Build/load symbol-reference graph per the PageRank algorithm in the pagerank-targeting reference (listed in the skill router)
- For each unit, compute personalized PageRank with seed = current `target_files` + binding citations
- Surface top-K (default K=5) non-seed file suggestions in unit body's `## PageRank suggestions` section
- User reviews + manually promotes to `target_files` frontmatter (NEVER silent rewrite per anti-halu)

Skipped when `precision_tier: regex` or `--skip-pagerank` flag set. Falls back to binding-only target_files. Symbol graph cached at `<vault>/.internal/symbol-graph.json` per scan-codebase run; reused across all units.

## Step 7.6 — Per-unit target_files collision check

Per the §Step 7.6 cross-check in the defensive-generation reference (listed in the skill router). Before writing each unit, for EACH `target_files` entry where `operation: create`:
1. Probe path existence (fs check OR codebase-map §1)
2. If file does NOT exist → proceed normally (true create)
3. If file EXISTS:
   - If binding has IMPLEMENTED state for related claim → INTERACTIVE prompt:
     ```
     "Target `<path>` already exists. Binding state: IMPLEMENTED.
      Options for unit U-XXX:
        1. Convert to `verify` (no code change) (recommended)
        2. Convert to `extend` (modify; fill Migration notes)
        3. Rename target file
        4. Force `create` (overwrite — DANGEROUS)
        5. Skip this unit"
     ```
   - If binding state PARTIAL_FIELDS_* or NEW or UNKNOWN → INTERACTIVE prompt with `extend` as recommended default

**Prompt frequency control:**
- Prompts fire ONLY on genuine collision (file exists + task_type=create)
- Same-session memory: previous picks default future similar collisions
- `--auto` flag suppresses interactive — picks safest default (`extend`)
- `--collision-policy=<extend|verify|skip|prompt>` flag overrides for batch behavior
