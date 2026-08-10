# context-enrichment.md — amendment & measurement archive (the 2026-07-31 rounds)

**Date:** 2026-08-11
**Status:** ARCHIVE — historical record. **Nothing in this file is operative.**
**Source:** every block below was extracted VERBATIM (byte-for-byte) from `plugins/mega-sdd/skills/execute-bolts/references/context-enrichment.md` by the Phase-3 reference diet (spec `2026-08-11-audit-phase3-reference-diet.md` §D2, Iron rule 4). Each block sits under a header naming the reference section it came from. The OPERATIVE sentences those blocks carried were extracted FIRST and remain in the reference — the living contract (the T1/T2 contents, the 9-row cascade, the budget caps in `running_budget`, the halt conjunction, the anti-hallucination rails, §Known open, §Re-decided amendments, and the builder contract) lives THERE, not here. This file holds the amendment/measurement history only: withdrawn boxes, struck derivations, dual byte-accounting tables, round-3/4 fix narratives, the "Removed in round 4" list, and dated amendment markers.

**Do not restore any struck or withdrawn text below into the reference.** Where a block says an assertion "is struck", the strike IS the record — the assertion was published, later falsified, and is preserved here so the falsification cannot be silently forgotten.

---

## 1. The retired `cap_t1 = 2048` heading note

*Was the blockquote under the `## TIER 1` heading. The operative content (no T1 size target; `cap_t1` = 12288 reporting threshold; crossing it = a `generate-units` atomicity smell) stays in the reference.*

> **There is no T1 size target.** The `≤2KB` that stood in this heading was the retired `cap_t1 = 2048`, which the AMENDMENT below measures as never satisfiable — the builder's own non-body T1 scaffolding floors at 2 385 B on a near-empty unit, so the heading's target fired on 123/123 measured runs. `cap_t1` is now **12288** and it is a **REPORTING THRESHOLD, not a bound**: T1 is never truncated and the unit body is embedded verbatim, so no value of `cap_t1` bounds T1. Crossing it is a `generate-units` atomicity smell (a unit too big to be one bolt), not a budget defect. Read `## AMENDMENT 2026-07-31` before quoting any T1 figure.

---

## 2. `DO NOT MODIFY:` policy-table parser — round-3/4 status narrative

*Was the status sub-bullet under the `DO NOT MODIFY:` labelled-union rule in `## TIER 1`. The operative parser contract (structural header drop in BOTH directions, discards recorded, §W pins) stays in the reference.*

  - **Status 2026-07-31 (round 4): the labelled union IS implemented, and the table parser is now structural in BOTH directions** — an earlier revision of this bullet asserted in bold that the builder read only (b) and labelled it as the whole line. That assertion is FALSE and is struck: the builder locates `data-mutation-policy.md` under the KB roots, reads both `## Per-locked-field policy` and `## Entity-level summary` with per-table marker semantics, and stamps a per-entry source. The header row is dropped **positionally** — it is row 1, and it is a header because row 2 is the `|---|` alignment row — not by a header-word allowlist; a table headed `| Field | Tier | Policy |` no longer emits `Field` as a locked path. **A round-3 revision of this bullet published that allowlist as an open defect; it was fixed in the same tranche and that text is struck.** The converse is closed too, and it was the round-4 fix: a dash-only FILLER row no longer eats the `[LOCKED]` entry above it (the alignment row is row 2 and nothing else), and any row the parser discards is recorded in `sections_omitted` with a reason. Both directions are rails — inventing a locked path and silently losing one are the same invariant-#5 class. Pinned by `tests/derived-artifacts/test-dispatch-prompt-builder-shape.sh` §W (W1–W9).

---

## 3. Reuse-index path — the two-wordings resolution

*Was the lead of the reuse-index-path bullet in `## TIER 1`. The canonical three-line text, the template-wins rule and the do-not-reintroduce rail stay in the reference.*

- **Reuse index path (ALWAYS — even when `reuse_candidates` is empty).** ONE canonical text, resolved 2026-07-31 — this file and `bolt-dispatch-prompt.md §Reuse index` previously carried two different wordings and the builder silently picked one. **The template's wording WINS** (it is the emitted artifact's own shape, and it names Iron Rule 4, which is the agent-side contract the line exists to trigger). Verbatim, three lines:

---

## 4. THE AMENDMENT — the cap numbers, from measurement (in full)

*Was the whole `## AMENDMENT 2026-07-31` section: the 123-run measurement, the T1 distribution and decompositions, the amended-numbers table, the retired identity, the WITHDRAWN algebraic derivation and the struck `cap_hard ≤ 12 906` ceiling, the empirical halt-firing table with its non-vacuity control, the struck term-(b) note, the measured T1-recovery backlog table, and the caveats. A slim operative section under the same heading remains in the reference.*

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

---

## 5. Cascade tier enumeration — the two dated amendments

*Was the paragraph under the T2 priority table. The operative enumeration (8a/8b/8c, 3a/3b, tie discipline, `map_patterns` kept) stays in the reference.*

**Amended 2026-07-31 (contract completeness, separate from the cap amendment):** tier 8 always carried THREE sections but listed one. `map_patterns` (the Map §6 fallback) and `design_slice` were emitted at tier 8 with no row, so a section sat outside the contract — and a rowless `map_patterns` that is permanently `at_floor()` could outrank `design_slice` while `design_slice` was truncated around it. The nine PRIORITIES are unchanged; rows 1–7 and 9 are unchanged verbatim; tier 8 is now enumerated 8a/8b/8c in its already-pinned order. **Amended 2026-08-02 (R2):** tier 3 is likewise enumerated 3a/3b — `symbol_slice` joins at the same priority as `reuse_slice`, stepped after it (3a first) one rung per pass, same tie discipline as tier 8. **`map_patterns` is kept, not removed** — it is the only pattern source a regex-tier scan produces (see §Map §6 fallback), so deleting it would drop real content on exactly the projects with the least context.

---

## 6. Constitution-clause selector — amendment narrative + the retired emitted heading

*Was the lead of the Constitution-clauses bullet in `## TIER 2` and its `Emitted heading — FIXED` paragraph. The three-way selector, the validator note and the fixed heading stay in the reference.*

- **Constitution clauses — selector AMENDED 2026-07-31 (re-decided, narrowed).** The pre-2b phrasing "ONLY clauses referenced in this unit's `vault_source` sections" is genuinely **unimplementable and cannot be restored**: `vault_source` is a scalar and nothing keys a clause to a vault section. But the replacement shipped by the wiring pass — a bare `\b[A-F]-\d{3}\b` scan of the whole unit file — is too wide, and its cost lands on the one section that can force the halt: a clause pulled by a token in a code sample enters priority 9, which is NEVER truncated, so a false positive can push a dispatch over the cap that would otherwise ship. The amended selector is the intersection of three real inputs, in this order:

  **Emitted heading — FIXED.** The section heading is `## Constitution clauses (cited in this unit, resolved in the constitution §C)`. The template's old `## Constitution clauses (referenced by your vault_source)` heading described a selector that has never existed and that this file's own text calls unimplementable — a section whose heading tells the subagent the clause came from its vault source when it came from a token match in its own body, contradicted by the provenance line inside the same section. A heading is a claim about provenance; it gets the same discipline as any other.

---

## 7. Historical memory — round-3 status narrative

*Was the historical-memory bullet in `## TIER 2`. The operative filter contract (join needles, `sections_omitted`, omit-on-zero) and the instincts sentence stay in the reference.*

- Historical memory: filter `<project>/.mega-sdd/memory/outcomes.md` for bolts touching similar files OR pattern — last 5 only. **This text is UNAMENDED and is the contract. Status 2026-07-31 (round 3): the relevance filter IS implemented** — an earlier revision asserted in bold that the builder did not honour it and emitted every run unfiltered. That assertion is now FALSE and is struck: the builder joins on the unit id plus the `target_files` basenames, drops non-matching runs, records them in `sections_omitted`, and omits the section entirely on zero matches. The word *relevant* in the emitted header is therefore a claim the builder can back. (This says the filter exists and joins on those needles; it makes no claim about the join's recall.) Active instincts (`memory/instincts/*.yaml`, confidence ≥0.7) whose `domain` matches the unit (ui → UI-bearing, security → risk-signal units, conventions/testing → all) join this slice as one line each — same budget, same truncation tier (per `memory/references/instincts.md`).

---

## 8. Design lens — round-2/3 narrative + the measured double-billing

*Was in `### Handing the slice to the design lens`: the dated AMENDED marker, the measured cost-fix paragraph, the amended rail lead-in, and the round-2 falsification narrative. The path mechanism, the purpose-stated rail and its three application bullets stay in the reference.*

The review-panel `design-reviewer` lens judges against the SAME slice, so the
implementer and the reviewer share one contract. **AMENDED 2026-07-31 (round 3): the slice reaches the lens as a PATH to a controller-written lens-input file, not as a pasted string.** The builder writes the emitted section verbatim to

**Why the change — this is a COST fix, and the earlier text-only rule was a MEASURED mistake, not an abandoned rail.** The round-2 shape returned the slice as `design_slice_text` on stdout and required the controller to paste it verbatim into the lens prompt. Measured, that bills the same string twice per greenfield UI bolt — once inbound as a tool result and once outbound as the controller's paste — and the outbound leg alone was the larger term. The rail it was protecting is intact and is stated below; only the carrier changed. **Exact figures, MEASURED 2026-07-31 against shipped code (n = 10 greenfield-UI + 10 starterkit-UI real units):** on a greenfield UI bolt the slice is **9,635 B**; the outbound paste into the lens prompt cost **≈ 2,409 output tok** and is now **one 129-byte path ≈ 32 tok** (saved ≈ 2,377 output tok/bolt, ≈ 823 tok when the `design_slice` truncation rung has fired and the slice is 3,420 B); the inbound stdout member it replaced was **9,911 B** (the JSON-escaped `json.dumps` member, not the 9,635 B file size) against **103–157 B** for the path. On a **starterkit** repo the slice is only **495 B** — D3's saving there is ≈ 366 B, and that arm must never be quoted as the headline. Full method, spread and per-channel breakdown → §Builder contract and `docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md` §2b.

**The rail, stated at its PURPOSE (amended — the round-2 absolute form was falsified by this repo's own live text):**

That is what blind review protects: a lens forming its opinion before it can see anyone else's. It is NOT a blanket prohibition on paths. The round-2 wording — *"no path into `<vault>/bolts/U-XXX/`, not the file, not the directory, not a glob that reaches either"* — was stated absolutely, and `review-panel.md §Live-app capture` (unchanged, live, older than the rail) already routes design-lens screenshots to `<bolt-dir>/views`. An absolute rail that the shipping procedure violates is not a rail; it is an ambiguity a reader resolves by guessing.

---

## 9. §Size check — restored-wording note + the dual byte-accounting DISCLOSURE

*Was the blockquote chain in `## Size check`: the restored-wording narrative, the 31-of-123 measurement, the measured gap by arm, the per-run identity, the round-3 vs round-4 block-boundary accountings, the round-4 CORRECTION, and the two round-4 growth constants. The operative reading (qualifier = terms (a)+(c); §Halt path is the definition) and a slim DISCLOSURE stay in the reference; the gap itself is carried in §Known open row 4.*

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

---

## 10. Builder invocation — the measured OUTPUT-cost table

*Was in `### Invocation` under `## Builder contract`. The `--plugin-root` requirement and the `--quiet` prohibition stay in the reference.*

**The invocation string itself is a measured OUTPUT cost** (the controller emits it every bolt) and it grew when `--plugin-root` became mandatory and the form became multi-line. **MEASURED 2026-07-31, byte-exact on the three-line form above, across BOTH axes:**

| project root | env-var form, emitted LITERALLY | plugin root PRE-EXPANDED (75 B) |
|---|---|---|
| `/Users/me/app` (13 B) | **190 B** | **298 B** |
| this repo's own root (67 B) | **298 B** | **406 B** |

**Which form the controller emits is UNRESOLVED and is published as a band, not guessed.** The SKILL.md template names the plugin-root variable twice, and whether the model emits it literally (bash expands at runtime) or pre-expanded swings the string by **+108 B** — more than the 54-byte project-root spread does. The string grows **+2 B per character of project-root length** (`--cwd` and `--vault` each carry it once). Any residual/ratio headline that quotes this string must state which expansion form and which root length it assumed.

---

## 11. stdout JSON — the pre-fix baseline + the measured current sizes

*Was in `### stdout JSON`. The required key set, the `sections_omitted[]` relocation and the three-stdout-states table stay in the reference.*

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

---

## 12. `design_slice_path` — rename narrative, measured cost, the round-4 gate fix

*Was in `### design_slice_path`. The contract (absent-when-not-UI-bearing, the two extraction branches, the writing rules), the `ui_bearing` gate and the blind-review-rail statement stay in the reference.*

**Renamed and re-carried 2026-07-31 (round 3). The predecessor key was `design_slice_text`, a string on stdout that the controller pasted verbatim into the lens prompt** — see §Handing the slice to the design lens for why it changed (measured double-billing) and for the purpose-scoped rail that makes a path legal here. The rubric is not weakened: it is the same bytes, written once, read once.

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

---

## 13. Named backlog — the struck "drop term (b)" item

*Was in `## Named backlog`. The do-not-re-file rail stays in the reference.*

- ~~**Halt restated on its real predicate** — drop the redundant `total > cap_hard` term.~~ **DELETED 2026-07-31 (round 3) — do not re-file.** It was derived from the withdrawn `(a) ⟹ (b)` step. Term (b) is not redundant, and executing this item would have made the halt fire on any unit citing one constitution clause regardless of size — a chain-killer. See the AMENDMENT's withdrawal box.

---

## 14. Known open — the round-4 re-verification intro + the "Removed in round 4" list

*Was the intro paragraph and the closing list of `## Known open`. The six-row table itself stays in the reference VERBATIM (its rows are cited by number from other references).*

**Every row below was re-verified against the shipped code in round 4, one at a time.** Five round-3 rows named defects that the same tranche had already fixed and are GONE — a known-open list that names fixed defects is worse than none, because it teaches a maintainer to distrust the whole table. What each removed row asserted, and where the fix is recorded, is noted under the table. Each surviving row is a real defect or a real cost; naming it is the requirement, fixing it is a separate change with its own tests.

**Removed in round 4 because the code no longer matches the complaint** (each verified by running the builder, not by reading a report):

- *"`truncation_exhausted: true` is a hardcoded literal."* **False** — it is `all_1_to_8_at_floor`, derived, with the vacuity documented at the assignment. 
- *"The `## Per-locked-field policy` header row is skipped by a name allowlist."* **False** — it is dropped positionally (row 1, because row 2 is the alignment row). Round 4 closed the converse defect this created; see §`DO NOT MODIFY:`.
- *"`design_slice_path` is written for units that are NOT `ui_bearing`."* **Fixed in round 4** — the write is gated on `ui_bearing`, the same gate the `design_slice` section uses. See §Handing the slice to the design lens.
- *"The exit-2 / exit-4 'target unlinked' contract is FALSE in five shipped places."* **Fixed in round 4** — all six sites (the five named plus the §Exit codes narrative) now state the temp-and-rename guarantee, and §Builder contract requirement 2 forbids a pre-assembly unlink outright. The row's second-order consequence was NOT fixed with it and survives as row 6 above.
- *"The gap enumeration names the wrong banners."* **Fixed in round 4** — in both places (this file's tracker template and the builder's injected block).

---
