# execute-bolts — Step 4.5 tiered context enrichment per bolt

**This file is the SPECIFICATION, not a procedure the model runs.** `scripts/build-dispatch-prompt.sh` (the builder) implements every rule below and is tested against it; the execute-bolts controller only *invokes* the builder (SKILL.md §Step 4.5) and pastes the returned `inline_core` into the Agent dispatch. The canonical numbers — budget constants, the 9-row priority table, the truncation cascade, the halt conjunction — live HERE and nowhere else; change them here first, then the builder, then re-run its fixtures. Where the pseudocode below describes a known defect, it is annotated as such and the builder **reproduces it as written** — do not silently "fix" either side.

Implements the 10 AI-executor principles. Populates the T1/T2/T3 sections of the bolt-subagent dispatch-prompt template (`bolt-dispatch-prompt.md`, listed in SKILL.md). Total dispatch prompt budget ≤9KB target (`cap_target`); the `cap_hard` term of the `dispatch_prompt_too_large` conjunction is 12KB (the progressive T2 budget tracker absorbs most cases first).

## Contents
- TIER 1 (always included)
- T2 budget tracker
- AMENDMENT 2026-07-31 — the cap numbers, from measurement
- T2 section priority + truncation cascade
- Halt path + soft-budget warnings
- TIER 2 (conditional)
- Reuse slice: build
- Symbol slice (3b): build
- Map §6 fallback (starterkit-context absent)
- Design slice: build + inject (INDEPENDENT of starterkit — the greenfield pipe)
- TIER 3 (reference-only)
- Size check
- Builder contract (invocation, exit codes, stdout)
- Log final prompt
- Anti-hallucination rails
- Re-decided amendments (2026-07-31)
- Named backlog
- Known open (carried deliberately)

## TIER 1 (always included — never truncated, and NOT budget-bounded)

> **There is no T1 size target.** The `≤2KB` that stood in this heading was the retired `cap_t1 = 2048`, which the AMENDMENT below measures as never satisfiable — the builder's own non-body T1 scaffolding floors at 2 385 B on a near-empty unit, so the heading's target fired on 123/123 measured runs. `cap_t1` is now **12288** and it is a **REPORTING THRESHOLD, not a bound**: T1 is never truncated and the unit body is embedded verbatim, so no value of `cap_t1` bounds T1. Crossing it is a `generate-units` atomicity smell (a unit too big to be one bolt), not a budget defect. Read `## AMENDMENT 2026-07-31` before quoting any T1 figure.

- Unit body (frontmatter + body sections).
- **Contracts pointer line** (halt / self-report / rollback / provenance / atomic — agent-carried by the bolt-implementer system prompt; one line naming `agents/bolt-implementer.md` + the plugin version at dispatch; see `bolt-dispatch-prompt.md §Contracts`). The constant blocks themselves are NEVER re-embedded in T1.
- **Provenance values block** (per-unit: unit_id, vault sha256, claim ids + texts, anchors, active Hard rules — the values the agent fills into its agent-carried trailer shape).
  - **`claims:` MUST carry the claim ID `C-NNN`, not a confidence label.** Shape: `- C-NNN "<claim text>"`, one line per implemented claim. The agent's mandated trailer is `Implements claim: C-NNN "<claim text>"` and this block is its ONLY sanctioned source (`agents/bolt-implementer.md §Provenance trailer`), so a block that emits `- HIGH "notes"` leaves the agent with two options — omit the id, or back-derive one from `binding_refs`. The second is the fabrication this block exists to prevent, and post-flight only checks that a trailer is PRESENT, so a malformed-but-present trailer passes every gate. The id is available where the claim is resolved; carry it through. The confidence label belongs in the T2 `confidence_labels` section, which is where it already is.
  - `hard_rules_active` carries the rule **TEXT verbatim**, not synthesized ids: unit Hard rules have no ids, and minting them would fork from the B1 engine's identity model (`_lib/postflight_rules.py`). **KEPT after re-decision 2026-07-31** — see §Re-decided amendments.
  - `vault.json` absent → the `vault_sha256:` line is **OMITTED with a warning** and the build proceeds (exit 0). Omission-on-absent-input is the moat's own rule (invariant #5); a recoverable state is not a chain-killer.
  - Same rule for every other value in the block: an absent input drops **its own line**, never the block, and never a placeholder.
- **Header lines:** `UNIT:` always; `SCOPE: <id> (<name>) — framework: <pack>` when the vault carries a scope. With **no scope**, the builder emits `FRAMEWORK: <pack>` on its own line rather than an invented `SCOPE: (none)`.
- Anti-context block (DO NOT MODIFY / DO NOT REPLICATE / DO NOT WRITE / DO NOT COMMIT IF). Each line names its own source; each is omitted whole when its source yields nothing.
  - **`DO NOT MODIFY:` is a LABELLED UNION of two sources, not one substituted for the other.** (a) the `[LOCKED]` entries of `<kb>/99-rebuild-architecture/data-mutation-policy.md` when that file exists — a real artifact: `extract-intelligence` Wave 5 writes it, `generate-intent` reads it, `validate-kb-reengineering.sh` halt-enforces it; and (b) the unit's own `## Hard rules` lines matching `^(DO NOT|MUST NOT|NEVER)\s+modify\s+(.+)`. **Every entry carries the source it came from** (`(source: data-mutation-policy.md §<section>)` / ``(source: U-XXX.md `## Hard rules`)``). Either source absent contributes nothing and is recorded in `sections_omitted`; both absent omits the line. The failure this rule exists to prevent: a legacy-rebuild project whose KB marks `LegacyLedger` `[LOCKED]` in `data-mutation-policy.md`, on a unit whose generated Hard rules do not restate it, ships a bolt that modifies the locked file. Substituting a different source under the original's label is the subtlest form of invariant-#5 breach — the citation is real, the assertion is not.
  - **Status 2026-07-31 (round 4): the labelled union IS implemented, and the table parser is now structural in BOTH directions** — an earlier revision of this bullet asserted in bold that the builder read only (b) and labelled it as the whole line. That assertion is FALSE and is struck: the builder locates `data-mutation-policy.md` under the KB roots, reads both `## Per-locked-field policy` and `## Entity-level summary` with per-table marker semantics, and stamps a per-entry source. The header row is dropped **positionally** — it is row 1, and it is a header because row 2 is the `|---|` alignment row — not by a header-word allowlist; a table headed `| Field | Tier | Policy |` no longer emits `Field` as a locked path. **A round-3 revision of this bullet published that allowlist as an open defect; it was fixed in the same tranche and that text is struck.** The converse is closed too, and it was the round-4 fix: a dash-only FILLER row no longer eats the `[LOCKED]` entry above it (the alignment row is row 2 and nothing else), and any row the parser discards is recorded in `sections_omitted` with a reason. Both directions are rails — inventing a locked path and silently losing one are the same invariant-#5 class. Pinned by `tests/derived-artifacts/test-dispatch-prompt-builder-shape.sh` §W (W1–W9).
- **Acceptance-test provenance NOTE:** if the unit's `acceptance_test._authored_by` is `same-pass` OR `adversarial-review-failed` (weak blind-spot signals per `generate-units/references/adversarial-test-prompt.md`), append a NOTE warning the bolt subagent the acceptance_test may have missed bugs the implementation introduces. The subagent's self-assessment is instructed to flag `acceptance_test_concern: <details>` if the implementation passes the test but feels under-validated. The NOTE template lives in the dispatch-prompt template (listed in SKILL.md).
  - **`_authored_by` MUST be read from the same region as the `acceptance_test` block it belongs to.** `validate-unit-spec.sh` accepts an `acceptance_test:` block in the frontmatter OR in the body, so scanning `acceptance_test` entries across the WHOLE unit file while scanning `_authored_by` in the FRONTMATTER ONLY makes a body-authored strong value read as absent — and "absent" is one of the conditions that FIRES the NOTE. Reproduced: a unit carrying `_authored_by: adversarial-reviewed (+2 gaps merged)` in a body block gets the NOTE anyway, in the same prompt whose verbatim unit body three sections above shows the real value. The subagent is then told to cap `confidence` at MEDIUM and file `acceptance_test_concern` for a test with strong provenance — degrading self-assessment on exactly the units `generate-units` spent adversarial review on. **Rule: locate the `acceptance_test` block first; read `_authored_by` from within that block. Absent there = genuinely absent.**
- **Reuse index path (ALWAYS — even when `reuse_candidates` is empty).** ONE canonical text, resolved 2026-07-31 — this file and `bolt-dispatch-prompt.md §Reuse index` previously carried two different wordings and the builder silently picked one. **The template's wording WINS** (it is the emitted artifact's own shape, and it names Iron Rule 4, which is the agent-side contract the line exists to trigger). Verbatim, three lines:
  ```
  Reuse index: .mega-sdd/codebase/reuse-index.yaml — your PRIMARY reuse lookup
  surface (Iron Rule 4): scan the FULL index with Read/Grep before writing any
  new capability; reuse_candidates below is only a hint.
  ```
  The retired wording ("…The reuse_candidates above are a fast-path hint, NOT the boundary.") is not an alternative — do not reintroduce it, and note it said *above* where the template says *below*, which is the emitted order.
- **`unit.reuse_candidates`** (fast-path hint — include when present; empty list is fine to omit the hint line, but the reuse-index path line above is unconditional).

## T2 budget tracker

Replaces a prior single-halt-at-cap enforcement with running T2 consumption tracking + progressive section-level truncation by priority.

```
running_budget = {
  cap_hard:      12288   # halt-conjunction term (b). UNCHANGED. See the AMENDMENT below.
  cap_target:    9216    # 9KB total target (advisory)
  cap_t1:        12288   # T1 REPORTING THRESHOLD (was 2048 — see the AMENDMENT below)
  cap_t2:        10240   # 10KB T2 budget (walking-skeleton: more context reach over a tight cap)
  consumed_t1:   <bytes of TIER 1>
  consumed_t2:   0       # accumulates during TIER 2 load
  remaining_t2:  cap_t2
  warnings:      []      # truncation events (logged to provenance)
}
```

After EACH T2 section loads, update the tracker: `consumed_t2 += section_bytes`; `remaining_t2 = cap_t2 - consumed_t2`. IF `remaining_t2 < next_section_min_viable_bytes` → apply progressive truncation (below) BEFORE loading the next section. The builder's realization of this is pinned: build every section at FULL fidelity, then walk the cascade one rung at a time re-measuring after each — the only realization reproducible from the table alone.

## AMENDMENT 2026-07-31 — the cap numbers, from measurement

**Scope of this amendment: the NUMBERS in `running_budget` and nothing else.** The 9-priority truncation table with every cascade rung and drop floor, the `starterkit-enrichment.md` 7-rung slice ladder, and the three-way `dispatch_prompt_too_large` conjunction in §Halt path are UNCHANGED by it. An earlier pass rewrote §Size check in the same changeset that made the rewrite necessary — spec loosened to fit an implementation. That edit has been REVERTED (§Size check now reads as it did at HEAD) and this block replaces it: one clearly-marked amendment, justified by bytes.

### What was measured

**n = 123 builder runs — 41 distinct units × 3 context arms** (`U-bare` = `_universal.md` pack only; `L-rich` and `L-max` = the `laravel-base-26 → laravel → _universal` chain with a full starterkit/reuse/memory/constitution set). 41 units = 33 real `U-*.md` fixtures from this tree, 5 extracted from the tranche-2b suites, and 3 CONSTRUCTED to `unit-schema.md`'s documented upper end (10–12 `target_files`, 3–5 `binding_refs`, populated `## Hard rules` and `## Anchors`). Byte decomposition verified byte-exact against the on-disk artifact on all 123 runs; `exit` was 0 and `halt` was `null` on all 123.

**T1 distribution: min 2 666 · p25 4 079 · median 4 741 · p75 5 312 · p90 6 209 · max 10 874.**

> **`consumed_t1 > cap_t1` fired on 123/123 runs (100 %) at `cap_t1 = 2048`.**

The decisive number is the **non-body T1** — total T1 minus the verbatim unit body, i.e. the builder's own fixed scaffolding: **min 2 385 · median 4 378 · max 5 493.** The minimum, 2 385 B, was measured on a 256-byte unit body in the leanest pack arm. That is **1.16 × the shipped `cap_t1` of 2048 with a near-empty unit**. The only configuration that lands under 2048 is a dispatch with no pack chain at all — which is the Windows App-Execution-Alias failure state (§Builder contract, pack-resolver exit codes), i.e. **`cap_t1 = 2048` was satisfiable only when moat content was missing.** It was never a real bound; it was an unmeasured guess that the prose-assembled flow silently violated because nobody was counting bytes.

Decomposition of the maximum (T1 = 10 874 B, `L-rich`, constructed unit): unit body verbatim 5 615 (51.6 %) · anti-context 2 424 (22.3 %, of which the pack `## Forbidden patterns` `DO NOT WRITE:` block is 2 044) · `Provenance values` 1 369 · header 765 · reuse rail + contracts pointer 383 · reuse candidates 318. Every one of those is contract-mandated T1 content. Pack chain alone is worth **1 272 B/unit** (`laravel` chain 2 044 B of `DO NOT WRITE:` vs `_universal` 772 B), independent of the unit.

### The amended numbers

| constant | was | now | why |
|---|---|---|---|
| `cap_t1` | 2048 | **12288** | Observed max 10 874 → 1 414 B (13.0 %) slack. Below the non-body floor (2 385–5 493) no smaller value is satisfiable. |
| `cap_t2` | 10240 | **10240** | unchanged — it is the truncation trigger and the cascade is calibrated to it. |
| `cap_hard` | 12288 | **12288 — UNCHANGED** | raising it destroys halt reachability; see the arithmetic below. |
| `cap_target` | 9216 | **9216** | unchanged, advisory. |

**`cap_t1` is a REPORTING THRESHOLD, not a budget.** Nothing branches on it: it feeds one warning and one report echo. T1 is never truncated and the unit body is embedded verbatim, so *no* value of `cap_t1` bounds T1 — a unit body over ~6.8 KB will still cross 12288. At 2048 the warning fired 28/28 in the cap probe (100 % — pure noise); at 12288 it fires 0/28 on everything measured, and only above ~6.8 KB of unit body thereafter. That residual signal is worth keeping because it is now a **`generate-units` atomicity smell** (a unit too big to be one PR-sized bolt), not a budget complaint.

### `cap_t1 + cap_t2 == cap_hard` is EXPLICITLY RETIRED

That identity (2048 + 10240 = 12288) held by arithmetic coincidence, not by design, and reading it as a constraint is what produced the "zero slack" framing this amendment replaces. `cap_t1` and `cap_hard` are different instruments — a reporting threshold and a halt term — and are no longer required to relate. **Do not re-derive one from the other.**

### The three-way conjunction is REACHABLE — proven by measurement, not by algebra

Halt terms, unchanged, from §Halt path: **(a)** priorities 1–8 all at their drop floor, **(b)** `total > cap_hard`, **(c)** `constitution_clauses` is non-empty and non-truncatable.

> **WITHDRAWN 2026-07-31 (round 3) — a previously-published derivation of this section was FALSE and is struck, not quietly deleted.** An earlier revision of this amendment argued reachability algebraically: that **(a)** is entered "exactly when `Σfloor(priorities 1..8) + constitution_bytes > cap_t2`", therefore **(a) ⟹ `t2 ≥ cap_t2 + 1 = 10 241`**, therefore **(a) ⟹ (b)** at every legal `cap_hard`. **The implication does not hold.** `all_1_to_8_at_floor` is evaluated over the sections that were actually ADDED, and `add_section` returns early on an empty section — so a unit with no priority-1..8 section at all satisfies (a) **vacuously, over an empty set**, at any `t2` whatsoever. Reproduced: a unit with a fat body, one cited clause and no other T2 input halts at `t1 = 18 684 · t2 = 306 · total = 18 990` with `truncations: []` — `t2` there is 3 % of `cap_t2`, not `≥ cap_t2 + 1`. The amendment's own empirical table below already contradicted the algebra (the lean-probe row halts at `t2 = 10 225 < cap_t2 = 10 240`); the derivation was published anyway.
>
> **Three artifacts were built on that false step and are struck with it:** (1) the `cap_hard ≤ 12 906` ceiling, which was `min(t1) + cap_t2` — a floor that does not exist; (2) the "structural note" claiming term (b) does no discriminating work; (3) the Named-backlog item proposing to **drop** term (b). Executing (3) would have been a chain-killer: under vacuous (a), term (b) is the ONLY discriminator on a thin-section unit, so a halt restated without it fires on any unit citing one constitution clause regardless of size. See §Known open for what is carried forward.
>
> **What is NOT in question is reachability itself.** It is established EMPIRICALLY below — four units plus a lean probe reached `exit 1` with a populated `halt` object, with a working non-vacuity control. That table is now the whole load-bearing proof; nothing in this section rests on algebra.

Reached `exit 1` with a populated `halt` object — five measured runs, four distinct units:

| unit | constitution input | t1 | t2 | total | halt |
|---|---|---|---|---|---|
| constructed-rich-extend | 10 530 B | 10 874 | 9 599 | 20 473 | no |
| constructed-rich-extend | 15 738 B | 10 874 | 10 136 | 21 010 | **YES** |
| constructed-rich-ui | 15 738 B | 10 070 | 11 077 | 21 147 | **YES** |
| constructed-verify-locked | 31 362 B | 7 977 | 14 388 | 22 365 | **YES** |
| lean probe (t1 = 2 835) | 10 000 B clause text | 2 835 | 10 225 | 13 060 | **YES** |

**Non-vacuity** (a gate that always fires is not a gate either): on the lean probe, 9 800 B of clause text gives `t2 = 10 149`, `total = 12 984` and **no halt** — (a) is not yet satisfied; 10 000 B flips it. 200 B of never-truncatable content is the discriminator. ✔

**Why `cap_hard` was NOT raised to `cap_t1 + cap_t2` (22528).** Measured, not derived: the largest `total` any halting run in the corpus reached is **22 365** (constructed-verify-locked, on 31 362 B of constitution input), and every other halting run is 21 147 or below. At `cap_hard = 22528` term (b) would have been false on all of them — **the halt would never have fired on any unit in the corpus.** A cap that can never fire is not a cap. Measured control: a full second builder copy at `cap_hard = 13312` halted **28/28 identically** to 12288, moving only the lean-probe firing point 10 000 → 10 300 B. Raising `cap_hard` is measurably not the lever.

> **CEILING for any future raise: NONE IS PUBLISHED.** The `cap_hard ≤ 12 906` ceiling that stood here was `min observed t1 (2 666) + cap_t2 (10 240)` — derived from the withdrawn `(a) ⟹ t2 ≥ cap_t2 + 1` step, i.e. from a T2 floor that does not exist. It is struck rather than repaired: **no number replaces it until one is re-derived from measurement.** Until then, treat `cap_hard = 12288` as pinned by the measured control above (28/28 identical at 13312) and by the empirical firing table, and re-establish a bound before proposing any raise. **Known-open:** a moat test still pins `12906` as a regression rail — see §Known open.

### Term (b) is NOT redundant — the note that said so is struck

A "structural note" here previously argued that because (a) ⟹ (b) at every legal `cap_hard`, term (b) does no discriminating work and the halt could be restated without it. Both the premise and the conclusion are false: (a) is satisfiable vacuously (see the withdrawal box above), and on a unit with no priority-1..8 sections **term (b) is the only size discriminator the conjunction has.** The three-term shape in §Halt path is operative and unchanged; do not restate it, do not "simplify" it, and do not re-derive one term from another.

### Measured T1 recoveries — BACKLOG, not this tranche

Three T1 reductions were measured and are deliberately **not** specified here (they change byte-exact emitted text that fixtures assert; they belong in their own tranche with their own tests):

| recovery | bytes on the max unit | note |
|---|---|---|
| acceptance-test provenance NOTE → T2 at priority 9 (never-truncated) | 689 | it is a self-assessment instruction consumed when writing `bolt-report.md`, not a fact needed before writing code |
| `prov.anchors` + `prov.hard_rules` → back-pointer into `## Hard rules` / `## Anchors` already verbatim in T1 | 880 | dedup, NOT relocation; `anchors_verified: N/M` is genuinely new and must stay |
| box-rule decoration `═` (3 B UTF-8) → ASCII `=` | 344 in T1 / 860 whole file | zero semantic cost |

Total 1 913 B → T1 max would fall 10 874 → 8 961. **If and when all three ship in one tranche, `cap_t1` becomes 10240** (1 279 B / 14.3 % slack over 8 961). `cap_hard` stays 12288 either way — the recoveries shrink T1, which only *increases* term (b)'s reachability margin.

### Caveats that travel with these numbers

1. **The maximum is CONSTRUCTED.** Real fixtures in this tree top out at T1 = 6 234 (largest real unit body 1 692 B). The 12288 figure is justified by the three schema-legal constructed units at `unit-schema.md`'s documented upper end, not by the found corpus. Anyone re-measuring on real production units should expect a lower max, not a higher one — do not lower `cap_t1` on that basis alone.
2. **T1 is unbounded in principle** (never truncated, unit body verbatim). Crossing `cap_t1` is a unit-atomicity defect, not a budget defect.
3. `laravel-base-26.md` already has the largest `## Forbidden patterns` of the 8 shipped packs that carry one, so this corpus samples the fat end of the pack axis.

## T2 section priority + truncation cascade

Ordered MOST disposable (priority 1) → MOST critical (priority 8). When budget is tight, truncate the top of the list first. Each truncation is appended to `running_budget.warnings` as `{section, rule_applied, bytes_saved}` and surfaces in the builder's JSON `truncations[]`.

| Priority | T2 section | Truncation cascade | Drop floor |
|---|---|---|---|
| 1 | `validation_hints` | drop expected-output patterns; keep test commands only | drop section entirely |
| 2 | `historical_memory` | last 5 → last 3 → last 1 → drop | drop section |
| 3a | `reuse_slice` | trim to top 5 entries by target_files overlap → top 3 → top 1 | "+N more — read reuse-index.yaml directly" (never fully dropped — at minimum 1 hint line survives) |
| 3b | `symbol_slice` | LEVEL 0 already caps at 40 rows (spec R2) → top 20 → top 10 | "+N more — query via scripts/query-symbol-index.sh" (never fully dropped when the index exists and overlaps; index absent/unparseable/no-overlap → section OMITTED, recorded) |
| 4 | `kb_anti_patterns` | top 3 → top 1 → drop | drop section (see the join-key note below — currently ALWAYS omitted) |
| 5 | `confidence_labels` | per-claim → aggregate ("HIGH×N / MEDIUM×N / LOW×N") | drop section |
| 6 | `depends_on_summaries` | N most-recently-touched files only | keep at least 1 upstream |
| 7 | `framework_pack_rules` | top 5 → top 3 → top 1 | keep top 1 always |
| 8a | `starterkit_slice` | libs → top 10; ui_ux.idioms → top 3 (per `starterkit-enrichment.md §Slice truncation order`) | per the slice cascade (`starterkit-enrichment.md`; halt if still over) |
| 8b | `map_patterns` | none — single level, zero rungs | level 0 (permanently at floor; it yields nothing under pressure) |
| 8c | `design_slice` | full verbatim → lead clauses + High-only ux → drop ux → system+style only | system+style only (never drops to empty) |
| 9 (NEVER drop) | `constitution_clauses` | NEVER truncate — LOCKED security/compliance content | n/a — if it alone exceeds → halt `dispatch_prompt_too_large` |

**Amended 2026-07-31 (contract completeness, separate from the cap amendment):** tier 8 always carried THREE sections but listed one. `map_patterns` (the Map §6 fallback) and `design_slice` were emitted at tier 8 with no row, so a section sat outside the contract — and a rowless `map_patterns` that is permanently `at_floor()` could outrank `design_slice` while `design_slice` was truncated around it. The nine PRIORITIES are unchanged; rows 1–7 and 9 are unchanged verbatim; tier 8 is now enumerated 8a/8b/8c in its already-pinned order. **Amended 2026-08-02 (R2):** tier 3 is likewise enumerated 3a/3b — `symbol_slice` joins at the same priority as `reuse_slice`, stepped after it (3a first) one rung per pass, same tie discipline as tier 8. **`map_patterns` is kept, not removed** — it is the only pattern source a regex-tier scan produces (see §Map §6 fallback), so deleting it would drop real content on exactly the projects with the least context.

**Cascade notes (spec ↔ builder parity — read before amending a row):**

- **Row order within tier 8** is pinned `starterkit_slice` (8a) → `map_patterns` (8b) → `design_slice` (8c); the builder steps ONE rung per pass in that order, re-measuring after each. 8b has no rung to step, so a pass over it is a no-op by contract, not by accident.
- **Row 4 is currently unsatisfiable and its section is ALWAYS OMITTED.** "domain tags" is a **phantom field** — no unit schema, validator, or writer defines it, so there is no join key from a unit to a KB anti-pattern. Emitting the section (or the template's `DO NOT REPLICATE:` line) would require inventing the join → invariant #5 violation. The row stays because the cascade is the contract; it activates the day a real join key ships. Do not delete it, and do not populate the section from a guess.
- **Row 7's "keep top 1 always" floor is vacuous on an empty set.** The pack HARD_RULEs in `_universal.md` carry `<…>` placeholder globs; the builder skips sentinel globs, and an empty filtered set OMITS the section rather than inventing a rule to satisfy the floor. Floor semantics: "never truncate BELOW 1 when ≥1 matched", not "always emit ≥1".
- **`reuse_slice`, `symbol_slice`, `depends_on_summaries`, `framework_pack_rules` and `design_slice` never reach `""`** — their drop floor is a real surviving payload (`reuse_slice`'s floor is the literal `+N more — read reuse-index.yaml directly` line; `design_slice`'s is system+style only). `validation_hints`, `historical_memory` and `confidence_labels` do drop to empty. (Sections are named here rather than numbered — the old "rows 3, 6, 7, 8b" form silently re-pointed when tier 8 was enumerated.)

## Halt path + soft-budget warnings

`dispatch_prompt_too_large` fires ONLY when ALL THREE hold: **(a)** all disposable T2 sections (priorities 1–8) are already truncated to their drop floor, **(b)** total still exceeds `cap_hard`, AND **(c)** `constitution_clauses` alone is non-truncatable. In practice this halt now indicates a true config issue (a unit references too many constitution clauses for one bolt) requiring spec-level adjustment, not a bolt-fixable problem.

The builder encodes this as one explicit three-term boolean, and reads term (c) as "a non-empty `constitution_clauses` section exists" — the gloss this paragraph itself supplies. **All three terms discriminate; none is derivable from another.** (a) can hold vacuously (a unit with no priority-1..8 section is trivially "all at floor"), so it does not imply (b); (b) is the only size term; (c) is what makes the overflow un-spendable. A run where (a) and (b) hold but (c) does not is a run whose overflow is truncatable-in-principle content — **WARN and proceed; never widen the conjunction to invent a halt, and never narrow it by dropping a term.** (An earlier revision justified this disposition with an "(a) implies (b)" argument that has since been withdrawn as false — see the AMENDMENT. The disposition survives the withdrawal; the argument does not.) The halt is the builder's **exit 1**; its JSON `halt` object carries the payload specified in §Size check and IS the blocker YAML's `details`. The prompt file is still written on exit 1 — forensic evidence, not a dispatchable artifact. Exit 1 is reserved for THIS halt and nothing else; an internal error exits 4 (§Builder contract).

**Soft-budget warning** — when `consumed_t2 > cap_t2` but `total < cap_hard`: log a warning (NOT a halt): `"T2 exceeded soft cap: target=<cap>, actual=<N> — truncation applied"`; apply truncation to bring T2 back under target; the bolt proceeds with truncated context + a provenance trail visible to the subagent in the `### T2 budget tracker` section. The subagent is instructed: if the tracker shows truncated sections, set `confidence: MEDIUM` for any claim that depended on truncated context.

## TIER 2 (conditional, target ≤10KB, budget-tracked)

- depends_on chain: 1-line summary per upstream bolt, derived mechanically from each `bolt-report.md` — **no `summary:` key exists** (`## Summary` is a paragraph; `certain_decisions[]` are full sentences), so the derivation is a two-line reduction and MUST carry the report's `[<status>]` so an upstream `halted_postflight` can never read as a clean success.
  - **The `[<status>]` marker is UNCONDITIONAL and does not depend on a `bolt_self_report` block.** `status` comes from the report's frontmatter and is available whether or not the report carries a self-report. A bolt that HALTED is precisely the bolt that never wrote a `bolt_self_report:` block — so any derivation that returns early when the self-report is missing drops the marker **exactly for the upstreams that most need it**, and the downstream implementer reads `- U-000 "…" → committed at abc1234`, byte-identical in shape to a clean success, and builds on a halted dependency. Emit the status line first, then whatever self-report detail exists.
  - **Absent sub-values render as `n/a`, never as a number.** `retries` in particular: a report with no `retries:` key has not said "zero retries" — an older report schema or a writer that omits the key is not evidence of a settled upstream. `confidence` already does this correctly on the same line; `retries` must match it, or the clause is dropped entirely when the key is absent. Every value on this line is cited to a real file, so a defaulted one reads as sourced.
- Framework pack rules: filter the pack file by `path_glob` match against this unit's `target_files`. Ordering = pack-chain order, then in-file order (the only ordering the files supply); record it in the emitted provenance. Rule ids are synthesized `framework-pack-<type-slug>-NNN` (packs declare none).
- **Constitution clauses — selector AMENDED 2026-07-31 (re-decided, narrowed).** The pre-2b phrasing "ONLY clauses referenced in this unit's `vault_source` sections" is genuinely **unimplementable and cannot be restored**: `vault_source` is a scalar and nothing keys a clause to a vault section. But the replacement shipped by the wiring pass — a bare `\b[A-F]-\d{3}\b` scan of the whole unit file — is too wide, and its cost lands on the one section that can force the halt: a clause pulled by a token in a code sample enters priority 9, which is NEVER truncated, so a false positive can push a dispatch over the cap that would otherwise ship. The amended selector is the intersection of three real inputs, in this order:
  1. the id appears in this unit file, in **prose, frontmatter, `binding_refs` or `## Hard rules` — with fenced code blocks and inline code spans EXCLUDED**. A clause id inside a code sample is a sample, not a reference by the unit.
  2. the id **resolves to a real clause block in the constitution's §C** — the builder is already reading the constitution to emit clause bodies, so this costs nothing and eliminates the whole class of "clause not found" markers minted from ids that are not clauses.
  3. the `[A-F]-\d{3}` shape also matches binding CLAIM ids. An id present in `binding_refs` that does NOT resolve under (2) is a claim, not a clause: its "clause not found" marker is suppressed and the case is recorded in `sections_omitted`. An id that resolves under (2) is still emitted from the constitution's own blocks even if it also appears in `binding_refs`.

  **This does NOT weaken `validate-constitution-propagation.sh`.** That validator runs binding → units (does every clause the BINDING cites survive into some unit?); it never asks whether a dispatch prompt injected a clause. Narrowing the builder's selector cannot open a gate, because no gate reads it.

  **Emitted heading — FIXED.** The section heading is `## Constitution clauses (cited in this unit, resolved in the constitution §C)`. The template's old `## Constitution clauses (referenced by your vault_source)` heading described a selector that has never existed and that this file's own text calls unimplementable — a section whose heading tells the subagent the clause came from its vault source when it came from a token match in its own body, contradicted by the provenance line inside the same section. A heading is a claim about provenance; it gets the same discipline as any other.
- KB anti-patterns: **not populated — the section is always OMITTED.** The documented selector ("filter the KB by this unit's domain tags") has no input: "domain tags" is a phantom field with no schema, validator or writer. Per invariant #5 an absent input omits the section; it is never invented. See the cascade note on row 4.
- Historical memory: filter `<project>/.mega-sdd/memory/outcomes.md` for bolts touching similar files OR pattern — last 5 only. **This text is UNAMENDED and is the contract. Status 2026-07-31 (round 3): the relevance filter IS implemented** — an earlier revision asserted in bold that the builder did not honour it and emitted every run unfiltered. That assertion is now FALSE and is struck: the builder joins on the unit id plus the `target_files` basenames, drops non-matching runs, records them in `sections_omitted`, and omits the section entirely on zero matches. The word *relevant* in the emitted header is therefore a claim the builder can back. (This says the filter exists and joins on those needles; it makes no claim about the join's recall.) Active instincts (`memory/instincts/*.yaml`, confidence ≥0.7) whose `domain` matches the unit (ui → UI-bearing, security → risk-signal units, conventions/testing → all) join this slice as one line each — same budget, same truncation tier (per `memory/references/instincts.md`).
- **Starterkit context slice:** the auth/authz/ui_ux/libs slices (the `Auth:` / `Authz:` / `UI/UX:` / `Design tokens:` / `Design system:` / `Libs in scope:` lines), the §patterns block, and the reference code exemplar — read/build/inject machinery per `starterkit-enrichment.md` (routed from SKILL.md), loaded ONLY when `<project>/.mega-sdd/codebase/starterkit-context.yaml` exists. When that file is absent, only the Map §6 fallback below applies.
- **Confidence labels per claim — taxonomy DECIDED 2026-07-31.** The enum is exactly **`HIGH | MEDIUM | LOW | OQ`** and it is the same enum in this file and in `bolt-dispatch-prompt.md`; neither file may carry a different one.
  - **The label is the EVIDENCE-QUALITY axis and it reads the binding's recorded value first.** When the claim has a row in `binding.md ## Implementation State Map`, the label is that row's `Confidence` cell, mapped `high→HIGH`, `medium→MEDIUM`, `low→LOW`.
  - **Fallback, only when no cell was recorded:** the source-keyed rule — binding-sourced → HIGH, KB inference → MEDIUM, heuristic → LOW (with rationale).
  - **`OQ`** for an `OQ-*` binding_ref: an open question carries no confidence, and rendering it as LOW would assert a low-confidence *answer* where there is no answer at all.
  - **Why the cell wins over the source rule** — and this is decided on the moat, not on what the builder happens to do. A binding row `| C-007 | CONFIRMED | UNKNOWN | dynamic route detected [reason: dynamic] | low | n/a |` is a binding-sourced claim the binder explicitly marked *low*. The source-keyed rule alone would stamp it `HIGH`, i.e. manufacture certainty the cited source contradicts — invariant #5, in the direction that matters most, since the implementer uses the label to decide how hard to verify. The source axis is not lost: every label line already carries `└─ Source: <file> <section>`, so the reader sees both where it came from and how sure the binder was. Recorded evidence beats a category rule.
  - **Anchor freshness (assembly-time):** before stamping a label on an `## Anchors` entry, probe **existence + line-range only** — the file resolves and the line is within it. The older "when the binding recorded an excerpt/sha, the region still matches" clause is **KEPT DELETED after re-decision** (see §Re-decided amendments): no binding-schema field records an excerpt or sha, and `check-anchor-freshness.sh` — the shipped deterministic owner of this exact question — probes path + line-range and nothing else, for the same reason. The clause described a check no artifact supports. A failed probe injects `ANCHOR STALE (verify before use)` in place of the label (never a bind-era HIGH re-stamped mid-batch). This LABELS, it never halts — the probe regexes are copied from `check-anchor-freshness.sh` and run in-process (no per-unit spawn); pre-flight check 3.7 remains the sole owner of `anchor_missing`.
  - **The emitted line MUST state what was probed**, because the residual gap is real: an anchor at `app/Models/User.php:10` whose content was rewritten in place still passes. Emit `Anchors verified N/M (path + line-range only — content drift NOT checked)`, not a bare `Anchors verified N/M`. Closing the gap properly needs a bind-time excerpt/sha field in the binding schema — a `bind-codebase` amendment, recorded here as a named backlog item, never a probe the builder invents against an input that does not exist.
- Validation hints (specific test commands + expected-output patterns).

## Reuse slice: build

```
Path: <project>/.mega-sdd/codebase/reuse-index.yaml

IF reuse-index.yaml exists:
  Parse YAML → entries[]
  slice.reuse = entries whose path overlaps any of unit.target_files
              OR whose name is in unit.reuse_candidates
  Sort by overlap count descending.
  Cap to fit T2 budget (priority 3 in the T2 cascade above).
  IF truncated: append note "+N more — read reuse-index.yaml directly" to slice.reuse
  Inject into T2 as:
    ### Reuse index (filtered slice)
    <for each entry in slice.reuse:>
    - <entry.name> (<entry.path>) — <entry.summary>
    </for>
    <IF truncated:> +N more — read reuse-index.yaml directly </IF>
IF reuse-index.yaml absent: skip slice.reuse (the T1 path line above still instructs the bolt to check)
```

## Symbol slice (3b): build

Source: `.mega-sdd/codebase/symbol-index.json` — the script-built full-repo symbol index
(`scripts/build-symbol-index.sh`; ONE bounded ast-grep pass, zero model tokens). The slice
closes the reuse-coverage hole: `reuse-index.yaml` carries only the deep-scan slices, so
generic helpers — the symbols agents most often reinvent — reached no dispatch before this.

- **Retrieval is a DETERMINISTIC rule, never model-chosen search terms** (a model-chosen
  query finds what it expects — the fabrication vector): (a) every symbol whose `file` IS
  one of the unit's `target_files` ("you are editing next to these — extend them"), then
  (b) symbols whose file sits in the SAME directory as any target file. Order: group (a)
  first, then (b); index order within each group. Header: `### Existing symbols (REUSE —
  extend, don't recreate)`; first body line is the provenance stamp
  `index@<head8> · <N> symbols · built by scripts/build-symbol-index.sh`.
- **Freshness is the CONTROLLER'S batch-level step** (SKILL.md batch-setup item 5 runs
  `scripts/build-symbol-index.sh` once per execute-bolts run, BEFORE the per-unit loop;
  its exit 3 = ast-grep not installed → proceed, the builder records the omission). The
  builder itself spawns NOTHING for this slice (its zero-subprocess law), so `head_commit`
  in the stamp is provenance, not a verdict — symbols committed by earlier bolts of the
  SAME batch may lag until the next run, which is acceptable for advisory reuse material
  and visible in the stamp.
- Absent index → omit with the build command in the reason; unparseable → omit naming the
  rebuild; parseable but zero overlap → omit "no indexed symbol in or beside target_files".
- **Known bounded noise:** a target file at the repo ROOT makes group (b) the entire root
  directory — per-spec-correct ("same directory") and bounded by the 40-row level-0 cap.
- **Sanitize on render:** every interpolated index field is collapsed to ONE line with
  backticks replaced — the index is unguarded derived state, and a hostile
  signature/name must never mint its own markdown line or fence inside the prompt.

## Map §6 fallback (starterkit-context absent)

**Express-born projects (P2 default spine, no scan ever run) have NEITHER leg** — no starterkit-context.yaml AND no codebase-map §6; the builder's `omit("map_patterns", …)` records the honest omission and the bolt proceeds on pack conventions + the symbol/reuse slices. Running `scan-codebase` on demand restores both legs.

Codebase pattern signatures travel even WITHOUT a deep scan. When `starterkit-context.yaml` is absent (regex-tier / shallow / no-deep-scan runs — i.e. exactly when `starterkit-enrichment.md` is NOT loaded), `codebase-map.md §6 Pattern signatures` is the only pattern source the scan produced — deliver it instead of letting the bolt re-invent generic defaults:

```
IF starterkit_context absent AND codebase-map.md §6 (Pattern signatures) present:
  slice.map_patterns = §6 rows verbatim (auth pattern, error handling, state, view/component pattern)
  # emitted as one `Codebase patterns:` line in the dispatch prompt — "new code matches these
  # unless the unit's Hard rules say otherwise". Informational context, never a gate.
```

## Design slice: build + inject (INDEPENDENT of starterkit — the greenfield pipe)

> Closes the clinic-project audit gap (2026-06-12): generate-intent wrote a full
> `vault.json design_system` (style/palette/typography/a11y picked from
> `design-intelligence/product-style-map.yaml`), but the only injection path lived
> INSIDE the starterkit branch (now `starterkit-enrichment.md`) — greenfield projects have no
> starterkit-context.yaml, so UI bolts received ZERO design guidance and rendered
> default-browser ("kuno") UI. This slice is built whenever the unit ships UI files,
> starterkit or not.

```
ui_bearing = any target_files path matches the active pack `## UI quality signatures`
             view_glob, OR matches the universal frontend shapes:
             *.blade.php, *.html.erb, *.twig, *.jsx, *.tsx, *.vue, *.svelte,
             *.html, *.css, *.scss, *.less, *.cshtml, *.razor,
             components/**, pages/**, views/**, templates/**, Views/**,
             **/components/**, **/views/**, **/templates/**

IF NOT ui_bearing → skip (no design slice for pure-backend bolts)
IF slice.ui_ux already built (starterkit path — starterkit-enrichment.md) → skip
   (template is AUTHORITATIVE; the starterkit branch already carries design_system
   as supplement)

ELSE build design_slice:
  IF vault.design_system present (vault-contract.md §design_system):
    design_slice.system   = style, palette, typography, a11y_level (exclude provenance)
                            # PER-KEY OMISSION — see the absent-value rule below.
    design_slice.style    = the matching style-principles.md row, under its OWN
                            column names — see the column rule below.
    design_slice.ux       = ux-rules.md a11y rows + form/feedback rows
  ELSE:
    # EMIT THE VALUE, NOT THE ASSIGNMENT. The line the subagent reads is:
    #   No design_system in this vault — raise it as an OQ at chain end; do not
    #   invent a palette or a type pairing.
    # (An earlier build emitted the literal pseudocode `design_slice.note = "..."`
    #  into the agent-facing prompt: the one line that tells the subagent to raise
    #  an OQ read as a leaked internal variable assignment.)
    design_slice.note     = <that sentence>
  design_slice.baseline   = design-intelligence/modern-baseline.md
                            §Non-negotiables + §Ceiling moves + §Anti-kuno tells (verbatim digest)
                            # Ceiling moves are NOT optional polish — the floor (tokens/states/a11y)
                            # is "not broken", the ceiling (page furniture, width-filling composition,
                            # iconography, hierarchy, a signature) is "designed product". The bolt
                            # must aim for the ceiling, not stop at the floor (clinic-project finding).
```

Injection: a T2 section `## Design system (UI-bearing unit)` per
`bolt-dispatch-prompt.md`. Priority: same tier as `starterkit_slice` in the
truncation cascade (truncated late, never first-dropped — an un-designed view is
a rework cycle, not a nice-to-have). Its ladder is `full verbatim → lead clauses +
High-only ux → drop ux → system+style only`; it never drops to empty. ALL injected
text — never a Skill-invoke.

### The absent-value rule (invariant #5 at the key level)

**A `key=value` pair whose value is absent is DROPPED, with the reason recorded — never rendered as `None`, `null`, `n/a`, `-`, or an empty string.** A `design_system` block carrying only `style` is legal — nothing requires all four keys — and it must produce `Design system: style=modern — source: vault.json design_system`, not `style=modern · palette=None · typography=None · a11y=None`. If EVERY value on a line is absent, the whole line is omitted. This governs every composed line in the dispatch prompt, not only this one: the starterkit `Auth:` / `UI/UX:` / `Design system:` / `Libs in scope:` lines and the §patterns `location` / `naming` / `extension` fields have exactly the same shape and exactly the same rule.

It is load-bearing here specifically because `bolt-dispatch-prompt.md §Design system` names this line as authoritative — *"The palette/typography lines are the SOURCE for your tokens — never invent a second palette or pairing."* Handing the implementer `palette=None` as its authoritative palette leaves it two choices, invent one or ship untokened output, while `validate-ui-quality.sh` sees a `Design system:` marker and reports `design_system_not_injected` clean. A rendered `None` is worse than an omitted line: it is a placeholder that satisfies a gate.

### The style row: use style-principles.md's OWN column names

`design-intelligence/style-principles.md` is a generated table with the header `| Style | Best For | Avoid For | CSS Keywords |`. **There is no traits column and no anti-patterns column.** Emit the row under the labels the file itself uses:

```
Style: <Style> — best for: <Best For> · avoid for: <Avoid For>
Style CSS keywords: <CSS Keywords>
   (style-principles.md §<Style>)
```

**Do NOT emit `Style traits:` / `Style anti-patterns:`.** Relabelling `Best For` as "traits" and `Avoid For` as "anti-patterns" turns a **product-suitability** list into a **design-defect** list while citing the file by section — e.g. it tells the implementer that the style's anti-patterns are "creative portfolios, entertainment, playful brands" (product categories) and its traits are "enterprise apps, dashboards". The source is real and the assertion is invented, which is invariant #5 in its subtlest form and the one this repo is least able to detect downstream. It is worse than a normal mislabel because the `design-reviewer` lens judges the implementation against **this same slice**: implementer and reviewer would agree on a contract `style-principles.md` does not state. If a real traits/anti-patterns vocabulary is wanted, add the columns to the generator's source — never rename someone else's columns.

### Handing the slice to the design lens — a NEUTRAL lens-input file

The review-panel `design-reviewer` lens judges against the SAME slice, so the
implementer and the reviewer share one contract. **AMENDED 2026-07-31 (round 3): the slice reaches the lens as a PATH to a controller-written lens-input file, not as a pasted string.** The builder writes the emitted section verbatim to

```
<vault>/lens-inputs/U-XXX/design-slice.md
```

and returns that absolute path in its stdout JSON as **`design_slice_path`** (§Builder contract). The controller puts the path in the lens prompt; the lens Reads it.

**Why the change — this is a COST fix, and the earlier text-only rule was a MEASURED mistake, not an abandoned rail.** The round-2 shape returned the slice as `design_slice_text` on stdout and required the controller to paste it verbatim into the lens prompt. Measured, that bills the same string twice per greenfield UI bolt — once inbound as a tool result and once outbound as the controller's paste — and the outbound leg alone was the larger term. The rail it was protecting is intact and is stated below; only the carrier changed. **Exact figures, MEASURED 2026-07-31 against shipped code (n = 10 greenfield-UI + 10 starterkit-UI real units):** on a greenfield UI bolt the slice is **9,635 B**; the outbound paste into the lens prompt cost **≈ 2,409 output tok** and is now **one 129-byte path ≈ 32 tok** (saved ≈ 2,377 output tok/bolt, ≈ 823 tok when the `design_slice` truncation rung has fired and the slice is 3,420 B); the inbound stdout member it replaced was **9,911 B** (the JSON-escaped `json.dumps` member, not the 9,635 B file size) against **103–157 B** for the path. On a **starterkit** repo the slice is only **495 B** — D3's saving there is ≈ 366 B, and that arm must never be quoted as the headline. Full method, spread and per-channel breakdown → §Builder contract and `docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md` §2b.

**The rail, stated at its PURPOSE (amended — the round-2 absolute form was falsified by this repo's own live text):**

> **No lens may receive a path that reaches another lens's verdict or the implementer's self-report.**

That is what blind review protects: a lens forming its opinion before it can see anyone else's. It is NOT a blanket prohibition on paths. The round-2 wording — *"no path into `<vault>/bolts/U-XXX/`, not the file, not the directory, not a glob that reaches either"* — was stated absolutely, and `review-panel.md §Live-app capture` (unchanged, live, older than the rail) already routes design-lens screenshots to `<bolt-dir>/views`. An absolute rail that the shipping procedure violates is not a rail; it is an ambiguity a reader resolves by guessing.

Applying the purpose-scoped rail:

- **`<vault>/bolts/U-XXX/dispatch-prompt.md` — still forbidden to every lens.** That directory is where `bolt-report.md` lands, and on a `--resume`, a retry, or any re-run over a previously-bolted unit it already holds the prior attempt's `## Review panel` verdicts and `bolt_self_report`. A lens with Read/Grep is one `Glob` of the parent directory away from all of it. The prohibition on the bolt dir is not weakened by this amendment.
- **`<vault>/lens-inputs/U-XXX/` — permitted, and it is a SIBLING of `bolts/`, deliberately.** **Only controller-written lens inputs are ever written under `lens-inputs/`. No implementer output, no lens verdict, no `bolt-report.md`, no self-assessment — ever, by any code path.** That invariant is the whole reason the directory is safe; the path alone guarantees nothing. Any future change that writes implementer or reviewer output there breaks the rail even though the path is unchanged.
- **`<bolt-dir>/views` screenshots (`review-panel.md §Live-app capture`) — a NAMED candidate to follow, deliberately NOT moved here.** Captured PNGs are controller-written lens inputs too and belong under `lens-inputs/U-XXX/views/` by the same reasoning; the capture driver's `--out` and the procedure that calls it are out of scope for this change. Recorded in §Named backlog. Until it moves, a lens receiving the screenshot path receives a path into the bolt dir — permitted by the purpose-scoped rail (a PNG is not a verdict or a self-report), and a `Glob` of that directory would breach it, which is why the move is worth making.

## TIER 3 (reference-only — NOT embedded; read on demand)

Full upstream bolt-reports, full constitution, full KB domain files, full memory tables, full framework pack.

## Size check

- Compute final `total = consumed_t1 + consumed_t2`.
- IF `total > cap_hard` → halt `dispatch_prompt_too_large` with details `{cap_hard, total, t1_bytes, t2_bytes, warnings: running_budget.warnings, truncation_exhausted: true}` — should only fire when `constitution_clauses` alone exceeds budget (progressive truncation absorbs most cases first).
- IF `consumed_t2 > cap_t2` (soft cap exceeded but under hard cap) → emit a warn-only log line; continue dispatch with the truncated prompt.

> **Reading the bullet above (2026-07-31 — restored wording, one clarification).** Those two bullets are RESTORED verbatim to their pre-tranche-2b text. A wiring pass had rewritten the first one into "`total > cap_hard` alone is NOT a halt trigger"; that was the spec being loosened in the same changeset that made the loosening necessary, and it is reverted.
>
> The restored bullet carries its own qualifier — *"should only fire when `constitution_clauses` alone exceeds budget (progressive truncation absorbs most cases first)"* — and that qualifier **is terms (a) and (c) of §Halt path stated in prose.** The bullet was never an independent `total > cap_hard` trigger; it is §Halt path's conjunction restated loosely, with its own intent written into the same sentence. **§Halt path is the operative definition, in one place, unchanged.**
>
> The qualifier is load-bearing, and the measurement is why: read WITHOUT it, `total > cap_hard` fires on **31 of 123** measured runs (25 %) — including runs with `truncations: []`, a fully legal T2, and nothing wrong with them. A halt that fires on a quarter of healthy dispatches is a tax, not a gate. Read WITH it, the conjunction fires only when never-truncatable constitution content is what pushed the prompt over, which is exactly the config problem the halt names. The AMENDMENT above supplies the cap numbers that make the qualified reading satisfiable and proves it reachable on four units.
> **DISCLOSURE (2026-07-31, round 3) — `total` is the T1+T2 ACCOUNTING, not the size of the file on disk.** The two bullets above are restored verbatim to their pre-tranche text and are not amended; this note is appended because the accounting they define does not cover the whole emitted artifact, and until now that was disclosed only in a code comment. Four blocks are written into `dispatch-prompt.md` and are OUTSIDE `total = consumed_t1 + consumed_t2`:
>
> 1. the `PROVENANCE — omissions` appendix (`sections_omitted[]`, relocated out of default stdout — §stdout JSON),
> 2. the `TIER 2` banner,
> 3. the `### T2 budget tracker` block itself,
> 4. the `TIER 3` banner + pointer list.
>
> **The title banner and the `TIER 1` banner are NOT among them** — both are appended into `t1`, so they are inside `consumed_t1` already. (An earlier revision of this list said "the three tier banners", which overstated the gap by 636 B and made it fail to sum.)
>
> **Consequences a reader must not be surprised by.** The tracker injected INTO the prompt reports `total:` for a file that is larger than that, and `agents/bolt-implementer.md` Rule 0 tells the implementer to read that file in full — so the subagent is handed a figure that does not describe what it just read. None of the four sits on any rung of the 9-priority cascade, so under budget pressure the ladder shrinks contract content while these are untouchable.
>
> **Magnitude — MEASURED 2026-07-31 against shipped code** (`file_bytes` is now on stdout, so this is `file_bytes − total_bytes` and needs no `wc -c`). Observed gap, by arm: **non-UI 5,398 / 5,398 / 5,835 B (min/med/max, n = 25)** · **UI on a starterkit repo 5,017 / 5,119 / 5,203 B (n = 10)** · **UI on a greenfield repo 5,197 / 5,239 / 5,281 B (n = 10)**; across all 105 runs, 4,889–5,835 B. On the leanest unit measured that is ~1.7× the whole T1+T2 accounting (`total_bytes` 3,149); on a fat UI unit ~0.4×.
>
> **Per-run identity, verified on all 105 runs with zero mismatches** (blocks split structurally on the `═` banner rules):
>
> `TIER 2 banner + tracker block + TIER 3 block + PROVENANCE appendix + 4 B of separators == file_bytes − total_bytes`
>
> | block | bytes observed | note |
> |---|---|---|
> | `TIER 2` banner | 314 | constant |
> | `T2 BUDGET TRACKER` banner + fenced tracker block | 1,273–1,277 | 294 banner + 979–983 fenced body |
> | `TIER 3` banner + pointer list | 1,154 | 321 banner + 833 list; the list holds 4 absolute paths, so it is path-length sensitive |
> | `PROVENANCE — omissions` appendix | 2,448–3,090 | 338 banner + 2,110–2,752 body; the only block that varies much with the unit |
> | inter-block separators | 4 | constant |
>
> **Do not add the column maxima to reconstruct the maximum gap** — the component maxima do not co-occur on one run. The identity above is per-run; the ranges are per-column.
>
> **CORRECTION — found by this measurement, FIXED in round 4 (no longer open).** The enumeration above (and the identical wording in the `### T2 budget tracker` block the builder injects into every prompt) said *"the tier banners"*. Measured, the **title banner (293 B) and the `TIER 1` banner (347 B) are INSIDE `consumed_t1`** — only the `TIER 2` and `TIER 3` banners are outside the accounting. Adding those two overstated the gap by 636 B and made the enumeration fail to sum. **Both places now name the four blocks exactly**, and the identity was re-verified live in round 4 on a fresh run, summing to the byte: `TIER 2` banner 313 + tracker 1 510 + `TIER 3` block 1 164 + `PROVENANCE` 3 237 + 11 B of separators == `file_bytes − total_bytes` == 6 235.
>
> **That re-verification splits the file on `assemble()`'s own joins, not on the `═` banner rules**, so its separator term is the literal 11 B the join contributes (five `"\n\n"` + the one trailing `"\n"`) and each block excludes the newlines around it. The table above uses the round-3 banner-rule split, whose separator row reads **4 B** because that convention attributes the joining newlines into the blocks themselves. **The two are different accountings of the same file, and both close.** Do not mix a block figure from one with a separator figure from the other; the block boundaries are not the same boundaries.
>
> **Round 4 grew the file by TWO constants, and the ranges above shift by different amounts per arm.** Both are constant string changes, so neither needs re-measuring — but neither may be omitted either, because the figures above were measured on round-3 code:
>
> - **+235 B on EVERY run** — the tracker block's corrected enumeration. The tracker row `1,273–1,277` becomes `1,508–1,512`; the fresh round-4 run measured 1 510, inside that range, which is the check.
> - **+216 B on NON-`ui_bearing` units only** — the new `design_slice_path` omission line in the `PROVENANCE` appendix (measured verbatim in the emitted file). Invariant #5 requires an absent input to carry a recorded reason, and a reason has bytes. It does not fire on UI-bearing units.
>
> So the arm ranges above shift by **+451 B for non-UI** (the largest arm, n = 25) and **+235 B for both UI arms**. **The per-run identity is unchanged** — a constant added to one block is added to the gap, and the +216 B lands inside the `PROVENANCE` appendix term.
>
> **This note discloses the gap; it does not close it.** Closing it is a builder change — either budget the appendix into the cascade or report the on-disk size alongside the accounting — and is carried in §Known open.

- Inject the `### T2 budget tracker` section into the dispatch prompt:
  ```
  ### T2 budget tracker
  consumed_t1: <X bytes> (cap 12288)
  consumed_t2: <Y bytes> (cap 10240, hard 12288)
  total: <X+Y bytes>       # T1 + T2 ONLY — the budgeted, truncatable content
  file_total: <N bytes>    # THIS WHOLE FILE
  truncations_applied:
    - <section>: <rule_applied> (saved <Z bytes>)
    ...
  instruction_to_subagent: "If your self-assessment references information that was truncated above, mark its confidence: MEDIUM and note the truncation in your bolt-report.md self-assessment section."
  ```

  **`total` and `file_total` are BOTH required, and the block must say what separates them.** `agents/bolt-implementer.md` Rule 0 tells the implementer to read the whole file, so a block reporting only `total` hands it a figure that does not describe what it just read — measured at a 24–59 % self-reporting gap. The difference is **exactly four blocks plus the blank lines joining them: the `TIER 2` banner, this tracker block, the `TIER 3` pointer list, and the `PROVENANCE — omissions` appendix.** The **title banner and the `TIER 1` banner are NOT in that gap** — they are appended into `t1` and are therefore already inside `consumed_t1`. None of the four is budgeted and none is ever truncated, so truncation must be reasoned about from `truncations_applied`, not from either number. (Both figures are on stdout too, as `total_bytes` / `file_bytes`.)

## Builder contract (invocation, exit codes, stdout)

### Invocation

```bash
bash "<plugin-root>/scripts/build-dispatch-prompt.sh" \
  --cwd=<project-root> --vault=<vault> --unit=U-XXX \
  --plugin-root="<plugin-root>"
```

> **`<plugin-root>` is a placeholder here on purpose — do not paste this block into a dispatch.**
> The plugin-root environment variable is **not substituted in reference files** (the repo-wide rule
> `generate-intent/references/vault-contract.md`, pinned by `tests/platform/test-platform-pins.sh`
> P6), so a reference file that spelled the variable would hand the controller a command that opens
> `/scripts/build-dispatch-prompt.sh` and writes no prompt for that bolt. The **runnable** form,
> where the variable IS substituted, lives in `execute-bolts/SKILL.md` §Step 4.5 — that is the one
> the controller emits, and it is the string measured below.

`--plugin-root` is **REQUIRED of the controller**, not optional. It is already known (the same variable names the script), and passing it skips the `resolve-plugin-root.sh` spawn — measured at 6 process creations per bolt including that helper's own `ls | grep | sort | tail` pipeline, ≈1.3 s/bolt and ≈53 s over a 40-unit run on a CrowdStrike-scanned Windows laptop at ~220 ms/spawn, at **zero behavioral cost**. `--quiet` is FORBIDDEN: stdout is the sole carrier of `inline_core` and `design_slice_path`.

**The invocation string itself is a measured OUTPUT cost** (the controller emits it every bolt) and it grew when `--plugin-root` became mandatory and the form became multi-line. **MEASURED 2026-07-31, byte-exact on the three-line form above, across BOTH axes:**

| project root | env-var form, emitted LITERALLY | plugin root PRE-EXPANDED (75 B) |
|---|---|---|
| `/Users/me/app` (13 B) | **190 B** | **298 B** |
| this repo's own root (67 B) | **298 B** | **406 B** |

**Which form the controller emits is UNRESOLVED and is published as a band, not guessed.** The SKILL.md template names the plugin-root variable twice, and whether the model emits it literally (bash expands at runtime) or pre-expanded swings the string by **+108 B** — more than the 54-byte project-root spread does. The string grows **+2 B per character of project-root length** (`--cwd` and `--vault` each carry it once). Any residual/ratio headline that quotes this string must state which expansion form and which root length it assumed.

### Exit codes

| exit | meaning | is the prompt file readable afterwards? | controller does |
|---|---|---|---|
| **0** | prompt written. `status: ok_with_soft_halts` may carry `soft_halts[]` (e.g. `deep_scan_cache_corrupt`) | yes — dispatch it | dispatch; log any `soft_halts[]` in the bolt-report |
| **1** | halt `dispatch_prompt_too_large`, and ONLY that. stdout JSON MUST carry a populated `halt` object | yes — written deliberately as forensic evidence | halt with the `halt` object as the blocker `details`. **Never dispatch.** |
| **2** | usage / IO / no interpreter, detected BEFORE assembly | **this run wrote nothing.** A prompt from a PREVIOUS run of this unit may still be there, unchanged — never dispatch it | fix the invocation and re-run |
| **4** | **internal error** — any unhandled exception in the builder | **this run wrote nothing.** A prompt from a PREVIOUS run of this unit may still be there, unchanged — never dispatch it | treat as a defect, not a budget halt: report the captured traceback, re-run once, then escalate. **Never dispatch.** |

**The exit CODE is the discriminator, never the presence of the file.** On exits 2 and 4 the builder publishes nothing — and it also destroys nothing: an existing correct `dispatch-prompt.md` is left INTACT and byte-for-byte unchanged. Do not infer freshness from a file's existence on any path.

**Why exit 4 exists (fixes a live contract hole).** Before this amendment, *any* unhandled exception in the builder — an unimportable shared lib, a malformed unit, the `assert len(rules) == len(levels) - 1` in the section ladder — also exited 1, with zero stdout and no file written. A controller following the exit-1 contract would read that as `dispatch_prompt_too_large`, look for a `halt` object that does not exist, and find the bolt directory still holding **the PREVIOUS run's `dispatch-prompt.md`** — which the exit-1 contract explicitly tells it to trust as forensic evidence. That is a crashed build dispatching the previous unit's prompt to a subagent. Two requirements close it, and BOTH are mandatory:

1. **Distinct code.** The builder wraps its whole body in a top-level handler that prints a JSON error object (`{"status":"internal_error","error":"<exception class>: <message>","traceback":"<text>","unit":"U-XXX"}`) to stdout and exits **4**. Exit 1 becomes unreachable except from the halt path. (4, not 3: this script family already uses 3 for "section absent → SKIP" in `_lib/resolve-framework-pack.sh`, and a reader should not have to ask which 3 they are looking at.)
2. **Never PUBLISH a stale file — and never destroy a good one.** The artifact MUST be written to a sibling temp file in the same directory and then `os.replace()`d into place. Publication is therefore atomic: a reader sees either the complete previous prompt or the complete new one, never a partial file, and a run that fails before the rename publishes **nothing**. The rename is atomic on the same filesystem, and the same-directory constraint keeps it atomic on Windows too.

   **A pre-assembly unlink of the target is FORBIDDEN.** It adds nothing — temp-and-rename already guarantees that a failed run publishes nothing — and it converts any internal error into the destruction of a correct artifact that was already on disk. That is not hypothetical: it shipped, and a stdout encoding error on the Windows target deleted the correct prompt the builder had just written.

   **What follows for the controller:** after exit 2 or exit 4 the path may still hold **this unit's previous attempt**, intact and unchanged. The **exit code**, not the file's existence, is the discriminator — 2 and 4 both mean NEVER DISPATCH. (Exit 1 still writes the prompt deliberately, as forensic evidence.)
3. **Controller rule that follows from both:** exit 1 is a budget halt **only if stdout parses and carries `halt`**. Exit 1 with unparseable or empty stdout is an internal error — handle it as exit 4. Do not infer a halt from an exit code alone.

### Pack-resolver exit codes MUST be discriminated (CRITICAL — silent moat-content loss)

The builder's one remaining unconditional spawn resolves the framework-pack chain. Swallowing its exit status into an empty chain is a **silent, per-bolt loss of the entire framework-pack contribution** on the documented Windows target: with `python3` resolving to the WindowsApps App-Execution-Alias stub (exit **49**, a documented false positive — see `scripts/_lib/resolve-python.sh`) the resolver fails, the chain comes back empty, and the dispatch loses its `## Framework pack rules` section AND the pack-derived `DO NOT WRITE:` anti-context line — reproduced at 8 733 → 5 412 bytes, **exit 0, empty stderr, nothing in `warnings[]`**. Worse, the recorded omission reasons (`chain: none resolved`, `no ## Forbidden patterns section in the resolved pack chain`) are textually identical to a legitimately packless project, so the `sections_omitted` audit trail actively conceals the failure.

**Required behavior:**

- Capture the resolver's exit code; do NOT `|| PACK_CHAIN=""` it away.
- **exit 0** → use the chain. **exit 3** → documented SKIP (no pack applies); record `chain: none resolved` as today.
- **Any other exit** → the chain is UNKNOWN, not empty. Record a `warnings[]` entry naming the exit code and the interpreter actually used, and make the `sections_omitted` reason say so verbatim: `framework pack chain UNRESOLVED (resolver exit <N>, interpreter <path>) — this is NOT a packless project`. The two states must never read alike.
- Pass the builder's already-resolved interpreter down to the resolver (`MEGA_SDD_PY`) so a stub `python3` on `PATH` cannot decide the outcome. The builder is the only hot-path script that resolves its interpreter correctly; the resolver must inherit that, not re-guess.
- This is a **recorded degradation, not a halt** — the bolt still ships, but nobody can mistake the loss for an absent input.

### stdout JSON — print what the controller consumes

The controller reads exactly five things: `status`, `halt`, `inline_core`, `prompt_path`, `total_bytes`.

**Why the slim was required (PRE-FIX baseline, retained as motivation — do NOT quote it as a current figure).** Before this change the emitted JSON measured **3 026–3 587 B**, of which **41–63 % (1 237–2 246 B) was `sections_omitted` prose the controller never reads** — forensics nobody consumes, re-billed on every subsequent controller turn as resident context. That measurement is what motivated the change; it describes a shape that no longer ships.

> **CURRENT stdout size — MEASURED 2026-07-31 against shipped code**, on the exact §Invocation form (with `--plugin-root`, without `--quiet`/`--explain`), over 35 real `U-*.md` units on three fixture projects (105 runs, all exit 0). **Three figures that must never be averaged**, min / median / max, stated **at this repository's own project-root length (67 B)** because path length is what made the three previously published figures non-reproducible:
>
> | arm | n | stdout bytes/bolt | tokens (÷4) |
> |---|---|---|---|
> | non-UI (`design_slice_path` absent) | 25 | **731 / 815 / 922** | 183 / 204 / 231 |
> | UI on a **starterkit** repo | 10 | **985 / 1,043 / 1,343** | 246 / 261 / 336 |
> | UI on a **greenfield** repo | 10 | **1,199 / 1,256 / 1,343** | 300 / 314 / 336 |
>
> **The exact path assumed by "67 B":** project root 67 B **+ `/.mega-sdd/vaults/demo-bound/bolts/U-XXX/dispatch-prompt.md` (59 B) = a 126-byte absolute `prompt_path`.** The vault name is inside the path that stdout carries, so a project whose vault is named `sample-vault-bound` reproduces a different number by exactly the name-length difference × 2 (or × 3 on a UI unit). Quote the full assumed path, never the root length alone.
>
> **Path-length law, exact (not an estimate):** the project path appears **2× on a non-UI unit** (`prompt_path`, and again inside `inline_core`'s READ-FIRST pointer) and **3× on a UI unit** (`+ design_slice_path`), so stdout moves by exactly 2 B or 3 B per character of project-root length — verified by re-running the same units at a 42-byte-longer root and observing deltas of exactly 84 B and 126 B. At a 13-byte root the three arms read 623 / 823 / 1,037 B (min); at a 144-byte root, 885 / 1,216 / 1,430 B.
>
> **Residency:** this object lands as a tool result billed 1.0× once and then `cache_read` 0.1× on every subsequent controller turn. That multiplier is real; N is **unmeasured** and no N is invented here.
>
> The retired figures (`3 026–3 587 B`, and `3.0–3.6 KB/bolt` with 41–63 % `sections_omitted`) are struck — they describe a shape that no longer ships.

**Required:** by default stdout carries only the controller-consumed keys plus the small accounting the report line needs — `status`, `halt`, `inline_core`, `prompt_path`, `total_bytes`, `t1_bytes`, `t2_bytes`, `truncations[]`, `warnings[]`, `soft_halts[]`, and `design_slice_path` (below). **`sections_omitted[]` moves out of default stdout.** It is forensics and it has a better home: it is already written into the prompt file's own provenance section, where the auditor and `validate-dispatch-prompt.sh` can both see it. Nothing is deleted — only the default channel changes.

**Three stdout states, and `--quiet` / `--explain` are NOT on the same axis:**

| flag | stdout | who uses it |
|---|---|---|
| *(none — default)* | the controller-consumed keys above | the execute-bolts controller. This is the shipping path. |
| `--explain` | the default keys **plus** `sections_omitted[]` and any other forensic keys | a human or `analyze` debugging one bolt |
| `--quiet` | **nothing** — existing flag, existing meaning, unchanged | **FORBIDDEN for the controller.** It suppresses the JSON entirely and therefore `inline_core` and `design_slice_path`, which are the only reason the controller runs the builder. |

`--explain` ADDS forensics back; `--quiet` removes everything. They are not two settings of one verbosity dial and must never be combined.

### `design_slice_path` — the design lens's rubric, as a lens-input FILE

**Renamed and re-carried 2026-07-31 (round 3). The predecessor key was `design_slice_text`, a string on stdout that the controller pasted verbatim into the lens prompt** — see §Handing the slice to the design lens for why it changed (measured double-billing) and for the purpose-scoped rail that makes a path legal here. The rubric is not weakened: it is the same bytes, written once, read once.

`design_slice_path` (string, **omitted entirely when the unit is not UI-bearing** — absent key, not `""`) is the ABSOLUTE path of `<vault>/lens-inputs/U-XXX/design-slice.md`, which the builder writes containing the exact emitted design-slice text, VERBATIM as it appears in the written prompt and byte-identical to it. The controller puts that path in the `design-reviewer` lens prompt; the lens Reads it. **Two branches, both pinned so the extraction boundary is never a judgement call:**

- **Greenfield branch** (no `starterkit-context.yaml`, or the starterkit `ui_ux` slice was not built): the whole `## Design system (UI-bearing unit…)` section, from its heading to the line before the next `## ` heading.
- **Starterkit branch** (the starterkit `ui_ux` slice WAS built, so §Design slice skipped): the design lines of `### Starterkit context`, enumerated in `starterkit-enrichment.md §Starterkit slice: inject`. Nothing else from that section travels — the `Auth:` / `Authz:` / libs / §patterns / code-exemplar content is not a design rubric and must not reach the design lens as one.

If neither branch produced text (UI-bearing but every design input absent), **no file is written and the key is absent** — the controller dispatches the design lens with no rubric and says so in the lens prompt. It never substitutes a different section, and it never hands the lens a path to a file that does not exist.

**Writing rules for the lens-input file** (same discipline as the prompt file, §Log final prompt): the builder ensures `<vault>/lens-inputs/U-XXX/` exists (idempotent `mkdir -p`), writes via a sibling temp file + atomic `os.replace()`, and writes UTF-8 with `\n` newlines. Nothing else is ever written under `lens-inputs/` — see the invariant in §Handing the slice to the design lens.

**Cost of this field — MEASURED 2026-07-31, and it is its own line item, never folded into a ratio.**

| channel | greenfield UI bolt (n = 10) | starterkit UI bolt (n = 10) |
|---|---|---|
| **input** (builder stdout) | retired `design_slice_text` member **9,911 B** → `design_slice_path` member **103–157 B** ⇒ **−9,754…−9,808 B ≈ −2,440 input tok** | retired member **526 B** → **103–157 B** ⇒ **−369…−423 B** |
| **output** (controller → design lens) | verbatim paste **9,635 B (≈ 2,409 tok)** → the RAW path **75–129 B (≈ 19–32 tok)** ⇒ **≈ −2,377 output tok** | paste **495 B** → path ⇒ **≈ −92 output tok** |

The two rows are in different units on purpose: the **input** row counts the JSON *member* (`  "design_slice_path": "…",\n` = path + 28 B) because that is what lands on stdout; the **output** row counts the **raw path** (75 B at a 13-byte project root, 129 B at a 67-byte one) because that is what the controller types into the lens prompt. Do not mix them.

The retired input term is the **JSON-escaped member**, 9,911 B — *not* the 9,635 B file size; newline and quote escaping is the ~2.9 % difference, and quoting the file size understates the saving. When the `design_slice` truncation rung has fired the slice is 3,420 B and the output saving falls to ≈ 823 tok. **`design_slice_path` is a per-UI-bolt cost of ~103–157 B on stdout** — that is what replaced both terms.

> **Found by this measurement (spec ≠ code) — FIXED in round 4, no longer open.** This section says the key is *"omitted entirely when the unit is not UI-bearing"*. The round-3 write was gated on the slice text being non-empty, **not on `ui_bearing`** — and on the starterkit branch the slice text exists whenever the unit's `starterkit_relevance` carries `ui_ux`, regardless of `target_files`. Reproduced: on a starterkit fixture with `starterkit_relevance: [ui_ux, libs, auth]` stamped on all 35 units, **34 received a `design_slice_path` while only 10 are `ui_bearing`**; a unit whose only target was `app/Services/Settlement.php` got a lens-input file no lens would ever be handed.
>
> **The gate is now `ui_bearing` — the SAME gate the `design_slice` section (priority 8c) already used.** The two disagreed and the looser one decided what was written to disk. A non-`ui_bearing` unit now emits no `design_slice_path`, writes no lens-input file, and records the reason in `sections_omitted`. The sentence above is true again, and `review-panel.md §Tier selection`'s *"pure-backend units never pay for it"* is true with it. **The unit's own starterkit slice still ships INTO THE PROMPT** when it declares `ui_ux` relevance — the fix withholds a lens input, it does not delete content. Pinned by `tests/derived-artifacts/test-dispatch-prompt-builder-shape.sh` §T4 (the cascade suite's non-UI rail cannot see this: its fixture has no `starterkit-context.yaml`, so it passed throughout round 3 with the defect live).

**Why the file and not the paste.** The paste was billed on BOTH channels for the same bytes — inbound as a tool result, outbound as the controller's re-emission into the lens prompt — and the outbound leg is the one the published residual never counted. A controller-written lens-input file costs one path on each channel and delivers the same bytes to the lens. **This is not a retreat from the blind-review rail:** the rail is *"no lens may receive a path that reaches another lens's verdict or the implementer's self-report"*, `<vault>/lens-inputs/` holds neither by construction, and the prohibition on `<vault>/bolts/U-XXX/dispatch-prompt.md` and its directory is unchanged.

## Log final prompt

The builder ensures the bolt dir exists (`mkdir -p <vault>/bolts/U-XXX/` — idempotent; Step 0 already made it, but it never assumes) and writes the assembled prompt to `<vault>/bolts/U-XXX/dispatch-prompt.md` (via the temp-file + atomic-rename rule in §Builder contract). **That file is CONTRACTUAL, not merely provenance:** `scripts/validate-dispatch-prompt.sh` globs exactly `<vault>/bolts/*/dispatch-prompt.md` and has no other input — if it stopped being written the advisory gate would SKIP on "no emitted prompt found" and go dark, indistinguishable from a passing check.

**Dispatch (controller):** read `inline_core` from the builder's stdout JSON and paste it VERBATIM as the Agent prompt — the ≤700B pointer that names the file. The controller does NOT re-type the assembled prompt; the subagent Reads it. (`--quiet` suppresses that JSON and therefore `inline_core` — the builder must never be called with it.)

**Validator dispatch is a HOOK, not a controller obligation.** `hooks/post-tool-use` fires `validate-dispatch-prompt.sh` deterministically on the Bash call that runs the builder, exactly as it fires on a `Write|Edit` of `*.mega-sdd/vaults/*/bolts/*/dispatch-prompt.md`. **The controller has no wiring step here and MUST NOT be given one** — a prose obligation that duplicates a hook rots, and the doctrine (`plugins/mega-sdd/CLAUDE.md` — *gates > rules > hooks*) is one-way: an existing deterministic hook is never downgraded into prose.

> **On "never per bolt" — read this before optimizing the hook.** The hook fires once per builder invocation, i.e. once per bolt. That is **restored parity**: before the builder existed the controller materialized `dispatch-prompt.md` with `Write`, and the same PostToolUse dispatch fired per bolt with zero model cooperation. The per-item-fan-out prohibition this repo enforces (tree-sitter per-file v5.11.0, pack-lint per-line v4.60.0) is about **fan-out inside one logical operation**, and it applies to spawns the *model* is told to emit in a loop. A hook that fires once per tool event is the platform's own cadence, it costs one spawn on an event that already cost several, and it is the only firing that survives a run halting at unit 12 of 40. **Do not "optimize" it to once-per-invocation** — that is precisely the model-cooperation dependency the hook exists to remove.

## Anti-hallucination rails

- T2 filtering MUST cite a source for inclusion (e.g. "framework pack rule X loaded because target_files matched glob Y"). **A citation binds the assertion to what the source actually says** — quoting a real file under a label it does not use (see the style-row rule) is a citation-discipline breach, not a wording choice.
- **An absent input OMITS its section — it is never invented, never stubbed, never placeholder-filled** (invariant #5). This is why `kb_anti_patterns` is always omitted, why an empty filtered pack-rule set omits §Framework pack rules despite the priority-7 floor, and why a missing `vault.json` omits the `vault_sha256:` line instead of halting. The builder records every such case in `sections_omitted[{section, reason}]` so the omission is auditable rather than silent.
- **The rule applies at KEY level, not only at section level** — a missing sub-key of a present dict drops its own `key=value` pair and, if every value on the line is absent, the line. See §The absent-value rule. `None` / `null` / `n/a` / `""` are never emitted as a value.
- **An omission reason must not read like a different, benign state.** When a source could not be RESOLVED (an error) the reason says so and names the cause; it never reuses the wording for a source that legitimately has nothing (see §Builder contract, pack-resolver exit codes). An audit trail that cannot distinguish "absent" from "broken" conceals the failure it was built to expose.
- **Never substitute one source for another under the original's label.** If the specified source is unavailable, omit and record. Sourcing `DO NOT MODIFY:` from the unit's Hard rules while the line reads as `data-mutation-policy.md` content is the archetype; so is relabelling another file's columns.
- The anti-context block is populated from actual data sources (data-mutation-policy.md, KB, framework pack) — NEVER invented.
- Self-assessment confidence MUST be numeric `0.0–1.0` (not strings); halt if omitted.
- A provenance trailer is MANDATORY in every modified file — the post-flight scan verifies its presence; missing → halt `provenance_missing`.
- Starterkit slice budget: the T2 starterkit slice MUST be capped per `starterkit-enrichment.md §Slice truncation order`. When the T2.3 starterkit section is present, the bolt subagent MUST honor it: extend the named layout, use the named notification lib, use only the listed libs (no inventing alternatives). Violating code is rejected at the post-flight check.

## Re-decided amendments (2026-07-31)

Five spec passages were amended during the tranche-2b wiring pass to match the new builder. Each was re-decided on its own merits; the verdicts and the grounds are recorded here so the next reader can audit the decision rather than discover it.

| # | passage | verdict | grounds |
|---|---|---|---|
| 1 | `kb_anti_patterns` is ALWAYS omitted (phantom "domain tags" join key) | **KEPT** | Verified independently: "domain tags" appears nowhere outside the builder, its own tests and these two spec files — no unit schema, validator or writer defines it. With no join key, omission is the invariant-#5 answer and populating it would be invention. The cascade row stays so the section activates the day a real key ships. |
| 2 | `hard_rules_active` carries verbatim TEXT, not synthesized ids | **KEPT** | Unit Hard rules genuinely have no ids. Minting them would fork a second identity model from `_lib/postflight_rules.py`, which is what the B1 gate matches against — two identity schemes for one rule set is a worse failure than a long line. |
| 3 | constitution selector: `vault_source` → whole-unit-file `[A-F]-\d{3}` scan | **AMENDED, NOT ACCEPTED AS WRITTEN** | The old phrasing is genuinely unimplementable (`vault_source` is a scalar), so it cannot be restored — but the replacement was too wide, and its false positives land in priority 9, the one never-truncatable section that can force the halt. Narrowed to a three-way intersection (unit reference outside code fences ∩ resolves to a real §C clause ∩ claim-id disambiguation) and the misdescribing heading fixed. See §TIER 2. |
| 4 | anchor freshness: excerpt/sha clause deleted | **DELETION KEPT, with a disclosure requirement added** | Corroborated beyond the builder: `check-anchor-freshness.sh`, the shipped deterministic owner of anchor freshness, also probes path + line-range only — because no binding-schema field records an excerpt or a sha. The clause described a check with no input. The residual gap (content rewritten in place still passes) is REAL, so the emitted line must now state the probe's scope, and the missing bind-time field is a named `bind-codebase` backlog item. |
| 5 | starterkit slice step 7: own halt → delegates to the global halt check | **KEPT** | One halt, one definition, one place is the correct shape; a slice-local halt would fire on a condition the global conjunction rejects. It was only dangerous in combination with a global halt that could not fire — and the AMENDMENT above restores that halt's reachability with measured arithmetic, which is where the fix belongs. |

**Also re-decided, from the same pass:** the `Design system (vault):` → `Design system:` marker change is **KEPT** — `validate-dispatch-prompt.sh` matches `^\s*Design system\s*:` byte-for-byte, so the parenthesised spelling could never have satisfied the gate that asserts the line landed. That is a spec typo fixed against a deterministic matcher, not a spec loosened to fit an implementation.

## Named backlog (measured or traced, deliberately NOT in this tranche)

- **T1 recoveries** — acceptance NOTE → T2 priority 9 (689 B), provenance anchors/hard-rules back-pointer (880 B), ASCII box rules (344 B in T1 / 860 B whole file). Ship together → `cap_t1` becomes 10240. See the AMENDMENT.
- ~~**Halt restated on its real predicate** — drop the redundant `total > cap_hard` term.~~ **DELETED 2026-07-31 (round 3) — do not re-file.** It was derived from the withdrawn `(a) ⟹ (b)` step. Term (b) is not redundant, and executing this item would have made the halt fire on any unit citing one constitution clause regardless of size — a chain-killer. See the AMENDMENT's withdrawal box.
- **Bind-time anchor excerpt/sha field** (`bind-codebase` schema) — the only way to close anchor content-drift detection without inventing an input.
- **Structured static-analysis field in the framework packs** — until one exists, the template's static-analysis slot stays empty rather than guessing a tool per stack.
- **Pack `## Forbidden patterns` is 772–2 044 B of NON-truncatable T1** (measured; 18.8 % of the max prompt). Making it truncatable would resolve the "pack silently vanished" failure by conceding it — a bolt shipping without pack governance through a sanctioned path that nobody blocks on. Recorded as a real tension; **do not resolve it by relocating the block to T2.**
- **`## Prior failure context`** (Reflexion delivery into the dispatch) — **a NAMED GAP, not a closed question.** `halts-and-handoff.md §Memory layer` specifies the block and the builder does not emit it; under the pointer dispatch the implementer's entire context is the dispatch file, so a retry after `review_critical_unresolved` currently reaches the re-dispatched implementer without its own prior attempt's failure reflection. Closing it needs a priority row here and a truncation rung. The spec keeps the obligation; this entry is its tracking record.

## Known open (carried deliberately — named so they are not lost)

**Every row below was re-verified against the shipped code in round 4, one at a time.** Five round-3 rows named defects that the same tranche had already fixed and are GONE — a known-open list that names fixed defects is worse than none, because it teaches a maintainer to distrust the whole table. What each removed row asserted, and where the fix is recorded, is noted under the table. Each surviving row is a real defect or a real cost; naming it is the requirement, fixing it is a separate change with its own tests.

| # | what | why it is not fixed here |
|---|---|---|
| 1 | **The pack-resolver call sites outside the builder still swallow non-zero exits.** Re-counted in round 4: **11 call sites across 7 validators** — `validate-flow-coverage.sh` (4), `validate-sibling-consistency.sh` (2), and one each in `validate-fanout-parity.sh`, `validate-unit-spec.sh`, `validate-ui-quality.sh`, `validate-cross-cutting-registration.sh`, `validate-ui-deferral.sh` — every one of the form `X=$(bash "$PACK_RESOLVER" … ) \|\| X=""`. (Round 3 recorded "6"; that figure was never right and is corrected here rather than carried.) On the Windows target the App-Execution-Alias stub makes "resolver failed" indistinguishable from "packless project", so those gates go dark at exit 0. The discrimination contract is in §Pack-resolver exit codes and is honoured by the builder and `validate-dispatch-prompt.sh` only. | Pre-existing, spans seven scripts including PreToolUse-blocking gates; deserves its own change and its own portability tests. |
| 2 | **The PostToolUse hook decodes `BASH_CMD_B64` three times per Bash event** (`hooks/post-tool-use` — one Python decode plus two `base64 -d` pipes). One decode into a shell variable would serve all three consumers; at ~220 ms/spawn on the CrowdStrike laptops the extra decodes are a real per-Bash-call cost. | Consolidating them touches a hot path that fires on every Bash call in every session; the risk of a regression there outweighs the saving in this round. |
| 3 | **A moat test still pins `cap_hard ≤ 12906`** as a regression rail (`tests/moat/test-dispatch-prompt-cascade.sh`, assertion I4). That ceiling was derived from the withdrawn arithmetic and is struck from this file. | Weakening or deleting an assertion without a code change that justifies it is not something this round will do. The pin must be **re-grounded by measurement** or dropped in a change that says so; until then it is documented here so nobody reads `12906` as a live bound. |
| 4 | **`total` under-reports the emitted file.** Four blocks — the `PROVENANCE` appendix, the `TIER 2` banner, the `### T2 budget tracker` block and the `TIER 3` banner + pointer list — are written into `dispatch-prompt.md` outside `consumed_t1 + consumed_t2`, and none sits on a cascade rung. (The title and `TIER 1` banners are NOT among them; they are inside `consumed_t1`.) §Size check DISCLOSES this and the tracker now reports `file_total` beside `total`; neither closes it. | Closing it is a builder change (budget the appendix into the cascade, or make the on-disk size the budgeted figure). Round 4 fixed what the enumeration SAYS; it did not change what the cascade COUNTS. |
| 5 | **Design-lens screenshots still land in `<bolt-dir>/views`** (`review-panel.md §Live-app capture`, still live). They are controller-written lens inputs and belong under `<vault>/lens-inputs/U-XXX/views/` by the same reasoning that placed the design slice there. | Moving them changes `capture-views.sh --out` and the procedure that calls it. Named as the candidate to follow; see §Handing the slice to the design lens. |
| 6 | **A failed run can now leave a STALE prompt for the advisory validator to pass.** This is the second-order consequence of removing the pre-assembly unlink, and removing it was still correct (the unlink destroyed correct artifacts). `hooks/post-tool-use` fires `validate-dispatch-prompt.sh` on any Bash call matching `build-dispatch-prompt.sh` **regardless of the builder's exit code**, and the validator globs `<vault>/*/bolts/*/dispatch-prompt.md` with **no freshness check of any kind** (verified in round 4: no mtime read, no exit-code input). So after an exit 2 or exit 4 it can read the PREVIOUS attempt's prompt and write a passing advisory state where the unlink used to make it go dark on "no emitted prompt found". | The fix is a freshness signal the validator can act on (the hook already knows `BASH_EXIT_CODE`), not a return of the unlink — reintroducing the unlink would trade a stale advisory state for a destroyed artifact, which is the worse of the two. It is a validator + hook change, and it is advisory-surface only: no dispatch decision is made from this state. |

**Removed in round 4 because the code no longer matches the complaint** (each verified by running the builder, not by reading a report):

- *"`truncation_exhausted: true` is a hardcoded literal."* **False** — it is `all_1_to_8_at_floor`, derived, with the vacuity documented at the assignment. 
- *"The `## Per-locked-field policy` header row is skipped by a name allowlist."* **False** — it is dropped positionally (row 1, because row 2 is the alignment row). Round 4 closed the converse defect this created; see §`DO NOT MODIFY:`.
- *"`design_slice_path` is written for units that are NOT `ui_bearing`."* **Fixed in round 4** — the write is gated on `ui_bearing`, the same gate the `design_slice` section uses. See §Handing the slice to the design lens.
- *"The exit-2 / exit-4 'target unlinked' contract is FALSE in five shipped places."* **Fixed in round 4** — all six sites (the five named plus the §Exit codes narrative) now state the temp-and-rename guarantee, and §Builder contract requirement 2 forbids a pre-assembly unlink outright. The row's second-order consequence was NOT fixed with it and survives as row 6 above.
- *"The gap enumeration names the wrong banners."* **Fixed in round 4** — in both places (this file's tracker template and the builder's injected block).
