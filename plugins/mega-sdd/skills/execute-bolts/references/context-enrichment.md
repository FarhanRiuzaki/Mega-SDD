# execute-bolts — Step 4.5 tiered context enrichment per bolt

Assembly logic for the bolt-dispatch prompt. Implements the 10 AI-executor principles. Populates the T1/T2/T3 sections of the bolt-subagent dispatch-prompt template (listed in SKILL.md). Total dispatch prompt budget ≤9KB target; hard cap 12KB → halt `dispatch_prompt_too_large` (the progressive T2 budget tracker absorbs most cases first).

## Contents
- TIER 1 (always included)
- T2 budget tracker
- T2 section priority + truncation cascade
- Halt path + soft-budget warnings
- TIER 2 (conditional)
- Starterkit slice: read
- Starterkit slice: build
- Starterkit slice: §patterns wiring
- Starterkit slice: code-slice (reference exemplar)
- Starterkit slice: inject
- TIER 3 (reference-only)
- Size check
- Log final prompt
- Anti-hallucination rails

## TIER 1 (always included, target ≤2KB)

- Unit body (frontmatter + body sections).
- Halt vocabulary block (halt types + YAML templates).
- Self-assessment vocabulary template.
- Atomic commit discipline reminder.
- Anti-context block (DO NOT MODIFY / DO NOT REPLICATE / DO NOT WRITE / DO NOT COMMIT IF).
- Provenance trailer template.
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
| 8 | `starterkit_slice` | libs → top 10; ui_ux.idioms → top 3 (see slice cascade below) | per slice cascade (halt if still over) |
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
- **Starterkit context slice:** see the slice sub-sections below.
- Confidence labels per claim (HIGH from binding C-NNN, MEDIUM from KB inference, LOW from heuristic with rationale).
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

## Starterkit slice: read

```
Path: <project>/.mega-sdd/codebase/starterkit-context.yaml

IF file absent → skip build + inject; do not inject the starterkit slice into T2
                 (the DESIGN slice below still applies — it is independent of starterkit)
IF file present → parse YAML
  IF parse fails → log warning; emit `deep_scan_cache_corrupt` soft halt; skip
  IF starterkit_context.partial == true → note partial_slices for slice availability
Read unit.frontmatter.starterkit_relevance array (from generate-units Step 7.7.e)
IF unit.starterkit_relevance is missing OR empty → skip build + inject
```

## Starterkit slice: build

For each relevance flag in `unit.starterkit_relevance`, include ONLY that slice from `starterkit-context.yaml`:

```
slice = {}

IF "auth" in unit.starterkit_relevance AND starterkit_context.auth exists:
  slice.auth = starterkit_context.auth (lib, mechanism, user_model only — exclude routes, _source)

IF "authz" in unit.starterkit_relevance AND starterkit_context.authz exists:
  slice.authz = starterkit_context.authz (lib, mechanism, role_source, declarations — exclude _source)

IF "ui_ux" in unit.starterkit_relevance AND starterkit_context.ui_ux exists:
  slice.ui_ux = starterkit_context.ui_ux (layout_extends, notification_lib, idioms, AND design_tokens — exclude _source)
  # TEMPLATE FLOW IS AUTHORITATIVE: the starterkit design_tokens/layout/idioms above WIN. Anything
  # from design_system only SUPPLEMENTS them — it must never override the scanned template.
  IF vault.design_system present (vault-contract.md §design_system):
    slice.design_system = vault.design_system (style, palette, typography, a11y_level, source — exclude provenance, which is audit-only)
    IF design_system.source == "scanned-template":
      # the `Design system:` line restates the TEMPLATE's own style/tokens; the design-intelligence
      # slice (style-principles/ux-rules) is injected ONLY as gap-fill, explicitly subordinate to the
      # starterkit tokens already in the prompt — the bolt follows the repo's existing flow.
    ELSE:  # source == design-intelligence-recommend or prd (greenfield / explicit source)
      # pull the matching slice of references/design-intelligence: style-principles[style]
      # (traits + CSS keywords + anti-patterns) and the a11y rows of ux-rules.md, as injected text
      # so the bolt renders ON the chosen style.
    # ALL of this is INJECTED TEXT — never a Skill-invoke.
  # design_tokens (colors/spacing/fonts) is INCLUDED in the ui_ux slice. A UI bolt that never
  # sees the project's colors/spacing/fonts re-invents generic defaults; injecting the actual
  # tokens anchors the view to the design system. design_tokens is MID-priority in the
  # truncation cascade (truncated before code_examples, NOT first-dropped). The deterministic
  # validate-dispatch-prompt.sh asserts the emitted prompt carries a `Design tokens:` line for
  # ui_ux units (non-no-op-able); this prose is defense-in-depth.

IF "libs" in unit.starterkit_relevance AND starterkit_context.libs exists:
  slice.libs = filter(starterkit_context.libs, by usage_hint overlap with unit.target_files)
  (NOT the full inventory — only libs whose usage_hint contains any of unit.target_files paths/prefixes)

# Map §6 fallback — codebase pattern signatures travel even WITHOUT a deep scan.
# When starterkit-context.yaml is absent (regex-tier / shallow / no-deep-scan runs),
# codebase-map.md §6 Pattern signatures is the only pattern source the scan produced —
# deliver it instead of letting the bolt re-invent generic defaults.
IF starterkit_context absent AND codebase-map.md §6 (Pattern signatures) present:
  slice.map_patterns = §6 rows verbatim (auth pattern, error handling, state, view/component pattern)
  # emitted as one `Codebase patterns:` line in the dispatch prompt — "new code matches these
  # unless the unit's Hard rules say otherwise". Informational context, never a gate.
```

## Design slice: build + inject (INDEPENDENT of starterkit — the greenfield pipe)

> Closes the clinic-project audit gap (2026-06-12): generate-intent wrote a full
> `vault.json design_system` (style/palette/typography/a11y picked from
> `design-intelligence/product-style-map.yaml`), but the only injection path lived
> INSIDE the starterkit branch above — greenfield projects have no
> starterkit-context.yaml, so UI bolts received ZERO design guidance and rendered
> default-browser ("kuno") UI. This slice is built whenever the unit ships UI files,
> starterkit or not.

```
ui_bearing = any target_files path matches the active pack `## UI quality signatures`
             view_glob, OR matches the universal frontend shapes:
             *.blade.php, *.html.erb, *.twig, *.jsx, *.tsx, *.vue, *.svelte,
             *.html, *.css, components/**, pages/**, views/**, templates/**

IF NOT ui_bearing → skip (no design slice for pure-backend bolts)
IF slice.ui_ux already built above (starterkit path) → skip (template is AUTHORITATIVE;
   the starterkit branch already carries design_system as supplement)

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

## Starterkit slice: §patterns wiring

The §patterns block is wired independently of `starterkit_relevance` — it triggers on `target_files` match against pack-discovered locations. (Closes the regression where the §patterns block was built but never injected, so the bolt was told "follow starterkit conventions" without being told what they ARE.)

```
IF starterkit_context.patterns exists AND unit.target_files is non-empty:
  slice.patterns = {}

  # component is listed BEFORE view so the more-specific component subdir
  # (e.g. resources/views/components/) location-matches first.
  FOR each pattern_category in [controller, data_model, request_validator, business_logic, test, schema_migration, route, component, view]:
    pattern = starterkit_context.patterns[pattern_category]
    IF pattern is None:
      CONTINUE

    has_location = pattern.location is not None
    matched = False

    FOR each target_file in unit.target_files:
      # PRIMARY: location prefix match (most discriminating)
      IF has_location:
        location_norm = pattern.location.rstrip("/") + "/"
        IF target_file.startswith(location_norm):
          slice.patterns[pattern_category] = pattern
          matched = True
          BREAK

      # FALLBACK: naming-pattern match against basename — ONLY when pattern.location is null
      # (e.g. file-based-routing frameworks where the convention is naming, not directory).
      # Generic patterns like "{Model}<ext>" match ANY PascalCase basename including controllers —
      # false-positive across categories. Location-primary avoids this.
      IF (not has_location) AND pattern.naming is not None:
        naming_regex = compile_pattern_to_regex(pattern.naming, pattern.extension)
        basename = path.basename(target_file)
        IF naming_regex AND naming_regex.search(basename):
          slice.patterns[pattern_category] = pattern
          matched = True
          BREAK
```

**Matching semantics:** location is the primary discriminator. Naming-fallback fires only when `pattern.location is null` (= the framework genuinely has no directory convention for that category — e.g. Next.js file-based routing, Express where handlers live anywhere). Location-primary is conservative and avoids crowding T2 with false-positive categories.

`compile_pattern_to_regex` converts a pack naming pattern (e.g. `{Model}Controller<ext>` or `{Model}.handler.ts`) by replacing `{Model}` → `[A-Z]\w+`, `{model}` → `[a-z_]+`, `<ext>` → `re.escape(extension)`, anchored with `$`. On compile failure → log + skip the naming-regex fallback (location match still applies if available).

Matching is conservative: ONE target_file match per category sets the slice; absence of any match means the unit doesn't touch that category and it's omitted (no false-positive injection).

## Starterkit slice: code-slice (reference exemplar)

Few-shot anchoring: when a pattern category matches, embed an actual code sample from the starterkit so the bolt subagent has a concrete reference to follow (not just a location/naming hint).

```
slice.code_examples = {}

# Categories that get a code exemplar. controller is the original walking skeleton;
# view/component give a ui_ux unit a REAL rendered-view few-shot, not a controller-only skeleton.
FOR each (category, source_list) in [
    ("controller", starterkit_context.patterns.controller._source),
    ("view",       starterkit_context.patterns.view._source),
    ("component",  starterkit_context.patterns.component._source),
]:
  IF slice.patterns.<category> does NOT exist:   # unit doesn't touch this category
    CONTINUE
  IF source_list is empty:
    CONTINUE

  # EXEMPLAR SELECTION: choose by exemplar_selection: linter-clean — the cleanest/most-idiomatic
  # sample, NOT source_list[0]. scan-codebase tags each pattern category with `exemplar_selection`
  # + orders `_source` best-first (cleanest first). Pick the FIRST entry whose file lints clean /
  # carries no scaffold tells; fall back to source_list[0] only if none is tagged. NEVER blindly
  # take [0] for view/component — a raw-scaffold view would anchor the bolt to exactly the tells
  # the UI-quality gate flags.
  chosen_source = first(source_list where exemplar_is_linter_clean) OR source_list[0]
  example_path = chosen_source.split(":")[0]   # strip line-range suffix
  full_example_path = <project_root> / example_path

  IF full_example_path exists AND is a regular file:
    file_size = stat(full_example_path).st_size

    IF file_size < 3072:   # <3KB → include full
      slice.code_examples.<category> = {path: example_path, content: read_text(full_example_path), truncated: false}
    ELSE:                  # ≥3KB → truncate to first 100 lines + marker
      lines = read_text(full_example_path).splitlines()[:100]
      slice.code_examples.<category> = {
        path: example_path,
        content: "\n".join(lines) + "\n# ... (truncated at 100 lines — see full file via Read tool)",
        truncated: true,
      }
  ELSE:
    # _source path absent on disk → skip the code example, NOT a halt (pattern still injected without code)
    log "starterkit.<category>._source not found on disk: <full_example_path>"
```

**Scope:** controller + view + component categories. For a `ui_ux`-relevance unit whose `target_files` include views/components, the view/component exemplar is the load-bearing one. The deterministic `validate-dispatch-prompt.sh` asserts the emitted ui_ux prompt carries a view/component exemplar (`exemplar_missing` otherwise); this prose is defense-in-depth. The remaining categories (data_model / request_validator / business_logic / test / schema_migration / route) stay deferred — identical pattern, extend the loop once telemetry confirms.

**Anti-halu rail:** `slice.code_examples.<category>.path` MUST equal the file actually read (provenance); never invent or substitute. The chosen exemplar must be a real `_source` entry — selecting by linter-clean re-ORDERS the real candidates, it never fabricates one.

**Slice truncation order** if the slice exceeds the T2 budget (design_tokens is MID-priority):
1. Truncate `slice.libs[]` — keep top 10 by relevance score (overlap count with target_files).
2. If still over → truncate `slice.code_examples.<category>.content` to first 50 lines; mark `truncated: true` (controller/view/component alike).
3. If still over → truncate `slice.ui_ux.idioms[]` to top 3.
4. If still over → compact `slice.ui_ux.design_tokens` — keep `colors` + `fonts`, drop `spacing` detail to `spacing=<scale-name|default>`. **design_tokens is MID-priority: compacted/dropped only AFTER libs + idioms, and BEFORE code_examples (step 5). NEVER first-dropped.** (The `Design tokens:` line is retained as long as any token survives, so validate-dispatch-prompt.sh still sees it.)
5. If still over → drop `slice.code_examples` entirely (patterns metadata still preserved).
6. If still over → drop the remaining `slice.ui_ux.design_tokens` line.
7. If still over → emit halt `dispatch_prompt_too_large` (chain stops).

## Starterkit slice: inject

Populate the T2.3 "Starterkit context (relevant slice)" section in the bolt-subagent dispatch-prompt template (listed in SKILL.md) with the built slice:

```
### Starterkit context (relevant to this unit)

<IF slice.auth present:>
Auth: lib=<slice.auth.lib>, mechanism=<slice.auth.mechanism>, user_model=<slice.auth.user_model>
</IF>

<IF slice.authz present:>
Authz: lib=<slice.authz.lib>, mechanism=<slice.authz.mechanism>, declarations=<slice.authz.declarations[].name joined by ", ">
</IF>

<IF slice.ui_ux present:>
UI/UX: extends=<slice.ui_ux.layout_extends>, notification=<slice.ui_ux.notification_lib>, idioms=[<slice.ui_ux.idioms joined by "; ">]
<IF slice.ui_ux.design_tokens present:>     # emit the literal `Design tokens:` marker line
Design tokens: colors=<design_tokens.colors as compact map>; spacing=<design_tokens.spacing>; fonts=[<design_tokens.fonts joined by ", ">]
</IF>
<IF slice.design_system present:>           # emit the literal `Design system:` marker line (validate-dispatch-prompt.sh asserts it)
Design system: <design_system.style>/<design_system.palette> (type <design_system.typography>, a11y <design_system.a11y_level>, source <design_system.source>) — render on this style; see injected style-principles + ux-rules. When source=scanned-template, the starterkit tokens above are authoritative.
</IF>
</IF>

<IF slice.libs present AND non-empty:>
Libs in scope: <for each lib in slice.libs: <lib.name>@<lib.version> (used in: <lib.usage_hint joined by ", ">)>
</IF>

<IF slice.patterns present AND non-empty:>
### Starterkit code patterns (follow these conventions)

<for each category in slice.patterns:>
- <category>:
    location:  <pattern.location>
    naming:    <pattern.naming>
    extension: <pattern.extension>
    <IF pattern.extras is non-empty object:>
    extras:    <yaml-flow-style representation of pattern.extras>
    </IF>
    _source:   <pattern._source[0] (single citation; first entry only — anti-halu)>
</for>
</IF>

<IF slice.code_examples present AND non-empty:>
### Reference code example (from starterkit)

<for each category in slice.code_examples (controller, view, component):>     # emit the literal `Pattern:`/`File:` marker lines
Pattern: <category>
File:    <slice.code_examples.<category>.path>
<IF slice.code_examples.<category>.truncated:>(truncated — full file available via Read tool)</IF>

```<file-extension>
<slice.code_examples.<category>.content>
```

Follow this style for new <category> files. Do not deviate from the conventions shown above (for a view/component: the layout extend, responsive grid, relation-resolved human labels, and notification idiom) unless the unit explicitly requires it.
</for>
</IF>

<IF unit.starterkit_relevance contains "ui_ux":>     # frontend-design heuristics as INJECTED CONTEXT (NOT a Skill-invoke)
### UI design quality heuristics

Inject the body of `plugins/mega-sdd/references/ui-design-heuristics.md` here (stack-agnostic
design-quality guidance — visual hierarchy, every state shown, value formatting, accessibility,
consistency). This is HOOK/DISPATCH-INJECTED TEXT the bolt subagent reads inline — it is NOT a
prose instruction to invoke the `frontend-design` skill (prose-only Skill-invoke wire-ups
historically no-op'd). The deterministic validate-dispatch-prompt.sh asserts the design tokens +
view exemplar above actually landed.
</IF>
```

Sections for absent relevance flags / unmatched categories are OMITTED entirely (not emitted as empty headers). Wall-clock cost: 0s when `starterkit-context.yaml` is absent (read exits early); ≤500ms when present (parse + filter + format).

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
- Starterkit slice budget: the T2 starterkit slice MUST be capped per the slice cascade above. When the T2.3 starterkit section is present, the bolt subagent MUST honor it: extend the named layout, use the named notification lib, use only the listed libs (no inventing alternatives). Violating code is rejected at the post-flight check.
