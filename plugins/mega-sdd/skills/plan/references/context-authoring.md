# plan — context.md authoring rules (Step 3) + self-check (Step 7)

> Relocated from `skills/generate-intent/references/generation-guide.md`, `skills/generate-intent/references/self-check.md`, `skills/generate-intent/SKILL.md` (§OQ classification) and `skills/bind-codebase/SKILL.md` (§Procedure Step 2) in 9.0 (P1); tuned text kept verbatim.

Loaded by `plan/SKILL.md` at Step 3 (writing `context.md` + `constitution.md`) and Step 7 (self-check). The layout-3 shape (the four hard-header H2 anchors, the optional H2s, the forbidden H2s, the OQ line grammar) is carried by `plan/references/templates/context.md`; this file carries only the content rules the template does not. OQ tags, the classifier table, the `vault.json` schema and the constitution schema are owned by `plugins/mega-sdd/references/vault-core.md`. Nothing here loosens a rail.

## Contents
- Project constitution gate (multi-PRD lifecycle)
- Hard invariants
- Readability standards (mandatory for `context.md`)
- Operator-workflow-UX capture + Design-Source OQ
- OQ classification — `recommend` fields, validation gate, memoization
- Project scale xs
- Step 7 — self-check before delivery

## Project constitution gate (multi-PRD lifecycle)

- **Project constitution gate (multi-PRD lifecycle).** Before writing a NEW vault's claims into `context.md` (Step 3), read `.mega-sdd/constitution.md` (project-scope locked rules inherited by every vault, per `plugins/mega-sdd/references/multi-prd-lifecycle.md`) if present. Any PRD claim that contradicts a project-locked clause (e.g. a new PRD proposes a different datastore than the project locks) is a **`[P1] [business]` Open Question** (`resolution_mode: blocking` — a source-vs-locked-rule contradiction is the business class, never an AI pick: `plugins/mega-sdd/references/vault-core.md §AI technical decisions`) at this gate — the OQ text names the locked clause id next to the PRD quote, it joins the Step-6 batched ask, and it is surfaced, never silently accepted. This is what keeps PRD 2..N inline with PRD 1's shipped decisions. Absent file = no project-scope layer = unchanged behavior.

## Hard invariants

**Hard invariants — never cut:** every claim cites a source (PRD §, Figma frame, uploaded file); every OQ tagged `OQ-{CODE}-{N}` with priority `P1|P2|P3`; every flow has a Definition of Done as an observable checklist; every decision has an explicit source.

## Readability standards (mandatory for `context.md`)

**Output language convention** (generated docs match the input PRD language):
- Code-level terms always in English: entity names (`mega_rencana_account`), field names (`source_account_id`), types (`bigint`, `varchar`), enum values (`active | dormant`), HTTP methods, protocol names, framework names.
- Prose narrative in the PRD's language. Don't mix English and the PRD language in one prose sentence except to reference a code term.
- Avoid awkward hybrid phrasing. Indonesian PRD example: ❌ "Status MUST be active" → ✅ "Status harus `active`".
- Avoid direct-translating from AC verbatim: ❌ "Sistem dapat melakukan pembayaran full akumulasi autodebet dan rekening tidak ditutup" → ✅ "Sistem bayar full akumulasi → rekening tetap aktif."

**Anti-AI-tone:** read each paragraph aloud mentally; if it sounds like AI translation or robotic prose, rewrite it in natural conversational tone for the target language. Avoid excessive hedging ("could", "may", "possibly") unless the content is genuinely ambiguous (then it goes to OQs). Use active, short, direct sentences.

**Placement discipline:** Every generated artifact leads with its densest load-bearing content — TL;DR, verdict/OQ counts, markers, citations, DoD, hard constraints — and pushes exposition, glossary, and append-only history to the tail. LLM consumers weight the start and end of a document most; the middle is the weakest position. Never let a growing history section or generic boilerplate occupy the opening region, and never dilute a load-bearing table with narrative between its header and its rows. Summaries with counts go first; anything a reader could skip goes last.

**Inline first-use definitions:** first-use acronym/jargon in any doc → define it inline at first occurrence (e.g., "DBML (Database Markup Language)"). `context.md` carries no `## Glossary` (layout-3 forbids the H2); the generic rows (ADR, DBML, DoD, FK, NFR, OQ, RTO, RPO, SLO, or the design-system terms) ship in the static `_meta/ai-consumer-guide.md` §Standard terms (installed by the Step-3 `cp` of the shipped template) and are never re-emitted.

**Cross-reference budget:** max 2 cross-refs to other section/doc per section. If more are needed, inline the essential information or move to an appendix. Cross-refs must be self-contained.

**Date format convention:** `Last updated:` → `YYYY-MM-DD`; decision dates, PRD versions, sprint/milestone refs → `YYYY-MM`.

**TL;DR (mandatory: the `context.md` header)** — the shape is the one in `plan/references/templates/context.md` (`> **TL;DR**: …` + `> **Read when**: …`); `output_mode` is `compact` on layout-3.

> TL;DR placeholders shown in English for clarity. At runtime, render them in the PRD's language.

## Operator-workflow-UX capture + Design-Source OQ

> `validate-vault-oqs.sh` runs under `analyze` (the `vault_oqs` family) and surfaces a capture-stage miss as **advisory** — it never blocks `mega-sdd:execute-bolts`. At plan Step 5 (row 6) the same validator exits 1 on these findings — fix them there. This prose is the real win — get it right at generation time.

**Rule 1 — model the operator surface when the flows show a workflow.** When the flows in `context.md ## Flows` exhibit a **maker-checker / multi-stage-approval / workflow** pattern (a user-facing flow with a maker→checker actor hand-off chain, OR ≥2 distinct decision transition steps — approve / reject / review / confirm), model the operator-facing surface as **FIRST-CLASS requirements GROUNDED in the flows** — never invented:

- **Worklist / inbox** — where each actor (checker, confirmer, …) finds the items awaiting *their* decision, filtered by role + current workflow state.
- **Decision affordance** — the approve / reject (and any return-to-prior-stage) actions available to the actor in the entity's current state.
- **Human-readable state labels** — a label map from the raw `workflow_state` enum to operator-facing text (e.g. `SUBMITTED` → "Awaiting Checker").
- **Audit timeline** — the append-only transition history rendered for the operator (who acted, when, prior → next state).

Capture these in `context.md ## Flows` (the workflow flow's Mermaid + Definition of Done — the validator scans the whole `context.md`). **Grounded, not invented:** every operator-surface requirement must trace to a flow step / actor / state in `context.md ## Flows`. If the surface design is genuinely undecided, capture it as an OQ instead of inventing it (Rule 2). The validator FAILs with `operator_surface_missing` when a workflow flow exists but the vault models no operator surface AND carries no Design-Source OQ.

> **Same workflow-flow signal also governs staging.** The maker→checker / multi-stage pattern that triggers operator-surface modeling here is also the staged-input pattern: if the source KB workflow carries a `## 3a` `stages:` block, PRESERVE it verbatim into this flow's `**Stages**` block + `_kb_source` per the staged-only rule of `context.md ## Flows` (`plugins/mega-sdd/references/vault-core.md §stages-propagation`). Modeling the operator surface and preserving the staging are two halves of the same workflow fidelity — don't do one and flatten the other.

**Rule 2 — design system: template-first, then recommend, never a defaulted value.** When `HAS_UI_COMPONENTS = true` (UI components exist) but `HAS_TOKENS`, `HAS_A11Y`, and `HAS_VOICE_BRAND` are **all `false`** (no design source in PRD/Figma/KB), resolve the design system by **precedence** — never by silently defaulting WCAG levels, Material/Tailwind palettes, spacing scales, or brand voice from prior knowledge. (These three flags reflect the **PRD/Figma/KB source only**; a scanned starterkit is a SEPARATE input, evaluated in path 1 below — so this rule still fires when the PRD has no design source even though a template was scanned.)

1. **Scanned template wins (source: `scanned-template`).** If a starterkit was scanned and `starterkit-context.yaml §ui_ux` supplies a design system (`design_tokens` / `layout_extends` / `idioms`), DERIVE `design_system` from the template — its flow is authoritative. **ui-ux-pro-max does NOT recommend a style here; it must not override or contradict the template.** Emit a Design-Source OQ ONLY for a genuine gap the template is silent on (e.g. a missing chart palette), and that gap-fill OQ must align with template idioms. Write `design_system` with `source: scanned-template`, `provenance` citing the `starterkit-context.yaml §ui_ux` anchor.

2. **Greenfield — recommend (source: `design-intelligence-recommend`).** ONLY when there is no scanned template design system (true greenfield), emit a single high-priority **Design-Source Open Question** `OQ-DESIGN-SOURCE-{N} [P1] [business]` (`resolution_mode: blocking`). **A design system with no source is a STAKEHOLDER decision, never an AI technical decision** — the AI must not pick the style / palette / typography / WCAG level (the "no defaulted standards" rail), and `validate-vault-oqs.sh` FAILs one that does (`oq_decided_business_signal`). The map pick below is carried ONLY as the recommendation the stakeholder sees in slot `[1]` of the ask (NOT a silent default — see `plugins/mega-sdd/references/vault-core.md §Updated vault.json OQ schema`). Consult `plugins/mega-sdd/references/design-intelligence/product-style-map.yaml` using PRD signals (product type, industry, brand hints):
   - `recommendation`: the chosen `{style, palette, typography, a11y_level}` from the matched `product-style-map` entry (the map key is `a11y_baseline` — write it into the vault as `a11y_level`).
   - `rationale`: the PRD signal → matched map key (e.g. "product_type=SaaS dashboard (PRD §1) → product-style-map.yaml#saas-general").
   - `scan_citations`: `["plugins/mega-sdd/references/design-intelligence/product-style-map.yaml#<key>", "<PRD §>"]` — **never fabricate**; if no map entry matches, the OQ simply carries no recommendation (the ask shows "no recommendation — needs the PO").
   - `fallback_if_wrong`: "blocking — request an explicit design source from the PO".
   Only when the user accepts is the `design_system` block written (with `source: design-intelligence-recommend`).

In both cases the `design_system` block (`plugins/mega-sdd/references/vault-core.md §design_system`) is written into the authored patch (it lands in `vault.json` via `derive-vault-json.sh`) + the `context.md ## Constraints > ### Design system` section, each line cited to its source. The validator still FAILs with `design_source_oq_missing` when UI components exist with all three design flags false and **no** Design-Source OQ (`[business]`, with or without a carried recommendation) is present AND no scanned-template design system was derived.

## OQ classification — `recommend` fields, validation gate, memoization

Runs on every OQ in `context.md ## Open Questions` at Step 3, after the heuristic table in `plugins/mega-sdd/references/vault-core.md §Auto-classifier heuristics` has set `category` / `resolution_mode` / `classification_confidence`.

### `recommend` mode — the four fields + write it DECIDED

**For `resolution_mode: recommend`:** populate the four required fields:
- `recommendation` — Claude's pick (1–2 sentences).
- `rationale` — why this pick; what trade-off was considered (2–3 sentences).
- `scan_citations` — at least 1 entry naming the BASIS of the pick: a codebase anchor (`app/Http/Resources/ErrorResource.php:12`), a pack section (`pack:laravel §Error handling`), current library docs (`docs:<library>@<version>` via the bundled context7 — never the ONLY basis: pair it with a verifiable citation such as the manifest line that pins that library or the PRD constraint), a KB section, or the PRD constraint it satisfies (`PRD §6.3`). If no exact match exists, cite the closest pattern with a "no exact match; closest: …" note.
- `fallback_if_wrong` — what to revisit if this pick turns out incorrect (1 sentence).
- **Anti-halu rail:** NEVER fabricate citations. No codebase (greenfield) is NOT a reason to ask a human — pick per the order in `plugins/mega-sdd/references/vault-core.md §AI technical decisions` and cite the pack / docs / PRD constraint. Only a question whose answer is a FACT no source contains is re-tagged `category: business` with the note "fact absent from every source; only a human knows."
- **Write it DECIDED:** the OQ line is `[x]` with `→ **Resolved v{X.Y}** (AI decision, <date>): <the recommendation, one line>`. A tech OQ is never left open for a human and never asked (`plugins/mega-sdd/references/vault-core.md §AI technical decisions`).

### Validation gate

**Validation gate:** before the Step-6 ask, validate every OQ entry per `plugins/mega-sdd/references/vault-core.md §Validation rules` — after `derive-vault-json.sh` has run (Step 5 row 5), **Run** `bash <plugin-root>/scripts/validate-vault-oqs.sh --cwd=<root> --file-path=<vault>/context.md --strict-tech` (Step 5 row 6) and read its exit code directly (never through a pipe):
- Tech OQ missing `resolution_mode` → halt `oq_tech_missing_mode`.
- `recommend` OQ missing any of `recommendation`, `rationale`, `scan_citations`, `fallback_if_wrong` → halt `oq_recommend_underspecified`.
- `scan` OQ missing `scan_query` → halt `oq_scan_missing_query`.
- Tech OQ left open in `recommend` / `blocking` mode (layout-3: `scan` too — no bind phase follows) → `oq_tech_undecided`: decide it (§`recommend` mode above) or, when it is a missing fact, re-tag it `[business]`.
- An AI-decided OQ that reads as business / regulated / `[LOCKED]` / source-vs-code contradiction → `oq_decided_business_signal`: re-open it, drop the annotation, tag it `[business]`.

### Memoization (re-runs over an existing vault)

- **Memoization (re-runs over an existing vault — `plan --regenerate`):** when the vault already carries a classification for an OQ whose TEXT is unchanged (exact match against the existing `vault.json` entry), REUSE it verbatim — re-classify only new or text-changed OQs. An existing vault classification IS the record of any human correction — reuse-verbatim protects it (never silently overwrite a human-edited bracket).

## Project scale xs

Set by Step 0 from `derive-plan-pins.sh` (→ `scripts/derive-project-scale.sh`; a deterministic structure count, never judgment). At `project_scale: xs` exactly ONE thing changes in `context.md`; nothing else: every P2 `[business]` OQ is born `**Deferred (plan)**:` (never asked; resurfaced in the report — `plan/references/plan-procedure.md §Step 3`). Every other section keeps its normal rules: the conditional sections (`HAS_*` design blocks) are already source-gated and the four hard-header H2 anchors stay mandatory.
Tech OQs need no xs carve-out: at EVERY scale they are decided by the AI at Step 3 (`plugins/mega-sdd/references/vault-core.md §AI technical decisions`) — a decision, not a deferral, so nothing resurfaces later as debt.

The target class: a "3 static screens" PRD stops producing a wall of interactive questions — OQ COUNT is unchanged (honesty), the interactive ceremony shrinks. `xs` can only ever come from structural evidence in the source document; absent/unparseable structure means `standard`.

## Step 7 — self-check before delivery

Applied to `context.md` + `constitution.md` after the Step-7 verdict table (`plan/references/plan-procedure.md §Step 7`). Verify:

**Grounding & anti-halu:**
- [ ] No invented entities, fields, endpoints, decisions, or behaviors. Every claim can be cited to PRD/Figma/uploaded docs.
- [ ] **Open Questions** — ALL in `context.md ## Open Questions`, each tagged `OQ-{DOC_CODE}-{N}` + prioritized P1/P2/P3 (an OQ checkbox in any other section fails the derive).
- [ ] **Project constitution gate** — when `.mega-sdd/constitution.md` exists, no PRD claim that contradicts a project-locked clause went into the body; each is a `[P1] [business]` OQ (§Project constitution gate).

**Readability (architect/PM/QA review-ready):**
- [ ] **TL;DR header** present at the top of `context.md` (shape per `plan/references/templates/context.md`).
- [ ] Output language convention consistent — code-level terms in English (entity names, field names, types, enum values, HTTP methods, framework names); prose narrative in PRD language. Avoid mixing English and PRD language in the same prose sentence except for code-term references.
- [ ] Language matches source (PRD ID → docs ID; PRD EN → docs EN).
- [ ] Read-aloud test: the first paragraph of each doc does not sound like AI translation.
- [ ] First-use acronym/jargon defined inline (layout-3 carries no `## Glossary`; the generic rows live in `_meta/ai-consumer-guide.md` §Standard terms).
- [ ] Cross-ref ≤ 2 per section.

**Anti-halu invariants (mandatory — never cut):**
- [ ] Every claim cites source.
- [ ] Every OQ tagged & prioritized.
- [ ] Every flow has a DoD checklist.
- [ ] Every decision has explicit source.
- [ ] Cross-cutting flow handoff points present.
- [ ] Every OQ carries `category` + (if tech) `resolution_mode` + `classification_confidence`.
- [ ] Every `recommend`-mode OQ has at least one `scan_citations` entry; no fabricated citations.
- [ ] **No tech OQ is left for a human:** every `[tech / recommend]` OQ is `[x]` + `→ **Resolved v{X.Y}** (AI decision, <date>): <pick>`; no `[tech / blocking]` bracket exists; every AI-decided OQ is genuinely technical (no scope / limit / money / retention / regulation / edge-case / `[LOCKED]` / PRD-vs-repo contradiction) — `validate-vault-oqs.sh --strict-tech` exits 0.
- [ ] `context.md` has the `## AI Technical Decisions` table when any tech OQ was decided (one row per decision, P1 first); the section is omitted when nothing was decided.
- [ ] **`constitution.md`** (the additional vault file): exists unless `--no-constitution`, and **every `X-NNN` clause cites a source** (`§` / `(source: …)` / a KB/PRD anchor / a `file:line` / a link). An uncited clause is a defaulted or invented rule — demote it to an Open Question, never ship it (it would become a BLOCKING Hard rule at execute-bolts). This mirrors the deterministic `validate-constitution.sh` per-clause check.

**Each doc must be readable in <10 minutes by an architect.**

**`vault.json` manifest (script-derived — never hand-checked field-by-field):**
- [ ] `derive-vault-json.sh` ran at Step 3 (the single authoring derive, AFTER constitution/classifier completed) and printed its `PASS: derived vault.json (…)` line (the structural arrays, summary, Vault Lock enums, and constitution pin are the SCRIPT's job — a hand-written vault.json is an authoring bug).
- [ ] The counts in the PASS line (`E entities, F flows, A adrs, Q oqs`) match the doc counts you generated in `context.md` (DBML `Table` blocks, `F-*-NNN` headings, `D-NNN` headings, checkbox OQs).
- [ ] The authored patch carried every field the model owns: `source_documents` + `design_system_flags` (matching the Step 2 detection values) [+ `design_system`] [+ scope block] + the per-OQ recommend/scan records (Step 3 OQ classification) — the pins come from the frontmatter, never the patch (`plan/references/plan-procedure.md §Step 3`). The validator's `oq_recommend_underspecified` is the tripwire for a recommend-OQ whose JSON-only fields went missing.

**Consumer guide (the guide is the sole carrier of the generic protocol):**
- [ ] `<vault>/_meta/ai-consumer-guide.md` exists (the Step-3 `cp` Run installed it — copied from the shipped template, never model-rendered).
- [ ] `context.md` does NOT restate the halt-YAML examples — a `blocker:` / `resolver_route:` fence in `context.md` is a regression (the halt protocol, parallel-work guidance, and companion-skills routing live in the guide only).

**Design-system grounding (only if any design-system section appears):**
- [ ] Section presence justified — `context.md ## Constraints > ### Design system` exists ⇒ at least one of `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND` is `true` from Step 2.
- [ ] Components table cites source per row (Figma frame name / tokens file path / PRD §). No invented components.
- [ ] Tokens table cites source per row. No invented hex values, type scales, spacing values, radius values.
- [ ] Patterns prose grounded in PRD note / Figma annotation / explicit user instruction. No best-practice insertions (no defaulted WCAG levels, no defaulted "max 1 CTA per screen" rules unless source explicitly states).
- [ ] Within an appearing section, sub-elements the source is silent on become `OQ-AR-{N}` or `OQ-CN-{N}` — not body.
- [ ] No design-system content appears in vault that did not originate from a cited source.
