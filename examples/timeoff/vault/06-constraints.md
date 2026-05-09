# 06 — Constraints

> **TL;DR**: Technical, business, regulatory, NFR + voice/brand constraints from PRD · audience: Architect, Tech Lead, PM, Compliance · read when validating feasibility or compliance.

## Technical constraints

- **Multi-tenant SaaS only** (D-001) — no on-prem deployment in v1.
- **Web-only client** (D-002) — no native mobile in v1.
- **Database**: PostgreSQL is "working assumption" per PRD §M; not yet locked → OQ-AR-2.
- **Hosting**: cloud provider TBD (AWS / GCP / Azure) per PRD §M → OQ-AR-6.
- **Email provider**: SendGrid is working assumption; alternatives Postmark / AWS SES under consideration → OQ-AR-8.
- **SSO**: must support Google Workspace OAuth + generic OIDC + password fallback (D-012).
- **Stripe**: payments and subscription management via Stripe Billing; org-level Stripe contract already in place per PRD §M.
- **iCal**: standard RFC 5545 format per PRD §M; no special server requirements beyond serving the feed file at a personal URL.

## Business constraints

- **Pricing target**: $2/seat/month per PRD §D (validated with 3 of 5+ prospects per PRD §O — pricing tier structure flat vs per-feature TBD per §L Q5).
- **Sign-off pending**: 0 of 4 stakeholder sign-offs collected per PRD §P (Sarah Chen / Mike Patel / Lisa Wong / Tom Yamamoto). Sprint-0 blocker until at least PM, Eng Lead, HR Lead, CTO sign.
- **Legal review of GDPR/CCPA compliance**: NOT STARTED per PRD §O (flagged for Q2). Sprint-0 blocker for EU/California-facing rollout.
- **Brand identity**: in progress (Maya Rodriguez owns) per PRD §O. Affects accent color choice, logo, marketing site.
- **Customer-research and competitive-analysis docs exist** per PRD §O (referenced as `customer-research-2026-Q1.md`, `competitive-analysis-2026-Q1.md`).

## Regulatory & compliance

- **GDPR** (EU users): data residency in EU region per PRD §I; explicit "delete my data" mechanism for departing employees.
- **CCPA** (California users): same delete-my-data mechanism per PRD §I.
- **Data retention**: 7 years for leave records per PRD §I (D-010).
- **Soft-delete with full audit trail** per PRD §I.
- **SOC 2**: NOT in scope for v1 per PRD §O (tracked for v2). Some prospects may require SOC 2 attestation; will gate enterprise sales until v2.

## Non-functional requirements

| Category | Requirement | Source |
|----------|-------------|--------|
| Performance — page load | p95 < 2 seconds | PRD §I |
| Performance — API response | p95 < 500 ms | PRD §I |
| Availability | 99.5% monthly uptime SLA | PRD §I |
| Scalability | Support 1,000 tenants × avg 75 employees ≈ 75,000 active users in year 1 | PRD §I, §E |
| Security — at rest | AES-256 encryption | PRD §I |
| Security — in transit | TLS 1.2+ | PRD §I |
| Observability | Structured logs to centralized store; metrics (p50/p95/p99 latency per endpoint, request rate, error rate); alerts on SLA dips | PRD §I |
| Backup | Daily full backups, retained 30 days; tenant-level restore within 4 hours of request | PRD §I |
| Notification SLA | Within 1 minute of triggering event (email + optional Slack) | PRD §G AC7-1, D-005 |

## Design system

> v0.6 design-system section appears here because PRD §J explicitly states tone, visual direction, and brand voice (Voice & brand sub-block). Tokens and a11y sub-blocks omitted — PRD has no design tokens / hex codes (Figma TBD), and accessibility level is explicitly TBD ("likely WCAG 2.1 AA but not yet ratified") which is a gap, not a source.

### Voice & brand

- **Tone**: friendly, calm, professional. Avoid jargon. Avoid corporate stiffness. *(Source: PRD §J.)*
- **Visual direction**: clean and minimal; default to system fonts; muted color palette with one accent color (TBD by Design Lead). *(Source: PRD §J.)*
- **User-facing locale**: not explicitly specified; English assumed for v1 (target market is English-speaking SMB SaaS). → OQ-CN-3.

---

## Sources

- PRD `PRD-Examples.pdf` v1.0 — §I (NFR), §J (UI/UX brand notes), §K (Out of Scope), §M (Dependencies), §O (Impact / Risk Checklist), §P (Sign-off)

## Out of Scope

- SOC 2 attestation (PRD §O — track for v2).
- HIPAA / industry-specific compliance (not mentioned in PRD).
- Internationalization / multi-language UI in v1 (not mentioned; English assumed).

## Open Questions

- [ ] **OQ-CN-1** [P1]: PRD §P shows 0 of 4 required sign-offs collected (Sarah Chen / Mike Patel / Lisa Wong / Tom Yamamoto) as of 2026-05-09. Sprint-0 blocker — vault should not be locked, and dev should not start, until at least PM + Eng Lead + HR Lead + CTO sign. Resolve: Sarah Chen + leadership (target per PRD §N: 2026-05-30).
- [ ] **OQ-CN-2** [P1]: Legal review of GDPR/CCPA compliance NOT STARTED per PRD §O (flagged for Q2). Required before any EU or California user onboarding. Sprint-0 blocker for those regions. Resolve: legal team.
- [ ] **OQ-CN-3** [P2]: User-facing UI locale — English-only for v1 assumed, but PRD doesn't state it. Tenant-level language preference? Per-user preference? Resolve: Sarah Chen.
- [ ] **OQ-CN-4** [P2]: Accessibility level — PRD §J says "likely WCAG 2.1 AA but not yet ratified". Lock the target before design phase finishes. Resolve: Maya Rodriguez + Mike Patel.
- [ ] **OQ-CN-5** [P2]: Accent color (visual identity) — TBD per PRD §J. Affects component library theming and marketing site. Resolve: Maya Rodriguez.
- [ ] **OQ-CN-6** [P2]: Pricing tier structure — flat $2/seat (current working number) vs feature-tier model per PRD §L Q5. Locks pricing UI + Stripe product config. Resolve: Sarah Chen + leadership (target 2026-05-30).
- [ ] **OQ-CN-7** [P3]: Disaster recovery RTO / RPO targets not stated explicitly. Backup/restore SLA mentioned (4 hours restore time) but RPO not specified. Tipikal SaaS: RPO ≤ 1h, RTO ≤ 4h. Resolve: Mike Patel + ops.
- [ ] **OQ-CN-8** [P3]: Pricing validation — PRD §O notes "3 prospects confirmed willingness at $2/seat; need 5 more". Track completion. Resolve: Sarah Chen.
- [ ] **OQ-CN-9** [P3]: Audit log retention — `balance_audit_log` and `export_log` follow general 7-year retention from PRD §I, or different policy? Resolve: legal review.
