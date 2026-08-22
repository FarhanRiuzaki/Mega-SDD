# Constraints & Open Questions

NFR: median response < 300ms per PRD SLA.

## Open Questions

- [ ] **OQ-AR-1** [P1] [tech / scan] [conf: high] [origin: vault.md#Architecture]: which test framework? — resolve: scan codebase-map §test_frameworks
- [ ] **OQ-AR-7** [P2] [tech / recommend] [conf: medium] [origin: vault.md#Architecture]: what HTTP error envelope shape? **Deferred (v1.1)**: waiting on platform team ruling
- [~] **OQ-AR-9** [P3] [business] [origin: vault.md#Architecture]: support SOAP fallback? → Out of Scope v1.1: REST only per PRD.
- [x] **OQ-DM-1** [P1] [origin: model.md#Entities]: which ID type? → **Resolved v1.1** (2026-07-19): UUID.
- [ ] **OQ-FL-2** [P2] [origin: flows.md#F-U-001]: notification channel unclear — resolve: PM
- [ ] **OQ-CN-3** [P2]: how should **Deferred** settlement deep-links batch?
- [ ] **OQ-CN-4** [P3]: data retention period? **Deferred (v1.2)**: waiting on legal review
  (follow-up booked with the platform team)

## Notes

Constraint review cadence is quarterly.
