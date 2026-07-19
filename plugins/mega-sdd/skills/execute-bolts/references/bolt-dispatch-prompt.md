# Bolt Subagent Dispatch Prompt Template

Canonical prompt template for dispatching bolt subagent via superpowers `executing-plans`. Implements the 10 AI-executor principles from spec §4. Tiered context (T1/T2/T3) per spec §6.10.

**Token budget**: T1 ≤2KB, T2 ≤10KB, T3 reference-only. Total dispatch prompt ≤9KB target (hard cap 12KB → halt `dispatch_prompt_too_large`). Canonical budget numbers live in `context-enrichment.md` §running budget tracker (`cap_hard=12288`, `cap_target=9216`, `cap_t1=2048`, `cap_t2=10240`); the figures in this template MUST match that source.

## Contents

- Template structure
- Unit body (verbatim)
- Contracts (agent-carried) — halt / self-report / rollback / provenance / atomic
- Provenance values (per-dispatch)
- Legacy dispatch note (order-3 fallback)
- Acceptance-test provenance NOTE
- Reuse index (PRIMARY reuse lookup surface — T1 line + T2 slice)
- Anti-context (negative space = freedom + protection)
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

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v<plugin.json version at dispatch>)

> **Assembly note (controller):** fill `<plugin.json version at dispatch>` from
> `plugin.json` under the resolved plugin root (`resolve-plugin-root.sh` — Step 4.5
> already shells out). The line is logged as-is to `dispatch-prompt.md`: a forensic
> reader resolves the exact contract text by name + version (agent files are
> versioned in the plugin cache and git — the M-09 sole-copy trade, deterministic
> resolution). The constants themselves are NEVER re-embedded here — the
> bolt-implementer system prompt is their single prompt-side source and cannot be
> truncated by the T2 budget.

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-XXX
  vault_sha256: <hash>
  claims: C-NNN "<claim text>" (one line per implemented claim)
  anchors_consulted: <list>
  hard_rules_active: <list of rule IDs>
```

> **Legacy dispatch (order-3 fallback ONLY, per `superpowers-bridge.md`):** the generic
> superpowers executor's system prompt lacks the contracts — Read
> `agents/bolt-implementer.md` and inline its §Halt vocabulary / §Self-report /
> §Rollback hints / §Provenance trailer sections verbatim into the prompt before
> dispatching.

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

## Reuse index (PRIMARY reuse lookup surface — T1 line + T2 slice)

T1 (always, one line):

```
Reuse index: .mega-sdd/codebase/reuse-index.yaml — your PRIMARY reuse lookup
surface (Iron Rule 4): scan the FULL index with Read/Grep before writing any
new capability; reuse_candidates below is only a hint.
```

T2 (`### Reuse index (filtered slice)`): assembled + truncated per
`context-enrichment.md §Reuse slice: build` (cascade priority 3 — never fully dropped).

## Anti-context (negative space = freedom + protection)

DO NOT MODIFY: <list of LOCKED files from data-mutation-policy.md>
DO NOT REPLICATE: <list of KB anti-patterns relevant to this unit's domain>
DO NOT WRITE: <forbidden patterns from framework pack — e.g., $(document).ready()>
DO NOT COMMIT IF: <preconditions — e.g., test failures, hard rule violations, missing provenance trailer>

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

This slot is populated by execute-bolts Step 4.5.b-starterkit ONLY when `<project>/.mega-sdd/codebase/starterkit-context.yaml` exists. The read/build/§patterns/code-slice/inject machinery, the emitted slice sections and their marker lines (`Auth:` / `Authz:` / `UI/UX:` / `Design tokens:` / `Design system:` / `Libs in scope:`, `### Starterkit code patterns`, `### Reference code example` with its `Pattern:` + `File:` lines), the slice budget, and the slice truncation cascade are defined ONCE in `starterkit-enrichment.md` (routed from SKILL.md; overall budgets + the T2 cascade stay in `context-enrichment.md`). This template MUST NOT restate them.

**Anti-halu rails (binding on the bolt subagent when the slice is present):**
- Honor the listed auth/authz/ui_ux/libs constraints. Do NOT invent libs not listed; do NOT use a different layout; do NOT use a different notification lib.
- When `### Starterkit code patterns` present, match `location` + `naming` + `extension` for new files in that category. Path conventions are non-negotiable.
- When `### Reference code example` present, follow the structural idioms (import order, base class, method shape, response pattern) shown — the provenance citation (`File:` path) is the source of truth.

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
```

## Tier-loading algorithm

The budget dict, the priority-ordered T2 section list, the per-section truncation cascade, and the `dispatch_prompt_too_large` halt condition are defined ONCE in `context-enrichment.md` (§T2 budget tracker, §T2 section priority + truncation cascade, §Halt path + soft-budget warnings, §Size check). This template MUST NOT restate them — the canonical budget figures already live there (see the Token budget note at the top of this file). Load order is HIGH-priority sections first (constitution_clauses NEVER dropped) so they survive truncation as `remaining_t2` depletes.

## Anti-halu rails

- T2 filtering MUST cite source for inclusion (e.g., "framework pack rule X loaded because target_files matched glob Y")
- Anti-context block populated from actual data sources (data-mutation-policy.md, KB, framework pack) — NEVER invented
- Confidence labels MUST cite source (binding C-NNN OR KB inference OR heuristic default with rationale)
- Validation hints MUST be specific commands (not "run tests")
- The Provenance values block MUST carry actual values (unit_id, vault_sha256, claim_id, anchors, rule_ids), not placeholders — the agent-carried trailer shape (bolt-implementer §Provenance trailer) is filled from it

## Logging

Per execute-bolts SKILL.md Step 4.5e: log final assembled prompt to `<vault>/bolts/U-XXX/dispatch-prompt.md` for provenance + auditability.
