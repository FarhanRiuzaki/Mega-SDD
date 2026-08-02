# orchestrate-flow Routing Test

## Trigger cases

### OF1: Explicit
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Inspect + propose

### OF2: Natural
- **Prompt:** `what's next?`
- **Setup:** any SDD signal in CWD
- **Expect:** Skill invoked

## Routing scenarios

### R1: Empty CWD, free-text prompt
- **State:** no PRD, no vault, no git
- **Expect:** Propose `generate-intent --from-prompt`

### R2: PRD present, no vault
- **State:** `prd.md` in CWD
- **Expect:** Propose `generate-intent ./prd.md`

### R3: Vault greenfield, no units
- **State:** vault.json mode=greenfield, no units/
- **Expect:** Propose `generate-units` (skip scan/bind)

### R4: Vault brownfield, no codebase-map
- **State:** vault.json mode=existing, .git present, no codebase-map.md
- **Expect:** Propose chain `scan-codebase → bind-codebase → generate-units` (3-cap reached, no execute-bolts in same chain)

### R5: Bound-vault clean, no units
- **State:** bound-vault exists, binding.md conflict=0
- **Expect:** Propose `generate-units`

### R6: Units exist, no bolts
- **State:** units/U-001.md etc., no bolts/
- **Expect:** Propose `execute-bolts --all --parallel` (chain dispatch is wave-parallel per `docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md` §2a)

### R7: P0 OQs present
- **State:** any state, vault has unresolved P0 OQs
- **Expect:** Propose `resolve-oq` first (overrides other proposals)

### R8: PRD newer than vault
- **State:** `prd.md` mtime > vault.json mtime
- **Expect:** Propose `diff-vault ./prd.md` first

### R9: Mode mismatch
- **State:** vault says greenfield, CWD has .git + package.json
- **Expect:** Halt with mode-migration prompt

### R-FACTORY-1: Backward re-run on unresolved
- **State:** vault + binding + units + bolts present; `factory-ledger.json` has a downstream checkpoint whose `unresolved[].blocks` names an earlier phase
- **Expect:** Router proposes a BACKWARD re-run of the OWNING upstream phase, not a forward step

### R-FACTORY-2: Convergence stops the loop
- **State:** `factory-ledger.json` with every latest checkpoint `completed` + `unresolved: []`
- **Expect:** `status: done`, zero excess re-runs

### R-FACTORY-3: Cap halts, does not spin
- **State:** a phase at attempt 3 still `unresolved`
- **Expect:** HALT `phase_stuck` + concrete human question; no 4th auto re-run

### R-FACTORY-4: bind_conflict KEEP_VAULT/DEFER resolution forward-exits convergence (no re-bind loop)
- **State:** `--deep`/`--converge`; bind halted `bind_conflict`; resolve-oq --binding resolved every conflict via ONLY KEEP_VAULT/DEFER (vault + code unchanged) and emitted `status: completed`, `next_action.suggested_skill: mega-sdd:generate-units`
- **Expect:** the convergence loop FOLLOWS the resolver's forward `next_action` — it EXITS the loop for this halt and rejoins the chain at `generate-units`; it does NOT "re-run the halted skill" (a re-bind would re-derive the unchanged vault-vs-code contradiction and re-raise the identical CONFLICT, burning every cycle). Retry + check-clear stays bound to the BACK-edge case only (KEEP_CODE/SPLIT → re-run bind-codebase). Per `references/convergence-loops.md` + `resolve-oq/references/binding-mode.md` Step 5.

### R-SYNC-1: Mode D maintenance/sync chain threads the corrected per-hop handoffs
- **State:** map + binding + units + bolts present; change signal present (`.mega-sdd/codebase/.dirty-paths.jsonl` non-empty OR git HEAD ≠ the map's `last_scanned_commit`). Invoked `/mega-sdd:sync` (or `orchestrate-flow --sync`).
- **Expect:** Router proposes the Mode D chain per `references/routing-rules.md` (per-hop handoff semantics per spec §3.8), and each producer's handoff threads the sync-aware `next_action` end-to-end:
  - `scan-codebase --changed-only` writes `<vault>/.sync-changed-paths.txt` and hands off `mega-sdd:detect-drift` with `suggested_args` containing `--scope=@<vault>/.sync-changed-paths.txt` (NOT a bare `--auto`).
  - `detect-drift` (sync lane) hands off `mega-sdd:bind-codebase` with `suggested_args` containing `--paths=@<vault>/.sync-changed-paths.txt` — it MUST NOT route to `mega-sdd:resolve-oq` (resolve-oq has no drift-consumption mode).
  - `bind-codebase --paths=@<vault>/.sync-changed-paths.txt` hands off `mega-sdd:generate-units` with `suggested_args` `["--reconcile", "--auto"]` (NOT a bare `["--auto"]`).
  - The `[resolve-oq]` slot in the §3.3 chain fires ONLY when the drift walkthrough CREATED an `OQ-DC-N` stub (resolve-oq's ordinary intent mode), never as a drift-finding consumer.
- **Failing-first:** against the pre-B4/B5/B6 handoffs this FAILS — scan emitted a bare `--auto`, detect-drift routed sync → `resolve-oq`, and bind emitted a bare `["--auto"]`; only the corrected per-hop handoffs (`detect-drift/references/auto-and-chain.md`, `scan-codebase/references/halts-flags-handoff.md`, `bind-codebase/references/auto-memory-handoff.md`) satisfy it.

## Pre-flight

### PF1: Chain includes execute-bolts, no superpowers, no vendored
- **Expect:** Halt with install offer; do NOT propose chain

### PF2: Chain includes execute-bolts, vendored ready
- **Expect:** Chain proposed; pre-flight passes

## Pass criteria

All routing rules per routing-rules.md fire deterministically (incl. R-FACTORY-4 — a KEEP_VAULT/DEFER conflict resolution forward-exits convergence to generate-units, never a re-bind loop; and R-SYNC-1 — the Mode D chain threads the corrected per-hop handoffs: scan → `detect-drift --scope=@<vault>/.sync-changed-paths.txt`, detect-drift sync → `bind-codebase --paths=@<vault>/.sync-changed-paths.txt` and NEVER resolve-oq, bind `--paths` → `generate-units --reconcile`; the `[resolve-oq]` slot covers drift-CREATED `OQ-DC-N` stubs only, per spec §3.8). Pre-flight gates correctly.

## Multi-squad routing (v1.1+)

### MS1: CWD inspection reports squad count
- **Setup:** vault has `_meta/squads.yaml` with 3 squads
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** state snapshot includes `squad_count: 3`

### MS2: Multi-squad + pending units → suggest --per-squad
- **Setup:** vault with 3 squads, units exist, no bolts yet
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** proposed chain contains `execute-bolts --per-squad`

### MS3: Single-squad (squad_count=1) → existing behavior
- **Setup:** vault has `_meta/squads.yaml` with exactly 1 squad declared
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** proposes `execute-bolts --all --parallel` (NOT `--per-squad`)

### MS4: No squads.yaml → existing behavior
- **Setup:** vault has no `_meta/squads.yaml`
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** state snapshot `squad_count: 0`; proposes `execute-bolts --all --parallel`

## Deep-chain mode (v1.3+, Iter 4)

### DC1: `--deep` lifts the 3-skill cap
- **Setup:** legacy codebase + no PRD + no vault; user mentions rebuild intent
- **Prompt:** `/mega-sdd:orchestrate-flow --deep`
- **Expect:** chain proposes ALL 6 phases (extract-intelligence → generate-intent --kb → scan-codebase → bind-codebase → generate-units → execute-bolts) in single upfront confirmation

### DC2: Default mode (no `--deep`) still cap-3
- **Setup:** same as DC1
- **Prompt:** `/mega-sdd:orchestrate-flow` (no --deep)
- **Expect:** chain proposes 3 phases (extract → generate-intent → scan-codebase); user re-invokes after for next chain

### DC3: Auto-continue via handoff YAML
- **Setup:** `--deep` mode chain proposed and approved; first skill (extract-intelligence) completes with `status: completed` handoff
- **Expect:** orchestrator parses handoff YAML; auto-invokes `next_action.suggested_skill` with `next_action.suggested_args`; user does NOT need to type next command

### DC4: Progress indication
- **Setup:** `--deep` chain running, currently on phase 3 of 5
- **Expect:** chat shows `▶ Phase 3 of 5: invoking bind-codebase (--auto)` before invocation and `✓ Phase 3 of 5: bind-codebase → status: completed, items: 87, blocked: 0` after

### DC5: Pause on `status: paused`
- **Setup:** `--deep` chain; generate-intent emits `status: paused` because P1 business OQs were produced
- **Expect:** chain STOPS after generate-intent; chat shows paused-item summary; orchestrator does NOT auto-invoke next phase; awaits user `--resume` after OQs triaged

### DC6: Halt on `status: halted`
- **Setup:** `--deep` chain; bind-codebase emits `status: halted` with `bind_conflict` blocker
- **Expect:** chain STOPS; blocker YAML surfaced verbatim; user resolves via resolve-oq

### DC7: Tech-OQ recommendations do NOT pause the chain
- **Setup:** `--deep` chain; bind-codebase surfaces one or more tech-OQ recommendations (recommend-mode, all fields valid — per bind-codebase.test.md TQ5) but has zero CONFLICTs and no `--strict` business OQs
- **Expect:** bind-codebase emits `status: completed` (NOT `paused`); orchestrator auto-invokes `generate-units`; recommendations remain in binding.md "## Tech-OQ Recommendations (review required)" for post-binding review and the OQ carries into generate-units as a pending ungrounded OQ — the chain never stalls awaiting `--resume` for an advisory recommendation

## Resume mechanics (v1.3+, Iter 4)

### RES1: --resume re-enters paused chain
- **Setup:** previous `--deep` run paused after generate-intent (P1 business OQs); user resolved OQs via `/mega-sdd:resolve-oq`
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --resume`
- **Expect:**
  - NO upfront confirmation (chain was approved earlier)
  - CWD inspection rebuilds state: vault.json exists, codebase-map absent
  - Chain resumes from `scan-codebase` (cursor advances past `generate-intent` because artifact exists)
  - Runs forward to pipeline-end

### RES2: --resume halts again if blocker unresolved
- **Setup:** previous run halted on bind_conflict; user did NOT resolve
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --resume`
- **Expect:** chain re-runs bind-codebase; same halt fires; user gets identical blocker (correct safety behavior)

### RES4: --resume after a KEEP_VAULT/DEFER resolution routes to generate-units (not a bind loop)
- **Setup:** previous run halted on bind_conflict; user resolved every conflict via `/mega-sdd:resolve-oq --binding` using ONLY KEEP_VAULT/DEFER (so `bound/` is intentionally absent but `binding.md` is fully resolution-marked — `validate-handoff-binding-units.sh` green)
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --resume`
- **Expect:** CWD inspection sees a resolution-marked binding.md with no ACTIVE conflict and routes to `generate-units` (per `references/routing-rules.md` — the resolved-binding row ABOVE the bare "no bound-vault → bind-codebase" row); it does NOT route back to bind-codebase (which would re-raise the identical CONFLICT and infinite-loop). Contrast RES2 (UNRESOLVED → correctly re-runs bind and re-halts).

### RES5: --resume after a MIXED (or KEEP_CODE/SPLIT) resolution routes to bind-codebase (re-bind)
- **Setup:** previous run halted on bind_conflict; user resolved via `/mega-sdd:resolve-oq --binding` with at least one KEEP_CODE or SPLIT (the vault WAS edited); `bound/` absent, every conflict resolution-marked, no ACTIVE conflict block
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --resume`
- **Expect:** routes to `bind-codebase` (re-bind — the edited claims now match code and bind cleanly), NOT generate-units. The resolved-binding→generate-units row (RES4) applies ONLY when EVERY resolution action is KEEP_VAULT/DEFER (zero KEEP_CODE/SPLIT); a MIXED resolution falls through to the bind row. This keeps `--resume` (surface 3) action-mix-consistent with the resolve-oq handoff (BM4) and the convergence branch (R-FACTORY-4) — routing is NOT keyed on "validator green" (RED by design for KEEP_VAULT-only) nor bare `binding.md` existence.

### RES3: --from override skips earlier completed phases
- **Setup:** all 6 phases completed; user wants to re-run only `generate-units` + `execute-bolts`
- **Prompt:** `/mega-sdd:orchestrate-flow --deep --from=generate-units`
- **Expect:** chain skips first 4 phases regardless of artifact presence; runs generate-units forward

## Pass criteria (Iter 4)

All deep-chain rules (DC1-DC6) follow `references/routing-rules.md` §Deep-chain decision matrix + `references/handoff-contract.md` §Orchestrator consumption logic. All resume mechanics (RES1-RES5) follow §Resume mechanics — incl. RES4 (KEEP_VAULT/DEFER-only, bound/ absent → generate-units, not a bind re-halt loop) and RES5 (MIXED/KEEP_CODE/SPLIT → bind-codebase re-bind), keeping the stateless resume routing action-mix-consistent with the resolve-oq handoff + convergence surfaces. Halt-protocol behavior unchanged in `--deep` mode vs cap-3 mode. No persisted state file.

---

## Iter 32 — End-to-end starterkit_context propagation case (v2.5.1+)

### OF-SK1 — Full --auto pipeline propagates starterkit_context through all 5 phases

**Setup:**
- Laravel starterkit at `<project_root>` (Sanctum + Spatie/permission + Alpine + Tailwind + SweetAlert2)
- PRD at `<project_root>/prd.md` describing "User management feature"
- No prior vault, no prior codebase-map.md, no prior starterkit-context.yaml

**Trigger:** `/mega-sdd`

**Expected pipeline:**
1. orchestrate-flow detects: PRD + starterkit + no vault → starterkit-first chain
2. Phase 1: `mega-sdd:scan-codebase` invoked
   - Deep-scan stage runs (4 subagents)
   - `.mega-sdd/codebase/starterkit-context.yaml` written
   - Handoff: `starterkit_context: { reused: false, framework: laravel, auth_lib: sanctum, ... }`
3. orchestrate-flow propagates handoff `starterkit_context:` into `metadata.starterkit_context`
4. Phase 2: `mega-sdd:generate-intent --scan=<codebase-map>` invoked
   - Receives `metadata.starterkit_context` in dispatch context
   - Vault generated under `.mega-sdd/vaults/<auto-generated-id>/`
   - Handoff: `starterkit_context:` passthrough (unchanged from scan-codebase)
5. Phase 3: `mega-sdd:bind-codebase` invoked
   - Handoff: `starterkit_context:` passthrough
6. Phase 4: `mega-sdd:generate-units` invoked
   - Step 7.7 fires for all generated units
   - Units that touch UI/auth/RBAC/libs gain starterkit anchors + Hard Rules
   - Handoff: `starterkit_context:` + 2 new metrics (`units_with_starterkit_anchors: <N>`, `units_with_starterkit_rules: <N>`)
7. Phase 5: `mega-sdd:execute-bolts --all --parallel --auto` invoked (wave layering from the chain's analyze-parallelism JSON)
   - Per-unit T2.3 slice injection for units with non-empty starterkit_relevance
   - Bolts produce code matching starterkit patterns (extends layouts.app, uses SweetAlert2, Spatie middleware)
   - Handoff: `starterkit_context:` + 2 new metrics (`bolts_used_starterkit_slice: <N>`, `slice_avg_size_kb: <X.X>`)

**Verification at each handoff boundary:**
- starterkit_context.framework field is `laravel` in ALL 5 handoffs
- starterkit_context.auth_lib field is `sanctum` in ALL 5 handoffs
- Final execute-bolts handoff metrics show non-zero bolts_used_starterkit_slice
- Final bolt-report.md files (per unit) cite `starterkit-context.yaml` in their context section

---

## Iter 33 — Intelligence features (v3.0.0+)

### OF-MR1 — Memory-driven routing recommends past-successful chain

**Setup:**
- `.mega-sdd/memory/routing-outcomes.md` exists with ≥3 rows matching current project fingerprint, all converged=yes, all chain-used="starterkit-first"
- Default routing-rules.md would propose "direct" chain

**Trigger:** `/mega-sdd`

**Expected:**
- Step 2.7 reads routing-outcomes.md
- Fingerprint matches ≥3 prior converged runs with consistent chain
- Recommendation displayed: "Routing recommendation from past 3 runs (all converged in avg 10 min): starterkit-first"
- Step 3 builds starterkit-first chain (overriding routing-rules.md default)
- Chain executes; Step 7.5 appends new outcome row

### OF-MR2 — No prior runs: fall through to default routing

**Setup:**
- `.mega-sdd/memory/routing-outcomes.md` does not exist (fresh project)

**Trigger:** `/mega-sdd`

**Expected:**
- Step 2.7 reads routing-outcomes.md → file absent → skips routing recommendation
- Step 3 builds chain per routing-rules.md default
- No "routing recommendation" message displayed
- Chain executes; Step 7.5 creates routing-outcomes.md + appends first row

### OF-PH1 — Predictive check (non-fatal): tree-sitter warning

**Setup:**
- tree-sitter AND ast-grep binaries NOT installed
- Project has Laravel composer.json (framework detected)
- Chain proposes scan-codebase

**Trigger:** `/mega-sdd`

**Expected:**
- Step 3.5 runs predictive checks for scan-codebase
- `ast_engine_present` check fails (non-fatal; fires only when tree-sitter AND ast-grep are BOTH absent)
- Warning displayed to user BEFORE chain starts: "⚠️ no AST engine installed; scan-codebase will fall back to regex engine. Install: brew install ast-grep / brew install tree-sitter-cli..."
- Chain proceeds normally (scan-codebase uses regex)
- handoff metrics.predictive_warnings_count = 1; metrics.predictive_halts_count = 0

### OF-PH2 — Predictive check (fatal): execute-bolts requires units

**Setup:**
- vault exists but units/ directory empty (no U-*.md files)
- Chain proposes execute-bolts (user passed `--from=execute-bolts`)

**Trigger:** `/mega-sdd:execute-bolts --auto`

**Expected:**
- Step 3.5 runs `units_directory_present` predictive check for execute-bolts
- Check fails (fatal=yes)
- Halt `predictive_check_failed` emitted; chain STOPS before execute-bolts dispatched
- halt envelope: details.failing_check_id="units_directory_present"; next_action.hint="Run generate-units first"
- Chain output: predictive halt YAML; no execute-bolts invocation

### OF-VG1 — Schema validation gate passes for compliant handoff

**Setup:**
- bind-codebase emits handoff with all REQUIRED + CONDITIONAL (vault has scope_metadata + scope: block present) fields

**Trigger:** chain that includes bind-codebase

**Expected:**
- Step 6.b parses bind-codebase handoff YAML successfully
- All REQUIRED fields present; condition met for scope: + scope present
- No halt; Step 6.c propagates metadata to next skill (generate-units)

### OF-VG2 — Schema validation gate halts on missing CONDITIONAL field

**Setup:**
- bind-codebase emits handoff WITHOUT scope: block, but vault.json has scope_metadata
- (Simulated: inject test fixture that bypasses Phase A1 sweep for this test)

**Trigger:** chain includes bind-codebase

**Expected:**
- Step 6.b validates handoff against schema
- Condition "vault has scope_metadata" evaluates TRUE
- scope: field missing (CONDITIONAL+condition_met)
- Halt `invalid_handoff` emitted; STOPS chain before generate-units dispatched
- halt envelope: details.failing_skill="bind-codebase"; missing_field="scope"; field_severity="CONDITIONAL"; condition_evaluated="vault has scope_metadata = TRUE"
- next_action.hint includes "Edit bind-codebase SKILL.md handoff template"

### OF-TC1 — Type check passes for compliant field types

**Setup:**
- bind-codebase emits handoff with scope.id as string "BE" (matches TYPE: enum)

**Trigger:** chain includes bind-codebase

**Expected:**
- Step 6.b.i type-checks scope.id field
- Value "BE" matches TYPE: enum from scope_metadata.allowed_scopes
- No halt; propagation continues

### OF-TC2 — Type check halts on type mismatch

**Setup:**
- bind-codebase emits handoff with scope.id as object `{id: "BE"}` instead of string "BE"
- (Simulated: inject test fixture)

**Trigger:** chain includes bind-codebase

**Expected:**
- Step 6.b.i type-checks scope.id field
- Expected: string; Actual: object → MISMATCH
- Halt `handoff_type_mismatch` emitted; STOPS chain
- halt envelope: details.failing_skill="bind-codebase"; field_name="scope.id"; expected_type="string (enum)"; actual_type="object"; actual_value="{id: 'BE'}"
- next_action.hint includes "Field scope.id should be a string (enum value), not an object"

---

## Iter 34 — Model tier resolution (v3.1.0+)

### OF-MT1 — Catalog defaults applied (no overrides)

**Setup:**
- No CLI `--model-tier` flag
- No `<project>/.mega-sdd/config.yaml` `model_tiers:` section
- No `~/.mega-sdd/memory/preferences.md` `## Model tiers` section

**Trigger:** `/mega-sdd ./prd.md`

**Expected:**
- Step 2.8 reads all 3 override sources (cli_overrides, project_overrides, user_overrides) — all empty
- For each role mentioned in chain → use catalog default per `references/model-tiers.md §Catalog`
- handoff metadata.model_tiers emitted with catalog defaults
- metadata.model_tier_sources = {role: "catalog"} for every entry
- No `model_tier_unknown` halt fired
- Subagent dispatches (e.g., scan-codebase deep-scan) use catalog defaults (sonnet for auth/rbac/ui-ux/libs-extractors)

### OF-MT2 — CLI flag overrides project config + user preference

**Setup:**
- CLI flag: `--model-tier=intelligence-audit-probe:sonnet` (a non-panel role — panel `*-reviewer` lenses are frontmatter-pinned and NOT overridable via `model_tiers:`, per review-panel.md/model-tiers.md §Override syntax)
- `<project>/.mega-sdd/config.yaml` has `model_tiers: { intelligence-audit-probe: haiku }`
- `~/.mega-sdd/memory/preferences.md` `## Model tiers` has `- intelligence-audit-probe: sonnet`

**Trigger:** `/mega-sdd --model-tier=intelligence-audit-probe:sonnet ./prd.md`

**Expected:**
- Step 2.8 override chain resolves intelligence-audit-probe to `sonnet` (CLI wins; project=haiku ignored; user=sonnet ignored — same result but CLI takes precedence)
- metadata.model_tier_sources.intelligence-audit-probe = "cli"
- Log output mentions: "Model tier overrides applied: intelligence-audit-probe=sonnet (cli-flag)"
- All other roles use catalog defaults
- Subagent dispatch uses sonnet for intelligence-audit-probe (NOT catalog haiku default)

### OF-MT3 — Unknown role in override triggers soft halt + chain continues

**Setup:**
- `<project>/.mega-sdd/config.yaml` has `model_tiers: { future-unreleased-role: opus, audit-probe: sonnet }`
- `future-unreleased-role` is NOT in `references/model-tiers.md §Catalog`
- `audit-probe` IS in catalog (intelligence-audit-probe)

**Trigger:** `/mega-sdd ./prd.md`

**Expected:**
- Step 2.8 processes project_overrides
- `future-unreleased-role` unknown → emit soft halt `model_tier_unknown` (warn-only)
- halt envelope: details.unknown_role="future-unreleased-role"; override_source="project-config"
- Log message: "Role 'future-unreleased-role' not found in catalog; override ignored"
- `audit-probe` (valid catalog entry: intelligence-audit-probe) override applied — sonnet (was haiku default)
- Chain PROCEEDS (soft halt; not chain-stopping)
- metadata.model_tiers does NOT include future-unreleased-role; DOES include audit-probe with sonnet
- Forward-compat: future iter adding `future-unreleased-role` to catalog would auto-pick up the project's existing override on next run
