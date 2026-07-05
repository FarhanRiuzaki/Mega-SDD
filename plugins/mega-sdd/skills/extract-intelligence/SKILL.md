---
name: extract-intelligence
version: 1.14.0
description: Tech-agnostic domain extractor for legacy codebases targeted for rebuild. Wave-based parallel-subagent extraction produces `.mega-sdd/knowledge-base/` with `[VERIFIED]/[INFERRED]/[OPEN]` confidence markers and `[LOCKED]/[INTENT]/[ARTIFACT]` mutability tiers — KB is an analysis input that drives REENGINEERING recommendations, not a 1:1 mirror of legacy. Output consumable by `mega-sdd:generate-intent` (Mode B via `--kb`) and `mega-sdd:bind-codebase` as secondary ground truth. Triggers — "extract domain knowledge", "reverse engineer this legacy", "pecah legacy code jadi knowledge base", "rebuild di stack baru", "legacy intelligence", or paraphrases.
---

# Extract-Intelligence — Legacy Domain Knowledge Extractor

Tech-agnostic domain extractor for legacy codebases. Produces a multi-file knowledge base organized by **business domain**, not by code structure. Output describes WHAT the system does in tech-agnostic terms, not HOW the legacy stack implements it. Source-of-truth for rebuild planning on a different stack.

**Announce at start:** "I'm using the extract-intelligence skill to extract domain knowledge from the legacy codebase."

> **Skill instruction language:** this skill reasons in English; KB content stays tech-agnostic per the `[VERIFIED]`/`[INFERRED]`/`[OPEN]` schema. Narrate (the announce, wave progress, summaries) in **Indonesian + English technical terms by default**; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 structural tokens (markers, citations, `sha256:`) stay English (→ `plugins/mega-sdd/references/output-language.md`).

**Core principle:** Domain-first, not code-first. Tech-agnostic vocabulary. Citation-disciplined extraction. Wave-based parallel agents to manage token budget. Ambiguous → `[OPEN]`, never silent default.

## When to use

- Legacy codebase needs full rebuild on a different stack (not in-place migration).
- High-stakes domain (financial, regulatory, healthcare) — missing edges cost money.
- Architect needs "what does this system actually do" without reading 600+ source files.
- After `mega-sdd:scan-codebase` when rebuild is in scope — KB is richer than codebase-map for rebuild planning.
- User says variations of: "extract domain knowledge", "reverse engineer this", "pecah legacy code", "source of truth dari legacy code", "rebuild di stack baru".

**When NOT to use:**
- Direct code port to a newer version of the same stack → use migration tooling.
- Small codebases (<50 files) → just read them.
- Greenfield projects (no legacy).
- "What files are in this repo" → use `mega-sdd:scan-codebase` (lighter, faster, code-organized).

## Relationship to other mega-sdd skills

| Need | Skill | Why |
|---|---|---|
| Map files/modules in a brownfield repo | `mega-sdd:scan-codebase` | Heuristic catalog organized by code structure |
| Validate an SDD vault claim against existing code | `mega-sdd:bind-codebase` | Primary ground truth = codebase-map; KB consulted as secondary |
| Extract domain knowledge to rebuild elsewhere | **this skill** | Tech-agnostic, domain-organized, marker-disciplined |
| Convert brief/KB → intent vault | `mega-sdd:generate-intent` | Consumes this skill's KB via `--kb=<path>` |

**Typical chain:**
`extract-intelligence` → `generate-intent --kb=<kb>` → `generate-units` → `execute-bolts`

Naming: this is the mega-sdd-flavored take on the legacy reverse-engineering pattern (no equivalently-named superpowers skill ships today — do not Skill-invoke one). The mega-sdd version produces a structured `.mega-sdd/knowledge-base/` that downstream mega-sdd skills explicitly consume. Use this version when the next step is mega-sdd unit/bolt generation.

## Inputs

- Legacy codebase path (positional, required)
- `--out=<path>` (OUTPUT_ROOT / parent dir; default `.mega-sdd/` per `plugins/mega-sdd/references/paths.md` — the KB is written to `<out>/knowledge-base/`)
- `--seed=<path>` (optional pre-existing forensic dump; moved to `_source/`)
- `--max-parallel=N` (subagent cap per wave; **default 3** per the empirical optimum; soft warn at >5; hard cap 8 — see orchestrate-flow/references/predictive-checks.md `subagent_capacity_reasonable`)
- `--auto` (skip per-wave confirmation prompts; quality-gate failures still halt)

## Output

**Secret-scan gate (mirrors scan-codebase Step 10a):** before EACH KB file is written, run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/secret-scan.sh" --redact <assembled-file>` — legacy code routinely hardcodes credentials, and KB citations would otherwise carry them verbatim. Findings → value replaced with `[REDACTED-SECRET]` in the KB artifact (the legacy SOURCE is never edited) + one chat warning citing source file:line.

Per `references/knowledge-base-schema.md` (read this file before generating any wave output) — see its **§Directory layout** for the full `{out}/` tree: the optional `_source/` seed, the `knowledge-base/` numbered tree (`00-overview` … `99-rebuild-architecture`) with each directory's sub-files, the `50-integrations` external-contract (conceptual, not protocol) convention, and the legacy `--out` probe order.

Every domain file has YAML frontmatter (`generated_by: mega-sdd:extract-intelligence`, classification, criticality, verified/inferred/open counts, citation count). Consumed by `bind-codebase` as secondary ground truth.

## Wave-based execution

6 sequential waves (Wave 0–5) with parallel subagents inside each wave — each wave subagent is the first-class **`mega-sdd:domain-extractor`** agent (dispatched via the Agent tool), given its domain assignment + legacy paths + the KB schema as its task. Read `references/wave-dispatch-templates.md` for the per-wave dispatch prompts and quality-gate grep commands.

| Wave | Output | Subagents | Why |
|---|---|---|---|
| **0 — Prep** | Skeleton dirs; move existing forensic dump to `_source/` | Main thread | Foundation |
| **1 — Foundation** | overview, glossary, classification, data-model, workflows | 3 parallel | Anchors for waves 2-4 |
| **2 — Masters** | Master entities, reference data, regulatory rules | 4 parallel | Low write volume; anchors workflows |
| **3 — Workflows** | Transactional workflows, ops rules, hidden gotchas | 5 parallel | Heaviest extraction wave |
| **4 — Integrations** | External system contracts, reporting/monitoring | 3 parallel | Wraps domain coverage |
| **5 — Synthesis** | ERD, system-flow, dependency-graph, phasing, README | Main thread | Needs holistic view across all wave outputs |

**Model tier per wave:** resolved per role from `references/model-tiers.md` — waves 1–4 default sonnet, wave 5 defaults opus (synthesis needs holistic context). The per-wave catalog lives in `references/wave-dispatch-templates.md` §Model tier per wave; override via handoff `metadata.model_tiers` when invoked through orchestrate-flow.

**Why wave-based:**
- Token budget control — never more than `--max-parallel` subagents in flight.
- Later waves cross-reference earlier outputs (glossary anchors every domain file).
- Quality gate between waves catches template / citation drift early.
- Wave 5 on main thread avoids subagent context loss — synthesis needs the whole map.

**Common timeout pitfall:** subagents reading >40 KB single files hit stream timeout. Mitigation: tighten Read scope with line ranges, prefer `Grep` for targeted patterns, fall back to synthesis-from-siblings (read other KB files instead of legacy source) for late waves.

**Glossary pre-parse + reference offset hints:** between Wave 1 completion and Wave 2 dispatch the main thread parses `glossary.md` ONCE into a compact `glossary_index` (term → 1-line def + line range) injected as the `<GLOSSARY_INDEX>` placeholder, and wave-output citations carry `§section:line-range` hints so downstream readers spot-read instead of full-document read. Full procedure + the verbatim subagent instructions: `references/wave-dispatch-templates.md` §`<GLOSSARY_INDEX>` placeholder + §Reference offset hints.

## Extraction discipline (non-negotiable)

Every non-trivial claim carries TWO orthogonal axes — **confidence** (epistemic: how sure are we?) + **mutability** (decisional: how much freedom does rebuild have?). Both axes are mandatory.

### Axis 1 — Confidence markers (existing convention, also used by `bind-codebase`)

- `[VERIFIED]` — confirmed by multiple code paths OR an explicit doc.
- `[INFERRED]` — single source code path; needs confirmation.
- `[OPEN]` — unknown from code; needs domain expert. Propagates to vault as OQ when KB is consumed by `generate-intent`.

### Axis 2 — Mutability tiers

Per user directive "code dan ERD bisa berubah, tapi goals reengineering nya terpenuhi, jika tidak ada ketentuan erd harus 1:1" — every claim is tagged with the freedom rebuild has to change it:

- `[LOCKED]` — **MUST be preserved 1:1 in rebuild**. Triggered by:
  - Regulatory citation (BI/OJK/SOX/HIPAA/PCI/GDPR specific field, calculation, retention rule)
  - Contractual integration spec (SWIFT MT format, partner API contract, audit-trail compliance)
  - Migration cost prohibitive (live production data with sensitive constraints — column rename breaks downstream)
  - Hard external dependency (FK referenced by external system out of scope)
- `[INTENT]` — **Business OUTCOME matters, implementation is FREE**. Default tier for most domain rules. Rebuild may redesign schema, refactor flow, swap algorithms — as long as the outcome (state transition, calculated value, business rule effect) is preserved.
- `[ARTIFACT]` — **Coincidental legacy implementation detail — free to DISCARD**. Triggered by:
  - Implementation accidents (e.g., field exists because legacy framework required it; not used by any business rule)
  - Workarounds for legacy stack limitations (denormalization for performance; flag columns for missing JOIN support; column-based polymorphism)
  - Dead code paths (referenced by zero callers; defunct workflow branches)

### Combined notation

Markers stack: `[VERIFIED][LOCKED]`, `[VERIFIED][INTENT]`, `[INFERRED][LOCKED]`, etc. Confidence comes first (epistemic) then mutability (decisional). When `[OPEN]`, mutability is `[?]` until the question is answered: `[OPEN][?]`.

Example claims:

> Customer NIP field is 8 numeric digits, validated by checksum algorithm `<spec link>`. `[VERIFIED][LOCKED]` — `(see §11.3)` — required by BI Regulation 23/2/2021 §4.

> Loan amount is denormalized into `application` and `disbursement` tables for read-performance. `[VERIFIED][ARTIFACT]` — `(see §11.7)` — rebuild may normalize via JOIN or projection.

> Approver matrix uses 7 hierarchy levels keyed by `approval_code`. `[VERIFIED][INTENT]` — `(see §11.4)` — outcome (correct authority routing) matters; representation (matrix vs role-based) is rebuild's choice.

### Default tier when uncertain

If a wave-2/3/4 agent can't classify with high confidence, default to `[INTENT]` (middle-ground, safest). Wave 5 synthesis re-reviews tier distribution and surfaces likely mis-classifications. Never default to `[LOCKED]` (would over-constrain rebuild) or `[ARTIFACT]` (would risk discarding business rule).

### Why this matters — KB role re-positioned

KB is no longer a "preserve-legacy spec". KB is an **analysis input** that produces a vault containing:
1. Business goals (immutable across rebuild)
2. Hard constraints (`[LOCKED]` rules from KB)
3. Recommended new shape (`99-rebuild-architecture/*` proposals — schema, flows, modules)
4. Discarded legacy detail (`[ARTIFACT]` items — listed but flagged as discardable)

The rebuild's job is to satisfy goals + locked constraints, not to mirror legacy verbatim.

**Citation required:** every non-trivial claim has a `file:line` reference in the file's `## 11. Source References` section. Inline claims may use a short `(see §11)` pointer if the citation is shared.

**Tech-agnostic vocabulary:** no language / framework / DB names in domain files except `## 11. Source References` and `50-integrations/`.
- ✓ "Customer entity (persisted in legacy as table `cifmast`)"
- ✗ "MySQL `cifmast` table"

**`.bak` / dated-file handling:** compare with live version, document discrepancies in `## 9. Edge Cases & Gotchas`. Don't assume `.bak` is older — sometimes it contains logic removed due to a regression.

**No fabrication:** ambiguous → `[OPEN]`. Never guess regulatory citations, never invent business rules from a single source.

### Staged-input detection (multi-step workflows)

A workflow that collects its inputs across MORE THAN ONE step / page / role is **staged** — a wizard, a maker→checker hand-off, a multi-page form. If you transcribe it as one flat "Inputs: A,B,C,D,E,F" list, the rebuild loses the staging and a bolt builds ONE form where the legacy had a multi-step wizard (the captured trade-finance regression). For every `classification: workflow` domain, actively look for staging and, when found, author the `## 3a. Staged inputs` `stages:` block (schema: `references/knowledge-base-schema.md §3a`).

**Signals the source is staged (any ONE is enough to author §3a):**
- **Multi-page form / wizard** — a `step` / `stage` / `page` request param or hidden state field that switches which fields render (`<input type="hidden" name="step">`, `?page=2`, `wizard_step`).
- **Conditional rendering keyed to a stage** — `if (stage == 'review') { … }`, `switch ($step)`, view partials selected by a phase variable.
- **State-machine transitions that gate inputs** — a `status` / `state` field whose value (`draft → pending → approved`) decides which fields are accepted or shown next.
- **Role-gated visibility** — a maker form vs a checker form; different roles supply different fields in sequence (maker enters A,B,C; checker then enters D,E,F).

**Discipline:**
- One `stages:` entry per step. Allocate each input field to the stage that actually collects it (`input_fields`), in source order.
- **Anchor MANDATORY per stage** — each stage's `_source` cites the `file:line` proving that stage exists. A stage you cannot anchor is an `[OPEN]`, not an invented step.
- Name the `actor_role` per stage and the `transitions` (trigger + guard `conditions`) that advance it. Reference each `stage_id` in the §8 state-machine transition labels.
- If staging is genuinely ambiguous (sequential flows exist but no explicit stage concept in code), still author §3a with `[INFERRED]` stages + an `[OPEN]` note — do NOT silently flatten.
- **Progressive-disclosure deltas (OPTIONAL / best-effort):** when a stage's form clearly differs from the prior stage, capture the delta in §3a — which fields are NEW here (`new_fields_vs_prior`), which were shown earlier but are gone (`hidden_fields_vs_prior`), which were promoted to mutable (`promoted_to_mutable_vs_prior`, e.g. display-only → dual-key re-entry), and any within-stage show/hide (`dynamic_disclosures`). Use the enriched object form of `input_fields` (`{name, mutability, visibility, conditional}`) when you can read per-field mutability/visibility; bare strings remain valid. Schema: `references/knowledge-base-schema.md §3a`. This deepens the staging capture (the user's "fields A,B,C at maker; D,E,F appear at the next stage" case) — but it is NOT validator-blocking; absence never fails a gate.

> Walking-skeleton scope: only the staged-input dimension is required this iter. `validate-kb-flows.sh` raises an advisory `kb_flow_staging_missing` (non-blocking) when a workflow looks multi-step but has no `stages:` block; `/mega-sdd:enrich-semantics` retro-fits staging on an existing KB without a full re-extract.

### Deep extraction disciplines (P1–P4 + P6)

Six extraction principles make the wave subagents reason deeper and catch the cases a write-side-only read misses. **The authoritative, agent-facing copy lives in `references/wave-dispatch-templates.md` §generic-agent-prompt-structure → DEEP DISCIPLINES** — that is the block injected into every wave subagent prompt, so the deeper reasoning fires *automatically* every run (a discipline that lived only here in SKILL.md would never reach the extraction subagents). This subsection is the design vocabulary; do not let the two drift.

**Tech-agnostic by construction (per user directive 2026-06-15 — "EI ini harus support tech agnostic ga hanya PHP… php just example"):** the principles are stack-NEUTRAL. The agent-facing copy carries a **STACK IDIOM TABLE** mapping each principle to the concrete idiom per stack (PHP / JS-TS / Python / C#-.NET / Java / Go / Ruby / Rust), so the reasoning fires on whatever the legacy is written in — not just PHP. Never read "not present" from "I didn't see the PHP idiom"; reason from the matching stack row.

- **P1 — State & data provenance.** For every state *writer*, locate the *reader*; for every clone copy (bulk row-copy, snapshot, object/struct copy — per the idiom table), trace the implicitly-inherited fields and who reads them downstream. Writer with no reader → `write-only / vestigial`; reader with no in-scope writer → `inherited / cross-domain seam`. Anti-halu: an unpaired side is `[OPEN]`, never invented.
- **P2 — Enumerate ALL sites of a rule or flow.** Document every site of a repeated rule (diff them, mark `[OPEN]` on disagreement — never average); treat each entry-point dispatcher branch (action/mode/HTTP-verb/route discriminator) as a distinct flow with its own initial state.
- **P3 — Behaviour-as-EXECUTED.** Unconditional halts / hard-exits (per the idiom table) as `[ARTIFACT: debug-code-as-feature]`; full transaction-rollback policy; hardcoded test flags; silent-success paths — what an operator OBSERVES.
- **P4 — Classify files by structure, not naming.** Role from template-ratio / form-tags / early-return gates (view / action_handler / dual_purpose / dispatcher / service); document filename-vs-structure mismatches in §9.
- **P6 — Dynamic dispatch & runtime wiring.** For every *dynamic seam* — a call site whose concrete target is resolved at RUNTIME, not lexically (DI-container resolution, reflection / `dynamic` / duck-typing, attribute/annotation/convention routing & validation, interface → implementation dispatch, event/delegate/middleware wiring — per the idiom table) — locate the real target(s) and document the observed behaviour, citing BOTH the seam and each target. The inverse of P2 (one call site, N runtime targets); the dominant silent-miss on DI/reflection-heavy stacks (C#/.NET, Java/Spring, Go, modern TS). Anti-halu: an unresolvable seam is `[OPEN]`, never an invented target.

**Framing (per user directive 2026-06-02):** the KB captures **business intent + flow**; the rebuild owns **implementation cleanliness**. So P1 captures coupling as a *business outcome* ("the amendment must still trigger downstream dispatch + facility re-balance"), NOT the legacy implementation accident, and **status-naming drift between legacy and rebuild is NOT a gap** (a legacy status flag normalizing to a clean `workflow_state` is a cleanup, not drift). The disciplines surface coupling and distinct operating models so the rebuild can preserve the *outcome* while redesigning the *encoding*.

These five are reasoning disciplines (P5 FE-completeness is covered by the staged-input mechanism above; its progressive-disclosure delta enrichment lives in `references/knowledge-base-schema.md §3a`). Completeness across the six principles is summarized end-of-extraction by an **Extraction Completeness Contract** scorecard.

## Quality gates between waves

After each wave, run the grep checks from `references/wave-dispatch-templates.md` §gate-checks:

- `^## 3\. Flow` exists in every new domain file
- `^## 10\. Open Questions` exists in every new domain file
- `^## 11\. Source References` exists in every new domain file
- Forbidden patterns (language/DB names, SQL strings) absent outside allowed sections — run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/kb-leak-scan.sh" --kb-dir=<kb> --stack=all` (unions every stack's tokens — a tech-agnostic KB must be neutral to BOTH the legacy AND the target stack, so `all` beats auto-detecting only the legacy language; detects C#/Java/Go/Rust leaks the old PHP/SQL grep missed; advisory)
- Frontmatter present with required keys
- **Mermaid emission rules** (`plugins/mega-sdd/references/mermaid-emission-rules.md`) — §3 Flow + §8 State Machine blocks MUST follow the 6-rule contract (quote node text, `<br/>` for newlines, escape special chars, paraphrase raw code expressions). `validate-kb-flows.sh` enforces a heuristic subset; producers are responsible for parser-valid syntax even when the heuristic doesn't flag the specific pattern
- **Staged inputs** — a multi-step `classification: workflow` file SHOULD carry `## 3a. Staged inputs` with a `stages:` block. `validate-kb-flows.sh` raises an advisory `kb_flow_staging_missing` (non-blocking — does NOT fail the wave) when a workflow looks multi-step but has none; re-dispatch the agent with the §3a discipline above, or retro-fit later via `/mega-sdd:enrich-semantics`
- **P1 provenance** — a workflow agent reporting `provenance_anomalies > 0` (per `wave-dispatch-templates.md` REPORT BACK) MUST carry a matching `write-only` / `inherited / cross-domain seam` note with an `[OPEN]` marker per anomaly. The Wave 3 gate surfaces a **non-blocking** advisory `provenance_read_side_thin` (a MANUAL between-wave grep nudge — NOT a validator-emitted state signal, unlike `kb_flow_staging_missing`) when a workflow file documents transitions but never references the read-side; re-dispatch with the P1 discipline. Never fails the wave (mirrors staged-input) — genuinely unpaired states are legitimate `[OPEN]`s

If failures → re-dispatch the failing agent with specific feedback. Don't proceed to the next wave with broken outputs — they're inputs to the next wave's cross-references.

If the same gate fails twice for the same agent → halt with the gate output. User decides whether to re-scope, re-prompt, or abort.

## Synthesis wave (main thread only)

Wave 5 MUST be main thread, not a subagent — it needs holistic context across every wave's output:

The six synthesis outputs, in order — `suggested-erd.md`, `suggested-system-flow.md`, `module-dependency-graph.md`, `suggested-phasing.md`, `data-mutation-policy.md`, and the `README.md` roll-up — are specified with their per-output schema (ERD Quality Rails; the `data-mutation-policy.md` `[LOCKED]/[INTENT]/[ARTIFACT]` table that drives `generate-intent --kb` freedom; README reengineering-opportunities-first ordering) in `references/wave-dispatch-templates.md` §Wave 5 — Synthesis and `references/knowledge-base-schema.md` §99-rebuild-architecture templates.

## Step 5.5 — Emit extracted-kb shared snapshot

After the Synthesis wave (Wave 5) completes and `README.md` roll-up is written, emit a shared-snapshot file per `plugins/mega-sdd/references/shared-snapshot-schema.md §extract-intelligence (extracted-kb snapshot)`. Enables downstream `generate-intent --kb` to verify KB freshness against source codebase without re-extracting.

```
1. Collect every source file enumerated during waves 1-4 extraction (from each subagent's _source: citations + main thread's file enumeration in wave 1).
2. Compute current sha256 for each source file.
3. Build source_files_sha256_map:
   { "<repo-relative-path>": "<sha256-hex>", ... }
4. Write atomically to <kb-dir>/.shared-snapshots/extracted-kb.snapshot.json:
   {
     "snapshot_schema_version": "1.1",
     "snapshot_type": "extracted-kb",
     "generated_by": "extract-intelligence@1.6.0",
     "generated_at": "<ISO8601 at extraction completion>",
     "scope": null,
     "files": [],
     "source_files_sha256_map": { ... }
   }
5. Use temp-file + rename for atomicity.
```

If write fails: log warning + continue (snapshot is freshness check optimization; KB itself remains the consumable output).

## Step 5.6 — Emit Extraction Completeness Contract scorecard

The contract makes extraction *falsifiable*: it summarizes how well each of the six Deep extraction disciplines (P1–P4 above + P5 staged inputs + P6 dynamic dispatch) was satisfied, so downstream stages can see what is solid vs `[OPEN]` before building on it. After Wave 5's README roll-up, the main thread emits two files into the KB dir:

- `.extraction-scorecard.json` (machine-readable — validated by `scripts/validate-extraction-scorecard.sh`)
- `EXTRACTION-SCORECARD.md` (human-readable companion)

**Deriving each principle's status** (from the Wave REPORT BACK self-checks + a holistic KB scan):

| Principle | COVERED when | PARTIAL / MISSING when |
|---|---|---|
| `P1_state_provenance` | every documented state writer has a located reader (or an explicit `write-only` / `inherited / cross-domain seam` `[OPEN]` note) | `provenance_anomalies` reported but not all carry an `[OPEN]`/seam note |
| `P2_rule_enumeration` | repeated rules documented at every site; entry-point branches captured as distinct initial states | a rule documented at only one site when grep shows more; disagreeing sites not marked `[OPEN]`/conflict |
| `P3_behavior_executed` | unconditional halts / rollback policy / test flags / silent-success paths documented as observed | a transaction wrapper in scope with no documented rollback policy |
| `P4_structural_classification` | in-scope files classified by structure; filename-vs-structure mismatches noted | files left role-ambiguous with no `[OPEN]` |
| `P5_staged_inputs` | every multi-step `classification: workflow` carries a `## 3a` `stages:` block | a multi-step workflow with no stages block (see `kb_flow_staging_missing`) |
| `P6_dynamic_dispatch` | every dynamic seam found (`dynamic_seams_found`) is resolved to ≥1 cited target OR carries an `[OPEN]` (`dynamic_seams_resolved + dynamic_seams_open == dynamic_seams_found`) | a seam found but neither resolved nor marked `[OPEN]` (a hidden runtime path) |

**`overall_status`:** `PASS` = all six COVERED · `PARTIAL` = ≥1 PARTIAL but every PARTIAL/MISSING principle has corresponding `[OPEN]` markers in the KB · `FAIL` = a PARTIAL/MISSING principle with NO `[OPEN]` markers (a hidden gap — the silent-drift failure mode this contract exists to catch).

**Anti-halu rail:** never up-rank a principle to COVERED to make the scorecard green. An honest `PARTIAL` with `[OPEN]` markers is the correct, passing state; a green scorecard hiding a gap is the failure.

```json
{
  "version": "1.1",
  "extracted_at": "<ISO8601>",
  "extractor_version": "extract-intelligence@1.11.0",
  "scope": { "legacy_root": "<path>", "files_in_scope": 0, "files_read_fully": 0 },
  "principles": {
    "P1_state_provenance":        { "status": "COVERED|PARTIAL|MISSING", "anomalies_count": 0, "anomalies": [] },
    "P2_rule_enumeration":        { "status": "COVERED|PARTIAL|MISSING", "rules_documented": 0, "conflicts_open": 0 },
    "P3_behavior_executed":       { "status": "COVERED|PARTIAL|MISSING", "artifact_markers": 0 },
    "P4_structural_classification":{ "status": "COVERED|PARTIAL|MISSING", "files_classified": 0, "naming_structure_drift_count": 0 },
    "P5_staged_inputs":           { "status": "COVERED|PARTIAL|MISSING", "workflows_audited": 0, "workflows_with_stages": 0 },
    "P6_dynamic_dispatch":        { "status": "COVERED|PARTIAL|MISSING", "seams_found": 0, "seams_resolved": 0, "seams_open": 0 }
  },
  "overall_status": "PASS|PARTIAL|FAIL",
  "open_markers_present": true
}
```

**Validation + downstream consumption:** `scripts/validate-extraction-scorecard.sh --cwd=<project>` checks the scorecard's internal consistency + the `[OPEN]`-correspondence rule (SKIP when absent — back-compat; FAIL only on inconsistency or a hidden gap). `bind-codebase` consults it as a **preflight advisory** (surfaces FAIL/absent; non-blocking this iter). If write fails: log warning + continue (the KB itself remains the consumable output).

## Bridge to rebuild + mega-sdd pipeline

After extraction, suggest one of:

1. **Manual rebuild planning** — use `99-rebuild-architecture/suggested-phasing.md` as the phase plan.
2. **Continue in mega-sdd pipeline** — run `/mega-sdd:generate-intent --kb=<knowledge-base-path>` to bootstrap a per-phase vault from the KB README + relevant domain files. From there: `generate-units` → `execute-bolts`.

If the rebuild lives in a different directory: copy `knowledge-base/` to the new project under `old-reference/`. Mark the distinction in the new project's CLAUDE.md:
- `old-reference/knowledge-base/` → REFERENCE liberally
- `old-reference/_source/` → legacy code dump, DON'T pattern-match

## Halt conditions

- Legacy codebase path missing or empty → halt; ask user for correct path.
- `--max-parallel` > 8 → halt; warn token budget collapse risk.
- Same wave's quality gate fails twice for the same agent → halt; surface the gate output verbatim.
- Wave 5 dispatched as a subagent → halt; config error, must be main thread.

## Path resolution

Per `plugins/mega-sdd/references/paths.md`. **No-excuse rule: ALL output defaults to `.mega-sdd/`** — back-compat to legacy `docs/knowledge-base/` triggers ONLY when legacy paths already exist on disk.

Resolution algorithm:

1. **User explicit `--out=<path>`** → always respected, overrides everything.
2. **Project config**: `<project-root>/.mega-sdd/config.yaml` → if `output_root: <path>` set, resolve `<out>` = `<output_root>/knowledge-base/`.
3. **Legacy back-compat detection**: ONLY if `<project-root>/docs/knowledge-base/` already exists with prior extraction (has `README.md` or any `00-overview/` content) → continue writing there to avoid split-brain.
4. **Default (new + fresh projects)**: `<project-root>/.mega-sdd/knowledge-base/`. Create the parent `.mega-sdd/` directory if absent. This is the path for ALL fresh extractions — chicken-and-egg detection from v1.2 is REMOVED.

**Read-side back-compat**: downstream `generate-intent --kb`, `bind-codebase --kb`, `orchestrate-flow` all probe in priority order — `.mega-sdd/knowledge-base/` first, then `docs/knowledge-base/`, then `docs/mega-sdd/knowledge-base/`, then `old-reference/knowledge-base/`. First hit wins.

## Hand-off

On completion, announce:

> "Knowledge base written to `<out>/knowledge-base/`. Critical findings: N. Open questions: N total (P1: …, P2: …, P3: …). Source citations: N. Next: review `<out>/knowledge-base/README.md`, then `/mega-sdd:generate-intent --kb=<out>/knowledge-base/` to bootstrap a vault."

## Handoff emission

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML record at the end of skill output per your local template in `references/handoff.md` — the OPERATIVE emission spec (`orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index). The orchestrator parses this to decide auto-continue.

The canonical `extract-intelligence` handoff record — full schema including the `scope:` and `mutability:` blocks (extract-intelligence is the PRIMARY mutability-tier producer: `tier_distribution`, `locked_claims_touched`, `artifact_discards_proposed`) — lives in `references/handoff.md`. Emit it verbatim with runtime values filled in (artifacts, metrics, scope, tier distribution).

Status `halted` when quality gate fails twice (per `references/wave-dispatch-templates.md` §gate-checks). Required ONLY under `--auto`; standalone invocations may emit informationally.

## Real-world validation

Validated on the Bank Mega Trade Finance legacy rebuild (~600 PHP files; MySQL + MSSQL + LDAP + SWIFT FTP). Full metrics — forensic-seed size, MD/KB/domain counts, findings beyond seed (gotchas, OQs, do-not-replicate bugs, hidden UDF, OFAC gap), wall-clock and dispatch counts — in `docs/superpowers/specs/2026-05-20-extract-intelligence-skill-design.md` §13.

## Cross-references

- `references/knowledge-base-schema.md` — output directory structure + per-domain 11-section template + frontmatter contract
- `references/wave-dispatch-templates.md` — per-wave subagent prompts + quality-gate grep commands
- `references/handoff.md` — the operative `--auto` handoff YAML template (scope + mutability blocks)
- `mega-sdd:generate-intent` — consumes KB via `--kb=<path>` as Mode B brief
- `mega-sdd:bind-codebase` — consults KB as secondary ground truth when codebase-map is silent
- `superpowers:subagent-driven-development` — pattern for the parallel agent dispatch this skill uses
- `superpowers:verification-before-completion` — pattern for the quality-gate grep checks
- `docs/superpowers/specs/2026-05-20-extract-intelligence-skill-design.md` — design spec this skill implements
- `docs/superpowers/specs/2026-06-15-extract-intelligence-tech-agnostic.md` — tech-agnostic hardening (concept-first disciplines + STACK IDIOM TABLE + P6 dynamic dispatch + per-stack `kb-leak-scan.sh`)
- `plugins/mega-sdd/scripts/kb-leak-scan.sh` — per-stack KB tech-leak detector (replaces the hardcoded PHP/SQL grep)
