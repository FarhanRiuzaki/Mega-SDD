---
id: U-015
title: Add the /staff/login page on the existing credentials login
context_source: context.md#F-S-001
prd_source: [PRD/prd-clinic.md:195, PRD/prd-clinic.md:170]
task_type: create
grounding_confidence: LOW
risk: medium
module: M-staff
depends_on: []
target_files:
  - path: src/app/(blank-layout-pages)/staff/login/page.tsx
    operation: create
  - path: src/app/(blank-layout-pages)/staff/login/page.test.tsx
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (no gaps)
  - type: test
    command: "pnpm test:run staff/login/page --reporter=verbose"
    expects: "renders the existing credentials login view for staff"
  - type: test
    command: "pnpm test:run staff/login/page --reporter=verbose"
    expects: "sets the staff login page title"
binding_refs: [OQ-CN-1]
---## Goal


Expose PRD §Clinic.3's `/staff/login` by rendering the existing next-auth credentials `Login` view.

## Context (read first)


F-S-001/F-S-002 start with a staff login and PRD §Clinic.3 names `/staff/login`; per the OQ-CN-1 recommendation staff keep the existing next-auth credentials flow, so this page reuses `@views/Login` exactly like `/login`.

## Anchors


- src/app/(blank-layout-pages)/login/page.tsx:1-22 — the page to mirror (metadata + `getServerMode` + `<Login mode={mode} />`)

## Claims


- C-U015-01 "the credentials login page exists" — expect: src/app/(blank-layout-pages)/login/page.tsx — must-exist
- C-U015-02 "the Login view exists" — expect: src/views/Login.tsx — must-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/views/Login.tsx
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- DO NOT modify src/libs/auth.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- file src/app/(blank-layout-pages)/staff/login/page.tsx MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
