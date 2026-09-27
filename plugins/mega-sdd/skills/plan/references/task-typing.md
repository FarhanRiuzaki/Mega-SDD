# plan — task_type assignment & target_files detail

> Relocated from `skills/generate-units/references/task-typing.md` in 9.0 (P1); trimmed to what 9.0 uses.

## Contents
- task_type rows keyed to `bolts/U-XXX/binding.json`
- `verify` unit specifics
- `extend` activation + Migration-notes authoring
- Step 7 — target_files whitelist
- Step 7.6 — Per-unit target_files collision check
- Reconcile pass (`--reconcile` — living-vault sync lane)

Loaded by `plan/SKILL.md` Step 4 (task_type, `target_files`, collision check) and `--reconcile`. Plan-time typing (greenfield ⇒ every unit `create`; brownfield ⇒ a symbol-index hit types `verify`/`extend`, a miss types `create` + a `must-not-exist` claim; never a verdict in a unit) is owned by `plan-procedure.md §Step 4`. Emitted halt YAML lives in the halt-protocol reference listed in the skill router.

## task_type rows keyed to `bolts/U-XXX/binding.json`

A unit's binding evidence exists only after the JIT bind at dispatch (`scripts/write-unit-binding.sh`, sole writer) or a re-bind (`scripts/rebind-units.sh`), so these rows apply wherever typing reads it (the Reconcile pass below). A resolution is the claim's `resolution.action`, recorded by `resolve-oq --binding` through the same writer.

| Claim in `bolts/U-XXX/binding.json` | Unit task_type |
|---|---|
| Claim carries a **resolved-KEEP_VAULT CONFLICT** (`verdict: CONFLICT` + `resolution.action: KEEP_VAULT`) | `extend` **toward the VAULT claim** — the architect ruled the vault correct and the CODE must change (S5). NEVER `verify` (that would certify the vault-DIVERGING code as correct — the exact inversion) and never dischargeable by a no-code unit. Migration notes = the vault-vs-code delta from the CONFLICT claim (its `expect` vs `evidence` / `anchor`); unit body cites the claim id (`C-U<NNN>-…`) + the KEEP_VAULT resolution and instructs "implement toward the VAULT's claim, not current code"; `binding_refs` carries the claim id. (A `fs_must_exist` claim in state `MISSING` has no code to extend → `create`, Reconcile step 1.) |
| Mix of CONFIRMED + **unresolved** CONFLICT (`verdict: CONFLICT`, no `resolution`) | Halt the typing for that unit — task_type unchanged; the CONFLICT is left for `resolve-oq --binding` and reported (`<unit> · <claim id> — unresolved CONFLICT`). (A RESOLVED conflict does NOT trigger this halt — KEEP_VAULT routes to the row above; KEEP_CODE routes to the Reconcile step-1 flip or is re-bound to CONFIRMED; SPLIT re-binds its sub-claims separately; DEFER became an OQ the unit carries) |

> The unresolved-CONFLICT row is a backstop. The primary defense is the dispatch gate: an open CONFLICT (no `resolution`) in `bolts/U-XXX/binding.json` BLOCKS that unit's bolt (invariant #2; `validate-handoff-binding-units.sh`, re-derived at the execute-bolts gate). A task_type is never derived from an unresolved CONFLICT — halt that unit's typing and report it rather than guess.

**Row precedence** (when a unit's claims match both rows): the unresolved-CONFLICT halt first, then KEEP_VAULT.

## `verify` unit specifics

Enforced by the per-task_type contracts in the unit-schema reference (listed in the skill router):
- `target_files` is empty OR all entries `operation: none`
- `acceptance_test` carries assertions that prove existing implementation still works
- Body's `## Implementation steps` is ONE line: "No code changes. Run acceptance tests against existing implementation at <anchor>."
- Body's `## Anchors` section is MANDATORY — cite the file:line where the implementation lives (the symbol-index hit at PLAN, `query-symbol-index.sh`; at reconcile, the binding.json claim's `anchor` field)

## `extend` activation + Migration-notes authoring

`extend` is emitted when the PRD demands a change to code that already exists (brownfield: a symbol-index hit for the artifact the unit would create — `plan-procedure.md §Step 4`) and for a resolved-KEEP_VAULT CONFLICT (table above). Its `## Migration notes` REMOVE / KEEP / ADD lists are authored from the PRD-vs-code delta: the field set the PRD states (via `context.md ## Data model`) against the field set at the hit's anchor. No hit → `create` (conservative — no delta signal available).

When the code is **missing fields** the PRD requires:
- **ADD** sub-list = the PRD fields absent from the code (missing fields to add)
- **KEEP** sub-list = the shared fields (bolt MUST NOT modify their behavior)
- **REMOVE** sub-list = (empty)

When the code has **SURPLUS fields** the PRD does not mention:
- **ADD** sub-list = (empty)
- **KEEP** sub-list = the shared fields
- **REMOVE** sub-list = the surplus fields with CAUTION note
- The SURPLUS question folds into the Step-6 batched ask (`plan-procedure.md §Step 6`) — never a mid-phase prompt. It is raised as a `[P1]` `[business]` OQ (a PRD-vs-code question is never an AI decision) and the unit cites it in `binding_refs`, so the unit stays blocked at bolts until it is answered. Surplus fields could indicate:
  - Feature drift (code has logic not in spec — vault should be updated)
  - Vault gap (spec is incomplete)
  - Legacy fields to deprecate (REMOVE is correct)
  - Field renaming (e.g., `legacy_ref` was renamed to something already in the PRD)

  The OQ text is rendered per the keterangan contract (`plugins/mega-sdd/references/output-language.md §Prompt surfaces`), never a bare category list; the answer maps to one category:

  ```
  <entity> punya field SURPLUS di code yang tidak ada di PRD:
  > PRD claim: <claim text> (PRD §<X.Y> · context.md#<anchor>)
  > Surplus fields: <list> (<code anchor file:line>)

  Apa status surplus ini?
    [1] Feature drift   — field valid tapi belum terdokumentasi; field jadi KEEP di Migration notes + dicatat di unit ## Open questions (vault di-update via resolve-oq/diff-vault setelahnya — BUKAN oleh plan)
    [2] Vault gap       — vault-nya kurang lengkap; field jadi KEEP di Migration notes + dicatat sebagai vault-gap note (perbaikan vault di-route ke diff-vault/sync)
    [3] Legacy deprecation — field memang mau dihapus; masuk REMOVE di Migration notes (bolt akan menghapusnya)
    [4] Rename          — field lama → nama baru; map lama→baru di Migration notes
  ```

  Recommended default (the ask's `[1]`): when the surplus field carries data in a production-looking table (migrations/seeds reference it), suggest `[1] Feature drift` — deletion is the destructive branch and needs positive evidence, never a default.

When the delta runs **both directions**:
- Both lists populated; HUMAN REVIEW mandatory before bolt (the SURPLUS OQ above)
- Strong warning in unit body

## Step 7 — target_files whitelist

- Greenfield: list expected files (from vault component definitions)
- Brownfield: list the file paths the symbol-index hits cite (the same paths the unit's `## Anchors` / `## Claims` carry)
- If a unit can't determine target_files: halt — vault too vague

## Step 7.6 — Per-unit target_files collision check

After `target_files` populated (Step 7), BEFORE writing unit to disk:

For EACH `target_files` entry where `operation: create`:

```
1. Probe path existence (fs)
2. If file does NOT exist → proceed normally (true create scenario)
3. If file EXISTS:
   a. Check if the unit's `## Claims` / `## Anchors` include a claim about this file's symbols
   b. If the symbol index has a hit for the related claim (IMPLEMENTED) → options for unit U-XXX:
         1. Convert to `verify` (no code change; assertion-only) (recommended)
         2. Convert to `extend` (modify file; fill Migration notes)
         3. Rename target file (provide new path)
         4. Force `create` anyway (overwrite — DANGEROUS)
         5. Skip this unit
   c. If the related claim's state is unclear (no symbol-index hit, or no index) → options for unit U-XXX:
         1. Convert to `extend` (recommended for unclear state)
         2. Convert to `verify`
         3. Rename target file
         4. Force `create` (overwrite)
         5. Skip this unit
```

### Resolution (no mid-phase ask)

- Fires ONLY when there's a genuine collision (file exists + task_type=create)
- `plan` asks the human once (Step 6), so a collision is never a mid-phase prompt: `--collision-policy=<extend|verify|skip>` picks the option for every collision — default `extend`, the safest option (user reviews later). Options 3 and 4 are never applied by policy.
- Every collision is listed in the Step-7 report with the option applied (`U-XXX · <path> · <option>`).

## Reconcile pass (`--reconcile` — living-vault sync lane)

Invoked by `orchestrate-flow --sync` and the `diff-vault` delta lane after the per-unit re-bind (`scripts/rebind-units.sh`; spec `2026-06-10-living-vault-continuous-sync-design.md` S6). Updates the EXISTING unit set against the refreshed `bolts/U-XXX/binding.json` files — id-stability is the contract: a unit ID never changes meaning, the pass never creates a unit, and it never rewrites `context.md`.

Per existing unit (its evidence is its OWN `bolts/U-XXX/binding.json` — the claims `derive-unit-claims.sh` minted from the unit file itself):

1. **task_type re-derivation** — re-read the unit's refreshed claims and re-apply the rows above:
   - was `create`, a `fs_must_not_exist` claim resolved `KEEP_CODE` (the file landed out of band) → flip to `extend`; every target present → `verify` (code landed out-of-pipeline; verify it, don't rewrite it)
   - was `extend`, a `fs_must_exist` claim now CONFLICT/`MISSING` resolved `KEEP_VAULT` → flip to `create`
   - any other resolved-KEEP_VAULT claim → `extend` toward the VAULT claim, never `verify` (a `fs_must_exist` claim in state `MISSING` → `create`, the row above)
   - an unresolved CONFLICT → no flip; left for `resolve-oq --binding`, the unit stays gated
   - state unchanged → task_type unchanged (do not churn the file)

   A flip rewrites ONLY `task_type` (+ a `reconciled: <ISO> from bolts/U-XXX/binding.json` note in the unit body).
2. **status re-computation** — run `scripts/compute-unit-staleness.sh --vault=<vault>`; write each unit's `status:` (`implemented` | `stale` | absent for never-executed). `unknown` results (legacy bolt-reports without `target_hashes`) leave `status` absent — never guessed.

2.6. **Transitive-impact advisory (graph-assisted)** — the hash check above is deliberately blind to a unit whose *dependency* changed while its own files did not. Run `scripts/derive-transitive-impact.sh --vault=<vault> --project=<root> --units=<csv of units whose status/task_type changed in steps 1–3>` (reverse-`depends_on` closure over the derived graph). Units in `transitive` that are currently `implemented` are surfaced as **"verify-recommended (transitive impact)"** — listed in `SYNC-REPORT.md` / the delta handoff and OFFERED alongside stale/new bolts at re-execution (a `verify` re-run is cheap; declining changes nothing). ADVISORY ONLY: this never writes `status:`, never gates, and is **fail-open** — `graph_available: false` (graph absent/unbuildable) means the list is simply empty and the lane never blocks on the graph.
3. **superseded detection** — a unit whose vault home no longer exists (its `context_source` anchor is gone from the revised `context.md` — a `diff-vault` apply removed the flow / section) → `status: superseded` + a one-line note in the unit body citing the vault revision that dropped it. The unit file is KEPT (audit trail); execute-bolts skips it with a warning. A superseded unit covers no PRD heading, so after marking one re-run `validate-plan-coverage.sh`. Until it runs, that vault's coverage entry is stale and the execute-bolts preflight refuses it.
4. **no new units** — a requirement with no unit is not the reconcile pass's to fill: it goes through `diff-vault` → `plan --regenerate`.
5. **untouched units are byte-identical** — the pass writes only units whose task_type / status actually changed; `_index.md` is regenerated (graph may have changed), then `derive-vault-json.sh --vault=<vault>` runs; every flip is listed in chat with its claim id.

**Anti-halu rails:** every flip cites the claim that caused it (the `bolts/U-XXX/binding.json` claim id — same citation discipline as first generation); a claim↔unit match that is ambiguous (multiple candidate units) → `dedup_ambiguous` halt, never a guess; a unit whose binding is absent is reported as `not re-bound — run rebind-units.sh`, never guessed.
