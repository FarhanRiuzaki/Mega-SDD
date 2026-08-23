═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-002
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-002

UNIT: U-002 "Render the nasabah detail view"
SCOPE: S-01 (Nasabah) — framework: _universal.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-002
title: Render the nasabah detail view
task_type: create
scope: S-01
scope_name: Nasabah
module: nasabah
risk: medium
status: pending
starterkit_relevance: [ui_ux]
target_files:
  - path: resources/views/nasabah/show.blade.php
    operation: create
acceptance_test:
  - command: "run the nasabah detail feature test"
    _authored_by: same-pass
---

## Intent

Render the nasabah detail view with the npwp field.

## Hard rules

- DO NOT modify app/Models/Nasabah.php

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v@VER@)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-002
  vault_sha256: 38489d6d0e47a99cee5336a0433ef86863a35529b1d62a27bcae9f2df2fe8862
  claims: (none cited)
  anchors_consulted: (none)
  hard_rules_active:
    - DO NOT modify app/Models/Nasabah.php
```

## Acceptance-test provenance NOTE

> NOTE: This unit's `acceptance_test` has weak blind-spot coverage
> (_authored_by: same-pass). The test was authored by the same LLM pass that
> wrote the unit body — the test may inherit the same blind spots as the spec
> and fail to catch behavioral bugs your implementation introduces.
>
> If your implementation passes this test but feels under-validated:
>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`
>     explaining what you suspect the test might miss
>   - Propose 1-2 additional assertions you'd add to strengthen coverage
>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested

Reuse index: .mega-sdd/codebase/reuse-index.yaml — your PRIMARY reuse lookup
surface (Iron Rule 4): scan the FULL index with Read/Grep before writing any
new capability; reuse_candidates below is only a hint.

## Anti-context (negative space = freedom + protection)

DO NOT MODIFY:
  - app/Models/Nasabah.php  (source: U-002.md `## Hard rules`)
DO NOT WRITE:
  - Tables without `id` primary key (denormalized intermediate tables OK as composite PK)  (from _universal.md §Forbidden patterns)
  - Tables without `created_at` + `updated_at` timestamps (unless explicitly immutable like audit logs)  (from _universal.md §Forbidden patterns)
  - VARCHAR(255) used as default type for everything (use proper sized/typed columns)  (from _universal.md §Forbidden patterns)
  - Comma-delimited values in single columns (use junction tables)  (from _universal.md §Forbidden patterns)
  - Date/time stored as VARCHAR/INT (use proper TIMESTAMP/DATETIME types)  (from _universal.md §Forbidden patterns)
  - Foreign keys without explicit constraint (`ON DELETE`/`ON UPDATE` defined)  (from _universal.md §Forbidden patterns)
DO NOT COMMIT IF: any `acceptance_test` command in this unit fails; any `## Hard rules` line above is violated; a modified file is missing its provenance trailer

═══════════════════════════════════════════
TIER 2 — Conditional context (target ≤10KB total)
═══════════════════════════════════════════

### Starterkit context (relevant to this unit)

UI/UX: extends=layouts.app, notification=sweetalert2, idioms=[toast on success]
Design tokens: colors={primary:#2563EB, surface:#F8FAFC}; spacing=8px scale; fonts=[Inter]
Design system: minimalism/trust-blue (type Inter, a11y AA, source scanned-template) — render on this style; see injected style-principles + ux-rules. When source=scanned-template, the starterkit tokens above are authoritative.

### UI design quality heuristics

# UI design quality heuristics (stack-agnostic)

> **Purpose.** Injected as inline context into a `ui_ux`-relevance bolt dispatch prompt
> (execute-bolts Step 4.5.b-starterkit.inject). It is the `frontend-design` bridge as
> INJECTED TEXT — NOT a prose instruction to invoke the `frontend-design` skill (prose-only
> Skill-invoke wire-ups historically no-op'd; see `plugins/mega-sdd/CLAUDE.md` Fork A).
>
> **Stack-agnostic.** This file names NO framework, templating language, or CSS library. It
> describes WHAT a production-grade view must achieve; the concrete HOW (layout extend,
> component library, formatting helpers) comes from the injected starterkit slice (design
> tokens + view/component exemplar) alongside this text. Pair the two: the exemplar shows
> the project's idiom; these heuristics keep the bolt from shipping generic scaffold output.
>
> **Anti-hallucination.** Apply these to data and affordances that the unit + vault flows
> already establish. Never invent fields, statuses, copy, or brand voice not grounded in the
> unit spec / vault. If a required affordance has no source (e.g. no design system), that is
> an Open Question for generate-intent — not a value to make up here.

## 1. Visual hierarchy

- Lead with the user's primary task. The most important action or datum is the most prominent
  (size, weight, position, contrast) — not buried in a uniform grid of equal-weight rows.
- Group related fields; separate unrelated ones with whitespace, not just borders.
- One clear primary action per screen; secondary/destructive actions are visually demoted.
- Use the project's design tokens (injected colors/spacing/fonts) for emphasis — do not
  hardcode ad-hoc hex values or one-off spacing.

## 2. Show every state (not just the happy path)

A non-trivial view MUST handle, with intentional UI, each state the flow can produce:

- **Empty** — a list/collection with zero rows shows a purposeful empty state (what it is, how
  to add the first item), never a bare blank table.
- **Loading** — long-running fetches/actions show a spinner/skeleton/disabled affordance, never
  a frozen or silently-empty screen.
- **Error** — failures surface a human-readable message + a recovery path, via the project's
  notification idiom (the injected `notification` lib), never a raw stack trace, a silent
  no-op, or a native browser dialog.
- **Partial / pending** — workflow items mid-process (awaiting approval, in review) show their
  human-readable status, not a raw enum/integer.

## 3. Human-readable values

- **Labels** are human language, not column names. Relabel `customer_id` → "Customer",
  `created_at` → "Created", a `Str::title(column)`-style "Customer Id" is a tell.
- **Foreign keys** render the related entity's display field (its name/title), resolved via the
  relation — never the raw id/UUID.
- **Money / numbers** are formatted (thousands separator, currency, fixed decimals) — never a
  raw float.
- **Dates / timestamps** are formatted for humans (and null-safe — a missing timestamp shows a
  placeholder, not a crash or the literal "null").
- **Statuses / enums** map to human-readable labels (+ a color/badge from the design tokens
  where the design system defines one).

## 4. Accessibility (a11y)

- Every interactive control is reachable and operable by keyboard; focus order is logical.
- Form inputs have associated labels; icon-only buttons have an accessible name.
- Color is never the SOLE carrier of meaning (pair it with text/icon).
- Sufficient text/background contrast (follow the design system; if undefined, that is an OQ —
  do not guess a WCAG value).
- Images/icons that convey meaning have alt text; decorative ones are marked decorative.

## 5. Consistency

- Reuse the project's layout, components, spacing scale, and notification idiom (from the
  injected exemplar + tokens) — do not introduce a parallel bespoke style.
- Sibling screens (index/detail/create/edit of the same or analogous entities) share structure,
  label wording, and action placement. A user who learned one should recognize the next.
- Match the established responsive behavior (the exemplar's breakpoint idiom) so the view works
  on the project's target viewports, not only desktop.

## 6. Pre-ship self-check (the bolt should be able to answer "yes" to each)

1. Is the primary task obvious within a glance (hierarchy)?
2. Are empty / loading / error / pending states all handled intentionally?
3. Are all labels humanized, all FKs resolved to display fields, all money/dates/statuses
   formatted and null-safe?
4. Is it keyboard-operable, labeled, and not color-only?
5. Does it reuse the project's layout/components/tokens and match its responsive idiom?
6. Is every datum/affordance grounded in the unit spec + vault flows (nothing invented)?

## Validation hints (specific, not vague)

After implementation, run:
```bash
run the nasabah detail feature test
```

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: @N@ bytes (cap 12288)
consumed_t2: 5427 bytes (cap 10240, hard 12288)
total: 9254 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: @N@    bytes  # THIS WHOLE FILE. The difference from `total` is
                            # exactly four blocks plus the blank lines joining
                            # them: the TIER 2 banner, this tracker block, the
                            # TIER 3 pointer list and the PROVENANCE appendix.
                            # The title banner and the TIER 1 banner are NOT in
                            # that gap — they are already inside consumed_t1.
                            # None of the four is budgeted and none is ever
                            # truncated. Reason about truncation from the list
                            # below, not from either number.
truncations_applied:
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

- Full upstream bolt-reports: `@PROJ@/.mega-sdd/vaults/v1/bolts/U-XXX/bolt-report.md`
- Full constitution: `@PROJ@/.mega-sdd/vaults/v1/constitution.md`
- Full KB domain files: `.mega-sdd/knowledge-base/10-domains/`
- Full framework pack: `@PLUGIN@/references/framework-conventions/<pack>.md`

═══════════════════════════════════════════
PROVENANCE — omissions (audit trail; NOT part of the T1/T2 byte accounting)
═══════════════════════════════════════════

Every absent or unresolvable input is recorded here rather than invented (invariant #5).

- t1.anti_context.do_not_modify.data_mutation_policy: no <kb>/99-rebuild-architecture/data-mutation-policy.md under @PROJ@ (searched .mega-sdd/, docs/, old-reference/ knowledge-base roots) — this source contributes nothing; the unit `## Hard rules` half is NOT relabelled to stand in for it
- depends_on_summaries: unit has no depends_on entries
- framework_pack_rules: no pack rule path_glob matched this unit's target_files (chain: _universal.md) — the 'keep top 1' floor is vacuous on an empty set, no rule invented
- constitution_clauses: no constitution.md in @PROJ@/.mega-sdd/vaults/v1 (absence IS the --no-constitution opt-out)
- kb_anti_patterns: the join key 'domain tags' (context-enrichment.md:76) is a phantom field — no unit schema, validator or writer defines it; substituting module:/vault_source would be a fabricated inclusion. Section omitted until the spec designates a join key.
- historical_memory: the memory lane was removed in v7.3.0 (pipeline-only mandate) — no historical-memory section exists to emit
- reuse_slice: reuse-index.yaml absent at @PROJ@/.mega-sdd/codebase/reuse-index.yaml (the UNCONDITIONAL T1 path line still ships)
- symbol_slice: symbol-index.json absent at @PROJ@/.mega-sdd/codebase/symbol-index.json (run scripts/build-symbol-index.sh; exit 3 there = ast-grep not installed)
- design_slice: starterkit ui_ux slice already built — template is AUTHORITATIVE
- confidence_labels: unit has no binding_refs (greenfield / standalone generate-units)
