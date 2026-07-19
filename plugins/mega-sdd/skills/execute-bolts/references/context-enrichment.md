# execute-bolts — Step 4.5 tiered context enrichment per bolt

Assembly logic for the bolt-dispatch prompt. Implements the 10 AI-executor principles. Populates the T1/T2/T3 sections of the bolt-subagent dispatch-prompt template (listed in SKILL.md). Total dispatch prompt budget ≤9KB target; hard cap 12KB → halt `dispatch_prompt_too_large` (the progressive T2 budget tracker absorbs most cases first).

## Contents
- TIER 1 (always included)
- T2 budget tracker
- T2 section priority + truncation cascade
- Halt path + soft-budget warnings
- TIER 2 (conditional)
- Reuse slice: build
- Map §6 fallback (starterkit-context absent)
- Design slice: build + inject (INDEPENDENT of starterkit — the greenfield pipe)
- TIER 3 (reference-only)
- Size check
- Log final prompt
- Anti-hallucination rails

## TIER 1 (always included, target ≤2KB)

- Unit body (frontmatter + body sections).
- **Contracts pointer line** (halt / self-report / rollback / provenance / atomic — agent-carried by the bolt-implementer system prompt; one line naming `agents/bolt-implementer.md` + the plugin version at dispatch; see `bolt-dispatch-prompt.md §Contracts`). The constant blocks themselves are NEVER re-embedded in T1.
- **Provenance values block** (per-unit: unit_id, vault sha256, claim ids + texts, anchors, active Hard-rule ids — the values the agent fills into its agent-carried trailer shape).
- Anti-context block (DO NOT MODIFY / DO NOT REPLICATE / DO NOT WRITE / DO NOT COMMIT IF).
- **Acceptance-test provenance NOTE:** if the unit's `acceptance_test._authored_by` is `same-pass` OR `adversarial-review-failed` (weak blind-spot signals per `generate-units/references/adversarial-test-prompt.md`), append a NOTE warning the bolt subagent the acceptance_test may have missed bugs the implementation introduces. The subagent's self-assessment is instructed to flag `acceptance_test_concern: <details>` if the implementation passes the test but feels under-validated. The NOTE template lives in the dispatch-prompt template (listed in SKILL.md).
- **Reuse index path (ALWAYS — even when `reuse_candidates` is empty):**
  `Reuse index: .mega-sdd/codebase/reuse-index.yaml — your PRIMARY reuse lookup surface; scan it for any capability you are about to write (you have Read/Grep). The reuse_candidates above are a fast-path hint, NOT the boundary.`
- **`unit.reuse_candidates`** (fast-path hint — include when present; empty list is fine to omit the hint line, but the reuse-index path line above is unconditional).

## T2 budget tracker

Replaces a prior single-halt-at-cap enforcement with running T2 consumption tracking + progressive section-level truncation by priority.

```
running_budget = {
  cap_hard:      12288   # 12KB hard cap — headroom for §patterns + controller code-slice
  cap_target:    9216    # 9KB total target
  cap_t1:        2048    # 2KB T1 budget
  cap_t2:        10240   # 10KB T2 budget (walking-skeleton: more context reach over a tight cap)
  consumed_t1:   <bytes of TIER 1>
  consumed_t2:   0       # accumulates during TIER 2 load
  remaining_t2:  cap_t2
  warnings:      []      # truncation events (logged to provenance)
}
```

After EACH T2 section loads, update the tracker: `consumed_t2 += section_bytes`; `remaining_t2 = cap_t2 - consumed_t2`. IF `remaining_t2 < next_section_min_viable_bytes` → apply progressive truncation (below) BEFORE loading the next section.

## T2 section priority + truncation cascade

Ordered MOST disposable (priority 1) → MOST critical (priority 8). When budget is tight, truncate the top of the list first. Each truncation is appended to `running_budget.warnings` as `{section, rule_applied, bytes_saved}`.

| Priority | T2 section | Truncation cascade | Drop floor |
|---|---|---|---|
| 1 | `validation_hints` | drop expected-output patterns; keep test commands only | drop section entirely |
| 2 | `historical_memory` | last 5 → last 3 → last 1 → drop | drop section |
| 3 | `reuse_slice` | trim to top 5 entries by target_files overlap → top 3 → top 1 | "+N more — read reuse-index.yaml directly" (never fully dropped — at minimum 1 hint line survives) |
| 4 | `kb_anti_patterns` | top 3 → top 1 → drop | drop section |
| 5 | `confidence_labels` | per-claim → aggregate ("HIGH×N / MEDIUM×N / LOW×N") | drop section |
| 6 | `depends_on_summaries` | N most-recently-touched files only | keep at least 1 upstream |
| 7 | `framework_pack_rules` | top 5 → top 3 → top 1 | keep top 1 always |
| 8 | `starterkit_slice` | libs → top 10; ui_ux.idioms → top 3 (per `starterkit-enrichment.md §Slice truncation order`) | per the slice cascade (`starterkit-enrichment.md`; halt if still over) |
| 9 (NEVER drop) | `constitution_clauses` | NEVER truncate — LOCKED security/compliance content | n/a — if it alone exceeds → halt `dispatch_prompt_too_large` |

## Halt path + soft-budget warnings

`dispatch_prompt_too_large` fires ONLY when: all disposable T2 sections (priorities 1–8) are already truncated to their drop floor AND total still exceeds `cap_hard` AND `constitution_clauses` alone is non-truncatable. In practice this halt now indicates a true config issue (a unit references too many constitution clauses for one bolt) requiring spec-level adjustment, not a bolt-fixable problem.

**Soft-budget warning** — when `consumed_t2 > cap_t2` but `total < cap_hard`: log a warning (NOT a halt): `"T2 exceeded soft cap: target=<cap>, actual=<N> — truncation applied"`; apply truncation to bring T2 back under target; the bolt proceeds with truncated context + a provenance trail visible to the subagent in the `### T2 budget tracker` section. The subagent is instructed: if the tracker shows truncated sections, set `confidence: MEDIUM` for any claim that depended on truncated context.

## TIER 2 (conditional, target ≤10KB, budget-tracked)

- depends_on chain: 1-line summary per upstream bolt (read each `bolt-report.md` self-assessment).
- Framework pack rules: filter the pack file by `path_glob` match against this unit's `target_files`.
- Constitution clauses: ONLY clauses referenced in this unit's `vault_source` sections.
- KB anti-patterns: filter the KB by this unit's domain tags.
- Historical memory: filter `<project>/.mega-sdd/memory/outcomes.md` for bolts touching similar files OR pattern — last 5 only. Active instincts (`memory/instincts/*.yaml`, confidence ≥0.7) whose `domain` matches the unit (ui → UI-bearing, security → risk-signal units, conventions/testing → all) join this slice as one line each — same budget, same truncation tier (per `memory/references/instincts.md`).
- **Starterkit context slice:** the auth/authz/ui_ux/libs slices (the `Auth:` / `Authz:` / `UI/UX:` / `Design tokens:` / `Design system:` / `Libs in scope:` lines), the §patterns block, and the reference code exemplar — read/build/inject machinery per `starterkit-enrichment.md` (routed from SKILL.md), loaded ONLY when `<project>/.mega-sdd/codebase/starterkit-context.yaml` exists. When that file is absent, only the Map §6 fallback below applies.
- Confidence labels per claim (HIGH from binding C-NNN, MEDIUM from KB inference, LOW from heuristic with rationale). **Anchor freshness (assembly-time):** before stamping a label on an `## Anchors` entry, probe it — path exists; when the binding recorded an excerpt/sha, the region still matches. A failed probe injects `ANCHOR STALE (verify before use)` in place of the label (never a bind-era HIGH re-stamped mid-batch); the streaming `Anchors verified N/N` line reflects the probe result.
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

## Map §6 fallback (starterkit-context absent)

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
    design_slice.style    = the matching style-principles[style] rows
                            (traits + CSS keywords + anti-patterns)
    design_slice.ux       = ux-rules.md a11y rows + form/feedback rows
  ELSE:
    design_slice.note     = "no design_system in vault — raise as OQ at chain end"
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
a rework cycle, not a nice-to-have). ALL injected text — never a Skill-invoke.
The review-panel `design-reviewer` lens receives the SAME slice as its rubric, so
the implementer and the reviewer judge against one contract.

## TIER 3 (reference-only — NOT embedded; read on demand)

Full upstream bolt-reports, full constitution, full KB domain files, full memory tables, full framework pack.

## Size check

- Compute final `total = consumed_t1 + consumed_t2`.
- IF `total > cap_hard` → halt `dispatch_prompt_too_large` with details `{cap_hard, total, t1_bytes, t2_bytes, warnings: running_budget.warnings, truncation_exhausted: true}` — should only fire when `constitution_clauses` alone exceeds budget (progressive truncation absorbs most cases first).
- IF `consumed_t2 > cap_t2` (soft cap exceeded but under hard cap) → emit a warn-only log line; continue dispatch with the truncated prompt.
- Inject the `### T2 budget tracker` section into the dispatch prompt:
  ```
  ### T2 budget tracker
  consumed_t1: <X bytes> (cap 2048)
  consumed_t2: <Y bytes> (cap 10240, hard 12288)
  truncations_applied:
    - <section>: <rule_applied> (saved <Z bytes>)
    ...
  instruction_to_subagent: "If your self-assessment references information that was truncated above, mark its confidence: MEDIUM and note the truncation in your bolt-report.md self-assessment section."
  ```

## Log final prompt

Ensure the bolt dir exists first — `mkdir -p <vault>/bolts/U-XXX/` (idempotent; it was already created at execute-bolts Procedure Step 0, but never assume it). Then write the assembled prompt to `<vault>/bolts/U-XXX/dispatch-prompt.md` for provenance + auditability, then dispatch via superpowers `executing-plans` with the enriched prompt as the plan body.

## Anti-hallucination rails

- T2 filtering MUST cite a source for inclusion (e.g. "framework pack rule X loaded because target_files matched glob Y").
- The anti-context block is populated from actual data sources (data-mutation-policy.md, KB, framework pack) — NEVER invented.
- Self-assessment confidence MUST be numeric `0.0–1.0` (not strings); halt if omitted.
- A provenance trailer is MANDATORY in every modified file — the post-flight scan verifies its presence; missing → halt `provenance_missing`.
- Starterkit slice budget: the T2 starterkit slice MUST be capped per `starterkit-enrichment.md §Slice truncation order`. When the T2.3 starterkit section is present, the bolt subagent MUST honor it: extend the named layout, use the named notification lib, use only the listed libs (no inventing alternatives). Violating code is rejected at the post-flight check.
