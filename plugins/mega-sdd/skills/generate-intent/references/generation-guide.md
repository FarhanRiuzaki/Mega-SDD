# generate-intent — Generation guide (Step 3 + 3.5)

## Contents
- Step 3 — Generate the 7 files (conditional sections)
- Operator-workflow-UX capture + Design-Source OQ
- `vault.json` machine-readable manifest
- Reading the templates
- Step 3.5 — OQ auto-classification + halt YAML
- Output mode policy
- Readability standards
- File-by-file content guide (00–06)
- Mandatory section template + OQ tagging
- 00-index.md Open Questions roll-up structure

## Step 3 — Generate the 7 files

Output to the **resolved output folder from Step 0** (`<OUTPUT_DIR>`). The 7-file layout is in the SKILL body (The 7-file vault output contract).

**Conditional sections** (driven by the Step 2 detection flags `HAS_UI_COMPONENTS` / `HAS_TOKENS` / `HAS_A11Y` / `HAS_VOICE_BRAND`):

- `02-architecture.md > UI components & patterns` sub-section: appears **only if** `HAS_UI_COMPONENTS = true`. Otherwise omitted entirely (no header, no placeholder, no OQ).
- `06-constraints.md > Design system` top-level section: appears **only if** at least one of `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND` is `true`. Within it, sub-blocks (Tokens / Accessibility / Voice & brand) appear only for the `true` flags.
- `00-index.md > Reading paths`: the "UI/UX or FE Dev" path appears **only if** `02-architecture#ui-components` or `06-constraints#design-system` is present.
- `00-index.md > Glossary`: design-system glossary entries (design tokens, design system, WCAG, a11y, semantic HTML) appear **only if** the term is actually used elsewhere in the vault.

**No shape-based defaulting.** A `PROJECT_SHAPE=mobile-app` project with no source coverage of design-system content produces a vault with no design-system sections. The skill never injects WCAG levels, color palettes, spacing scales, or component lists from prior knowledge.

> Vault structure is the same regardless of `IMPLEMENTATION_MODE`. The mode flag drives the content of the `00-index.md` "Implementation Notes for AI Consumers" section, not the file count.

## Operator-workflow-UX capture + Design-Source OQ

> `validate-vault-oqs.sh` re-validates every vault doc write (PostToolUse) and surfaces a capture-stage miss as **advisory** via `/mega-sdd:analyze` (v4 Hybrid demoted this from a hard-block — it no longer blocks `mega-sdd:execute-bolts`). This prose is the real win — get it right at generation time.

**Rule 1 — model the operator surface when the flows show a workflow.** When the flows in `04-flows.md` exhibit a **maker-checker / multi-stage-approval / workflow** pattern (a user-facing flow with a maker→checker actor hand-off chain, OR ≥2 distinct decision transition steps — approve / reject / review / confirm), model the operator-facing surface as **FIRST-CLASS requirements GROUNDED in the flows** — never invented:

- **Worklist / inbox** — where each actor (checker, confirmer, …) finds the items awaiting *their* decision, filtered by role + current workflow state.
- **Decision affordance** — the approve / reject (and any return-to-prior-stage) actions available to the actor in the entity's current state.
- **Human-readable state labels** — a label map from the raw `workflow_state` enum to operator-facing text (e.g. `SUBMITTED` → "Awaiting Checker").
- **Audit timeline** — the append-only transition history rendered for the operator (who acted, when, prior → next state).

Capture these in `02-architecture.md` (and the component/view inventory) and reflect them in `vault.json`. **Grounded, not invented:** every operator-surface requirement must trace to a flow step / actor / state in `04-flows.md`. If the surface design is genuinely undecided, capture it as an OQ instead of inventing it (Rule 2). The validator FAILs with `operator_surface_missing` when a workflow flow exists but the vault models no operator surface AND carries no Design-Source OQ.

> **Same workflow-flow signal also governs staging.** The maker→checker / multi-stage pattern that triggers operator-surface modeling here is also the staged-input pattern: if the source KB workflow carries a `## 3a` `stages:` block, PRESERVE it verbatim into this flow's `**Stages**` block + `_kb_source` per the 04-flows generation step (`generate-intent/references/vault-contract.md §stages-propagation`). Modeling the operator surface and preserving the staging are two halves of the same workflow fidelity — don't do one and flatten the other.

**Rule 2 — design system: template-first, then recommend, never a defaulted value.** When `HAS_UI_COMPONENTS = true` (UI components exist) but `HAS_TOKENS`, `HAS_A11Y`, and `HAS_VOICE_BRAND` are **all `false`** (no design source in PRD/Figma/KB), resolve the design system by **precedence** — never by silently defaulting WCAG levels, Material/Tailwind palettes, spacing scales, or brand voice from prior knowledge. (These three flags reflect the **PRD/Figma/KB source only**; a scanned starterkit is a SEPARATE input, evaluated in path 1 below — so this rule still fires when the PRD has no design source even though a template was scanned.)

1. **Scanned template wins (source: `scanned-template`).** If a starterkit was scanned and `starterkit-context.yaml §ui_ux` supplies a design system (`design_tokens` / `layout_extends` / `idioms`), DERIVE `design_system` from the template — its flow is authoritative. **ui-ux-pro-max does NOT recommend a style here; it must not override or contradict the template.** Emit a Design-Source OQ ONLY for a genuine gap the template is silent on (e.g. a missing chart palette), and that gap-fill OQ must align with template idioms. Write `design_system` with `source: scanned-template`, `provenance` citing the `starterkit-context.yaml §ui_ux` anchor.

2. **Greenfield — recommend (source: `design-intelligence-recommend`).** ONLY when there is no scanned template design system (true greenfield / `--greenfield`), emit a single high-priority **Design-Source Open Question** `OQ-DESIGN-SOURCE-{N} [P1]` with `resolution_mode: recommend` (NOT a silent default — see vault-contract.md §OQ schema). Consult `references/design-intelligence/product-style-map.yaml` using PRD signals (product type, industry, brand hints):
   - `recommendation`: the chosen `{style, palette, typography, a11y_level}` from the matched `product-style-map` entry (the map key is `a11y_baseline` — write it into the vault as `a11y_level`).
   - `rationale`: the PRD signal → matched map key (e.g. "product_type=SaaS dashboard (PRD §1) → product-style-map.yaml#saas-general").
   - `scan_citations`: `["references/design-intelligence/product-style-map.yaml#<key>", "<PRD §>"]` — **never fabricate**; if no map entry matches, fall back to a bare `resolution_mode: blocking` OQ instead.
   - `fallback_if_wrong`: "blocking — request an explicit design source from the PO".
   Only when the user accepts is the `design_system` block written (with `source: design-intelligence-recommend`).

In both cases the `design_system` block (vault-contract.md §design_system) is written to `vault.json` + the `06-constraints.md > Design system` section, each line cited to its source. The validator still FAILs with `design_source_oq_missing` when UI components exist with all three design flags false and **no** Design-Source OQ (blocking or recommend) is present AND no scanned-template design system was derived.

## `vault.json` machine-readable manifest

Alongside the 7 markdown files, generate `vault.json` — a structured manifest AI dev consumers (Claude Code, Cursor, automated agents) load for fast, reliable context without parsing prose markdown. Markdown remains the human-authoritative source; JSON is a derived index.

- **Schema, field rules, and regeneration trigger points** → `generate-intent/references/vault-contract.md §schema`. Read this before generating `vault.json`.
- **Advisory lock:** acquire an exclusive file lock on `<vault>/vault.json.lock` per `generate-intent/references/vault-contract.md §Concurrency contract` BEFORE writing `vault.json`. Backoff + retry 3×; fail with `memory_in_use` halt if all retries fail. Release after the atomic write (temp file + rename) completes. The lock is REQUIRED for the initial write — concurrent generate-intent invocations on the same path would race.
- **Why both formats:** humans review markdown (narrative, citations, nuance); AI consumers read `vault.json` (fast structural lookup, no token-heavy prose parsing, reliable enum-based status/priority filtering).

## Reading the templates

Use templates in `references/templates/` as scaffolds. **Resolve the path relative to where the skill is mounted:**

- **Claude Code (plugin install — primary distribution):** `${CLAUDE_PLUGIN_ROOT}/skills/generate-intent/references/templates/<name>.md`
- **Claude Code (manual install at `~/.claude/skills/`):** `~/.claude/skills/generate-intent/references/templates/<name>.md`
- **Claude Code (project-scoped manual install):** `<project-root>/.claude/skills/generate-intent/references/templates/<name>.md`
- **Claude.ai upload:** `/mnt/skills/user/generate-intent/references/templates/<name>.md`

Read the relevant template (Claude Code: `Read` tool; Claude.ai sandbox: `view` / platform read tool), then fill it in based on extracted facts. **Never invent fields beyond what the source PRD/Figma supports.**

## Step 3.5 — OQ auto-classification

After Step 3 writes the 7 files but BEFORE the Step 4 self-check, run the auto-classifier on every generated OQ:

1. **For each OQ in docs 01–06**, apply the heuristic table from `generate-intent/references/vault-contract.md §Auto-classifier heuristics`: match the OQ text against the pattern column; assign `category`, `resolution_mode`, `classification_confidence`. Conservative default when no pattern matches: `category: business`, `resolution_mode: blocking`, `classification_confidence: low`.
2. **For `resolution_mode: scan`:** populate `scan_query` from the OQ's "Resolves:" hint or infer the codebase-map section to probe (e.g., "what test framework?" → `scan_query: "codebase-map §test_frameworks"`).
3. **For `resolution_mode: recommend`:** populate the four required fields:
   - `recommendation` — Claude's pick (1–2 sentences).
   - `rationale` — why this pick; what trade-off was considered (2–3 sentences).
   - `scan_citations` — at least 1 entry; cite a related-pattern anchor in the codebase-map / KB / source PRD (e.g., `app/Http/Resources/ErrorResource.php:12`). If no exact match exists, cite the closest pattern with a "no exact match; closest: …" note.
   - `fallback_if_wrong` — what to revisit if this recommendation turns out incorrect (1 sentence).
   - **Anti-halu rail:** NEVER fabricate citations. If no codebase context exists at all, downgrade to `category: business` with note "no codebase context to ground recommendation; needs human decision."
4. **For `resolution_mode: blocking`** (default for business + low-confidence tech): no additional fields required.
5. **Write classified OQ data** back to both the markdown body and `vault.json` per `generate-intent/references/vault-contract.md §Updated OQ schema`.
6. **Generate the `00-index.md` "## Auto-Classification Review" section** before the main OQ roll-up. List every tech-tagged OQ + every flipped/manually-overridden OQ. Only `high`-confidence tech OQs auto-resolve downstream in `bind-codebase`; `medium`/`low` are flagged for user review.
7. **Validation gate:** before proceeding to Step 4, validate every OQ entry per `generate-intent/references/vault-contract.md §Validation rules`:
   - Tech OQ missing `resolution_mode` → halt `oq_tech_missing_mode`.
   - `recommend` OQ missing any of `recommendation`, `rationale`, `scan_citations`, `fallback_if_wrong` → halt `oq_recommend_underspecified`.
   - `scan` OQ missing `scan_query` → halt `oq_scan_missing_query`.

**Halt YAML format:**

```yaml
blocker:
  type: oq_recommend_underspecified
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-intent
  details:
    oq_id: OQ-AR-7
    missing_fields: [scan_citations, fallback_if_wrong]
    oq_text: "<verbatim from vault>"
  next_action: "Re-run generate-intent OR manually populate the missing fields in vault.json before bind-codebase."
```

## Output mode policy

Driven by `OUTPUT_MODE` (Step 0.7):

| Aspect | `compact` (default) | `full` |
|--------|---------------------|--------|
| TL;DR header (doc 01–06) | 1 line: `> **TL;DR**: <doc summary> · <intended audience> · <when to read>.` | 3 lines (TL;DR / Audience / When to read) |
| API contracts (doc 02) | Table: endpoint · method · purpose · auth · errors · source. Skip request/response JSON unless the payload is non-trivial or has a nested struct that isn't obvious from field names. | Full request/response JSON example per endpoint |
| Entity descriptions (doc 03) | DBML only + 1-line `Purpose:` per entity. No prose narrative. | DBML + per-entity prose: Purpose, Key fields, Relations |
| Flow blocks (doc 04) | Numbered Steps + DoD checklist per flow. Skip Preconditions/Postconditions sections (derivable from steps). Source line still required. | Actor / Trigger + Preconditions + Steps + Postconditions + DoD + Failure handling + Source |
| Decision blocks (doc 05) | 1-paragraph: `D-XXX: title — context in 1 sentence. Decision: <X>. Consequences: <Y, Z>. Source: PRD §...` | Multi-section: Status / Date / Context / Decision / Consequences (✅⚠️ bullets) / Source |
| Glossary (doc 00) | Only product-specific terms from the PRD + acronyms that appear in the vault body. Drop generic IT terms (FK, RTO, RPO, SLO, ADR, NFR) unless they appear in the body. | Full glossary including generic IT terms |
| Open Questions per doc | 1-line: `OQ-{CODE}-{N} [P{1\|2\|3}]: <question> — resolve: <PIC/source>` | Multi-line: question + reasoning + impact + resolution path |
| Sources section | Bullet list, no prose intro. | Same |
| "Note" / "Why X" asides in body | Cut. Reasoning belongs in `05-decisions.md`. | Allowed when it adds context. |
| Cross-ref to other doc | 1 anchor link, no quote duplication. | Inline quote of cited doc allowed. |

**Hard invariants — preserved in BOTH modes:** every claim cites a source (PRD §, Figma frame, uploaded file); every OQ tagged `OQ-{CODE}-{N}` with priority `P1|P2|P3`; every flow has a Definition of Done as an observable checklist; every decision has an explicit source; Out of Scope never empty (`TBD - confirm with PO` if genuinely unknown).

**Audience principle:** `compact` = optimized for builder reading (architect, dev, QA) — tables + DoD + citations, skips narrative scaffolding because the reader knows the domain. `full` = optimized for cross-functional review (PM, BO, legal, compliance + builder) — prose context for non-technical readers, examples for clarity.

**Doc 04 (flows) exception:** `compact` still cuts Preconditions/Postconditions, but Steps + DoD detail stay complete (flow correctness > token saving for QA & implementation); `full` uses full structured blocks per template.

Cut filler. No padding to look thorough. No amputation to look minimal. Output mode adjusts the **granularity of context**, not the completeness of facts.

## Readability standards (mandatory for all 7 files)

**Output language convention** (generated docs match the input PRD language):
- Code-level terms always in English: entity names (`mega_rencana_account`), field names (`source_account_id`), types (`bigint`, `varchar`), enum values (`active | dormant`), HTTP methods, protocol names, framework names.
- Prose narrative in the PRD's language. Don't mix English and the PRD language in one prose sentence except to reference a code term.
- Avoid awkward hybrid phrasing. Indonesian PRD example: ❌ "Status MUST be active" → ✅ "Status harus `active`".
- Avoid direct-translating from AC verbatim: ❌ "Sistem dapat melakukan pembayaran full akumulasi autodebet dan rekening tidak ditutup" → ✅ "Sistem bayar full akumulasi → rekening tetap aktif."

**Anti-AI-tone:** read each paragraph aloud mentally; if it sounds like AI translation or robotic prose, rewrite it in natural conversational tone for the target language. Avoid excessive hedging ("could", "may", "possibly") unless the content is genuinely ambiguous (then it goes to OQs). Use active, short, direct sentences.

**Glossary policy:** first-use acronym/jargon in any doc → define it inline at first occurrence (e.g., "DBML (Database Markup Language)"). `00-index.md` MUST have a **Glossary** for cross-doc terms: DBML, ADR, FK, NFR, RTO, RPO, MPIN, CIF, OTP, SLO, parameterized, plus product-specific PRD terms.

**Cross-reference budget:** max 2 cross-refs to other section/doc per section. If more are needed, inline the essential information or move to an appendix. Cross-refs must be self-contained.

**Date format convention:** `Last updated:` → `YYYY-MM-DD`; decision dates, PRD versions, sprint/milestone refs → `YYYY-MM`.

**Per-doc TL;DR (mandatory header for docs 01–06)** — format depends on `OUTPUT_MODE`:

```markdown
# OUTPUT_MODE=compact (default) — 1 line:
> **TL;DR**: <doc summary> · <primary audience> · <when to read this>.

# OUTPUT_MODE=full — 3 lines:
> **TL;DR**: <one sentence: what this doc contains>.
> **Audience**: <primary reader role, e.g. Architect / Dev / QA / PM>.
> **Read when**: <condition for relevance, e.g. "you're reviewing system structure">.
```

> TL;DR placeholders shown in English for clarity. At runtime, render them in the PRD's language.

## File-by-file content guide (00–06)

### 00-index.md
Required sections, **in this order**:

1. **Project header** — project name + 1-sentence product description.

1.5. **Phase context** — emit immediately after the Project header. generate-intent MUST write this block after the header:

```markdown
## Phase context

**Phase:** <N> of <M>

**This vault covers:** <1-line summary from suggested-phasing.md §Phase N "scope" or "deliverables" — first sentence wins>
```

When `phase_total > 1` AND `N < phase_total`, additionally emit:

```markdown
**Upcoming phases:**
- Phase <N+1>: <1-line from suggested-phasing.md §Phase N+1>
- Phase <N+2>: <1-line from suggested-phasing.md §Phase N+2>
- ...

**To start the next phase** (after this phase's bolts complete):

\`\`\`bash
/mega-sdd:generate-intent --kb=<KB-path> --phase=<N+1>
\`\`\`

**Full phased plan:** `.mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md`
```

When `phase_total == 1` (greenfield / single-phase), omit upcoming phases + next-phase command; emit only:

```markdown
## Phase context

**Phase:** 1 of 1
**Project type:** single-phase (greenfield OR Mode A PRD-driven OR Mode B without legacy-rebuild phasing)
```

Source for "This vault covers": first sentence of the `## Phase N` section in `suggested-phasing.md`. When `suggested-phasing.md` is absent or `phase_total=1` → use "Single-phase project".

2. **Executive Summary** — 3–4 sentences: what + why + current state.
3. **Project Readiness Status** — checklist: PRD (complete/draft/pending); Figma (complete/pending review/not consumed); Tech stack (defined/TBD); Sign-off (X/Y stakeholders); Open Questions count (P1/P2/P3).
4. **Reading paths by role** — Architect: 02 → 03 → 05 → 06; Dev (FE/BE): 02 → 03 → 04; QA: 04 (focus DoD); PM / Business Owner: 00 → 01 → 05.
5. **Reading order** (full sequence with a 1-line purpose per doc).
6. **Anti-hallucination rules** for dev / dev-AI consumers.
7. **Glossary** — cross-doc terms & acronyms. `compact`: only product-specific PRD terms + acronyms in the body (drop FK, RTO, RPO, SLO, ADR, NFR, DBML, DoD, OQ unless used). `full`: full glossary.
8. **Open Questions roll-up** — categorized, sorted P1 → P2 → P3 within each (see roll-up structure below). `compact`: 1-line per OQ; `full`: multi-line per OQ.
9. **Source documents** — files consumed.
10. **Last updated** — YYYY-MM-DD.

### 01-overview.md
- **TL;DR header** · **Product** (2–3 sentences max) · **Target users / personas** (only what the PRD names) · **Problem & motivation** · **Success criteria** (KPIs/metrics — only if the PRD specifies, else → OQs).

### 02-architecture.md
- **TL;DR header** · **System overview** (1-paragraph high-level + text/ASCII diagram, all layers in one view).
- **By component layer** — sub-sections **derived from `PROJECT_SHAPE`** (Step 2). Each role deep-links to its section. Examples: `mobile-app` → `### Mobile / Frontend`, `### Backend`, `### Integrations`; `api-only` → `### Backend`, `### Integrations`; `multi-platform` → `### Web Frontend`, `### Mobile`, `### Backend`, `### Integrations`; `data-pipeline` → `### Source connectors`, `### Processors`, `### Sinks`, `### Integrations`; `custom` → layers from the user's description.
- **API contracts** (only if applicable to the shape): endpoint, method, req/res shape, error code — only what's explicit or directly derivable, else → OQs. Group under the consuming layer. `compact`: table by default (endpoint · method · purpose · auth · errors · source); inline JSON example only for a non-trivial payload. `full`: full request/response JSON per endpoint incl. error envelope.
- **Tech stack** — only what's stated/constrained; group per layer.

> **Why per-layer:** the vault is consumed by multiple roles; per-layer sub-sections let each role anchor directly. Reading paths in `00-index.md` can deep-link to `02-architecture.md#<layer-anchor>`.

### 03-data-model.md
- **TL;DR header** · default format **DBML** (fall back to entity tables if DBML doesn't fit).
- Per entity: name, purpose, key fields + types, mandatory/optional. Relations: 1-1, 1-N, M-N with FK direction. Constraints: uniqueness, indexes, soft-delete, audit fields — only what's specified.
- `compact`: DBML block with inline `note:` per field + max 1 line `Purpose:` per entity; skip the prose "Entity descriptions" section; field-level validation table only for non-obvious constraints (min/max, enum, format). `full`: DBML + per-entity prose (Purpose / Key fields / Relations) + field-level validation table.

### 04-flows.md
> **Exception to the simplicity policy:** this doc is allowed to be reasonably complete.

- **TL;DR header** · **By flow type** — sub-sections **derived from `PROJECT_SHAPE`**. Examples: `mobile-app` → `### User flows (mobile-facing)`, `### Backend / system flows`, `### Cross-cutting flows`; `api-only` → `### Backend / system flows`, `### Consumer-facing flows`; `multi-platform` → `### User flows (web)`, `### User flows (mobile)`, `### Backend / system flows`, `### Cross-cutting flows`; `data-pipeline` → `### Pipeline flows`, `### Error/recovery flows`, `### Operational flows`; `custom` → categories from the user's description.
- For each flow: numbered steps (reference Figma frame if available); **per-flow Definition of Done** (observable behavior, bullet list — **required in BOTH modes**, it's the QA contract; never cut). `compact`: skip Preconditions/Postconditions (derivable from steps + DoD); skip Failure handling unless the failure path is non-trivial; steps stay detailed. `full`: full structured blocks (Actor, Preconditions, Steps, Postconditions, DoD, Failure handling, Source).
- **Staged inputs (multi-step workflows) — PRESERVE, never flatten.** When the source is a KB workflow domain (`--kb` mode) whose `## 3a. Staged inputs` carries a `stages:` block, copy that block **verbatim** into this flow's `**Stages**` block, emit the matching Mermaid `stateDiagram`, and stamp the flow with `_kb_source: [20-workflows/<file>.md]` (the deterministic back-reference `validate-vault-flow-staging.sh` follows to prove staging was not dropped). Do NOT collapse the staged fields into one flat input list / single form — that destroys the multi-step wizard intent (the captured trade-finance regression). The flat **Steps** narrative MAY remain for readability, but the `stages:` block is authoritative. (No `--kb`? If the PRD itself describes a multi-step / maker-checker flow, author the `**Stages**` block from the PRD and omit `_kb_source`.) See `generate-intent/references/vault-contract.md §stages-propagation`. Surface the count in the handoff as `metrics.flows_with_stages`.
- For cross-cutting flows (or any multi-layer flow), explicit handoff points: e.g. "Mobile sends to BE → BE responds → Mobile renders". **Required in BOTH modes.**

> **Why per-type:** same rationale as `02-architecture.md` — multiple consumers, deep-link navigation. QA uses the DoD per flow; layer-specific devs focus on their flow type.

### 05-decisions.md
- **TL;DR header** · format depends on `OUTPUT_MODE`:

```markdown
# OUTPUT_MODE=compact (default) — 1 paragraph per ADR:
### D-001: <short title>
<Context in one sentence>. **Decision**: <what was decided, 1–2 sentences>. **Consequences**: <pros + tradeoffs, comma-separated, max 2 lines>. **Source**: <PRD §X>.

# OUTPUT_MODE=full — multi-section per ADR:
### D-001: <short decision title>
**Status**: Proposed | Accepted | Superseded by D-XXX
**Date**: YYYY-MM
**Context**: <why this decision is needed, 2–3 sentences>
**Decision**: <what was decided, 1–3 sentences>
**Consequences**:
- ✅ <positive>
- ⚠️ <trade-off>
**Source**: <PRD §X / explicit user instruction / meeting note>
```

Only decisions with an explicit source. PRD silent → not an ADR; it's an Open Question. Applies in both modes.

### 06-constraints.md
- **TL;DR header** · **Technical constraints** (stack lock-ins, infra limits, integration boundaries) · **Business constraints** (timeline, budget, regulatory, compliance, contractual) · **NFR** (performance, scalability, security, availability, observability — only what the PRD/stakeholder states).

## Mandatory section template (every doc 01–06)

Append at the bottom of every numbered doc:

```markdown
---

## Sources
- PRD §X.Y (page Z)
- Figma: <frame-name or URL fragment>
- <other inputs>

## Out of Scope
- <explicit non-goals>
- <if unknown: "TBD - confirm with PO">

## Open Questions
- [ ] **OQ-{DOC_CODE}-{N}** [P{1|2|3}]: <ambiguity, with what's needed to resolve it>
- [ ] **OQ-{DOC_CODE}-{N+1}** [P{1|2|3}]: <next ambiguity>
```

**Open Question tagging convention:** see `generate-intent/references/vault-contract.md §OQ-conventions` for the tag format, doc-code table, and priority definitions. Every Open Question generated by this skill MUST follow that convention.

## 00-index.md Open Questions roll-up structure

The roll-up aggregates all OQs from docs 01–06. Categorize by topic (not by doc), with the category's overall priority as the section header; within each category sort P1 → P2 → P3.

```markdown
## Open Questions roll-up

> Total: **{N} Open Questions** across 6 docs. Sorted by category, then P1 → P2 → P3 within each category.

### {Category 1 — e.g. "PRD inconsistencies"} (PRIORITY-1)
- [ ] **OQ-DM-1** [P1]: <text> `[03-data-model.md]`
- [ ] **OQ-FL-1** [P1]: <text> `[04-flows.md]`

### {Category 2 — e.g. "Tech stack & architecture"} (PRIORITY-1)
- [ ] **OQ-AR-1** [P1]: <text> `[02-architecture.md]`
...
```
