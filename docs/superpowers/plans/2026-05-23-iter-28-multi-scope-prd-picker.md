# Iter 28 Multi-Scope PRD Picker — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-scope PRD detection + interactive scope picker to mega-sdd so each IT architect (BE, MW, FE, etc.) generates a vault containing ONLY content relevant to their scope.

**Architecture:** Canonical PRD format with `scopes:` frontmatter block makes detection deterministic. When frontmatter absent, AI-assisted retrofit bridge proposes scope partitioning. Scope picker uses cwd-smart-default + memory-driven recall. Vault tagged with scope metadata; sibling scopes noted informationally; no cross-scope orchestration.

**Tech Stack:** Markdown-driven mega-sdd plugin (no runtime code). Documentation edits, YAML frontmatter schemas, skill-triggering test fixtures, scenario walkthrough.

**Spec source:** `docs/superpowers/specs/2026-05-23-iter-28-multi-scope-prd-picker-design.md`

---

## File Structure

### New files (10)

| Path | Responsibility |
|---|---|
| `docs/templates/prd-template.md` | Canonical PRD scaffold (governance artifact for PMs) |
| `docs/templates/brd-template.md` | Canonical BRD variant (business-focused) |
| `docs/templates/multi-scope-example.md` | Fully-filled example PRD (Order Management) |
| `plugins/mega-sdd/skills/generate-intent/references/scope-picker.md` | Detection algorithm + smart default heuristic spec |
| `plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md` | AI subagent prompt template for retrofit |
| `tests/scenarios/sample-prd-multi-scope.md` | Test fixture — canonical format PRD with 3 scopes |
| `tests/scenarios/sample-prd-legacy-no-frontmatter.md` | Test fixture — legacy PRD (triggers retrofit bridge) |
| `tests/scenarios/sample-prd-single-scope.md` | Test fixture — single-scope PRD (legacy single-vault flow) |
| `tests/scenarios/scenario-7-multi-architect.md` | Scenario walkthrough — 3 architects, 3 sessions, 1 PRD |
| `tests/skill-triggering/scope-picker.test.md` | Skill-trigger fixtures for scope picker behavior |

### Modified files (10)

| Path | Change |
|---|---|
| `plugins/mega-sdd/skills/generate-intent/SKILL.md` | v1.11.0 → v1.12.0: add Step 0.6 scope detection + `--scope` flag + retrofit dispatcher |
| `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` | Add §Multi-scope vault section (schema + 00-index.md header structure) |
| `plugins/mega-sdd/skills/memory/references/memory-schema.md` | Add §PRD Scope Decisions table schema |
| `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` | Add `scope:` block to handoff YAML (informational) |
| `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md` | Mention multi-scope picker in anchor auto-trigger flow |
| `plugins/mega-sdd/commands/auto.md` | Add `--scope=<id>` flag passthrough + docs |
| `plugins/mega-sdd/commands/generate-intent.md` | Add `--scope=<id>` flag + combination matrix |
| `plugins/mega-sdd/.claude-plugin/plugin.json` | Bump 3.19.0 → 3.20.0 |
| `plugins/mega-sdd/README.md` | Add Iter 28 to "What's new" section |
| `CHANGELOG.md` | Add Iter 28 entry |

---

## Task 1: Create canonical PRD template

**Files:**
- Create: `docs/templates/prd-template.md`

- [ ] **Step 1.1: Verify target directory exists**

```bash
mkdir -p docs/templates
ls docs/templates/
```

Expected: directory exists (may be empty)

- [ ] **Step 1.2: Write the canonical PRD template file**

Write to `docs/templates/prd-template.md`:

```markdown
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
```

- [ ] **Step 1.3: Verify file is valid markdown + has all required sections**

```bash
test -f docs/templates/prd-template.md && echo "EXISTS"
grep -c "^---$" docs/templates/prd-template.md
grep -c "^scopes:" docs/templates/prd-template.md
grep -c "^universal_sections:" docs/templates/prd-template.md
grep -c "^cross_scope_dependencies:" docs/templates/prd-template.md
grep -c "^# §" docs/templates/prd-template.md
```

Expected output:
- EXISTS
- 2 (frontmatter open/close markers)
- 1
- 1
- 1
- 5+ (§1 through §Frontend + Cross-scope + Appendix)

- [ ] **Step 1.4: Commit**

```bash
git add docs/templates/prd-template.md
git commit -m "$(cat <<'EOF'
feat(iter-28): canonical PRD template (governance artifact)

Multi-scope PRD scaffold with frontmatter scopes block.
Drives deterministic scope detection by mega-sdd v3.20.0+.

Sections:
- Frontmatter: title, type, scopes (BE/MW/FE), universal_sections,
  cross_scope_dependencies, regulatory_mapping
- Body: universal sections (§1-§9) + scope sections (§Backend,
  §Middleware, §Frontend) + cross-scope contracts + appendix

User shares this template with PMs as new SOP.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Create canonical BRD template

**Files:**
- Create: `docs/templates/brd-template.md`

- [ ] **Step 2.1: Write BRD template (business-focused variant of PRD)**

Write to `docs/templates/brd-template.md`:

```markdown
---
# REQUIRED frontmatter (machine-read by mega-sdd v3.20.0+)
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

# Scope declaration — same as PRD
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
  - { from: FE, to: BE, contract: "Customer-facing endpoints per §Backend" }
  - { from: BE, to: MW, contract: "External integration events per §Middleware" }
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
```

- [ ] **Step 2.2: Verify BRD has same frontmatter contract as PRD**

```bash
grep -c "^scopes:" docs/templates/brd-template.md
grep -c "^universal_sections:" docs/templates/brd-template.md
grep -c "^type: BRD" docs/templates/brd-template.md
```

Expected:
- 1 (scopes block present)
- 1
- 1

- [ ] **Step 2.3: Commit**

```bash
git add docs/templates/brd-template.md
git commit -m "feat(iter-28): canonical BRD template (business-focused variant)

Same frontmatter schema as PRD (type: BRD vs type: PRD).
Body sections focus on business view (capabilities, journeys,
ROI) rather than technical specs.

Architects use BRD as upstream input → translate to PRD for
technical scoping → mega-sdd reads PRD for vault generation.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Create fully-filled multi-scope example

**Files:**
- Create: `docs/templates/multi-scope-example.md`

- [ ] **Step 3.1: Write fully-filled example PRD (Order Management System)**

Write to `docs/templates/multi-scope-example.md`:

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
  - { role: "Product Owner", name: "Sarah Chen", email: "sarah@co.id" }
  - { role: "BE Architect", name: "Alex Tan", email: "alex@co.id" }
  - { role: "FE Architect", name: "Maya Putri", email: "maya@co.id" }
  - { role: "MW Architect", name: "Budi Santoso", email: "budi@co.id" }
  - { role: "QA Lead", name: "Lina Wijaya", email: "lina@co.id" }

scopes:
  BE:
    name: "Backend API"
    pics: ["Alex Tan"]
    priority: 1
    sections: ["§Backend"]
    depends_on_locked_contracts: []
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
    depends_on_locked_contracts: ["BE-FE-orders-api", "MW-FE-realtime-channels"]

universal_sections: ["§1", "§2", "§3", "§4", "§5", "§6", "§7"]

cross_scope_dependencies:
  - { from: FE, to: BE, contract: "REST API per §Backend.3 endpoints" }
  - { from: BE, to: MW, contract: "OrderCreated event per §Middleware.2 schema" }
  - { from: FE, to: MW, contract: "Realtime order updates per §Middleware.4" }

regulatory_mapping:
  - { ref: "PCI-DSS 3.2", applies_to: "BE.payment_storage" }
---

# §1. Executive Summary

E-commerce platform allowing retail customers to place product orders online. Replaces phone+spreadsheet workflow with self-service web app + real-time order tracking. Targets reducing order processing time from 8 minutes → 90 seconds and supporting 10x peak Black Friday load.

# §2. Goals & Success Metrics

- Goal 1: Customer self-service ordering (no phone calls for standard orders)
- Goal 2: Operations team sees order pipeline in real-time
- Goal 3: Inventory sync with warehouse system (latency < 5 seconds)
- Metric 1: 80% of orders placed via self-service within 3 months
- Metric 2: Order processing time P95 < 90s (down from 8 min phone)
- Metric 3: Cart abandonment < 25% (industry baseline 35%)

# §3. Stakeholders & User Roles

- **Customer (Retail)**: places orders, tracks status, manages account
- **Customer Service Rep**: views customer orders, modifies on behalf of customer
- **Warehouse Operator**: marks orders shipped/delivered
- **Operations Manager**: views all orders, manages refunds, reports

# §4. Glossary

| Term | Definition |
|---|---|
| Order | Customer's request to purchase one or more products |
| Line item | Single product entry within an order |
| Cart | Customer's working set of products before order submission |
| Settlement | Payment confirmed + funds transferred |

# §5. Global Business Rules

- BR-001: Orders cannot be modified after warehouse marks "shipped" (source: Ops Policy 2024-Q3)
- BR-002: Customer email is unique identifier across all systems
- BR-003: Refunds require Ops Manager approval if > IDR 5M

# §6. Constraints

## §6.1 Compliance
- PCI-DSS 3.2 for payment data (no card numbers stored in our DB; tokenization via Stripe)
- Indonesian e-commerce regulation (BPKN) on consumer rights disclosure

## §6.2 Performance
- Order placement latency P95 < 1.5 seconds
- 99.9% uptime SLO (excludes planned maintenance windows)
- Support 1000 concurrent users; 5000 at peak Black Friday

## §6.3 Deployment
- AWS region: ap-southeast-3 (Jakarta) primary, ap-southeast-1 DR
- Containerized; Kubernetes on EKS

# §7. Out of Scope (v1)

- Mobile app (web responsive only for v1)
- Multi-currency (IDR only)
- Marketplace mode (single seller for v1)
- Loyalty program / rewards
- Subscription orders / recurring

---

# §Backend

> Owner: Alex Tan (BE Architect)

## §Backend.1 Functional Requirements

- FR-BE-001: Accept order creation requests with line items + shipping address
- FR-BE-002: Validate inventory availability at order placement
- FR-BE-003: Reserve inventory for 15 minutes during payment processing
- FR-BE-004: Persist order with state machine (pending → paid → shipped → delivered)
- FR-BE-005: Emit OrderCreated event after successful payment

## §Backend.2 Non-Functional Requirements

- NFR-BE-001: Order creation endpoint P95 < 800ms
- NFR-BE-002: Idempotent order creation (Idempotency-Key header)
- NFR-BE-003: Horizontal scaling (stateless application servers)

## §Backend.3 API Design / Endpoints

| Endpoint | Method | Auth | Request | Response |
|---|---|---|---|---|
| /api/v1/orders | POST | Bearer | { customer_id, items[], shipping_address, idempotency_key } | 201 { order_id, status, total_amount } |
| /api/v1/orders/{id} | GET | Bearer | - | 200 { order details } |
| /api/v1/orders/{id}/cancel | POST | Bearer | { reason } | 200 { order_id, status: cancelled } |

## §Backend.4 Data Model

- **customer**: id, email (unique), name, phone, created_at
- **product**: id, sku (unique), name, price, stock_quantity
- **order**: id, customer_id, status, total_amount, shipping_address, created_at, paid_at, shipped_at
- **order_item**: id, order_id, product_id, quantity, unit_price, subtotal
- **payment**: id, order_id, provider (stripe), provider_transaction_id, amount, status, created_at

## §Backend.5 Acceptance Criteria

- AC-BE-001: POST /orders with valid payload returns 201 with order_id within 800ms (p95)
- AC-BE-002: Same idempotency_key produces same order_id (no duplicate orders)
- AC-BE-003: Order placement reserves inventory; cancellation within 15min releases reservation
- AC-BE-004: OrderCreated event emitted to MW within 100ms of payment confirmation

## §Backend.6 Open Questions

- **OQ-BE-001** [P1] [business]: Should partial fulfillment be allowed (3 of 5 items shipped, rest backordered)?
- **OQ-BE-002** [P2] [tech]: Postgres or MySQL for primary DB? (operations prefers Postgres; infra has MySQL skill)

---

# §Middleware

> Owner: Budi Santoso (MW Architect)

## §Middleware.1 Integration Surface

External systems:
- **Stripe**: payment processing (REST API + webhooks)
- **Warehouse System**: inventory sync + shipment status (REST API; legacy)
- **Email Provider (SendGrid)**: transactional emails
- **Push Notification (Firebase)**: real-time updates

Protocols:
- Inbound webhooks: Stripe payment events
- Outbound REST: Warehouse, SendGrid, Firebase
- Internal: Kafka topic `orders.events`

## §Middleware.2 Message Schema / Event Bus

Topic: `orders.events`

Event: `OrderCreated`
Payload schema: { order_id (uuid), customer_id (uuid), items (array of {product_id, quantity, unit_price}), total_amount (decimal), shipping_address (object), timestamp (iso8601) }

Event: `OrderPaid`
Payload schema: { order_id, payment_id, payment_provider, amount, timestamp }

Event: `OrderShipped`
Payload schema: { order_id, carrier, tracking_number, shipped_at }

## §Middleware.3 Adapter Layer

- Stripe adapter: webhook listener → translate to OrderPaid event
- Warehouse adapter: poll for shipment status every 60s → emit OrderShipped on status change
- SendGrid adapter: subscribe to OrderCreated/Shipped → send template emails
- Firebase adapter: subscribe to OrderCreated/Shipped → push notification to FE

## §Middleware.4 Realtime Channels

Channel: `private-order.{order_id}`
Auth: Bearer token (Sanctum)
Events broadcast: order.status_changed, payment.received, shipment.dispatched

## §Middleware.5 Acceptance Criteria

- AC-MW-001: Stripe webhook → OrderPaid event end-to-end within 500ms
- AC-MW-002: Warehouse poller handles 10k orders without backlog
- AC-MW-003: SendGrid delivery success rate > 98% (excluding bounce/spam)

## §Middleware.6 Open Questions

- **OQ-MW-001** [P1] [business]: SLA for warehouse poll frequency? (cost vs latency trade-off)
- **OQ-MW-002** [P2] [tech]: Kafka cluster sizing (dedicated vs shared with other domains)?

---

# §Frontend

> Owner: Maya Putri (FE Architect)

## §Frontend.1 User Flows

### F-001 Customer places order
1. Customer browses product catalog
2. Adds items to cart
3. Reviews cart, edits quantities
4. Enters shipping address
5. Selects payment method (Stripe Checkout)
6. Redirected to Stripe → completes payment
7. Returns to confirmation page
8. Receives order confirmation email

### F-002 Customer views order status
1. Customer clicks "My Orders" from header
2. Sees list of past orders (sortable by date/status)
3. Clicks order → sees detail page with timeline
4. Real-time status updates via WebSocket channel

### F-003 Ops Manager refund
1. Ops Manager searches order by customer email or order ID
2. Selects order; reviews details
3. Clicks "Refund" → enters reason
4. System processes refund via Stripe; status updates

## §Frontend.2 UI/UX Specs

- Page: `/products` (catalog)
- Page: `/cart` (cart review)
- Page: `/checkout` (shipping + payment)
- Page: `/orders` (customer's orders list)
- Page: `/orders/{id}` (single order with real-time updates)
- Page: `/admin/orders` (ops dashboard)

Responsive breakpoints: mobile 375px, tablet 768px, desktop 1280px

## §Frontend.3 State Model

- Cart state: localStorage + sync to backend on login
- User session: JWT in cookie (httpOnly)
- Order list: server-side rendered + revalidate-on-focus
- Order detail: server-rendered initial + WebSocket subscription for updates

## §Frontend.4 Acceptance Criteria

- AC-FE-001: Cart persists across browser sessions (localStorage + DB sync on login)
- AC-FE-002: Order placement form validates inline (no full-page reload)
- AC-FE-003: Order detail page shows live status updates within 2 seconds of MW broadcast
- AC-FE-004: Mobile checkout flow works at 375px without horizontal scroll

## §Frontend.5 Open Questions

- **OQ-FE-001** [P2] [business]: Display estimated delivery date on order confirmation? (depends on warehouse SLA accuracy)
- **OQ-FE-002** [P3] [tech]: Server-side rendering framework — Inertia (with Laravel BE) or pure Vue/Nuxt SPA?

---

# §Cross-scope Contracts

## be-fe-orders-api (v1.0, locked 2026-05-23)

Endpoint: `POST /api/v1/orders`
Auth: Bearer token (Sanctum)
Request: { customer_id, items[], shipping_address, idempotency_key }
Response 201: { order_id, status, total_amount }
Error responses: 400 (validation), 401 (auth), 409 (idempotency conflict), 422 (inventory unavailable)

## be-mw-event-bus (v1.0, locked 2026-05-23)

Topic: `orders.events`
Events: OrderCreated, OrderPaid, OrderShipped, OrderCancelled
Schema details: see §Middleware.2

## mw-fe-realtime-channels (v1.0, locked 2026-05-23)

Channel: `private-order.{order_id}`
Auth: Bearer token (Sanctum)
Events: order.status_changed, payment.received, shipment.dispatched
Payload contract: see §Middleware.4

---

# §Appendix

## A. Diagrams

- ERD: docs/architecture/orders-erd.md
- System architecture: docs/architecture/orders-system-diagram.md
- User flows: docs/ux/orders-user-flows.md

## B. References

- Existing legacy order system: ./old-reference/order-mgmt-v0/
- Stripe API docs: https://stripe.com/docs/api
- Warehouse API docs: docs/integrations/warehouse-api-v3.md
- BPKN compliance: docs/compliance/bpkn-ecommerce-2024.md
```

- [ ] **Step 3.2: Verify example is internally consistent**

```bash
test -f docs/templates/multi-scope-example.md && echo "EXISTS"
# Frontmatter scope IDs match section headers
grep -c "^scopes:" docs/templates/multi-scope-example.md
grep -c "^# §Backend$" docs/templates/multi-scope-example.md
grep -c "^# §Middleware$" docs/templates/multi-scope-example.md
grep -c "^# §Frontend$" docs/templates/multi-scope-example.md
# Cross-scope contracts present
grep -c "^## be-fe-orders-api" docs/templates/multi-scope-example.md
```

Expected: EXISTS, 1, 1, 1, 1, 1

- [ ] **Step 3.3: Commit**

```bash
git add docs/templates/multi-scope-example.md
git commit -m "feat(iter-28): fully-filled multi-scope PRD example

Reference example demonstrating canonical format applied to a
realistic e-commerce order management system. Three scopes
(BE/MW/FE) with realistic content per section, cross-scope
contracts locked, regulatory mapping (PCI-DSS).

Used as the gold-standard reference for PMs adopting the new
SOP and as a fixture for mega-sdd scope detection testing.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Create scope-picker algorithm reference

**Files:**
- Create: `plugins/mega-sdd/skills/generate-intent/references/scope-picker.md`

- [ ] **Step 4.1: Write the scope-picker algorithm spec**

Write to `plugins/mega-sdd/skills/generate-intent/references/scope-picker.md`:

```markdown
# Scope Picker Algorithm (v1.12+, Iter 28)

Reference for `generate-intent` Step 0.6 scope detection + filtering. Companion to `vault-contract.md` §Multi-scope vault.

## Detection priority order

```
1. Read PRD frontmatter
   - If `scopes:` block present → DETERMINISTIC: use as authoritative list
   - If `scopes:` block absent → continue to step 2

2. Trigger interactive bridge (legacy retrofit)
   - User chooses: [retrofit / single-scope / cancel]
   - On retrofit: AI analyzes PRD content → proposes scopes + sections
                 → writes <prd>.retrofit.md (preserves original)
                 → restart from step 1 with retrofit file
   - On single-scope: route to legacy single-vault flow (current behavior)

3. Determine scope choice (if multi-scope detected)
   - If `--scope=<id>` flag set → use that scope; halt `scope_not_declared_in_prd` if id not in scopes
   - Else if memory has prior choice for this PRD sha256 + cwd basename matches → silent default + confirm-once
   - Else → AskUserQuestion with smart default (see §Smart default heuristic)

4. Filter PRD content per chosen scope
   - Include: universal_sections (from frontmatter) + chosen scope's declared sections
   - Include: cross_scope_dependencies (rendered as informational notes in vault)
   - Exclude: other scopes' specific sections (still cited as "sibling scopes" in 00-index.md)

5. Tag vault with scope metadata
   - vault.json: scope, scope_metadata, prd_sha256
   - 00-index.md: scope header + sibling scopes notes + locked contracts

6. Persist scope choice to memory
   - `<project>/.mega-sdd/memory/decisions.md` §PRD Scope Decisions
   - Increment override_count if user switched scope on same PRD
```

## Smart default heuristic

When asking the user, recommend a scope based on signal strength:

| Signal | Confidence | Example |
|---|---|---|
| cwd basename matches `<project>-<scope>` | HIGH | `order-management-be/` → BE |
| cwd basename matches `<scope>-<project>` | HIGH | `be-order-mgmt/` → BE |
| cwd parent dir matches scope id | MEDIUM | `~/projects/order/be/` → BE |
| Composer/package.json filename hints (per Iter 27) | MEDIUM | composer.json + Laravel → likely BE |
| Memory: last scope used on this PRD sha256 | HIGH (if same cwd) | matches BE → suggest BE |

Conflict resolution:
- If multiple signals match → use highest-confidence
- If signals contradict (memory says BE, cwd says FE) → surface BOTH options to user
- If no signals → present full scope list without "recommended" marker

## --scope flag semantics

| Flag | Behavior |
|---|---|
| `--scope=<id>` | Use that scope; halt if not in PRD scopes block |
| `--scope=all` | Legacy single-vault behavior — include ALL PRD content; emit warning |
| (flag absent) | Interactive picker per step 3 above |

## Filter logic

After scope choice, build the filtered PRD passed to generate-intent's main parser:

```
filtered_prd = ""
filtered_prd += frontmatter   # always include all frontmatter (mega-sdd reads metadata)

for section in PRD body:
    if section.heading in universal_sections:
        filtered_prd += section
    elif section.heading in chosen_scope.sections:
        filtered_prd += section
    else:
        # Skip — sibling scope section
        # Will be cited as informational in vault 00-index.md
        pass

# Always append cross_scope_dependencies as informational footer
filtered_prd += "## Cross-scope dependencies (informational only)\n"
for dep in PRD frontmatter.cross_scope_dependencies:
    if dep.from == chosen_scope or dep.to == chosen_scope:
        filtered_prd += f"- {dep}\n"
```

## Sibling scope informational

When chosen_scope = BE and PRD has scopes = {BE, MW, FE}:

00-index.md MUST include:

```markdown
## Sibling scopes (managed externally — NOT in this vault)

- **MW** — Integration Middleware (PIC: <name>; priority: 2)
- **FE** — Frontend Web (PIC: <name>; priority: 3)

> Cross-scope coordination handled OUTSIDE mega-sdd. Each scope generates an independent vault.
> Locked contracts cross-referenced below for awareness, NOT enforcement.
```

## Memory hit UX

When PRD sha256 found in memory + cwd matches last invocation:

```
▶ PRD ./<path> recognized (sha256: <hash>...)
  Last scope used: <scope> (<date>)

❓ Same scope this run?
   [Enter] <scope> (default after 5s; confirm-once)
   [2/3/4] Different scope
   [5] Cancel
```

Confirm-once timeout default: 5 seconds. Configurable via `--scope-confirm-timeout=N` (rarely needed).

When `--auto` flag set AND memory hit → silent default; do not prompt at all.

## Anti-halu rails

- NEVER silently re-use memory's scope choice without showing it to user (except `--auto` mode)
- NEVER auto-substitute retrofit file path — user explicitly invokes with retrofit file
- NEVER write to memory if user cancels picker
- ALWAYS include cross_scope_dependencies notes when chosen_scope is involved (publisher OR consumer)
- ALWAYS preserve original PRD when generating retrofit; new file written, original untouched

## Edge cases handled

See `generate-intent/SKILL.md` Halt conditions for halt types:
- `scope_not_declared_in_prd`
- `prd_no_scopes_block_user_rejected_retrofit`
- `prd_retrofit_low_confidence`
```

- [ ] **Step 4.2: Verify file structure**

```bash
test -f plugins/mega-sdd/skills/generate-intent/references/scope-picker.md && echo "EXISTS"
grep -c "^## " plugins/mega-sdd/skills/generate-intent/references/scope-picker.md
```

Expected: EXISTS, 8+ section headings

- [ ] **Step 4.3: Commit**

```bash
git add plugins/mega-sdd/skills/generate-intent/references/scope-picker.md
git commit -m "feat(iter-28): scope-picker algorithm reference

Documents Step 0.6 scope detection priority order, smart default
heuristic, --scope flag semantics, PRD content filter logic,
sibling scope informational rendering, memory hit UX, and
anti-halu rails for scope detection.

Companion to vault-contract.md §Multi-scope vault.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Create legacy retrofit prompt reference

**Files:**
- Create: `plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md`

- [ ] **Step 5.1: Write the retrofit subagent prompt template**

Write to `plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md`:

```markdown
# Legacy PRD Retrofit Prompt Template (v1.12+, Iter 28)

When generate-intent encounters a PRD without `scopes:` frontmatter, dispatches an AI subagent with this prompt template. Subagent analyzes PRD content + proposes canonical retrofit.

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
4. Propose canonical frontmatter (per `references/scope-picker.md` schema)
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
```

- [ ] **Step 5.2: Verify file**

```bash
test -f plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md && echo "EXISTS"
grep -c "^## " plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md
grep -c "OUTPUT FORMAT" plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md
```

Expected: EXISTS, 6+ sections, 1

- [ ] **Step 5.3: Commit**

```bash
git add plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md
git commit -m "feat(iter-28): legacy PRD retrofit prompt template

Subagent prompt for AI-assisted retrofit when PRD lacks
canonical scopes frontmatter. Includes detection patterns
(English + Indonesian variants), evidence citation discipline,
output YAML schema, post-processing pipeline, low-confidence
handling, and anti-halu rails (original PRD preserved).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Create test fixture — canonical multi-scope PRD

**Files:**
- Create: `tests/scenarios/sample-prd-multi-scope.md`

- [ ] **Step 6.1: Write canonical multi-scope test fixture**

The fixture should be a SMALLER version of the multi-scope-example.md (Task 3) — same structure but trimmed content for fast test usage.

Write to `tests/scenarios/sample-prd-multi-scope.md`:

```markdown
---
title: "Clinic Appointment System (Multi-scope test fixture)"
type: PRD
version: "1.0"
status: draft
date: 2026-05-23
authors: ["Test Suite"]
industry: healthcare
stakeholders:
  - { role: "BE Architect", name: "Test BE", email: "be@test.local" }
  - { role: "MW Architect", name: "Test MW", email: "mw@test.local" }
  - { role: "FE Architect", name: "Test FE", email: "fe@test.local" }

scopes:
  BE:
    name: "Backend API"
    pics: ["Test BE"]
    priority: 1
    sections: ["§Backend"]
  MW:
    name: "Integration Middleware"
    pics: ["Test MW"]
    priority: 2
    sections: ["§Middleware"]
    depends_on_locked_contracts: ["BE-MW-appointment-events"]
  FE:
    name: "Frontend Web"
    pics: ["Test FE"]
    priority: 3
    sections: ["§Frontend"]
    depends_on_locked_contracts: ["BE-FE-appointment-api"]

universal_sections: ["§1", "§2", "§3", "§4"]

cross_scope_dependencies:
  - { from: FE, to: BE, contract: "REST API per §Backend.3" }
  - { from: BE, to: MW, contract: "AppointmentCreated event" }
---

# §1. Executive Summary

Clinic appointment booking system. Patients book online; doctors view schedule; system sends reminders.

# §2. Goals

- Patients self-book without phone
- Reduce no-shows via 24h email reminders
- Staff sees daily schedule at a glance

# §3. Stakeholders

- Patient: books own appointments
- Doctor: views own schedule
- Receptionist: manages all schedules

# §4. Glossary

| Term | Definition |
|---|---|
| Appointment | Scheduled patient visit with a doctor |
| Slot | 15-minute time block on doctor's schedule |

---

# §Backend

## §Backend.1 Functional
- FR-BE-001: POST /api/appointments creates appointment + reserves slot
- FR-BE-002: GET /api/appointments/{id} returns appointment detail
- FR-BE-003: Emit AppointmentCreated event after persistence

## §Backend.3 API
| Endpoint | Method | Auth |
|---|---|---|
| /api/appointments | POST | Bearer |
| /api/appointments/{id} | GET | Bearer |

## §Backend.4 Data Model
- appointment: id, patient_id, doctor_id, start_time, status

---

# §Middleware

## §Middleware.1 Integration
- Email provider (SendGrid) for reminders
- SMS provider (Twilio) for backup reminders

## §Middleware.2 Events
- AppointmentCreated → trigger reminder schedule
- AppointmentCancelled → release reminder

---

# §Frontend

## §Frontend.1 User Flows
- F-001 Patient books appointment
- F-002 Doctor views schedule

## §Frontend.2 UI
- Page: /book — calendar widget
- Page: /doctor/schedule — day/week view
```

- [ ] **Step 6.2: Verify fixture parses + scopes block detected**

```bash
test -f tests/scenarios/sample-prd-multi-scope.md && echo "EXISTS"
# Frontmatter has scopes block with 3 scopes
grep -A 10 "^scopes:" tests/scenarios/sample-prd-multi-scope.md | grep -cE "^\s+(BE|MW|FE):"
# Body has 3 scope-specific sections
grep -c "^# §Backend$" tests/scenarios/sample-prd-multi-scope.md
grep -c "^# §Middleware$" tests/scenarios/sample-prd-multi-scope.md
grep -c "^# §Frontend$" tests/scenarios/sample-prd-multi-scope.md
```

Expected: EXISTS, 3, 1, 1, 1

- [ ] **Step 6.3: Commit**

```bash
git add tests/scenarios/sample-prd-multi-scope.md
git commit -m "test(iter-28): canonical multi-scope PRD fixture

Smaller version of multi-scope-example.md for fast test usage.
Healthcare-domain clinic appointment system with 3 scopes
(BE/MW/FE) and 4 universal sections.

Used by skill-triggering tests to validate scope detection,
scope picker UI, vault filtering, and sibling scope rendering.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: Create test fixture — legacy PRD (no frontmatter)

**Files:**
- Create: `tests/scenarios/sample-prd-legacy-no-frontmatter.md`

- [ ] **Step 7.1: Write legacy PRD fixture (no scopes block)**

Write to `tests/scenarios/sample-prd-legacy-no-frontmatter.md`:

```markdown
# Order System PRD (Legacy, no canonical frontmatter)

**Author**: Old Product Team
**Date**: 2025-11-10
**Status**: Draft

A simple order system. Customers place orders; warehouse fulfills; customer service handles support.

## 1. Goals

- Online ordering replaces phone
- Real-time order tracking
- Inventory sync with warehouse

## 2. User Roles

- Customer
- Warehouse Operator
- Customer Service Rep

## 3. API Design

Backend Lead: Alice Doe

REST endpoints:
- POST /api/orders
- GET /api/orders/{id}
- POST /api/orders/{id}/cancel

Auth: Bearer token (Sanctum).

## 4. Database Schema

Postgres 15. Tables:
- customer (id, email, phone, name)
- order (id, customer_id, status, total)
- order_item (id, order_id, product_id, quantity)

Migration via Laravel migrations.

## 5. User Interface

UX Lead: Bob Smith

Pages:
- /products — catalog
- /cart — review items
- /checkout — payment
- /orders — customer order history

Bootstrap-based Vuexy theme. Mobile responsive at 375px.

## 6. Migration Plan

Migrate from legacy phone-based system. Run parallel for 2 months. Decommission legacy 2026 Q2.

## 7. Wireframes

(See attached PDF: order-mgmt-wireframes-v2.pdf)

## 8. External Integrations

Integration Lead: Carol Lee

- Stripe for payments (webhook → MW → BE)
- SendGrid for emails
- Kafka topic `orders.events` for internal pub/sub
- Warehouse system polled every 60s for shipment status

## 9. Out of Scope

- Mobile app (v2)
- Multi-currency
- Loyalty rewards
```

- [ ] **Step 7.2: Verify fixture has NO frontmatter scopes block**

```bash
test -f tests/scenarios/sample-prd-legacy-no-frontmatter.md && echo "EXISTS"
# No frontmatter at all
grep -c "^---$" tests/scenarios/sample-prd-legacy-no-frontmatter.md
# Scopes implicit in body (BE/FE/MW mentions)
grep -c "Backend Lead" tests/scenarios/sample-prd-legacy-no-frontmatter.md
grep -c "UX Lead" tests/scenarios/sample-prd-legacy-no-frontmatter.md
grep -c "Integration Lead" tests/scenarios/sample-prd-legacy-no-frontmatter.md
```

Expected: EXISTS, 0 (no frontmatter), 1, 1, 1

- [ ] **Step 7.3: Commit**

```bash
git add tests/scenarios/sample-prd-legacy-no-frontmatter.md
git commit -m "test(iter-28): legacy PRD fixture (no canonical frontmatter)

Realistic legacy PRD without scopes frontmatter block. Scope
indicators present implicitly via role mentions (Backend Lead,
UX Lead, Integration Lead) + section headers (API Design,
User Interface, External Integrations).

Triggers mega-sdd retrofit bridge during scope detection. Used
to test AI subagent retrofit prompt + diff confirmation UX.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Create test fixture — single-scope PRD

**Files:**
- Create: `tests/scenarios/sample-prd-single-scope.md`

- [ ] **Step 8.1: Write single-scope PRD fixture**

Write to `tests/scenarios/sample-prd-single-scope.md`:

```markdown
---
title: "Internal Reporting Service (Single-scope test fixture)"
type: PRD
version: "1.0"
status: draft
date: 2026-05-23
authors: ["Test Suite"]
industry: general
stakeholders:
  - { role: "BE Architect", name: "Test BE", email: "be@test.local" }

# Single-scope: only BE declared. No multi-scope semantics expected.
scopes:
  BE:
    name: "Backend Service"
    pics: ["Test BE"]
    priority: 1
    sections: ["§Backend"]

universal_sections: ["§1", "§2", "§3"]
---

# §1. Executive Summary

Internal reporting service that aggregates data from operational DBs and emits daily reports to ops team.

# §2. Goals

- Daily PDF report generation by 6am
- Manual on-demand report trigger
- Email delivery to ops mailing list

# §3. Stakeholders

- Ops team (consumers)
- BE Architect (owner)

---

# §Backend

## §Backend.1 Functional
- FR-001: Cron job runs daily at 5am
- FR-002: Aggregates data from 3 operational DBs
- FR-003: Generates PDF report
- FR-004: Sends email via SendGrid

## §Backend.4 Data Model
- report_run: id, run_at, status, report_path

## §Backend.5 Acceptance
- Daily report delivered by 6am
- Manual trigger via POST /api/reports/generate
```

- [ ] **Step 8.2: Verify single-scope fixture**

```bash
test -f tests/scenarios/sample-prd-single-scope.md && echo "EXISTS"
# Has scopes block but with only ONE scope
grep -A 5 "^scopes:" tests/scenarios/sample-prd-single-scope.md | grep -cE "^\s+(BE|MW|FE|[A-Z]+):"
# No multi-scope sections
grep -c "^# §Middleware$" tests/scenarios/sample-prd-single-scope.md
grep -c "^# §Frontend$" tests/scenarios/sample-prd-single-scope.md
```

Expected: EXISTS, 1, 0, 0

- [ ] **Step 8.3: Commit**

```bash
git add tests/scenarios/sample-prd-single-scope.md
git commit -m "test(iter-28): single-scope PRD fixture

PRD declares only 1 scope (BE). Mega-sdd should route to legacy
single-vault flow without scope picker (only 1 option exists).

Used to test boundary: scope detection picks up the single scope
silently, no AskUserQuestion fired, vault generated normally.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: Create scenario-7 multi-architect walkthrough

**Files:**
- Create: `tests/scenarios/scenario-7-multi-architect.md`

- [ ] **Step 9.1: Write scenario walkthrough**

Write to `tests/scenarios/scenario-7-multi-architect.md`:

```markdown
# Scenario 7 — Multi-Architect (Multi-Scope PRD)

**Time**: 60 minutes total (20 min per architect)
**When to use**: Project where PRD is shared across multiple IT architects (BE, MW, FE) — each architect generates their own vault for their scope only

**Prerequisites**:
- Mega-sdd v3.20.0+ (Iter 28 multi-scope picker)
- Canonical PRD with `scopes:` frontmatter (or legacy PRD via retrofit bridge)
- Three separate repos (BE, MW, FE) — or three separate folders within one monorepo
- Each architect operating in their own session

## Setup (one-time, by Product Owner)

1. Product Owner writes PRD following `docs/templates/prd-template.md`
2. PRD frontmatter declares scopes block with BE, MW, FE
3. PRD shared via shared docs (Notion, Git, Drive) to all 3 architects
4. Each architect clones PRD into their working folder

```bash
# Architect BE
cd ~/projects/order-management-be/
cp ~/shared/order-mgmt-prd.md ./prd.md

# Architect MW
cd ~/projects/order-management-mw/
cp ~/shared/order-mgmt-prd.md ./prd.md

# Architect FE
cd ~/projects/order-management-fe/
cp ~/shared/order-mgmt-prd.md ./prd.md
```

## Phase 1 — Architect BE generates vault (20 min)

```bash
cd ~/projects/order-management-be/
/mega-sdd:auto ./prd.md
```

Expected output:

```
▶ Phase 0a: PRD scope detection
  Reading ./prd.md frontmatter...
  ✓ Canonical format detected (scopes: BE, MW, FE)
  Smart default: BE (cwd basename `order-management-be` matches)

❓ This vault is for which scope?
   [1] BE — Backend API (recommended)
   [2] MW — Integration Middleware
   [3] FE — Frontend Web
   [4] All scopes (single combined vault — legacy behavior)
   [5] Cancel
```

User picks `[1] BE`.

```
✓ Scope: BE locked in.
  Filtering PRD to: §Backend + universal sections §1-§7
  Sibling scopes noted: MW, FE

▶ Phase 0b: Starterkit detection (Iter 27)
  ✓ composer.json → laravel-base-26 detected

▶ Phase 1: scan-codebase ./
  Output: .mega-sdd/codebase/codebase-map.md
  §7 Framework: laravel-base-26 (pack loaded)

▶ Phase 2: generate-intent --scope=BE --scan ./prd.md
  Output: .mega-sdd/vaults/order-management-be/
  - vault.json: scope=BE, scope_metadata declared, prd_sha256 recorded
  - 00-index.md: scope header + sibling scopes (MW, FE) noted + locked contracts listed

▶ Phase 3: bind-codebase
▶ Phase 4: generate-units
▶ Phase 5: execute-bolts (auto, with halts on conflict)
```

BE architect's vault is at `.mega-sdd/vaults/order-management-be/`. 00-index.md shows:

```markdown
# Vault: Order Management System — BE

**Scope**: Backend API (BE)
**PICs**: Alex Tan
**Priority**: 1

## Sibling scopes (managed externally)
- MW — Integration Middleware (PIC: Budi Santoso; priority: 2)
- FE — Frontend Web (PIC: Maya Putri; priority: 3)

## Locked contracts this scope PUBLISHES
- BE-MW-event-bus
- BE-FE-orders-api
```

Memory entry written:
```
<project>/.mega-sdd/memory/decisions.md
| sha256 abc... | Order Mgmt v1.0 | 2026-05-23 | BE | order-management-be | 0 |
```

## Phase 2 — Architect FE generates vault (20 min, different session)

```bash
cd ~/projects/order-management-fe/
/mega-sdd:auto ./prd.md
```

Same PRD, different cwd. Smart default suggests FE.

User picks `[3] FE`.

Vault filtered to §Frontend + universal sections. 00-index.md shows:

```markdown
# Vault: Order Management System — FE

**Scope**: Frontend Web (FE)
**Priority**: 3

## Sibling scopes (managed externally)
- BE — Backend API (PIC: Alex Tan; priority: 1)
- MW — Integration Middleware (PIC: Budi Santoso; priority: 2)

## Locked contracts this scope CONSUMES
- BE-FE-orders-api → see PRD §Cross-scope contracts
- MW-FE-realtime-channels → see PRD §Cross-scope contracts
```

## Phase 3 — Architect BE re-runs (memory hit demo)

BE architect adds a unit, re-runs:

```bash
cd ~/projects/order-management-be/
/mega-sdd:auto ./prd.md
```

Expected:

```
▶ PRD ./prd.md recognized (sha256: abc123..., last scope: BE 2026-05-23)

❓ Same scope this run?
   [Enter] BE (default after 5s; confirm-once)
   [2/3/4] Different scope
   [5] Cancel
```

User presses Enter. Silent re-run with BE scope. No friction.

## Phase 4 — Architect MW generates vault (later that day)

MW architect arrives later, fresh session:

```bash
cd ~/projects/order-management-mw/
/mega-sdd:auto ./prd.md
```

User picks `[2] MW` (cwd basename matches).

MW vault generated. Cross-scope contracts referenced:
- Consumes: BE-MW-event-bus (BE publishes; MW receives)
- Publishes: MW-FE-realtime-channels (MW publishes; FE receives)

## Validation: independent vaults

Each architect has their own vault. No cross-vault automation by mega-sdd.

```bash
# Validate scope tagging
jq -r '.scope' ~/projects/order-management-be/.mega-sdd/vaults/*/vault.json
# Output: BE

jq -r '.scope' ~/projects/order-management-fe/.mega-sdd/vaults/*/vault.json
# Output: FE

jq -r '.scope' ~/projects/order-management-mw/.mega-sdd/vaults/*/vault.json
# Output: MW
```

Cross-scope coordination happens OUTSIDE mega-sdd — architects meet, lock contracts in PRD §Cross-scope contracts, then re-generate vaults.

## What if PRD changes mid-flight

PM updates PRD to add new endpoint:

```bash
# Architect BE
/mega-sdd:auto ./prd.md
```

Memory check:
```
▶ PRD ./prd.md recognized (sha256: NEW_HASH... — content changed since last invocation)

⚠️ PRD content changed since last vault generation (2026-05-23, sha: abc123...)
   Run diff-vault to apply revisions? [Y/n]
```

User runs `/mega-sdd:diff-vault ./prd.md` → revisions applied; bolts re-execute for changed units only.

## Common questions

**Q: What if architect FE invokes `--scope=BE` flag?**
A: Mega-sdd halts `scope_not_declared_in_prd` IF cwd doesn't have BE manifest signals; otherwise proceeds with BE scope (architect is explicitly overriding role). Useful for architect doing cross-scope review.

**Q: How do BE and FE architects coordinate on the locked contract `BE-FE-orders-api`?**
A: Outside mega-sdd. Both vaults reference the contract section in PRD. When contract changes:
1. BE + FE architects agree on new spec in rapat
2. PM updates PRD §Cross-scope contracts > be-fe-orders-api
3. Both architects run `/mega-sdd:auto --resume` → diff-vault detects PRD change → revisions applied per-scope

**Q: What if PRD has no scopes frontmatter?**
A: Retrofit bridge fires (per `scope-picker.md` step 2). AI proposes scope partitioning. User accepts or rejects per scope. Retrofit written to `<prd>.retrofit.md` (preserves original).

**Q: Can one architect own multiple scopes?**
A: Yes. PRD `scopes:` can have same person in multiple `pics` arrays. Architect runs mega-sdd once per scope they own; gets multiple vaults.
```

- [ ] **Step 9.2: Verify scenario walkthrough**

```bash
test -f tests/scenarios/scenario-7-multi-architect.md && echo "EXISTS"
grep -c "^## Phase" tests/scenarios/scenario-7-multi-architect.md
grep -c "scope" tests/scenarios/scenario-7-multi-architect.md
```

Expected: EXISTS, 4+ phases, multiple "scope" mentions

- [ ] **Step 9.3: Commit**

```bash
git add tests/scenarios/scenario-7-multi-architect.md
git commit -m "test(iter-28): scenario-7 multi-architect walkthrough

Demonstrates Iter 28 multi-scope flow with 3 architects:
- Phase 1: BE architect generates BE-only vault
- Phase 2: FE architect generates FE-only vault (different repo)
- Phase 3: BE re-run shows memory hit + silent default
- Phase 4: MW architect joins later

Includes validation commands (jq scope tagging check),
common-question FAQ, cross-scope coordination policy
(outside mega-sdd; rapat antar arsitek).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 10: Update generate-intent SKILL.md — Step 0.6 scope detection + --scope flag

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-intent/SKILL.md`

- [ ] **Step 10.1: Read current generate-intent SKILL.md frontmatter + Step 0**

```bash
head -5 plugins/mega-sdd/skills/generate-intent/SKILL.md
```

Expected: shows `version: 1.11.0` in frontmatter.

- [ ] **Step 10.2: Bump version**

Use Edit tool on `plugins/mega-sdd/skills/generate-intent/SKILL.md`:

- Find: `version: 1.11.0`
- Replace with: `version: 1.12.0`

- [ ] **Step 10.3: Add Step 0.6 to Procedure section**

Find the section header `## Procedure` in `plugins/mega-sdd/skills/generate-intent/SKILL.md`. After the existing Step 0 (output path) and before Step 1, insert Step 0.6.

Use Edit tool — find the exact text where Step 1 begins (start of "1. **Load PRD**" or equivalent line — check actual file), and prepend the new step.

Content for Step 0.6:

```markdown
0.6. **Scope detection + PRD filtering (v1.12+, Iter 28).** Per `references/scope-picker.md`.

   a. **Read PRD frontmatter.**
      - If `scopes:` block present (canonical multi-scope PRD) → step b
      - If absent → step c (legacy retrofit bridge)

   b. **Canonical scope handling**:
      - If only one scope declared → silent route to legacy single-vault flow (no picker)
      - If multiple scopes declared:
        - If `--scope=<id>` flag set → validate against declared scopes; halt `scope_not_declared_in_prd` if invalid
        - Else if `<project>/.mega-sdd/memory/decisions.md` has prior choice for this PRD sha256 + same cwd basename → silent default with confirm-once UX (5s timeout)
        - Else → invoke `AskUserQuestion` with options:
          - One option per declared scope (smart-default flagged per cwd heuristic)
          - "All scopes (single combined vault — legacy behavior)" option (legacy fallback)
          - "Cancel" option
        - If user chose `--scope=all` (legacy) → emit warning, proceed with all content (current behavior pre-Iter-28)
      - After scope chosen: filter PRD content per `references/scope-picker.md` §Filter logic
      - Persist scope choice to memory per `references/scope-picker.md` §Memory write rules
      - Tag vault.json with `scope`, `scope_metadata`, `prd_sha256` per `references/vault-contract.md` §Multi-scope vault
      - Render sibling scopes informational notes in `00-index.md` per same reference

   c. **Legacy PRD retrofit bridge**:
      - Invoke `AskUserQuestion` with options:
        - "Yes, propose retrofit (recommended)" — dispatches AI subagent per `references/legacy-retrofit-prompt.md`
        - "Treat as single-scope PRD" — routes to legacy single-vault flow
        - "Cancel — manual fix first"
      - On retrofit chosen:
        - Dispatch subagent with prompt template; receive structured analysis
        - Render diff to user (detected scopes + evidence + proposed frontmatter + section restructure)
        - `AskUserQuestion`: accept / review per scope / skip / cancel
        - On accept: write retrofit to `<prd-name>.retrofit.md` (preserves original); restart Step 0.6 from step a using retrofit file
        - On overall_confidence: LOW → halt `prd_retrofit_low_confidence` with options

   `--scope=<id>` and `--greenfield` flags interact as documented in `commands/generate-intent.md` §Flag combinations.
```

- [ ] **Step 10.4: Update Inputs section to document --scope flag**

Find the Inputs section in `plugins/mega-sdd/skills/generate-intent/SKILL.md`. Add a new bullet for `--scope`:

Use Edit tool to find `--greenfield` documentation line, add `--scope=<id>` flag documentation right after it:

```markdown
- `--scope=<id>` (v1.12+ Iter 28): explicit scope selection (BE, MW, FE, custom id, or `all` for legacy single-vault). When PRD has `scopes:` block AND flag not set → interactive picker fires. Halt `scope_not_declared_in_prd` if id not in PRD scopes.
```

- [ ] **Step 10.5: Add halt types to Halt conditions section**

Find the `## Halt conditions` section. Add 3 new halts to the list:

```markdown
- (v1.12+, Iter 28) `--scope=<id>` flag mismatches PRD scopes block → halt `scope_not_declared_in_prd`
- (v1.12+, Iter 28) PRD lacks `scopes:` frontmatter AND user rejected retrofit AND chose cancel → halt `prd_no_scopes_block_user_rejected_retrofit`
- (v1.12+, Iter 28) AI retrofit subagent returned `overall_confidence: LOW` → halt `prd_retrofit_low_confidence` with options
```

- [ ] **Step 10.6: Verify changes**

```bash
grep "version: 1.12.0" plugins/mega-sdd/skills/generate-intent/SKILL.md
grep -c "0.6\." plugins/mega-sdd/skills/generate-intent/SKILL.md
grep -c "--scope=" plugins/mega-sdd/skills/generate-intent/SKILL.md
grep -c "scope_not_declared_in_prd" plugins/mega-sdd/skills/generate-intent/SKILL.md
```

Expected: 1 (version line), 1+ (Step 0.6 reference), 2+ (flag mentions), 1+ (halt mention)

- [ ] **Step 10.7: Commit**

```bash
git add plugins/mega-sdd/skills/generate-intent/SKILL.md
git commit -m "feat(generate-intent v1.12.0): scope detection + --scope flag (Iter 28)

Adds Step 0.6 scope detection between Step 0 (output path) and
Step 1 (Load PRD). Procedure:
  a. Read PRD frontmatter for scopes: block
  b. Canonical multi-scope: --scope flag / memory hit / interactive picker
  c. Legacy retrofit bridge if no scopes block

New flag --scope=<id> with semantics per references/scope-picker.md.

New halt types:
- scope_not_declared_in_prd
- prd_no_scopes_block_user_rejected_retrofit
- prd_retrofit_low_confidence

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 11: Add §Multi-scope vault section to vault-contract.md

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`

- [ ] **Step 11.1: Find insertion point**

```bash
grep -n "^## §" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
```

Identify where §Starterkit-binding ends (look for the line right before `## §boilerplate`). New §Multi-scope vault section goes right after §Starterkit-binding, before §boilerplate.

- [ ] **Step 11.2: Insert new §Multi-scope vault section**

Use Edit tool. Find the line `## §boilerplate — Skill instruction language` and prepend the new section before it:

```markdown
## §Multi-scope vault — Scope tagging schema (v1.12+, Iter 28)

When `generate-intent` runs with `--scope=<id>` flag OR canonical PRD has `scopes:` block, the vault is tagged with scope metadata. Single-scope PRDs without scopes block use current single-vault schema (no scope tagging).

### vault.json extension

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

### Field rules

| Field | Required | Set by | Purpose |
|---|---|---|---|
| `scope` | When `scope_metadata` exists | generate-intent Step 0.6 | Quick lookup; matches `scope_metadata.id` |
| `scope_metadata.id` | Yes | generate-intent | Stable id from PRD frontmatter |
| `scope_metadata.name` | Yes | generate-intent | Display name from PRD frontmatter |
| `scope_metadata.pics` | Yes | generate-intent | Array of architect names (team-shared) |
| `scope_metadata.priority` | No (default 1) | generate-intent | Delivery sequencing hint |
| `scope_metadata.prd_sections_used` | Yes | generate-intent | Computed: universal_sections + scope.sections |
| `scope_metadata.sibling_scopes_in_prd` | Yes | generate-intent | Other scopes from PRD (informational) |
| `scope_metadata.consumed_locked_contracts` | Yes | generate-intent | From PRD scope's `depends_on_locked_contracts` |
| `scope_metadata.published_locked_contracts` | Yes | generate-intent | Computed: contracts where this scope is `from` in `cross_scope_dependencies` |
| `prd_sha256` | Yes | generate-intent | For memory-driven scope default on re-invocation |
| `prd_path_at_generation` | Yes | generate-intent | For PRD change tracking via diff-vault |

### 00-index.md header structure

When vault has scope metadata, `00-index.md` header MUST include:

```markdown
# Vault: <Project Name> — <Scope ID>

**Scope**: <scope_metadata.name> (`<scope_metadata.id>`)
**PICs**: <comma-separated pics list>
**Priority**: <scope_metadata.priority> (delivery sequencing hint)
**PRD source**: `<prd_path_at_generation>` (sha256: `<prd_sha256>`)
**Universal sections included**: <comma-separated universal_sections>
**Scope-specific section**: <scope_metadata.sections>

## Sibling scopes (managed externally — NOT in this vault)

- **<sibling_id>** — <sibling_name> (PIC: <name>; priority: <N>)
- ...

> Cross-scope coordination handled OUTSIDE mega-sdd. Each scope generates an independent vault.
> Locked contracts cross-referenced below for awareness, NOT enforcement.

## Locked contracts this scope PUBLISHES

- `<contract-id>` → see PRD §Cross-scope contracts > <contract-id>
- ...

## Locked contracts this scope CONSUMES

- `<contract-id>` → see PRD §Cross-scope contracts > <contract-id>
- ...
```

When vault has NO scope metadata (legacy single-scope PRD), 00-index.md header omits scope/sibling/contracts sections entirely.

### Validation rules (enforced by generate-intent at write time)

- If `scope` field present → `scope_metadata` MUST exist with all required fields
- `scope_metadata.id` MUST match PRD frontmatter `scopes.<id>` key
- `sibling_scopes_in_prd` MUST list ALL other scopes from PRD scopes block (not chosen ones)
- `prd_sha256` MUST be sha256 of PRD content at generation time (used by memory recall)
- When chosen scope == `all` (legacy flag) → vault written without `scope` field (back-compat)

### Backward compatibility

- Pre-v1.12 vaults (no `scope` field) → consumed unchanged by bind-codebase + generate-units
- Mixed vaults (some scoped, some legacy) permitted in same project — orchestrate-flow handles both
- diff-vault reads `prd_sha256` to detect PRD changes; pre-v1.12 vaults skip this check gracefully

```

- [ ] **Step 11.3: Verify changes**

```bash
grep -c "^## §Multi-scope vault" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
grep -c "prd_sha256" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
```

Expected: 1, 2+ (multiple references)

- [ ] **Step 11.4: Commit**

```bash
git add plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
git commit -m "feat(iter-28): vault-contract.md §Multi-scope vault section

Documents vault.json scope tagging schema:
- scope, scope_metadata block, prd_sha256, prd_path_at_generation
- Field rules table with required/optional + set-by + purpose
- 00-index.md header structure (scope, sibling, contracts)
- Validation rules enforced by generate-intent
- Backward compat for pre-v1.12 vaults

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 12: Add §PRD Scope Decisions to memory-schema.md

**Files:**
- Modify: `plugins/mega-sdd/skills/memory/references/memory-schema.md`

- [ ] **Step 12.1: Find insertion point**

```bash
grep -n "^## " plugins/mega-sdd/skills/memory/references/memory-schema.md | head -10
```

Identify the §PROJECT scope subsection. Add §PRD Scope Decisions to the decisions.md file schema.

- [ ] **Step 12.2: Find decisions.md schema section**

```bash
grep -n "decisions.md" plugins/mega-sdd/skills/memory/references/memory-schema.md | head -5
```

Locate the section documenting decisions.md content. Append new subsection.

- [ ] **Step 12.3: Add §PRD Scope Decisions subsection**

Use Edit tool. Find the line that ends the decisions.md schema (search for a heading like `## CONFLICT resolutions` table example or similar last section). Append:

```markdown
### PRD Scope Decisions (v1.12+, Iter 28)

Records each invocation's PRD → scope mapping. Drives "silent default" on re-invocation when PRD sha256 + cwd basename match.

```markdown
## PRD Scope Decisions

| PRD sha256 | PRD title | Date | Scope picked | Architect cwd | Override count |
|---|---|---|---|---|---|
| abc123... | Order Mgmt System v1.0 | 2026-05-23 | BE | order-management-be | 0 |
| def456... | Payment Gateway v1.0 | 2026-05-24 | MW | payment-mw | 0 |
```

Write rules:
- First-time scope pick on a PRD → INSERT new row
- Re-invocation on same PRD + same scope → NO write (no change)
- Re-invocation on same PRD + DIFFERENT scope → increment `override_count` on existing row for PRD+old scope; INSERT new row for PRD+new scope

Read rules:
- On generate-intent Step 0.6: lookup PRD sha256 → if found AND cwd basename matches → propose last-used scope as silent default with confirm-once UX
- Lookup is local to project memory; cross-project PRD scope decisions tracked separately (each project has own decisions.md)

```

- [ ] **Step 12.4: Verify**

```bash
grep -c "PRD Scope Decisions" plugins/mega-sdd/skills/memory/references/memory-schema.md
grep -c "Override count" plugins/mega-sdd/skills/memory/references/memory-schema.md
```

Expected: 2+, 1

- [ ] **Step 12.5: Commit**

```bash
git add plugins/mega-sdd/skills/memory/references/memory-schema.md
git commit -m "feat(iter-28): memory schema PRD Scope Decisions table

Adds new subsection to decisions.md schema documenting per-PRD
scope decision tracking with override count. Used by Iter 28
scope picker for memory-driven silent default on re-invocation.

Write rules: insert on first pick, increment override on switch.
Read rules: lookup by PRD sha256 + cwd basename match.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 13: Add scope: block to handoff-contract.md

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`

- [ ] **Step 13.1: Find insertion point**

```bash
grep -n "mutability:" plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
```

The `mutability:` block is at handoff YAML schema (added in Iter 25). Add new `scope:` block right after it.

- [ ] **Step 13.2: Add scope: block**

Use Edit tool. Find:

```yaml
  mutability:                           # v3.17+ (Iter 25 — propagates Iter 22 mutability tiers)
```

After this block ends (look for the line right before `metadata:` block), insert:

```yaml
  scope:                                # v3.20+ (Iter 28 — propagates multi-scope PRD picker)
    id: <scope id, e.g., "BE">          # from vault.json scope_metadata.id (omit if legacy single-scope vault)
    name: <scope name>                  # from vault.json scope_metadata.name
    sibling_scopes: []                  # list of OTHER scopes from PRD (informational)
    prd_sha256: <sha256>                # from vault.json (used by downstream skills to detect PRD changes)
```

- [ ] **Step 13.3: Verify**

```bash
grep -c "scope:" plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
grep -c "sibling_scopes:" plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
```

Expected: 2+ (existing + new), 1

- [ ] **Step 13.4: Commit**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md
git commit -m "feat(iter-28): handoff-contract.md scope block

Adds scope: { id, name, sibling_scopes, prd_sha256 } to handoff
YAML schema. Informational only — orchestrate-flow doesn't act
on it (no cross-scope automation), but downstream skills (e.g.,
diff-vault) read prd_sha256 for change detection.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 14: Update using-mega-sdd anchor to mention multi-scope picker

**Files:**
- Modify: `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md`

- [ ] **Step 14.1: Read current version**

```bash
head -5 plugins/mega-sdd/skills/using-mega-sdd/SKILL.md
```

Expected: shows current version (likely 1.3.0 from Iter 27).

- [ ] **Step 14.2: Bump version**

Use Edit tool:
- Find: `version: 1.3.0`
- Replace with: `version: 1.3.1`

- [ ] **Step 14.3: Add multi-scope picker note**

Find the section "## Starterkit-first mode (v1.3+, Iter 27)" or similar Iter 27 section. After it (or at end of "Sharper auto-trigger" section), add:

```markdown
### Multi-scope PRD picker (v1.3.1+, Iter 28)

When `/mega-sdd:auto` invoked on a PRD with canonical multi-scope format (`scopes:` frontmatter), the chain proposal surfaces scope picker upfront:

```
Detected scopes in PRD: BE, MW, FE
Smart default: BE (cwd basename matches)

❓ This vault is for which scope?
   [1] BE — Backend API (recommended)
   [2] MW — Integration Middleware
   [3] FE — Frontend Web
   [4] All scopes (legacy single-vault)
   [5] Cancel
```

When PRD lacks scopes block → retrofit bridge fires (per `generate-intent/references/legacy-retrofit-prompt.md`).

When memory has prior scope for this PRD + same cwd → silent default with confirm-once UX (5s timeout).

`--scope=<id>` flag bypasses picker entirely. `--scope=all` falls back to legacy single-vault behavior.

See `tests/scenarios/scenario-7-multi-architect.md` for end-to-end walkthrough.
```

- [ ] **Step 14.4: Verify**

```bash
grep "version: 1.3.1" plugins/mega-sdd/skills/using-mega-sdd/SKILL.md
grep -c "Multi-scope PRD picker" plugins/mega-sdd/skills/using-mega-sdd/SKILL.md
```

Expected: 1, 1

- [ ] **Step 14.5: Commit**

```bash
git add plugins/mega-sdd/skills/using-mega-sdd/SKILL.md
git commit -m "feat(using-mega-sdd v1.3.1): document multi-scope picker (Iter 28)

Adds section describing Iter 28 multi-scope picker UX surfaced
when /mega-sdd:auto invoked on canonical PRD. Includes memory
hit + confirm-once flow + --scope flag semantics.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 15: Update commands/auto.md and commands/generate-intent.md

**Files:**
- Modify: `plugins/mega-sdd/commands/auto.md`
- Modify: `plugins/mega-sdd/commands/generate-intent.md`

- [ ] **Step 15.1: Update auto.md argument-hint**

Use Edit tool on `plugins/mega-sdd/commands/auto.md`. Find:

```
argument-hint: [input] [--deep|--shallow] [--greenfield] [--step-after=<phase>]
```

Replace with:

```
argument-hint: [input] [--deep|--shallow] [--greenfield] [--scope=<id>] [--step-after=<phase>]
```

(Adds `[--scope=<id>]` flag in argument-hint.)

- [ ] **Step 15.2: Add scope picker section to auto.md**

Find the section "## Starterkit detection (v3.19+, Iter 27)". After it, add:

```markdown
## Multi-scope picker (v3.20+, Iter 28)

When PRD input has canonical `scopes:` frontmatter block, auto invokes scope picker BEFORE pipeline starts:

```
▶ Phase 0a: PRD scope detection
  Reading <prd-path> frontmatter...
  ✓ Canonical format detected (scopes: BE, MW, FE)
  Smart default: BE (cwd basename matches scope id)

❓ This vault is for which scope?
   [1] BE — Backend API (recommended)
   [2] MW — Integration Middleware
   [3] FE — Frontend Web
   [4] All scopes (single combined vault — legacy behavior)
   [5] Cancel
```

`--scope=<id>` flag bypasses picker. `--scope=all` invokes legacy single-vault behavior (with warning).

When PRD lacks scopes block → retrofit bridge fires per `skills/generate-intent/references/legacy-retrofit-prompt.md`.

When memory has prior scope decision for this PRD + cwd matches → silent default with confirm-once UX.

See `tests/scenarios/scenario-7-multi-architect.md` for walkthrough.
```

- [ ] **Step 15.3: Update generate-intent.md argument-hint**

Use Edit tool on `plugins/mega-sdd/commands/generate-intent.md`. Find:

```
argument-hint: [<prd-path> | --from-prompt "<brief>" | --kb=<path>] [--scan=<path>|--greenfield] [--out=<path>] [--auto]
```

Replace with:

```
argument-hint: [<prd-path> | --from-prompt "<brief>" | --kb=<path>] [--scan=<path>|--greenfield] [--scope=<id>] [--out=<path>] [--auto]
```

- [ ] **Step 15.4: Add flag combination matrix to generate-intent.md**

Find a suitable location (after existing flag descriptions). Add:

```markdown
## Flag combinations (v1.12+, Iter 28)

| Flag combo | Behavior |
|---|---|
| (no flags, PRD has scopes block, 1 scope) | Silent → single-vault behavior |
| (no flags, PRD has scopes block, ≥2 scopes) | Interactive picker fires |
| (no flags, PRD lacks scopes block) | Retrofit bridge fires |
| `--scope=<id>` (valid id in PRD) | Silent → scoped vault |
| `--scope=<id>` (invalid id) | Halt `scope_not_declared_in_prd` |
| `--scope=all` | Legacy single-vault behavior + warning |
| `--greenfield` + scopes block | Warning (scopes ignored); stack-agnostic single vault |
| `--scope=<id>` + `--kb=<path>` | Multi-scope legacy rebuild: KB intent × target scaffold × scope filter |
| `--scope=<id>` + `--scan=<map>` + `--kb=<path>` | Iter 22+23+27+28 full composition: pack-aware, mutability-tier-routed, scope-filtered vault |
| `--auto` + memory hit | Silent default scope from memory; no picker prompt |
```

- [ ] **Step 15.5: Verify both files**

```bash
grep -c "scope=<id>" plugins/mega-sdd/commands/auto.md
grep -c "scope=<id>" plugins/mega-sdd/commands/generate-intent.md
grep -c "Multi-scope picker" plugins/mega-sdd/commands/auto.md
grep -c "Flag combinations" plugins/mega-sdd/commands/generate-intent.md
```

Expected: 2+, 2+, 1, 1

- [ ] **Step 15.6: Commit**

```bash
git add plugins/mega-sdd/commands/auto.md plugins/mega-sdd/commands/generate-intent.md
git commit -m "feat(iter-28): command flags --scope= in auto + generate-intent

auto.md:
- Adds --scope=<id> to argument-hint
- New section: Multi-scope picker (v3.20+, Iter 28)

generate-intent.md:
- Adds --scope=<id> to argument-hint
- New section: Flag combinations matrix
- Documents 10 flag combos (scope x kb x scan x greenfield x auto)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 16: Create skill-triggering test for scope picker

**Files:**
- Create: `tests/skill-triggering/scope-picker.test.md`

- [ ] **Step 16.1: Verify target directory**

```bash
ls tests/skill-triggering/ 2>/dev/null | head -5
```

Expected: directory exists with other test files.

- [ ] **Step 16.2: Write skill-triggering test fixture**

Write to `tests/skill-triggering/scope-picker.test.md`:

```markdown
# Scope Picker — Skill Triggering Tests

Manual test fixtures for `generate-intent` Step 0.6 scope detection (Iter 28). Step through each case; document actual vs expected output.

## Test 1: Canonical multi-scope PRD → interactive picker

**Setup**:
- cwd: `~/test-projects/order-be/`
- PRD: `tests/scenarios/sample-prd-multi-scope.md`
- No `--scope` flag

**Invocation**:
```bash
cd ~/test-projects/order-be/
/mega-sdd:generate-intent ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- generate-intent detects `scopes: { BE, MW, FE }` from frontmatter
- AskUserQuestion fires with 5 options (3 scopes + "All scopes" + Cancel)
- Smart default: BE (cwd basename `order-be` matches BE)
- Option 1 labeled "BE — Backend API (recommended)"

**Pass criteria**: AskUserQuestion fires; BE recommended; vault tagged scope=BE on accept.

---

## Test 2: Canonical PRD + --scope=<valid> flag → silent

**Setup**: Same PRD as Test 1

**Invocation**:
```bash
/mega-sdd:generate-intent --scope=MW ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- generate-intent reads scopes; validates `MW` is declared
- NO AskUserQuestion (silent)
- Vault tagged scope=MW
- 00-index.md sibling scopes: BE, FE
- Consumed contracts: BE-MW-appointment-events
- Published contracts: (none — MW is mid-stream in this fixture)

**Pass criteria**: Silent execution; vault tagged scope=MW; sibling notes include BE+FE.

---

## Test 3: Canonical PRD + --scope=<invalid> flag → halt

**Setup**: Same PRD as Test 1

**Invocation**:
```bash
/mega-sdd:generate-intent --scope=XYZ ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- generate-intent reads scopes; validates `XYZ` not in declared list
- Halts `scope_not_declared_in_prd`
- Halt YAML shows: declared_scopes: [BE, MW, FE], requested_scope: XYZ
- Options: re-pick from valid list OR cancel

**Pass criteria**: Halt fires; YAML structure correct; no vault written.

---

## Test 4: Legacy PRD (no frontmatter) → retrofit bridge

**Setup**:
- PRD: `tests/scenarios/sample-prd-legacy-no-frontmatter.md`
- No `--scope` flag

**Invocation**:
```bash
/mega-sdd:generate-intent ./tests/scenarios/sample-prd-legacy-no-frontmatter.md
```

**Expected**:
- generate-intent reads PRD; no `scopes:` block detected
- AskUserQuestion fires with options:
  - [1] Yes, propose retrofit (recommended)
  - [2] Treat as single-scope PRD
  - [3] Cancel
- On user choosing [1]:
  - Subagent dispatched per `legacy-retrofit-prompt.md`
  - Detects: BE (Backend Lead: Alice Doe), FE (UX Lead: Bob Smith), MW (Integration Lead: Carol Lee)
  - Confidence: HIGH for BE+FE, MEDIUM for MW
  - Diff rendered to user

**Pass criteria**: Retrofit AskUserQuestion fires; subagent dispatched on accept; original PRD untouched.

---

## Test 5: Single-scope PRD → silent (no picker)

**Setup**:
- PRD: `tests/scenarios/sample-prd-single-scope.md`
- No `--scope` flag

**Invocation**:
```bash
/mega-sdd:generate-intent ./tests/scenarios/sample-prd-single-scope.md
```

**Expected**:
- generate-intent reads scopes; only 1 scope declared (BE)
- NO AskUserQuestion (silent — single scope is unambiguous)
- Vault tagged scope=BE
- 00-index.md sibling scopes: [] (empty)

**Pass criteria**: Silent execution; vault tagged scope=BE; no AskUserQuestion fired.

---

## Test 6: Memory hit on second invocation

**Setup**:
- cwd: `~/test-projects/order-be/`
- PRD: `tests/scenarios/sample-prd-multi-scope.md`
- Run Test 1 first (which records scope=BE to memory)

**Invocation**:
```bash
# Same PRD, same cwd, second time
/mega-sdd:generate-intent ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- generate-intent reads scopes; multi-scope detected
- Memory lookup: PRD sha256 found → last scope BE
- AskUserQuestion fires with shortened prompt:
  ```
  ▶ PRD ./...md recognized (last scope: BE)
  ❓ Same scope this run?
     [Enter] BE (default after 5s; confirm-once)
     [2/3/4] Different scope
     [5] Cancel
  ```
- On Enter (or 5s timeout): silent default to BE

**Pass criteria**: Confirm-once UX fires; BE silently defaulted; 5s timeout works.

---

## Test 7: --scope=all (legacy single-vault)

**Setup**: Same PRD as Test 1

**Invocation**:
```bash
/mega-sdd:generate-intent --scope=all ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- generate-intent skips picker entirely
- Warning emitted: "Combined vault may produce noisy units for non-applicable scopes."
- Vault written WITHOUT scope field (legacy behavior)
- All PRD content included (universal + BE + MW + FE)

**Pass criteria**: Warning shown; vault has no scope field; full content included.

---

## Test 8: --scope=BE + --kb=<path> + --scan=<map> (full composition)

**Setup**:
- cwd: `~/test-projects/order-be/`
- PRD: `tests/scenarios/sample-prd-multi-scope.md`
- KB: synthetic `.mega-sdd/knowledge-base/` from prior extract-intelligence run
- codebase-map: synthetic `.mega-sdd/codebase/codebase-map.md` with framework: laravel-base-26

**Invocation**:
```bash
/mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/ --scan=.mega-sdd/codebase/codebase-map.md --scope=BE ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- Scope filter applied first (BE-only PRD content)
- KB consulted with tier-aware routing (Iter 22): [LOCKED] preserved, [INTENT] free
- Framework pack loaded (Iter 23): laravel-base-26 Hard Rules emitted
- Starterkit-first vault (Iter 27): dual-citation in 02-architecture
- Vault has scope=BE + scope_metadata + pack_path + KB tier annotations

**Pass criteria**: All four iters compose correctly; vault has all expected metadata fields.

---

## Notes

- All tests can run manually by stepping through generate-intent skill procedure
- Skill should announce which test case is active for traceability
- Failed test → file issue with verbatim AskUserQuestion output / halt YAML / vault.json
```

- [ ] **Step 16.3: Verify**

```bash
test -f tests/skill-triggering/scope-picker.test.md && echo "EXISTS"
grep -c "^## Test " tests/skill-triggering/scope-picker.test.md
```

Expected: EXISTS, 8 (tests 1-8)

- [ ] **Step 16.4: Commit**

```bash
git add tests/skill-triggering/scope-picker.test.md
git commit -m "test(iter-28): skill-triggering tests for scope picker

8 test fixtures covering Iter 28 scope picker scenarios:
- Test 1: canonical multi-scope → interactive picker
- Test 2: --scope flag → silent
- Test 3: --scope=invalid → halt
- Test 4: legacy PRD → retrofit bridge
- Test 5: single-scope → silent
- Test 6: memory hit → confirm-once UX
- Test 7: --scope=all → legacy single-vault
- Test 8: --scope + --kb + --scan full composition (Iter 22+23+27+28)

Manual test fixtures (step through procedure; document outputs).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 17: Bump versions + CHANGELOG + README + final commit

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json`
- Modify: `plugins/mega-sdd/README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 17.1: Bump plugin version**

Use Edit tool on `plugins/mega-sdd/.claude-plugin/plugin.json`:
- Find: `"version": "3.19.0",`
- Replace: `"version": "3.20.0",`

- [ ] **Step 17.2: Update plugins/mega-sdd/README.md**

Find: `## What's new in v3.19.0 (Iters 17-27)`
Replace: `## What's new in v3.20.0 (Iters 17-28)`

Find the last "What's new" bullet (Iter 27). After it, add:

```markdown
- **Iter 28 Multi-scope PRD picker** — canonical PRD/BRD format with `scopes:` frontmatter block enables deterministic scope detection. Each architect (BE/MW/FE) generates a vault scoped to ONLY their content. Interactive picker (cwd smart default + memory-driven recall + confirm-once). Legacy PRDs without frontmatter trigger AI-assisted retrofit bridge. No cross-scope orchestration — coordination remains human-driven (rapat antar arsitek). New `--scope=<id>` flag in `/mega-sdd:auto` + `/mega-sdd:generate-intent`. Governance artifact: `docs/templates/prd-template.md` for sharing with PMs as new SOP
```

- [ ] **Step 17.3: Update CHANGELOG.md — add Iter 28 entry**

Find the top of CHANGELOG.md (after the format header). Insert new section above `## [3.19.0]`:

```markdown
## [3.20.0] — 2026-05-23

### Added — Iter 28: Multi-Scope PRD Picker + Canonical Format

User's actual organizational workflow: PRD/BRD shared to multiple IT architects (BE, MW, FE) — each generates THEIR OWN vault for their scope only. Iter 28 makes this first-class.

### Two deliverables

1. **Governance artifact**: canonical PRD/BRD template at `docs/templates/prd-template.md` + `brd-template.md` + filled example `multi-scope-example.md`. Shared with PMs as new SOP.

2. **Mega-sdd skill behavior**: scope detection + interactive picker + AI-assisted retrofit for legacy PRDs.

### Frontmatter schema (canonical multi-scope PRD)

```yaml
---
title: "Order Management System"
type: PRD
scopes:
  BE: { name: "Backend API", pics: [...], priority: 1, sections: ["§Backend"] }
  MW: { name: "Integration Middleware", pics: [...], priority: 2, sections: ["§Middleware"] }
  FE: { name: "Frontend Web", pics: [...], priority: 3, sections: ["§Frontend"] }
universal_sections: ["§1", "§2", ...]
cross_scope_dependencies: [...]
---
```

### Three modes (resolves Iter 28 design §5.6.1)

| Mode | Trigger | Behavior |
|---|---|---|
| Canonical multi-scope | `scopes:` block + ≥2 scopes | Interactive picker (cwd smart default + memory hit) |
| `--scope=<id>` explicit | Flag set | Silent; halt if id invalid |
| Legacy (no scopes block) | Frontmatter missing | AI retrofit bridge; user accepts/rejects |
| Single-scope | scopes block with 1 entry | Silent route to single-vault |
| `--scope=all` (legacy) | Flag set | Single combined vault + warning |

### Updated skills

**generate-intent** (v1.11.0 → v1.12.0):
- New Step 0.6: scope detection + PRD filtering
- New flag `--scope=<id>`
- New halt types: `scope_not_declared_in_prd`, `prd_no_scopes_block_user_rejected_retrofit`, `prd_retrofit_low_confidence`
- References: scope-picker.md (algorithm) + legacy-retrofit-prompt.md (AI subagent template)

**using-mega-sdd** (v1.3.0 → v1.3.1):
- Anchor auto-trigger documents multi-scope picker UX

### Updated references

- `vault-contract.md`: new §Multi-scope vault section (vault.json scope tagging schema, 00-index.md header structure, validation rules)
- `memory/memory-schema.md`: new §PRD Scope Decisions table (per-PRD scope decisions with override count)
- `orchestrate-flow/handoff-contract.md`: new `scope:` block in handoff YAML (informational)

### Commands

- `auto.md`: new `--scope=<id>` flag in argument-hint + Multi-scope picker section
- `generate-intent.md`: new `--scope=<id>` flag + Flag combinations matrix (10 combos)

### Tests

- `tests/scenarios/sample-prd-multi-scope.md` (canonical fixture)
- `tests/scenarios/sample-prd-legacy-no-frontmatter.md` (retrofit trigger fixture)
- `tests/scenarios/sample-prd-single-scope.md` (boundary fixture)
- `tests/scenarios/scenario-7-multi-architect.md` (end-to-end walkthrough — 3 architects, 3 sessions, 1 PRD)
- `tests/skill-triggering/scope-picker.test.md` (8 skill-trigger fixtures)

### Composition with prior iters

Iter 28 composes correctly with:
- Iter 22 (KB mutability tiers): scope filter applies BEFORE KB tier routing
- Iter 23 (framework packs): scope-filtered vault still pack-aware
- Iter 27 (starterkit-first): scope picker fires AFTER scan-codebase (so smart default can use composer.json hints)
- Iter 11/12 (squads/modules): squads/modules live WITHIN a scope's vault (scope > squad > module > unit hierarchy)

### Out of scope (per design §3)

Deferred (NOT implemented in Iter 28):
- Cross-scope contract auto-locking (architect-rapat domain)
- Multi-vault parallel orchestration from single CLI invocation
- Cross-vault drift detection
- PRD format conversion from PDF/DOCX/Notion

### Governance

Architect rolls out new SOP gradually:
1. PMs adopt canonical format for NEW PRDs (zero friction)
2. Legacy PRDs use retrofit bridge as encountered (gradual cleanup)
3. Memory layer accumulates per-PRD scope decisions organically

### Plugin

3.19.0 → 3.20.0

### Skill version bumps

| Skill | Version |
|---|---|
| generate-intent | 1.11.0 → 1.12.0 |
| using-mega-sdd | 1.3.0 → 1.3.1 |

```

- [ ] **Step 17.4: Verify all updates**

```bash
grep '"version": "3.20.0"' plugins/mega-sdd/.claude-plugin/plugin.json
grep "v3.20.0" plugins/mega-sdd/README.md
grep "^## \[3.20.0\]" CHANGELOG.md
grep "Iter 28" CHANGELOG.md | head -3
```

Expected: 1 match each, multiple "Iter 28" mentions in CHANGELOG.

- [ ] **Step 17.5: Final inventory check — all expected files exist**

```bash
ls docs/templates/prd-template.md docs/templates/brd-template.md docs/templates/multi-scope-example.md
ls plugins/mega-sdd/skills/generate-intent/references/scope-picker.md plugins/mega-sdd/skills/generate-intent/references/legacy-retrofit-prompt.md
ls tests/scenarios/sample-prd-multi-scope.md tests/scenarios/sample-prd-legacy-no-frontmatter.md tests/scenarios/sample-prd-single-scope.md tests/scenarios/scenario-7-multi-architect.md
ls tests/skill-triggering/scope-picker.test.md
```

Expected: All 10 file paths echo back successfully (no "No such file" errors).

- [ ] **Step 17.6: Final commit — release v3.20.0**

```bash
git add plugins/mega-sdd/.claude-plugin/plugin.json plugins/mega-sdd/README.md CHANGELOG.md
git commit -m "$(cat <<'EOF'
feat(iter-28): multi-scope PRD picker release (v3.20.0)

Plugin: 3.19.0 -> 3.20.0
Skills bumped:
- generate-intent: 1.11.0 -> 1.12.0
- using-mega-sdd: 1.3.0 -> 1.3.1

User's actual organizational workflow: PRD/BRD shared to multiple
IT architects (BE, MW, FE) — each generates their own vault for
their scope only. Iter 28 makes this first-class.

Deliverables (per docs/superpowers/specs/2026-05-23-iter-28-...):
1. Governance artifacts (3 templates at docs/templates/)
2. References (2 docs in generate-intent/references/)
3. Skill changes (generate-intent v1.12.0 with Step 0.6)
4. Test fixtures (3 PRDs + scenario-7 walkthrough)
5. Skill-trigger tests (8 fixtures)
6. Schema updates (vault-contract.md, memory-schema.md, handoff-contract.md)
7. Command updates (auto.md, generate-intent.md)

Composes with Iter 22 (KB tiers) + Iter 23 (framework packs)
+ Iter 27 (starterkit-first). Out of scope per design: cross-scope
orchestration (remains human/rapat-driven).

Spec: docs/superpowers/specs/2026-05-23-iter-28-multi-scope-prd-picker-design.md
Plan: docs/superpowers/plans/2026-05-23-iter-28-multi-scope-prd-picker.md

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 17.7: Push**

```bash
git push origin main
```

Expected: ok main (push succeeds).

- [ ] **Step 17.8: Verify final state**

```bash
git log --oneline -20
```

Expected: 17 commits (one per Task) all on origin/main.

---

## Self-Review Notes (run after plan completion)

After implementing all tasks, verify:

1. **Spec coverage**: every section of `docs/superpowers/specs/2026-05-23-iter-28-multi-scope-prd-picker-design.md` is implemented (§5 templates, §6 detection algorithm, §7 skill changes, §8 vault tagging, §9 memory, §11 retrofit, §12 edge cases, §13 testing, §14 deliverables).

2. **Type consistency check**:
   - vault.json `scope_metadata` field names match across:
     - spec §8.1 schema
     - vault-contract.md §Multi-scope vault
     - handoff-contract.md scope: block
     - 00-index.md header rendering
   - Halt type names consistent: `scope_not_declared_in_prd` (not `scope_invalid` or similar variant)
   - PRD frontmatter field names match across:
     - prd-template.md
     - multi-scope-example.md
     - sample-prd-multi-scope.md
     - scope-picker.md algorithm

3. **Cross-references**:
   - generate-intent SKILL.md Step 0.6 cites scope-picker.md and legacy-retrofit-prompt.md
   - scope-picker.md cites vault-contract.md §Multi-scope vault
   - scenario-7 cites scope-picker.md procedures

4. **Placeholder scan**: search for "TBD", "TODO", "implement later" — no results expected.

---

**End of plan.**

Total tasks: 17  
Estimated execution time: 4-6 hours (markdown-heavy, low cognitive load per task)  
Risk areas: Task 10 (Step 0.6 insertion — easy to break existing procedure flow), Task 11 (vault-contract.md section ordering), Task 17 (CHANGELOG entry length — verify CHANGELOG remains valid markdown)
