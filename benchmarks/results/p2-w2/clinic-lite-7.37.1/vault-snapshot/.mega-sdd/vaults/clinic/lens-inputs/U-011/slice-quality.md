---
id: U-011
title: Add the branded patient shell layout
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:124, PRD/prd-clinic.md:128, PRD/prd-clinic.md:182]
task_type: create
grounding_confidence: LOW
risk: low
module: M-patient-booking
depends_on: []
target_files:
  - path: src/app/(patient)/layout.tsx
    operation: create
  - path: src/features/appointments/components/PatientShell/index.tsx
    operation: create
  - path: src/features/appointments/components/PatientShell/index.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+1 gap merged)
  - type: test
    command: "pnpm test:run src/features/appointments/components/PatientShell/index.test.tsx --reporter=verbose"
    expects: "renders header main and footer landmarks"
  - type: test
    command: "pnpm test:run src/features/appointments/components/PatientShell/index.test.tsx --reporter=verbose"
    expects: "links the header navigation to the booking page"
  - type: test
    command: "pnpm test:run src/features/appointments/components/PatientShell/index.test.tsx --reporter=verbose"
    expects: "shows the product name as the brand text"
  - type: manual
    desc: "Open /book at a 375px-wide viewport: header, content and footer fit without horizontal scrolling and every link is reachable by keyboard with a visible focus ring."
binding_refs: [OQ-CN-1, OQ-CN-5]
---

# Unit U-011 — Add the branded patient shell layout

## Goal


Create the `(patient)` route-group layout and a `PatientShell` with a branded header (brand text + navigation), a main landmark and a footer, used by `/book` and `/reschedule/[token]`.

## Anchors


- src/app/(blank-layout-pages)/layout.tsx:1-29 — async layout wrapping children in `Providers direction='ltr'`; mirror it
- src/components/Providers.tsx:18-40 — provider stack (NextAuth → TanStack Query → VerticalNav → Settings → Theme)

## Claims


- C-U011-01 "Providers wraps the MUI theme and query client" — expect: src/components/Providers.tsx — must-exist
- C-U011-02 "no patient route group exists yet" — expect: src/app/(patient) — must-not-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/components/Providers.tsx
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file src/app/(patient)/layout.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST render semantic header, main and footer landmarks with a keyboard-reachable navigation and visible focus (constitution F-001)
  Source: constitution.md §F F-001
- MUST NOT show a logo image or clinic name that the PRD does not provide (context.md OQ-CN-5)
  Source: context.md OQ-CN-5
- MUST stay usable at a 375px viewport without horizontal scrolling (source: PRD §Clinic.2 NFR-001)
  Source: PRD §Clinic.2 NFR-001

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-5 — replace the text brand with the clinic's name and logo once provided.

## Out of scope


- The booking wizard — U-013
- The reschedule page — U-014
