# Inline execution — the default `execute-bolts` run

Loaded by `execute-bolts` SKILL.md for every run without `--agents` (`--inline` = no-op alias): every unit in THIS session,
no `bolt-implementer` dispatch, no per-unit panel. The CONFLICT gate runs at run start (`derive-exec-plan.sh`) and at each
task's re-bind; `conflict_bypassed` checks every commit against the recorded bindings at the run boundary. Spec v9 §8.5 ((e)).

## Contents

- [(a) Pre-flight and flags](#a-pre-flight-and-flags) · [(b) Up-front bind](#b-up-front-bind) ·
  [(c) Execute](#c-execute) · [(d) Close](#d-close) · [(e) What it gives up](#e-what-it-gives-up)

## (a) Pre-flight and flags

**Applies unchanged** (SKILL.md §Pre-flight checks): 2, 3, 3.5–3.8, 4 (Hard-rule pre-flight scan), 5, 6.
**Does not apply** (`--agents` only): 1, Step 2 model routing, Step 4.5 `build-dispatch-prompt.sh`, the panel and its scripts,
the resolution-verifier, the hook-counted attempt cap, the per-bolt drift check ((e)). 3.9 → (b) + each task's re-bind step.

| Flag | Inline (no `--agents`) |
|---|---|
| a unit id, `--squad=<id>`, `--sprint=<n>`, `--module=<id>` | the set becomes `--units=<ids>` for (b)3; `--sprint=<n>` = `analyze-parallelism.sh --format=json` `waves[n-1]` (1-indexed, never hand-numbered; n outside 1..total_waves = usage error; a `--pending` unit in an earlier wave → halt `sprint_blocked_by`; superseded counts as done, stale does not); `--module=<id>` is passed to (b)1 and (b)3 instead |
| `--parallel`, `--sequential`, `--worktree`, `--per-squad`, `--sprint-checkpoint`, `--review-panel`, `--model-tier`, `--no-escalate`, `--resume` | nothing (one context, plan order; (b) resumes an open run by itself) |
| `--max-retries=N` | a prose cap per task, no hook counts it: a step still failing after N fixes → STOP the run |
| `--dry-run` | (b) runs, the plan is shown, then `--retire --dry-run` (no re-bind) unless (b) resumed an open run; no task starts |
| `--force`, `--no-code-gates`, `--no-full-suite`, `--force-skip-postflight` | refused: a done unit is never re-planned, and the boundary gates need the evidence |

## (b) Up-front bind

**Resume first:** a `<vault>/bolts/_exec-plan-*.md` is the open run until (d)8 retires it — skip (b), continue (c) at the
first task without a `complete` ledger line (built-in `_inline-ledger-*.md`, written with the plan, or superpowers'
`progress.md`); every task done → (d)1, or (d)4 once the built-in ledger has `Close: reviewed` (never a second review).
(b)3 returns an open run (`"resumed": true`), never a new plan (abandon one: retire it). Otherwise (zero model tokens but E3):

1. `bash <plugin-root>/scripts/derive-exec-plan.sh --cwd=<root> --vault=<vault> --pending [--module=<id>]` → `{"pending":[…]}` (not done,
   not superseded, topological). Empty = nothing to execute: say so, stop. Exit 1 = halt `module_blocked_by`: run that module first. Exit 2 = a `depends_on` cycle or usage: fix, re-run.
2. `bash <plugin-root>/scripts/rebind-units.sh --cwd=<root> --vault=<vault> --units=<pending>` with
   the comma-join of `pending[]` (exit 4 = re-bound; 2/3 = fail closed, re-run with `--units=all`).
   Its `gate: FAIL` / `next` are expected here — step 3 decides. `text_pending` > 0: ladder E3
   (`references/jit-bind-and-quarantine.md §E3`) per unit, then `write-unit-binding.sh --cwd=<root>
   --vault=<vault> --unit=<U> --claims=<claims[U]> --verdicts=<file>`.
3. `bash <plugin-root>/scripts/derive-exec-plan.sh --cwd=<root> --vault=<vault> [--units=<ids> | --module=<id>]`:
   - **exit 0** — the plan is at `plan`. Say the quarantine in ONE chat line (`Karantina: U-003
     binding_conflict C-U003-01 · U-004 via U-003`); each `quarantined[]` row goes into the **Karantina**
     table (unit · reason · conflict ids or `via` · the question): `binding_conflict` (`resolve-oq --binding`),
     `quarantine_recorded`, `cross_squad_interface_draft` (the producer squad sets `status: locked`), `binding_stale` (re-bind),
     `depends_on_quarantined`. Not quarantined: `deferred` (the task's re-bind re-verdicts a file an earlier task creates) and `own_wip` (the unit's own WIP).
   - **exit 1 with `halt`** → ALWAYS STOP on `halt.type` (`jit-bind-and-quarantine.md §3.10`); say its `keterangan`:
     **halt `binding_conflict`** → the human picks KEEP_VAULT / KEEP_CODE / SPLIT via `resolve-oq --binding`, then the run
     starts again; `module_blocked_by` → run that module first. **Exit 1 without `halt`**: report the Karantina table, stop.
   - **exit 2** — no readable verdict from a validator: fail closed, fix what stderr names, re-run.
4. `run_base` = the plan's `**Run base:**` sha. Never edit the plan or add a quarantined unit to it.

## (c) Execute

- **The Skill tool lists `superpowers:executing-plans`** → invoke it with the plan path. The plan's Global Constraints override
  its Setup (current branch, main/master included); its `## After the last task` section overrides its Final Review and Finish
  (the last task's brief carries it).
- **Otherwise, the built-in loop**, task by task in plan order: (1) `BASE` = `git rev-parse HEAD`, pasted
  wherever a step says `<BASE>`; read the `## Task N` section and its unit file in full. (2) Work the steps
  in order — the re-bind first, test first, the evidence commit last — comparing every `Expected:` line with
  the real output. (3) Only when `Task done` exits 0, append its line to the plan's `_inline-ledger-<head12>.md`.
  (4) A deviation is a ledgered ruling: `Task N: Ruling: <what> — <why> — <cost if wrong>`. Resume: trust the ledger.
- **Stops** (the halt taxonomy, `jit-bind-and-quarantine.md §3.10`):
  - `hard_rule_violated`, an OQ P1 business question → STOP THE RUN (one-screen halt).
  - A CONFLICT at a task's re-bind (not one marked `own_wip`: this task's own uncommitted create target, untracked with its
    provenance header, at a resume) → `write-unit-quarantine.sh --halt=binding_conflict --dependents=<skipped>`, skip every
    task whose **Depends on** reaches it, continue. Any other DEFER-class halt on a unit with NO commit yet → the same.
  - A unit whose commit already landed is never quarantined: fix it forward, or stop the run.
  Committing a stopped unit's work fails `conflict_bypassed` at the boundary.

## (d) Close

With superpowers, steps 1–3 run inside executing-plans (the plan's `## After the last task`); the built-in
loop runs them here. Both then run 4–9 in order.

1. `bash <plugin-root>/scripts/run-full-suite.sh --cwd=<root> --base=<run_base>` → green `_batch-suite.json` (RED → **halt `batch_suite_red`**).
2. **ONE blind review of `run_base..HEAD`** — no commit since `run_base` (review-package's
   `empty commit range`) = nothing to review: go to 4. Without superpowers: ONE `general-purpose`
   Agent on the most capable model, with this prompt (fill every `<…>`):

   ```
   mega-sdd-trace:execute-bolts
   You are a blind code reviewer. Review commit range <run_base>..<HEAD> in <root>
   (git -C <root> diff <run_base>..<HEAD> -- . ':(exclude).mega-sdd' ':(exclude)docs/mega-sdd').
   Spec: <vault>/context.md · units: <in-scope unit files> · PRD: <prd path, if named>.
   Out of scope (quarantined, a human decides them): <the Karantina units>.
   Review Focus — check each one deliberately: <the plan's ## Review Focus lines, verbatim>
   You get no ledger and no implementer reasoning: judge the code against the spec only. Return
   every finding as Critical, Important or Minor, with file:line, what a user would hit, the fix.
   ```
3. **Every Critical and Important finding** is fixed in ONE pass, RED→GREEN: a fix of one unit is `fix(U-XXX): …` with its
   trailers inside its `target_files`, then its `run-acceptance-tests.sh` and `run-postflight-scan.sh` again and its evidence
   committed again; a cross-cutting `fix(review): …` touches no path an in-scope unit's `## Hard rules` protects nor a
   quarantined unit's target (else attribute it). A quarantined unit's finding is ruled out by construction, any other
   unfixed one in the report with its reason; Minors are deferred. There is no second review.
4. Append `Close: reviewed` to the built-in ledger (a resume continues here); `delivery-check.sh` must print
   `VERDICT: PASS` (SKILL.md §Hand-off).
5. A commit landed since step 1 → `run-full-suite.sh --cwd=<root> --base=<run_base>` again.
6. **Close re-bind, then run evidence:** `derive-exec-plan.sh --cwd=<root> --vault=<vault> --rebind-wip` re-binds every unit
   whose binding holds an open `own_wip` CONFLICT (`rebound`: a done unit re-reads CONFIRMED; `text_pending` > 0: ladder E3
   now). **Exit 1** = a CONFLICT it left (`halt.scope: close`, recorded as a `Close: halt` ledger line, so a re-run stops
   again): halt `binding_conflict`, the human decides it (`resolve-oq --binding`), then this step again. Then
   `git add -- <vault>/bolts` and commit `chore(sdd): evidence run <run_base7>` (skip when `.mega-sdd/` is not versioned).
7. **Run-boundary gate** — after the last commit; must exit 0:
   `bash <plugin-root>/scripts/validate-bolt-artifacts.sh --cwd=<root> --orphan-scan --batch-suite-gate --postflight-scan --recompute --whitelist-scan --acceptance-scan --conflict-bypass-scan`.
   A FAIL is fixed per each state's `next_action`, never reported as done. `conflict_bypassed` = a unit
   committed past an open CONFLICT or a quarantine (a re-bind never clears it: `resolve-oq --binding`, or the
   human releases it), or on a tree its bound claim did not hold (`rebind_skipped`: re-bind, a human decides).
8. **Retire the run:** `derive-exec-plan.sh --cwd=<root> --vault=<vault> --retire` removes plan, ledger, superpowers workspace
   (the next run plans fresh, a resolved quarantine gets its turn). It repeats 6's re-bind as a backstop: `rebound` non-empty
   (6 was skipped) → commit `chore(sdd): evidence re-bind`, then 7 again; exit 1 as in 6, nothing retired. Exit 2: fix stderr.
9. Report the result contract as SKILL.md §Hand-off, plus the Karantina table, every ledgered ruling, the
   review findings and how each was closed, and the deferred minors.

## (e) What it gives up

- **Per-dispatch hook legs.** The `--agents` path re-checks each unit at its dispatch: the CONFLICT
  gate, binding freshness, the F-18 gate (`acceptance_expects_missing`) and the attempt cap. Inline
  runs the CONFLICT gate and freshness once at run start, the re-bind per task as a plan step, and no F-18
  check; a commit past a CONFLICT, or past a skipped re-bind whose claim did not hold, is caught at the boundary.
- **The per-bolt drift check** (`halts-and-handoff.md`): no task runs it, so `bolt_introduces_locked_drift` cannot fire;
  the chain-end `detect-drift` auto-gate (standalone: the hand-off suggests it) is the backstop.
- **The per-unit panel and L0 enforcement.** One blind review replaces the panel; `run-code-gates.sh --write` runs per task,
  but no gate checks its `l0-results.json`. No gate checks a `fix(review)` / `fix(delivery)` commit against the touched units'
  `## Hard rules` (B1 judges a unit's own commits) — the same exposure as the `--agents` path's delivery fix; (d)3's rule is prose.
- **Threat model.** The gates catch an honest controller's slips: it forgets a quarantine, resumes after a compaction, re-runs,
  re-plans, or a later run re-binds a unit it already committed. They do not defend against deliberate evasion — backdated author
  dates, deleted or moved evidence, mislabelled commits, a blocked unit's change hidden in another unit's commit on a shared file.
  The `--agents` path has the same limit (a controller can write code without dispatching); evasion is out of scope for both.
- **Why the default.** The §8.4 block (`research/2026-09-28-p2-inline-results.md`, brownfield, n=3 per arm): AC, Critical,
  Important, traps and regressions all not WORSE than `--agents`, `conflict_bypassed` PASS every run, cost BETTER. No claim vs vanilla.
