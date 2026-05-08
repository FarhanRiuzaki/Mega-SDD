# 06 — Constraints

> **TL;DR**: Batasan teknis, bisnis, regulasi, dan NFR yang harus dipenuhi.
> **Untuk siapa**: Architect, Tech Lead, PM, Compliance/Legal.
> **Baca kalau**: lo lagi pilih solusi, validasi feasibility, atau review compliance.

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

---

## Sources

- PRD §<X.Y>
- Compliance / regulatory documents
- SLA / contract references

## Out of Scope

- <constraints that are explicitly NOT applicable, e.g. "GDPR — no EU users in v1">
- <if unknown: "TBD - confirm with compliance / legal">

## Open Questions

- [ ] **OQ-CN-1** [P{1|2|3}]: <e.g. "Performance targets not specified in PRD">
- [ ] **OQ-CN-2** [P{1|2|3}]: <e.g. "Disaster recovery RTO / RPO not stated">
