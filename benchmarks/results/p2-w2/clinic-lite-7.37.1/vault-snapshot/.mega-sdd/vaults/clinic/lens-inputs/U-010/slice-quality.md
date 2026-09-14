---
id: U-010
title: Open the patient pages and staff login in the route proxy
context_source: context.md#Constraints
prd_source: [PRD/prd-clinic.md:53, PRD/prd-clinic.md:190, PRD/prd-clinic.md:192, PRD/prd-clinic.md:195]
task_type: extend
grounding_confidence: LOW
risk: high
module: M-platform
depends_on: []
target_files:
  - path: src/proxy.ts
    operation: modify
  - path: src/proxy.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: independent-llm (+4 gaps merged)
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "lets an anonymous visitor open the booking page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "lets an anonymous visitor open a reschedule link"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "lets an anonymous visitor open the staff login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "still redirects an anonymous visitor on a staff page to the login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "bounces a signed-in user from the staff login page to home"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "redirects an anonymous visitor on reschedule without a token or a substring collision to the login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "redirects an anonymous visitor on a book prefixed but unrelated path to the login page"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "still bounces a signed-in user from the login page to home"
  - type: test
    command: "pnpm test:run src/proxy.test.ts --reporter=verbose"
    expects: "still clears cookies and redirects to login on a refresh error even for the booking page"
binding_refs: [OQ-CN-1]
---

# Unit U-010 — Open the patient pages and staff login in the route proxy

## Goal


Extend `src/proxy.ts` so anonymous visitors can reach `/book`, `/reschedule/<token>` and `/staff/login`, while every other page keeps redirecting anonymous users to `/login`.

## Anchors


- src/proxy.ts:7-37 — `proxy(request)` with `publicRoutes`, the RefreshTokenError branch, the auth-page bounce and the matcher config

## Claims


- C-U010-01 "the Next.js 16 proxy guards every page" — expect: src/proxy.ts — must-exist
- C-U010-02 "no proxy test exists yet" — expect: src/proxy.test.ts — must-not-exist

## Hard rules


- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/libs/auth.ts
  Source: unit target_files whitelist — shared file owned outside this unit (unit-schema.md §Atomicity rules)
- MUST keep the exported `proxy(request: Request)` function name and the exported `config.matcher` value unchanged (source: CLAUDE.md §Auth & routing)
  Source: CLAUDE.md §Auth & routing
- MUST keep the RefreshTokenError branch clearing both session cookies and redirecting to /login before any other rule
  Source: src/proxy.ts:14-22 — CLAUDE.md §Auth & routing
- MUST match the reschedule route only as the /reschedule/ prefix followed by a token segment, never by substring (constitution B-002)
  Source: constitution.md §B B-002
- MUST NOT make any /staff path other than /staff/login public (constitution B-005)
  Source: constitution.md §B B-005

## Migration notes


- **REMOVE**: the single `publicRoutes` list and its `includes(pathname)` check.
- **KEEP**: the RefreshTokenError cookie-clearing redirect, the `/home` bounce for signed-in users on auth pages, the anonymous → `/login` redirect, the `export const config` matcher.
- **ADD**: `/staff/login` as an auth page; `/book` and `/reschedule/<token>` as always-public patient pages; `src/proxy.test.ts`.

## Acceptance criteria


Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative); every Vitest test MUST be named exactly as its `expects` string.
- Adversarial addition — `redirects an anonymous visitor on reschedule without a token or a substring collision to the login page`: anonymous GET /reschedule and GET /rescheduled both redirect to /login.
- Adversarial addition — `redirects an anonymous visitor on a book prefixed but unrelated path to the login page`: anonymous GET /book/admin (a path sharing the /book prefix) still redirects to /login.
- Adversarial addition — `still bounces a signed-in user from the login page to home`: a signed-in user on /login is still redirected to /home after the refactor.
- Adversarial addition — `still clears cookies and redirects to login on a refresh error even for the booking page`: a RefreshTokenError session on /book is redirected to /login with both session cookies deleted.

## Out of scope


- Role checks for `/staff/schedule` and `/staff/reception` — page guards (U-016, U-019) and server scoping (U-007)
- The staff login page itself — U-015
