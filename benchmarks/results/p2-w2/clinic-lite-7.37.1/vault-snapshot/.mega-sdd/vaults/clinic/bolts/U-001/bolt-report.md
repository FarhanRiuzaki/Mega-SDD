---
unit: U-001
status: success
attempted_at: 2026-09-14T11:41:05+00:00
duration_seconds: 613947
commits: [5fd9c1b7d23ac6208a4f6580ae33ce83da590eed]
files_touched: [src/features/appointments/schemas/booking/index.test.ts, src/features/appointments/schemas/booking/index.ts, src/features/appointments/types/index.ts]
tests_run: ["pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose"]
test_results: "0 acceptance entries passed / 4 not passing (see acceptance.json)"
retries: 0
target_hashes:
  src/features/appointments/types/index.ts: f236c524978bca627dc59d85d2f558569a2e5d652345158014448069b803301f
  src/features/appointments/schemas/booking/index.ts: 4a7554281bd5fe8de39ece3c9ed1fa7992034a484a51738c91986ba9bfae07a7
  src/features/appointments/schemas/booking/index.test.ts: 6a770cf2938c0b8b61aeea6bacfc3657d985e78140f4cf57866ad27bde9f669e
---

# Bolt Report — U-001

## Summary
(see implementer report)
# Bolt report — U-001 "Define appointment domain types and zod payload schemas"

- **Status:** DONE
- **Commit:** 5f1ceced64c7603f0727a4650171a73cc99d8e05 (`feat(U-001): Define appointment domain types and zod payload schemas`, trailers `Unit: U-001`, `SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-001`, `SDD-Acceptance: v5`)

## What was implemented

- `src/features/appointments/types/index.ts` — `APPOINTMENT_STATUSES` / `BOOKING_CHANNELS` (`as const`) with the derived unions `AppointmentStatus` / `BookingChannel`; `TWorkingHours`; interfaces `IDoctor`, `IPatient`, `IService` (display-only `price: number`, no other money fields), `IAppointment` (with optional `patient` / `doctor` / `service` display summaries), `IAvailability`; `TAppointmentList`; payload types `TCreateAppointmentPayload`, `TReschedulePayload`, `TCancelPayload`, `TReassignPayload`.
- `src/features/appointments/schemas/booking/index.ts` — `bookingSchema` + `BookingFormValues` + `bookingFormDefaults`; `BOOKING_STEPS` / `BookingStep` / `BOOKING_STEP_FIELDS` (doctorService, dateTime, details, review=[]); `walkInSchema` + `WalkInFormValues` + `walkInFormDefaults` (override=false); `rescheduleSchema` + `RescheduleFormValues` + `rescheduleFormDefaults`; `createAppointmentPayloadSchema`, `reschedulePayloadSchema`, `cancelPayloadSchema`, `reassignPayloadSchema`, each with an inferred `*PayloadValues` type and a compile-time `satisfies z.ZodType<T*Payload>` check against the types file.
- `src/features/appointments/schemas/booking/index.test.ts` — the 4 acceptance tests (titles verbatim) + 4 strengthening tests.

Field rules: every text field is `z.string().trim().min(1, msg)` (trim before min, the permissions-schema pattern); email = trimmed then piped into `z.email('Enter a valid email address')`; `date` = `z.iso.date()` (`YYYY-MM-DD`, calendar-valid); `startTime` = `z.iso.time({ precision: -1 })` (`HH:mm` only); payload `startTime` = `z.iso.datetime({ local: true, precision: -1 })` plus an explicit refine rejecting a trailing `Z` (zod's `local: true` still accepts `Z` — verified empirically), so the value stays timezone-free.

## Tests

TDD followed: the test file was written first and run → failed with `Failed to resolve import "."` (module absent — right reason). After implementation:

```
pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose
 ✓ bookingSchema > accepts a complete booking
 ✓ bookingSchema > rejects an invalid email with a readable message
 ✓ bookingSchema > rejects whitespace-only name and reason
 ✓ bookingSchema > covers every booking field in exactly one wizard step
 ✓ walk-in and payload schemas > requires the walk-in override flag and defaults it to false
 ✓ walk-in and payload schemas > keeps payload start times timezone-free
 ✓ walk-in and payload schemas > validates the create payload patient and channel
 ✓ walk-in and payload schemas > rejects blank cancel tokens and reassign doctors
 Tests  8 passed (8)
```

Also: `npx tsc --noEmit -p tsconfig.json` → exit 0, 0 errors (this is what exercises `types/index.ts`, which the scoped vitest run only reaches through the schema module's import); `rtk proxy npx eslint <3 files>` (unfiltered) → exit 0, no findings (incl. no `import/no-duplicates` on the split value/type imports); `rtk proxy npx prettier --check <3 files>` → "All matched files use Prettier code style!" (one cosmetic reflow applied by `prettier --write` before commit).

## Hard rules honored

- DO NOT add new package.json dependencies — honored (package.json / pnpm-lock.yaml untouched; zod 4.3.6 already installed).
- file src/features/appointments/types/index.ts MUST exist after bolt — honored.
- file src/features/appointments/schemas/booking/index.ts MUST exist after bolt — honored.
- MUST export every schema together with its inferred type and its defaults (constitution A-004) — honored for the three form schemas (booking, walk-in, reschedule: schema + `*FormValues` + `*FormDefaults`). The four server-side payload schemas export schema + inferred type but no defaults: they validate inbound request bodies and have no form to seed. A-004 as resolved in T2 is file-level ("each schema file exports the schema, its inferred type and its defaults") and scoped to forms (react-hook-form + zod resolvers), which this file satisfies. Recorded here so the omission is a decision, not a silent gap.
- MUST keep the schema module and its test together in schemas/booking/ (constitution A-002) — honored (`schemas/booking/index.ts` + `schemas/booking/index.test.ts`).
- MUST NOT add any payment or price-calculation field beyond the display-only service price (constitution C-005) — honored (`IService.price` only; no currency/total/discount/payment fields anywhere).

Anti-context `DO NOT WRITE` block (tables / columns / FK constraints) — vacuous for this unit: no persistence, no DB schema is written here.

## Provenance

The trailer is present at the top of all 3 files: `Generated by mega-sdd execute-bolts v7.37.1` (version from the dispatch Contracts line), `Unit: U-001 (vault sha256: e477c0d2…e8e8)`, `Anchors consulted`, `Hard Rules active` (rule text verbatim, 6 entries). **The `Implements claim:` line is omitted** because the Provenance values block says `claims: (none cited)`.

No `C-*` / `F-*` / `OQ-*` ids appear in any code comment. The timezone and display-only-price intents are written in words.

## reuse_decisions

```yaml
reuse_decisions:
  - candidate: ".mega-sdd/codebase/reuse-index.yaml"
    decision: not_applicable
    reason: "Index absent (recorded in the dispatch PROVENANCE omissions); scanned src/ with Grep for existing date/time/trim/email helpers instead — none exist beyond per-schema inline zod."
  - candidate: "src/features/users/types/index.ts (I-prefixed interfaces, T-prefixed payload types)"
    decision: reused
    reason: "Naming convention followed."
  - candidate: "src/features/users/types/index.ts:17 (TUserList list alias)"
    decision: reused
    reason: "Added TAppointmentList by the same anchor pattern; not in the unit's step enumeration, a one-line alias for list consumers (U-009 hooks). Removable with no other change if judged out of scope."
  - candidate: "src/features/users/schemas/user.schema.ts (schema + inferred type + defaults; z.email)"
    decision: reused
    reason: "Export shape and z.email usage followed."
  - candidate: "src/features/permissions/schemas/permission.schema.ts (z.string().trim().min(1, msg))"
    decision: reused
    reason: "Trim-before-min required-text pattern followed."
  - candidate: "zod 4 z.iso.date / z.iso.time / z.iso.datetime"
    decision: reused
    reason: "Native library validators over hand-written regex (calendar-valid dates, HH:mm-only times)."
  - candidate: "src/libs/constants.ts (centralized SelectOption lists)"
    decision: not_applicable
    reason: "Outside target_files; the unit places APPOINTMENT_STATUSES / BOOKING_CHANNELS in types/index.ts. Status labels are U-003's scope."
```

## Self-assessment

- `acceptance_test_concern`: the four acceptance tests only exercise `bookingSchema` and `BOOKING_STEP_FIELDS`. They do not pin the walk-in `override` requirement, the timezone-free payload `startTime`, the create-payload enum/nested patient, or the cancel/reassign non-empty rules, and they never load `types/index.ts` except transitively. Mitigated by 4 extra tests in the same file (walk-in override required, `...Z` / `+07:00` / seconds / date-only rejected, invalid channel and nested email rejected, blank token/doctorId rejected) plus a clean `tsc --noEmit`.
- Further assertions I would add: (1) `bookingSchema` rejects `startTime: '09:15:00'` and `date: '2026-02-30'`; (2) `createAppointmentPayloadSchema` output trims `patient.name`.

```yaml
bolt_self_report:
  model_used: "Opus 5"
  confidence: 0.8
  certain_decisions:
    - "Field names, unions and interfaces follow the unit's implementation-step enumeration literally (no createdAt/updatedAt added, no price siblings)."
    - "Every text field trims before the non-empty check, so whitespace-only name/reason fail with readable messages."
    - "BOOKING_STEP_FIELDS covers every bookingSchema key exactly once; review step is an explicit empty list."
    - "Payload schemas are type-checked against the T*Payload types via `satisfies` — a payload schema that drops or mistypes a required field fails to compile (one-directional: an extra schema field is not caught)."
    - "Enum arrays are declared once in types/index.ts and reused by z.enum in the schema module."
  uncertain_decisions:
    - decision: "createAppointmentPayloadSchema.startTime uses the same local `YYYY-MM-DDTHH:mm` format as reschedulePayloadSchema."
      rationale: "The unit specifies the ISO-like format only for the reschedule payload; the create payload carries the same combined start instant (form date + time), so one format keeps the BFF contract consistent."
      fallback_if_wrong: "Swap the create payload's startTime to a plain non-empty string or split it into date + time fields."
    - decision: "phone is validated as trimmed non-empty only (no format regex)."
      rationale: "The unit says 'every text field trimmed and non-empty'; the PRD gives no phone format, and a region-specific regex would be invented behavior."
      fallback_if_wrong: "Add a pattern check in the shared phone field once a format is specified."
    - decision: "Payload schemas export schema + inferred type but no defaults."
      rationale: "Defaults only make sense for forms; A-004 is file-level and form-scoped (see Hard rules section)."
      fallback_if_wrong: "Export empty-string defaults objects for each payload schema."
    - decision: "IAppointment embedded summaries typed as the full IPatient / IDoctor / IService (all optional)."
      rationale: "Least-invention option; the unit names the summaries but not a subset shape."
      fallback_if_wrong: "Narrow to Pick<> subsets once the upstream response shape is known."
  retry_history:
    - attempt: 1
      failure: "npx prettier --check (raw): [warn] src/features/appointments/schemas/booking/index.ts — Code style issues found (the rtk wrapper had printed 'All files formatted correctly' over it)"
      fix: "Ran prettier --write on the 3 files (only reflowed the z.iso.datetime chain), re-ran tests/tsc/eslint/prettier — all clean — before committing."
```

## Rollback hints

```yaml
- step_id: step-1-create-test
  step_type: file_created
  evidence: "created src/features/appointments/schemas/booking/index.test.ts (115 lines)"
  compensating_action: "git rm -f src/features/appointments/schemas/booking/index.test.ts"
  idempotent: true
- step_id: step-2-create-types
  step_type: file_created
  evidence: "created src/features/appointments/types/index.ts (106 lines)"
  compensating_action: "git rm -f src/features/appointments/types/index.ts"
  idempotent: true
- step_id: step-3-create-schema
  step_type: file_created
  evidence: "created src/features/appointments/schemas/booking/index.ts (152 lines)"
  compensating_action: "git rm -f src/features/appointments/schemas/booking/index.ts"
  idempotent: true
- step_id: step-4-run-tests
  step_type: test_command_run
  evidence: "pnpm test:run src/features/appointments/schemas/booking/index.test.ts --reporter=verbose → 8 passed; tsc --noEmit → 0 errors"
  compensating_action: "(none — manual review required)"
  idempotent: true
- step_id: step-5-commit
  step_type: git_commit
  evidence: "commit 5f1ceced64c7603f0727a4650171a73cc99d8e05 on bench/p0-clinic-arm (3 files, +373)"
  compensating_action: "git revert --no-edit 5f1ceced64c7603f0727a4650171a73cc99d8e05"
  idempotent: false
```

## Review panel
- Tier: **full** · signals_fired: ['vocabulary'] · lenses: spec, quality, security, standards · implementer model routing: inherit (session model)
- L0: run-code-gates.sh --write per unit commit (5fd9c1b) — no blocking finding
- Ledger `findings.json` (merge-panel-findings.sh): attempt 1 · gate clear · open 0 · advisory 7 · resolved 0

| id | severity | file:line | lens | status | title |
|---|---|---|---|---|---|
| F-1 | Important | src/features/appointments/types/index.ts:26 | quality | advisory | duplicate: `TWorkingHours` has the same shape as U-002's `TimeWindow` |
| F-2 | Important | src/features/appointments/schemas/booking/index.test.ts:44 | quality | advisory | Date/time format checks on the form schemas have no tests |
| F-3 | Minor | src/features/appointments/schemas/booking/index.ts:134 | quality | advisory | duplicate: each payload type is declared twice (hand-written `T*` and inferred `*Values`) |
| F-4 | Minor | src/features/appointments/schemas/booking/index.test.ts:110 | quality | advisory | Test title doesn't match what it asserts |
| F-5 | Minor | src/features/appointments/schemas/booking/index.test.ts:93 | quality | advisory | No whitespace-only test for the payload schema's patient fields |
| F-6 | Important | src/features/appointments/schemas/booking/index.ts:130 | security | advisory | Mass assignment: shared create schema lets callers set staff-only fields |
| F-7 | Minor | src/features/appointments/schemas/booking/index.ts:26 | security | advisory | Input validation: no length limit on unauthenticated free-text fields |

## Post-flight
- Hard rules: postflight.json status **pass** (DO_NOT_ADD_DEPS=pass, FILE_PRESENCE_RULE=pass, FILE_PRESENCE_RULE=pass)
- Acceptance: acceptance.json status **pass** (0/4 executed entries pass)
- ✓ Drift check: clean (lite lane — no binding.md anchors; no LOCKED entities in the vault)

