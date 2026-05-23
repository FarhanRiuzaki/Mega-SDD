# Iter 28 Design — Multi-Scope PRD Picker + Canonical PRD/BRD Format

**Status**: Design approved 2026-05-23
**Spec author**: Claude Opus 4.7 (via `superpowers:brainstorming` skill)
**User**: Farhan Riuzaki
**Plugin target**: mega-sdd v3.20.0 (next after v3.19.0 Iter 27)

## 1. Problem statement

User's actual organizational workflow: a single PRD/BRD document describes a system spanning multiple scopes (e.g., Backend `BE`, Middleware `MW`, Frontend `FE`). The PRD is then distributed to multiple IT architects, each owning their scope. Each architect needs to generate their OWN vault containing ONLY the content relevant to their scope.

Current mega-sdd (v3.19.0) does NOT support this:
- `generate-intent` assumes 1 PRD → 1 vault containing ALL PRD content
- No scope-tagging in vault
- No PRD partitioning logic
- No interactive scope picker
- No memory of "last invocation on this PRD used scope X"

Without scope partitioning, each architect's vault is bloated with irrelevant content; downstream skills (`generate-units`, `execute-bolts`) emit work outside the architect's responsibility; output quality degrades.

## 2. Goals

1. **Each architect's vault is scope-only** — content from PRD sections relevant to their scope + universal sections
2. **PRD authoring becomes governable** — canonical template that PMs follow → mega-sdd reads it deterministically
3. **Gradual adoption path** — legacy PRDs (no canonical frontmatter) handled via AI-assisted retrofit, not halt-and-blame
4. **Zero cross-scope orchestration** — mega-sdd does NOT manage cross-scope contracts; each architect runs their own pipeline; coordination happens via shared contract documents OUTSIDE mega-sdd
5. **Compose with existing iters** — multi-scope works alongside Iter 22 (KB mutability tiers), Iter 23 (framework packs), Iter 27 (starterkit-first), Iter 11/12 (squads/modules within a scope)

## 3. Non-goals

- ❌ Cross-scope contract auto-locking (per architect-rapat-handled)
- ❌ Multi-vault parallel execution from single CLI invocation
- ❌ Cross-vault drift detection (BE vault vs FE vault drift)
- ❌ Federated/distributed mega-sdd (no remote vault sync)
- ❌ Auto-generating multiple vaults from one `--scope=all` invocation (treated as legacy single-vault behavior)

## 4. User-facing flow

### 4.1 Architect-BE invocation (first time on this PRD)

```
$ cd ~/projects/order-management-be/
$ /mega-sdd:auto ./shared-docs/prd.md

▶ Phase 0a: PRD scope detection
  Reading ./shared-docs/prd.md frontmatter...
  ✓ Canonical format detected (scopes block present)
  Detected scopes: BE, MW, FE
  Smart default: BE (cwd basename `order-management-be` matches scope id)

❓ This vault is for which scope?
   [1] BE — Backend API (recommended; PIC: BE Architect 1)
   [2] MW — Integration Middleware (PIC: MW Architect)
   [3] FE — Frontend Web (PIC: FE Architect)
   [4] All scopes (single combined vault — legacy behavior)
   [5] Cancel

> 1

✓ Scope: BE locked in.
  Filtering PRD to: §Backend + universal_sections [§1-§7, §9]
  Sibling scopes noted for vault: MW, FE
  PRD sha256: abc123... → saved to memory for re-invocation default

▶ Phase 0b: Starterkit detection (per Iter 27)
  ✓ composer.json → laravel-base-26 detected

▶ Phase 1+: scan-codebase → generate-intent (scope=BE, scan, pack) → bind → units → bolts
```

### 4.2 Architect-BE re-invocation on same PRD

```
$ /mega-sdd:auto ./shared-docs/prd.md

▶ PRD ./shared-docs/prd.md recognized (sha256: abc123...)
  Last scope used: BE (2026-05-23)
  
❓ Same scope this run?
   [Enter] BE (default after 5s; confirm-once)
   [2/3/4] Different scope
   [5] Cancel

> [Enter]

✓ Scope: BE (re-confirmed).
▶ Resuming pipeline...
```

### 4.3 Architect-FE invocation (different repo, fresh session)

```
$ cd ~/projects/order-management-fe/
$ /mega-sdd:auto ./shared-docs/prd.md

▶ PRD detected scopes: BE, MW, FE (canonical format)
  Smart default: FE (cwd matches)

❓ This vault is for which scope?
   [1] BE
   [2] MW
   [3] FE — Frontend Web (recommended)
   [4] All scopes
   [5] Cancel

> 3

✓ Scope: FE locked in.
  Filtering PRD to: §Frontend + universal_sections + cross_scope_dependencies (informational)
  Vault will reference BE-FE-orders-api + MW-FE-realtime-channels contracts (informational)
```

### 4.4 Legacy PRD (no frontmatter) — interactive bridge

```
$ /mega-sdd:auto ./old-prd.md

⚠️ PRD doesn't follow canonical multi-scope format (no `scopes:` frontmatter detected).

Mega-sdd can auto-analyze + propose retrofit:
  - Scans content for scope indicators (section headers, role mentions, tech stack hints)
  - Proposes scope partitioning + frontmatter
  - Original PRD preserved; retrofit written to NEW file

❓ Proceed?
   [1] Yes, propose retrofit (recommended)
   [2] Treat as single-scope PRD (legacy single-vault behavior)
   [3] Cancel — I'll retrofit PRD manually first

> 1

▶ AI analysis dispatched...
  Inferred scopes (with citation evidence):
  
  BE — Backend (confidence: HIGH)
    Evidence:
      - §4 "API Endpoints" mentions /api/orders, /api/users (REST patterns)
      - §6 "Database Schema" mentions migrations + models
      - Stakeholder list mentions "Backend Lead: <name>"
    Proposed section assignment: §3, §4, §6 → §Backend
  
  FE — Frontend (confidence: HIGH)
    Evidence:
      - §5 "User Interface" describes screens + flows
      - §7 "Wireframes" includes mockups
      - Stakeholder list mentions "UX Lead: <name>"
    Proposed section assignment: §5, §7 → §Frontend
  
  MW — Middleware (confidence: MEDIUM)
    Evidence:
      - §8 "External Integrations" mentions Kafka + payment gateway
      - Note: no dedicated section header for MW; content scattered
    Proposed section assignment: §8 + extracts from §4 → §Middleware

❓ Review + accept retrofit?
   [1] Accept all (recommended) — write to ./old-prd.retrofit.md
   [2] Review per scope (interactive)
   [3] Skip retrofit; treat as single-scope
   [4] Cancel

> 1

✓ Retrofit written to ./old-prd.retrofit.md
  Original ./old-prd.md preserved.
  Subsequent mega-sdd invocations should use ./old-prd.retrofit.md.

▶ Resuming with ./old-prd.retrofit.md as PRD input...
```

## 5. Canonical PRD/BRD format

Templates ship at `docs/templates/`:
- `prd-template.md` — full PRD scaffold
- `brd-template.md` — BRD variant (business-focused, less technical)
- `multi-scope-example.md` — concrete fully-filled example for reference

### 5.1 Frontmatter schema

```yaml
---
# Identity
title: "Order Management System"
type: PRD | BRD
version: "1.0"
status: draft | review | final
date: 2026-05-23
authors: ["Product Team Lead"]
industry: banking | healthcare | retail | fintech | logistics | general

# Stakeholders
stakeholders:
  - { role: "BE Architect", name: "...", email: "..." }
  - { role: "FE Architect", name: "...", email: "..." }
  - { role: "MW Architect", name: "...", email: "..." }
  - { role: "QA Lead", name: "...", email: "..." }
  - { role: "Product Owner", name: "...", email: "..." }

# Scope declaration — REQUIRED for multi-scope PRDs
# When this block is absent → mega-sdd triggers interactive bridge for retrofit
scopes:
  BE:
    name: "Backend API"
    pics: ["BE Architect 1", "BE Architect 2"]   # team-shared OK
    priority: 1                                  # delivery sequencing hint
    sections: ["§Backend"]
    depends_on_locked_contracts: []
  MW:
    name: "Integration Middleware"
    pics: ["MW Architect"]
    priority: 2
    sections: ["§Middleware"]
    depends_on_locked_contracts: ["BE-MW-event-bus"]
  FE:
    name: "Frontend Web"
    pics: ["FE Architect"]
    priority: 3
    sections: ["§Frontend"]
    depends_on_locked_contracts: ["BE-FE-orders-api", "MW-FE-realtime-channels"]

# Universal sections — included in EVERY scope's vault
# Default: §1-§9 (everything pre-scope-specific)
universal_sections: ["§1", "§2", "§3", "§4", "§5", "§6", "§7", "§9"]

# Cross-scope dependencies — informational (mega-sdd doesn't auto-orchestrate)
cross_scope_dependencies:
  - { from: FE, to: BE, contract: "REST API per §Backend.3 endpoints" }
  - { from: BE, to: MW, contract: "Event bus per §Middleware.2 message schema" }
  - { from: FE, to: MW, contract: "Realtime channels per §Middleware.4" }

# OPTIONAL: Industry-specific compliance mapping
regulatory_mapping:
  - { ref: "BI Reg 23/2/2021", applies_to: "BE.data_handling.customer_pii" }
  - { ref: "PCI-DSS 3.2", applies_to: "BE.payment_processing" }
---
```

### 5.2 Body structure

```markdown
# §1. Executive Summary
# §2. Goals & Success Metrics
# §3. Stakeholders & User Roles
# §4. Glossary
# §5. Global Business Rules
# §6. Constraints (Compliance, Performance, Deployment)
# §7. Out of Scope (v1)
# §8. (Optional) Global Open Questions
# §9. Success Metrics

# §Backend
## §Backend.1 Functional Requirements
## §Backend.2 Non-Functional Requirements
## §Backend.3 API Design / Endpoints
## §Backend.4 Data Model
## §Backend.5 Acceptance Criteria
## §Backend.6 Open Questions (scope-specific)

# §Middleware
## §Middleware.1 Integration Surface
## §Middleware.2 Message Schema / Event Bus
## §Middleware.3 Adapter Layer
## §Middleware.4 Realtime Channels
## §Middleware.5 Acceptance Criteria
## §Middleware.6 Open Questions

# §Frontend
## §Frontend.1 User Flows
## §Frontend.2 UI/UX Specs
## §Frontend.3 State Model
## §Frontend.4 Acceptance Criteria
## §Frontend.5 Open Questions

# §Cross-scope contracts (locked artifacts referenced by multiple scopes)
# §Appendix (diagrams, mockups, regulatory refs)
```

### 5.3 Naming/labels rationale

- Descriptive section labels (`§Backend`, `§Middleware`, `§Frontend`) instead of letters (`§A`, `§B`, `§C`) — readable for PMs without legend lookup
- Scope IDs (`BE`, `MW`, `FE`) remain short for memorable CLI usage (`--scope=BE`)
- `priority` field is DELIVERY SEQUENCING hint (1 = first to deliver), NOT importance ranking
- `pics` plural array supports team-shared ownership
- `industry:` field optional but enables `regulatory_mapping` semantic check

## 6. Detection algorithm

### 6.1 Detection priority order

```
1. Read PRD frontmatter
   - If `scopes:` block present → DETERMINISTIC: use as authoritative list
   - If `scopes:` block absent → continue to step 2

2. Trigger interactive bridge (legacy retrofit)
   - User chooses: [retrofit / single-scope / cancel]
   - On retrofit: AI analyzes PRD content → proposes scopes + sections
   - On single-scope: route to legacy single-vault flow (current behavior pre-Iter-28)

3. Filter PRD content per scope choice
   - Include: universal_sections + scope's declared sections + cross_scope_dependencies (informational)
   - Exclude: other scopes' specific sections

4. Tag vault with scope metadata
   - vault.json: scope, scope_metadata, prd_sha256
   - 00-index.md: scope header + sibling notes + locked contracts
```

### 6.2 Smart default heuristic (cwd → scope)

When asking the user, recommend a scope based on:
1. cwd basename pattern: `<project>-<scope>` (e.g., `order-be` → BE)
2. cwd basename pattern: `<scope>-<project>` (e.g., `be-order` → BE)
3. cwd parent dir name match: `~/projects/order/be/...` → BE
4. composer.json/package.json filename hints (per Iter 27 starterkit detection)
5. Memory: last scope used on this PRD (from per-project memory)

If multiple hints conflict → recommend the highest-confidence option, list others.
If no hints → present full scope list without recommendation.

## 7. Skill changes

### 7.1 generate-intent (v1.11.0 → v1.12.0)

**New flag**: `--scope=<id>` (e.g., `--scope=BE`, `--scope=all`)

**Behavior**:
- `--scope` not specified + PRD has scopes block + multi-scope detected → interactive picker (AskUserQuestion)
- `--scope=<id>` specified → silent; use that scope; halt if id not in PRD scopes
- `--scope=all` → legacy single-vault behavior (include ALL content)
- No scopes block in PRD → trigger §6.1 step 2 (interactive bridge)
- Single-scope PRD (only universal sections, no per-scope headers) → silent route to legacy flow

**New procedure step (after Step 0, before Step 1)**:
```
0.6 Scope detection + filter
   a. Read PRD frontmatter
   b. If scopes block present → deterministic detection
      - If --scope=<id> flag set → use that scope; halt if invalid
      - Else → check memory for prior choice on this PRD; if found AND --auto NOT set, surface "confirm-once" prompt; if found AND --auto set, default silently
      - Else → AskUserQuestion with smart default (§6.2)
   c. If scopes block absent → trigger interactive bridge
      - AskUserQuestion: retrofit / single-scope / cancel
      - On retrofit: dispatch AI subagent (read PRD, propose scopes), present diff for confirmation, write retrofit file, restart Step 0.6 with retrofit file
   d. Filter PRD to selected scope's sections + universal sections + cross-scope dep notes
   e. Persist scope choice to <project>/.mega-sdd/memory/decisions.md
```

### 7.2 vault-contract.md schema extension

Add new section `§Multi-scope vault` documenting:
- `vault.json.scope` field
- `vault.json.scope_metadata` block
- `vault.json.prd_sha256` field
- `00-index.md` header structure (scope + sibling + contracts)

### 7.3 New CLI / command flags

`commands/auto.md`:
- New flag `--scope=<id>` (passthrough to generate-intent)
- Documentation: scope picker behavior, smart default, memory hints

`commands/generate-intent.md`:
- New flag `--scope=<id>`
- Behavior table for combinations of `--scope`, `--kb`, `--scan`, `--greenfield`

### 7.4 New skill helper file

`plugins/mega-sdd/skills/generate-intent/references/scope-picker.md`:
- Algorithm spec for §6 detection + §6.2 smart default
- Multi-scope PRD example
- Legacy PRD retrofit prompt template

`plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md`:
- Subagent prompt template for AI retrofit analysis
- Heuristic patterns for scope inference (section headers, role mentions, tech stack hints)
- Output format (proposed frontmatter + section restructure diff)

## 8. Vault tagging

### 8.1 vault.json extension

```json
{
  "version": "1.0",
  "title": "Order Management System — BE",
  "implementation_mode": "existing",
  "scope": "BE",
  "scope_metadata": {
    "id": "BE",
    "name": "Backend API",
    "pics": ["BE Architect 1", "BE Architect 2"],
    "priority": 1,
    "prd_sections_used": ["§Backend", "§1", "§2", "§3", "§4", "§5", "§6", "§7", "§9"],
    "sibling_scopes_in_prd": ["MW", "FE"],
    "consumed_locked_contracts": [],
    "published_locked_contracts": ["BE-MW-event-bus", "BE-FE-orders-api"]
  },
  "prd_sha256": "abc123...",
  "prd_path_at_generation": "./shared-docs/prd.md"
}
```

### 8.2 00-index.md header

```markdown
# Vault: Order Management System — BE

**Scope**: Backend API (`BE`)
**PICs**: BE Architect 1, BE Architect 2
**Priority**: 1 (deliver first per PRD scopes block)
**PRD source**: `./shared-docs/prd.md` (sha256: `abc123...`)
**Universal sections included**: §1-§7, §9
**Scope-specific section**: §Backend

## Sibling scopes (managed externally — NOT in this vault)

- **MW** — Integration Middleware (PIC: MW Architect; priority 2)
- **FE** — Frontend Web (PIC: FE Architect; priority 3)

> Cross-scope coordination handled OUTSIDE mega-sdd. Each scope generates an independent vault. Locked contracts cross-referenced below for awareness, NOT enforcement.

## Locked contracts this scope PUBLISHES

- `BE-MW-event-bus` → see PRD §Cross-scope contracts > be-mw-event-bus
- `BE-FE-orders-api` → see PRD §Cross-scope contracts > be-fe-orders-api

## Locked contracts this scope CONSUMES

- (none — BE is upstream in dependency graph)

## Vault content

(Standard 7-file vault contents follow this header.)
```

## 9. Memory schema extension

`<project>/.mega-sdd/memory/decisions.md` gains new section:

```markdown
## PRD Scope Decisions

Records each invocation's PRD → scope mapping. Drives "silent default" on re-invocation (per Memory-OQ-X).

| PRD sha256 | PRD title | Date | Scope picked | Architect cwd | Override count |
|---|---|---|---|---|---|
| abc123... | Order Mgmt System v1.0 | 2026-05-23 | BE | order-be | 0 |
| def456... | Payment Gateway v1.0 | 2026-05-24 | MW | payment-mw | 0 |
```

Memory write rules:
- First-time scope pick on a PRD → INSERT row
- Re-invocation on same PRD + same scope → no write (no change)
- Re-invocation on same PRD + DIFFERENT scope → increment `override_count` on existing row + INSERT new row for the new scope

Memory read rules:
- On generate-intent step 0.6: lookup PRD sha256 → if found, propose last-used scope as default

## 10. Composition with prior iters

### 10.1 With Iter 22 (KB mutability tiers)

PRD scope filter → KB filter. Example: BE scope vault consumes KB but only [VERIFIED][LOCKED] items related to backend domain.

Open question (carry-over from Iter 22): does KB content need scope tagging too? Decision: NO — KB is tech-agnostic domain knowledge, scopes are output partitioning. Each scope's vault includes ALL relevant KB entries (filtered by scope's stated domains).

### 10.2 With Iter 23 (framework packs) + Iter 27 (starterkit-first)

scan-codebase per Iter 27 runs FIRST. Pack loaded. Then generate-intent runs with `--scope` + `--scan`:
1. Read PRD, detect scopes
2. User picks scope BE
3. Filter PRD to BE sections + universal
4. Read codebase-map.md §7 Framework → pack `laravel-base-26.md` loaded
5. Vault `02-architecture.md` uses dual-citation (Intent from BE PRD subset + Starterkit binding from pack)

### 10.3 With Iter 11/12 (squads/modules within a scope)

Squads/modules remain WITHIN a single scope's vault. Example: BE vault has 2 squads (`be-core`, `be-integrations`) — both squads still BACKEND scope, just team partition within BE.

Iter 28 scope layer SITS ABOVE squad/module layer:
```
PRD → scopes (BE, MW, FE) → per-scope vault → squads/modules → units → bolts
```

## 11. Interactive retrofit bridge (legacy PRD)

When PRD lacks `scopes:` frontmatter:

### 11.1 AI subagent prompt template

```
ROLE: PRD scope analyst.

CONTEXT:
- PRD path: <absolute path>
- PRD content (verbatim): <embed content>
- Industry context (if known): <from user>

TASK:
1. Read entire PRD
2. Detect scope indicators:
   - Section headers mentioning Backend / Frontend / Middleware / Mobile / API / etc.
   - Tech stack mentions (Laravel + Vue + Go → 3 scopes possible)
   - Role/stakeholder mentions (Backend Lead, FE Architect, etc.)
   - Cross-references (e.g., "BE will provide API; FE will consume")
3. Propose scope partitioning:
   - ≥1 scope (single-scope PRD also valid output if PRD is genuinely uniscope)
   - For each scope: id, name, evidence citations, proposed sections
4. Propose canonical frontmatter
5. Propose section restructure if needed (preserve original content; add scope headers)

OUTPUT (verbatim format):
---
analysis:
  detected_scopes:
    - id: BE
      name: "Backend API"
      confidence: HIGH | MEDIUM | LOW
      evidence:
        - "§3 'API Design' header (line 45)"
        - "Stakeholder: 'Backend Lead: John' (line 8)"
        - "Tech mention: 'Laravel 11 + MySQL' (line 78)"
      proposed_sections: ["§3", "§4", "§6"]
    - id: FE
      ...
  proposed_frontmatter: |
    <inline yaml>
  proposed_section_restructure:
    operations:
      - { type: rename_header, from: "§3", to: "§Backend.3 API Design" }
      - { type: wrap_content, range: "§3-§4-§6", into_section: "§Backend" }
      - ...
---
```

### 11.2 Diff presentation

Mega-sdd renders the analysis as a diff view (markdown side-by-side or "current vs proposed" tables) before user confirmation.

### 11.3 Write retrofit

On user accept:
- Original PRD UNTOUCHED
- New file written: `<prd-name>.retrofit.md` (sibling of original)
- Frontmatter inserted at top of new file
- Section headers renamed per proposal
- All original content preserved (only structural reorganization)
- User informed: "Retrofit at `<path>`. Subsequent mega-sdd runs should use the retrofit file."

Subsequent invocation auto-detects the retrofit file when both exist? **Decision**: NO. User must explicitly point at the retrofit file. Reason: original may have business meaning (e.g., shared with non-mega-sdd team); auto-substitution could confuse user. Be explicit.

## 12. Edge cases + halts

### 12.1 Edge: PRD has scopes block but user `--scope` flag mismatches

```
--scope=XYZ but PRD scopes block doesn't declare XYZ
→ halt `scope_not_declared_in_prd`
   options: re-pick from declared list / cancel
```

### 12.2 Edge: PRD scopes block declares scopes but body has no §Backend/§Frontend headers

```
PRD has scopes: { BE: ..., FE: ... } but body lacks §Backend / §Frontend section
→ warning, NOT halt
   "Scopes declared but body sections absent. Vault will include only universal_sections."
   Reason: PRD author may add scope sections later; vault is still useful.
```

### 12.3 Edge: Memory has prior scope on PRD but cwd suggests different scope

```
Memory: PRD abc → scope BE
cwd basename: `order-management-fe` → smart default suggests FE
→ Surface both:
   "Memory shows BE (last 2026-05-23). cwd suggests FE.
    Which scope?
      [1] BE — restore last
      [2] FE — switch (recommended based on cwd)
      [3] Other"
```

### 12.4 Edge: User invokes `--scope=all` on canonical multi-scope PRD

```
--scope=all → all content included → single combined vault
   This is LEGACY behavior preserved for back-compat
   Warning: "Combined vault may produce noisy units for non-applicable scopes.
              Consider running with --scope=BE / --scope=MW / --scope=FE separately."
```

### 12.5 Edge: PRD retrofit confidence is LOW across the board

```
AI retrofit returns all scopes with confidence: LOW
→ surface to user:
   "Retrofit confidence low. Mega-sdd may misclassify content.
    Recommendations:
      [1] Accept anyway (you'll review per-scope after generation)
      [2] Treat as single-scope (safest fallback)
      [3] Cancel — I'll manually frontmatter the PRD"
```

### 12.6 Halt types added

| Halt | Trigger | User options |
|---|---|---|
| `scope_not_declared_in_prd` | `--scope=<id>` mismatches PRD scopes block | re-pick from valid list / cancel |
| `prd_no_scopes_block_user_rejected_retrofit` | User rejected retrofit + chose cancel | manual fix / single-scope fallback |
| `prd_retrofit_low_confidence` | All scopes inferred with confidence LOW | accept / single-scope / cancel |

## 13. Testing strategy

### 13.1 New test fixtures (in `tests/scenarios/`)

- `sample-prd-multi-scope.md` — canonical format PRD with 3 scopes (BE/MW/FE) — gold-standard fixture
- `sample-prd-legacy-no-frontmatter.md` — legacy PRD without scopes block (triggers retrofit bridge)
- `sample-prd-single-scope.md` — PRD with only universal sections (routes to legacy single-vault flow)

### 13.2 New scenario walkthrough

- `tests/scenarios/scenario-7-multi-architect.md` — 3 architects, 3 sessions, 1 PRD; demonstrates:
  - Architect-BE first invocation
  - Architect-FE first invocation (different repo, different scope, same PRD)
  - Architect-MW second invocation on same PRD (memory hit demo)
  - Cross-scope sibling notes in vault 00-index.md
  - No cross-vault automation (manual coordination)

### 13.3 New skill-triggering tests

- `tests/skill-triggering/scope-picker.test.md` — covers:
  - Frontmatter detected → no prompt with --scope flag
  - Frontmatter detected → prompt without --scope flag
  - Frontmatter absent → retrofit bridge flow
  - Memory hit → silent default + confirm-once
  - cwd smart default suggestion
  - All edge cases from §12

## 14. Implementation deliverables (file-level)

### 14.1 New files

| Path | Purpose |
|---|---|
| `docs/templates/prd-template.md` | Canonical PRD scaffold (governance artifact for PMs) |
| `docs/templates/brd-template.md` | Canonical BRD variant |
| `docs/templates/multi-scope-example.md` | Fully-filled example PRD (Order Management) |
| `plugins/mega-sdd/skills/generate-intent/references/scope-picker.md` | Algorithm spec |
| `plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md` | AI subagent prompt template |
| `tests/scenarios/sample-prd-multi-scope.md` | Test fixture |
| `tests/scenarios/sample-prd-legacy-no-frontmatter.md` | Test fixture |
| `tests/scenarios/sample-prd-single-scope.md` | Test fixture |
| `tests/scenarios/scenario-7-multi-architect.md` | Scenario walkthrough |
| `tests/skill-triggering/scope-picker.test.md` | Skill-trigger test |

### 14.2 Modified files

| Path | Change |
|---|---|
| `plugins/mega-sdd/skills/generate-intent/SKILL.md` | v1.11.0 → v1.12.0: add Step 0.6 scope detection, `--scope` flag, retrofit dispatcher |
| `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` | Add §Multi-scope vault section (scope, scope_metadata schema) |
| `plugins/mega-sdd/skills/memory/references/memory-schema.md` | Add §PRD Scope Decisions table schema |
| `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` | Handoff YAML gains `scope:` block (informational) |
| `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md` | Mention multi-scope picker in anchor flow |
| `plugins/mega-sdd/commands/auto.md` | Add `--scope=<id>` flag passthrough + docs |
| `plugins/mega-sdd/commands/generate-intent.md` | Add `--scope=<id>` flag + combination matrix |
| `plugins/mega-sdd/.claude-plugin/plugin.json` | Bump 3.19.0 → 3.20.0 |
| `plugins/mega-sdd/README.md` | "What's new" section: Iter 28 multi-scope picker |
| `CHANGELOG.md` | Iter 28 entry |

## 15. Acceptance criteria

This Iter 28 ships when:

1. ✅ Canonical PRD template + BRD template + filled example exist at `docs/templates/`
2. ✅ generate-intent v1.12.0 detects scopes block in PRD frontmatter
3. ✅ generate-intent v1.12.0 accepts `--scope=<id>` flag
4. ✅ Interactive scope picker fires for multi-scope PRD without `--scope` flag
5. ✅ Smart default heuristic surfaces recommendation based on cwd basename
6. ✅ Legacy PRD (no scopes block) triggers retrofit bridge with options
7. ✅ AI retrofit subagent produces structured analysis with confidence ratings
8. ✅ Retrofit written to NEW file (`<name>.retrofit.md`); original untouched
9. ✅ Vault gains scope-tagged metadata (`scope`, `scope_metadata`, `prd_sha256`)
10. ✅ 00-index.md surfaces scope header + sibling notes + locked contracts
11. ✅ Memory layer records PRD → scope decisions
12. ✅ Memory hit → silent default with confirm-once UX
13. ✅ All 5 edge cases from §12 handled with documented halt types
14. ✅ Scenario-7 multi-architect walkthrough demonstrates flow
15. ✅ Test fixtures cover canonical, legacy, single-scope PRDs
16. ✅ Skill-triggering test passes for all §12 edge cases
17. ✅ Skill versions bumped + plugin version bumped + CHANGELOG entry
18. ✅ Composes correctly with Iter 22 (KB) + Iter 23/27 (framework + starterkit)

## 16. Out of scope (for Iter 28)

Explicitly deferred:

- Cross-scope contract auto-locking (architect-rapat domain)
- Multi-vault parallel orchestration (Iter 30+ candidate)
- Cross-scope drift detection (BE vault vs FE vault)
- Auto-generation of all scopes' vaults from single invocation
- PRD format conversion from non-markdown (PDF/DOCX/Notion) — user handles upstream
- Per-scope memory promotion to user-scope (each project tracks its own decisions)

## 17. Rollout + governance

1. After v3.20.0 ships:
   - User shares `docs/templates/prd-template.md` with PMs as new SOP
   - User runs mega-sdd against existing project PRDs to test retrofit flow
   - User validates scenario-7 walkthrough against a real project
2. PM adoption phase (gradual):
   - New PRDs follow canonical format (zero friction with mega-sdd)
   - Legacy PRDs use retrofit bridge (gradual cleanup over time)
   - Memory layer accumulates per-PRD scope decisions organically
3. Future iter feedback loop:
   - User reports retrofit accuracy → iterate on AI prompt template
   - User reports scope detection edge cases → extend smart default heuristic
   - User reports multi-team coordination friction → consider Iter 30+ multi-vault orchestration

---

## Appendix A — Example: canonical multi-scope PRD

(Full example will live at `docs/templates/multi-scope-example.md`. Sketch below.)

```markdown
---
title: "Order Management System"
type: PRD
version: "1.0"
status: draft
date: 2026-05-23
authors: ["Sarah Chen (Product Owner)"]
industry: retail
stakeholders:
  - { role: "BE Architect", name: "Alex Tan", email: "alex@co.id" }
  - { role: "FE Architect", name: "Maya Putri", email: "maya@co.id" }
  - { role: "MW Architect", name: "Budi Santoso", email: "budi@co.id" }

scopes:
  BE:
    name: "Backend API"
    pics: ["Alex Tan"]
    priority: 1
    sections: ["§Backend"]
  MW:
    name: "Integration Middleware"
    pics: ["Budi Santoso"]
    priority: 2
    sections: ["§Middleware"]
    depends_on_locked_contracts: ["BE-MW-event-bus"]
  FE:
    name: "Frontend Web"
    pics: ["Maya Putri"]
    priority: 3
    sections: ["§Frontend"]
    depends_on_locked_contracts: ["BE-FE-orders-api"]

universal_sections: ["§1", "§2", "§3", "§4", "§5", "§6", "§7"]

cross_scope_dependencies:
  - { from: FE, to: BE, contract: "REST API per §Backend.3" }
  - { from: BE, to: MW, contract: "OrderCreated event per §Middleware.2" }
---

# §1. Executive Summary
This system allows retail customers to place orders online...

# §Backend
## §Backend.1 Functional Requirements
- POST /api/orders accepts order payload, returns order_id
- ...

## §Backend.3 API Design / Endpoints
| Endpoint | Method | Auth | Response |
|---|---|---|---|
| /api/orders | POST | Bearer | { order_id, status } |
| ...

# §Middleware
## §Middleware.2 Message Schema / Event Bus
- OrderCreated event: { order_id, customer_id, items[], total_amount }
- ...

# §Frontend
## §Frontend.1 User Flows
- Flow F-001: Customer places order
- ...
```

## Appendix B — Example: retrofit diff output

(Sketch of what mega-sdd shows the user during legacy retrofit confirmation.)

```
PROPOSED RETROFIT for ./old-prd.md

═══════════════════════════════════════════════════════════
SCOPE DETECTION
═══════════════════════════════════════════════════════════

BE — Backend (confidence: HIGH)
  Evidence:
  - Line 45: "## API Design" (matches BE indicator)
  - Line 78: "## Database Schema" (matches BE indicator)
  - Line 8: "Backend Lead: John Smith" (stakeholder)
  Proposed sections: §3, §4, §6
  Section rename: "## API Design" → "# §Backend.3 API Design"

FE — Frontend (confidence: HIGH)
  Evidence:
  - Line 102: "## User Interface" (matches FE indicator)
  - Line 130: "## Wireframes" (matches FE indicator)
  Proposed sections: §5, §7
  Section rename: "## User Interface" → "# §Frontend.1 User Flows"

MW — Middleware (confidence: MEDIUM ⚠️)
  Evidence:
  - Line 165: "## External Integrations" (mentions Kafka, Stripe)
  Note: No dedicated MW section header; content embedded in §8
  Proposed sections: §8 (extract subset)

═══════════════════════════════════════════════════════════
PROPOSED FRONTMATTER (to be prepended)
═══════════════════════════════════════════════════════════

---
title: "Order Management System"
type: PRD
version: "0.9 (retrofit from legacy)"
scopes:
  BE: { name: "Backend", pics: ["John Smith"], priority: 1, sections: ["§Backend"] }
  FE: { name: "Frontend", pics: ["Sarah UX"], priority: 2, sections: ["§Frontend"] }
  MW: { name: "Middleware", pics: ["TBD"], priority: 3, sections: ["§Middleware"] }
universal_sections: ["§1", "§2"]
---

═══════════════════════════════════════════════════════════
SECTION RESTRUCTURE
═══════════════════════════════════════════════════════════

Original §3 "API Design" → New §Backend.3 "API Design"
Original §4 "Database Schema" → New §Backend.4 "Database Schema"
Original §5 "User Interface" → New §Frontend.1 "User Flows"
Original §6 "Migration" → New §Backend.6 "Migration"
Original §7 "Wireframes" → New §Frontend.2 "UI/UX Specs"
Original §8 "External Integrations" → New §Middleware.1 "Integration Surface"

Original content PRESERVED verbatim; only headers renamed.

═══════════════════════════════════════════════════════════

❓ Accept retrofit?
   [1] Accept all (recommended) — write to ./old-prd.retrofit.md
   [2] Review per scope (interactive)
   [3] Skip retrofit; treat as single-scope
   [4] Cancel
```

---

**End of design spec.**

Approved by user: 2026-05-23  
Spec author: Claude Opus 4.7 via `superpowers:brainstorming` skill  
Next step: invoke `superpowers:writing-plans` to create implementation plan from this spec.
