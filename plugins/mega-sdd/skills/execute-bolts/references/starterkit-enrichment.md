# execute-bolts — Starterkit slice enrichment (Step 4.5.b-starterkit)

**This file is the SPECIFICATION for the starterkit half of `scripts/build-dispatch-prompt.sh`, not a procedure the model runs.** It defines the read/build/§patterns/code-slice/inject machinery for the T2.3 "Starterkit context (relevant slice)" section of the bolt dispatch prompt, and the builder implements it and is tested against it. **The builder applies this whole file ONLY when `<project>/.mega-sdd/codebase/starterkit-context.yaml` exists** (same trigger as generate-units' `starterkit-derivation.md`) — when the file is absent it skips this entire slice and the Map §6 fallback + the Design slice in `context-enrichment.md` (which also owns the budgets + T2 truncation cascade) apply instead. Read it to review or amend builder behavior; where the pseudocode below describes a known defect it is annotated as such and the builder **reproduces it as written** — do not silently "fix" one side.

## Contents
- Starterkit slice: read
- Starterkit slice: build
- Starterkit slice: §patterns wiring
- Starterkit slice: code-slice (reference exemplar)
- Slice truncation order
- Starterkit slice: inject

## Starterkit slice: read

```
Path: <project>/.mega-sdd/codebase/starterkit-context.yaml

IF file absent → skip build + inject; do not inject the starterkit slice into T2
                 (the DESIGN slice in context-enrichment.md still applies — it is
                 independent of starterkit)
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
  # truncation cascade (truncated before code_examples, NOT first-dropped). validate-dispatch-prompt.sh
  # asserts the emitted prompt carries a `Design tokens:` line for ui_ux units — ADVISORY:
  # its state is surfaced via /mega-sdd:analyze, nothing in PreToolUse reads it (per the
  # demotion list); this prose is the operative rail WHEN THE INPUT EXISTS. On a greenfield
  # repo there is no starterkit-context.yaml and therefore no design_tokens at all: the line is
  # legitimately absent and the advisory validator records `tokens_not_injected`. That is an
  # honest absent-input report, NOT a builder defect — emitting a token line there would be
  # fabrication (invariant #5). The Design slice in context-enrichment.md is the greenfield pipe.

IF "libs" in unit.starterkit_relevance AND starterkit_context.libs exists:
  slice.libs = filter(starterkit_context.libs, by usage_hint overlap with unit.target_files)
  (NOT the full inventory — only libs whose usage_hint contains any of unit.target_files paths/prefixes)
```

The starterkit-ABSENT fallback (codebase-map.md §6 pattern signatures → the `Codebase patterns:` dispatch line) stays hot in `context-enrichment.md §Map §6 fallback` — it applies exactly when this file's trigger file is absent.

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

> **KNOWN DEFECT — reproduced as written; amendment pending.** `location.rstrip("/") + "/"` + `startswith` assumes `location` is a DIRECTORY. For a pack whose `route` category declares a single FILE (`route: {location: routes/api.php}`), `target_file.startswith("routes/api.php/")` can never be true, so the route category never matches — and the naming fallback cannot rescue it, because that branch is gated on `location is None`. The builder reproduces this exactly rather than re-deriving the matcher: silently widening the match would change which categories reach T2 and what the §patterns block asserts. Fix it in the spec (e.g. an is-file branch that compares equality) and the builder together, never one alone.

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

**Scope:** controller + view + component categories. For a `ui_ux`-relevance unit whose `target_files` include views/components, the view/component exemplar is the load-bearing one. `validate-dispatch-prompt.sh` asserts the emitted ui_ux prompt carries a view/component exemplar (`exemplar_missing` otherwise) — ADVISORY: surfaced via /mega-sdd:analyze, not a PreToolUse block; this prose is the operative rail **whenever a real `_source` exemplar exists**. When none does (greenfield, or a `_source` path absent on disk) the section is omitted and the validator records `exemplar_missing` — the honest absent-input report; the alternative is inventing an exemplar path, which the anti-halu rail below forbids outright. The remaining categories (data_model / request_validator / business_logic / test / schema_migration / route) stay deferred — identical pattern, extend the loop once telemetry confirms.

**Anti-halu rail:** `slice.code_examples.<category>.path` MUST equal the file actually read (provenance); never invent or substitute. The chosen exemplar must be a real `_source` entry — selecting by linter-clean re-ORDERS the real candidates, it never fabricates one.

## Slice truncation order

This is the tier-**8a** `starterkit_slice` rung ladder of the `context-enrichment.md` cascade (tier 8 also carries `map_patterns` at 8b and `design_slice` at 8c — all three now have rows) — the builder steps ONE rung per pass and re-measures, it does not run the list to completion. If the slice exceeds the T2 budget (design_tokens is MID-priority):
1. Truncate `slice.libs[]` — keep top 10 by relevance score (overlap count with target_files).
2. If still over → truncate `slice.code_examples.<category>.content` to first 50 lines; mark `truncated: true` (controller/view/component alike).
3. If still over → truncate `slice.ui_ux.idioms[]` to top 3.
4. If still over → compact `slice.ui_ux.design_tokens` — keep `colors` + `fonts`, drop `spacing` detail to `spacing=<scale-name|default>`. **design_tokens is MID-priority: compacted/dropped only AFTER libs + idioms, and BEFORE code_examples (step 5). NEVER first-dropped.** (The `Design tokens:` line is retained as long as any token survives, so validate-dispatch-prompt.sh still sees it.)
5. If still over → drop `slice.code_examples` entirely (patterns metadata still preserved).
6. If still over → drop the remaining `slice.ui_ux.design_tokens` line.
7. If still over → the slice is at its drop floor; the halt decision **delegates to the ONE global halt check** in `context-enrichment.md §Halt path` (`dispatch_prompt_too_large` requires the full three-way conjunction — this step never halts on its own, or the slice being tight would fire a halt the global condition rejects). **Re-decided and KEPT 2026-07-31:** one halt, one definition, one place is the right shape; the danger was only ever that the global halt could not fire, and that was fixed where it belonged — `context-enrichment.md ## AMENDMENT 2026-07-31` re-derives the cap numbers from 123 measured runs and proves the conjunction reachable on four units.

**Un-budgeted by this ladder:** `### UI design quality heuristics` (the injected `ui-design-heuristics.md` body, measured ≥4 826 B) has **no rung** — no step drops or trims it, and the builder does not invent an 8th step to do so. Adding one is a spec amendment, not a builder change. Measured consequence, so it is not a theoretical concern: on a UI-bearing unit the tier-8 drop floor cannot fall below that block, and the whole priorities-1-to-8 floor was measured at **6 374 B** on such a unit versus 746–947 B on non-UI units — 47 % of `cap_t2` that no cascade rung can reclaim.

## Starterkit slice: inject

The builder populates the T2.3 "Starterkit context (relevant slice)" section of the bolt-subagent dispatch-prompt template (`bolt-dispatch-prompt.md`, listed in SKILL.md) with the built slice. **The marker lines below are byte-compatible with `validate-dispatch-prompt.sh`'s regexes** (`Design tokens:`, `Design system:`, `Pattern:`, `File:`) — they are matched, not merely read, so re-wording one silently disarms the check that asserts it landed.

> **Absent values are DROPPED, not rendered** (`context-enrichment.md §The absent-value rule`). Every composed line here — `Auth:`, `Authz:`, `UI/UX:`, `Design tokens:`, `Design system:`, `Libs in scope:` — and every §patterns field (`location`, `naming`, `extension`) drops the `key=value` pair whose value is absent, and drops the whole line when every value on it is absent. **Never `None`, `null`, `n/a` or `""`.** A missing sub-key of a present dict is an ABSENT INPUT and gets the same treatment as an absent file: omit and record in `sections_omitted`. This matters most where the emitted line then asserts its own authority — e.g. a `Design system:` line whose `source=` is absent cannot also say "when source=scanned-template, the starterkit tokens above are authoritative", and `Libs in scope: alpinejs@None` names a version nobody recorded.

> **`design_slice_path` on the starterkit branch — the extraction boundary, pinned** (the key was `design_slice_text` before 2026-07-31 round 3; the boundary below is unchanged, only the carrier is — `context-enrichment.md §design_slice_path`). When the starterkit `ui_ux` slice is built, `context-enrichment.md §Design slice` skips (the template is authoritative), so there is no `## Design system (UI-bearing unit…)` section to hand the `design-reviewer` lens. The lens's rubric is then **exactly these three emitted lines of `### Starterkit context`, in this order, whichever of them survived the absent-value rule:**
>
> 1. `UI/UX: …`
> 2. `Design tokens: …`
> 3. `Design system: …`
>
> **Nothing else travels.** `Auth:` / `Authz:` / `Libs in scope:` / the §patterns block / the reference code exemplar are not a design rubric and must not reach the design lens as one — a lens judging UI quality against an auth line is judging against a contract nobody wrote. If none of the three survived, **no lens-input file is written**, `design_slice_path` is ABSENT (not `""`), and the controller tells the lens it has no rubric rather than substituting a different section.
>
> **This branch runs ONLY when the unit is `ui_bearing`, and that is a round-4 correction to THIS branch.** `starterkit_relevance: [ui_ux]` on the frontmatter is not sufficient: a unit whose `target_files` are all backend declares the relevance, gets the slice lines in its own prompt, and is still **not** UI-bearing — so no `design-reviewer` is dispatched for it and no rubric is written. Round 3 gated the lens-input write on the slice text alone, which is exactly this branch, and shipped a `design_slice_path` for pure-backend units. The gate is now `ui_bearing`, matching `context-enrichment.md §Design slice` and `review-panel.md §Tier selection`.


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
