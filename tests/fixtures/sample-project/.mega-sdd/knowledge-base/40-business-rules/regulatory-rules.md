---
generated_by: mega-sdd:extract-intelligence
generated_at: 2026-05-27
domain: regulatory-rules
classification: reference
criticality: high
rebuild_phase: 1
depends_on: []
verified_count: 3
inferred_count: 1
open_count: 0
source_files_cited: 2
---

# Regulatory Rules — Sample Project

## 1. Domain Summary

The sample project operates under employment law requirements for leave management.

## A. Employment Law Compliance

- FMLA (Family and Medical Leave Act) requires 12 weeks unpaid leave for qualifying events. [VERIFIED] (`src/config/leave-policies.ts:8`)
- ADA (Americans with Disabilities Act) accommodation requires flexible leave options. [VERIFIED] (`src/config/accessibility.ts:3`)
- State-specific paid sick leave minimums must be enforced per employee location. [INFERRED]

## B. Data Privacy

- GDPR Article 9 restricts processing of health data (sick leave reasons). [VERIFIED] (`src/middleware/gdpr.ts:15`)
