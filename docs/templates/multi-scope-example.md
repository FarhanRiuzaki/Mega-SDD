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
    depends_on_locked_contracts: ["be-mw-event-bus"]
  FE:
    name: "Frontend Web"
    pics: ["Maya Putri"]
    priority: 3
    sections: ["§Frontend"]
    depends_on_locked_contracts: ["be-fe-orders-api", "mw-fe-realtime-channels"]

universal_sections: ["§1", "§2", "§3", "§4", "§5", "§6", "§7"]

cross_scope_dependencies:
  - { from: FE, to: BE, contract: "REST API per §Backend.3 endpoints" }
  - { from: BE, to: MW, contract: "OrderCreated event per §Middleware.2 schema" }
  - { from: FE, to: MW, contract: "Realtime order updates per §Middleware.4" }

regulatory_mapping:   # informational only — not machine-read by any mega-sdd skill
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
