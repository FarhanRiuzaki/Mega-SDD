# Scenario 5 — Multi-Squad Parallel

**Time**: ~45 minutes
**Goal**: Partition work across multiple dev teams (squads); each squad runs independently in parallel.

For projects where multiple teams co-develop on the same vault. Each squad gets its share of units; the main-thread controller loops over squads and dispatches independent units' `bolt-implementer` agents concurrently (depth-1; no squad subagent exists); cross-squad coupling forced through explicit interface contracts.

## When to use multi-squad mode

- ≥2 distinct teams (backend + frontend, or be + fe + integrations)
- Want parallel development without merge conflicts
- Need clear ownership boundaries
- Have explicit cross-team contracts (REST APIs, GraphQL schemas, event payloads)

For solo developers or single-team: skip this scenario. Use default squad mode (single implicit squad).

## Prerequisites

- Mega-sdd v7.4+
- Existing project OR new project
- Recommended: ast-grep installed
- Clear understanding of team partition (which team owns what)

## Setup — declare squads

In your vault dir (after `generate-intent` runs OR pre-create for new vault):

Create `<vault>/_meta/squads.yaml`:

```yaml
mega_sdd_schema: 1
squads:
  - id: squad-be
    label: Backend Team
    owns_layers: [backend, data-model]
    owns_components: [api/*, app/Models/*, database/*]
    owns_flow_prefixes: [F-S-, F-B-]      # system flows + backend flows

  - id: squad-fe-web
    label: Frontend Web Team
    owns_layers: [frontend-web]
    owns_components: [resources/views/*, resources/js/*, public/*]
    owns_flow_prefixes: [F-U-]             # user-facing flows

  - id: squad-integrations
    label: Integrations Team
    owns_layers: [integrations]
    owns_components: [app/Services/External/*, app/Mail/*, app/Jobs/*]
    owns_feature_tags: [stripe, twilio, swift-messaging, ldap]
```

Squad partition rules:
1. `owns_components` (most specific)
2. `owns_flow_prefixes` (flow-level ownership)
3. `owns_layers` (broad)
4. `owns_feature_tags` (cross-cutting)

First match wins; ambiguity halts with `cross_squad_ambiguous` blocker.

## Step 1 — Run mega-sdd auto with multi-squad mode

```
/mega-sdd ./prd-clinic.md
```

When mega-sdd detects `_meta/squads.yaml`, it:
- Assigns each unit a `squad: <id>` per partition rules
- Validates cross-squad dependencies (must go through interface notes)
- Defaults to `--per-squad` execution for parallelism

## Step 2 — Watch squad partition + interface emission

After generate-units:

```
▶ Phase 3 of 4: invoking generate-units
✓ Phase 3 of 4: generate-units → 18 units across 3 squads

Squad partition:
  squad-be:           7 units (backend logic, models, migrations, API)
  squad-fe-web:       6 units (Blade views, forms, Tailwind, JS)
  squad-integrations: 3 units (email, SWIFT messaging adapter, LDAP)
  squad: default —    2 units (warning; they still execute)

Interface index emitted (`interfaces/_index.md`); the three notes below are authored by the architects:
  - api-patient-booking.md         (consumed by squad-fe; produced by squad-be)
  - api-doctor-schedule.md         (consumed by squad-fe; produced by squad-be)
  - email-reminder-payload.md      (consumed by squad-integrations; produced by squad-be)

⚠️ 2 unrouted units assigned squad: default — refine squads.yaml or accept
```

Two unassigned units flag — review squads.yaml; either add new squad or extend existing partition.

## Step 3 — Inspect generated unit with squad assignment

```bash
cat .mega-sdd/vaults/<slug>/units/U-001.md
```

```markdown
---
id: U-001
title: Build POST /api/appointments endpoint
module: M-booking
squad: squad-be                            # ← assigned by partition rules
task_type: create
target_files:
  - path: app/Http/Controllers/Api/AppointmentController.php
    operation: create
  - path: routes/api.php
    operation: modify
  - path: tests/Feature/AppointmentApiTest.php
    operation: create
produces_interfaces:                        # ← cross-squad contract
  - api-patient-booking                    # consumed by squad-fe
---
```

And a frontend unit:

```markdown
---
id: U-008
title: Booking form Blade view
module: M-booking
squad: squad-fe-web
task_type: create
target_files:
  - path: resources/views/booking.blade.php
consumes_interfaces:                        # ← waits for backend interface
  - api-patient-booking
---
```

Cross-squad coupling REQUIRES interface notes — direct `depends_on` between squads is rejected by mega-sdd (would halt with `cross_squad_dep_invalid`).

## Step 4 — Execute with --per-squad

When `auto` invokes `execute-bolts`, multi-squad mode auto-fires:

```
▶ Phase 4 of 4: invoking execute-bolts --per-squad --parallel
  Fan-out over 3 squads (main-thread loop; N implementer agents in flight):
    • squad-be
    • squad-fe-web
    • squad-integrations
  
  The controller iterates squads and filters units by squad: field; independent units dispatch concurrently.
  
  Pre-flight check: all consumed interfaces have status: ?
    api-patient-booking: status: draft → squad-fe-web HALTS on cross_squad_interface_draft
    api-doctor-schedule: status: draft → squad-fe-web HALTS
    email-reminder-payload: status: draft → squad-integrations HALTS
```

Interface lock gate: consumer squads wait for producer squad to LOCK their interfaces. Otherwise consumer codes against draft contract → high churn risk.

## Step 5 — Producer squad locks interfaces

In a separate session (or as squad-be lead):

```bash
# Edit each interface note that squad-be produces; mark as locked
```

```yaml
# .mega-sdd/vaults/<slug>/interfaces/api-patient-booking.md frontmatter:
---
id: api-patient-booking
producer: squad-be
consumers: [squad-fe-web]
kind: api
status: locked        # ← was: draft
# locked_at / locked_by: optional, your own bookkeeping
contract:
  endpoint: POST /api/appointments
  request: { patient_id, doctor_id, service_id, start_time }
  response: { appointment_id, status, confirmation_token }
  errors: 401, 422, 503
---

(rest of interface note content describing semantics)
```

After locking all 3 interfaces, resume the chain:

```
/mega-sdd --resume
```

Frontend + integrations squads proceed:

```
▶ Phase 4 of 4: invoking execute-bolts --per-squad --parallel (resumed)
  squad-be: continuing... 7 bolts processed
  squad-fe-web: 6 bolts queued; consumer interfaces NOW locked → execute
  squad-integrations: 3 bolts queued; execute
  
  Independent units across all 3 squads dispatch concurrently (main-thread loop, depth-1)...
  
✓ squad-be: 7/7 bolts complete (wave-1: 5 parallel, wave-2: 2 sequential)
✓ squad-fe-web: 6/6 bolts complete (wave-1: 4 parallel, wave-2: 2 sequential)
✓ squad-integrations: 3/3 bolts complete (wave-1: 3 parallel)

✓ Phase 4 of 4: execute-bolts → status: completed, items: 18/18 bolts, blocked: 0 (2 units ran as squad: default)
```

## Step 6 — Verify per squad

```bash
# Backend commits (only squad-be units)
git log --oneline | grep -E "U-(00[1-7])" | head

# Frontend commits
git log --oneline | grep -E "U-(00[8-9]|01[0-3])" | head

# Integrations commits
git log --oneline | grep -E "U-(01[4-6])" | head

# Module status — say "list modules" in Claude Code (typed skill commands were removed at 6.0.0)
```

```
M-booking          7 units    7/7 done    completed
M-auth             3 units    3/3 done    completed
M-reminders        3 units    3/3 done    completed
M-admin-schedule   3 units    3/3 done    completed
M-utility          2 units    2/2 done    completed (squad: default)
```

Two units in M-utility ran under `squad: default` (a warning, not a halt) — refine squads.yaml if they belong to a team.

## Real-world workflow

In practice, each squad runs in their own Claude Code session on their own laptop:

```bash
# Backend dev's machine:
cd ~/projects/clinic-app
# in Claude Code: "execute bolts --squad=squad-be"

# Frontend dev's machine (different person, different machine):
cd ~/projects/clinic-app
# in Claude Code: "execute bolts --squad=squad-fe-web"

# They merge via standard git workflow (PRs, rebase, etc.)
```

The pipeline supports BOTH:
- **Single-machine** `--per-squad` (main-thread loop over squads; independent units' implementer agents run concurrently — faster for solo dev)
- **Multi-machine** `--squad=<id>` (each dev runs their squad's slice; standard merge workflow)

## Common pitfalls

### cross_squad_dep_invalid halt

A unit's `depends_on` points to a unit in another squad WITHOUT going through interface note:

```yaml
blocker:
  type: cross_squad_dep_invalid
  details:
    unit_id: U-FE-005
    unit_squad: squad-fe-web
    dependency_id: U-BE-003
    dependency_squad: squad-be
  next_action: "Cross-squad direct depends_on not allowed. Producer squad
                declares produces_interfaces; consumer declares consumes_interfaces.
                See interfaces/_index.md"
```

Fix: remove the cross-squad `depends_on`. Either:
- Producer declares interface (`produces_interfaces`)
- Consumer declares interface (`consumes_interfaces`)
- Edit both units' frontmatter accordingly

### cross_squad_ambiguous halt

Two squads claim same artifact at same precedence level:

```yaml
blocker:
  type: cross_squad_ambiguous
  details:
    artifact: F-U-007
    artifact_kind: flow
    claimed_by_squads: [squad-fe-web, squad-mobile]
    matched_via: owns_layers
```

Fix: refine `_meta/squads.yaml`. One squad's match should be more specific (e.g., move `owns_components: [resources/views/booking.blade.php]` to whichever team should own it).

### cross_squad_interface_draft halt

Consumer squad's units wait; producer hasn't locked the interface yet (under `--deep`, the default, the chain first retries with backoff 30/60/120 s ×3 before stopping).

Fix: producer squad reviews + locks (`status: draft` → `status: locked`); optional: your own `locked_at`/`locked_by` notes. The consumer squad resumes via `--resume`.

### Unrouted units (`squad: default`)

Units that didn't match any partition rule get `squad: default` (a warning, not a halt) and still execute. To route them:
- Refine squads.yaml to claim them (add new owns_* rule)
- Assign them explicitly: edit unit frontmatter `squad: <existing-squad-id>`
- Or run them with `execute-bolts --all` after the squad fan-out

## What you learned

- Multi-squad mode partitions atomic units across teams via `_meta/squads.yaml`
- Cross-squad direct deps FORBIDDEN — must route through interface notes
- Interface lock gate prevents premature consumer coupling to draft producer contracts
- `--per-squad --parallel` loops squads on the main thread and dispatches independent units' implementer agents concurrently (no squad subagent)
- `--squad=<id>` lets each dev team run their slice independently on their own machine
- Same vault + atomic units + parallel execution = lower merge conflict risk

## Next scenario

→ [Scenario 6 — Recovery from halt](scenario-6-recovery-from-halt.md): bolt halted on Hard Rule violation; recover safely.
