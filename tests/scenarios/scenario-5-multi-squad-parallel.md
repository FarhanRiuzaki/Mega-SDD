# Scenario 5 — Multi-Squad Parallel

**Time**: ~45 minutes
**Goal**: Partition work across multiple dev teams (squads); each squad runs independently in parallel.

For projects where multiple teams co-develop on the same vault. Each squad gets its share of units; squads run as independent Claude subagents in parallel; cross-squad coupling forced through explicit interface contracts.

## When to use multi-squad mode

- ≥2 distinct teams (backend + frontend, or be + fe + integrations)
- Want parallel development without merge conflicts
- Need clear ownership boundaries
- Have explicit cross-team contracts (REST APIs, GraphQL schemas, event payloads)

For solo developers or single-team: skip this scenario. Use default squad mode (single implicit squad).

## Prerequisites

- Mega-sdd v6+
- Existing project OR new project
- Recommended: tree-sitter + ast-grep installed
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
▶ Phase 4 of 5: invoking generate-units
✓ Phase 4 of 5: generate-units → 18 units across 3 squads
  [auto] lint-units: 18 HIGH grounding | all anchors verified
  [auto] analyze-parallelism: max width per squad — be:5, fe:4, int:3 | total speedup 4.1x

Squad partition:
  squad-be:           7 units (backend logic, models, migrations, API)
  squad-fe-web:       6 units (Blade views, forms, Tailwind, JS)
  squad-integrations: 3 units (email, SWIFT messaging adapter, LDAP)
  squad-unassigned:   2 units (admin utilities; check squads.yaml)

Interface notes generated:
  - api-patient-booking.md         (consumed by squad-fe; produced by squad-be)
  - api-doctor-schedule.md         (consumed by squad-fe; produced by squad-be)
  - email-reminder-payload.md      (consumed by squad-integrations; produced by squad-be)

⚠️ 2 units in squad-unassigned — refine squads.yaml or accept as default squad
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
  - path: routes/api.php
  - path: tests/Feature/AppointmentApiTest.php
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
▶ Phase 5 of 5: invoking execute-bolts --per-squad --parallel
  Spawning 3 Claude subagents (one per declared squad):
    • squad-be subagent (background)
    • squad-fe-web subagent (background)
    • squad-integrations subagent (background)
  
  Each subagent runs in parallel; filters units by squad: field.
  
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
producer_squad: squad-be
consumer_squads: [squad-fe-web]
status: locked        # ← was: draft
locked_at: 2026-05-21T14:30:00Z
locked_by: backend-team-lead
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

Frontend + integrations subagents proceed:

```
▶ Phase 5 of 5: invoking execute-bolts --per-squad --parallel (resumed)
  squad-be subagent: continuing... 7 bolts processed
  squad-fe-web subagent: 6 bolts queued; consumer interfaces NOW locked → execute
  squad-integrations subagent: 3 bolts queued; execute
  
  All 3 subagents running in PARALLEL (concurrent)...
  
✓ squad-be subagent: 7/7 bolts complete (wave-1: 5 parallel, wave-2: 2 sequential)
✓ squad-fe-web subagent: 6/6 bolts complete (wave-1: 4 parallel, wave-2: 2 sequential)
✓ squad-integrations subagent: 3/3 bolts complete (wave-1: 3 parallel)

✓ Phase 5 of 5: execute-bolts → 16/16 complete (squad-unassigned 2 deferred per warning)
  [auto] list-modules: 4/4 modules with squad-explicit units complete
  [auto] emit-agents-md: AGENTS.md updated
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
M-utility          2 units    0/2 done    deferred (unassigned squad)
```

Two units in M-utility stayed deferred — either refine squads.yaml + re-run, or accept and run them sequentially solo.

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
- **Single-machine** `--per-squad` (spawns N subagents in parallel; faster for solo dev)
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

Consumer subagent waiting; producer hasn't locked the interface yet.

Fix: producer squad reviews + locks (`status: draft` → `status: locked`); add `locked_at` + `locked_by` metadata. Consumer subagent resumes via `--resume`.

### Squad-unassigned units

Units that didn't match any partition rule. Either:
- Refine squads.yaml to claim them (add new owns_* rule)
- Manually edit unit frontmatter: `squad: <existing-squad-id>`
- Accept and run them with `--squad=default` (single squad mode)

## What you learned

- Multi-squad mode partitions atomic units across teams via `_meta/squads.yaml`
- Cross-squad direct deps FORBIDDEN — must route through interface notes
- Interface lock gate prevents premature consumer coupling to draft producer contracts
- `--per-squad --parallel` spawns N Claude subagents for solo-dev parallelism
- `--squad=<id>` lets each dev team run their slice independently on their own machine
- Same vault + atomic units + parallel execution = lower merge conflict risk

## Next scenario

→ [Scenario 6 — Recovery from halt](scenario-6-recovery-from-halt.md): bolt halted on Hard Rule violation; recover safely.
