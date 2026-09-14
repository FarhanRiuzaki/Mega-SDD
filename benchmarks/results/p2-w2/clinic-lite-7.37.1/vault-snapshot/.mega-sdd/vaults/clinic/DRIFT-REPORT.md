# Drift Report

**Vault**: v1.1 (layout 3 — `context.md` + `constitution.md` + `vault.json`; last updated 2026-09-14; mode `existing`)
**Codebase**: `/Users/<user>/SunnyGo/2026/AIRND2026/Project/TRAINING/p0-clinic-arm3` (commit `048b3c6`; code tree clean — only untracked `.mega-sdd/` bookkeeping files)
**Framework detected**: Next.js 16.2 App Router + React 19 + MUI 7 + next-auth v4 + TanStack Query/Table + zod 4 (from `package.json`; no `codebase-map.md` §7 present)
**Drift scope**: full
**Scope hint**: none — full scan (post-bolt auto-gate after `execute-bolts --all --lite`, 19/19 units done, B2 full-suite green)
**Generated**: 2026-09-14 (against HEAD `048b3c6`)

**Inputs**: `VAULT_DIR=.mega-sdd/vaults/clinic` · `CODE_DIR=<repo root>` (`.git` + `package.json`) · `SCOPE_DIRS=` full scan
**Integrity checks**: `sha256(PRD/prd-clinic.md)` = `34b026c2…5d0a` = `vault.json.prd_sha256` ✓ · `sha256(constitution.md)` = `52a8fd5c…c1` = `vault.json.constitution_hash` ✓ · `binding.md` absent (lite lane), so the `constitution_drift_detected` binding-hash comparison can't be run and does not fire.
**Framework vs vault**: the vault records PRD §6.3's stack (Bun, Drizzle, Better Auth, shadcn/ui) as different from this codebase, but OQ-CN-1 already covers that. Its recommendation (keep the existing starterkit) is the working assumption all 19 units were built on. Because the gap is already recorded, `drift_framework_mismatch` does not fire.

## Summary

| Category | High | Medium | Low | Total |
|----------|-----:|-------:|----:|------:|
| Missing in code | 2 | 1 | 0 | 3 |
| Missing in vault | 1 | 0 | 0 | 1 |
| Name drift | 0 | 0 | 0 | 0 |
| Type drift | 0 | 1 | 0 | 1 |
| Behavior drift | 0 | 1 | 1 | 2 |
| Decision violation | 2 | 2 | 0 | 4 |
| Decision unwritten | 2 | 1 | 0 | 3 |
| **Confirmed match** | — | — | — | **35** |

> **Confidence legend**: columns show **confidence**, not severity. High means an exact match or an unambiguous absence (action recommended). Medium means similar names, differing signatures, or a partial pattern match (verify before acting). Low means a heuristic keyword guess (always verify manually).

**Severity rule applied** (this vault has no `mutability_source` / LOCKED-INTENT-ARTIFACT tiers):
- **HIGH** is the safe default. It applies when the code contradicts, under-delivers, or leaves undocumented a vault claim that no vault OQ covers.
- **LOW** means the vault already acknowledges the item. The vault records it as a deferred OQ or a pending DoD item, and the code follows that OQ's interim or picks one of its answers. On these, vault and code agree the item is still open.
- **Constitution findings** follow `constitution-drift.md`. Critical (§B/§F) counts as HIGH, standard (§A/§C/§E) as MEDIUM, and advisory (§D) as LOW.
- **No CRITICAL**: there are no LOCKED claims.

**Severity totals**: HIGH 6 · MEDIUM 3 · LOW 5 · CRITICAL 0. **Auto-gate chain action: PAUSE** (HIGH present, no CRITICAL).

---

## Decision violations & decision unwritten (PRIORITY-1)

> `vault.json.adrs` is empty. For this vault, the binding decisions are the `constitution.md` clauses plus the recorded OQ working assumptions. Review these first.

### DRIFT-C1 — §B-005 role gate can be forged through session update (constitution_violation_critical · confidence: medium · severity HIGH)

**Vault constraint** (`constitution.md` §B-005): "Staff surfaces require the matching role … and a doctor's schedule data is limited to that doctor's own appointments."

**Code reference**: `src/libs/auth.ts` lines 120-122 (pre-existing starterkit code, not introduced by any bolt):
```ts
// Handle manual session update
if (trigger === 'update' && session) {
  return { ...token, ...session }
}
```
The token's `roles` and `id` then flow into `session.user` (`src/libs/auth.ts:141,145`). Every clinic gate reads those fields:
- `src/app/api/v1/appointments/schedule/route.ts:45-54`: role check, then `params.doctorId = session.user.id`
- `src/app/api/v1/appointments/[id]/reassign/route.ts:46-50`
- `src/app/api/v1/appointments/route.ts:38-44,64`
- `ProtectedRoute` on `src/app/(dashboard)/staff/schedule/page.tsx:30` and `src/app/(dashboard)/staff/reception/page.tsx:29`

**Drift**:
- **Vault**: the role gate and the doctor-only scoping are enforced.
- **Code**: the gate trusts JWT claims that a signed-in client can overwrite by calling `useSession().update({...})`. A doctor could set `roles` to include `receptionist`, or change `id`, and so widen the BFF scope.
- **Unknown**: whether the upstream API also scopes by the bearer token. That depends on the upstream contract, which is still open (OQ-AR-1). Confidence is medium for that reason.
- Units U-005/U-007/U-010/U-015 all ran under the hard rule "DO NOT modify src/libs/auth.ts". `bolts/_summary.md` §Advisory already records the issue as out of scope for this batch.

**Suggested action** (informational):
- (A) Fix code: a dedicated hardening unit that owns `src/libs/auth.ts` and whitelists the fields an update may change.
- (B) Update vault: add to §B-005 an explicit dependency on the upstream enforcing role/scope by bearer, and document it as an ADR.
- (C) Defer: capture as an OQ.

### DRIFT-C2 — §A-003 test bypasses `renderWithProviders` (constitution_violation_standard · confidence: high · severity MEDIUM)

**Vault constraint** (`constitution.md` §A-003): "components render through `renderWithProviders`".

**Code reference**: `src/app/(blank-layout-pages)/staff/login/page.test.tsx:13`: `import { render, screen } from '@testing-library/react'`. All 11 other clinic test files import from `@/test/utils`, for example `components/BookingWizard/index.test.tsx:17` and `components/DoctorSchedule/index.test.tsx:22`.

**Drift**: this one test file renders without the shared providers harness.

**Suggested action**: (A) fix code, switching to `renderWithProviders` from `@/test/utils`; (B) update vault, if page-level smoke tests are meant to be exempt from A-003.

### DRIFT-C3 — §A-004 server payload schemas export no defaults (constitution_violation_standard · confidence: medium · severity MEDIUM)

**Vault constraint** (`constitution.md` §A-004): "each schema file exports the schema, its inferred type and its defaults". The U-001 hard rule applied it per schema: "MUST export every schema together with its inferred type and its defaults."

**Code reference**: `src/features/appointments/schemas/booking/index.ts:120-152`. These four schemas export a schema and an inferred type but no defaults object:
- `createAppointmentPayloadSchema`
- `reschedulePayloadSchema`
- `cancelPayloadSchema`
- `reassignPayloadSchema`

The three form schemas (booking, walk-in, reschedule) do export defaults (`:61`, `:95`, `:111`).

**Drift**: whether this counts as drift depends on reading the clause per file (satisfied) or per schema (4 schemas lack defaults). The U-001 implementer flagged it as uncertain. Verify manually.

**Suggested action**: (A) fix code, exporting defaults for the payload schemas; (B) update vault, amending A-004 so defaults are required only for schemas that back a form.

### DRIFT-C4 — §A-002 test-less module placed in a folder (constitution_violation_standard · confidence: high · severity MEDIUM)

**Vault constraint** (`constitution.md` §A-002): "files with no test stay flat".

**Code reference**: `src/features/appointments/components/AppointmentDetailDialog/index.tsx`. It is the only clinic component folder with no `index.test.tsx`.

**Drift**: the module is foldered but has no test pair. It is only exercised indirectly, through the DoctorSchedule and ReceptionBoard tests.

**Suggested action**: (A) fix code, either adding `index.test.tsx` or flattening to `components/AppointmentDetailDialog.tsx`; (B) update vault, if shared sub-components may be foldered for symmetry.

### DRIFT-D1 — Decision unwritten: OQ-DM-1 answered in code, only the start slot is blocked (confidence: high · severity LOW, vault-acknowledged)

**Vault**: `context.md ## Open Questions` OQ-DM-1 [P2, deferred]: "Does a longer visit … also block the following slot(s), or does only its start slot count as taken?"

**Code reference**: `src/features/appointments/utils/slots/index.ts:125-129` doc comment: "Only the booked start time itself is hidden — the slots that follow it stay available." The implementation is at `:134,140-144`, a `Set` of booked start times.

**Drift**: the code settles the deferred OQ as "start slot only" and does not cite OQ-DM-1. (The upstream uniqueness key `(doctor_id, start_time)` is consistent with this.)

**Suggested action**: (A) record the chosen answer as OQ-DM-1's working assumption, or resolve it via `resolve-oq`; (B) if the Product Owner answers "block the following slots", fix code in `availableSlots`, which needs the service duration.

### DRIFT-D2 — Decision unwritten: OQ-CN-3 answered in code, the patient's browser clock decides (confidence: high · severity LOW, vault-acknowledged)

**Vault**: OQ-CN-3 [P2, deferred]: "Which timezone do the 09:00–17:00 bookable hours and the 24-hour reminder use — the clinic's local time or the patient's own device time?"

**Code reference**:
- `src/features/appointments/components/BookingWizard/index.tsx:116-125`: `readBrowserClock()`, with the comment "the patient's own browser clock decides"
- `src/features/appointments/components/RescheduleForm/index.tsx:357-358`: `dayjs()` defaults
- `src/features/appointments/components/WalkInDialog/index.tsx:120-121`
- `src/features/appointments/types/index.ts:14-16`: values are timezone-free strings

**Drift**: this tier uses the device clock to decide which dates and slots are past, which is one of OQ-CN-3's two answers. The code does not cite OQ-CN-3.

**Suggested action**: (A) record this as OQ-CN-3's interim, or resolve it; (B) if the answer is clinic-local time, fix code with a clinic-timezone helper feeding `today`/`now`.

### DRIFT-D3 — Decision unwritten: only `booked` appointments can be reassigned (confidence: medium · severity HIGH, default)

**Vault**: F-S-002 DoD: "An appointment can be reassigned to a different doctor, with a patient notification email". There is no status qualifier.

**Code reference**: `src/features/appointments/components/ReceptionBoard/columns.tsx:96-102`: `disabled={item.status !== 'booked'}`, with the comment "a cancelled or completed one stays put". The server route `src/app/api/v1/appointments/[id]/reassign/route.ts` does not check status and leaves that to the upstream.

**Drift**: the UI narrows reassignment to booked appointments. That choice is recorded only as a U-019 self-assessment, not in the vault.

**Suggested action**: (A) update vault, qualifying the F-S-002 DoD with "booked appointments only"; (B) fix code, enabling reassignment for all statuses and letting the upstream reject.

---

## Constitution Findings

> Detection uses text-grep (no `codebase-map.md` means no `precision_tier: ast`), so precision is lower. Prose-only clauses are flagged for manual review, never fabricated.

### Critical violations (§B Security, §F Compliance)
- `src/libs/auth.ts:120-122` puts §B-005 at risk: roles and id are forgeable through session update, pre-existing code (DRIFT-C1).

### Standard violations (§A Coding, §C Architecture, §E Performance)
- `src/app/(blank-layout-pages)/staff/login/page.test.tsx:13` violates §A-003 (DRIFT-C2).
- `src/features/appointments/schemas/booking/index.ts:120-152` may violate §A-004 (DRIFT-C3).
- `src/features/appointments/components/AppointmentDetailDialog/` violates §A-002 (DRIFT-C4).
- §E-001 (lookup under 200ms median) and §E-002 (reminder within 5 min) are prose-only and upstream-owned. This repo has no instrumentation for either. **Manual review needed** (see OQ-CN-2).

### Advisory (§D Anti-patterns)
- None. §D-001 has no timers in the app; the cron route only triggers the upstream sweep. §D-002 has no SMS, i18n, patient accounts, recurring appointments or medical records. Both are confirmed.

### Framework-forced exceptions (not counted)
- §A-002: `src/proxy.test.ts`, `src/app/**/route.test.ts`, `…/staff/login/page.test.tsx` and `src/configs/primaryColorConfig/index.test.ts` sit beside their sources. Next.js needs the fixed filenames `proxy.ts`, `route.ts` and `page.tsx`, so those files can't be moved into folders. `primaryColorConfig` was correctly promoted to a folder.

---

## Schema drift

> The vault's `## Data model` DBML describes the **upstream** system of record. Per OQ-AR-1 this tier has no database and no mail transport. The code types in `src/features/appointments/types/index.ts` are the client/transport view model. The snake_case to camelCase mapping (`booking_channel` to `bookingChannel`, `start_time` to `startTime`, `duration_minutes` to `durationMinutes`, `price decimal` to `price: number`, …) is a transport convention. It is treated as a **confirmed match** below, not as name or type drift.

### DRIFT-S1 — Type drift: `staff.working_hours` (confidence: medium · severity HIGH, default)

**Vault** (`context.md` DBML `staff`): `working_hours json [null, note: 'doctors only; narrows availability within BR-001 bounds']`.
**Code** (`src/features/appointments/types/index.ts:26-29,35,77`): `TWorkingHours = { start: string; end: string }`, a single daily window, on both `IDoctor.workingHours` and `IAvailability.workingHours`. It is applied by `generateDaySlots` (`utils/slots/index.ts:74-97`).
**Drift**: the free-form `json` is narrowed to one start/end window. A per-weekday schedule, or a split shift, can't be represented. The window only narrows within BR-001 bounds, which does match the vault note.
**Suggested action**: (A) update vault, typing `working_hours` as `{start, end}` per date, if that is the upstream shape (settled with OQ-AR-1); (B) fix code, if the upstream sends richer structures.

### DRIFT-S2 — Missing in code: client projection omits upstream-owned columns (confidence: medium · severity LOW, vault-acknowledged via OQ-AR-1)

**Vault**: DBML `appointment.created_at`, `appointment.updated_at`, `patient.created_at`, and `staff.email` / `password_hash` / `role` / `created_at`. `appointment.reminder_at timestamp` and `reminder_sent boolean` are non-nullable.
**Code**:
- `IAppointment` (`types/index.ts:54-71`) has no `createdAt`/`updatedAt`, and has `reminderAt?`/`reminderSent?` as optional.
- `IPatient` (`:38-43`) has no `createdAt`.
- `IDoctor` (`:31-36`) projects `staff` without `email`, `role`, `password_hash` or `created_at`.

**Drift**: under the OQ-AR-1 recommendation these fields are upstream-owned (auth schema, reminder sweep). This tier reads none of them, and a public doctor listing should not expose staff credentials.
**Suggested action**: (A) update vault, marking these columns as upstream-only or not exposed to the BFF; (B) no code change unless a view needs them.

---

## Flow drift

### DRIFT-F1 — Behavior drift: taken-slot hiding (BR-002 / F-U-001 step 4) inconsistent across pickers (confidence: medium · severity HIGH, default)

**Vault**:
- F-U-001 step 4: "taken slots hidden"
- F-U-004 DoD: "The new slot is chosen from available slots only (BR-001 / BR-002)"
- constitution §B-006: taken slots are hidden, not labelled

**Code**: `availableSlots` matches booked start times as exact `HH:mm` strings (`src/features/appointments/utils/slots/index.ts:134,141`).
- `BookingWizard` normalises the upstream values first: `toSlotTime` at `components/BookingWizard/index.tsx:127-133`, applied at `:198`.
- `RescheduleForm` passes the raw values: `components/RescheduleForm/index.tsx:304`.
- `WalkInDialog` passes them raw as well: `components/WalkInDialog/index.tsx:94,122,369`.

**Drift**: suppose the upstream `bookedStartTimes` contains full date-times (`2026-09-15T09:15…`). The code itself treats that format as possible, which is why the wizard normalises. In that case, the reschedule page and the walk-in slot grid show taken slots as free. The upstream uniqueness constraint would still reject the insert, so this is a UX and BR-002-hiding gap, not a double-book. Confidence is medium because the upstream format is part of the open OQ-AR-1.
**Suggested action**: (A) fix code, normalising once (in the `useAvailability` hook or in `availableSlots`) so every picker shares it; (B) update vault, pinning the availability contract to `HH:mm`, and drop the wizard's conversion.

### DRIFT-F2 — Missing in code: F-U-002 has no patient-facing path (confidence: high · severity LOW, vault-acknowledged via OQ-FL-1)

**Vault**: F-U-002 has four steps: link with the one-time token, a confirmation prompt, `cancelled` with the slot freed, and a confirmation page. The DoD already notes that steps 2 and 4 are "pending the same open question … no unit delivers it yet" (OQ-FL-1).

**Code**:
- `POST /api/appointments/[id]/cancel` exists: `src/app/api/appointments/[id]/cancel/route.ts:33-58`, POST-only and zod-validated.
- The `useCancelAppointment` hook also exists (`src/features/appointments/hooks/useAppointments/index.ts:105-110`).
- No component or page calls the hook; the only matches under `src` are the hook and repository definitions. `RescheduleForm` has no cancel action.
- The route needs the appointment `id` in the path plus the token in the body. The email link carries only the token, so a landing page would first need `GET /api/v1/appointments/token/[token]`.

**Drift**: F-U-002 cannot be reached end-to-end by a patient: step 1 has no landing, and steps 2 and 4 have no screen.
**Suggested action**: resolve OQ-FL-1 (Design Lead), then add a unit that builds the cancel landing and confirmation page on the existing hook and route.

### DRIFT-F3 — Behavior drift: emergency override also bypasses date bounds (confidence: low · severity HIGH, default · verify manually)

**Vault**: F-S-002 step 4: "Override booking restrictions for an emergency walk-in **outside slot times**".
**Code**: `src/features/appointments/components/WalkInDialog/index.tsx:114-131` checks slots only when `!values.override`. With the override on, no past-date or weekend restriction applies to the date (U-018 self-assessment: "Override-mode date field has no weekend or past-date restriction").
**Drift**: the override reaches beyond "outside slot times" to past and weekend dates. Whether that is intended is a product call.
**Suggested action**: (A) fix code, adding `min={today}` or a weekend guard to the override date field; (B) update vault, stating that the override lifts all date and time restrictions.

---

## Endpoint drift

### DRIFT-E1 — Missing in vault: the BFF / upstream API contract (confidence: high · severity HIGH, default)

**Vault**: `context.md ## Constraints` §Surfaces lists only the 7 PRD §Clinic.3 surfaces. The `/v1/*` upstream paths appear only inside OQ-AR-1's deferred recommendation text, and no request or response shape is documented anywhere.

**Code**: the BFF routes in this repo, with what each accepts and forwards:

| Route | Methods | Shape |
|---|---|---|
| `/api/v1/doctors` | GET | — |
| `/api/v1/services` | GET | — |
| `/api/v1/appointments` | POST | `TCreateAppointmentPayload`: a nested `patient{name,email,phone}` (not a `patient_id`), plus `bookingChannel` and an `override?` flag; `types/index.ts:82-94`, `schemas/booking/index.ts:120-132` |
| `/api/v1/appointments/availability` | GET | `IAvailability{doctorId,date,bookedStartTimes,workingHours}`; `types/index.ts:73-78` |
| `/api/v1/appointments/schedule` | GET | `from`, `to`, `doctorId?` |
| `/api/v1/appointments/token/[token]` | GET, PUT | PUT body `{startTime}`, local `YYYY-MM-DDTHH:mm` |
| `/api/v1/appointments/[id]/reassign` | POST | body `{doctorId}` |

Upstream calls:
- `POST /v1/appointments/{id}/cancel` with `{token}`
- `POST /v1/reminders/sweep`

**Drift**: the paths match OQ-AR-1's recommendation 9/9, so they are a working assumption the vault acknowledges. The payload and response shapes, and the rule that only receptionists may send `bookingChannel: staff` or `override: true` (`src/app/api/v1/appointments/route.ts:62-66`), are not captured in the vault.
**Suggested action**: (A) update vault by adding an API-contract subsection (source: code as built), to be reconciled when OQ-AR-1's upstream contract is published; (B) defer, and fold it into OQ-AR-1's resolution.

### DRIFT-E2 — Missing in code: rate limiting on `/book` (confidence: high · severity LOW, vault-acknowledged via OQ-CN-4)

**Vault**: §Surfaces: "`/book` (public, rate-limited)". OQ-CN-4 [P2, deferred] leaves the limit, and whether this app or the upstream/gateway enforces it, open.
**Code search**: no match for `rate.?limit` or `throttle` anywhere under `src/`. `POST /api/v1/appointments` (`src/app/api/v1/appointments/route.ts`) has no limiter.
**Suggested action**: resolve OQ-CN-4. If the limit is enforced in this app, add a unit; if at the gateway, update the vault's surface note.

---

## Confirmed matches

> Listed for completeness, no action needed. 35 claims evaluated.

**Flows (5)**
- ✓ **F-U-001**:
  - Public route: `/book` via `src/proxy.ts:19-26,40-42`.
  - Wizard steps: `schemas/booking/index.ts:72-83`, one `useForm` instance (`BookingWizard/index.tsx:169-180`).
  - Slot rules: past and weekend dates are disabled (`utils/slots/index.ts:104-123`); 15-min slots run 09:00–17:00 with 12–13 excluded (`:20-26,74-97`) and are narrowed by `workingHours` (`BookingWizard/index.tsx:424`); taken slots are hidden (`SlotPicker/index.tsx:93-95`).
  - Validation: zod on the client and again on the server (`src/app/api/v1/appointments/route.ts:55-59`).
  - Booking: `bookingChannel: 'online'` (`BookingWizard/index.tsx:251`); a rejected insert sends the patient back to the date/time step (`:266-272`).
  - Confirmation: `role="status"` / `aria-live` (`:553`).
- ✓ **F-U-003**: the cron route rejects any caller without `Authorization: Bearer <CRON_SECRET>`, using a constant-time comparison (`src/app/api/cron/reminders/route.ts:32-50`). It forwards one sweep to `/v1/reminders/sweep` (`:52`). The selection, the `reminder_sent` flag and the email are upstream-owned per OQ-AR-1.
- ✓ **F-U-004**:
  - Public route: `/reschedule/[token]` as a single-segment match (`src/proxy.ts:19-26`).
  - Current appointment loaded by token (`RescheduleForm/index.tsx:362`); same-doctor availability (`:262`).
  - Server: zod-validated atomic PUT forwarded upstream (`api/v1/appointments/token/[token]/route.ts:38-58`).
  - Confirmation: `role="status"` live region (`RescheduleForm/index.tsx:422`).
- ✓ **F-S-001**:
  - Access: `ProtectedRoute` with roles `['doctor']` (`staff/schedule/page.tsx:30`); the server overwrites `doctorId` with the session doctor (`api/v1/appointments/schedule/route.ts:49-55`).
  - Views: Today and Week toggle (`DoctorSchedule/index.tsx:114,347-357`).
  - Details: patient name and reason for visit (`AppointmentDetailDialog/index.tsx:64-65`); status is shown with the chip.
- ✓ **F-S-002**:
  - Access: `ProtectedRoute` with roles `['receptionist']` (`staff/reception/page.tsx:29`).
  - Views: an all-doctors grid plus `BaseTable` (`ReceptionBoard/index.tsx:460`).
  - Reassign: `ReassignDialog`, which excludes the current doctor, backed by the receptionist-only route (`reassign/route.ts:46-50`).
  - Walk-in: `bookingChannel: 'staff'` (`WalkInDialog/index.tsx:140`); the override flag is server-gated to receptionists (`api/v1/appointments/route.ts:62-66`).

**Data model (2)**
- ✓ `staff`, `patient`, `service` and `appointment` map to `IDoctor`, `IPatient`, `IService` and `IAppointment` through the camelCase transport mapping. There is no DB in this tier (OQ-AR-1). The differences are recorded separately as DRIFT-S1 and DRIFT-S2.
- ✓ Enumerations: `status` ∈ {booked, cancelled, completed} and `booking_channel` ∈ {online, staff} (`types/index.ts:18-24`). `staff.role` ∈ {doctor, receptionist} appears as the role literals in `schedule/route.ts:29-30`, `appointments/route.ts:30` and `reassign/route.ts:29`.

**Surfaces (1)**
- ✓ All 7 PRD §Clinic.3 surfaces exist: `src/app/(patient)/book/page.tsx`, `src/app/api/appointments/[id]/cancel/route.ts` (POST-only, with token), `src/app/(patient)/reschedule/[token]/page.tsx`, `src/app/(dashboard)/staff/schedule/page.tsx`, `src/app/(dashboard)/staff/reception/page.tsx`, `src/app/(blank-layout-pages)/staff/login/page.tsx` and `src/app/api/cron/reminders/route.ts`.

**OQ working assumptions honoured (6)**
- ✓ OQ-CN-1: no new dependencies. `package.json` has none of Drizzle, Better Auth, shadcn, Resend, Schedule-X or croner.
- ✓ OQ-AR-1: all 9 recommended upstream `/v1/*` paths are the ones used. The missing contract shapes are DRIFT-E1.
- ✓ OQ-AR-2: the staff pages have no menu entry. `src/data/navigation/*` has no `staff`/`schedule`/`reception` match, and `reception/page.tsx:26` notes it.
- ✓ OQ-CN-5: the header shows the product name as text (`PatientShell/index.tsx:29-30`), with no logo or clinic name.
- ✓ OQ-CLINIC-005: the external-scheduler trigger accepts GET and POST (`cron/reminders/route.ts:58-59`), and `.env.example` defines `CRON_SECRET=` empty.
- ✓ OQ-CLINIC-006: the grid is built from MUI and `BaseTable`, with no Schedule-X or FullCalendar.

**Design tokens (1)**
- ✓ The primary is teal-700 `#0E7490`. `src/configs/primaryColorConfig/index.ts:41-44` defines it as the `primary-3` entry, and `src/@core/contexts/settingsContext.tsx:63` seeds the theme from it. The raw `#0891B2` appears only as the `light` fill hue, which PRD §8.2 permits.

**Constitution clauses (20)**, with B-005 excluded because of DRIFT-C1:
- ✓ A-001: the domain lives under `src/features/appointments/{components,hooks,repositories,schemas,types,utils}`.
- ✓ A-005: `APPOINTMENT_STATUS_LABELS` and `BOOKING_CHANNEL_LABELS` extend `src/libs/label-maps.ts:75-84`.
- ✓ A-006: no `@mui/icons-material` in the clinic code; `tabler-*` classes are used.
- ✓ B-001: zod runs at every mutating boundary (appointments, cancel, token PUT and reassign routes).
- ✓ B-002: patients have no login, and the token is encoded into the upstream path and never echoed.
- ✓ B-003: `CRON_SECRET` is server-only, has no `NEXT_PUBLIC_` variant, and is empty in `.env.example`.
- ✓ B-004: covered by the F-U-003 check above.
- ✓ B-006: taken slots are filtered out, not labelled.
- ✓ C-001: route handlers call only `apiServer`; the repository calls only `apiClient`.
- ✓ C-002: the hand-written `/api/v1` routes (appointments POST, schedule GET, reassign, token PUT) each add server-side logic (a role gate, session scoping, or boundary validation), which the clause's own exception allows. `doctors`, `services`, `availability` and token GET are `proxyGet` one-liners.
- ✓ C-003: the repository returns the raw response; the hooks own snackbars and invalidation through `createQueryKeys` and `make{Create,Update}Mutation`.
- ✓ C-004: no changes to `src/@core`, `src/@layouts`, `src/@menu` or `src/components/{layout,theme}` in `dcf69b5..HEAD`; the theme work lives in `src/configs/*`.
- ✓ C-005: no payment paths; the price is display-only.
- ✓ C-006: the `booking_channel` rule is covered under F-U-001 and F-S-002 above.
- ✓ D-001: no timers.
- ✓ D-002: none of the out-of-scope v1 features.
- ✓ F-001: live regions are present on booking, reschedule, the slot picker, the doctor schedule and the reception board.
- ✓ F-002: the status chip shows text, an icon and a tint (`AppointmentStatusChip/index.tsx:27-55`).
- ✓ F-003: covered by the design-token check above.
- ✓ F-004: no `console.*`, `localStorage`, `sessionStorage` or `document.cookie` use in the clinic code.

---

## Not verifiable in this repository (manual review)

- **Upstream-owned**: the `appointment(doctor_id, start_time)` unique-where-booked constraint, the atomic reschedule, the reminder selection window (24h ± 5 min) and exactly-once `reminder_sent`, and the confirmation, reminder and reassignment emails. These await OQ-AR-1.
- **§F-001 beyond live regions**: contrast of 4.5:1 or better, visible focus, and target sizes of 24×24 or larger (44×44 for touch). Checking these needs a rendered audit.
- **§E-001 / §E-002 / 99% uptime**: there is no instrumentation (OQ-CN-2).

## Observations outside vault claims (not counted, already tracked in `bolts/_summary.md`)

- `src/views/Login.tsx:133-136`: `redirectTo` is not validated before `router.replace`. This is an open redirect after sign-in and is now also reachable through `/staff/login`. No constitution clause covers redirects, so it is not counted as a clause violation.
- `units/_index.md` still shows every unit as `pending` and "0/N complete", while `vault.json` changelog and `bolts/_summary.md` record 19/19 done. This is a vault-internal bookkeeping lag, not code drift.

## Suggested next actions

All 14 findings are queued in `PENDING-SYNC.md`. `--auto-apply=safe` was not passed, so nothing was written back.

| Finding | Severity | Claim | Source tier | Resolution path |
|---|---|---|---|---|
| DRIFT-C1 | HIGH | §B-005 role gate | vault_constitution (untiered) | human triage; FIX_CODE via a hardening unit that owns `src/libs/auth.ts` |
| DRIFT-F1 | HIGH | BR-002 taken-slot hiding in reschedule and walk-in | inferred (PRD §5 BR-002) | human triage; FIX_CODE normalisation, or pin the contract in the vault |
| DRIFT-E1 | HIGH | API contract | inferred (OQ-AR-1 recommendation) | human triage; UPDATE_VAULT, or fold into OQ-AR-1 |
| DRIFT-S1 | HIGH | `staff.working_hours` | inferred (PRD §Clinic.4) | human triage |
| DRIFT-D3 | HIGH | reassign status scope | inferred (PRD F-S-002) | human triage |
| DRIFT-F3 | HIGH | override date bounds | inferred (PRD F-S-002 step 4) | human triage [verify manually] |
| DRIFT-C2 | MEDIUM | §A-003 | vault_constitution | FIX_CODE, one-line import change |
| DRIFT-C3 | MEDIUM | §A-004 | vault_constitution | human triage (clause interpretation) |
| DRIFT-C4 | MEDIUM | §A-002 | vault_constitution | FIX_CODE, or amend clause |
| DRIFT-D1 | LOW | OQ-DM-1 | deferred OQ | `resolve-oq` (OQ-DM-1) |
| DRIFT-D2 | LOW | OQ-CN-3 | deferred OQ | `resolve-oq` (OQ-CN-3) |
| DRIFT-F2 | LOW | F-U-002 cancel path | deferred OQ | `resolve-oq` (OQ-FL-1), then a new unit |
| DRIFT-E2 | LOW | `/book` rate limit | deferred OQ | `resolve-oq` (OQ-CN-4) |
| DRIFT-S2 | LOW | upstream-owned columns | deferred OQ (OQ-AR-1) | UPDATE_VAULT, or fold into OQ-AR-1 |

The chain pauses because six HIGH findings are present. None is CRITICAL, since there are no LOCKED claims. There are three resolution paths:
1. Human triage of `PENDING-SYNC.md`.
2. Re-run `/mega-sdd:sync` after code or vault changes.
3. `--auto-apply=safe`. None of the 14 findings qualifies: the only missing-in-vault finding (DRIFT-E1) sits on a deferred OQ, and every other finding is outside the safe categories or below high confidence.

## Notes & caveats

- Detection is heuristic, using grep and read with no AST. Low-confidence findings (DRIFT-F3) may be false positives.
- Decision detection keyword-probes the constitution clauses and the OQ interims. Treat violations as triggers for review, not verdicts.
- **Scanned**: `src/features/appointments/**`, `src/app/(patient)/**`, `src/app/(dashboard)/staff/**`, `src/app/(blank-layout-pages)/staff/**`, `src/app/api/{appointments,cron}/**`, `src/app/api/v1/{appointments,doctors,services}/**`, `src/proxy.ts`, `src/libs/{auth.ts,label-maps.ts}`, `src/configs/primaryColorConfig/**`, `src/data/navigation/**`, `src/components/rbac/ProtectedRoute.tsx`, `src/views/Login.tsx`, `src/@core/contexts/settingsContext.tsx`, `package.json`, `.env.example`, and the full bolt diff `dcf69b5..HEAD` (58 files).
- **Excluded**: the other template reference features (`users`, `roles`, `permissions`, `branches`, `profile`), `node_modules`, and `.mega-sdd/`.
- This was a fresh scan. Bolt postflight snapshot reuse was not applied; the codebase is small, so a full read was used.
- **Changelog**: layout-3 vaults have no `vault.md` Changelog surface, and `context.md` has no `## Changelog` section. The drift session is recorded in this report only. `vault.json` is untouched and the vault version stays at v1.1, because no write-back was applied (`--auto-apply=safe` not set). This keeps re-runs idempotent.
- If the framework was mis-detected, re-run with an explicit `--scope=<dirs>` override.
