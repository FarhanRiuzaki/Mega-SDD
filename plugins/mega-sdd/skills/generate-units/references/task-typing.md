# generate-units — task_type assignment & target_files detail

## Contents
- Full task_type table (binding state → task_type)
- Six-state Implementation State Map + field_diff mechanics
- task_type for the six states
- `verify` unit specifics
- `extend` activation + Migration-notes auto-population
- Reconcile pass (`--reconcile` — living-vault sync lane)
- Step 7 — target_files whitelist
- Step 7.6 — Per-unit target_files collision check

Loaded by `generate-units/SKILL.md` Steps 2.5 / 7 / 7.6. The BODY keeps the moat-critical skeleton (read Implementation State Map → assign `task_type: create | verify`, the CONFLICT block, OQ-ID carry, anchors-mandatory rule); this file carries the full state matrix and the brownfield target_files mechanics. Emitted halt YAML lives in the halt-protocol reference listed in the skill router.

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
| Claim carries a **resolved-KEEP_VAULT CONFLICT** (binding.md `✅ RESOLVED (KEEP_VAULT …)` / binding.json `resolution: KEEP_VAULT`) | `extend` **toward the VAULT claim** — the architect ruled the vault correct and the CODE must change (S5). NEVER `verify` (that would certify the vault-DIVERGING code as correct — the exact inversion) and never dischargeable by a no-code unit. Migration notes = the vault-vs-code delta from the CONFLICT entry; unit body cites `CONFLICT-N` + the KEEP_VAULT resolution and instructs "implement toward the VAULT's claim, not current code"; `binding_refs` carries the CONFLICT-N (the propagation drop keeps it un-droppable) |
| Mix of CONFIRMED + **unresolved** CONFLICT | Halt — binding gate should have blocked already; report inconsistency. (A RESOLVED conflict does NOT trigger this halt — KEEP_VAULT routes to the row above; KEEP_CODE/SPLIT re-bound to CONFIRMED; DEFER became an OQ) |

> The `Mix of CONFIRMED + CONFLICT` row is a backstop. The primary defense is the SKILL.md hard gate: unresolved CONFLICT entries in binding.md BLOCK unit generation outright (invariant #2). If a CONFLICT reaches this table, the gate was bypassed — halt and report the inconsistency rather than generating.

**Row precedence** (when a claim-set matches multiple rows): (1) Mix of CONFIRMED + CONFLICT halt; (2) Any UNKNOWN — resolve each UNKNOWN claim per the sub-rule below FIRST, then re-aggregate the set and re-apply this table; (3) any `PARTIAL_FIELDS_*`; (4) SPLIT (NEW + IMPLEMENTED); (5) all-NEW / all-IMPLEMENTED.

**UNKNOWN sub-rule (S4 — closes the truncation hole):**
- **Truncation-sourced UNKNOWN** — the binding row's Anchor/reason cell (or `binding.json` `state_reason`) cites `truncated_sections`: the map was CAPPED there, so absence is NOT evidence of absence. Do NOT type `create` from the map. **Probe the repo directly** (grep the claimed entity/route/symbol in the codebase — same fs-probe idiom as Step 7.6): found → treat as IMPLEMENTED-equivalent, type `verify` citing the probed `file:line` as the anchor; not found → `create` (absence now verified against the repo itself, not the truncated map). This delivers the producer contract's "never a create-type task from a truncated section" (codebase-map-schema.md / binding-contract.md).
- **All other UNKNOWN** (dynamic route, ambiguous match, regex tier, KB-confirmed) → `create` (conservative default per DESIGN-OQ-1) — surface a note in unit body: "Binding marked one or more claims as UNKNOWN (anchor: ...). Verify manually whether this work is needed."

The full six-state model + `field_diff` mechanics are specified below (§Six-state Implementation State Map + field_diff mechanics) — this file is the single owner of task_type assignment.

## Six-state Implementation State Map + field_diff mechanics

Produced by `bind-codebase`. The classification rules, the deterministic ADD/KEEP/REMOVE field-diff set ops, the binding.md `Field diff` column format, and the worked login example are owned by `bind-codebase/references/binding-contract.md §Implementation-State Classification` (per-claim probe rules in its implementation-state reference). Consumer-side summary of the states this file's tables key on:

| State | Definition | Code Signal |
|---|---|---|
| `IMPLEMENTED` | V == C (field sets match exactly) | tree-sitter signature == vault claim signature |
| `PARTIAL_FIELDS_MISSING` | C ⊂ V (code missing fields from claim) | extracted signature missing fields V \ C |
| `PARTIAL_FIELDS_SURPLUS` | V ⊂ C (code has extra fields not in claim) | extracted signature has extras C \ V; vault may need update |
| `PARTIAL_FIELDS_BOTH` | shared fields exist but both V\C and C\V non-empty (rare; bidirectional drift) | field-level set diff at precision_tier ast |
| `NEW` | C absent (symbol missing) | not in codebase-map |
| `UNKNOWN` | V ∩ C empty but symbol exists | semantic mismatch needs human review |

(V = vault claim field set; C = code field set from tree-sitter signature extraction.)

## task_type for the six states

| Implementation State | Unit task_type | Migration notes auto-populated |
|---|---|---|
| `IMPLEMENTED` (V == C) | `verify` — ONLY at `confidence: high`; medium/low → treat as UNKNOWN (a fuzzy anchor must not mint a verify) | (none; no code changes) |
| `PARTIAL_FIELDS_MISSING` (C ⊂ V) | `extend` | **ADD**: missing fields from V \ C · **KEEP**: shared fields V ∩ C · **REMOVE**: (none) |
| `PARTIAL_FIELDS_SURPLUS` (V ⊂ C) | `extend` with HUMAN REVIEW | **ADD**: (none) · **KEEP**: V ∩ C · **REMOVE**: C \ V (CAUTION — code has fields vault doesn't mention; could be feature drift OR vault gap; user reviews via interactive prompt) |
| `NEW` | `create` | (omitted; create task) |
| `UNKNOWN` | truncation-sourced → direct-probe sub-rule (§Full task_type table above); otherwise `create` (conservative default) with note | (omitted; warning in body) |

For PARTIAL_FIELDS_SURPLUS specifically, generate-units fires INTERACTIVE prompt because surplus fields could indicate:
- Feature drift (code has logic not in spec — vault should be updated)
- Vault gap (spec is incomplete)
- Legacy fields to deprecate (REMOVE is correct)
- Field renaming (e.g., `legacy_ref` was renamed to something already in V)

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
- INTERACTIVE prompt fires — rendered per the keterangan contract (`plugins/mega-sdd/references/output-language.md §Prompt surfaces`), never a bare category list:

  ```
  <entity> punya field SURPLUS di code yang tidak ada di vault claim:
  > Vault claim: <claim text> (<vault doc §section>)
  > Surplus fields: <list> (<binding.md row / code anchor>)

  Apa status surplus ini?
    [1] Feature drift   — field valid tapi belum terdokumentasi; field jadi KEEP di Migration notes + dicatat di unit ## Open questions (vault di-update via resolve-oq/diff-vault setelahnya — BUKAN oleh generate-units)
    [2] Vault gap       — vault-nya kurang lengkap; field jadi KEEP di Migration notes + dicatat sebagai vault-gap note (perbaikan vault di-route ke diff-vault/sync — generate-units tidak menulis vault)
    [3] Legacy deprecation — field memang mau dihapus; masuk REMOVE di Migration notes (bolt akan menghapusnya)
    [4] Rename          — field lama → nama baru; map lama→baru di Migration notes
  ```

  Recommended default: when the surplus field carries data in a production-looking table (migrations/seeds reference it), suggest `[1] Feature drift` — deletion is the destructive branch and needs positive evidence, never a default.

When binding state is **PARTIAL_FIELDS_BOTH**:
- Both lists populated; HUMAN REVIEW mandatory before bolt
- Strong warning in unit body

## Step 7 — target_files whitelist

- Greenfield: list expected files (from vault component definitions)
- Brownfield: list bound-vault citations (specific file paths from binding)
- If a unit can't determine target_files: halt — vault too vague

## Step 7.6 — Per-unit target_files collision check

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
   c. If binding has PARTIAL_FIELDS_* or NEW or UNKNOWN state (or no binding) → INTERACTIVE prompt:
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

## Reconcile pass (`--reconcile` — living-vault sync lane)

Invoked by `orchestrate-flow --sync` after a re-bind (spec `2026-06-10-living-vault-continuous-sync-design.md` S6). Updates the EXISTING unit set against the refreshed `binding.md` — id-stability is the contract: a unit ID never changes meaning, and the pass never creates a duplicate for a claim that already has a unit (the `dedup_ambiguous` gate still applies).

Per existing unit (matched by `binding_refs` → claim as the PRIMARY key — survives SPLIT pairs sharing one vault_source; `vault_source` is the fallback for units with no binding refs):

1. **task_type re-derivation** — re-read the claim's NEW Implementation State Map row and re-apply the standard table:
   - was `create`, claim now `IMPLEMENTED` → flip to `verify` (code landed out-of-pipeline; verify it, don't rewrite it)
   - was `create`/`verify`, claim now `PARTIAL_FIELDS_*` → flip to `extend`; REFRESH Migration notes from the new `field_diff` (ADD/KEEP/REMOVE)
   - state unchanged → task_type unchanged (do not churn the file)
2. **status re-computation** — run `scripts/compute-unit-staleness.sh --vault=<vault>`; write each unit's `status:` (`implemented` | `stale` | absent for never-executed). `unknown` results (legacy bolt-reports without `target_hashes`) leave `status` absent — never guessed.

2.6. **Transitive-impact advisory (graph-assisted, 6.12.0)** — the hash check above is deliberately blind to a unit whose *dependency* changed while its own files did not. Run `scripts/derive-transitive-impact.sh --vault=<vault> --project=<root> --units=<csv of units whose status/task_type changed in steps 1–3>` (reverse-`depends_on` closure over the derived graph). Units in `transitive` that are currently `implemented` are surfaced as **"verify-recommended (transitive impact)"** — listed in `SYNC-REPORT.md` / the delta handoff and OFFERED alongside stale/new bolts at re-execution (a `verify` re-run is cheap; declining changes nothing). ADVISORY ONLY: this never writes `status:`, never gates, and is **fail-open** — `graph_available: false` (graph absent/unbuildable) means the list is simply empty and the lane never blocks on the graph.
3. **superseded detection** — a unit whose claim no longer exists in the re-bound vault → `status: superseded` + a one-line note in the unit body citing the binding run that dropped the claim. The unit file is KEPT (audit trail); execute-bolts skips it with a warning.
4. **new claims** — claims in the refreshed binding with no matching unit → emit new units through the NORMAL full pipeline (Steps 2–12 incl. adversarial test review), not a shortcut.
5. **untouched units are byte-identical** — the pass writes only units whose task_type / status / Migration notes actually changed; `_index.md` is regenerated (graph may have changed).

**Anti-halu rails:** every flip cites the binding row that caused it (same citation discipline as first generation); a claim↔unit match that is ambiguous (multiple candidate units) → `dedup_ambiguous` halt, never a guess; `--reconcile` without a refreshed `binding.md` newer than the units → halt with "re-run bind-codebase first".
