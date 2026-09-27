# mega-sdd 9.0: simplification design (evidence-led)

**Status:** approved by the owner ("oke gas sederhanakan pipeline-nya, lo harus design dengan matang",
2026-09-27). Phases P1–P3 are below. Each phase lands as its own commit(s), green on the full
suite, with the complexity budget lowered to the measured values.

**Evidence base (all measured, n=3 clean runs per arm, vanilla Claude Code as control):**

| Block | Result |
|---|---|
| greenfield xs + clinic (`research/2026-09-27-vanilla-vs-megasdd-results.md`) | The pipeline (lite and classic) was 2.3–12× slower and 9–22× costlier than vanilla, with equal or lower quality |
| lane router (`research/2026-09-27-lane-router-results.md`) | The direct/assisted lanes are on par with vanilla. Delivery-check passes 9/9 of their runs and fails 9/9 of the old pipeline's |
| brownfield + seeded traps (`research/2026-09-27-brownfield-results.md`) | The guarded pipeline surfaced the same 5/5 traps as vanilla at 6.0× the cost. Its CONFLICT gate fired 3× in 3 runs, all false positives on its own anchors |
| lite vs classic, xs (`benchmarks/results/vanilla-ab/REPORT.md`) | Lite was faster and cheaper with no range overlap. Quality overlapped |

## 0. Owner principles (2026-09-27)

1. **Consistent, result-oriented output.** A run is judged by what it delivers, and every run
   delivers the same **result contract**, whatever the lane:
   - an acceptance-criterion → test table;
   - `delivery-check.sh` `VERDICT: PASS` on the final commit;
   - the list of assumptions and decisions made.

   Process artefacts are kept only where they make that result predictable or auditable.
   "Consistent" is measured, not asserted. Benchmark reports show every run and the **spread**
   (min–max) next to the median. A lane whose spread is wider than vanilla's on a result metric is
   a regression, even when the median is fine.
2. **`extract-intelligence` stays.** The legacy-codebase → knowledge-base lane is kept, and it must
   keep producing a buildable spec. Its hand-off moves from `generate-intent --kb` to `plan --kb`,
   and that path is a P1 exit criterion, pinned by a test.

## 1. What mega-sdd is for, after the evidence

The evidence removes one claim and leaves four.

**The removed claim:** "the spec pipeline writes better code." It did not, in any block.

**What remains:**

1. **A router that keeps ordinary work at vanilla speed and cost** (measured on par).
2. **A delivery check that vanilla does not run.** It is deterministic, and it caught every
   reviewer-visible defect the old pipeline shipped.
3. **One structured ask for business decisions before coding** (assisted). Headless blocks cannot
   measure its interactive value; both arms surfaced the traps in text.
4. **Spec and audit artefacts for teams that need traceability:**
   - the vault and units;
   - per-unit binding and evidence;
   - team documents (FSD, SIT, UAT) and legacy extraction.

   These are a **documentation and audit** value, opt-in, and must never be sold as a quality
   gain.

The design keeps 1–4 and removes what serves none of them.

## 2. Target shape (9.0)

```
/mega-sdd <prd|brief>  →  route-lane.sh
   direct    main session + delivery-check                          (default, no vault)
   assisted  direct + one batched ask + one blind review           (existing app, open items, security, multi-flow)
   guarded   ONE pipeline: plan → execute-bolts → delivery-check   (existing vault or --guarded)
docs lanes (unchanged, opt-in): extract-intelligence → KB; emit prd|fsd|sit|uat|html; emit-agents-md
maintenance: /mega-sdd:sync (plan --reconcile + rebind-units), resolve-oq, analyze, graph
```

The one pipeline is **lite**:
- `plan` writes the layout-3 vault (`context.md` + `constitution.md` + `vault.json` + `units/`).
- `execute-bolts` binds each unit just in time and runs the bolts.

The classic chain (`generate-intent → scan-codebase → bind-codebase → generate-units`) and the
classic spine are removed. Lite beat classic on every cost dimension, quality overlapped, and the
router already stopped sending anything to classic.

## 3. Component verdicts

Callers were mapped by grep over `skills/ commands/ hooks/ agents/ references/ scripts/`
(2026-09-27).

### Skills (20 → 16)

| skill | verdict | why / what replaces it |
|---|---|---|
| using-mega-sdd | KEEP | the router anchor |
| plan | KEEP, grows | the only spec producer. Absorbs the unit-generation procedure and the vault contracts it used to read from generate-intent / generate-units, and gains a `--kb` input (legacy rebuild) |
| execute-bolts | KEEP (P1); P2 inline mode | the guarded executor |
| orchestrate-flow | KEEP, shrinks | chain proposals become plan → execute-bolts (+ sync). The classic rows and the scan-first spine go |
| **generate-intent** | **REMOVE (P1)** | replaced by `plan` (PRD / KB). Briefs go to direct/assisted, or to `plan` via `--guarded` (the front door writes the brief to a file first) |
| **bind-codebase** | **REMOVE (P1)** | the whole-vault bind is replaced by the JIT per-unit bind already inside execute-bolts (`write-unit-binding.sh`). The CONFLICT gate stays at dispatch |
| **generate-units** | **REMOVE (P1)** | replaced by `plan` (units written in the same phase since 8.0) |
| **scan-codebase** | **REMOVE (P1)** | the scan-first classic spine. The express spine (GROUND script + symbol index) has been the default since P2 |
| resolve-oq | KEEP | OQ walk + `--binding` for per-unit `binding.json`. Its classic `binding.md` paths go |
| diff-vault | KEEP | PRD revision / delta. The re-bind hop becomes `rebind-units.sh` + `plan --reconcile` (the lite path it already documents) |
| detect-drift | KEEP | sync lane |
| analyze, graph, install-deps, emit-agents-md, emit-prd/fsd/sit/uat, extract-intelligence | KEEP | docs, maintenance and tooling lanes. Not in the build path, not measured, and not touched beyond re-pointing relocated contract paths. extract-intelligence hands off to `plan --kb` |

### Agents (9)

KEEP in P1. P2 decides the review panel (spec / quality / security / standards / design lenses,
resolution-verifier) and `bolt-implementer` dispatch with a measurement. `domain-extractor` and
`claim-verifier` belong to extract-intelligence and stay.

### Hooks

KEEP in P1, byte-for-byte except path strings.
- The gates read per-unit lite evidence. Their layout-2 legs stay because existing layout-2
  vaults remain readable.
- Measured cost on a repo with no vault: ±6 ms per tool call (fast path). Not a user-visible cost.

### Scripts

P1 deletes a script only if its sole callers were the removed skills: `compute-lock-digests.sh`.
Every other script has a surviving caller: a doc reference, the state engine, or a validator.

Script pruning is **P1b**:
- a per-script caller audit, including what tests pin;
- delete only when no surviving skill *executes* it (a doc mention is not an execution).

## 4. Migration and compatibility

- **Existing layout-2 vaults (built by classic):** still READ. `scripts/_lib/vault_md.py` keeps
  resolving layout-3 → layout-2 → legacy, and emit-* keep working. To build or sync on them, the
  front door proposes the existing one-timer `/mega-sdd:migrate-paths --vault-layout=3` (layout-2
  → `context.md`, then a mandatory full JIT re-bind). It never runs it silently.
- **`lane: standard` in config:** no longer selects a chain. The front door says so in one line
  and proceeds with lite.
- **`--classic`** (the spine flag): removed. The front door names the removal in one line and
  ignores the flag.
- **Legacy rebuild** (extract → KB → build): `plan --kb=<kb-dir>` reads `README.md` +
  `modules/*.prd.md` as its source, one module at a time (plan already self-slices per module).
- **Commands:** unchanged (the 6 files). No command is removed, so the demotion ladder for
  commands is untouched.
- **Removed skills:** the plugin contract allowed their removal "in 9.0 after a usage review". The
  three benchmark blocks are that review.

## 5. Phases

| phase | scope | exit criteria |
|---|---|---|
| **P1** (this change) | Relocate contracts → delete the 4 classic skills → state engine + orchestrate-flow + front door on one pipeline → `plan --kb` → tests pruned/updated → docs, contract, CHANGELOG, 9.0.0 | full suite green; `claude plugin validate` passes; complexity budget lowered to measured values; no surviving file references a removed skill path (grep check, pinned by a test); **extract-intelligence → `plan --kb` path pinned by a test**; the result contract (AC→test table, delivery-check PASS, assumptions) is stated identically in every lane's procedure |
| **P1b** | Script / reference pruning audit (executed-by-a-survivor rule) | the same checks. `scripts_total_lines` lowered |
| **P2** | Inline execution for guarded: `execute-bolts` runs units in the main session with the script gates (acceptance, postflight, whitelist, delivery-check) and NO per-unit implementer/panel subagents. Panel opt-in via `--panel` | brownfield block, n=3: inline vs current guarded vs vanilla. Adopt as default only if AC / Critical / regressions are not WORSE than current guarded |
| **P3** | Remove what P2 made dead (review agents, panel scripts, dispatch gates) only if P2 was adopted | the same checks + a lower budget |

**Rollback:** each phase is a separate commit on the branch. A phase is reverted with `git revert`;
there is no data migration that `git revert` cannot undo, because vault layout-2 reading is kept.

## 6. What this design deliberately does not do

- **It does not remove the vault or the audit trail.** Teams that need traceability keep
  `--guarded`.
- **It does not claim any quality gain for guarded.** The three blocks say there is none, and the
  README and contract must say that.
- **It does not delete a gate on assumption.** P2/P3 remove execution machinery only against a
  measurement.

## 7. P1 design decisions

These come from the reference audit: workflow `classic-removal-reference-audit`, 35 agents, 1,133
verified reference items. About 2,900 of the ~9,550 classic lines survive, relocated. The rest are
deleted.

| # | question | decision | why |
|---|---|---|---|
| 1 | Starterkit Step 7.7 / 7.7.f / render check 12.5 f (deep-scan was the only producer of `starterkit-context.yaml` / `reuse-index.yaml`) | Drop them from `plan`. Keep the legacy-cache readers (validate-unit-spec Check 3, the execute-bolts starterkit slice) | there is no producer left; keeping the step would partly reverse the scan-codebase removal |
| 2 | Framework-pack Hard rules on lite units (12.4.5) | Keep today's lite behaviour: pack rules reach the bolt as the advisory T2 slice. No new machine-checked B1 rules | the change is unmeasured and could add `hard_rule_violated` halts; that is not result-neutral |
| 3 | Multi-squad authoring (squads.yaml, interfaces/) | Retire the authoring. Keep the unit-side squad rules for migrated vaults. `interface_ref_missing` stops naming the deleted template | no survivor produces squads anymore |
| 4 | Guarded brief path; `--scope` retrofit subagent | The front door writes a seed PRD from the brief (unspecified items become OQs) and `plan` asks once. The retrofit subagent is dropped: a PRD without a `scopes:` block is single-scope, with a one-line note | the pre-plan Q&A and the retrofit subagent were process; `--auto` already behaved like this |
| 5 | `plan --reconcile` vs `/mega-sdd:sync` "new units" | Reconcile flips task_type and status and marks superseded units. New requirements go through `diff-vault` → `plan --regenerate`. `commands/sync.md` is corrected | it removes a contradiction between two documents |
| 6 | KB-born vault pins | `prd_path` = `<kb>/README.md`; `prd_sha256` = sha256 of `<kb>/census.json` | census.json changes whenever a legacy source or the extraction changes |
| 7 | Hook edits in P1 | Allowed only for correctness of the surviving path: the scope-flag arm (`plan --scope`) and the predictive arm list. The GateGuard trigger on `context.md` moves to P1b | GateGuard is already inert on layout-3 today, so P1 causes no regression |
| 8 | Scripts that lose their executing callers (make-bound, derive-claims-ledger, derive-binding-json, derive-codebase-map, validate-codebase-map Check 4) | **P1b**. P1 deletes only `compute-lock-digests.sh`. `derive-binding-json.sh`'s marker string never changes while layout-2 is readable | staged deletion; every layout-2 read path stays intact in P1 |
| 9 | A migrated vault with an unresolved CONFLICT | Still blocks until the mandatory JIT re-bind re-verdicts it | invariant #2 |
| 10 | Layout-2 binding grammar docs | Owned by the code (`scripts/_lib/binding_md.py`); the templates are not relocated. resolve-oq's classic `binding.md` walk stays until P1b | nothing un-migrated is stranded |
| 11 | lib-patterns/, starterkit-context-schema producer sections, shared-snapshot-schema | P1b prune candidates | they lost their producer or consumer; pruning them needs its own audit |
| 12 | Migrated layout-2 vaults and the lite plan-coverage FATAL | Exempt when `_meta/archive/layout2/` exists. `plan --regenerate` is allowed on them | classic-born units carry no `prd_source` |
