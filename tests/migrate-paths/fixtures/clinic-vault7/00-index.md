# Clinic Appointment System — Grand Design

> Booking appointment klinik: pasien self-book/reschedule/cancel via email token.

## Vault Lock Status

- **Vault version**: v1.0
- **History**: full version log in "## Changelog" at the end of this doc (newest entry first).
- **Project shape**: `web-app`
- **Implementation mode**: `new`
- **Mode migration trigger**: first prod deploy
- **PRD status**: `final`
- **Output mode**: `compact`
- **PRD source**: sample-prd-clinic.md, v2.0, 2026-06-12 — FINAL

## Executive Summary

A simple appointment-booking system for a small medical clinic (mirrors 01-overview).

## Reading order (full)

1. [[01-overview]] — what, who, why
2. [[02-architecture]] — surfaces
3. [[03-data-model]] — entities

## Glossary

| Term | Definition |
|------|----------|
| Appointment | A scheduled patient visit with a doctor (booked / cancelled / completed). |
| Slot | A 15-minute bookable time block on a doctor's schedule. |
| Booking channel | Whether an appointment was created `online` or by `staff`. |

## Auto-Classification Review

- OQ-CLINIC-005 → tech / high (deployment target — auto-resolve eligible)
- OQ-CLINIC-006 → tech / medium (user reviews before binding)

## Open Questions (roll-up)

> Total: **6 Open Questions**.

### Compliance & privacy (PRIORITY-1)

- [ ] **OQ-CLINIC-001** [P1]: privacy regulation? `[06-constraints.md]`
- [ ] **OQ-CLINIC-002** [P1]: patient names visible? `[02-architecture.md]`

## Source documents

- **PRD**: sample-prd-clinic.md / v2.0 / 2026-06

## Changelog

### v1.0 (2026-06-12)
- Initial vault generated from PRD v2.0.
- Mode: new.

## Last updated

2026-06-12
