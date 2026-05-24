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
