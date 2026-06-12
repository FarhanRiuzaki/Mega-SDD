# Adversarial Acceptance-Test Review Prompt

> Prompt template for `generate-units` Step 9.5 — adversarial review of acceptance_test authored in Step 9. Closes audit Pattern F structural risk (D4-006): "Never trust AI to both generate and validate" (ACM FSE 2025).

**Consumed by:** `generate-units/SKILL.md` Step 9.5
**Output target:** updates `acceptance_test` in unit frontmatter with merged gap assertions + sets `_authored_by:` provenance field

## Contents
- Default mode (main-thread self-re-prompt)
- Opt-in subagent mode (`--adversarial-subagent`)
- Gap merge logic (Step 9.5 post-review)
- `_authored_by:` provenance values
- Anti-halu rails

---

## Default mode (main-thread self-re-prompt)

The main thread, after authoring the unit body + acceptance_test in Step 9, re-prompts itself with the following framing BEFORE writing the unit file. No subagent dispatch needed.

```
ROLE: QA engineer reviewing an acceptance_test for completeness.

UNIT (verbatim from Step 9):
<paste the just-generated unit body>

CURRENT acceptance_test (verbatim):
<paste the just-generated acceptance_test block>

YOUR JOB:
Find AT LEAST 2 cases where this acceptance_test would FAIL to catch a real
bug in the implementation. For each case:

- Describe the bug scenario (e.g., "what if user_id is null but the request
  still returns HTTP 200?")
- Identify which existing test assertion would miss it (e.g., "test only
  checks HTTP status code; never inspects response body shape")
- Propose the additional test assertion that would catch it (test code OR
  natural-language assertion the bolt subagent can translate)

Be ADVERSARIAL: assume the original test author had blind spots. The goal is
to find what they missed, NOT to validate what they wrote. If the test looks
"obviously fine" to you, look harder — that's a sign you're inheriting the
same blind spots.

CONSTRAINTS:
- Do NOT rewrite the entire acceptance_test. Only identify gaps and propose
  targeted additions.
- Do NOT propose gaps that are out-of-scope for this unit (e.g., suggesting
  load tests when the unit is about CRUD correctness). Per-unit scope matters.
- If the unit body is genuinely tight and the test covers it well, return
  `coverage_verdict: strong` + empty `gaps_identified`. Honest "no gaps
  found" is better than fabricated gaps.

OUTPUT FORMAT (strict YAML):
```yaml
adversarial_review:
  reviewer_pass: 2                          # always 2 (after Step 9 = pass 1)
  gaps_identified:
    - scenario: "<bug case description>"
      missed_by_assertion: "<which existing assertion fails to catch it>"
      proposed_additional_assertion: "<test code or natural language>"
    # repeat per gap; aim for AT LEAST 2 unless coverage_verdict is strong
  coverage_verdict: weak | adequate | strong
```
```

## Opt-in subagent mode (`--adversarial-subagent` flag)

When user passes `--adversarial-subagent` to `/mega-sdd:generate-units`, OR when unit frontmatter declares `risk: high`, dispatch a SEPARATE subagent for the adversarial review. Separate LLM context = stronger blind-spot coverage at the cost of one extra dispatch per high-risk unit.

Subagent dispatch contract:
- Model: sonnet (default; opus for `risk: critical` units)
- Tool surface: Read, Grep (read-only)
- Wall-clock budget: ≤3 min per unit
- Output format: same YAML structure as default mode

Subagent is dispatched per-unit; main thread iterates units sequentially when `--adversarial-subagent` is set (no parallel — keeps simplifikasi).

## Gap merge logic (generate-units Step 9.5 post-review)

Main thread (NOT the adversarial reviewer) handles merge:

1. If `coverage_verdict: strong` AND `gaps_identified: []` → keep original acceptance_test as-is; set `_authored_by: adversarial-reviewed (no gaps)`
2. If `gaps_identified: [...]` non-empty → for each gap, append `proposed_additional_assertion` to acceptance_test as new test case. Set `_authored_by: adversarial-reviewed (+N gaps merged)` where N = count
3. If `coverage_verdict: weak` AND `gaps_identified: []` (incoherent) → keep original acceptance_test; set `_authored_by: adversarial-review-failed (kept original; manual review recommended)`. Log warning to chat.

## `_authored_by:` provenance values (canonical)

| Value | Origin | Trust signal |
|---|---|---|
| `same-pass` | legacy unit (field absent) OR `--no-adversarial-review` flag set | weakest |
| `adversarial-reviewed` | default; gaps merged or no-gap finding | recommended baseline |
| `adversarial-reviewed (no gaps)` | adversarial pass found nothing to add | strong |
| `adversarial-reviewed (+N gaps merged)` | N gaps merged into test | strong |
| `adversarial-review-failed` | adversarial pass returned incoherent output | weak + warning |
| `independent-llm` | `--adversarial-subagent` flag, separate subagent extended test | strongest LLM |
| `human` | user manually edited acceptance_test post-generation | strongest overall |

Legacy units (no field present) → treat as `same-pass` for execute-bolts surface logic.

## Anti-halu rails

- Adversarial reviewer MUST NOT modify the unit body — only proposes test additions
- Adversarial reviewer MUST output strict YAML matching the schema above; parse failures → fallback to `same-pass` provenance + log warning
- `--no-adversarial-review` flag preserved for users who explicitly want the same-pass behavior (debug / regression testing)
- Legacy units re-encountered by `generate-units --regenerate` get the adversarial review pass on rewrite; user-marked `_authored_by: human` units are preserved untouched
