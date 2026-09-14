═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-001
═══════════════════════════════════════════
mega-sdd-trace:execute-bolts:U-001

UNIT: U-001 "Define appointment domain types and zod payload schemas"
FRAMEWORK: next.md

═══════════════════════════════════════════
TIER 1 — Always read (never truncated; cap_t1 is a reporting threshold, not a bound)
═══════════════════════════════════════════

## Unit body (verbatim)
---
id: U-001
title: Define appointment domain types and zod payload schemas
context_source: context.md#Data-model
prd_source: [PRD/prd-clinic.md:202, PRD/prd-clinic.md:149, PRD/prd-clinic.md:95]
task_type: create
grounding_confidence: LOW
risk: low
module: M-clinic-core
depends_on: []
target_files:
  - path: src/features/appointments/types/index.ts
    operation: create
  - path: src/features/appointments/schemas/booking/index.ts
    operation: create
  - path: src/features/appointments/schemas/booking/index.test.ts
    operation: create
existing_interfaces: []
allowed_new_deps: []
acceptance_test:  # _authored_by: adversarial-reviewed (+2 gaps merged)
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "accepts a complete booking"
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "rejects an invalid email with a readable message"
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "rejects whitespace-only name and reason"
  - type: test
    command: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"
    expects: "covers every booking field in exactly one wizard step"
binding_refs: [OQ-CN-1, OQ-AR-1, OQ-DM-1, OQ-CN-3]
---

# Unit U-001 — Define appointment domain types and zod payload schemas

## Goal

Create the clinic domain types (doctor/staff, patient, service, appointment, availability) and the zod schemas that validate the booking form, the walk-in form and the server-side request payloads, so every later unit shares one contract.

## Context (read first)

The entities come from `context.md#Data-model` (PRD §Clinic.4): staff with role `doctor | receptionist`, patient, service (price display-only, BR-005) and appointment with `status` (`booked | cancelled | completed`) and `booking_channel` (`online | staff`, BR-006). F-U-001 step 5 requires name, email, phone and reason for visit to be validated on the client and on the server, so the same schemas are reused by the booking wizard (U-013), the walk-in dialog (U-018), the reschedule form (U-014) and the BFF route handlers (U-005, U-006, U-007). Field names follow the house camelCase shape of the upstream API recommended in OQ-AR-1; no persistence happens in this repository (OQ-CN-1 recommendation).

## Anchors

- src/features/users/types/index.ts:1-29 — `I`-prefixed entity interfaces and `T`-prefixed payload types; follow this naming
- src/features/users/schemas/user.schema.ts:1-30 — a schema file exports schema + inferred type + defaults
- src/libs/api/query-params/index.ts — a module that owns a test lives in `<name>/index.ts` + `<name>/index.test.ts`

## Claims

- C-U001-01 "feature types follow the users feature shape" — expect: src/features/users/types/index.ts — must-exist
- C-U001-02 "schema files export schema, inferred type and defaults" — expect: src/features/users/schemas/user.schema.ts — must-exist
- C-U001-03 "the folder-with-test module pattern is established" — expect: src/libs/api/query-params/index.test.ts — must-exist

## Hard rules

- DO NOT add new package.json dependencies
  Source: context.md OQ-CN-1 recommendation (build on the existing starterkit, add no new dependencies)
- file src/features/appointments/types/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- file src/features/appointments/schemas/booking/index.ts MUST exist after bolt
  Source: unit target_files (create) — unit-schema.md §Hard rule grammar FILE_PRESENCE_RULE
- MUST export every schema together with its inferred type and its defaults (constitution A-004)
  Source: constitution.md §A A-004
- MUST keep the schema module and its test together in schemas/booking/ (constitution A-002)
  Source: constitution.md §A A-002
- MUST NOT add any payment or price-calculation field beyond the display-only service price (constitution C-005)
  Source: constitution.md §C C-005

## Anti-patterns

- Don't invent entity fields the PRD §Clinic.4 data model does not list; display-only embedded summaries (`patient`, `doctor`, `service`) on an appointment are allowed because staff views must show patient name and reason for visit (context.md#F-S-001).
- Don't encode timezone conversions — the timezone is still open (OQ-CN-3); keep `date` as `YYYY-MM-DD` and times as `HH:mm`.

## Implementation steps

1. Create `src/features/appointments/types/index.ts` with the literal unions `AppointmentStatus = 'booked' | 'cancelled' | 'completed'` and `BookingChannel = 'online' | 'staff'` (plus exported `APPOINTMENT_STATUSES` / `BOOKING_CHANNELS` arrays), and the interfaces `IDoctor` (`id`, `name`, `specialty?`, `workingHours?: { start: string; end: string } | null`), `IPatient` (`id`, `name`, `email`, `phone`), `IService` (`id`, `name`, `durationMinutes`, `price`), `IAppointment` (`id`, `patientId`, `doctorId`, `serviceId`, `startTime`, `endTime`, `status`, `reasonForVisit`, `bookingChannel`, `reminderAt?`, `reminderSent?`, plus optional display summaries `patient?`, `doctor?`, `service?`) and `IAvailability` (`doctorId`, `date`, `bookedStartTimes: string[]`, `workingHours?`), following the naming of the users feature anchor.
2. Add the payload types `TCreateAppointmentPayload` (`doctorId`, `serviceId`, `startTime`, `patient: { name, email, phone }`, `reasonForVisit`, `bookingChannel`, `override?: boolean`), `TReschedulePayload` (`startTime`), `TCancelPayload` (`token`) and `TReassignPayload` (`doctorId`) in the same file.
3. Create `src/features/appointments/schemas/booking/index.ts` exporting `bookingSchema` (form: `doctorId`, `serviceId`, `date` as `YYYY-MM-DD`, `startTime` as `HH:mm`, `name`, `email`, `phone`, `reasonForVisit` — every text field trimmed and non-empty, email via `z.email`), `BookingFormValues`, `bookingFormDefaults`, and `BOOKING_STEP_FIELDS` mapping the four wizard steps (`doctorService`, `dateTime`, `details`, `review`) to the field names each step validates with `trigger(fields)`, so every schema field belongs to exactly one step.
4. In the same module export `walkInSchema` (`bookingSchema` plus `override: z.boolean()`), `rescheduleSchema` (`date`, `startTime`) with its defaults, and the server-side payload schemas `createAppointmentPayloadSchema`, `reschedulePayloadSchema` (`startTime` as an ISO-like `YYYY-MM-DDTHH:mm` string), `cancelPayloadSchema` (non-empty `token`) and `reassignPayloadSchema` (non-empty `doctorId`), each with its inferred type.
5. Write `index.test.ts` with the four tests named exactly as the acceptance_test `expects` strings: a complete booking parses; an invalid email fails with a readable message; whitespace-only `name` and `reasonForVisit` fail; the union of `BOOKING_STEP_FIELDS` equals the `bookingSchema` keys with no duplicates.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- TBD: OQ-CN-3 — date/time strings stay timezone-free until the clinic timezone is decided.
- TBD: OQ-DM-1 — nothing here assumes how long services occupy slots.

## Out of scope

- Slot generation and availability rules — U-002
- Status labels and the status chip — U-003
- API calls — U-009

## Contracts (agent-carried)

Halt / self-report / rollback / provenance / atomic contracts: carried by your system prompt (agents/bolt-implementer.md, mega-sdd v7.37.1)

## Provenance values (per-dispatch)

The VALUES the agent fills into the agent-carried trailer shape (its system
prompt §Provenance trailer) in every modified file:

```
Provenance values:
  unit_id: U-001
  vault_sha256: e477c0d20993d2484f9f13bc2b8b5bbf12b468cf9f7994d89c6df588c812e8e8
  claims: (none cited)
  anchors_consulted:
    - src/features/users/types/index.ts:1
    - src/features/users/schemas/user.schema.ts:1
  anchors_verified: 2/2 (path + line-range only — content drift NOT checked)
  hard_rules_active:
    - DO NOT add new package.json dependencies
    - file src/features/appointments/types/index.ts MUST exist after bolt
    - file src/features/appointments/schemas/booking/index.ts MUST exist after bolt
    - MUST export every schema together with its inferred type and its defaults (constitution A-004)
    - MUST keep the schema module and its test together in schemas/booking/ (constitution A-002)
    - MUST NOT add any payment or price-calculation field beyond the display-only service price (constitution C-005)
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

## Constitution clauses (cited in this unit, resolved in the constitution §C)

- §A-002: A module with its own test lives in a folder — `foo/index.ts` + `foo/index.test.ts`; files with no test stay flat (source: CLAUDE.md:25)
- §A-004: Forms use react-hook-form + zod resolvers; each schema file exports the schema, its inferred type and its defaults (source: CLAUDE.md:105; PRD §8.1 Forms)
- §C-005: There are no payment code paths — service price is display-only (source: PRD §5 BR-005; PRD §7)

(selector: `\b[A-F]-\d{3}\b` cited in U-001.md OUTSIDE code fences/spans, AND resolving to a real clause block in constitution.md; binding claim ids and retired clauses excluded)

## Validation hints (specific, not vague)

After implementation, run:
```bash
pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose
```
Expected output pattern: accepts a complete booking
```bash
pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose
```
Expected output pattern: rejects an invalid email with a readable message
```bash
pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose
```
Expected output pattern: rejects whitespace-only name and reason
```bash
pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose
```
Expected output pattern: covers every booking field in exactly one wizard step

═══════════════════════════════════════════
T2 BUDGET TRACKER (informational)
═══════════════════════════════════════════

```
### T2 budget tracker
consumed_t1: 11142 bytes (cap 12288)
consumed_t2: 1432 bytes (cap 10240, hard 12288)
total: 12574 bytes  # T1 + T2 ONLY — the budgeted, truncatable content
file_total: 17304    bytes  # THIS WHOLE FILE; the gap from `total` is the four
                            # un-budgeted, never-truncated blocks (TIER 2 banner,
                            # this tracker, TIER 3 list, PROVENANCE appendix).
truncations_applied:
  - (none)
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
- t1.anti_context.do_not_modify: neither source produced an entry (data-mutation-policy.md [LOCKED] rows nor the unit's `## Hard rules` DO NOT/MUST NOT/NEVER modify lines) — line omitted
- depends_on_summaries: unit has no depends_on entries
- framework_pack_rules: no pack rule path_glob matched this unit's target_files (chain: next.md _universal.md) — the 'keep top 1' floor is vacuous on an empty set, no rule invented
- reuse_slice: reuse-index.yaml absent at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/reuse-index.yaml (the T1 pointer line is omitted too)
- symbol_slice: no indexed symbol in or beside target_files
- starterkit_slice: no starterkit-context.yaml at /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/codebase/starterkit-context.yaml — the Map §6 fallback applies instead
- map_patterns: no codebase-map.md §6 Pattern signatures
- design_slice: unit is not ui_bearing (no target_files path matched the pack view_glob or any universal frontend shape)
- confidence_labels: no binding.md in /Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3/.mega-sdd/vaults/clinic
- t3.kb_pointer: no knowledge-base root under .mega-sdd/, docs/ or old-reference/ — the TIER 3 KB pointer is omitted rather than naming a dead path
- design_slice_path: unit is not ui_bearing, so no design lens is dispatched for it — no lens-input file is written and the `design_slice_path` key is ABSENT (a rubric with no reader is a cost, not a contribution)
- (structural, every project — historical_memory, kb_anti_patterns; reasons on stdout sections_omitted)
