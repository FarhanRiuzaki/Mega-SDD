---
title: "Internal Reporting Service (Single-scope test fixture)"
type: PRD
version: "1.0"
status: draft
date: 2026-05-23
authors: ["Test Suite"]
industry: general
stakeholders:
  - { role: "BE Architect", name: "Test BE", email: "be@test.local" }

# Single-scope: only BE declared. No multi-scope semantics expected.
scopes:
  BE:
    name: "Backend Service"
    pics: ["Test BE"]
    priority: 1
    sections: ["§Backend"]

universal_sections: ["§1", "§2", "§3"]
---

# §1. Executive Summary

Internal reporting service that aggregates data from operational DBs and emits daily reports to ops team.

# §2. Goals

- Daily PDF report generation by 6am
- Manual on-demand report trigger
- Email delivery to ops mailing list

# §3. Stakeholders

- Ops team (consumers)
- BE Architect (owner)

---

# §Backend

## §Backend.1 Functional
- FR-001: Cron job runs daily at 5am
- FR-002: Aggregates data from 3 operational DBs
- FR-003: Generates PDF report
- FR-004: Sends email via SendGrid

## §Backend.4 Data Model
- report_run: id, run_at, status, report_path

## §Backend.5 Acceptance
- Daily report delivered by 6am
- Manual trigger via POST /api/reports/generate
