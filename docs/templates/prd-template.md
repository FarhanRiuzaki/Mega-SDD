---
# REQUIRED frontmatter (machine-read by mega-sdd v3.20.0+)
title: "<Project Name>"
type: PRD
version: "1.0"
status: draft | review | final
date: <YYYY-MM-DD>
authors: ["<author name>"]
industry: banking | healthcare | retail | fintech | logistics | general

# Stakeholders (all roles touching this PRD)
stakeholders:
  - { role: "BE Architect", name: "<name>", email: "<email>" }
  - { role: "FE Architect", name: "<name>", email: "<email>" }
  - { role: "MW Architect", name: "<name>", email: "<email>" }
  - { role: "QA Lead", name: "<name>", email: "<email>" }
  - { role: "Product Owner", name: "<name>", email: "<email>" }

# Scope declaration — REQUIRED for multi-scope PRDs
# When this block is absent → mega-sdd triggers interactive retrofit bridge
scopes:
  BE:
    name: "Backend API"
    pics: ["<BE Architect 1>", "<BE Architect 2>"]   # team-shared OK
    priority: 1                                       # delivery sequencing hint (1 = first)
    sections: ["§Backend"]
    depends_on_locked_contracts: []
  MW:
    name: "Integration Middleware"
    pics: ["<MW Architect>"]
    priority: 2
    sections: ["§Middleware"]
    depends_on_locked_contracts: ["BE-MW-event-bus"]
  FE:
    name: "Frontend Web"
    pics: ["<FE Architect>"]
    priority: 3
    sections: ["§Frontend"]
    depends_on_locked_contracts: ["BE-FE-orders-api", "MW-FE-realtime-channels"]

# Universal sections — included in EVERY scope's vault
universal_sections: ["§1", "§2", "§3", "§4", "§5", "§6", "§7", "§9"]

# Cross-scope dependencies — informational (mega-sdd does NOT auto-orchestrate)
cross_scope_dependencies:
  - { from: FE, to: BE, contract: "REST API per §Backend.3 endpoints" }
  - { from: BE, to: MW, contract: "Event bus per §Middleware.2 message schema" }
  - { from: FE, to: MW, contract: "Realtime channels per §Middleware.4" }

# OPTIONAL: Industry-specific compliance mapping
regulatory_mapping:
  - { ref: "<regulation citation>", applies_to: "<scope>.<area>" }
---

# §1. Executive Summary

<2-3 paragraph high-level overview. What the system does, who uses it, why it matters.>

# §2. Goals & Success Metrics

- Goal 1: <measurable outcome>
- Goal 2: <measurable outcome>
- Success metric 1: <quantified target>
- Success metric 2: <quantified target>

# §3. Stakeholders & User Roles

- **<Role 1>**: <responsibilities>
- **<Role 2>**: <responsibilities>

# §4. Glossary

| Term | Definition |
|---|---|
| <term> | <definition> |

# §5. Global Business Rules

Rules that apply across ALL scopes (regulatory, organizational, cross-cutting).

- BR-001: <rule statement> (source: <reference>)
- BR-002: <rule statement>

# §6. Constraints

## §6.1 Compliance
- <regulatory constraints>

## §6.2 Performance
- <SLO / latency targets>

## §6.3 Deployment
- <environment / infrastructure constraints>

# §7. Out of Scope (v1)

- <feature deferred to v2>
- <feature explicitly excluded>

# §8. (Optional) Global Open Questions

These need stakeholder input across multiple scopes.

- **OQ-G-001** [P1] [business]: <question>
- **OQ-G-002** [P2] [tech]: <question>

# §9. Success Metrics (optional — if separate from §2)

- <metric 1>: target / measurement window
- <metric 2>

---

# §Backend

> Scope owner: BE Architect(s) per frontmatter `scopes.BE.pics`

## §Backend.1 Functional Requirements

- FR-BE-001: <requirement> (acceptance: <criteria>)
- FR-BE-002: <requirement>

## §Backend.2 Non-Functional Requirements

- NFR-BE-001: <e.g., response time < 200ms p95>
- NFR-BE-002: <e.g., 99.9% availability>

## §Backend.3 API Design / Endpoints

| Endpoint | Method | Auth | Request | Response |
|---|---|---|---|---|
| /api/<resource> | GET | <auth> | <params> | <shape> |

## §Backend.4 Data Model

- Entity-A: id, field1, field2, created_at, updated_at
- Entity-B: id, entity_a_id (FK), field3
- Relationships: <ERD reference>

## §Backend.5 Acceptance Criteria

- AC-BE-001: <test scenario>
- AC-BE-002: <test scenario>

## §Backend.6 Open Questions (scope-specific)

- **OQ-BE-001** [P1] [business]: <question>

---

# §Middleware

> Scope owner: MW Architect(s) per frontmatter `scopes.MW.pics`

## §Middleware.1 Integration Surface

- External systems: <list>
- Protocols: <REST / gRPC / message queue>

## §Middleware.2 Message Schema / Event Bus

- Event: `OrderCreated` → payload: { order_id, customer_id, items[] }
- Event: `PaymentSettled` → payload: { order_id, amount, currency, timestamp }

## §Middleware.3 Adapter Layer

- <external system 1> adapter: <translation rules>
- <external system 2> adapter: <translation rules>

## §Middleware.4 Realtime Channels

- Channel: `private-order.{order_id}` → broadcast events
- Channel: `presence-customer.{customer_id}` → online indicator

## §Middleware.5 Acceptance Criteria

- AC-MW-001: <test scenario>

## §Middleware.6 Open Questions

- **OQ-MW-001** [P2] [tech]: <question>

---

# §Frontend

> Scope owner: FE Architect(s) per frontmatter `scopes.FE.pics`

## §Frontend.1 User Flows

### F-001 <flow name>
1. User <action>
2. System <response>
3. User confirms
4. System persists

## §Frontend.2 UI/UX Specs

- Page: <name> — route: `<path>` — components: <list>
- Responsive breakpoints: mobile (375px), tablet (768px), desktop (1280px)

## §Frontend.3 State Model

- Global state: <what>
- Per-page state: <what>
- Cache strategy: <approach>

## §Frontend.4 Acceptance Criteria

- AC-FE-001: <test scenario>

## §Frontend.5 Open Questions

- **OQ-FE-001** [P2] [business]: <question>

---

# §Cross-scope Contracts

Locked artifacts referenced by multiple scopes. Editing these requires re-locking with all consumer scopes' architects.

## be-fe-orders-api (v1.0, locked 2026-MM-DD)

Endpoint: `POST /api/orders`
Request shape: { customer_id, items[], shipping_address }
Response shape: { order_id, status, created_at }
Error responses: 400 (validation), 401 (auth), 409 (conflict)

## be-mw-event-bus (v1.0, locked 2026-MM-DD)

Event: `OrderCreated`
Payload schema: { order_id (uuid), customer_id (uuid), items (array), total_amount (decimal), timestamp (iso8601) }
Topic: `orders.created.v1`

## mw-fe-realtime-channels (v1.0, locked 2026-MM-DD)

Channel: `private-order.{order_id}`
Broadcast events: order.updated, order.shipped, order.delivered
Auth: Bearer token via Sanctum

---

# §Appendix

## A. Diagrams

- ERD: <link or embed>
- System architecture: <link or embed>
- User flow diagrams: <link or embed>

## B. References

- Existing systems: <links>
- Regulatory documents: <links>
- Competitor analysis: <links>
