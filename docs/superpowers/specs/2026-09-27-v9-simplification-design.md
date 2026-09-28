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
| **P1** ✅ done 2026-09-27 (commit 6727b30f) | Relocate contracts → delete the 4 classic skills → state engine + orchestrate-flow + front door on one pipeline → `plan --kb` → tests pruned/updated → docs, contract, CHANGELOG, 9.0.0 | full suite green; `claude plugin validate` passes; complexity budget lowered to measured values; no surviving file references a removed skill path (grep check, pinned by a test); **extract-intelligence → `plan --kb` path pinned by a test**; the result contract (AC→test table, delivery-check PASS, assumptions) is stated identically in every lane's procedure |
| **P1b** ✅ done 2026-09-27 (−1,531 script lines, −102 hook lines, −11 reference files) | Script / reference pruning audit (executed-by-a-survivor rule) | the same checks. `scripts_total_lines` lowered |
| **P2** ✅ adopted 2026-09-28 (§8.5) | Inline execution for guarded: `execute-bolts` runs units in the main session with the script gates (acceptance, postflight, whitelist, delivery-check) and NO per-unit implementer/panel subagents (the default since §8.5; `--agents` = the per-unit path; `--inline` a no-op alias) | brownfield block, n=3: inline vs current guarded vs vanilla. Adopt as default only if the five quality metrics of §8.4 are not WORSE than current guarded |
| **P3** in progress 2026-09-28 (§8.6; P2 adopted in §8.5) | Remove what P2 made dead (review agents, panel scripts, dispatch gates) only if P2 was adopted | the same checks + a lower budget |

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
| 13 | How the plan-coverage gate decides that a PRD heading needs no unit (decided after the 9.0 verification) | **Declared coverage.** Every anchor of the PRD — an H1-H3 with text of its own or no sub-heading; the sub-headings (H4 too) of a text-less heading that has them; the text before the first heading (parsed as CommonMark does; unique slugs `x`, `x-1` …) — must be one of: named by a unit's `prd_source`; bound by an open, deferred or out-of-scope OQ through `[covers: <prd>#<slug>]` (the only OQ route — round 5 showed quotes and `§` citations covering whole features by accident; a resolved OQ covers nothing); or listed in `context.md ## Coverage exclusions` with a real reason (not a placeholder, not a pending decision), one line per anchor. The gate no longer guesses whether a heading is "meta" or "out of scope". `--kb` keeps only the plugin's own KB-template sections. The gate reads markdown only (a non-`.md` PRD gets a rendition first). The state holds one entry per vault, bound by a digest to its sources, exclusions, OQs and units and to the sources the vault pins; the execute-bolts preflight and analyze refuse a missing, FAIL or stale entry | the heuristic classifier did not converge. Three adversarial rounds each found 2–3 new HIGH findings in both directions (a requirement dropped silently / a non-requirement blocking the plan), every fix produced the opposite error, and the script grew from 182 to 588 lines. Declared coverage turns a silent omission into a visible, reviewable decision, and lets a false block be cleared in one line |
| 1a | P3 amendment to 1: the execute-bolts starterkit slice | Deleted with the dispatch-prompt builder (`starterkit-enrichment.md`). The other legacy-cache readers stay: validate-unit-spec Check 3, conformance, GROUND Guard 7, emit-agents-md and the resolver. execute-bolts passes the `starterkit_context` hand-off block through without reading it at execution time | the slice was injected only into the per-unit dispatch prompt, and P3 removes that prompt (§8.6) |
| 2a | P3 amendment to 2: framework-pack rules at bolt time | No slice is injected any more, so pack rules no longer reach the bolt. They reach execution only as plan-authored Hard rules and the pack-driven gates. Still no new machine-checked B1 rules | the advisory T2 slice was built by the per-unit builder, which P3 deletes. This is a recorded loss (§8.6 G4, G6), not a measured one |
| 3a | P3 amendment to 3: `--per-squad` | Retired as a proposal: orchestrate-flow no longer offers `execute-bolts --per-squad --agents`. The flag text stays in execute-bolts, inert because it is scoped to `--agents`, until P3b retires the fan-out flags. The unit-side squad rules and `--squad=` validation stay | per-squad dispatch existed only on the per-unit agent path |

Rows 1a–3a were added by P3 (2026-09-28, §8.6). Each one replaces the part of row 1, 2 or 3 that
it names.

## 8. P2: lean inline execution for guarded, built on superpowers (owner choice 2026-09-27: "P2 ramping")

**Why.** The P2 design workflow (`v9-p2-superpowers-design`: 4 readers, 3 variants, a 3-judge panel,
a synthesis and an attack) found two things.

First, the guarded pipeline's extra defects are fragmentation defects: work split into per-unit
subagents leaves cross-cutting pieces unowned.

| defect | pipeline runs | single-context runs |
|---|---|---|
| no `npm test` script | 7/7 | 0/11 |
| page unreachable from navigation | 7/7 | 0/11 |
| leftover scaffold content | 6/7 | 0/11 |
| clinic: build fails with an empty env | 3/3 | 0/7 |

Second, the per-unit review panel flagged problems, but 213 of its 217 Important findings were mapped
to advisory and never fixed.

The full-fidelity synthesis kept every per-dispatch gate 1:1 through new handshakes, markers and
receipts. The attack returned about 30 fixes. The owner chose the lean variant instead: the
per-dispatch CONFLICT gate it would have preserved fired 3 times on the brownfield block, all false
positives, and caught none of the seeded contradictions.

### 8.1 Flow (`execute-bolts --inline`; the guarded default only if §8.4 passes) (adopted, §8.5)

1. **Bind every unit up front** (script, 0 model tokens): `rebind-units.sh --units=all` →
   `validate-handoff-binding-units.sh --units=all`. A unit with an open CONFLICT is QUARANTINED for
   this run, together with its dependents. If every unit is blocked, the run halts with
   `binding_conflict` and a keterangan. CONFLICTs route to `resolve-oq --binding` as before.
   *Implementation (`scripts/derive-exec-plan.sh`):* the gate applies the per-dispatch predicates —
   the validator, an open or unparseable per-unit CONFLICT, a recorded `quarantine.json`, the
   dispatch gate's freshness function (`freshness.gate_check`, a missing binding included) and the
   dependents. The bind is scoped: `rebind-units.sh --units=<pending>` (the not-done units,
   `derive-exec-plan.sh --pending`) and the validator runs `--units=<candidates>`. "Every unit
   blocked" halts `binding_conflict` only when a quarantine is a `binding_conflict`; otherwise the
   run exits 1 with `halt: null` and the Karantina table. An `fs_must_exist` CONFLICT on a file an
   in-scope ancestor creates is deferred, not quarantined: an up-front bind cannot see a file an
   earlier task will create, so every task starts by re-binding its unit (the per-wave JIT bind of
   the default path, as a plan step); a CONFLICT there quarantines the unit
   (`write-unit-quarantine.sh`) and skips its dependents. An `own_wip` CONFLICT (the unit's own
   uncommitted create target — untracked, carrying its provenance header — seen at a resume) quarantines
   nothing; once the unit is done its next re-bind re-verdicts it CONFIRMED. No run record is written: the
   run-start verdict lives in the bindings and quarantine files the boundary re-reads.
2. **Execute in ONE context:**
   - **superpowers present (`executing-plans` available):** a generated plan
     (`bolts/_exec-plan-<head12>.md` plus its built-in ledger, from the units in `depends_on` order) runs
     through `superpowers:executing-plans`. The plan is the open run until the close retires it
     (`derive-exec-plan.sh --retire`): a compaction, a re-run of the up-front bind or a new session gets
     it back (`resumed`), never a new plan, so the run base and the ledger survive.
   - **superpowers absent:** the built-in inline procedure (`execute-bolts/references/inline-run.md`)
     does the same.
   - **Per unit:** read the unit, implement it, write and run its `acceptance_test`, and commit with
     the canonical trailers (`Unit: U-XXX`, `SDD-PROVENANCE`, `SDD-Acceptance: v5`).
   - **Right after each commit:** the existing evidence writers `run-acceptance-tests.sh` and
     `run-postflight-scan.sh` run, and a short `bolt-report.md` is written.
   - **Nothing is dispatched per unit:** no subagent, no panel.
3. **Close the run:**
   - `run-full-suite.sh` writes `_batch-suite.json`;
   - ONE blind review subagent reviews `base..HEAD`, and its prompt carries
     `mega-sdd-trace:execute-bolts`. Every Critical and Important finding is fixed, or ruled out in
     the report with a reason;
   - `delivery-check.sh` must print PASS;
   - the plan's `## After the last task` carries these steps, so the last task's brief (what a compacted
     controller reads) overrides executing-plans' own Final Review and Finish;
   - the run-boundary gates pass, the run is retired, and the result contract is reported.
4. **Run-boundary gates (deterministic, existing + one new leg):**
   - existing: B1 postflight (recomputed), B2 batch-suite, B3 whitelist, B4 acceptance, orphans
     (every unit commit has its `bolt-report.md`);
   - **new: `conflict_bypassed`** (`validate-bolt-artifacts.sh --conflict-bypass-scan`, body
     `_lib/conflict_bypass.py`). A commit is judged against the CONFLICT state it landed under.
     `write-unit-binding.sh` keeps each CONFLICT claim's onset (`conflict_since`, keyed by kind +
     expect, never the positional id) across re-binds, and moves every CONFLICT a re-bind closes into
     an append-only `conflict_history` (since, closed_at); a human resolution ends an episode, and
     `--resolve` also decides a closed one. A unit commit that landed inside an unresolved episode,
     after its `quarantine.json`, or while a `depends_on` ancestor was so blocked and not yet
     implemented (done by its evidence, first commit before the block), fails the gate at the next
     `execute-bolts` entry and in the Stop hook. So does a unit whose first commit landed on a tree
     where a claim its binding holds did not hold, when no bind saw that tree (`rebind_skipped`: the
     task's re-bind was skipped). A claim that already held in the tree the commit landed on is not a
     bypass: a deferred `fs_must_exist`, and an `own_wip` ALREADY_EXISTS whose target was absent before
     the unit's first commit (a mid-task resume) — never a user's untracked file. Identity is the
     validators' `unit_of`; times are author times; an unparseable binding of a bolted unit fails closed.

### 8.2 The moat change, stated plainly

- **Before:** the CONFLICT block fires at each unit's `bolt-implementer` dispatch.
- **P2 inline:**
  - the block fires at run start, when the unit is quarantined before any work;
  - it is re-checked at the run boundary by `conflict_bypassed`, a deterministic detect-after in the
    same topology the B1–B4 gates already use.
- **What is lost:** the hook on the mid-run re-bind of later units after earlier units moved the
  code. Each task re-binds its unit as a plan step (prose). `conflict_bypassed` checks every commit
  against the recorded bindings: a commit past a CONFLICT that re-bind records, and a skipped re-bind
  whose claim did not hold on the tree the unit landed on (`rebind_skipped`). It does not re-bind at
  the boundary, so a skipped re-bind whose claims all still held stays invisible (and harmless).
- **Threat model (normative).** The gates catch an honest controller's slips: it forgets a
  quarantine, resumes after a compaction, re-runs, re-plans, or a later run re-binds a unit it
  already committed. They do not defend against deliberate evasion — backdated author dates, deleted
  or moved evidence directories, mislabelled commits, a blocked unit's change hidden inside another
  unit's commit on a shared file. The per-dispatch path has the same limit: a controller can always
  write code without dispatching. Evasion is out of scope for both paths.
- **No flag kept today's per-dispatch path** while P2 was opt-in; since §8.5 the default is inline and
  `--agents` keeps the per-dispatch path until P3 decides whether to delete it. `conflict_bypassed` reads git and the bindings, not the mode, so it also
  guards that path: a unit committed past its own open CONFLICT or quarantine (a hand
  implementation the dispatch gate never saw) fails it there too. A normal `--agents` run never trips
  it (the dispatch gate blocks first). The per-dispatch path is therefore not byte-unchanged: it gains
  this leg at the Skill entry and each dispatch.

### 8.3 What changes and what is deleted

- **P2 changes:**
  - `execute-bolts` gains `--inline`, plus the `inline-run.md` reference and the plan generator;
  - `validate-bolt-artifacts.sh` gains `conflict_bypassed`;
  - the one-review close.
- **P2 deletes nothing.**
- **P3, only if §8.4 adopts inline, deletes the per-dispatch machinery:**
  - the per-unit panel lenses;
  - `resolution-verifier`;
  - `merge-panel-findings.sh`;
  - attempt-cap;
  - the per-dispatch hook legs;
  - `build-dispatch-prompt.sh`'s per-unit path, if nothing else uses it.

### 8.4 Measurement (locked before any run)

- **Fixture:** `fixture-brown` @ `015ecf3`, the Harbor Clinic app plus PRD v2 with 7 seeded traps.
- **Arms:**
  - `guarded` (the batch arm name; `guarded-agents` in earlier drafts): the per-unit subagent +
    panel path, from the same P2 snapshot;
  - `guarded-inline`: P2;
  - `vanilla`: the existing clean vanilla runs 2–4, plus one same-day vanilla run as a drift check.
- **Runs:** n=3 clean per guarded arm, in seeded random order.
- **Metrics (spread shown next to every median):**
  - AC, Critical / Important, rubric (blind scorer);
  - traps surfaced (`trap-judge.py`);
  - v1 regressions;
  - delivery-check;
  - `conflict_bypassed` = 0;
  - time, cost, tokens, subagents, committed `.mega-sdd` lines.
- **Decision rule:** adopt `--inline` as the guarded default when, against `guarded`,
  **all five hold**:
  - AC not WORSE;
  - Critical not WORSE;
  - Important not WORSE;
  - traps surfaced not WORSE;
  - regressions not WORSE.

  Cost and time are reported, never traded against a quality loss. If any quality metric is WORSE,
  `--inline` stays opt-in and P3 does not run.

### 8.5 Outcome (2026-09-28)

The §8.4 block ran as locked (`benchmarks/runbooks/p2-inline-vs-agents.md`; results
`research/2026-09-28-p2-inline-results.md`, brownfield, n=3 clean per guarded arm). All five quality
metrics are OVERLAP (AC 13 vs 13, Critical 0 vs 0, Important 0 vs 0, traps 5/5 ×3 in both, v1 suite
73/73 ×3 in both) and `conflict_bypassed` PASS in every run, so the decision rule adopts inline:

- **The flip:** on a layout-3 vault `execute-bolts` runs `references/inline-run.md` by default.
  `--agents` keeps the per-unit `bolt-implementer` + review-panel path (the per-dispatch CONFLICT
  gate with it) until P3 decides its deletion. `--inline` stays an accepted no-op alias (the front
  door, orchestrate-flow, the `guarded-inline` batch arm and older docs pass it). Invariant #2 now reads:
  the run-start gate plus `conflict_bypassed` by default, the per-dispatch gate under `--agents`.
- **What it supports:** the same quality as the per-unit agent path on this fixture at about 60% of
  the cost ($25.08 vs $42.45 median, ranges disjoint) with 3 subagents instead of 70. Nothing against
  vanilla: both guarded arms stay WORSE than vanilla on time, cost and tokens at equal quality, so
  guarded stays opt-in and the router default is unchanged.
- **The one residual it found:** guarded-inline-2 ended with an open `own_wip` CONFLICT on U-011's own
  test file, because no re-bind ran after the unit was done. The close now runs
  `derive-exec-plan.sh --rebind-wip` before the run evidence commit, so that commit carries the
  re-bound `binding.json` and the run-boundary gate sees it: it re-binds every unit whose binding still
  holds an open `own_wip` CONFLICT, reports them (`rebound`), and exits 1 (`scope: close`) when that
  re-bind leaves any other CONFLICT, writing a `Close: halt` line into the run ledger so a re-run stops
  again until a human decides it. `--retire` repeats the same re-bind and check as a backstop (skipped
  under `--dry-run`) and never retires over such a CONFLICT (`tests/v9/test-inline-lane.sh` m11).
- **Given up on the default path, stated:** the per-bolt LOCKED drift check (`--agents` only; the
  chain-end `detect-drift` auto-gate is the backstop), the hook-counted attempt cap (`--max-retries`
  is a prose cap per task) and per-unit model routing (`--model-tier` / `--no-escalate` need `--agents`).

### 8.6 P3 outcome (skeleton, 2026-09-28; the measured numbers land with the last P3 commit)

**Decision.** On 2026-09-28 the owner decided to run the full P3 (commits C0–C9) and accepted O2.
The plan is `research/2026-09-28-p3-deletion-plan.md`. It was produced by the read-only workflow
`p3-caller-audit` (144 agents: inventory, 9 cluster audits, 135 adversarial refutation checks, a
synthesis) at `4e1cf166`. The only basis for deleting anything is §8.5: inline was non-inferior to
the per-unit agent path on one brownfield fixture, n=3. **P3 claims no speed, cost or quality
gain.** An item the refutation checks refuted stays unchanged. An item that was not refuted but is
coupled to a refuted one moves to P3b as a unit, rather than being half-done.

**`--agents` is retired.** The token is still recognized and still implies `--guarded`. A user who
types it gets the guarded lane they asked for, plus this one line, said once:
`--agents is retired: the per-unit agent path was removed (spec v9 §8.6); running the default inline run.`
It is dropped from the argument-hint, and the `guarded-agents` benchmark arm is deleted rather than
left to record inline runs under an "agents" label. This follows the 9.0 `--classic` pattern.
`--inline` stays an accepted no-op alias. `--model-tier=<role>:<tier>` (extract-intelligence roles)
is unchanged. `--max-retries=N` stays as a prose cap per task, and no hook counts it. The retired
flags are: `--review-panel`, the bare `--model-tier=<tier>`, `--no-escalate`, execute-bolts
`--resume` and `--rollback`. Each one gets its own one-line notice (plan §5). The fan-out flags
(`--parallel`, `--sequential`, `--per-squad`, `--worktree`, `--sprint-checkpoint`) keep their text
in P3. They are inert because they are scoped to `--agents`, and P3b retires them.

**Deletion list (planned; the last commit records what landed).**
- **Agents, 7 of 9:** bolt-implementer, spec-, code-quality-, security-, standards- and
  design-reviewer, resolution-verifier. domain-extractor and claim-verifier stay.
- **Scripts:** `merge-panel-findings.sh`, `resolve-review-tier.sh`, `capture-views.sh`,
  `build-dispatch-prompt.sh`, `validate-dispatch-prompt.sh`. The panel scan in
  `validate-bolt-artifacts.sh` goes, but `--panel-scan` stays an accepted no-op for at least one
  release because open plans on disk still pass it.
- **execute-bolts references:** `review-panel.md`, `context-enrichment.md`,
  `starterkit-enrichment.md`, `bolt-dispatch-prompt.md`, `partial-state-and-saga.md`.
- **Hook legs (`hooks/pre-tool-use`):** the panel-evidence reader, the attempt cap, the wave and
  probe rails, the in-run F-18 and binding-freshness legs, the D24a crash-deny, and the F-09 Agent
  dispatch mapping. The PreToolUse matcher becomes `Skill|Bash|Edit|Write`.
- **Artefacts that are no longer written:** `review-tier.json`, `attempts.json`, `findings.json`,
  `dispatch-prompt.md`, `design-slice.md`, `partial-state.json`, `.bolt-panel-state.json`,
  `.dispatch-prompt-state.json`. Legacy copies on disk stay readable.
- **Tests:** 57 files that pin only deleted code are deleted (8,221 lines, measured at `4e1cf166`),
  after their surviving pins moved in C0.
- **Measured totals:** complexity-budget values, lines and files deleted. *(Filled in by C9.)*

**The moat after P3.** Invariant #2 has one form for every run. The CONFLICT block is the
run-start quarantine in `derive-exec-plan.sh`, plus each task's re-bind, plus `conflict_bypassed` at
the run boundary and on Stop. The per-dispatch gate is removed together with the per-dispatch path.
The §8.2 threat model is unchanged. The moat pins are re-pointed in C6b, never dropped:
`test-bind-codebase-fork` will name the run-start quarantine, and `test-migrated-conflict-blocks` a5
moves to the execute-bolts Skill entry, which still denies `binding_missing`.

**Owner decisions and disclosures.**
- **O1, per-unit trace tag retired.** `mega-sdd-trace:execute-bolts:<unit-id>` loses its only
  emitter (the dispatch-prompt builder), and `docs/gateway-contract.md` records the retirement.
  Every other tag is unchanged: `mega-sdd-trace:execute-bolts` (the inline run's one blind
  reviewer), `:turn`, `:plan`, the skill and lane announce tags, `:assisted-review`, and the
  `mega-sdd-note:` session note.
  *Note for the gateway team:* the `contains "mega-sdd-trace"` filter still catches every mega-sdd
  session, and the per-phase prefix breakdown is unchanged. A breakdown or alert keyed on the
  `:<unit-id>` suffix stops receiving rows, because an inline run dispatches nothing per unit.
  Per-unit attribution is now available only in git (the `Unit: U-XXX` commit trailer), not in-band.
- **O2, accepted.** The panel and L0 obligations on units committed by a legacy `--agents` run stop
  being enforced. Before P3 they could block an inline run through `--panel-scan`, and after P3 no
  remedy script would exist. The CHANGELOG carries this as a release note.
- **O3, disclosed.** The spawn-ceiling pin C8b moves from the Agent payload to the
  `mega-sdd:execute-bolts` Skill entry on the bound fixture. It measured 91 spawns there, above C8's
  90 on the unbound fixture, and stays under the ≤95 ceiling. The ceiling is not raised.
- **O4, disclosed.** A stale `model_tiers.bolt_implementer` or `*-reviewer` key in
  `.mega-sdd/config.yaml` triggers GROUND's existing `[self-resolved] model_tier_unknown` notice on
  every run. The notice never halts, and users will see it until they remove the key.
- **O5, P3b, non-blocking.** The packs cluster decides the fate of the pack sections
  `## Code style`, `## Hard Rules emitted` and `## Security idioms`.

**Honest losses.** The inline arm that §8.5 measured had none of the items below, so its
non-inferiority result already reflects their absence on that fixture. None of them was measured on
its own.
- **G1.** Iron Rules 5/6 and the Context7 consult guidance no longer reach implement time. The
  Context7 guidance survives in the extras `slice-procedure.md` and in `plan`.
- **G2.** Gone: the per-unit trace tag (O1); the per-dispatch freshness, F-18 and attempt-cap legs;
  the `acceptance_test_concern` writer (the FSD label is fixed); and the per-bolt LOCKED drift check
  (`bolt_introduces_locked_drift`) in every mode. The chain-end `detect-drift` auto-gate stays the
  backstop.
- **G3.** `cross_squad_interface_draft` and `module_blocked_by` are still promised (execute-bolts
  SKILL.md, unit-schema, modules-schema) but have no inline implementation. This gap exists since
  P2 and is not caused by P3. P3b fixes it.
- **G4.** Pack rules and the reuse, design and starterkit slices no longer reach any bolt (§7 rows
  1a, 2a). `[LOCKED]` still reaches units through `plan --kb` Hard rules and GateGuard.
- **G5.** No gate reads `l0-results.json`, and SAST WARN findings have no reader.
- **G6.** `modern-baseline.md` and the pack `## Code style` / `## Security idioms` sections have no
  runtime reader.
- **G7.** The T01 lite trace does not trace the inline reference set (about 74 KB). Re-pointing it
  raises the ceiling and needs a `raises` entry, so it is deferred to P3b.
- **G8.** The inline controller has no bounded-probe rule. This is an existing gap.
- **G9.** The fix-proposer prompt carries no `mega-sdd-trace` line. This is an existing gap, and
  propose-and-confirm stays unchanged in P3.

**Deferred to P3b** (each as a unit, each with its own re-audit): the fan-out cluster
(`batch-and-fanout.md`, `squad-subagent.md`, the fan-out flags, `parallel_max`, G3); the halt
vocabulary (emitterless registry rows and their mirrors, the fix-proposer trace); JIT capture
(`derive-unit-claims.sh` wave mode and the `_wave-claims` guard); and the done-rule
(`unit_binding.py` and the dead `vault_layouts` functions).
