---
type: vault
doc_id: vault
vault_layout: 2
vault_version: "1.1"
project_shape: web-app
implementation_mode: new
mode_migration_trigger: null
prd_status: draft
output_mode: compact
sources:
  prd: "demo-leave-prd.md / v1 / 2026-07"
changelog:
  - version: "1.1"
    date: 2026-07-19
    notes: "OQ-DM-1 resolved (UUID); OQ-AR-9 out of scope."
---

# Vault: Demo Leave System

## Overview

Demo leave system overview.

## Architecture

REST API over a managed relational store; notification fan-out via the
platform bus (envelope shape pending OQ-AR-7).

## Decisions

### D-001: Use PostgreSQL
Managed relational store. **Decision**: Postgres 16. **Consequences**: SQL skills reusable, vendor lock modest. **Source**: PRD §2.

### D-002: Legacy session auth
**Status**: Superseded by D-003
**Source**: PRD §5.
