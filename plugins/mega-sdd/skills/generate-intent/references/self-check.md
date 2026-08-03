# generate-intent — Self-check, Present & push-back matrix (Steps 4–5)

## Contents
- Step 4 — Self-check before delivery
- Step 5 — Present
- When to push back on the user (full matrix)

## Step 4 — Self-check before delivery

Verify every doc has:

**Grounding & anti-halu:**
- [ ] No invented entities, fields, endpoints, decisions, or behaviors. Every claim can be cited to PRD/Figma/uploaded docs.
- [ ] **Sources** section filled (cite PRD section, Figma frame, or other input).
- [ ] **Out of Scope** section filled (write `TBD - confirm with PO` if genuinely unknown — never leave empty).
- [ ] **Open Questions** section filled. Tagged `OQ-{DOC_CODE}-{N}` + prioritized P1/P2/P3.

**Readability (architect/PM/QA review-ready):**
- [ ] **TL;DR header** present in every doc 01–06. Format: 1-line if `OUTPUT_MODE=compact`, 3-line if `OUTPUT_MODE=full`.
- [ ] Output language convention consistent — code-level terms in English (entity names, field names, types, enum values, HTTP methods, framework names); prose narrative in PRD language. Avoid mixing English and PRD language in the same prose sentence except for code-term references.
- [ ] Read-aloud test: the first paragraph of each doc does not sound like AI translation.
- [ ] First-use acronym/jargon defined inline; cross-doc terms are in the Glossary at `00-index.md`.
- [ ] Cross-ref ≤ 2 per section.
- [ ] `00-index.md` has: Executive Summary, Project Readiness Status, Reading paths by role, Glossary, OQ roll-up.

**Output mode compliance (driven by `OUTPUT_MODE` from Step 0.7):**
- [ ] If `compact`: TL;DR header is 1-line in docs 01–06.
- [ ] If `compact`: API contracts use the table format; full request/response JSON only appears for endpoints with non-trivial payload (nested struct / polymorphic shape).
- [ ] If `compact`: doc 03 entity descriptions dropped — DBML block + 1-line `Purpose:` per entity is enough.
- [ ] If `compact`: doc 04 Preconditions/Postconditions sections cut; Steps + DoD remain detailed.
- [ ] If `compact`: doc 05 ADRs use the 1-paragraph format, not the multi-section block.
- [ ] If `compact`: OQ entries are 1-line, not multi-line elaboration.
- [ ] Glossary (BOTH modes — the drop is unconditional): product-specific PRD terms only + the pointer line to `_meta/ai-consumer-guide.md` §Standard terms; generic/standard rows never re-emitted.
- [ ] If `full`: every section per template scaffold is filled, including prose narrative, JSON examples, multi-bullet consequences.

**Anti-halu invariants (mandatory in BOTH modes — never cut even in compact):**
- [ ] Every claim cites source.
- [ ] Every OQ tagged & prioritized.
- [ ] Every flow has a DoD checklist.
- [ ] Every decision has explicit source.
- [ ] Out of Scope section never empty.
- [ ] Cross-cutting flow handoff points present.
- [ ] Every OQ carries `category` + (if tech) `resolution_mode` + `classification_confidence`.
- [ ] Every `recommend`-mode OQ has at least one `scan_citations` entry; no fabricated citations.
- [ ] `00-index.md` has `## Auto-Classification Review` section listing tech-tagged OQs + medium/low confidence cases.
- [ ] **`constitution.md`** (the 8th file): exists unless `--no-constitution`, and **every `X-NNN` clause cites a source** (`§` / `(source: …)` / a KB/PRD anchor / a `file:line` / a link). An uncited clause is a defaulted or invented rule — demote it to an Open Question, never ship it (it would become a BLOCKING Hard rule at execute-bolts). This mirrors the deterministic `validate-constitution.sh` per-clause check.

**Each doc must be readable in <10 minutes by an architect (BOTH modes).**

**Output integrity:**
- [ ] All files written to `<OUTPUT_DIR>` (not the default sandbox path).
- [ ] Folder structure matches the 7-file spec.
- [ ] Language matches source (PRD ID → docs ID; PRD EN → docs EN).

**`vault.json` manifest (script-derived — never hand-checked field-by-field):**
- [ ] `derive-vault-json.sh` ran at Step 3.8 (the single derive, AFTER constitution/classifier/advisor completed) and printed its `PASS: derived vault.json (…)` line (the structural arrays, summary, Vault Lock enums, and constitution pin are the SCRIPT's job — a hand-written vault.json is an authoring bug).
- [ ] The counts in the PASS line (`E entities, F flows, A adrs, Q oqs`) match the doc counts you generated (DBML `Table` blocks, `F-*-NNN` headings, `D-NNN` headings, checkbox OQs).
- [ ] The authored patch carried every field the model owns: metadata + `source_documents` + `design_system_flags` (matching the Step 3 conditional-generation values) [+ `design_system`] [+ scope block] + the per-OQ recommend/scan records (Step 3.5) + the advisor provenance record (Step 3.7) — the validator's `oq_recommend_underspecified` is the tripwire for a recommend-OQ whose JSON-only fields went missing.

**Consumer guide & implementation notes (P2a — the guide is the sole carrier of the generic protocol):**
- [ ] `<OUTPUT_DIR>/_meta/ai-consumer-guide.md` exists (the `copy-consumer-guide.sh` Run in Step 3 installed it — script-copied, never model-rendered).
- [ ] `00-index.md` Implementation Notes carries the `_meta/ai-consumer-guide.md` pointer and does NOT restate the halt-YAML examples — a `blocker:` / `resolver_route:` fence in 00-index is a regression (the halt protocol, parallel-work guidance, and companion-skills routing live in the guide only).
- [ ] `00-index.md` Glossary carries product-specific terms only + the pointer to the guide's Standard-terms table — no re-emitted generic rows (ADR/DBML/DoD/FK/NFR/OQ/RTO/RPO/SLO or design-system terms).

**Design-system grounding (only if any design-system section appears):**
- [ ] Section presence justified — `02-architecture#ui-components` exists ⇒ `HAS_UI_COMPONENTS = true` from Step 2; `06-constraints#design-system` exists ⇒ at least one of `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND` is `true`.
- [ ] Components table cites source per row (Figma frame name / tokens file path / PRD §). No invented components.
- [ ] Tokens table cites source per row. No invented hex values, type scales, spacing values, radius values.
- [ ] Patterns prose grounded in PRD note / Figma annotation / explicit user instruction. No best-practice insertions (no defaulted WCAG levels, no defaulted "max 1 CTA per screen" rules unless source explicitly states).
- [ ] Within an appearing section, sub-elements the source is silent on become `OQ-AR-{N}` or `OQ-CN-{N}` — not body.
- [ ] No design-system content appears in vault that did not originate from a cited source.

## Step 5 — Present

Files are already on disk under `<OUTPUT_DIR>` (written in Step 3). Step 5 is a chat-only summary:

- **Claude Code:** no special tool needed — files are accessible via filesystem. Summarize in chat with the absolute path so the user can open them.
- **Claude.ai sandbox:** use `present_files` to surface the folder in the UI.

In the chat message:

1. Summary: total docs, total Open Questions count, `PRD_STATUS` + `OUTPUT_MODE` flag values.
2. **List of Open Questions (top blockers)** — what the user must resolve before dev starts. If `PRD_STATUS=final`, frame it as: *"Take this OQ list to your stakeholders for offline triage."*
3. Brief note on which sections are most likely to need stakeholder review.
4. Path to the vault: `<OUTPUT_DIR>` (absolute).
5. If `OUTPUT_MODE=compact`, mention once that a prose-rich version is available: *"Re-run with `OUTPUT_MODE=full` if you need the prose-rich version for non-technical readers."*
6. **Suggested next steps** — point to companion skills:
   - *"After stakeholder triage, run `resolve-oq` to walk the OQ list interactively and capture answers back into the vault."*
   - If `PRD_STATUS=final` and OQ count > 10: *"Bring the P1 list to a stakeholder meeting first; resolve-oq picks up from current state when you re-run."*
   - If `IMPLEMENTATION_MODE=existing`: *"Run `detect-drift` to reconcile this vault against the live codebase — flags entity/flow/decision drift between target and current reality."*
   - When the PRD eventually revises: *"Use `diff-vault` to evolve the vault against the new PRD without losing resolved OQs or ADR history."*

Do NOT pad with "I have created..." preamble. Just deliver and surface blockers.

## When to push back on the user (full matrix)

Push-back rules are **conditional on `PRD_STATUS`** (set in Step 0.6).

### Always (regardless of PRD_STATUS)
- Figma URL given but no MCP and no screenshots → ask. Never invent UI structure.
- User says "just guess the rest" → refuse politely. The whole point of this skill is to NOT guess. Offer to mark unknowns as Open Questions instead. `PRD_STATUS=final` does NOT license invention — it only changes whether the skill pauses to ask the stakeholder, not whether Claude can fill in blanks.
- Path mismatch with environment (alien path) → reject per Step 0 rules.
- Output folder exists and non-empty → ask before overwriting.

### Only when `PRD_STATUS=draft`
- Inputs missing critical sections (e.g. no flows in the PRD) → ask before generating.
- PRD is contradictory → surface contradictions in chat, ask which version is canonical, wait for resolution.
- Gap count > 10 → ask whether to proceed or get clarification first.

### Only when `PRD_STATUS=final`
- Do NOT pause for any of the three `draft` cases above. PRD is locked, stakeholder is unavailable for synchronous clarification.
- Missing sections, contradictions, large gaps → all funnel into the Open Questions roll-up with full context (quotes from the PRD, what's missing, what would resolve it).
- For contradictions specifically: write the OQ as `OQ-{DOC}-{N} [P1]: PRD inconsistency — §X.Y says "<quote A>" but §X.Z says "<quote B>". Need stakeholder ruling on which is canonical.`
- Surface in the Step 5 summary: total OQ count + reminder that the user must triage with the stakeholder before dev starts.

### Design-system absence is acceptable (no push-back)
Design-system content is **auxiliary**. Source silence on tokens, UI components, a11y, or brand voice is allowed and produces vault output without those sections. The skill MUST NOT:
- Prompt the user "do you have a Figma URL / tokens file / Storybook export?"
- Default to industry standards (WCAG 2.1 AA, Material Design, iOS HIG, Tailwind defaults).
- Generate placeholder Open Questions for missing design-system content.

If the user explicitly mentions a design system in conversation but didn't upload a source, treat that as a regular request for clarification (one chat question), not a workflow gate. Otherwise stay silent.
