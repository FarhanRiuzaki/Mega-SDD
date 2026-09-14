═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-009
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-009

UNIT: U-009 "Add the appointments repository and TanStack Query hooks"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-009
title: Add the appointments repository and TanStack Query hooks
context_source: context.md#F-U-001
prd_source: [PRD/prd-clinic.md:145, PRD/prd-clinic.md:165, PRD/prd-clinic.md:175]
task_type: create
grounding_confidence: LOW
risk: medium
module: M-clinic-core
depends_on: [U-001]
target_files:
  - path: src/features/appointments/repositories/appointment.repository.ts
    operation: create
  - path: src/features/appointments/hooks/useAppointments/index.ts
    operation: create
  - path: src/features/appointments/hooks/useAppointments/index.test.tsx
    operation: create
existing_interfaces:
  - file: src/libs/query-keys/index.ts
    symbol: createQueryKeys
    note: "reuse unchanged"
  - file: src/libs/api/crud-hooks.ts
    symbol: makeCreateMutation
    note: "reuse unchanged"
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "loads doctors and services from the clinic proxy routes"
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "requests availability only when doctor and date are chosen"
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "posts a booking to the appointments proxy route"
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "cancels through the token cancel route outside the v1 prefix"
  - type: test
    command: "pnpm test:run src/features/appointments/hooks/useAppointments/index.test.tsx --reporter=verbose"
    expects: "reassigns an appointment and refreshes the schedule"
binding_refs: [OQ-CN-1, OQ-AR-1]
---

# Unit U-009 — Add the appointments repository and TanStack Query hooks

## Goal

Create the browser data-access layer for every clinic call — one repository of `apiClient` functions and the TanStack Query hooks that wrap them with query keys, snackbars and invalidation.

## Context (read first)

The house data flow is page → hook → repository → `apiClient` → `/api/v1` proxy (CLAUDE.md §Data flow, constitution C-001 / C-003): repositories return the raw envelope and hooks own snackbars and invalidation through `createQueryKeys` and `make{Create,Update,Delete}Mutation`. The paths match the BFF routes of U-005, U-006 and U-007 (the cancel route lives outside `/v1` because PRD §Clinic.3 names `/api/appointments/[id]/cancel`). The booking wizard (U-013), reschedule form (U-014), schedule views (U-016, U-019) and dialogs (U-017, U-018) consume these hooks.

## Anchors

- src/features/users/repositories/user.repository.ts:1-19 — repository functions over `apiClient` with `/v1/...` paths
- src/features/users/hooks/useUsers.ts:1-51 — query keys + `useQuery` + mutation factories
- src/libs/api/crud-hooks.ts:21-61 — `makeCreateMutation` / `makeUpdateMutation` contracts (snackbar + invalidate)
- src/libs/api/client.ts:10-18 — `apiClient` base `/api`, throws on non-OK
- src/test/utils.tsx:36 — `renderWithProviders`; tests override MSW handlers per case with `server.use`

## Claims

- C-U009-01 "createQueryKeys is the query-key factory" — expect: src/libs/query-keys/index.ts:createQueryKeys
- C-U009-02 "makeCreateMutation wires snackbar and invalidation" — expect: src/libs/api/crud-hooks.ts:makeCreateMutation
- C-U009-03 "renderWithProviders is the component test helper" — expect: src/test/utils.tsx:renderWithProviders
- C-U009-04 "apiClient is the browser fetcher" — expect: src/libs/api/client.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- DO NOT modify src/test/handlers.ts
  Source: src/test/handlers.ts:14-21 (tests override default handlers per case with server.use)
- file src/features/appointments/repositories/appointment.repository.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST keep repositories free of enqueueSnackbar and return the raw envelope (constitution C-003)
  Source: constitution.md §C C-003
- MUST build query keys with createQueryKeys and CRUD mutations with the crud-hooks factories where they fit (constitution C-003)
  Source: constitution.md §C C-003
- MUST call only apiClient from this client-side layer (constitution C-001)
  Source: constitution.md §C C-001

## Implementation steps

1. Create `appointment.repository.ts` with `fetchDoctors`, `fetchServices`, `fetchAvailability({ doctorId, date })` (GET `/v1/appointments/availability` with params), `createAppointment(payload)` (POST `/v1/appointments`), `fetchAppointmentByToken({ token })` (GET `/v1/appointments/token/${encodeURIComponent(token)}`), `rescheduleAppointment({ token, startTime })` (PUT same path), `cancelAppointment({ id, token })` (POST `/appointments/${id}/cancel` — outside `/v1`, resolving to `/api/appointments/...`), `fetchSchedule({ from, to, doctorId? })` (GET `/v1/appointments/schedule`) and `reassignAppointment({ id, doctorId })` (POST `/v1/appointments/${id}/reassign`), typed with the U-001 types and following the users repository anchor.
2. Create `hooks/useAppointments/index.ts` (`'use client'`) exporting `appointmentKeys`, `doctorKeys`, `serviceKeys` (from `createQueryKeys`), `useDoctors`, `useServices`, `useAvailability(doctorId, date)` (`enabled` only when both are set; key `[...appointmentKeys.all(), 'availability', doctorId, date]`), `useCreateAppointment` (`makeCreateMutation`, success message `Appointment booked`, invalidating `appointmentKeys.all()` so availability refetches), `useAppointmentByToken(token)`, `useRescheduleAppointment`, `useCancelAppointment`, `useSchedule(params)` and `useReassignAppointment` (invalidating the schedule queries); mutations not covered by the factories use `useMutation` with the same snackbar/invalidate pattern as `crud-hooks.ts`.
3. Write `index.test.tsx` rendering small probe components through `renderWithProviders`, overriding MSW handlers with `server.use` for `/api/v1/doctors`, `/api/v1/services`, `/api/v1/appointments/availability`, `/api/v1/appointments`, `/api/appointments/:id/cancel`, `/api/v1/appointments/:id/reassign` and `/api/v1/appointments/schedule`, with the five tests named exactly as the acceptance_test `expects` strings; the adversarial cases must assert no availability request is sent while `doctorId` or `date` is empty and that the schedule is refetched after a successful reassign.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-AR-1 — upstream response shapes follow the recommended contract; the envelope `data` is typed with the U-001 types.

## Out of scope

- The BFF routes themselves — U-005, U-006, U-007
- Any UI — U-012 onwards

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-009
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted:
    - src/features/users/repositories/user.repository.ts:1
    - src/features/users/hooks/useUsers.ts:1
    - src/libs/api/crud-hooks.ts:21
    - src/libs/api/client.ts:10
    - src/test/utils.tsx:36
  anchors_verified: 5/5 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - DO NOT modify src/test/handlers.ts
    - file src/features/appointments/repositories/appointment.repository.ts MUST exist after bolt
    - MUST keep repositories free of enqueueSnackbar and return the raw envelope (constitution C-003)
    - MUST build query keys with createQueryKeys and CRUD mutations with the crud-hooks factories where they fit (constitution C-003)
    - MUST call only apiClient from this client-side layer (constitution C-001)
```

## Acceptance-test provenance NOTE

> NOTE: This unit's `acceptance_test` has weak blind-spot coverage
> (_authored_by: absent — legacy unit, treated as same-pass). The test was authored by the same LLM pass that
> wrote the unit body — the test may inherit the same blind spots as the spec
> and fail to catch behavioral bugs your implementation introduces.
>
> If your implementation passes this test but feels under-validated:
>   - In bolt-report.md self-assessment, set `acceptance_test_concern: <details>`
>     explaining what you suspect the test might miss
>   - Propose 1-2 additional assertions you'd add to strengthen coverage
>   - Mark `confidence` no higher than MEDIUM for behaviors not directly tested

## Anti-context (negative space = freedom + protection)

DO NOT MODIFY:
  - src/test/handlers.ts  (source: U-009.md `## Hard rules`)
DO NOT WRITE:
  - Tables without `id` primary key (denormalized intermediate tables OK as composite PK)  (from _universal.md §Forbidden patterns)
  - Tables without `created_at` + `updated_at` timestamps (unless explicitly immutable like audit logs)  (from _universal.md §Forbidden patterns)
  - VARCHAR(255) used as default type for everything (use proper sized/typed columns)  (from _universal.md §Forbidden patterns)
  - Comma-delimited values in single columns (use junction tables)  (from _universal.md §Forbidden patterns)
  - Date/time stored as VARCHAR/INT (use proper TIMESTAMP/DATETIME types)  (from _universal.md §Forbidden patterns)
  - Foreign keys without explicit constraint (`ON DELETE`/`ON UPDATE` defined)  (from _universal.md §Forbidden patterns)
DO NOT COMMIT IF: any `acceptance_test` command in this unit fails; any `## Hard rules` line above is violated; a modified file is missing its provenance trailer

═══════════════════════════════════════════
TIER 2 — Conditional context (target ≤10KB total)
═══════════════════════════════════════════

## Upstream bolts (depends_on chain — 1-line summary each)

- U-001 "Define appointment domain types and zod payload schemas" → committed at (no commit recorded)
  └─ [unknown] Field names, unions and interfaces follow the unit's implementation-step enumeration literally (no createdAt/updatedAt added, no price siblings). — src: /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic/bolts/U-001/bolt-report.md

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §C-001: Browser code calls `apiClient` (same-origin `/api` proxy, no Authorization header); Route Handlers and Server Components call `apiServer`; the two are never mixed (source: CLAUDE.md:65; CLAUDE.md:134)
- §C-003: Repositories return the raw response; hooks own `enqueueSnackbar` feedback and query invalidation, built from `createQueryKeys` and `make{Create,Update,Delete}Mutation` (source: CLAUDE.md:132; CLAUDE.md:68)

(selector: `\b[A-F]-\d{3}\b` cited in U-009.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

## Design system (UI-bearing unit — per context-enrichment.md §Design slice)


Design system: style=clinical, trustworthy, anti-generic — brand color on high-signal elements only · palette=primary teal-700 #0E7490 (white foreground, 5.36:1); accent/success green-700 #15803D (5.02:1); raw #0891B2 / #16A34A only for fills, charts and icon accents · typography=humanist sans body with a real type scale; optional serif display headers · a11y=WCAG 2.2 AA — source: vault.json design_system (provenance excluded, audit-only)
UX floor: (ux-rules.md — Accessibility/Forms/Feedback rows, Severity: High)
  - Accessibility/Color Contrast: DO Minimum 4.5:1 ratio for normal text; DON'T Low contrast text [High]
  - Accessibility/Color Only: DO Use icons/text in addition to color; DON'T Red/green only for error/success [High]
  - Accessibility/Alt Text: DO Descriptive alt text for meaningful images; DON'T Empty or missing alt attributes [High]
  - Accessibility/ARIA Labels: DO Add aria-label for icon-only buttons; DON'T Icon buttons without labels [High]
  - Accessibility/Keyboard Navigation: DO Tab order matches visual order; DON'T Keyboard traps or illogical tab order [High]
  - Accessibility/Form Labels: DO Use label with for attribute or wrap input; DON'T Placeholder-only inputs [High]
  - Accessibility/Error Messages: DO Use aria-live or role=alert for errors; DON'T Visual-only error indication [High]
  - Forms/Input Labels: DO Always show label above or beside input; DON'T Placeholder as only label [High]
  - Forms/Submit Feedback: DO Show loading then success/error state; DON'T No feedback after submit [High]
  - Feedback/Loading Indicators: DO Show spinner/skeleton for operations > 300ms; DON'T No feedback during loading [High]
  - Accessibility/Motion Sensitivity: DO Respect prefers-reduced-motion; DON'T Force scroll effects [High]
Modern baseline (non-negotiables — the FLOOR):
  - Design tokens first.
  - Spacing system, not ad-hoc gaps.
  - Typographic scale.
  - Layout is composed, not stacked.
  - Interactive states exist.
  - Feedback states exist.
  - Forms are designed.
  - Accessibility floor = WCAG AA
  - Tables are for data — styled.
  - Distinctive, not generic.
Ceiling moves (clear the floor, then DO these — a floor-only view is "basic/generic"):
  - Page furniture.
  - Composition, not a lone card.
  - Iconography.
  - Visual hierarchy with depth.
  - A signature.
  - Motion with purpose.
  - Density that fits the product.
Anti-kuno tells (a match in your output = defect):
- Unstyled default browser controls / default link blue / default focus-less buttons.
- Layout via nested `<table>` or `<br>` stacks; no page shell (content hugging the left edge full-width).
- No spacing system: arbitrary `margin: 3px 7px 11px`, cramped forms.
- System-default typography wall (no scale, no pairing, line-height 1).
- Raw `<input>` rows with placeholder-as-label, no validation states.
- Native `alert()`/`confirm()`; raw URL text as actions ("click here").
- Unformatted data: ISO timestamps shown raw, unformatted money, raw FK ids.
- Zero hover/focus/disabled treatment; zero loading/empty/error states.
- Inline `style=` attributes everywhere instead of the token layer.

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 11000 bytes (cap 12288)
consumed_t2: 4390 bytes (cap 10240, hard 12288)
total: 15390 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 20282    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - validation_hints: drop expected-output patterns; keep test commands only (saved 401 bytes)
  - validation_hints: drop section entirely (drop floor) (saved 609 bytes)
  - design_slice: modern-baseline -> bolded lead clauses verbatim; ux-rules -> Severity: High rows (saved 6215 bytes)
instruction_to_subagent:
  If your self-assessment relies on a truncated section listed above, mark its
  confidence MEDIUM (not HIGH) and note the truncation in bolt-report.md.
  Truncation is transparency, not failure.
```

═══════════════════════════════════════════
TIER 3 — Reference-on-demand (NOT embedded; use Read tool)
═══════════════════════════════════════════

- Full upstream bolt-reports: `/Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic/bolts/U-XXX/bolt-report.md`
- Full constitution: `/Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic/constitution.md`
- Full framework pack: `/Users/<user>/.claude/plugins/cache/mega-sdd/mega-sdd/7.37.1/references/framework-conventions/<pack>.md`

═══════════════════════════════════════════
PROVENANCE — omissions (audit trail; NOT part of the T1/T2 byte accounting)
═══════════════════════════════════════════

Every absent or unresolvable input is recorded here rather than invented (invariant #5).

- t1.reuse_index_line: reuse-index.yaml absent at ./.mega-sdd/codebase/reuse-index.yaml — the Iron Rule 4 pointer line is NOT emitted for a file that does not exist (run scan-codebase to produce the index)
- t1.anti_context.do_not_modify.data_mutation_policy: no <kb>/99-rebuild-architecture/data-mutation-policy.md under /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3 (searched .mega-sdd/, docs/, old-reference/ knowledge-base roots) — this source contributes nothing; the unit `## Hard rules` half is NOT relabelled to stand in for it
- framework_pack_rules: no pack rule path_glob matched this unit's target_files (chain: next.md _universal.md) — the 'keep top 1' floor is vacuous on an empty set, no rule invented
- reuse_slice: reuse-index.yaml absent at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/reuse-index.yaml (the T1 pointer line is omitted too)
- symbol_slice: no indexed symbol in or beside target_files
- starterkit_slice: no starterkit-context.yaml at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice.style[clinical]: style token matches no style-principles.md row — omitted, never substituted
- design_slice.style[trustworthy]: style token matches no style-principles.md row — omitted, never substituted
- design_slice.style[anti-generic — brand color on high-signal elements only]: style token matches no style-principles.md row — omitted, never substituted
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic
- validation_hints: truncated to its drop floor (section dropped) by the T2 cascade
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
