# God-review — Stage 2: `generate-intent`

**Date:** 2026-07-01
**Reviewer:** architectural god-review (adversarial multi-lens Workflow), findings ground-truthed by hand.
**Target:** the `generate-intent` skill — SKILL.md (183 L) + 12 references + its 4 advisory vault validators
(`validate-vault-oqs.sh`, `validate-vault-flow-staging.sh`, `validate-vault-flows.sh`,
`validate-vault-binding-coverage.sh`) + the constitution surface (`validate-constitution.sh`,
`validate-constitution-propagation.sh`).
**Predecessor:** Stage 1 (`extract-intelligence`) shipped as v4.54.0 (Batch 1 — tech-agnostic validator hardening).

## Method

7 blind, single-lens reviewers (generalization · anti-halu · enforcement-gap · oq-classifier ·
validator-robustness · cross-batch · mode-matrix), each given explicit file paths, run in parallel; then every
deduped finding passed to a **refute-by-default** verifier (reproduces? / by-design? / fix-generalizes?). Authoring
conformance (SKILL ≤ 500 L, YAML validity, refs one-level) was checked deterministically instead of spending a
reviewer slot.

Two lenses (`anti-halu`, `mode-matrix`) died on transient API stalls in the first pass; the partial-pass guard
captured them as `null_dimensions` and they were **re-run**. As in Batch B, the re-run was decisive — it surfaced
the second Critical (constitution) that a "5/7 agreed → ship" synthesis would have hidden.

**Tally:** 19 REAL (2 Critical · 5 High · 7 Medium · 5 Low, before consolidation) · 13 rejected by the verifier.

## The two dominant defect classes

1. **Validator ⇄ spec drift.** A deterministic validator keyed on a grammar the generator never emits — so the
   detection is dead (fail-open) *and* cry-wolfs (false-positive) on 100 % of real vaults. Root causes are
   self-contradictions *inside* `vault-contract.md` (two sections document two different field grammars; the
   validator was coded to the stale one). Same shape as Batch 1, but the axis is **spec-internal** not per-codebase.
2. **Language-axis inertness.** Detection heuristics keyed on English-only vocabulary (`approve/reject/review/
   confirm`, `maker→checker`), yet `generate-intent` **emits the vault in the input language** (Indonesian PRD →
   Indonesian vault). The rails go inert on exactly the Indonesian trade-finance maker-checker vault they were built
   to protect. The Batch-1 defect class, one axis over (**language**, not stack). The `TECH-AGNOSTIC` comments in
   these validators defend only the *stack* axis and are silent on language.

Both are "plugin behavior must generalize" violations. The generalizing fix keys off **language-invariant signals the
skill already emits** (the frozen `F-U-/F-S-/F-C-/F-X-` flow taxonomy, `vault.json` structured fields,
`design_system_flags`, `stages:`/`role:` keys, mermaid `stateDiagram` type) **or explicitly SKIPs-with-advisory** —
never "add Indonesian terms" (that recreates the one-context anti-pattern one language over).

---

## Findings, grouped into independently-shippable batches

### Batch 2A — OQ-schema realignment  🔴 **Critical**

**C1 — the OQ-schema validator arm is coded to a phantom grammar.**
`validate-vault-oqs.sh:183,205,220-221,232-238` greps for `[tech]` (exact) / `category: tech` (unquoted) /
`^mode:` / `scan_target:`. The vault actually emits (per `vault-contract.md §Updated OQ schema`, L300-337):
markdown `[tech / scan] [conf: high]` and JSON `"category":"tech"`, `"resolution_mode":"scan"`, `"scan_query":…`,
`"scan_citations":[…]`, `"fallback_if_wrong":…`. Running the regexes verbatim against the canonical tags yields
`has_tech_category=False`, `mode=None`, `scan_target=N` on **both** the markdown and JSON forms. Two-way failure:

- **Fail-open (silent):** `oq_tech_missing_mode` / `oq_scan_missing_query` / `oq_recommend_underspecified` never
  fire on a well-formed vault → §Validation-rules #1-3 (the OQ anti-halu tagging moat, invariant #5) are unenforced;
  PostToolUse writes PASS ~100 % even when a `recommend` OQ omits its citations.
- **Cry-wolf (noisy):** `oq_misclassified_tech` (L190) false-fires on a *correctly*-tagged `[tech / scan]` OQ
  (`has_tech_category=False` + a `TECH_TEXT_RE` hit).

**Root cause — a self-contradiction inside `vault-contract.md`:** §Halt-taxonomy (L800-810) documents `mode:` /
`scan_target:` / `citations`; §Updated OQ schema (L300-337) documents `resolution_mode:` / `scan_query:` /
`scan_citations`. The validator was coded to the **stale** §Halt-taxonomy grammar.

**Generalizing fix:** re-key the parser to the emitted grammar in **both regimes** — markdown
`\[\s*(tech|business)\s*(?:/\s*(scan|recommend|hard_rule|blocking))?\s*\]` + `\[conf:\s*(high|medium|low)\]`, and
JSON `"category"\s*:\s*"(tech|business)"`, `"resolution_mode"\s*:\s*"(\w+)"`, `"scan_query"`; prefer JSON
`open_questions[]` as the structured authority with markdown as advisory cross-check. **Also** reconcile the
§Halt-taxonomy prose (L800-810) to §Updated OQ schema (`mode`→`resolution_mode`, `scan_target`→`scan_query`,
`citations`→`scan_citations`) — fixing only the regex or only the doc leaves the drift. These tokens are English
*schema keywords* regardless of PRD language, so the fix is language-invariant. Keep advisory (do not block).
Folds in **M3** (`oq_recommend_underspecified` required-field set is incomplete — add `fallback_if_wrong` /
`scan_citations`) and **H3** (`oq_misclassified_tech` cry-wolf, fixed by the re-key).

**Fixture:** a canonical vault OQ fixture exercising `[tech / scan]`, `[tech / recommend]`, `[business]` in both
markdown and `vault.json` — the arm must go quiet on well-formed OQs and fire on a genuinely mode-less tech OQ.

*Lenses: enforcement-gap + oq-classifier (independent corroboration) + hand-reproduced.*

---

### Batch 2B — constitution citation rail  🔴 **Critical**

**C2 — "every clause source-cited" is enforced by nothing, and fabrication becomes a blocking gate on code.**
`vault-contract.md:439` and `SKILL.md:130` both mandate that every constitution clause cite a source. The shipped
schema example (`vault-contract.md:377-414`) models ~17 of ~20 clauses **uncited**, including **invented NFR
numbers** with no anchor: `E-001 median < 200ms`, `E-002 < 5 queries`, `E-003 < 30s`, `F-003 7 years / 90 days`.
No validator checks per-clause source: `validate-constitution.sh` checks only readability, sha256, clause-ID parse,
and *unit-coverage* — its "uncited" (L116) means *clause-ID-absent-from-units*, not *clause-lacks-a-source*, and is
WARN/exit-0. `self-check.md` never mentions constitution at all.

**Harm amplification (code-traced):** `generate-units:102` (Step 12.4) injects each clause into a unit's
`## Hard rules` at severity `error`; `validation-passes.md:56` — "halts bolt commit if violated"; `execute-bolts`
enforces Hard rules via a blocking pre/post-flight scan. So a fabricated/defaulted clause becomes a **deterministic
BLOCKING gate on code** on the default run (constitution written unless `--no-constitution`). The no-fabrication moat
(invariant #5) **inverts** — fabrication is enforced as ground truth.

**Generalizing fix:** (a) add a per-clause citation check to `validate-constitution.sh` — for each `- X-NNN:` line,
require a source token (`§`, `(source:`, PRD/KB/regulatory anchor); a clause with none → FAIL (or force
demote-to-OQ). Clause-ID pattern + source token are language-invariant; reuse Batch B's shared letter-led citation
grammar, **with a constitution-context relaxation** so a regulatory anchor (which the rail explicitly allows) isn't
rejected as a version/reg token. (b) Rewrite the schema example so every line shows an inline `(source: PRD § / KB §)`
and uses `<placeholder>` values instead of concrete generic defaults — the scaffold must not be copy-able into a
fabricated standard.

**Fixture:** a constitution with an uncited invented NFR → FAIL; a fully-cited constitution → PASS.

*Lens: anti-halu + hand-reproduced enforcement chain.*

**H5 — Step 4 self-check never re-asserts the constitution rail (ships in 2B).** `SKILL.md:26` promises the anti-halu
invariants "are re-asserted in the self-check before delivery," but `self-check.md` scopes its output-integrity check
to "the 7-file spec" (L50) and its anti-halu block (L36-45) has no constitution line — constitution is the 8th file.
Add one invariant line ("`constitution.md` exists unless `--no-constitution` and every `X-NNN` clause carries a
source — else demote to OQ"), backed by the 2B validator so it's a wired gate, not prose.

---

### Batch 2C — language-axis generalization  🟠 **High**

**H1 — operator-UX / operator-surface / `TECH_TEXT` detection is English-lemma-only → silent PASS on an Indonesian
vault.** `validate-vault-oqs.sh` `DECISION_STEP_RE` (L283-289), `MAKER_CHECKER_CHAIN_RE` (L290-293),
`OPERATOR_SURFACE_RE` (L362-368), `TECH_TEXT_RE` (L124-132) match only English (`approve/reject/review/confirm`,
literal `maker`). `vault_has_workflow_flow()` (L335-354) returns True *only* via those signals, and the gate at
L412 wraps **both** operator-UX rails (`operator_surface_missing`, `design_source_oq_missing`). On an Indonesian
maker-checker vault (`menyetujui/menolak/meninjau`, `pembuat…pemeriksa`) all signals miss → the whole block L412-477
is skipped → **silent PASS**. The rails built for the captured trade-finance maker-checker regression go inert on
exactly the Indonesian trade-finance maker-checker vault they were built to protect. (Advisory per
`plugins/mega-sdd/CLAUDE.md` → High, not Critical: the binding/CONFLICT moat gates still function.)

**H4 — Rail 2 (`design_source_oq_missing`) is needlessly gated behind the English workflow detector.** Its own
trigger (`has_ui_components and all_design_false and not has_design_source_oq`, L445-477) reads *only*
language-invariant inputs — `design_system_flags` (JSON, frozen English keys) and the frozen `OQ-DESIGN/TOKEN/A11Y/
VOICE/BRAND` tokens — yet it can never fire on an Indonesian vault purely because it sits inside the L412 English
gate. UI-with-no-design-source is a defect regardless of whether a workflow flow exists. **Decouple Rail 2 from the
workflow gate.**

**M2 — flow-staging advisory arm is English-verb-keyed** (`validate-vault-flow-staging.sh:93-94,161-172`) → the
dominant wholesale-flatten detection is inert on a non-English vault.

**Generalizing fix (whole batch):** re-key the operator-workflow fast-path YES onto high-precision,
multi-step-specific, **language-invariant** tells the skill already emits — the `stages:`/`stage_id:`/`role:` block
(frozen keys; `vault-contract.md §stages-propagation` defines it as the multi-step wizard/maker-checker marker), a
mermaid `stateDiagram` diagram-type (mandated for staged flows), `_kb_source`, and ≥2 stages with distinct `role:`
keys (count the frozen key, ignore the possibly-Indonesian value). Do **not** re-derive workflow-ness from raw
mermaid edge/branch count — every non-trivial flow has ≥2 branches, so that flips today's silent-PASS into a
false-positive storm. For the residual case (a workflow expressed only in non-English prose with none of that
structure), take an explicit **SKIP-with-advisory** path ("unverifiable: non-English flow prose, operator-surface
check skipped") — **never** silently return False/PASS. Decouple Rail 2 (H4) from the workflow gate.

**Fixture:** a **multi-language matrix** (Indonesian maker-checker vault + a non-banking Indonesian vault) mirroring
Batch B's multi-stack matrix — assert the rail fires or SKIP-advises, never silent-PASSes.

*Lenses: generalization + validator-robustness (corroborated) + hand-reproduced.*

---

### Batch 2D — smaller correctness (Med / Low / Nit)

- **H2 — no-defaulted-standards fabrication is never positively detected.** `validate-vault-oqs.sh` only checks the
  *inverse* (a Design-Source OQ present); a vault that ships a bare WCAG/Material/Tailwind value with no adjacent
  source passes. Add an advisory check: a defaulted-standard token with no source token nearby → WARN. *(Medium.)*
- **M1 — mermaid mandate is anchored solely on the `F-<prefix>-NNN` heading regex** (`validate-vault-flows.sh:67,
  71-78`); a 04-flows.md flow section without that heading escapes the Batch-A mermaid gate. Broaden the trigger so
  a flow body is mermaid-checked regardless of heading shape. *(Medium — Batch-A hole.)*
- **L1 — `validate-vault-binding-coverage.sh` advisory issues flip status to FAIL / exit 1** (L119,175-185),
  inconsistent with the sibling validators' `PASS|SKIP|WARN) exit 0`. Align exit semantics. *(Low.)*
- **L3 — Rule 0 (`--kb`) silently ignores a co-present `--from-prompt`** (`SKILL.md:58`), asymmetric with the Rule 1
  flag-conflict warning — the user's steering brief is discarded with no notice. Apply the Rule 1 "ignoring X because
  Y took precedence" warning uniformly. *(Low.)*
- **Nits — version archaeology in runtime prose.** `from-prompt-mode.md:102` leaks `v0.1.0` into a **generated**
  artifact ("Generated by … v0.1.0"); `squad-partition.md:56` "Plugin behavior matches v1.2". Strip both.

---

## Rejected by the verifier (refute-by-default worked)

`--auto` table "omits Step 0.9" (facts reproduce, behavioral claim does not) · `--scan+--kb` "discards
`[ARTIFACT]`" (prose exists but is by-design) · `[INFERRED][LOCKED]` combo silence (does not reproduce — keys on
mutability tier) · re-run memoization "ignores human override" (premise about where the override lives is wrong) ·
from-prompt brief-inventory English-keyword matcher (by-design, non-load-bearing) · self-check "no-defaulted-
standards conditionally gated" (structural obs reproduces, load-bearing claim does not) · mermaid-mandate N/A escape
English-only (rejected — separately handled) · binding-coverage unanchored substring · citation-integrity hardcoded
KB path · multi-vault binding-doc shadowing · `classification_confidence` presence-check · per-doc Open-Questions
presence · no-diagram NA_LINE English vocab. **13 total** — plausible-but-wrong findings that did not survive
independent re-reading.

## Recommended sequencing

Each batch is independently shippable (own files, own fixture, own version bump). Severity order:

1. **2A — OQ-schema realignment** (Critical; `validate-vault-oqs.sh` OQ arm + `vault-contract.md` §Halt-taxonomy).
2. **2B — constitution citation rail** (Critical; `validate-constitution.sh` + `vault-contract.md` schema example +
   `self-check.md`).
3. **2C — language-axis generalization** (High cluster; `validate-vault-oqs.sh` detection + `-flow-staging`, with
   the multi-language fixture matrix).
4. **2D — smaller correctness** (Med/Low/Nit grab-bag).

Discipline carried from Batch 1/B: shared-lib for any grammar touched by two validators; ground-truth every regex
against a reject/accept set before wiring; multi-language matrix mirrors the multi-stack matrix; adversarial re-review
before ship; full suite green; `plugin.json == marketplace.json`; behavior change ⇒ spec + fixtures + reviewer ack.
