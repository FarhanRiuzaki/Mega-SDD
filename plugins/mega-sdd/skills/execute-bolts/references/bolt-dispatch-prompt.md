# Bolt Subagent Dispatch Prompt Template

Canonical prompt template for dispatching bolt subagent via superpowers `executing-plans`. Implements the 10 AI-executor principles from spec §4. Tiered context (T1/T2/T3) per spec §6.10.

**Token budget**: T1 ≤2KB, T2 ≤10KB, T3 reference-only. Total dispatch prompt ≤9KB target (hard cap 12KB → halt `dispatch_prompt_too_large`). Canonical budget numbers live in `context-enrichment.md` §running budget tracker (`cap_hard=12288`, `cap_target=9216`, `cap_t1=2048`, `cap_t2=10240`); the figures in this template MUST match that source.

## Contents

- Template structure
- Unit body (verbatim)
- Halt vocabulary (pre-loaded for clean halts)
- Self-assessment vocabulary (REQUIRED in bolt-report.md)
- Acceptance-test provenance NOTE
- Rollback hints (REQUIRED in bolt-report.md `## Rollback hints` section)
- Atomic discipline (scaffolded, not assumed)
- Anti-context (negative space = freedom + protection)
- Provenance trailer (MANDATORY in every modified file)
- Upstream bolts (depends_on chain — 1-line summary each)
- Framework pack rules (filtered by your target_files glob match)
- Constitution clauses (referenced by your vault_source)
- KB anti-patterns (filtered by your domain tags)
- Historical memory (last 5 relevant patterns)
- T2.3 — Starterkit context (relevant slice)
- Confidence labels per claim
- Validation hints (specific, not vague)
- Tier-loading algorithm
- Anti-halu rails
- Logging

## Template structure

```
═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-XXX
═══════════════════════════════════════════

UNIT: <id> "<title>"
SCOPE: <scope_id> (<scope_name>) — framework: <framework_pack>

═══════════════════════════════════════════
TIER 1 — Always read (target ≤2KB)
═══════════════════════════════════════════

## Unit body (verbatim)
<full unit frontmatter + body — non-negotiable>

## Halt vocabulary (pre-loaded for clean halts)

IF YOU CAN'T PROCEED, HALT WITH ONE OF:
  type: test_fail              (after 3 retries; include test name + output)
  type: hard_rule_violated     (cite rule + file:line evidence)
  type: ambiguous_spec         (cite ambiguity + 2 interpretations + your default)
  type: missing_dependency     (cite what's missing + where you looked)
  type: scope_creep_detected   (asked to touch files outside target_files)

Halt YAML template (fill placeholders):
```yaml
blocker:
  type: <halt_type>
  emitted_at: <ISO8601>
  emitted_by: bolt-subagent-U-XXX
  unit_id: U-XXX
  details:
    <halt-type-specific fields>
  next_action: "<suggested user action>"
```

## Self-assessment vocabulary (REQUIRED in bolt-report.md)

```yaml
bolt_self_report:
  confidence: <0.0-1.0>
  certain_decisions:
    - "<decision with HIGH confidence>"
  uncertain_decisions:
    - decision: "<what you did>"
      rationale: "<why>"
      fallback_if_wrong: "<safer alternative>"
  retry_history:
    - attempt: <int>
      failure: "<verbatim failure>"
      fix: "<what you changed>"
```

## Acceptance-test provenance NOTE

execute-bolts injects this NOTE into the dispatch prompt when the unit's `acceptance_test._authored_by` field is `same-pass` OR `adversarial-review-failed` (weak blind-spot coverage signals per `generate-units/references/adversarial-test-prompt.md` §provenance values).

```
> NOTE: This unit's `acceptance_test` has weak blind-spot coverage
> (_authored_by: <value>). The test was authored by the same LLM pass that
> wrote the unit body — the test may inherit the same blind spots as the spec
> and fail to catch behavioral bugs your implementation introduces.
>
> If your implementation passes this test but feels under-validated:
>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`
>     explaining what you suspect the test might miss
>   - Propose 1-2 additional assertions you'd add to strengthen coverage
>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested
>
> Strong provenance values (`adversarial-reviewed (+N gaps merged)` /
> `independent-llm` / `human`) → no NOTE injected; trust the test.
```

The NOTE is OMITTED for units with strong provenance (the default for newly generated units). Legacy units (no `_authored_by:` field) are treated as `same-pass` and trigger the NOTE.

## Rollback hints (REQUIRED in bolt-report.md `## Rollback hints` section)

For EACH significant step you perform (file write, dep add, migration, etc.), append a rollback hint to bolt-report.md `## Rollback hints` section. On crash, execute-bolts harvests these into partial-state.json v2.0 `rollback_hints[]` array. On `--rollback`, they're applied in reverse order.

```yaml
- step_id: step-1-add-dep                   # short identifier, unique within this bolt
  step_type: composer_dep_added             # see canonical taxonomy below
  evidence: "added 'laravel/cashier': '^15.0' to composer.json:42; composer.lock regenerated"
  compensating_action: "composer remove laravel/cashier --no-update && git checkout composer.json composer.lock"
  idempotent: false
```

**Canonical step_type taxonomy (use these EXACT values — execute-bolts §Partial-state contract table):**

| step_type | When to use | Idempotent? |
|---|---|---|
| `file_created` | created a new file | ✓ |
| `file_modified` | edited an existing file | ✓ |
| `file_partially_written` | started writing but did not finish (crash mid-write) | ✓ |
| `file_deleted` | rm'd a file | ✓ |
| `composer_dep_added` | added a require/require-dev to composer.json + ran composer | ✗ |
| `composer_dep_removed` | removed a composer dep | ✗ |
| `npm_dep_added` | added a dep to package.json | ✗ |
| `npm_dep_removed` | removed an npm dep | ✗ |
| `migration_created` | wrote a new migration file | ✓ |
| `migration_executed` | ran `php artisan migrate` or equivalent | ✗ (DB state) |
| `external_api_call` | hit an external API with side effect | ✗ |
| `test_command_run` | ran a test command (read-only side-effects only) | ✓ |
| `git_commit` | created a git commit | ✗ |
| `git_branch_created` | created a git branch | ✓ |

If a step doesn't fit any of these, use `file_modified` (safest fallback) OR omit the rollback hint (less safe). Unknown step_type values in partial-state.json trigger the `partial_state_corrupt` halt.

**Idempotent flag:** TRUE if the compensating_action is safe to re-run multiple times. FALSE if running the action twice could compound errors (composer cache, DB state, external state). FALSE values prompt user confirmation per-action during `--rollback`.

**Compensating_action:** literal shell command (NOT a description). Empty string `""` only when no rollback is possible (e.g., `external_api_call` to a non-idempotent endpoint); use `"(none — manual review required)"` for that case.

**If the bolt completes successfully:** the `## Rollback hints` section is INFORMATIONAL only — no rollback needed; the commit landed cleanly. Hints persist in bolt-report.md for audit trail.

## Atomic discipline (scaffolded, not assumed)

- THIS BOLT = ONE COMMIT
- target_files whitelist: <list from unit frontmatter> — DO NOT touch outside
- Commit message format: "feat(U-XXX): <imperative phrase from unit title>"
- DO NOT bundle unrelated concerns
- If you find yourself wanting to modify unrelated file → halt `scope_creep_detected`

## Anti-context (negative space = freedom + protection)

DO NOT MODIFY: <list of LOCKED files from data-mutation-policy.md>
DO NOT REPLICATE: <list of KB anti-patterns relevant to this unit's domain>
DO NOT WRITE: <forbidden patterns from framework pack — e.g., $(document).ready()>
DO NOT COMMIT IF: <preconditions — e.g., test failures, hard rule violations, missing provenance trailer>

## Provenance trailer (MANDATORY in every modified file)

Add at top of file (language-appropriate comment):
```
Generated by mega-sdd execute-bolts <version>
Unit: U-XXX (vault sha256: <hash>)
Implements claim: C-NNN "<claim text>"
Anchors consulted: <list>
Hard Rules active: <list of rule IDs>
```

Post-flight scan VERIFIES presence. Missing → halt `provenance_missing`.

═══════════════════════════════════════════
TIER 2 — Conditional context (target ≤10KB total)
═══════════════════════════════════════════

## Upstream bolts (depends_on chain — 1-line summary each)

<for each upstream bolt in depends_on:>
- U-<id> "<title>" → committed at <sha>
  └─ <1-line summary from bolt-report.md self-report>

## Framework pack rules (filtered by your target_files glob match)

<for each rule in framework pack where rule.path_glob matches any unit.target_files:>
- <rule-id> (from <pack>.md §<section>)
  └─ <rule body>

## Constitution clauses (referenced by your vault_source)

<for each clause in constitution.md where clause was cited in unit's vault_source sections:>
- §<id>: <clause text>

## KB anti-patterns (filtered by your domain tags)

<for each KB anti-pattern matching unit's domain tags:>
- KB <gotcha-id> from <kb-file>.md: <anti-pattern description>
  └─ DO NOT REPLICATE per <constitution clause OR explicit rationale>

## Historical memory (last 5 relevant patterns)

<from <project>/.mega-sdd/memory/outcomes.md, filtered by:>
<- bolts touching similar files (overlap with this unit's target_files)>
<- bolts with similar patterns (same unit type, same scope)>
<show last 5 only, most-recent-first>

Pattern: <pattern-description> → <past resolution>

## T2.3 — Starterkit context (relevant slice)

This section is populated by execute-bolts Step 4.5.b-starterkit when:
1. `<project>/.mega-sdd/codebase/starterkit-context.yaml` exists (deep-scan was run)
2. EITHER `unit.starterkit_relevance` is non-empty (auth/rbac/ui_ux/libs slices) OR `starterkit_context.patterns` exists AND `unit.target_files` matches a pack-discovered location (§patterns slice — independent of starterkit_relevance)

The dispatcher injects relevant slices (≤8KB total under v3.67.0 caps). Non-matching domains are OMITTED.

**Slice template (sections appear only when relevant):**

```
### Starterkit context (relevant to this unit)

Auth: lib=<auth.lib>, mechanism=<auth.mechanism>, user_model=<auth.user_model>
Authz: lib=<authz.lib>, mechanism=<authz.mechanism>, declarations=<authz.declarations[].name joined by ", ">
UI/UX: extends=<ui_ux.layout_extends>, notification=<ui_ux.notification_lib>, idioms=[<idioms joined by "; ">]
Libs in scope: <lib.name>@<lib.version> (used in: <usage_hint joined by ", ">), ...

### Starterkit code patterns (follow these conventions)

- controller:
    location:  app/Http/Controllers/
    naming:    {Model}Controller<ext>
    extension: .php
    extras:    {base_class: "Controller", methods: ["index","show","store","update","destroy"]}
    _source:   app/Http/Controllers/ExampleController.php:1-30
- data_model: (... same shape for each matched category ...)
- ...

### Reference code example (from starterkit — walking-skeleton: controller only)

Pattern: controller
File:    app/Http/Controllers/ExampleController.php

```php
<?php
namespace App\Http\Controllers;
// ... full file content (or first 100 lines + truncation marker) ...
```

Follow this style for new controller files. Do not deviate from the import order, base class, method shape, or response idiom shown above unless the unit explicitly requires it.
```

**Budget:** total slice content target ≤4KB. Hard cap rolls up to overall T2 budget (cap_t2=10240) — see SKILL.md §T2 Section Priority + Truncation.

Truncation order:
1. `libs[]` — keep top 10 by relevance score
2. `code_examples.controller.content` — truncate from 100 → 50 lines
3. `ui_ux.idioms[]` — keep top 3
4. Drop `code_examples` entirely (patterns metadata preserved)
5. Halt `dispatch_prompt_too_large` if still over hard cap

**Anti-halu rails:**
- When auth/rbac/ui_ux/libs sections present, bolt subagent MUST honor the constraints listed. Do NOT invent libs not listed; do NOT use a different layout; do NOT use a different notification lib.
- When `### Starterkit code patterns` present, bolt subagent MUST match `location` + `naming` + `extension` for new files in that category. Path conventions are non-negotiable.
- When `### Reference code example` present, bolt subagent MUST follow the structural idioms (import order, base class, method shape, response pattern) shown — provenance citation `path:` is the source of truth.

**Absence is valid:** if this section is absent, no starterkit context is available — the bolt should produce code following framework defaults (per the framework pack T1 section).

## Design system (UI-bearing unit — per context-enrichment.md §Design slice)

<present ONLY when the unit ships UI files AND the starterkit ui_ux slice is absent (greenfield / no template). When the starterkit slice IS present it is authoritative and this section is omitted.>

```
Design system (vault): style=<design_system.style> · palette=<design_system.palette> · typography=<design_system.typography> · a11y=<design_system.a11y_level>
Style traits: <style-principles[style] traits + CSS keywords>
Style anti-patterns: <style-principles[style] anti-patterns>
UX floor: <ux-rules a11y + form/feedback rows>
Modern baseline (non-negotiables — the FLOOR): <modern-baseline.md §Non-negotiables digest>
Ceiling moves (clear the floor, then DO these — a floor-only view is "basic/generic"): <modern-baseline.md §Ceiling moves digest>
Anti-kuno tells (a match in your output = defect): <modern-baseline.md §Anti-kuno digest>
```

**Anti-halu rails:**
- The palette/typography lines are the SOURCE for your tokens — never invent a second palette or pairing.
- Every view you write MUST satisfy the Non-negotiables (tokens, spacing scale, type scale, page shell, interactive states, loading/empty/error states, designed forms, a11y floor) and MUST NOT match an anti-kuno tell.
- The design-reviewer panel lens judges your output against THIS EXACT section — it is the contract, not a suggestion.

**Absence is valid:** absent for pure-backend units, or when the starterkit template governs the UI.

## Confidence labels per claim

<for each claim this unit implements (from binding.md):>
- [<HIGH | MEDIUM | LOW>] <claim text>
  └─ Source: <binding citation OR KB inference OR heuristic default>

## Validation hints (specific, not vague)

After implementation, run:
```bash
<specific test command, e.g., ./vendor/bin/phpunit tests/Unit/UserModelTest.php>
```

Expected output pattern: <e.g., "OK (3 tests, X assertions)">
On fail: <failure interpretation — what failing test name encodes>

Also run static analysis (if framework pack specifies):
```bash
<e.g., ./vendor/bin/phpstan analyse <target file> -l 5>
```

Must pass at <pack-specified level>.

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: <X> bytes (cap 2048)
consumed_t2: <Y> bytes (cap 10240, hard 12288)
total: <X+Y> bytes
truncations_applied:
  <if any T2 section was truncated below default contents:>
  - <section_name>: <rule_applied> (saved <Z> bytes)
  ...
  <else:>
  - (none)
instruction_to_subagent:
  If your self-assessment references information that came from a truncated
  section (listed above), mark its confidence as MEDIUM (not HIGH) and note
  the truncation explicitly in your bolt-report.md self-assessment section.
  Truncation is NOT a failure — it's transparency.
```

═══════════════════════════════════════════
TIER 3 — Reference-on-demand (NOT embedded; use Read tool)
═══════════════════════════════════════════

- Full upstream bolt-reports: `<vault>/bolts/U-XXX/bolt-report.md`
- Full constitution: `<vault>/constitution.md`
- Full KB domain files: `.mega-sdd/knowledge-base/10-domains/`
- Full memory tables: `<project>/.mega-sdd/memory/`
- Full framework pack: `plugins/mega-sdd/references/framework-conventions/<pack>.md`

═══════════════════════════════════════════
GENERATE CODE THAT:
═══════════════════════════════════════════

- Uses target framework conventions per pack (Tier 2 §Framework pack rules)
- Respects all [HIGH] claims 1:1 (Tier 2 §Confidence labels)
- Cites anchors when extending existing patterns
- NEVER replicates anti-patterns (Tier 2 §KB anti-patterns + Tier 1 §Anti-context)
- Emits provenance trailer in every modified file (Tier 1 §Provenance trailer)
- Halts cleanly per halt vocabulary if stuck (Tier 1 §Halt vocabulary)
- Self-reports via bolt_self_report YAML at end of bolt-report.md (Tier 1 §Self-assessment vocabulary)
```

## Tier-loading algorithm

The budget dict, the priority-ordered T2 section list, the per-section truncation cascade, and the `dispatch_prompt_too_large` halt condition are defined ONCE in `context-enrichment.md` (§T2 budget tracker, §T2 section priority + truncation cascade, §Halt path + soft-budget warnings, §Size check). This template MUST NOT restate them — the canonical budget figures already live there (see the Token budget note at the top of this file). Load order is HIGH-priority sections first (constitution_clauses NEVER dropped) so they survive truncation as `remaining_t2` depletes.

## Anti-halu rails

- T2 filtering MUST cite source for inclusion (e.g., "framework pack rule X loaded because target_files matched glob Y")
- Anti-context block populated from actual data sources (data-mutation-policy.md, KB, framework pack) — NEVER invented
- Confidence labels MUST cite source (binding C-NNN OR KB inference OR heuristic default with rationale)
- Validation hints MUST be specific commands (not "run tests")
- Provenance trailer template MUST include actual values (unit_id, vault_sha256, claim_id, anchors, rule_ids), not placeholders

## Logging

Per execute-bolts SKILL.md Step 4.5e: log final assembled prompt to `<vault>/bolts/U-XXX/dispatch-prompt.md` for provenance + auditability.
