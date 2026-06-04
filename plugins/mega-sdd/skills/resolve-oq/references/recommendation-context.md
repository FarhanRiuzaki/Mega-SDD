# resolve-oq — context-aware recommendations

## Contents
- Anti-halu invariants (NON-NEGOTIABLE)
- Context sources (priority order: KB → memory → vault → codebase-map → fallback)
- Recommendation generation algorithm
- Citation probe step
- AskUserQuestion presentation
- Audit trail
- Memory feedback loop (override self-correction)
- High-stakes domain warning
- Examples

`resolve-oq` builds context-aware `(recommended)` answers per OQ before presenting `AskUserQuestion`. Extends the `resolution_mode: recommend` pattern from tech-OQs (at generate-intent time) to ALL OQ types (at resolve-oq time).

Inspired by a user UX request — "kasih (recommended) base on dia baca context, dan kasih suggest yg paling sesuai".

## Anti-halu invariants (NON-NEGOTIABLE)

Mirror Iter 2 recommend mode discipline:

1. **Citation MANDATORY.** Every recommendation cites source (file:line OR memory entry OR KB section OR vault ADR). No citation → NO recommendation surfaced (silent fallback to no-recommendation interactive walk).
2. **Rationale MANDATORY.** Why this pick. 1-3 sentences. Visible in `AskUserQuestion` description.
3. **Fallback-if-wrong MANDATORY.** What to revisit if this turns out incorrect. 1 sentence.
4. **User confirms ALWAYS.** Recommendation is `(recommended)` label on default option; user can pick "Other" or override freely.
5. **No fabrication.** If context sources don't yield a confident recommendation → omit recommendation; fall back to v0.5 behavior (memory-only or no pre-fill).
6. **High-stakes warning.** Business-OQ recommendations carry a "review carefully — high-stakes domain" prefix in description (regulatory / finance / edge case markers).
7. **Override capture.** When user picks a different option than `(recommended)`, log to memory as "recommendation overridden" — feeds future learning (Iter 5 patterns).

## Context sources (priority order)

When building a recommendation for an OQ, consult these sources in order. First confident source wins; multiple sources strengthen confidence:

### 1. KB `[VERIFIED]` markers (strongest)

If a knowledge-base exists at (priority order, first hit wins) `.mega-sdd/knowledge-base/` (v3.4+ canonical), `docs/knowledge-base/` (legacy), or `old-reference/knowledge-base/`:

- Match OQ tag/text against KB domain files
- E.g., `OQ-AR-7` (architecture, error envelope) → look in `10-domains/*` for error-related entries
- `OQ-FL-3` (flows, payment) → look in `10-domains/20-import-lc-payment.md` or similar
- Extract `[VERIFIED]` items that directly answer the OQ
- **v1.4+ Iter 22 mutability tier**: if KB claim carries mutability marker, surface it in recommendation (`[VERIFIED][LOCKED]` → flag user "this is a LOCKED rule, rebuild MUST preserve 1:1"; `[VERIFIED][ARTIFACT]` → flag "this is discardable, do you want to discard?")
- Citation: `<kb-path>/10-domains/<file>.md §<section>:<line>` (use detected KB path)
- Confidence: HIGH

### 2. Memory — project-scope decisions (strong)

`<project>/.mega-sdd/memory/decisions.md` (v3.4+ canonical per paths.md; legacy `<project>/.mega-sdd-memory/decisions.md` honored for read-side back-compat):

- Search past CONFLICT resolutions / OQ resolutions / Recommendation outcomes for similar patterns
- E.g., OQ about auth → check past auth-related decisions
- Threshold: ≥3 consistent past observations OR confidence ≥0.80
- Citation: `.mega-sdd/memory/decisions.md row <N>`
- Confidence: HIGH (≥5 obs) or MEDIUM (3-4 obs)

### 3. Memory — user-scope patterns (strong cross-project)

`~/.mega-sdd/memory/patterns.md`:

- Cross-project patterns observed by user across projects
- Threshold: ≥3 projects show same pattern OR confidence ≥0.80
- Citation: `~/.mega-sdd/memory/patterns.md §<section>`
- Confidence: HIGH

### 4. Vault — related ADRs + flows + constraints (medium)

Current vault context:

- ADRs in `05-decisions.md` that relate to the OQ's domain
- Flows in `04-flows.md` that touch the same area
- Constraints in `06-constraints.md` that may dictate the answer
- Citation: `.mega-sdd/vaults/<slug>/05-decisions.md §D-XXX` (v3.4+ canonical; legacy `docs/mega-sdd/vaults/<slug>/05-decisions.md` honored for back-compat)
- Confidence: MEDIUM (vault is locked spec; recommendation extrapolates from related decisions)

### 5. Codebase-map (medium, brownfield only)

If `codebase-map.md` present:

- Existing code patterns relevant to OQ
- E.g., OQ about error format → existing `app/Http/Resources/ErrorResource.php` pattern
- Citation: `codebase-map.md §<N> + <file>:<line>`
- Confidence: MEDIUM (existing pattern is observed reality; may or may not be desired going forward)

### 6. No-context fallback (no recommendation)

If NONE of sources 1-5 yield a confident answer → DO NOT recommend. Fall back to v0.5 interactive walk without `(recommended)` label.

**Critical**: silent fallback is better than fabricated recommendation. NEVER invent a recommendation from "industry best practice" or LLM prior knowledge without citation.

## Recommendation generation algorithm

```
function build_recommendation(oq):
  context = collect_context(oq):
    - kb_match     = search_kb(oq) [strongest]
    - mem_project  = search_project_memory(oq)
    - mem_user     = search_user_memory(oq)
    - vault_related = search_vault(oq)
    - codebase_match = search_codebase_map(oq)

  if kb_match.confidence == HIGH:
    return Recommendation(
      answer: kb_match.verified_value,
      rationale: kb_match.kb_section_explanation,
      citation: kb_match.file_section,
      confidence: HIGH,
      sources: [kb_match]
    )

  if mem_project.confidence >= HIGH or mem_user.confidence >= HIGH:
    return Recommendation(
      answer: most_consistent_past_resolution,
      rationale: f"Past pattern: {N}/{M} times resolved as X across this project",
      citation: memory_row_citation,
      confidence: HIGH,
      sources: [memory]
    )

  if vault_related or codebase_match:
    return Recommendation(
      answer: extrapolated_answer,
      rationale: f"Extrapolated from related decision D-XXX / existing pattern",
      citation: vault_or_codebase_citation,
      confidence: MEDIUM,
      sources: [vault, codebase]
    )

  return None  # silent fallback; no recommendation surfaced
```

## Citation probe step (v0.7+, Iter 9 Bug 2 fix)

BEFORE surfacing the recommendation in `AskUserQuestion`, probe each citation in `Recommendation.citation` for resolution. This prevents LLM-fabricated citations from surfacing (mirrors Iter 2 bind-codebase `oq_recommend_citation_invalid` halt for tech-OQ recommend mode).

### Probe logic

For each citation in the recommendation:

| Citation source | Probe |
|---|---|
| KB section (`<kb-path>/<file>.md §<section>:<line>`) | `Bash test -f <file>` + `Bash grep -n "<section>" <file>` to verify section exists |
| Memory entry (`.mega-sdd/memory/<file>.md row N` v3.4+ canonical; legacy `.mega-sdd-memory/` honored) | `Read <file>` + count rows in target table; verify N within range |
| User patterns (`~/.mega-sdd/memory/patterns.md §<section>`) | `Read patterns.md` + grep for section header |
| Vault ADR (`.mega-sdd/vaults/<slug>/05-decisions.md §D-XXX` v3.4+ canonical) | `Read 05-decisions.md` + grep for D-XXX heading |
| Codebase-map line (`.mega-sdd/codebase/codebase-map.md §N + <file>:<line>` v3.4+) | `Read codebase-map.md` + verify referenced file path exists |

### Outcomes

- **All citations resolve** → ✅ surface recommendation in AskUserQuestion
- **Any citation unresolved** → silently DOWNGRADE: omit recommendation; fall back to plain interactive walk
- **Optional**: log silently-omitted recommendations to `<vault>/.memory/citation-failures.jsonl` for audit (helps detect LLM fabrication patterns over time)

### Why silent downgrade (not halt)

- Recommendation surface is opt-in UX enhancement; failing silently keeps the OQ resolution flow moving
- Halt would block on cosmetic issue (citation typo); over-aggressive
- Citation failure logged in vault memory for future review

## AskUserQuestion presentation

When a recommendation is built (AND all citations probed successfully), the `AskUserQuestion` for the OQ uses this format:

```
Question: <OQ text>

Options:
  1. <recommended answer text> (recommended)
     description: <rationale>. Source: <citation>. Fallback-if-wrong: <fallback>. Confidence: <HIGH|MEDIUM>.

  2. <alternative answer 1>
     description: ...

  3. <alternative answer 2>
     description: ...

  4. Defer (mark as deferred for later)
     description: Skip this OQ for now; revisit in next session.

  5. Out of scope
     description: This OQ is not in scope for current milestone.
```

User selects via interactive menu. Default cursor on option 1 (`recommended`).

## Audit trail

On user selection:

- **Picked `(recommended)`** → record in vault + memory:
  - vault.json OQ entry: `resolution: <answer>`, `resolution_source: recommendation`, `recommendation_citation: <citation>`
  - memory `decisions.md`: append row with `source: ai_recommended` flag

- **Picked alternative (OVERRIDE)** → record:
  - vault.json OQ entry: `resolution: <user-chosen-answer>`, `resolution_source: user_override`
  - memory `decisions.md`: append row with `source: user_override`, `recommendation_ignored: <recommended-answer>`, `override_reason: <if-provided>`
  - User-scope `patterns.md`: increment "recommendation override" counter for this OQ type

- **Picked Defer/Out-of-scope** → record:
  - vault.json: mark `status: deferred` or `status: out-of-scope`
  - memory: no decision row (nothing was resolved)

## Memory feedback loop (Iter 5 integration)

Override patterns are tracked. If user overrides the recommendation ≥5 times for the same OQ pattern:

- Iter 5 self-learning fires a suggestion: "Mega-SDD's recommendation for OQ pattern X is wrong 5/5 times. Disable recommendation for this pattern? [ACCEPT/REJECT]"
- ACCEPT → future OQs matching this pattern get no recommendation; fall back to plain interactive walk

This self-corrects bad recommendations over time.

## High-stakes domain warning

For OQs tagged with `category: business` + priority `P1`, the AskUserQuestion description prefixes:

> ⚠️ **High-stakes business OQ.** Review citation + rationale carefully before accepting. AI recommendation is a starting point, not authority.

This visual marker discourages lazy ACCEPT for regulatory / finance / compliance OQs.

## Examples

### Example 1 — KB-derived recommendation

```
OQ-AR-7 [P2] [tech / recommend]: What HTTP error envelope shape?

Recommendation: Use RFC 7807 problem+json envelope (recommended)
  Rationale: KB domain file 10-domains/50-parameter-reference.md §3 marks
    error envelope as [VERIFIED] following RFC 7807 in 3 prior runs.
  Source: .mega-sdd/knowledge-base/10-domains/50-parameter-reference.md §3:12
  Fallback-if-wrong: If RFC 7807 doesn't fit client expectations, revisit
    and consider JSON:API error format.
  Confidence: HIGH
```

### Example 2 — Memory-derived recommendation

```
OQ-FL-3 [P1] [business / blocking]: Does cancellation flow refund prior payments?

⚠️ High-stakes business OQ. Review citation + rationale carefully.

Recommendation: Yes — refund prior payments via auto-reversal job (recommended)
  Rationale: Past pattern: 4/5 cancellation OQs resolved as auto-refund in
    this project + 2/2 cross-project (memory.patterns.md row 12).
  Source: .mega-sdd/memory/decisions.md rows 23, 31, 38, 45 +
    ~/.mega-sdd/memory/patterns.md §cancellation-refund-patterns
  Fallback-if-wrong: If finance/compliance team objects, revisit; alternative
    is manual reconciliation via /reconcile-payments endpoint.
  Confidence: HIGH
```

### Example 3 — No confident recommendation (silent fallback)

```
OQ-CN-12 [P3] [business / blocking]: What is the SLA for OFAC sanction screening response?

(No recommendation surfaced — no KB / memory / vault / codebase signal sufficient.)

Options:
  1. <user enters answer>
  2. Defer
  3. Out of scope
```

User does normal interactive walk; no fabricated recommendation. Better silent than wrong.

## References

- `../../execute-bolts/references/hard-rule-grammar-v2.md` — Iter 2 recommend mode (which this skill's Iter 7 enhancement extends)
- `../../memory/references/memory-schema.md` — memory sources consulted
- `../../memory/references/learning-rules.md` — override-tracking + self-correction loop
- Iter 5 spec — memory layer (recommendation source #2-3)
- Iter 2 spec — `resolution_mode: recommend` original pattern (recommendation source #1, KB-derived)
