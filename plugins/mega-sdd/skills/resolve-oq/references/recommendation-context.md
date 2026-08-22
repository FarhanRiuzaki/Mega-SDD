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

Mirror the recommend-mode discipline:

1. **Citation MANDATORY.** Every recommendation cites source (file:line OR memory entry OR KB section OR vault ADR). No citation → NO recommendation surfaced (silent fallback to no-recommendation interactive walk).
2. **Rationale MANDATORY.** Why this pick. 1-3 sentences. Visible in `AskUserQuestion` description.
3. **Fallback-if-wrong MANDATORY.** What to revisit if this turns out incorrect. 1 sentence.
4. **User confirms ALWAYS.** Recommendation is `(recommended)` label on default option; user can pick "Other" or override freely.
5. **No fabrication.** If context sources don't yield a confident recommendation → omit recommendation; fall back to v0.5 behavior (memory-only or no pre-fill).
6. **High-stakes warning.** Business-OQ recommendations carry a "review carefully — high-stakes domain" prefix in description (regulatory / finance / edge case markers).
7. **Override capture.** When user picks a different option than `(recommended)`, log to memory as "recommendation overridden" — feeds future learning (memory patterns).

## Context sources (priority order)

When building a recommendation for an OQ, consult these sources in order. First confident source wins; multiple sources strengthen confidence:

### 1. KB `[VERIFIED]` markers (strongest)

If a knowledge-base exists at (priority order, first hit wins) `.mega-sdd/knowledge-base/` (canonical), `docs/knowledge-base/` (legacy), or `old-reference/knowledge-base/`:

- Match OQ tag/text against KB domain files
- E.g., `OQ-AR-7` (architecture, error envelope) → look in `10-domains/*` for error-related entries
- `OQ-FL-3` (flows, payment) → look in `10-domains/20-import-lc-payment.md` or similar
- Extract `[VERIFIED]` items that directly answer the OQ
- **Mutability tier**: if KB claim carries mutability marker, surface it in recommendation (`[VERIFIED][LOCKED]` → flag user "this is a LOCKED rule, rebuild MUST preserve 1:1"; `[VERIFIED][ARTIFACT]` → flag "this is discardable, do you want to discard?")
- Citation: `<kb-path>/10-domains/<file>.md §<section>:<line>` (use detected KB path)
- Confidence: HIGH

### 2. Memory — project-scope decisions (strong)

`<project>/.mega-sdd/memory/decisions.md` (canonical):

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

- ADRs in `vault.md ## Decisions` (legacy `05-decisions.md`) that relate to the OQ's domain
- Flows in `flows.md` that touch the same area
- Constraints in `constraints.md` that may dictate the answer
- Citation: `.mega-sdd/vaults/<slug>/vault.md §D-XXX` (legacy: `05-decisions.md §D-XXX`) (canonical)
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

## Citation probe step

BEFORE surfacing the recommendation in `AskUserQuestion`, probe each citation in `Recommendation.citation` for resolution. This prevents LLM-fabricated citations from surfacing (mirrors the bind-codebase `oq_recommend_citation_invalid` halt for tech-OQ recommend mode).

### Probe logic

For each citation in the recommendation:

| Citation source | Probe |
|---|---|
| KB section (`<kb-path>/<file>.md §<section>:<line>`) | `Bash test -f <file>` + `Bash grep -n "<section>" <file>` to verify section exists |
| Memory entry (`.mega-sdd/memory/<file>.md row N` canonical; legacy `.mega-sdd-memory/` honored) | `Read <file>` + count rows in target table; verify N within range |
| User patterns (`~/.mega-sdd/memory/patterns.md §<section>`) | `Read patterns.md` + grep for section header |
| Vault ADR (`.mega-sdd/vaults/<slug>/vault.md §D-XXX` canonical; legacy `05-decisions.md`) | `Read` the decisions doc + grep for D-XXX heading |
| Codebase-map line (`.mega-sdd/codebase/codebase-map.md §N + <file>:<line>`) | `Read codebase-map.md` + verify referenced file path exists |

### Outcomes

- **All citations resolve** → ✅ surface recommendation in AskUserQuestion
- **Any citation unresolved** → silently DOWNGRADE: omit recommendation; fall back to plain interactive walk
- **Optional**: log silently-omitted recommendations to `<vault>/.memory/citation-failures.jsonl` for audit (helps detect LLM fabrication patterns over time)

### Why silent downgrade (not halt)

- Recommendation surface is opt-in UX enhancement; failing silently keeps the OQ resolution flow moving
- Halt would block on cosmetic issue (citation typo); over-aggressive
- Citation failure logged in vault memory for future review

## AskUserQuestion presentation

> **`interactive-walk.md` Step 2b is CANONICAL for this prompt's shape** — the verbatim template,
> the slot table, the option cap, the "Other" parse order, the Esc semantics, and the per-action
> derive mapping live there and are **deliberately not restated here**, so the shape has exactly one
> normative home. This section owns only what the recommendation CONTRIBUTES to that prompt. If this
> section and Step 2b ever disagree, Step 2b wins.

**ONE prompt per OQ.** The recommendation does not get its own round trip: it rides the same single
`AskUserQuestion` that also captures a free-text answer, Skip, Defer, and Out of scope.

### What the recommendation contributes

1. **The recommended answer takes the first option slot**, labelled `<answer>  (recommended)`.
   Exactly one option is ever marked recommended, and only when the citation probe passed.
2. **Its `description` must carry, in this order:** the high-stakes prefix when (and only when)
   `category: business` AND `P1`; the rationale (1–3 sentences); `Sumber: <probed citation>`;
   `Kalau salah: <fallback-if-wrong>`; `Confidence: HIGH|MEDIUM`; and the destination disclosure
   (`→ mendarat …` — target doc, inline vs promoted, cross-refs when cross-cutting). The exact
   template lives in Step 2b.
3. **The considered alternatives do NOT take a slot** — Skip and end-the-walk need the platform's
   four slots more than a pre-typed alternative does, and "Other" already covers *answer in my own
   words*. The alternatives are surfaced as prose in the question text, on the line the Step 2b
   template labels `Alternatif yang sudah dipertimbangkan:` (`… {alt-1} — kalau …`),
   and this section's rule on how to write them is unchanged: MANDATORY explanation of what the
   alternative means and when you would pick it over the recommendation; if it has a source, cite
   it, otherwise say `tanpa sumber — alternatif umum`. **NEVER left blank/"…" and NEVER given a
   fabricated citation, and NEVER invented to fill the line** — no grounded alternative means the
   line is omitted, not padded.
4. **When there is no recommendation at all** (no signal, or the probe failed) the slot is simply
   not spent — see Step 2b §"When there is NO recommendation". Never surface an unsourced guess.

Default cursor sits on the recommended option. Skip, Defer, Out of scope, the "Other" answer
channel, and Esc are all owned by Step 2b.

## Audit trail

On user selection:

- **Picked `(recommended)`** — including a bare `→ <file>.md` destination override, which per Step 2b
  composes with (i.e. accepts) the recommendation → record in vault + memory:
  - vault.json OQ entry: `resolution: <answer>`, `resolution_source: recommendation`, `recommendation_citation: <citation>`
  - memory `decisions.md`: append row with `source: ai_recommended` flag

- **Answered via "Other" WHILE a `(recommended)` option was on the prompt (OVERRIDE)** — since the
  alternatives no longer own a slot, an override arrives as free text (often one of the alternatives
  listed in the question text, typed back). The branch is keyed on *a recommendation existing and
  being declined*, not on the channel: "Other" is also the ONLY answer channel on the
  no-recommendation shape, so keying it on the channel alone would book every unsourced-OQ answer as
  an override of a recommendation that never existed. → record:
  - vault.json OQ entry: `resolution: <user-typed-answer>`, `resolution_source: user_override`
  - memory `decisions.md`: append row with `source: user_override`, `recommendation_ignored: <recommended-answer>`, `override_reason: <if-provided>`
  - User-scope `patterns.md`: increment "recommendation override" counter for this OQ type

- **Answered via "Other" when NO recommendation was surfaced** (the no-recommendation shape — no
  signal, or the citation probe failed and it downgraded silently; "Other" is the only answer
  channel there) → this is a direct answer, **not** an override:
  - vault.json OQ entry: `resolution: <user-typed-answer>`, `resolution_source: user_direct`
    — the third and last value of `resolution_source`, declared here alongside `recommendation` and
    `user_override`, and existing precisely because this shape has no recommended option to accept
    or decline. No `recommendation_ignored` field (there is no recommended answer to name).
  - memory `decisions.md`: append row with `source: user_direct`
  - **No override counter increment** anywhere. Counting these would make the self-correction loop
    below fire on OQs the recommender never even attempted — it would disable recommendations for a
    pattern on the evidence that no recommendation was ever built for it.

- **Picked Skip** → nothing recorded anywhere: no vault edit, no derive run, no memory row. A skip is
  not an override and must never increment the override counter.

- **Picked Defer/Out-of-scope** → record:
  - vault.json: mark `status: deferred` or `status: out-of-scope`
  - memory: no decision row (nothing was resolved)

## Memory feedback loop

Override patterns are tracked. If user overrides the recommendation ≥5 times for the same OQ pattern:

- Self-learning fires a suggestion: "Mega-SDD's recommendation for OQ pattern X is wrong 5/5 times. Disable recommendation for this pattern? [ACCEPT/REJECT]"
- ACCEPT → future OQs matching this pattern get no recommendation; fall back to plain interactive walk

This self-corrects bad recommendations over time.

## High-stakes domain warning

For OQs tagged with `category: business` + priority `P1`, the AskUserQuestion description prefixes:

> ⚠️ **High-stakes business OQ.** Review citation + rationale carefully before accepting. AI recommendation is a starting point, not authority.

This visual marker discourages lazy ACCEPT for regulatory / finance / compliance OQs.

**The collapse does not move it — it carries it in BOTH positions.** With three prompts merged into
one, the marker rides (a) the recommended option's `description` prefix, exactly as above, AND
(b) the panel banner above the question text (`interactive-walk.md` Step 2b). Losing either
position is a regression: the banner is what the user sees before reading options, the description
prefix is what sits next to the answer they are about to accept.

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

### Example 3 — No confident recommendation (silent fallback) — STILL one round trip

The recommendation slot is simply not spent. The answer rides "Other". The walk does NOT gain a
prompt because the recommendation is missing — the shape is owned by `interactive-walk.md` Step 2b
§"When there is NO recommendation" and is not reproduced here.

```
OQ-CN-12 [P3] [business / blocking]: What is the SLA for OFAC sanction screening response?
  Sumber: (tidak ada — tidak ada sinyal KB / memory / vault / codebase yang bisa dikutip)
```

No fabricated recommendation, no unsourced guess dressed as one, and no empty slot padded with an
invented answer. Better silent than wrong — and still ONE stop.

## References

- `execute-bolts/references/hard-rule-grammar-v2.md` — recommend mode (which this skill's recommendation context extends)
- `memory/references/memory-schema.md` — memory sources consulted
- `memory/references/learning-rules.md` — override-tracking + self-correction loop
- Memory-layer spec — recommendation source #2-3
- `resolution_mode: recommend` original pattern (recommendation source #1, KB-derived)
