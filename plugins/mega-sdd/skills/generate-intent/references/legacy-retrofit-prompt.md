# Legacy PRD Retrofit Prompt Template

When generate-intent encounters a PRD without `scopes:` frontmatter, dispatches an AI subagent with this prompt template. Subagent analyzes PRD content + proposes canonical retrofit.

## Contents

- Subagent dispatch contract
- Prompt template
- Main thread post-processing
- Low-confidence handling
- Anti-halu rails
- Backward compatibility

## Subagent dispatch contract

Main thread `generate-intent` invokes subagent via Agent tool with the prompt below. Subagent returns structured analysis. Main thread renders diff to user; on accept, writes retrofit file.

## Prompt template

```
ROLE: PRD scope analyst.

CONTEXT:
- PRD path: <absolute path>
- PRD content (verbatim follows after delimiter):
- Industry context (if known): <from frontmatter `industry` if any, else "unknown">
- cwd of architect (smart default hint): <basename>

TASK:
1. Read entire PRD carefully.
2. Detect scope indicators using these patterns (priority order):
   a. Section headers mentioning Backend / Frontend / Middleware / Mobile / API
   b. Tech stack mentions (Laravel + Vue + Go suggests 3 scopes)
   c. Role/stakeholder mentions (Backend Lead, FE Architect, etc.)
   d. Cross-references (e.g., "BE will provide API; FE will consume")
   e. Indonesian variants (Sisi Server, Sisi Klien, Layer Integrasi)
3. For each detected scope:
   - Assign confidence: HIGH (≥3 indicators), MEDIUM (1-2 indicators), LOW (inferred only)
   - Cite EVIDENCE — specific line numbers + quoted text
   - Propose which existing PRD sections belong to this scope
4. Propose canonical frontmatter (per `generate-intent/references/scope-picker.md` schema)
5. Propose section restructure — preserve original content; add scope headers where missing

DISCIPLINE (non-negotiable):
- NEVER invent scope evidence. If unclear → LOW confidence + flag as ambiguous.
- NEVER discard PRD content. Restructure only renames/reorganizes headers; body content preserved verbatim.
- Universal sections (overview, glossary, business rules global) → keep at top, not assigned to any scope.
- If PRD genuinely single-scope (e.g., backend-only) → output ONE scope with confidence HIGH, frontmatter shows just that scope.

OUTPUT FORMAT (exact YAML structure, no prose preamble):

---
analysis:
  detected_scopes:
    - id: <ScopeId, e.g., BE>
      name: "<Display name>"
      confidence: HIGH | MEDIUM | LOW
      evidence:
        - "Line <N>: '<quoted text>' (indicator: <pattern matched>)"
        - "Line <N>: '<quoted text>' (indicator: <pattern matched>)"
      proposed_sections:
        - original: "§<N> <header>"
          renamed: "§<Scope>.<N> <header>"
    - id: <next scope>
      ...

  proposed_frontmatter: |
    title: "<inferred title>"
    type: PRD
    version: "<original or 0.9-retrofit>"
    status: <inferred or 'unknown'>
    date: <today>
    authors: ["<inferred from header/footer>"]
    industry: <inferred or 'general'>
    stakeholders:
      - { role: <inferred>, name: "<TBD by user>" }
    scopes:
      <ScopeId>:
        name: "<name>"
        pics: ["<TBD by user>"]
        priority: <inferred or 1>
        sections: ["<§Scope>"]
      ...
    universal_sections: ["§1", "§2", ...]
    cross_scope_dependencies: []
  
  proposed_section_restructure:
    operations:
      - { type: rename_header, from: "§<N>", to: "§<Scope>.<N>" }
      - { type: wrap_content, range: "§<N>-§<M>", into_section: "§<Scope>" }
      - { type: extract_content, range: "§<N>.<a>-<b>", to: "§<Scope>.<X>" }

  warnings:
    - "<any ambiguity flagged>"
    - "<any content that resists clean partitioning>"
  
  overall_confidence: HIGH | MEDIUM | LOW
---

PRD CONTENT FOLLOWS:
=== BEGIN PRD ===
<verbatim PRD content>
=== END PRD ===
```

## Main thread post-processing

After subagent returns:

1. Parse output YAML
2. Render diff view to user (per `scope-picker.md` UX section):
   - Detected scopes with evidence
   - Proposed frontmatter
   - Section rename operations
3. Show overall_confidence prominently
4. AskUserQuestion: accept / review per scope / skip retrofit / cancel
5. On accept:
   - Write retrofit to `<prd-name>.retrofit.md` (sibling of original)
   - DO NOT modify original
   - Inform user of retrofit path
   - Continue generate-intent pipeline with retrofit file

## Low-confidence handling

If `overall_confidence: LOW` → halt `prd_retrofit_low_confidence` with options:
- Accept anyway (user reviews vault per scope after generation)
- Treat as single-scope (safest fallback)
- Cancel (user manually retrofits)

## Anti-halu rails

- Subagent MUST cite line numbers for every evidence claim
- Original PRD NEVER modified — retrofit is always a new file
- Section restructure operations preserve original content; only headers renamed
- Universal sections never assigned to any specific scope (stays at PRD top-level)
- When confidence MEDIUM → flag inline in evidence ("⚠️ MEDIUM — single indicator, verify with PM")

## Backward compatibility

PRDs that pass through retrofit get an explicit version suffix: `version: "<original>-retrofit"` so vault.json records the retrofitted source clearly. Re-runs on the retrofit file proceed normally (it has scopes block now).
