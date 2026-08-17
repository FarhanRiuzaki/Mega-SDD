# Advisor scope gate — P3 of the token-lard cuts (v6.15.0)

**Status:** DRAFT
**Decision:** USER-DECIDED 2026-08-17 (AskUserQuestion, option "Scope: KB/CONFLICT lane saja") — the P3 item of the pemangkasan audit. Evidence at decision time: advisor = the most expensive default-on pass in the pipeline (measured ~91–157k input tok per dispatch across 7 runs, all opus); its catch class (false-CONFIRMED → fail-safe CONFLICT) is real but field findings-per-bind was unmeasurable (the 7 runs' playgrounds are gone). The user chose scoping over instrument-first / tier-down / keep.

## Design

`bind-codebase` Step 2.12 (the phase-advisor pass) gains a deterministic **scope gate**, evaluated BEFORE `build-advisor-bundle.sh`, from inputs that all exist at 2.12 time (the draft verdict set + the KB probe result):

**Run the advisor iff ANY of:**
1. **KB lane** — a knowledge base was resolved for this bind (probe hit or `--kb=`, and not `--no-kb`): the legacy/rebuild lane the advisor was strongest in.
2. **≥1 draft CONFLICT** — the bind already surfaced contradiction; the advisor's `false_conflict`/`state_map_error` flags and second-opinion are warranted.
3. **≥1 non-NEW draft claim** — any claim whose Implementation-State-Map draft state ∈ {IMPLEMENTED, PARTIAL_*, UNKNOWN}: existing-code evidence exists that could be **falsely CONFIRMED** — the advisor's core catch class.

**Else skip** — the bind is all-NEW greenfield (nothing to falsely confirm, nothing to contradict): record the audit-log provenance
`advisor: skipped (scoped — all-NEW greenfield bind: conflicts=0, non_new_claims=0, kb=none)` — the zeros are ASSERTED over the FULL draft set (a skip can, by construction, only print zeros; the line is an auditable claim that the condition held, and its frequency is the field counter).

**Honest delta from the chosen option's wording:** the option said "mayoritas klaim NEW" — implemented as **ALL-NEW** (strictly fewer skips): a bind with even one IMPLEMENTED/PARTIAL/UNKNOWN claim still gets the advisor, because that one claim is exactly a false-CONFIRMED candidate. Fail-safe beats extra savings; recorded here so the narrowing is on the record.

**Flags:**
- `--advisor` (NEW) — force the pass on a scoped-skip bind (escape hatch; the mirror of `--no-advisor`). Both flags together → error (contradiction, refuse to guess).
- `--no-advisor` — unchanged (skips regardless of scope; lean profile unchanged).

**Unchanged:** the intent-side advisor leg (generate-intent), the advisor's materialization contract (HIGH → CONFLICT, MED/LOW → OQ, never auto-downgrade), model tier (opus per `references/model-tiers.md`), the `advisor: {model, findings:{high,med,low}}` audit-log line on runs (which remains the findings-per-bind record for future evaluation), `advisor: unavailable` on agent error.

## Why prose-gate, not hook

The advisor dispatch itself is prose-driven (Skill body instructs the Agent call); its scope gate belongs at the same tier (gates > rules > hooks — don't grow the hot-path PreToolUse surface for an advisory pass). The audit-log line with REAL counts makes the skip mechanically auditable post-hoc (analyze surface), which is the enforcement proportionate to an advisory-pass scope rule.

## Savings (honest form)

Express greenfield-ish binds (all-NEW) skip a measured ~91–157k-input-tok opus dispatch. Brownfield/KB/CONFLICT binds pay it exactly as before. Field frequency of all-NEW binds is not yet measured — the audit-log provenance line is the counter going forward.

## Tests

NEW `tests/phase-advisor/test-advisor-scope-gate.sh`:
- Step 2.12 carries the scope gate with ALL THREE run-triggers (KB, draft CONFLICT, non-NEW claim) + the all-NEW skip;
- the skip provenance shape carries real counts (`conflicts=`, `non_new_claims=`, `kb=`);
- `--advisor` force flag documented + contradiction with `--no-advisor` refused;
- fail-safe wording present (one non-NEW claim → advisor runs);
- the existing pins survive: `test-bind-advisor-wired.sh` + `test-provenance-states.sh` run unmodified.

## Ship
v6.15.0 — bind-codebase skill version bump, CHANGELOG, manifests parity, both-tree suite, CI, stamp, memory.

## Round amendments (blind reviewer, all folded — on the record)

- **M1 (the sharpest):** `express-bind.md` still mandated "2.12 advisor pass: unchanged and NOT skipped" — a live contradiction ON THE DEFAULT LANE, exactly where the savings live. Folded: the express ref now states the scope gate applies identically in both lanes ("express changes retrieval, never the advisor contract"); the `--express` flag text likewise.
- **M2:** orchestrate-flow's "advisor legs stay DEFAULT-ON on every spine" updated to the scope-gated reality (intent leg unconditional; bind leg gated; `--lean` unchanged).
- **M3:** the gate input was ambiguous on a `--paths` claim-scoped re-bind (fresh-only reading would skip past carried IMPLEMENTED claims AND print a false `non_new_claims=0`). Folded: the gate reads the FULL set — fresh AND carried-forward — in both SKILL and `binding-contract.md`.
- **M4:** the documented `--advisor` flag could not ARRIVE through the front door (translation law silently drops unknown flags). Folded: forwarded-verbatim rows added to `commands/mega-sdd.md` (argument-hint + §Flag handling) and `orchestrate-flow §Flags`.
- **M5:** two test arms were mutation-proven vacuous (a4 matched Step 2.5's state list; d2 matched an unrelated "contradicts → CONFLICT"). Folded: arms pinned to gate-paragraph literals; two new arms (b3 full-set input, b4 distinct scoped form).
- **M6:** the provenance taxonomy (`advisor-findings-schema.md` + the SKILL enumeration) omitted the scoped-skip form — the very counter this spec depends on. Folded: TWO distinct skip forms recorded (opt-out vs gate decision).
- Minors: counted-zeros wording made honest (asserted, not "real numbers"); the contradiction refusal got a typed blocker (`bind_inputs_missing`/`flag_contradiction`); the test's cross-suite arms made cwd-independent.
- Reviewer-noted residual, accepted as spec-inherent: a bind that MIS-classifies existing code as NEW (`missed_match` class) also skips its reviewer — the trade the user chose; the counted skip line is the instrument that will surface it if it happens in the field.
