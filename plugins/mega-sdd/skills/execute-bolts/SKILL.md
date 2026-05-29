---
name: execute-bolts
version: 2.10.2
description: Execute one or more units to produce code commits (bolts). Bridges to superpowers (executing-plans, subagent-driven-development, test-driven-development) with vendored fallback. (v1.2+, Iter 3) Pre-flight + post-flight Hard Rule scan validates unit `## Hard rules` constraints against codebase state; violations halt commit. (v2.7.0+, Iter 32) T2 starterkit slice injection — auto-injects relevant starterkit context per unit into bolt dispatch prompt. Triggers — "execute bolts", "run units", "implement units", "jalanin unit", "eksekusi bolt", or paraphrases.
---

# Execute-Bolts

The terminal phase of the SDD pipeline — turns units into code.

**Announce at start:** "I'm using the execute-bolts skill to execute units via superpowers."

## When to use

- After `generate-units` wrote `<vault>/units/U-*.md`
- User explicit: `/mega-sdd:execute-bolts <unit-id>` or `--all`
- `orchestrate-flow` auto-routes after units are ready

## Inputs

- Unit path OR unit ID OR `--all` (positional)
- Flags:
  - `--parallel` — dispatch independent units via subagent-driven-development
  - `--worktree` — isolate each bolt in a git worktree
  - `--max-retries=N` — default 3
  - `--dry-run` — walk steps, do not commit
  - `--force` — re-execute completed units
  - `--auto` — non-interactive
  - `--per-squad` — (v1.1+) fan out across all squads declared in `_meta/squads.yaml`. Spawns one Claude subagent per squad via `subagent-driven-development`; each subagent filters units by their `squad:` field and runs in parallel.
  - `--squad=<id>` — (v1.1+) filter units to a single squad. For human-team handoff: a dev team runs this on their own laptop to process only their squad's units. Halts on `cross_squad_interface_draft` if any consumed interface is still draft.
  - `--module=<id>` — (v2.2+, Iter 11) filter units to a single module (semantic grouping per `generate-units/references/modules-schema.md`). Topologically sorts within module. Halts on `module_blocked_by` if dependencies in another module are incomplete.
  - `--force-skip-postflight` — (v2.6.4+, Iter 39) **DISCOURAGED** escape hatch that skips ast-grep Hard Rule postflight validation for THIS run only. Use only when ast-grep binary is broken or a known false-positive pattern blocks otherwise-valid work; document the reason in the bolt-report.md self-assessment section. Does NOT downgrade the rail (BLOCKING remains BLOCKING per CLAUDE.md "no bypassing anti-hallucination"); a follow-up bolt re-run WITHOUT the flag is required before drift-detect / merge.

    > ⚠️ **WARNING — anti-bypass policy.** This flag exists for operational continuity (broken tool / known false-positive), NOT to ship code that fails Hard Rules. Any use is logged in the handoff YAML `notes.postflight_skipped: true` field and surfaces in `<vault>/bolts/_summary.md`. Repeated unauthorized use is treated as a constitution violation per `bind-codebase/references/constitution.md §B`.
  - `--resume` — resume a partially-completed bolt from `<vault>/bolts/U-XXX/partial-state.json`. Forward-only re-execution from `current_step`. See §Partial-state contract for resume integrity checks.
  - `--rollback <unit-id-or-vault-path>` — (v2.9.0+, Iter 45 — saga compensating actions) read partial-state.json v2.0; apply `rollback_hints[]` in reverse order to undo a crashed bolt's side effects. Per-action confirmation (default safe for non-idempotent ops). Records `applied_at:` timestamp per action so partial rollback can be resumed. Errors out on v1.0 partial-state.json files (no rollback hints) with manual-review guidance. See §Saga compensating actions below + spec doc `docs/superpowers/specs/2026-05-25-iter-45-saga-compensating-actions-design.md`.

## Pre-flight checks

1. **Superpowers detection.** Per `references/superpowers-bridge.md` order:
   - Real install? → use plugin namespace
   - Vendored fallback ready? → use local paths
   - Neither? → halt with install instructions

**Structured halt per `vault-contract.md §halt-protocol`:**

```yaml
blocker:
  type: dep_missing
  emitted_at: <ISO8601 timestamp>
  emitted_by: execute-bolts
  details:
    required_skills:
      - executing-plans
      - subagent-driven-development
      - test-driven-development
      - using-git-worktrees
    missing_real: <list of skills not found in real superpowers install>
    missing_vendored: <list of skills not found in _vendored/>
    install_command: "/plugin install superpowers"
  next_action: "Install superpowers (recommended) OR run: bash plugins/mega-sdd/scripts/sync-superpowers.sh"
```

2. **Unit validity.** For each target unit:
   - Frontmatter parses and matches `unit-schema.md`
   - `target_files` non-empty (EXCEPT `task_type: verify` units — empty/`operation: none` is required)
   - `acceptance_test` has ≥1 `type: test` entry
   - `depends_on` references resolve (no dangling)
   - (v1.2+, Iter 1) `task_type: verify` units MUST NOT have any `target_files` with `operation: create | modify | delete` — verify is read-only. Violation → halt `verify_unit_writable`.

3. **Repo state.** Working tree clean (or `--force` to proceed). Bolts produce commits, so dirty state could be lost.

4. **Hard Rule pre-flight scan (v1.2+, Iter 3; v2 grammar via ast-grep in v2.0+, Iter 6).**

   For each unit with non-empty `## Hard rules` body section:

   a. **Detect grammar version**:
      - YAML code blocks under `## Hard rules` → **v2 grammar** (ast-grep YAML per `references/hard-rule-grammar-v2.md`)
      - Bulleted line items (`- DO NOT modify ...`) → **v1 grammar** (Iter 3 5-type)
      - Mixed → halt `hard_rule_mixed_grammar` (user must migrate via `/mega-sdd:migrate-rules`)
      - Override via `--hard-rule-grammar=v1|v2` flag

   b. **For v2 grammar**: probe `command -v ast-grep`. If absent → halt `dep_missing` (per `references/hard-rule-grammar-v2.md` §Installation guidance). Validate each YAML block via `ast-grep test --validate`. Unparseable → halt `hard_rule_unparseable`.

   c. **For v1 grammar (legacy path preserved)**: parse each rule line against the 5-grammar set per `unit-schema.md` §Hard rule grammar (Iter 3):
      - `DO NOT modify <path>`
      - `DO NOT add new <manifest> dependencies`
      - `<path-glob> MUST follow <case-style> naming`
      - `function <name> MUST preserve signature: <type-sig>`
      - `file <path> MUST exist after bolt`
      Unparseable line → halt `hard_rule_unparseable`. NEVER silently skip a rule.

   c. **Capture pre-flight snapshot** (deterministic state for post-flight diff):
      - **v2 grammar**: for each rule, snapshot AST state via `ast-grep scan --rule <yaml> --json` (zero matches expected pre-bolt for "forbidden" rules); persist matched-files list + sha256 per matched file
      - **v1 grammar (legacy)**:
        - `DO_NOT_MODIFY <path>` → record `sha256(file content)` if file exists; record "absent" otherwise
        - `DO_NOT_ADD_DEPS <manifest>` → record manifest's dependency-section content
        - `NAMING_RULE <path-glob> <case-style>` → no pre-snapshot (post-flight checks new files only)
        - `SIGNATURE_RULE function <name>` → read codebase-map §2 for current signature; record verbatim. Not in codebase-map → halt `hard_rule_unanchored`
        - `FILE_PRESENCE_RULE file <path>` → no pre-snapshot

   d. **Persist snapshot** as `<vault>/bolts/U-XXX/preflight.json` for post-flight comparison. Format:
      ```json
      {
        "unit_id": "U-001",
        "snapshot_at": "2026-05-20T10:00:00Z",
        "rules": [
          {"type": "DO_NOT_MODIFY", "path": "src/Models/User.php", "sha256": "abc123..."},
          {"type": "DO_NOT_ADD_DEPS", "manifest": "package.json", "deps_section": "..."},
          {"type": "SIGNATURE_RULE", "function": "authenticateUser", "signature_at_preflight": "(email: string, password: string) => Promise<User>"}
        ]
      }
      ```

   **Halt YAML for hard_rule_unparseable:**

   ```yaml
   blocker:
     type: hard_rule_unparseable
     emitted_at: <ISO8601>
     emitted_by: execute-bolts
     details:
       unit_id: U-XXX
       offending_line: "<verbatim>"
       expected_grammar: [DO_NOT_MODIFY, DO_NOT_ADD_DEPS, NAMING_RULE, SIGNATURE_RULE, FILE_PRESENCE_RULE]
     next_action: "Fix the unit's ## Hard rules section per references/unit-schema.md §Hard rule grammar."
   ```

   **Halt YAML for hard_rule_unanchored:**

   ```yaml
   blocker:
     type: hard_rule_unanchored
     emitted_at: <ISO8601>
     emitted_by: execute-bolts
     details:
       unit_id: U-XXX
       rule: "function <name> MUST preserve signature: ..."
       reason: "Referenced function not found in codebase-map; cannot snapshot or validate"
     next_action: "Verify the function name is correct OR remove this rule if the function doesn't exist yet."
   ```

## Procedure (per unit)

Follow `references/superpowers-bridge.md` per-unit flow. Standard sequence (Iter 3 additions in **bold**):

1. **Pre-flight: parse and snapshot Hard rules** (per §Pre-flight checks step 4)
2. Read unit body; pass to superpowers `executing-plans` for code implementation
3. Run acceptance tests (per superpowers `test-driven-development`)
4. **Post-flight: re-validate Hard rules** (see §Post-flight Hard Rule validation below)

## Step 4.5: Tiered context enrichment per bolt (v2.6.0+, Iter 30; budget tracker v2.8.0+, Iter 44)

Per `references/bolt-dispatch-prompt.md` template. Implements the 10 AI-executor principles from spec §4. Total dispatch prompt budget ≤7KB target (hard cap 10KB → halt `dispatch_prompt_too_large`).

a. **Load TIER 1 (always included, target ≤2KB)**:
   - Unit body (frontmatter + body sections)
   - Halt vocabulary block (5 halt types + YAML templates)
   - Self-assessment vocabulary template
   - Atomic commit discipline reminder
   - Anti-context block (DO NOT MODIFY / DO NOT REPLICATE / DO NOT WRITE / DO NOT COMMIT IF)
   - Provenance trailer template
   - **Acceptance-test provenance NOTE (v2.9.1+, Iter 47 — D4-006 surface):** if unit's `acceptance_test._authored_by` field is `same-pass` OR `adversarial-review-failed` (weak blind-spot coverage signals per `generate-units/references/adversarial-test-prompt.md` §provenance values), append a NOTE to the dispatch prompt warning the bolt subagent that the acceptance_test may have missed bugs the implementation introduces. Bolt subagent self-assessment instructed to flag `acceptance_test_concern: <details>` if implementation passes the test but feels under-validated. NOTE template lives in `references/bolt-dispatch-prompt.md` §Acceptance-test provenance NOTE.

**a.5 Initialize T2 budget tracker (v2.8.0+, Iter 44 — closes audit D1-003)**

Replaces the prior "single-halt at 10KB" enforcement. Tracks running T2 consumption + applies progressive section-level truncation per priority order.

```
running_budget = {
  cap_hard:      12288         # 12KB hard cap (v3.67.0+, Iter 76 — raised from 10KB to make room for §patterns + controller code-slice)
  cap_target:    9216          # 9KB total target (raised from 7KB Iter 44 baseline)
  cap_t1:        2048          # 2KB T1 budget
  cap_t2:        10240         # 10KB T2 budget (v3.67.0+, Iter 76 — raised from 5KB; option-A walking-skeleton: more context reach over tight cap)
  consumed_t1:   <bytes of TIER 1 from Step a>
  consumed_t2:   0             # accumulates during Step b
  remaining_t2:  cap_t2
  warnings:      []            # truncation events (logged to provenance)
}
```

**Iter 76 cap bump rationale (revisit at Iter 77):** Step 4.5.b-starterkit now injects §patterns block (≤1KB) + 1 controller code example (≤3KB) — together ~4KB additional T2 load on top of legacy auth/rbac/ui_ux/libs slices. Bumping cap_t2 5KB → 10KB ensures walking-skeleton patterns reach the bolt subagent without forcing aggressive truncation that would defeat the purpose. cap_hard 10KB → 12KB preserves ~2KB T1 headroom. Monitor in Iter 77 telemetry: if total prompts stay <8KB in practice, revert to tighter caps; if patterns saturate budget, tune category priority cascade (libs first to drop).

After EACH T2 section loads in Step b, update tracker:
- `consumed_t2 += section_bytes`
- `remaining_t2 = cap_t2 - consumed_t2`
- IF `remaining_t2 < next_section_min_viable_bytes` → apply progressive truncation per "T2 Section Priority + Truncation" below BEFORE loading next section.

### T2 Section Priority + Truncation (v2.8.0+, Iter 44)

Ordered from MOST disposable (priority 1) to MOST critical (priority 8). When budget tight, truncate top-of-list first. Truncation log appended to `running_budget.warnings` with `{section, rule_applied, bytes_saved}`.

| Priority | T2 Section | Truncation cascade | Drop floor |
|---|---|---|---|
| 1 | `validation_hints` | drop expected-output patterns; keep test commands only | drop section entirely |
| 2 | `historical_memory` | last 5 → last 3 → last 1 → drop | drop section |
| 3 | `kb_anti_patterns` | top 3 → top 1 → drop | drop section |
| 4 | `confidence_labels` | per-claim → aggregate ("HIGH×N / MEDIUM×N / LOW×N") | drop section |
| 5 | `depends_on_summaries` | N most-recently-touched files only | keep at least 1 upstream |
| 6 | `framework_pack_rules` | top 5 → top 3 → top 1 | keep top 1 always |
| 7 | `starterkit_slice` | (existing Iter 32 cascade) libs→top 10, ui_ux.idioms→top 3 | per Iter 32 (halt if still over) |
| 8 (NEVER drop) | `constitution_clauses` | NEVER truncate — LOCKED security/compliance content | n/a — if exceeds here → halt `dispatch_prompt_too_large` |

### Halt path (preserved, v2.8.0+ semantics)

`dispatch_prompt_too_large` fires ONLY when:
- All disposable T2 sections (priorities 1-7) already truncated to drop floor
- AND total prompt still exceeds `cap_hard` (10KB)
- AND `constitution_clauses` alone is non-truncatable

In practice: this halt now indicates a true config issue (unit references too many constitution clauses for a single bolt) requiring spec-level adjustment, not bolt-fixable. Iter 30 halt semantics preserved.

### Soft-budget warnings (v2.8.0+ — NEW)

When `consumed_t2 > cap_t2` (5KB) but `total < cap_hard` (10KB):
- Log warning (NOT halt): `"T2 exceeded soft cap: target=5KB, actual=<N>KB — truncation applied"`
- Truncation still applied per priority to bring T2 back under target
- Bolt proceeds with truncated context + provenance trail (visible to subagent in bolt-dispatch-prompt.md `### T2 budget tracker` section)
- Bolt self-assessment instructed: if `T2 budget tracker` shows truncated sections, set `confidence: MEDIUM` for any claim that depended on truncated context

b. **Load TIER 2 (conditional, target ≤5KB total — enforced v2.8.0+)**:
   - depends_on chain: 1-line summary per upstream bolt (read each bolt-report.md self-assessment)
   - Framework pack rules: filter pack file by `path_glob` match against this unit's `target_files`
   - Constitution clauses: ONLY clauses referenced in this unit's `vault_source` sections
   - KB anti-patterns: filter KB by this unit's domain tags
   - Historical memory: filter `<project>/.mega-sdd/memory/outcomes.md` for "bolts touching similar files OR similar pattern" — last 5 only
   - **Starterkit context slice (v2.7.0+, Iter 32)**: see Step 4.5.b-starterkit sub-block below for read + filter + inject logic
   - Confidence labels per claim (HIGH from binding C-NNN, MEDIUM from KB inference, LOW from heuristic with rationale)
   - Validation hints (specific test commands + expected output patterns)

**Step 4.5.b-starterkit: Starterkit context slice details (v2.7.0+, Iter 32)**

### Step 4.5.b-starterkit.read — Read starterkit-context.yaml

```
Path: <project>/.mega-sdd/codebase/starterkit-context.yaml

IF file absent → skip Steps b-starterkit.build + b-starterkit.inject; do not inject starterkit slice into T2
IF file present → parse YAML
  IF parse fails → log warning; emit `deep_scan_cache_corrupt` soft halt; skip
  IF starterkit_context.partial == true → note partial_slices for slice availability
Read unit.frontmatter.starterkit_relevance array (from generate-units Step 7.7.e)
IF unit.starterkit_relevance is missing OR empty → skip Steps b-starterkit.build + b-starterkit.inject
```

### Step 4.5.b-starterkit.build — Build T2 slice based on unit.starterkit_relevance + §patterns

For each relevance flag in `unit.starterkit_relevance`, include ONLY that slice from `starterkit-context.yaml`. Additionally, the §patterns block is wired independently of `starterkit_relevance` (it triggers on `target_files` match against pack-discovered locations):

```
slice = {}

IF "auth" in unit.starterkit_relevance AND starterkit_context.auth exists:
  slice.auth = starterkit_context.auth (lib, guard, user_model only — exclude routes, _source)

IF "rbac" in unit.starterkit_relevance AND starterkit_context.rbac exists:
  slice.rbac = starterkit_context.rbac (lib, role_model, permission_model, middleware only — exclude policies, _source)

IF "ui_ux" in unit.starterkit_relevance AND starterkit_context.ui_ux exists:
  slice.ui_ux = starterkit_context.ui_ux (layout_extends, notification_lib, idioms only — exclude design_tokens, _source)

IF "libs" in unit.starterkit_relevance AND starterkit_context.libs exists:
  slice.libs = filter(starterkit_context.libs, by usage_hint overlap with unit.target_files)
  (NOT the full inventory — only libs whose usage_hint contains any of unit.target_files paths or path prefixes)
```

**Step 4.5.b-starterkit.build.patterns — Wire §patterns to T2 slice (v3.67.0+, Iter 76)**

Closes Iter 75 regression where §patterns block (produced by scan-codebase v3.0 Step 10.5.2.5) was built but never injected into T2 — bolt subagent received "follow starterkit conventions" without ever being told what those conventions ARE.

```
IF starterkit_context.patterns exists AND unit.target_files is non-empty:
  slice.patterns = {}

  FOR each pattern_category in [controller, data_model, request_validator, business_logic, test, schema_migration, route]:
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
      # (e.g., file-based-routing frameworks where convention is naming, not directory).
      # Why not OR-with-location when location is set: generic patterns like "{Model}<ext>"
      # (data_model with extension .php) match ANY PascalCase .php basename including
      # controllers — false-positive across categories. Location-primary avoids this.
      IF (not has_location) AND pattern.naming is not None:
        naming_regex = compile_pattern_to_regex(pattern.naming, pattern.extension)
        basename = path.basename(target_file)
        IF naming_regex AND naming_regex.search(basename):
          slice.patterns[pattern_category] = pattern
          matched = True
          BREAK
```

**Matching semantics (Iter 76 decision):** location is the primary discriminator. Naming-fallback fires only when `pattern.location is null` (= framework genuinely has no directory convention for that category — e.g., Next.js file-based routing, Express where handlers live anywhere). User-spec said `OR location/naming` but that proved too loose in fixture (data_model `{Model}<ext>` regex collides with controller basenames). Location-primary is conservative and avoids crowding T2 with false-positive categories. Revisit Iter 77+ if real-run telemetry shows missed-match cases for null-location frameworks.

`compile_pattern_to_regex` converts pack naming pattern (e.g., `{Model}Controller<ext>` or `{Model}.handler.ts`) by replacing `{Model}` → `[A-Z]\w+`, `{model}` → `[a-z_]+`, `<ext>` → `re.escape(extension)`, anchored with `$`. On compile failure → log + skip naming-regex fallback (location match still applies if available).

Matching is conservative: ONE target_file match per category sets the slice; absence of any match means the unit doesn't touch that category and it's omitted from the slice (no false-positive injection).

**Step 4.5.b-starterkit.build.code-slice — Inject reference code example (v3.67.0+, Iter 76 — walking-skeleton: controller only)**

Few-shot anchoring: when patterns.controller matches, embed an actual code sample from the starterkit so the bolt subagent has a concrete reference to follow (not just a location/naming hint).

```
slice.code_examples = {}

IF slice.patterns.controller exists
   AND starterkit_context.patterns.controller._source is non-empty:
  # _source entries look like: "app/Http/Controllers/ExampleController.php:1-30"
  first_source = starterkit_context.patterns.controller._source[0]
  example_path = first_source.split(":")[0]   # strip line-range suffix
  full_example_path = <project_root> / example_path

  IF full_example_path exists AND is a regular file:
    file_size = stat(full_example_path).st_size

    IF file_size < 3072:   # <3KB → include full
      slice.code_examples.controller = {
        path: example_path,
        content: read_text(full_example_path),
        truncated: false,
      }
    ELSE:                  # ≥3KB → truncate to first 100 lines + marker
      lines = read_text(full_example_path).splitlines()[:100]
      slice.code_examples.controller = {
        path: example_path,
        content: "\n".join(lines) + "\n# ... (truncated at 100 lines — see full file via Read tool)",
        truncated: true,
      }
  ELSE:
    # _source path absent on disk → skip code example, NOT a halt (pattern still injected without code)
    log "starterkit.controller._source[0] not found on disk: <full_example_path>"
```

**Walking-skeleton scope (Iter 76):** controller category ONLY. data_model / request_validator / business_logic / test / schema_migration / route categories deferred to Iter 77+ after telemetry confirms controller injection lands cleanly in real-run + no T2 budget thrash. Pattern is identical — extend the loop above to other categories once validated.

**Anti-halu rail:** `slice.code_examples.controller.path` MUST equal the actual file read (provenance); never invent or substitute.

Truncation order if slice exceeds T2 budget (v3.67.0+, Iter 76 — extended):
1. Truncate `slice.libs[]` — keep top 10 by relevance score (overlap count with target_files)
2. If still over → truncate `slice.code_examples.controller.content` to first 50 lines (was 100); mark `truncated: true`
3. If still over → truncate `slice.ui_ux.idioms[]` to top 3
4. If still over → drop `slice.code_examples` entirely (patterns metadata still preserved)
5. If still over → emit halt `dispatch_prompt_too_large` (existing Iter 30 halt; chain stops)

### Step 4.5.b-starterkit.inject — Inject into bolt-dispatch-prompt T2.3 section

Populate the T2.3 "Starterkit context (relevant slice)" section in bolt-dispatch-prompt.md template (see `references/bolt-dispatch-prompt.md`) with the slice from b-starterkit.build:

```
### Starterkit context (relevant to this unit)

<IF slice.auth present:>
Auth: lib=<slice.auth.lib>, guard=<slice.auth.guard>, user_model=<slice.auth.user_model>
</IF>

<IF slice.rbac present:>
RBAC: lib=<slice.rbac.lib>, role_model=<slice.rbac.role_model>, middleware=<slice.rbac.middleware joined by ", ">
</IF>

<IF slice.ui_ux present:>
UI/UX: extends=<slice.ui_ux.layout_extends>, notification=<slice.ui_ux.notification_lib>, idioms=[<slice.ui_ux.idioms joined by "; ">]
</IF>

<IF slice.libs present AND non-empty:>
Libs in scope: <for each lib in slice.libs: <lib.name>@<lib.version> (used in: <lib.usage_hint joined by ", ">)>
</IF>

<IF slice.patterns present AND non-empty:>     # v3.67.0+, Iter 76
### Starterkit code patterns (follow these conventions)

<for each category in slice.patterns (controller, data_model, ...):>
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

<IF slice.code_examples present AND non-empty:>     # v3.67.0+, Iter 76 — walking-skeleton: controller only
### Reference code example (from starterkit)

<IF slice.code_examples.controller present:>
Pattern: controller
File:    <slice.code_examples.controller.path>
<IF slice.code_examples.controller.truncated:>(truncated — full file available via Read tool)</IF>

```<file-extension>
<slice.code_examples.controller.content>
```

Follow this style for new <controller> files. Do not deviate from the import order, base class, method shape, or response idiom shown above unless the unit explicitly requires it.
</IF>
</IF>
```

Sections for absent relevance flags / unmatched categories are OMITTED entirely (not emitted as empty headers).

Wall-clock cost: 0sec when starterkit-context.yaml is absent (b-starterkit.read exits early). When present: ≤500ms (YAML parse + filter + format).

c. **TIER 3 (NOT embedded; reference-on-demand via Read tool)**:
   - Full upstream bolt-reports
   - Full constitution
   - Full KB domain files
   - Full memory tables
   - Full framework pack

d. **Size check (v2.8.0+, Iter 44 — budget-tracker informed)**:
   - Compute final `total = consumed_t1 + consumed_t2`
   - IF `total > cap_hard` (10KB) → halt `dispatch_prompt_too_large` with details `{cap_hard, total, t1_bytes, t2_bytes, warnings: running_budget.warnings, truncation_exhausted: true}` — this should only fire when constitution_clauses alone exceeds budget (Iter 44 inversion: progressive truncation absorbs most cases before reaching this halt)
   - IF `consumed_t2 > cap_t2` (5KB soft cap exceeded but under hard cap) → emit warn-only log line (per Iter 44 §Soft-budget warnings); continue dispatch with truncated prompt
   - Inject `### T2 budget tracker` section into bolt-dispatch-prompt.md per `references/bolt-dispatch-prompt.md` §T2-budget-tracker. Contents:
     ```
     ### T2 budget tracker
     consumed_t1: <X bytes> (cap 2048)
     consumed_t2: <Y bytes> (cap 5120, hard 10240)
     truncations_applied:
       - <section>: <rule_applied> (saved <Z bytes>)
       ...
     instruction_to_subagent: "If your self-assessment references information that was truncated above, mark its confidence: MEDIUM and note the truncation in your bolt-report.md self-assessment section."
     ```

e. **Log final prompt**:
   - Write assembled prompt to `<vault>/bolts/U-XXX/dispatch-prompt.md` for provenance + auditability

f. **Partial-state contract (v2.0 schema as of Iter 45 — saga compensating actions)**:
   - If bolt subagent crashes mid-execution, write `<vault>/bolts/U-XXX/partial-state.json` per `references/shared-snapshot-schema.md`-like format:
     - `schema_version: "2.0"` (Iter 45 bump from 1.0 Iter 30 baseline)
     - `bolt_id`, `started_at`, `current_step`, `current_step_status` (enum: `crashed | partial | succeeded`)
     - `files_modified[]`: each `{path, sha256_before, sha256_after}`
     - `last_test_result`, `last_action`
     - **`rollback_hints[]`** (NEW v2.0, Iter 45): harvested from bolt-report.md `## Rollback hints` section. Each entry: `{step_id, step_type (canonical taxonomy below), evidence (1-line what happened), compensating_action (literal shell command OR "(none — manual review required)"), idempotent (bool), applied_at (null until --rollback runs the action)}`.
   - Resume reads partial-state, doesn't start from zero
   - After 3 partial-state attempts → halt `bolt_repeated_partial_failure`
   - **Resume-time integrity check (v2.7.3+):** before consuming partial-state, attempt JSON parse. On parse failure → emit halt `partial_state_corrupt` with details `{partial_state_path: <absolute>, parse_error: <first 200 chars of exception>, corrupt_backup_path: "<path>.corrupt-<ISO8601>"}`; ALWAYS STOP. Resolution: rename corrupt file to suggested `.corrupt-<ISO8601>` path for forensics; re-run `--resume` (will start fresh now that corrupt file is moved) OR run without `--resume` to restart bolt batch from scratch.
   - **Malformed rollback_hints check (v2.9.0+, Iter 45):** if partial-state.json v2.0 parses but `rollback_hints[]` entries are missing required fields OR reference unknown `step_type` → emit halt `partial_state_corrupt` with details `{..., malformed_hints: [<entry indices + reason>]}`. Reuses Iter 40 halt envelope; no new halt type. Resolution: user inspects bolt-report.md to reconstruct hints OR proceeds with `--resume` (forward-only, no rollback) accepting risk.

   **Step type canonical taxonomy (Iter 45)** — bolt subagent classifies each significant step into one of these when emitting rollback hint to bolt-report.md:

   | step_type | Compensating action template | Idempotent? |
   |---|---|---|
   | `file_created` | `rm <path>` | ✓ |
   | `file_modified` | `git checkout HEAD -- <path>` | ✓ |
   | `file_partially_written` | `git checkout HEAD -- <path>` | ✓ |
   | `file_deleted` | `git checkout HEAD -- <path>` | ✓ |
   | `composer_dep_added` | `composer remove <pkg> --no-update && git checkout composer.json composer.lock` | ✗ (composer cache may persist) |
   | `composer_dep_removed` | `git checkout composer.json composer.lock && composer install` | ✗ |
   | `npm_dep_added` | `npm uninstall <pkg> && git checkout package.json package-lock.json` | ✗ |
   | `npm_dep_removed` | similar | ✗ |
   | `migration_created` | `rm <migration-file>` | ✓ |
   | `migration_executed` | `php artisan migrate:rollback --step=1` (Laravel) OR equivalent | ✗ (DB state) |
   | `external_api_call` | `(none — manual review required)` | ✗ |
   | `test_command_run` | `(none — read-only)` | ✓ |
   | `git_commit` | `git reset --hard HEAD~1` (DANGEROUS — only if commit was THIS bolt's) | ✗ |
   | `git_branch_created` | `git branch -D <branch>` | ✓ |

   ```yaml
   # Example partial_state_corrupt envelope:
   type: partial_state_corrupt
   source_skill: execute-bolts
   details:
     partial_state_path: "<vault>/bolts/U-007/partial-state.json"
     parse_error: "json.decoder.JSONDecodeError: Expecting ',' delimiter: line 4 column 18 (char 87)"
     corrupt_backup_path: "<vault>/bolts/U-007/partial-state.json.corrupt-2026-05-25T14:32:00Z"
   next_action: "Rename partial-state.json to the suggested corrupt_backup_path (preserves forensics) then re-run `/mega-sdd:execute-bolts U-007 --resume` (will start fresh — corrupt file moved aside). Likely cause: bolt subagent crashed mid-write to partial-state.json (rare); inspect corrupt content for skill-author bug."
   ```

### Saga compensating actions (v2.9.0+, Iter 45 — `--rollback` flag)

Forward-only `--resume` retries failing steps but cannot undo non-idempotent prior steps (composer dep adds, migrations, external API calls). `--rollback` applies `rollback_hints[]` captured in partial-state.json v2.0 in reverse order with per-step confirmation.

**Bolt subagent contract (per `references/bolt-dispatch-prompt.md` §Rollback hints):**

For each significant step (file write / dep add / migration / etc.), bolt subagent appends to bolt-report.md `## Rollback hints` section:

```yaml
- step_id: step-1-add-dep
  step_type: composer_dep_added
  evidence: "added 'laravel/cashier': '^15.0' to composer.json:42; composer.lock regenerated"
  compensating_action: "composer remove laravel/cashier --no-update && git checkout composer.json composer.lock"
  idempotent: false
```

On crash: execute-bolts harvests this section + writes `rollback_hints[]` array into partial-state.json v2.0. On `--rollback`: applies actions in reverse order with per-action confirmation (default safe for non-idempotent).

**`--rollback` flow:**

1. Read `<vault>/bolts/U-XXX/partial-state.json`
2. If `schema_version: "1.0"` → error: "No rollback hints in v1.0 partial-state.json. Manual review required (`git status` + `git diff HEAD`)."
3. If `schema_version: "2.0"` AND `rollback_hints[]` present → display reverse-order list with idempotency markers:

   ```
   Rolling back partial bolt U-007 (3 compensating actions):

     3. file_partially_written: git checkout HEAD -- app/Http/Controllers/SubscriptionController.php  [idempotent ✓]
     2. file_created: rm database/migrations/2026_05_25_100000_create_subscriptions_table.php  [idempotent ✓]
     1. composer_dep_added: composer remove laravel/cashier --no-update && git checkout composer.json composer.lock  [idempotent ✗ — composer cache may persist]

   Apply in reverse order (3 → 2 → 1)?
     [I] interactive — prompt before each action (DEFAULT — safe for non-idempotent steps)
     [Y] batch-apply all actions including non-idempotent (DANGEROUS — composer/migration removes happen without per-step confirmation)
     [N] cancel; review partial-state.json manually
   ```

   **Default = `[I] interactive`** — non-idempotent compensating actions (composer dep removes, migration rollbacks) NEVER auto-run without per-step user approval.

4. After each action runs: write `applied_at: <ISO8601>` back to partial-state.json (so partial rollback can be resumed).
5. If all actions complete: rename partial-state.json to `.rolled-back-<ISO8601>` for forensics; bolt slot is now clean.

**Out of scope:**
- Auto-rollback on crash (user-initiated only; auto-rollback compounds non-idempotent errors)
- Cross-bolt saga (rollback scope = single bolt U-XXX; batch-level too risky)
- DB introspection for `migration_executed` rollback (hint says rollback last migration; user accepts risk via per-action confirmation)
   - **Resume-time integrity check (v2.7.3+):** before consuming partial-state, attempt JSON parse. On parse failure → emit halt `partial_state_corrupt` with details `{partial_state_path: <absolute>, parse_error: <first 200 chars of exception>, corrupt_backup_path: "<path>.corrupt-<ISO8601>"}`; ALWAYS STOP. Resolution: rename corrupt file to suggested `.corrupt-<ISO8601>` path for forensics; re-run `--resume` (will start fresh now that corrupt file is moved) OR run without `--resume` to restart bolt batch from scratch.

   ```yaml
   # Example partial_state_corrupt envelope:
   type: partial_state_corrupt
   source_skill: execute-bolts
   details:
     partial_state_path: "<vault>/bolts/U-007/partial-state.json"
     parse_error: "json.decoder.JSONDecodeError: Expecting ',' delimiter: line 4 column 18 (char 87)"
     corrupt_backup_path: "<vault>/bolts/U-007/partial-state.json.corrupt-2026-05-25T14:32:00Z"
   next_action: "Rename partial-state.json to the suggested corrupt_backup_path (preserves forensics) then re-run `/mega-sdd:execute-bolts U-007 --resume` (will start fresh — corrupt file moved aside). Likely cause: bolt subagent crashed mid-write to partial-state.json (rare); inspect corrupt content for skill-author bug."
   ```

g. **Dispatch via superpowers.executing-plans** with the enriched prompt as plan body.

Anti-halu rails:
- T2 filtering MUST cite source for inclusion (e.g., "framework pack rule X loaded because target_files matched glob Y")
- Anti-context block populated from actual data sources (data-mutation-policy.md, KB, framework pack) — NEVER invented
- Self-assessment confidence MUST be 0.0-1.0 numeric (not strings); halt if omitted
- Provenance trailer MANDATORY in every modified file — post-flight scan verifies presence; missing → halt `provenance_missing`

5. Commit (via superpowers); write bolt-report.md

### Post-flight Hard Rule validation (v1.2+, Iter 3; v2.4.1+ Iter 25 framework pack provenance)

After superpowers' executing-plans completes and acceptance tests pass, run the post-flight scan BEFORE committing. This is the safety net.

**Framework pack rules** (v2.4.1+ Iter 25 — pulled into unit Hard Rules by `generate-units` Step 12.4.5 per Iter 23 contract): validated identically to other Hard Rules — ast-grep `rule:` block from pack runs against codebase post-bolt. Violation surface includes `framework_pack_source` field in halt YAML so user knows WHICH framework rule fired.

For each rule in the unit's `## Hard rules`:

**v2 grammar (ast-grep)**:

```bash
# Per rule: run ast-grep scan; any match against "forbidden" patterns = VIOLATED
ast-grep scan --rule <rule-yaml-tempfile> --json <repo-root>
```

Parse JSON output. Match found → VIOLATED with file:line + matched text as evidence. Zero matches → PASSED. For `files:`-scoped lock rules: also compare current sha256 to preflight snapshot (defense in depth).

**v1 grammar (legacy, preserved)**:

| Rule type | Post-flight check |
|---|---|
| `DO_NOT_MODIFY <path>` | Compute current `sha256(file)`. Compare to preflight snapshot. Differs OR file appeared → VIOLATED. |
| `DO_NOT_ADD_DEPS <manifest>` | Read current manifest deps section. Diff against preflight snapshot. ANY new entry → VIOLATED. |
| `NAMING_RULE <path-glob> <case-style>` | Enumerate new files matching `path-glob`. Apply case-style regex. Mismatch → VIOLATED. |
| `SIGNATURE_RULE function <name>` | Re-extract current signature from codebase. Compare to preflight. Differs → VIOLATED. |
| `FILE_PRESENCE_RULE file <path>` | Probe `<path>` exists. Absent → VIOLATED. |

### Violation handling

- **ANY rule violated** → **HALT BEFORE COMMIT.** Bolt's code changes remain in working tree (uncommitted). User reviews + reverts/edits.
- Emit `hard_rule_violated` blocker YAML with violated_rule + evidence.
- bolt-report.md MUST be written with `status: halted_postflight` and list violations.

**Halt YAML for hard_rule_violated:**

```yaml
blocker:
  type: hard_rule_violated
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    violations:
      - rule: "DO NOT modify src/Models/User.php"
        evidence: "sha256 mismatch — preflight: abc123..., postflight: def456..."
      - rule: "function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>"
        evidence: "Signature changed; postflight: (email: string, password: string, twoFactor?: string) => Promise<User>"
  next_action: "Review changes in working tree; revert the offending modification OR edit the unit's Hard rules + re-run execute-bolts."
```

### verify-unit special path

`task_type: verify` units run a simplified flow (no code write):
1. Pre-flight: validate unit `target_files` is empty / all `operation: none` (else halt `verify_unit_writable`)
2. Skip executing-plans (no code to write)
3. Run acceptance tests
4. Skip post-flight Hard rule scan (no changes to validate)
5. Commit only the bolt-report.md (no source code changes); OR skip commit entirely on `--no-empty-commits` flag

For `--all`:
1. Topologically sort units by `depends_on`
2. Execute in order (default sequential)
3. On `--parallel`: group units with no shared dependency; dispatch group as subagent batch via `subagent-driven-development`
4. On any failure: halt entire `--all` run (no skip-ahead)

For `--per-squad` (v1.1+):

1. **Load `_meta/squads.yaml`.** If absent or single-squad → halt with informative message: "`--per-squad` requires ≥2 squads declared in `_meta/squads.yaml`. Run `/mega-sdd:generate-intent` to add squad config, or use plain `/mega-sdd:execute-bolts --all` for single-squad."
2. **Read squad list.** Build a list of squad IDs declared.
3. **For each squad, dispatch a Claude subagent** per `references/squad-subagent.md`. Subagents run in parallel via `Agent(run_in_background: true)`.
4. **Wait for all subagents** to complete or halt. Each subagent reports back its bolt-report list + halt status.
5. **Consolidate report.** Aggregate per-squad summaries into a single chat message: N squads, M units total, K commits, list of halts (with squad attribution).

For `--module=<id>` (v2.2+, Iter 11):

1. **Load `_meta/modules.yaml`.** If absent → halt: "`--module=` requires `_meta/modules.yaml`. Auto-derive via `/mega-sdd:generate-units --derive-modules` first."
2. **Validate `<id>` exists** in declared modules.
3. **Check blocked_by**: for each `blocked_by` entry, verify that module is `status: completed` (per memory). Incomplete → halt `module_blocked_by` listing pending prerequisites.
4. **Filter units**: working set = units where `module: <id>` AND not yet completed.
5. **Topologically sort** within module by `depends_on`.
6. **Proceed with sequential or `--parallel` execution** on the filtered set.
7. **After all units complete**: probe module's DoD checklist (modules.yaml.modules[<id>].dod). Surface incomplete DoD items in chat; user marks via `/mega-sdd:list-modules --mark-dod=<module>` or edits modules.yaml manually.

**Halt YAML for module_blocked_by:**

```yaml
blocker:
  type: module_blocked_by
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    requested_module: M-leave-mgmt
    blocked_by_modules: [M-auth]
    blocker_status: M-auth has 2/5 units complete
  next_action: "Complete prerequisite module first via /mega-sdd:execute-bolts --module=M-auth"
```

For `--squad=<id>` (v1.1+):

1. **Load `_meta/squads.yaml`.** If absent → halt: "`--squad=` requires `_meta/squads.yaml`. This flag is only valid in multi-squad mode."
2. **Validate `<id>` exists** in declared squads. If not → halt with list of valid IDs.
3. **Filter units.** Build the working set = units where `squad: <id>` matches.
4. **Verify consumed interfaces lockable.** For each unit in the working set, read `consumes_interfaces`. For each listed interface, read its frontmatter `status`. If ANY status is `draft` → halt with `cross_squad_interface_draft`.
5. **Proceed with normal sequential or `--parallel` execution** on the filtered working set.

### Per-bolt lightweight drift check (v2.6.0+, Iter 30 §6.4)

After post-flight Hard Rule validation passes (or proposed-and-confirmed fix applied), AND BEFORE commit, run a quick scope-filtered drift scan vs vault:

a. Read vault.json scope (if multi-scope vault per Iter 28) OR skip scope filter
b. For each file in unit's target_files modified this bolt:
   - Compare current state vs vault's expected state (from binding.md anchors when present)
   - Detect: name drift, type drift, behavior drift (per detect-drift v1.4+ categories)
c. If drift detected on LOCKED entity (per `data-mutation-policy.md`) → halt `bolt_introduces_locked_drift` (eligible for propose-and-confirm OR override)
d. If drift detected on INTENT/ARTIFACT entity → log to bolt-report.md `## Drift introduced` section + continue (will surface in batch-end detect-drift gate)
e. If no drift → log "✓ Drift check: clean" to bolt-report.md

Compact streaming format reflects this:
```
└─ Post-flight: Hard Rules ✓ | PBT ✓ | Drift check: clean ✓
```

OR (drift detected case):
```
└─ Post-flight: Hard Rules ✓ | PBT ✓ | ⚠️ Drift: order.amount type changed (LOCKED — will halt at gate)
```

### Self-assessment requirement in bolt-report.md (v2.6.0+, Iter 30 §10)

Every bolt-report.md MUST include `bolt_self_report` YAML block at end:

```yaml
bolt_self_report:
  confidence: <0.0-1.0>   # bolt subagent's own confidence in this bolt's correctness
  certain_decisions:
    - "<decision with HIGH confidence + evidence>"
  uncertain_decisions:
    - decision: "<what bolt did>"
      rationale: "<why this path was taken>"
      fallback_if_wrong: "<safer alternative if this turns out wrong>"
  retry_history:
    - attempt: 1
      failure: "<verbatim failure if any>"
      fix: "<what was changed>"
```

If bolt-report.md lacks this block → halt `self_assessment_missing` (post-flight verification fails).

Aggregate `_summary.md` rolls up uncertain_decisions across batch for human review post-execution.

### Post-flight acceptance-test concern harvest (v2.10.0+, Iter 53 — consumer wiring closure for Iter 47 surface)

After bolt-report.md is written, scan the `bolt_self_report` YAML block (and adjacent self-assessment text) for `acceptance_test_concern: <non-empty string>` field (written by bolt subagent per `references/bolt-dispatch-prompt.md` line 73 contract when implementation passes acceptance test but feels under-validated per Iter 47 D4-006 surface):

1. Parse bolt-report.md bottom-of-file YAML blocks.
2. IF `acceptance_test_concern:` key present AND value is non-empty string:
   - Append entry to in-memory aggregate: `{unit_id: U-XXX, concern: <text>, source: <bolt-report.md path>}`.
   - Log one-line warning to chat: `"⚠ U-XXX flagged acceptance_test_concern: <truncated 100 chars>"`.
3. After all bolts complete (in `--all` mode), assemble aggregate into handoff `metrics.acceptance_test_concerns: [{unit, concern}]` array (per §Handoff emission below).
4. Aggregate also surfaced via `_summary.md` (existing rollup mechanism — adds new sub-section "## Acceptance-test concerns" listing affected units).

**Closes Iter 53 PARTIAL→USED wiring:** Iter 47 instrumented the bolt subagent to emit `acceptance_test_concern` self-assessment field, but no execute-bolts post-flight scanned the field and no downstream consumer surfaced it. Pure producer-only emission until Iter 53. The orchestrate-flow Step 7 final summary now surfaces the count + unit list when non-empty (per `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` Step 7 diagnostics summary).

**No new halt type** — concerns are warnings, not blockers. Re-validation path is `/mega-sdd:generate-units --regenerate --adversarial-subagent --units=<list>` (Iter 47 mechanism) to author stronger acceptance tests, then re-run affected bolts.

### Provenance trailer enforcement (v2.6.0+, Iter 30 §10 principle 9)

Post-flight scan also verifies every modified file has provenance trailer comment:

```
Generated by mega-sdd execute-bolts <version>
Unit: U-XXX (vault sha256: <hash>)
Implements claim: C-NNN "<claim text>"
Anchors consulted: <list>
Hard Rules active: <list of rule IDs>
```

Language-appropriate comment style (e.g., `//` for JS/PHP/Java, `#` for Python/Ruby, `--` for SQL).

Missing trailer → halt `provenance_missing` (always-pause per §6.3).

## Halt protocol

Per `references/bolt-contract.md` failure modes. Always emit blocker YAML on halt:

```yaml
blocker:
  unit: U-XXX
  cause: <category>
  details: <verbatim error / test output>
  next_action: <retry | edit unit | manual fix>
```

When retries exhaust for a unit's acceptance test, emit:

**Structured halt per `vault-contract.md §halt-protocol`:**

```yaml
blocker:
  type: test_fail
  emitted_at: <ISO8601 timestamp>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    retries_attempted: <N, default 3>
    test_command: <exact command run>
    last_failure_output: |
      <verbatim output of last failing test invocation>
    files_touched:
      - <list of files touched during the attempts>
  next_action: "Review bolt-report.md; edit unit acceptance criteria, fix code manually, or skip via --force"
```

**Structured halt per `vault-contract.md §halt-protocol` (v1.1+):**

```yaml
blocker:
  type: cross_squad_interface_draft
  emitted_at: <ISO8601 timestamp>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    unit_squad: squad-fe-web
    consumed_interface_id: api-leave-request-submit
    producer_squad: squad-be
    interface_status: draft
  next_action: "Producer squad must lock the interface before consumer bolts can execute. Edit interfaces/<id>.md frontmatter: status: locked, locked_at: YYYY-MM-DD. Re-run execute-bolts."
```

### Propose-and-confirm halt UX (v2.6.0+, Iter 30 §6.3)

Per `references/propose-and-confirm-prompt.md`. When bolt halts with eligible halt type, dispatch AI fix-proposer subagent → render proposal via AskUserQuestion → on user-accept apply fix + re-execute → on user-reject continue chain pause.

**Eligible halt types** (default propose-and-confirm; configurable per `~/.mega-sdd/memory/config.yaml` `halt_auto_propose`):
- `test_fail` (after default 3 retries via `--max-retries`)
- `hard_rule_violated` (with framework pack provenance evidence)
- `pbt_property_violated` (counterexample preserved in postflight)

**NOT eligible** (always pure pause):
- `oq_business_p1_unresolved` — human business decision required
- `dedup_ambiguous` — human judgment required
- `quality_gate_failed` — broader investigation needed
- `constitution_drift_detected` — audit-significant
- `bolt_repeated_partial_failure` — structural problem; fix won't help
- `provenance_missing` — user must add trailer
- `dispatch_prompt_too_large` — config issue, not bolt-fixable
- `dep_missing` — environment setup needed
- `hard_rule_unparseable` — config issue
- `hard_rule_unanchored` — config issue
- `verify_unit_writable` — config issue

**Dispatch contract**:
1. Bolt halt → check halt type eligibility + user config override
2. If eligible: dispatch fix-proposer subagent with `references/propose-and-confirm-prompt.md` template
3. Subagent returns proposed_fix YAML (root_cause + evidence_chain + fix diff + confidence + optional alternatives)
4. Render to user via AskUserQuestion (5 options: Apply / Alt / Reject / Cancel / Override)
5. On Apply: write proposed_fix to `<vault>/bolts/U-XXX/proposed-fix.md` → apply diff → re-execute single bolt → continue batch
6. On Reject: write proposed_fix to `<vault>/bolts/U-XXX/proposed-fix.md` (preserved for next session) → chain pauses
7. On Override: record to memory `decisions.md` as forced_pass → continue batch (audit-significant)

**Halt cycle safety**: if same halt fires twice on same bolt with different proposed fixes → escalate to `bolt_repeated_partial_failure` (always-stop).

**Configuration override** (`~/.mega-sdd/memory/config.yaml`):

```yaml
halt_auto_propose:
  test_fail: propose          # default
  hard_rule_violated: propose
  pbt_property_violated: propose
  oq_business_p1_unresolved: pause   # always
  dedup_ambiguous: pause             # always
  # ... rest pause by default
```

### New halt types (v2.6.0+, Iter 30)

Beyond existing halts, Iter 30 adds:

| Halt type | Fires when | Eligible for propose? |
|---|---|---|
| `dispatch_prompt_too_large` | Step 4.5 tiered prompt > 10KB hard cap | NO (config/spec issue) |
| `bolt_repeated_partial_failure` | 3+ partial-state attempts on same bolt OR propose-and-confirm cycled with different fixes | NO (structural) |
| `provenance_missing` | Post-flight detects missing provenance trailer in modified file | NO (user adds trailer) |
| `bolt_introduces_locked_drift` | Per-bolt drift check detects drift on LOCKED entity | YES (eligible for propose-and-confirm OR override) |
| `self_assessment_missing` | bolt-report.md lacks `bolt_self_report` YAML block | NO (bolt must self-report) |

Halt YAML envelopes for each are documented in spec §Appendix B and `references/propose-and-confirm-prompt.md`.

## Property-Based Testing validation (v2.4+, Iter 20 — closes Iter 18 Bug 1)

Per `generate-units/references/pbt-integration.md`. When unit has `properties:` field non-empty:

### Pre-flight (during Step 4 alongside Hard Rule snapshots)

For each `properties[].cites` reference, validate citation resolves (per Iter 7 anti-halu rail):
- Probe vault section / entity / constitution clause exists
- If unresolved → halt `pbt_citation_invalid` (mirrors `oq_recommend_citation_invalid` rail)

### Acceptance phase (within Step 5 superpowers TDD)

If PBT framework detected (per `pbt-integration.md` §Framework detection):

1. Generate-units has already emitted PBT test stubs in unit's `target_files` (e.g., `tests/Property/<Name>Test.<ext>`)
2. Run PBT tests as part of acceptance phase via the detected framework:
   ```bash
   # Examples per language:
   ./vendor/bin/phpunit --group=property      # PHP/Eris
   npm run test -- --testPathPattern=Property # TS/JS/fast-check
   pytest tests/property/ -p hypothesis        # Python/Hypothesis
   go test ./... -run TestProperty              # Go/gopter
   cargo test property -- --include-ignored    # Rust/proptest
   ```
3. Parse exit code + counterexample output

### Post-flight halt logic

For each property tested:

| Outcome | severity=error | severity=warning |
|---|---|---|
| Property holds | ✓ PASS | ✓ PASS |
| Property violated (counterexample found) | HALT `pbt_property_violated` | Log to bolt-report.md as warning; bolt proceeds to commit |

### Halt YAML for pbt_property_violated

```yaml
blocker:
  type: pbt_property_violated
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    violated_property: PROP-002
    property_description: "nama is case-insensitive"
    counterexample:
      nip: 12345
      nama: "Müller"
      password: "secret"
    expected: case-insensitive match
    actual: response codes differ for 'müller' vs 'Müller'
    cites: 04-flows.md#F-U-001-login
  next_action: "Property violated. Either fix code to satisfy property OR adjust property statement OR add explicit edge-case handling. See <vault>/bolts/<unit>/bolt-report.md PBT section for full counterexample."
```

### Framework absent fallback

If `properties:` non-empty but no PBT framework detected (e.g., bare PHP project without Eris):
- Skip test emission + validation
- Log advisory note in bolt-report.md: "PBT framework not detected; properties documented as advisory only"
- Bolt proceeds normally per acceptance_test

### --no-pbt opt-out

`--no-pbt` flag on execute-bolts skips PBT validation entirely. Preserves pre-v2.4 behavior. Useful when:
- CI environment lacks PBT framework
- One-off bolt run for testing
- User explicitly wants example-test-only validation

## Anti-hallucination rails

- target_files whitelist enforced at every step
- existing_interfaces preserved (verified by tests)
- No auto-bypass of pre-commit hooks
- No --force commits or push to remote
- OQ in unit body → prompt user before bolt finalizes
- (v1.2+, Iter 1) `task_type: verify` units MUST NOT write code; halt `verify_unit_writable` if target_files has writable operations
- (v1.2+, Iter 3) Hard rules pre-flight snapshot is mandatory when `## Hard rules` is non-empty. NEVER skip the snapshot to save time.
- (v1.2+, Iter 3) Post-flight Hard rule validation runs BEFORE commit. Violations halt with code changes still in working tree (NOT auto-reverted; user decides).
- (v1.2+, Iter 3) Unparseable hard rules halt at pre-flight — NEVER silently skip rules whose grammar isn't recognized.
- (v1.2+, Iter 3) `SIGNATURE_RULE` referencing a symbol absent in codebase-map → halt `hard_rule_unanchored` (cannot validate what doesn't exist).
- (v1.2+, Iter 3) No `--skip-preflight` flag per DESIGN-OQ-5. Pre-flight scan is the contract.
- (v2.0+, Iter 6) `--hard-rule-grammar=v1|v2` selects grammar version; default `auto` (detect from YAML presence in `## Hard rules`).
- (v2.0+, Iter 6) Mixed v1/v2 grammar in same unit → halt `hard_rule_mixed_grammar`. User migrates via `/mega-sdd:migrate-rules`.
- (v2.0+, Iter 6) ast-grep not on PATH AND unit has v2 rules → halt `dep_missing` with install commands.
- (v2.7.0+, Iter 32) Starterkit slice budget: T2 starterkit slice MUST be capped at 2KB. Truncation order: libs[] (top 10 by relevance) → idioms[] (top 3) → halt dispatch_prompt_too_large if still over. Prevents bolt context bloat regression.
- (v2.7.0+, Iter 32) Starterkit slice constraint honoring: when T2.3 starterkit section is present in dispatch prompt, bolt subagent MUST honor: extend the named layout, use the named notification lib, use only the listed libs (no inventing alternatives). Code that violates is rejected at post-flight check (existing rule extension).

## Compact streaming progress (v2.6.0+, Iter 30 §6.1)

Per-bolt status emitted as compact streaming format (chat-friendly, updated in-place):

```
▶ Bolt 7/20: U-007 "Create User model" (scope: BE)
  └─ Context: 6 upstream loaded, 3 anti-patterns flagged, confidence HIGH
  └─ Pre-flight: Hard Rules ✓ | PBT ready ✓ | Anchors verified 3/3 ✓
  └─ Execution: TDD red ✓ → green ✓ (45s)
  └─ Post-flight: Hard Rules ✓ | PBT ✓ | Drift check: clean ✓
  └─ Commit: 8a3f2e1 "feat(U-007): create User model"
✓ Bolt 7/20: U-007 → done in 1m23s, 0 retries, confidence 0.92
```

Halt cases get fuller treatment inline (see §Propose-and-confirm halt UX below).

After batch (printed at end of execute-bolts --all run):

```
══════════════════════════════════════════════════════════
✓ execute-bolts batch complete: 18/20 done, 2 halted, 1 auto-resolved
══════════════════════════════════════════════════════════
  Scope: BE | Duration: 24m11s | Retries: 3 total | Avg confidence: 0.87
  Halts open: U-012 (test_fail awaiting user), U-015 (hard_rule_violated)
  See <vault>/bolts/_summary.md for full table
  Next: detect-drift (auto-gate, hybrid mode — DEFAULT-ON per Iter 30 §6.4)
```

## Aggregate summary `<vault>/bolts/_summary.md` (v2.6.0+, Iter 30 §6.2)

Auto-generated AFTER every batch (overwrite-safe; idempotent regen).

Structure:

```markdown
# Bolts Summary — <Project Name>
**Generated**: <ISO8601> (mega-sdd execute-bolts v2.6.0+)
**Scope**: <scope_id> (<scope_name>)
**Batch**: <--all | --squad=X | --module=Y>
**Duration**: <duration>
**Avg AI confidence**: <0.0-1.0>

## Status table
| Unit | Title | Status | Duration | Retries | Confidence | Halt type | Commit |
|---|---|---|---|---|---|---|---|
| U-001 | <title> | ✓ done | 45s | 0 | 0.95 | — | <sha> |
| ... | ... | ... | ... | ... | ... | ... | ... |

## Halts open (N)
- U-XXX: <halt_type> after <retries> retries. <fix proposal status>. Resume: `/mega-sdd:auto --resume`.

## Hard rule violations across batch (by rule)
| Rule | Source | Violations | Resolution |
|---|---|---|---|

## Mutability tier coverage (when scope-tagged vault)
| Tier | Units touched | Status |
|---|---|---|

## Self-assessment summary (uncertain decisions across batch)
- U-XXX: "<decision>" — fallback: <safer alternative>

## Next steps
- Resolve <N> halts: `/mega-sdd:auto --resume`
- After all green: detect-drift will auto-run (hybrid gate; --no-drift-check opt-out)
```

Generation timing: written immediately after batch loop completes (whether all bolts succeeded, some halted, or chain cancelled). Overwrites any prior _summary.md (no append; full regen each batch).

## Outputs

Per unit:
- Code commits (1+) on current branch (skipped for `task_type: verify` if no changes)
- `<vault>/bolts/U-XXX/bolt-report.md`
- (v1.2+, Iter 3) `<vault>/bolts/U-XXX/preflight.json` — Hard rule pre-flight snapshot for audit + diff
- (v1.2+, Iter 3) `<vault>/bolts/U-XXX/postflight.json` — Hard rule post-flight check results (per-rule pass/fail + evidence)

Global:
- Update `<vault>/vault.json` changelog: `{ "event": "bolt_completed", "unit": "U-XXX", "commits": [...] }`

**v2.4.2+ Iter 29 scope traceability (P2-1)**: When `vault.json` has `scope` field, `bolt-report.md` MUST include scope field in header for multi-squad traceability:

```yaml
---
unit: U-001
scope: <vault.scope_metadata.id>           # v2.4.2+ Iter 29; omit when vault has no scope
scope_name: <vault.scope_metadata.name>    # v2.4.2+ Iter 29
# ... existing fields
---
```

Lightweight: read vault.json once at skill start; propagate scope into bolt-report header. NO behavior change to bolt execution logic.

Handoff YAML may include scope: block per `orchestrate-flow/references/handoff-contract.md` v3.20+ when vault has scope.

## Hand-off

After last unit:
- Suggest `/mega-sdd:detect-drift` to verify all bolts honored the vault
- Show summary: N units done, M failed, P skipped

### End-of-chain phase context (v2.7.1+, Iter 35)

After final bolt completes successfully (status==completed AND blockers==[]), inspect `vault.json` for `phase` + `phase_total` fields:

IF `vault.phase < vault.phase_total`:
  Set handoff `next_action`:
  ```yaml
  next_action:
    suggested_skill: mega-sdd:generate-intent
    suggested_args: ["--kb=<KB-path-from-vault.json.kb_source>", "--phase=<phase+1>"]
    rationale: "Phase <N> complete; continue to Phase <N+1>. Plan: .mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md §Phase <N+1>."
  ```

IF `vault.phase == vault.phase_total` (final phase) OR `phase_total == 1`:
  Set handoff `next_action`:
  ```yaml
  next_action: "All phases complete (Phase <N> of <M>). Pipeline finished — no further skill to invoke."
  ```

IF `phase` field absent in vault.json (pre-v3.26.0 vault):
  Default treatment: act as if `phase: 1, phase_total: 1` → chain_complete hint.

## Handoff emission (v1.3+, Iter 4)

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML record at the end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: execute-bolts
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  artifacts:                                                  # Enumerate ONE LINE per bolt dir actually written; NO "..." shorthand ranges; NO "(N units)" annotations
    - <absolute path to vault/bolts/U-001/>                   # e.g., /Users/.../.mega-sdd/vaults/<vault>/bolts/U-001
    - <absolute path to vault/bolts/U-002/>                   # one line per executed unit
    # WRONG: "/.../bolts/U-001/ ... U-016/"  ← validator expands ellipsis defensively (Iter 74), but producers SHOULD enumerate explicitly
    # WRONG: "/.../bolts/ (16 units)"        ← annotation will be stripped, but be explicit
    # Repeat "- <abs path to bolts/U-NNN/>" for EVERY unit you executed — no shortcuts. validate-handoff-yaml.sh os.path.exists() each entry.
  starterkit_context:                                       # v2.7.0+, Iter 32 (passthrough + metrics)
    reused: false
    framework: laravel
    auth_lib: sanctum
    rbac_lib: spatie/permission
    ui_stack: "alpine + tailwind + sweetalert2"
    libs_count: 47
    bolts_used_starterkit_slice: 11                         # NEW metric
    slice_avg_size_kb: 1.6                                  # NEW metric (average T2 slice size injected)
  next_action:
    suggested_skill: mega-sdd:detect-drift
    suggested_args: []
    rationale: "All bolts executed; recommend periodic drift check."
  blockers: []   # populated on test_fail / hard_rule_violated / hard_rule_unparseable / hard_rule_unanchored / cross_squad_interface_draft / verify_unit_writable
  metrics:
    items_processed: <N units executed>
    items_blocked: <N halts encountered>
    bolts_used_starterkit_slice: <int>                      # NEW v2.7.0+
    slice_avg_size_kb: <float>                              # NEW v2.7.0+
    acceptance_test_concerns:                               # NEW v2.10.0+, Iter 53 — harvested from bolt-report.md self-assessment per §Post-flight acceptance-test concern harvest
      - unit: U-007
        concern: "Test asserts user.id present but doesn't validate id is unique across concurrent requests; implementation may regress under load."
      # ... one entry per bolt that flagged a concern; empty array if none
    # Consumer (Iter 53): orchestrate-flow Step 7 diagnostics summary surfaces count + unit list when non-empty.
  scope:                                  # v3.20+ (Iter 28) — when vault has scope_metadata
    id: <scope id, e.g., "BE">
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from vault.json>
```

Status `halted` on `test_fail` (acceptance test exhausted retries) / `hard_rule_violated` (post-flight scan) / `hard_rule_unparseable` / `hard_rule_unanchored` / `cross_squad_interface_draft` / `verify_unit_writable`. Required ONLY under `--auto`.

## Memory layer (v1.4+, Iter 5)

When memory enabled (default; opt-out via `--memory-off`), participates in mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`.

### Writes

| When | File | Content |
|---|---|---|
| After each bolt commits (success) | `<vault>/.memory/bolt-outcomes.json` | Append entry: unit_id, run_at, task_type, status=completed, duration_ms, tests_passed=true, hard_rules_validated=[list of rule strings that passed] |
| After each bolt halts (failure) | `<vault>/.memory/bolt-outcomes.json` | Append entry: unit_id, status=halted_*, halt_reason, violated_rules=[list with evidence], resolution=pending |
| After user resolves a halt (next session) | `<vault>/.memory/bolt-outcomes.json` | Update prior entry: resolution=(user_reverted_code | user_edited_unit | user_force_committed | user_skipped), resolution_at, resolution_note |
| After chain run completes | `<project>/.mega-sdd/memory/outcomes.md` | Append run summary: phases run, halts encountered, total duration, hard rule violation count |

### Reads

| What | Source | How used |
|---|---|---|
| Past bolt outcomes for same unit | `<vault>/.memory/bolt-outcomes.json` | Before executing unit U-X: if past run halted with violation Y → surface to user pre-execution: "U-X previously halted on rule Y. Same risk now. Continue?" (informational; not blocking) |
| Past Hard Rule violation+revert patterns | `<vault>/.memory/bolt-outcomes.json` | Pre-flight: if rule R has been violated AND reverted ≥3 times → emit one-line warning in chat before scanning: "Rule R has been overridden 3+ times. Validation will still fire; consider removing rule from unit" |

### Anti-halu rails

- Memory consultation NEVER bypasses pre/post-flight Hard Rule validation
- Past-halt warnings are INFORMATIONAL only; user decides to proceed
- `bolt_outcomes.json` write happens AFTER commit (or after halt) — memory is derivative of bolt-report.md (the source-of-truth artifact)
- `--memory-off` disables both reads and writes
