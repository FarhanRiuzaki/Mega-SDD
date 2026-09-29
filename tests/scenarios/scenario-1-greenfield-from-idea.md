# Scenario 1 — Greenfield from Idea

**Time**: ~15–30 minutes (Part A) · Part B takes several times longer
**Goal**: Run mega-sdd end-to-end on a fresh idea (no PRD, no existing code) and get working code with passing tests, plus the result contract every lane ends with.

You'll start with just a sentence ("build a clinic appointment system") and end with committed code, passing tests and a delivery check that says `VERDICT: PASS`.

- **Part A**: the default route. The front door's router sends a clear idea to the **direct lane**, where Claude builds it like plain Claude Code would.
- **Part B**: the same idea on the **guarded lane**, the spec pipeline (`plan` → `execute-bolts`). Use it when your team needs the spec and audit trail: vault, units, per-unit binding and bolt evidence.

## Prerequisites

- Mega-sdd installed ([install check](README.md#before-you-start--install-check))
- An empty directory (Part A). Part B also needs a framework scaffold (Step B1).
- Optional: `ast-grep`. Only the guarded lane uses it (the symbol index); a greenfield run barely needs it.

## Part A — the default route (direct lane)

### Step A1 — Create an empty project dir

```bash
mkdir ~/playground/clinic-app
cd ~/playground/clinic-app
git init
```

### Step A2 — Hand mega-sdd the idea

In a Claude Code session at the new dir:

```
/mega-sdd "build a clinic appointment system for a small medical clinic — patients self-book, doctors view schedules, email reminders 24 hours before appointment"
```

The front door runs `scripts/route-lane.sh` first. It is a read-only script with zero model tokens, and it looks for evidence that the task needs more than plain Claude Code: an existing vault, existing code, open items in the spec, a security surface, several flows. This sentence fires none of them:

```
lane: direct (signals: none) · naik ke pipeline: /mega-sdd "build a clinic appointment system…" --guarded `mega-sdd-trace:direct`
```

There is no chain proposal and no confirmation prompt, and nothing is written under `.mega-sdd/`. The request itself is the go-ahead.

> **Want the question round anyway?** The brief implies staff logins, but it doesn't say so in words the router counts. Add `--assisted` to force the assisted lane: before coding you get ONE batched `AskUserQuestion` for the business decisions, and after delivery ONE blind review of the diff ([Scenario 2](scenario-2-prd-driven-feature.md) walks it).

### Step A3 — Claude builds it in the main session

The procedure is `plugins/mega-sdd/references/direct-lane.md`:

1. Claude lists every requirement and acceptance criterion from your sentence in its working notes. That list is the contract it reports against at the end.
2. It implements in this session. There are no implementer subagents, no vault and no units.
3. The brief is silent on stack, storage and email provider. Claude picks the simplest reversible option for each and records each one as an assumption. It never invents a business rule.
4. It meets the delivery bar, where each item is a defect a benchmark run once shipped:
   - at least one automated test per criterion, run through the repo's standard test command;
   - date/time logic pins its time zone (the 24-hour reminder is exactly this kind of logic);
   - `build` passes on a fresh checkout with no local `.env`, and secrets are validated at request time;
   - every page is reachable from the app's navigation.

### Step A4 — The delivery check

After committing, Claude runs `bash "${CLAUDE_PLUGIN_ROOT}/scripts/delivery-check.sh" --cwd=.` against a fresh copy of HEAD, and repeats fix → commit → re-run until it passes:

```
delivery-check @ 3f9c2e1 (/Users/you/playground/clinic-app)
  D1 PASS scripts.test = vitest run
  D2 PASS npm test (TZ=UTC) exit 0
  D3 PASS npm test (TZ=Pacific/Kiritimati) exit 0
  D4 PASS npm run build on a fresh checkout, empty env: exit 0
  D5 PASS every static page route (4) is linked from another source file
VERDICT: PASS
```

D1–D4 block, D5 is advisory: a `D5 WARN` names a page nothing links to, and Claude fixes it or says why it is intended. On a non-Node stack the check prints `D0 SKIP`, and Claude runs that stack's own test and build commands instead.

### Step A5 — The result contract

The run is reported in chat, briefly, and only after `VERDICT: PASS`. No report file is written. Every lane ends with this same shape (illustrative values):

```
| # | Criterion (from your brief)                    | Status | Test                                           |
|---|------------------------------------------------|--------|------------------------------------------------|
| 1 | Patients self-book an appointment              | ✓      | tests/booking.test.ts › books a free slot      |
| 2 | Doctors view their schedule                    | ✓      | tests/schedule.test.ts › doctor sees own day   |
| 3 | Email reminder 24 hours before the appointment | ✓      | tests/reminders.test.ts › sends at T-24h (UTC) |

delivery-check: VERDICT: PASS (3f9c2e1)

Assumptions & decisions:
- Stack: Next.js + SQLite via Drizzle (brief names none; easiest to swap)
- Email: provider interface + console transport in dev (no provider named)
- Slot length 30 min, clinic hours 09:00–17:00 (brief silent; one constant each)
- One appointment per doctor per slot; a second booking is rejected (brief silent; the conservative reading of "self-book")

Commits: a1b2c3d, 3f9c2e1
```

### Step A6 — Verify it yourself

```bash
git log --oneline
npm test          # or: bun test — whatever scripts.test runs
npm run dev       # open the app, walk the booking flow
```

**Measured, so you know what to expect:** on the benchmark's greenfield PRDs the routed lanes were **on par with plain Claude Code** in time, cost and quality. They were not better. The one thing they add is the delivery check, which plain Claude Code does not run (`research/2026-09-27-lane-router-results.md`).

## Part B — the same idea on the guarded lane (spec + audit trail)

Use this when the team wants the spec and audit artefacts:

- a cited vault;
- atomic units with acceptance tests;
- a binding verdict per unit;
- bolt evidence per commit;
- later, FSD / SIT / UAT documents via `/mega-sdd:emit`.

Be clear about what you are buying. On the greenfield benchmark the pipeline cost 9–22× plain Claude Code and did not produce better code (`research/2026-09-27-vanilla-vs-megasdd-results.md`). What it adds is traceability, not quality.

### Step B1 — Scaffold first

The guarded lane runs on a framework scaffold (the "starterkit"):

```bash
mkdir ~/playground/clinic-app-guarded && cd ~/playground/clinic-app-guarded
bunx create-next-app@latest .     # also runs git init + a first commit; any framework a pack knows works the same way
git log --oneline                 # the baseline commit is there
```

Without a framework manifest, the front door halts `no_starterkit_detected`, with three options: scaffold first, opt in to greenfield, or cancel. `--greenfield` lets `plan` write stack-agnostic units, but `execute-bolts` waits until you scaffold.

### Step B2 — Ask for the pipeline

```
/mega-sdd "build a clinic appointment system for a small medical clinic — patients self-book, doctors view schedules, email reminders 24 hours before appointment" --guarded
```

`plan` takes a PRD, not a sentence, so the front door first writes your brief to a seed PRD at `.mega-sdd/vaults/<slug>/source/seed-PRD.md`:

- your words are kept verbatim;
- there is **no Q&A before planning**;
- every topic the brief leaves open becomes `(unspecified)`, and later an Open Question.

Then you get ONE confirmation for the whole chain:

```
Proposed pipeline (--deep):
  1. plan .mega-sdd/vaults/<slug>/source/seed-PRD.md --vault=.mega-sdd/vaults/<slug> --lite --mode=existing → context.md + units/
  2. execute-bolts --all --lite           → bolts/ (JIT bind per unit → bolts/U-XXX/binding.json) + delivery-check

Halts may re-engage you mid-chain (test failures, business OQ
resolutions, hard-rule violations, dedup ambiguity, recommendation
reviews). Otherwise runs end-to-end silently with progress indicators.

[Run] [Edit] [Cancel]
```

`--mode=existing` because the repo already carries code files: the scaffold's own pages count. The engine picks the mode; you are not asked. It only means `plan` looks each unit up in the symbol index before typing it. Click **Run**.

### Step B3 — Phase 1: `plan` (one phase: vault + units)

`plan` reads the seed PRD once and writes the layout-3 vault into `.mega-sdd/vaults/<slug>/`:

- `context.md` — flows (Mermaid + DoD per flow), data model, constraints, and the one `## Open Questions` home; every row cites its source
- `constitution.md` — the project rules, each clause source-cited
- `vault.json` — the manifest (script-derived, never hand-written)
- `_meta/ai-consumer-guide.md`
- `units/U-*.md` + `units/_index.md` — atomic, PR-sized units, each with `prd_source:` + `context_source:` citations, a `target_files` whitelist and at least one `acceptance_test`. Units that add new files are `task_type: create`. A unit that changes a scaffold file, such as the root layout for navigation, is typed from its symbol-index hit (`extend`, with `## Migration notes`).

Open Questions are sorted before anyone is asked:

- **Technical** OQs are decided by the AI as labelled, cited, reversible choices (`→ **Resolved v<X.Y>** (AI decision, <date>): <pick>`) and listed in the report.
- **P1 business** OQs come to you in ONE batched ask, with at most 4 questions. Each option carries a keterangan line and a recommendation, or "no recommendation — needs stakeholder":

```
OQ-004 [P1] [business]:
  "Which patient-data regulation applies (storage + reminder emails)?"
  (source: seed-PRD §G Regulatory & compliance — (unspecified))

  [1] No recommendation — needs stakeholder
      keterangan: no source in the brief; the AI will not pick a legal regime
  [2] Defer — the units that depend on it stay blocked at bolts
  [3] Out of scope
  — Other: free text (e.g. "GDPR — EU clinic")
```

An answer lands in `context.md ## Open Questions`. A P1 business OQ left unanswered, including every one past the first four, stays `blocking`. Its units stay blocked at bolts and the chain pauses there with `oq_business_p1_unresolved`, so the AI never answers it for you.

```
▶ Phase 1 of 2: invoking plan (.mega-sdd/vaults/<slug>/source/seed-PRD.md --lite --mode=existing)
✓ Phase 1 of 2: plan → status: completed, items: 14 units, blocked: 0
```

Before the next hop, the validators must pass: unit spec, flow coverage, and plan coverage. Plan coverage means every PRD heading has a unit, an open OQ carrying `[covers: …]`, or a `context.md ## Coverage exclusions` line with a reason; a gap halts `plan_coverage_gap`. `plan` emits no handoff YAML, so the front door re-derives state from disk before it dispatches bolts.

### Step B4 — Phase 2: `execute-bolts --all --lite`

Before any task runs, the up-front bind binds every pending unit **just in time** (each task re-binds its unit again before it starts):

- `derive-unit-claims.sh` collects each unit's claims;
- `write-unit-binding.sh` writes the verdicts to `bolts/U-XXX/binding.json`. It is the only writer of that file.

On a fresh scaffold almost every claim is a filesystem check (a `create` target must not exist yet; a modified file must exist), verdicted by the script. A bind with no symbol or free-text claims costs zero model tokens. A CONFLICT would stop only the unit it belongs to: `derive-exec-plan.sh` quarantines it at run start (and skips the units that depend on it).

The units then run in ONE context, one task per unit in the generated plan's order: the task's re-bind, test first, the L0 gates and the detect-after scans (Hard-rule post-flight, acceptance), then its evidence commit. ONE blind review of the whole run range closes the run. Per unit you see two lines:

```
▶ Bolt 1/14: U-001 "Create appointment schema + migration"
✓ Bolt 1/14: U-001 → done in 2m05s, 0 retries, confidence 0.90, anchors 0/0 ✓, commit 8a3f2e1
…
✓ execute-bolts batch complete: 14/14 done, 0 halted
```

The chain ends with the same `delivery-check.sh` as Part A.

### Step B5 — Same result contract, plus the audit trail

The final summary is the Part A contract: the criterion → test table, the delivery-check `VERDICT:` line of the last commit, and the assumptions and decisions. That covers the AI's tech decisions and your answers to the business OQs. On top of it you have:

```bash
ls .mega-sdd/vaults/<slug>/
# context.md  constitution.md  vault.json  source/  _meta/  units/  bolts/
ls .mega-sdd/vaults/<slug>/bolts/U-001/
# binding.json  dispatch-prompt.md  bolt-report.md  acceptance.json  …
git log --oneline      # one commit per unit
```

Tool-agnostic `AGENTS.md` export: say "emit agents.md" (the chain skips it by default). Team documents: `/mega-sdd:emit fsd|sit|uat`.

## Common pitfalls

### delivery-check keeps failing (any lane)

The check runs on a fresh `git archive` of HEAD: untracked files and your local `.env` are not there. Typical failures:

- `D1 FAIL` — `package.json` has no real `scripts.test`, so tests only `node --test` can find don't count. Add the command the tests actually run with.
- `D3 FAIL` — the tests pass under UTC and fail under UTC+14. Pin the zone in the code or the test.
- `D4 FAIL` — the build reads a secret at import or prerender time. Read and validate it at request time instead.

A report without `VERDICT: PASS` is an unfinished run.

### Guarded: `no_starterkit_detected` on an empty directory

Scaffold first (Step B1), or add `--greenfield` to plan stack-agnostic units now and run bolts after you scaffold.

### Guarded: a bolt halts on `test_fail`

The unit's acceptance test still failed after its retry budget (3 by default; 1 on an xs project). Read the bolt report:

```bash
cat .mega-sdd/vaults/<slug>/bolts/U-XXX/bolt-report.md
```

Common causes: the test runner isn't installed, the database isn't migrated, or the test references a file outside the unit's `target_files`. Resolve it, then `/mega-sdd --resume`.

### Guarded: you want to review units before any code is written

Add `--stop-after=plan`. The chain halts after Phase 1; continue with `/mega-sdd --resume`.

## What you learned

- `/mega-sdd` routes first. A clear idea takes the direct lane, which is plain Claude Code plus the delivery check.
- Every lane ends with the same result contract: criterion → test table, `delivery-check.sh` `VERDICT: PASS`, and the assumptions and decisions.
- `--guarded` runs the one spec pipeline, `plan` → `execute-bolts`, with a single batched business ask and a JIT bind per unit.
- The pipeline's value is traceability and audit artefacts, not better code. Choose it for that reason.

## Next scenario

→ [Scenario 2 — PRD-driven feature](scenario-2-prd-driven-feature.md): start from a real PRD file in an existing project.
