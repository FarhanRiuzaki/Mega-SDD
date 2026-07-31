# Bolt Subagent Dispatch Prompt Template

Canonical prompt template for the bolt-subagent dispatch. Implements the 10 AI-executor principles from spec §4. Tiered context (T1/T2/T3) per spec §6.10.

**This template is POPULATED BY `scripts/build-dispatch-prompt.sh`, not by the controller.** The builder emits the sections below into `<vault>/bolts/U-XXX/dispatch-prompt.md`; the controller only invokes it and pastes the returned `inline_core` pointer into the Agent call (SKILL.md §Step 4.5). Several literal strings here are **marker lines matched byte-for-byte by `scripts/validate-dispatch-prompt.sh`** — `Design tokens:`, `Design system:`, `Pattern:`, `File:` — so re-wording one silently disarms the check that asserts it landed. Sections whose input is absent are OMITTED, never emitted empty or placeholder-filled.

**Token budget**: T2 ≤10KB, T3 reference-only. Total dispatch prompt ≤9KB target; `cap_hard` is the `dispatch_prompt_too_large` conjunction's size term. Canonical budget numbers live in `context-enrichment.md` §running budget tracker (`cap_hard=12288`, `cap_target=9216`, `cap_t1=12288`, `cap_t2=10240`); the figures in this template MUST match that source. **`cap_t1` was 2048 and is now 12288** — amended 2026-07-31 from 123 measured builder runs (T1 max 10 874 B; the builder's non-unit-body scaffolding alone floors at 2 385 B, so 2048 was satisfiable only when pack content was missing). It is a REPORTING THRESHOLD, not a bound: T1 is never truncated and the unit body is verbatim, so crossing it means a unit too big to be one bolt. Read `context-enrichment.md ## AMENDMENT 2026-07-31` before quoting any budget figure.

## Contents

- Template structure
- Unit body (verbatim)
- Contracts (agent-carried) — halt / self-report / rollback / provenance / atomic
- Provenance values (per-dispatch)
- Acceptance-test provenance NOTE
- Reuse index (PRIMARY reuse lookup surface — T1 line + T2 slice)
- Anti-context (negative space = freedom + protection)
- Upstream bolts (depends_on chain — 1-line summary each)
- Framework pack rules (filtered by your target_files glob match)
- Constitution clauses (cited in this unit, resolved in the constitution §C)
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
mega-sdd-trace:execute-bolts:<unit-id>   ← observability tag, verbatim (AI-gateway/Langfuse filter; subagent context is fresh, so the session tag never reaches it)

UNIT: <id> "<title>"
SCOPE: <scope_id> (<scope_name>) — framework: <framework_pack>

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
<full unit frontmatter + body — non-negotiable>

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v<plugin.json version at dispatch>)

> **Assembly note (builder):** `<plugin.json version at dispatch>` is filled from
> `<plugin_root>/.claude-plugin/plugin.json` (NOT `<plugin_root>/plugin.json` — this
> template said so for a long time and no such file exists) under the resolved plugin
> root. The builder shells out to `resolve-plugin-root.sh` once, and skips even that
> when the caller passes `--plugin-root`. The line is logged as-is to `dispatch-prompt.md`: a forensic
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
  hard_rules_active:            # rule TEXT verbatim, one entry per rule — NOT ids
    - <rule text exactly as the unit's `## Hard rules` states it>
```

> **`hard_rules_active` carries verbatim TEXT, decided 2026-07-31** (`context-enrichment.md §Re-decided amendments`, row 2). Unit Hard rules have no ids; minting them would fork a second identity model from `_lib/postflight_rules.py`, which is what the B1 gate matches against. This template said `<list of rule IDs>` and `agents/bolt-implementer.md §Provenance trailer` said the same — both are corrected, because the implementer was being told to stamp ids into a mandatory trailer while its only sanctioned source hands it text, and post-flight verifies trailer PRESENCE only, so the mismatch would land as a malformed-but-present trailer no gate catches.

> **The order-3 legacy-dispatch element is REMOVED (2026-07-31 — path closed, not
> unimplemented).** It used to say: on the order-3 fallback, Read
> `agents/bolt-implementer.md` and inline its §Halt vocabulary / §Self-report /
> §Rollback hints / §Provenance trailer verbatim, because a generic superpowers
> executor's system prompt carries none of them. The builder never implemented it
> and has no flag for it — it always emits the single `## Contracts (agent-carried)`
> pointer line above. Rather than leave a template element with no implementation
> and a contracts line that would assert something FALSE on that path, the path
> itself is closed: **`build-dispatch-prompt.sh` and `agents/bolt-implementer.md`
> ship in the SAME plugin tree and resolve from the SAME `resolve-plugin-root.sh`
> root that fills the version on the contracts line** — so "the builder ran but the
> first-class agents are unavailable" is not a reachable state. If the Agent tool
> genuinely cannot dispatch `mega-sdd:bolt-implementer`, that is a broken install:
> STOP and surface it to the human (untyped blocker → pure-pause). Never substitute
> a generic executor that holds no halt vocabulary, no rollback hints and no
> provenance-trailer shape while the prompt tells it that it does. See
> `superpowers-bridge.md §Dispatch order` item 3.

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

DO NOT MODIFY: <LABELLED UNION of two sources, each entry carrying its own:
                (a) [LOCKED] entries of <kb>/99-rebuild-architecture/data-mutation-policy.md
                    — emitted as `<path>  (source: data-mutation-policy.md)`
                (b) the unit's own `## Hard rules` DO NOT / MUST NOT / NEVER modify lines
                    — emitted as `<path>  (source: U-XXX.md ## Hard rules)`
                Either source absent contributes nothing and is recorded in
                sections_omitted; both absent omits the line. NEVER emit (b) alone
                under a label that reads as (a) — see context-enrichment.md
                §Anti-hallucination rails, "never substitute one source for another".>
DO NOT REPLICATE: <list of KB anti-patterns relevant to this unit's domain — the WHOLE line is omitted today: phantom "domain tags" join key, see §KB anti-patterns>
DO NOT WRITE: <forbidden patterns from framework pack — e.g., $(document).ready()>
DO NOT COMMIT IF: <preconditions — e.g., test failures, hard rule violations, missing provenance trailer>

═══════════════════════════════════════════
TIER 2 — Conditional context (target ≤10KB total)
═══════════════════════════════════════════

## Upstream bolts (depends_on chain — 1-line summary each)

<for each upstream bolt in depends_on:>
- U-<id> "<title>" → committed at <sha>
  └─ [<status>] <confidence or n/a> · <retries or n/a> — src: <bolt-report.md path>

<The `[<status>]` marker is UNCONDITIONAL — it comes from the report FRONTMATTER and
 does NOT depend on a `bolt_self_report:` block. A halted bolt is precisely the one
 with no self-report, so a derivation that stops early when the block is missing drops
 the marker for the upstreams that most need it, and `halted_postflight` then reads
 byte-identically to a clean success. Absent sub-values render `n/a`, never `0`.>

## Framework pack rules (filtered by your target_files glob match)

<for each rule in framework pack where rule.path_glob matches any unit.target_files:>
- <rule-id> (from <pack>.md §<section>)
  └─ <rule body>

## Constitution clauses (cited in this unit, resolved in the constitution §C)

<HEADING FIXED 2026-07-31. The old `(referenced by your vault_source)` heading described
 a selector that has never existed — `vault_source` is a scalar and nothing keys a clause
 to a vault section — so the section told the subagent its clause came from its vault
 source when it came from a token match in its own body, contradicting the provenance line
 inside the same section. A heading is a claim about provenance and gets the same
 discipline as any other. The selector is the three-way intersection in
 `context-enrichment.md §TIER 2 — Constitution clauses`.>

<for each id that (1) appears in this unit outside fenced code blocks and inline code
 spans, AND (2) resolves to a real clause block in the constitution §C:>
- §<id>: <clause text>
  └─ Source: constitution.md §C (cited in <where in the unit>)

## KB anti-patterns (filtered by your domain tags)

<NOT POPULATED — this section and the T1 `DO NOT REPLICATE:` anti-context line are
 currently ALWAYS OMITTED. "domain tags" is a phantom field: no unit schema, validator
 or writer defines it, so there is no join key from a unit to a KB anti-pattern, and
 filling it would be fabrication (invariant #5). Kept as the shape to emit the day a
 real join key ships — see `context-enrichment.md` cascade note on priority 4.>

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
Design system: style=<design_system.style> · palette=<design_system.palette> · typography=<design_system.typography> · a11y=<design_system.a11y_level>
Style: <Style> — best for: <Best For> · avoid for: <Avoid For>
Style CSS keywords: <CSS Keywords>
   (style-principles.md §<Style>)
UX floor: <ux-rules a11y + form/feedback rows>
Modern baseline (non-negotiables — the FLOOR): <modern-baseline.md §Non-negotiables digest>
Ceiling moves (clear the floor, then DO these — a floor-only view is "basic/generic"): <modern-baseline.md §Ceiling moves digest>
Anti-kuno tells (a match in your output = defect): <modern-baseline.md §Anti-kuno digest>
```

> **Absent values are DROPPED, not rendered.** Every `key=value` pair on the
> `Design system:` line whose value is absent is omitted with its reason recorded;
> if all four are absent the whole line is omitted. A `design_system` block carrying
> only `style` is legal and MUST produce `Design system: style=modern`, never
> `style=modern · palette=None · typography=None · a11y=None`. This is load-bearing
> because the anti-halu rail below names this line as the SOURCE for the bolt's
> tokens: handing it `palette=None` as its authoritative palette forces it to either
> invent one or ship untokened output, while `validate-ui-quality.sh` sees a
> `Design system:` marker and reports `design_system_not_injected` clean. A rendered
> `None` is worse than an omitted line — it is a placeholder that satisfies a gate.
> The same rule governs the starterkit `Auth:` / `UI/UX:` / `Libs in scope:` lines
> and the §patterns `location` / `naming` / `extension` fields.
>
> **Style row: use style-principles.md's OWN column names.** That file's header is
> `| Style | Best For | Avoid For | CSS Keywords |` — there is NO traits column and NO
> anti-patterns column. The retired `Style traits:` / `Style anti-patterns:` lines
> relabelled a PRODUCT-SUITABILITY list as a DESIGN-DEFECT list while citing the file
> by section, telling the implementer that a style's "anti-patterns" are "creative
> portfolios, entertainment, playful brands". The source was real and the assertion
> was invented — invariant #5 in its subtlest form — and because the `design-reviewer`
> lens judges against THIS SAME section, implementer and reviewer would have shared a
> contract `style-principles.md` does not state. Want a real traits vocabulary? Add
> the columns to the generator's source; never rename another file's columns.
>
> **Marker line, not prose.** `Design system:` is matched byte-for-byte by
> `validate-dispatch-prompt.sh` (`DESIGN_SYSTEM_RE = ^\s*Design system\s*:`). The older
> `Design system (vault):` spelling in this template could NEVER match that gate — the
> builder emits the marker-compatible form above, and the greenfield design slice now
> clears `design_system_not_injected` where the old spelling would not have. Do not
> re-insert the parenthetical; it is the vault's `design_system` block either way.

**Anti-halu rails:**
- The palette/typography lines are the SOURCE for your tokens — never invent a second palette or pairing.
- Every view you write MUST satisfy the Non-negotiables (tokens, spacing scale, type scale, page shell, interactive states, loading/empty/error states, designed forms, a11y floor) and MUST NOT match an anti-kuno tell.
- The design-reviewer panel lens judges your output against THIS EXACT section — it is the contract, not a suggestion.

**Absence is valid:** absent for pure-backend units, or when the starterkit template governs the UI.

## Confidence labels per claim

<for each claim this unit implements (from binding.md):>
- [<HIGH | MEDIUM | LOW | OQ>] <claim text>
  └─ Source: <binding citation OR KB inference OR heuristic default>

<TAXONOMY — one enum, decided 2026-07-31, identical in both spec files. `OQ` was added
 here because the builder emits it for an `OQ-*` binding_ref and an open question carries
 no confidence; rendering it LOW would assert a low-confidence ANSWER where there is none.
 The LABEL is the EVIDENCE-QUALITY axis and reads the binding's `## Implementation State
 Map` Confidence cell first (high/medium/low → HIGH/MEDIUM/LOW), falling back to the
 source-keyed rule (binding → HIGH, KB inference → MEDIUM, heuristic → LOW) only when no
 cell was recorded. Rationale in `context-enrichment.md §TIER 2 — Confidence labels`:
 stamping HIGH on a binding row the binder explicitly marked `low` manufactures certainty
 the cited source contradicts, and the SOURCE axis is not lost — it is on the `└─` line.>

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

<Emitted only when a pack declares a machine-readable static-analysis command. No shipped
 pack does today — `## Testing conventions` is prose — so the builder leaves this slot EMPTY
 rather than guessing a tool/level per stack (that would be both fabrication and a hardcoded
 stack signature). Adding a structured pack field is the fix; inventing the command is not.>

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: <X> bytes (cap 12288)
consumed_t2: <Y> bytes (cap 10240, hard 12288)
total: <X+Y> bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: <N> bytes  # THIS WHOLE FILE. The difference from `total` is
                            # exactly four blocks plus the blank lines joining
                            # them: the TIER 2 banner, this tracker block, the
                            # TIER 3 pointer list and the PROVENANCE appendix.
                            # The title banner and the TIER 1 banner are NOT in
                            # that gap — they are already inside consumed_t1.
                            # None of the four is budgeted and none is ever
                            # truncated. Reason about truncation from the list
                            # below, not from either number.
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

`scripts/build-dispatch-prompt.sh` writes the assembled prompt to `<vault>/bolts/U-XXX/dispatch-prompt.md`. The file is **contractual, not merely provenance** — `validate-dispatch-prompt.sh` globs exactly that path and has no other input, so if it stopped being written the advisory gate would go dark. A script write fires no `Write|Edit` tool event, so `hooks/post-tool-use` carries a second, Bash-side dispatch of the same validator, keyed on the builder's own command — deterministic, per bolt, at parity with the pre-builder `Write` cadence. **The controller has no refresh step and must not be given one:** a rule that duplicates a hook rots, and `plugins/mega-sdd/CLAUDE.md`'s *gates > rules > hooks* runs one way only.
