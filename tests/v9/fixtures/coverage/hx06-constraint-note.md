# PRD: Payments
## Transfers
Transfers settle via BI-FAST.
## Non-Functional Requirements
p95 latency MUST stay under 300 ms.
## Data Model
Table transfers { client_ref varchar [unique] }
