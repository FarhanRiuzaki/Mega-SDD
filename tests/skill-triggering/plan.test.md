# plan Trigger + Behavior Test

Manual-run fixture for the `plan` skill — the one spec phase of the guarded pipeline: a PRD, a seed PRD the front door writes from a brief, or an `extract-intelligence` knowledge base (`--kb`) → `context.md` + units in ONE model turn. 9.0 removed the classic chain (`generate-intent` → `scan-codebase` → `bind-codebase` → `generate-units`): `plan` inherited their spec-side trigger phrases (PT cases below), and no lane key or flag gates it any more. The guarded lane is reached through the front door (`scripts/route-lane.sh`: an existing vault, or `--guarded`; `--lite` implies it) — a clear task takes the direct/assisted lane and invokes no `plan` at all.

## Trigger cases

### P1: Front door with `--lite`
- **Setup:** CWD has `docs/PRD-leave.md`, no vault
- **Prompt:** `/mega-sdd docs/PRD-leave.md --lite`
- **Expect:** `--lite` implies `--guarded` (route-lane.sh records the override); the front door proposes `plan docs/PRD-leave.md --lite --mode=<existing|new>` → `execute-bolts --all --lite` with ONE confirmation; `plan` announces with `mega-sdd-trace:plan`

### P2: Config `lane: lite` is informational
- **Setup:** `.mega-sdd/config.yaml` carries `lane: lite`; PRD as P1; no vault; no flag
- **Prompt:** `/mega-sdd docs/PRD-leave.md`
- **Expect:** the key selects no lane — `route-lane.sh` decides from its signals (direct/assisted here, no vault); the front door dispatches `plan` only when the lane is guarded (`--guarded` / `--lite` on the run, or an existing vault; a direct `/mega-sdd:plan` call is P6). On guarded, the chain is the P1 chain with or without the key

### P3: Retired `lane: standard` (negative)
- **Setup:** `.mega-sdd/config.yaml` has `lane: standard`; the run is guarded (`--guarded`)
- **Prompt:** `/mega-sdd docs/PRD-leave.md --guarded`
- **Expect:** ONE line saying `lane: standard` is retired in 9.0 and ignored (`derived.notes`), then the same one pipeline as P1 — never a classic chain (it no longer exists). `--classic` / `spine: classic` get the same one-line treatment

### P4: Natural English
- **Prompt:** `plan this PRD` / `PRD straight to units`
- **Expect:** Skill invocation

### P5: Natural Indonesian
- **Prompt:** `plan PRD ini` / `rencanakan dari PRD, langsung ke units`
- **Expect:** Skill invocation

### P6: Direct invocation needs no lane key
- **Setup:** no `lane:` key, no `--lite` on the args
- **Prompt:** `/mega-sdd:plan docs/PRD-leave.md`
- **Expect:** the dispatch preflight PASSES (`plan_target_layout`) — the 8.x `plan_off_lane` gate is retired; `plan` runs
- **Variant (layout-2 target):** `--vault=<dir>` names a layout-2 vault (`vault.md`, no `context.md`) → dispatch FATAL `plan_layout2_vault` naming `/mega-sdd:migrate-paths --vault-layout=3` (then the mandatory full JIT re-bind), or `--vault=<new-dir>`; nothing written. A layout-2 vault NEXT TO the target never blocks a new PRD

### P7: A brief is not a direct plan input
- **Prompt:** `/mega-sdd:plan "bikin sistem cuti karyawan"`
- **Expect:** Step 0 refuses in one line — `plan` reads a PRD file or `--kb=<kb-dir>`; `/mega-sdd <brief>` routes a brief (direct/assisted; `--guarded` writes it to a seed-PRD file first — S1 below). Nothing written

## Trigger phrases inherited from the removed classic skills (9.0)

Route check: these phrases are in `plan`'s description (and `spec out` / `pecah PRD` / `dev handoff` in the `using-mega-sdd` router's). With a `.mega-sdd/` dir the session anchor is injected and sends M/L work through the front door first; without one the phrase reaches `plan` by its description.

### PT1: `pecah PRD ini buat AI dev` — anchorless
- **Setup:** `prd.md` in CWD; no `.mega-sdd/`
- **Prompt:** `pecah PRD ini buat AI dev`
- **Expect:** Skill invocation `plan ./prd.md` (was generate-intent Mode A); output language per the PRD, chat Indonesian + English technical terms (plan carries the policy itself — no anchor)

### PT2: same phrase with the session anchor
- **Setup:** as PT1, plus a `.mega-sdd/` dir (no vault)
- **Prompt:** `pecah PRD ini buat AI dev`
- **Expect:** tier L → the `/mega-sdd` front door with the PRD → `route-lane.sh --prd=prd.md` first. `guarded` (forced, or a vault exists) → `plan prd.md --lite --mode=<existing|new>` → `execute-bolts --all --lite`; `direct`/`assisted` → built without a vault, and the announce line names the way up (`/mega-sdd prd.md --guarded`)

### PT3: English handoff phrasings
- **Prompt:** `spec out this feature` / `buat dev handoff` / `break down this PRD for the dev team` (a PRD file named or in CWD)
- **Expect:** as PT1 (anchorless) / PT2 (anchor present)

### PT4: `spec out` with no PRD (brief only)
- **Setup:** empty CWD, no PRD file
- **Prompt:** `I only have an idea, not a PRD. Let me describe it...` / `spec out fitur ini buat dev`
- **Expect:** the brief goes through the front door (`route-lane.sh --text`) → direct/assisted; no pre-plan interview (generate-intent's Mode B Q&A left with the skill — assisted asks its open business items in ONE batched ask). If `plan` is invoked on the brief it refuses as P7. Under `--guarded` → S1

### PT5: `pecah vault jadi unit` on a plan-born vault without units
- **Setup:** layout-3 vault (`context.md` + `vault.json`), no `units/`
- **Prompt:** `pecah vault jadi unit` / `generate units` / `bikin units` / `dev tasks dari vault` / `vault to units`
- **Expect:** `plan` owns the phrase (was generate-units). There is no units-only pass: units are written with the vault, so the hop is `plan <prd> --lite --regenerate` (state position `lite_context_no_units`) — carried human OQ outcomes kept verbatim. `plan` without `--regenerate` on an existing `context.md` refuses in one line ("`plan --regenerate` rewrites it, `/mega-sdd --resume` continues")

### PT6: same phrase on a layout-2 vault
- **Setup:** classic-born layout-2 vault (`vault.md` + `model.md` + `flows.md` + `constraints.md`), no `context.md`
- **Prompt:** `pecah vault jadi unit`
- **Expect:** never a units pass over layout-2: the front door proposes `/mega-sdd:migrate-paths --vault-layout=3` (then the mandatory full JIT re-bind, `rebind-units.sh --units=all`) and never runs it silently; a `plan` dispatch at that vault → FATAL `plan_layout2_vault` (P6 variant)

### PT7: Removed skill names typed from habit
- **Prompt:** `/mega-sdd:generate-intent ./prd.md` / `/mega-sdd:generate-units`
- **Expect:** no command or skill registers; the text routes by phrase / artifact (→ PT1/PT2, PT5). A stale 8.x chain (e.g. a paused `--resume`) naming a removed skill → predictive preflight FATAL `skill_removed_in_9` with its one-line replacement (`generate-intent was removed in 9.0 — use plan …` / `generate-units was removed in 9.0 — use plan: units are written with the vault …`)

## KB input — `plan --kb` (legacy rebuild: extract-intelligence → plan --kb → execute-bolts)

### K1: Explicit `--kb` on a PRD-kontrak KB
- **Setup:** `.mega-sdd/knowledge-base/` with `README.md` + `census.json` + `modules/*.prd.md` (extract-intelligence output); no vault
- **Prompt:** `/mega-sdd:plan --kb=.mega-sdd/knowledge-base/`
- **Expect:**
  - Step 0 (`derive-plan-pins.sh --kb=…`): `prd_path_at_generation` = `<kb>/README.md`, `prd_sha256` = sha256 of `<kb>/census.json`, `project_scale: standard` (a KB run is never xs)
  - the advisory preflights run: the extraction scorecard (`validate-extract-census.sh --quiet`) — a FAIL is an `Extraction quality (advisory)` line in the Step-7 report, never a block — and the opt-in KB freshness check (census sha256 vs the legacy source: warns, never halts)
  - Steps 1–3 read the README, `data-mutation-policy.md` (when present) and every module PRD; one `context.md`, units written module by module
  - tier routing: `[LOCKED]` → `## Constraints` verbatim + Hard rule; `[INTENT]` → outcome in `## Flows`; `[ARTIFACT]` → OQ, default discard; `[INFERRED][LOCKED]` → a confirmation OQ; a §6 OQ already `[x]` (resolve-oq KB mode) lands PRE-RESOLVED with its stakeholder provenance
  - every unit `prd_source` names `<kb>/modules/<m>.prd.md#<slug>`

### K2: Hand-off from extract-intelligence
- **Setup:** `extract-intelligence <legacy> --auto` just completed (census gate PASS)
- **Expect:** its handoff `next_action` = `mega-sdd:plan` with `["--kb=.mega-sdd/knowledge-base/", "--auto"]`; under `--deep` the orchestrator auto-invokes it (never `generate-intent --kb`)

### K3: Front door on a KB
- **Prompt:** `/mega-sdd .mega-sdd/knowledge-base/` — or `/mega-sdd` with a KB present and no vault (position `kb_no_vault`)
- **Expect:** proposes `plan --kb=<kb> --lite --mode=<existing|new>` → `execute-bolts --all --lite` (the bolts hop only when a target scaffold exists; otherwise a note) + ONE line mentioning the `emit-prd` reverse lane (never auto-chained)

### K4: Implicit `--kb` + shared KB via `knowledge_base:` in config
- **Setup:** monorepo, session cwd `apps/api/` (own `.mega-sdd/`, no local `knowledge-base/`); `apps/api/.mega-sdd/config.yaml` has `knowledge_base: ../../knowledge/mcf-domain-knowledge/.mega-sdd/knowledge-base/`; that directory (a git submodule) holds `README.md` + `census.json` + `modules/*.prd.md`
- **Trigger:** `/mega-sdd:plan` (no positional, no `--kb`)
- **Expect:** `derive-state` reports `knowledge_base: present (path: ../../knowledge/.../README.md, source: config)`; `--kb=<configured path>` is set implicitly and confirmed once (on the chain: the front door's one upfront confirmation — never a second ask inside `plan`)
- **Variant (configured but missing):** submodule not initialised → `knowledge_base: absent`, `probes.knowledge_base.configured_missing: true`, a `derived.notes` line names the path; `plan` never falls back to a local copy
- **Variant (config + stale local copy):** cwd `apps/web/` with an old `.mega-sdd/knowledge-base/` AND the key set → the configured KB wins (`source: config`)

### K5: `--phase` (legacy numbered-tree KB only)
- **Setup:** a pre-7.6 numbered-tree KB (`00-overview/` … `99-rebuild-architecture/`, no `census.json`); `99-rebuild-architecture/suggested-phasing.md` has 3 `## Phase` headings
- **Trigger:** `/mega-sdd:plan --kb=<kb> --phase=2` (no flag → Phase 1)
- **Expect:** content scoped to Phase 2; `phase: 2`, `phase_total: 3` land in `vault.json` through the Step-3 `derive-vault-json.sh --patch` (never hand-written); out-of-range N → invocation-time error
- **Variant (PRD-kontrak KB):** `--phase=N` → logged ("PRD-kontrak KB has no phase lane (module = phasing unit); flag ignored") and ignored — never a halt

### K6: Architecture-advisor ADRs
- **Setup:** `<kb>/decisions/ADR-001.md` `Status: accepted`, `ADR-002.md` `Status: proposed`
- **Expect:** ADR-001 → a `context.md ## Decisions` `### D-NNN` record citing `decisions/ADR-001.md`; ADR-002 → an OQ ("arsitektur target belum diputuskan — ADR-002 masih proposed"), never a decision

### K7: KB-derived Hard rules stay honest
- **Expect:** a `## 5. Edge Cases & Gotchas` entry that is cited (implicitly `[VERIFIED]`) AND mechanically detectable → `DO NOT modify <file>` in the unit's `## Hard rules`; an `[INFERRED]` / `[OPEN]` gotcha → `## Anti-patterns` only; a rule whose file is not in the tracked source (symbol index / disk) → Anti-pattern, never a Hard rule that would fail `hard_rule_unanchored` at bolt time

### K8: KB coverage gap
- **Setup:** a module heading (neither §1 Purpose nor §6 Open Questions) with no unit `prd_source`, no open OQ carrying `[covers: <kb>/modules/<m>.prd.md#<slug>]`, and no module-qualified `## Coverage exclusions` line
- **Expect:** Step 5 `validate-plan-coverage.sh --cwd=<root> --kb=<kb-dir> --vault=<vault>` exits 1 → halt `plan_coverage_gap` naming the heading and its module file; an OQ that quotes the heading or cites its `§` covers nothing, and so does a resolved OQ

## Seed PRD from a brief (the guarded brief path)

### S1: Brief forced onto the pipeline
- **Setup:** no vault
- **Prompt:** `/mega-sdd "bikin sistem cuti karyawan" --guarded` (or `--lite`)
- **Expect:** the front door writes `.mega-sdd/vaults/<slug>/source/seed-PRD.md` per `plan/references/brief-input.md` with cap 0 (NO pre-plan Q&A), then proposes `plan .mega-sdd/vaults/<slug>/source/seed-PRD.md --vault=.mega-sdd/vaults/<slug> --lite --mode=<existing|new>` → `execute-bolts --all --lite` (the `--vault` keeps the vault from being slugged `seed-prd`)

### S2: The seed PRD never invents
- **Expect:** `§brief` is the brief verbatim; every `§qa` row for a topic the brief does not cover reads `(skipped — hard cap)`; every body claim carries a `(brief)` / `(brief §N)` marker; silent topics are `(unspecified)` and listed in `## I. Mentioned but not specified`; `**Status**: DRAFT` → `prd_status: draft`

### S3: Unspecified topics become OQs, asked ONCE
- **Expect:** each `## I` item becomes an OQ in `context.md ## Open Questions`; a technical gap is decided by the AI at Step 3 (`(AI decision, <date>)`); the P1 business ones are asked in plan's single batched ask (B5) — never in a separate interview

## Behavior checks

### B1: Output set is layout-3
- After a clean run: `<vault>/context.md` (H2 anchors `## Flows` / `## Data model` / `## Constraints` / `## Open Questions`), `constitution.md`, `_meta/ai-consumer-guide.md`, `vault.json` (`vault_layout: 3`), `units/U-*.md` + `units/_index.md`
- NO `binding.md`, NO `bound/`, NO `claims-ledger.json` — verdicts are written per unit at dispatch (`bolts/U-XXX/binding.json`)

### B2: Every unit cites both sources
- Each unit carries `prd_source:` AND `context_source: context.md#<anchor>`; never `vault_source`
- A PRD heading with no unit `prd_source`, no open OQ carrying `[covers: …]` and no `context.md ## Coverage exclusions` line → halt `plan_coverage_gap` (`validate-plan-coverage.sh`), never silently dropped

### B3: Claims are contracts, not verdicts
- Brownfield (`--mode=existing`): a unit whose symbol-index query hit carries `## Anchors` + `## Claims`; a miss carries a `must-not-exist` claim
- No unit body contains `CONFIRMED` / `CONFLICT` (the JIT bind writes those at dispatch)

### B4: Validators run project-wide with `--cwd`
- Step 5 runs `validate-unit-spec.sh --cwd=<root>`, `validate-flow-coverage.sh --cwd=<root>`, `validate-sibling-consistency.sh --cwd=<root>`, `validate-plan-coverage.sh --cwd=<root> --prd=<prd> --vault=<vault>` (under `--kb`: `--kb=<kb-dir>` in place of `--prd`)
- `validate-sibling-consistency.sh --vault=` is a usage error (exit 2, `STATUS: ERROR` on stdout); `validate-unit-spec.sh --vault=<vault>` is accepted as an exit-code scope only (the state file still lists every unit)
- The controller reads the validator's exit code, never a piped `$?`

### B5: ONE batched ask
- P1 business OQs → ONE `AskUserQuestion`, ≤4 questions, each with keterangan (question source + per-option explanation, Indonesian for ID users), options `[1]` recommended / `[2]` Defer / `[3]` Out of scope / Other
- More than 4 → the 4 with the largest unit blast radius; the rest stay `blocking` in the report
- Headless → the business OQs stay open; the skill never self-answers a business OQ
- A tech OQ is NEVER one of the questions — at any priority, P1 included

### B5b: Tech OQs are decided by the AI, never asked
- Every `[tech / scan|recommend]` OQ is written `[x]` + `→ **Resolved v<X.Y>** (AI decision, <date>): <pick>` at Step 3 (a `scan` question is probed NOW — no bind phase follows PLAN); `context.md` carries the `## AI Technical Decisions` table (omitted when none); vault.json shows `status: resolved`, `resolved_by: ai`
- No `[tech / blocking]` bracket is ever written; a missing FACT or a "PRD says X but the repo does Y" question is `[business]`
- Step 5 runs `validate-vault-oqs.sh --cwd=<root> --file-path=<vault>/context.md --strict-tech` AFTER the derive: `oq_tech_undecided` / `oq_decided_business_signal` are findings the phase fixes and re-runs — never patched around
- The Step-7 summary prints ONE information line (`N keputusan teknis diambil AI … override: resolve-oq single-oq <OQ-ID>`) — not a question
- A human answer from the batched ask is written `→ **Resolved v<X.Y>** (plan, <date>): <answer>` — never the `(AI decision …)` marker

### B5c: The Design-Source OQ is the stakeholder's, never the AI's
- **Setup:** greenfield UI PRD, `HAS_UI_COMPONENTS: true`, no tokens / a11y / voice-brand source
- **Expect:** `OQ-DESIGN-SOURCE-1 [P1] [business]` (`resolution_mode: blocking`), left `[ ]`; the product-style-map pick rides only as slot `[1]` of the batched ask; `design_system` is written only after the human accepts
- **FAIL if:** it is tagged `[tech / recommend]` and written `(AI decision …)` (`validate-vault-oqs.sh` → `oq_decided_business_signal`)

### B6: xs switch
- `project_scale: xs` (1–3 screens ∧ ≤2 entities ∧ ≤3 flows): P2 *business* OQs are born `**Deferred (plan)**:` (tech OQs are decided at every scale, never deferred); units get the xs body diet

### B7: `--regenerate` guard
- Existing `context.md` in the target vault without `--regenerate` → refuse with one line; nothing overwritten
- With `--regenerate`: every human OQ outcome (`[x]` without the AI marker, `[~]`, a deferred `[business]`) is carried verbatim, never re-asked; `(AI decision …)` lines are re-decided

### B8: `--reconcile` flips task_type only
- **Setup:** layout-3 vault with `bolts/U-*/binding.json` refreshed by `rebind-units.sh`
- **Prompt:** `/mega-sdd:plan --reconcile`
- **Expect:** NO new units, `context.md` untouched; `task_type` flips per the binding evidence (`fs_must_not_exist` KEEP_CODE → `create`→`extend`; `fs_must_exist` CONFLICT KEEP_VAULT → `extend`→`create`) with a `reconciled: <ISO> from bolts/U-XXX/binding.json` note; unresolved CONFLICTs stay gated; a unit without a binding is reported `not re-bound — run rebind-units.sh`, never guessed; a new requirement goes `diff-vault` → `plan --regenerate`

### B9: Handoff
- No handoff YAML in this lane; the front door re-derives state from disk (`derive-state.sh`) before the `execute-bolts --all --lite` hop; chat ends with `NEXT: /mega-sdd --resume`

### B10: Dependency DAG
- Units whose `depends_on` form a cycle → halt `cycle_detected` at Step 4; never written with the cycle

## Pass criteria

P1/P4/P5 invoke `plan` (P1 through the forced guarded lane); P2 shows the `lane:` key selects no lane and P3 shows `lane: standard` / `--classic` are retired in one line; P6 dispatches with no lane key and refuses only a layout-2 TARGET; P7 refuses a brief. The inherited phrases (PT1–PT7) reach `plan` — directly when anchorless, through the front door's router when the anchor is present — and a removed skill name is never dispatched. `plan --kb` (K1–K8) pins the KB honestly, routes by mutability tier, carries KB-stage answers, scopes `--phase` to the numbered-tree grammar only, and gates coverage per module file. A brief reaches `plan` only as a seed PRD with no pre-plan Q&A (S1–S3). B1–B10 hold: layout-3 output set, dual citations, contracts-not-verdicts, `--cwd` validators with read exit codes, one batched keterangan ask, AI-decided tech OQs, the stakeholder-owned Design-Source OQ, xs deferral, regenerate guard, reconcile = task_type only, no handoff YAML, cycles halt.
