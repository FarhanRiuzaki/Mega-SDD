# PRD: Platform API
## Overview
Intro.
## FR12 Version History
Every config change MUST be versioned and restorable.
## US3 Goals
As a saver I MUST be able to create a goal.
## OAuth2 Scope
Tokens MUST carry the minimal scope; `payments:write` MUST require step-up auth.
## §API.3 Sources (Funding Sources: card, VA, QRIS)
Checkout MUST offer card, virtual account and QRIS as funding sources.
## Context (Request Context Propagation)
Every service MUST propagate trace-id and tenant-id.
## Version (Force Update):
Clients below min version MUST be blocked.
## 4) Scope (per-tenant data isolation)
Queries MUST be scoped by tenant_id.
## Sources / References
Every transfer MUST store the upstream source reference number.
## B2B Scope
Corporate users MUST approve transfers with 2-of-3 maker-checker.
