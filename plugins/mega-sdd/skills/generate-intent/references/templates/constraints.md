---
type: prose
doc_id: constraints
vault_version: "{{VAULT_VERSION}}"
aliases: [Constraints, NFR, Non-Functional Requirements]
tags: ["vault/{{PROJECT_SLUG}}", "doc/constraints"]
---

# Constraints & Open Questions

> **TL;DR**: Technical, business, regulatory, and NFR constraints — plus the ONE authored home of every Open Question.
> **Audience**: Architect, Tech Lead, PM, Compliance/Legal.
> **Read when**: you're choosing a solution, validating feasibility, or reviewing compliance.

> **Note**: TL;DR placeholders shown in English. At runtime, render them in the PRD's language.

## Technical constraints

- **Stack lock-in**: <e.g. "Must use Laravel 11 — existing org standard">
- **Infrastructure**: <e.g. "On-prem deployment, no cloud-managed services">
- **Integration boundaries**: <e.g. "Must consume legacy SOAP service at `<endpoint>` — cannot be replaced">
- **Browser / device support**: <e.g. "Chrome / Safari latest 2 versions, mobile responsive 360px+">

## Business constraints

- **Timeline**: <hard deadlines and their reason>
- **Budget**: <if specified>
- **Regulatory**: <e.g. "OJK compliance for transaction logging", "PDP Law data residency in Indonesia">
- **Compliance**: <e.g. "PCI-DSS for payment handling", "SOC 2 audit trail">
- **Contractual**: <e.g. "SLA 99.5% uptime per client agreement">

## Non-functional requirements

| Category | Requirement | Source |
|----------|-------------|--------|
| Performance | <e.g. "p95 API response < 300ms"> | PRD §<X> |
| Scalability | <e.g. "Support 10k concurrent users"> | PRD §<X> |
| Availability | <e.g. "99.5% monthly uptime"> | SLA |
| Security | <e.g. "All PII encrypted at rest"> | Compliance |
| Observability | <e.g. "Structured logs to centralized log store, traces for all external calls"> | Ops requirement |

> Only list NFRs with explicit source. Do not invent SLO targets.

## Design system

> **Conditional**: appears only if Step 2 detection finds at least one of `HAS_TOKENS`, `HAS_A11Y`, or `HAS_VOICE_BRAND` = true. Sub-blocks (Tokens / Accessibility / Voice & brand) appear only for flags that are true. Does not appear from shape inference or prior knowledge — strict source-mirror per Step 2.

### Tokens

> Appears only if `HAS_TOKENS=true`. Source priority: Figma variables > user tokens file > PRD-stated.

**Color**:
| Token | Value | Use case | Source |
|-------|-------|----------|--------|
| `<token.name>` | `<value>` | <where used> | Figma var / tokens.json `<key>` / PRD §<X.Y> |

**Typography**: `<token.name>` `<font-family> <weight> <size>/<line-height>` — Source: <Figma var / tokens.json / PRD §X.Y>

**Spacing scale**: `<list of allowed values, e.g. "4 / 8 / 16 / 24 / 32 / 48 / 64 (px). Increments of 8 only.">` — Source: <...>

**Radius**: `<list of allowed values>` — Source: <...>

### Accessibility

> Appears only if `HAS_A11Y=true`. State only what the source explicitly says.

- WCAG level: <level stated by source — e.g. "WCAG 2.1 AA per PRD §X.Y">. **Do NOT default to AA if source silent.**
- Color contrast: <values from source>
- Keyboard / screen reader: <rules from source>

### Voice & brand (light)

> Appears only if `HAS_VOICE_BRAND=true`. Editorial guidance only when the source provides it.

- Tone: <quoted from PRD or user instruction>
- User-facing locale: <quoted from PRD or user instruction>
- Copy guidelines: <quoted from PRD or user instruction>

---

## Sources

- PRD §<X.Y>
- Compliance / regulatory documents
- SLA / contract references

## Out of Scope

- <constraints that are explicitly NOT applicable, e.g. "GDPR — no EU users in v1">
- <if unknown: "TBD - confirm with compliance / legal">

## Open Questions

> THE ONE AUTHORED OQ SURFACE (layout-2). Every Open Question from every part
> of the vault lives HERE — derive-vault-json exits 2 on an OQ checkbox line
> found in any other vault doc. Rules:
> - Tag prefixes stay TOPIC markers (OV/AR/DM/FL/DC/CN — no ID churn): OV/AR/DC
>   topics point into vault.md sections, DM into model.md, FL into flows.md.
> - Every non-constraints-native OQ carries `[origin: <file>#<anchor>]` naming
>   where the question arose (e.g. `[origin: flows.md#F-U-002]`,
>   `[origin: vault.md#Architecture]`) — the locality that per-doc placement
>   used to give for free. Constraints-native OQs need no origin.
> - The `[tech / <mode>]` / `[business]` bracket is MANDATORY per OQ (bracket-
>   first is the only category source — there is no roll-up fallback here).
> - Sort P1 → P2 → P3. Priority + conf + resolution annotations per
>   vault-contract.md §OQ-conventions, unchanged.

- [ ] **OQ-CN-1** [P1] [business]: <e.g. "Performance targets not specified in PRD">
- [ ] **OQ-FL-1** [P2] [business] [origin: flows.md#F-U-001]: <e.g. "PRD describes happy path only — what happens when payment fails?">
- [ ] **OQ-AR-1** [P2] [tech / scan] [conf: high] [origin: vault.md#Architecture]: <e.g. "which test framework?" — resolve: scan codebase-map §test_frameworks>
