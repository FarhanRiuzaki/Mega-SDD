# orchestrate-flow Routing Test

orchestrate-flow runs the **guarded** lane — ONE pipeline, `plan` → `execute-bolts --all --lite` (JIT bind per unit, `delivery-check.sh`) — plus the maintenance lanes (sync, delta, OQ, drift). The front door's `route-lane.sh` runs first: `direct` / `assisted` work never reaches this skill. The default chain is the state engine's `derived.proposed_next` (`scripts/derive-state.sh`); `references/routing-rules.md` is the matrix it encodes. 9.0 removed the classic chain, so no row proposes `generate-intent` / `scan-codebase` / `bind-codebase` / `generate-units`.

## Trigger cases

### OF1: Explicit
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Inspect + propose

### OF2: Natural
- **Prompt:** `what's next?`
- **Setup:** a mega-sdd chain already ran in this session
- **Expect:** Skill invoked. (With only a CWD signal and no chain this session it is tier S — inline answer, at most a one-line `/mega-sdd --resume` offer; using-mega-sdd.test.md T3)

## Routing scenarios

### R1: Empty CWD, free-text prompt
- **State:** no PRD, no vault, no KB (position `empty`)
- **Expect:** `proposed_next: []` — ask for a PRD/brief. A brief goes to `route-lane.sh --text` (direct/assisted); under `--guarded` the front door writes a seed PRD and proposes `plan <seed-PRD> --vault=<dir> --lite --mode=<existing|new>` → `execute-bolts --all --lite`

### R2: PRD present, no vault
- **State:** `prd.md` in CWD (position `prd_no_vault`)
- **Expect:** Propose `plan ./prd.md --lite --mode=<existing|new>` → `execute-bolts --all --lite` (`existing` when the repo carries code, `new` for a bare scaffold — never asked)

### R3: Plan-born vault, no units
- **State:** layout-3 vault (`context.md` + `vault.json`), no `units/` (position `lite_context_no_units`)
- **Expect:** Propose `plan <prd> --lite --regenerate` → `execute-bolts --all --lite` (units are written with the vault — never a units-only phase)

### R4: Layout-2 vault (classic-born)
- **State:** a pre-9.0 layout-2 vault (`vault.md`, no `context.md`) that needs building or syncing (position `layout2_needs_migration`)
- **Expect:** `proposed_next: []` + a note PROPOSING `/mega-sdd:migrate-paths --vault-layout=3` (then the mandatory full JIT re-bind, `rebind-units.sh --units=all`); never run silently. emit-* and the status view still read the layout-2 vault as it is

### R5: Leftover pre-9.0 artefacts are not routing keys
- **State:** a `.mega-sdd/codebase/codebase-map.md` and/or `<vault>/bound/` from a pre-9.0 run
- **Expect:** reported in the digest (`codebase_map`, `bound_vault`) as read-only context; never a scan, bind or units proposal, and a stale map stamp never fires the sync lane (only the symbol-index stamp does)

### R6: Units exist, no bolts
- **State:** units/U-001.md etc., no bolts/
- **Expect:** Propose `execute-bolts --all --lite` (the inline run, spec v9 §8.5; a typed `--agents` is retired in one line and changes nothing)

### R7: Blocking OQs present
- **State:** any state, the vault has unresolved P1 business OQs, status != deferred (the grammar has no P0 — P1 is the blocking tier)
- **Expect:** Propose `resolve-oq` first (overrides other proposals; chain + `--auto` = the batched walk). Deferred P1 OQs do NOT gate

### R8: PRD newer than vault
- **State:** `prd.md` mtime > vault.json mtime
- **Expect:** Propose `diff-vault ./prd.md` first

### R8b: PRD revision outranks the delta overlay (guard)
- **State:** `prd.md` mtime > vault.json mtime AND the user hands a chat brief ("tambah kolom npwp")
- **Expect:** the `prd_revision` row wins — propose `diff-vault ./prd.md` (file lane), NOT `diff-vault --from-prompt`; the delta row fires only when no PRD revision is present (routing-rules §Decision matrix: prd_revision OUTRANKS the delta row)

### R8c: Delta lane is overlay-only (guard)
- **State:** vault + per-unit bindings present, no flags, no chat brief handed over — derived state alone
- **Expect:** the engine NEVER proposes `diff-vault --from-prompt` from derived state (routing-rules: "NEVER fired from derived state alone"); the normal rows apply

### R9: Mode mismatch
- **State:** vault says greenfield, CWD has .git + package.json
- **Expect:** Halt with mode-migration prompt

### R-FACTORY-1: Backward re-run on unresolved
- **State:** vault + per-unit bindings + units + bolts present; `factory-ledger.json` has a downstream checkpoint whose `unresolved[].blocks` names an earlier phase
- **Expect:** Router proposes a BACKWARD re-run of the OWNING upstream phase, not a forward step

### R-FACTORY-2: Convergence stops the loop
- **State:** `factory-ledger.json` with every latest checkpoint `completed` + `unresolved: []`
- **Expect:** `status: done`, zero excess re-runs

### R-FACTORY-3: Cap halts, does not spin
- **State:** a phase at attempt 3 still `unresolved`
- **Expect:** HALT `phase_stuck` + concrete human question; no 4th auto re-run

### R-FACTORY-4: binding_conflict resolved → the scope run re-binds and re-plans
- **State:** `--deep`/`--converge`; the `execute-bolts` run start (`derive-exec-plan.sh`) halted on `binding_conflict` (U-008 blocked every pending unit); the auto-invoked `resolve-oq --binding` resolved every conflict, written through `write-unit-binding.sh --resolve`
- **Expect:** the loop re-invokes `execute-bolts`, whose run start re-binds and re-plans (`inline-run.md` (b)); U-008 is in the plan once its gate is open. Per `references/convergence-loops.md` + `resolve-oq/references/binding-mode.md` Step 5

### R-SYNC-1: Mode D maintenance/sync chain (per-unit, script hops)
- **State:** layout-3 vault with units, bolts and per-unit `bolts/U-*/binding.json`; the symbol index exists; a change signal is present (`.mega-sdd/codebase/.dirty-paths.jsonl` non-empty OR git HEAD ≠ the index `head_commit`). Invoked `/mega-sdd:sync` (or `orchestrate-flow --sync`).
- **Expect:** Router proposes the Mode D chain per `references/routing-rules.md` §Mode D, each hop threading the next:
  - `scripts/derive-changed-paths.sh --vault <vault>` writes `<vault>/.sync-changed-paths.txt` (journal rotated only after that write)
  - `scripts/sync-intersect.sh` short-circuit: exit 0 → one-line SYNC-REPORT.md, chain ENDS; exit 4 → proceed; any other exit → fail-closed, full chain
  - `detect-drift --scope=@<vault>/.sync-changed-paths.txt` hands off `mega-sdd:plan` `["--reconcile", "--auto"]` naming the re-bind hop — it MUST NOT route to `mega-sdd:resolve-oq` (resolve-oq has no drift-consumption mode)
  - `scripts/rebind-units.sh --cwd=<root> --vault=<vault> --paths=@<vault>/.sync-changed-paths.txt` re-verdicts only the units the changed set touches (a CONFLICT closes their gate)
  - `plan --reconcile` → `execute-bolts --all --lite` (stale units only; `superseded` skipped)
  - The `[resolve-oq]` slot fires ONLY when the drift scan CREATED an `OQ-DC-N` stub (resolve-oq's ordinary intent mode), never as a drift-finding consumer
- **No baseline:** no symbol index (or `derive-changed-paths.sh` exit 3) → detect-drift skipped, `rebind-units.sh --units=all` → `plan --reconcile` → `execute-bolts --all --lite` — never a guessed scope

## Pre-flight

### PF1: Chain includes execute-bolts, no superpowers installed (v7.4.0)
- **Expect:** Chain proposed — NO dependency halt (first-class agents ship in the plugin; the vendored probe was removed)

### PF2: A stale chain names a removed skill
- **State:** a paused 8.x chain resumed with a hop naming `bind-codebase` (or `generate-intent` / `generate-units` / `scan-codebase`)
- **Expect:** `validate-preflight.sh --predictive` FATAL `skill_removed_in_9` for that hop, with its one-line replacement; chain STOPS before dispatch — the removal never depends on lane, config or vault layout

## Pass criteria

All routing rules per routing-rules.md fire deterministically from the state engine: one pipeline (`plan` → `execute-bolts --all --lite`), `plan --regenerate` for a plan-born vault without units, migrate-paths PROPOSED for a layout-2 vault, pre-9.0 artefacts never a routing key (R1–R9). R-FACTORY-4 — a KEEP_VAULT/DEFER-only resolution continues the unit with no re-bind; KEEP_CODE/SPLIT re-binds that one unit (3.9b). R-SYNC-1 — the Mode D chain runs `derive-changed-paths` → `sync-intersect` → scoped `detect-drift` (→ `plan --reconcile`, NEVER resolve-oq) → `rebind-units.sh --paths` → `plan --reconcile` → bolts; the `[resolve-oq]` slot covers drift-CREATED `OQ-DC-N` stubs only. Pre-flight gates correctly; a removed skill in a chain is FATAL.

## Multi-squad routing (migrated pre-9.0 vaults only)

`plan` never authors `_meta/squads.yaml`; these cases apply to a migrated vault that still carries one.

### MS1: CWD inspection reports squad count
- **Setup:** vault has `_meta/squads.yaml` with 3 squads
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** state snapshot includes `squad_count: 3`

### MS2: Multi-squad + pending units → --all (the inline run ignores squads)
- **Setup:** vault with 3 squads, units exist, no bolts yet
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** proposed chain contains `execute-bolts --all --lite` (NOT `--per-squad`)

### MS3: Single-squad (squad_count=1) → existing behavior
- **Setup:** vault has `_meta/squads.yaml` with exactly 1 squad declared
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** proposes `execute-bolts --all --lite` (NOT `--per-squad`)

### MS4: No squads.yaml → existing behavior
- **Setup:** vault has no `_meta/squads.yaml`
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** state snapshot `squad_count: 0`; proposes `execute-bolts --all --lite`

## Deep-chain mode

### DC1: `--deep` chains to pipeline end
- **Setup:** legacy codebase + no PRD + no vault; user mentions rebuild intent
- **Prompt:** `/mega-sdd:orchestrate-flow --deep`
- **Expect:** chain proposes all 3 phases (`extract-intelligence` → `plan --kb=<kb> --lite --mode=<existing|new>` → `execute-bolts --all --lite`) in a single upfront confirmation

### DC2: Default mode (no `--deep`) keeps the cap-3 rule
- **Setup:** same as DC1
- **Prompt:** `/mega-sdd:orchestrate-flow` (no --deep)
- **Expect:** the same 3 phases — the one pipeline fits inside the cap; the cap would only truncate a chain longer than 3 sub-skills

### DC3: Auto-continue via handoff YAML
- **Setup:** `--deep` mode chain proposed and approved; first skill (extract-intelligence) completes with `status: completed` handoff
- **Expect:** orchestrator parses handoff YAML; auto-invokes `next_action.suggested_skill` (`mega-sdd:plan`) with `next_action.suggested_args` (`--kb=<kb>`, `--auto`); user does NOT need to type next command

### DC3b: plan emits no handoff (lite-lane exemption)
- **Setup:** `--deep` chain; `plan` returns `completed`
- **Expect:** no handoff YAML is parsed or invented for the `plan` hop; the orchestrator re-runs `derive-state.sh`, then `validate-preflight.sh --predictive --chain=execute-bolts` (units present + `lite_plan_coverage_pass`), then dispatches `execute-bolts --all --lite`

### DC4: Progress indication
- **Setup:** `--deep` chain running, currently on phase 2 of 3
- **Expect:** chat shows `▶ Phase 2 of 3: invoking plan (--kb=… --lite --auto)` before invocation and `✓ Phase 2 of 3: plan → status: completed, items: <units>, blocked: 0` after

### DC5: A `plan` blocker stops the chain
- **Setup:** `--deep` chain; `plan` halts `plan_coverage_gap` and prints its `blocker:` envelope
- **Expect:** chain STOPS after plan; the blocker is surfaced verbatim; the orchestrator does NOT auto-invoke execute-bolts (and never invents a handoff for the halted hop); the user closes the gap, then `--resume`

### DC6: Halt on `status: halted`
- **Setup:** `--deep --no-converge` chain; `execute-bolts` halts `binding_conflict` for a unit (the up-front bind)
- **Expect:** that unit STOPS (dependents skipped with the reason); blocker YAML surfaced verbatim; user resolves via `resolve-oq --binding`

### DC7: AI technical decisions never pause the chain and never route to resolve-oq
- **Setup:** `--deep` chain; `plan` decided the vault's tech OQs (`(AI decision, <date>)`, `resolved_by: ai`), one of them P1; zero CONFLICTs and no open business OQs
- **Expect:** the chain continues to `execute-bolts`; the decisions are listed in `context.md ## AI Technical Decisions` (information, never an ask); because a decided OQ is `status: resolved`, the `oq_gate` (`pending_p0_p1`) does NOT fire for the P1 tech OQ and `resolve-oq` is never inserted into the chain — only an open P1 *business* OQ can do that; an open `[tech / scan]` OQ is not counted in `pending_p0_p1` either

## Resume mechanics

### RES1: --resume re-enters a paused chain
- **Setup:** previous `--deep` run stopped with open P1 business OQs; user resolved them via `/mega-sdd:resolve-oq`
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --resume`
- **Expect:**
  - NO upfront confirmation (chain was approved earlier)
  - CWD inspection rebuilds state: `context.md` + `units/_index.md` exist
  - the cursor skips `plan` (its artifacts exist) and resumes at `execute-bolts --all --lite`
  - Runs forward to pipeline-end

### RES2: --resume halts again if blocker unresolved
- **Setup:** previous run halted on `binding_conflict` for U-004; user did NOT resolve
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --resume`
- **Expect:** chain re-enters execute-bolts; the gate closes U-004 again with the same CONFLICT; user gets the identical blocker (correct safety behavior)

### RES4: --resume after a KEEP_VAULT/DEFER resolution dispatches the unit (no re-bind loop)
- **Setup:** previous run halted on `binding_conflict` for U-004; user resolved every conflict via `/mega-sdd:resolve-oq --binding` using ONLY KEEP_VAULT/DEFER (`write-unit-binding.sh --resolve`)
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --resume`
- **Expect:** `validate-handoff-binding-units.sh --units=U-004` passes on the resolved claims and U-004 is dispatched without a re-bind (a later re-bind keeps the resolution while the claim and its code paths are unchanged). Contrast RES2 (UNRESOLVED → the gate closes again)

### RES5: --resume after a KEEP_CODE/SPLIT resolution re-binds that unit
- **Setup:** previous run halted on `binding_conflict` for U-004; user resolved via `/mega-sdd:resolve-oq --binding` with at least one KEEP_CODE or SPLIT (the unit's `## Claims` WAS edited)
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --resume`
- **Expect:** U-004 is re-bound before its task (`rebind-units.sh --units=U-004`, then `plan --reconcile` per resolve-oq's hand-off); skipped, the run start backstops it — the edited unit trips `unit_changed_since_bind` and the up-front bind re-binds it. Routing keys on the resolution action mix, never on a whole-vault re-bind

### RES3: --from override skips earlier completed phases
- **Setup:** all phases completed; user wants to re-run only `execute-bolts`
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --from=execute-bolts`
- **Expect:** chain skips `plan` regardless of artifact presence; runs execute-bolts forward

## Pass criteria (deep chain + resume)

All deep-chain rules (DC1-DC7) follow `references/routing-rules.md` §Deep-chain decision matrix + `references/handoff-consumption.md` (incl. §Lite lane exemption for `plan`). All resume mechanics (RES1-RES5) follow §Resume mechanics — a KEEP_VAULT/DEFER-only resolution dispatches the unit with no re-bind (RES4); KEEP_CODE/SPLIT re-binds that unit (RES5), keeping the stateless resume routing action-mix-consistent with the resolve-oq hand-off + convergence surfaces. Halt-protocol behavior unchanged in `--deep` mode vs cap-3 mode. No persisted state file.

---

## Predictive checks + handoff validation

### OF-PH1 — Predictive check (non-fatal): AST-engine warning

**Setup:**
- ast-grep binary NOT installed
- Project has Laravel composer.json (framework detected)
- Chain proposes `plan` → `execute-bolts`

**Trigger:** `/mega-sdd ./prd.md --guarded`

**Expected:**
- Step 5 runs `validate-preflight.sh --predictive --chain=plan,execute-bolts`
- `ast_engine_present` warns (non-fatal), once per hop: GROUND builds no symbol index, so plan types brownfield units greenfield (+WARN) and the JIT bind leaves symbol claims OQ; install hint names `/mega-sdd:install-deps`
- Warning displayed to user BEFORE chain starts; chain proceeds normally

### OF-PH2 — Predictive check (fatal): execute-bolts requires units

**Setup:**
- vault exists but units/ directory empty (no U-*.md files)
- Chain proposes execute-bolts (user passed `--from=execute-bolts`)

**Trigger:** `/mega-sdd:orchestrate-flow --from=execute-bolts --auto`

**Expected:**
- Step 5 runs the `units_directory_present` predictive check for execute-bolts
- Check fails (fatal=yes)
- Halt `predictive_check_failed` emitted; chain STOPS before execute-bolts dispatched
- halt envelope: details.failing_check_id="units_directory_present"; hint "Run plan <prd> first (plan writes units/U-*.md)"
- A direct `/mega-sdd:execute-bolts` dispatch is blocked by the dispatch-time twin `bolts_units_missing`

### OF-VG1 — Schema validation gate passes for compliant handoff

**Setup:**
- `detect-drift` (sync lane) emits a handoff with all REQUIRED + CONDITIONAL fields (the vault has `scope_metadata` and the `scope:` block is present)

**Trigger:** `/mega-sdd:sync` on that vault

**Expected:**
- Step 7.b parses the detect-drift handoff YAML successfully
- All REQUIRED fields present; condition met for `scope:` + scope present
- No halt; Step 7.c propagates metadata to the next hop (`rebind-units.sh` → `plan --reconcile`)

### OF-VG2 — Schema validation gate halts on missing CONDITIONAL field

**Setup:**
- `detect-drift` emits a handoff WITHOUT the `scope:` block, but vault.json has `scope_metadata`
- (Simulated: inject a test fixture)

**Trigger:** `/mega-sdd:sync` on that vault

**Expected:**
- Step 7.b validates the handoff against the schema
- Condition "vault has scope_metadata" evaluates TRUE
- `scope:` field missing (CONDITIONAL + condition_met)
- Halt `invalid_handoff` emitted; STOPS the chain before the next hop
- halt envelope: details.failing_skill="detect-drift"; missing_field="scope"; field_severity="CONDITIONAL"; condition_evaluated="vault has scope_metadata = TRUE"

### OF-TC1 — Type check passes for compliant field types

**Setup:**
- `detect-drift` emits a handoff with scope.id as string "BE" (matches TYPE: enum)

**Trigger:** chain includes detect-drift

**Expected:**
- Step 7.b type-checks the scope.id field
- Value "BE" matches the expected string type
- No halt; propagation continues

### OF-TC2 — Type check halts on type mismatch

**Setup:**
- `detect-drift` emits a handoff with scope.id as object `{id: "BE"}` instead of string "BE"
- (Simulated: inject a test fixture)

**Trigger:** chain includes detect-drift

**Expected:**
- Step 7.b type-checks the scope.id field
- Expected: string; Actual: object → MISMATCH
- Halt `handoff_type_mismatch` emitted; STOPS chain
- halt envelope: details.failing_skill="detect-drift"; field_name="scope.id"; expected_type="string (enum)"; actual_type="object"; actual_value="{id: 'BE'}"

---

## Model tier resolution

### OF-MT1 — Catalog defaults applied (no overrides)

**Setup:**
- No CLI `--model-tier` flag
- No `<project>/.mega-sdd/config.yaml` `model_tiers:` section

**Trigger:** `/mega-sdd ./legacy-php/ --out=./rebuild/` (legacy rebuild — the chain dispatches extract-intelligence's agents)

**Expected:**
- The model-tier resolution step reads both override sources (cli_overrides, project_overrides) — all empty (the user-scope `preferences.md` source died with the memory lane in v7.3.0)
- For each role mentioned in chain → use catalog default per `references/model-tiers.md §Catalog`
- handoff metadata.model_tiers emitted with catalog defaults
- metadata.model_tier_sources = {role: "catalog"} for every entry
- No `model_tier_unknown` halt fired
- Subagent dispatches use catalog defaults (sonnet for `extract-intelligence-module` and `extract-intelligence-verify`)

### OF-MT2 — CLI flag overrides project config

**Setup:**
- CLI flag: `--model-tier=extract-intelligence-module:opus` (a catalog role, per model-tiers.md §Override syntax)
- `<project>/.mega-sdd/config.yaml` has `model_tiers: { extract-intelligence-module: haiku }`

**Trigger:** `/mega-sdd --model-tier=extract-intelligence-module:opus ./legacy-php/ --out=./rebuild/`

**Expected:**
- The override chain resolves `extract-intelligence-module` to `opus` (CLI wins; project=haiku ignored)
- metadata.model_tier_sources.extract-intelligence-module = "cli"
- Log output mentions: "Model tier overrides applied: extract-intelligence-module=opus (cli-flag)"
- All other roles use catalog defaults
- The per-module extractor dispatch uses opus (NOT the catalog sonnet default)

### OF-MT3 — Unknown role in override triggers soft halt + chain continues

**Setup:**
- `<project>/.mega-sdd/config.yaml` has `model_tiers: { libs-extractor: opus, extract-intelligence-module: haiku }`
- `libs-extractor` is NOT in `references/model-tiers.md §Catalog` (rows 1–5 retired with the scan-codebase deep scan in 9.0)
- `extract-intelligence-module` IS in catalog (row 6)

**Trigger:** `/mega-sdd ./legacy-php/ --out=./rebuild/`

**Expected:**
- `libs-extractor` unknown → emit soft halt `model_tier_unknown` (warn-only)
- halt envelope: details.unknown_role="libs-extractor"; override_source="project-config"
- Log message: "Role 'libs-extractor' not found in catalog; override ignored"
- `extract-intelligence-module` (valid catalog entry, row 6) override applied — haiku (was sonnet default)
- Chain PROCEEDS (soft halt; not chain-stopping)
- metadata.model_tiers does NOT include libs-extractor; DOES include extract-intelligence-module with haiku
