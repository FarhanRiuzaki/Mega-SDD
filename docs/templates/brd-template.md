---
# REQUIRED frontmatter — machine-read by the mega-sdd skills (keep this block 1:1 with them).
#   Primary reader:  generate-intent  → Mode A BRD parse + scope picker (Step 0.9); `type: BRD`
#                                        routes the business-view sections below.
#   Downstream:      emit-fsd          → stakeholders[] becomes the FSD §3 sign-off table;
#                    resolve-oq        → industry seeds OQ recommendation context;
#                    diff-vault        → re-diffs the vault when this doc changes (by sha256).
title: "<Project Name>"
type: BRD
version: "1.0"
status: draft | review | final
date: <YYYY-MM-DD>
authors: ["<business analyst name>"]
industry: banking | healthcare | retail | fintech | logistics | general

# Stakeholders
stakeholders:
  - { role: "Business Sponsor", name: "<name>", email: "<email>" }
  - { role: "BE Architect", name: "<name>", email: "<email>" }
  - { role: "FE Architect", name: "<name>", email: "<email>" }
  - { role: "MW Architect", name: "<name>", email: "<email>" }
  - { role: "Operations Lead", name: "<name>", email: "<email>" }

# Scope declaration — same schema as PRD
scopes:
  BE:
    name: "Backend / API"
    pics: ["<BE Architect>"]
    priority: 1
    sections: ["§Backend"]
  MW:
    name: "Integration Middleware"
    pics: ["<MW Architect>"]
    priority: 2
    sections: ["§Middleware"]
  FE:
    name: "Frontend / User-facing"
    pics: ["<FE Architect>"]
    priority: 3
    sections: ["§Frontend"]

universal_sections: ["§1", "§2", "§3", "§4", "§5", "§6", "§7"]

cross_scope_dependencies:
  - { from: FE, to: BE, contract: "be-fe-customer-endpoints" }
  - { from: BE, to: MW, contract: "be-mw-external-integration-events" }
---

# §1. Business Context

<Why this project exists. Market drivers. Current pain points. Strategic alignment.>

# §2. Business Objectives

- Objective 1: <measurable business outcome>
- Objective 2: <measurable business outcome>
- ROI / value proposition: <expected impact>

# §3. Stakeholders & Impact

| Stakeholder group | Current state | Future state |
|---|---|---|
| Customers | <pain points> | <benefits> |
| Operations | <current workflow> | <new workflow> |
| Compliance | <current burden> | <new burden> |

# §4. Glossary

| Business term | Definition |
|---|---|
| <term> | <definition> |

# §5. Business Rules (regulatory + organizational)

- BR-001: <rule + regulatory source>
- BR-002: <organizational policy + source>

# §6. Constraints

- Budget: <amount + timeline>
- Compliance: <regulations applicable>
- Operational: <e.g., 24/7 availability, peak load expectations>

# §7. Out of Scope

- <feature explicitly excluded with rationale>

---

# §Backend (business view)

> Captures backend business capabilities, not technical implementation.
> Architect translates into PRD §Backend technical specs.

## §Backend.1 Business Capabilities
- Capability: <name> → enables <business outcome>

## §Backend.2 Data ownership
- <data domain> owned by backend (regulatory implications)

## §Backend.3 Integration responsibilities
- Inbound: <where data comes from>
- Outbound: <where data goes>

---

# §Middleware (business view)

## §Middleware.1 External system integrations
- <system 1>: <business relationship + SLA>
- <system 2>: <business relationship + SLA>

## §Middleware.2 Event flows (business level)
- Trigger event → business consequence

---

# §Frontend (business view)

## §Frontend.1 User personas served
- Persona A: <demographics + needs>
- Persona B: <demographics + needs>

## §Frontend.2 Customer journey
1. Awareness → Discovery
2. Decision → Action
3. Service → Loyalty

## §Frontend.3 Accessibility requirements
- WCAG level: <A / AA / AAA>
- Language support: <list>

---

# §Cross-scope Contracts (business view)

Lock contracts described business-side; PRD locks technical contracts.

# §Appendix

- Market research: <link>
- Competitor comparison: <link>
- Financial projections: <link>
