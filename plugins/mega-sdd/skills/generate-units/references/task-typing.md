# generate-units — task_type assignment & target_files detail

## Contents
- Full task_type table (binding state → task_type)
- `verify` unit specifics
- `extend` activation + Migration-notes auto-population
- Reconcile pass (`--reconcile` — living-vault sync lane)
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
| All IMPLEMENTED with `confidence: medium` or `low` | treat as UNKNOWN (apply the UNKNOWN row incl. the direct-probe rule) — a fuzzy anchor must NOT mint a `verify` unit (false "already built", invariant #1 adjacent) |
| **PARTIAL_FIELDS_MISSING** — code missing fields from claim | `extend` with Migration notes auto-populated from binding's `field_diff`: ADD/KEEP/REMOVE lists |
| **PARTIAL_FIELDS_SURPLUS** — code has fields not in claim | `extend` with HUMAN REVIEW interactive prompt (could be feature drift, vault gap, legacy deprecation, or rename) |
| **PARTIAL_FIELDS_BOTH** — both directions diff | `extend` with HUMAN REVIEW mandatory before bolt + strong warning in unit body (usually signals semantic mismatch needing vault update OR code triage) |
| Mix of NEW + IMPLEMENTED | SPLIT — emit one `create` unit for NEW claims, one `verify` unit for IMPLEMENTED claims; chain via `depends_on` so verify runs first |
| Any UNKNOWN (regardless of confidence) | see **UNKNOWN sub-rule** below — `create` is the default ONLY after the truncation check + direct probe |
| Mix of CONFIRMED + CONFLICT | Halt — binding gate should have blocked already; report inconsistency |

> The `Mix of CONFIRMED + CONFLICT` row is a backstop. The primary defense is the SKILL.md hard gate: unresolved CONFLICT entries in binding.md BLOCK unit generation outright (invariant #2). If a CONFLICT reaches this table, the gate was bypassed — halt and report the inconsistency rather than generating.

**Row precedence** (when a claim-set matches multiple rows): (1) Mix of CONFIRMED + CONFLICT halt; (2) Any UNKNOWN — resolve each UNKNOWN claim per the sub-rule below FIRST, then re-aggregate the set and re-apply this table; (3) any `PARTIAL_FIELDS_*`; (4) SPLIT (NEW + IMPLEMENTED); (5) all-NEW / all-IMPLEMENTED.

**UNKNOWN sub-rule (S4 — closes the truncation hole):**
- **Truncation-sourced UNKNOWN** — the binding row's Anchor/reason cell (or `binding.json` `state_reason`) cites `truncated_sections`: the map was CAPPED there, so absence is NOT evidence of absence. Do NOT type `create` from the map. **Probe the repo directly** (grep the claimed entity/route/symbol in the codebase — same fs-probe idiom as Step 7.6): found → treat as IMPLEMENTED-equivalent, type `verify` citing the probed `file:line` as the anchor; not found → `create` (absence now verified against the repo itself, not the truncated map). This delivers the producer contract's "never a create-type task from a truncated section" (codebase-map-schema.md / binding-contract.md).
- **All other UNKNOWN** (dynamic route, ambiguous match, regex tier, KB-confirmed) → `create` (conservative default per DESIGN-OQ-1) — surface a note in unit body: "Binding marked one or more claims as UNKNOWN (anchor: ...). Verify manually whether this work is needed."

The full six-state model + `field_diff` mechanics are specified in the defensive-generation reference (§Six-state Implementation State Map) listed in the skill router.

## `verify` unit specifics

Enforced by the per-task_type contracts in the unit-schema reference (listed in the skill router):
- `target_files` is empty OR all entries `operation: none`
- `acceptance_test` carries assertions that prove existing implementation still works
- Body's `## Implementation steps` is ONE line: "No code changes. Run acceptance tests against existing implementation at <anchor>."
- Body's `## Anchors` section is MANDATORY — cite the file:line where the implementation lives (from binding's `anchor` field)
- Estimated complexity: small

## `extend` activation + Migration-notes auto-population

`extend` was forward-compat-only in the initial schema (deferred PARTIAL state). It is now auto-emitted for `PARTIAL_FIELDS_*` states with Migration notes populated from binding's `field_diff` column. Non-truncation UNKNOWN states still default to `create` (conservative — no field-diff signal available); truncation-sourced UNKNOWN goes through the direct-probe sub-rule first (see the task_type table).

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

Skipped when `precision_tier: regex` or `--skip-pagerank` flag set. Falls back to binding-only target_files. Symbol graph cached at `<vault>/.internal/symbol-graph.json`, built by generate-units on first use (pagerank-targeting §Build — scan-codebase does NOT persist reference captures); reused across all units, invalidated when `codebase-map.md` is regenerated.

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

## Reconcile pass (`--reconcile` — living-vault sync lane)

Invoked by `orchestrate-flow --sync` after a re-bind (spec `2026-06-10-living-vault-continuous-sync-design.md` S6). Updates the EXISTING unit set against the refreshed `binding.md` — id-stability is the contract: a unit ID never changes meaning, and the pass never creates a duplicate for a claim that already has a unit (the `dedup_ambiguous` gate still applies).

Per existing unit (matched by `vault_source` → claim):

1. **task_type re-derivation** — re-read the claim's NEW Implementation State Map row and re-apply the standard table:
   - was `create`, claim now `IMPLEMENTED` → flip to `verify` (code landed out-of-pipeline; verify it, don't rewrite it)
   - was `create`/`verify`, claim now `PARTIAL_FIELDS_*` → flip to `extend`; REFRESH Migration notes from the new `field_diff` (ADD/KEEP/REMOVE)
   - state unchanged → task_type unchanged (do not churn the file)
2. **status re-computation** — run `scripts/compute-unit-staleness.sh --vault=<vault>`; write each unit's `status:` (`implemented` | `stale` | absent for never-executed). `unknown` results (legacy bolt-reports without `target_hashes`) leave `status` absent — never guessed.
3. **superseded detection** — a unit whose claim no longer exists in the re-bound vault → `status: superseded` + a one-line note in the unit body citing the binding run that dropped the claim. The unit file is KEPT (audit trail); execute-bolts skips it with a warning.
4. **new claims** — claims in the refreshed binding with no matching unit → emit new units through the NORMAL full pipeline (Steps 2–12 incl. adversarial test review), not a shortcut.
5. **untouched units are byte-identical** — the pass writes only units whose task_type / status / Migration notes actually changed; `_index.md` is regenerated (graph may have changed).

**Anti-halu rails:** every flip cites the binding row that caused it (same citation discipline as first generation); a claim↔unit match that is ambiguous (multiple candidate units) → `dedup_ambiguous` halt, never a guess; `--reconcile` without a refreshed `binding.md` newer than the units → halt with "re-run bind-codebase first".
