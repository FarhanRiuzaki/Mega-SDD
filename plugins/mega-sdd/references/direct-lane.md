# Direct & assisted lanes — build a PRD/brief the way plain Claude Code would

The front door runs `scripts/route-lane.sh` FIRST for a PRD file or a free-text brief. The script
picks `direct`, `assisted` or `guarded` from observable signals (its header lists them). This file
is the procedure for the first two. `guarded` is the spec pipeline (`orchestrate-flow`), unchanged.

**Why these lanes exist (measured, `research/2026-09-27-vanilla-vs-megasdd-results.md`).** On a
greenfield PRD, vanilla Claude Code shipped 12/12 (xs) and 10/10 (clinic) acceptance criteria in
3–30 min for $1–8. The lite and classic pipelines took 2.4–12× longer, cost 8.8–22× more and scored
equal or lower. On a brownfield PRD with seeded spec-vs-code traps the pipeline surfaced the same 5/5
traps as vanilla at 5.2–6.6× the cost (`research/2026-09-27-brownfield-results.md`). So every task
without an existing vault is built here, with no vault, units or `.mega-sdd/` writes. Assisted adds the batched ask — the part of the pipeline that did its job (surfacing).

**Done means `delivery-check.sh` printed `VERDICT: PASS` on your last commit, and its output is quoted in your report.** Not "tests pass locally". The check runs on a fresh checkout, which is where the pipeline's own defects hid. A report without that line is an unfinished run.

## Contents
- Both lanes: the procedure
- Assisted: what it adds
- Escalating to guarded
- What these lanes never do

## Both lanes: the procedure

1. **Announce the lane in one line**, with the fired signals, the way up, and the gateway trace tag
   (`docs/gateway-contract.md`: the lanes write no `.mega-sdd/`, so this tag is the only way the gateway
   sees the session; verbatim, never a variant):
   `lane: direct (signals: none) · naik ke pipeline: /mega-sdd <input> --guarded` `` `mega-sdd-trace:direct` ``
   (on the assisted lane: `` `mega-sdd-trace:assisted` ``).
   No confirmation prompt. The request itself is the go-ahead, as it is for plain Claude Code.
2. **Read the whole PRD/brief.** List every requirement and acceptance criterion / DoD item in
   your working notes, not in a file. That list is the contract you report against at step 6.
3. **Implement in the main session.** Follow the repo's own conventions (`CLAUDE.md`, `AGENTS.md`,
   existing code). Don't dispatch implementer subagents. Plan with TodoWrite if it helps.
4. **Meet the delivery bar.** Every item below was a real defect in a benchmark run
   (`scripts/delivery-check.sh` header):
   - At least one automated test per acceptance criterion. Tests run through the repo's standard
     command: `npm test` needs a real `scripts.test`, so no test file only `node --test` can find.
   - Date/time logic pins its time zone in the code or in the test. It never relies on the
     machine's zone.
   - `build` passes on a fresh checkout with no local `.env`. Required secrets are read and
     validated at request time with a clear error, never at module import or prerender.
   - Every user-facing page is reachable from the app's navigation (or from a link on a
     reachable page), not only by typing its URL.
   - Stay inside the spec. Where it is silent, pick the simplest reversible option and name it at
     step 6.
5. **Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/delivery-check.sh" --cwd=<root>`** after committing.
   Fix every blocking `FAIL`, commit again and re-run until `VERDICT: PASS`. Treat `D5 WARN`
   (unlinked page) as a finding: fix it or say why it is intended. A `SKIP` (non-node stack) means
   run that stack's own test and build commands yourself.
6. **Report in chat, briefly**, and only after step 5 printed `VERDICT: PASS` (quote that line):
   - a table of every criterion with its status and the test that covers it;
   - the delivery-check verdict;
   - every assumption and decision you made;
   - the commits.

   Don't write a report file.

## Assisted: what it adds

Assisted fires on `existing_code`, `spec_open_items`, `security_surface` or `multi_flow`. It
keeps the direct procedure and adds two steps, in this order:

- **Before coding, when the spec has open items:** sort them.
  - A **technical** item is yours to decide: pick, cite why, and list it at step 6.
  - A **business** item (policy, scope, legal, money, who-sees-what) is the human's. Ask them all
    in ONE `AskUserQuestion` (≤4 questions; the rest keep a stated conservative default). Each
    option carries a one-line keterangan; mark the recommended option and include "Defer".
  - Headless (no `AskUserQuestion`): take the most conservative, easiest-to-revert option and
    record it as an assumption. Never invent a business rule.
- **After delivery-check passes: ONE blind review.** Dispatch ONE `Agent`
  (`general-purpose`), read-only by instruction. The prompt carries:
  - the line `mega-sdd-trace:assisted-review`, on its own line (the gateway contract: every subagent
    dispatch prompt carries one trace line);
  - the PRD path and the commit range `<base>..HEAD`;
  - the review scope: unmet acceptance criteria; authorization enforced only in the UI;
    unvalidated input; secrets in code; data-integrity races (double-booking, lost updates).
    Every finding comes back as `severity | file:line | issue`.

  It does NOT get your notes or your criteria table, so it judges the code, not your claims. Fix
  every Critical and Important finding, re-run delivery-check, and commit. Report Minor findings
  without fixing them.

## Escalating to guarded

Stop and offer `/mega-sdd <input> --guarded` (one line, the reason included) when the work reveals
what the router could not see up front:
- the spec contradicts existing code you would have to change;
- the change spans modules someone else owns;
- a business decision blocks most of the work and the human is unavailable.

The user can also force any lane: `--direct`, `--assisted` or `--guarded`. `--lite`, `--inline` and
`--agents` imply guarded; the retired `--classic` forces no lane.

## What these lanes never do

- They don't write `.mega-sdd/` or run `ground.sh`/`derive-state.sh`.
- They don't run `detect-drift`, `analyze`, the HTML renderer, `emit-*`, or a per-unit review
  panel.
- They don't add provenance trailers to commits or code.
- A later `/mega-sdd` PRD or brief on this repo sees ordinary code (`existing_code`) and routes to assisted. The pipeline stays available with `--guarded`.
  That is correct: from then on the spec has something real to be checked against.
