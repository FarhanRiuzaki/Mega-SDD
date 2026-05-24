# Iter 47 — Independent Acceptance-Test Authoring Design

**Status:** Approved (autonomous execution)
**Source:** Iter 38 audit Queue #7 (D4-006; pattern F)
**Plugin:** v3.31.0 → v3.32.0 (MINOR — new generate-units Step + new acceptance_test provenance field)
**Estimated effort:** ~2-3hr (markdown-driven; less than 6hr audit estimate)

---

## §1 — Problem

Audit D4-006 (**HIGH** severity, pattern F structural risk): `acceptance_test` for each unit is authored by the SAME LLM pass that generated the unit body. Both inherit the same blind spots:

- If the LLM misunderstands the requirement, both the unit body AND its acceptance_test will be wrong in the same direction
- Bolt subagent runs the test → test passes → user trusts the green checkmark → ships broken code
- Hard Rules + provenance trailer catch STRUCTURAL bugs (file modified outside whitelist, missing trailer); they cannot catch BEHAVIORAL bugs that the test was authored to NOT detect

External research (audit-cited):
- [PBT for LLM-Generated Code (ACM FSE 2025)](https://dl.acm.org/doi/10.1145/3696630.3728702) — "Never trust AI to both generate and validate"
- [Multicalibration for LLM Code Generation](https://www.researchgate.net/publication/398513108_Multicalibration_for_LLM-based_Code_Generation)
- [Stanford AI Index 2026 — Hallucination Engineering](https://explore.n1n.ai/blog/stanford-ai-index-2026-hallucination-engineering-2026-04-21)

---

## §2 — Design

### Change 1: Adversarial test review pass (new Step 9.5 in generate-units)

After Step 9 fills acceptance_test inline with the unit body, dispatch a SECOND pass with adversarial framing. Two implementation options:

**Option A (DEFAULT — fewer subagent dispatches):** main thread re-prompts itself in adversarial mode after Step 9 completes. Same LLM, different prompt framing.

**Option B (OPT-IN via `--adversarial-subagent` flag):** dispatch a separate subagent with adversarial role. Independent LLM context = stronger blind-spot coverage.

Option A is default (per simplifikasi — minimum dispatch overhead). Option B for high-risk units (mark via unit frontmatter `risk: high`).

**Adversarial framing prompt template (new `references/adversarial-test-prompt.md`):**

```
ROLE: QA engineer reviewing an acceptance_test for completeness.

UNIT: <unit body>

CURRENT acceptance_test:
<acceptance_test from Step 9>

YOUR JOB:
Find AT LEAST 2 cases where the acceptance_test would FAIL to catch a real
bug in the implementation. For each case:
- Describe the bug scenario (e.g., "what if user_id is null but request still
  succeeds?")
- Identify which existing test assertion would miss it (e.g., "test only checks
  HTTP 200; doesn't verify response body shape")
- Propose the additional test assertion that would catch it

Be ADVERSARIAL: assume the original test author had blind spots. The goal is
to find what they missed, not to validate what they wrote.

OUTPUT FORMAT:
```yaml
adversarial_review:
  gaps_identified:
    - scenario: "<bug case description>"
      missed_by_assertion: "<which existing assertion fails to catch it>"
      proposed_additional_assertion: "<test code or natural language>"
  coverage_verdict: weak | adequate | strong
```

OUT OF SCOPE: do NOT rewrite the entire acceptance_test. Only identify gaps
and propose targeted additions.
```

### Change 2: Merge gaps into expanded acceptance_test

After adversarial pass returns review:
1. If `coverage_verdict: strong` AND `gaps_identified` is empty → keep original acceptance_test as-is; mark `_authored_by: adversarial-reviewed (no gaps)`
2. If `gaps_identified` non-empty → merge each `proposed_additional_assertion` into acceptance_test as additional test cases. Mark `_authored_by: adversarial-reviewed (+N gaps merged)`
3. If `coverage_verdict: weak` AND 0 gaps proposed (incoherent) → mark `_authored_by: adversarial-review-failed (kept original; manual review recommended)`. Log warning.

### Change 3: `_authored_by:` provenance field

New OPTIONAL field in unit frontmatter `acceptance_test` block. Values (ordered from weakest → strongest blind-spot coverage):

| Value | Meaning | Trust signal |
|---|---|---|
| `same-pass` | Original Iter 30 behavior — same LLM authored both unit body + test | weakest (audit risk D4-006) |
| `adversarial-reviewed` | Iter 47 default — main thread re-prompted itself adversarially; gaps merged | recommended baseline |
| `adversarial-reviewed (no gaps)` | Iter 47 — adversarial pass found nothing to add | strong (passed adversarial scrutiny) |
| `adversarial-reviewed (+N gaps merged)` | Iter 47 — adversarial pass identified N gaps; merged | strong (gaps explicitly closed) |
| `adversarial-review-failed` | Iter 47 — adversarial pass returned incoherent output; original kept | weak + warning |
| `independent-llm` | Iter 47 OPT-IN (`--adversarial-subagent` flag) — separate subagent re-authored or extended | strongest LLM-derived |
| `human` | User manually edited acceptance_test post-generation | strongest overall |

**Pre-Iter-47 units** (no field present) → treat as `same-pass` (current weakest signal).

### Change 4: execute-bolts surfaces provenance to bolt subagent

In bolt-dispatch-prompt.md `## Unit body (verbatim)` section, when acceptance_test has `_authored_by: same-pass` OR `_authored_by: adversarial-review-failed`, append a NOTE to the dispatch prompt:

```
> NOTE: This unit's acceptance_test has weak blind-spot coverage
> (_authored_by: <value>). The test may fail to catch behavioral bugs.
> If your implementation passes this test but feels under-validated, propose
> additional assertions in your bolt-report.md self-assessment.
```

Bolt subagent self-assessment can flag `acceptance_test_concern: <details>` for user attention.

### Change 5: User-editable `_authored_by: human` flag

After user manually edits acceptance_test in a unit file, they can change `_authored_by:` to `human`. `generate-units --regenerate` will preserve user-marked acceptance_tests (do not overwrite). Default `--regenerate` behavior: rewrite all unless `_authored_by: human`.

---

## §3 — Surface updates

| Surface | Change |
|---|---|
| `generate-units/SKILL.md` | + Step 9.5 (Adversarial test review pass); + `--adversarial-subagent` flag (OPT-IN Option B); preserve `_authored_by: human` on regenerate; bump 2.6.0 → 2.7.0 |
| `generate-units/references/adversarial-test-prompt.md` (NEW) | Prompt template for adversarial review pass |
| `generate-units/references/defensive-generation.md` OR inline in SKILL.md | document `_authored_by:` provenance values + meaning |
| `execute-bolts/SKILL.md` | + Step 4.5.b detects `_authored_by:` weak values + adds NOTE to dispatch prompt; bump to next patch |
| `execute-bolts/references/bolt-dispatch-prompt.md` | + NOTE template for weak acceptance_test |

---

## §4 — Version bumps

- `plugin.json`: 3.31.0 → **3.32.0** (MINOR)
- `generate-units`: 2.6.0 → 2.7.0 (MINOR — new Step + new flag + new frontmatter field)
- `execute-bolts`: 2.9.0 → 2.9.1 (PATCH — detection + NOTE injection)

---

## §5 — Out of scope

- **Full independent-LLM re-authoring** (Option B with `--adversarial-subagent`): DEFAULT-OPT-IN this iter; can be promoted to default in future iter if field validates better outcomes
- **PBT property-based test generation:** out of scope; existing PBT generation (Iter 20) continues separately
- **Acceptance test execution validation:** out of scope; bolt subagent already runs the test
- **Cross-unit acceptance_test consistency:** out of scope; per-unit only

---

## §6 — Standing directives applied

- **simplifikasi:** 1 audit finding (HIGH structural) → 1 iter; 1 new Step + 1 new reference file + 1 new frontmatter field
- **flawless:** producer (generate-units emits `_authored_by:`) + consumer (execute-bolts reads + surfaces to bolt subagent) ship in-iter; backward compat for pre-Iter-47 units (treated as `same-pass`)
- **reuse-first:** extends existing generate-units 12.x post-write validation pattern + extends existing bolt-dispatch-prompt.md NOTE injection convention; no new halt type (adversarial-review-failed is a `confidence` signal, not a halt)
