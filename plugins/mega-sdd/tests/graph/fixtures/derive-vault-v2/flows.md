# Flows

## User flows

### F-U-001: Submit leave request

**Flow**:
```mermaid
flowchart TD
    A["Fill form"] --> B["Validate dates"]
    B --> C["Create leave_request"]
```

**Definition of Done**:
- [ ] request row created
- [ ] manager notified
- [x] audit written

**Source**: PRD §3.1 (AC1-1, AC1-2, AC1-2)

## System flows

### F-S-002: Nightly accrual

**Flow**:
```mermaid
flowchart TD
    T(["cron 02:00"]) --> R["Read balances"]
    R --> W[("Write accruals")]
```

**Definition of Done**:
- [ ] balances updated

**_kb_source**: [20-workflows/accrual.md]
**Source**: PRD §4
