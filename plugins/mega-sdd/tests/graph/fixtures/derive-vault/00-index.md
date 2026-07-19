# Vault: Demo Leave System

## Vault Lock Status

- **Vault version**: v1.1
- **History**: full version log in "## Changelog" at the end of this doc (newest entry first).
- **Project shape**: `web-app`
- **Implementation mode**: `new`
- **Mode migration trigger**: null
- **PRD status**: `draft`
- **Output mode**: `compact`

## Open Questions roll-up

> Total: **5 Open Questions**.

### Tech stack & architecture (PRIORITY-1)
- [ ] **OQ-AR-1** [P1] [tech / scan] [conf: high]: which test framework? — resolve: scan codebase-map §test_frameworks `[02-architecture.md]`
- [ ] **OQ-AR-7** [P2] [tech / recommend] [conf: medium]: what HTTP error envelope shape? `[02-architecture.md]`
- [~] **OQ-AR-9** [P3] [business]: support SOAP fallback? → Out of Scope v1.1: REST only per PRD. `[02-architecture.md]`

### PRD inconsistencies (PRIORITY-1)
- [x] **OQ-DM-1** [P1]: which ID type? → Resolved v1.1: UUID. `[03-data-model.md]`
- [ ] **OQ-FL-2** [P2]: notification channel unclear `[04-flows.md]`

## Changelog
