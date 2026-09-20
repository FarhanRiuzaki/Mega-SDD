# plan Trigger + Behavior Test

Manual-run fixture for the `plan` skill — the lite-lane pre-code phase (PRD → `context.md` + units in ONE model turn). The classic lane (DEFAULT through 8.x) never routes here; that is the point of P1–P3 below.

## Trigger cases

### P1: Front door with `--lite`
- **Setup:** CWD has `docs/PRD-leave.md`, no vault
- **Prompt:** `/mega-sdd docs/PRD-leave.md --lite`
- **Expect:** front door proposes the lite chain `plan → execute-bolts --all --lite`; `plan` announces with `mega-sdd-trace:plan`; NO `generate-intent` / `bind-codebase` / `generate-units` hop is proposed

### P2: Config lane
- **Setup:** `.mega-sdd/config.yaml` carries `lane: lite`; PRD as P1
- **Prompt:** `/mega-sdd docs/PRD-leave.md`
- **Expect:** same lite chain as P1 (the config key is the durable form of the flag)

### P3: Classic default is untouched (negative)
- **Setup:** no `lane:` key, no `--lite`
- **Prompt:** `/mega-sdd docs/PRD-leave.md`
- **Expect:** the classic chain (`generate-intent → scan → bind → units → bolts`); `plan` is NOT invoked

### P4: Natural English
- **Prompt:** `plan this PRD --lite` / `PRD straight to units`
- **Expect:** Skill invocation (lite lane)

### P5: Natural Indonesian
- **Prompt:** `plan PRD ini --lite` / `rencanakan dari PRD, langsung ke units`
- **Expect:** Skill invocation (lite lane)

### P6: Off-lane direct invocation refuses
- **Setup:** no `lane: lite`, no `--lite` on the args
- **Prompt:** `/mega-sdd:plan docs/PRD-leave.md`
- **Expect:** predictive preflight FATAL `plan_off_lane` — one line pointing at `/mega-sdd <prd>` (classic) or `--lite` / `lane: lite`; nothing written

### P7: Brief / KB are not plan inputs (negative)
- **Prompt:** `/mega-sdd "bikin sistem cuti karyawan" --lite`
- **Expect:** routes to `generate-intent --from-prompt` (Mode B), not `plan`; same for `--kb=<dir>`

## Behavior checks

### B1: Output set is layout-3
- After a clean run: `<vault>/context.md` (H2 anchors `## Flows` / `## Data model` / `## Constraints` / `## Open Questions`), `constitution.md`, `_meta/ai-consumer-guide.md`, `vault.json` (`vault_layout: 3`), `units/U-*.md` + `units/_index.md`
- NO `binding.md`, NO `bound/`, NO `claims-ledger.json` — verdicts are written per unit at dispatch (`bolts/U-XXX/binding.json`)

### B2: Every unit cites both sources
- Each unit carries `prd_source:` AND `context_source: context.md#<anchor>`; never `vault_source`
- A PRD heading with no unit `prd_source` and no OQ → halt `plan_coverage_gap` (`validate-plan-coverage.sh`), never silently dropped

### B3: Claims are contracts, not verdicts
- Brownfield (`--mode=existing`): a unit whose symbol-index query hit carries `## Anchors` + `## Claims`; a miss carries a `must-not-exist` claim
- No unit body contains `CONFIRMED` / `CONFLICT` (the JIT bind writes those at dispatch)

### B4: Validators run project-wide with `--cwd`
- Step 5 runs `validate-unit-spec.sh --cwd=<root>`, `validate-flow-coverage.sh --cwd=<root>`, `validate-sibling-consistency.sh --cwd=<root>`, `validate-plan-coverage.sh --cwd=<root> --prd=<prd> --vault=<vault>`
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

### B6: xs switch
- `project_scale: xs` (1–3 screens ∧ ≤2 entities ∧ ≤3 flows): P2 *business* OQs are born `**Deferred (plan)**:` (tech OQs are decided at every scale, never deferred); units get the xs body diet

### B7: `--regenerate` guard
- Existing `context.md` in the target vault without `--regenerate` → refuse with one line; nothing overwritten

### B8: `--reconcile` flips task_type only
- **Setup:** layout-3 vault with `bolts/U-*/binding.json` refreshed by `rebind-units.sh`
- **Prompt:** `/mega-sdd:plan --reconcile`
- **Expect:** NO new units, `context.md` untouched; `task_type` flips per the binding evidence (`fs_must_not_exist` KEEP_CODE → `create`→`extend`; `fs_must_exist` CONFLICT KEEP_VAULT → `extend`→`create`) with a `reconciled: <ISO> from bolts/U-XXX/binding.json` note; unresolved CONFLICTs stay gated; a unit without a binding is reported `not re-bound — run rebind-units.sh`, never guessed

### B9: Handoff
- No handoff YAML in this lane; the front door re-derives state from disk (`derive-state.sh`) before the `execute-bolts --all --lite` hop; chat ends with `NEXT: /mega-sdd --resume`

## Pass criteria

P1/P2/P4/P5 invoke `plan`; P3/P7 do NOT (classic default and Mode B untouched); P6 refuses off-lane. B1–B9 hold: layout-3 output set, dual citations, contracts-not-verdicts, `--cwd` validators with read exit codes, one batched keterangan ask, xs deferral, regenerate guard, reconcile = task_type only, no handoff YAML.
